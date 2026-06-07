"""
rl_agent.py – Contextual-Bandit Reinforcement Learning Agent
=============================================================
Uses Stable-Baselines3 (PPO) to learn which recommendation strategy
(action) to apply per user context (state).

Workflow
--------
1. FastAPI calls `predict_action(state)` to get the current best action.
2. Flutter sends user feedback via POST /api/rl/feedback.
3. FastAPI stores the experience in the `rl_experiences` DB table.
4. A nightly cron job calls `train_offline()` to update the model.

Endpoints wired into FastAPI (add to your main FastAPI app):
    POST /api/rl/feedback   – receive {state, action, reward, customer_id?}
    GET  /api/rl/action     – receive ?state=0.5,0.3,... → returns {action}

Actions (discrete, 5 strategies)
----------------------------------
    0 = Solo Cross-sell
    1 = Solo Up-sell de volumen
    2 = Promociones especiales
    3 = Reposición de stock habitual
    4 = Combo personalizado
"""

import os
import json
import logging
import numpy as np
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

# Stable-Baselines3 imports
# Install with: pip install stable-baselines3 gymnasium
from stable_baselines3 import PPO
from stable_baselines3.common.env_util import make_vec_env
import gymnasium as gym
from gymnasium import spaces

load_dotenv()

# ─── Configuration ────────────────────────────────────────────────────────────
DB_HOST     = os.getenv("DB_HOST")
DB_USER     = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME     = os.getenv("DB_NAME")
DB_PORT     = os.getenv("DB_PORT", "5432")

MODEL_PATH  = "rl_model.zip"          # Saved/loaded model checkpoint
STATE_DIM   = 5                        # Feature vector size (see below)
N_ACTIONS   = 5                        # Number of recommendation strategies

logging.basicConfig(level=logging.INFO, format="%(asctime)s [RL] %(message)s")
logger = logging.getLogger(__name__)


# ─── State Feature Engineering ────────────────────────────────────────────────
# The state vector passed from FastAPI has STATE_DIM = 5 floats:
#   [0] avg_ticket          – Customer's average order value (normalised 0-1)
#   [1] bebidas_ratio       – Fraction of orders that are beverages (0-1)
#   [2] dia_semana          – Day of week 0=Mon … 6=Sun (normalised / 6)
#   [3] hora_dia            – Hour of day 0-23 (normalised / 23)
#   [4] n_productos_carrito – Current cart item count (capped at 20, /20)


# ─── Gymnasium Environment (Offline / Replay) ─────────────────────────────────
class RecommendationEnv(gym.Env):
    """
    Minimal Gymnasium environment backed by experience replay from PostgreSQL.
    Used for offline (batch) training with SB3.
    """

    metadata = {"render_modes": []}

    def __init__(self, experiences: list[dict]):
        super().__init__()
        self.experiences   = experiences
        self.current_idx   = 0
        self.observation_space = spaces.Box(
            low=0.0, high=1.0, shape=(STATE_DIM,), dtype=np.float32
        )
        self.action_space = spaces.Discrete(N_ACTIONS)

    def reset(self, *, seed=None, options=None):
        super().reset(seed=seed)
        self.current_idx = 0
        obs = np.array(self.experiences[0]["state"], dtype=np.float32)
        return obs, {}

    def step(self, action):
        exp        = self.experiences[self.current_idx]
        reward     = exp["reward"] if action == exp["action"] else -0.1
        self.current_idx += 1
        terminated  = self.current_idx >= len(self.experiences)
        truncated   = False
        if not terminated:
            obs = np.array(self.experiences[self.current_idx]["state"], dtype=np.float32)
        else:
            obs = np.zeros(STATE_DIM, dtype=np.float32)
        return obs, float(reward), terminated, truncated, {}


# ─── Database Helpers ─────────────────────────────────────────────────────────
def _get_conn():
    return psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER,
        password=DB_PASSWORD, port=DB_PORT,
        sslmode="require", sslrootcert="ca.pem"
    )


def save_experience(state: list[float], action: int, reward: float,
                    customer_id: str | None = None):
    """Persist one interaction experience to PostgreSQL."""
    conn = _get_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO rl_experiences (state, action, reward, customer_id)
                       VALUES (%s, %s, %s, %s)""",
                    (state, action, reward, customer_id)
                )
        logger.info("Experience saved: action=%d reward=%.1f", action, reward)
    finally:
        conn.close()


def load_experiences(limit: int = 10_000) -> list[dict]:
    """Fetch the most recent `limit` experiences for offline training."""
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT state, action, reward FROM rl_experiences
                   ORDER BY created_at DESC LIMIT %s""",
                (limit,)
            )
            rows = cur.fetchall()
        return [{"state": r[0], "action": r[1], "reward": r[2]} for r in rows]
    finally:
        conn.close()


# ─── Model Lifecycle ──────────────────────────────────────────────────────────
_model: PPO | None = None   # In-memory model singleton


def load_model() -> PPO:
    """Load model from disk, or create a fresh one if none exists."""
    global _model
    if os.path.exists(MODEL_PATH):
        logger.info("Loading existing RL model from %s", MODEL_PATH)
        # We need a dummy env for loading
        dummy_env = make_vec_env(lambda: _make_dummy_env(), n_envs=1)
        _model = PPO.load(MODEL_PATH, env=dummy_env)
    else:
        logger.info("No model found – initialising fresh PPO model.")
        dummy_env = make_vec_env(lambda: _make_dummy_env(), n_envs=1)
        _model = PPO("MlpPolicy", dummy_env, verbose=0)
    return _model


def _make_dummy_env():
    """Minimal env with random data for model initialisation."""
    dummy = [{"state": [0.5] * STATE_DIM, "action": 0, "reward": 0.0}]
    return RecommendationEnv(dummy)


def predict_action(state: list[float]) -> int:
    """
    Inference: given a state vector, return the recommended strategy action.
    Called synchronously from FastAPI.
    """
    global _model
    if _model is None:
        load_model()
    obs = np.array(state, dtype=np.float32).reshape(1, -1)
    action, _ = _model.predict(obs, deterministic=True)
    return int(action)


def train_offline(total_timesteps: int = 2000):
    """
    Offline training loop – meant to be called by a nightly cron job.
    Loads recent experiences from PostgreSQL and fine-tunes the PPO model.
    """
    global _model
    logger.info("Starting offline RL training...")

    experiences = load_experiences()
    if len(experiences) < 10:
        logger.warning("Not enough experiences (%d) to train. Skipping.", len(experiences))
        return

    # Shuffle for stable training
    import random
    random.shuffle(experiences)

    env = RecommendationEnv(experiences)
    from stable_baselines3.common.vec_env import DummyVecEnv
    vec_env = DummyVecEnv([lambda: env])

    if _model is None:
        load_model()

    # Replace the env and continue learning
    _model.set_env(vec_env)
    _model.learn(total_timesteps=total_timesteps, reset_num_timesteps=False)
    _model.save(MODEL_PATH)

    logger.info("RL training complete. Model saved to %s", MODEL_PATH)


# ─── FastAPI Router (paste into your main FastAPI app) ────────────────────────
# Add these two functions to your FastAPI app file:
#
#   from rl_agent import predict_action, save_experience, load_model
#
#   @app.on_event("startup")
#   async def startup_event():
#       load_model()  # pre-load model into memory at boot
#
#   class RlFeedbackPayload(BaseModel):
#       state: List[float]
#       action: int
#       reward: float
#       customer_id: Optional[str] = None
#
#   @app.post("/api/rl/feedback")
#   async def rl_feedback(payload: RlFeedbackPayload):
#       save_experience(payload.state, payload.action, payload.reward, payload.customer_id)
#       return {"status": "ok"}
#
#   @app.get("/api/rl/action")
#   async def rl_action(state: str):
#       # state is a comma-separated list: ?state=0.5,0.3,0.2,0.4,0.1
#       state_vec = [float(x) for x in state.split(",")]
#       action = predict_action(state_vec)
#       return {"action": action, "strategy": ACTION_LABELS[action]}
#
ACTION_LABELS = {
    0: "Solo Cross-sell",
    1: "Solo Up-sell de volumen",
    2: "Promociones especiales",
    3: "Reposición de stock habitual",
    4: "Combo personalizado",
}

# ─── Cron Entry Point ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Run this script nightly via cron:
    #   0 3 * * * cd /path/to/project && python rl_agent.py
    load_model()
    train_offline(total_timesteps=2000)
    logger.info("Done.")

-- DDL for Reinforcement Learning telemetry table
-- Each row records one user interaction experience used for offline training.

CREATE TABLE IF NOT EXISTS rl_experiences (
    id             BIGSERIAL PRIMARY KEY,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- State vector: numeric features describing the user context at decision time
    -- Examples: [avg_ticket, bebidas_ratio, dia_semana, hora_dia, n_productos_carrito]
    state          FLOAT[]    NOT NULL,

    -- Action chosen by the RL model (0-4 recommendation strategy index)
    -- 0 = Solo Cross-sell
    -- 1 = Solo Up-sell volumen
    -- 2 = Promociones
    -- 3 = Reposición de stock
    -- 4 = Combo personalizado
    action         SMALLINT   NOT NULL CHECK (action BETWEEN 0 AND 4),

    -- Reward signal from the user's response
    -- +1.0  = Accepted cart as-is (full checkout)
    -- +0.5  = Modified qty or removed item but completed checkout
    -- -1.0  = Discarded suggestion and built cart from scratch
    reward         FLOAT      NOT NULL CHECK (reward BETWEEN -1.0 AND 1.0),

    -- Optional: customer identifier for user-level analysis
    customer_id    TEXT
);

-- Index to speed up chronological training queries
CREATE INDEX IF NOT EXISTS rl_experiences_created_at_idx
    ON rl_experiences (created_at DESC);

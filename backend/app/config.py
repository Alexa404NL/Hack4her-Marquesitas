import os
from dotenv import load_dotenv

# Load variables from current or root directories
load_dotenv()

class Settings:
    DB_HOST: str = os.getenv("DB_HOST", "")
    DB_USER: str = os.getenv("DB_USER", "")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    DB_NAME: str = os.getenv("DB_NAME", "")
    DB_PORT: str = os.getenv("DB_PORT", "10751")
    API_KEY: str = os.getenv("API_KEY", "")

settings = Settings()

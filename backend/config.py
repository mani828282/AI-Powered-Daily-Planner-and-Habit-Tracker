import os
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Database Configuration
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = ""
    DB_NAME: str = "ai_planner_db"
    DB_SSL: bool = False  # Enable for cloud MySQL providers
    
    # Groq API Configuration
    GROQ_API_KEY: str = ""  # Set via environment variable on Render
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    AI_MODEL: str = "llama-3.1-8b-instant"
    
    # JWT Configuration
    SECRET_KEY: str = "your-secret-key-change-in-production-make-it-very-long-and-random"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # App Configuration
    APP_NAME: str = "AI-Powered Daily Planner"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    
    # Phone Verification (Mock for now)
    VERIFICATION_CODE_LENGTH: int = 6
    VERIFICATION_CODE_EXPIRE_MINUTES: int = 10
    
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Auto-configure from DATABASE_URL or MYSQL_URL if present
        # Cloud providers (DigitalOcean, Aiven, TiDB, etc.) often set these
        import os
        from urllib.parse import urlparse
        
        db_url = os.getenv("DATABASE_URL") or os.getenv("MYSQL_URL")
        if db_url:
            try:
                # Handle mysql:// or mysql+mysqlconnector://
                if db_url.startswith("mysql"):
                    parsed = urlparse(db_url)
                    self.DB_HOST = parsed.hostname or self.DB_HOST
                    self.DB_PORT = parsed.port or self.DB_PORT
                    self.DB_USER = parsed.username or self.DB_USER
                    self.DB_PASSWORD = parsed.password or self.DB_PASSWORD
                    self.DB_NAME = parsed.path.lstrip("/") or self.DB_NAME
                    # Enable SSL for remote database connections
                    self.DB_SSL = True
            except Exception as e:
                print(f"Error parsing DATABASE_URL: {e}")
        
        # Auto-detect cloud environment and enable SSL
        if os.getenv("RENDER") or os.getenv("IS_RENDER"):
            self.DB_SSL = True
        
        # If DB_HOST is not localhost, likely a remote DB — enable SSL
        if self.DB_HOST not in ("localhost", "127.0.0.1", "host.docker.internal"):
            self.DB_SSL = True

settings = Settings()

# Database URL getter for SQLAlchemy (if needed later)
def get_database_url():
    return f"mysql+mysqlconnector://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"

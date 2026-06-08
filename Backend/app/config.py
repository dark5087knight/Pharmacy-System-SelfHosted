import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ENV: str = "development"

    model_config = SettingsConfigDict(extra="ignore")

def load_settings() -> Settings:
    yaml_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.yaml")
    yaml_config = {}
    if os.path.exists(yaml_path):
        with open(yaml_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if ":" in line:
                    k, v = line.split(":", 1)
                    k = k.strip()
                    v = v.strip()
                    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                        v = v[1:-1]
                    if v.isdigit():
                        v = int(v)
                    yaml_config[k] = v

    # Override with env variables if set
    for k in Settings.__annotations__:
        env_val = os.getenv(k)
        if env_val is not None:
            if Settings.__annotations__[k] == int:
                yaml_config[k] = int(env_val)
            else:
                yaml_config[k] = env_val

    return Settings(**yaml_config)

settings = load_settings()

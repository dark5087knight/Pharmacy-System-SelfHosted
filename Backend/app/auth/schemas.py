from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional
from datetime import datetime

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenUserResponse(CamelModel):
    id: str
    name: str
    username: str
    email: Optional[str] = None
    role: str
    status: str
    shift: str
    joined_at: str
    last_seen: str
    pharmacy_name: Optional[str] = None
    pharmacy_settings_id: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    session_token: str
    user: TokenUserResponse


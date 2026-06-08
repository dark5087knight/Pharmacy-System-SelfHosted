from pydantic import BaseModel, ConfigDict
from typing import Optional

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class NotificationBase(CamelModel):
    title: str
    body: str
    category: str
    priority: str
    read: bool
    at: str

class NotificationCreate(NotificationBase):
    id: str

class NotificationResponse(NotificationBase):
    id: str

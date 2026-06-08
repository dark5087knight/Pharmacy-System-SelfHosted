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

class ActivityEventBase(CamelModel):
    type: str
    message: str
    actor: str  # Actor name
    at: str
    severity: Optional[str] = None

class ActivityEventCreate(ActivityEventBase):
    id: str

class ActivityEventResponse(ActivityEventBase):
    id: str

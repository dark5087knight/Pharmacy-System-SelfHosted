from pydantic import BaseModel, ConfigDict
from typing import List, Optional

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class RoleBase(CamelModel):
    name: str
    description: str
    permissions: List[str]

class RoleCreate(RoleBase):
    id: str

class RoleResponse(RoleBase):
    id: str

class StaffMemberBase(CamelModel):
    name: str
    username: str
    email: Optional[str] = None
    role: str
    status: str
    shift: str
    joined_at: str
    last_seen: str

class StaffMemberCreate(StaffMemberBase):
    id: str
    password: Optional[str] = None

class StaffMemberResponse(StaffMemberBase):
    id: str

from pydantic import BaseModel

class GroupCreate(BaseModel):
    name: str
    description: str
    purpose: str
    type: str  # public/private/invite

class GroupJoin(BaseModel):
    group_id: int

class GroupJoinByCode(BaseModel):
    code: str
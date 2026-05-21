from pydantic import BaseModel

class IdeaCreate(BaseModel):
    group_id: int
    title: str
    description: str
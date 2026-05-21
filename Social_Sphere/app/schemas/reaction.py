from pydantic import BaseModel

class ReactionCreate(BaseModel):
    post_id: int
    type: str
from pydantic import BaseModel

class CommentCreate(BaseModel):
    post_id: int
    content: str
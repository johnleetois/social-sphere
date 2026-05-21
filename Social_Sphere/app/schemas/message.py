from pydantic import BaseModel

class MessageCreate(BaseModel):
    channel_id: int
    content: str
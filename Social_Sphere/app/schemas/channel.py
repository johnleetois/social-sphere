from pydantic import BaseModel

class ChannelCreate(BaseModel):
    group_id: int
    name: str
    type: str
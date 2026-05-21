from pydantic import BaseModel
from datetime import datetime

class EventCreate(BaseModel):
    group_id: int
    title: str
    description: str
    event_date: datetime
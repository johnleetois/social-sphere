from pydantic import BaseModel
from datetime import datetime

class TaskCreate(BaseModel):
    group_id: int
    assigned_to: int
    title: str
    description: str
    deadline: datetime
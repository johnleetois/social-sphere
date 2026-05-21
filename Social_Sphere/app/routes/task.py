from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.task import TaskCreate
from app.services.task_service import create_task, get_tasks
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/tasks", tags=["Tasks"])

@router.post("/")
def create(data: TaskCreate, db: Session = Depends(get_db), user = Depends(get_current_user)):
    task = create_task(db, user.id, data)

    if not task:
        raise HTTPException(status_code=403, detail="Not a group member")

    return task


@router.get("/group/{group_id}")
def get(group_id: int, db: Session = Depends(get_db), user = Depends(get_current_user)):
    tasks = get_tasks(db, group_id, user.id)

    if tasks is None:
        raise HTTPException(status_code=403, detail="Access denied")

    return tasks
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.idea import IdeaCreate
from app.services.idea_service import create_idea, get_group_ideas
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/ideas", tags=["Ideas"])

@router.post("/")
def create(data: IdeaCreate, db: Session = Depends(get_db), user = Depends(get_current_user)):
    idea = create_idea(db, user.id, data)

    if not idea:
        raise HTTPException(status_code=403, detail="Not a group member")

    return idea


@router.get("/group/{group_id}")
def get(group_id: int, db: Session = Depends(get_db), user = Depends(get_current_user)):
    ideas = get_group_ideas(db, group_id, user.id)

    if ideas is None:
        raise HTTPException(status_code=403, detail="Access denied")

    return ideas
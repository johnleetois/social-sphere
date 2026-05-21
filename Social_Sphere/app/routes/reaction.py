from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.services.reaction_service import toggle_reaction, get_likers
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/reactions", tags=["Reactions"])


@router.post("/toggle/{post_id}")
def toggle(post_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return toggle_reaction(db, user.id, post_id)


@router.get("/{post_id}/likers")
def likers(post_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return get_likers(db, post_id)

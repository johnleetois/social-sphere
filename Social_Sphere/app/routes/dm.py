from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.core.dependencies import get_current_user
from app.services import dm_service

router = APIRouter(prefix="/dm", tags=["Direct Messages"])


@router.get("/conversations")
def get_conversations(db: Session = Depends(get_db), user=Depends(get_current_user)):
    return dm_service.get_conversations(db, user.id)


@router.get("/history/{peer_id}")
def get_history(
    peer_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    msgs = dm_service.get_dm_history(db, user.id, peer_id, skip, limit)
    return [
        {
            "id": m.id,
            "sender_id": m.sender_id,
            "receiver_id": m.receiver_id,
            "content": m.content,
            "message_type": m.message_type,
            "is_read": m.is_read,
            "created_at": m.created_at.isoformat(),
        }
        for m in msgs
    ]

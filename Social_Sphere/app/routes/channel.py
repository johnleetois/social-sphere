from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.channel import ChannelCreate
from app.services.channel_service import create_channel, get_group_channels
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/channels", tags=["Channels"])

@router.post("/")
def create(data: ChannelCreate, db: Session = Depends(get_db), user = Depends(get_current_user)):
    channel = create_channel(db, user.id, data)
    if not channel:
        raise HTTPException(status_code=403, detail="Only group owners/admins can create channels")
    return channel

@router.get("/group/{group_id}")
def get_channels(group_id: int, db: Session = Depends(get_db), user = Depends(get_current_user)):
    return get_group_channels(db, group_id)

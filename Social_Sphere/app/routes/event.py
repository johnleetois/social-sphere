from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.event import EventCreate
from app.services.event_service import create_event, get_events
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/events", tags=["Events"])

@router.post("/")
def create(data: EventCreate, db: Session = Depends(get_db), user = Depends(get_current_user)):
    event = create_event(db, user.id, data)

    if not event:
        raise HTTPException(status_code=403, detail="Not a group member")

    return event


@router.get("/group/{group_id}")
def get(group_id: int, db: Session = Depends(get_db), user = Depends(get_current_user)):
    events = get_events(db, group_id, user.id)

    if events is None:
        raise HTTPException(status_code=403, detail="Access denied")

    return events
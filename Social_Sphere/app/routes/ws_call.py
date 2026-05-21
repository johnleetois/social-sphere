"""
WebRTC signaling server.
Handles: call_request, call_accept, call_reject, call_end,
         offer (SDP), answer (SDP), ice_candidate
"""
from fastapi import APIRouter, WebSocket
from sqlalchemy.orm import Session
from jose import jwt

from app.services.ws_manager import manager
from app.database.database import SessionLocal
from app.core.config import SECRET_KEY, ALGORITHM
from app.models.user import User
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


@router.websocket("/ws/call")
async def call_signaling(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001)
        return

    db: Session = SessionLocal()
    user = None

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            await websocket.close(code=4001)
            db.close()
            return

        await manager.call_connect(user.id, websocket)
        logger.info(f"User {user.username} connected to call signaling")

        while True:
            try:
                data = await websocket.receive_json()
                sig_type = data.get("type")
                target_id = data.get("target_id")

                if not target_id:
                    continue

                # Forward the signal to the target user with sender info
                await manager.call_send(target_id, {
                    **data,
                    "from_user_id": user.id,
                    "from_username": user.username,
                    "from_avatar": user.avatar_url,
                })

                logger.info(f"Signal '{sig_type}' from {user.username} -> user {target_id}")

            except Exception as e:
                logger.info(f"Call WS loop ended: {e}")
                break

    except Exception as e:
        logger.error(f"Call WS error: {e}")
    finally:
        if user:
            manager.call_disconnect(user.id)
        db.close()

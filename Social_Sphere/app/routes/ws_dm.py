from fastapi import APIRouter, WebSocket
from sqlalchemy.orm import Session
from jose import jwt

from app.services.ws_manager import manager
from app.services.dm_service import save_dm, _share_group
from app.database.database import SessionLocal
from app.core.config import SECRET_KEY, ALGORITHM
from app.models.user import User
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


@router.websocket("/ws/dm/{peer_id}")
async def dm_chat(websocket: WebSocket, peer_id: int):
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

        peer = db.query(User).filter(User.id == peer_id).first()
        if not peer:
            await websocket.close(code=4004)
            db.close()
            return

        if not _share_group(db, user.id, peer_id):
            await websocket.close(code=4003)
            db.close()
            return

        await manager.dm_connect(user.id, peer_id, websocket)

        # Notify peer that this user is now online
        await manager.dm_send(user.id, peer_id, {
            "type": "presence",
            "user_id": user.id,
            "is_online": True,
        })

        while True:
            try:
                data = await websocket.receive_json()
                msg_type = data.get("type", "message")

                if msg_type == "typing":
                    await manager.set_typing_dm(
                        user.id, peer_id, user.username, data.get("is_typing", False)
                    )

                elif msg_type == "message":
                    content = data.get("content", "").strip()
                    mtype = data.get("message_type", "text")
                    if not content:
                        continue

                    msg = save_dm(db, user.id, peer_id, content, mtype)

                    payload_out = {
                        "type": "message",
                        "id": msg.id,
                        "sender_id": user.id,
                        "username": user.username,
                        "avatar_url": user.avatar_url,
                        "content": msg.content,
                        "message_type": msg.message_type,
                        "is_read": False,
                        "timestamp": msg.created_at.isoformat(),
                    }

                    # Send to both sender and receiver
                    await manager.dm_send(user.id, peer_id, payload_out)

                elif msg_type == "seen":
                    # Mark messages from peer as read
                    from app.models.direct_message import DirectMessage
                    db.query(DirectMessage).filter_by(
                        sender_id=peer_id, receiver_id=user.id, is_read=False
                    ).update({"is_read": True})
                    db.commit()
                    await manager.dm_send(user.id, peer_id, {
                        "type": "seen",
                        "by_user_id": user.id,
                    })

            except Exception as e:
                logger.info(f"DM WS loop ended: {e}")
                break

    except Exception as e:
        logger.error(f"DM WS error: {e}")
    finally:
        if user:
            manager.dm_disconnect(user.id, peer_id, websocket)
            await manager.dm_send(user.id, peer_id, {
                "type": "presence",
                "user_id": user.id,
                "is_online": False,
            })
        db.close()

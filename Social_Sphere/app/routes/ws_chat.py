from fastapi import APIRouter, WebSocket
from sqlalchemy.orm import Session
from app.services.ws_manager import manager
from app.database.database import SessionLocal
from jose import jwt
from app.core.config import SECRET_KEY, ALGORITHM
from app.models.user import User
from app.models.channel import Channel
from app.models.message import Message
from app.services.group_utils import is_member
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


@router.websocket("/ws/chat/{channel_id}")
async def chat(websocket: WebSocket, channel_id: int):
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

        channel = db.query(Channel).filter(Channel.id == channel_id).first()
        if not channel:
            await websocket.close(code=4004)
            db.close()
            return

        if not is_member(db, user.id, channel.group_id):
            await websocket.close(code=4003)
            db.close()
            return

        await manager.channel_connect(channel_id, user.id, websocket)

        # Announce presence
        await manager.channel_broadcast(channel_id, {
            "type": "presence",
            "user_id": user.id,
            "username": user.username,
            "is_online": True,
        })

        # Send message history (last 50)
        history = (
            db.query(Message)
            .filter_by(channel_id=channel_id)
            .order_by(Message.created_at.asc())
            .limit(50)
            .all()
        )
        for m in history:
            u = db.query(User).filter(User.id == m.user_id).first()
            await websocket.send_json({
                "type": "history",
                "id": m.id,
                "user_id": m.user_id,
                "username": u.username if u else "Unknown",
                "avatar_url": u.avatar_url if u else None,
                "content": m.content,
                "message_type": getattr(m, "message_type", "text"),
                "timestamp": m.created_at.isoformat() if m.created_at else None,
            })

        while True:
            try:
                data = await websocket.receive_json()
                msg_type = data.get("type", "message")

                if msg_type == "typing":
                    await manager.set_typing_channel(
                        channel_id, user.id, user.username, data.get("is_typing", False)
                    )

                elif msg_type == "message":
                    content = data.get("content", "").strip()
                    mtype = data.get("message_type", "text")
                    if not content:
                        continue

                    msg = Message(
                        user_id=user.id,
                        channel_id=channel_id,
                        content=content,
                    )
                    try:
                        msg.message_type = mtype
                    except AttributeError:
                        pass
                    db.add(msg)
                    db.commit()
                    db.refresh(msg)

                    await manager.channel_broadcast(channel_id, {
                        "type": "message",
                        "id": msg.id,
                        "user_id": user.id,
                        "username": user.username,
                        "avatar_url": user.avatar_url,
                        "content": msg.content,
                        "message_type": mtype,
                        "timestamp": msg.created_at.isoformat() if msg.created_at else None,
                    })

                elif msg_type == "seen":
                    await manager.channel_broadcast(channel_id, {
                        "type": "seen",
                        "user_id": user.id,
                        "username": user.username,
                    })

            except Exception as e:
                logger.info(f"Channel WS loop ended: {e}")
                break

    except Exception as e:
        logger.error(f"Channel WS error: {e}")
    finally:
        if user:
            manager.channel_disconnect(channel_id, user.id, websocket)
            await manager.channel_broadcast(channel_id, {
                "type": "presence",
                "user_id": user.id,
                "username": user.username,
                "is_online": False,
            })
        db.close()

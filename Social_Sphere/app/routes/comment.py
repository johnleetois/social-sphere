from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.comment import CommentCreate
from app.services.comment_service import create_comment, delete_comment
from app.core.dependencies import get_current_user
from app.models.comment import Comment
from app.models.user import User

router = APIRouter(prefix="/comments", tags=["Comments"])


@router.post("/")
def add_comment(data: CommentCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return create_comment(db, user.id, data)


@router.get("/{post_id}")
def get_comments(post_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    comments = (
        db.query(Comment)
        .filter_by(post_id=post_id)
        .order_by(Comment.created_at.asc())
        .all()
    )
    result = []
    for c in comments:
        author = db.query(User).filter(User.id == c.user_id).first()
        result.append({
            "id": c.id,
            "post_id": c.post_id,
            "user_id": c.user_id,
            "username": author.username if author else "Unknown",
            "avatar_url": author.avatar_url if author else None,
            "content": c.content,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        })
    return result


@router.delete("/{comment_id}")
def remove_comment(comment_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    delete_comment(db, user.id, comment_id)
    return {"message": "Comment deleted"}

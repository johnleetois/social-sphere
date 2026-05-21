from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.post import PostCreate, PostUpdate
from app.services.post_service import create_post
from app.core.dependencies import get_current_user
from app.core.limiter import limiter
from app.models.post import Post
from app.models.comment import Comment
from app.models.reaction import Reaction
from app.models.user import User
from app.models.group_member import GroupMember
from app.services.group_utils import is_member

router = APIRouter(prefix="/posts", tags=["Posts"])


def _enrich(post: Post, db: Session, current_user_id: int) -> dict:
    author = db.query(User).filter(User.id == post.user_id).first()
    reactions = db.query(Reaction).filter_by(post_id=post.id, type="like").all()
    comment_count = db.query(Comment).filter_by(post_id=post.id).count()
    likers = []
    is_liked = False
    for r in reactions:
        if r.user_id == current_user_id:
            is_liked = True
        u = db.query(User).filter(User.id == r.user_id).first()
        if u:
            likers.append({"user_id": u.id, "username": u.username, "avatar_url": u.avatar_url})
    return {
        "id": post.id,
        "group_id": post.group_id,
        "user_id": post.user_id,
        "username": author.username if author else "Unknown",
        "avatar_url": author.avatar_url if author else None,
        "content": post.content,
        "media_url": post.media_url,
        "is_pinned": getattr(post, "is_pinned", False) or False,
        "created_at": post.created_at.isoformat() if post.created_at else None,
        "like_count": len(reactions),
        "is_liked_by_me": is_liked,
        "likers": likers,
        "comment_count": comment_count,
    }


@router.post("/")
@limiter.limit("10/minute")
def create(request: Request, data: PostCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    post = create_post(db, user.id, data)
    if not post:
        raise HTTPException(status_code=403, detail="Not a group member")
    return _enrich(post, db, user.id)


@router.get("/group/{group_id}")
def get_posts(
    group_id: int,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    if not is_member(db, user.id, group_id):
        raise HTTPException(status_code=403, detail="Access denied")

    posts = (
        db.query(Post)
        .filter(Post.group_id == group_id)
        .order_by(Post.is_pinned.desc(), Post.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich(p, db, user.id) for p in posts]


@router.patch("/{post_id}")
def edit_post(
    post_id: int,
    data: PostUpdate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your post")
    post.content = data.content
    db.commit()
    db.refresh(post)
    return _enrich(post, db, user.id)


@router.delete("/{post_id}")
def delete_post(
    post_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    # Allow owner of post OR group admin/owner to delete
    membership = db.query(GroupMember).filter_by(user_id=user.id, group_id=post.group_id).first()
    is_admin = membership and membership.role in ("owner", "admin")
    if post.user_id != user.id and not is_admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db.query(Comment).filter_by(post_id=post_id).delete()
    db.query(Reaction).filter_by(post_id=post_id).delete()
    db.delete(post)
    db.commit()
    return {"message": "Post deleted"}


@router.patch("/{post_id}/pin")
def pin_post(
    post_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    membership = db.query(GroupMember).filter_by(user_id=user.id, group_id=post.group_id).first()
    if not membership or membership.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="Only admins can pin posts")
    post.is_pinned = not (getattr(post, "is_pinned", False) or False)
    db.commit()
    db.refresh(post)
    return {"is_pinned": post.is_pinned}

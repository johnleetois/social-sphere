from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.database import get_db
from app.schemas.group import GroupCreate, GroupJoin, GroupJoinByCode
from app.services.group_service import create_group, join_group, join_by_code
from app.core.dependencies import get_current_user
from app.models.group_member import GroupMember
from app.models.group import Group
from app.models.post import Post


router = APIRouter(prefix="/groups", tags=["Groups"])


@router.post("/create")
def create_group_route(
    group: GroupCreate,
    db: Session = Depends(get_db),
    user = Depends(get_current_user)
):
    g = create_group(db, user.id, group)
    return {
        "id": g.id,
        "name": g.name,
        "description": g.description,
        "purpose": g.purpose,
        "type": g.type,
        "invite_code": g.invite_code,
        "owner_id": g.owner_id,
    }


@router.post("/join")
def join_group_route(
    data: GroupJoin,
    db: Session = Depends(get_db),
    user = Depends(get_current_user)
):
    member = join_group(db, user.id, data.group_id)

    if not member:
        raise HTTPException(status_code=400, detail="Already a member")

    return {"message": "Joined group"}


@router.post("/join-by-code")
def join_by_code_route(
    data: GroupJoinByCode,
    db: Session = Depends(get_db),
    user = Depends(get_current_user)
):
    group, err = join_by_code(db, user.id, data.code)

    if err == "Invalid invite code":
        raise HTTPException(status_code=404, detail="Invalid invite code")

    return {"message": "Joined group", "group_id": group.id, "group_name": group.name}

@router.get("/my")
def get_my_groups(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    memberships = db.query(GroupMember).filter(
        GroupMember.user_id == user.id
    ).all()

    groups = []
    for m in memberships:
        group = db.query(Group).filter(Group.id == m.group_id).first()
        if group is None:
            continue

        member_count = db.query(GroupMember).filter(GroupMember.group_id == m.group_id).count()
        last_post = (
            db.query(Post)
            .filter(Post.group_id == m.group_id)
            .order_by(Post.created_at.desc())
            .first()
        )

        groups.append({
            "id": group.id,
            "name": group.name,
            "description": group.description,
            "type": group.type,
            "role": m.role,
            "member_count": member_count,
            "last_post_at": last_post.created_at.isoformat() if last_post else None,
            "last_post_preview": (last_post.content[:80] if last_post and last_post.content else None),
        })

    return groups

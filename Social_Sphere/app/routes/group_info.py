from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from app.database.database import get_db
from app.core.dependencies import get_current_user
from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.user import User
from app.services.group_utils import is_member

router = APIRouter(prefix="/groups", tags=["Group Info & Management"])


# ── Schemas ─────────────────────────────────────────────────

class GroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    avatar_url: Optional[str] = None


class RoleUpdate(BaseModel):
    role: str  # admin | member


# ── Info ────────────────────────────────────────────────────

@router.get("/{group_id}/info")
def get_group_info(
    group_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    if not is_member(db, user.id, group_id):
        raise HTTPException(status_code=403, detail="Not a group member")

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    memberships = db.query(GroupMember).filter_by(group_id=group_id).all()
    members = []
    for m in memberships:
        u = db.query(User).filter(User.id == m.user_id).first()
        if u:
            members.append({
                "user_id": u.id,
                "username": u.username,
                "full_name": u.full_name,
                "avatar_url": u.avatar_url,
                "role": m.role,
                "joined_at": m.joined_at.isoformat() if m.joined_at else None,
            })

    my_membership = next((m for m in memberships if m.user_id == user.id), None)
    my_role = my_membership.role if my_membership else "member"
    is_admin = my_role in ("owner", "admin")

    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "purpose": group.purpose,
        "type": group.type,
        "avatar_url": getattr(group, "avatar_url", None),
        "owner_id": group.owner_id,
        "created_at": group.created_at.isoformat() if group.created_at else None,
        "member_count": len(members),
        "members": members,
        "invite_code": group.invite_code if is_admin else None,
    }


# ── Update group (admin/owner only) ─────────────────────────

@router.put("/{group_id}")
def update_group(
    group_id: int,
    data: GroupUpdate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    membership = db.query(GroupMember).filter_by(user_id=user.id, group_id=group_id).first()
    if not membership or membership.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="Only admins can edit group details")

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    if data.name:
        group.name = data.name
    if data.description is not None:
        group.description = data.description
    if data.avatar_url is not None:
        try:
            group.avatar_url = data.avatar_url
        except AttributeError:
            pass  # column not yet migrated

    db.commit()
    db.refresh(group)
    return {"message": "Group updated", "id": group.id, "name": group.name}


# ── Update member role (owner only) ─────────────────────────

@router.put("/{group_id}/members/{target_user_id}/role")
def update_member_role(
    group_id: int,
    target_user_id: int,
    data: RoleUpdate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    my_membership = db.query(GroupMember).filter_by(user_id=user.id, group_id=group_id).first()
    if not my_membership or my_membership.role != "owner":
        raise HTTPException(status_code=403, detail="Only the group owner can change roles")

    if data.role not in ("admin", "member"):
        raise HTTPException(status_code=400, detail="Role must be 'admin' or 'member'")

    target = db.query(GroupMember).filter_by(user_id=target_user_id, group_id=group_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Member not found")

    if target.role == "owner":
        raise HTTPException(status_code=400, detail="Cannot change owner's role")

    target.role = data.role
    db.commit()
    return {"message": f"Role updated to {data.role}"}


# ── Leave group ──────────────────────────────────────────────

@router.delete("/{group_id}/leave")
def leave_group(
    group_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    membership = db.query(GroupMember).filter_by(user_id=user.id, group_id=group_id).first()
    if not membership:
        raise HTTPException(status_code=404, detail="Not a member of this group")

    if membership.role == "owner":
        other_admins = db.query(GroupMember).filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id != user.id,
            GroupMember.role.in_(["owner", "admin"]),
        ).count()
        if other_admins == 0:
            raise HTTPException(
                status_code=400,
                detail="Transfer ownership before leaving, or delete the group",
            )

    db.delete(membership)
    db.commit()
    return {"message": "Left group successfully"}

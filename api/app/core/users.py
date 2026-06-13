import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def get_or_create_user(db: AsyncSession, supabase_id: str, email: str | None) -> User:
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()
    if not user:
        user = User(id=uuid.uuid4(), supabase_id=supabase_id, email=email or "")
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user

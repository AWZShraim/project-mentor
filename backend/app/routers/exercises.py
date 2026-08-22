from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.db import get_db

router = APIRouter(tags=["exercises"])


@router.get("/exercises", response_model=list[schemas.ExerciseOut])
def list_exercises(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Exercise)
        .filter(
            or_(
                models.Exercise.user_id.is_(None),
                models.Exercise.user_id == current_user.id,
            )
        )
        .order_by(models.Exercise.name)
        .all()
    )


@router.post("/exercises", response_model=schemas.ExerciseOut)
def create_exercise(
    payload: schemas.ExerciseCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    exercise = models.Exercise(user_id=current_user.id, **payload.model_dump())
    db.add(exercise)
    db.commit()
    db.refresh(exercise)
    return exercise

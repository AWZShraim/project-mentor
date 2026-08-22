import uuid
from datetime import date as date_type
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.db import get_db

router = APIRouter(tags=["workouts"])


@router.get("/workout-templates", response_model=list[schemas.WorkoutTemplateOut])
def list_workout_templates(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    templates = (
        db.query(models.WorkoutTemplate)
        .filter(models.WorkoutTemplate.user_id == current_user.id)
        .all()
    )
    return [
        {
            "id": t.id,
            "name": t.name,
            "exercises": [wte.exercise for wte in t.exercises],
            "created_at": t.created_at,
        }
        for t in templates
    ]


@router.post("/workout-templates", response_model=schemas.WorkoutTemplateOut)
def create_workout_template(
    payload: schemas.WorkoutTemplateCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    exercises = (
        db.query(models.Exercise)
        .filter(
            models.Exercise.id.in_(payload.exercise_ids),
            or_(
                models.Exercise.user_id.is_(None),
                models.Exercise.user_id == current_user.id,
            ),
        )
        .all()
    )
    exercises_by_id = {e.id: e for e in exercises}
    if len(exercises_by_id) != len(set(payload.exercise_ids)):
        raise HTTPException(status_code=404, detail="One or more exercises not found")

    template = models.WorkoutTemplate(user_id=current_user.id, name=payload.name)
    db.add(template)
    db.flush()

    for i, exercise_id in enumerate(payload.exercise_ids):
        db.add(
            models.WorkoutTemplateExercise(
                template_id=template.id, exercise_id=exercise_id, position=i
            )
        )
    db.commit()
    db.refresh(template)

    return {
        "id": template.id,
        "name": template.name,
        "exercises": [exercises_by_id[eid] for eid in payload.exercise_ids],
        "created_at": template.created_at,
    }


@router.delete("/workout-templates/{template_id}", status_code=204)
def delete_workout_template(
    template_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    template = db.get(models.WorkoutTemplate, template_id)
    if template is None or template.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Template not found")
    db.delete(template)
    db.commit()


@router.get("/workout-logs", response_model=list[schemas.WorkoutLogOut])
def list_workout_logs(
    date: date_type,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = datetime.combine(date, datetime.min.time())
    end = datetime.combine(date, datetime.max.time())
    return (
        db.query(models.WorkoutLogEntry)
        .filter(
            models.WorkoutLogEntry.user_id == current_user.id,
            models.WorkoutLogEntry.logged_at >= start,
            models.WorkoutLogEntry.logged_at <= end,
        )
        .all()
    )


@router.post("/workout-logs", response_model=schemas.WorkoutLogOut)
def create_workout_log(
    payload: schemas.WorkoutLogCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    exercise = db.get(models.Exercise, payload.exercise_id)
    if exercise is None or (
        exercise.user_id is not None and exercise.user_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Exercise not found")

    entry = models.WorkoutLogEntry(
        user_id=current_user.id,
        exercise_id=payload.exercise_id,
        logged_at=payload.logged_at,
        notes=payload.notes,
    )
    db.add(entry)
    db.flush()

    for s in payload.sets:
        db.add(models.WorkoutSet(workout_log_entry_id=entry.id, **s.model_dump()))

    db.commit()
    db.refresh(entry)
    return entry


@router.patch("/workout-logs/{log_id}", response_model=schemas.WorkoutLogOut)
def update_workout_log(
    log_id: uuid.UUID,
    payload: schemas.WorkoutLogUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = db.get(models.WorkoutLogEntry, log_id)
    if entry is None or entry.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Workout log not found")

    db.query(models.WorkoutSet).filter(
        models.WorkoutSet.workout_log_entry_id == entry.id
    ).delete()

    for s in payload.sets:
        db.add(models.WorkoutSet(workout_log_entry_id=entry.id, **s.model_dump()))

    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/workout-logs/{log_id}", status_code=204)
def delete_workout_log(
    log_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = db.get(models.WorkoutLogEntry, log_id)
    if entry is None or entry.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Workout log not found")
    db.delete(entry)
    db.commit()

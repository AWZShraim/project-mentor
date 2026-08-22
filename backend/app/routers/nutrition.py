import uuid
from datetime import date as date_type
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.db import get_db

router = APIRouter(tags=["nutrition"])


@router.get("/food-items/recent", response_model=list[schemas.FoodItemOut])
def list_recent_food_items(
    limit: int = 10,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    last_logged = (
        db.query(
            models.NutritionLog.food_item_id,
            func.max(models.NutritionLog.logged_at).label("last_logged_at"),
        )
        .filter(models.NutritionLog.user_id == current_user.id)
        .group_by(models.NutritionLog.food_item_id)
        .subquery()
    )
    return (
        db.query(models.PersonalFoodLibraryItem)
        .join(last_logged, models.PersonalFoodLibraryItem.id == last_logged.c.food_item_id)
        .order_by(last_logged.c.last_logged_at.desc())
        .limit(limit)
        .all()
    )


@router.get("/food-items", response_model=list[schemas.FoodItemOut])
def list_food_items(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.PersonalFoodLibraryItem)
        .filter(models.PersonalFoodLibraryItem.user_id == current_user.id)
        .order_by(models.PersonalFoodLibraryItem.name)
        .all()
    )


@router.post("/food-items", response_model=schemas.FoodItemOut)
def create_food_item(
    payload: schemas.FoodItemCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = models.PersonalFoodLibraryItem(
        user_id=current_user.id, **payload.model_dump()
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/nutrition-logs", response_model=list[schemas.NutritionLogOut])
def list_nutrition_logs(
    date: date_type,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = datetime.combine(date, datetime.min.time())
    end = datetime.combine(date, datetime.max.time())
    return (
        db.query(models.NutritionLog)
        .filter(
            models.NutritionLog.user_id == current_user.id,
            models.NutritionLog.logged_at >= start,
            models.NutritionLog.logged_at <= end,
        )
        .all()
    )


@router.post("/nutrition-logs", response_model=schemas.NutritionLogOut)
def create_nutrition_log(
    payload: schemas.NutritionLogCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    food_item = db.get(models.PersonalFoodLibraryItem, payload.food_item_id)
    if food_item is None or food_item.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Food item not found")

    log = models.NutritionLog(user_id=current_user.id, **payload.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.patch("/nutrition-logs/{log_id}", response_model=schemas.NutritionLogOut)
def update_nutrition_log(
    log_id: uuid.UUID,
    payload: schemas.NutritionLogUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = db.get(models.NutritionLog, log_id)
    if entry is None or entry.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Nutrition log not found")

    entry.quantity = payload.quantity
    entry.quantity_unit = payload.quantity_unit
    entry.meal_type = payload.meal_type

    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/nutrition-logs/{log_id}", status_code=204)
def delete_nutrition_log(
    log_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = db.get(models.NutritionLog, log_id)
    if entry is None or entry.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Nutrition log not found")
    db.delete(entry)
    db.commit()

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.db import get_db

router = APIRouter(tags=["nutrition"])


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

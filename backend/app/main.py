from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.auth import get_current_user
from app.db import get_db

app = FastAPI(title="Mentor API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/me", response_model=schemas.UserOut)
def read_me(current_user: models.User = Depends(get_current_user)):
    return current_user


@app.post("/food-items", response_model=schemas.FoodItemOut)
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


@app.post("/nutrition-logs", response_model=schemas.NutritionLogOut)
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

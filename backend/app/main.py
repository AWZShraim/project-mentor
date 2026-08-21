import uuid

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.db import get_db

app = FastAPI(title="Mentor API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/users", response_model=schemas.UserOut)
def create_user(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    user = models.User(email=payload.email)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.get("/users", response_model=list[schemas.UserOut])
def list_users(db: Session = Depends(get_db)):
    return db.query(models.User).all()


@app.post(
    "/users/{user_id}/food-items",
    response_model=schemas.FoodItemOut,
)
def create_food_item(
    user_id: uuid.UUID, payload: schemas.FoodItemCreate, db: Session = Depends(get_db)
):
    if not db.get(models.User, user_id):
        raise HTTPException(status_code=404, detail="User not found")

    item = models.PersonalFoodLibraryItem(user_id=user_id, **payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@app.post(
    "/users/{user_id}/nutrition-logs",
    response_model=schemas.NutritionLogOut,
)
def create_nutrition_log(
    user_id: uuid.UUID,
    payload: schemas.NutritionLogCreate,
    db: Session = Depends(get_db),
):
    if not db.get(models.User, user_id):
        raise HTTPException(status_code=404, detail="User not found")
    if not db.get(models.PersonalFoodLibraryItem, payload.food_item_id):
        raise HTTPException(status_code=404, detail="Food item not found")

    log = models.NutritionLog(user_id=user_id, **payload.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log

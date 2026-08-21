import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserCreate(BaseModel):
    email: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    created_at: datetime


class FoodItemCreate(BaseModel):
    name: str
    brand: str | None = None
    source_type: str
    external_id: str | None = None
    serving_size: float
    serving_unit: str
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float | None = None
    sugar_g: float | None = None
    sodium_mg: float | None = None


class FoodItemOut(FoodItemCreate):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    created_at: datetime


class NutritionLogCreate(BaseModel):
    food_item_id: uuid.UUID
    quantity: float
    quantity_unit: str
    meal_type: str | None = None
    logged_at: datetime


class NutritionLogOut(NutritionLogCreate):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    created_at: datetime

import uuid
from datetime import datetime
from typing import Any

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


class NutritionLogUpdate(BaseModel):
    quantity: float
    quantity_unit: str
    meal_type: str | None = None


class NutritionLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    food_item: FoodItemOut
    quantity: float
    quantity_unit: str
    meal_type: str | None
    logged_at: datetime
    created_at: datetime


class ExerciseCreate(BaseModel):
    name: str
    category: str | None = None
    muscle_groups: list[str] | None = None
    equipment: str | None = None
    movement_pattern: str | None = None
    logging_type: str | None = None


class ExerciseOut(ExerciseCreate):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID | None
    created_at: datetime


class WorkoutTemplateCreate(BaseModel):
    name: str
    exercise_ids: list[uuid.UUID]


class WorkoutTemplateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    exercises: list[ExerciseOut]
    created_at: datetime


class WorkoutSetIn(BaseModel):
    set_number: int
    reps: int | None = None
    weight: float | None = None
    weight_unit: str | None = None
    duration_seconds: int | None = None
    distance: float | None = None
    distance_unit: str | None = None


class WorkoutSetOut(WorkoutSetIn):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID


class WorkoutLogCreate(BaseModel):
    exercise_id: uuid.UUID
    logged_at: datetime
    notes: str | None = None
    sets: list[WorkoutSetIn]


class WorkoutLogUpdate(BaseModel):
    sets: list[WorkoutSetIn]


class WorkoutLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    exercise: ExerciseOut
    logged_at: datetime
    notes: str | None
    sets: list[WorkoutSetOut]
    created_at: datetime


class GoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    goal_type: str
    value: dict[str, Any]
    status: str
    reasoning: str | None
    created_by: str
    effective_at: datetime | None
    created_at: datetime


class CoachCheckInResult(BaseModel):
    proposal: GoalOut | None
    message: str


class HealthMetricCreate(BaseModel):
    metric_type: str
    value: float
    unit: str
    recorded_at: datetime


class HealthMetricOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    metric_type: str
    value: float
    unit: str
    recorded_at: datetime
    source: str


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    role: str
    content: str
    created_at: datetime


class ChatRequest(BaseModel):
    message: str


class AgentActionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    action_type: str
    payload: dict[str, Any]
    summary: str
    reasoning: str | None
    status: str
    created_at: datetime
    executed_at: datetime | None


class ChatResponse(BaseModel):
    reply: str
    proposed_goal: GoalOut | None = None
    proposed_action: AgentActionOut | None = None


class DashboardOut(BaseModel):
    today_calories: float
    today_protein_g: float
    today_carbs_g: float
    today_fat_g: float
    active_goal: GoalOut | None
    latest_weight: HealthMetricOut | None
    weight_change_7d: float | None
    sleep_hours_last_night: float | None
    insight_text: str | None
    insight_generated_at: datetime | None

import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db import Base


def _uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = _uuid_pk()
    cognito_sub: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class PersonalFoodLibraryItem(Base):
    """A user's own food item — sourced from barcode/search lookup, manual
    entry, screenshot OCR, or natural-language description. Never AI-invented:
    every numeric value here traces back to something the user supplied or an
    external catalog lookup, per the grounding rule in the functional spec.
    """

    __tablename__ = "personal_food_library"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    brand: Mapped[str | None] = mapped_column(String)
    source_type: Mapped[str] = mapped_column(String, nullable=False)
    # one of: barcode, manual, search, screenshot, natural_language
    external_id: Mapped[str | None] = mapped_column(String)
    # barcode or external catalog provider ID, if applicable

    serving_size: Mapped[float] = mapped_column(Numeric, nullable=False)
    serving_unit: Mapped[str] = mapped_column(String, nullable=False)
    calories: Mapped[float] = mapped_column(Numeric, nullable=False)
    protein_g: Mapped[float] = mapped_column(Numeric, nullable=False)
    carbs_g: Mapped[float] = mapped_column(Numeric, nullable=False)
    fat_g: Mapped[float] = mapped_column(Numeric, nullable=False)
    fiber_g: Mapped[float | None] = mapped_column(Numeric)
    sugar_g: Mapped[float | None] = mapped_column(Numeric)
    sodium_mg: Mapped[float | None] = mapped_column(Numeric)

    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class NutritionLog(Base):
    __tablename__ = "nutrition_logs"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    food_item_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("personal_food_library.id"), nullable=False
    )
    quantity: Mapped[float] = mapped_column(Numeric, nullable=False)
    quantity_unit: Mapped[str] = mapped_column(String, nullable=False)
    meal_type: Mapped[str | None] = mapped_column(String)
    # breakfast, lunch, dinner, snack
    logged_at: Mapped[datetime] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    food_item: Mapped["PersonalFoodLibraryItem"] = relationship()


class Exercise(Base):
    """Shared base library when user_id is NULL; a personal, AI-defined
    exercise (from natural-language logging with no base-library match)
    when user_id is set.
    """

    __tablename__ = "exercises"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str | None] = mapped_column(String)
    # strength, cardio, mobility, plyometric
    muscle_groups: Mapped[list[str] | None] = mapped_column(ARRAY(String))
    equipment: Mapped[str | None] = mapped_column(String)
    movement_pattern: Mapped[str | None] = mapped_column(String)
    # push, pull, squat, hinge, lunge, carry, rotation, isometric
    logging_type: Mapped[str | None] = mapped_column(String)
    # reps_weight, reps_only, duration, distance - which input fields the
    # logging UI should show for this exercise
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class WorkoutTemplate(Base):
    """A user's named, reusable split (e.g. "Push Day") - just an ordered
    list of exercises. No prescribed sets/reps/weight targets for now;
    those get logged fresh each time via WorkoutLogEntry/WorkoutSet.
    """

    __tablename__ = "workout_templates"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    exercises: Mapped[list["WorkoutTemplateExercise"]] = relationship(
        back_populates="template",
        cascade="all, delete-orphan",
        order_by="WorkoutTemplateExercise.position",
    )


class WorkoutTemplateExercise(Base):
    __tablename__ = "workout_template_exercises"

    id: Mapped[uuid.UUID] = _uuid_pk()
    template_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workout_templates.id"), nullable=False
    )
    exercise_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exercises.id"), nullable=False
    )
    position: Mapped[int] = mapped_column(nullable=False)

    template: Mapped["WorkoutTemplate"] = relationship(back_populates="exercises")
    exercise: Mapped["Exercise"] = relationship()


class WorkoutLogEntry(Base):
    __tablename__ = "workout_log_entries"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    exercise_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exercises.id"), nullable=False
    )
    logged_at: Mapped[datetime] = mapped_column(nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    exercise: Mapped["Exercise"] = relationship()
    sets: Mapped[list["WorkoutSet"]] = relationship(
        back_populates="workout_log_entry", cascade="all, delete-orphan"
    )


class WorkoutSet(Base):
    __tablename__ = "workout_sets"

    id: Mapped[uuid.UUID] = _uuid_pk()
    workout_log_entry_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workout_log_entries.id"), nullable=False
    )
    set_number: Mapped[int] = mapped_column(nullable=False)
    reps: Mapped[int | None]
    weight: Mapped[float | None] = mapped_column(Numeric)
    weight_unit: Mapped[str | None] = mapped_column(String)
    duration_seconds: Mapped[int | None]
    distance: Mapped[float | None] = mapped_column(Numeric)
    distance_unit: Mapped[str | None] = mapped_column(String)

    workout_log_entry: Mapped["WorkoutLogEntry"] = relationship(back_populates="sets")


class HealthMetric(Base):
    """Passive data pulled from HealthKit — steps, heart rate, weight,
    sleep — feeding the coach context without manual entry.
    """

    __tablename__ = "health_metrics"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    metric_type: Mapped[str] = mapped_column(String, nullable=False)
    # steps, heart_rate, weight, sleep_hours, ...
    value: Mapped[float] = mapped_column(Numeric, nullable=False)
    unit: Mapped[str] = mapped_column(String, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(nullable=False)
    source: Mapped[str] = mapped_column(String, nullable=False, default="healthkit")
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class Goal(Base):
    """A calorie target / macro split / workout plan. The autonomous coach
    writes proposals here with status='proposed' and a reasoning trail;
    nothing takes effect until the user approves it, per the functional
    spec's human-in-the-loop requirement.
    """

    __tablename__ = "goals"

    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    goal_type: Mapped[str] = mapped_column(String, nullable=False)
    # calorie_target, macro_split, workout_plan
    value: Mapped[dict] = mapped_column(JSONB, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="proposed")
    # proposed, approved, rejected, active, superseded
    reasoning: Mapped[str | None] = mapped_column(Text)
    created_by: Mapped[str] = mapped_column(String, nullable=False)
    # user, ai
    effective_at: Mapped[datetime | None]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

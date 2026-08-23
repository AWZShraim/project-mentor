from fastapi import Depends, FastAPI

from app import models, schemas
from app.auth import get_current_user
from app.routers import coach, exercises, nutrition, workouts

app = FastAPI(title="Mentor API")

app.include_router(nutrition.router)
app.include_router(exercises.router)
app.include_router(workouts.router)
app.include_router(coach.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/me", response_model=schemas.UserOut)
def read_me(current_user: models.User = Depends(get_current_user)):
    return current_user

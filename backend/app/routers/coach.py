import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import coach, models, schemas
from app.auth import get_current_user
from app.db import get_db

router = APIRouter(tags=["coach"])


def _require_configured() -> None:
    if not coach.settings.anthropic_api_key:
        raise HTTPException(status_code=503, detail="Mentor is not configured yet")


@router.post("/coach/check-in", response_model=schemas.CoachCheckInResult)
def check_in(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_configured()
    goal, message, _run = coach.run_check_in(db, current_user)
    return schemas.CoachCheckInResult(proposal=goal, message=message)


@router.get("/goals", response_model=list[schemas.GoalOut])
def list_goals(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Goal)
        .filter(models.Goal.user_id == current_user.id)
        .order_by(models.Goal.created_at.desc())
        .all()
    )


@router.post("/goals/{goal_id}/approve", response_model=schemas.GoalOut)
def approve_goal(
    goal_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    goal = db.get(models.Goal, goal_id)
    if goal is None or goal.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Goal not found")
    if goal.status != "proposed":
        raise HTTPException(status_code=409, detail="Goal is not pending approval")

    db.query(models.Goal).filter(
        models.Goal.user_id == current_user.id,
        models.Goal.goal_type == goal.goal_type,
        models.Goal.status == "active",
    ).update({"status": "superseded"})

    goal.status = "active"
    goal.effective_at = datetime.utcnow()
    db.commit()
    db.refresh(goal)
    return goal


@router.post("/goals/{goal_id}/reject", response_model=schemas.GoalOut)
def reject_goal(
    goal_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    goal = db.get(models.Goal, goal_id)
    if goal is None or goal.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Goal not found")
    if goal.status != "proposed":
        raise HTTPException(status_code=409, detail="Goal is not pending approval")

    goal.status = "rejected"
    db.commit()
    db.refresh(goal)
    return goal


@router.post("/health-metrics", response_model=schemas.HealthMetricOut)
def create_health_metric(
    payload: schemas.HealthMetricCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    metric = models.HealthMetric(user_id=current_user.id, source="manual", **payload.model_dump())
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return metric


@router.get("/mentor/dashboard", response_model=schemas.DashboardOut)
def mentor_dashboard(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return schemas.DashboardOut(**coach.get_dashboard(db, current_user))


@router.get("/mentor/messages", response_model=list[schemas.ChatMessageOut])
def list_messages(
    limit: int = 50,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    messages = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.user_id == current_user.id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    return list(reversed(messages))


@router.post("/mentor/chat", response_model=schemas.ChatResponse)
def chat(
    payload: schemas.ChatRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_configured()
    result = coach.handle_chat(db, current_user, payload.message)
    return schemas.ChatResponse(**result)


@router.get("/mentor/actions", response_model=list[schemas.AgentActionOut])
def list_actions(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.AgentAction)
        .filter(models.AgentAction.user_id == current_user.id)
        .order_by(models.AgentAction.created_at.desc())
        .all()
    )


@router.post("/mentor/actions/{action_id}/approve", response_model=schemas.AgentActionOut)
def approve_action(
    action_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    action = db.get(models.AgentAction, action_id)
    if action is None or action.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Action not found")
    if action.status != "proposed":
        raise HTTPException(status_code=409, detail="Action is not pending approval")

    if action.action_type == "log_nutrition_entry":
        now = datetime.utcnow()
        for entry in action.payload["entries"]:
            try:
                food_item_id = uuid.UUID(entry["food_item_id"])
            except (KeyError, ValueError):
                action.status = "failed"
                db.commit()
                raise HTTPException(status_code=422, detail="Action payload is malformed") from None

            food_item = db.get(models.PersonalFoodLibraryItem, food_item_id)
            if food_item is None or food_item.user_id != current_user.id:
                action.status = "failed"
                db.commit()
                raise HTTPException(status_code=422, detail="A referenced food item no longer exists")
            db.add(
                models.NutritionLog(
                    user_id=current_user.id,
                    food_item_id=food_item.id,
                    quantity=entry["quantity"],
                    quantity_unit=entry["quantity_unit"],
                    meal_type=entry.get("meal_type"),
                    logged_at=now,
                )
            )
    else:
        raise HTTPException(status_code=422, detail=f"Unknown action type {action.action_type!r}")

    action.status = "executed"
    action.executed_at = datetime.utcnow()
    db.commit()
    db.refresh(action)
    return action


@router.post("/mentor/actions/{action_id}/reject", response_model=schemas.AgentActionOut)
def reject_action(
    action_id: uuid.UUID,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    action = db.get(models.AgentAction, action_id)
    if action is None or action.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Action not found")
    if action.status != "proposed":
        raise HTTPException(status_code=409, detail="Action is not pending approval")

    action.status = "rejected"
    db.commit()
    db.refresh(action)
    return action

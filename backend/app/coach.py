"""AI orchestration for the Mentor tab: chat, dashboard insights, and
nutrition target proposals. Every AI-initiated change to the user's data
goes through a propose-then-approve step - `Goal` for standing targets,
`AgentAction` for one-off actions like logging a food entry - and the
model never gets the last word on a number that could be unsafe; hard
guardrails run in code after every proposal.

v1 scope: nutrition only (calorie/macro targets, food logging). Workout
programming is a separate, more complex kind of proposal and is out of
scope here. HealthKit isn't connected yet, so sleep is always reported as
unavailable.
"""

import json
from datetime import datetime, timedelta

import anthropic
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.config import settings

CONTEXT_WINDOW_DAYS = 14
CHAT_CONTEXT_WINDOW_DAYS = 7
CHAT_HISTORY_LIMIT = 20

# Safety guardrails. These are deliberately conservative, general-purpose
# heuristics (not personalized medical advice) enforced in code - the model
# never gets the last word on a number that could be unsafe.
CALORIE_FLOOR = 1200
CALORIE_CEILING = 6000
MAX_DAILY_CALORIE_SWING = 500
# max change from the prior baseline (active goal, or recent average intake
# if there is none yet) that a single proposal is allowed to make
MIN_PROTEIN_CALORIE_SHARE = 0.10
MACRO_CALORIE_TOLERANCE = 0.15
# protein*4 + carbs*4 + fat*9 must land within this fraction of the
# proposed daily_calories

_CHECK_IN_TOOL = {
    "name": "submit_nutrition_assessment",
    "description": (
        "Report your assessment of the user's nutrition based on the "
        "provided context."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "should_change": {
                "type": "boolean",
                "description": "Whether you are proposing a new target, vs. the current one is fine.",
            },
            "daily_calories": {"type": "integer"},
            "protein_g": {"type": "integer"},
            "carbs_g": {"type": "integer"},
            "fat_g": {"type": "integer"},
            "reasoning": {
                "type": "string",
                "description": "Plain-language explanation the user will read directly.",
            },
        },
        "required": [
            "should_change",
            "daily_calories",
            "protein_g",
            "carbs_g",
            "fat_g",
            "reasoning",
        ],
    },
}

_GOAL_PROPOSE_TOOL = {
    "name": "propose_nutrition_target",
    "description": (
        "Propose a new daily calorie/macro target. Only call this when the "
        "user is asking about, or would clearly benefit from, changing "
        "their nutrition target - not for general questions."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "daily_calories": {"type": "integer"},
            "protein_g": {"type": "integer"},
            "carbs_g": {"type": "integer"},
            "fat_g": {"type": "integer"},
            "reasoning": {
                "type": "string",
                "description": "Plain-language explanation the user will read directly.",
            },
        },
        "required": ["daily_calories", "protein_g", "carbs_g", "fat_g", "reasoning"],
    },
}

_LOG_ENTRY_TOOL = {
    "name": "propose_nutrition_log",
    "description": (
        "Propose logging one or more food entries on the user's behalf "
        "(e.g. 'log the same breakfast as yesterday'). Resolve each entry "
        "to a food_item_id from recent_nutrition_entries or food_library in "
        "the context - never invent one. Only call this when the user is "
        "asking you to log something, not just asking a question."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "entries": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "food_item_id": {"type": "string"},
                        "quantity": {"type": "number"},
                        "quantity_unit": {"type": "string"},
                        "meal_type": {
                            "type": "string",
                            "enum": ["breakfast", "lunch", "dinner", "snack"],
                        },
                    },
                    "required": ["food_item_id", "quantity", "quantity_unit", "meal_type"],
                },
            },
            "summary": {
                "type": "string",
                "description": "One sentence describing what will be logged, shown to the user for approval.",
            },
            "reasoning": {"type": "string"},
        },
        "required": ["entries", "summary", "reasoning"],
    },
}

_INSIGHT_TOOL = {
    "name": "submit_insight",
    "description": (
        "Report whether the dashboard headline insight needs to change and, "
        "if so, what it should say."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "should_update": {"type": "boolean"},
            "insight_text": {
                "type": "string",
                "description": "One short sentence, plain language - e.g. 'Everything looks good today' or 'New low weight - great work'.",
            },
        },
        "required": ["should_update", "insight_text"],
    },
}


def _client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=settings.anthropic_api_key)


def _food_totals(entries: list[models.NutritionLog]) -> dict[str, float]:
    totals = {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}
    for entry in entries:
        scale = float(entry.quantity) / float(entry.food_item.serving_size)
        totals["calories"] += float(entry.food_item.calories) * scale
        totals["protein_g"] += float(entry.food_item.protein_g) * scale
        totals["carbs_g"] += float(entry.food_item.carbs_g) * scale
        totals["fat_g"] += float(entry.food_item.fat_g) * scale
    return totals


def _day_totals(db: Session, user: models.User, day) -> dict[str, float]:
    start = datetime.combine(day, datetime.min.time())
    end = datetime.combine(day, datetime.max.time())
    logs = (
        db.query(models.NutritionLog)
        .filter(
            models.NutritionLog.user_id == user.id,
            models.NutritionLog.logged_at >= start,
            models.NutritionLog.logged_at <= end,
        )
        .all()
    )
    return {k: round(v, 1) for k, v in _food_totals(logs).items()}


def _weight_stats(db: Session, user: models.User) -> dict:
    metrics = (
        db.query(models.HealthMetric)
        .filter(
            models.HealthMetric.user_id == user.id,
            models.HealthMetric.metric_type == "weight",
        )
        .order_by(models.HealthMetric.recorded_at.asc())
        .all()
    )
    if not metrics:
        return {"latest": None, "change_7d": None, "is_all_time_low": False, "is_all_time_high": False}

    latest = metrics[-1]
    values = [float(m.value) for m in metrics]
    is_low = float(latest.value) <= min(values)
    is_high = float(latest.value) >= max(values)

    cutoff = latest.recorded_at - timedelta(days=7)
    prior = [m for m in metrics if m.recorded_at <= cutoff]
    change_7d = float(latest.value) - float(prior[-1].value) if prior else None

    return {
        "latest": {
            "value": float(latest.value),
            "unit": latest.unit,
            "recorded_at": latest.recorded_at.isoformat(),
        },
        "change_7d": round(change_7d, 1) if change_7d is not None else None,
        "is_all_time_low": is_low,
        "is_all_time_high": is_high,
    }


def gather_context(db: Session, user: models.User) -> dict:
    """Context for the standalone check-in / nutrition-target analysis."""
    window_start = datetime.utcnow() - timedelta(days=CONTEXT_WINDOW_DAYS)

    logs = (
        db.query(models.NutritionLog)
        .filter(
            models.NutritionLog.user_id == user.id,
            models.NutritionLog.logged_at >= window_start,
        )
        .all()
    )
    by_day: dict[str, list[models.NutritionLog]] = {}
    for entry in logs:
        day = entry.logged_at.date().isoformat()
        by_day.setdefault(day, []).append(entry)

    daily_totals = [
        {"date": day, **{k: round(v, 1) for k, v in _food_totals(entries).items()}}
        for day, entries in sorted(by_day.items())
    ]
    days_logged = len(daily_totals)
    averages = {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}
    if days_logged:
        for key in averages:
            averages[key] = round(sum(d[key] for d in daily_totals) / days_logged, 1)

    active_goals = (
        db.query(models.Goal)
        .filter(models.Goal.user_id == user.id, models.Goal.status == "active")
        .order_by(models.Goal.effective_at.desc())
        .all()
    )

    workout_count = (
        db.query(func.count(models.WorkoutLogEntry.id))
        .filter(
            models.WorkoutLogEntry.user_id == user.id,
            models.WorkoutLogEntry.logged_at >= window_start,
        )
        .scalar()
    )

    return {
        "window_days": CONTEXT_WINDOW_DAYS,
        "days_logged": days_logged,
        "daily_totals": daily_totals,
        "averages": averages,
        "active_goals": [
            {
                "goal_type": g.goal_type,
                "value": g.value,
                "effective_at": g.effective_at.isoformat() if g.effective_at else None,
            }
            for g in active_goals
        ],
        "workout_sessions_in_window": workout_count,
    }


def gather_chat_context(db: Session, user: models.User) -> dict:
    window_start = datetime.utcnow() - timedelta(days=CHAT_CONTEXT_WINDOW_DAYS)

    logs = (
        db.query(models.NutritionLog)
        .filter(
            models.NutritionLog.user_id == user.id,
            models.NutritionLog.logged_at >= window_start,
        )
        .order_by(models.NutritionLog.logged_at.asc())
        .all()
    )
    entries = [
        {
            "date": e.logged_at.date().isoformat(),
            "meal_type": e.meal_type,
            "food_item_id": str(e.food_item_id),
            "food_name": e.food_item.name,
            "quantity": float(e.quantity),
            "quantity_unit": e.quantity_unit,
        }
        for e in logs
    ]

    recent_foods = (
        db.query(models.PersonalFoodLibraryItem)
        .filter(models.PersonalFoodLibraryItem.user_id == user.id)
        .order_by(models.PersonalFoodLibraryItem.created_at.desc())
        .limit(30)
        .all()
    )
    food_library = [
        {
            "food_item_id": str(f.id),
            "name": f.name,
            "serving_size": float(f.serving_size),
            "serving_unit": f.serving_unit,
            "calories": float(f.calories),
        }
        for f in recent_foods
    ]

    active_goals = (
        db.query(models.Goal)
        .filter(models.Goal.user_id == user.id, models.Goal.status == "active")
        .all()
    )

    return {
        "today": datetime.utcnow().date().isoformat(),
        "recent_nutrition_entries": entries,
        "food_library": food_library,
        "weight": _weight_stats(db, user),
        "active_goals": [{"goal_type": g.goal_type, "value": g.value} for g in active_goals],
    }


def gather_dashboard_context(db: Session, user: models.User) -> dict:
    today = datetime.utcnow().date()
    active_goal = (
        db.query(models.Goal)
        .filter(
            models.Goal.user_id == user.id,
            models.Goal.status == "active",
            models.Goal.goal_type == "calorie_target",
        )
        .order_by(models.Goal.effective_at.desc())
        .first()
    )
    workout_today = (
        db.query(func.count(models.WorkoutLogEntry.id))
        .filter(
            models.WorkoutLogEntry.user_id == user.id,
            models.WorkoutLogEntry.logged_at >= datetime.combine(today, datetime.min.time()),
        )
        .scalar()
    )
    return {
        "today_totals": _day_totals(db, user, today),
        "active_calorie_goal": active_goal.value if active_goal else None,
        "weight": _weight_stats(db, user),
        "sleep_hours_last_night": None,  # HealthKit not connected yet
        "workout_sessions_today": workout_today,
    }


def _baseline_calories(context: dict) -> float | None:
    for goal in context["active_goals"]:
        if goal["goal_type"] == "calorie_target" and "daily_calories" in goal["value"]:
            return float(goal["value"]["daily_calories"])
    if context["days_logged"]:
        return context["averages"]["calories"]
    return None


def _apply_guardrails(proposal: dict, context: dict) -> tuple[dict | None, str | None]:
    """Returns (clamped_proposal_or_None, notes). A None proposal means the
    model's output couldn't be made safe and no goal should be created.

    Internal-consistency checks (floor/ceiling, macro reconciliation,
    protein minimum) run first, against the model's own numbers. Only then
    is the swing-from-baseline clamp applied - and when it kicks in, macros
    are rescaled proportionally along with calories, so the clamped result
    stays internally consistent instead of comparing stale macros against a
    new calorie number.
    """
    calories = proposal["daily_calories"]
    if calories < CALORIE_FLOOR or calories > CALORIE_CEILING:
        return None, (
            f"Rejected: proposed {calories} kcal/day is outside the safe "
            f"range [{CALORIE_FLOOR}, {CALORIE_CEILING}]."
        )

    protein_g, carbs_g, fat_g = (
        proposal["protein_g"],
        proposal["carbs_g"],
        proposal["fat_g"],
    )
    macro_calories = protein_g * 4 + carbs_g * 4 + fat_g * 9
    if macro_calories == 0 or abs(macro_calories - calories) / calories > MACRO_CALORIE_TOLERANCE:
        return None, (
            f"Rejected: macro breakdown ({protein_g}P/{carbs_g}C/{fat_g}F = "
            f"{macro_calories} kcal) doesn't reconcile with the {int(calories)} "
            f"kcal target."
        )

    if (protein_g * 4) / calories < MIN_PROTEIN_CALORIE_SHARE:
        return None, (
            f"Rejected: protein ({protein_g}g) is below the minimum "
            f"{int(MIN_PROTEIN_CALORIE_SHARE * 100)}% of calories."
        )

    notes: list[str] = []
    baseline = _baseline_calories(context)
    if baseline is not None:
        low = max(CALORIE_FLOOR, baseline - MAX_DAILY_CALORIE_SWING)
        high = min(CALORIE_CEILING, baseline + MAX_DAILY_CALORIE_SWING)
        if calories < low or calories > high:
            clamped = max(low, min(high, calories))
            scale = clamped / calories
            protein_g, carbs_g, fat_g = protein_g * scale, carbs_g * scale, fat_g * scale
            notes.append(
                f"Clamped daily_calories from {calories} to {int(clamped)} "
                f"(max swing of {MAX_DAILY_CALORIE_SWING} kcal from baseline "
                f"{int(baseline)}); macros scaled proportionally."
            )
            calories = clamped

    return {
        "daily_calories": int(calories),
        "protein_g": int(protein_g),
        "carbs_g": int(carbs_g),
        "fat_g": int(fat_g),
    }, ("; ".join(notes) if notes else None)


def _propose_nutrition_goal(
    db: Session, user: models.User, context: dict, proposal: dict
) -> tuple[models.Goal | None, str | None]:
    clamped, notes = _apply_guardrails(proposal, context)
    if clamped is None:
        return None, notes
    goal = models.Goal(
        user_id=user.id,
        goal_type="calorie_target",
        value=clamped,
        status="proposed",
        reasoning=proposal.get("reasoning"),
        created_by="ai",
    )
    db.add(goal)
    db.flush()
    return goal, notes


def run_check_in(db: Session, user: models.User) -> tuple[models.Goal | None, str, models.CoachRun]:
    """Runs one on-demand nutrition check-in. Returns (goal_or_None, message, run)."""
    context = gather_context(db, user)

    system_prompt = (
        "You are a nutrition coach reviewing a user's recent food logging "
        "data to decide whether their daily calorie and macro targets need "
        "to change. Be conservative: only propose a change when the data "
        "clearly supports it, and prefer small, sustainable adjustments over "
        "large swings. If fewer than 5 days were logged in the window, "
        "prefer should_change=false and say so - there isn't enough data yet. "
        "Never propose fewer than 1200 kcal/day."
    )
    message = _client().messages.create(
        model=settings.anthropic_model,
        max_tokens=1024,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": "Here is the user's context as JSON:\n\n" + json.dumps(context, indent=2),
            }
        ],
        tools=[_CHECK_IN_TOOL],
        tool_choice={"type": "tool", "name": "submit_nutrition_assessment"},
    )

    tool_use = next(b for b in message.content if b.type == "tool_use")
    proposal = tool_use.input
    raw_response = json.dumps(proposal)

    goal: models.Goal | None = None
    guardrail_notes: str | None = None

    if not proposal.get("should_change"):
        result_message = proposal.get("reasoning") or "No changes needed."
    else:
        goal, guardrail_notes = _propose_nutrition_goal(db, user, context, proposal)
        if goal is None:
            result_message = (
                "The coach's proposal didn't pass safety checks this time, "
                "so no target was suggested."
            )
        else:
            result_message = proposal.get("reasoning") or "New target proposed."

    run = models.CoachRun(
        user_id=user.id,
        context=context,
        raw_response=raw_response,
        model=settings.anthropic_model,
        resulting_goal_id=goal.id if goal else None,
        guardrail_notes=guardrail_notes,
    )
    db.add(run)
    db.commit()
    if goal:
        db.refresh(goal)
    db.refresh(run)

    return goal, result_message, run


def handle_chat(db: Session, user: models.User, message_text: str) -> dict:
    db.add(models.ChatMessage(user_id=user.id, role="user", content=message_text))
    db.flush()

    history = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.user_id == user.id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(CHAT_HISTORY_LIMIT)
        .all()
    )
    history.reverse()

    context = gather_chat_context(db, user)
    system_prompt = (
        "You are Mentor, a fitness and nutrition assistant embedded in the "
        "user's tracking app. Answer questions directly using the provided "
        "context. If the user asks you to log something (e.g. 'log the same "
        "breakfast as yesterday'), use the propose_nutrition_log tool - find "
        "the matching entries in recent_nutrition_entries and resolve them "
        "to a food_item_id from the context, never invent one. If the user "
        "is asking about or would benefit from changing their calorie/macro "
        "target, use propose_nutrition_target. Never claim to have taken an "
        "action - proposing it via a tool is enough, the user approves it "
        "afterward."
    )

    api_messages = [{"role": m.role, "content": m.content} for m in history] + [
        {
            "role": "user",
            "content": "Context:\n" + json.dumps(context, indent=2, default=str),
        }
    ]

    response = _client().messages.create(
        model=settings.anthropic_model,
        max_tokens=1024,
        system=system_prompt,
        messages=api_messages,
        tools=[_LOG_ENTRY_TOOL, _GOAL_PROPOSE_TOOL],
    )

    reply_parts = [b.text for b in response.content if b.type == "text" and b.text]
    proposed_goal: models.Goal | None = None
    proposed_action: models.AgentAction | None = None

    for block in response.content:
        if block.type != "tool_use":
            continue

        if block.name == "propose_nutrition_target":
            goal_context = gather_context(db, user)
            proposed_goal, notes = _propose_nutrition_goal(db, user, goal_context, block.input)
            db.add(
                models.CoachRun(
                    user_id=user.id,
                    context=goal_context,
                    raw_response=json.dumps(block.input),
                    model=settings.anthropic_model,
                    resulting_goal_id=proposed_goal.id if proposed_goal else None,
                    guardrail_notes=notes,
                )
            )
            if not reply_parts:
                reply_parts.append(block.input.get("reasoning", "Here's a proposed target."))

        elif block.name == "propose_nutrition_log":
            action = models.AgentAction(
                user_id=user.id,
                action_type="log_nutrition_entry",
                payload={"entries": block.input["entries"]},
                summary=block.input["summary"],
                reasoning=block.input.get("reasoning"),
            )
            db.add(action)
            db.flush()
            proposed_action = action
            if not reply_parts:
                reply_parts.append(block.input["summary"])

    reply_text = " ".join(reply_parts).strip() or "Done."
    db.add(models.ChatMessage(user_id=user.id, role="assistant", content=reply_text))
    db.commit()
    if proposed_goal:
        db.refresh(proposed_goal)
    if proposed_action:
        db.refresh(proposed_action)

    return {"reply": reply_text, "proposed_goal": proposed_goal, "proposed_action": proposed_action}


def _latest_activity_at(db: Session, user: models.User) -> datetime | None:
    candidates = [
        db.query(func.max(models.NutritionLog.created_at))
        .filter(models.NutritionLog.user_id == user.id)
        .scalar(),
        db.query(func.max(models.WorkoutLogEntry.created_at))
        .filter(models.WorkoutLogEntry.user_id == user.id)
        .scalar(),
        db.query(func.max(models.HealthMetric.created_at))
        .filter(models.HealthMetric.user_id == user.id)
        .scalar(),
        db.query(func.max(models.Goal.created_at)).filter(models.Goal.user_id == user.id).scalar(),
    ]
    present = [c for c in candidates if c is not None]
    return max(present) if present else None


def refresh_insight(db: Session, user: models.User) -> models.MentorInsight:
    latest = (
        db.query(models.MentorInsight)
        .filter(models.MentorInsight.user_id == user.id)
        .order_by(models.MentorInsight.created_at.desc())
        .first()
    )
    activity_at = _latest_activity_at(db, user)
    now = datetime.utcnow()
    if (
        latest is not None
        and latest.created_at.date() == now.date()
        and (activity_at is None or latest.created_at >= activity_at)
    ):
        return latest

    if not settings.anthropic_api_key:
        # Can't call the model - carry the previous text forward (or a
        # neutral placeholder on first run) rather than blocking the
        # dashboard on a missing API key.
        text = latest.text if latest else "Log some data and check back for insights."
        insight = models.MentorInsight(user_id=user.id, text=text)
        db.add(insight)
        db.commit()
        db.refresh(insight)
        return insight

    context = gather_dashboard_context(db, user)
    context["previous_insight"] = latest.text if latest else None

    message = _client().messages.create(
        model=settings.anthropic_model,
        max_tokens=300,
        system=(
            "You write a single short, plain-language headline sentence "
            "summarizing the user's day/trend for a fitness app dashboard - "
            "things like 'Everything looks good today', 'You didn't get "
            "enough sleep last night', or 'New low weight - great work'. "
            "Only propose changing it when something in the context is "
            "actually noteworthy compared to previous_insight; otherwise "
            "keep the previous text unchanged."
        ),
        messages=[{"role": "user", "content": json.dumps(context, indent=2, default=str)}],
        tools=[_INSIGHT_TOOL],
        tool_choice={"type": "tool", "name": "submit_insight"},
    )
    tool_use = next(b for b in message.content if b.type == "tool_use")
    result = tool_use.input
    if result.get("should_update"):
        text = result["insight_text"]
    else:
        text = latest.text if latest else result["insight_text"]

    insight = models.MentorInsight(user_id=user.id, text=text)
    db.add(insight)
    db.commit()
    db.refresh(insight)
    return insight


def get_dashboard(db: Session, user: models.User) -> dict:
    insight = refresh_insight(db, user)
    context = gather_dashboard_context(db, user)
    active_goal = (
        db.query(models.Goal)
        .filter(
            models.Goal.user_id == user.id,
            models.Goal.status == "active",
            models.Goal.goal_type == "calorie_target",
        )
        .order_by(models.Goal.effective_at.desc())
        .first()
    )
    latest_weight_metric = (
        db.query(models.HealthMetric)
        .filter(
            models.HealthMetric.user_id == user.id,
            models.HealthMetric.metric_type == "weight",
        )
        .order_by(models.HealthMetric.recorded_at.desc())
        .first()
    )
    totals = context["today_totals"]
    return {
        "today_calories": totals["calories"],
        "today_protein_g": totals["protein_g"],
        "today_carbs_g": totals["carbs_g"],
        "today_fat_g": totals["fat_g"],
        "active_goal": active_goal,
        "latest_weight": latest_weight_metric,
        "weight_change_7d": context["weight"]["change_7d"],
        "sleep_hours_last_night": None,
        "insight_text": insight.text,
        "insight_generated_at": insight.created_at,
    }

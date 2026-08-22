"""Seed the shared base exercise library (user_id=NULL rows in `exercises`).

Safe to re-run: upserts by name among base (user_id IS NULL) exercises,
so editing exercises.json and re-running updates existing rows instead of
duplicating them.

Usage: python -m app.seeds.seed_exercises
"""

import json
from pathlib import Path

from app.db import SessionLocal
from app.models import Exercise

DATA_PATH = Path(__file__).parent / "exercises.json"


def seed_exercises() -> None:
    exercises = json.loads(DATA_PATH.read_text())

    db = SessionLocal()
    try:
        existing = {
            e.name: e
            for e in db.query(Exercise).filter(Exercise.user_id.is_(None)).all()
        }

        created = 0
        updated = 0
        for entry in exercises:
            row = existing.get(entry["name"])
            if row is None:
                db.add(Exercise(user_id=None, **entry))
                created += 1
            else:
                for key, value in entry.items():
                    setattr(row, key, value)
                updated += 1

        db.commit()
        print(f"Seeded exercises: {created} created, {updated} updated.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_exercises()

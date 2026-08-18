# Mentor — Functional & Technical Specification (Draft v0.1)

Status: functionality locked pending your review; stack/technology decisions deliberately deferred to a follow-up doc.

## 1. Vision

Mentor is an AI-first fitness coaching app. Unlike MyFitnessPal/MyNetDiary, which are primarily logging tools with a human doing the thinking, Mentor's core value is an AI agent that owns the coaching loop: it ingests nutrition/workout/health data, reasons over trends, and actively manages the user's goals and plan — proposing changes rather than just displaying charts.

Secondary goal: this project is a deliberate vehicle to learn three concepts hands-on —
1. **AI Orchestration Layer** — multi-step reasoning + tool-calling pipelines (entity resolution, goal-adjustment, notification dispatch).
2. **AI Harness** — guardrails, evaluation, observability, and safety bounds around the AI's decisions.
3. **Distributed Computing** — backend split into independently scalable services (API, scheduled agent runs, job queues) rather than a monolith.

Plus exposure to a new cloud provider (Azure or AWS — TBD) and at least one new language, both to go on a resume. Stack choice is intentionally deferred until this functional spec is agreed.

## 2. Core Functional Requirements

### 2.1 Nutrition Tracking

**Personal food library.** Every user has a personal library of food items, populated only from grounded sources — the AI never invents nutrition data:
- **Barcode scan** — looked up against an external nutrition DB (e.g. Open Food Facts / USDA) on first scan, then cached into the user's personal library.
- **Manual entry** — user types name + macros directly.
- **AI-assisted structured entry** — user supplies nutrition facts via a screenshot of a label or a spoken/typed description ("240 kcal, 12g protein per 100g"); the AI structures this into a library item but sources the numbers only from what the user gave it.
- **Screenshot parsing pipeline**: OCR extracts raw text from the label image → LLM structures the OCR text into macros/serving size → user confirms before it's saved to the library. (OCR-first chosen over direct vision-LLM parsing, partly to get hands-on with a distinct OCR component as its own learning surface.)

**Database search.** Beyond barcode scanning, users can search the food database directly via a search bar (by name/brand) and add a result straight to their personal library — barcode scanning and search are just two entry points into the same grounded database, both landing in the same personal library flow.

**Natural-language logging.** The AI resolves free-text meal descriptions against the personal library + barcode history, not general knowledge:
- "Same breakfast as yesterday" → re-logs yesterday's exact resolved items (e.g. 100g cereal + 250ml milk from their barcode-sourced records).
- "120g cereal instead" → same item, quantity override parsed from the sentence.
- If the AI cannot confidently match a described food to an existing library item, it must ask the user to disambiguate or provide the source (barcode/manual/screenshot) rather than guessing new nutrition values.

This makes nutrition logging fundamentally a **grounded retrieval + entity-resolution** pipeline: NL input → match against personal library/barcode DB → structured log entry → confirmation. This is the first concrete home for the AI Orchestration Layer learning goal.

### 2.2 Workout Tracking

- **Base exercise database**: a standard shared library (exercise name, muscle groups, equipment, etc.), not user-editable.
- **Manual logging** against that database: sets, reps, weight, duration.
- **Natural-language logging**: AI parses free-text workout descriptions into structured sets, matching against the base DB or the user's personal exercise library.
- **Custom exercises**: when the AI can't match a described exercise to the base DB, it defines a new one and **saves it to the user's personal library** (not the shared base DB), so it's directly reusable next time without being re-described.
- **HealthKit sync**: passively pulls steps, heart rate, workouts already logged elsewhere, weight, and sleep from Apple Health, feeding context to the coach even without manual entry.

### 2.3 AI Coach — Autonomous Goal Management

The most ambitious piece, and the primary surface for the AI Orchestration/Harness learning goals:

- On a recurring schedule (e.g. daily/weekly), the AI reviews logged nutrition, workout, and HealthKit data for trends and adherence.
- It **drafts** goal/plan changes (calorie targets, macro splits, workout programming) with an explanation of its reasoning, based on progress.
- Changes are **proposed, not auto-applied** — the user reviews and approves/rejects each proposed change before it takes effect. (Chosen deliberately over full auto-apply given this is health data — human-in-the-loop gate before any write to the user's actual goals/plan.)
- The AI also proactively surfaces insights/nudges (not just goal changes) without being asked.
- Needs an explicit **AI Harness** layer: guardrails against unsafe recommendations (e.g. refuses to propose unsafe caloric deficits or unsafe training load jumps), logging of every decision + the data it was based on, and a way to evaluate/test the coaching prompts over time.

### 2.4 Multi-User Architecture

- Full auth and per-user data isolation from day one, even though the initial real user is just you.
- Backend designed to scale horizontally — the natural hook for the Distributed Computing learning goal (separable services, job queue for scheduled coaching runs, rather than a single process).

## 3. Non-Functional / Learning Objective Mapping

| Learning goal | Where it lives in the product |
|---|---|
| AI Orchestration Layer | NL → structured-entity resolution pipeline (nutrition + workouts); the multi-step reasoning/tool-calling the autonomous coach does each cycle (read data → reason → draft proposal → notify → await approval → write state) |
| AI Harness | Guardrails/safety bounds on coach proposals, decision logging/observability, prompt evaluation over time |
| Distributed Computing | Backend split into independently scalable services: ingestion API, scheduled agent-run workers/queue, notification dispatch — not a monolith |
| New cloud provider (Azure/AWS — TBD) | Hosting for backend services, job scheduling, storage, auth |
| New language(s) — TBD | Deferred to stack discussion |

## 4. Open Items Still Needing a Decision Before Technical Spec

These don't block writing this functional spec but do block the technical architecture doc:

1. **Approval UX** — how does a "propose then approve" goal change get surfaced (push notification, in-app inbox, both)?
2. **Guardrail specifics** — what numeric/qualitative safety bounds should the AI never cross (e.g. minimum calorie floor, max weekly weight-loss rate, max training load increase)? Worth defining explicit rules rather than leaving it to model judgment.
3. **Data privacy & App Store health-data requirements** — HealthKit usage triggers Apple's stricter review path (usage descriptions, privacy nutrition label, no undisclosed third-party sharing of health data). Needs to shape data-handling design before, not after, submission.
4. **Barcode/nutrition DB provider** — Open Food Facts (free, community-sourced, less consistent) vs USDA (US-only, very structured) vs a commercial API — affects data quality and cost.
5. **Pace/scope expectations** — this is a multi-phase, multi-month part-time build; worth confirming how much time per week you're planning so the roadmap phases are realistic.

## 5. Rough Phase Roadmap (functionality-driven, stack-agnostic)

- **Phase 0** — this spec + stack decision (next step)
- **Phase 1 (MVP)** — manual + barcode nutrition logging, manual + HealthKit workout logging, basic reactive AI Q&A over logged data, single real user, running locally
- **Phase 2** — NL logging for both nutrition and workouts with entity resolution against the personal library; screenshot→OCR→LLM nutrition-label parsing
- **Phase 3** — Autonomous coaching agent: scheduled review runs, goal-change proposals, approval flow, guardrails/harness — where most of the orchestration/harness learning work concentrates
- **Phase 4** — Multi-user hardening: real auth, per-user isolation, cloud deployment, backend split into distributed services
- **Phase 5** — App Store submission: TestFlight, HealthKit/privacy disclosures, review, launch

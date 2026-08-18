# Mentor — Technical Stack & Architecture (Draft v0.1)

Companion to [functional_spec.md](functional_spec.md). Captures the stack decisions made so the skeleton/infra can be built; deeper design (guardrail specifics, approval UX, DB provider choice, etc.) is deferred to when each phase is actually reached, per the functional spec's open items.

## 1. Stack Decisions

| Layer | Choice | Why |
|---|---|---|
| Mobile app | **Swift + SwiftUI**, native iOS | Best HealthKit integration and App Store idioms; genuinely new language for the resume/learning goal. |
| Backend / AI orchestration | **Python** (FastAPI) | Dominant ecosystem for LLM orchestration tooling; matches existing (moderate) Python experience, which this project will deepen. |
| Cloud provider | **AWS** | New to the user (prior experience is GCP); most in-demand for resume purposes. |
| LLM provider | **Direct Anthropic API** (Claude) | Simplest integration, first access to newest Claude models/features, standard path for most orchestration tooling. |
| Infrastructure-as-code | **Terraform** | Cloud-agnostic, most universally recognized IaC skill; adds HCL as a small new syntax. |
| OCR (nutrition-label screenshots) | TBD service (e.g. AWS Textract) → LLM structuring | OCR-first pipeline chosen over direct vision-LLM parsing, partly as its own distinct learning surface. |

**Known gap:** native iOS builds require macOS (Xcode, Simulator, App Store Connect tooling). The user's local machine is Windows. Needs a Mac environment (owned/virtual Mac, or cloud macOS CI like GitHub Actions macOS runners / Codemagic / MacStadium) before the `ios/` app can be built or shipped. Backend, infra, and docs work is unaffected and fully Windows-native.

## 2. High-Level Architecture

```
┌─────────────────┐
│   iOS App        │  Swift/SwiftUI, HealthKit integration
│  (native client)  │
└────────┬─────────┘
         │ HTTPS (REST/JSON)
         ▼
┌─────────────────────────────┐
│   API Service (FastAPI)      │  Auth-gated CRUD: users, food library,
│                               │  workout library, logs, goals
└────────┬─────────────────────┘
         │
         ├──► Postgres (RDS) — relational store: users, personal food/exercise
         │                      libraries, logs, goals, proposal history
         │
         ├──► SQS queue ──► AI Orchestration Worker(s)
         │                   - NL log entity resolution (nutrition/workout)
         │                   - Screenshot OCR → LLM structuring
         │                   - Calls Anthropic API
         │
         └──► EventBridge (scheduled) ──► Autonomous Coach Worker
                                            - reviews user data on a cadence
                                            - drafts goal/plan change proposals
                                            - writes proposals for user approval
                                            - dispatches notifications
```

Distributed-computing learning goal shows up here as: API service, orchestration workers, and the scheduled coach are independently deployable/scalable units communicating via SQS/EventBridge rather than a single monolith process.

## 3. Repository Layout

Monorepo, since this is a solo learning project and cross-cutting changes (e.g. an API field added to both backend and app) are common:

```
project-mentor/
├── docs/           product & technical specs
├── ios/            Swift/SwiftUI app (requires macOS to build)
├── backend/        Python/FastAPI API + orchestration workers
├── infra/          Terraform for AWS resources
└── README.md
```

## 4. Still Open (deferred until reached, per functional spec §4)

- Guardrail specifics for autonomous coaching
- Approval UX (push vs in-app inbox)
- Barcode/food DB provider (Open Food Facts vs USDA vs commercial)
- OCR service choice
- Mac build environment for iOS

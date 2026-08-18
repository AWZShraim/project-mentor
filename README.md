# Mentor

An AI-first fitness coaching app: tracks nutrition and workouts, and uses an AI agent to actively manage the user's goals and coaching rather than just displaying dashboards.

Personal project + learning vehicle for AI orchestration, AI harness design, distributed computing, and AWS.

## Docs

- [Functional Spec](docs/functional_spec.md) — what the app does
- [Technical Spec](docs/technical_spec.md) — stack, architecture, repo layout

## Layout

- `ios/` — Swift/SwiftUI native app (requires macOS to build)
- `backend/` — Python/FastAPI API + AI orchestration workers
- `infra/` — Terraform for AWS resources
- `docs/` — specs

## Status

Early scaffolding stage. See docs for the current phase roadmap.

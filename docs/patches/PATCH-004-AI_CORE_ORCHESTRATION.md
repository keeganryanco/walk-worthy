# PATCH-004: AI Core Orchestration + Offline Foundations

## Goal
Implement the first production-ready core logic layer for Tend so UI can integrate against stable interfaces while AI/provider decisions are finalized.

## Scope
- Added daily package cache model and source tracking:
  - `DailyJourneyPackageRecord`
  - `DailyJourneyPackageSource` (`cache`, `remote`, `template`)
- Added package validation/sanitization:
  - approved scripture reference fallback
  - normalized question and suggested-step constraints
- Added content orchestration service:
  - `JourneyContentService`
  - remote-provider protocol seam + local deterministic fallback
  - online prefetch for today + tomorrow
- Added memory/progression services:
  - `JourneyMemoryService`
  - `JourneyProgressService`
- Added connectivity service:
  - `ConnectivityService` (`NWPathMonitor`)
- Wired core services into app:
  - daily package prefetch after startup / connectivity restoration / journey count changes
  - today card generation now uses orchestrated package flow
  - journey creation now enforces offline + paywall + free-tier policy via `JourneyCreationPolicy`
- Added tests for:
  - package validation fallback behavior
  - day-key stability

## Acceptance
- Unit tests pass for monetization/policy/template + new package-validation/day-key coverage.
- Existing journeys remain usable offline.
- New journey creation is blocked while offline with clear user messaging.
- Daily package generation has deterministic fallback and cached retrieval behavior.

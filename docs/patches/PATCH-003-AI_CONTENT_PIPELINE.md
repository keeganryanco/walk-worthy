# PATCH-003: AI Content Pipeline (MVP)

## Goal
Generate contextual Today cards from onboarding and journey history while preserving safety constraints.

## Scope
- Prompt builder based on onboarding tags + recent entries
- Action-step selector and validator
- Scripture reference selector
- Fallback non-AI deterministic templates

## Acceptance
- Today card generated on first onboarding completion
- Generation remains deterministic/fallback-safe offline
- Scripture snippets always include an approved verse reference

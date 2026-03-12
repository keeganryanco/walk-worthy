# RFC-0002: AI Content and Scripture Policy

- **Status:** Draft
- **Date:** March 12, 2026
- **Owner:** Product + Engineering

## Context
Walk Worthy will lean into AI for personalization of prayer prompts and action steps. The product also intends to include scripture excerpts.

## Decision
1. AI is allowed for:
- Prompt personalization
- Action-step selection
- Reflection summarization
- Scripture reference selection

2. AI is not allowed to generate text labeled as direct scripture quote unless it is sourced from approved translation text.

3. Displayed scripture text must come from:
- Public-domain source text, or
- Translation with explicit usage rights and compliance terms

4. If source rights are unresolved, launch fallback is:
- Scripture references only (`Book Chapter:Verse`) without excerpt text

## Rationale
This prevents doctrinal misquote risk, reduces App Review risk, and lowers copyright/legal exposure.

## Implementation notes
- Add `ScriptureSourcePolicy` enum in app settings.
- Add `isVerbatim` marker on rendered verse snippets.
- Keep AI output and source verse text separate in code.

## Open items
- Confirm translation licensing path (if using NIV/ESV/NLT).

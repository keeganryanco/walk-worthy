# RFC-0002: AI Content and Scripture Policy

- **Status:** Draft
- **Date:** March 12, 2026
- **Owner:** Product + Engineering

## Context
Tend will lean into AI for personalization of prayer prompts and action steps. The product also intends to include scripture excerpts.

## Decision
1. AI is allowed for:
- Prompt personalization
- Action-step selection
- Reflection summarization
- Scripture reference selection
- Scripture snippet generation (summarized or verbatim)

2. MVP display policy:
- Show scripture reference + snippet.
- Do not show translation source in user-facing UI.

3. Hallucination controls:
- Generate snippets only for references selected from an approved verse reference set.
- Reject and regenerate if output does not include a valid reference or exceeds snippet bounds.

4. Translation direction:
- Product direction is NIV/ESV/NLT-adjacent scripture output for MVP.

## Rationale
This maximizes personalized UX while maintaining practical anti-hallucination constraints for launch.

## Implementation notes
- Add `ScriptureSourcePolicy` enum in app settings.
- Add constraint validator for reference format and approved-reference membership.
- Keep fallback deterministic snippet generator for offline/no-AI states.

## Open items
- Finalize production AI provider and key-management pattern.

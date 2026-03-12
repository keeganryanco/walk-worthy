# Risks: App Review Rejection or Product Confusion

## App Review rejection risks
1. Misleading religious quotations
- Risk: Generated text appears to quote scripture inaccurately.
- Mitigation: Constrain generation to approved verse references and reject outputs without valid references.

2. Scripture licensing infringement
- Risk: Using NIV/ESV/NLT excerpts without proper license/compliance obligations.
- Mitigation: Product owner accepted this launch risk for MVP; maintain fallback to summarized snippets and adjust immediately if review/legal requires.

3. Subscription compliance gaps
- Risk: Missing restore purchases or unclear subscription terms.
- Mitigation: Restore button visible; clear pricing and renewal messaging.

4. Missing required metadata/URLs
- Risk: Privacy Policy URL or Support URL missing/invalid.
- Mitigation: Validate URLs before submission and maintain live endpoints.

5. Overstated claims
- Risk: Content implies guaranteed divine, therapeutic, or medical outcomes.
- Mitigation: Keep language invitational and non-guaranteed.

6. Broken reviewer path
- Risk: Reviewer cannot access/test premium flows.
- Mitigation: Provide clean review notes + sandbox test instructions.

## Product confusion risks
1. App appears like generic devotional content app
- Mitigation: Keep Pray -> Do framing explicit in onboarding and Today card.

2. Action step feels too vague
- Mitigation: Constrain prompts to concrete, measurable actions.

3. Hard paywall feels abrupt
- Mitigation: Ensure at least one clear value moment before prompt and communicate free trial terms plainly.

4. “Answered prayer” semantics feel presumptive
- Mitigation: Use optional language and user-controlled framing in UI copy.

5. Overly complex journey model at launch
- Mitigation: Keep category/tagging lightweight and optional.

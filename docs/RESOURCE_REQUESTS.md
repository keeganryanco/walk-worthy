# Resource Request List (Blocking Inputs)

## Decisions resolved
1. Final app name confirmation
- Final: **Tend**

2. Subscription pricing decision
- MVP direction: hard paywall with **3-day free trial** using Apple subscription intro offer
- Final recurring prices:
  - `$5.99/week`
  - `$35/year`
- Still needed: final App Store Connect product IDs if different from scaffold defaults

3. Scripture policy for launch
- Final direction: AI-generated scripture snippets (summarized or verbatim), constrained to real verse references.
- UI direction: translation source is not shown to the user.
- Implementation direction: enforce reference constraints and anti-hallucination validation.

## Brand and design assets needed before final polish
1. App icon direction
- Direction approved: simple prayer icon, single-color, brand-aligned, standout
- Still needed: final source file (SVG/PDF/1024x1024 PNG)
- Place final source file at:
  - `design/brand-assets/icons/tend-icon-1024.png`

2. Color palette approval
- Approved:
  - White `#FFFFFF`
  - Grow green `#4CAF7D`
  - Morning gold `#F0C060`
  - Surface `#F5F5F3`
  - Near black `#1A1A1A`
  - Muted `#888884`
  - Dark mode background `#0F0F0F`

3. Typography confirmation
- Direction approved:
  - Plus Jakarta Sans (Display/Heading)
  - Inter (Body/Caption)
- Still needed: final font files/licensing for app bundling
- Place fonts in:
  - `design/brand-assets/fonts/`

4. Screenshot copy direction
- Deferred for later; story format direction acknowledged (phone + feature narrative slides)

## Content assets needed
1. Starter prayer prompts
- AI-first strategy approved
- Still needed: baseline curated seed set for safety and fallback (recommended minimum: 20)

2. Action-step templates
- AI-first strategy approved
- Still needed: baseline curated seed set for safety and fallback (recommended minimum: 40)

3. Onboarding option labels
- Final wording for growth goals, blockers, and reminder windows

## App Store and legal assets needed
1. Support email
- Final for now: `tend@keeganryan.co`

2. Privacy Policy URL
- Pending deploy: `site/` is ready; provide final deployed URL

3. Support URL
- Pending deploy: `site/` is ready; provide final deployed URL

4. Marketing URL (optional but recommended)
- Landing page URL for Tend

5. Copyright holder line
- Person/company legal owner name

## Optional but strongly recommended
1. App Preview video decision
- Yes/No for launch

2. Demo mode preference for App Review
- Enable hidden demo content or rely on review notes only

3. Export format scope for MVP
- TXT/Markdown/PDF choice

## AI gateway + runtime config needed (new)
1. Vercel environment variables
- `OPENAI_API_KEY`
- `GEMINI_API_KEY`
- `TEND_APP_SHARED_SECRET` (recommended)

2. iOS runtime config values
- `TENDAI_BASE_URL` = deployed Vercel domain
- `TENDAI_APP_KEY` = same value as `TEND_APP_SHARED_SECRET`

3. Model overrides (optional)
- `OPENAI_PRIMARY_MODEL` (default `gpt-5-mini`)
- `OPENAI_ESCALATION_MODEL` (default `gpt-5.1`)
- `GEMINI_PRIMARY_MODEL` (default `gemini-2.5-flash`)

4. Remaining integrations
- RevenueCat App Store Connect key configuration + offering activation in dashboard
- PostHog event verification in production build (after first TestFlight session)

## What I can complete without further input
- Full SwiftUI/SwiftData/StoreKit 2 scaffold
- Core onboarding + Today flow
- Journey and timeline implementation
- Notification scheduling
- Test suite scaffolding
- App Store checklist and metadata templates

## What explicitly requires you
- Final legal URLs (or approval to use deployed Vercel URLs)
- Final icon asset file handoff
- Any licensed font assets

# Resource Request List (Blocking Inputs)

## Decisions resolved
1. Final app name confirmation
- Final: **Walk Worthy**

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
  - `design/app-icon/source/app-icon-1024.png`

2. Color palette approval
- Approved: `#EAE0C8`, `#9CBA8F`, `#0F52BA`, deep charcoal text

3. Typography confirmation
- Direction approved: creative editorial fonts near Playfair/Instrument Serif vibe
- Still needed: final font files/licensing if using non-system fonts

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
- Final for now: `keegan.ryan@keeganryan.co`

2. Privacy Policy URL
- Pending deploy: `site/` is ready; provide final deployed URL

3. Support URL
- Pending deploy: `site/` is ready; provide final deployed URL

4. Marketing URL (optional but recommended)
- Landing page URL for Walk Worthy

5. Copyright holder line
- Person/company legal owner name

## Optional but strongly recommended
1. App Preview video decision
- Yes/No for launch

2. Demo mode preference for App Review
- Enable hidden demo content or rely on review notes only

3. Export format scope for MVP
- TXT/Markdown/PDF choice

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

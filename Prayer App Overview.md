# Prayer App Overview

## 1) Prayer app first

## Recommended brand

**Best pick:** Walk Worthy  
**App Store subtitle:** Pray & Do

**Why:** It has stronger emotional and biblical resonance than Acta, while “Pray & Do” gives immediate clarity. Your PDF’s core wedge is exactly this: prayer + action, not passive listening.

### Keep as alternates
- Acta
- Faith in Motion

## Brand direction
Your PDF’s direction is right: modern, warm, editorial, grounded, not church-software-y. The strongest visual lane is warm alabaster + sage + sapphire with elegant serif headers and clean sans body text.

- `App%20Idea%20Research%20and%20D…`

## Visual system
- Background: `#EAE0C8`
- Secondary: `#9CBA8F`
- Primary CTA: `#0F52BA`
- Text: near-charcoal, not pure black
- Headers: Playfair Display / Instrument Serif vibe
- Body: Inter / SF Pro / Open Sans vibe

## Tone
- sincere
- disciplined
- hopeful
- not preachy
- not prosperity-gospel-coded
- not political

## Positioning

### Core promise
Pray, then take the next faithful step.

### What it is not
- not a meditation library
- not a church app
- not a social prayer wall
- not “manifest your dream life”

### What it is
- a daily prayer + action rhythm
- a prayer tracker with real-world follow-through
- a private spiritual discipline tool

## Best marketing angles
These are directly aligned with the report and still the strongest.

- `App%20Idea%20Research%20and%20D…`

### Angle 1: Faith without drift
**Hook:**
- “I stopped confusing thinking about God with actually walking with God.”
- “This is the daily habit that got my faith out of my head.”

### Angle 2: Answered prayers timeline
**Hook:**
- “Tracking my prayers changed how I see what God is doing.”
- “Most people forget what they prayed for. That’s why their faith feels blurry.”

### Angle 3: Pray + do
**Hook:**
- “After you pray, what’s the next faithful step?”
- “This app doesn’t just tell you to pray. It tells you what to do next.”

## Messaging stack

### Homepage / App Store message
- **Headline:** Pray, then move.
- **Subhead:** Turn prayers into daily action with a private rhythm built for real life.

**Three bullets:**
- Daily prayer prompt
- One concrete next step
- Track what changed over time

### Paywall message
- **Title:** Build a daily rhythm.
- **Body:** Keep every prayer, every next step, and every answered prayer in one place.

**Bullets:**
- Unlimited prayer journeys
- Answered prayer timeline
- Guided Pray & Do templates
- Export and reflection tools

## Onboarding flow
This should feel identity-based, not utilitarian.

- What are you praying about right now?  
  family / anxiety / purpose / work / relationships / health
- How do you want to grow?  
  consistency / courage / peace / discipline / service
- When do you want to show up?  
  morning / lunch / evening
- What usually gets in the way?  
  forgetfulness / overwhelm / inconsistency / distraction / not knowing what to do

### Wow moment
Generate the first Today card instantly:
- 1 prayer prompt
- 1 action step
- 1 optional reflection line

## Some thoughts on this
- We can use a small AI model to generate all of this. If our instructions are clear, we can count on it not to hallucinate a wrong bible quote, rather it's just important for it to be in the ballpack of correct.
- We can incorporate denomination/religious affiliation as part of onboarding later, and that can guide the user experience subtly to shift toward using certain translations / adhering to specific theology. but, as of now, we're focused on creating the app, proposing the core idea and direction of the app to be accepted by the user. we can include a disclaimer that the app is not affiliated with any particular denomination or religious affiliation, and is intended for personal spiritual growth and development. It claims no liability for any misinformation or harm caused by the app.
- We will likely use just my OpenAI API key/account to generate any AI-generated content. Or we could make it actually offline and rely on Llama if it's possible to run a sufficient model of Llama on a phone.

## Free -> paid
- free: 1-2 active prayer journeys, basic Today flow
- paid: unlimited journeys, answer history, template packs, export, widgets
- Pricing tiers: $5.99 / week or $35 / year.

Trigger paywall after the user completes:
- 2 sessions, or
- creates a 2nd/3rd journey, or
- tries to open timeline history

## MVP tech stack
- iOS: SwiftUI
- Persistence: SwiftData
- Payments: StoreKit 2
- Notifications: local only
- Analytics: light local event logger + App Store Connect analytics outside app
- Backend: none for MVP
- Website: minimal Next.js/Vercel support + privacy pages only

## Apple / App Review notes
This one is very App Store-friendly if handled cleanly.

### Must do
- use IAP / StoreKit 2 for premium digital features
- provide privacy policy URL and support URL
- if App Review needs access to special content, provide demo mode or clear review notes/resources

### Important content caution
Apple explicitly flags inaccurate or misleading quotations of religious texts and inflammatory religious commentary. So:
- do not auto-generate fake Bible quotes
- do not paraphrase Scripture and present it as verbatim
- do not become denomination-war content
- keep prompts pastoral, not doctrinally overconfident

### Safe content policy for v1
- use your own prayer prompts
- use very short scripture references or public-domain scripture only until licensing is settled
- avoid therapeutic / medical claims
- avoid “God guaranteed this outcome” framing

## Resources the agent should ask you for
- chosen name: Walk Worthy vs Acta
- app icon direction
- final color palette
- 10-20 starter prayer prompts
- 30-50 starter action-step templates by category
- subscription pricing choice
- support email
- privacy policy/support URLs
- App Store subtitle + description
- screenshots / screenshot copy
- whether to include scripture text at launch

## Inciting prompt for the agent
Build an iOS app called “Walk Worthy” with the subtitle “Pray & Do.”

### Goal
Create a private, offline (preferred) Christian prayer app that turns prayer into action. The daily loop is: Pray -> Take one concrete step -> Reflect -> Track what changed over time.

### Requirements
- SwiftUI
- SwiftData
- StoreKit 2
- Local notifications
- No account system
- No backend for MVP
- Extremely polished UX/UI
- Modern editorial style: warm alabaster, sage, sapphire, elegant serif headings, clean sans body
- App must feel sincere, grounded, and contemporary

### Core features
1. Onboarding
   - What are you praying about?
   - How do you want to grow?
   - When do you want to show up?
   - What gets in the way?
   - Generate first Today card instantly

2. Today card
   - short prayer prompt
   - one concrete action step
   - optional reflection
   - complete in under 30 seconds if desired

3. Prayer journeys
   - category/tagged prayer projects
   - daily entries
   - answered prayer timeline

4. Monetization
   - free tier limited journeys
   - premium unlocks unlimited journeys, templates, export, widgets
   - StoreKit 2 with restore purchases

5. App Review readiness
   - privacy-first, local data
   - demo mode if needed
   - no misleading religious quotes
   - no unsupported claims

### Deliverables
- agent.md
- docs/RFC.md
- project architecture
- TODO.md
- exact list of required resources/assets/decisions needed from me before final polish
- complete production-ready SwiftUI scaffold

### Before coding
Before coding, ask me for any missing assets/resources and list them clearly.

---

## Skills

### skill: ios_app_polish

**Purpose:**
Ensure the iOS app feels native, premium, and App Store ready.

**Principles:**
- SwiftUI-first architecture
- Minimal view hierarchy
- Prefer system components when possible
- Smooth transitions
- Instant responsiveness

**Design rules:**
- No clutter
- Every screen has one clear primary action
- Use large touch targets (44pt minimum)
- Prioritize vertical flow

**Engineering rules:**
- SwiftUI
- SwiftData for persistence
- StoreKit 2 for purchases
- Local-first architecture
- No backend for MVP

**Performance rules:**
- Avoid heavy frameworks
- Avoid unnecessary async complexity
- App launch < 1s
- No blocking operations on main thread

**UX rules:**
- First action should be achievable within 5 seconds of opening the app
- Avoid modal spam
- Avoid tutorial slideshows
- Prefer progressive discovery

**App Store readiness:**
- Privacy policy link
- Support URL
- Restore purchases button
- Clear subscription explanation

### skill: frictionless_onboarding

**Purpose:**
Create onboarding that generates psychological investment without feeling like setup work.

**Rules:**
- Max 4-5 questions
- Tap-based answers
- No typing unless optional
- Immediate payoff after onboarding

**Design:**
- One question per screen
- Large card-style options
- Friendly tone
- Visible progress indicator

**Psychology:**
- Questions should make the user reflect on identity
- Avoid generic setup questions
- Frame questions around goals, struggles, desires

**Example:**
Instead of: “What reminder time?”

Use: “When do you want to show up for this?”

After onboarding:
Immediately generate a personalized experience.

Never end onboarding with a blank dashboard.

### skill: mobile_subscription_design

**Purpose:**
Create subscription flows that convert without feeling pushy.

**Rules:**
- Allow user to experience value before paywall
- Show paywall after emotional investment
- Focus on identity and transformation, not features

**Paywall structure:**
1. Title: identity transformation
2. 3 benefits
3. Subscription options
4. Restore purchases
5. Continue free option if applicable

**Engineering:**
- Use StoreKit 2
- Support restore purchases
- Handle offline gracefully

**Avoid:**
- Aggressive blocking
- Dark patterns
- Feature comparison tables

### skill: viral_app_loop

**Purpose:**
Ensure the product loop supports viral content creation.

**Principles:**
Every user action should produce a shareable moment.

**Examples:**
- progress streak
- ritual completion
- focus timer ending
- answered prayer timeline

**Rules:**
- Design visually satisfying completion states
- Allow screenshot-worthy UI
- Use strong typography and spacing
- Favor bold visual states

**Goal:**
App interactions should easily become social media clips.

### skill: prayer_app_design_language

**Purpose:**
Create a calm, reverent, modern spiritual experience.

**Visual tone:**
- warm
- grounded
- reflective
- hopeful

**Colors:**
- Background: #EAE0C8
- Accent: #0F52BA
- Secondary: #9CBA8F
- Text: deep charcoal

**Typography:**
- Headers: editorial serif
- Body: clean sans-serif

**Layout rules:**
- generous spacing
- minimal UI chrome
- no clutter
- prayer text should breathe

**Animation:**
- slow and soft
- subtle fades
- no harsh motion

**Avoid:**
- church software aesthetics
- stained glass motifs
- overly religious iconography

### skill: prayer_app_product_logic

**Purpose:**
Define the product structure for the prayer app.

**Core concept:**
Prayer -> Action -> Reflection -> Timeline

**Main objects:**

`PrayerJourney`
- title
- category
- startDate

`PrayerEntry`
- prompt
- userReflection
- actionStep
- completed

`AnsweredPrayer`
- referencePrayer
- notes
- date

**DailyFlow:**
1. Show prayer prompt
2. Show action step
3. Allow reflection
4. Mark complete

**Rules:**
Daily flow should take under 60 seconds.

# Tend

**Subtitle:** pray. act. grow.

Tend is an iOS-first, private, offline-first Christian prayer app built around one daily rhythm:

**Pray -> Take one concrete step -> Reflect -> Track what changed over time.**

## Product concept (concise)
Tend helps users move from intention to faithful action in under a minute a day. It is not a social network or content library. It is a personal spiritual discipline tool focused on practical follow-through.

## MVP defaults
- SwiftUI app architecture
- SwiftData local persistence
- StoreKit 2 subscriptions
- Local notifications only
- No auth
- Minimal AI gateway backend on Vercel (`site/`) for model key security and orchestration

## Repository status
Planning docs and first-pass implementation scaffold are in place:
- `WalkWorthy.xcodeproj` + SwiftUI/SwiftData/StoreKit2 app skeleton
- `site/` Next.js legal/support website + AI gateway API routes for journey package generation

## Key docs
- [RFC](./docs/RFC.md)
- [Resource Request List](./docs/RESOURCE_REQUESTS.md)
- [Minimal Architecture](./docs/MINIMAL_ARCHITECTURE.md)
- [App Store Shipping Checklist](./docs/APP_STORE_SHIPPING_CHECKLIST.md)
- [App Store Metadata Requirements](./docs/APP_STORE_METADATA.md)
- [Test Plan](./docs/TEST_PLAN.md)
- [Risks](./docs/RISKS.md)
- [Vercel AI Gateway Deploy](./docs/VERCEL_AI_GATEWAY_DEPLOY.md)
- [Skills](./docs/skills/README.md)
- [Patch Tickets](./docs/patches)
- [Brand Guidelines](./docs/BRAND_GUIDELINES.md)
- [Brand Asset Drop Zone](./design/brand-assets/README.md)
- [Xcode Setup](./docs/XCODE_SETUP.md)

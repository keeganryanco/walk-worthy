# PATCH-002: Legal + Support Site

- **Status:** Implemented
- **Date:** March 12, 2026

## Goal
Add a minimal Next.js site containing Privacy Policy and Support pages for App Store URLs.

## Scope
- `site/` Next.js app
- `/privacy` page
- `/support` page with support email
- Minimal root route
- Vercel deploy instructions

## Acceptance
- `pnpm build` succeeds
- Vercel deployment produces live HTTPS URLs for privacy and support

## Notes
- `site/` Next.js app is scaffolded with `/privacy` and `/support`.
- Local `pnpm build` completed successfully.
- Live HTTPS URLs are pending Vercel deployment.

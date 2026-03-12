# Vercel Deploy: Privacy and Support URLs

## Goal
Deploy `site/` and produce final App Store URLs.

## Steps
1. Push this repository to a Git remote connected to Vercel.
2. In Vercel, import project.
3. Set **Root Directory** to `site`.
4. Install command: `pnpm install`.
5. Build command: `pnpm build`.
6. Deploy.

## Required final URLs
- Privacy Policy URL: `https://<your-vercel-domain>/privacy`
- Support URL: `https://<your-vercel-domain>/support`

## After deployment
Update:
- [RESOURCE_REQUESTS.md](./RESOURCE_REQUESTS.md)
- App Store Connect metadata
- iOS app settings/support links

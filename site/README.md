# Walk Worthy Legal Site

Minimal Next.js site for App Store-required URLs.

## Routes
- `/privacy`
- `/support`

## Local development
```bash
pnpm install
pnpm dev
```

Optional analytics (Google Analytics 4):

```bash
export NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
```

## Build
```bash
pnpm build
pnpm start
```

## Deploy to Vercel
1. Import this repo in Vercel.
2. Set Root Directory to `site`.
3. Build command: `pnpm build`
4. Output: default Next.js output
5. Deploy.

After deploy, set App Store URLs to:
- Privacy Policy URL: `https://<vercel-domain>/privacy`
- Support URL: `https://<vercel-domain>/support`

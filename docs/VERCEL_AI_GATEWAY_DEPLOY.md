# Vercel AI Gateway Deploy (Subfolder: `site`)

## Goal
Deploy the legal pages (`/privacy`, `/support`) and AI gateway (`/api/v1/journey-package`) from a single Vercel project using only the `site` subfolder.

## 1. Create project in Vercel
1. In Vercel, click **Add New Project** and import this GitHub repo.
2. In project setup, set **Root Directory** to `site`.
3. Framework preset should auto-detect as **Next.js**.
4. Keep build settings:
- Install command: `pnpm install`
- Build command: `pnpm build`
- Output: default Next.js output

## 2. Add environment variables
In **Project Settings -> Environment Variables**, add:

Required:
- `OPENAI_API_KEY`
- `GEMINI_API_KEY`

Recommended:
- `TEND_APP_SHARED_SECRET` (random long secret used by iOS app header)

Optional model overrides:
- `OPENAI_PRIMARY_MODEL` (`gpt-5-mini`)
- `OPENAI_ESCALATION_MODEL` (`gpt-5.1`)
- `GEMINI_PRIMARY_MODEL` (`gemini-2.5-flash`)

## 3. Deploy
1. Click **Deploy**.
2. After deploy, note production URL, e.g. `https://tend-app.vercel.app`.

## 4. Smoke test API
Run locally from terminal:

```bash
curl -X POST "https://<your-vercel-domain>/api/v1/journey-package" \
  -H "Content-Type: application/json" \
  -H "x-tend-app-key: <TEND_APP_SHARED_SECRET>" \
  -d '{
    "profile": {"prayerFocus": "purpose", "growthGoal": "consistency"},
    "journey": {"id": "j1", "title": "Launch Tend", "category": "purpose"},
    "memory": {"summary": "User is building steadily"},
    "recentEntries": []
  }'
```

Expected:
- JSON response with `package` and `meta`.

## 5. Wire iOS app config
Set these values in iOS Info.plist (or build settings):
- `TENDAIBaseURL` = `https://<your-vercel-domain>`
- `TENDAIAppKey` = same value as `TEND_APP_SHARED_SECRET`

## 6. App Store URL mapping
- Privacy URL: `https://<your-vercel-domain>/privacy`
- Support URL: `https://<your-vercel-domain>/support`

## Notes
- You are not deploying the whole repo runtime, only `site/`.
- iOS app remains a separate build/release process via Xcode.

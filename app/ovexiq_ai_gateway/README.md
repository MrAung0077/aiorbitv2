# Ovexiq AI Gateway

Minimal Cloudflare Worker gateway for the Ovexiq private beta. Provider API
keys stay in Worker secrets and are never included in Flutter builds.

## Local test

```powershell
npm install
npm test
npm run check
```

For local manual requests, copy `.dev.vars.example` to `.dev.vars`, replace the
placeholders, and run `npm run dev`. Never commit `.dev.vars`. `OPENROUTER_API_KEY`
is a Worker secret used only for a single fallback attempt after a transient
primary-provider failure; it is never sent to Flutter.

`OVEXIQ_BETA_TOKENS` is a JSON object mapping tester IDs to revocable tokens.
These tokens identify a tester for rate limiting; they are shipped in beta apps
and are not trusted secrets or authority for unlimited provider spend.

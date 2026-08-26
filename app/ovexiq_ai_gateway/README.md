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

## Private-beta spend controls

The gateway keeps the existing per-minute limits and adds durable UTC-day caps:

- Per tester: 20 text requests and 2 image requests.
- Entire beta: 30 text requests and 3 image requests.

The quota is consumed only after request validation and before a provider call.
When exhausted, the gateway returns a safe `429 beta_limit_reached` response.

The gateway also has a server-side emergency deny switch. Set the Worker secret
`OVEXIQ_BETA_AI_DISABLED` to `true` to reject text and image requests with a
safe temporary-unavailable response before authentication, quotas, or provider
calls. See [BETA_RUNBOOK.md](./BETA_RUNBOOK.md) for the operating procedure.

`npm run test:runtime` starts an isolated local Workerd/Miniflare Worker with
fake beta tokens and no provider keys. It exercises the configured Durable
Object binding and concurrency behavior without making a provider request.

### Emergency access control

- To revoke one tester, edit the Worker secret `OVEXIQ_BETA_TOKENS` in the
  Cloudflare dashboard and remove that tester's entry. Save the secret, then
  verify the token receives `401`.
- To stop all beta access, replace `OVEXIQ_BETA_TOKENS` with `{}` in the same
  Worker secret. All requests then receive `401` before rate limits or providers.
- Keep the provider keys as separate Worker secrets. Do not put them in the
  Flutter app, source control, or the beta-token secret.

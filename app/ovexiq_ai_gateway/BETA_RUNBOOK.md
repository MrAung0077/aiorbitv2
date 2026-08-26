# Ovexiq private-beta emergency runbook

Use the Cloudflare dashboard or Wrangler from `ovexiq_ai_gateway`. Enter
secret values only at Wrangler's interactive prompt. Do not put secrets in a
command, shell history, source file, or ticket.

## Stop all paid AI requests now

1. Set the Worker secret `OVEXIQ_BETA_AI_DISABLED` to `true`.

   ```powershell
   npx wrangler secret put OVEXIQ_BETA_AI_DISABLED
   ```

2. Confirm a text and image request return `503` with
   `beta_temporarily_unavailable`. This does not require a Flutter app release.
3. In Workers Logs, confirm new `ovexiq_ai_request` events have rejection
   `beta_temporarily_unavailable` and no provider latency.

## Revoke one tester

1. Retrieve the current `OVEXIQ_BETA_TOKENS` JSON only from the approved secret
   manager or Cloudflare dashboard.
2. Remove that tester's entry, then update the Worker secret interactively:

   ```powershell
   npx wrangler secret put OVEXIQ_BETA_TOKENS
   ```

3. Confirm the old token receives `401`. Never paste the token into logs or a
   test command.

## Provider emergency stop

1. Enable the global deny switch first.
2. In each provider dashboard, disable the project or revoke/rotate its API
   key according to that provider's emergency procedure.
3. If needed, remove the corresponding Worker secret after the deny switch is
   active:

   ```powershell
   npx wrangler secret delete OPENAI_API_KEY
   npx wrangler secret delete OPENROUTER_API_KEY
   ```

## Check beta activity

- Open the Worker’s **Workers Logs** view and filter custom JSON events where
  `event` is `ovexiq_ai_request`.
- Use `requestId` to trace one request. `testerIdHash` is intentionally a
  short SHA-256-derived identifier, not a beta token.
- Review `endpoint`, `capability`, `status`, `rejection`, and optional
  `providerLatencyMs`. Prompts, generated content, provider keys, and beta
  tokens must never appear in this event.

## Restore service

1. Restore/rotate provider keys in the provider dashboards and Worker secrets
   if they were disabled or deleted.
2. Set `OVEXIQ_BETA_AI_DISABLED` to `false` using the interactive secret
   command above.
3. Verify one approved, non-production test request through the intended
   staging Worker before reopening beta access.
4. Watch Workers Logs and provider usage for the first few requests.

## Required staging verification before expanding beta

The local Workerd test is strong but is not a Cloudflare edge deployment. This
repository does not yet define a separate staging Worker/route, so do not point
the production route at a test deployment. After an approved staging
environment is configured with isolated secrets and a non-production route,
run:

```powershell
npx wrangler deploy --env staging
```

Then send only invalid-token and deny-switch checks, followed by a quota test
with provider keys intentionally absent. Do not run this command or any paid
provider request without explicit deployment approval.

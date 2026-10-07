# Original song workflow — Android first, shared backend

Implementation foundation, not a completed production/device acceptance run. No paid generation is part of automated tests.

## Execution target

Android (and a future Web client) -> existing Ovexiq Worker/session boundary -> dedicated Linux media service -> text song specification -> Gemini music generation -> server FFmpeg -> persistent server artifact storage -> authenticated download to client.

There is no Windows-local production executor, browser FFmpeg, or Android FFmpeg dependency. A Web UI is not included: it must use this same job/artifact API. The Cloudflare skill review informed the fail-closed proxy, server-derived ownership and unchanged existing Durable Object bindings/migrations.

The media service needs **one replica, one process, an exclusive durable volume, and restart-not-overlap deployments**. Do not autoscale this SQLite worker or share its volume between live replicas. Hosting is not provisioned by this patch. Use a Linux container host supporting persistent volumes and HTTPS ingress. Container-local ephemeral storage alone is not acceptable. Back up the SQLite database and artifact volume consistently; restrict access to the service and storage.

## Contracts and separation

- `MusicGenerationProvider`: `generateSong(spec, artist, requirement)`, `supportsLanguage(language)`, `capabilities`, `providerId`.
- First adapter: official Gemini `lyria-3.5:generateContent`, custom lyrics/style/language as documented text input, MP3 inline data. No unofficial API or scraping. Reference: https://ai.google.dev/gemini-api/docs/generate-content/music-generation
- Song specification: one existing-model OpenRouter `openai/gpt-6-astra` request, JSON, maximum 4096 output tokens; separate English/Burmese lyric instructions. This new capability does not modify existing Chat model routing.
- Stable fictional artist: name, ID, male vocal register/timbre/delivery/range, genre family, four owner-scoped visual IDs, supported request languages. Each project snapshots the profile. Voice direction is **not** a guaranteed cloned voice; actual consistency and Burmese singing require listening review. The provider interface permits a later audio transformation stage without changing client artifacts; voice conversion is not implemented.
- Durable `SongProject`: id, original goal/language, title/theme/genre/mood/tempo, lyrics/music prompt, artist snapshot, audio/video artifacts, status, fixed typed failure, internal provider metadata. Project data is server-side SQLite, separate from unchanged Flutter conversation/Mission schemas.
- Capability/preflight, provider adapter, execution, rendering and artifact validation are separate modules. Provider output is not treated as a finished MP4.

### Shared API

All client requests use the existing beta token and opaque device-session headers. Ownership is derived at the Worker; any client owner/account header is discarded. Provider/service keys never enter Flutter. Production media is disabled unless explicitly provisioned and the authenticated account is allowlisted.

| Method/path | Meaning |
|---|---|
| `GET /v1/media/artist` | Saved reusable profile |
| `POST /v1/media/visuals` | JSON `{mimeType,data}`; base64 JPEG/PNG, maximum 8 MiB; server validates/normalizes image |
| `PUT /v1/media/artist` | `{artistName,visualReferenceIds}`; exactly four distinct owned images |
| `POST /v1/media/projects` | `{requestId,goal,language,preferences?}`; UUID idempotency key; `language` is `en` or `my`; returns persisted job, not a long-held generation request |
| `GET /v1/media/projects` | Newest 100 owned projects; never executes/retries |
| `GET /v1/media/projects/{id}` | Status and artifacts |
| `PUT /v1/media/projects/{id}` | `{action:"approve_final",selectedArtifactIds:[...]}`; owner-scoped, completed outputs only; idempotent creative approval, never a grant of commercial rights |
| `GET /v1/media/projects/{id}/artifacts/{artifactId}` | Private authenticated bytes; MIME, length, SHA-256; no external URL handoff |

Same request ID and payload return the existing project. A changed payload with that ID fails. One active project per account; maximum two new projects/account/UTC day; one globally executing job in this service. Existing text/image/speech quotas and limits are unchanged. This is a separately operator-enabled personal capability, **not** access to paid media for every beta token holder.

States: `queued -> specifying -> generating -> rendering -> completed`, or `failed`/`interrupted`. New jobs use the durable stage/attempt records described below. Expired leases recover persisted results and safe local work. Legacy active projects without durable checkpoints remain interrupted. Unknown live-provider outcomes require review and never auto-resubmit. History GETs never dispatch work. There are no automatic paid retries/fallbacks. Server failures preserve already validated outputs.

## Durable song foundation (Phase 1)

HTTP 202 follows one SQLite transaction creating the project and its separate workflow job. `(owner, request_id)` remains the submission deduplication boundary. Duplicate requests are checked before renderer preflight, so lost acknowledgements can recover during a renderer outage. Image-permission declarations join the existing input conflict checks; artist/reference snapshots are captured on first acceptance. Existing project and artifact URLs remain compatible.

`media_jobs`, `media_stages`, `media_attempts`, `media_artifacts` and `media_outbox` are additive tables in the same database. Project ID, workflow job ID, stage ID, attempt ID, external provider ID, artifact ID, artifact version ID and submission key have distinct meanings and identities. Each provider stage has one persisted attempt; lease recovery continues that attempt instead of creating another paid attempt. Local retries retain the stage identity and record a bounded failure count.

Claims use `BEGIN IMMEDIATE`, a random ownership token, a 30-second renewable lease, and a ready-at timestamp. Every execution checkpoint, result publication, final-file publication and terminal transition checks the current token and lease inside a transaction. Stale workers may finish writing their private temporary files but cannot publish them or commit state. SQLite uses WAL, FULL synchronization and a busy timeout. This is coordination on one filesystem/database, not a distributed queue. The existing single-host volume and deployment constraints still apply.

Before provider dispatch, attempts retain the selected route, immutable inputs, prompt/instruction, source IDs, rights evidence, provider/model/API information when known, workflow version, timestamps, lease information and billing/uncertainty state. Current live Lyria and song-spec adapters remain synchronous and unchanged. Known model names are implementation snapshots, not evidence of external service availability. A completed response is flushed to a checksummed private result spool before downstream assembly. Restart reuses that result. A lost live response with no recoverable result becomes `failed` with `reviewRequired=true` and job status `uncertain`; it is never automatically submitted again. No Lyria lookup semantics are invented. Unknown billing remains unknown even when output exists.

Only adapters explicitly implementing the internal idempotent-submit/lookup protocol can reconcile asynchronous work. The only such implementation added here is `test/fixtures/synthetic_media_provider.js`, which is never imported by the production server or copied into its image. Its separate SQLite database retains idempotency keys, external execution IDs, completion time and deterministic output. It models delayed completion without timers or networking: elapsed provider time becomes observable through lookup. Its billing state is always not-applicable.

Artifact IDs/version IDs are reserved before publication. The worker writes a lease-specific temporary output, validates it through the unchanged renderer, flushes bytes, writes a checksummed receipt, and publishes under the lease fence. A recovery that finds a valid final file and receipt registers the same reserved artifact without rerendering it. A unique `(stage_id, slot)` constraint prevents duplicate registration. Source-artifact and producing-stage references accompany each artifact. Partial unpublished output can be rebuilt; completed upstream provider results are reused. Local failure permits at most two additional local tries, spaced five seconds apart; exhaustion becomes terminal failure. This is not a new paid retry policy.

Terminal project state and one uniquely job-keyed outbox event commit together. Events include project/job IDs, success/failure/review state and ready artifact IDs. The test consumer demonstrates at-least-once delivery with consumer deduplication by event ID. There is no push service, device-token registration, notification permission flow or new notification UI.

Provider results may include `artifacts: []` with zero, one or many descriptors and an optional `primaryArtifactKey`. Each descriptor has a stable execution-local `key`, an open semantic `role` (for example `converted_vocal`, `backing`, `combined_mix`, `stem` or `master`), `mimeType`, optional `extension`, `mediaType`, `format`, `codec`, `technicalMetadata`, `sourceArtifactIds`, and optional expected `sha256`. Several artifacts may share a role. There is no fixed output count, filename, codec, backing-track requirement or combined-mix requirement. Legacy byte-only adapters remain compatible.

Descriptors contain inline bytes or adapter-owned locators. The existing execution boundary can implement `durableExecution.captureArtifact({ externalExecutionId, artifact })` to return bytes; orchestration never fetches arbitrary provider URLs itself. The private result spool retains discovery metadata. Each output then receives its own reserved artifact/version IDs and local capture stage, hashed local filename, producing stage/attempt references, source references, provider execution provenance and an Ovexiq `storageReference` of project/artifact IDs. Downloads use the existing authenticated artifact route. Size and any supplied hash are checked during capture; the selected audio is also validated by the unchanged renderer. Technical metadata for other outputs is adapter-supplied, not independently codec-verified in this slice.

Provider status may be completed while the durable attempt remains `capturing`. Every listed output is conservatively captured before the attempt becomes completed, including outputs marked `required: false`; optional-output skipping is not implemented. Temporary URLs alone never satisfy completion. Partial capture retries only local retrieval/publication and never repeats generation. Reconciliation verifies owned files and reuses registrations even after provider URLs expire. Lost URLs before capture can still prevent completion; no live URL-refresh integration is claimed.

The Song workflow retains all captured music/conversion artifacts and uses an explicitly selected primary audio directly for rendering. A collection without primary audio is valid at the execution layer but cannot finish this original-song workflow. Selecting the primary does not discard stems or other production artifacts. Flutter accepts safe generated filenames and typed MIME values, retains artifact metadata, and no longer assumes exactly four artifacts or MP3 primary audio. There is no mandatory mix/master stage: an acceptable combined result can be used immediately; future lossless assembly or requested/QC-driven repair can consume preserved source artifacts without a schema change. These later orchestration choices are not implemented here.

Flutter stores an append-only, flushed submission journal before POST. Records retain the exact JSON request, stable request ID, creation time, acknowledgement state and returned project ID. The journal is scoped by server origin and the existing non-secret account reference; no token/session secret is written. API operations serialize journal access. An unresolved submission cannot be replaced by an edited request or new key. Reopen/resume recovers the same saved POST if acknowledgement is missing, or GETs the acknowledged project. Failed refreshes retry while the screen exists; the server needs neither this timer nor a foreground client. Existing Android hash-checked download/open/save/share behavior is unchanged. Legacy artifacts without a version ID receive an explicitly legacy-namespaced client version reference.

### Proof and limits

Run from `app/media_backend`: `node --test test/durable_jobs.test.js`, then `npm test`. The deterministic matrix covers acknowledged/disconnected clients, duplicate submission, lost acknowledgement, restart before dispatch/after acceptance/after external-ID persistence/after result storage/during rendering, local-only retry, lease exclusion/takeover/stale fencing, passive reads, unknown live-style outcomes, stable artifact IDs/hashes, durable events and authenticated downloads. One test exits an actual child process immediately after synthetic provider acceptance, then recovers the same external execution.

Flutter Song tests cover a real local journal reopened by a new API/store instance, exact replay after an unobserved response, persisted acknowledgement/project ID, rejection of replacement keys, account isolation, storage failure before POST, lifecycle refresh, and the existing native file-action contract. They do not establish physical-device playback/share acceptance.

Multi-artifact tests use the same persistent synthetic provider, with a combined Ogg/Opus preview, a FLAC converted vocal, and WAV/FLAC stems. They crash during publication/capture, reopen storage, verify all identities/hashes/provenance, expire synthetic provider outputs, repeat capture without generation, and retrieve every production output over authenticated HTTP. Zero/one-output and inline-byte cases are also covered. Synthetic bytes prove storage/recovery contracts, not valid codecs or audible quality.

The existing manual `.github/workflows/media-render-smoke.yml` (`Media render smoke (synthetic only)`) already invokes `test/render_smoke.test.js` on Ubuntu 24.04 in the existing network-disabled Docker image, so no workflow YAML change is necessary. The smoke retains a real synthetic MP3 primary and an independent real FLAC production stem from one persistent synthetic execution; the unchanged renderer consumes the selected MP3. This does not prove arbitrary primary codecs or lossless assembly.

Recovery boundaries are explicit: first interrupt after provider acceptance before its identity is committed; then inject a worker exception after the real landscape encode, FFprobe validation and full decode finish at a private temporary path, before publication/registration. Close/reopen SQLite and the synthetic provider, expire the lease, and resume. The smoke deletes synthetic provider output locators after audio capture, requiring recovery from owned inputs. Only the local landscape render repeats. A further interruption after final landscape publication but before registration checks receipt recovery without another render. Assertions require exactly two landscape renders, one portrait render, one upstream execution, one text call, five distinct registered artifacts and one completion event. This is deterministic worker/store restart simulation, not a killed operating-system process or an interrupted FFmpeg child.

Both final MP4s must pass real FFprobe dimensions/H.264/AAC/duration checks and full FFmpeg decode. Both audio files also undergo real codec/duration/decode checks. A later reopen/scheduler tick preserves all IDs/hashes without rendering; the keyless real service must serve canonical history and authenticated downloads for every artifact, with byte count, MIME and SHA-256 checks. The smoke report records recovery boundaries, render counts and validated artifact metadata. The existing workflow retains MP4s, raw MP4 FFprobe reports and the smoke report. An available Linux/Docker environment is required; a skipped test is not rendering proof. No remote workflow is triggered by local tests.

Not proven by this foundation: live provider reconciliation/idempotency, real music quality, physical-device background/reopen/open/share behavior, push delivery, power-loss/storage-loss recovery, shared network filesystems, or production hosting capacity. Protect and back up the whole data volume, including `.executions` and artifact receipts. Old abandoned temporary files and submission journals are retained; retention/garbage collection is outside this slice.

### Song routing foundation

`preferences` lives in the existing project JSON (no SQL migration): `voiceIntent` (`generated`, `reusable_identity`, `own_voice_clone`, `custom_locked_voice`), `subtitles` (`off` / `requested`), `context` (`single_song`, `reusable_artist`, `album`), optional `style` / `userFinalLyrics`, and `voicePermissionConfirmed`. Old jobs default to generated voice, single-song context and no subtitles. Preferences are part of idempotency matching. Clients choose outcomes, not providers.

`song_routing.js` filters server-registered candidates by language, availability, voice capability and supplied lyric limits, then prefers operator-reviewed quality, reliability, latency and cost, in that order. No dynamic quality scoring or live capability discovery is claimed. The original artist snapshot and routing requirement reach the selected adapter.

Voice operations are distinct: `GENERATED_VOICE`, `VOICE_CONDITIONED_GENERATION`, `TRUE_VOICE_CLONE`, and `VOICE_CONVERSION`. Existing persisted `VoiceIntent` values remain outcome keys, not capability claims. Legacy `reusableSingerIdentity` maps only to conditioning. Standard songs use generation only; fictional singer consistency uses a supported reference/reusable voice without a clone stage. Neither promises likeness to a real person.

Own/custom identity requests require both explicit clone and conversion capabilities. `SingingVoiceProvider.createVoiceProfile(request)` prepares the authorized reusable identity; `convertVoice(audio, profile, request)` converts an already-generated performance. The old ambiguous `convertOrClone` contract is not accepted. Compatible high-fidelity routes rank above approximate/unspecified routes before the existing quality/cost tie-breakers. This is operator-declared capability metadata, not a measured or guaranteed quality score.

Conversion adapters declare `conversionInput` (`complete_song` or `vocal_stem`) and `returnsFinalMix: true`. Stem routes require a music adapter declaring `vocalStemOutput` and returning `vocalSource.bytes`; absent source stops without conversion. Isolation/recombination belongs to a future capable adapter, not the FFmpeg renderer. No live clone, conversion or conditioned-generation adapter is supplied here.

Internal route snapshots retain `billingUnit`, `estimatedCostClass`, `exportQuotaLimited`, `conversionRequired` and `identityFidelityClass` (`unspecified`, `character_consistency`, `approximate_identity`, `high_fidelity_identity`). Missing data stays unspecified; there are no vendor prices or quota entitlements inferred from these labels. Real export quota/budget enforcement remains a future adapter prerequisite.

Own/other identity stages require the existing permission declaration before any paid stage. Conditioning is treated as real-person reference unless the server capability explicitly declares `referenceVoiceUsesRealPerson: false`; the current reusable-singer UI is for fictional consistency, not uploading a real-person reference. Internal provenance retains declarations, profile/source dependencies, operation metadata and provider-rights snapshots. Other-person commercial readiness additionally requires trusted operator `rightsContext.voiceAuthorizationVerified` plus `voiceAuthorizationEvidenceId`; client declarations alone do not suffice. Profile creation permission and output commercialization remain separate, and missing profile rights stay review-required. No new table/schema or automatic history execution is introduced.

No real voice-conversion adapter or subtitle alignment renderer is included. The current music adapter does **not** advertise reusable singer identity. These unavailable requests stop in preflight before paid stages, rather than silently degrading. Subtitles remain off for both videos. `subtitleWork` prepares an alignment requirement only when explicitly requested: user final lyrics, otherwise generated final lyrics, verbatim; ASR is never canonical text. Future alignment/voice adapters need their own bounded execution, consent/input validation and spend approval before enabling them.

`songRecoveryDecision` is policy only, not an automatic retry executor. It can offer one capable alternate (or a manual retry) only for an allowlisted typed execution failure, explicit approval and a known unbilled outcome. Cancellation, aesthetic rejection, unknown billing and an exhausted attempt budget stop recovery. It never invokes a provider or changes the current no-replay behavior.

### Creative provenance and commercial-use review

Creation accepts optional `commercialUseRequested` (default false), captured by the Song screen, and `imagePermissionsDeclared` for the current image-use confirmation. Upload-time confirmation is also retained as `permissionsDeclared` in the artist snapshot. Neither declaration grants or verifies commercial rights. No license/plan is assumed for the current providers or user inputs: rights default to `unknown`.

The existing project JSON holds append-only contribution records (type/source/time/reference and user/generated flags), exact lyric-version snapshots, asset-rights records and a final `manifest`. No table migration, file-layout change or provider call is involved. Initial goal, supplied lyrics/style, chosen voice/images, generated lyrics/title/structure/chorus suggestion and assembled versions are recorded at their existing workflow boundaries. A generated chorus suggestion is not recorded as a user-selected hook. Revisions retain their parent/source; the helper supports edits/revision notes, but no new natural-language revision parser or song editor is introduced. UI final approval explicitly records user selection plus approval; generation success/history reads are never approval.

The internal manifest contains project identity/title/time, final lyrics source/hash, contribution summary and records, asset rights and dependencies, selected version IDs/hashes, voice/subtitle preferences, final approval and commercial readiness. Provider/plan/terms detail stays internal; ordinary clients receive only `provenanceSummary` and fixed factual review reasons. No copyright ownership or copyrightability determination is made. Human direction is recorded, not legally scored.

For commercial projects, final outputs and their transitive source dependencies must all have documented `allowed` status. `nonCommercial`, `blocked`, `conditional`, missing records or `unknown` require `COMMERCIAL_REVIEW_REQUIRED`; nothing is deleted and completed files remain usable. Rejected/unreferenced draft takes do not block selected outputs. Final creative approval is additionally required, and cannot override rights. Local render rights derive from source records, not from rendering success. Generated-asset eligibility now comes from the verified registry below, not adapter `commercialRights` declarations. Raw model/provider responses and client-supplied status/manifest fields cannot grant eligibility.

### Provider rights registry (verified 2026-10-03)

`provider_rights_registry.js` stores dated, inactive-able provider/product/plan/mode rules with official source references, verification notes, restrictions and review deadlines. `resolveCommercialRights` is network-free and returns status, rule ID, reason codes, an evidence snapshot and `requiresReview`. No account lookup, new adapter or scraping is implemented.

Initial evidence: [official terms, effective 2026-09-03](https://suno.com/terms/), with [subscription continuity](https://help.suno.com/en/articles/2425729) and [paid download guidance](https://help.suno.com/en/articles/9601665). Paid outputs require historical subscription and permitted-download evidence; Basic/free and remix cases remain non-commercial. Voice-model compatibility is own-voice only; permission to create a model is not a license to commercialize the model itself. Copyright remains undetermined. These rules cover the stated service cases, not enterprise exceptions or an integration/API license.

Only trusted server/operator `rightsContext` may supply `product`, **plan at generation**, `generationMode`, `subscribedAtGeneration`, and `downloadedThroughApprovedChannel`. The last field means a verified permitted tier download, not merely that Ovexiq saved a file. Current subscription expiry is not used to revoke a qualified historical output. Ambiguous modes/plans, unsupported services/providers and pre-effective-date generations fail closed. Current music/text adapters have no verified registry entries, so remain unknown; no unverified provider rules were added.

The workflow records a rights review before each paid stage and snapshots the resolution on each generated asset, including `matchingRuleId`. Unknown/conditional evidence does not prevent personal generation, but cannot yield commercial-ready status. Explicitly incompatible voice requests are stopped before paid stages. Publication remains unimplemented and must use `commercialReadiness` before any future commercial action.

Initial `reviewAfter` is **2026-11-02 UTC**, a 30-day Ovexiq review policy, not legal expiry of acquired rights. New resolutions after that boundary require review. Current-readiness checks detect missing, changed, inactive, stale or incompatible evidence while leaving asset records and the historical manifest unchanged. Registry updates require manual official-source review and a new dated rule/version; there is no runtime fetch or automatic update. Adding evidence later must be an explicit review action, not a silent historical rewrite. An operator entitlement/approved-download evidence workflow is still needed before real outputs can qualify.

## Provider capability and evaluation registry (operator-only)

`src/provider_evaluation_registry.js` keeps capability profiles separate from dated observations. There are **no prefilled real-provider profiles/ratings** and no network discovery. Supporting a language or voice operation does not establish good pronunciation or likeness. Unknown fields use `null`/`unknown`, not an inferred capability, price or unlimited quota.

Use `tools/provider-registry.js` with a private operator-owned directory outside Git/project artifact storage. Protect it with OS permissions; never put credentials, private prompts/audio, signed URLs or passwords in records. Strict schemas reject extra fields and common credential patterns; the command never echoes records. This is defense in depth, not a guarantee that arbitrary notes are secret-free. Storage is append-only UTF-8 JSONL with unique IDs and a single-writer lock. `readProviderRegistry(directory)` loads validated profiles/evaluations for trusted callers. No endpoint/admin UI is added.

```powershell
# From app/media_backend; variables refer to operator-owned paths, not secrets.
node tools/provider-registry.js $registryDirectory profile $profileJsonPath
node tools/provider-registry.js $registryDirectory evaluation $evaluationJsonPath
```

**Synthetic schema examples only**, not provider evidence. Replace with actual independently verified facts/observations before recording; sample IDs reference separately retained safe evidence:

```json
{
  "profileId": "example-profile-1", "providerId": "example-provider",
  "capability": "full_song_generation", "supportedLanguages": null,
  "voiceCapabilities": null, "inputTypes": null, "outputTypes": null,
  "maxDuration": null, "billingUnit": null, "quotaLimited": null,
  "commercialRightsRuleIds": [], "apiAvailability": "unknown",
  "verifiedAt": "2026-10-03T00:00:00Z",
  "evidenceSource": {"type": "operator_verified", "reference": "replace-with-evidence-reference"},
  "active": false
}
```

```json
{
  "evaluationId": "example-evaluation-1", "providerId": "example-provider",
  "capability": "full_song_generation", "testedAt": "2026-10-03T00:00:00Z",
  "language": "my", "style": null, "sourceType": "manual_test",
  "quality": "unknown", "identityLikeness": "unknown", "pronunciation": "unknown",
  "artifacts": "unknown", "latencyMs": null, "workflowFriction": "unknown",
  "quotaCostObservation": {"quotaType": null, "quotaRemaining": null, "quotaWindow": null,
    "billingUnit": null, "observedEffectiveCost": null, "costEvidenceDate": null},
  "sampleReferenceIds": [], "operatorNotes": "Replace with factual test notes only.",
  "confidence": "single_test", "repeatCount": 1, "active": false
}
```

Quality uses unknown/poor/acceptable/good/excellent; likeness uses not_applicable/unknown/weak/moderate/strong; pronunciation uses unknown/problematic/mixed/good; friction uses unknown/low/medium/high. Confidence is single_test/repeated_observation/well_established; repeated labels require more than one test. Observed costs use `{amount,currency}` plus cost evidence date and billing unit, not a current quote. No numeric quality scores are accepted.

For a provider/capability, the newest dated profile controls availability; inactive/ambiguous profiles fail closed. A newer inactive evaluation retires earlier matching provider/capability/language/style observations without deleting them. Ranking chooses higher-confidence task-matching evidence before recency, then compares quality/pronunciation (identity likeness first for high-likeness tasks). Confidence/reliability and finally cost break ties. No global winner exists. Operators must review dates and retire obsolete observations; automatic freshness checks are not implemented.

`planSongRoute(requirement, candidates, voiceCandidates, evidence)` optionally accepts `{registry,musicRequest,voiceRequest}`. The registry combines loaded records with trusted current `constraints` keyed by provider. Requests provide approved stage budget `{amount,currency}`, commercial requirement, desired fidelity, optional duration/style and real-voice context. The planner supplies actual language, task capability and permission declaration; adapter gates still run. Existing APIs do not accept these internal evidence/budget fields from clients.

Constraints require available status, finite `quotaRemaining`, positive `requiredUnits`, matching `billingUnit`, future `validUntil`, bounded `estimatedCost` and currency. Reliability may be unknown/unreliable/mixed/reliable. Unknown/exhausted/expired quota or unapproved cost excludes a route; historical export-minute observations never authorize new usage. Profile rights-rule IDs do not grant rights: commercial requests use the existing resolver; real-person requests retain permission/evidence gates.

Internal decisions retain copied evidence, IDs, requirements, reasons, cost/quota bounds and rights verification. Ordinary UX receives only a fixed neutral availability code, never provider names/notes. This optional path is **not wired into live execution**: current quotas/providers/spend authority are unchanged. Before enabling it, trusted orchestration must supply current bounds, reserve combined multi-stage spend/quota, persist the selected decision, and validate entitlements. Existing routing is unchanged when no evidence context is supplied.

## Server rendering and artifacts

Four supplied artist stills, slow zoom/crop and short crossfades. Full-song MP4 is 16:9, 1920x1080 when every image's smaller dimension is at least 1080, otherwise 1280x720. Portrait teaser is 1080x1920 or 720x1280, 30 seconds. H.264/yuv420p + AAC stereo 44.1 kHz, faststart, fade out. FFprobe plus full decode validates duration/codecs/dimensions; missing FFmpeg fails preflight before paid work.

**Hook-selection limitation:** teaser starts at the song specification's suggested chorus time, clamped to the actual audio duration. It is not verified audio alignment or strongest-hook detection. Metadata explicitly marks listening review required. No claim that a text-estimated timestamp is the sung chorus.

Server volume layout:

```
MEDIA_DATA_DIR/media.sqlite
MEDIA_DATA_DIR/visuals/{image-id}.jpg
MEDIA_DATA_DIR/{project-id}/lyrics.txt
MEDIA_DATA_DIR/{project-id}/song.mp3
MEDIA_DATA_DIR/{project-id}/youtube.mp4
MEDIA_DATA_DIR/{project-id}/teaser.mp4
```

Client metadata is adapted to the existing `ArtifactVersion` type. Android caches private files in its application documents `song_artifacts/{project-id}/` directory. Native SHA-256 validation happens before use. Open/save/share use Android content URIs and `Downloads/Ovexiq`, never a credential-bearing browser URL. Deleted public downloads can be recreated from the private cache. Corrupt private cache entries are redownloaded.

The native MediaStore path currently targets **Android 10/API 29+**; older Android fails safely and is not accepted for this workflow yet. The existing app minSdk is unchanged. Opening requires an installed compatible audio/video viewer; Share uses the system chooser. No physical-device acceptance is claimed by widget/channel mocks.

## Required configuration (names only, never commit values)

Media container runtime, injected by host secret management. Only the storage directory and service credential are mandatory at boot; each paid adapter checks its own key at invocation:

- `GEMINI_API_KEY`: needed only for the music-generation stage; paid Gemini project with access to `lyria-3.5`. Not needed for boot, artifact reads or synthetic rendering.
- `OPENROUTER_API_KEY`: needed only for the planning/lyrics stage; authorized access to the existing song-spec model. Not needed for boot, artifact reads or synthetic rendering.
- `OVEXIQ_MEDIA_SERVICE_KEY`: high-entropy shared service credential, at least 32 characters, identical at Worker and media service.
- `MEDIA_DATA_DIR=/data`: durable, private volume writable by container uid 1000.
- `PORT=8080` (default).

Worker runtime configuration (new, absent means disabled):

- `OVEXIQ_MEDIA_ENABLED=true`
- `OVEXIQ_MEDIA_ORIGIN`: HTTPS origin of the container's ingress, no path/query/credentials.
- `OVEXIQ_MEDIA_ALLOWED_ACCOUNTS`: JSON array of operator-approved `acct_<UUID>` values, initially the owner's account only.
- `OVEXIQ_MEDIA_SERVICE_KEY`: secret above, never in `wrangler.jsonc`.
- `OVEXIQ_MEDIA_WEB_ORIGIN`: optional exact HTTPS origin for the future Web client, no wildcard.

Existing beta-token/session/invite/signing/provider configuration and Durable Object migrations must be preserved. No secret rotation is needed. Existing beta-AI emergency-disable configuration also disables the media proxy. Disable the container scheduler as well to stop already queued work; this is not provider in-flight cancellation.

Android uses its existing production base URL, beta token and secure device-session storage. No new paid-provider key is supplied in Dart defines. HTTPS network only. Do not put service/provider secrets in build arguments, logs, APKs or source.

## Validation and container commands

From `app/media_backend`:

```powershell
npm test
docker build -t ovexiq-media:local .
docker run --rm --network none -e MEDIA_RENDER_SMOKE=1 --mount "type=bind,source=$($PWD.Path)\test,target=/app/test,readonly" ovexiq-media:local node --test test/render_smoke.test.js
```

The render smoke uses four synthetic color cards and a sine wave. It requires no secret or provider/network access. Do not treat it as music quality acceptance. Docker must already be available on the validation host. The production Docker image installs FFmpeg inside Linux; Windows FFmpeg is not a runtime requirement.

### Reproducible Linux validation alternative (no deployment)

No existing repository CI runner/workflow was found during this review. Use an operator-approved Linux host with Docker; do not provision a new paid host or upload source without authorization. From this directory:

```sh
docker build -t ovexiq-media:smoke .
smoke_output="$(mktemp -d)"
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --cpus 2 --memory 2g \
  --mount "type=bind,source=$PWD/test,target=/app/test,readonly" \
  --mount "type=bind,source=$smoke_output,target=/out" \
  -e MEDIA_RENDER_SMOKE=1 -e MEDIA_SMOKE_OUTPUT_DIR=/out \
  ovexiq-media:smoke node --test test/render_smoke.test.js
```

The image build downloads public base-image/OS packages, not AI services. The actual smoke container has networking disabled and receives no provider key. It runs the existing SongWorkflow with synthetic text/audio adapters and real FFmpeg, validates MP3/full MP4/teaser MP4, checks SHA-256, closes/reopens SQLite, boots the actual service entry point without paid keys, and tests authenticated history/download over container-local loopback. Outputs and `smoke-report.json` remain beneath the printed synthetic-output directory for review. The temporary service key is random, in-memory only, and never included in the report.

The two-CPU/2-GiB settings above are an initial **test envelope, not a measured production sizing guarantee**. CPU/RAM and 1080p/long-song performance remain unbenchmarked. Production currently has one render at a time and no built-in process resource ceiling; the host must impose resource/disk limits and monitor capacity.

### Local readiness evidence — 2026-10-02

- Docker client 27.5.1 exists, but `desktop-linux` cannot connect: `dockerDesktopLinuxEngine` named pipe is absent. A real `docker build` attempt stopped at daemon connection, before building an image.
- WSL 2.4.12 exists, default version 2, but no distributions are installed. Windows reports `VirtualizationFirmwareEnabled=False`. No firmware, Windows features, WSL distributions, Docker settings or remote infrastructure were changed during this review.
- The explicitly enabled render test fails at preflight with `ffmpeg_unavailable`; FFmpeg did not execute and no real MP4 was produced. Installing FFmpeg on the developer PC is not the proposed production solution.
- Focused tests: 15 pass, real renderer test skipped by default. Existing SQLite reopen, metadata hash and authenticated-read tests pass with synthetic/fake media; this is not real MP4 validation.
- **Deployment gate remains blocked** until the Linux/container command above succeeds and its retained artifacts/report are reviewed. No deployment or paid-provider request occurred.

### Deployment readiness facts

- Runtime: Linux Node.js 22.16+ (Dockerfile uses Node 22 Debian Bookworm), FFmpeg/FFprobe with libx264, AAC and libmp3lame; no extra npm dependencies. Container is the reproducible packaging path, but an equivalent Linux installation can run the same service.
- One process/replica, one exclusive persistent filesystem volume, writable by uid 1000 for the default image. Preserve SQLite/WAL, visuals and all project artifacts together across restart/deployment. Do not use ephemeral-only disk or overlapping replicas.
- Internal bind: `0.0.0.0:8080` by default, configurable `PORT`; public ingress must terminate HTTPS (normally port 443). Worker requires an HTTPS origin without a path, query or embedded credentials.
- No dedicated `/health` endpoint is implemented. Use a TCP readiness probe, plus an operator-controlled authenticated `GET /v1/media/artist` or `/v1/media/projects` probe. Do not create a generation job as a health check.
- Gateway-to-service authentication: constant-time-checked shared bearer `OVEXIQ_MEDIA_SERVICE_KEY`, plus server-derived `X-Ovexiq-Account`. Never accept that ownership header from an unauthenticated client. Existing gateway beta-token/session validation and allowlist remain unchanged.
- Storage is private server filesystem storage, with portable project/artifact IDs and authenticated byte-download routes. Client metadata does not contain server filesystem paths. Retention/backups, disk size, monitoring and measured CPU/RAM must be configured by the operator before deployment.

From `app`: `flutter test --no-pub`, `flutter analyze --no-pub`, `git diff --check`.
From `app/ovexiq_ai_gateway`: `npm run test:unit`, `npm run test:runtime` (isolated local tests).
Android native compilation: `android/gradlew.bat :app:compileDebugKotlin` with the established JDK. This does not install an APK.

## One controlled live English-song run — only after operator provisioning

1. Provision durable server hosting and HTTPS ingress; validate the container with synthetic render smoke. Securely inject only the variables above. Back up the volume and restrict the media allowlist to the owner. Confirm Lyria account access/pricing/budget with the operator; this patch does not invent a dollar cost.
2. Deploy the updated Worker entry point using the existing approved deployment procedure, preserving secrets/bindings/migrations. Build/install the Android client through the established secure release process. Neither action is performed by implementation tests.
3. On Android 10+, open Songs from Library (or request “Create an original soft-rock song in English” in Home/Chat). Enter the reusable fictional artist name, confirm image rights, select exactly four authorized JPG/PNG artist images. Choose English.
4. Submit one original English-song goal and accept the one-spec-call + one-music-call confirmation **once**. This is the only step authorizing generation. Refresh/reopen only if submission becomes uncertain; unchanged in-screen resubmission uses the same idempotency ID.
5. Wait for server status. If it fails/interrupted, inspect the fixed failure stage and internal provider metadata, keep valid outputs, and STOP. No automatic regeneration.
6. Retrieve MP3, full MP4 and teaser **inside Android**; open/play each, Save to device, Share using a chosen target. Reopen Library/Songs after app restart; retrieve the same project/artifacts without generating another song.
7. Human-review English lyrics, singing, full-song ending, visual pacing, MP4 sync and actual teaser chorus. Verify hashes and full audio/video duration. A server `completed` status alone is not Android end-to-end acceptance.
8. Only after separate authorization, repeat with one Burmese goal and native-language listening review. No live call is included in tests.

Remaining acceptance gates: deployed/provisioned backend, installed client, actual Android retrieve/open/save/share/reopen, model access/budget, English/Burmese song quality, vocal consistency, teaser alignment. Web UI, voice cloning/conversion, generated video, silent comedy, publishing, payments and multi-provider fallback are out of scope.

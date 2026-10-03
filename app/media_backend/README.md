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

States: `queued -> specifying -> generating -> rendering -> completed`, or `failed`/`interrupted`. Persist the stage before a paid request. A restart marks in-flight jobs interrupted and does not replay a paid stage. Pending jobs can start; history reads cannot start new jobs. There are no automatic provider retries/fallbacks. An uncertain request outcome requires operator review before any new paid job; do not press Create again with a new id to try to recover it. Server failures preserve already validated outputs.

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

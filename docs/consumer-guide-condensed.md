# BI with AI Chat: Consumer Guide (Condensed)

A compact integration reference. It states the contract and the rules that break clients when ignored — no walkthroughs, no client code. For the long-form version with worked examples, see [consumer-guide.md](consumer-guide.md).

---

## 1. Surfaces

One user-facing WebSocket endpoint, plus supporting REST.

| Surface | URL | Lifetime |
| --- | --- | --- |
| Data Crew | `/chat/{agent_id}?token=…[&session_id=…]` | Per-tab; resume by passing `session_id` back |
| Concierge (global agent) | `/chat/concierge?token=…[&go_auth_token=…][&session_id=…]` | Survives reconnects while the client passes `session_id` back |
| Live (voice) | the same `/chat/{agent_id}` connection | Entered/exited inline; same `session_id` throughout |

All three speak the **same JSON protocol**. The server branches on the agent's `is_global` flag (from BigQuery config), not on the literal id `"concierge"` — any agent configured global gets cached sessions and accepts `context` frames.

`go_auth_token` (optional, Concierge) is the user's Google OAuth JWT; it lets the server inject the admin menu the user can reach into the model's system instructions. Omitting it is safe.

---

## 2. Auth

- **WebSocket**: bearer token in the `token` query param.
- **HTTP**: `x-winp-token` header.

Unauthorized sockets close with **1008**, no frame. A rejected `session_id` gets an `error` frame *first*, then 1008.

HTTP errors: `{"detail": "<message>"}` — `400` bad query/attachment, `403` BigQuery permission, `404` agent not available, `413` too large, `415` unsupported MIME, `502` BigQuery/model failure, `504` query timeout, `500` config/unclassified.

---

## 3. HTTP Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /agents` | Agent picker list. `status` ∈ `active`, `coming_soon`, `disabled` (`coming_soon` is not connectable). `requires_context: true` means send a `context` frame before the first message. Carries `suggested_questions` |
| `GET /agents/{agent_id}` | One agent's identity: `{agent_id, agent_type, name, model}`. `agent_type` is `"concierge"` when the agent is global, else `"data-crew"`. **Any non-200 means "not connectable"** — a missing agent returns `500`, not `404` |
| `DELETE /agents/cache` | Invalidate cached agent configs after editing config rows |
| `GET /sessions` | The user's sessions, newest first — session history picker |
| `DELETE /sessions/evict` | Evict all of the user's sessions. `204` |
| `DELETE /sessions/{session_id}/evict` | Evict one (ownership-guarded; a stranger's id is a no-op). `204` |
| `GET /sessions/count` | `{"count": n}` — cheap health check |
| `POST /read-aloud` | Text-to-speech, one shot → `audio/wav` bytes ([§10](#10-read-aloud-text-to-speech)) |
| `WS /read-aloud/stream?token=…` | Streaming text-to-speech ([§10](#10-read-aloud-text-to-speech)) |
| `GET /malloy/status` _(no auth)_ | Liveness + version + compiler pin. Always 200 while up |
| `GET /malloy/ready` _(no auth)_ | **Deployment gate.** 200 when ready, `503` with failing checks otherwise |
| `GET /malloy/schema` _(no auth)_ | Curated Malloy semantic surface — ops tooling, not a chat-client surface |
| `GET /files/…` _(no auth)_ | Attachment serving, `FILE_STORAGE_BACKEND=local` only |
| `GET /` , `/static/…` _(no auth)_ | Bundled demo client. Reference only — not part of the contract |
| `POST` / `WS /remote/{secret}/…` | Backend-only (BigQuery remote functions). Not a frontend route |

**`GET /sessions` fields that matter:** `title` is the label to render — the model writes it once the session's first turn completes and it never changes, so it is safe to cache. It is `null` only while the first turn hasn't finished; fall back to `messages` (the single earliest user message) until then. `agent_id` is the session's *initial* agent; `participant_agents` lists every agent that took a turn — label the thread from that.

**There is no per-session history endpoint.** To replay a conversation, reconnect the WebSocket with its `session_id` and read the `history` frame. Tool calls, actions and per-message timestamps are audited in BigQuery but never exposed to clients.

**Tools and data sources are never returned** by any endpoint (they carry raw SQL, Python, endpoints, GCS URIs). There is also **no client-side tool selection**: to trigger a tool-backed action from a button, send an ordinary user turn describing the intent and let the model pick the tool.

---

## 4. Sessions and connecting

- **New conversation** — omit `session_id`. The server mints one and emits a `session` frame. **Capture it.** The audit row is written only on the first user message (or on entering live mode); a `context` frame alone does not create it.
- **Resume** — pass `session_id=<uuid>`. The server rehydrates from BigQuery and emits `session` then `history`. A malformed/foreign/unknown id gets an `error` frame then close **1008**.
- Sessions are keyed by `(account, email, agent_id, session_id)`, so multiple concurrent sessions per user work.
- A session is a **shared transcript**, not a binding to one agent — you may resume the same `session_id` while connecting to a different agent ([§8](#8-agent-switching-shared-sessions)).
- Concierge (global) sessions stay in the in-memory cache across reconnects within a **4-hour idle TTL**; past that, or after a restart, rehydration from BigQuery is automatic.
- **Idle sockets are closed.** After 600 s with no client message the server closes with code **1000**, reason `"Idle timeout"`. Reconnect with the same `session_id`; nothing is lost.

`session.created_at` / `modified_at` are the timestamps of *this connect*, not of the stored record. Use `GET /sessions` for real creation time.

---

## 5. Frames

All frames are JSON. Every outbound frame has `type` and `content`; every inbound frame has `text`, `context`, or `type`.

### 5.1. Outbound — server → client (standard mode)

| `type` | `content` / siblings |
| --- | --- |
| `session` | `{session_id, account, email, agent_id, model_id, title\|null, status, created_at, modified_at}` — once, right after accept |
| `history` | `{agent_id, data: [ {role: "user"\|"model", text, agent_id, attachments?} \| {role: "edit", origin, file_id, from_version, to_version, diff} ]}` |
| `context_ack` | The stored context echoed back, or `null` |
| `delta` | `"<chunk>"` — streamed text |
| `image` | `{mime_type, data}` (base64) |
| `executable_code` | `{code, language}` — Gemini native code execution |
| `code_execution_result` | `{output, outcome}` |
| `tool_call` | `{name, args}` |
| `tool_result` | `{name, result}` — **summarised**; heavy rows collapse to `row_count` + `columns` |
| `action_confirmation` | `{tool_name, summary, parameters, settings: [{key, label, value, display}]}` — a gate; the turn parks ([§6](#6-gates)) |
| `action_result` | `{tool_name, status: "running"\|"ok"\|"error"\|"cancelled", result?, error?, reason?, latency_ms?}` — the response half of `action_confirmation` |
| `clarification` | `{tool_name, questions: [{question, options: [{label, description?}], multi_select}]}` — a gate |
| `agent_switched` | `{from_agent_id, to_agent_id, agent_name}` |
| `session_named` | `{session_id, title}` — once, shortly after the first turn |
| `navigate` | `{target, params}` — route the user there; no acknowledgement needed |
| `text_diff` | `{file_id, from_version, to_version, origin, diff, old_value, new_value}` — an **already-committed** document edit |
| `document_resync` | `{file_id, version, filename, mime_type, text}` — hard reset a document |
| `final` | `content: "<full text>"` **+ sibling** `attachments: [record, …]` — **the turn terminator** |
| `error` | `"<message>"` — explains a failure; **never ends a turn** |
| `mode_changed` | `{mode: "live"\|"standard"}` |

Unrecognised frame types must be dropped silently, never treated as errors.

### 5.2. Inbound — client → server (standard mode)

| Shape | Effect |
| --- | --- |
| `{text}` | User prompt |
| `{text, attachments: [{filename, mime_type, data}]}` | Prompt with files. `text` is **required** alongside attachments |
| `{text, focused_file_id}` | Prompt naming the editable document the user is viewing ([§7.3](#73-editable-documents)) |
| `{text, agent_id}` | Prompt directed at a chosen agent ([§8](#8-agent-switching-shared-sessions)) |
| `{context: {module, page, …}}` | Module context for a global agent ([§9](#9-module-context-global-agents)) |
| `{type: "action_confirm", tool_name}` | Approve the open confirmation |
| `{type: "action_cancel", tool_name, reason?}` | Decline it. `reason` is model-facing prose |
| `{type: "elicit_response", tool_name, answers: [["<label>", …], …]}` | Answer a clarification; positional per question, `[]` = dismissed |
| `{type: "document_edit", content: {file_id, diff, origin?}}` | Commit a **manual** user edit as a git diff |
| `{type: "start_live"}` | Enter live mode |

Blank `text` with no other recognised field returns `error: "Please provide a message."` — audio and image frames are exempt (they enter live mode).

### 5.3. Turn rules

**`final` is the one and only terminator. Gate your "response in progress" state on it and nothing else.** Exactly one `final` is emitted for every turn the server accepts — normal answer, turn that died mid-flight, or turn that never started (rejected attachment). On the failure paths `content` is `""`: that is a **bare terminator**, not a correction. Keep the deltas already rendered; render nothing new.

- **`error` never ends a turn.** It explains one, and it can arrive mid-turn. A client that re-enables the composer on `error` unlocks it under a running turn.
- **A turn parked on a gate is still running.** While an `action_confirmation` or `clarification` is open the server sends nothing else and accepts no new prompt.
- **One turn at a time.** A prompt sent while a turn is in flight is refused, not queued. The server answers with an `error` (`"Still working on your previous message — one moment."`), and if a gate is open it **re-sends the open gate frame** first, followed by an error naming the reason. A repeat frame for the same `tool_name` is a **redelivery** — replace the dialog, don't stack a second one.

---

## 6. Gates

Two flows park the turn and wait for the client. Both keep the input box disabled until answered, both are keyed by `tool_name`, and both live on the WebSocket handler instance — if the connection drops while parked, the turn is lost and reconnecting starts fresh.

A reply that arrives with **no gate open** (double click, retry after the turn moved on) is logged and discarded, never queued — a queued verdict would resolve the *next* action instead. Sending a confirmation twice is harmless, but it is also not an undo.

### 6.1. `action_confirmation` — Tier-3 actions

Fires when a tool has `tool_requires_confirmation`. **Not limited to `action` tools** — side-effecting Python tools (the knowledge-base publish/save family) set it too; handle it identically whatever the tool is. When confirmation is *not* required, the action executes inline and you just see `tool_call` / `tool_result` (plus `navigate` for navigation actions).

Render:

- **`summary`** — a user-facing sentence, resolved server-side (model-written summary → the tool's configured prompt with arguments filled in → humanised tool name). Safe to render verbatim; never contains model-facing text.
- **`settings`** — an ordered, render-ready list of what the action will *actually* do: values the model never supplies (destination, folder, theme, schedule) and so appear in neither `summary` nor `parameters`. Render `label` / `display`; **never render `value`** (it is the identifier the server executes with). `settings` is `[]` for tools that declare none — render nothing, not an empty box. Keys vary per tool; iterate as given.
- **`parameters`** — the raw argument dict, for a details disclosure.

`action_result` is the response half. Confirming produces at least two:

| `status` | Meaning |
| --- | --- |
| `running` | Confirmation accepted, call started. Dismiss the dialog and show a pending indicator here |
| `ok` | Succeeded. `result` is the summarised outcome, `latency_ms` the duration |
| `error` | Failed. The **turn continues** — the model is given the failure and explains it, then `final` |
| `cancelled` | Declined, never ran. `reason` echoes what you sent |

The `running` ack exists because a real publish or bulk write routinely takes ten seconds or more; without it there is no frame at all between the click and the outcome.

**Send a `reason` on cancel** whenever the dismissal is not a refusal. It becomes the tool result the model reads. A client that sends the user to a fuller configuration screen has *deferred* the action; the default (`"User declined the action."`) makes the model answer as though the user said no. Write it as prose about what the user did, not an enum.

Multiple confirmations can occur in one turn; the server parks on each in order.

### 6.2. `clarification` — `ASK_USER`

The model asks for a choice it cannot infer (publish group, folder, theme). `questions` is an **array** — the model batches what can be answered together and leaves dependent questions for a later round.

- Render one picker per question; honour each `multi_select`. `label` is the choice, `description` optional helper text.
- Reply with a single `elicit_response` for the whole batch. `answers` is **positional**: `answers[i]` is the array of chosen **`label`** strings for `questions[i]`. `[]` means that question was dismissed — the model is told and decides how to proceed.
- `tool_name` must match the frame's.
- **Text mode only** — `ASK_USER` is removed from the toolset in live mode; the model asks aloud instead.

---

## 7. Attachments

### 7.1. Record shape and kinds

Attachment records appear on `final.attachments` and on `history.data[].attachments`, always with the same shape and a **freshly minted** `url`:

`{file_id, filename, kind, mime_type, size_bytes, backend, storage_key, created_at, resource_id, url}`

**Classify on `kind`, not `mime_type`** — `plotly` and `malloy` are both JSON and render completely differently.

| `kind` | What to do |
| --- | --- |
| `plotly` | Fetch `url` (a serialised Plotly figure: `data`, `layout`, optional `config`) and render it **at its slot marker** in the prose |
| `malloy` | Fetch `url` and hand the `malloy.dashboard.v1` envelope to the dashboard renderer. **No slot marker** — its own panel |
| `editable` | Fetch `url` for the body and open it in a preview/editor. Track `file_id` ([§7.3](#73-editable-documents)) |
| `image` | Render inline |
| `file` | Download chip |

Only `plotly`, `malloy` and `editable` are set explicitly by the producing tool. Anything else — notably user uploads — falls back to `image` for `image/*` and `file` otherwise. `kind` may be `null` on older rows; infer from `mime_type` then.

`resource_id` is the source record the attachment was materialised from (a knowledge-base node id, …), or `null` — it tells you whether an `editable` document is backed by a stored node, e.g. to choose between a create-save and an update-save.

`url` is short-lived (GCS signed URLs, default 24 h). It is re-minted every time the server hands you a record, so it is always valid at render time — never cache it. On a resolution failure the field is **omitted entirely**; guard for absence, not `null`. `file_id`, `resource_id` and `storage_key` are stable, so key your own cache on `file_id`.

### 7.2. Charts and dashboards

- **Charts** (`GENERATE_CHARTS`): `final.content` carries ` ```chart\n<file_id>\n``` ` slot markers, one per chart, each immediately before the prose that interprets it. Split the content on them, look the `file_id` up in `attachments`, render at that position.
- **Dashboards** (`MALLOY_ANALYTICS`): no slot markers. The envelope carries the **complete** row set (the rows inline on `tool_result` are capped at 20), plus `view_meta` with the Malloy render tags the renderer needs, and `compiled_sql` / `request_id` as provenance for a "show me the SQL" affordance. An ad-hoc inline query produces no artifact — just rows and prose.
- The `artifacts` array on a `tool_result` is **informational only** and carries no `url`. `final.attachments` is the authoritative render source.
- Malloy tool failures come back as an ordinary `tool_result` with `{error, error_type}` (`compile_error`, `unexported_object`, `execution_error`, `budget_exceeded`, `retry_budget_exhausted`, `adapter_error`). The model normally explains them in the following prose; rendering them is optional.

### 7.3. Editable documents

The contract behind Knowledge Composer preview / create / edit / save / publish. It is text-generic, not markdown-specific.

A document enters preview either by **retrieval** or by **creation** — both deliver an identical `kind: "editable"` attachment on `final.attachments`. The body is *never* inline in `final.content` or in the `tool_result` (which carries only title, excerpt, `body_chars`, `file_id`). Persisting is an ordinary action call — no document body crosses the wire, and you never branch on which persistence tool fired. Publish and hand-over tools address documents by their real KB node id (the attachment's `resource_id`), resolved server-side — an unsaved draft (`resource_id` `null`) is refused with a save-first error, and a Composer hand-over `navigate` carries `params.node_ids` as a plain string array of node ids.

**The server owns the document** and assigns a monotonically increasing integer `version`. Clients never send a version.

| Change | Who commits | What you do |
| --- | --- | --- |
| Agent edit (`text_diff`) | The server, **before the frame reaches you** | Apply the diff to the document named by `content.file_id`, adopt its `to_version`. **Never echo it back** — that double-applies and forces a resync |
| Manual user edit | You, by sending `document_edit` with a git unified diff | On success there is **no reply** — advance your own copy by one |

- `text_diff` carries `old_value` / `new_value`, the full body before and after — use `new_value` to reset your preview exactly instead of patching. (They make the frame large; ignore them if you patch.)
- The `DOCUMENT_EDIT` `tool_result` still reads `status: "awaiting_user_decision"`. **It does not mean the server is waiting for you** — a leftover string; nothing is parked, the turn continues. Don't gate on it.
- An accept/reject affordance is presentation only. "Reject" is an undo you author: write `old_value` back and relay it as a manual `document_edit`.
- Conflicts are detected by the patch, not a version number — the server verifies every context and removed line against its current text. Include git's default 3 lines of context. Edits to untouched regions merge cleanly even if an agent edit landed meanwhile.
- **`document_resync`** hard-resets your copy to `text` / `version`. Two triggers: a diff that failed to apply, and a **re-open** — when the agent retrieves a document already open in this session, the server reuses the existing `file_id` and resyncs rather than minting a second preview. **No new attachment is delivered in that turn** (`tool_result` marks it `"reopened": true`), so a client that only reacts to attachments shows nothing.
- **`focused_file_id`** on a user turn tells the server which document the user is looking at, so an unqualified request ("tighten this") resolves to that tab instead of the model's last-touched document — and avoids a needless clarification. A stale or closed id is ignored, so it is always safe to send.
- **On reconnect**, rebuild from the `history` timeline: take the `editable` attachment body as version 0 and replay the `role: "edit"` entries for that `file_id` in order.
- `final.attachments` is empty on an edit turn — the diff rides `text_diff`, never an attachment.

### 7.4. User uploads

Sent as `{filename, mime_type, data}` (base64) alongside a required `text`. Multiple per message.

Allowed: `text/csv`, `text/plain`, `application/json`, `application/pdf`, `application/vnd.malloy.dashboard+json`, `.xlsx`, `image/png`, `image/jpeg`, `image/gif`, `image/webp`. **`text/markdown` is not uploadable** (though documents are *delivered* as it) — send markdown as `text/plain`.

Max **20 MB** decoded per file. Every failure — bad type, oversized, storage error — arrives as one wrapper: `"Failed to upload attachment '<name>': <cause>"`. Match on the cause, not the prefix. The batch aborts on the first bad file and earlier files are deleted, so exactly one such frame arrives, and nothing reaches the model. Uploads are persisted on the user message row and come back on `history` with fresh URLs.

---

## 8. Agent switching (shared sessions)

The agent in the connect URL is only the **initial** agent. Ownership is `(account, email, session_id)`.

- Include `agent_id` on a user turn to hand the conversation over. The incoming agent inherits the **full prior transcript** plus a one-shot handoff note.
- `agent_id` is **sticky** — later turns without it stay with that agent. An agent the user cannot access is ignored and the current agent continues.
- On `agent_switched`, update your "who's answering" affordance and attribute the turn to `to_agent_id`.
- Every turn is persisted with its producing agent, so `history` bubbles carry `agent_id` — colour/label per agent on replay.
- **Text mode only.** A live session runs the single agent it entered with.

---

## 9. Module context (global agents)

Send a `context` frame whenever the user's situation changes meaningfully — route change, filter change, entity selection.

- The server acknowledges with `context_ack` and **prepends** the context as a `[Module Context]` preamble to the very next user turn. Identical consecutive contexts are deduplicated.
- **Nothing is persisted.** Context is in-memory, not audited, and does not survive a reconnect — **re-send it after every reconnect**. There is no `role: "context"` row in any history.
- Never render context frames as chat bubbles. `context_ack` is a diagnostic; no UI required.
- For agents with `requires_context: true`, send one immediately after connect, before the first user message.

---

## 10. Live mode (voice)

Connects the current session to the Gemini Live API. Entered and exited **inline on the same connection** — no second socket, no new `session_id`. Text before and after a live segment shares one conversation history.

**Entry:** `{"type": "start_live"}` → `mode_changed / live`. Entry is also **implicit** — a top-level `audio` or `image` frame opens live mode and is carried into the session, so nothing the user said is lost. Prefer explicit entry: the provider handshake and history seeding then happen before the first utterance instead of during it. **Exit stays explicit** (`{"end_live": true}`) — silence is not "done speaking".

Entry is rejected while a text turn is running: `"Cannot switch to live mode while a response is in progress."`

### Inbound (live)

| Shape | Effect |
| --- | --- |
| `{audio}` | PCM 16 kHz mono s16le chunk. Stream continuously; queued in order |
| `{image, mime_type}` | Camera/screen frame — visual context. Client → server only; there is no outbound video |
| `{text}` | A **complete typed turn** — no `end_turn` |
| `{end_turn: true}` | Closes the streamed audio turn so the model responds |
| `{end_live: true}` | Back to standard mode |

**Server-side VAD is disabled — `end_turn` is required.** Turn boundaries are push-to-talk: the model will not answer because the user paused. `end_turn` with no audio awaiting a response is ignored.

**Typed text is a whole turn, not streamed input.** It *interrupts* (expect `interrupted` if the model is speaking), it is **echoed back as `input_transcript`** — render that rather than appending locally, or it appears twice — and it is persisted as a user transcript row. The **answer is still audio**: the response modality is fixed when the session connects, so a typed question gets speech plus `output_transcript`, never `delta`. A typed message never exits live mode.

### Outbound (live)

| `type` | Notes |
| --- | --- |
| `audio_output` | `content: "<base64>"`, `mime_type: "<format>"` — typically `audio/pcm;rate=16000`, but use the field to pick a decoder |
| `output_transcript` | `content`, `is_delta` — `false` is the final assembled text for the turn (the one persisted). Captions |
| `input_transcript` | User speech-to-text, or the echo of a typed message |
| `tool_call` / `tool_result` | Same shapes as text mode |
| `action_result` | `running` then `ok` / `error`. No `cancelled` — nothing to decline |
| `navigate`, `text_diff`, `document_resync` | Tool-declared client events fire in voice too, identically |
| `interrupted` | Barge-in. **Stop playback and flush buffered audio**; attachments staged for the turn are discarded |
| `final` | `content: ""`, `attachments: […]` — emitted **only when the turn produced attachments**, just before `turn_complete` |
| `turn_complete` | **Turn terminator** — live mode's `final`. Emitted after a normal turn *and* after one killed by an error, so a turn is never left open |
| `error` | Explains a failure; the `turn_complete` closing the turn follows |
| `mode_changed` | Sent at entry and exit |

**Live mode is tool-capable** — a tool that fails or times out fails only its own call; the model speaks to the error and the session continues.

What does **not** occur: `delta`, `clarification`, `agent_switched`, and — the one to watch — **`action_confirmation`. There is no confirmation gate in voice: a tool with `tool_requires_confirmation` executes immediately, without asking.** If an agent is voice-enabled, treat every side-effecting tool it carries as fire-and-forget and scope its toolset accordingly.

**Transcripts are first-class history.** Both directions are persisted and appended to the shared transcript as they happen, so voice and text interleave in one ordered conversation and replay in `history` as ordinary `role: "user"` / `"model"` entries — indistinguishable from typed turns (badge them yourself while live if you want the distinction). A model turn cut off by barge-in is stored with a trailing `[interrupted]` line.

---

## 11. Read-aloud (text-to-speech)

For reading arbitrary UI text — a chat bubble, a summary — aloud. Independent of live mode and of any session.

- **`POST /read-aloud`** (`x-winp-token`) — body `{text, voice?, language?}`, response is a playable **`audio/wav`** file. Simplest integration.
- **`WS /read-aloud/stream?token=…`** — send one `{text, voice?, language?}` message, receive a sequence of `audio_output` frames carrying **raw PCM** (mono, 16-bit, 24 kHz) as they are generated, then `turn_complete`, then the socket closes. Lower latency to first sound on long text. The frames are the same shapes live mode uses, so a client already wired for live audio playback needs no new decoding.

`voice` is a prebuilt Gemini TTS voice name (defaults to a professional one); `language` is BCP-47. Text over **4000 characters** returns `413` (or an `error` frame on the socket); empty text returns `400`. Synthesis failure is `502`.

---

## 12. History replay

On reconnect the server emits `session`, then — only if the conversation has visible turns — a single `history` frame before any interactive traffic. If none arrives within ~500 ms, treat the conversation as empty.

`data` is a chronological timeline mixing two entry kinds:

- **`role: "user"` / `"model"`** — chat bubbles, each with its producing `agent_id` and any `attachments` (fresh URLs, so charts render from history without extra requests).
- **`role: "edit"`** — a committed document change `{origin, file_id, from_version, to_version, diff}`. **Never render it as a bubble.** Replay it: patch it onto your copy of that `file_id`, in timeline order. A client that doesn't recognise it must skip it.

Both the agent's and the user's edits appear, so a fresh client converges on the exact current document. `role: "edit"` exists **only** in this frame — it is synthesised from `content_type: "document_edit"` audit rows and is not an audit role.

Not in `history`, and not retrievable anywhere: tool calls, actions, per-message timestamps, module context.

If the backend restarted since your last turn, it transparently rebuilt both the model chat and the authoritative document copies from BigQuery using the `session_id` you passed.

---

## 13. Errors and reconnect

| Situation | Client behaviour |
| --- | --- |
| Close **1008** | Unauthorized, or a `session_id` that is malformed/expired/not yours. Refresh the token and retry; if you passed a `session_id`, reconnect without it to start fresh |
| Close **1000**, reason `"Idle timeout"` | 600 s with no client message. Reconnect with the same `session_id` |
| `error` frame | Surface it. The connection stays open and the turn is **not** over — wait for `final` |
| `"Still working on your previous message — one moment."` | Your prompt was refused because a turn is in flight. Disable the composer until `final` |
| `"This turn is waiting on the prompt above — answer or dismiss it to continue."` | A gate is open; the gate frame was re-sent just before this. Re-render it |
| `"Failed to upload attachment '<name>': …"` | Read the cause after the colon: unsupported type, over 20 MB, or storage. Earlier files in the batch were cleaned up |
| `"Please provide a message."` | Blank `text` with no other recognised field — including attachments with no text |
| `"Cannot switch to live mode while a response is in progress."` | Wait for `final`, then retry `start_live` |
| `"document_edit requires 'file_id' and 'diff'."` | Malformed frame; nothing was committed |
| `"No open document with file_id '…'."` | Not open server-side. Re-open it before editing |
| Tool failure in a `tool_result` | Rendering optional — the model usually explains it in the next `delta` |
| Attachment `url` 403/404, or no `url` field | Expired signed URL → reconnect with the same `session_id` for fresh ones. An **omitted** field means resolution failed: show the filename without a link |
| No `final` for a long time | Show a typing indicator. Tools are bounded (120 s each), so an `error` or `final` does arrive |
| `GET /malloy/ready` → `503` | Malloy tooling is down; `MALLOY_ANALYTICS` will fail. Other agents still work |

**Reconnect strategy:** capture `session_id` from every `session` frame and persist it per tab; pass it back on reconnect; exponential backoff 1s → 30s cap; wait ~500 ms for `history` before calling the conversation empty; on 1008 after passing a `session_id`, drop it and start fresh.

---

## 14. Quick reference

### Outbound — standard mode

```
session             { session_id, account, email, agent_id, model_id, title, status, created_at, modified_at }
history             { agent_id, data: [{role, text, agent_id, attachments?} | {role:"edit", origin, file_id, from_version, to_version, diff}] }
delta               "<chunk>"
image               { mime_type, data }
executable_code     { code, language }
code_execution_result { output, outcome }
tool_call           { name, args }
tool_result         { name, result }                # summarised
action_confirmation { tool_name, summary, parameters, settings: [{key, label, value, display}] }   # repeat = redelivery
action_result       { tool_name, status: running|ok|error|cancelled, result?, error?, reason?, latency_ms? }
clarification       { tool_name, questions: [{question, options: [{label, description?}], multi_select}] }
agent_switched      { from_agent_id, to_agent_id, agent_name }
session_named       { session_id, title }
navigate            { target, params }
text_diff           { file_id, from_version, to_version, origin, diff, old_value, new_value }   # committed — never echo
document_resync     { file_id, version, filename, mime_type, text }
context_ack         <context echoed, or null>
final               content: "<full text>", attachments: [...]   # THE terminator; content:"" = bare terminator
error               "<message>"                     # NEVER ends a turn
mode_changed        { mode: "live" | "standard" }
```

### Outbound — live mode

```
audio_output        content: "<base64>", mime_type: "<format>"
output_transcript   content: "<text>", is_delta: <bool>       # false = final text for the turn
input_transcript    "<user speech or typed echo>"
tool_call / tool_result / navigate / text_diff / document_resync      # same shapes as text mode
action_result       { tool_name, status: running|ok|error, ... }      # no `cancelled` in voice
interrupted         (no content)                    # barge-in — stop playback, flush
final               content: "", attachments: [...]  # only when the turn produced attachments
turn_complete       (no content)                     # terminator, including after an error
error               "<message>"
mode_changed        { mode: "live" | "standard" }
```

### Inbound

```
standard:
{ text }                                            { text, attachments: [{filename, mime_type, data}] }
{ text, focused_file_id }                           { text, agent_id }                # sticky
{ context: {...} }
{ type: "action_confirm",  tool_name }
{ type: "action_cancel",   tool_name, reason? }     # reason is model-facing prose
{ type: "elicit_response", tool_name, answers: [["<label>", …], …] }   # positional; [] = dismissed
{ type: "document_edit",   content: { file_id, diff, origin? } }       # MANUAL edits only
{ type: "start_live" }

live:
{ audio }            { image, mime_type }           # either also enters live mode from standard
{ text }             # COMPLETE turn — no end_turn; interrupts; echoed as input_transcript
{ end_turn: true }   # required — server VAD is off
{ end_live: true }
```

### URLs

```
wss://host/chat/{agent_id}?token=<winp-token>[&session_id=<uuid>]
wss://host/chat/concierge?token=<winp-token>[&go_auth_token=<go-jwt>][&session_id=<uuid>]
wss://host/read-aloud/stream?token=<winp-token>

GET    /agents | /agents/{agent_id} | /sessions | /sessions/count        (x-winp-token)
DELETE /agents/cache | /sessions/evict | /sessions/{session_id}/evict    (x-winp-token)
POST   /read-aloud                                                       (x-winp-token)
GET    /malloy/status | /malloy/ready | /malloy/schema | /files/…        (no auth)
```

# BI with AI Chat: Consumer Guide

## Overview

The bi-with-ai-chat service provides WebSocket endpoints and supporting REST APIs to integrate generative AI conversational agents into frontend administrative interfaces. It powers three distinct surfaces: ephemeral, inquiry-focused "Data Crew" agents (`/chat/{agent_id}`), the persistent, state-aware "Concierge" panel (`/chat/concierge`) which survives reconnects and can execute user-confirmed administrative actions, and real-time voice conversations that can be entered at any point via the same `/chat/{agent_id}` connection using a `start_live` message or simply by streaming audio. The `/chat/` endpoint uses a strictly typed, bidirectional JSON messaging contract covering streaming responses, historical audit replays, tool executions, frontend routing, module context injection, interactive chart and Malloy-dashboard delivery, editable document preview/edit, and live audio events.

---

## 1. Architecture at a Glance

```txt
┌─────────────────────────┐        ┌─────────────────────────┐
│  Admin Frontend         │◀──────▶│  bi-with-ai-chat (this) │
│  - Data Crew chat page  │  WS/   │  - /chat/{agent_id}     │
│  - Concierge side panel │  HTTP  │  - /agents, /sessions   │
│  - Voice interface      │        │  - /malloy/status /ready│
└─────────────────────────┘        └──────────┬──────────────┘
                                              │ google-genai
                                              │ BigQuery (audit, tools, config)
                                              │ GCS / local (attachment files)
                                              │ Node (pinned Malloy compiler)
                                              ▼
                                    ┌──────────────────────────────┐
                                    │  Gemini (Vertex AI)          │
                                    │  - standard models (text)    │
                                    │  - Live API (voice/audio)    │
                                    └──────────────────────────────┘
```

There is a single user-facing WebSocket endpoint. Live (voice) mode is entered inline on the same connection:

| Surface        | URL                                            | Protocol | Lifetime                                                                                        |
| -------------- | ---------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------- |
| Data Crew      | `/chat/{agent_id}?token=...[&session_id=...]`  | JSON     | Per-tab; session released on disconnect unless the client reconnects with the same `session_id` |
| Concierge      | `/chat/concierge?token=...[&session_id=...]`   | JSON     | Long-lived across reconnects **when the client passes the same `session_id` back**              |
| Live (voice)   | same `/chat/{agent_id}` connection             | JSON     | Entered via `{"type":"start_live"}`, or implicitly by sending an `audio`/`image` frame; exited via `{"end_live":true}`. Same session throughout. |

All surfaces speak the **same JSON protocol** on `/chat/`. The server branches on the agent's **`is_global` flag** (from its BigQuery config) — not on the literal string `"concierge"` — to (a) keep the session cached across disconnects and (b) accept module `context` frames. `concierge` is simply the agent that ships with `is_global = true`; any agent configured that way gets the same behaviour. Section 5 describes the full `/chat/` protocol (text and live events); Section 6 covers the global-agent behaviour; Section 9 covers live mode switching.

---

## 2. Authentication

All user-facing endpoints read the bearer token from the `token` query parameter.

- **WebSocket**: `wss://host/chat/bob_the_kpi_guy?token=<winp-token>`
- **HTTP**: send the token in the `x-winp-token` header instead.

The token is resolved against the Winp auth service (`ADMIN_URL`) to produce `{account, project, email}`. Two non-production shortcuts exist:

- `ENV=local` — the auth call is skipped entirely and the values come from `DEV_ACCOUNT` / `DEV_PROJECT` / `DEV_EMAIL`. Any token (or none) is accepted.
- `ENV=staging` — the token is required and decoded as a JWT **without signature verification**; `account`/`email` come from its claims, with `DEV_CLIENT_PROJECT` overriding the project.

Neither is ever enabled in production.

Unauthorized WebSocket connections are closed with close code **1008** and no frame. A rejected `session_id` (see [Section 4](#4-connecting-the-websocket)) gets an `error` frame *first*, then the 1008 close.

HTTP errors come back as `{"detail": "<message>"}` with a status derived from the failure class: `400` bad query/attachment, `403` BigQuery permission, `404` agent not available, `413` attachment too large, `415` unsupported MIME type, `502` BigQuery/model-provider failure, `504` query timeout, `500` for configuration and anything unclassified.

---

## 3. HTTP Endpoints

### `GET /agents`

Lists all agents visible to the authenticated account. Use this to render the agent picker.

Request:

```http
GET /agents
x-winp-token: <winp-token>
```

Response: `200 OK`

```json
[
  {
    "agent_id": "bob_the_kpi_guy",
    "agent_name": "Bob the KPI Guy",
    "agent_subtitle": "Business KPIs & Trends",
    "agent_description": "…",
    "agent_image_url": "https://…",
    "agent_profile_text": "…",
    "agent_welcome_message": "Hi! I'm Bob…",
    "model_id": "gemini-2.5-flash",
    "temperature": 0.7,
    "status": "active",
    "display_order": 1,
    "requires_context": false,
    "suggested_questions": [
      {
        "category": "Metric Evolution",
        "icon": "chart-line",
        "question_text": "…",
        "display_order": 1
      }
    ]
  }
]
```

`status` is one of `active`, `coming_soon`, `disabled`. `coming_soon` agents appear in the list so the UI can render a "Coming soon" badge — they are not connectable.

`requires_context` is `true` for global/concierge-style agents that expect a module context frame before the first user message. Send a `context` frame on connect for these agents (see [Section 6.3](#63-module-context-injection)).

### `GET /agents/{agent_id}`

Returns the client-safe identity of one agent. Note this is a **different, smaller shape** than the entries in `GET /agents`; it is not a per-agent version of that list.

```json
{
  "agent_id": "bob_the_kpi_guy",
  "agent_type": "data-crew",
  "name": "Bob the KPI Guy",
  "model": "gemini-2.5-flash"
}
```

`agent_type` is derived from the agent's `is_global` flag: `"concierge"` when set, `"data-crew"` (hyphenated) otherwise.

When no **active** agent matches the id for this account — including a `coming_soon` one — the lookup fails as an agent-config error and the response is **`500`** with `{"detail": "No active config found for agent '…' / account '…'"}`. Treat any non-200 here as "not connectable"; don't branch on 404.

> **`tools` and `data_sources` are deliberately not returned.** The resolved tool rows carry `tool_query_template` (raw SQL), `tool_python_code`, and `tool_action_endpoint`; data-source rows carry `source_reference` (GCS URIs, BigQuery table names, webhook URLs). None of it is client-facing.
>
> **There is no client-side tool selection.** A client never picks or invokes a tool by name. To trigger a tool-backed action from a button, send an ordinary user turn describing the intent — e.g. `{"text": "save this query"}` — and the model selects the tool. That is the whole contract; no tool list is needed to build such a button.

### `DELETE /agents/cache`

Invalidates every cached agent config so the next request re-fetches from BigQuery. Use after editing agent config rows; otherwise changes wait for the cache to lapse. Returns `{"message": "Agent cache cleared", …}`.

### `GET /sessions`

Lists all active sessions belonging to the authenticated user, newest first, with the first user message per session as a preview. Use this to render a session history picker. Sessions are **shared transcripts**, not tied to one agent, so this is not agent-scoped — each row carries the session's initial `agent_id` plus `participant_agents` (every agent that produced a turn in the thread).

Request:

```http
GET /sessions
x-winp-token: <winp-token>
```

Response: `200 OK` — array of session objects, newest first.

```json
[
  {
    "session_id": "f3a1c2d4-…",
    "account": "acme",
    "email": "user@acme.com",
    "agent_id": "concierge",
    "model_id": "gemini-2.5-flash",
    "status": "active",
    "created_at": "2026-05-04T10:00:00+00:00",
    "participant_agents": ["concierge", "bob_the_kpi_guy"],
    "messages": [
      {
        "message_id": "…",
        "role": "user",
        "content": "How did revenue evolve last quarter?",
        "content_type": "text",
        "created_at": "2026-05-04T10:00:05+00:00"
      }
    ]
  }
]
```

`agent_id` is the session's initial agent; `participant_agents` lists every agent that took a turn (label/colour the thread accordingly). `messages` contains the single earliest user message for each session, suitable for a preview card. If the session has no user message yet, `messages` is `null`.

### Per-session detail

There is **no** endpoint returning a single session's full message history. The route that once did (`GET /threads/{session_id}`) has been removed.

To replay a conversation, reconnect the WebSocket with its `session_id` and read the [`history`](#62-history-replay-on-reconnect) frame: it carries the user/model turns with freshly resolved attachment URLs, plus `role: "edit"` document edits — enough to rebuild both the transcript and the current document state. Tool calls, actions and per-message timestamps are persisted in BigQuery but are not exposed to clients.

### `DELETE /sessions/evict`

Evicts every session belonging to the authenticated user. Drops them from the in-memory SessionCache, deletes per-session file-storage subdirectories for every affected session, and marks matching BigQuery rows as `expired`. Sessions are shared transcripts, not agent-scoped, so this is not agent-filtered. Returns `204 No Content`.

```http
DELETE /sessions/evict
x-winp-token: <winp-token>
```

### `DELETE /sessions/{session_id}/evict`

Evicts exactly one session. The session must belong to the authenticated user (account + email guard on both the BQ query and the UPDATE); passing a stranger's session_id is a no-op. Returns `204 No Content`.

```http
DELETE /sessions/f3a1c2d4-…/evict
x-winp-token: <winp-token>
```

### `GET /sessions/count`

Returns `{"count": <int>}` — the live cached session count. Cheap health-check.

### `GET /files/…` _(local backend only)_

Static file serving for attachment output when `FILE_STORAGE_BACKEND=local`. The mount path is derived from the `FILE_STORAGE_LOCAL_PUBLIC_URL` environment variable (default: `/files`). Not present when `FILE_STORAGE_BACKEND=gcs` — GCS generates signed URLs directly.

### `GET /` and `/static/…` _(no auth)_

The bundled `demo-client` reference UI — a working implementation of this protocol, useful to diff your client against. Not part of the integration contract; don't build on these paths.

### `GET /malloy/status` _(no auth)_

Liveness plus build/config metadata. Always `200` while the process is up.

```json
{
  "service": "bi-with-ai-chat",
  "version": "1.4.2",
  "malloy_compiler_pin": "0.0.110",
  "malloy_package_dir": "/app/malloy/packages"
}
```

### `GET /malloy/ready` _(no auth)_

Readiness probe. Returns `200` with `{"ready": true, …}` when every check passes, or **`503`** with the failing checks when not. Use this — not `/malloy/status` — as the deployment gate.

```json
{
  "ready": true,
  "checks": {
    "node_runtime": true,
    "malloy_packages": true,
    "export_artifacts": true
  }
}
```

`node_runtime` is the pinned Node Malloy compiler, `malloy_packages` that at least one `.malloy` model is present, `export_artifacts` that each package has its `malloy_semantic_export.json`.

### `GET /malloy/schema` _(no auth)_

The curated Malloy semantic surface — every package's `malloy_semantic_export.json` plus the compiler pin. Consumed by ops tooling and the graph publish pipeline; it is **not** an LLM surface and not something a chat client needs.

```json
{
  "malloy_compiler_pin": "0.0.110",
  "packages": [ { "package": "bi_chat", "models": [ … ] } ]
}
```

A package whose export artifact is unreadable appears as `{"package": "…", "error": "unreadable export artifact"}` rather than failing the whole response.

### `/remote/{secret}/{agent_id}/{account}/{project}/{email}` _(backend-only)_

A **POST** (unary) and a **WebSocket** variant intended for BigQuery remote functions, which cannot set HTTP headers — hence the shared-secret path segment (`REMOTE_SECRET`) instead of a token. Each invocation starts a fresh session. Not part of the frontend contract; listed here only so it isn't mistaken for a user-facing route. POST returns `{"response": "<assembled text>"}`.

---

## 4. Connecting the WebSocket

Every connection is bound to a single `session_id` for its lifetime. Live (voice) mode is entered and exited within the same connection — the session_id never changes.

### `/chat/` — Data Crew, Concierge, and Live mode

- **New conversation**: omit `session_id`. The server allocates a fresh UUID, creates the in-memory chat, and emits a [`session`](#51-outbound--server--client) frame carrying the id. **Capture it** — you'll need it to reconnect and resume. The `bi_with_ai_chat_session` row is only written once you send your first user message (or enter live mode), so connect-and-close without activity leaves no audit trail behind. A `context` frame on its own does **not** create the row.
- **Resume a prior conversation**: pass `session_id=<uuid>` as a query param. The server rehydrates the conversation from BigQuery (user + model text turns, plus `role: "edit"` document edits to replay) and emits both a `session` frame (echoing the id you sent) and a `history` frame. If the `session_id` is malformed, missing, or belongs to a different user, the server sends an `error` frame explaining why and then closes the socket with code **1008**. Read the frame before the close event if you want to surface the reason.

A single user can hold **multiple concurrent sessions** with the same agent — the in-memory cache is keyed by `(account, email, agent_id, session_id)`, so opening two browser tabs against Bob, each resumed from a different historical session, works correctly.

### Data Crew

```js
const ws = new WebSocket(`wss://${HOST}/chat/${agentId}?token=${token}`);
// …or, to resume an existing conversation:
const ws = new WebSocket(
  `wss://${HOST}/chat/${agentId}?token=${token}&session_id=${sessionId}`,
);
```

- `agentId` comes from the `/agents` list (e.g. `bob_the_kpi_guy`). It is the session's **initial** agent, not a permanent binding: ownership of a session is `(account, email, session_id)` only, so you can resume the same `session_id` while connecting to a different agent, and you can hand individual turns to another agent mid-conversation ([§6.7](#67-picking-the-agent-shared-sessions)). Connecting **without** a `session_id` always starts a fresh conversation, whichever agent you name.
- On disconnect the bound session is **released** from the in-process cache. The `bi_with_ai_chat_session` row remains in BigQuery; the client can reconnect with the same `session_id` to rehydrate from the audit tables.

### Concierge

```js
const ws = new WebSocket(
  `wss://${HOST}/chat/concierge?token=${token}&go_auth_token=${goAuthToken}&session_id=${sessionId}`,
);
```

- Same endpoint as Data Crew, with the reserved `agent_id = "concierge"`.
- **`go_auth_token`** (optional) — the user's Google OAuth JWT. When provided, the server fetches the admin menu visible to this account and injects an `[Available Modules]` block into the model's system instructions for the session. This gives the Concierge awareness of which modules the user can navigate to. Omitting it is safe; the model simply won't have menu context.
- The session lives in the in-memory cache across WebSocket reconnects **for as long as the client keeps passing its `session_id` back** and the backend stays up within the 4-hour idle TTL. After a backend restart (or past that TTL), rehydration from BigQuery is automatic on the next connect with the same `session_id`.
- Right after `accept()` the server emits a [`session`](#51-outbound--server--client) frame; a [`history`](#62-history-replay-on-reconnect) frame follows if the conversation had any visible turns.

### Live mode switching

Live (voice) mode is entered and exited on the same `/chat/` connection by sending control messages. No second connection is needed; the same `session_id` is used throughout.

```js
// Enter live mode explicitly — server confirms with mode_changed
ws.send(JSON.stringify({ type: "start_live" }));

// Entry is also implicit: sending a top-level audio/image frame from standard
// mode enters live mode on its own and carries that frame into the session
ws.send(JSON.stringify({ audio: "<base64 PCM 16kHz mono s16le>" }));

// Exit live mode — server confirms with mode_changed
ws.send(JSON.stringify({ end_live: true }));
```

See [Section 9](#9-live-mode-voice) for the full protocol.

---

## 5. Message Protocol

All frames are JSON. Every outbound frame has `type` and `content`. Every inbound frame has either `text`, `context`, or a `type` field.

### 5.1. Outbound — server → client

| `type`                | When                                                     | `content` shape / siblings                                                                        |
| --------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `session`             | Exactly once, right after `accept()`                     | `{ "session_id": "<uuid>", "account": "…", "email": "…", "agent_id": "<id>", "model_id": "…", "status": "active", "created_at": "<iso>", "modified_at": "<iso>" }` |
| `history`             | Sent once on connect if a prior session exists           | `{ "agent_id": "<id>", "data": [ chat: {"role": "user"\|"model", "text", "agent_id", "attachments"?}, edits: {"role": "edit", "origin", "file_id", "from_version", "to_version", "diff"} ] }` — chat bubbles carry the producing `agent_id` (shared session) |
| `context_ack`         | After the server accepts a `context` message             | The stored context, or `null`                                                                     |
| `delta`               | Incremental streamed text from the model                 | `"<chunk>"` (plain string)                                                                        |
| `image`               | Inline image from a code-execution tool                  | `{ "mime_type": "image/png", "data": "<base64>" }`                                                |
| `executable_code`     | Model emitted code via Gemini native code execution      | `{ "code": "<source>", "language": "<lang>" }`                                                    |
| `code_execution_result` | Output of the model's native code execution            | `{ "output": "<stdout/text>", "outcome": "<status>" }`                                            |
| `tool_call`           | Model invoked a function                                 | `{ "name": "<fn>", "args": { … } }`                                                               |
| `tool_result`         | A function returned (summarised)                         | `{ "name": "<fn>", "result": { … } }`                                                             |
| `action_confirmation` | Action requires user confirmation (Tier 3)               | `{ "tool_name": "…", "summary": "…", "parameters": { … } }`                                       |
| `clarification`       | Model asked the user one or more questions (`ASK_USER`) — turn pauses for the reply | `{ "tool_name": "…", "questions": [{ "question": "…", "options": [{ "label": "…", "description"?: "…" }], "multi_select": <bool> }] }` |
| `agent_switched`      | The active agent changed for this turn (user handed the session to another agent) | `{ "from_agent_id": "…", "to_agent_id": "…", "agent_name": "…" }` |
| `navigate`            | `navigate` action method fired                           | `{ "target": "/admin/…", "params": { … } }`                                                       |
| `text_diff`           | An AI edit from `DOCUMENT_EDIT`. It carries a `to_version`, so it is a **committed** change — apply it, don't echo it back ([§5.4](#text-document-retrieve-and-edit-lifecycle)) | `{ "file_id": "…", "from_version": <int>, "to_version": <int>, "origin": "agent", "diff": "<git diff>", "old_value": "<full body before>", "new_value": "<full body after>" }` |
| `document_resync`     | Hard-reset a document — after a failed patch, or when an already-open document is retrieved again | `{ "file_id": "…", "version": <int>, "filename": "…", "mime_type": "…", "text": "<full body>" }`   |
| `final`               | Turn complete; full assembled model text                 | `content: "<full-text>"` **+ sibling** `attachments: [attachment record, …]`                      |
| `error`               | Anything went wrong                                      | `"<human-readable message>"`                                                                      |
| `mode_changed`        | Server confirms a live↔standard mode switch             | `{ "mode": "live" \| "standard" }`                                                                |
| `audio_output`        | _(live mode)_ Model speech chunk                         | `content: "<base64-encoded bytes>"`, **+ sibling** `mime_type: "<e.g. audio/pcm;rate=16000>"`     |
| `output_transcript`   | _(live mode)_ Model text alongside the audio response    | `content: "<text>"`, **+ sibling** `is_delta: <bool>` — `true` = streaming chunk, `false` = final assembled text for the turn |
| `input_transcript`    | _(live mode)_ Speech-to-text of what the user said, or the echo of a message they typed | `"<text>"` (plain string)                                                                         |
| `interrupted`         | _(live mode)_ The model was cut off mid-response (barge-in) | _(no content field)_ — stop playback and discard buffered audio                                |
| `turn_complete`       | _(live mode)_ Model has finished speaking for this turn  | _(no content field)_                                                                              |

`session.created_at` / `modified_at` are the timestamps of **this connect**, not the stored session record — a resumed session reports "now" for both. Use `GET /sessions` when you need the session's real creation time.

The `final` frame has two top-level siblings:

````json
{
  "type": "final",
  "content": "```chart\n826ae6dc-…\n```\nRevenue grew 24% over the past year, peaking in March…",
  "attachments": [
    {
      "file_id": "826ae6dc-…",
      "filename": "chart_0.json",
      "mime_type": "application/json",
      "kind": "plotly",
      "size_bytes": 12345,
      "backend": "gcs",
      "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
      "created_at": "2026-05-04T15:00:00+00:00",
      "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
    }
  ]
}
````

`attachments` is always present on `final` (empty array when no charts were produced in the turn). When `attachments` is non-empty, `content` contains ` ```chart\n<file_id>\n``` ` slot markers indicating where each chart should be rendered within the prose (see [Section 8](#8-attachments-and-chart-rendering)).

### 5.2. Inbound — client → server

| Shape                                                                         | Effect                                               |
| ----------------------------------------------------------------------------- | ---------------------------------------------------- |
| `{ "text": "…" }`                                                             | User prompt; starts (or continues) a turn            |
| `{ "text": "…", "attachments": [{…}] }`                                      | User prompt with one or more uploaded files          |
| `{ "text": "…", "focused_file_id": "…" }`                                    | User prompt naming the editable document the user is viewing (see below) |
| `{ "text": "…", "agent_id": "…" }`                                           | User prompt directed at a chosen agent — hands this (and subsequent) turns to that agent in the shared session (see [§6.7](#67-picking-the-agent-shared-sessions)) |
| `{ "context": { "module": "…", "page": "…", "…": "…" } }`                    | Update Concierge module context (no-op on Data Crew) |
| `{ "type": "action_confirm", "tool_name": "…" }`                              | Approve the pending Tier-3 action                    |
| `{ "type": "action_cancel", "tool_name": "…" }`                               | Decline the pending Tier-3 action                    |
| `{ "type": "elicit_response", "tool_name": "…", "answers": [["<label>", …], …] }`  | Answer a pending `clarification`; `answers[i]` is the chosen label(s) for question _i_ (empty inner array = that question dismissed) |
| `{ "type": "document_edit", "content": { "file_id": "…", "diff": "…", "origin"?: "user"\|"agent" } }` | Commit a **manual** change as a git diff (`origin: "user"`, the default); server owns the version. Do not use it to echo an agent `text_diff` back — those are already committed ([§5.4](#text-document-retrieve-and-edit-lifecycle)) |
| `{ "type": "start_live" }`                                                    | Enter live (voice) mode on this connection           |
| `{ "audio": "<base64 PCM 16kHz mono s16le>" }`                                | Microphone audio chunk. Sent in standard mode it enters live mode implicitly and is carried into the session |
| `{ "image": "<base64>", "mime_type": "…" }`                                   | Camera/screen frame. Same implicit entry as `audio`. Not the same as `attachments`, which ride on a text turn |
| `{ "end_turn": true }` _(live mode only)_                                     | Close the streamed audio turn opened by the first audio chunk since the last response (push-to-talk; server VAD is off) |
| `{ "end_live": true }` _(live mode only)_                                     | Exit live mode and return to standard text mode      |

Each attachment in the `attachments` array must have three fields:

```json
{
  "text": "Analyse the attached file and summarise the key metrics",
  "attachments": [
    {
      "filename": "june_revenue.csv",
      "mime_type": "text/csv",
      "data": "<base64-encoded file bytes>"
    }
  ]
}
```

`text` is **required** alongside attachments — a message with attachments but no text returns `error: "Please provide a message."`. For the full upload contract (allowed types, size limit, error responses) see [Section 8.3](#83-user-uploaded-file-attachments).

Blank `text` with no other recognised field gets an `error: "Please provide a message."` frame. Audio and video frames are exempt — they enter live mode instead of erroring (see [Section 9](#9-live-mode-voice)).

**`focused_file_id` (optional).** When the user has an editable document open in your preview/editor surface, include its `file_id` on the text turn:

```json
{ "text": "Tighten this intro", "focused_file_id": "b2c4…" }
```

This tells the server which document the user is looking at, so an **unqualified** edit request ("change this", "edit it") resolves to the focused tab instead of whichever document the model happened to touch last — and avoids a needless "which document?" clarification when several are open. Pass the `file_id` of the `editable` attachment the user currently has focused (the same `file_id` you track for `text_diff` and `document_edit`). A stale or closed `file_id` is ignored, so it's always safe to send. Omit it when no editable document is open. See [Section 8](#8-attachments-and-chart-rendering) and the edit lifecycle in [Section 5.4](#54-turn-lifecycle-with-tools) for how editable documents are delivered and tracked.

### 5.3. Turn lifecycle (no tools)

```
client → { "text": "hi" }

server → { "type": "delta",   "content": "He" }
server → { "type": "delta",   "content": "llo!" }
server → { "type": "final",   "content": "Hello!", "attachments": [] }
```

### 5.4. Turn lifecycle (with tools)

Tool calls may repeat several times before the model produces prose:

```
client → { "text": "How did revenue evolve?" }

server → { "type": "tool_call",   "content": { "name": "get_revenue_summary", "args": { "reference_date": "2026-04-23" } } }
server → { "type": "tool_result", "content": { "name": "get_revenue_summary", "result": { "row_count": 12, "columns": ["month", "total_revenue", "…"] } } }
server → { "type": "delta",       "content": "Over the last 12 months…" }
server → { "type": "delta",       "content": " revenue grew by 24%…" }
server → { "type": "final",       "content": "Over the last 12 months revenue grew by 24%…", "attachments": [] }
```

`tool_result.content.result` is a **summarised** view safe for the wire — for BigQuery tools, heavy row arrays are collapsed to `row_count` + `columns`. The full rows are not delivered to the client; where a tool produces a heavy result worth rendering, it ships it as an **attachment** instead (a chart, or a Malloy dashboard envelope carrying the complete row set).

#### `GENERATE_CHARTS` turn lifecycle

When the model invokes `GENERATE_CHARTS`, the `tool_result` carries a summary of what was produced. The actual renderable data arrives separately in `final.attachments`:

````
client → { "text": "Show me a chart of monthly revenue" }

server → { "type": "tool_call",   "content": { "name": "GENERATE_CHARTS", "args": { … } } }
server → { "type": "tool_result", "content": {
             "name": "GENERATE_CHARTS",
             "result": {
               "stdout": "",
               "stderr": "",
               "exit_code": 0,
               "artifacts": [
                 { "file_id": "826ae6dc-…", "filename": "chart_0.json", "mime_type": "application/json", "kind": "plotly" }
               ]
             }
           } }
server → { "type": "delta",  "content": "```chart\n826ae6dc-…\n```\nHere is the monthly revenue trend." }
server → { "type": "final",  "content": "```chart\n826ae6dc-…\n```\nHere is the monthly revenue trend.",
           "attachments": [
             { "file_id": "826ae6dc-…", "filename": "chart_0.json", "mime_type": "application/json",
               "size_bytes": 12345, "backend": "gcs",
               "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
               "created_at": "2026-05-12T10:00:00+00:00",
               "url": "https://storage.googleapis.com/…?X-Goog-Signature=…" }
           ] }
````

The `artifacts` array in `tool_result` is **informational only** — a uniform pointer (`file_id`, `filename`, `mime_type`, `kind`) telling you what was produced. Do **not** use those records for rendering; they carry no `url`. The `final.attachments` array is the authoritative source and carries freshly resolved URLs. See [Section 8](#8-attachments-and-chart-rendering) for the rendering walkthrough.

#### `MALLOY_ANALYTICS` turn lifecycle (dashboards)

`MALLOY_ANALYTICS` runs a curated query against the Malloy semantic layer. When the query targets a dashboard-tagged view (or the model passes `render_dashboard: true`), the turn additionally produces a **dashboard envelope** attachment with `kind: "malloy"`.

The delivery is the same pattern as charts — pointers in `tool_result`, renderable records in `final.attachments` — so there is no Malloy-specific event and no Malloy-specific field on `final`. You select it by `kind`:

````
client → { "text": "Give me the executive KPI summary" }

server → { "type": "tool_call",   "content": { "name": "MALLOY_ANALYTICS", "args": {
             "package_name": "bi_chat", "model_path": "kpi.malloy",
             "query": "run: kpi -> kpi_executive_summary", "render_dashboard": true } } }
server → { "type": "tool_result", "content": {
             "name": "MALLOY_ANALYTICS",
             "result": {
               "rows": [ … ≤20 rows … ],
               "row_count": 1,
               "columns": ["total_revenue", "total_sessions", "…"],
               "compiled_sql": "SELECT … FROM …",
               "request_id": "a1b2c3d4e5f6",
               "confidence_level": "authoritative",
               "source_report": "Malloy semantic layer / bi_chat/kpi.malloy",
               "artifacts": [
                 { "file_id": "9f2b1c77-…", "filename": "malloy_dashboard_a1b2c3.json",
                   "mime_type": "application/vnd.malloy.dashboard+json", "kind": "malloy" }
               ]
             }
           } }
server → { "type": "delta",  "content": "Revenue reached $5.82M across 1.89M sessions…" }
server → { "type": "final",  "content": "Revenue reached $5.82M across 1.89M sessions…",
           "attachments": [
             { "file_id": "9f2b1c77-…", "filename": "malloy_dashboard_a1b2c3.json",
               "mime_type": "application/vnd.malloy.dashboard+json", "kind": "malloy",
               "size_bytes": 4213, "backend": "gcs",
               "storage_key": "gs://bucket/charts/session_id/malloy_dashboard_a1b2c3.json",
               "created_at": "2026-07-01T10:15:42+00:00", "resource_id": null,
               "url": "https://storage.googleapis.com/…?X-Goog-Signature=…" }
           ] }
````

**Client contract:** filter `attachments` for `kind == "malloy"`, fetch the JSON at `url`, and hand it to the Malloy dashboard renderer. Same selection pattern as `kind == "plotly"` and `kind == "editable"`.

Unlike charts, **there are no slot markers** for dashboards — the prose does not reference the dashboard positionally. Render it as its own surface (a panel or card) alongside the reply.

The fetched envelope is `schema: "malloy.dashboard.v1"`:

```json
{
  "schema": "malloy.dashboard.v1",
  "package": "bi_chat",
  "model_path": "kpi.malloy",
  "view": "kpi_executive_summary",
  "query": "run: kpi -> kpi_executive_summary",
  "view_meta": { "name": "kpi_executive_summary", "dashboard": true, "…": "…" },
  "generated_at": "2026-07-01T10:15:42Z",
  "request_id": "a1b2c3d4e5f6",
  "compiled_sql": "SELECT … FROM …",
  "source_report": "Malloy semantic layer / bi_chat/kpi.malloy",
  "confidence_level": "authoritative",
  "result": { "rows": [ … full, untrimmed rows … ] }
}
```

The envelope holds the **complete** result set; the `rows` inline on `tool_result` are capped (20) precisely because the dashboard carries the full detail. `view_meta` carries the view's Malloy render tags (`# line_chart`, `# bar_chart`, nested view names) so the renderer knows the intended layout.

`compiled_sql` — the BigQuery SQL the Malloy query compiled to — is present on both the `tool_result` and the envelope, and `request_id` correlates the two with the server logs. It is provenance for a "show me the SQL" affordance; it is not required to render anything, and it can be long, so don't put it in a fixed-height layout.

When the query is an ad-hoc inline block rather than a dashboard-tagged view, no artifact is produced and `final.attachments` is empty — you just get rows and prose.

Malloy tool failures return a typed error the model self-corrects from (`compile_error`, `unexported_object`, `execution_error`, `budget_exceeded`, `retry_budget_exhausted`, `adapter_error`). These surface as an ordinary `tool_result` carrying `{"error": …, "error_type": …}`; the model normally explains the failure in the following prose, so rendering them is optional.

#### Text document retrieve and edit lifecycle

This is the contract behind Knowledge Composer **preview**, **edit**, **create**, and **save** (and any future text-document surface — the protocol is text-generic, not markdown-specific).

A document can enter preview two ways, both delivering an identical `editable` attachment on `final.attachments`: the agent **retrieves** an existing document, or the agent **creates** a new one from scratch (the model authors the body — no prior document needed). Once open, the document is revised via **edit** — the agent emits a diff you apply to your preview — and persisted via **save** or **publish**. Saving is an ordinary action tool call — you see a `tool_call`/`tool_result` pair and no document body crosses the wire (the server persists the copy it already holds).

There are **many** persistence tools, differing only in destination and in create-vs-update semantics. Which ones an agent actually has is per-account tool configuration; from the client's side they are all ordinary action calls — you never need to branch on which one fired:

| Tool | Purpose |
|---|---|
| `KNOWLEDGE_MARKDOWN_RETRIEVE` | Open an existing KB document into preview |
| `DOCUMENT_CREATE` | Author a brand-new document into preview (not yet persisted) |
| `DOCUMENT_EDIT` | Apply anchored edits to the previewed document → `text_diff` |
| `KNOWLEDGE_MARKDOWN_SAVE` / `…_SAVE_PY` | Persist a **new** document (creates a node) |
| `KNOWLEDGE_MARKDOWN_UPDATE` / `…_UPDATE_PY` | Persist edits to an **existing** node, in place |
| `KNOWLEDGE_MARKDOWN_SAVE_BIGQUERY` | Persist straight to the BigQuery content store |
| `KNOWLEDGE_COMPOSER_OPEN` | Hand the document off to the Knowledge Composer UI (a `navigate` action) |
| `KNOWLEDGE_PUBLISH` | Export the previewed document (PDF, Google Docs, Confluence) |
| `KNOWLEDGE_PUBLISH_BUNDLE` / `…_BUNDLE_QUICK` | Compose several KB nodes into one published Google Doc — the `_QUICK` variant skips the group/folder questions and uses the default destination |
| `KNOWLEDGE_COMPOSER_OPTIONS` | Fetch selectable groups / folders / themes, usually paired with `ASK_USER` |

Publish flows are confirmation-gated and typically preceded by one or more `clarification` rounds ([§6.6](#66-clarification-questions-ask_user)) to choose group, folder, and theme. Nothing new to handle for create, save, or publish beyond the `editable` attachment, `clarification`, and action frames you already render.

The attachment's `resource_id` tells you whether a previewed document is backed by a stored node — it carries the KB node id once one exists, and is `null` for a `DOCUMENT_CREATE` draft that has never been saved.

**Retrieve (preview).** When the agent retrieves a document, the body is delivered as an **attachment**, never inline in `final.content` and never as the primary `tool_result` payload. The `tool_result` summary carries only metadata (title, excerpt, `body_chars`, `file_id`); the renderable body arrives on `final.attachments` with `mime_type: text/markdown` (or another `text/*` type) and a resolved `url`:

````
client → { "text": "Open the Q1 review doc" }

server → { "type": "tool_call",   "content": { "name": "KNOWLEDGE_MARKDOWN_RETRIEVE", "args": { … } } }
server → { "type": "tool_result", "content": {
             "name": "KNOWLEDGE_MARKDOWN_RETRIEVE",
             "result": {
               "row_count": 1,
               "documents": [
                 { "file_id": "b2c4…", "filename": "q1-review.md", "mime_type": "text/markdown",
                   "title": "Q1 Review", "excerpt": "# Heading…", "body_chars": 5120, "doc_id": "kc-123" }
               ]
             }
           } }
server → { "type": "delta",  "content": "I've opened the Q1 review for preview." }
server → { "type": "final",  "content": "I've opened the Q1 review for preview.",
           "attachments": [
             { "file_id": "b2c4…", "filename": "q1-review.md", "mime_type": "text/markdown",
               "size_bytes": 5120, "backend": "gcs",
               "storage_key": "gs://bucket/charts/session_id/uuid_q1-review.md",
               "created_at": "2026-06-12T10:00:00+00:00",
               "url": "https://storage.googleapis.com/…?X-Goog-Signature=…" }
           ] }
````

Fetch `att.url` (it returns the raw document text) and render it in your preview pane. The `documents[].body` field is **never** on the wire — it stays in the model's context so the agent can edit without re-fetching.

**Which document is being edited.** The `text_diff` event's **`content.file_id` is the file_id of the document being edited** — the same `file_id` you received when the document was delivered (as a `kind: "editable"` attachment). Track delivered `editable` attachments by `file_id`; when a `text_diff` arrives, look that file_id up and update that document's preview. The diff is **not** an attachment (it rides the `text_diff` event); the change is replayed as a `role: "edit"` entry in the `history` frame on reconnect. `final.attachments` is empty on an edit turn.

**Telling the server which document is focused.** When several editable documents are open, an unqualified edit ("tighten this") is ambiguous. Send `focused_file_id` on the user turn (see [Section 5.2](#52-inbound--client--server)) with the `file_id` of the document the user currently has open, and the server routes the edit there. Without it, the edit falls back to the model's last-touched document.

**The server owns the document.** The server holds the authoritative copy of every open document and assigns it a monotonically increasing integer `version`. There are two ways it changes, and they commit differently:

- **Agent edits** (`DOCUMENT_EDIT`) are committed **by the server**, immediately, before the `text_diff` reaches you. Apply the diff to your preview and advance to its `to_version`. **Do not send anything back.**
- **Manual user edits** are committed **by you**, relayed as a git unified diff (`document_edit`, below). The server applies each to its copy and bumps the version.

> ⚠️ **This is a deliberate deviation from the staged accept/reject design** ([decision 2026-07-13](../../claude/decisions/2026-07-13-staged-ai-edits-accept-reject.md)), currently active server-side. In the staged model an agent `text_diff` was a *proposal* carrying no `to_version`, and the client committed it by echoing back a `document_edit { origin: "agent" }`. Today the server auto-commits agent edits and the `text_diff` **does** carry `to_version` — so echoing one back is a double-apply that will fail to patch and force a `document_resync`. Keep the accept/reject UI if you want it, but treat it as presentation: rejecting an edit means restoring the previous text yourself and relaying **that** as a manual `document_edit`.

**Edit (agent).** The `DOCUMENT_EDIT` tool computes anchored edits against the server's copy, commits them, and emits a `text_diff` carrying the diff, both versions, and the full body before and after:

````
client → { "text": "Tighten the intro and drop the disclaimer paragraph" }

server → { "type": "tool_call", "content": { "name": "DOCUMENT_EDIT", "args": { … } } }
server → { "type": "text_diff", "content": {
             "file_id": "b2c4…",
             "from_version": 1,
             "to_version": 2,
             "origin": "agent",
             "diff": "diff --git a/quarterly-review.md b/quarterly-review.md\n@@ -3,3 +3,1 @@\n-Old intro line one.\n-Old intro line two.\n-Old intro line three.\n+A tighter intro paragraph.\n",
             "old_value": "<full body at version 1>",
             "new_value": "<full body at version 2>"
           } }
server → { "type": "tool_result", "content": { "name": "DOCUMENT_EDIT",
             "result": { "status": "awaiting_user_decision", "proposed": 2 } } }
server → { "type": "delta",  "content": "I've tightened the intro — take a look in the preview." }
server → { "type": "final",  "content": "…", "attachments": [] }
````

Two things in that frame to be careful with:

- The `tool_result` still reads `status: "awaiting_user_decision"` and `proposed: <n>`. That string is a leftover of the staged model — **it does not mean the server is waiting for you**. Nothing is parked; the turn continues. Don't gate your UI on it.
- `old_value` / `new_value` are the complete document body before and after. Use `new_value` as a shortcut to reset your preview exactly, instead of patching `diff` yourself — it is the same text the server now holds. (They make the frame large for a big document; ignore them if you patch.)

**Rendering an accept/reject affordance.** Since the change is already committed, "reject" is an undo you author: take `old_value` (or invert the diff), write it back to your copy, and relay it as a manual `document_edit` with `origin: "user"`. The model is told about that follow-up change on its next turn, so it stays in sync.

`final.attachments` is empty on an edit turn — the diff rides the `text_diff` event, not an attachment.

**Committing a manual change (`document_edit`).** When the user types a change themselves, you commit it by sending the diff back to the server. `origin` is `"user"` (the default); `"agent"` exists for the staged model and should not be used while agent edits auto-commit. **You do not send a version** — the server owns it:

````
client → { "type": "document_edit", "content": {
             "file_id": "b2c4…",
             "diff": "diff --git a/quarterly-review.md b/quarterly-review.md\n@@ -8,0 +9 @@\n+A sentence the user typed.\n",
             "origin": "user"
           } }

// on success the server sends nothing back; on conflict it sends document_resync (below)
````

The server applies your diff to its current authoritative copy, bumps the version, and audits it. **A successful commit gets no reply** — you authored the change and already hold it, so advance your own copy's `version` by one; the server stays in step because it only ever applies your diffs. The model is told about the change on its next turn, so it edits against your latest text. For history, every committed change — yours and the agent's — is replayed as a `role: "edit"` entry in the `history` frame on reconnect.

Conflicts are detected by the patch itself, not by a version number: the server verifies every context/removed line in your diff against its current text. Include a few lines of context around your change (git's default 3 is plenty). A diff that touches a region the agent has since changed won't apply and you'll get a `document_resync`; edits to untouched regions merge cleanly even if an agent edit landed meanwhile.

**`document_resync` — hard reset.** The server sends the full authoritative body whenever your copy may have diverged from it. Two triggers:

1. **A failed patch** — your `document_edit` diff didn't apply to the server's current text.
2. **A re-open** — the agent retrieved a document that is *already open* in this session. Rather than minting a second preview, the server reuses the existing `file_id` and resyncs it, so the preview shows the current working body (including edits made since it was first opened) instead of the freshly fetched original. Note that no **new** `editable` attachment is delivered in that turn — the `tool_result` marks the document `"reopened": true` and the `document_resync` is how you get the body. A client that only reacts to attachments would show nothing.

Either way, hard-reset your copy to `text` and adopt `version`:

````
server → { "type": "document_resync", "content": {
             "file_id": "b2c4…", "version": 5, "filename": "quarterly-review.md",
             "mime_type": "text/markdown", "text": "<full authoritative body>"
           } }
````

**Versioning contract.** `version` is owned by the server and only ever increases; clients never send a version. An agent `text_diff` carries the `to_version` it was committed at — adopt it. When you relay a manual `document_edit`, just send the diff (no version): the server applies it to its current version, and on success there is no reply, so advance your own copy by one. If a diff doesn't apply, or a document is re-opened, you get a `document_resync` with the authoritative body and `version` — hard-reset to it. `version` is a per-session working counter, not a stored document revision.

**On reconnect**, rebuild the document from the `history` timeline: take the `editable` attachment body as version 0 and replay the `role: "edit"` entries for that `file_id` in order (see [§6.2](#62-history-replay-on-reconnect)). The last `to_version` is your current version, and the server has hydrated the matching copy, so your next edit lines up. Saving (any of the `KNOWLEDGE_MARKDOWN_SAVE*` / `…_UPDATE*` tools) separately persists the document to Knowledge Composer, the cross-session source of truth.

#### Native code execution events

When an agent uses Gemini's **native code execution** (distinct from the `GENERATE_CHARTS` tool), the model's own code and its output stream as two frames before the prose:

```
server → { "type": "executable_code",       "content": { "code": "print(2+2)", "language": "PYTHON" } }
server → { "type": "code_execution_result",  "content": { "output": "4", "outcome": "OUTCOME_OK" } }
server → { "type": "delta",                  "content": "The answer is 4." }
server → { "type": "final",                  "content": "The answer is 4.", "attachments": [] }
```

These are informational. Render them as an optional collapsible "ran code" block (code + output) or ignore them — the human-facing answer always follows in `delta`/`final`. They can appear on any `/chat/{agent_id}` connection in standard mode; a client that doesn't recognise them should drop them silently, never error.

> **Note for combined chat/voice screens:** a single `/chat/{agent_id}` socket carries both standard-mode frames (`delta`, `tool_call`, `text_diff`, `executable_code`, …) and live-mode frames (`audio_output`, `*_transcript`, …). Handle the full set on one connection and switch behaviour on `mode_changed`, rather than assuming a frame's mode from the screen state.

### 5.5. Audit roles

Most events described above are persisted to `bi_with_ai_chat_message`. Rows carry both a `role` and a `content_type`, and **the pair matters** — some flows share a role and are told apart only by `content_type`.

| role          | `content_type`      | When emitted                                              |
| ------------- | ------------------- | --------------------------------------------------------- |
| `user`        | `text`              | Every user text turn                                      |
| `user`        | `document_edit`     | Every **committed** document change — a manual client edit (`origin: "user"`) or a server-committed agent edit (`origin: "agent"`). Note the role is `user` for both, not `edit` |
| `model`       | `text`              | Every assembled model reply (when `final` is sent)        |
| `model`/`user`| `transcript`        | Live-mode speech transcripts (model and user respectively) |
| `tool_call`   | `function_call`     | Each `tool_call` outbound frame                           |
| `tool_result` | `function_response` | Each non-action `tool_result` frame                       |
| `action`      | `function_response` | Tier-3 action executions (confirmed, cancelled, or error) |

Two clarifications that trip people up:

- **There is no `role: "context"` row.** Module `context` frames are held in memory and prepended to the next user turn; they are acknowledged with `context_ack` but **not** persisted. Don't expect them in any history.
- **`role: "edit"` is not an audit role.** It exists only in the WebSocket `history` frame, synthesised from the `content_type: "document_edit"` rows. See [§6.2](#62-history-replay-on-reconnect).

---

## 6. Concierge Flow

This is the panel-style, always-on agent — documented in the [Migration Plan PDF, page 15–19](../WI-Migration%20Plan_%20BI%20with%20AI%20+%20Concierge%20Chat%20to%20Google%20Gen%20AI%20SDK.pdf). Four things make it different from Data Crew.

### 6.1. Persistent connection

Open the Concierge with the shared endpoint: `wss://host/chat/concierge?token=…[&go_auth_token=…][&session_id=<uuid>]`. The WebSocket stays open as the user navigates between admin modules.

- **First open after login**: connect without `session_id`, capture the id from the [`session`](#51-outbound--server--client) frame, stash it in `sessionStorage` (or any per-tab store).
- **Reconnect or page reload**: connect with `&session_id=<stashed id>`. The backend reuses the cached session if it's still warm (in-process, within the 4-hour idle TTL) or transparently rehydrates from BigQuery otherwise. Either way, the same conversation is attached.
- **New conversation button**: connect without `session_id`. The server will mint a fresh one and emit the corresponding `session` frame.

The session is cached by `(account, email, "concierge", session_id)`, so a user can have multiple Concierge conversations open in parallel (e.g., different tabs) without one overwriting another.

### 6.2. `history` replay on reconnect

Right after the server accepts the connection it emits a [`session`](#51-outbound--server--client) frame, then — if the bound conversation has any visible turns — a single `history` frame before any interactive traffic:

````json
{
  "type": "history",
  "content": {
    "agent_id": "concierge",
    "data": [
      { "role": "user", "text": "Any anomalies last week?" },
      {
        "role": "model",
        "text": "Yes — organic revenue dropped 18% on Tuesday…",
        "attachments": []
      },
      {
        "role": "user",
        "text": "Here is the raw export — can you cross-check against your figures?",
        "attachments": [
          {
            "file_id": "a4d8b12c-…",
            "filename": "june_revenue.csv",
            "mime_type": "text/csv",
            "size_bytes": 4096,
            "backend": "gcs",
            "storage_key": "gs://bucket/charts/session_id/uuid_june_revenue.csv",
            "created_at": "2026-05-03T10:45:00+00:00",
            "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
          }
        ]
      },
      {
        "role": "user",
        "text": "Show me a chart of that"
      },
      {
        "role": "model",
        "text": "```chart\n826ae6dc-…\n```\nThe chart shows the daily revenue dip clearly on Tuesday the 28th…",
        "attachments": [
          {
            "file_id": "826ae6dc-…",
            "filename": "chart_0.json",
            "mime_type": "application/json",
            "size_bytes": 12345,
            "backend": "gcs",
            "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
            "created_at": "2026-05-03T11:00:00+00:00",
            "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
          }
        ]
      },
      {
        "role": "edit",
        "origin": "agent",
        "file_id": "2bf474e0-…",
        "from_version": 0,
        "to_version": 1,
        "diff": "diff --git a/q1-review.md b/q1-review.md\n@@ -3 +3 @@\n-## Summary\n+## Overview\n"
      },
      {
        "role": "edit",
        "origin": "user",
        "file_id": "2bf474e0-…",
        "from_version": 1,
        "to_version": 2,
        "diff": "diff --git a/q1-review.md b/q1-review.md\n@@ -8,0 +9 @@\n+- A line the user typed.\n"
      }
    ]
  }
}
````

`attachments` appears on model entries that produced charts; it carries freshly resolved URLs so clients can render charts from history without a separate request. Entries with no attachments carry `"attachments": []` or may omit the field entirely.

**`role: "edit"` entries — document edits, not chat.** The timeline interleaves document edits with chat turns in chronological order. An edit entry carries `{origin: "agent"|"user", file_id, from_version, to_version, diff}` and **must not be rendered as a chat bubble**. Instead, **replay** it: apply `diff` to your in-memory copy of the document identified by `file_id`. The base you replay onto is the `editable` attachment body delivered earlier in the same timeline (its version 0); applying the edits in order brings your preview to the server's current version (the last `to_version` you see for that `file_id`). `from_version`/`to_version` let you verify ordering. Applying a `role: "edit"` entry is an ordinary unified-diff patch-apply, run in timeline order. Both the agent's edits and the user's manual edits appear, so a fresh client converges on the exact current document. A client that doesn't recognise `role: "edit"` must skip it (never render it), and the server has already hydrated its own authoritative copy, so subsequent edits stay consistent.

Client responsibilities:

1. Read `session_id` from the `session` frame and persist it (e.g., `sessionStorage`) — you need it for the next reconnect.
2. Render the `data` list from the `history` frame as prior turns (read-only). Render `role: "user"|"model"` as bubbles (with any `attachments`, see [Section 8](#8-attachments-and-chart-rendering)); for `role: "edit"`, replay the `diff` onto the matching `editable` document instead of rendering it.
3. If no `history` frame arrives within a short window after `session` (say 500 ms), treat the conversation as empty — it just means the session has no rows yet.
4. Fuller history — tool calls, actions, timestamps — is **not retrievable** by the client; no endpoint exposes it. Everything you can replay is in the `history` frame. (Module `context` frames are never persisted at all.)

**Important**: `history` carries replayed user/model text — typed turns and live-mode voice transcripts alike ([§9.5](#95-transcript-persistence-and-history-continuity)) — **plus `role: "edit"` document edits**. It is the timeline needed to both render the conversation and reconstruct the current document state. Other rows (tool calls, actions) are not in it, and module context was never persisted. If the backend process restarted between your last turn and now, the backend transparently rebuilt both the Gemini chat and the authoritative document copies from the BigQuery audit trail using the `session_id` you passed. BigQuery remains the durable record, but this frame is the only client-facing way to read it back.

### 6.3. Module context injection

Whenever the user navigates to an admin module (or changes filters, selects a report, etc.), send a context frame:

```json
{
  "context": {
    "module": "pdp_analytics",
    "page": "/analytics/pdp/overview",
    "entity_id": null,
    "metadata": {
      "date_range": "last_30_days",
      "filters_applied": ["category:shoes"]
    }
  }
}
```

Server behaviour:

- Acknowledges with `{"type": "context_ack", "content": <the context you sent>}` (or `null` if you sent an empty context, which clears it).
- Stashes the context in memory and **prepends it** as a `[Module Context] …` preamble to the very next `text` turn the user sends — so the model naturally sees the page state when it answers.
- Deduplicates: sending the same context twice in a row only prepends once.
- **Does not persist anything.** Context is in-memory only, scoped to the live handler; it is not audited and does not survive a reconnect. Re-send the current context after every reconnect.

Client guidance:

- Do **not** render context frames in the chat bubble list. They are not user-facing turns.
- Send a new context frame any time the user's situation changes meaningfully (route change, filter change, entity selection). The server is cheap about deduping.
- `context_ack` is a diagnostic — use it to confirm state if you want, but no UI is required.
- For agents where `requires_context: true`, send a context frame immediately after connect (before sending any user message) so the model has page awareness from the very first turn.

### 6.4. Action-taking tools (Tier 3)

Concierge tools of `tool_type = "action"` perform side-effects: call an admin API, write BigQuery rows, or ask the frontend to navigate. Two flavours:

Note that the **confirmation gate is not limited to `action` tools** — any tool may set `tool_requires_confirmation`, and side-effecting Python tools (the knowledge-base publish/save family) do. So an `action_confirmation` can name a tool that is not an action; handle it the same way regardless.

#### 6.4.1. Fire-and-forget actions (no confirmation)

When `tool_requires_confirmation = false`, the server executes the action inline as soon as the model calls the function. You'll see a normal `tool_call` / `tool_result` pair on the wire; the `tool_result` for a `navigate` action additionally triggers a dedicated frame:

```
server → { "type": "tool_call",   "content": { "name": "navigate_to_report", "args": { "target_path": "/analytics/pdp/overview", "params": { "category": "shoes" } } } }
server → { "type": "tool_result", "content": { "name": "navigate_to_report", "result": { "navigated": true, "target": "/analytics/pdp/overview", "params": { "category": "shoes" } } } }
server → { "type": "navigate",    "content": { "target": "/analytics/pdp/overview", "params": { "category": "shoes" } } }
server → { "type": "delta",       "content": "Opening PDP analytics for shoes…" }
server → { "type": "final",       "content": "Opening PDP analytics for shoes…", "attachments": [] }
```

When your client sees `{"type": "navigate", …}`, route the user to `content.target` (possibly with `content.params` turned into query string). No additional acknowledgement to the server is required.

#### 6.4.2. Actions that require confirmation

When `tool_requires_confirmation = true`, the flow pauses mid-turn. Sequence:

```
client → { "text": "Increase cross-sell weight for shoes to 0.5" }

server → { "type": "tool_call", "content": { "name": "update_recommendation_weight", "args": { "category": "shoes", "weight_type": "cross_sell", "new_weight": 0.5 } } }
server → { "type": "action_confirmation",
           "content": {
             "tool_name": "update_recommendation_weight",
             "summary":   "Set the cross-sell weight for shoes to 0.5.",
             "parameters": { "category": "shoes", "weight_type": "cross_sell", "new_weight": 0.5 }
           } }

    … server is now parked; no more outbound traffic until the client responds …

client → { "type": "action_confirm", "tool_name": "update_recommendation_weight" }

server → { "type": "tool_result", "content": { "name": "update_recommendation_weight", "result": { "affected_rows": 1 } } }
server → { "type": "delta",       "content": "Done — cross-sell weight for shoes is now 0.5." }
server → { "type": "final",       "content": "Done — cross-sell weight for shoes is now 0.5.", "attachments": [] }
```

On **cancel**, the client sends the same shape with `action_cancel`:

```
client → { "type": "action_cancel",  "tool_name": "update_recommendation_weight" }

server → { "type": "tool_result", "content": { "name": "update_recommendation_weight", "result": { "cancelled": true, "reason": "User declined the action." } } }
server → { "type": "delta",       "content": "No problem — I didn't change anything." }
server → { "type": "final",       "content": "No problem — I didn't change anything.", "attachments": [] }
```

`summary` is a **user-facing sentence**, resolved server-side in this order: a `summary` the model wrote for this specific call → the tool's configured confirmation prompt with the call's arguments filled in (e.g. `"Open {label}."` → `"Open PDP Analytics."`) → the humanised tool name as a last resort. It is safe to render verbatim; it never contains the model-facing tool description. `parameters` is the raw argument dict, for a "details" disclosure.

Client rules:

- When you receive `action_confirmation`, **pause the input box** and render a confirmation UI with `summary` and `parameters`. Offer **Confirm** and **Cancel** buttons.
- The `tool_name` in your reply MUST match the `tool_name` from the server. Mismatched names produce an `error` frame.
- The user may close the panel or navigate away while an action is pending. When they reopen, send `action_cancel` — the server will clean up. If the connection dropped, the pending-action state is lost (it lives on the WebSocket handler instance) and reconnecting starts fresh.
- Multiple confirmations can stack up in one turn (the model asked to do several things). The server pauses on each one in order; your UI should treat them one at a time.

### 6.5. Navigate actions and your router

The `navigate` frame is **independent** of the action_confirmation flow — it fires whether or not confirmation was required. Typical implementation:

```js
ws.addEventListener("message", (ev) => {
  const frame = JSON.parse(ev.data);
  if (frame.type === "navigate") {
    const qs = new URLSearchParams(frame.content.params ?? {}).toString();
    router.push(qs ? `${frame.content.target}?${qs}` : frame.content.target);
  }
});
```

### 6.6. Clarification questions (`ASK_USER`)

Some flows need the user to make a choice the model can't infer — for example, which group, folder, and theme to publish a document under. The model calls the `ASK_USER` tool, and the server pauses the turn on a `clarification` frame (the same park-and-wait mechanism as `action_confirmation`, but the reply carries the user's **selections** rather than a yes/no).

A clarification carries a `questions` **array** — the model may batch several questions that can be answered together (group and theme, say), while keeping a dependent question (folder options depend on the chosen group) for a later round. Render one picker per question and reply with a positional `answers` array:

```
client → { "text": "Publish these two nodes as a Google Doc" }

server → { "type": "tool_call",     "content": { "name": "ASK_USER", "args": { … } } }
server → { "type": "clarification",
           "content": {
             "tool_name": "ASK_USER",
             "questions": [
               {
                 "question": "Which group should this be published under?",
                 "options": [
                   { "label": "Marketing",   "description": "Group 002" },
                   { "label": "Engineering", "description": "Group 001" }
                 ],
                 "multi_select": false
               },
               {
                 "question": "Which theme?",
                 "options": [ { "label": "Winning Interactions", "description": "default" } ],
                 "multi_select": false
               }
             ]
           } }

    … server is now parked; no more outbound traffic until the client responds …

client → { "type": "elicit_response",
           "tool_name": "ASK_USER",
           "answers": [ ["Marketing"], ["Winning Interactions"] ] }

server → { "type": "tool_result",
           "content": { "name": "ASK_USER",
                        "result": { "answers": [
                          { "question": "Which group should this be published under?", "selected": ["Marketing"] },
                          { "question": "Which theme?", "selected": ["Winning Interactions"] }
                        ] } } }
server → …the turn continues (often a follow-up clarification for the folder, then the publish)…
```

Client rules:

- On `clarification`, **pause the input box** and render one picker **per question** in `questions` (`label` is the choice; `description` is optional helper text). Honour each question's `multi_select`: a single-choice picker when `false`, a multi-select when `true`.
- Reply with `elicit_response`. `answers` is **positional** — `answers[i]` is the array of chosen **`label`** strings for `questions[i]`. The `tool_name` MUST match the frame's `tool_name`.
- Collect **all** questions on one screen and submit them together — the server expects a single `elicit_response` for the whole batch.
- If the user dismisses a question without choosing, send `[]` for that position — the model is told that question was dismissed and will decide how to proceed rather than guessing.
- Like confirmations, several clarifications can still occur across one turn (e.g. group+theme, then folder); the server parks on each `clarification` in order, so handle them one at a time.
- Pending clarification state lives on the WebSocket handler instance: if the connection drops while parked, the turn is lost and reconnecting starts fresh.
- **Text mode only** — `ASK_USER` is not supported in live (voice) mode.

### 6.7. Picking the agent (shared sessions)

A session is a **shared transcript**, not a conversation with one fixed agent.
The agent named in the connect URL (`/chat/{agent_id}`) is only the *initial*
agent; the user can hand the conversation to any agent they can access, turn by
turn. Agents take turns — one active agent per turn — and the incoming agent
inherits the **full prior transcript** (every agent's turns) plus a one-shot
handoff note, so context carries across the switch.

To switch, include `agent_id` on the user turn:

```
client → { "text": "Now summarise the search trends", "agent_id": "sally_the_search_scout" }

server → { "type": "agent_switched",
           "content": { "from_agent_id": "concierge", "to_agent_id": "sally_the_search_scout", "agent_name": "Sally" } }
server → { "type": "tool_call", … }        # Sally now answers, with the whole thread as context
server → { "type": "final", "content": "…", "attachments": [] }
```

Client rules:

- Discover selectable agents via `GET /agents`; let the user pick one and send its `agent_id` on the next turn.
- `agent_id` is **sticky**: once switched, subsequent turns without an `agent_id` stay with that agent. Send it again only to switch.
- On `agent_switched`, update your "who's answering" affordance and attribute the upcoming turn (and its `final`) to `to_agent_id`.
- Omit `agent_id` (or send the current one) to keep the active agent. An `agent_id` the user can't access is ignored and the current agent continues.
- Every turn is persisted with its producing agent, so `history` bubbles carry an `agent_id` (see §6.2) — colour/label them per agent on replay.

Note: agent switching is a **text-mode** feature. Live (voice) mode runs the single agent it entered with.

---

## 7. Data Crew Flow (no action tooling)

Data Crew agents (Bob, Sally, Rex, Bart, …) answer analytics questions and can generate interactive charts. They don't modify state, so you'll never see `action_confirmation` or `navigate` frames on these connections — if you do, they were misconfigured and should be treated as normal tool results.

Minimal integration including chart attachment handling:

```js
const resumeId = loadStoredSessionId(agentId); // null on first open
const url = resumeId
  ? `wss://${HOST}/chat/${agentId}?token=${token}&session_id=${resumeId}`
  : `wss://${HOST}/chat/${agentId}?token=${token}`;
const ws = new WebSocket(url);

let streamingText = "";
let sessionId = null;

ws.onmessage = (ev) => {
  const frame = JSON.parse(ev.data);
  switch (frame.type) {
    case "session":
      sessionId = frame.content.session_id;
      storeSessionId(agentId, sessionId); // persist so you can resume this session
      break;
    case "history":
      hydrateHistoryPane(frame.content.data); // each entry may carry .attachments
      break;
    case "delta":
      streamingText += frame.content;
      renderAssistantMessage(streamingText);
      break;
    case "image":
      renderImage(
        `data:${frame.content.mime_type};base64,${frame.content.data}`,
      );
      break;
    case "tool_call":
      renderToolIndicator(`Calling ${frame.content.name}…`);
      break;
    case "tool_result":
      clearToolIndicator();
      break;
    case "final":
      streamingText = "";
      finalizeAssistantMessage(frame.content); // prose text
      renderAttachments(frame.attachments ?? []); // charts delivered out-of-band
      break;
    case "error":
      renderError(frame.content);
      break;
  }
};

function send(text) {
  ws.send(JSON.stringify({ text }));
}
```

`renderAttachments` receives the resolved attachment array. Branch on `kind`, not `mime_type` — `plotly` and `malloy` are both JSON but render completely differently:

```js
function renderAttachments(attachments) {
  for (const att of attachments) {
    if (!att.url) continue; // resolution failed — field is omitted, not null
    switch (att.kind) {
      case "plotly":
        renderPlotlyChart(att); // positioned by its ```chart slot marker
        break;
      case "malloy":
        renderMalloyDashboard(att); // own panel — no slot marker
        break;
      case "editable":
        openInPreviewPane(att); // track att.file_id for text_diff / document_edit
        break;
      case "image":
        renderInlineImage(att.url);
        break;
      default:
        renderDownloadChip(att); // "file", or an older row with kind === null
    }
  }
}
```

See [Section 8](#8-attachments-and-chart-rendering) for the full rendering walkthrough.

The Concierge integration is exactly this plus the three extra cases from Section 6 (`action_confirmation`, `navigate`, sending `context` on route changes).

---

## 8. Attachments and Chart Rendering

### Attachment record shape

Attachment records appear in two places: `final.attachments`, and each entry in `history.data[].attachments` on reconnect. Every record has the same shape and carries a freshly resolved, short-lived `url`:

```json
{
  "file_id": "826ae6dc-0c80-4139-a7d1-05eacc7e7f86",
  "filename": "chart_0.json",
  "mime_type": "application/json",
  "kind": "plotly",
  "size_bytes": 12345,
  "backend": "gcs",
  "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
  "created_at": "2026-05-04T15:00:00+00:00",
  "resource_id": null,
  "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
}
```

| Field         | Description                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file_id`     | Stable UUID identifying the file across sessions and requests. A bare UUID — no prefix                                                                                     |
| `filename`    | Original filename as produced by the tool                                                                                                                                  |
| `kind`        | **Semantic type — classify on this, not on `mime_type`.** One of `plotly`, `malloy`, `editable`, `image`, `file` (see table below). May be absent on older rows (`null`); when absent, fall back to inferring from `mime_type`. |
| `mime_type`   | IANA media type (`application/json`, `application/vnd.malloy.dashboard+json`, `text/markdown`, `image/png`, …)                                                             |
| `size_bytes`  | File size in bytes (may be `null` for older entries)                                                                                                                       |
| `backend`     | Storage backend: `gcs` or `local`                                                                                                                                          |
| `storage_key` | Internal storage key — `gs://bucket/path` for GCS or `local://path` for local                                                                                              |
| `created_at`  | ISO 8601 timestamp when the file was uploaded                                                                                                                              |
| `resource_id` | Stable identity of the **source record** this attachment was materialised from (a knowledge-base node id, ticket id, …), or `null`. Lets you link an `editable` document back to its origin without re-deriving it — e.g. to decide between a create-save and an update-save |
| `url`         | Freshly minted download URL. GCS signed URLs are short-lived (default: 24 h, `FILE_STORAGE_GCS_SIGNED_URL_TTL`). Reconnect the WebSocket to get fresh URLs if one expired. On a resolution failure the field is **omitted entirely** — guard for its absence rather than assuming `null` |

Render each attachment by its `kind`:

| `kind` | Typical `mime_type` | What to do |
|--------|---------------------|------------|
| `plotly` | `application/json` | Fetch `url`, render with plotly.js (see below). Positioned in the prose by a ` ```chart ` slot marker |
| `malloy` | `application/vnd.malloy.dashboard+json` | Fetch `url`, hand the `malloy.dashboard.v1` envelope to the Malloy dashboard renderer. **No slot marker** — render as its own panel ([§5.4](#malloy_analytics-turn-lifecycle-dashboards)) |
| `editable` | any `text/*` (markdown, code, config, …) | Fetch `url` for the body, render in a preview/editor. This is an **editable plain-text** body — remember its `file_id` (it opens at `version` 0); later `text_diff` events target it, and manual user edits are relayed back as `document_edit` |
| `image` | `image/png`, `image/jpeg`, … | Render inline |
| `file` | anything else | Show a download chip linking to `url` |

Only `plotly`, `malloy`, and `editable` are set explicitly by the producing tool. Anything stored without a declared kind — notably **user uploads** — falls back to `image` for `image/*` and `file` for everything else.

Edits (`text_diff`) are **not** attachments — they arrive as the `text_diff` event and are audited as committed `document_edit` rows (replayed as `role: "edit"` in `history`); never expect a diff in `final.attachments`.

### Rendering Plotly charts (`mime_type: "application/json"`)

Charts produced by the `GENERATE_CHARTS` tool are saved as Plotly figure JSON and delivered as `application/json` attachments. The model's `content` text contains ` ```chart\n<file_id>\n``` ` slot markers that indicate exactly where each chart should appear within the prose. The rendering flow is:

1. **Split** the `content` text on ` ```chart\n<file_id>\n``` ` blocks. Each block gives you the `file_id` of the chart to render at that position.
2. **Look up** the matching attachment by `file_id` in the `attachments` array.
3. **Fetch** `att.url` as JSON.
4. **Render** with `Plotly.newPlot(container, fig.data, fig.layout, fig.config ?? {})` at that position in the text.
5. **Continue** rendering the prose that follows the slot marker.

The fetched JSON is a serialised `go.Figure` object with `data`, `layout`, and (optionally) `config` keys, identical to what `plotly.io.to_json` produces.

Charts support zoom, pan, hover tooltips, and legend toggling out of the box.

````js
const CHART_SLOT_RE = /```chart\n([0-9a-f-]{36})\n```/g;

async function renderMessageContent(content, attachments) {
  const attachmentByFileId = Object.fromEntries(
    attachments.map((a) => [a.file_id, a]),
  );

  const parts = content.split(CHART_SLOT_RE);
  // split on a capturing group: [text, file_id, text, file_id, text, …]
  for (let i = 0; i < parts.length; i++) {
    if (i % 2 === 0) {
      // prose segment
      if (parts[i]) appendText(parts[i]);
    } else {
      // file_id segment
      const att = attachmentByFileId[parts[i]];
      if (att?.mime_type === "application/json") {
        const fig = await fetch(att.url).then((r) => r.json());
        const el = document.createElement("div");
        chatContainer.appendChild(el);
        Plotly.newPlot(el, fig.data, fig.layout, fig.config ?? {});
      }
    }
  }
}
````

### Chart slot markers

The model places one slot marker per chart, on its own line, immediately **before** the prose that interprets that chart:

````
```chart
826ae6dc-0c80-4139-a7d1-05eacc7e7f86
```
Revenue peaked in March, driven mainly by the shoes category…
````

Slots appear in the same order as the `artifacts` array in the `GENERATE_CHARTS` `tool_result` but the slot content holds an id corresponding to the attachments array. If the model produced no charts (or chart generation failed), no slot markers appear and `final.attachments` is empty.

### 8.3. User-uploaded file attachments

Users can attach files alongside a text prompt on the standard (`/chat/`) endpoint. The server validates, stores, and forwards each file to the model so the model can read its contents and respond accordingly.

#### Wire format

```json
{
  "text": "Analyse this export and highlight any negative trends",
  "attachments": [
    {
      "filename": "june_revenue.csv",
      "mime_type": "text/csv",
      "data": "<base64-encoded bytes>"
    }
  ]
}
```

Multiple attachments are supported in a single message — include multiple objects in the array.

#### Allowed MIME types

| Type                                                                       | Use case                        |
| -------------------------------------------------------------------------- | ------------------------------- |
| `text/csv`                                                                 | Spreadsheet exports, data files |
| `text/plain`                                                               | Plain text                      |
| `application/json`                                                         | Structured data                 |
| `application/pdf`                                                          | Documents, reports              |
| `application/vnd.malloy.dashboard+json`                                    | Malloy dashboard envelope       |
| `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`       | Excel workbooks (`.xlsx`)       |
| `image/png`, `image/jpeg`, `image/gif`, `image/webp`                      | Screenshots, diagrams           |

Any other MIME type returns an `error` frame and the message is not sent to the model.

> **Note:** `text/markdown` is **not** in the allowed set. Editable documents are *delivered* to you as `text/markdown` attachments, but a user cannot *upload* one — send markdown as `text/plain` instead.

#### Size limit

Each file may be at most **20 MB** (decoded). Larger files return an `error` frame.

#### Error responses

If validation fails or storage is unavailable the server responds with an `error` frame and does **not** forward anything to the model. Previously uploaded files from the same batch are deleted automatically.

Every failure — bad type, oversized, storage error — is reported through the **same wrapper**: `Failed to upload attachment '<filename>': <cause>`. Match on the cause, not the prefix:

```json
{ "type": "error", "content": "Failed to upload attachment 'export.zip': Unsupported MIME type 'application/zip' for 'export.zip'. Allowed: application/json, application/pdf, …" }
{ "type": "error", "content": "Failed to upload attachment 'dump.csv': Attachment 'dump.csv' is 23.4 MB; maximum is 20 MB" }
{ "type": "error", "content": "Failed to upload attachment 'data.csv': <storage error>" }
```

The batch is processed in order and aborts on the first bad file, so only one such frame arrives per message.

#### What the model receives

On GCS backends each attachment is forwarded as a `Part.from_uri` reference (the same `gs://…` path used by the file storage layer). On local backends the bytes are passed inline. Either way the model can read the full file content.

#### How attachments appear in history

Uploaded files are persisted on the **user message row** using the same [attachment record shape](#attachment-record-shape) as model-generated charts. They come back on `history.content.data[].attachments` for user entries when a session is resumed, with freshly resolved `url` values.

Render user attachment records however suits your UI — e.g. a small file chip with the `filename` that links to `url` for download. Reconnect the WebSocket to get fresh URLs if a signed URL has expired.

### Session resume and attachment URLs

Attachment `url` values are short-lived — GCS signed URLs expire after `FILE_STORAGE_GCS_SIGNED_URL_TTL` (default 24 h). Whenever the server hands you an attachment — on `final`, or in a `history` frame on reconnect — it mints a fresh URL at that moment, so URLs are always valid at render time. You do not need to cache or refresh them yourself.

If a URL has expired (a long-lived tab, a stored render), reconnect the WebSocket with the same `session_id` and take the URLs from the replayed `history` frame. Note that `resource_id`, `file_id`, and `storage_key` are stable across resolutions — only `url` changes — so you can key your own cache on `file_id` safely.

---

## 9. Live Mode (Voice)

Live mode connects the current `/chat/{agent_id}` session to the **Gemini Live API** (`gemini-live-2.5-flash-native-audio`) for real-time, voice-first conversation. It is entered and exited inline on the same WebSocket connection — no second connection, no new `session_id`. Text turns before and after a live segment all share the same conversation history.

### 9.1. Entering and exiting live mode

```
client → { "type": "start_live" }

server → { "type": "mode_changed", "content": { "mode": "live" } }

  … live audio exchange …

client → { "end_live": true }

server → { "type": "mode_changed", "content": { "mode": "standard" } }
```

**Entry is also implicit.** Sending `{"audio": …}` or `{"image": …}` while in standard mode enters live mode on its own — the server emits `mode_changed / live` and forwards that first frame into the session it opens, so nothing the user said is lost. Top-level `audio`/`image` are unambiguous because a still image attached to an ordinary text turn travels in `attachments`, not at the top level.

Prefer the explicit `start_live` anyway when you can: the provider handshake and history seeding happen before the server starts reading your media frames, so opening the session when the user taps the mic keeps that latency out of their first utterance. The implicit path is the safety net.

Exit stays explicit — silence is not the same as "done speaking", so the server never infers it.

The server rejects entry (explicit or implicit) while a text turn is in progress:

```json
{ "type": "error", "content": "Cannot switch to live mode while a response is in progress." }
```

After the server emits `mode_changed / standard`, the connection returns to normal text mode and you can send `{"text": "…"}` messages again. An `end_turn` or `end_live` frame that arrives after the session already closed is ignored rather than answered with an error.

### 9.2. Inbound messages during live mode (client → server)

| Shape                                                | Effect                                                                          |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- |
| `{ "audio": "<base64>" }`                            | PCM 16 kHz mono s16le chunk from the microphone                                 |
| `{ "image": "<base64>", "mime_type": "image/jpeg" }` | A video/camera frame — enables screen- or camera-sharing alongside voice        |
| `{ "text": "<string>" }`                             | A **complete typed turn** — the model answers immediately, no `end_turn` needed |
| `{ "end_turn": true }`                               | Closes the streamed audio turn opened by the first audio chunk since the last response, so the model responds (push-to-talk; server-side VAD is disabled). Ignored when no audio is awaiting a response — a video-only burst or a typed message closes on its own |
| `{ "end_live": true }`                               | Exits live mode; server returns to standard mode                                |

**Typed text is a whole turn, not streamed input.** Send `{"text": …}` on its own — do *not* follow it with `end_turn`. Three things happen server-side:

- **It interrupts.** If the model is still speaking, you get an `interrupted` frame before the new answer starts — typing over the model is barge-in, exactly like talking over it. Flush buffered audio on that frame as usual.
- **It is echoed back** as an `input_transcript` frame carrying the same text. Render *that* rather than optimistically appending the typed message locally, or it will appear twice. The echo is what makes the server authoritative, so a replayed session matches what the user saw.
- **It is persisted** as a `role: "user"` transcript row, so it comes back in `history` on resume.

**The answer is still audio.** The response modality is fixed when the live session connects, so a typed question gets a spoken answer plus `output_transcript` — not a `delta` stream. If the user wants the full text-mode agent (clarification gate, action confirmation, agent switching), send `end_live` first. A typed message never exits live mode on its own; doing so would tear down and rebuild the provider session per message.

Send audio chunks continuously as they arrive from the microphone. Chunks are queued and streamed to Gemini in order; no framing or length constraints on the client side. Video frames go on the same connection via `image` and are queued separately — the model receives them as visual context for the ongoing conversation. There is no outbound video event type; frames flow client → server only.

**Server-side VAD is disabled — `end_turn` is required to get a response.** Turn boundaries are push-to-talk, not silence-detected: the model will not answer just because the user paused or stopped talking. Send `{"end_turn": true}` when the user is done (e.g. releases a push-to-talk button or their own client-side VAD fires) to get a response to the streamed audio. Pausing the mic without sending it leaves the turn open.

### 9.3. Outbound events during live mode (server → client)

All outbound frames are JSON — there are no raw binary frames. Audio is delivered as base64 inside `audio_output` events.

| `type`               | `content` / siblings                                      | Description                                                                                       |
| -------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `audio_output`       | `content: "<base64>"`, `mime_type: "<format>"`            | Model speech chunk. Decode the base64 bytes and pipe to a Web Audio `AudioWorklet` or `AudioContext`. `mime_type` is typically `"audio/pcm;rate=16000"` but may vary — use it to choose a decoder. |
| `output_transcript`  | `content: "<text>"`, `is_delta: <bool>`                   | Model text transcript alongside the audio. `is_delta: true` is a streaming chunk; `is_delta: false` is the final assembled text for the turn (and the one that gets persisted). Use for captions. |
| `input_transcript`   | `content: "<text>"`                                       | What the user said, or the echo of a message they typed. Speech-to-text is available because `input_audio_transcription` is enabled by default. |
| `tool_call`          | `content: { name, args }`                                 | The model invoked a function **during voice**. Same shape as text mode.                           |
| `tool_result`        | `content: { name, result }`                               | The function returned (summarised). Same shape as text mode.                                      |
| `navigate`           | `content: { target, params }`                             | A navigate action fired during voice — route the user exactly as in text mode.                    |
| `text_diff`          | `content: { file_id, from_version, to_version, origin, diff, old_value, new_value }` | A document edit committed during voice. Rare (voice agents seldom carry document tools) but dispatched identically. |
| `document_resync`    | `content: { file_id, version, filename, mime_type, text }` | Same triggers as text mode.                                                                       |
| `interrupted`        | _(none)_                                                  | The model was cut off mid-response (the user barged in). **Stop playback and flush buffered audio immediately** — any attachments staged for the turn are discarded too. |
| `final`              | `content: ""`, `attachments: [ … ]`                       | Emitted **only when the turn produced attachments** (e.g. a chart or Malloy dashboard), just before `turn_complete`. `content` is always an empty string in live mode — the spoken answer is the audio. |
| `turn_complete`      | _(none)_                                                  | The model has finished speaking for this turn.                                                    |
| `error`              | `content: "<message>"`                                    | An error occurred in the Live session.                                                            |
| `mode_changed`       | `content: { "mode": "live" \| "standard" }`               | Confirms the mode switch (sent at entry and exit).                                                |

**Live mode is tool-capable.** Agents can call tools while speaking, so `tool_call` / `tool_result` frames — and a `final` carrying attachments — do occur in voice mode. Any client event a tool declares (`navigate`, `text_diff`, `document_resync`) is dispatched here too, through the same path as text mode.

What does *not* occur is `delta` (the answer is audio, not streamed text), `action_confirmation`, `clarification`, and `agent_switched`:

- **`ASK_USER` is removed from the toolset** for a live session — a tap-to-choose picker is meaningless mid-utterance, so the model simply asks the question aloud instead.
- **Agent switching is text-only.** A live session runs the single agent it entered with.
- **There is no confirmation gate in voice.** This is the one to watch: a tool with `tool_requires_confirmation` is **executed immediately** in live mode, without an `action_confirmation` frame and without asking the user. If an agent is voice-enabled, treat every side-effecting tool it carries as fire-and-forget, and scope its toolset accordingly.

If your voice UI shows charts or dashboards, handle `final` on the live connection exactly as you do in text mode — read `attachments`, ignore the empty `content`.

### 9.4. Example exchange

```
client → { "type": "start_live" }
server → { "type": "mode_changed",      "content": { "mode": "live" } }

# Client streams microphone audio
client → { "audio": "<base64 PCM chunk>" }
client → { "audio": "<base64 PCM chunk>" }
client → { "end_turn": true }

# Model may call tools mid-turn, then respond with audio chunks + transcripts
server → { "type": "tool_call",         "content": { "name": "KPI_ANALYTICS", "args": { … } } }
server → { "type": "tool_result",       "content": { "name": "KPI_ANALYTICS", "result": { "row_count": 12, "…": "…" } } }
server → { "type": "audio_output",      "content": "<base64>", "mime_type": "audio/pcm;rate=16000" }
server → { "type": "output_transcript", "content": "Revenue for Q1 was…", "is_delta": true }
server → { "type": "output_transcript", "content": "Revenue for Q1 was 5.8 million.", "is_delta": false }
server → { "type": "turn_complete" }

# User speech is transcribed (may arrive after turn_complete)
server → { "type": "input_transcript",  "content": "What was revenue in Q1?" }

# If the user barges in mid-answer, playback must stop
server → { "type": "interrupted" }

# A typed follow-up is a complete turn — echoed back, answered in audio, no end_turn
client → { "text": "Break that down by region." }
server → { "type": "input_transcript",  "content": "Break that down by region." }
server → { "type": "audio_output",      "content": "<base64>", "mime_type": "audio/pcm;rate=16000" }
server → { "type": "turn_complete" }

client → { "end_live": true }
server → { "type": "mode_changed",      "content": { "mode": "standard" } }

# Back to text mode — model has full context of the voice exchange
client → { "text": "And how does that compare to Q2?" }
server → { "type": "delta",  "content": "In Q2…" }
server → { "type": "final",  "content": "…", "attachments": [] }
```

### 9.5. Transcript persistence and history continuity

`output_transcript` and `input_transcript` turns — including messages typed in live mode, which are logged as user transcripts — are persisted to `bi_with_ai_chat_message` with `content_type = 'transcript'`. When the session returns to standard mode, the server rehydrates the conversation provider with those transcript rows so the model can reference the voice exchange in subsequent text turns. History continuity is automatic — no client action is needed.

Transcripts also come back to the **client** on reconnect: the `history` frame replays them as ordinary `role: "user"` / `role: "model"` entries, indistinguishable from typed turns. A resumed transcript therefore shows the spoken exchange inline with the text conversation. If you want to badge voice turns differently, you'd have to track them yourself while live — the replay carries no marker. A model turn cut off by a barge-in is stored with a trailing `[interrupted]` line.

---

## 10. Reconnect Semantics

| Surface   | Behaviour when you reconnect without `session_id` | Behaviour when you reconnect with `session_id`                                                       |
| --------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Data Crew | Brand-new conversation.                           | Same conversation: hot-reattach from cache if warm, else rehydrate user/model history from BigQuery. |
| Concierge | Brand-new conversation (the old one is orphaned). | Same conversation: cache hot-reattach or BQ rehydrate. Safe across backend restarts.                 |

Live mode exists within the `/chat/` session and is not a separate connection. Transcript turns produced during live mode are included in the rehydrated history the next time the session is resumed.

Recommended client reconnect strategy:

1. On every successful connect, capture `session_id` from the `session` frame and persist it (e.g., `sessionStorage`, keyed by tab + agent).
2. On reconnect (network drop, page reload), pass the stored `session_id` back as `&session_id=…`.
3. Use exponential backoff (`1s, 2s, 4s, 8s`, cap at 30s).
4. After each successful reconnect, wait up to 500 ms for a `history` frame before considering the conversation "empty" — it arrives only if the session had visible turns.
5. If the server closes with **1008** after passing `session_id`, treat the session as gone (expired, deleted, or never existed for this user) and reconnect without it to start fresh.
6. Keep `session_id` as the primary handle for the conversation — it is what you pass to resume, and what identifies the session in `GET /sessions`. The `history` frame is the whole replay surface.

---

## 11. Error Handling

| Situation                                           | Client behaviour                                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| WebSocket close code `1008`                         | Unauthorized. Refresh the token and reconnect; if that fails, bounce the user to login.                       |
| `{"type": "error", "content": "…"}`                 | Surface the message to the user. The connection stays open; the user can send another prompt.                 |
| Tool failure (returned as `tool_result` error dict) | Rendering is optional; the model will usually explain the failure in the next `delta`.                        |
| No `final` frame for a long time                    | Show a typing indicator. The server has a per-tool latency budget — eventually an `error` or `final` arrives. |
| Attachment `url` returns 403 / 404                  | The signed URL has expired. Reconnect the WebSocket with the same `session_id` and take fresh URLs from the `history` frame. |
| Attachment record has **no** `url` field            | URL resolution failed server-side (the field is omitted, not `null`). Show the filename without a link rather than fetching `undefined`. |
| `error` — `"Failed to upload attachment '<name>': …"` | One wrapper for every attachment failure — unsupported MIME type, over 20 MB, or a storage error. Read the cause after the colon: show the allowed list ([§8.3](#83-user-uploaded-file-attachments)) for a type error, prompt for a smaller file on a size error, offer retry on a storage error. Earlier files in the batch were cleaned up. |
| `error` — `"document_edit requires 'file_id' and 'diff'."` | Your `document_edit` frame was malformed. Nothing was committed.                                          |
| `error` — `"No open document with file_id '…'."`     | The document isn't open server-side (wrong id, or a session that never previewed it). Re-open it before editing. |
| `error` — "Please provide a message."                | Sent for a blank `text` with no other recognised field — including attachments with no accompanying text.     |
| `error` — "Cannot switch to live mode while a response is in progress." | You sent `start_live` — or an `audio`/`image` frame, which enters live mode too — while a text turn was still running. Wait for `final`, then retry. |
| A turn silently produces nothing                     | Only **one turn runs at a time** — a `text` sent while a turn is in flight is dropped server-side with no error frame. Disable the composer until `final` arrives. |
| `GET /malloy/ready` returns `503`                           | Malloy tooling is unavailable (Node compiler or package artifacts). `MALLOY_ANALYTICS` calls will fail; other agents still work. |

---

## 12. Quick Reference

### Outbound frame cheatsheet — `/chat/` (text mode)

```
session             { session_id, account, email, agent_id, model_id, status, created_at, modified_at }
history             { agent_id, data: [{role, text, agent_id, attachments?} | {role:"edit", origin, file_id, from_version, to_version, diff}] }
delta               "<chunk>"
image               { mime_type, data (base64) }
executable_code     { code, language }
code_execution_result { output, outcome }
tool_call           { name, args }
tool_result         { name, result }
action_confirmation { tool_name, summary, parameters }
clarification       { tool_name, questions: [{question, options: [{label, description?}], multi_select}] }   # ASK_USER — reply with elicit_response
agent_switched      { from_agent_id, to_agent_id, agent_name }   # user handed the turn to another agent
navigate            { target, params }
text_diff           { file_id, from_version, to_version, origin: "agent", diff, old_value, new_value }   # already committed — apply, never echo back
document_resync     { file_id, version, filename, mime_type, text: "<full body>" }   # failed patch, or a re-opened document
context_ack         <context echoed back, or null>
final               content: "<full text>",  attachments: [{attachment record + url}, …]   # kind ∈ plotly|malloy|editable|image|file
error               "<message>"
```

### Outbound frame cheatsheet — `/chat/` (live mode)

```
mode_changed        { mode: "live" | "standard" }   # confirms mode switch
audio_output        content: "<base64>",  mime_type: "<format>"   # model speech chunk
output_transcript   content: "<model text>",  is_delta: <bool>    # is_delta=false → final text for the turn
input_transcript    "<user speech>"                 # user speech-to-text, or the echo of a typed message
tool_call           { name, args }                  # live mode IS tool-capable (no confirmation gate)
tool_result         { name, result }
navigate            { target, params }              # tool-declared client events fire in voice too
text_diff           { file_id, from_version, to_version, origin, diff, old_value, new_value }
document_resync     { file_id, version, filename, mime_type, text }
interrupted         (no content field)              # barge-in — stop playback, flush buffers
final               content: "",  attachments: [...]  # only when the turn produced attachments
turn_complete       (no content field)
error               "<message>"
```

### Inbound frame cheatsheet — `/chat/` (text mode)

```
{ text: "…" }                                                       # user prompt
{ text: "…", attachments: [{filename, mime_type, data(base64)}] }   # user prompt + files
{ text: "…", focused_file_id: "…" }                                 # user prompt + the editable doc the user is viewing
{ text: "…", agent_id: "…" }                                        # user prompt directed at a chosen agent (shared session; sticky)
{ context: {...} }                                                   # module awareness (Concierge)
{ type: "action_confirm", tool_name: "…" }                          # approve pending action
{ type: "action_cancel",  tool_name: "…" }                          # decline pending action
{ type: "elicit_response", tool_name: "…", answers: [["<label>", …], …] }  # answer a clarification; answers[i] ↔ questions[i] (empty = dismissed)
{ type: "document_edit", content: { file_id, diff, [origin: "user"] } }  # commit a MANUAL change (git diff); agent edits are already committed server-side
{ type: "start_live" }                                              # enter live (voice) mode
```

### Inbound frame cheatsheet — `/chat/` (live mode)

```
{ audio: "<base64 PCM 16kHz mono s16le>" }        # microphone chunk (also enters live mode from standard)
{ image: "<base64>", mime_type: "image/jpeg" }    # camera / screen frame (same implicit entry)
{ text: "…" }                                     # COMPLETE typed turn — no end_turn; interrupts, echoed as input_transcript
{ end_turn: true }                                # close the streamed audio turn (push-to-talk; server VAD disabled)
{ end_live: true }                                # exit live mode
```

### URL templates

```
wss://host/chat/{agent_id}?token=<winp-token>                                          # Data Crew — new session
wss://host/chat/{agent_id}?token=<winp-token>&session_id=<uuid>                        # Data Crew — resume
wss://host/chat/concierge?token=<winp-token>&go_auth_token=<go-jwt>                    # Concierge — new session (with menu context)
wss://host/chat/concierge?token=<winp-token>&go_auth_token=<go-jwt>&session_id=<uuid>  # Concierge — resume (with menu context)

GET    /agents                                   (x-winp-token)
GET    /agents/{agent_id}                        (x-winp-token)   # one agent's identity (id, type, name, model)
DELETE /agents/cache                             (x-winp-token)   # invalidate cached agent configs
GET    /sessions                                 (x-winp-token)   # all of the user's sessions (shared, not agent-scoped)
DELETE /sessions/evict                           (x-winp-token)   # all of the user's sessions (not agent-scoped)
DELETE /sessions/{session_id}/evict              (x-winp-token)
GET    /sessions/count                           (x-winp-token)

GET    /malloy/status                            (no auth)        # liveness + version + malloy compiler pin
GET    /malloy/ready                             (no auth)        # readiness; 503 when malloy tooling is unavailable
GET    /malloy/schema                            (no auth)        # curated malloy semantic surface (ops tooling)
GET    /files/…                                  (no auth)        # local file-storage backend only
GET    /  and  /static/…                         (no auth)        # bundled demo-client reference UI

POST   /remote/{secret}/{agent_id}/{account}/{project}/{email}    # backend-only (BQ remote functions); body {"text": …} → {"response": …}
WS     /remote/{secret}/{agent_id}/{account}/{project}/{email}    # backend-only streaming variant
```

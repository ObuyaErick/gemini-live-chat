# BI with AI Chat: Consumer Guide

## Overview

The bi-with-ai-chat service provides WebSocket endpoints and supporting REST APIs to integrate generative AI conversational agents into frontend administrative interfaces. It powers three distinct surfaces: ephemeral, inquiry-focused "Data Crew" agents (`/chat/{agent_id}`), the persistent, state-aware "Concierge" panel (`/chat/concierge`) which survives reconnects and can execute user-confirmed administrative actions, and real-time voice conversations that can be entered at any point via the same `/chat/{agent_id}` connection using a `start_live` message. The `/chat/` endpoint uses a strictly typed, bidirectional JSON messaging contract covering streaming responses, historical audit replays, tool executions, frontend routing, module context injection, interactive chart delivery, and live audio events.

---

## 1. Architecture at a Glance

```txt
┌─────────────────────────┐        ┌─────────────────────────┐
│  Admin Frontend         │◀──────▶│  bi-with-ai-chat (this) │
│  - Data Crew chat page  │  WS/   │  - /chat/{agent_id}     │
│  - Concierge side panel │  HTTP  │  - /agents, /threads    │
│  - Voice interface      │        │                         │
└─────────────────────────┘        └──────────┬──────────────┘
                                              │ google-genai
                                              │ BigQuery (audit, tools, config)
                                              │ GCS / local (chart files)
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
| Live (voice)   | same `/chat/{agent_id}` connection             | JSON     | Entered via `{"type":"start_live"}`; exited via `{"end_live":true}`. Same session throughout.   |

All surfaces speak the **same JSON protocol** on `/chat/`. The server branches on `agent_id = "concierge"` to (a) keep the session cached across disconnects and (b) accept module `context` frames. Section 5 describes the full `/chat/` protocol (text and live events); Section 6 covers the Concierge-only behaviour; Section 9 covers live mode switching.

---

## 2. Authentication

All user-facing endpoints read the bearer token from the `token` query parameter.

- **WebSocket**: `wss://host/chat/bob_the_kpi_guy?token=<winp-token>`
- **HTTP**: send the token in the `x-winp-token` header instead.

The token is resolved against the Winp auth service to produce `{account, project, email}`. In `ENV=local` mode, the service bypasses the auth call and returns the values from `LOCAL_ACCOUNT` / `LOCAL_PROJECT` / `LOCAL_EMAIL` — useful for local development, never enabled in production.

Unauthorized connections are closed with WebSocket close code **1008**.

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

### `GET /agents/{agent_id}/threads`

Lists all sessions belonging to the authenticated user for `agent_id`, with the first user message per session as a preview. Use this to render a session history picker.

Request:

```http
GET /agents/bob_the_kpi_guy/threads
x-winp-token: <winp-token>
```

Response: `200 OK` — array of session objects, newest first.

```json
[
  {
    "session_id": "f3a1c2d4-…",
    "account": "acme",
    "email": "user@acme.com",
    "agent_id": "bob_the_kpi_guy",
    "model_id": "gemini-2.5-flash",
    "status": "active",
    "created_at": "2026-05-04T10:00:00+00:00",
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

`messages` contains the single earliest user message for each session, suitable for a preview card. If the session has no user message yet, `messages` is `null`.

### `GET /threads/{session_id}`

Returns the full BigQuery-backed audit history for a session. Use this when the in-memory WebSocket history isn't enough (server restarts, older than cache TTL, deeper detail with tool calls / actions / context turns).

Response: `200 OK`

````json
{
  "session": {
    "session_id": "…",
    "account": "…",
    "email": "…",
    "agent_id": "bob_the_kpi_guy",
    "model_id": "gemini-2.5-flash",
    "status": "active",
    "message_count": 12,
    "created_at": "…",
    "modified_at": "…"
  },
  "messages": [
    {
      "message_id": "…",
      "role": "user",
      "content": "How did revenue evolve?",
      "content_type": "text",
      "attachments": [],
      "created_at": "…"
    },
    {
      "message_id": "…",
      "role": "tool_call",
      "tool_name": "get_revenue_summary",
      "tool_arguments": "{…}",
      "attachments": [],
      "created_at": "…"
    },
    {
      "message_id": "…",
      "role": "tool_result",
      "tool_name": "get_revenue_summary",
      "content": "{…}",
      "attachments": [],
      "created_at": "…"
    },
    {
      "message_id": "…",
      "role": "model",
      "content": "```chart\n826ae6dc-…\n```\nRevenue grew by 24% over 12 months…",
      "content_type": "text",
      "latency_ms": 3400,
      "attachments": [
        {
          "file_id": "826ae6dc-…",
          "filename": "chart_0.json",
          "mime_type": "application/json",
          "size_bytes": 12345,
          "backend": "gcs",
          "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
          "created_at": "2026-05-04T10:01:00+00:00",
          "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
        }
      ],
      "created_at": "…"
    },
    {
      "message_id": "…",
      "role": "action",
      "tool_name": "update_recommendation_weight",
      "status": "ok",
      "attachments": [],
      "created_at": "…"
    }
  ]
}
````

`attachments` on each message row is an array of [attachment records](#attachment-record-shape) with freshly resolved `url` values. For model messages that produced charts, this array is non-empty. For all other roles, it is empty.

`content` on model messages may contain ` ```chart\n<file_id>\n``` ` slot markers — positional hints indicating where each chart belongs within the prose. Resolve each slot by looking up the `file_id` in the message's `attachments` array and rendering the chart in-place (see [Section 8](#8-attachments-and-chart-rendering)).

Role values and their meanings are defined in [Section 5.5](#55-audit-roles).

### `DELETE /sessions/evict`

Evicts every cached session belonging to the authenticated user, across all agents. Drops them from the in-memory SessionCache, deletes per-session file-storage subdirectories for every affected session, and marks matching BigQuery rows as `expired`. Returns `204 No Content`.

```http
DELETE /sessions/evict
x-winp-token: <winp-token>
```

### `DELETE /agents/{agent_id}/sessions/evict`

Same as `/sessions/evict` but scoped to a single agent — evicts all sessions for the authenticated user under `agent_id` only. Returns `204 No Content`.

```http
DELETE /agents/bob_the_kpi_guy/sessions/evict
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

Static file serving for chart output when `FILE_STORAGE_BACKEND=local`. The mount path is derived from the `FILE_STORAGE_LOCAL_PUBLIC_URL` environment variable (default: `/files`). Not present when `FILE_STORAGE_BACKEND=gcs` — GCS generates signed URLs directly.

---

## 4. Connecting the WebSocket

Every connection is bound to a single `session_id` for its lifetime. Live (voice) mode is entered and exited within the same connection — the session_id never changes.

### `/chat/` — Data Crew, Concierge, and Live mode

- **New conversation**: omit `session_id`. The server allocates a fresh UUID, creates the in-memory chat, and emits a [`session`](#51-outbound--server--client) frame carrying the id. **Capture it** — you'll need it for reconnects, and it's the key for `GET /threads/{session_id}`. The `bi_with_ai_chat_session` row is only written once you send your first user/context message, so connect-and-close without activity leaves no audit trail behind.
- **Resume a prior conversation**: pass `session_id=<uuid>` as a query param. The server rehydrates the conversation from BigQuery (user + model text turns, plus `role: "edit"` document edits to replay) and emits both a `session` frame (echoing the id you sent) and a `history` frame. If the `session_id` is malformed, missing, or belongs to a different user/agent, the socket is closed with code **1008**.

A single user can hold **multiple concurrent sessions** with the same agent — the in-memory cache is keyed by `(account, email, agent_id, session_id)`, so opening two browser tabs against Bob, each resumed from a different historical session, works correctly.

### Data Crew

```js
const ws = new WebSocket(`wss://${HOST}/chat/${agentId}?token=${token}`);
// …or, to resume an existing conversation:
const ws = new WebSocket(
  `wss://${HOST}/chat/${agentId}?token=${token}&session_id=${sessionId}`,
);
```

- `agentId` comes from the `/agents` list (e.g. `bob_the_kpi_guy`). Switching agents always gives you a fresh conversation (the agent_id is part of the cache key).
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
// Enter live mode — server confirms with mode_changed
ws.send(JSON.stringify({ type: "start_live" }));

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
| `session`             | Exactly once, right after `accept()`                     | `{ "session_id": "<uuid>", "agent_id": "<id>" }`                                                  |
| `history`             | Sent once on connect if a prior session exists           | `{ "agent_id": "<id>", "data": [ chat: {"role": "user"\|"model", "text", "attachments"?}, edits: {"role": "edit", "origin", "file_id", "from_version", "to_version", "diff"} ] }` |
| `context_ack`         | After the server accepts a `context` message             | The stored context, or `null`                                                                     |
| `delta`               | Incremental streamed text from the model                 | `"<chunk>"` (plain string)                                                                        |
| `image`               | Inline image from a code-execution tool                  | `{ "mime_type": "image/png", "data": "<base64>" }`                                                |
| `executable_code`     | Model emitted code via Gemini native code execution      | `{ "code": "<source>", "language": "<lang>" }`                                                    |
| `code_execution_result` | Output of the model's native code execution            | `{ "output": "<stdout/text>", "outcome": "<status>" }`                                            |
| `tool_call`           | Model invoked a function                                 | `{ "name": "<fn>", "args": { … } }`                                                               |
| `tool_result`         | A function returned (summarised)                         | `{ "name": "<fn>", "result": { … } }`                                                             |
| `action_confirmation` | Action requires user confirmation (Tier 3)               | `{ "tool_name": "…", "summary": "…", "parameters": { … } }`                                       |
| `navigate`            | `navigate` action method fired                           | `{ "target": "/admin/…", "params": { … } }`                                                       |
| `text_diff`           | A **proposed** AI edit from `DOCUMENT_EDIT` — render accept/reject; never a commit | `{ "file_id": "…", "from_version": <int>, "origin": "agent", "diff": "<git diff>" }` |
| `document_resync`     | Hard-reset a document after a conflict                   | `{ "file_id": "…", "version": <int>, "filename": "…", "mime_type": "…", "text": "<full body>" }`   |
| `final`               | Turn complete; full assembled model text                 | `content: "<full-text>"` **+ sibling** `attachments: [attachment record, …]`                      |
| `error`               | Anything went wrong                                      | `"<human-readable message>"`                                                                      |
| `mode_changed`        | Server confirms a live↔standard mode switch             | `{ "mode": "live" \| "standard" }`                                                                |
| `audio_output`        | _(live mode)_ Model speech chunk                         | `content: "<base64-encoded bytes>"`, **+ sibling** `mime_type: "<e.g. audio/pcm;rate=16000>"`     |
| `output_transcript`   | _(live mode)_ Model text alongside the audio response    | `"<text>"` (plain string)                                                                         |
| `input_transcript`    | _(live mode)_ Speech-to-text of what the user said       | `"<text>"` (plain string)                                                                         |
| `turn_complete`       | _(live mode)_ Model has finished speaking for this turn  | _(no content field)_                                                                              |

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
| `{ "context": { "module": "…", "page": "…", "…": "…" } }`                    | Update Concierge module context (no-op on Data Crew) |
| `{ "type": "action_confirm", "tool_name": "…" }`                              | Approve the pending Tier-3 action                    |
| `{ "type": "action_cancel", "tool_name": "…" }`                               | Decline the pending Tier-3 action                    |
| `{ "type": "document_edit", "content": { "file_id": "…", "diff": "…", "origin"?: "user"\|"agent" } }` | Commit a change as a git diff — a manual edit (`"user"`, default) or an accepted AI proposal (`"agent"`); server owns the version |
| `{ "type": "start_live" }`                                                    | Enter live (voice) mode on this connection           |
| `{ "audio": "<base64 PCM 16kHz mono s16le>" }` _(live mode only)_            | Microphone audio chunk                               |
| `{ "end_turn": true }` _(live mode only)_                                     | Signal the model to respond (client-side VAD)        |
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

Blank `text` with no other recognised field gets an `error: "Please provide a message."` frame. For audio input, send `{"type": "start_live"}` first to enter live mode (see [Section 9](#9-live-mode-voice)).

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

`tool_result.content.result` is a **summarised** view safe for the wire — for BigQuery tools, heavy row arrays are collapsed to `row_count` + `columns`. If you need the raw rows, query `/threads/{session_id}` for the audit entry.

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

#### Text document retrieve and edit lifecycle

This is the contract behind Knowledge Composer **preview**, **edit**, **create**, and **save** (and any future text-document surface — the protocol is text-generic, not markdown-specific).

A document can enter preview two ways, both delivering an identical `editable` attachment on `final.attachments`: the agent **retrieves** an existing document, or the agent **creates** a new one from scratch (the model authors the body — no prior document needed). Once open, the document is revised via **edit** — the agent *proposes* a change the user accepts or rejects — and persisted via **save**. Saving is an ordinary action tool call — you see a `tool_call`/`tool_result` pair and no document body crosses the wire (the server persists the copy it already holds). There may be more than one save tool (e.g. one writing to an API, one to BigQuery); they differ only in destination and all behave as normal action calls from your side. Nothing new to handle for create or save beyond the `editable` attachment and action frames you already render.

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

**Which document is being edited.** The `text_diff` event's **`content.file_id` is the file_id of the document being edited** — the same `file_id` you received when the document was delivered (as a `kind: "editable"` attachment). Track delivered `editable` attachments by `file_id`; when a `text_diff` arrives, look that file_id up and render the proposed change for that document for accept/reject. The diff is **not** an attachment (it rides the `text_diff` event); a committed change is recorded as a `role: "edit"` history row via `/threads`. `final.attachments` is empty on an edit turn.

**Telling the server which document is focused.** When several editable documents are open, an unqualified edit ("tighten this") is ambiguous. Send `focused_file_id` on the user turn (see [Section 5.2](#52-inbound--client--server)) with the `file_id` of the document the user currently has open, and the server routes the edit there. Without it, the edit falls back to the model's last-touched document.

**The server owns the document; the client owns the merge.** The server holds the authoritative copy of every open document and assigns it a monotonically increasing integer `version`. Changes are committed by **you**: the user's manual edits and the AI edits they accept are relayed to the server as a **git unified diff** (`document_edit`, below). The server applies each to its copy and bumps the version. AI edits arrive only as **proposals** — a `text_diff` you render for accept/reject — and never touch the server copy until you relay the accepted hunks. (A diff that no longer applies is corrected with `document_resync`.)

**Edit (propose → accept/reject).** The `DOCUMENT_EDIT` tool does **not** change the document — it **proposes** a change for the user to accept or reject. It emits a `text_diff` with a `diff` and `from_version`; a `text_diff` is **always** a proposal. Render the hunks in a review UI (accept/reject, per hunk if you like); nothing is committed on the server. The `tool_result` reports `status: "awaiting_user_decision"` and `proposed: <n>`:

````
client → { "text": "Tighten the intro and drop the disclaimer paragraph" }

server → { "type": "tool_call", "content": { "name": "DOCUMENT_EDIT", "args": { … } } }
server → { "type": "text_diff", "content": {          // a text_diff is always a PROPOSAL
             "file_id": "b2c4…",
             "from_version": 1,
             "origin": "agent",
             "diff": "diff --git a/quarterly-review.md b/quarterly-review.md\n@@ -3,3 +3,1 @@\n-Old intro line one.\n-Old intro line two.\n-Old intro line three.\n+A tighter intro paragraph.\n"
           } }
server → { "type": "tool_result", "content": { "name": "DOCUMENT_EDIT",
             "result": { "status": "awaiting_user_decision", "proposed": 2 } } }
server → { "type": "delta",  "content": "I've proposed a tighter intro — accept or reject it in the preview." }
server → { "type": "final",  "content": "…", "attachments": [] }
````

**Applying the decision.** The client owns the merge. When the user **accepts** (all or a subset of the hunks), apply the accepted hunks to your copy and sync them back as a `document_edit` with `origin: "agent"` — the same message you use for manual edits. When the user **rejects** everything, send **nothing**: the server never changed the document, so there is nothing to undo. To offer an **auto-apply** mode, make it a pure client behaviour — on receiving a proposal, immediately echo the full diff back as a `document_edit { origin: "agent" }`; the server needs no mode setting.

`final.attachments` is empty on an edit turn — the proposal rides the `text_diff` event, not an attachment.

**Committing a change (`document_edit`).** Whether the user typed the change themselves or accepted an AI proposal, you commit it by sending the diff back to the server. Set `origin` to `"user"` (manual, the default) or `"agent"` (an accepted proposal). **You do not send a version** — the server owns it:

````
client → { "type": "document_edit", "content": {
             "file_id": "b2c4…",
             "diff": "diff --git a/quarterly-review.md b/quarterly-review.md\n@@ -8,0 +9 @@\n+A sentence the user typed.\n",
             "origin": "user"
           } }

// on success the server sends nothing back; on conflict it sends document_resync (below)
````

The server applies your diff to its current authoritative copy, bumps the version, and audits it. **A successful commit gets no reply** — you authored the change and already hold it, so advance your own copy's `version` by one; the server stays in step because it only ever applies your diffs. The model is told about the change on its next turn, so it edits against your latest text. For history, `GET /threads/{session_id}` returns each committed change as a `role: "edit"` row (proposals are not recorded — only what the user committed).

Conflicts are detected by the patch itself, not by a version number: the server verifies every context/removed line in your diff against its current text. Include a few lines of context around your change (git's default 3 is plenty). A diff that touches a region the agent has since changed won't apply and you'll get a `document_resync`; edits to untouched regions merge cleanly even if an agent edit landed meanwhile.

**Conflict recovery (`document_resync`).** If your `from_version` is stale or the diff doesn't apply cleanly, the server replies with a `document_resync` carrying the full authoritative body — hard-reset your copy to it:

````
server → { "type": "document_resync", "content": {
             "file_id": "b2c4…", "version": 5, "filename": "quarterly-review.md",
             "mime_type": "text/markdown", "text": "<full authoritative body>"
           } }
````

**Versioning contract.** `version` is owned by the server and only ever increases; clients never send a version. A `text_diff` is always a **proposal** — it carries no version to adopt; you render it for accept/reject and commit it by relaying a `document_edit`. When you relay a `document_edit`, just send the diff (no version): the server applies it to its current version. **On success there is no reply** — advance your own copy by one; the server stays in step because it only ever applies your diffs. If a diff doesn't apply (you and the server diverged), you get a `document_resync` with the authoritative body and `version` — hard-reset to it. `version` is a per-session working counter, not a stored document revision.

**On reconnect**, rebuild the document from the `history` timeline: take the `editable` attachment body as version 0 and replay the `role: "edit"` entries for that `file_id` in order (see [§6.2](#62-history-replay-on-reconnect)). The last `to_version` is your current version, and the server has hydrated the matching copy, so your next edit lines up. Saving (`KNOWLEDGE_MARKDOWN_SAVE`) separately persists the document to Knowledge Composer, the cross-session source of truth.

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

Every event described above is also persisted to `bi_with_ai_chat_message` so the full history is replayable through `GET /threads/{session_id}`. Roles you'll see:

| role          | When emitted                                              |
| ------------- | --------------------------------------------------------- |
| `user`        | Every user text turn                                      |
| `model`       | Every assembled model reply (when `final` is sent)        |
| `tool_call`   | Each `tool_call` outbound frame                           |
| `tool_result` | Each non-action `tool_result` frame                       |
| `action`      | Tier-3 action executions (confirmed, cancelled, or error) |
| `context`     | Each Concierge `context` injection                        |

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

**`role: "edit"` entries — document edits, not chat.** The timeline interleaves document edits with chat turns in chronological order. An edit entry carries `{origin: "agent"|"user", file_id, from_version, to_version, diff}` and **must not be rendered as a chat bubble**. Instead, **replay** it: apply `diff` to your in-memory copy of the document identified by `file_id`. The base you replay onto is the `editable` attachment body delivered earlier in the same timeline (its version 0); applying the edits in order brings your preview to the server's current version (the last `to_version` you see for that `file_id`). `from_version`/`to_version` let you verify ordering. Applying a `role: "edit"` entry is an ordinary unified-diff patch-apply, run in timeline order. Both the accepted AI edits and the user's manual edits appear, so a fresh client converges on the exact current document. A client that doesn't recognise `role: "edit"` must skip it (never render it), and the server has already hydrated its own authoritative copy, so subsequent edits stay consistent.

Client responsibilities:

1. Read `session_id` from the `session` frame and persist it (e.g., `sessionStorage`) — you need it for the next reconnect and for `GET /threads/{session_id}`.
2. Render the `data` list from the `history` frame as prior turns (read-only). Render `role: "user"|"model"` as bubbles (with any `attachments`, see [Section 8](#8-attachments-and-chart-rendering)); for `role: "edit"`, replay the `diff` onto the matching `editable` document instead of rendering it.
3. If no `history` frame arrives within a short window after `session` (say 500 ms), treat the conversation as empty — it just means the session has no rows yet.
4. For fuller history — tool calls, actions, context turns, timestamps — fall back to `GET /threads/{session_id}` using the id from step 1.

**Important**: `history` carries replayed user/model text **plus `role: "edit"` document edits** — it is the timeline needed to both render the conversation and reconstruct the current document state. Other rows (tool calls, actions, context) are not in it. If the backend process restarted between your last turn and now, the backend transparently rebuilt both the Gemini chat and the authoritative document copies from the BigQuery audit trail using the `session_id` you passed. `GET /threads/{session_id}` remains the durable, complete record.

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

- Acknowledges with `{"type": "context_ack", "content": <the context you sent>}`.
- Writes a `role='context'` audit row.
- Stashes the context in memory and **prepends it** as a `[Module Context] …` preamble to the very next `text` turn the user sends — so the model naturally sees the page state when it answers.
- Deduplicates: sending the same context twice in a row only prepends once.

Client guidance:

- Do **not** render context frames in the chat bubble list. They are not user-facing turns.
- Send a new context frame any time the user's situation changes meaningfully (route change, filter change, entity selection). The server is cheap about deduping.
- `context_ack` is a diagnostic — use it to confirm state if you want, but no UI is required.
- For agents where `requires_context: true`, send a context frame immediately after connect (before sending any user message) so the model has page awareness from the very first turn.

### 6.4. Action-taking tools (Tier 3)

Concierge tools of `tool_type = "action"` perform side-effects: call an admin API, write BigQuery rows, or ask the frontend to navigate. Two flavours:

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
             "summary":   "update_recommendation_weight (category='shoes', weight_type='cross_sell', new_weight=0.5)",
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
      storeSessionId(agentId, sessionId); // persist for reconnect + /threads lookups
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

`renderAttachments` receives the resolved attachment array. For `mime_type: "application/json"` entries, fetch the `url` and render with Plotly.js (see [Section 8](#8-attachments-and-chart-rendering)).

The Concierge integration is exactly this plus the three extra cases from Section 6 (`action_confirmation`, `navigate`, sending `context` on route changes).

---

## 8. Attachments and Chart Rendering

### Attachment record shape

Attachment records appear in three places: `final.attachments`, each model entry in `history.data[].attachments`, and each message row in `GET /threads/{session_id}`. Every record has the same shape and carries a freshly resolved, short-lived `url`:

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
  "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
}
```

| Field         | Description                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file_id`     | Stable UUID identifying the file across sessions and requests                                                                                                              |
| `filename`    | Original filename as produced by the tool                                                                                                                                  |
| `kind`        | **Semantic type — classify on this, not on `mime_type`.** One of `plotly`, `editable`, `image`, `file` (see table below). May be absent on older rows (`null`); when absent, fall back to inferring from `mime_type`. |
| `mime_type`   | IANA media type (`application/json`, `text/markdown`, `text/x-python`, `image/png`, …)                                                                                     |
| `size_bytes`  | File size in bytes (may be `null` for older entries)                                                                                                                       |
| `backend`     | Storage backend: `gcs` or `local`                                                                                                                                          |
| `storage_key` | Internal storage key — `gs://bucket/path` for GCS or `local://path` for local                                                                                              |
| `created_at`  | ISO 8601 timestamp when the file was uploaded                                                                                                                              |
| `url`         | Freshly minted download URL. GCS signed URLs are short-lived (default: 24 h TTL). Re-request from `/threads/{session_id}` or reconnect the WebSocket if a URL has expired. |

Render each attachment by its `kind`:

| `kind` | Typical `mime_type` | What to do |
|--------|---------------------|------------|
| `plotly` | `application/json` | Fetch `url`, render with plotly.js (see below) |
| `editable` | any `text/*` (markdown, code, config, …) | Fetch `url` for the body, render in a preview/editor. This is an **editable plain-text** body — remember its `file_id` (it opens at `version` 0); later `text_diff` events target it, and manual user edits are relayed back as `document_edit` |
| `image` | `image/png`, `image/jpeg`, … | Render inline |
| `file` | anything else | Show a download chip linking to `url` |

Edits (`text_diff`) are **not** attachments — they arrive as the `text_diff` event and are recorded as `tool_result` rows; never expect a diff in `final.attachments`.

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
| `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`       | Excel workbooks (`.xlsx`)       |
| `image/png`, `image/jpeg`, `image/gif`, `image/webp`                      | Screenshots, diagrams           |

Any other MIME type returns an `error` frame and the message is not sent to the model.

#### Size limit

Each file may be at most **20 MB** (decoded). Larger files return an `error` frame.

#### Error responses

If validation fails or storage is unavailable the server responds with an `error` frame and does **not** forward anything to the model. Previously uploaded files from the same batch are deleted automatically:

```json
{ "type": "error", "content": "Unsupported MIME type 'application/zip' for 'export.zip'. Allowed: application/json, application/pdf, …" }
{ "type": "error", "content": "Attachment 'dump.csv' is 23.4 MB; maximum is 20 MB" }
{ "type": "error", "content": "Failed to upload attachment 'data.csv': <storage error>" }
```

#### What the model receives

On GCS backends each attachment is forwarded as a `Part.from_uri` reference (the same `gs://…` path used by the file storage layer). On local backends the bytes are passed inline. Either way the model can read the full file content.

#### How attachments appear in history

Uploaded files are persisted on the **user message row** using the same [attachment record shape](#attachment-record-shape) as model-generated charts. They appear in:

- `history.content.data[].attachments` for user entries when a session is resumed (with freshly resolved `url` values)
- `GET /threads/{session_id}` message rows for `role = "user"`

Render user attachment records however suits your UI — e.g. a small file chip with the `filename` that links to `url` for download. Re-request from `/threads/{session_id}` if a signed URL has expired.

### Session resume and attachment URLs

Attachment `url` values are short-lived (GCS signed URLs expire;). When resuming a session via `history` frames or `/threads/{session_id}`, the server resolves fresh URLs on every read — so you always get valid URLs at render time. You do not need to cache or refresh URLs yourself.

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

The server rejects `start_live` while a text turn is in progress:

```json
{ "type": "error", "content": "Cannot switch to live mode while a response is in progress." }
```

After the server emits `mode_changed / standard`, the connection returns to normal text mode and you can send `{"text": "…"}` messages again.

### 9.2. Inbound messages during live mode (client → server)

| Shape                                 | Effect                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------- |
| `{ "audio": "<base64>" }`             | PCM 16 kHz mono s16le chunk from the microphone                                 |
| `{ "text": "<string>" }`              | Text input alongside voice (e.g. a typed follow-up)                             |
| `{ "end_turn": true }`                | Signals the model to respond (use when voice activity detection is client-side) |
| `{ "end_live": true }`                | Exits live mode; server returns to standard mode                                |

Send audio chunks continuously as they arrive from the microphone. Chunks are queued and streamed to Gemini in order; no framing or length constraints on the client side.

### 9.3. Outbound events during live mode (server → client)

All outbound frames are JSON — there are no raw binary frames. Audio is delivered as base64 inside `audio_output` events.

| `type`               | `content` / siblings                                      | Description                                                                                       |
| -------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `audio_output`       | `content: "<base64>"`, `mime_type: "<format>"`            | Model speech chunk. Decode the base64 bytes and pipe to a Web Audio `AudioWorklet` or `AudioContext`. `mime_type` is typically `"audio/pcm;rate=16000"` but may vary — use it to choose a decoder. |
| `output_transcript`  | `content: "<text>"`                                       | Model text transcript emitted alongside the audio. Use this to display captions of what the model said. |
| `input_transcript`   | `content: "<text>"`                                       | Speech-to-text of what the user said. Available because `input_audio_transcription` is enabled by default. |
| `turn_complete`      | _(none)_                                                  | The model has finished speaking for this turn.                                                    |
| `error`              | `content: "<message>"`                                    | An error occurred in the Live session.                                                            |
| `mode_changed`       | `content: { "mode": "live" \| "standard" }`               | Confirms the mode switch (sent at entry and exit).                                                |

There are no `delta`, `final`, `tool_call`, or `action_confirmation` frames during live mode.

### 9.4. Example exchange

```
client → { "type": "start_live" }
server → { "type": "mode_changed",      "content": { "mode": "live" } }

# Client streams microphone audio
client → { "audio": "<base64 PCM chunk>" }
client → { "audio": "<base64 PCM chunk>" }
client → { "end_turn": true }

# Model responds with audio chunks + transcripts
server → { "type": "audio_output",      "content": "<base64>", "mime_type": "audio/pcm;rate=16000" }
server → { "type": "output_transcript", "content": "Revenue for Q1 was…" }
server → { "type": "turn_complete" }

# User speech is transcribed (may arrive after turn_complete)
server → { "type": "input_transcript",  "content": "What was revenue in Q1?" }

client → { "end_live": true }
server → { "type": "mode_changed",      "content": { "mode": "standard" } }

# Back to text mode — model has full context of the voice exchange
client → { "text": "And how does that compare to Q2?" }
server → { "type": "delta",  "content": "In Q2…" }
server → { "type": "final",  "content": "…", "attachments": [] }
```

### 9.5. Transcript persistence and history continuity

`output_transcript` and `input_transcript` turns are persisted to `bi_with_ai_chat_message` with `content_type = 'transcript'`. When the session returns to standard mode, the server rehydrates the conversation provider with those transcript rows so the model can reference the voice exchange in subsequent text turns. History continuity is automatic — no client action is needed.

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
6. Keep `session_id` as the primary handle for `GET /threads/{session_id}` — that endpoint remains the durable source of truth, including tool calls and actions not carried in the `history` frame.

---

## 11. Error Handling

| Situation                                           | Client behaviour                                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| WebSocket close code `1008`                         | Unauthorized. Refresh the token and reconnect; if that fails, bounce the user to login.                       |
| `{"type": "error", "content": "…"}`                 | Surface the message to the user. The connection stays open; the user can send another prompt.                 |
| Tool failure (returned as `tool_result` error dict) | Rendering is optional; the model will usually explain the failure in the next `delta`.                        |
| No `final` frame for a long time                    | Show a typing indicator. The server has a per-tool latency budget — eventually an `error` or `final` arrives. |
| Attachment `url` returns 403 / 404                  | The signed URL has expired. Re-request the session from `/threads/{session_id}` to get fresh URLs.            |
| `error` — unsupported MIME type                      | The file type is not in the allowed set. Check `ALLOWED_MIME_TYPES` in Section 8.3 and show the user the list. |
| `error` — file too large                             | The decoded payload exceeds 20 MB. Prompt the user to reduce the file size or split it.                       |
| `error` — failed to upload attachment                | A storage error occurred mid-upload. Previously uploaded files in the same batch were cleaned up. Retry.      |

---

## 12. Quick Reference

### Outbound frame cheatsheet — `/chat/` (text mode)

```
session             { session_id, agent_id }
history             { agent_id, data: [{role, text, attachments?}] }
delta               "<chunk>"
image               { mime_type, data (base64) }
executable_code     { code, language }
code_execution_result { output, outcome }
tool_call           { name, args }
tool_result         { name, result }
action_confirmation { tool_name, summary, parameters }
navigate            { target, params }
text_diff           { file_id, from_version, origin: "agent", diff }   # a proposed AI edit — accept/reject
document_resync     { file_id, version, filename, mime_type, text: "<full body>" }
context_ack         <context echoed back>
final               content: "<full text>",  attachments: [{attachment record + url}, …]
error               "<message>"
```

### Outbound frame cheatsheet — `/chat/` (live mode)

```
mode_changed        { mode: "live" | "standard" }   # confirms mode switch
audio_output        content: "<base64>",  mime_type: "<format>"   # model speech chunk
output_transcript   "<model text>"                  # caption of what the model said
input_transcript    "<user speech>"                 # speech-to-text of the user
turn_complete       (no content field)
error               "<message>"
```

### Inbound frame cheatsheet — `/chat/` (text mode)

```
{ text: "…" }                                                       # user prompt
{ text: "…", attachments: [{filename, mime_type, data(base64)}] }   # user prompt + files
{ text: "…", focused_file_id: "…" }                                 # user prompt + the editable doc the user is viewing
{ context: {...} }                                                   # module awareness (Concierge)
{ type: "action_confirm", tool_name: "…" }                          # approve pending action
{ type: "action_cancel",  tool_name: "…" }                          # decline pending action
{ type: "document_edit", content: { file_id, diff, [origin: "user"|"agent"] } }  # commit a change (git diff): manual ("user") or accepted AI proposal ("agent")
{ type: "start_live" }                                              # enter live (voice) mode
```

### Inbound frame cheatsheet — `/chat/` (live mode)

```
{ audio: "<base64 PCM 16kHz mono s16le>" }   # microphone chunk
{ text: "…" }                                # text input alongside voice
{ end_turn: true }                           # signal model to respond
{ end_live: true }                           # exit live mode
```

### URL templates

```
wss://host/chat/{agent_id}?token=<winp-token>                                          # Data Crew — new session
wss://host/chat/{agent_id}?token=<winp-token>&session_id=<uuid>                        # Data Crew — resume
wss://host/chat/concierge?token=<winp-token>&go_auth_token=<go-jwt>                    # Concierge — new session (with menu context)
wss://host/chat/concierge?token=<winp-token>&go_auth_token=<go-jwt>&session_id=<uuid>  # Concierge — resume (with menu context)

GET    /agents                                   (x-winp-token)
GET    /agents/{agent_id}/threads                (x-winp-token)
GET    /threads/{session_id}                     (x-winp-token)
DELETE /sessions/evict                           (x-winp-token)
DELETE /agents/{agent_id}/sessions/evict         (x-winp-token)
DELETE /sessions/{session_id}/evict              (x-winp-token)
GET    /sessions/count                           (x-winp-token)
```

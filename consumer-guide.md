# BI with AI Chat: Consumer Guide

## Overview

The bi-with-ai-chat service provides a unified WebSocket protocol and supporting REST APIs to integrate generative AI conversational agents into frontend administrative interfaces. Operating through a single endpoint (/chat/{agent_id}), it powers two distinct user experiences: ephemeral, inquiry-focused "Data Crew" agents and the persistent, state-aware "Concierge" panel, which survives reconnects and can execute user-confirmed administrative actions. All communication relies on a strictly typed, bidirectional JSON messaging contract that manages real-time streaming responses, historical audit replays, complex tool executions, automated frontend routing, dynamic module context injection, and interactive chart delivery.

---

## 1. Architecture at a Glance

```txt
┌─────────────────────────┐        ┌─────────────────────────┐
│  Admin Frontend         │◀──────▶│  bi-with-ai-chat (this) │
│  - Data Crew chat page  │  WS/   │  - /chat/{agent_id}     │
│  - Concierge side panel │  HTTP  │  - /agents, /threads    │
└─────────────────────────┘        └──────────┬──────────────┘
                                              │ google-genai
                                              │ BigQuery (audit, tools, config)
                                              │ GCS / local (chart files)
                                              ▼
                                    ┌─────────────────────┐
                                    │  Gemini (Vertex AI) │
                                    └─────────────────────┘
```

All conversations flow through a **single WebSocket endpoint**, `/chat/{agent_id}`. The `agent_id` path segment selects the agent (Bob, Sally, …) and also picks the Concierge:

| Surface   | URL                                           | Lifetime                                                                                        |
| --------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Data Crew | `/chat/{agent_id}?token=...[&session_id=...]` | Per-tab; session released on disconnect unless the client reconnects with the same `session_id` |
| Concierge | `/chat/concierge?token=...[&session_id=...]`  | Long-lived across reconnects **when the client passes the same `session_id` back**              |

The two surfaces speak the **same protocol**. The server branches on the reserved `agent_id = "concierge"` to (a) keep the session cached across disconnects and (b) accept module `context` frames. Section 5 describes the shared protocol; Section 6 covers the Concierge-only behaviour.

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

```json
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
      "content": "Revenue grew by 24% over 12 months…",
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
```

`attachments` on each message row is an array of [attachment records](#attachment-record-shape) with freshly resolved `url` values. For model messages that produced charts, this array is non-empty. For all other roles, it is empty.

`content` on model messages has any `attachment://` placeholders replaced with resolved URLs. (This is transparent to clients reading this endpoint, but worth knowing if you encounter a raw placeholder in older data.)

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

Every chat connection is bound to a single `session_id` for its lifetime.

- **New conversation**: omit `session_id`. The server allocates a fresh UUID, creates the in-memory chat, and emits a [`session`](#51-outbound--server--client) frame carrying the id. **Capture it** — you'll need it for reconnects, and it's the key for `GET /threads/{session_id}`. The `bi_with_ai_chat_session` row is only written once you send your first user/context message, so connect-and-close without activity leaves no audit trail behind.
- **Resume a prior conversation**: pass `session_id=<uuid>` as a query param. The server rehydrates the conversation from BigQuery (user + model text turns) and emits both a `session` frame (echoing the id you sent) and a `history` frame. If the `session_id` is malformed, missing, or belongs to a different user/agent, the socket is closed with code **1008**.

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
  `wss://${HOST}/chat/concierge?token=${token}&session_id=${sessionId}`,
);
```

- Same endpoint as Data Crew, with the reserved `agent_id = "concierge"`.
- The session lives in the in-memory cache across WebSocket reconnects **for as long as the client keeps passing its `session_id` back** and the backend stays up within the 4-hour idle TTL. After a backend restart (or past that TTL), rehydration from BigQuery is automatic on the next connect with the same `session_id`.
- Right after `accept()` the server emits a [`session`](#51-outbound--server--client) frame; a [`history`](#62-history-replay-on-reconnect) frame follows if the conversation had any visible turns.

---

## 5. Message Protocol

All frames are JSON. Every outbound frame has `type` and `content`. Every inbound frame has either `text`, `context`, or a `type` field.

### 5.1. Outbound — server → client

| `type`                | When                                           | `content` shape / siblings                                                                                |
| --------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `session`             | Exactly once, right after `accept()`           | `{ "session_id": "<uuid>", "agent_id": "<id>" }`                                                          |
| `history`             | Sent once on connect if a prior session exists | `{ "agent_id": "<id>", "data": [{"role": "user"\|"model", "text": "…", "attachments"?: [...]}] }`         |
| `context_ack`         | After the server accepts a `context` message   | The stored context, or `null`                                                                             |
| `delta`               | Incremental streamed text from the model       | `"<chunk>"` (plain string)                                                                                |
| `image`               | Inline image from a code-execution tool        | `{ "mime_type": "image/png", "data": "<base64>" }`                                                        |
| `tool_call`           | Model invoked a function                       | `{ "name": "<fn>", "args": { … } }`                                                                       |
| `tool_result`         | A function returned (summarised)               | `{ "name": "<fn>", "result": { … } }`                                                                     |
| `action_confirmation` | Action requires user confirmation (Tier 3)     | `{ "tool_name": "…", "summary": "…", "parameters": { … } }`                                               |
| `navigate`            | `navigate` action method fired                 | `{ "target": "/admin/…", "params": { … } }`                                                               |
| `final`               | Turn complete; full assembled model text       | `content: "<full-text>"` **+ sibling** `attachments: [attachment record, …]`                              |
| `error`               | Anything went wrong                            | `"<human-readable message>"`                                                                              |

The `final` frame has two top-level siblings:

```json
{
  "type": "final",
  "content": "Revenue grew 24% over the past year. The chart above shows the monthly breakdown…",
  "attachments": [
    {
      "file_id": "826ae6dc-…",
      "filename": "chart_0.json",
      "mime_type": "application/json",
      "size_bytes": 12345,
      "backend": "gcs",
      "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
      "created_at": "2026-05-04T15:00:00+00:00",
      "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
    }
  ]
}
```

`attachments` is always present on `final` (empty array when no charts were produced in the turn).

### 5.2. Inbound — client → server

| Shape                                                     | Effect                                               |
| --------------------------------------------------------- | ---------------------------------------------------- |
| `{ "text": "…" }`                                         | User prompt; starts (or continues) a turn            |
| `{ "context": { "module": "…", "page": "…", "…": "…" } }` | Update Concierge module context (no-op on Data Crew) |
| `{ "type": "action_confirm", "tool_name": "…" }`          | Approve the pending Tier-3 action                    |
| `{ "type": "action_cancel", "tool_name": "…" }`           | Decline the pending Tier-3 action                    |

Blank `text` with no other recognised field gets an `error: "Please provide a message."` frame.

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

Open the Concierge with the shared endpoint: `wss://host/chat/concierge?token=…[&session_id=<uuid>]`. The WebSocket stays open as the user navigates between admin modules.

- **First open after login**: connect without `session_id`, capture the id from the [`session`](#51-outbound--server--client) frame, stash it in `sessionStorage` (or any per-tab store).
- **Reconnect or page reload**: connect with `&session_id=<stashed id>`. The backend reuses the cached session if it's still warm (in-process, within the 4-hour idle TTL) or transparently rehydrates from BigQuery otherwise. Either way, the same conversation is attached.
- **New conversation button**: connect without `session_id`. The server will mint a fresh one and emit the corresponding `session` frame.

The session is cached by `(account, email, "concierge", session_id)`, so a user can have multiple Concierge conversations open in parallel (e.g., different tabs) without one overwriting another.

### 6.2. `history` replay on reconnect

Right after the server accepts the connection it emits a [`session`](#51-outbound--server--client) frame, then — if the bound conversation has any visible turns — a single `history` frame before any interactive traffic:

```json
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
        "text": "Show me a chart of that"
      },
      {
        "role": "model",
        "text": "The chart shows the daily revenue dip clearly on Tuesday the 28th…",
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
      }
    ]
  }
}
```

`attachments` appears on model entries that produced charts; it carries freshly resolved URLs so clients can render charts from history without a separate request. Entries with no attachments carry `"attachments": []` or may omit the field entirely.

Client responsibilities:

1. Read `session_id` from the `session` frame and persist it (e.g., `sessionStorage`) — you need it for the next reconnect and for `GET /threads/{session_id}`.
2. Render the `data` list from the `history` frame as prior turns (read-only). For model entries, render any `attachments` alongside the text (see [Section 8](#8-attachments-and-chart-rendering)).
3. If no `history` frame arrives within a short window after `session` (say 500 ms), treat the conversation as empty — it just means the session has no visible turns yet.
4. For fuller history — tool calls, actions, context turns, timestamps — fall back to `GET /threads/{session_id}` using the id from step 1.

**Important**: `history` is the replayed user/model text only (Gemini-style chat history). Tool calls, actions, and context rows are not in it. If the backend process restarted between your last turn and now, the backend transparently rebuilt the Gemini chat from the BigQuery audit trail using the `session_id` you passed. `GET /threads/{session_id}` remains the durable, complete record.

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
      finalizeAssistantMessage(frame.content);        // prose text
      renderAttachments(frame.attachments ?? []);     // charts delivered out-of-band
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
  "size_bytes": 12345,
  "backend": "gcs",
  "storage_key": "gs://bucket/charts/session_id/uuid_chart_0.json",
  "created_at": "2026-05-04T15:00:00+00:00",
  "url": "https://storage.googleapis.com/…?X-Goog-Signature=…"
}
```

| Field         | Description                                                                              |
| ------------- | ---------------------------------------------------------------------------------------- |
| `file_id`     | Stable UUID identifying the file across sessions and requests                            |
| `filename`    | Original filename as produced by the tool                                                |
| `mime_type`   | IANA media type. `application/json` = interactive Plotly chart; `image/png` = static image |
| `size_bytes`  | File size in bytes (may be `null` for older entries)                                    |
| `backend`     | Storage backend: `gcs` or `local`                                                        |
| `storage_key` | Internal storage key — `gs://bucket/path` for GCS or `local://path` for local           |
| `created_at`  | ISO 8601 timestamp when the file was uploaded                                            |
| `url`         | Freshly minted download URL. GCS signed URLs are short-lived (default: 24 h TTL). Re-request from `/threads/{session_id}` or reconnect the WebSocket if a URL has expired. |

### Rendering Plotly charts (`mime_type: "application/json"`)

Charts produced by the `generate_charts` tool are saved as Plotly figure JSON and delivered as `application/json` attachments. To render them interactively:

1. **Identify** entries in the `attachments` array where `mime_type === "application/json"`.
2. **Fetch** the `url` as JSON.
3. **Render** with `Plotly.react(container, data.data, data.layout, data.config)` (or `Plotly.newPlot`).

The fetched JSON is a serialised `go.Figure` object with `data`, `layout`, and (optionally) `config` keys, identical to what `plotly.io.to_json` produces.

Charts support zoom, pan, hover tooltips, and legend toggling out of the box.

```js
async function renderAttachments(attachments) {
  for (const att of attachments) {
    if (att.mime_type === "application/json") {
      const fig = await fetch(att.url).then((r) => r.json());
      const el = document.createElement("div");
      chatContainer.appendChild(el);
      Plotly.newPlot(el, fig.data, fig.layout, fig.config ?? {});
    }
  }
}
```

### Charts are delivered out-of-band

The model's `content` text (in `final` or `history`) is **prose only** — the model is instructed not to embed image markdown, filenames, or `attachment://` references. Clients should display the prose text and the rendered charts side-by-side; the text interprets the chart but does not point to it by URL.

### Session resume and attachment URLs

Attachment `url` values are short-lived (GCS signed URLs expire; local URLs are reachable only while the server is running). When resuming a session via `history` frames or `/threads/{session_id}`, the server resolves fresh URLs on every read — so you always get valid URLs at render time. You do not need to cache or refresh URLs yourself.

---

## 9. Reconnect Semantics

| Surface   | Behaviour when you reconnect without `session_id` | Behaviour when you reconnect with `session_id`                                                       |
| --------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Data Crew | Brand-new conversation.                           | Same conversation: hot-reattach from cache if warm, else rehydrate user/model history from BigQuery. |
| Concierge | Brand-new conversation (the old one is orphaned). | Same conversation: cache hot-reattach or BQ rehydrate. Safe across backend restarts.                 |

Recommended client reconnect strategy:

1. On every successful connect, capture `session_id` from the `session` frame and persist it (e.g., `sessionStorage`, keyed by tab + agent).
2. On reconnect (network drop, page reload), pass the stored `session_id` back as `&session_id=…`.
3. Use exponential backoff (`1s, 2s, 4s, 8s`, cap at 30s).
4. After each successful reconnect, wait up to 500 ms for a `history` frame before considering the conversation "empty" — it arrives only if the session had visible turns.
5. If the server closes with **1008** after passing `session_id`, treat the session as gone (expired, deleted, or never existed for this user) and reconnect without it to start fresh.
6. Keep `session_id` as the primary handle for `GET /threads/{session_id}` — that endpoint remains the durable source of truth, including tool calls and actions not carried in the `history` frame.

---

## 10. Error Handling

| Situation                                           | Client behaviour                                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| WebSocket close code `1008`                         | Unauthorized. Refresh the token and reconnect; if that fails, bounce the user to login.                       |
| `{"type": "error", "content": "…"}`                 | Surface the message to the user. The connection stays open; the user can send another prompt.                 |
| Tool failure (returned as `tool_result` error dict) | Rendering is optional; the model will usually explain the failure in the next `delta`.                        |
| No `final` frame for a long time                    | Show a typing indicator. The server has a per-tool latency budget — eventually an `error` or `final` arrives. |
| Attachment `url` returns 403 / 404                  | The signed URL has expired. Re-request the session from `/threads/{session_id}` to get fresh URLs.            |

---

## 11. Quick Reference

### Outbound frame cheatsheet

```
session             { session_id, agent_id }
history             { agent_id, data: [{role, text, attachments?}] }
delta               "<chunk>"
image               { mime_type, data (base64) }
tool_call           { name, args }
tool_result         { name, result }
action_confirmation { tool_name, summary, parameters }
navigate            { target, params }
context_ack         <context echoed back>
final               content: "<full text>",  attachments: [{attachment record + url}, …]
error               "<message>"
```

### Inbound frame cheatsheet

```
{ text: "…" }                                  # user prompt
{ context: {...} }                             # module awareness
{ type: "action_confirm", tool_name: "…" }     # approve pending action
{ type: "action_cancel",  tool_name: "…" }     # decline pending action
```

### URL templates

```
wss://host/chat/{agent_id}?token=<winp-token>                       # Data Crew — new session
wss://host/chat/{agent_id}?token=<winp-token>&session_id=<uuid>     # Data Crew — resume

GET    /agents                                   (x-winp-token)
GET    /agents/{agent_id}/threads                (x-winp-token)
GET    /threads/{session_id}                     (x-winp-token)
DELETE /sessions/evict                           (x-winp-token)
DELETE /agents/{agent_id}/sessions/evict         (x-winp-token)
DELETE /sessions/{session_id}/evict              (x-winp-token)
GET    /sessions/count                           (x-winp-token)
```

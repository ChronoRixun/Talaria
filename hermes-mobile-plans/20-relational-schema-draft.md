# Hermes Mobile Relational Schema Draft

## Purpose
Provide a practical first-pass relational schema for the relay/backend so implementation can begin without inventing the data model ad hoc.

This is intentionally modest. It should support the first real product flows without premature over-modeling.

Suggested default database:
- Postgres

---

## Design principles
- optimize for clarity
- use UUID primary keys
- audit sensitive actions
- keep optional tables optional
- avoid exotic database patterns until needed

---

## Table: users
Purpose:
- app user identity

Suggested columns:
- `id uuid primary key`
- `display_name text`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Notes:
- auth/account model can stay simple early on
- if open source, self-hosters may use a minimal single-user mode initially

---

## Table: devices
Purpose:
- one row per mobile installation/device

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `platform text not null` -- ios
- `installation_id text not null unique`
- `device_name text`
- `device_model text`
- `system_version text`
- `app_version text`
- `build_number text`
- `bundle_id text`
- `environment text`
- `is_active boolean not null default true`
- `last_seen_at timestamptz`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- unique on `installation_id`
- index on `user_id`

---

## Table: auth_sessions
Purpose:
- session/refresh token tracking if using server-issued sessions

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)`
- `refresh_token_hash text not null`
- `expires_at timestamptz not null`
- `revoked_at timestamptz`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- index on `user_id`
- index on `device_id`

---

## Table: push_registrations
Purpose:
- APNs token registry per device

Suggested columns:
- `id uuid primary key`
- `device_id uuid references devices(id)`
- `apns_token text not null`
- `push_environment text not null` -- sandbox or production
- `is_active boolean not null default true`
- `last_registered_at timestamptz not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- index on `device_id`
- optional unique constraint on (`device_id`, `apns_token`)

---

## Table: conversations
Purpose:
- durable conversation container

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `title text`
- `is_archived boolean not null default false`
- `last_message_at timestamptz`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- index on `user_id`
- index on `last_message_at`

---

## Table: messages
Purpose:
- durable message records

Suggested columns:
- `id uuid primary key`
- `conversation_id uuid references conversations(id)`
- `user_id uuid references users(id)`
- `role text not null` -- user, hermes, system
- `text text not null`
- `client_message_id uuid`
- `delivery_status text`
- `created_at timestamptz not null`

Indexes:
- index on `conversation_id`, `created_at`
- index on `client_message_id`

---

## Table: inbox_items
Purpose:
- async actionable items shown in the app

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)` nullable
- `kind text not null`
- `title text not null`
- `body text not null`
- `priority text not null default 'normal'`
- `status text not null default 'pending'`
- `payload jsonb` -- structured contextual data
- `expires_at timestamptz`
- `opened_at timestamptz`
- `completed_at timestamptz`
- `dismissed_at timestamptz`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- index on `user_id`, `status`, `created_at`
- index on `device_id`

---

## Table: inbox_actions
Purpose:
- track actions taken on inbox items

Suggested columns:
- `id uuid primary key`
- `inbox_item_id uuid references inbox_items(id)`
- `action_id text not null` -- approve, dismiss, open, etc.
- `actor_type text not null` -- user, system
- `payload jsonb`
- `result jsonb`
- `created_at timestamptz not null`

Indexes:
- index on `inbox_item_id`

---

## Table: capability_requests
Purpose:
- track device capability requests initiated by Hermes/relay

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)` nullable
- `capability_type text not null` -- location, health, camera, photos, canvas
- `reason text`
- `status text not null default 'pending'`
- `source text not null` -- hermes, relay, app
- `request_payload jsonb`
- `expires_at timestamptz`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Indexes:
- index on `user_id`, `capability_type`, `status`

---

## Table: capability_results
Purpose:
- store structured outputs from device capability flows

Suggested columns:
- `id uuid primary key`
- `capability_request_id uuid references capability_requests(id)`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)`
- `capability_type text not null`
- `result_payload jsonb not null`
- `summary text`
- `captured_at timestamptz`
- `created_at timestamptz not null`

Indexes:
- index on `capability_request_id`
- index on `user_id`, `capability_type`

---

## Table: media_uploads
Purpose:
- track uploaded media metadata

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)`
- `capability_request_id uuid references capability_requests(id)` nullable
- `storage_url text not null`
- `media_type text not null`
- `mime_type text`
- `size_bytes bigint`
- `created_at timestamptz not null`

Indexes:
- index on `user_id`
- index on `capability_request_id`

---

## Table: voice_sessions
Purpose:
- optional metadata for Talk Mode sessions

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)`
- `device_id uuid references devices(id)`
- `provider text not null` -- openai
- `model text`
- `transport text` -- webrtc, websocket
- `started_at timestamptz not null`
- `ended_at timestamptz`
- `summary text`
- `created_at timestamptz not null`

Indexes:
- index on `user_id`, `started_at`

---

## Table: audit_log
Purpose:
- trace sensitive operations for debugging and privacy review

Suggested columns:
- `id uuid primary key`
- `user_id uuid references users(id)` nullable
- `device_id uuid references devices(id)` nullable
- `event_type text not null`
- `actor_type text not null` -- user, app, relay, hermes
- `event_payload jsonb`
- `created_at timestamptz not null`

Indexes:
- index on `event_type`, `created_at`
- index on `user_id`
- index on `device_id`

---

## Suggested enum values

### devices.environment
- development
- staging
- production

### inbox_items.priority
- low
- normal
- high

### inbox_items.status
- pending
- opened
- completed
- dismissed
- expired

### capability_requests.status
- pending
- approved
- denied
- fulfilled
- expired
- cancelled

### messages.role
- user
- hermes
- system

---

## Suggested first migrations order
1. users
2. devices
3. auth_sessions
4. push_registrations
5. conversations
6. messages
7. inbox_items
8. inbox_actions
9. capability_requests
10. capability_results
11. media_uploads
12. voice_sessions
13. audit_log

---

## Minimal subset for first real demo
If you want the smallest viable backend first, begin with:
- users
- devices
- push_registrations
- conversations
- messages
- inbox_items
- inbox_actions

Then add capability and voice tables later.

---

## Implementation note
If the backend team later chooses an ORM or migration framework, preserve the logical shape above and do not let tool-specific defaults distort the product model without reason.

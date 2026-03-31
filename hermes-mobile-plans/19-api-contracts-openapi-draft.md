# Hermes Mobile API Contracts / OpenAPI Draft

## Purpose
Provide a concrete first-pass API contract so backend implementation is deterministic and the iOS app can wire to stable request/response shapes.

This is a planning draft, not a final OpenAPI document. It should be used to guide the first relay implementation.

---

## API design principles
- provider-neutral backend
- app-safe responses only
- explicit device/user context
- durable inbox/action semantics
- no root provider secrets exposed to the client
- capability requests/results are structured and auditable

## Versioning
Suggested base path:
- `/v1`

Example base URL:
- `https://relay.example.com/v1`

Authentication suggestion:
- Bearer token for app session
- device registration bootstrap may begin unauthenticated or use a signed bootstrap token depending on final auth design

---

## Common envelope shapes

### Error response
```json
{
  "error": {
    "code": "string",
    "message": "Human-readable message",
    "retryable": false
  }
}
```

### Success metadata pattern
```json
{
  "data": {},
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:00:00Z"
  }
}
```

---

## 1. Health and version

### GET `/v1/health`
Purpose:
- health check for local/dev/prod deployment

Response:
```json
{
  "data": {
    "status": "ok"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:00:00Z"
  }
}
```

### GET `/v1/version`
Response:
```json
{
  "data": {
    "service": "hermes-mobile-relay",
    "version": "0.1.0",
    "environment": "development"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:00:00Z"
  }
}
```

---

## 2. Device registration

### POST `/v1/device/register`
Purpose:
- register or upsert a device record

Request:
```json
{
  "device": {
    "platform": "ios",
    "deviceName": "Dylan's iPhone",
    "appVersion": "0.1.0",
    "buildNumber": "1",
    "bundleId": "com.example.HermesMobile",
    "installationId": "uuid",
    "deviceModel": "iPhone17,2",
    "systemVersion": "26.0"
  },
  "client": {
    "environment": "development"
  }
}
```

Response:
```json
{
  "data": {
    "deviceId": "uuid",
    "deviceRegistered": true,
    "session": {
      "connectionStatus": "connectedSoon",
      "isMockMode": false,
      "backendEndpoint": "https://relay.example.com/v1",
      "lastSyncAt": null
    },
    "auth": {
      "accessToken": "opaque-or-jwt",
      "refreshToken": "opaque-token",
      "expiresAt": "2026-03-31T01:00:00Z"
    }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:00:00Z"
  }
}
```

---

## 3. Session bootstrap

### GET `/v1/session`
Purpose:
- fetch session metadata the app needs for startup/settings

Response:
```json
{
  "data": {
    "user": {
      "id": "uuid",
      "displayName": "Dylan"
    },
    "device": {
      "id": "uuid",
      "registered": true
    },
    "session": {
      "connectionStatus": "connected",
      "isMockMode": false,
      "backendEndpoint": "https://relay.example.com/v1",
      "lastSyncAt": "2026-03-31T00:10:00Z"
    },
    "push": {
      "tokenRegistered": true
    }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:10:01Z"
  }
}
```

### POST `/v1/auth/refresh`
Request:
```json
{
  "refreshToken": "opaque-token"
}
```

Response:
```json
{
  "data": {
    "accessToken": "new-access-token",
    "refreshToken": "new-refresh-token",
    "expiresAt": "2026-03-31T02:00:00Z"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T01:00:00Z"
  }
}
```

---

## 4. Push registration

### POST `/v1/push/register`
Request:
```json
{
  "deviceId": "uuid",
  "apnsToken": "hex-string",
  "pushEnvironment": "sandbox",
  "bundleId": "com.example.HermesMobile"
}
```

Response:
```json
{
  "data": {
    "registered": true,
    "updatedAt": "2026-03-31T00:20:00Z"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:20:00Z"
  }
}
```

---

## 5. Conversation and messages

### GET `/v1/conversations/current`
Response:
```json
{
  "data": {
    "conversation": {
      "id": "uuid",
      "title": "Hermes",
      "updatedAt": "2026-03-31T00:30:00Z",
      "messages": [
        {
          "id": "uuid",
          "role": "hermes",
          "text": "Hi, how can I help?",
          "timestamp": "2026-03-31T00:29:00Z"
        }
      ]
    }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:30:00Z"
  }
}
```

### POST `/v1/messages`
Request:
```json
{
  "conversationId": "uuid",
  "text": "What do I need to do today?",
  "clientMessageId": "uuid"
}
```

Response:
```json
{
  "data": {
    "accepted": true,
    "message": {
      "id": "uuid",
      "role": "user",
      "text": "What do I need to do today?",
      "timestamp": "2026-03-31T00:31:00Z"
    },
    "delivery": {
      "status": "accepted"
    }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:31:00Z"
  }
}
```

Optional future endpoints:
- `GET /v1/messages?since=<cursor>`
- SSE or WebSocket endpoint for live updates

---

## 6. Inbox

### GET `/v1/inbox`
Query params:
- `status` optional
- `cursor` optional
- `limit` optional

Response:
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "kind": "location_request",
        "title": "Hermes wants a location snapshot",
        "body": "Share your current location for a place-aware reminder.",
        "priority": "normal",
        "status": "pending",
        "createdAt": "2026-03-31T00:40:00Z",
        "actions": [
          { "id": "approve", "title": "Approve" },
          { "id": "dismiss", "title": "Dismiss" }
        ]
      }
    ],
    "nextCursor": null
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:40:01Z"
  }
}
```

### POST `/v1/inbox/{id}/action`
Request:
```json
{
  "actionId": "approve",
  "payload": {
    "note": "optional"
  }
}
```

Response:
```json
{
  "data": {
    "itemId": "uuid",
    "status": "completed",
    "result": "accepted"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:41:00Z"
  }
}
```

---

## 7. Realtime session issuance

### POST `/v1/realtime/session`
Purpose:
- return client-safe ephemeral session/credential material for foreground Talk Mode

Request:
```json
{
  "deviceId": "uuid",
  "capabilities": {
    "audioInput": true,
    "audioOutput": true,
    "textFallback": true
  }
}
```

Response:
```json
{
  "data": {
    "provider": "openai",
    "transport": "webrtc",
    "session": {
      "clientSecret": "ephemeral-client-secret",
      "expiresAt": "2026-03-31T00:50:00Z",
      "model": "gpt-realtime"
    }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:45:00Z"
  }
}
```

Important:
- never return root provider keys
- keep TTL short

---

## 8. Capability request/result flows

### POST `/v1/capabilities/location/request`
Purpose:
- create a request/inbox item for a location snapshot

Request:
```json
{
  "reason": "Place-aware reminder",
  "expiresAt": "2026-03-31T01:00:00Z"
}
```

### POST `/v1/capabilities/location/result`
Request:
```json
{
  "requestId": "uuid",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "horizontalAccuracy": 25,
    "capturedAt": "2026-03-31T00:46:00Z"
  },
  "summary": "User is near downtown San Francisco"
}
```

### POST `/v1/capabilities/health/result`
Request:
```json
{
  "requestId": "uuid",
  "summary": {
    "stepsToday": 7214,
    "sleepHours": 7.4,
    "restingHeartRate": 58
  },
  "capturedAt": "2026-03-31T00:46:00Z"
}
```

### POST `/v1/uploads/media`
Suggested response:
```json
{
  "data": {
    "uploadId": "uuid",
    "url": "https://storage.example.com/object",
    "status": "uploaded"
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-03-31T00:47:00Z"
  }
}
```

---

## 9. Hermes-facing internal operations
These may be internal APIs, service methods, or webhook handlers rather than public mobile endpoints.

Suggested operations:
- `POST /internal/inbox`
- `POST /internal/mobile-message`
- `POST /internal/capability-request`
- `POST /internal/voice-session-summary`

These should be separately authenticated from mobile app endpoints.

---

## Status enums

### ConnectionStatus
- `offline`
- `mockLocal`
- `connectingSoon`
- `connected`

### InboxStatus
- `pending`
- `opened`
- `completed`
- `dismissed`
- `expired`

### Priority
- `low`
- `normal`
- `high`

### PermissionStatus
- `notDetermined`
- `authorized`
- `limited`
- `denied`
- `restricted`
- `unsupported`

---

## Implementation note
If you later formalize this into a real OpenAPI spec, start with the endpoints above and only add complexity after the first app-to-relay integration succeeds.

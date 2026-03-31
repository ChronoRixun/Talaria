# Provider and Platform Research

Research focus:
- hosting a lightweight but durable relay/backend for Hermes Mobile
- supporting APNs, HTTP APIs, inbox/event flows, and possibly WebSockets
- fitting a Hermes-style persistent agent architecture
- working well with a SwiftUI iOS client and OpenAI Realtime Talk Mode

Last updated:
- March 2026 planning context

---

## What the relay actually needs to do
The relay does not need to be a giant backend on day one. It needs to do a few things well:
- device registration
- auth/session bootstrap
- APNs token registration
- inbox/event APIs
- optional WebSocket or SSE for foreground sync
- ephemeral credential/session issuance for OpenAI Realtime
- media upload handling
- policy and audit boundaries for device capability requests
- integration surface for Hermes runtime

This is a strong fit for a small always-on containerized backend.

---

## Recommendation summary

### Best overall default: Render
Choose Render if you want:
- the simplest path to a durable always-on API
- easy WebSocket support on persistent services
- straightforward deploys for API + worker + Postgres
- lower operational complexity

Why it fits:
- Render explicitly supports inbound WebSockets on web services
- Render does not impose a fixed WebSocket duration timeout, though reconnect handling is still required because instances can restart
- the platform is well-suited to “serverful” long-lived services, background workers, and AI/chat backends

Good fit for:
- first production relay
- solo or small-team shipping quickly
- durable API + worker architecture beside Hermes runtime

Tradeoffs:
- less edge-native than Fly.io
- not as globally distributed by default

### Best if you want stronger multi-region / network control: Fly.io
Choose Fly.io if you want:
- globally distributed containers
- more direct control over service topology
- private networking between services
- good support for public and private app services
- easy fit for a small relay plus adjacent internal services

Why it fits:
- Fly supports WebSockets and long-lived TCP services well
- Fly private networking and `.internal` DNS are useful if you split relay, worker, and internal Hermes-facing services
- a containerized relay on Fly is a good fit if you care about low latency across regions

Good fit for:
- multi-region relay
- WebSocket-heavy or low-latency geodistributed backends
- teams comfortable with a more infra-aware workflow

Tradeoffs:
- more operational involvement than Render
- slightly steeper learning curve

### Best for edge event handling or selective realtime primitives: Cloudflare Workers + Durable Objects
Choose Cloudflare if you want:
- edge auth and lightweight request handling
- globally distributed low-latency event entrypoints
- Durable Objects for WebSocket server patterns and coordination

Why it fits:
- Durable Objects are strong for server-side WebSocket fan-in/fan-out and per-user/session coordination
- Hibernation can reduce cost for idle WebSocket server workloads

But note the constraint:
- Durable Object hibernation helps when the Durable Object acts as a WebSocket server
- outgoing WebSockets do not hibernate the same way
- an edge-only architecture can become awkward if you also need a richer serverful runtime adjacent to Hermes tools, background workers, APNs logic, or more complex persistence

Good fit for:
- selective edge pieces
- notification fanout gateways
- per-user websocket coordination layers

Tradeoffs:
- more architectural specialization
- can be less natural as the sole home for a Hermes-adjacent backend

---

## Practical recommendation for Hermes Mobile

### Recommended default deployment stack
Option A, easiest good path:
- Render web service for relay API
- Render worker for async jobs if needed
- managed Postgres
- object storage provider of choice for uploads

Option B, strongest flexible path:
- Fly.io relay API service
- Fly.io internal worker or Hermes-adjacent services
- Postgres (managed or external)
- Redis if event fanout or rate limiting becomes necessary

### What I would choose here
If the priority is shipping quickly with continuation-friendly architecture:
- start on Render

If the priority is future low-latency global scaling and more control:
- start on Fly.io

Because you explicitly mentioned Fly.io for a relay, yes: Fly.io is a very good fit here.
It is especially attractive if:
- Hermes runtime may later run as a nearby internal service
- you want region-aware routing
- you want direct container control without jumping all the way to a larger cloud stack

---

## OpenAI Realtime integration hosting implication
For Talk Mode, the best default is:
- app requests ephemeral credentials/session info from relay
- app connects directly to OpenAI Realtime in the foreground
- relay never exposes root provider secrets to the app

This reduces the need for your relay to be the audio transport path.
That, in turn, means the relay mostly needs durable HTTP APIs plus optional WebSocket/SSE for app sync.

This architecture makes both Render and Fly.io even more suitable because:
- they do not have to proxy all voice media
- they can stay comparatively small and focused

---

## Notes from research sources
- Apple background push guidance says background notifications are low priority and not guaranteed; they should not be spammed
- Render docs explicitly support WebSockets and note that reconnect handling is still required because instances can be replaced
- Fly docs support public app services, private networking, WebSockets, and TCP services cleanly
- Cloudflare Durable Objects are strong for WebSocket server patterns, but hibernation is specifically about incoming server-side WebSockets

---

## Distribution model recommendations

### A. If this will be your mass-distributed hosted product
Best default:
- Fly.io or Render for the managed relay

How to choose:
- choose Fly.io if you expect global users, WebSockets, regional placement, or eventually multiple internal services around the relay
- choose Render if you want the simplest durable hosted control plane and you care more about low operational friction than multi-region control

My recommendation for a mass-distributed Hermes Mobile product:
- Fly.io is the stronger long-term default
- Render is the easier first-production default

Practical interpretation:
- if you want to optimize for day-1 speed, pick Render
- if you want to optimize for global latency, infra flexibility, and future service topology, pick Fly.io

### B. If this will be open sourced and users may self-host
Best default:
- do not make Fly.io the only blessed path
- define a provider-agnostic relay architecture with Docker-first deployment

Recommended self-host posture:
- ship a Docker Compose reference stack
- keep the relay as a plain containerized HTTP API + worker
- use Postgres as the default durable store
- make Redis optional, not mandatory
- document Fly.io, Render, and generic VPS deployment separately

Why:
- open-source adoption improves when users can run the relay on a cheap VPS, home server, Railway, Fly.io, Render, or Kubernetes without architectural changes
- a Docker-first relay is more future-proof than a Fly-specific design

Best open-source default stack:
- relay API container
- optional worker container
- Postgres
- optional reverse proxy
- APNs credentials mounted/configured via env or secret file

### C. Best hybrid strategy
If you want both hosted scale and open-source portability:
- build the relay to be provider-neutral
- deploy your managed version on Fly.io
- publish Docker Compose for self-hosters

This is the most robust approach.
It gives you:
- a strong production default for your own hosted service
- a clear self-host path for open-source users
- no deep lock-in to Fly-specific primitives

## Final recommendation
If you want one clear recommendation:
- for your own hosted, mass-distributed product: use Fly.io as the primary production relay target
- for open-source/self-host: ship a Docker-first provider-neutral relay and document Fly.io as one recommended deployment option, not the only option

For your exact situation, I would lean:
1. Architect provider-neutral
2. Deploy your managed relay on Fly.io first
3. Offer Docker Compose self-host docs for everyone else

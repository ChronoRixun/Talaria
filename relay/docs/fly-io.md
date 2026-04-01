# Fly.io deployment

This relay can be deployed to Fly.io from the `relay` directory.

## What this Fly deployment does today

- Deploys the FastAPI relay as a public HTTPS service.
- Uses Fly Managed Postgres for persistence through `DATABASE_URL`.
- Defaults to `HERMES_ADAPTER=mock` on Fly.

## Important limitation

Real Hermes-backed chat is currently local to the Mac mini, because the Hermes CLI and its authenticated runtime live on this machine at `/Users/dylan-mac-mini/.local/bin/hermes` and `/Users/dylan-mac-mini/.hermes`.

A Fly deployment of the relay will **not** be able to use that local Hermes install directly. If you deploy the relay exactly as configured here, device registration, session bootstrap, inbox APIs, and mock chat will work, but real Hermes CLI chat will not run in Fly yet.

To get real Hermes chat on Fly later, we would need one of these follow-up architectures:

1. Install and authenticate Hermes inside the Fly runtime image.
2. Expose Hermes behind a separate service/API that the relay can call.
3. Keep the relay local on the Mac mini whenever live Hermes CLI access is required.

## Recommended first deploy

1. Install `flyctl`.
2. Log in with `flyctl auth login`.
3. From this `relay` directory, create or confirm the Fly app name.
4. Create a Managed Postgres cluster.
5. Attach the app to Postgres so Fly sets `DATABASE_URL`.
6. Set `INTERNAL_API_KEY` as a Fly secret.
7. Deploy with `fly deploy`.

## Example commands

```bash
cd /Users/dylan-mac-mini/Documents/HermesMobile/relay

# Authenticate first.
flyctl auth login

# If you keep the default app name from fly.toml:
flyctl apps create hermes-mobile-relay-dylan

# Create Managed Postgres in the same primary region.
flyctl mpg create --name hermes-mobile-relay-db --region iad --plan basic

# List clusters to get the cluster ID, then attach it to the app.
flyctl mpg list
flyctl mpg attach <cluster-id> -a hermes-mobile-relay-dylan

# Set the relay's internal key as a secret.
flyctl secrets set INTERNAL_API_KEY=replace-this-with-a-real-secret -a hermes-mobile-relay-dylan

# Deploy the relay from this directory.
flyctl deploy
```

## After deploy

- `PUBLIC_BASE_URL` in `fly.toml` should match the final Fly app URL.
- The iOS app's production or staging environment should point at the deployed relay URL.
- If you want always-warm Machines instead of cold starts, change `min_machines_running` from `0` to `1`.

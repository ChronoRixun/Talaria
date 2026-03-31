# Local Development

The relay defaults to a provider-neutral configuration model:

- `DATABASE_URL` chooses the backing database.
- `PUBLIC_BASE_URL` is returned to the mobile app for session metadata.
- `INTERNAL_API_KEY` protects Hermes-facing endpoints.

For the first live milestone:

- use Postgres in Docker for local development,
- point the iOS app's development environment at `http://127.0.0.1:8000/v1`,
- keep Hermes integration out-of-process and talk to the relay through the internal endpoints.

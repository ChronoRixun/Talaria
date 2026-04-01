# Hermes Mobile Connector

`hermes-mobile-connector` is the host-side process that runs next to a local Hermes install and bridges it to a public Hermes Mobile relay.

## Install

```bash
cd /Users/dylan-mac-mini/Documents/HermesMobile/connector
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

## Configure Hermes execution

The connector only uses Hermes through the documented CLI surface. Configure it with environment variables:

```bash
export HERMES_COMMAND=/absolute/path/to/hermes
export HERMES_WORKDIR=/path/to/your/hermes/project
export HERMES_PROVIDER=
export HERMES_MODEL=
export HERMES_TOOLSETS=
export HERMES_SOURCE=tool
export HERMES_HISTORY_LIMIT=20
```

Optional connector-local state directory:

```bash
export HERMES_MOBILE_CONNECTOR_HOME=~/.hermes-mobile-connector
```

## Enroll

Generate a host setup code from the Hermes Mobile iPhone app, then redeem it on the Hermes host:

```bash
hermes-mobile-connector enroll --code 'HC1:...'
```

You can inspect the stored enrollment:

```bash
hermes-mobile-connector status
```

## Run

```bash
hermes-mobile-connector run
```

The connector opens one outbound authenticated WebSocket to the relay, heartbeats while idle or during long jobs, executes one Hermes CLI job at a time, and reports results back to the relay.

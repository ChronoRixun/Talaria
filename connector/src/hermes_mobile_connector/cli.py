from __future__ import annotations

import argparse
import asyncio
import sys

import qrcode

from .client import HermesMobileConnector


def prompt(label: str, *, default: str | None = None, optional: bool = False) -> str | None:
    """Prompt the user interactively. Returns None only when optional and blank."""
    suffix = f" [{default}]" if default else ""
    suffix += " (optional)" if optional and not default else ""
    response = input(f"{label}{suffix}: ").strip()
    if response:
        return response
    if default:
        return default
    if optional:
        return None
    raise SystemExit(f"{label} is required.")


def confirm(question: str, *, default: bool = True) -> bool:
    hint = "Y/n" if default else "y/N"
    response = input(f"{question} [{hint}] ").strip().lower()
    if not response:
        return default
    return response in ("y", "yes")


def print_qr_code(value: str) -> None:
    qr = qrcode.QRCode(border=1)
    qr.add_data(value)
    qr.make(fit=True)
    qr.print_ascii(tty=sys.stdout.isatty())


def print_header(text: str) -> None:
    print(f"\n{'─' * 40}")
    print(f"  {text}")
    print(f"{'─' * 40}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hermes-mobile",
        description="Connect your Hermes CLI to Hermes Mobile.",
    )
    subparsers = parser.add_subparsers(dest="command")

    setup = subparsers.add_parser("setup", help="Create a Hermes Mobile account and enroll this host.")
    setup.add_argument("--owner-display-name", help="Display name for the relay account owner.")
    setup.add_argument("--host-display-name", help="Optional label for this Hermes host.")
    setup.add_argument("--relay-url", help="Relay API base URL (default: hosted relay).")

    enroll = subparsers.add_parser("enroll", help="(Legacy) Redeem an HC1 host setup code.")
    enroll.add_argument("--code", required=True, help="HC1 setup code.")
    enroll.add_argument("--display-name", help="Optional label for this Hermes host.")

    subparsers.add_parser("pair-phone", help="Generate a short-lived phone pairing code and QR.")
    subparsers.add_parser("run", help="Run the long-lived Hermes Mobile connector.")
    subparsers.add_parser("status", help="Show the current connector state.")
    subparsers.add_parser("reset", help="Remove local connector state and start fresh.")
    return parser


# ── Interactive wizard (no subcommand) ───────────────────────────

def run_wizard(connector: HermesMobileConnector) -> int:
    print_header("Hermes Mobile Connector Setup")

    # Check for existing state
    try:
        existing = connector.state_store.load()
        print(f"This machine is already set up as \"{existing.connector_display_name or existing.host_id}\".")
        print(f"Owner: {existing.owner_display_name or 'unknown'}")
        print()
        if not confirm("Start over with a fresh setup?", default=False):
            return _wizard_post_setup(connector)
        connector.state_store.clear()
        print("Previous state cleared.\n")
    except RuntimeError:
        pass

    # Step 1: Validate Hermes CLI
    print_header("Step 1 of 3 — Verify Hermes CLI")
    metadata = connector.metadata()
    if metadata.hermes_version is None:
        print(f"Could not find Hermes at: {metadata.hermes_command}")
        print("Install Hermes or set HERMES_COMMAND to its path.")
        return 1
    print(f"Found: {metadata.hermes_version}")
    print(f"Command: {metadata.hermes_command}")
    print()

    # Step 2: Create account
    print_header("Step 2 of 3 — Create Your Account")
    import socket
    default_host = socket.gethostname()
    owner_name = prompt("Your name")
    host_label = prompt("Label for this machine", default=default_host, optional=True)

    print()
    print("Registering with relay...")
    try:
        state = connector.setup(
            owner_display_name=owner_name,
            host_display_name=host_label,
        )
    except Exception as e:
        print(f"Setup failed: {e}")
        return 1
    print(f"Account created. Host ID: {state.host_id}")

    return _wizard_post_setup(connector)


def _wizard_post_setup(connector: HermesMobileConnector) -> int:
    # Step 3: Phone pairing
    print_header("Step 3 of 3 — Pair Your Phone")
    print("Generate a one-time code for the Hermes Mobile app.\n")

    if not confirm("Generate a phone pairing code now?"):
        print("\nYou can generate one later with: hermes-mobile pair-phone")
        print("Then start the connector with: hermes-mobile run")
        return 0

    try:
        pairing = connector.create_phone_pairing_code()
    except Exception as e:
        print(f"Failed to create pairing code: {e}")
        return 1

    print(f"\nYour pairing code:  {pairing.display_code}\n")
    if pairing.expires_at:
        print(f"Expires at: {pairing.expires_at}")
    print()
    print_qr_code(pairing.display_code)
    print("Open Hermes Mobile on your phone and enter this code (or scan the QR).")
    print()

    input("Press Enter once your phone is paired...")

    print()
    if confirm("Start the connector now?"):
        print_header("Connector Running")
        print("Listening for messages from your phone. Press Ctrl+C to stop.\n")
        try:
            asyncio.run(connector.run_forever())
        except KeyboardInterrupt:
            print("\nConnector stopped.")
        return 0

    print("\nStart the connector later with: hermes-mobile run")
    return 0


# ── Individual subcommands ───────────────────────────────────────

def cmd_setup(args: argparse.Namespace, connector: HermesMobileConnector) -> int:
    try:
        existing = connector.state_store.load()
        print(f"Already set up for {existing.relay_url}.")
        print("Run `hermes-mobile reset` to start over.")
        return 1
    except RuntimeError:
        pass

    owner_name = args.owner_display_name or prompt("Your name")
    host_label = args.host_display_name
    if host_label is None:
        import socket
        host_label = prompt("Label for this machine", default=socket.gethostname(), optional=True)

    state = connector.setup(
        owner_display_name=owner_name,
        host_display_name=host_label,
        relay_url=args.relay_url,
    )
    print(f"Account created. Host: {state.host_id}")
    print("\nNext: hermes-mobile pair-phone")
    return 0


def cmd_enroll(args: argparse.Namespace, connector: HermesMobileConnector) -> int:
    state = connector.enroll(code=args.code, display_name=args.display_name)
    print(f"Enrolled host {state.host_id} against {state.relay_url}")
    return 0


def cmd_pair_phone(connector: HermesMobileConnector) -> int:
    pairing = connector.create_phone_pairing_code()
    print(f"\nPairing code:  {pairing.display_code}\n")
    if pairing.expires_at:
        print(f"Expires at: {pairing.expires_at}")
    print()
    print_qr_code(pairing.display_code)
    print("Open Hermes Mobile on your phone and enter this code or scan the QR.")
    return 0


def cmd_run(connector: HermesMobileConnector) -> int:
    print("Connector running. Press Ctrl+C to stop.\n")
    asyncio.run(connector.run_forever())
    return 0


def cmd_status(connector: HermesMobileConnector) -> int:
    for line in connector.status_lines():
        print(line)
    return 0


def cmd_reset(connector: HermesMobileConnector) -> int:
    try:
        connector.state_store.load()
    except RuntimeError:
        print("No connector state found. Nothing to reset.")
        return 0

    if not confirm("Remove all local connector state? This cannot be undone."):
        print("Cancelled.")
        return 0

    connector.state_store.clear()
    print("Connector state removed. Run `hermes-mobile` to set up again.")
    return 0


# ── Entry point ──────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    connector = HermesMobileConnector()

    if args.command is None:
        return run_wizard(connector)

    if args.command == "setup":
        return cmd_setup(args, connector)
    if args.command == "enroll":
        return cmd_enroll(args, connector)
    if args.command == "pair-phone":
        return cmd_pair_phone(connector)
    if args.command == "run":
        return cmd_run(connector)
    if args.command == "status":
        return cmd_status(connector)
    if args.command == "reset":
        return cmd_reset(connector)

    raise SystemExit(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())

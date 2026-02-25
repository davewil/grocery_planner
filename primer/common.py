"""
primer/common.py — Shared helpers used by all platform-specific primers.
"""

import subprocess
import sys
import shutil
import os
import textwrap

AMBER = "\033[33m"
RESET = "\033[0m"


def amber(text: str) -> str:
    return f"{AMBER}{text}{RESET}"


# ---------------------------------------------------------------------------
# User interaction
# ---------------------------------------------------------------------------

def ask(question: str, choices: list[str]) -> str:
    """Present a numbered menu and return the user's chosen value."""
    print()
    print(question)
    for i, choice in enumerate(choices, 1):
        print(f"  {i}) {choice}")
    while True:
        raw = input("Enter number: ").strip()
        if raw.isdigit() and 1 <= int(raw) <= len(choices):
            chosen = choices[int(raw) - 1]
            print(f"  → {chosen}")
            return chosen
        print(f"  Please enter a number between 1 and {len(choices)}.")


def ask_yes_no(question: str, default: str = "yes") -> bool:
    """Ask a yes/no question. default must be 'yes' or 'no'."""
    hint = "[Y/n]" if default == "yes" else "[y/N]"
    print()
    raw = input(f"{question} {hint}: ").strip().lower()
    if raw == "":
        return default == "yes"
    return raw in ("y", "yes")


# ---------------------------------------------------------------------------
# Command helpers
# ---------------------------------------------------------------------------

def is_available(cmd: str) -> bool:
    """Return True if *cmd* can be found on PATH."""
    return shutil.which(cmd) is not None


def run(args: list[str], check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    """Run a command, streaming output, and optionally raise on failure."""
    print(f"\n  $ {' '.join(args)}")
    # On Windows, .bat files (e.g. mix.bat, elixir.bat) require shell=True
    if sys.platform == "win32":
        kwargs.setdefault("shell", True)
    result = subprocess.run(args, **kwargs)
    if check and result.returncode != 0:
        print(f"\n  ERROR: command exited with code {result.returncode}")
        sys.exit(result.returncode)
    return result


# ---------------------------------------------------------------------------
# Postgres (via Docker Compose)
# ---------------------------------------------------------------------------

def ensure_postgres() -> None:
    """Start the postgres container and wait for it to be healthy."""
    print("\n" + "=" * 60)
    print("STEP 5b: Start PostgreSQL (Docker Compose)")
    print("=" * 60)

    if not is_available("docker"):
        print("  docker not found — skipping. Start postgres manually before running mix setup.")
        return

    print("  Starting postgres container...")
    result = subprocess.run(
        ["docker", "compose", "up", "-d", "--wait", "postgres"],
        **({} if sys.platform != "win32" else {"shell": True}),
    )
    if result.returncode != 0:
        print("  WARNING: docker compose up exited with a non-zero code.")
        print("  Make sure Docker Desktop is running and try again.")
    else:
        print("  ✓ PostgreSQL container is up and healthy.")


# ---------------------------------------------------------------------------
# Mix setup (shared across platforms — caller must ensure mix is on PATH first)
# ---------------------------------------------------------------------------

def run_mix_setup() -> None:
    print("\n" + "=" * 60)
    print("STEP 6: Elixir project setup (mix setup)")
    print("=" * 60)

    if not is_available("mix"):
        print("  mix not found on PATH — skipping. Run 'mix setup' manually once Elixir is installed.")
        return

    if not ask_yes_no("Run 'mix setup' now? (downloads deps, creates DB, builds assets)"):
        print("  Skipping mix setup.")
        return

    run(["mix", "setup"])
    print("  ✓ mix setup complete.")


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

def print_summary() -> None:
    print()
    print("=" * 60)
    print("SETUP COMPLETE")
    print("=" * 60)
    print(textwrap.dedent("""
      Next steps:
        1. Start the Phoenix server:
             mix phx.server
           or with interactive shell:
             iex -S mix phx.server

        2. Open http://localhost:4000

        3. (Optional) Start the Python AI service:
             docker compose up -d python-service

      Run this script again at any time — already-installed items are skipped.
    """))

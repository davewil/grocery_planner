"""
primer/macos_primer.py — Setup steps for macOS using Homebrew.
"""

import sys
import os
import shutil
import textwrap

from common import (
    amber, ask, ask_yes_no, is_available, run,
    run_mix_setup, ensure_postgres, print_summary,
)


# ---------------------------------------------------------------------------
# Step 0 – Homebrew
# ---------------------------------------------------------------------------

def ensure_package_manager() -> None:
    print("\n" + "=" * 60)
    print("STEP 0: Homebrew")
    print("=" * 60)

    if is_available("brew"):
        print("  ✓ Homebrew already installed.")
        return

    print("  Homebrew is not installed.")
    if not ask_yes_no("Install Homebrew now?"):
        print("  Homebrew is required. Exiting.")
        sys.exit(1)

    run(["/bin/bash", "-c",
         "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"])
    print("  ✓ Homebrew installed.")


# ---------------------------------------------------------------------------
# Step 1 – Git
# ---------------------------------------------------------------------------

def ensure_git() -> None:
    print("\n" + "=" * 60)
    print("STEP 1: Git")
    print("=" * 60)

    if is_available("git"):
        print("  ✓ Git already installed.")
        return

    print("  Git is not installed.")
    if not ask_yes_no("Install Git via Homebrew?"):
        print("  Skipping Git install.")
        return

    run(["brew", "install", "git"])
    print("  ✓ Git installed.")


# ---------------------------------------------------------------------------
# Step 2 – Erlang / Elixir
# ---------------------------------------------------------------------------

def ensure_elixir() -> None:
    print("\n" + "=" * 60)
    print("STEP 2: Elixir (and Erlang/OTP)")
    print("=" * 60)

    if is_available("elixir"):
        print("  ✓ Elixir already installed.")
        return

    print("  Elixir is not installed.")
    if not ask_yes_no("Install Elixir via Homebrew (includes Erlang/OTP)?"):
        print("  Skipping Elixir install.")
        return

    run(["brew", "install", "elixir"])
    print("  ✓ Elixir installed.")


# ---------------------------------------------------------------------------
# Precondition – Docker Desktop
# ---------------------------------------------------------------------------

def ensure_docker() -> None:
    print(amber(textwrap.dedent("""
      PRECONDITION: Docker Desktop

      Docker Desktop is required to run PostgreSQL and other services via docker-compose.

      Please make sure you have:
        1. Installed Docker Desktop (https://www.docker.com/products/docker-desktop/)
        2. Launched Docker Desktop so the daemon has started
        3. Docker Desktop is currently running in the menu bar
    """)))

    if not ask_yes_no(amber("Is Docker Desktop installed and currently running?")):
        print("  Please install Docker Desktop, start it, then re-run this script.")
        sys.exit(1)

    print("  ✓ Docker Desktop confirmed running.")


# ---------------------------------------------------------------------------
# Step 5 – Python service
# ---------------------------------------------------------------------------

def ensure_python() -> None:
    print("\n" + "=" * 60)
    print("STEP 5: Python service")
    print("=" * 60)

    print(textwrap.dedent("""
      The app includes a Python micro-service (python_service/) that provides:
        - AI-based grocery categorisation (PyTorch / Transformers -- ~2 GB)
        - Receipt OCR (Tesseract + OpenCV)
        - Constraint-based meal optimisation (Z3 solver)
    """))

    print("  Installing python_service locally on this machine.")

    # --- uv ---
    print()
    uv_choice = ask(
        "Install 'uv' (fast Python package manager — used by 'mix precommit')?",
        [
            "Yes, install uv via pip [recommended]",
            "Yes, install uv via Homebrew",
            "No, skip",
        ],
    )
    if "pip" in uv_choice:
        run(["pip", "install", "uv"])
    elif "Homebrew" in uv_choice:
        run(["brew", "install", "uv"])

    # --- Tesseract OCR ---
    print()
    tesseract_choice = ask(
        "Install Tesseract OCR? (required for receipt scanning features)",
        ["Yes [recommended if using OCR]", "No, skip (OCR features will be disabled)"],
    )
    if "Yes" in tesseract_choice:
        if is_available("tesseract"):
            print("  ✓ Tesseract already installed.")
        else:
            run(["brew", "install", "tesseract"])
            print("  ✓ Tesseract installed.")

    # --- Python venv + pip deps ---
    print()
    if ask_yes_no("Create python_service/.venv and install Python dependencies now?"):
        python_exe = shutil.which("python3") or shutil.which("python") or "python3"
        venv_dir = os.path.join("python_service", ".venv")
        run([python_exe, "-m", "venv", venv_dir])
        pip_exe = os.path.join(venv_dir, "bin", "pip")
        run([pip_exe, "install", "-r", os.path.join("python_service", "requirements.txt")])
        print("  ✓ Python venv created and dependencies installed.")

    print("  ✓ Python setup complete.")


# ---------------------------------------------------------------------------
# Mix PATH helper
# ---------------------------------------------------------------------------

def ensure_mix_on_path() -> None:
    if is_available("mix"):
        return
    for candidate in ["/opt/homebrew/bin", "/usr/local/bin"]:
        if os.path.isfile(os.path.join(candidate, "mix")):
            print(f"  Adding {candidate} to PATH")
            os.environ["PATH"] = candidate + ":" + os.environ.get("PATH", "")
            return


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    print()
    print("=" * 52)
    print("  GroceryPlanner -- Local Environment Setup")
    print("=" * 52)
    print()
    print("  Platform: macOS (Homebrew)")
    print()
    print("This script installs missing dependencies via Homebrew.")
    print("It will ask before making any choice that has alternatives.")

    ensure_docker()

    if not ask_yes_no("Continue?"):
        print("Exiting.")
        sys.exit(0)

    ensure_package_manager()
    ensure_git()
    ensure_elixir()
    ensure_python()
    ensure_mix_on_path()
    ensure_postgres()
    run_mix_setup()
    print_summary()

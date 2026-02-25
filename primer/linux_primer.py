"""
primer/linux_primer.py — Setup steps for Arch Linux using pacman.
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
# Elevation helper
# ---------------------------------------------------------------------------

def ensure_sudo() -> None:
    """Warn if not running with sudo-capable access."""
    if os.geteuid() == 0:
        return
    if not is_available("sudo"):
        print("  WARNING: sudo not found. Some install steps may fail.")


# ---------------------------------------------------------------------------
# Step 0 – pacman
# ---------------------------------------------------------------------------

def ensure_package_manager() -> None:
    print("\n" + "=" * 60)
    print("STEP 0: pacman (built-in to Arch Linux)")
    print("=" * 60)
    print("  ✓ pacman is available.")


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
    if not ask_yes_no("Install Git via pacman?"):
        print("  Skipping Git install.")
        return

    run(["sudo", "pacman", "-S", "--noconfirm", "git"])
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
    if not ask_yes_no("Install Elixir via pacman (includes Erlang/OTP)?"):
        print("  Skipping Elixir install.")
        return

    run(["sudo", "pacman", "-S", "--noconfirm", "elixir"])
    print("  ✓ Elixir installed.")


# ---------------------------------------------------------------------------
# Precondition – Docker
# ---------------------------------------------------------------------------

def ensure_docker() -> None:
    print("\n" + "=" * 60)
    print("PRECONDITION: Docker")
    print("=" * 60)

    if is_available("docker"):
        print("  ✓ Docker already installed.")
        return

    if not ask_yes_no("Install Docker via pacman?"):
        print("  Docker is required. Exiting.")
        sys.exit(1)

    run(["sudo", "pacman", "-S", "--noconfirm", "docker"])
    run(["sudo", "systemctl", "enable", "--now", "docker"])
    user = os.environ.get("SUDO_USER") or os.environ.get("USER", "")
    if user:
        run(["sudo", "usermod", "-aG", "docker", user])
    print("  NOTE: log out and back in for docker group membership to take effect.")
    print("  ✓ Docker installed.")


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
            "Yes, install uv via pacman",
            "No, skip",
        ],
    )
    if "pip" in uv_choice:
        run(["pip", "install", "uv"])
    elif "pacman" in uv_choice:
        run(["sudo", "pacman", "-S", "--noconfirm", "uv"])

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
            run(["sudo", "pacman", "-S", "--noconfirm", "tesseract"])
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
    for candidate in ["/usr/bin", "/usr/local/bin"]:
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
    print("  Platform: Arch Linux (pacman)")
    print()
    print("This script installs missing dependencies via pacman.")
    print("It will ask before making any choice that has alternatives.")

    ensure_sudo()
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

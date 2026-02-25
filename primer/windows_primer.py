"""
primer/windows_primer.py — Setup steps for Windows using Chocolatey.
"""

import subprocess
import sys
import os
import shutil
import textwrap

from common import (
    amber, ask, ask_yes_no, is_available, run, ensure_postgres, print_summary,
)


# ---------------------------------------------------------------------------
# Elevation
# ---------------------------------------------------------------------------

def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def relaunch_as_admin() -> None:
    python = sys.executable
    script = os.path.abspath(sys.argv[0])
    subprocess.run([
        "powershell", "-NoProfile", "-Command",
        f'Start-Process "{python}" -ArgumentList \'"{script}"\' -Verb RunAs -Wait'
    ])
    sys.exit(0)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def choco_install(package: str, extra_args: list[str] | None = None) -> None:
    cmd = ["choco", "install", package, "-y", "--no-progress"]
    if extra_args:
        cmd.extend(extra_args)
    run(cmd)


def refresh_path() -> None:
    """Reload PATH from the Windows registry into the current process."""
    print("\n  Refreshing PATH …")
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                            r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment") as key:
            sys_path, _ = winreg.QueryValueEx(key, "Path")
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment") as key:
            try:
                user_path, _ = winreg.QueryValueEx(key, "Path")
            except FileNotFoundError:
                user_path = ""
        os.environ["PATH"] = ";".join(filter(None, [sys_path, user_path]))
        print("  PATH refreshed from registry.")
    except Exception as e:
        print(f"  WARNING: could not refresh PATH from registry: {e}")


# ---------------------------------------------------------------------------
# Step 0 – Chocolatey
# ---------------------------------------------------------------------------

def ensure_package_manager() -> None:
    print("\n" + "=" * 60)
    print("STEP 0: Chocolatey")
    print("=" * 60)

    if is_available("choco"):
        print("  ✓ Chocolatey already installed.")
        return

    print("  Chocolatey is not installed.")
    if not ask_yes_no("Install Chocolatey now? (requires an elevated PowerShell prompt)"):
        print("  Chocolatey is required. Exiting.")
        sys.exit(1)

    install_script = (
        "Set-ExecutionPolicy Bypass -Scope Process -Force; "
        "[System.Net.ServicePointManager]::SecurityProtocol = "
        "[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; "
        "iex ((New-Object System.Net.WebClient).DownloadString("
        "'https://community.chocolatey.org/install.ps1'))"
    )
    run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", install_script])
    refresh_path()

    if not is_available("choco"):
        print("\n  ERROR: choco still not found after install. Open a new terminal and retry.")
        sys.exit(1)

    print("  ✓ Chocolatey installed.")


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
    if not ask_yes_no("Install Git via Chocolatey?"):
        print("  Skipping Git install.")
        return

    choco_install("git")
    refresh_path()
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
    print(textwrap.dedent("""
      Elixir requires Erlang/OTP. The Chocolatey 'elixir' package installs
      both automatically.  Alternatively, install each separately if you need
      a specific Erlang version.
    """))

    choice = ask(
        "How would you like to install Elixir?",
        [
            "Install Elixir via Chocolatey (includes Erlang/OTP) [recommended]",
            "Install Erlang and Elixir separately via Chocolatey",
            "Skip (I will install manually)",
        ],
    )

    if "Skip" in choice:
        print("  Skipping Elixir install.")
        return

    if "separately" in choice:
        choco_install("erlang")
        choco_install("elixir")
    else:
        choco_install("elixir")

    refresh_path()
    print("  ✓ Elixir installed.")


# ---------------------------------------------------------------------------
# Step 3 – C compiler (Visual Studio Build Tools, required for NIFs)
# ---------------------------------------------------------------------------

def _import_vs_environment(architecture: str = "amd64") -> bool:
    """
    Import the full Visual Studio build environment by running vcvarsall.bat
    and capturing all environment variables it sets into os.environ.
    Returns True if successful.
    """
    if is_available("nmake") and is_available("cl"):
        return True

    vswhere = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if not os.path.isfile(vswhere):
        print("  WARNING: vswhere not found — cannot locate vcvarsall.bat.")
        return False

    result = subprocess.run(
        [vswhere, "-latest", "-products", "*",
         "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
         "-property", "installationPath"],
        capture_output=True, text=True,
    )
    install_path = result.stdout.strip()
    if not install_path:
        print("  WARNING: vswhere found no VS installation with VC tools.")
        return False

    vcvarsall = os.path.join(install_path, "VC", "Auxiliary", "Build", "vcvarsall.bat")
    if not os.path.isfile(vcvarsall):
        print(f"  WARNING: vcvarsall.bat not found at: {vcvarsall}")
        return False

    print(f"  Importing Visual Studio environment ({architecture}) ...")
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        subprocess.run(
            f'cmd /c ""{vcvarsall}" {architecture} && set > "{tmp_path}""',
            shell=True,
        )
        with open(tmp_path, "r", errors="replace") as f:
            for line in f:
                line = line.rstrip("\n")
                if "=" in line:
                    name, _, value = line.partition("=")
                    if name and name not in ("PROMPT", "PSModulePath"):
                        os.environ[name] = value
    finally:
        os.unlink(tmp_path)

    if is_available("nmake"):
        print("  Visual Studio environment loaded successfully.")
        return True
    else:
        print("  WARNING: nmake still not found after loading VS environment.")
        return False


def ensure_c_compiler() -> None:
    print("\n" + "=" * 60)
    print("STEP 3: C compiler (Visual Studio Build Tools)")
    print("=" * 60)

    if is_available("nmake") or is_available("cl"):
        print("  ✓ MSVC tools already available.")
        return

    # Try to load the VS environment first (VS may be installed but env not set)
    if _import_vs_environment():
        print("  ✓ Visual Studio Build Tools environment loaded.")
        return

    print("  Visual Studio Build Tools are required to compile Elixir NIFs (e.g. bcrypt_elixir).")
    print("  This is a large download (~3–4 GB).")
    if not ask_yes_no("Install Visual Studio 2022 Build Tools via Chocolatey?"):
        print("  Skipping — NIF compilation may fail during 'mix setup'.")
        return

    # VS installer often exits with 4294967295 (0xFFFFFFFF) meaning "reboot required"
    # not a real failure. --ignore-exit-codes stops choco aborting on it.
    # check=False lets us verify success via nmake detection instead of the exit code.
    run(
        ["choco", "install", "visualstudio2022buildtools", "-y", "--no-progress",
         "--ignore-exit-codes",
         "--package-parameters",
         "--add Microsoft.VisualStudio.Workload.VCTools "
         "--add Microsoft.VisualStudio.Component.Windows11SDK.26100 "
         "--includeRecommended --passive"],
        check=False,
    )
    if _import_vs_environment():
        print("  ✓ Visual Studio Build Tools installed.")
    else:
        print("  WARNING: nmake not found yet — a reboot may be required.")
        print("  After rebooting, re-run this script to continue setup.")
# ---------------------------------------------------------------------------

def ensure_wsl() -> None:
    print(amber(textwrap.dedent("""
      PRECONDITION: WSL 2 (Windows Subsystem for Linux)

      WSL 2 is required by Docker Desktop on Windows.
      If it is not yet installed, open PowerShell as Administrator and run:

          wsl --install --no-distribution

      Then reboot before continuing.
    """)))

    if not ask_yes_no(amber("Is WSL 2 installed on this machine?")):
        print("  Please install WSL 2, reboot, then re-run this script.")
        sys.exit(1)

    print("  ✓ WSL 2 confirmed.")


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
        3. Docker Desktop is currently running in the system tray
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
            "Yes, install uv via Chocolatey",
            "No, skip",
        ],
    )
    if "pip" in uv_choice:
        run(["pip", "install", "uv"])
    elif "Chocolatey" in uv_choice:
        choco_install("uv")
        refresh_path()

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
            choco_install("tesseract")
            refresh_path()
            print("  ✓ Tesseract installed.")

    # --- Python venv + pip deps ---
    print()
    if ask_yes_no("Create python_service/.venv and install Python dependencies now?"):
        python_exe = shutil.which("python") or shutil.which("python3") or "python"
        venv_dir = os.path.join("python_service", ".venv")
        run([python_exe, "-m", "venv", venv_dir])
        pip_exe = os.path.join(venv_dir, "Scripts", "pip.exe")
        run([pip_exe, "install", "-r", os.path.join("python_service", "requirements.txt")])
        print("  ✓ Python venv created and dependencies installed.")

    print("  ✓ Python setup complete.")


# ---------------------------------------------------------------------------
# Mix PATH helper + Windows-specific mix setup
# ---------------------------------------------------------------------------

def _find_vs_paths() -> tuple[str | None, str | None]:
    """Return (vcvarsall_path, nmake_dir) using vswhere; either may be None."""
    vswhere = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if not os.path.isfile(vswhere):
        return None, None
    result = subprocess.run(
        [vswhere, "-latest", "-products", "*",
         "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
         "-property", "installationPath"],
        capture_output=True, text=True,
    )
    install_path = result.stdout.strip()
    if not install_path:
        return None, None

    vcvarsall = os.path.join(install_path, "VC", "Auxiliary", "Build", "vcvarsall.bat")
    if not os.path.isfile(vcvarsall):
        return None, None

    # Find the nmake.exe bin dir (walk MSVC/x.y.z/bin/HostX64/x64)
    nmake_dir = None
    msvc_base = os.path.join(install_path, "VC", "Tools", "MSVC")
    if os.path.isdir(msvc_base):
        for version in sorted(os.listdir(msvc_base), reverse=True):
            candidate = os.path.join(msvc_base, version, "bin", "HostX64", "x64")
            if os.path.isfile(os.path.join(candidate, "nmake.exe")):
                nmake_dir = candidate
                break

    return vcvarsall, nmake_dir


def ensure_mix_on_path() -> None:
    """Refresh PATH and, if mix is still missing, probe known Elixir install dirs."""
    refresh_path()
    if is_available("mix"):
        return
    candidates = [
        r"C:\ProgramData\chocolatey\bin",
        r"C:\Program Files\Elixir\bin",
        r"C:\ProgramData\chocolatey\lib\Elixir\tools\bin",
    ]
    for candidate in candidates:
        if any(os.path.isfile(os.path.join(candidate, name)) for name in ["mix.bat", "mix"]):
            print(f"  Adding {candidate} to PATH")
            os.environ["PATH"] = candidate + ";" + os.environ.get("PATH", "")
            return


def run_mix_setup() -> None:
    """Run mix setup, loading the VS build environment first if available."""
    print("\n" + "=" * 60)
    print("STEP 6: Elixir project setup (mix setup)")
    print("=" * 60)

    # Find mix.bat location for PATH injection inside cmd
    mix_dir = None
    for candidate in [
        r"C:\ProgramData\chocolatey\lib\Elixir\tools\bin",
        r"C:\ProgramData\chocolatey\bin",
        r"C:\Program Files\Elixir\bin",
    ]:
        if os.path.isfile(os.path.join(candidate, "mix.bat")):
            mix_dir = candidate
            break

    if mix_dir is None and not is_available("mix"):
        print("  mix not found on PATH — skipping. Run 'mix setup' manually once Elixir is installed.")
        return

    if not ask_yes_no("Run 'mix setup' now? (downloads deps, creates DB, builds assets)"):
        print("  Skipping mix setup.")
        return

    vcvarsall, nmake_dir = _find_vs_paths()
    cwd = os.path.abspath(".")

    if vcvarsall:
        # Build an explicit PATH that includes nmake + mix dirs.
        # Erlang's System.find_executable may not see vcvarsall's PATH changes,
        # so we inject the MSVC bin dir explicitly in the same cmd session.
        extra_dirs = ";".join(filter(None, [mix_dir, nmake_dir]))
        path_prefix = f"{extra_dirs};" if extra_dirs else ""
        cmd_str = (
            f'"{vcvarsall}" amd64 '
            f'&& set "PATH={path_prefix}%PATH%" '
            f'&& cd /d "{cwd}" '
            f'&& mix setup'
        )
        print(f"\n  $ (vcvarsall amd64 + explicit MSVC PATH) mix setup")
        result = subprocess.run(["cmd", "/c", cmd_str])
    else:
        result = subprocess.run(["mix", "setup"], shell=True, cwd=cwd)

    if result.returncode != 0:
        print(f"\n  ERROR: mix setup exited with code {result.returncode}")
        sys.exit(result.returncode)

    print("  ✓ mix setup complete.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    print()
    print("=" * 52)
    print("  GroceryPlanner -- Local Environment Setup")
    print("=" * 52)
    print()
    print("  Platform: Windows (Chocolatey)")
    print()
    print("This script installs missing dependencies via Chocolatey.")
    print("It will ask before making any choice that has alternatives.")

    if not is_admin():
        print("\n  Administrator privileges are required.")
        print("  Re-launching with elevated permissions (UAC prompt may appear) ...")
        relaunch_as_admin()

    ensure_wsl()
    ensure_docker()

    if not ask_yes_no("Continue?"):
        print("Exiting.")
        sys.exit(0)

    ensure_package_manager()
    ensure_git()
    ensure_elixir()
    ensure_c_compiler()
    ensure_python()
    ensure_mix_on_path()
    ensure_postgres()
    run_mix_setup()
    print_summary()

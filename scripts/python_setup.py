"""
Cross-platform Python service setup: creates the venv and installs dependencies.
Called from the mix 'python.setup' alias so it works on Windows, macOS, and Linux.
"""

import subprocess
import sys
import pathlib

VENV_DIR = pathlib.Path("python_service/.venv")
REQUIREMENTS = pathlib.Path("python_service/requirements.txt")

subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)

pip = VENV_DIR / ("Scripts" if sys.platform == "win32" else "bin") / "pip"
subprocess.run([str(pip), "install", "-q", "-r", str(REQUIREMENTS)], check=True)

print("  python_service venv ready.")

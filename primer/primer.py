#!/usr/bin/env python3
"""
primer/primer.py — GroceryPlanner local environment setup.

Detects the current OS and delegates to the appropriate platform script.
Supports: Windows (Chocolatey), macOS (Homebrew), Arch Linux (pacman).

Re-running is safe — already-installed packages are skipped.
"""

import sys
import os

# Ensure this directory is on sys.path so sibling scripts are importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if sys.platform == "win32":
    from windows_primer import main
elif sys.platform == "darwin":
    from macos_primer import main
elif sys.platform == "linux":
    from linux_primer import main
else:
    print(f"Unsupported platform: {sys.platform}")
    print("Please set up the environment manually. See README.md for instructions.")
    sys.exit(1)

if __name__ == "__main__":
    main()

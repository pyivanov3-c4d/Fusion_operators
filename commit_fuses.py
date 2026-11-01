# -*- coding: utf-8 -*-
"""
commit_fuses.py
----------------
Scans the project for changed / newly added .fuse files (PSN_ operators and any
other Fusion fuses), stages them, commits with a structured message, and pushes
to the GitHub repository.

Usage:
    python commit_fuses.py                 # scan, commit, push
    python commit_fuses.py --dry-run       # show what would be committed, no push
    python commit_fuses.py --no-push       # commit locally only
    python commit_fuses.py --message "msg" # custom commit message prefix
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Repo root = folder containing this script
REPO_ROOT = Path(__file__).resolve().parent

# Git identity for commits made by this script (falls back to repo/global config
# if set to None)
GIT_USER_NAME = None          # e.g. "Poul San"
GIT_USER_EMAIL = None         # e.g. "you@example.com"

# Remote / branch to push to
REMOTE = "origin"
BRANCH = None                 # None = push the currently checked-out branch

# Fuse file pattern: PSN_ operators live anywhere under the repo root.
# Add more patterns here if you keep fuses in other locations.
FUSE_PATTERNS = ["**/*.fuse"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_git(args, check=True, capture=True):
    """Run a git command inside REPO_ROOT and return stdout as text."""
    result = subprocess.run(
        ["git"] + args,
        cwd=str(REPO_ROOT),
        capture_output=capture,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode != 0:
        print(f"[ERROR] git {' '.join(args)}\n{result.stderr.strip()}")
        sys.exit(result.returncode)
    return result.stdout.strip()


def ensure_repo():
    """Verify we are inside a git repository with a configured remote."""
    if not (REPO_ROOT / ".git").exists():
        print(f"[ERROR] Not a git repository: {REPO_ROOT}")
        print("        Run 'git init' first, or move this script into the repo root.")
        sys.exit(1)
    remotes = run_git(["remote"])
    if REMOTE not in remotes.split():
        print(f"[WARN] Remote '{REMOTE}' is not configured.")
        print(f"       Add it with: git remote add {REMOTE} <github-url>")
        return False
    return True


def apply_identity():
    """Apply local git identity if configured at the top of this script."""
    if GIT_USER_NAME:
        run_git(["config", "user.name", GIT_USER_NAME])
    if GIT_USER_EMAIL:
        run_git(["config", "user.email", GIT_USER_EMAIL])


def find_changed_fuses():
    """
    Return (new_files, modified_files) lists of repo-relative .fuse paths,
    based on git status (porcelain) filtered to .fuse files.
    """
    out = run_git(["status", "--porcelain"])
    new, modified = [], []
    for line in out.splitlines():
        if not line.strip():
            continue
        status = line[:2]
        path = line[3:].strip().strip('"')
        # Handle renamed entries ("old -> new")
        if " -> " in path:
            path = path.split(" -> ")[1]
        if not path.lower().endswith(".fuse"):
            continue
        if "?" in status or "A" in status:
            new.append(path)
        elif "M" in status or "D" in status or "R" in status:
            modified.append(path)
    return new, modified


def build_commit_message(new, modified, prefix=None):
    """Structured commit message with date and file lists."""
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    head = prefix or "Fuses update"
    lines = [f"{head} — {stamp}", ""]
    if new:
        lines.append(f"Added ({len(new)}):")
        lines += [f"  + {p}" for p in new]
    if modified:
        lines.append(f"Modified ({len(modified)}):")
        lines += [f"  ~ {p}" for p in modified]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Commit changed/new .fuse files to GitHub.")
    parser.add_argument("--dry-run", action="store_true", help="show changes only, no commit/push")
    parser.add_argument("--no-push", action="store_true", help="commit locally without pushing")
    parser.add_argument("--message", "-m", default=None, help="custom commit message prefix")
    args = parser.parse_args()

    has_remote = ensure_repo()
    apply_identity()

    new, modified = find_changed_fuses()
    total = len(new) + len(modified)

    if total == 0:
        print("[OK] No changed or new .fuse files. Nothing to commit.")
        return

    print(f"[INFO] Found {total} .fuse file(s) to commit:")
    for p in new:
        print(f"  + {p}")
    for p in modified:
        print(f"  ~ {p}")

    if args.dry_run:
        print("[DRY-RUN] No changes staged or committed.")
        return

    # Stage only the .fuse files
    fuse_files = new + modified
    run_git(["add", "--"] + fuse_files)

    message = build_commit_message(new, modified, args.message)
    run_git(["commit", "-m", message])
    print("[OK] Commit created:")
    print(message)

    if args.no_push or not has_remote:
        print("[OK] Skipping push (--no-push or missing remote).")
        return

    branch = BRANCH or run_git(["rev-parse", "--abbrev-ref", "HEAD"])
    print(f"[INFO] Pushing to {REMOTE}/{branch} ...")
    push = subprocess.run(
        ["git", "push", "-u", REMOTE, branch],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )
    if push.returncode != 0:
        print(f"[ERROR] Push failed:\n{push.stderr.strip()}")
        sys.exit(push.returncode)
    print(f"[OK] Pushed {total} .fuse file(s) to {REMOTE}/{branch}.")


if __name__ == "__main__":
    main()

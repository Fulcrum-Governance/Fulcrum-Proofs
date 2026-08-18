#!/usr/bin/env python3
"""Redacted, fail-fast prerequisites for live benchmark runs."""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]


def resolve_source_repo(value: str | None) -> Path:
    raw = os.environ.get("FULCRUM_SOURCE_REPO", value or "../Fulcrum")
    candidate = Path(raw).expanduser()
    return candidate if candidate.is_absolute() else (ROOT / candidate).resolve()


def load_credential_keys(creds_file: Path) -> set[str]:
    if not creds_file.exists():
        return set()
    keys: set[str] = set()
    for line in creds_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export ") and "=" in line:
            keys.add(line[len("export ") :].split("=", 1)[0].strip())
    return keys


def fail(code: str, message: str) -> None:
    print(f"{code}: {message}", file=sys.stderr)
    raise SystemExit(1)


def check_source_repo(source_repo: Path) -> None:
    if not source_repo.is_dir():
        fail("BENCH_SOURCE_REPO_MISSING", f"no Fulcrum source checkout at {source_repo}; set FULCRUM_SOURCE_REPO")
    git = subprocess.run(
        ["git", "-C", str(source_repo), "rev-parse", "--is-inside-work-tree"],
        text=True,
        capture_output=True,
    )
    if git.returncode != 0 or git.stdout.strip() != "true":
        fail("BENCH_SOURCE_REPO_INVALID", f"{source_repo} is not a Git checkout")
    porcelain = subprocess.run(
        ["git", "-C", str(source_repo), "status", "--porcelain"],
        text=True,
        capture_output=True,
        check=True,
    )
    if porcelain.stdout.strip():
        fail("BENCH_SOURCE_REPO_DIRTY", f"{source_repo} has uncommitted changes; use a clean checkout")
    setup = source_repo / "scripts/setup-load-test-auth.sh"
    if not setup.is_file() or not os.access(setup, os.X_OK):
        fail("BENCH_SOURCE_SETUP_MISSING", f"missing executable scripts/setup-load-test-auth.sh in {source_repo}")


def check_credentials(source_repo: Path, creds_file: Path) -> None:
    required = {"FULCRUM_TEST_API_KEY", "FULCRUM_TEST_TENANT_ID"}
    if required.issubset(load_credential_keys(creds_file)):
        return
    setup = source_repo / "scripts/setup-load-test-auth.sh"
    result = subprocess.run([str(setup)], cwd=source_repo, text=True, capture_output=True)
    if result.returncode != 0:
        fail("BENCH_CREDENTIAL_SETUP_FAILED", f"{setup} exited {result.returncode}; inspect the source checkout setup logs")
    missing = sorted(required - load_credential_keys(creds_file))
    if missing:
        fail("BENCH_CREDENTIALS_MISSING", f"credentials file lacks required keys: {', '.join(missing)}")


def check_service(host: str) -> None:
    hostname, separator, port_text = host.rpartition(":")
    if not separator or not hostname or not port_text.isascii() or not port_text.isdigit():
        fail("BENCH_SERVICE_ADDRESS_INVALID", f"expected host:port, got {host}")
    try:
        port = int(port_text)
    except ValueError:
        fail("BENCH_SERVICE_ADDRESS_INVALID", f"expected host:port, got {host}")
    if not 1 <= port <= 65535:
        fail("BENCH_SERVICE_ADDRESS_INVALID", f"expected host:port with port in 1..65535, got {host}")
    try:
        with socket.create_connection((hostname, port), timeout=2):
            pass
    except OSError as error:
        fail("BENCH_SERVICE_UNAVAILABLE", f"cannot connect to {host}: {error.__class__.__name__}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()
    manifest = yaml.safe_load(Path(args.manifest).read_text(encoding="utf-8")) or {}
    source_repo = resolve_source_repo(manifest.get("source_repo"))
    check_source_repo(source_repo)
    credentials_file = Path(manifest.get("credentials_file", "/tmp/fulcrum-load-test-credentials.sh"))
    check_credentials(source_repo, credentials_file)
    check_service(str(manifest.get("host", "localhost:50051")))
    print(f"BENCH_PREFLIGHT_OK: source={source_repo} service={manifest.get('host', 'localhost:50051')}")


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

expect_failure() {
  local expected="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    echo "Expected failure containing $expected" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected $expected, got: $output" >&2
    exit 1
  fi
}

expect_failure_redacted() {
  local expected="$1"
  local forbidden="$2"
  shift 2
  local output
  if output="$("$@" 2>&1)"; then
    echo "Expected failure containing $expected" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* || "$output" == *"$forbidden"* ]]; then
    echo "Expected redacted failure containing $expected" >&2
    exit 1
  fi
}

CALLER_DIR="$TMP_DIR/caller cwd"
mkdir -p "$CALLER_DIR"
JAVA_BIN="$CALLER_DIR/java with spaces"
CANONICAL_CALLER_DIR="$(cd "$CALLER_DIR" && pwd -P)"
CANONICAL_JAVA_BIN="$CANONICAL_CALLER_DIR/java with spaces"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "-version" ]]; then\n  echo '\''openjdk version "17.0.0"'\'' >&2\n  exit 0\nfi\nprintf '\''java=%%s args=%%s\\n'\'' "$0" "$*" >> "${TLA_EXEC_LOG:?}"\n' > "$JAVA_BIN"
chmod +x "$JAVA_BIN"
expect_failure "TLA_JAVA_MISSING" env TLA_JAVA_BIN="$TMP_DIR/no-java" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
expect_failure "TLA_JAR_MISSING" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
mkdir -p "$TMP_DIR/tools"
printf 'not a jar\n' > "$TMP_DIR/tools/tla2tools.jar"
expect_failure "TLA_JAR_CHECKSUM_MISMATCH" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"

TLC_INSTALL_DIR="$TMP_DIR/tlc tools"
TLA_TOOLS_DIR="$TLC_INSTALL_DIR" bash "$ROOT/scripts/tla_toolchain.sh" --install >/dev/null
OVERRIDE_TOOLS="$CALLER_DIR/override tools"
CANONICAL_OVERRIDE_TOOLS="$CANONICAL_CALLER_DIR/override tools"
mkdir -p "$OVERRIDE_TOOLS"
cp "$TLC_INSTALL_DIR/tla2tools.jar" "$OVERRIDE_TOOLS/tla2tools.jar"
TLA_EXEC_LOG="$TMP_DIR/tla-executions.log"
(
  cd "$CALLER_DIR"
  env \
    TLA_JAVA_BIN="./java with spaces" \
    TLA_TOOLS_DIR="./override tools" \
    TLA_TRACE_DIR="$TMP_DIR/traces" \
    TLA_REPORT_DIR="$TMP_DIR/reports" \
    TLA_EXEC_LOG="$TLA_EXEC_LOG" \
    bash "$ROOT/models/tla/scripts/run_tlc.sh" >/dev/null
)
if [[ "$(wc -l < "$TLA_EXEC_LOG")" -ne 3 ]] \
  || ! grep -F -- "java=$CANONICAL_JAVA_BIN args=-cp $CANONICAL_OVERRIDE_TOOLS/tla2tools.jar tlc2.TLC" "$TLA_EXEC_LOG" >/dev/null; then
  echo "Expected TLC to execute the exact verified relative overrides" >&2
  exit 1
fi

UNCONFIGURED_MANIFEST="$TMP_DIR/unconfigured-manifest.yaml"
cat > "$UNCONFIGURED_MANIFEST" <<EOF
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:1
EOF
expect_failure "BENCH_SOURCE_REPO_UNCONFIGURED" env -u FULCRUM_SOURCE_REPO python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$UNCONFIGURED_MANIFEST"
expect_failure "BENCH_SOURCE_REPO_UNCONFIGURED" env -u FULCRUM_SOURCE_REPO python3 "$ROOT/benchmarks/harness/run_benchmarks.py" --manifest "$UNCONFIGURED_MANIFEST" --out "$TMP_DIR/unconfigured.json"

MANIFEST="$TMP_DIR/manifest.yaml"
cat > "$MANIFEST" <<EOF
source_repo: $TMP_DIR/missing-source
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:1
EOF
expect_failure "BENCH_SOURCE_REPO_MISSING" env FULCRUM_SOURCE_REPO="$TMP_DIR/missing-source" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

SOURCE="$TMP_DIR/source"
mkdir -p "$SOURCE/scripts"
GIT_FIXTURE_HOME="$TMP_DIR/git-home"
GIT_FIXTURE_HOOKS="$TMP_DIR/git-hooks"
mkdir -p "$GIT_FIXTURE_HOME" "$GIT_FIXTURE_HOOKS"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git init -q "$SOURCE"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$SOURCE" config user.email "test@example.invalid"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$SOURCE" config user.name "toolchain-preflight-test"
printf '#!/usr/bin/env bash\nexit 23\n' > "$SOURCE/scripts/setup-load-test-auth.sh"
chmod +x "$SOURCE/scripts/setup-load-test-auth.sh"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$SOURCE" add scripts/setup-load-test-auth.sh
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$SOURCE" -c commit.gpgSign=false -c core.hooksPath="$GIT_FIXTURE_HOOKS" commit -qm "test fixture"
expect_failure "BENCH_CREDENTIAL_SETUP_FAILED" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

EMPTY_SOURCE="$TMP_DIR/empty-source"
mkdir -p "$EMPTY_SOURCE/scripts"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git init -q "$EMPTY_SOURCE"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" config user.email "test@example.invalid"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" config user.name "toolchain-preflight-test"
printf '#!/usr/bin/env bash\nexit 0\n' > "$EMPTY_SOURCE/scripts/setup-load-test-auth.sh"
chmod +x "$EMPTY_SOURCE/scripts/setup-load-test-auth.sh"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" add scripts/setup-load-test-auth.sh
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" -c commit.gpgSign=false -c core.hooksPath="$GIT_FIXTURE_HOOKS" commit -qm "empty credential fixture"
printf 'export FULCRUM_TEST_API_KEY=fixture-api-key-must-stay-redacted\nexport FULCRUM_TEST_TENANT_ID=""\n' > "$TMP_DIR/empty-credentials.sh"
EMPTY_CREDENTIALS_MANIFEST="$TMP_DIR/empty-credentials-manifest.yaml"
cat > "$EMPTY_CREDENTIALS_MANIFEST" <<EOF
source_repo: $EMPTY_SOURCE
credentials_file: $TMP_DIR/empty-credentials.sh
host: 127.0.0.1:1
EOF
expect_failure_redacted "BENCH_CREDENTIALS_MISSING" "fixture-api-key-must-stay-redacted" env FULCRUM_SOURCE_REPO="$EMPTY_SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$EMPTY_CREDENTIALS_MANIFEST"

printf 'export FULCRUM_TEST_API_KEY=redacted\nexport FULCRUM_TEST_TENANT_ID=redacted\n' > "$TMP_DIR/credentials.sh"
INVALID_HOST_MANIFEST="$TMP_DIR/invalid-host-manifest.yaml"
cat > "$INVALID_HOST_MANIFEST" <<EOF
source_repo: $SOURCE
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:not-a-port
EOF
expect_failure "BENCH_SERVICE_ADDRESS_INVALID" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$INVALID_HOST_MANIFEST"

OUT_OF_RANGE_PORT_MANIFEST="$TMP_DIR/out-of-range-port-manifest.yaml"
cat > "$OUT_OF_RANGE_PORT_MANIFEST" <<EOF
source_repo: $SOURCE
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:65536
EOF
expect_failure "BENCH_SERVICE_ADDRESS_INVALID" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$OUT_OF_RANGE_PORT_MANIFEST"

expect_failure "BENCH_SERVICE_UNAVAILABLE" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

echo "toolchain preflight diagnostics passed"

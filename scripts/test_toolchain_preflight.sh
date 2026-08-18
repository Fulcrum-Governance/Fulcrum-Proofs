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

JAVA_BIN="$TMP_DIR/java with spaces"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "-version" ]]; then\n  echo '\''openjdk version "17.0.0"'\'' >&2\n  exit 0\nfi\nprintf '\''%%s\\n'\'' "$*" >> "${TLA_EXEC_LOG:?}"\n' > "$JAVA_BIN"
chmod +x "$JAVA_BIN"
expect_failure "TLA_JAVA_MISSING" env TLA_JAVA_BIN="$TMP_DIR/no-java" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
expect_failure "TLA_JAR_MISSING" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
mkdir -p "$TMP_DIR/tools"
printf 'not a jar\n' > "$TMP_DIR/tools/tla2tools.jar"
expect_failure "TLA_JAR_CHECKSUM_MISMATCH" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"

bash "$ROOT/scripts/tla_toolchain.sh" --install >/dev/null
OVERRIDE_TOOLS="$TMP_DIR/override-tools"
mkdir -p "$OVERRIDE_TOOLS"
cp "$ROOT/models/tla/tools/tla2tools.jar" "$OVERRIDE_TOOLS/tla2tools.jar"
TLA_EXEC_LOG="$TMP_DIR/tla-executions.log"
env \
  TLA_JAVA_BIN="$JAVA_BIN" \
  TLA_TOOLS_DIR="$OVERRIDE_TOOLS" \
  TLA_TRACE_DIR="$TMP_DIR/traces" \
  TLA_REPORT_DIR="$TMP_DIR/reports" \
  TLA_EXEC_LOG="$TLA_EXEC_LOG" \
  bash "$ROOT/models/tla/scripts/run_tlc.sh" >/dev/null
if [[ "$(wc -l < "$TLA_EXEC_LOG")" -ne 3 ]] || ! grep -F -- "-cp $OVERRIDE_TOOLS/tla2tools.jar tlc2.TLC" "$TLA_EXEC_LOG" >/dev/null; then
  echo "Expected TLC to execute the checksum-verified TLA_TOOLS_DIR override" >&2
  exit 1
fi

MANIFEST="$TMP_DIR/manifest.yaml"
cat > "$MANIFEST" <<EOF
source_repo: $TMP_DIR/missing-source
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:1
EOF
expect_failure "BENCH_SOURCE_REPO_MISSING" env FULCRUM_SOURCE_REPO="$TMP_DIR/missing-source" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

SOURCE="$TMP_DIR/source"
mkdir -p "$SOURCE/scripts"
git -C "$SOURCE" init -q
git -C "$SOURCE" config user.email "test@example.invalid"
git -C "$SOURCE" config user.name "toolchain-preflight-test"
printf '#!/usr/bin/env bash\nexit 23\n' > "$SOURCE/scripts/setup-load-test-auth.sh"
chmod +x "$SOURCE/scripts/setup-load-test-auth.sh"
git -C "$SOURCE" add scripts/setup-load-test-auth.sh
git -C "$SOURCE" commit -qm "test fixture"
expect_failure "BENCH_CREDENTIAL_SETUP_FAILED" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

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

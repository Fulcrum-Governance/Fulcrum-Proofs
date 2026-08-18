#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LISTENER_PID=""
CLEANUP_DONE=0

cleanup() {
  if [[ "$CLEANUP_DONE" -ne 0 ]]; then
    return
  fi
  CLEANUP_DONE=1
  if [[ -n "${SIGNAL_PROBE_CLEANUP_COUNT_FILE:-}" ]]; then
    printf 'cleanup\n' >> "$SIGNAL_PROBE_CLEANUP_COUNT_FILE"
  fi
  if [[ -n "$LISTENER_PID" ]]; then
    kill "$LISTENER_PID" >/dev/null 2>&1 || true
    wait "$LISTENER_PID" >/dev/null 2>&1 || true
    LISTENER_PID=""
  fi
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
    TMP_DIR=""
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

run_signal_cleanup_probe() {
  local signal_name="$1"
  local state_dir="${SIGNAL_PROBE_STATE_DIR:?}"
  local listener_ready="$state_dir/listener-ready"
  local listener_stopped="$state_dir/listener-stopped"

  mkdir -p "$state_dir"
  printf '%s\n' "$TMP_DIR" > "$state_dir/tmp-dir"
  python3 - "$listener_ready" "$listener_stopped" <<'PY' &
import signal
import socket
import sys
from pathlib import Path

ready = Path(sys.argv[1])
stopped = Path(sys.argv[2])
listener = socket.socket()
listener.bind(("127.0.0.1", 0))
listener.listen(1)
ready.write_text("ready\n", encoding="utf-8")

def stop(_signum, _frame):
    listener.close()
    stopped.write_text("stopped\n", encoding="utf-8")
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGHUP, stop)
signal.signal(signal.SIGINT, stop)
while True:
    signal.pause()
PY
  LISTENER_PID=$!
  printf '%s\n' "$LISTENER_PID" > "$state_dir/listener-pid"
  for _ in $(seq 1 50); do
    [[ -s "$listener_ready" ]] && break
    sleep 0.1
  done
  if [[ ! -s "$listener_ready" ]]; then
    echo "Expected signal cleanup probe listener to become ready" >&2
    exit 1
  fi
  kill -s "$signal_name" "$$"
  echo "Expected signal cleanup probe to exit for $signal_name" >&2
  exit 1
}

assert_direct_signal_cleanup() {
  local signal_name="$1"
  local expected_status="$2"
  local state_dir="$TMP_DIR/signal-cleanup-$signal_name"
  local probe_status probe_tmp listener_pid

  mkdir -p "$state_dir"
  set +e
  SIGNAL_PROBE_STATE_DIR="$state_dir" \
    SIGNAL_PROBE_CLEANUP_COUNT_FILE="$state_dir/cleanup-count" \
    bash "$ROOT/scripts/test_toolchain_preflight.sh" --signal-cleanup-probe "$signal_name" >/dev/null 2>&1
  probe_status=$?
  set -e
  probe_tmp="$(<"$state_dir/tmp-dir")"
  listener_pid="$(<"$state_dir/listener-pid")"
  if [[ "$probe_status" -ne "$expected_status" || -e "$probe_tmp" || ! -s "$state_dir/listener-stopped" || "$(wc -l < "$state_dir/cleanup-count")" -ne 1 ]] || kill -0 "$listener_pid" >/dev/null 2>&1; then
    echo "Expected direct $signal_name cleanup to remove artifacts and stop its listener" >&2
    exit 1
  fi
}

if [[ "${1:-}" == "--signal-cleanup-probe" ]]; then
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 --signal-cleanup-probe [HUP|INT|TERM]" >&2
    exit 2
  fi
  case "$2" in
    HUP|INT|TERM) run_signal_cleanup_probe "$2" ;;
    *)
      echo "Unsupported signal cleanup probe: $2" >&2
      exit 2
      ;;
  esac
fi

assert_direct_signal_cleanup HUP 129
assert_direct_signal_cleanup INT 130
assert_direct_signal_cleanup TERM 143

expect_repeatable_failure() {
  local expected="$1"
  local expected_detail="$2"
  local forbidden="$3"
  shift 3
  local first_output first_status second_output second_status
  set +e
  first_output="$("$@" 2>&1)"
  first_status=$?
  second_output="$("$@" 2>&1)"
  second_status=$?
  set -e
  if [[ "$first_status" -eq 0 || "$second_status" -eq 0 || "$first_status" -ne "$second_status" || "$first_output" != "$second_output" || "$first_output" != *"$expected"* || ( -n "$expected_detail" && "$first_output" != *"$expected_detail"* ) ]]; then
    echo "Expected stable failure containing $expected" >&2
    exit 1
  fi
  if [[ -n "$forbidden" && "$first_output" == *"$forbidden"* ]]; then
    echo "Expected redacted stable failure containing $expected" >&2
    exit 1
  fi
}

write_versioned_java() {
  local path="$1"
  local version="$2"
  mkdir -p "$(dirname "$path")"
  # shellcheck disable=SC2016 # Writes a literal fake-Java script for the fixture.
  printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "-version" ]]; then\n  echo '\''openjdk version "%s"'\'' >&2\nfi\n' "$version" > "$path"
  chmod +x "$path"
}

CALLER_DIR="$TMP_DIR/caller cwd"
mkdir -p "$CALLER_DIR"
JAVA_BIN="$CALLER_DIR/java with spaces"
CANONICAL_CALLER_DIR="$(cd "$CALLER_DIR" && pwd -P)"
CANONICAL_JAVA_BIN="$CANONICAL_CALLER_DIR/java with spaces"
# shellcheck disable=SC2016 # Writes a literal fake-Java script for the fixture.
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "-version" ]]; then\n  echo '\''openjdk version "17.0.0"'\'' >&2\n  exit 0\nfi\nprintf '\''java=%%q\\n'\'' "$0" >> "${TLA_EXEC_LOG:?}"\nindex=0\nfor argument in "$@"; do\n  printf '\''arg[%%d]=%%q\\n'\'' "$index" "$argument" >> "${TLA_EXEC_LOG:?}"\n  index=$((index + 1))\ndone\n' > "$JAVA_BIN"
chmod +x "$JAVA_BIN"
expect_repeatable_failure "TLA_JAVA_MISSING" "" "" env TLA_JAVA_BIN="$TMP_DIR/no-java" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
expect_repeatable_failure "TLA_JAR_MISSING" "bootstrap_toolchains.sh --conductor-setup" "" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"
mkdir -p "$TMP_DIR/tools"
printf 'not a jar\n' > "$TMP_DIR/tools/tla2tools.jar"
expect_repeatable_failure "TLA_JAR_CHECKSUM_MISMATCH" "bootstrap_toolchains.sh --conductor-setup" "" env TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$TMP_DIR/tools" bash "$ROOT/scripts/preflight_model_gate.sh"

HOMEBREW_OPT="$TMP_DIR/homebrew opt"
write_versioned_java "$HOMEBREW_OPT/openjdk@11/bin/java" "11.0.0"
write_versioned_java "$HOMEBREW_OPT/openjdk@21/bin/java" "21.0.0"
write_versioned_java "$HOMEBREW_OPT/openjdk/bin/java" "17.0.0"
DISCOVERED_JAVA="$(env -u TLA_JAVA_BIN -u JAVA_HOME TLA_HOMEBREW_OPT_ROOTS="$HOMEBREW_OPT" bash "$ROOT/scripts/preflight_model_gate.sh" --java-path)"
if [[ "$DISCOVERED_JAVA" != "$(cd "$HOMEBREW_OPT/openjdk@21/bin" && pwd -P)/java" ]]; then
  echo "Expected discovery to skip Homebrew Java 11 and select Java 21" >&2
  exit 1
fi
rm "$HOMEBREW_OPT/openjdk@21/bin/java"
DISCOVERED_JAVA="$(env -u TLA_JAVA_BIN -u JAVA_HOME TLA_HOMEBREW_OPT_ROOTS="$HOMEBREW_OPT" bash "$ROOT/scripts/preflight_model_gate.sh" --java-path)"
if [[ "$DISCOVERED_JAVA" != "$(cd "$HOMEBREW_OPT/openjdk/bin" && pwd -P)/java" ]]; then
  echo "Expected discovery to skip Homebrew Java 11 and select unversioned Java 17" >&2
  exit 1
fi

TLC_INSTALL_DIR="$TMP_DIR/tlc tools"
TLA_TOOLS_DIR="$TLC_INSTALL_DIR" bash "$ROOT/scripts/tla_toolchain.sh" --install >/dev/null

FAKE_CURL_BIN="$TMP_DIR/fake curl bin"
FAILED_TOOLS_DIR="$TMP_DIR/failed tools"
mkdir -p "$FAKE_CURL_BIN"
cat > "$FAKE_CURL_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while (($#)); do
  if [[ "$1" == "--output" ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
printf 'partial download\n' > "$output"
echo "fake curl failure" >&2
exit 22
EOF
chmod +x "$FAKE_CURL_BIN/curl"
expect_repeatable_failure "fake curl failure" "" "" env TLA_TOOLS_DIR="$FAILED_TOOLS_DIR" PATH="$FAKE_CURL_BIN:$PATH" bash "$ROOT/scripts/tla_toolchain.sh" --install
if [[ -e "$FAILED_TOOLS_DIR/tla2tools.jar" ]] || find "$FAILED_TOOLS_DIR" -maxdepth 1 -name '.tla2tools.jar.*' -print -quit | grep -q .; then
  echo "Expected failed TLC download cleanup to remove every partial artifact" >&2
  exit 1
fi
TLA_TOOLS_DIR="$FAILED_TOOLS_DIR" bash "$ROOT/scripts/tla_toolchain.sh" --install >/dev/null

HUP_CURL_BIN="$TMP_DIR/hup curl bin"
HUP_TOOLS_DIR="$TMP_DIR/hup tools"
mkdir -p "$HUP_CURL_BIN"
cat > "$HUP_CURL_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while (($#)); do
  if [[ "$1" == "--output" ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
printf 'partial download\n' > "$output"
kill -HUP "$PPID"
EOF
chmod +x "$HUP_CURL_BIN/curl"
set +e
env TLA_TOOLS_DIR="$HUP_TOOLS_DIR" PATH="$HUP_CURL_BIN:$PATH" bash "$ROOT/scripts/tla_toolchain.sh" --install >/dev/null 2>&1
hup_status=$?
set -e
if [[ "$hup_status" -ne 129 || -e "$HUP_TOOLS_DIR/tla2tools.jar" ]] || find "$HUP_TOOLS_DIR" -maxdepth 1 -name '.tla2tools.jar.*' -print -quit | grep -q .; then
  echo "Expected HUP cleanup to remove every partial TLC artifact" >&2
  exit 1
fi

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
    TLA_TRACE_DIR="./trace dirs" \
    TLA_REPORT_DIR="./report dirs" \
    TLA_EXEC_LOG="$TLA_EXEC_LOG" \
    bash "$ROOT/models/tla/scripts/run_tlc.sh" >/dev/null
)
printf -v CANONICAL_JAR_ARGUMENT '%q' "$CANONICAL_OVERRIDE_TOOLS/tla2tools.jar"
if [[ "$(grep -Fxc "java=$(printf '%q' "$CANONICAL_JAVA_BIN")" "$TLA_EXEC_LOG")" -ne 3 ]] \
  || [[ "$(grep -Fxc 'arg[0]=-cp' "$TLA_EXEC_LOG")" -ne 3 ]] \
  || [[ "$(grep -Fxc "arg[1]=$CANONICAL_JAR_ARGUMENT" "$TLA_EXEC_LOG")" -ne 3 ]]; then
  echo "Expected TLC to execute the exact verified relative overrides" >&2
  exit 1
fi
if [[ ! -d "$CANONICAL_CALLER_DIR/trace dirs" || ! -f "$CANONICAL_CALLER_DIR/report dirs/tlc-GatewaySafetySmall.log" || ! -f "$CANONICAL_CALLER_DIR/report dirs/tlc-GatewaySafety.log" || ! -f "$CANONICAL_CALLER_DIR/report dirs/tlc-GatewaySafetyMedium.log" || -e "$ROOT/models/tla/specs/report dirs" ]]; then
  echo "Expected relative TLC reports and traces to remain in the caller directory" >&2
  exit 1
fi

BOOTSTRAP_BIN="$TMP_DIR/bootstrap bin"
BOOTSTRAP_TOOLS="$TMP_DIR/bootstrap tools"
BOOTSTRAP_LOG="$TMP_DIR/bootstrap.log"
BOOTSTRAP_FORBIDDEN_LOG="$TMP_DIR/bootstrap-forbidden.log"
mkdir -p "$BOOTSTRAP_BIN" "$TMP_DIR/bootstrap-home"
cat > "$BOOTSTRAP_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while (($#)); do
  if [[ "$1" == "--output" ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
cp "${BOOTSTRAP_JAR_SOURCE:?}" "$output"
printf 'curl\n' >> "${BOOTSTRAP_LOG:?}"
EOF
cat > "$BOOTSTRAP_BIN/lake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s\n' "$PWD" "$*" >> "${BOOTSTRAP_LOG:?}"
EOF
cat > "$BOOTSTRAP_BIN/elan" <<'EOF'
#!/usr/bin/env bash
printf 'elan %s\n' "$*" >> "${BOOTSTRAP_FORBIDDEN_LOG:?}"
exit 99
EOF
cat > "$BOOTSTRAP_BIN/python3" <<'EOF'
#!/usr/bin/env bash
printf 'python3 %s\n' "$*" >> "${BOOTSTRAP_FORBIDDEN_LOG:?}"
exit 99
EOF
cat > "$BOOTSTRAP_BIN/python" <<'EOF'
#!/usr/bin/env bash
printf 'python %s\n' "$*" >> "${BOOTSTRAP_FORBIDDEN_LOG:?}"
exit 99
EOF
cat > "$BOOTSTRAP_BIN/pip" <<'EOF'
#!/usr/bin/env bash
printf 'pip %s\n' "$*" >> "${BOOTSTRAP_FORBIDDEN_LOG:?}"
exit 99
EOF
cat > "$BOOTSTRAP_BIN/pip3" <<'EOF'
#!/usr/bin/env bash
printf 'pip3 %s\n' "$*" >> "${BOOTSTRAP_FORBIDDEN_LOG:?}"
exit 99
EOF
chmod +x "$BOOTSTRAP_BIN/curl" "$BOOTSTRAP_BIN/lake" "$BOOTSTRAP_BIN/elan" "$BOOTSTRAP_BIN/python3" "$BOOTSTRAP_BIN/python" "$BOOTSTRAP_BIN/pip" "$BOOTSTRAP_BIN/pip3"
for _ in 1 2; do
  env HOME="$TMP_DIR/bootstrap-home" TLA_JAVA_BIN="$JAVA_BIN" TLA_TOOLS_DIR="$BOOTSTRAP_TOOLS" BOOTSTRAP_JAR_SOURCE="$TLC_INSTALL_DIR/tla2tools.jar" BOOTSTRAP_LOG="$BOOTSTRAP_LOG" BOOTSTRAP_FORBIDDEN_LOG="$BOOTSTRAP_FORBIDDEN_LOG" PATH="$BOOTSTRAP_BIN:$PATH" bash "$ROOT/scripts/bootstrap_toolchains.sh" --conductor-setup >/dev/null
done
if [[ "$(grep -Fxc "curl" "$BOOTSTRAP_LOG")" -ne 1 || "$(grep -Fxc "$ROOT/proofs/lean|exe cache get" "$BOOTSTRAP_LOG")" -ne 2 || -s "$BOOTSTRAP_FORBIDDEN_LOG" ]]; then
  echo "Expected bounded bootstrap to be idempotent and avoid ambient tool installation" >&2
  exit 1
fi

UNCONFIGURED_MANIFEST="$TMP_DIR/unconfigured-manifest.yaml"
cat > "$UNCONFIGURED_MANIFEST" <<EOF
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:1
EOF
expect_repeatable_failure "BENCH_SOURCE_REPO_UNCONFIGURED" "" "" env -u FULCRUM_SOURCE_REPO python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$UNCONFIGURED_MANIFEST"
expect_repeatable_failure "BENCH_SOURCE_REPO_UNCONFIGURED" "" "" env -u FULCRUM_SOURCE_REPO python3 "$ROOT/benchmarks/harness/run_benchmarks.py" --manifest "$UNCONFIGURED_MANIFEST" --out "$TMP_DIR/unconfigured.json"
if [[ -e "$TMP_DIR/unconfigured.json" ]]; then
  echo "Expected unconfigured benchmark runner to leave no output artifact" >&2
  exit 1
fi

MANIFEST="$TMP_DIR/manifest.yaml"
cat > "$MANIFEST" <<EOF
source_repo: $TMP_DIR/missing-source
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:1
EOF
expect_repeatable_failure "BENCH_SOURCE_REPO_MISSING" "" "" env FULCRUM_SOURCE_REPO="$TMP_DIR/missing-source" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

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
expect_repeatable_failure "BENCH_CREDENTIAL_SETUP_FAILED" "" "" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

EMPTY_SOURCE="$TMP_DIR/empty-source"
mkdir -p "$EMPTY_SOURCE/scripts"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git init -q "$EMPTY_SOURCE"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" config user.email "test@example.invalid"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" config user.name "toolchain-preflight-test"
printf '#!/usr/bin/env bash\nexit 0\n' > "$EMPTY_SOURCE/scripts/setup-load-test-auth.sh"
chmod +x "$EMPTY_SOURCE/scripts/setup-load-test-auth.sh"
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" add scripts/setup-load-test-auth.sh
env HOME="$GIT_FIXTURE_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$EMPTY_SOURCE" -c commit.gpgSign=false -c core.hooksPath="$GIT_FIXTURE_HOOKS" commit -qm "empty credential fixture"
printf "export FULCRUM_TEST_API_KEY='   '\nexport FULCRUM_TEST_TENANT_ID=fixture-credential-canary-must-stay-redacted\n" > "$TMP_DIR/empty-credentials.sh"
EMPTY_CREDENTIALS_MANIFEST="$TMP_DIR/empty-credentials-manifest.yaml"
cat > "$EMPTY_CREDENTIALS_MANIFEST" <<EOF
source_repo: $EMPTY_SOURCE
credentials_file: $TMP_DIR/empty-credentials.sh
host: 127.0.0.1:1
EOF
expect_repeatable_failure "BENCH_CREDENTIALS_MISSING" "" "fixture-credential-canary-must-stay-redacted" env FULCRUM_SOURCE_REPO="$EMPTY_SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$EMPTY_CREDENTIALS_MANIFEST"
python3 - "$ROOT" "$TMP_DIR/empty-credentials.sh" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from benchmarks.harness.run_benchmarks import load_credentials

credentials = load_credentials(Path(sys.argv[2]))
assert credentials["FULCRUM_TEST_API_KEY"] == ""
assert credentials["FULCRUM_TEST_TENANT_ID"] == "fixture-credential-canary-must-stay-redacted"
PY

SUCCESS_CREDENTIALS="$TMP_DIR/success-credentials.sh"
printf 'export FULCRUM_TEST_API_KEY=redacted\nexport FULCRUM_TEST_TENANT_ID=redacted\n' > "$SUCCESS_CREDENTIALS"
LISTENER_PORT_FILE="$TMP_DIR/listener-port"
python3 - "$LISTENER_PORT_FILE" <<'PY' &
import socket
import sys
from pathlib import Path

listener = socket.socket()
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(("127.0.0.1", 0))
listener.listen(2)
Path(sys.argv[1]).write_text(str(listener.getsockname()[1]), encoding="utf-8")
for _ in range(2):
    connection, _ = listener.accept()
    connection.close()
listener.close()
PY
LISTENER_PID=$!
for _ in $(seq 1 50); do
  [[ -s "$LISTENER_PORT_FILE" ]] && break
  sleep 0.1
done
if [[ ! -s "$LISTENER_PORT_FILE" ]]; then
  echo "Expected temporary loopback listener to publish its port" >&2
  exit 1
fi
SUCCESS_MANIFEST="$TMP_DIR/success-manifest.yaml"
cat > "$SUCCESS_MANIFEST" <<EOF
source_repo: $EMPTY_SOURCE
credentials_file: $SUCCESS_CREDENTIALS
host: 127.0.0.1:$(<"$LISTENER_PORT_FILE")
EOF
success_output_first="$(env FULCRUM_SOURCE_REPO="$EMPTY_SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$SUCCESS_MANIFEST")"
success_output_second="$(env FULCRUM_SOURCE_REPO="$EMPTY_SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$SUCCESS_MANIFEST")"
wait "$LISTENER_PID"
LISTENER_PID=""
if [[ "$success_output_first" != "$success_output_second" || "$success_output_first" != *"BENCH_PREFLIGHT_OK"* || -n "$(git -C "$EMPTY_SOURCE" status --porcelain)" ]]; then
  echo "Expected clean benchmark preflight fixture to succeed twice with stable output" >&2
  exit 1
fi

printf 'export FULCRUM_TEST_API_KEY=redacted\nexport FULCRUM_TEST_TENANT_ID=redacted\n' > "$TMP_DIR/credentials.sh"
INVALID_HOST_MANIFEST="$TMP_DIR/invalid-host-manifest.yaml"
cat > "$INVALID_HOST_MANIFEST" <<EOF
source_repo: $SOURCE
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:not-a-port
EOF
expect_repeatable_failure "BENCH_SERVICE_ADDRESS_INVALID" "" "" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$INVALID_HOST_MANIFEST"

OUT_OF_RANGE_PORT_MANIFEST="$TMP_DIR/out-of-range-port-manifest.yaml"
cat > "$OUT_OF_RANGE_PORT_MANIFEST" <<EOF
source_repo: $SOURCE
credentials_file: $TMP_DIR/credentials.sh
host: 127.0.0.1:65536
EOF
expect_repeatable_failure "BENCH_SERVICE_ADDRESS_INVALID" "" "" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$OUT_OF_RANGE_PORT_MANIFEST"

expect_repeatable_failure "BENCH_SERVICE_UNAVAILABLE" "" "" env FULCRUM_SOURCE_REPO="$SOURCE" python3 "$ROOT/benchmarks/harness/preflight_bench.py" --manifest "$MANIFEST"

echo "toolchain preflight diagnostics passed"

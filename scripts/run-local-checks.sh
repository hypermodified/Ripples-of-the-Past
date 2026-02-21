#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_VERSION="port-checks-v4-proxy-sane"
MODE=""
PROFILE=""

usage() {
  cat <<USAGE
Usage:
  bash scripts/run-local-checks.sh --port-1201-smoke --port-profile <profile>
  bash scripts/run-local-checks.sh --port-1201-compile-diagnostic --port-profile <profile>
  bash scripts/run-local-checks.sh --port-1201-build-jar --port-profile <profile>

Profiles are relative to repository root (example: porting/gradle-1.20.1-packet-manager-slice.properties).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port-1201-smoke)
      MODE="smoke"
      shift
      ;;
    --port-1201-compile-diagnostic)
      MODE="diagnostic"
      shift
      ;;
    --port-1201-build-jar)
      MODE="build-jar"
      shift
      ;;
    --port-profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Missing mode argument." >&2
  usage >&2
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  echo "Missing --port-profile <profile>." >&2
  usage >&2
  exit 1
fi

PROFILE_PATH="$ROOT_DIR/$PROFILE"
if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "Profile file not found: $PROFILE" >&2
  exit 1
fi

read_profile_args() {
  local file="$1"
  local -n out_arr=$2
  while IFS='=' read -r key value; do
    key="${key%%[[:space:]]*}"
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^# ]] && continue
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    out_arr+=("-P${key}=${value}")
  done < "$file"
}

declare -a PROFILE_GRADLE_ARGS
read_profile_args "$PROFILE_PATH" PROFILE_GRADLE_ARGS

declare -a PROFILE_SYS_PROPS
for gradle_arg in "${PROFILE_GRADLE_ARGS[@]}"; do
  PROFILE_SYS_PROPS+=("-D${gradle_arg#-P}")
done


resolve_effective_mc_version() {
  local version=""
  if [[ -f "$ROOT_DIR/gradle.properties" ]]; then
    version="$(sed -n 's/^mc_version[[:space:]]*=[[:space:]]*//p' "$ROOT_DIR/gradle.properties" | head -n1 | tr -d '\r')"
  fi

  while IFS='=' read -r key value; do
    key="${key%%[[:space:]]*}"
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^# ]] && continue
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    if [[ "$key" == "mc_version" ]]; then
      version="$value"
    fi
  done < "$PROFILE_PATH"

  echo "$version"
}

ensure_port_1201_target() {
  local mc_version
  mc_version="$(resolve_effective_mc_version)"
  if [[ "$mc_version" != "1.20.1" ]]; then
    echo "[run-local-checks] ERROR: requested --port-1201-* mode but effective mc_version is '${mc_version:-unset}'." >&2
    echo "[run-local-checks] This build currently targets a different Minecraft version and will produce a non-1.20.1 jar." >&2
    echo "[run-local-checks] Fix the Gradle/mappings toolchain to 1.20.1 before using port-1201 checks for runtime testing." >&2
    exit 1
  fi
}

ensure_port_1201_target

sanitize_proxy_env_for_gradle() {
  local proxy_blob="${GRADLE_OPTS:-} ${HTTP_PROXY:-} ${HTTPS_PROXY:-} ${http_proxy:-} ${https_proxy:-}"
  if [[ "$proxy_blob" == *"proxy:8080"* ]]; then
    echo "[run-local-checks] detected placeholder proxy env (proxy:8080); unsetting proxy variables for Gradle"
    unset GRADLE_OPTS HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
  fi
}

sanitize_proxy_env_for_gradle

select_compatible_java() {
  local current_major
  current_major="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')"
  if [[ -z "$current_major" ]]; then
    return
  fi

  if (( current_major <= 17 )); then
    return
  fi

  local fallback_java_home="${HOME}/.local/share/mise/installs/java/17.0.2"
  if [[ -x "$fallback_java_home/bin/java" ]]; then
    export JAVA_HOME="$fallback_java_home"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "[run-local-checks] selected JAVA_HOME=$JAVA_HOME for Gradle compatibility"
  fi
}

select_compatible_java

clear_forge_gradle_caches() {
  python - <<'PYTHON'
import os
import shutil

paths = [
    os.path.expanduser('~/.gradle/caches/forge_gradle'),
    os.path.expanduser('~/.gradle/caches/modules-2/files-2.1/net.minecraftforge/installertools'),
    os.path.expanduser('~/.gradle/caches/modules-2/files-2.1/net/minecraftforge/installertools'),
    'build/fg_cache',
    'build/createMcpToSrg',
    'build/extractSrg',
]
for path in paths:
    if os.path.exists(path):
        shutil.rmtree(path)
        print(f"[run-local-checks] removed cache path: {path}")
PYTHON
}

run_gradle_with_retry() {
  local log_file
  local start_ts
  local attempt_timeout
  local heartbeat_pid
  local gradle_status
  local first_status
  log_file="$(mktemp)"
  start_ts="$(date +%s)"

  heartbeat() {
    local phase="$1"
    while true; do
      sleep 30
      echo "[run-local-checks] still running (${phase}) ... $(date -u +"%H:%M:%S UTC")"
    done
  }

  run_with_heartbeat() {
    local phase="$1"
    shift
    heartbeat "$phase" &
    heartbeat_pid=$!
    timeout "$attempt_timeout"s "$@"
    gradle_status=$?
    kill "$heartbeat_pid" >/dev/null 2>&1 || true
    wait "$heartbeat_pid" 2>/dev/null || true
    return $gradle_status
  }

  attempt_timeout="$TIMEOUT_SECONDS"

  set +e
  run_with_heartbeat "attempt-1" ./gradlew --no-daemon "${PROFILE_GRADLE_ARGS[@]}" "${PROFILE_SYS_PROPS[@]}" "${TASKS[@]}" > >(tee "$log_file") 2>&1
  first_status=$?
  set -e
  if [[ "$first_status" -eq 0 ]]; then
    rm -f "$log_file"
    return 0
  fi

  if [[ "$first_status" -eq 124 ]]; then
    echo "[run-local-checks] ${MODE} timed out before completion (often during ForgeGradle bootstrap/listLibraries); failing fast instead of retrying" >&2
    rm -f "$log_file"
    return 124
  fi

  if grep -Eq "Execution failed for task ':compileJava'|Compilation failed; see the compiler error output for details" "$log_file"; then
    echo "[run-local-checks] compile failure detected; skipping cache-clean retry to avoid duplicate long runs"
    rm -f "$log_file"
    return 1
  fi

  if [[ "$MODE" == "smoke" ]]; then
    if grep -Fq "Running 'listLibraries'" "$log_file"; then
      echo "[run-local-checks] smoke gate reached ForgeGradle listLibraries bootstrap; skipping retry for faster feedback"
    else
      echo "[run-local-checks] smoke gate failed before compile stage; skipping retry for faster feedback"
    fi
    rm -f "$log_file"
    return 1
  fi

  if grep -Eq "Unexpected end of ZLIB input stream|Could not find or load main class net\.minecraftforge\.installertools\.ConsoleTool|Could not find or load main class net\.minecraftforge\.installertools\.ConsoleTool" "$log_file"; then
    echo "[run-local-checks] detected corrupted ForgeGradle cache artifacts; clearing cache and retrying once"
  else
    echo "[run-local-checks] non-compile failure detected; retrying once with cache clean and refreshed dependencies"
  fi

  clear_forge_gradle_caches
  attempt_timeout=$(( TIMEOUT_SECONDS - ($(date +%s) - start_ts) ))
  if (( attempt_timeout <= 0 )); then
    echo "[run-local-checks] timeout budget exhausted before retry; aborting" >&2
    rm -f "$log_file"
    return 1
  fi

  if run_with_heartbeat "attempt-2" ./gradlew --refresh-dependencies --no-daemon "${PROFILE_GRADLE_ARGS[@]}" "${PROFILE_SYS_PROPS[@]}" "${TASKS[@]}"; then
    rm -f "$log_file"
    return 0
  fi

  rm -f "$log_file"
  return 1
}

if [[ "$MODE" == "smoke" ]]; then
  TASKS=(compileJava)
  TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-240}"
elif [[ "$MODE" == "diagnostic" ]]; then
  TASKS=(compileJava --stacktrace)
  TIMEOUT_SECONDS="${PORT_COMPILE_DIAG_TIMEOUT_SECONDS:-240}"
else
  TASKS=(jar)
  TIMEOUT_SECONDS="${PORT_BUILD_JAR_TIMEOUT_SECONDS:-1200}"
fi

echo "[run-local-checks] script=$SCRIPT_VERSION mode=$MODE profile=$PROFILE timeout=${TIMEOUT_SECONDS}s"
set -x
run_gradle_with_retry

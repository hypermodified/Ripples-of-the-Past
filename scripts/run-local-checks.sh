#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  log_file="$(mktemp)"

  if timeout "${TIMEOUT_SECONDS}"s ./gradlew --no-daemon "${PROFILE_GRADLE_ARGS[@]}" "${PROFILE_SYS_PROPS[@]}" "${TASKS[@]}" 2>&1 | tee "$log_file"; then
    rm -f "$log_file"
    return 0
  fi

  if grep -Eq "Unexpected end of ZLIB input stream|Could not find or load main class net\.minecraftforge\.installertools\.ConsoleTool" "$log_file"; then
    echo "[run-local-checks] detected corrupted ForgeGradle cache artifacts; clearing cache and retrying once"
    clear_forge_gradle_caches
    if timeout "${TIMEOUT_SECONDS}"s ./gradlew --no-daemon "${PROFILE_GRADLE_ARGS[@]}" "${PROFILE_SYS_PROPS[@]}" "${TASKS[@]}"; then
      rm -f "$log_file"
      return 0
    fi
  fi

  rm -f "$log_file"
  return 1
}

if [[ "$MODE" == "smoke" ]]; then
  TASKS=(compileJava)
  TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-120}"
elif [[ "$MODE" == "diagnostic" ]]; then
  TASKS=(compileJava --stacktrace)
  TIMEOUT_SECONDS="${PORT_COMPILE_DIAG_TIMEOUT_SECONDS:-240}"
else
  TASKS=(jar)
  TIMEOUT_SECONDS="${PORT_BUILD_JAR_TIMEOUT_SECONDS:-1200}"
fi

echo "[run-local-checks] mode=$MODE profile=$PROFILE timeout=${TIMEOUT_SECONDS}s"
set -x
run_gradle_with_retry

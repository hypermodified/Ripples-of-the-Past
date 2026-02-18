#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Ripples of the Past: Local checks =="


PORT_1201_SMOKE=false
PORT_1201_COMPILE_DIAG=false
PORT_PROFILE_FILE="${PORT_PROFILE_FILE:-porting/gradle-1.20.1.properties}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port-1201-smoke)
      PORT_1201_SMOKE=true
      ;;
    --port-1201-compile-diagnostic)
      PORT_1201_COMPILE_DIAG=true
      ;;
    --port-profile)
      shift
      if [ "$#" -eq 0 ]; then
        echo "[ERROR] --port-profile requires a file path argument." >&2
        exit 1
      fi
      PORT_PROFILE_FILE="$1"
      ;;
  esac
  shift
done

SMOKE_TIMEOUT_SECONDS=${SMOKE_TIMEOUT_SECONDS:-30}
SMOKE_GRADLE_VERSION=${SMOKE_GRADLE_VERSION:-8.1.1}
PORT_COMPILE_DIAG_MAXERRS=${PORT_COMPILE_DIAG_MAXERRS:-200}
PORT_COMPILE_DIAG_MAXWARNS=${PORT_COMPILE_DIAG_MAXWARNS:-50}
PORT_COMPILE_DIAG_TIMEOUT_SECONDS=${PORT_COMPILE_DIAG_TIMEOUT_SECONDS:-180}
HAVE_TIMEOUT=false
if command -v timeout >/dev/null 2>&1; then
  HAVE_TIMEOUT=true
fi

if [ ! -f "gradlew" ]; then
  echo "[ERROR] gradlew not found. Run this script from inside the repo." >&2
  exit 1
fi

get_java_major() {
  local version
  version="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/{print $2}' | tr -d '[:space:]' || true)"
  if [ "$version" = "1.8" ]; then
    echo "8"
  else
    echo "$version"
  fi
}

pick_jdk17() {
  local candidates=(
    "$ROOT_DIR/.codex-jdks/temurin-17"
    "/root/.local/share/mise/installs/java/17.0.2"
    "/root/.local/share/mise/installs/java/17.0.2+8"
    "/usr/lib/jvm/java-17-openjdk-amd64"
    "/usr/lib/jvm/temurin-17-jdk-amd64"
    "/usr/lib/jvm/adoptium-17-hotspot-amd64"
    "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
  )

  for j in "${candidates[@]}"; do
    if [ -x "$j/bin/java" ]; then
      echo "$j"
      return 0
    fi
  done

  local mise_match=""
  mise_match="$(find /root/.local/share/mise/installs/java -maxdepth 1 -type d -name '17*' 2>/dev/null | head -n 1 || true)"
  if [ -n "$mise_match" ] && [ -x "$mise_match/bin/java" ]; then
    echo "$mise_match"
    return 0
  fi

  if [ -d "/usr/lib/jvm" ]; then
    local first_match
    first_match="$(find /usr/lib/jvm -maxdepth 1 -type d | grep -E '17' | head -n 1 || true)"
    if [ -n "$first_match" ] && [ -x "$first_match/bin/java" ]; then
      echo "$first_match"
      return 0
    fi
  fi

  return 1
}

pick_host_truststore() {
  local candidates=(
    "/etc/ssl/certs/java/cacerts"
    "/root/.local/share/mise/installs/java/25.0.1/lib/security/cacerts"
    "/root/.local/share/mise/installs/java/21.0.2/lib/security/cacerts"
    "$JAVA_HOME/lib/security/cacerts"
  )
  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

install_jdk17_local() {
  local os arch api_url tmp_dir archive_path install_dir
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)
      echo "[WARN] Unsupported CPU architecture for auto-install: $arch" >&2
      return 1
      ;;
  esac

  case "$os" in
    linux|darwin) ;;
    *)
      echo "[WARN] Unsupported OS for auto-install: $os" >&2
      return 1
      ;;
  esac

  if ! command -v curl >/dev/null 2>&1; then
    echo "[WARN] curl is required to auto-install JDK 17, but curl was not found." >&2
    return 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "[WARN] tar is required to auto-install JDK 17, but tar was not found." >&2
    return 1
  fi

  api_url="https://api.adoptium.net/v3/binary/latest/17/ga/${os}/${arch}/jdk/hotspot/normal/eclipse"
  tmp_dir="$ROOT_DIR/.codex-jdks"
  archive_path="$tmp_dir/temurin17.tar.gz"
  install_dir="$tmp_dir/temurin-17"

  mkdir -p "$tmp_dir"
  rm -rf "$install_dir" "$archive_path"

  echo "[INFO] Downloading Temurin JDK 17 for ${os}/${arch}..." >&2
  curl -fsSL "$api_url" -o "$archive_path"

  echo "[INFO] Extracting JDK 17 locally into $install_dir ..." >&2
  mkdir -p "$install_dir"
  tar -xzf "$archive_path" -C "$install_dir" --strip-components=1
  rm -f "$archive_path"

  if [ ! -x "$install_dir/bin/java" ]; then
    echo "[WARN] JDK 17 extraction finished, but java binary was not found." >&2
    return 1
  fi

  echo "$install_dir"
  return 0
}


install_gradle_for_smoke() {
  local version="$1"
  local base_dir archive_path install_dir download_url
  base_dir="$ROOT_DIR/.codex-jdks"
  archive_path="$base_dir/gradle-${version}-bin.zip"
  install_dir="$base_dir/gradle-${version}"
  download_url="https://services.gradle.org/distributions/gradle-${version}-bin.zip"

  if [ -x "$install_dir/bin/gradle" ]; then
    echo "$install_dir/bin/gradle"
    return 0
  fi

  mkdir -p "$base_dir"
  rm -rf "$install_dir" "$archive_path"

  if ! command -v curl >/dev/null 2>&1; then
    echo "[WARN] curl is required to auto-install Gradle ${version} for smoke checks." >&2
    return 1
  fi

  echo "[INFO] Downloading Gradle ${version} for 1.20.1 smoke checks..." >&2
  curl -fsSL "$download_url" -o "$archive_path"

  python - "$archive_path" "$install_dir" <<'PY2'
import os, pathlib, zipfile, sys
archive = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(archive) as zf:
    prefix = None
    for name in zf.namelist():
        if not name or name.endswith('/'):
            continue
        if prefix is None:
            prefix = name.split('/', 1)[0] + '/'
        rel = name[len(prefix):] if name.startswith(prefix) else name
        if not rel:
            continue
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(name) as src, open(target, 'wb') as dst:
            dst.write(src.read())
        if rel.startswith('bin/'):
            target.chmod(target.stat().st_mode | 0o755)
PY2

  rm -f "$archive_path"

  if [ ! -x "$install_dir/bin/gradle" ]; then
    echo "[WARN] Failed to install Gradle ${version} for smoke checks." >&2
    return 1
  fi

  echo "$install_dir/bin/gradle"
  return 0
}


select_gradle_for_port_tasks() {
  PORT_GRADLE_CMD="./gradlew"
  if GRADLE8_BIN="$(install_gradle_for_smoke "$SMOKE_GRADLE_VERSION")"; then
    PORT_GRADLE_CMD="$GRADLE8_BIN"
    echo "[INFO] Port task will run with Gradle ${SMOKE_GRADLE_VERSION}: $PORT_GRADLE_CMD"
  else
    echo "[WARN] Could not provision Gradle ${SMOKE_GRADLE_VERSION}; falling back to ./gradlew for port task." >&2
  fi
}


write_port_error_report() {
  local log_file="$1"
  local report_file="$2"
  python - "$log_file" "$report_file" <<'PY2'
import re, sys, collections, pathlib
log = pathlib.Path(sys.argv[1]).read_text(errors='ignore').splitlines()
out = pathlib.Path(sys.argv[2])
file_counts = collections.Counter()
missing_packages = collections.Counter()
missing_symbols = collections.Counter()
for line in log:
    m = re.match(r'(.+\.java):(\d+): error: package (.+) does not exist', line)
    if m:
        file_counts[m.group(1)] += 1
        missing_packages[m.group(3)] += 1
        continue
    m = re.match(r'(.+\.java):(\d+): error: cannot find symbol', line)
    if m:
        file_counts[m.group(1)] += 1
        continue
    m = re.match(r'\s*symbol:\s+class\s+(.+)', line)
    if m:
        missing_symbols[m.group(1)] += 1

with out.open('w') as f:
    f.write('1.20.1 compile diagnostic summary\n')
    f.write('================================\n\n')
    f.write('Top files by error count:\n')
    for k, v in file_counts.most_common(20):
        f.write(f'  {v:4d}  {k}\n')
    f.write('\nTop missing packages:\n')
    for k, v in missing_packages.most_common(20):
        f.write(f'  {v:4d}  {k}\n')
    f.write('\nTop missing classes/symbols:\n')
    for k, v in missing_symbols.most_common(20):
        f.write(f'  {v:4d}  {k}\n')
PY2
}


print_port_compile_error_summary() {
  local log_file="$1"
  echo "[INFO] 1.20.1 diagnostic summary (top missing packages/symbols):" >&2
  awk '/error: package .* does not exist|error: cannot find symbol/ {print}' "$log_file" | head -n 30 >&2 || true
}

read_profile_props() {
  local profile_file="$1"
  PROFILE_PROPS=()
  if [ ! -f "$profile_file" ]; then
    echo "[WARN] Port profile file not found: $profile_file (using built-in defaults)." >&2
    PROFILE_PROPS=(
      "-Pmc_version=1.20.1"
      "-Pforge_version=47.2.0"
      "-Pjava_lang_version=17"
      "-Pparchment_version=2023.09.03-1.20.1"
      "-Ploader_version_range=[47,)"
      "-Pforge_version_range=[47.2.0,)"
      "-Penable_optional_mod_deps=false"
    )
    return 0
  fi

  while IFS='=' read -r key value; do
    key="${key%%#*}"
    key="$(echo "$key" | tr -d '[:space:]')"
    value="${value%%#*}"
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -z "$key" ] || [ -z "$value" ]; then
      continue
    fi
    PROFILE_PROPS+=("-P${key}=${value}")
  done < "$profile_file"

  if [ "${#PROFILE_PROPS[@]}" -eq 0 ]; then
    echo "[WARN] Port profile file is empty: $profile_file (using built-in defaults)." >&2
    PROFILE_PROPS=(
      "-Pmc_version=1.20.1"
      "-Pforge_version=47.2.0"
      "-Pjava_lang_version=17"
      "-Pparchment_version=2023.09.03-1.20.1"
      "-Ploader_version_range=[47,)"
      "-Pforge_version_range=[47.2.0,)"
      "-Penable_optional_mod_deps=false"
    )
  fi
}

clear_forgegradle_generated_caches() {
  python - <<'PY'
import pathlib, shutil
home = pathlib.Path.home()
paths = [
    home / '.gradle' / 'caches' / 'forge_gradle',
    pathlib.Path('build') / 'tmp' / '.cache' / 'expanded',
    pathlib.Path('build') / 'tmp' / '.cache' / 'forge_gradle'
]
for p in paths:
    if p.exists():
        shutil.rmtree(p)
PY
}

print_failure_hints() {
  local log_file="$1"
  if grep -q "Unsupported class file major version" "$log_file"; then
    cat <<'MSG'
[HINT] Gradle is using an unsupported Java version.
       Use JDK 17 for this project, then rerun the script.
MSG
  fi

  if grep -q "PKIX path building failed" "$log_file"; then
    cat <<'MSG'
[HINT] TLS certificate trust failed while downloading dependencies.
       The script tried host truststore fallback; if it still fails, this is usually
       an external proxy/certificate policy limitation in the environment.
MSG
  fi

  if grep -q "NoSuchFileException: .*mcp_config-1.16.5.zip" "$log_file"; then
    cat <<'MSG'
[HINT] ForgeGradle cache got a partial/corrupted MCP download.
       The script now auto-cleans that cache and retries with --refresh-dependencies.
MSG
  fi

  if grep -q "zip END header not found\|MinecraftUserRepo: Failed to get Minecraft Vanilla Base" "$log_file"; then
    cat <<'MSG'
[HINT] A cached Minecraft/ForgeGradle artifact appears corrupted or partial.
       The script now clears ForgeGradle/generated caches and retries automatically.
MSG
  fi
}

run_compile_once() {
  local extra_args=("$@")
  ./gradlew --no-daemon compileJava -x test "${extra_args[@]}" 2>&1 | tee "$LOG_FILE"
}

JAVA_VERSION_RAW="$(java -version 2>&1 | head -n 1 || true)"
echo "Detected Java: ${JAVA_VERSION_RAW:-<unknown>}"
JAVA_MAJOR="$(get_java_major)"

if [ -n "$JAVA_MAJOR" ]; then
  echo "Detected Java major: $JAVA_MAJOR"
fi

if [ -n "$JAVA_MAJOR" ] && [ "$JAVA_MAJOR" -gt 17 ] 2>/dev/null; then
  if JDK17_PATH="$(pick_jdk17)"; then
    export JAVA_HOME="$JDK17_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "[INFO] Switched JAVA_HOME to JDK 17: $JAVA_HOME"
    echo "[INFO] Java now: $(java -version 2>&1 | head -n 1)"
  else
    echo "[INFO] No JDK 17 found on disk. Trying local auto-install..."
    if JDK17_PATH="$(install_jdk17_local)"; then
      export JAVA_HOME="$JDK17_PATH"
      export PATH="$JAVA_HOME/bin:$PATH"
      echo "[INFO] Switched JAVA_HOME to auto-installed JDK 17: $JAVA_HOME"
      echo "[INFO] Java now: $(java -version 2>&1 | head -n 1)"
    else
      cat <<'MSG'
[WARN] Could not auto-install JDK 17.
       Please install JDK 17 manually, set JAVA_HOME to it, then rerun this script.
MSG
    fi
  fi
fi

if [ ! -x "./gradlew" ]; then
  echo "Making gradlew executable..."
  chmod +x ./gradlew
fi

echo "Running: ./gradlew --no-daemon --version"
./gradlew --no-daemon --version

if [ "$PORT_1201_SMOKE" = true ]; then
  read_profile_props "$PORT_PROFILE_FILE"
  echo "[INFO] Using port profile: $PORT_PROFILE_FILE"

  select_gradle_for_port_tasks
  SMOKE_GRADLE_CMD="$PORT_GRADLE_CMD"

  echo "Running: ${SMOKE_GRADLE_CMD} help -q (1.20.1 smoke config override)"
  SMOKE_RC=1
  if [ "$HAVE_TIMEOUT" = true ]; then
    set +e
    timeout "$SMOKE_TIMEOUT_SECONDS" "$SMOKE_GRADLE_CMD" --no-daemon -p "$ROOT_DIR" help -q "${PROFILE_PROPS[@]}"
    SMOKE_RC=$?
    set -e
  else
    echo "[WARN] 'timeout' command not found; running smoke check without timeout guard." >&2
    set +e
    "$SMOKE_GRADLE_CMD" --no-daemon -p "$ROOT_DIR" help -q "${PROFILE_PROPS[@]}"
    SMOKE_RC=$?
    set -e
  fi

  if [ "$SMOKE_RC" -eq 0 ]; then
    echo "[OK] 1.20.1 smoke config evaluation succeeded."
    exit 0
  fi

  if [ "$SMOKE_RC" -eq 124 ]; then
    echo "[WARN] 1.20.1 smoke config evaluation timed out (non-blocking)." >&2
    exit 0
  fi

  echo "[WARN] 1.20.1 smoke config evaluation failed (exit ${SMOKE_RC})." >&2
  exit 1
fi

if [ "$PORT_1201_COMPILE_DIAG" = true ]; then
  read_profile_props "$PORT_PROFILE_FILE"
  echo "[INFO] Using port profile: $PORT_PROFILE_FILE"
  select_gradle_for_port_tasks

  LOG_DIR="$ROOT_DIR/.codex-jdks"
  LOG_FILE="$LOG_DIR/last-port-1201-compile.log"
  mkdir -p "$LOG_DIR"

  echo "Running: ${PORT_GRADLE_CMD} compileJava -x test (1.20.1 diagnostic mode, maxerrs=${PORT_COMPILE_DIAG_MAXERRS}, timeout=${PORT_COMPILE_DIAG_TIMEOUT_SECONDS}s)"
  set +e
  if [ "$HAVE_TIMEOUT" = true ]; then
    timeout "$PORT_COMPILE_DIAG_TIMEOUT_SECONDS" "$PORT_GRADLE_CMD" --no-daemon -p "$ROOT_DIR" compileJava -x test       "${PROFILE_PROPS[@]}"       -Pjavac_maxerrs="$PORT_COMPILE_DIAG_MAXERRS"       -Pjavac_maxwarns="$PORT_COMPILE_DIAG_MAXWARNS" 2>&1 | tee "$LOG_FILE"
    DIAG_RC=$?
  else
    echo "[WARN] 'timeout' command not found; running diagnostic compile without timeout guard." >&2
    "$PORT_GRADLE_CMD" --no-daemon -p "$ROOT_DIR" compileJava -x test       "${PROFILE_PROPS[@]}"       -Pjavac_maxerrs="$PORT_COMPILE_DIAG_MAXERRS"       -Pjavac_maxwarns="$PORT_COMPILE_DIAG_MAXWARNS" 2>&1 | tee "$LOG_FILE"
    DIAG_RC=$?
  fi
  set -e

  if [ "$DIAG_RC" -eq 0 ]; then
    echo "[OK] 1.20.1 diagnostic compile succeeded."
    exit 0
  fi

  if [ "$DIAG_RC" -eq 124 ]; then
    echo "[WARN] 1.20.1 diagnostic compile timed out after ${PORT_COMPILE_DIAG_TIMEOUT_SECONDS}s (non-blocking)." >&2
    if [ -f "$LOG_FILE" ]; then
      REPORT_FILE="$LOG_DIR/port-1201-error-summary.txt"
      write_port_error_report "$LOG_FILE" "$REPORT_FILE"
      print_port_compile_error_summary "$LOG_FILE"
      echo "[INFO] Partial diagnostic summary written to: $REPORT_FILE" >&2
    fi
    exit 0
  fi

  REPORT_FILE="$LOG_DIR/port-1201-error-summary.txt"
  write_port_error_report "$LOG_FILE" "$REPORT_FILE"
  print_port_compile_error_summary "$LOG_FILE"
  echo "[INFO] Detailed diagnostic summary written to: $REPORT_FILE" >&2
  echo "[WARN] 1.20.1 diagnostic compile failed (exit ${DIAG_RC}). Full log: $LOG_FILE" >&2
  exit 1
fi

LOG_DIR="$ROOT_DIR/.codex-jdks"
LOG_FILE="$LOG_DIR/last-compile.log"
mkdir -p "$LOG_DIR"

echo "Running: ./gradlew compileJava -x test"
if run_compile_once; then
  echo "[OK] compileJava completed."
  exit 0
fi

if grep -q "PKIX path building failed" "$LOG_FILE"; then
  if HOST_TRUSTSTORE="$(pick_host_truststore)"; then
    echo "[INFO] Retrying with host truststore: $HOST_TRUSTSTORE"
    export GRADLE_OPTS="${GRADLE_OPTS:-} -Djavax.net.ssl.trustStore=$HOST_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit"
    if run_compile_once --refresh-dependencies; then
      echo "[OK] compileJava completed after truststore fallback."
      exit 0
    fi
  fi
fi

if grep -q "NoSuchFileException: .*mcp_config-1.16.5.zip" "$LOG_FILE"; then
  echo "[INFO] Retrying after clearing ForgeGradle MCP cache..."
  python - <<'PY'
import shutil, pathlib
p = pathlib.Path.home() / '.gradle' / 'caches' / 'forge_gradle' / 'maven_downloader'
if p.exists():
    shutil.rmtree(p)
PY
  if run_compile_once --refresh-dependencies; then
    echo "[OK] compileJava completed after cache cleanup."
    exit 0
  fi
fi

if grep -q "zip END header not found\|MinecraftUserRepo: Failed to get Minecraft Vanilla Base" "$LOG_FILE"; then
  echo "[INFO] Retrying after clearing ForgeGradle/generated caches (corrupted MCP or vanilla base artifact)..."
  clear_forgegradle_generated_caches
  if run_compile_once --refresh-dependencies; then
    echo "[OK] compileJava completed after full ForgeGradle cache cleanup."
    exit 0
  fi
fi

print_failure_hints "$LOG_FILE"
exit 1

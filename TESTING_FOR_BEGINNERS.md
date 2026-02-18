# Testing for beginners (no coding knowledge needed)

You can run the basic health check with **one command**.

## 1) Open a terminal in the mod folder
You should be in the folder that contains `build.gradle` and `gradlew`.

## 2) Run this
```bash
bash scripts/run-local-checks.sh
```

That script will:
1. Tell you what Java version your machine is using.
2. If Java is too new, try to auto-switch to JDK 17.
3. If JDK 17 is missing, try to auto-download a local JDK 17 (no admin rights needed).
4. Fix `gradlew` permissions automatically.
5. Run compile checks.
6. If dependency downloads fail with TLS trust (`PKIX`), retry once with a host truststore fallback.
7. If ForgeGradle cache is corrupted (`mcp_config ... NoSuchFileException`), clean cache and retry once.
8. If cached Minecraft/FG artifacts are corrupted (`zip END header not found`), clear generated caches and retry once.

---

## If you still get
`Unsupported class file major version ...`

That means Gradle is still not running on Java 17.

### Fix (manual)
- Install **JDK 17**.
- Set `JAVA_HOME` to JDK 17.
- Re-open terminal and run again:

```bash
bash scripts/run-local-checks.sh
```

---

## If you get
`./gradlew: Permission denied`

Run:
```bash
chmod +x gradlew
bash scripts/run-local-checks.sh
```

---

## If you get
`PKIX path building failed`

This is a TLS/certificate trust issue while Gradle downloads dependencies.
It usually means network/proxy HTTPS interception.

### What to do
- The script already retries with host truststore.
- If it still fails in Codex web, send me the full output and I will treat it as an environment limitation.
- If this is your own machine, add your proxy/company root certificate to your JDK trust store.

---

## What to send back after running
Please copy/paste:
1. The full output of `bash scripts/run-local-checks.sh`
2. If it fails, the last ~60 lines are most important.

I can diagnose the next issue from that output directly.


---

## Optional: 1.20.1 bootstrap smoke check
If you want to test whether the build script can evaluate with 1.20.1 target values (without full compile), run:

```bash
bash scripts/run-local-checks.sh --port-1201-smoke
```

This runs a quick smoke evaluation only (no full compile), which helps catch early build-config issues for the migration profile.

For this smoke mode, the script now auto-provisions a local Gradle 8 runtime (`.codex-jdks/gradle-8.1.1`) so ForgeGradle 6 checks are not blocked by older wrapper versions.

The default timeout is 30s to avoid long stalls in web environments. If it times out, the script treats it as non-blocking and continues.


Tip: you can adjust the smoke timeout if needed:
```bash
SMOKE_TIMEOUT_SECONDS=60 bash scripts/run-local-checks.sh --port-1201-smoke
```

## Optional: 1.20.1 diagnostic compile (trimmed errors)
If you want to run a real 1.20.1 compile attempt but avoid giant 40k+ error spam, run:

```bash
bash scripts/run-local-checks.sh --port-1201-compile-diagnostic
```

This uses the 1.20.1 profile and limits javac output (`-Xmaxerrs`, `-Xmaxwarns`) so you get a shorter actionable error list plus a full log path at the end.
It also writes a grouped summary file: `.codex-jdks/port-1201-error-summary.txt` (top failing files/packages/symbols).
The diagnostic run is now timeout-guarded (default 180s) and timeout is treated as non-blocking with a partial summary.

Tip: tune limits if needed:
```bash
PORT_COMPILE_DIAG_MAXERRS=300 PORT_COMPILE_DIAG_MAXWARNS=100 PORT_COMPILE_DIAG_TIMEOUT_SECONDS=240 bash scripts/run-local-checks.sh --port-1201-compile-diagnostic
```



Tip: you can run smoke/diagnostic checks with a different port profile file:
```bash
bash scripts/run-local-checks.sh --port-1201-smoke --port-profile porting/gradle-1.20.1-jojomodconfig-slice.properties
```

# Build Test JAR Workflow (Step-by-Step)

Use this exact flow to avoid branch mixups and to force a 1.20.1-targeted build even though the branch is named 1.16.5.

## 1) Open the correct workflow
1. Open GitHub repo: `hypermodified/Ripples-of-the-Past`.
2. Go to **Actions**.
3. Click **Build Test JAR (Clean)**.

## 2) Start a fresh run on the correct branch
1. Click **Run workflow**.
2. In branch dropdown, choose **1.16.5**.
3. Click green **Run workflow**.

> Important: do not rely on **Re-run jobs** from an older failed run.

## 3) Confirm branch correctness in logs
1. Open the run.
2. In **Print dispatch context**, verify:
   - `ref_name=1.16.5`
3. Ensure **Fail fast unless running from 1.16.5 branch** is skipped or passes.

If that step fails, you launched from the wrong branch. Start a new run and select `1.16.5`.

## 4) Wait for completion and download artifact
1. Wait until run is green.
2. Download artifact: `ripples-test-jar-<sha>`.
3. Unzip artifact.

## 5) Install jar safely
1. Remove old JJBA jars from profile `mods` folder.
2. Copy only the new JJBA jar from the downloaded artifact.
3. Keep one JJBA jar at a time.

## 6) Validate artifact before launch
(Workflow uses `porting/gradle-1.20.1-ci.properties` to override target mc_version to 1.20.1.)
1. Open `build-metadata.txt` from artifact.
2. Confirm:
   - `sha=` equals run commit SHA.
   - `playeranimator_range=[0,)`.

## 7) Launch test
1. Launch Forge **1.20.1** profile.
2. If it fails, send:
   - `latest.log`
   - crash report
   - `build-metadata.txt`


## 8) If CI fails with ForgeGradle cache corruption
- Symptom examples: `Unexpected end of ZLIB input stream` or `Could not find or load main class net\.minecraftforge\.installertools\.ConsoleTool`.
- The workflow now pre-cleans known ForgeGradle cache paths and the local script retries once after cleanup.
- If you still see it, run the workflow again as a **new run** (not Re-run).

## 9) Why runs can take 20+ minutes before failing
- ForgeGradle setup for a fresh runner is heavy (MCP/mappings/deobf setup), so logs can be very long before the actual dependency error appears.
- If you see errors mentioning `mapped_parchment_...1.16.5` while targeting 1.20.1, that indicates mapping-version mismatch during dependency remap.
- The workflow now uses a dedicated 1.20.1 profile to override `mc_version`, `forge_version`, and `parchment_version` together to avoid that mismatch.

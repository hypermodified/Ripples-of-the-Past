# Build Test JAR Workflow (Step-by-Step)

Use this exact flow to avoid branch mixups and stale-run issues.

## 1) Open the correct workflow
1. Open GitHub repo: `hypermodified/Ripples-of-the-Past`.
2. Go to **Actions**.
3. Click **Build Test JAR (Clean)**.

## 2) Start a fresh run on the correct branch
1. Click **Run workflow**.
2. In branch dropdown, choose **work**.
3. Click green **Run workflow**.

> Important: do not rely on **Re-run jobs** from an older failed run.

## 3) Confirm branch correctness in logs
1. Open the run.
2. In **Print dispatch context**, verify:
   - `ref_name=work`
3. Ensure **Fail fast unless running from work branch** is skipped or passes.

If that step fails, you launched from the wrong branch. Start a new run and select `work`.

## 4) Wait for completion and download artifact
1. Wait until run is green.
2. Download artifact: `ripples-test-jar-<sha>`.
3. Unzip artifact.

## 5) Install jar safely
1. Remove old JJBA jars from profile `mods` folder.
2. Copy only the new JJBA jar from the downloaded artifact.
3. Keep one JJBA jar at a time.

## 6) Validate artifact before launch
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

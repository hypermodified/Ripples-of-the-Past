# Build Test JAR Workflow (Step-by-Step)

This is a click-by-click guide to run the updated GitHub workflow and download the correct artifact.

## 1) Open the right repository and branch context
1. Open your GitHub repo page.
2. Confirm you are in **hypermodified/Ripples-of-the-Past**.
3. (Optional but recommended) switch branch selector to **work** before starting.

## 2) Start a brand-new run (do not re-run old failed jobs)
1. Click **Actions**.
2. Click **Build Test JAR** in the left sidebar.
3. Click **Run workflow** (top-right).
4. In the branch dropdown, choose **work**.
5. Click the green **Run workflow** button.

## 3) Verify the run is actually using the right branch
1. Open the new run you just started.
2. Open the first job logs and check these lines:
   - `Print dispatch context`
   - `Workflow always checks out branch: work`
3. Open `Checkout porting branch (work)` and confirm it succeeded.

## 4) Wait for completion and download artifact
1. Wait until the run is green (success).
2. Scroll to the **Artifacts** section.
3. Download `ripples-test-jar-<commit sha>`.
4. Unzip it.

## 5) Install cleanly in Modrinth profile
1. Remove old JJBA jar(s) from your profile `mods` folder.
2. Copy the **newly downloaded** JJBA jar from the artifact into `mods`.
3. Keep only one JJBA jar at a time.

## 6) Quick sanity check before launch
1. Open `build-metadata.txt` from the artifact zip.
2. Confirm:
   - `playeranimator_range=[0,)`
   - `sha=` matches the run you downloaded.

## 7) Launch test profile
1. Start Forge **1.20.1** profile.
2. If it fails, send:
   - `latest.log`
   - crash report file
   - `build-metadata.txt` from the artifact used

## Common mistake to avoid
- Do **not** press **Re-run jobs** on an old failed run and assume it's equivalent to a fresh run.

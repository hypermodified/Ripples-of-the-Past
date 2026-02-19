# In-Game Testing Checklist (Beginner Friendly)

Use this checklist to test the current **1.20.1 stands-focused MVP** build.

## 1) Build the test JAR

From the repository root:

```bash
PORT_BUILD_JAR_TIMEOUT_SECONDS=1200 bash scripts/run-local-checks.sh --port-1201-build-jar --port-profile porting/gradle-1.20.1-packet-manager-slice.properties
```

Expected output file:

- `build/libs/JJBA-RipplesOfThePast-1.16.5-0.2.2.2-no-gecko.jar`

## 2) Install for local testing

1. Close Minecraft.
2. Copy the JAR above into your Forge 1.20.1 `mods` folder.
3. Start Minecraft with your Forge 1.20.1 profile.
4. Create a fresh test world first (to keep test noise low).

## 3) Singleplayer (SP) smoke loop

Mark each item ✅ pass or ❌ fail.

- [ ] Game loads to main menu without crash.
- [ ] World loads without immediate packet/disconnect errors.
- [ ] Summon/unsummon stand works repeatedly.
- [ ] Stand manual control toggle works.
- [ ] Basic click action works.
- [ ] Held action start/stop works.
- [ ] Dash/Leap actions trigger and recover correctly.
- [ ] Stand effects/sounds/particles appear when expected.
- [ ] No obvious freeze/desync after 5+ repeated action cycles.

## 4) Multiplayer (MP) smoke loop (LAN or dedicated)

- [ ] Both clients can join without packet disconnect.
- [ ] Player A can see Player B stand summon/unsummon.
- [ ] Player A can see Player B movement/action effects.
- [ ] Dash/leap state appears consistent to both players.
- [ ] Continuous action state is visible to other player.
- [ ] No repeated packet spam/errors in logs during 10 minutes.

## 5) Optional focused checks (if time)

- [ ] Time-stop related movement sync behaves normally.
- [ ] Cosmetic/skin updates replicate correctly.
- [ ] Soul-control actions do not crash server/client.
- [ ] Nearby Hamon-related sync values do not produce obvious UI/state errors.

## 6) What to report back

If anything fails, report:

1. Which checklist item failed.
2. SP or MP.
3. Exact action right before failure.
4. Last ~30 lines of log around the error (client and/or server).

This is enough to quickly isolate the next porting fix.


## 7) Quick troubleshooting before reporting

- [ ] If startup fails with `jojo only supports playeranimator ... 0.4.0+1.16.5`, you are using an **older jar build**. Replace it with a newly built/downloaded jar from the latest `work` branch commits.
- [ ] Keep only one `JJBA-RipplesOfThePast-*.jar` in the `mods` folder to avoid loading a stale file by accident.
- [ ] If the game still refuses to load, attach both `latest.log` and the crash report file from `crash-reports/`.

## 8) If Codex web only shows "Copy patch" / "Copy git apply"

If your Codex UI does not expose a PR creation button, this is expected on some deployments. You can still proceed by:

1. Asking Codex to keep committing fixes on branch `work`.
2. Opening GitHub in browser and creating the PR from `work` to your target base branch manually.
3. If needed, use the copied patch as fallback, but branch-based PR is preferred for full history.

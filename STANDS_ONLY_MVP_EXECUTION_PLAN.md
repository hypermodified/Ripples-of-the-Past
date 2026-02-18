# Stands-only 1.20.1 execution plan (concrete "go ahead" checklist)

This is a practical implementation order for getting a **playable stands-only branch** on Forge 1.20.1.

## Goal definition (MVP done when)
- Game boots in dev client.
- Player can obtain/assign/summon a stand.
- Stand can perform at least one offensive action and one utility action.
- Stand state sync works in multiplayer (2 clients + dedicated server smoke test).
- No worldgen/structure/dimension/non-stand systems enabled.

---

## Phase 0 — branch + guardrails
- Create branch: `port/1.20.1-stands-mvp`.
- Add temporary feature flags in config for:
  - `enableWorldgen=false`
  - `enableNonStandPowers=false`
  - `enableOptionalCompat=false`
- Keep disabled code paths explicit rather than deleting them, to ease parity restoration.

---

## Phase 1 — build/system bootstrap (must pass first)

### 1.1 Upgrade build baseline
- Move `mc_version`/`forge_version` to 1.20.1-compatible versions.
- Update ForgeGradle + mappings configuration.
- Raise toolchain from Java 8 to required modern Java.
- Keep dependency list minimal until first compile passes.

### 1.2 Make mod entrypoint minimal and bootable
Focus file: `src/main/java/com/github/standobyte/jojo/JojoMod.java`.

Temporarily disable/defer registration/setup calls not needed for stands MVP, especially:
- `ModStructures.*`
- `ModDimensions.init()`
- non-stand command args and non-stand setup loops
- optional compat initialization

Keep only stand-critical registration/setup online first.

---

## Phase 2 — registry scope reduction (compile-focused)

### 2.1 Keep these first
- Stand custom registries and stand effects/types:
  - `init/power/stand/*`
  - stand pieces of `JojoCustomRegistries`
- Stand entities/items minimally required for summon/combat loop.
- Essential sounds/particles used directly by stand actions.

### 2.2 Defer these initially
- `init/ModStructures.java`
- `world/gen/**`
- `world/dimension/**`
- non-stand init trees:
  - `init/power/non_stand/**`
  - non-stand branches in power data/logic

---

## Phase 3 — networking slice (stand-only packet channel)

Focus file: `src/main/java/com/github/standobyte/jojo/network/PacketManager.java`.

- Create a temporary registration mode that registers only stand-critical packets.
- Exclude packet handlers tied to:
  - hamon/vampirism/pillarman
  - worldgen/dimension-specific systems
  - optional integrations and cosmetic extras
- Maintain packet ID stability within the MVP branch (avoid reshuffling IDs repeatedly).

MVP networking target:
- stand summon/despawn/control
- stand action trigger + server authority resolution
- stand state sync to tracking clients

---

## Phase 4 — capability/data migration (stand path only)

Prioritize:
- `capability/entity/power/StandCap*`
- any stand-critical player/entity util capability code

Defer:
- non-stand-specific capability branches
- world and dimension capabilities not required for stand combat loop

Checkpoint:
- joining/leaving world preserves stand assignment and active state.

---

## Phase 5 — client rendering + input minimum

Prioritize stand rendering/input path first:
- stand renderer/model classes (e.g., stand renderer package)
- stand HUD/input bindings needed to control and trigger actions

Defer:
- advanced overlays/cosmetics/secondary UI panels
- non-stand UI and animation systems not required for combat loop

Checkpoint:
- stand visible, animates, and responds to key inputs in first/third person.

---

## Phase 6 — mixin/reflection triage

### 6.1 Triage mixins
From `mixins.jojo.json`, classify each mixin as:
- **Required for stand MVP**
- **Deferred**
- **Delete/replace later**

Start by disabling all non-essential mixins, then re-enable only stand-critical ones.

### 6.2 Reflection/AT minimization
- Avoid porting all reflection and access-transformer hooks at once.
- Port only hooks that block stand MVP functionality.
- Replace with public API/event-based alternatives where possible.

---

## Phase 7 — test matrix (definition of "playable")

### Singleplayer
- summon stand
- execute basic actions
- despawn/resummon
- save and reload world without stand corruption

### Multiplayer
- dedicated server startup
- 2-client sync for stand position/actions
- reconnect test preserves stand data

### Stability
- 30-minute combat smoke session
- verify no hard crashes in disabled/deferred systems

---

## Recommended implementation order (strict)
1. Build/toolchain update compiles.
2. Minimal mod bootstrap starts.
3. Stand registries/entities/items compile.
4. Stand-only packet set works.
5. Stand capabilities persist and sync.
6. Stand renderer/input works.
7. Re-enable only required mixins one-by-one.
8. Multiplayer smoke tests pass.

Do **not** touch worldgen/dimension/non-stand until step 8 is green.

---

## Risk controls
- Keep all deferred systems behind explicit feature flags.
- Land work in small commits by subsystem (bootstrap, packets, capabilities, rendering, mixins).
- Maintain a short "known disabled features" list in README/changelog for testers.

---

## Suggested first coding PR after this document
- "1.20.1 bootstrap for stands-only MVP"
  - Build files upgraded.
  - `JojoMod` reduced to minimal stand-safe init path.
  - PacketManager with temporary stand-only registration mode.
  - Deferred systems gated behind config flags.

---

## Manual tester checklist (for non-programmers)

Use this after each migration PR to quickly report whether we are still on track.

### A) Prepare config
1. Open the generated common config file for the mod.
2. Under the `Feature gates` section, set:
   - `enableWorldgen = false`
   - `enableNonStandPowers = false`
   - `enableOptionalCompat = false`

### B) Start game and world
1. Launch the mod in client.
2. Create a fresh singleplayer world.
3. Wait 30-60 seconds after spawn.

### C) What to confirm in logs
Look for lines similar to:
- `RotP feature gates: worldgen=false, nonStandPowers=false, optionalCompat=false`
- `RotP preInit feature gates: worldgen=false, nonStandPowers=false`

### D) What to report back
Send:
- `logs/latest.log`
- any crash report file (if present)
- a short note with:
  - Did game reach world spawn? (yes/no)
  - Did it crash? (yes/no)
  - Did you see the two feature-gate log lines? (yes/no)

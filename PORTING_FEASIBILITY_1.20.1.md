# Port feasibility analysis: 1.16.5 -> 1.20.1 (Forge)

## Short answer
Yes, this project is **portable in principle**, but it is a **large, high-risk migration** rather than a quick version bump.

That said, your idea of a **barebones "stands-first" port** is very good and is the approach I recommend.

## Direct answer to your suggestion
A **stands-only first release** (no custom structures/dimension/non-stand systems) is realistic and significantly lowers risk.

You would still need to port the core engine pieces (build, registries, networking, core entity logic, rendering, and selected mixins), but you can defer many expensive subsystems.

## Why it is possible
- The mod already uses Forge patterns that still exist conceptually in 1.20.1 (deferred registration, capabilities, packets, data-driven assets).
- Most gameplay content (items, sounds, recipes, loot tables, animations/assets) can be preserved with format/API updates.
- The project is source-available and not binary-only, so no fundamental legal/technical blocker appears in-repo.

## Main migration blockers (highest effort)

### 1) Build + mappings + Java baseline shift
- Current setup is hard-pinned to Forge 1.16.5 and Java 8.
- 1.20.1 Forge requires newer toolchains and modern mappings/API surfaces.
- This is the first mandatory gate before any code compiles.

### 2) Mixin-heavy internals patching
- The project contains a large Mixin surface that targets 1.16 internals by class/method/field shape.
- Even where classes still exist conceptually, method names/signatures and call sites have shifted significantly.
- Each mixin must be revalidated or redesigned.

### 3) Reflection + access transformer dependence on obfuscated internals
- There is extensive reflection helper logic and AT usage against private/obfuscated fields and methods.
- These internals are version-fragile and are likely to break across 1.16 -> 1.20.
- Many of these hooks may need replacement with newer public Forge/Minecraft APIs or new mixins.

### 4) Worldgen + structure registration model changes
- The structure/worldgen code uses 1.16-era registration and spacing injection patterns.
- 1.20.1 worldgen/biome modification flow is substantially different.
- This subsystem should be treated as a rewrite if/when re-enabled.

### 5) Rendering pipeline and model API churn
- Client renderer code uses 1.16 rendering types/namespaces.
- 1.20.1 rendering signatures/classes changed (PoseStack, buffer types, model part APIs, render events).
- Stand rendering and first-person custom behavior are likely one of the largest client rewrites.

## Barebones 1.20.1 MVP (recommended)

### Keep in MVP
- Stand entities and basic summoning/despawning
- Essential stand actions (minimal combat loop)
- Minimal HUD/input for stand controls
- Required packets and capability/save sync for stands
- Core stand renderer + animations (only what is needed for function)

### Defer for later phases
- All custom structures and worldgen hooks
- Custom dimension content and related features
- Non-stand power systems (hamon/vampirism/pillarman)
- Optional integrations (JEI, Vampirism, Expandability) unless trivial
- Nice-to-have visuals, advanced overlays, and secondary systems

### What this cuts technically
- Removes the need to immediately port the highest-risk worldgen path.
- Shrinks networking and registry surface area for first playable milestone.
- Lets you validate gameplay loop early before full parity.

## Minimum technical work still required even for "stands-only"
- Build migration (ForgeGradle/mappings/toolchain/Java)
- Core mod bootstrap + deferred registries
- Stand-related capability data, serialization, and network channels
- Stand entity logic and AI behavior updates where signatures changed
- Stand rendering pipeline migration and model adaptation
- Selective mixin/reflection rewrite for stand-critical hooks

## Medium-risk migration areas
- Networking packet encode/decode/context APIs (conceptually similar, but method signatures/types changed).
- TileEntity/Container naming and API migration to BlockEntity/menu APIs.
- Command argument registration and command source API differences.
- Custom registries and codec/serialization touchpoints.

## External dependency compatibility to verify early
- player-animation-lib (Forge 1.20.1 availability)
- bendy-lib (Forge 1.20.1 availability)
- JEI API version for 1.20.1 (if JEI support is kept in MVP)
- Optional integrations (Vampirism, Expandability) for later phases

If a dependency is unavailable, gate or disable that feature for MVP.

## Scope signal from repository
- Java source files: 1273
- Mixin files: 58
- Packet classes: 140

This is a large codebase; a scoped MVP is the safest path.

## Suggested phased plan
1. **Bootstrap compile target**
   - Move Gradle/Forge/mappings/toolchain to 1.20.1 baseline.
   - Get an empty mod init path running with minimal registries.

2. **Stands-only MVP**
   - Port only stand-critical systems (entities, packets, capabilities, renderer/HUD).
   - Stub or disable non-MVP systems behind config/feature flags.

3. **Stabilization**
   - Multiplayer sync testing, crash fixes, and performance pass.
   - Confirm no stand-critical mixin/reflection regressions.

4. **Reintroduce major deferred systems**
   - Worldgen/structures/dimension rewrite.
   - Non-stand powers and optional integrations.

5. **Full parity polish**
   - Quality-of-life features, visuals, edge-case mechanics, compatibility.

## Practical feasibility verdict
- **Feasible:** Yes.
- **Difficulty:** High for full parity, **medium-high for stands-only MVP**.
- **Risk:** High overall, but meaningfully reduced with scoped MVP.
- **Recommended strategy:** stands-first incremental migration with feature gating.


## Next document
- See `STANDS_ONLY_MVP_EXECUTION_PLAN.md` for a concrete implementation checklist.

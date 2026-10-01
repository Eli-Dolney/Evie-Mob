# LTW Mobs — Evie & ELi

A family-friendly companion mod for **Minecraft Java 1.21.1**, **NeoForge 21.1.235**, and **Java 21**. No extra runtime mods are required. The loader version is pinned exactly.

## Install with CurseForge

1. Create or select a Minecraft profile using **1.21.1 / NeoForge 21.1.235**.
2. Open the profile’s menu and choose **Open Folder**.
3. Remove any older `ltw_mobs-*.jar` from its `mods` folder, then put `ltw_mobs-1.1.0.jar` there. Do not unzip the JAR.
4. Launch the profile. Find **LTW Mobs** on Minecraft’s Mods screen.
5. Explore new terrain to discover habitats, or use the Creative spawn eggs to meet both companions immediately.

For multiplayer, install the same JAR and versions on every player’s profile and the server. Existing generated chunks are not retrofitted with islands. This is a local custom mod; it is not published in CurseForge’s searchable catalog.

CurseForge’s official [custom-profile guide](https://support.curseforge.com/support/solutions/articles/9000196904-creating-a-custom-profile) explains profile creation and adding local mods.

## Meet your companions

**Evie the Dragon** lives on floating cherry-and-amethyst islands above plains, meadows, cherry groves and forests. Climb her island’s waterfall, then offer **five glow berries**. Her island has a clear landing area. Her revised Blockbench model has softly patterned pink scales, painted violet eyes, purple crystals, folding wings, a segmented tail, and a fitted saddle.

**ELi, King of the Seas** lives in tropical lagoons in warm or lukewarm ocean regions. Offer **five tropical fish**. His lagoon has a deep central pool and a broad opening to the ocean. His revised Blockbench model has mottled navy hide, a pale belly, eyes with pupils, glowing cyan markings, four animated flippers, jaws, and a forked tail.

Each habitat has one companion; different family members can find their own. Treat progress belongs to the most recent player feeding an untamed companion and is saved across world reloads. Switching the feeding player restarts progress.

After taming, right-click with a **vanilla saddle**, then right-click to ride. Only the owner can ride or change behavior. Sneak + right-click with an empty hand toggles follow/stay. Treats heal injured companions. Breeding and combat attacks are not included.

## Riding controls

| Action | Default control |
|---|---|
| Move forward / backward | W / S |
| Strafe | A / D |
| Steer | Look with the mouse |
| Ascend / take off | Space |
| Descend / dive | C; rebind under Options → Controls → LTW Mobs |
| Boost | Hold your Sprint key, normally Left Control |
| Dismount | Shift |

Evie walks on land and takes off when you press Space. Descend onto the ground to land. ELi swims quickly and can move slowly when stranded. He follows owners only through water, so lead him around coastlines rather than across land.

ELi gives his mounted rider water breathing and night vision while submerged, plus **60 seconds of water breathing** after dismount. Evie gives slow falling on dismount (up to five minutes to cover very high falls). Dismount placement searches for nearby free space.

Tamed companions recover instead of permanently dying. A lethal hit dismounts the rider, puts the companion in stay mode, and starts **30 seconds of recovery while loaded**. They cannot take damage during recovery and return to full health. Interact afterward to resume following or riding. Companions falling below the world return to their saved home. Wild companions retain normal damage rules.

## Finding habitats

Craft a **compass + amethyst shard** for Evie’s locator, or a **compass + prismarine shard** for ELi’s. Use it in the Overworld. It reports the nearest matching habitat’s X/Z coordinates and saves them in its tooltip. The icon is decorative, not a rotating compass needle. A bounded search covers roughly 6,400 blocks for Evie or 5,120 for ELi; it reports when nothing is found. A found habitat may already have been visited or its companion tamed.

Creative/admin commands:

```text
/locate structure ltw_mobs:sky_island
/locate structure ltw_mobs:tropical_lagoon
/summon ltw_mobs:evie
/summon ltw_mobs:eli
```

## Configuration

After first launch, edit `config/ltw_mobs-common.toml` with the game/server stopped:

- `flightSpeed`: Evie’s cruise speed in blocks/tick; default 0.65.
- `swimSpeed`: ELi’s cruise speed in blocks/tick; default 0.8.
- `habitatChance`: fraction of candidate habitats enabled in new terrain; default 1.0. Set 0 to disable new habitats.

Sprint multiplies cruise speed by 1.6. Biome filters, spacing, and separation can also be overridden by datapacks using the included structure and structure-set JSON files. Common configuration on the server determines actual movement and generation.

## Build and test

Install a Java 21 JDK, then run `./gradlew build` (Windows: `gradlew.bat build`). The JAR is produced in `build/libs/`. The Gradle wrapper downloads build dependencies on first use.

- `./gradlew runGameTestServer`: eight automated integration tests; exits when finished.
- `./gradlew runClient`: development client.
- `./gradlew runServer`: development dedicated server with console input.
- `python3 tools/generate_resources.py`: regenerate the original v1 pixel textures, recipes, translations, and worldgen data. Standard library only. The v2 textures remain separate.
- `python3 tools/export_blockbench_geometry.py`: regenerate the native model layers and v2 textures from the editable `.bbmodel` files; requires Pillow. The generated files are already included, so installing the mod does not require Python or Blockbench.

Development runs use separate `run`, `run-server`, and `run-tests` directories. NeoForge development servers use offline authentication; keep testing local. These development folders are not part of the mod distribution.

See `VERIFICATION.md` for completed checks and remaining playtesting limitations. The supplied images are concept references, not game-ready model files; these are original block-based interpretations.

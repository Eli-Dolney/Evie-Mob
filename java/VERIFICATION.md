# Verification — LTW Mobs 1.1.0

## Blockbench model update

- Evie and ELi now render from native model layers generated from the editable `models/evie_textured_study.bbmodel` and `models/eli_textured_study.bbmodel` files. No model or animation runtime dependency was added.
- Evie has 98 model cubes and 20 bones; ELi has 88 cubes and 19 bones. Both textures and their emissive maps are bundled in the JAR.
- Compilation against Minecraft 1.21.1 / NeoForge 21.1.235 passed. The development client reached the title screen and completed resource loading with the new renderers.
- All eight existing GameTests passed with the new version, including rider ownership and dismount protection. The dedicated GameTest server loaded the mod without client class loading errors.
- Both models were inspected in Blockbench. The Java-game window was not accessible to computer control, so actual in-game appearance, saddle alignment, animations, and swimming/flying visual quality still need interactive review in CurseForge.

The following older verification notes describe the original gameplay and world-generation checks; the Blockbench model update did not change those systems.

Tested on macOS Apple Silicon using Java 21, Minecraft 1.21.1, and NeoForge 21.1.235.

## Completed

- Exact-version Gradle build produced an installable mod JAR.
- Eight Minecraft GameTests passed on the final gameplay/world-generation code:
  1. Five-treat taming, item consumption, saved trust, ownership, saddle, and stay state.
  2. Owner-only riding and protected dragon dismount; vanilla vehicle-position control disabled.
  3. Lethal-hit recovery, damage immunity, saved recovery timer, full healing after 600 ticks.
  4. Server flight ascent, input timeout, non-finite input rejection.
  5. Underwater rider breathing, night vision, and 60-second dismount breathing protection.
  6. Independent ownership for two mock players.
  7. Sky island construction, landing pad, waterfall, one companion, and saved spawn flag.
  8. Lagoon construction, depth, ocean entrance, shore, one companion, and saved spawn flag.
- The development client launched with the mod and completed texture/model resource loading without a mod-loading failure. Final membrane-shape/animation refinements compile but have not been visually inspected.
- A dedicated development server loaded the mod and reached its ready state. Subsequent runs were restricted to localhost.
- Natural structure discovery on a normal Overworld found a sky island near X -992 / Z -1264 and a lagoon near X -256 / Z 256 in the generated test world. These coordinates are specific to that test world’s seed.
- Loading the surrounding chunks generated Evie at [-983.5, 156, -1255.5] and ELi at [-247.5, 58, 264.5]. Entity queries returned one of each.
- Saved and restarted the dedicated server: queries again returned exactly one of each at the same positions, without duplicate habitat spawns.
- Source reference files were not modified.

GameTests accelerate server ticks; the recovery test verifies 600 game ticks, which is 30 seconds at normal 20 TPS. It is not a stopwatch performance benchmark.

## Not verified in interactive play

The computer-control tool could not access the standalone development Java game window. Therefore these checks remain open rather than being represented as completed:

- Visual quality against the concept references, saddle/player alignment, and every animation in daylight, darkness, and underwater.
- Human-controlled takeoff/landing, sustained swimming/diving/boosting, collision feel, and camera comfort.
- Real two-client multiplayer, reconnecting while mounted, and perceived network smoothness. Mock-player ownership tests do not replace this.
- Performance with many active companions or a large third-party modpack.
- Installation and play inside the user’s actual CurseForge profile. Only the development environment was launched.

The models are original native Minecraft cuboid models with layered pixel textures and emissive markings. They are interpretations of the reference artwork, not a conversion of the images into identical 3D assets. Locator items report saved coordinates rather than animating a compass needle. Flight follow behavior uses direct steering; complex caves and dense obstacles can require manual riding.

This is the first playable build, with the above playtesting limitations. Start in a new test world or a copy of an existing world.

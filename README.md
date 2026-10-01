# Evie & Eli — LTW Mobs

Evie the Dragon and Eli, King of the Seas, for our family Minecraft worlds.
This repository contains the original **Java mod** and the **Bedrock Add-On**.

## Download on your Windows PC

Open [the download page](https://github.com/Eli-Dolney/Evie-Mob/releases/tag/v0.2.0)
on your Windows PC, or use these direct downloads:

| Edition | Install file | Requirements |
| --- | --- | --- |
| **Bedrock — for PC, iPad, and PS5 play** | [Download Bedrock 0.2.0 Add-On](https://github.com/Eli-Dolney/Evie-Mob/releases/download/v0.2.0/ltw-mobs-bedrock-0.2.0.mcaddon) | Minecraft for Windows, version 1.21.90 or newer |
| **Java** | [Download Java 1.1.0 mod](https://github.com/Eli-Dolney/Evie-Mob/releases/download/v0.2.0/ltw_mobs-1.1.0.jar) | Minecraft Java 1.21.1, NeoForge 21.1.235, Java 21 |

For playing with an iPad, start with **Bedrock**. Java and Bedrock have separate
install files; the Java JAR does not run in Bedrock.

### Bedrock installation

1. Download the `.mcaddon` on your Windows PC and double-click it to import.
2. Create a **new Creative test world** in Minecraft for Windows.
3. Activate **LTW Mobs Bedrock — Behaviors** and **LTW Mobs Bedrock — Creatures**.
4. Keep experiments off. Follow the [PC test guide](downloads/bedrock/0.2.0/LTW-Mobs-Bedrock-0.2.0-PC-Guide.txt),
   which includes commands to place both habitats immediately.

The Bedrock test build includes the updated creatures, animations, five-item
taming, saddles, owner-only riding, follow/stay, flight, swimming/diving, habitat
spawning, craftable locators, boosting, and optional 30-second recovery.
Tamed damage immunity is the default. Locators point to discovered habitats.
Natural habitats appear in newly generated terrain.

**Test status:** 22 automated tests and pack/archive checks passed. Actual
Minecraft import, natural generation, appearance, riding, recovery, and
multiplayer still need testing. After the PC test, try PC + iPad, then an
Add-On-enabled Realm for PS5. The original 0.1.0 test build is preserved below.

### Java installation

Create a Minecraft **1.21.1 / NeoForge 21.1.235** profile. Put the downloaded
`ltw_mobs-1.1.0.jar` in that profile's `mods` folder; do not unzip the JAR.
Remove any earlier LTW Mobs JAR from the same folder. Launch that profile.
For Java multiplayer, every player and the server need the same mod and versions.
See the [original Java guide](java/README.md) for care, controls, and habitats.

## Editable source and earlier downloads

- [Java project](java/) and [original Java source ZIP](downloads/java/ltw-mobs-1.1.0-source.zip)
- [Bedrock project](bedrock/) and [Bedrock 0.2.0 source ZIP](downloads/bedrock/0.2.0/ltw-mobs-bedrock-0.2.0-source.zip)
- [Earlier Bedrock 0.1.0 files](downloads/bedrock/0.1.0/)

The supplied Java source ZIP/JAR and the two Bedrock downloads are preserved
byte-for-byte. The editable Bedrock project comes from the verified 0.2.0 source
ZIP. Local dependencies and build caches are excluded. The original Java license
and template notices are retained.

Build instructions are in each project's README. To download everything together,
use **Code → Download ZIP** on this repository. For installing the mod/Add-On,
use the individual files above rather than the repository ZIP.

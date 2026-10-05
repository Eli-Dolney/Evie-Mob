# Pastel Dream

A painterly, cel-shaded shader pack for Minecraft **1.21.1** (NeoForge 21.1.x) using **Iris**.

## Features
- Cel-shaded lighting with pastel violet shadows
- Dynamic gradient sky with vivid sunsets, stylized clouds, stars
- Depth-based ink outlines (water-aware)
- Stylized water: shallow aqua to deep blue, opacity by depth, soft ripples
- Bloom, soft tonemap, pastel color grading, distance fog
- Profiles: Default, Dreamy, Ink Comic, Performance

## Install
1. Install NeoForge 1.21.1, then Sodium and Iris for NeoForge.
2. Put `PastelDream.zip` in `.minecraft/shaderpacks/`.
3. Options > Video Settings > Shader Packs > Pastel Dream.

## Build
```
zip -r PastelDream.zip shaders
```

## Layout
- `shaders/lib/` shared code (settings, lighting, common vertex shaders)
- `gbuffers_*` geometry passes; `composite*` outlines + bloom; `final` grading

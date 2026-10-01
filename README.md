# BendCraft — a voxel Minecraft clone in Bend 2.0.5

Procedural terrain (biomes, caves, ores, trees), software raycaster with
face shading / sun / clouds / fog, survival (HP, hunger, fall damage,
mobs with day/night AI), block break/place, 9-slot hotbar, day cycle,
machine-checked proofs (`bend PROOF.bend`).

## Play (macOS / Linux)

```bash
curl -fsSL https://bend-lang.com/install.sh | sh
# macOS: xcode-select --install   (Linux: clang 14+ and libx11-dev)
bend minecraft.bend -o bendcraft
./bendcraft --threads 8
```

Default is a 1920x1080 window with a 512x512 render (GPU-upscaled x4,
chunky retro pixels). For smooth CPU play, set `MC.quality()` to `8n`
with a 256x256 window (~15fps), or `7n`/128x128 (~60fps); see the
resolution comment at the top of `minecraft.bend`. True 1:1 1080p needs
an depth-11 image plus the documented GPU `!` swap (experimental).

`game.bend` is a lighter 256x256 entry with a placeholder renderer.

## Controls

WASD move (Ctrl = sprint, Shift = sneak), arrows/JLIK look, Space jump,
E / left-click break, Q / right-click place, R attack, F fly, 1–9 hotbar,
Esc quit.

## Perf test (headless, no window)

```bash
bend bench.bend -o bench && time ./bench --threads 8
```

Reference: one full 128x128 raymarched frame in ~16ms on 8 x86 cores.

## Layout

- `minecraft.bend` — integrated game (App view/tick, raycaster, survival)
- `world.bend` / `blocks.bend` — terrain gen, chunk storage, block tables
- `render.bend` — camera, raymarcher, sky, shading
- `physics.bend` / `player.bend` — movement, collision, input, hotbar, inventory
- `mobs.bend` / `craft.bend` — mobs + AI, items + recipes + smelting
- `game.bend` / `save.bend` — alt entry with HUD/menus, persistence + RLE
- `LAWS.bend` / `PROOF.bend` — spec laws + machine-checked proofs

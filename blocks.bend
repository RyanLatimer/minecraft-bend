import Base

# Block IDs: 0 air, 1 grass, 2 dirt, 3 stone, 4 wood_log,
# 5 leaves, 6 sand, 7 water, 8 bedrock, 9 planks, 10 glass, 11 coal_ore,
# 12 sandstone, 13 gravel, 14 birch_log, 15 tall_grass, 16 rose_flower,
# 17 snow_layer, 18 ice, 19 obsidian, 20 pumpkin, 21 cactus.
# IDs 0-11 keep their original meaning; 12-21 are additive.

def Block.air() -> U32:
  0

def Block.grass() -> U32:
  1

def Block.dirt() -> U32:
  2

def Block.stone() -> U32:
  3

def Block.wood_log() -> U32:
  4

def Block.leaves() -> U32:
  5

def Block.sand() -> U32:
  6

def Block.water() -> U32:
  7

def Block.bedrock() -> U32:
  8

def Block.planks() -> U32:
  9

def Block.glass() -> U32:
  10

def Block.coal_ore() -> U32:
  11

def Block.sandstone() -> U32:
  12

def Block.gravel() -> U32:
  13

def Block.birch_log() -> U32:
  14

def Block.tall_grass() -> U32:
  15

def Block.rose_flower() -> U32:
  16

def Block.snow_layer() -> U32:
  17

def Block.ice() -> U32:
  18

def Block.obsidian() -> U32:
  19

def Block.pumpkin() -> U32:
  20

def Block.cactus() -> U32:
  21

# RGB packed 0xRRGGBB. Air is 0. Invalid IDs give magenta.
# grass 0x5DB83C=6142012, dirt 0x8A5A2B=9067051, stone 0x888888=8947848,
# wood 0x6B4A2A=7031338, leaves 0x2E8B2E=3050286, sand 0xE3D79B=14931867,
# water 0x3B6FD4=3895252, bedrock 0x333333=3355443, planks 0xB08A4F=11569743,
# glass 0xDDF2FF=14545663, coal 0x555555=5592405.

# New palette 12-21 (additive; 00..11 behavior for IDs 0-11 unchanged,
# overflow past 21 still answers magenta 16711935).
# sandstone 0xE7D8A4=15194276, gravel 0x837E73=8617587,
# birch_log 0xD8D8D0=14211280, tall_grass 0x4A9E2F=4890159,
# rose_flower 0xD42A2A=13904426, snow_layer 0xF2FBFB=15924219,
# ice 0xA8D8F0=11065584, obsidian 0x1A1026=1708070,
# pumpkin 0xE08A1E=14715422, cactus 0x2E7D32=3046706.

def Block.color21(n: Nat) -> U32:
  match n:
    case 0n:
      3046706
    case 1n+p:
      16711935

def Block.color20(n: Nat) -> U32:
  match n:
    case 0n:
      14715422
    case 1n+p:
      Block.color21(p)

def Block.color19(n: Nat) -> U32:
  match n:
    case 0n:
      1708070
    case 1n+p:
      Block.color20(p)

def Block.color18(n: Nat) -> U32:
  match n:
    case 0n:
      11065584
    case 1n+p:
      Block.color19(p)

def Block.color17(n: Nat) -> U32:
  match n:
    case 0n:
      15924219
    case 1n+p:
      Block.color18(p)

def Block.color16(n: Nat) -> U32:
  match n:
    case 0n:
      13904426
    case 1n+p:
      Block.color17(p)

def Block.color15(n: Nat) -> U32:
  match n:
    case 0n:
      4890159
    case 1n+p:
      Block.color16(p)

def Block.color14(n: Nat) -> U32:
  match n:
    case 0n:
      14211280
    case 1n+p:
      Block.color15(p)

def Block.color13(n: Nat) -> U32:
  match n:
    case 0n:
      8617587
    case 1n+p:
      Block.color14(p)

def Block.color12(n: Nat) -> U32:
  match n:
    case 0n:
      15194276
    case 1n+p:
      Block.color13(p)

def Block.color11(n: Nat) -> U32:
  match n:
    case 0n:
      5592405
    case 1n+p:
      Block.color12(p)

def Block.color10(n: Nat) -> U32:
  match n:
    case 0n:
      14545663
    case 1n+p:
      Block.color11(p)

def Block.color09(n: Nat) -> U32:
  match n:
    case 0n:
      11569743
    case 1n+p:
      Block.color10(p)

def Block.color08(n: Nat) -> U32:
  match n:
    case 0n:
      3355443
    case 1n+p:
      Block.color09(p)

def Block.color07(n: Nat) -> U32:
  match n:
    case 0n:
      3895252
    case 1n+p:
      Block.color08(p)

def Block.color06(n: Nat) -> U32:
  match n:
    case 0n:
      14931867
    case 1n+p:
      Block.color07(p)

def Block.color05(n: Nat) -> U32:
  match n:
    case 0n:
      3050286
    case 1n+p:
      Block.color06(p)

def Block.color04(n: Nat) -> U32:
  match n:
    case 0n:
      7031338
    case 1n+p:
      Block.color05(p)

def Block.color03(n: Nat) -> U32:
  match n:
    case 0n:
      8947848
    case 1n+p:
      Block.color04(p)

def Block.color02(n: Nat) -> U32:
  match n:
    case 0n:
      9067051
    case 1n+p:
      Block.color03(p)

def Block.color01(n: Nat) -> U32:
  match n:
    case 0n:
      6142012
    case 1n+p:
      Block.color02(p)

def Block.color00(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.color01(p)

def Block.color(b: U32) -> U32:
  Block.color00(U32.to_nat(b))

# Solid is false for air and water, true otherwise.
# Glass is solid but transparent.

# Solid 12-21: sandstone/gravel/birch solid, tall_grass/rose/snow non-solid,
# ice/obsidian/pumpkin/cactus solid. Overflow past 21 still False.
# Keeps 00..11 behavior for IDs 0-11.

def Block.solid21(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      False{}

def Block.solid20(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid21(p)

def Block.solid19(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid20(p)

def Block.solid18(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid19(p)

def Block.solid17(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.solid18(p)

def Block.solid16(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.solid17(p)

def Block.solid15(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.solid16(p)

def Block.solid14(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid15(p)

def Block.solid13(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid14(p)

def Block.solid12(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid13(p)

def Block.solid11(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid12(p)

def Block.solid10(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid11(p)

def Block.solid09(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid10(p)

def Block.solid08(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid09(p)

def Block.solid07(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.solid08(p)

def Block.solid06(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid07(p)

def Block.solid05(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid06(p)

def Block.solid04(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid05(p)

def Block.solid03(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid04(p)

def Block.solid02(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid03(p)

def Block.solid01(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.solid02(p)

def Block.solid00(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.solid01(p)

def Block.solid(b: U32) -> Bool:
  Block.solid00(U32.to_nat(b))

# Transparent is true for air, leaves, water and glass.

# Transparent 12-21: sandstone/gravel/birch opaque, tall_grass/rose/snow/ice
# transparent, obsidian/pumpkin/cactus opaque. Overflow past 21 still True.

def Block.transparent21(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      True{}

def Block.transparent20(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent21(p)

def Block.transparent19(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent20(p)

def Block.transparent18(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent19(p)

def Block.transparent17(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent18(p)

def Block.transparent16(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent17(p)

def Block.transparent15(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent16(p)

def Block.transparent14(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent15(p)

def Block.transparent13(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent14(p)

def Block.transparent12(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent13(p)

def Block.transparent11(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent12(p)

def Block.transparent10(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent11(p)

def Block.transparent09(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent10(p)

def Block.transparent08(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent09(p)

def Block.transparent07(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent08(p)

def Block.transparent06(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent07(p)

def Block.transparent05(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent06(p)

def Block.transparent04(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent05(p)

def Block.transparent03(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent04(p)

def Block.transparent02(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent03(p)

def Block.transparent01(n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      Block.transparent02(p)

def Block.transparent00(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Block.transparent01(p)

def Block.transparent(b: U32) -> Bool:
  Block.transparent00(U32.to_nat(b))

# Human-readable names.

# Names 12-21 additive; overflow past 21 still "unknown".

def Block.name21(n: Nat) -> String:
  match n:
    case 0n:
      "cactus"
    case 1n+p:
      "unknown"

def Block.name20(n: Nat) -> String:
  match n:
    case 0n:
      "pumpkin"
    case 1n+p:
      Block.name21(p)

def Block.name19(n: Nat) -> String:
  match n:
    case 0n:
      "obsidian"
    case 1n+p:
      Block.name20(p)

def Block.name18(n: Nat) -> String:
  match n:
    case 0n:
      "ice"
    case 1n+p:
      Block.name19(p)

def Block.name17(n: Nat) -> String:
  match n:
    case 0n:
      "snow_layer"
    case 1n+p:
      Block.name18(p)

def Block.name16(n: Nat) -> String:
  match n:
    case 0n:
      "rose_flower"
    case 1n+p:
      Block.name17(p)

def Block.name15(n: Nat) -> String:
  match n:
    case 0n:
      "tall_grass"
    case 1n+p:
      Block.name16(p)

def Block.name14(n: Nat) -> String:
  match n:
    case 0n:
      "birch_log"
    case 1n+p:
      Block.name15(p)

def Block.name13(n: Nat) -> String:
  match n:
    case 0n:
      "gravel"
    case 1n+p:
      Block.name14(p)

def Block.name12(n: Nat) -> String:
  match n:
    case 0n:
      "sandstone"
    case 1n+p:
      Block.name13(p)

def Block.name11(n: Nat) -> String:
  match n:
    case 0n:
      "coal_ore"
    case 1n+p:
      Block.name12(p)

def Block.name10(n: Nat) -> String:
  match n:
    case 0n:
      "glass"
    case 1n+p:
      Block.name11(p)

def Block.name09(n: Nat) -> String:
  match n:
    case 0n:
      "planks"
    case 1n+p:
      Block.name10(p)

def Block.name08(n: Nat) -> String:
  match n:
    case 0n:
      "bedrock"
    case 1n+p:
      Block.name09(p)

def Block.name07(n: Nat) -> String:
  match n:
    case 0n:
      "water"
    case 1n+p:
      Block.name08(p)

def Block.name06(n: Nat) -> String:
  match n:
    case 0n:
      "sand"
    case 1n+p:
      Block.name07(p)

def Block.name05(n: Nat) -> String:
  match n:
    case 0n:
      "leaves"
    case 1n+p:
      Block.name06(p)

def Block.name04(n: Nat) -> String:
  match n:
    case 0n:
      "wood_log"
    case 1n+p:
      Block.name05(p)

def Block.name03(n: Nat) -> String:
  match n:
    case 0n:
      "stone"
    case 1n+p:
      Block.name04(p)

def Block.name02(n: Nat) -> String:
  match n:
    case 0n:
      "dirt"
    case 1n+p:
      Block.name03(p)

def Block.name01(n: Nat) -> String:
  match n:
    case 0n:
      "grass"
    case 1n+p:
      Block.name02(p)

def Block.name00(n: Nat) -> String:
  match n:
    case 0n:
      "air"
    case 1n+p:
      Block.name01(p)

def Block.name(b: U32) -> String:
  Block.name00(U32.to_nat(b))

# Light emission 0-21: pumpkin 20 glows 14, all others 0, overflow 0.

def Block.light21(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      0

def Block.light20(n: Nat) -> U32:
  match n:
    case 0n:
      14
    case 1n+p:
      Block.light21(p)

def Block.light19(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light20(p)

def Block.light18(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light19(p)

def Block.light17(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light18(p)

def Block.light16(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light17(p)

def Block.light15(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light16(p)

def Block.light14(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light15(p)

def Block.light13(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light14(p)

def Block.light12(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light13(p)

def Block.light11(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light12(p)

def Block.light10(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light11(p)

def Block.light09(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light10(p)

def Block.light08(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light09(p)

def Block.light07(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light08(p)

def Block.light06(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light07(p)

def Block.light05(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light06(p)

def Block.light04(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light05(p)

def Block.light03(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light04(p)

def Block.light02(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light03(p)

def Block.light01(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light02(p)

def Block.light00(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.light01(p)

def Block.light(b: U32) -> U32:
  Block.light00(U32.to_nat(b))

# Hardness 0-21 in break ticks: air 0, grass 3, dirt 3, stone 6, wood 5,
# leaves 1, sand 3, water 0, bedrock 9999, planks 4, glass 2, coal 7,
# sandstone 5, gravel 3, birch 5, tall_grass 1, rose 1, snow 1, ice 2,
# obsidian 20, pumpkin 3, cactus 2. Overflow 0.

def Block.hard21(n: Nat) -> U32:
  match n:
    case 0n:
      2
    case 1n+p:
      0

def Block.hard20(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.hard21(p)

def Block.hard19(n: Nat) -> U32:
  match n:
    case 0n:
      20
    case 1n+p:
      Block.hard20(p)

def Block.hard18(n: Nat) -> U32:
  match n:
    case 0n:
      2
    case 1n+p:
      Block.hard19(p)

def Block.hard17(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      Block.hard18(p)

def Block.hard16(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      Block.hard17(p)

def Block.hard15(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      Block.hard16(p)

def Block.hard14(n: Nat) -> U32:
  match n:
    case 0n:
      5
    case 1n+p:
      Block.hard15(p)

def Block.hard13(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.hard14(p)

def Block.hard12(n: Nat) -> U32:
  match n:
    case 0n:
      5
    case 1n+p:
      Block.hard13(p)

def Block.hard11(n: Nat) -> U32:
  match n:
    case 0n:
      7
    case 1n+p:
      Block.hard12(p)

def Block.hard10(n: Nat) -> U32:
  match n:
    case 0n:
      2
    case 1n+p:
      Block.hard11(p)

def Block.hard09(n: Nat) -> U32:
  match n:
    case 0n:
      4
    case 1n+p:
      Block.hard10(p)

def Block.hard08(n: Nat) -> U32:
  match n:
    case 0n:
      9999
    case 1n+p:
      Block.hard09(p)

def Block.hard07(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.hard08(p)

def Block.hard06(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.hard07(p)

def Block.hard05(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      Block.hard06(p)

def Block.hard04(n: Nat) -> U32:
  match n:
    case 0n:
      5
    case 1n+p:
      Block.hard05(p)

def Block.hard03(n: Nat) -> U32:
  match n:
    case 0n:
      6
    case 1n+p:
      Block.hard04(p)

def Block.hard02(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.hard03(p)

def Block.hard01(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.hard02(p)

def Block.hard00(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.hard01(p)

def Block.hard(b: U32) -> U32:
  Block.hard00(U32.to_nat(b))

# Drops 0-21: grass->dirt 2, leaves/glass/water/bedrock/tall_grass/snow/ice->air 0,
# others drop themselves (coal_ore->11 lawful). Overflow 0.

def Block.drop21(n: Nat) -> U32:
  match n:
    case 0n:
      21
    case 1n+p:
      0

def Block.drop20(n: Nat) -> U32:
  match n:
    case 0n:
      20
    case 1n+p:
      Block.drop21(p)

def Block.drop19(n: Nat) -> U32:
  match n:
    case 0n:
      19
    case 1n+p:
      Block.drop20(p)

def Block.drop18(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop19(p)

def Block.drop17(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop18(p)

def Block.drop16(n: Nat) -> U32:
  match n:
    case 0n:
      16
    case 1n+p:
      Block.drop17(p)

def Block.drop15(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop16(p)

def Block.drop14(n: Nat) -> U32:
  match n:
    case 0n:
      14
    case 1n+p:
      Block.drop15(p)

def Block.drop13(n: Nat) -> U32:
  match n:
    case 0n:
      13
    case 1n+p:
      Block.drop14(p)

def Block.drop12(n: Nat) -> U32:
  match n:
    case 0n:
      12
    case 1n+p:
      Block.drop13(p)

def Block.drop11(n: Nat) -> U32:
  match n:
    case 0n:
      11
    case 1n+p:
      Block.drop12(p)

def Block.drop10(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop11(p)

def Block.drop09(n: Nat) -> U32:
  match n:
    case 0n:
      9
    case 1n+p:
      Block.drop10(p)

def Block.drop08(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop09(p)

def Block.drop07(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop08(p)

def Block.drop06(n: Nat) -> U32:
  match n:
    case 0n:
      6
    case 1n+p:
      Block.drop07(p)

def Block.drop05(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop06(p)

def Block.drop04(n: Nat) -> U32:
  match n:
    case 0n:
      4
    case 1n+p:
      Block.drop05(p)

def Block.drop03(n: Nat) -> U32:
  match n:
    case 0n:
      3
    case 1n+p:
      Block.drop04(p)

def Block.drop02(n: Nat) -> U32:
  match n:
    case 0n:
      2
    case 1n+p:
      Block.drop03(p)

def Block.drop01(n: Nat) -> U32:
  match n:
    case 0n:
      2
    case 1n+p:
      Block.drop02(p)

def Block.drop00(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      Block.drop01(p)

def Block.drop(b: U32) -> U32:
  Block.drop00(U32.to_nat(b))

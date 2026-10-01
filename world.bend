import Base
import ./blocks.bend as B

# Voxel world: W=64, H=32, D=64, flat size 131072 = 2^17.
# Flat index: (y * 64 + z) * 64 + x.
# Pure reads must thread the Array: World.get returns Array beside value.
# Out-of-bounds reads answer air (0); out-of-bounds writes are no-ops.

type WorldState is Type:
  World{seed: U32, data: Array<U32>}

def World.w() -> U32:
  64

def World.h() -> U32:
  32

def World.d() -> U32:
  64

def World.hash(seed: U32, x: U32, z: U32) -> U32:
  t1 = U32.mul(x, 374761393)
  t2 = U32.mul(z, 668265263)
  t3 = U32.xor(seed, t1)
  +h = U32.xor(t3, t2)
  s = U32.shrn(h, 13n)
  q = U32.xor(h, s)
  U32.mul(q, 1274126177)

def World.height_at(seed: U32, x: U32, z: U32) -> U32:
  h = World.hash(seed, x, z)
  m = U32.mod(h, 10)
  U32.add(10, m)

def World.block_at_ore(c: Bool) -> U32:
  match c:
    case False{}:
      B.Block.stone()
    case True{}:
      B.Block.coal_ore()

def World.block_at_stone(+seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  hh = World.hash(U32.add(seed, y), x, z)
  m = U32.mod(hh, 20)
  World.block_at_ore(U32.is_eq(m, 0))

def World.block_at_bed(+seed: U32, +x: U32, +y: U32, +z: U32, c: Bool) -> U32:
  match c:
    case False{}:
      World.block_at_stone(seed, x, y, z)
    case True{}:
      B.Block.bedrock()

def World.block_at_sub(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      World.block_at_bed(seed, x, y, z, U32.is_eq(y, 0))
    case True{}:
      B.Block.dirt()

def World.block_at_beach(h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      B.Block.grass()
    case True{}:
      B.Block.sand()

def World.block_at_surface(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      World.block_at_sub(seed, x, y, z, h, U32.is_gt(y, U32.sub(h, 3)))
    case True{}:
      World.block_at_beach(h, U32.is_le(h, 12))

def World.block_at_water(y: U32, c: Bool) -> U32:
  match c:
    case False{}:
      B.Block.air()
    case True{}:
      B.Block.water()

def World.block_at_above(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      World.block_at_surface(seed, x, y, z, h, U32.is_eq(y, h))
    case True{}:
      World.block_at_water(y, U32.is_le(y, 11))

def World.block_at(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32) -> U32:
  World.block_at_above(seed, x, y, z, h, U32.is_gt(y, h))

def World.idx(x: U32, y: U32, z: U32) -> U32:
  t1 = U32.mul(y, 64)
  t2 = U32.add(t1, z)
  t3 = U32.mul(t2, 64)
  U32.add(t3, x)

def World.get(w: Array<U32>, idx: U32) -> Array<U32> & U32:
  w[idx]

def World.set(w: Array<U32>, idx: U32, v: U32) -> Array<U32>:
  w[idx] <- v

def World.in_bounds(x: U32, y: U32, z: U32) -> Bool:
  Bool.and(U32.is_lt(x, 64), Bool.and(U32.is_lt(y, 32), U32.is_lt(z, 64)))

def World.get_xyz_oob(world: Array<U32>) -> Array<U32> & U32:
  (world, B.Block.air())

def World.get_xyz_hit(world: Array<U32>, x: U32, y: U32, z: U32) -> Array<U32> & U32:
  idx = World.idx(x, y, z)
  World.get(world, idx)

def World.get_xyz_if(world: Array<U32>, +x: U32, +y: U32, +z: U32, c: Bool) -> Array<U32> & U32:
  match c:
    case False{}:
      World.get_xyz_oob(world)
    case True{}:
      World.get_xyz_hit(world, x, y, z)

def World.get_xyz(world: Array<U32>, +x: U32, +y: U32, +z: U32) -> Array<U32> & U32:
  World.get_xyz_if(world, x, y, z, World.in_bounds(x, y, z))

def World.set_xyz_hit(world: Array<U32>, x: U32, y: U32, z: U32, v: U32) -> Array<U32>:
  idx = World.idx(x, y, z)
  World.set(world, idx, v)

def World.set_xyz_if(world: Array<U32>, +x: U32, +y: U32, +z: U32, v: U32, c: Bool) -> Array<U32>:
  match c:
    case False{}:
      world
    case True{}:
      World.set_xyz_hit(world, x, y, z, v)

def World.set_xyz(world: Array<U32>, +x: U32, +y: U32, +z: U32, v: U32) -> Array<U32>:
  World.set_xyz_if(world, x, y, z, v, World.in_bounds(x, y, z))

def World.place_tree(world: Array<U32>, +x: U32, +z: U32, +h: U32) -> Array<U32>:
  +xm = U32.sub(x, 1)
  +xp = U32.add(x, 1)
  +zm = U32.sub(z, 1)
  +zp = U32.add(z, 1)
  +y3 = U32.add(h, 3)
  +y4 = U32.add(h, 4)
  +y1 = U32.add(h, 1)
  +y2 = U32.add(h, 2)
  +leaf = B.Block.leaves()
  +trunk = B.Block.wood_log()
  w01 = World.set_xyz(world, xm, y3, zm, leaf)
  w02 = World.set_xyz(w01, x, y3, zm, leaf)
  w03 = World.set_xyz(w02, xp, y3, zm, leaf)
  w04 = World.set_xyz(w03, xm, y3, z, leaf)
  w05 = World.set_xyz(w04, xp, y3, z, leaf)
  w06 = World.set_xyz(w05, xm, y3, zp, leaf)
  w07 = World.set_xyz(w06, x, y3, zp, leaf)
  w08 = World.set_xyz(w07, xp, y3, zp, leaf)
  w09 = World.set_xyz(w08, xm, y4, zm, leaf)
  w10 = World.set_xyz(w09, x, y4, zm, leaf)
  w11 = World.set_xyz(w10, xp, y4, zm, leaf)
  w12 = World.set_xyz(w11, xm, y4, z, leaf)
  w13 = World.set_xyz(w12, xp, y4, z, leaf)
  w14 = World.set_xyz(w13, xm, y4, zp, leaf)
  w15 = World.set_xyz(w14, x, y4, zp, leaf)
  w16 = World.set_xyz(w15, xp, y4, zp, leaf)
  w17 = World.set_xyz(w16, x, y4, z, leaf)
  w18 = World.set_xyz(w17, x, y1, z, trunk)
  w19 = World.set_xyz(w18, x, y2, z, trunk)
  w20 = World.set_xyz(w19, x, y3, z, trunk)
  World.set_xyz(w20, x, y4, z, trunk)

def World.gen_rec(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +idx = U32.from_nat(p)
      +t = U32.div(idx, 64)
      +x = U32.mod(idx, 64)
      +z = U32.mod(t, 64)
      +y = U32.div(t, 64)
      +hh = World.height_at(seed, x, z)
      b = World.block_at(seed, x, y, z, hh)
      w2 = World.set(world, idx, b)
      World.gen_rec(p, w2, seed)

def World.fill(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  World.gen_rec(n, world, seed)

def World.fill_range_rec(n: Nat, world: Array<U32>, +seed: U32, +lo: U32, hi: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +t = U32.div(lo, 64)
      +x = U32.mod(lo, 64)
      +z = U32.mod(t, 64)
      +y = U32.div(t, 64)
      +hh = World.height_at(seed, x, z)
      b = World.block_at(seed, x, y, z, hh)
      w2 = World.set(world, lo, b)
      World.fill_range_rec(p, w2, seed, U32.add(lo, 1), hi)

def World.fill_range(world: Array<U32>, +seed: U32, +lo: U32, +hi: U32) -> Array<U32>:
  n = U32.to_nat(U32.sub(hi, lo))
  World.fill_range_rec(n, world, seed, lo, hi)

def World.chunk_rec(+n: Nat, world: Array<U32>, +seed: U32, +base: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +lp = U32.from_nat(p)
      +g = U32.add(base, lp)
      +t = U32.div(g, 64)
      +x = U32.mod(g, 64)
      +z = U32.mod(t, 64)
      +y = U32.div(t, 64)
      +hh = World.height_at(seed, x, z)
      b = World.block_at(seed, x, y, z, hh)
      w2 = World.set(world, lp, b)
      World.chunk_rec(p, w2, seed, base)

def World.gen_chunk(+seed: U32, base: U32) -> Array<U32>:
  w0 = [0 : U32^16n]
  World.chunk_rec(U32.to_nat(65536), w0, seed, base)

def World.gen_half(+seed: U32, base: U32) -> Array<U32>:
  World.gen_chunk(seed, base)

def World.trees_if(world: Array<U32>, +x: U32, +z: U32, +h: U32, c: Bool) -> Array<U32>:
  match c:
    case False{}:
      world
    case True{}:
      World.place_tree(world, x, z, h)

def World.trees(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +g = U32.from_nat(p)
      +x = U32.mod(g, 64)
      +z = U32.div(g, 64)
      hh = World.hash(seed, x, z)
      +h = World.height_at(seed, x, z)
      m = U32.mod(hh, 100)
      c1 = U32.is_lt(m, 2)
      c2 = U32.is_gt(h, 12)
      c = Bool.and(c1, c2)
      w2 = World.trees_if(world, x, z, h, c)
      World.trees(p, w2, seed)

def World.gen(+seed: U32) -> Array<U32>:
  w0 = [0 : U32^17n]
  w1 = World.gen_rec(U32.to_nat(131072), w0, seed)
  World.trees(U32.to_nat(4096), w1, seed)

# Parallelism: full 131072 terrain splits into two 65536 chunks.
# The game can run both halves at once with a parallel let:
#   c1 c2 = World.gen_chunk(seed, 0) World.gen_chunk(seed, 65536)
# or for in-place fills on a cloned world:
#   a b = World.fill_range(w1, seed, 0, 65536) World.fill_range(w2, seed, 65536, 131072)
# Each chunk owns its Array, so the two calls are independent and balanced.

# ---- Additive full pipeline (keeps height_at/block_at/gen untouched) ----
# Biomes 0 plains, 1 desert, 2 forest, 3 tundra, 4 swamp from second hash.

def World.biome(seed: U32, x: U32, z: U32) -> U32:
  s = U32.add(seed, 7919)
  h = World.hash(s, x, z)
  U32.mod(h, 5)

def World.biome_h_fallback() -> U32:
  0

def World.biome_h4(c: Bool) -> U32:
  match c:
    case True{}:
      0
    case False{}:
      World.biome_h_fallback()

def World.biome_h3(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      3
    case False{}:
      World.biome_h4(U32.is_eq(b, 4))

def World.biome_h2(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      2
    case False{}:
      World.biome_h3(b, U32.is_eq(b, 3))

def World.biome_h1(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      0
    case False{}:
      World.biome_h2(b, U32.is_eq(b, 2))

def World.biome_h0(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      1
    case False{}:
      World.biome_h1(b, U32.is_eq(b, 1))

def World.biome_height(+b: U32) -> U32:
  World.biome_h0(b, U32.is_eq(b, 0))

def World.height_full(+seed: U32, +x: U32, +z: U32) -> U32:
  base = World.height_at(seed, x, z)
  bi = World.biome(seed, x, z)
  mod = World.biome_height(bi)
  dx = U32.mul(x, 4)
  dz = U32.mul(z, 4)
  s2 = U32.add(seed, 12345)
  dh = World.hash(s2, dx, dz)
  det = U32.mod(dh, 3)
  t = (base + mod : U32)
  (t + det : U32)

def World.cave_and(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case True{} False{}:
      False{}
    case False{} True{}:
      False{}
    case False{} False{}:
      False{}

def World.cave_at(+seed: U32, +x: U32, +y: U32, +z: U32) -> Bool:
  s1 = U32.add(seed, y)
  h1 = World.hash(s1, x, z)
  m1 = U32.mod(h1, 100)
  y2 = (y + 1000 : U32)
  s2 = U32.add(seed, y2)
  h2 = World.hash(s2, z, x)
  m2 = U32.mod(h2, 100)
  World.cave_and(U32.is_lt(m1, 10), U32.is_lt(m2, 10))

def World.full_ore_iron(c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.obsidian()
    case False{}:
      B.Block.stone()

def World.full_ore_coal(c_coal: Bool, c_iron: Bool) -> U32:
  match c_coal:
    case True{}:
      B.Block.coal_ore()
    case False{}:
      World.full_ore_iron(c_iron)

def World.full_stone(+seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  s = U32.add(seed, y)
  +hh = World.hash(s, x, z)
  m20 = U32.mod(hh, 20)
  m100 = U32.mod(hh, 100)
  c_coal = U32.is_eq(m20, 0)
  c_deep = U32.is_lt(y, 6)
  c_rare = U32.is_eq(m100, 1)
  c_iron = Bool.and(c_deep, c_rare)
  World.full_ore_coal(c_coal, c_iron)

def World.full_bed(+seed: U32, +x: U32, +y: U32, +z: U32, c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.bedrock()
    case False{}:
      World.full_stone(seed, x, y, z)

def World.full_dirt_desert(c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.sandstone()
    case False{}:
      B.Block.dirt()

def World.full_sub(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, +biome: U32, c: Bool) -> U32:
  match c:
    case True{}:
      World.full_dirt_desert(U32.is_eq(biome, 1))
    case False{}:
      World.full_bed(seed, x, y, z, U32.is_eq(y, 0))

def World.full_surf_fallback() -> U32:
  B.Block.grass()

def World.full_surf4(c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.gravel()
    case False{}:
      World.full_surf_fallback()

def World.full_surf3(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.snow_layer()
    case False{}:
      World.full_surf4(U32.is_eq(b, 4))

def World.full_surf2(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.grass()
    case False{}:
      World.full_surf3(b, U32.is_eq(b, 3))

def World.full_surf1(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.sand()
    case False{}:
      World.full_surf2(b, U32.is_eq(b, 2))

def World.full_surf0(+b: U32, c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.grass()
    case False{}:
      World.full_surf1(b, U32.is_eq(b, 1))

def World.full_surf(+b: U32) -> U32:
  World.full_surf0(b, U32.is_eq(b, 0))

def World.full_surf_gravel(c: Bool, surf_val: U32) -> U32:
  match c:
    case True{}:
      B.Block.gravel()
    case False{}:
      surf_val

def World.full_water_pick(c: Bool) -> U32:
  match c:
    case True{}:
      B.Block.water()
    case False{}:
      B.Block.air()

def World.full_surface(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, +biome: U32, c: Bool) -> U32:
  match c:
    case False{}:
      World.full_sub(seed, x, y, z, h, biome, U32.is_gt(y, U32.sub(h, 3)))
    case True{}:
      s = U32.add(seed, 777)
      hh = World.hash(s, x, z)
      m = U32.mod(hh, 25)
      base = World.full_surf(biome)
      World.full_surf_gravel(U32.is_eq(m, 0), base)

def World.full_above(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, +biome: U32, c: Bool) -> U32:
  match c:
    case True{}:
      World.full_water_pick(U32.is_le(y, 11))
    case False{}:
      World.full_surface(seed, x, y, z, h, biome, U32.is_eq(y, h))

def World.full_cave_go(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, +biome: U32, c_cave: Bool) -> U32:
  match c_cave:
    case True{}:
      B.Block.air()
    case False{}:
      World.full_above(seed, x, y, z, h, biome, U32.is_gt(y, h))

def World.full_pick(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, +biome: U32, c_bed: Bool, c_cave: Bool) -> U32:
  match c_bed:
    case True{}:
      B.Block.bedrock()
    case False{}:
      World.full_cave_go(seed, x, y, z, h, biome, c_cave)

def World.block_full(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32) -> U32:
  bi = World.biome(seed, x, z)
  cc = World.cave_at(seed, x, y, z)
  cb = U32.is_eq(y, 0)
  World.full_pick(seed, x, y, z, h, bi, cb, cc)

def World.place_big_generic(world: Array<U32>, +x: U32, +z: U32, +h: U32, +log: U32) -> Array<U32>:
  +xm2 = U32.sub(x, 2)
  +xm1 = U32.sub(x, 1)
  +xp1 = U32.add(x, 1)
  +xp2 = U32.add(x, 2)
  +zm2 = U32.sub(z, 2)
  +zm1 = U32.sub(z, 1)
  +zp1 = U32.add(z, 1)
  +zp2 = U32.add(z, 2)
  +y1 = U32.add(h, 1)
  +y2 = U32.add(h, 2)
  +y3 = U32.add(h, 3)
  +y4 = U32.add(h, 4)
  +y5 = U32.add(h, 5)
  +y6 = U32.add(h, 6)
  +leaf = B.Block.leaves()
  w01 = World.set_xyz(world, xm2, y5, zm2, leaf)
  w02 = World.set_xyz(w01, xm1, y5, zm2, leaf)
  w03 = World.set_xyz(w02, x, y5, zm2, leaf)
  w04 = World.set_xyz(w03, xp1, y5, zm2, leaf)
  w05 = World.set_xyz(w04, xp2, y5, zm2, leaf)
  w06 = World.set_xyz(w05, xm2, y5, zm1, leaf)
  w07 = World.set_xyz(w06, xm1, y5, zm1, leaf)
  w08 = World.set_xyz(w07, x, y5, zm1, leaf)
  w09 = World.set_xyz(w08, xp1, y5, zm1, leaf)
  w10 = World.set_xyz(w09, xp2, y5, zm1, leaf)
  w11 = World.set_xyz(w10, xm2, y5, z, leaf)
  w12 = World.set_xyz(w11, xm1, y5, z, leaf)
  w13 = World.set_xyz(w12, x, y5, z, leaf)
  w14 = World.set_xyz(w13, xp1, y5, z, leaf)
  w15 = World.set_xyz(w14, xp2, y5, z, leaf)
  w16 = World.set_xyz(w15, xm2, y5, zp1, leaf)
  w17 = World.set_xyz(w16, xm1, y5, zp1, leaf)
  w18 = World.set_xyz(w17, x, y5, zp1, leaf)
  w19 = World.set_xyz(w18, xp1, y5, zp1, leaf)
  w20 = World.set_xyz(w19, xp2, y5, zp1, leaf)
  w21 = World.set_xyz(w20, xm2, y5, zp2, leaf)
  w22 = World.set_xyz(w21, xm1, y5, zp2, leaf)
  w23 = World.set_xyz(w22, x, y5, zp2, leaf)
  w24 = World.set_xyz(w23, xp1, y5, zp2, leaf)
  w25 = World.set_xyz(w24, xp2, y5, zp2, leaf)
  w26 = World.set_xyz(w25, xm2, y6, zm2, leaf)
  w27 = World.set_xyz(w26, xm1, y6, zm2, leaf)
  w28 = World.set_xyz(w27, x, y6, zm2, leaf)
  w29 = World.set_xyz(w28, xp1, y6, zm2, leaf)
  w30 = World.set_xyz(w29, xp2, y6, zm2, leaf)
  w31 = World.set_xyz(w30, xm2, y6, zm1, leaf)
  w32 = World.set_xyz(w31, xm1, y6, zm1, leaf)
  w33 = World.set_xyz(w32, x, y6, zm1, leaf)
  w34 = World.set_xyz(w33, xp1, y6, zm1, leaf)
  w35 = World.set_xyz(w34, xp2, y6, zm1, leaf)
  w36 = World.set_xyz(w35, xm2, y6, z, leaf)
  w37 = World.set_xyz(w36, xm1, y6, z, leaf)
  w38 = World.set_xyz(w37, x, y6, z, leaf)
  w39 = World.set_xyz(w38, xp1, y6, z, leaf)
  w40 = World.set_xyz(w39, xp2, y6, z, leaf)
  w41 = World.set_xyz(w40, xm2, y6, zp1, leaf)
  w42 = World.set_xyz(w41, xm1, y6, zp1, leaf)
  w43 = World.set_xyz(w42, x, y6, zp1, leaf)
  w44 = World.set_xyz(w43, xp1, y6, zp1, leaf)
  w45 = World.set_xyz(w44, xp2, y6, zp1, leaf)
  w46 = World.set_xyz(w45, xm2, y6, zp2, leaf)
  w47 = World.set_xyz(w46, xm1, y6, zp2, leaf)
  w48 = World.set_xyz(w47, x, y6, zp2, leaf)
  w49 = World.set_xyz(w48, xp1, y6, zp2, leaf)
  w50 = World.set_xyz(w49, xp2, y6, zp2, leaf)
  w51 = World.set_xyz(w50, x, y1, z, log)
  w52 = World.set_xyz(w51, x, y2, z, log)
  w53 = World.set_xyz(w52, x, y3, z, log)
  w54 = World.set_xyz(w53, x, y4, z, log)
  w55 = World.set_xyz(w54, x, y5, z, log)
  World.set_xyz(w55, x, y6, z, log)

def World.place_big_tree(world: Array<U32>, +x: U32, +z: U32, +h: U32) -> Array<U32>:
  World.place_big_generic(world, x, z, h, B.Block.wood_log())

def World.place_big_birch(world: Array<U32>, +x: U32, +z: U32, +h: U32) -> Array<U32>:
  World.place_big_generic(world, x, z, h, B.Block.birch_log())

def World.place_cactus(world: Array<U32>, +x: U32, +z: U32, +h: U32) -> Array<U32>:
  y1 = U32.add(h, 1)
  y2 = U32.add(h, 2)
  +c = B.Block.cactus()
  w1 = World.set_xyz(world, x, y1, z, c)
  World.set_xyz(w1, x, y2, z, c)

def World.scatter_flower_go(world: Array<U32>, +x: U32, +z: U32, +h: U32, c: Bool) -> Array<U32>:
  match c:
    case True{}:
      y = U32.add(h, 1)
      World.set_xyz(world, x, y, z, B.Block.rose_flower())
    case False{}:
      world

def World.scatter_grass_go(world: Array<U32>, +x: U32, +z: U32, +h: U32, c_grass: Bool, c_flower: Bool) -> Array<U32>:
  match c_grass:
    case True{}:
      y = U32.add(h, 1)
      World.set_xyz(world, x, y, z, B.Block.tall_grass())
    case False{}:
      World.scatter_flower_go(world, x, z, h, c_flower)

def World.scatter_one(world: Array<U32>, +x: U32, +z: U32, +h: U32, +seed: U32) -> Array<U32>:
  s = U32.add(seed, 555)
  hh = World.hash(s, x, z)
  +m = U32.mod(hh, 100)
  World.scatter_grass_go(world, x, z, h, U32.is_lt(m, 8), U32.is_eq(m, 9))

def World.scatter_if(world: Array<U32>, +x: U32, +z: U32, +h: U32, +seed: U32, c: Bool) -> Array<U32>:
  match c:
    case True{}:
      World.scatter_one(world, x, z, h, seed)
    case False{}:
      world

def World.cactus_if(world: Array<U32>, +x: U32, +z: U32, +h: U32, c: Bool) -> Array<U32>:
  match c:
    case True{}:
      World.place_cactus(world, x, z, h)
    case False{}:
      world

def World.big_tree_if(world: Array<U32>, +x: U32, +z: U32, +h: U32, c: Bool) -> Array<U32>:
  match c:
    case True{}:
      World.place_big_tree(world, x, z, h)
    case False{}:
      world

def World.birch_if(world: Array<U32>, +x: U32, +z: U32, +h: U32, c: Bool) -> Array<U32>:
  match c:
    case True{}:
      World.place_big_birch(world, x, z, h)
    case False{}:
      world

def World.trees_full(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +g = U32.from_nat(p)
      +x = U32.mod(g, 64)
      +z = U32.div(g, 64)
      +h = World.height_full(seed, x, z)
      +bi = World.biome(seed, x, z)
      hh = World.hash(seed, x, z)
      +m = U32.mod(hh, 100)
      c_des = U32.is_eq(bi, 1)
      c_for = U32.is_eq(bi, 2)
      c_pln = U32.is_eq(bi, 0)
      c_m3 = U32.is_lt(m, 3)
      c_m2 = U32.is_lt(m, 2)
      c_m4 = U32.is_eq(m, 4)
      +c_h = U32.is_gt(h, 12)
      c1a = Bool.and(c_des, c_m3)
      c_cactus = Bool.and(c1a, c_h)
      c2a = Bool.and(c_for, c_m2)
      c_oak = Bool.and(c2a, c_h)
      c3a = Bool.and(c_pln, c_m4)
      c_birch = Bool.and(c3a, c_h)
      w2 = World.cactus_if(world, x, z, h, c_cactus)
      w3 = World.big_tree_if(w2, x, z, h, c_oak)
      w4 = World.birch_if(w3, x, z, h, c_birch)
      World.trees_full(p, w4, seed)

def World.scatter(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +g = U32.from_nat(p)
      +x = U32.mod(g, 64)
      +z = U32.div(g, 64)
      +h = World.height_full(seed, x, z)
      w2 = World.scatter_if(world, x, z, h, seed, U32.is_gt(h, 12))
      World.scatter(p, w2, seed)

def World.gen_full_rec(+n: Nat, world: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +idx = U32.from_nat(p)
      +t = U32.div(idx, 64)
      +x = U32.mod(idx, 64)
      +z = U32.mod(t, 64)
      +y = U32.div(t, 64)
      +hh = World.height_full(seed, x, z)
      b = World.block_full(seed, x, y, z, hh)
      w2 = World.set(world, idx, b)
      World.gen_full_rec(p, w2, seed)

def World.gen_full(+seed: U32) -> Array<U32>:
  w0 = [0 : U32^17n]
  w1 = World.gen_full_rec(U32.to_nat(131072), w0, seed)
  w2 = World.trees_full(U32.to_nat(4096), w1, seed)
  World.scatter(U32.to_nat(4096), w2, seed)

def World.chunk_full_rec(+n: Nat, world: Array<U32>, +seed: U32, +base: U32) -> Array<U32>:
  match n:
    case 0n:
      world
    case 1n+p:
      +lp = U32.from_nat(p)
      +g = U32.add(base, lp)
      +t = U32.div(g, 64)
      +x = U32.mod(g, 64)
      +z = U32.mod(t, 64)
      +y = U32.div(t, 64)
      +hh = World.height_full(seed, x, z)
      b = World.block_full(seed, x, y, z, hh)
      w2 = World.set(world, lp, b)
      World.chunk_full_rec(p, w2, seed, base)

def World.gen_chunk_full(+seed: U32, base: U32) -> Array<U32>:
  w0 = [0 : U32^16n]
  World.chunk_full_rec(U32.to_nat(65536), w0, seed, base)

# Parallel full pipeline: 131072 voxels split into two 65536 chunks.
#   c1 c2 = World.gen_chunk_full(seed, 0) World.gen_chunk_full(seed, 65536)
# Each chunk owns its Array, so the two calls are independent and balanced.

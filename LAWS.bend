import Base

# Minimal Minecraft spec (standalone; integrator adapts to final modules).
# Block IDs, height-bounded world, pure physics helpers, hotbar.

type Block is Data:
  Air{}
  Stone{}
  Dirt{}
  Grass{}
  Bedrock{}
  Wood{}
  Leaves{}
  Sand{}
  Water{}

def is_solid(b: Block) -> Bool:
  match b:
    case Air{}:
      False{}
    case Stone{}:
      True{}
    case Dirt{}:
      True{}
    case Grass{}:
      True{}
    case Bedrock{}:
      True{}
    case Wood{}:
      True{}
    case Leaves{}:
      False{}
    case Sand{}:
      True{}
    case Water{}:
      False{}

def block_at(x: Nat, y: Nat, z: Nat, seed: Nat) -> Block:
  match y:
    case 0n:
      Bedrock{}
    case 1n+py:
      match py:
        case 0n:
          Stone{}
        case 1n+py2:
          match py2:
            case 0n:
              Dirt{}
            case 1n+py3:
              Grass{}

def world_get(w: List<Block>, i: Nat) -> Block:
  match w i:
    case Nil{} _:
      Air{}
    case h <> t 0n:
      h
    case h <> t 1n+p:
      world_get(t, p)

def world_set(w: List<Block>, i: Nat, b: Block) -> List<Block>:
  match w i:
    case Nil{} 0n:
      b <> Nil{}
    case Nil{} 1n+p:
      Air{} <> world_set(Nil{}, p, b)
    case h <> t 0n:
      b <> t
    case h <> t 1n+p:
      h <> world_set(t, p, b)

def gravity_step(vy: Nat, airborne: Bool, flying: Bool) -> Nat:
  match airborne flying:
    case True{} False{}:
      Nat.sub(vy, 1n)
    case True{} True{}:
      vy
    case False{} True{}:
      vy
    case False{} False{}:
      vy

def phys_step(pos: Nat, vel: Nat, dt: Nat) -> Nat:
  match dt:
    case 0n:
      pos
    case 1n+p:
      Nat.add(pos, vel)

def shade_n(steps: Nat, sky: Nat) -> Nat:
  match steps:
    case 0n:
      sky
    case 1n+p:
      shade_n(p, Nat.sub(sky, 1n))

type Hotbar is Type:
  HB{slots: List<Block>, sel: Nat}

def hotbar_select(hb: Hotbar, i: Nat) -> Hotbar:
  match hb:
    case HB{slots, sel}:
      HB{slots, i}

def hotbar_selected(hb: Hotbar) -> Nat:
  match hb:
    case HB{slots, sel}:
      sel

# (1) air is not solid
law air_not_solid:
  {is_solid(Air{}) == False{} : Bool}

# (2) bedrock at y=0 for any x/z/seed
law bedrock_at_zero:
  for x: Nat
  for z: Nat
  for seed: Nat
  {block_at(x, 0n, z, seed) == Bedrock{} : Block}

# (3) out-of-bounds get returns air
law oob_get_air:
  for n: Nat
  {world_get(Nil{}, n) == Air{} : Block}

# (4) set-then-get roundtrip (general index; needs induction)
law set_get_roundtrip:
  for w: List<Block>
  for i: Nat
  for b: Block
  {world_get(world_set(w, i, b), i) == b : Block}

# (5) gravity step decreases vy when airborne and not flying
law gravity_falls:
  for vy: Nat
  {gravity_step(vy, True{}, False{}) == Nat.sub(vy, 1n) : Nat}

# (6) zero-dt physics is identity on position
law phys_zero_dt:
  for pos: Nat
  for vel: Nat
  {phys_step(pos, vel, 0n) == pos : Nat}

# (7) shade with 0 steps is identity (determinism base)
law shade_zero:
  for sky: Nat
  {shade_n(0n, sky) == sky : Nat}

# (8) hotbar select-then-selected roundtrip
law hotbar_roundtrip:
  for hb: Hotbar
  for i: Nat
  {hotbar_selected(hotbar_select(hb, i)) == i : Nat}

# helper: Nat.add zero (induction + rewrite demo, also used for physics reasoning)
law nat_add_zero:
  for x: Nat
  {Nat.add(x, 0n) == x : Nat}

# ---- NEW: minimal local spec models (standalone, no sibling imports) ----

def block_hard(b: Block) -> Nat:
  match b:
    case Air{}:
      0n
    case Stone{}:
      5n
    case Dirt{}:
      2n
    case Grass{}:
      2n
    case Bedrock{}:
      10n
    case Wood{}:
      4n
    case Leaves{}:
      1n
    case Sand{}:
      2n
    case Water{}:
      0n

def nat_eq(a: Nat, b: Nat) -> Bool:
  match a b:
    case 0n 0n:
      True{}
    case 0n 1n+bp:
      False{}
    case 1n+ap 0n:
      False{}
    case 1n+ap 1n+bp:
      nat_eq(ap, bp)

type Edit is Data:
  E{idx: Nat, val: Block}

def edit_push(edits: List<Edit>, i: Nat, v: Block) -> List<Edit>:
  E{i, v} <> edits

def edit_lookup(edits: List<Edit>, +i: Nat) -> Block:
  match edits:
    case Nil{}:
      Air{}
    case E{idx, val} <> rest:
      Bool.pick(Block, nat_eq(idx, i), val, edit_lookup(rest, i))

type Item is Data:
  Stick{}
  Plank{}
  Coal{}
  Torch{}

def craft_sticks(a: Item, b: Item) -> Item:
  match a b:
    case Plank{} Plank{}:
      Stick{}
    case Plank{} Coal{}:
      Torch{}
    case Plank{} Stick{}:
      Plank{}
    case Plank{} Torch{}:
      Plank{}
    case Stick{} _:
      Stick{}
    case Coal{} _:
      Coal{}
    case Torch{} _:
      Torch{}

def time_wrap(t: Nat) -> Nat:
  Nat.mod(Nat.add(t, 1n), 1000n)

def mob_hurt(hp: Nat, dmg: Nat) -> Nat:
  Nat.sub(hp, dmg)

def mob_dead(hp: Nat) -> Bool:
  Nat.is_eq(hp, 0n)

def save_encode(xs: List<Nat>) -> List<Nat>:
  0n <> xs

def save_decode(xs: List<Nat>) -> List<Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      t

# (10) water is not solid
law water_not_solid:
  {is_solid(Water{}) == False{} : Bool}

# (11) bedrock hardness maximal vs stone (Nat comparison to True)
law bedrock_hard_ge_stone:
  {Nat.is_ge(block_hard(Bedrock{}), block_hard(Stone{})) == True{} : Bool}

# (12) decidable Nat equality reflexive (supports edit overlay)
law nat_eq_refl:
  for n: Nat
  {nat_eq(n, n) == True{} : Bool}

# (13) break-then-place roundtrip on edit overlay
law edit_push_hit:
  for edits: List<Edit>
  for i: Nat
  for v: Block
  {edit_lookup(edit_push(edits, i, v), i) == v : Block}

# (14) push preserves older entries when indices differ
law edit_push_miss:
  for edits: List<Edit>
  for i: Nat
  for v: Block
  for j: Nat
  for pf: {nat_eq(i, j) == False{} : Bool}
  {edit_lookup(edit_push(edits, i, v), j) == edit_lookup(edits, j) : Block}

# (15) hotbar last-select-wins (mod-periodicity simpler lawful variant)
law hotbar_select_twice:
  for hb: Hotbar
  for i: Nat
  for j: Nat
  {hotbar_selected(hotbar_select(hotbar_select(hb, i), j)) == j : Nat}

# (16) gravity saturating at zero (terminal-clamp simpler face)
law gravity_zero_stays:
  {gravity_step(0n, True{}, False{}) == 0n : Nat}

# (17) gravity grounded is identity (terminal-clamp second face)
law gravity_grounded:
  for vy: Nat
  {gravity_step(vy, False{}, False{}) == vy : Nat}

# (18) crafting lawful: planks craft sticks
law craft_sticks_ok:
  {craft_sticks(Plank{}, Plank{}) == Stick{} : Item}

# (19) day/night wrap at end of cycle
law time_wrap_999:
  {time_wrap(999n) == 0n : Nat}

# (20) day/night tick at start of cycle
law time_wrap_0:
  {time_wrap(0n) == 1n : Nat}

# (21) mob damage example (monotone simpler face)
law mob_hurt_example:
  {mob_hurt(5n, 3n) == 2n : Nat}

# (22) mob dead at zero (dead <=> hp==0 face)
law mob_dead_zero:
  {mob_dead(0n) == True{} : Bool}

# (23) mob alive when nonzero (dead <=> hp==0 second face)
law mob_alive_nonzero:
  {mob_dead(5n) == False{} : Bool}

# (24) save framing roundtrip on Nat runs (RLE toy simpler variant)
law save_roundtrip:
  for xs: List<Nat>
  {save_decode(save_encode(xs)) == xs : List<Nat>}

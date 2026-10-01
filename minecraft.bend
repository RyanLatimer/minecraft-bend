import Base
import ./blocks.bend as B
import ./world.bend as W
import ./render.bend as R
import ./player.bend as PL
import ./physics.bend as PH
import ./mobs.bend as MB

# minecraft.bend — integrated BendCraft entry point.
#
# Architecture (why pure sampling, not the Array world):
# - view must build a 128x128 Image with PARALLEL quadtree lets. An
#   Array<U32> world is affine (Type): it cannot be shared across parallel
#   branches without cloning (exponential blowup), nor captured by a closed
#   template. So live rendering samples the world PURELY: terrain from
#   W.World.block_at/height_at/hash (exactly the function World.gen fills
#   the Array with), trees approximated per-column, and player edits kept
#   as a prepend-only List<Edit> overlay (Data, freely reusable with +).
# - The Array world (world.bend: World.gen, parallel gen_chunk halves,
#   get_xyz/set_xyz) remains the chunk-storage / save format used by
#   game.bend + save.bend. Both paths agree on block IDs and terrain shape.
# - Real module reuse in this file: B.Block.color + B.Block.* ids,
#   W.World.hash/height_at/block_at, R.Render.cam_from/pixel_ray/sky/shade/
#   is_cross, PL.Hotbar.default/select/selected + PL.Is* key predicates,
#   PH.Physics.blocked for break solidity.
# - Controls: W/A/S/D move (+arrow keys also WASD-alias-free: arrows look),
#   J/L/I/K also look, Space jump (fly: up), C/down fly-down, E or
#   left-click break, Q or right-click place, F fly toggle, 1-9 hotbar,
#   Esc/Close quits. Bottom HUD strip shows 9 hotbar slots + selection.
# - Physics is tick-unit (see do_phys): gravity 0.3/tick, terminal -1.5,
#   jump 1.2, walk 0.3/tick, ground clamp from pure height_at.

type Edit is Data:
  E{idx: U32, val: U32}

type Acc is Data:
  A{fw: Bool, back: Bool, left: Bool, right: Bool, jump: Bool, down: Bool, brk: Bool, plc: Bool, flytog: Bool, spr: Bool, snk: Bool, atk: Bool, hot: U32, quit: Bool, yaw_d: F32, pitch_d: F32}

type State is Data:
  S{seed: U32, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, og: Bool, fly: Bool, hb: PL.Hotbar, edits: List<&2, Edit>, hp: U32, food: U32, hurt: U32, mobs: List<&2, MB.Mob>, tickn: U32, time: F32}

# ---------------- resolution ----------------
# The display backend walks the Image quadtree on the GPU, one thread per
# screen pixel, down to depth k = ceil_pow2(max(win_w, win_h)). Two regimes:
# - depth < k: each rendered pixel magnifies to 2^(k-depth) screen pixels
#   (free integer upscale, chunky retro look).
# - depth >= k: 1:1 pixels (depth > k wastes rays point-picking tl).
# So: match depth to the window (2^depth >= max(w,h), minimal) for 1:1, or
# render small for speed and let the backend upscale.
# CPU cost ~= leaves * raymarch: 128^2 ~60fps, 256^2 ~15fps, 512^2 ~4fps.
# PRESETS (edit quality/win_w/win_h together):
#   Smooth:   7n / 128  / 128   (60fps CPU)
#   Balanced: 8n / 256  / 256   (~15fps CPU)
#   Big:      9n / 512  / 512   (~4fps CPU, needs GPU for realtime)
#   1080p:    9n / 1920 / 1080  (512 render upscaled x4, chunky 1080p)
#   FullHD:   11n / 1920 / 1080 (true 1:1 1080p, GPU `!` only, experimental)
# GPU NOTE: replace MC.build with MC.build! inside frame_q to run the whole
# quadtree build on the GPU (needs clang 19+, Metal on Mac / CUDA on Linux).
# Untested here (no GPU in this box) — keep the CPU path as fallback.
def MC.quality() -> Nat:
  9n

def MC.win_w() -> U32:
  1920

def MC.win_h() -> U32:
  1080

# ---------------- input accumulator ----------------

def MC.acc_empty() -> Acc:
  A{False{}, False{}, False{}, False{}, False{}, False{}, False{}, False{}, False{}, False{}, False{}, False{}, 9, False{}, 0.0, 0.0}

def MC.set_fw(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{v, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_back(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, v, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_left(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, v, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_right(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, v, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_jump(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, v, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_down(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, v, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_brk(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, v, plc, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_plc(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, v, flytog, spr, snk, atk, hot, quit, yd, pd}

def MC.set_flytog(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, v, spr, snk, atk, hot, quit, yd, pd}

def MC.set_spr(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, v, snk, atk, hot, quit, yd, pd}

def MC.set_snk(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, v, atk, hot, quit, yd, pd}

def MC.set_atk(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, v, hot, quit, yd, pd}

def MC.set_hot(a: Acc, v: U32) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, v, quit, yd, pd}

def MC.set_quit(a: Acc, v: Bool) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, v, yd, pd}

def MC.add_look(a: Acc, dx: F32, dy: F32) -> Acc:
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, (yd + dx : F32), (pd + dy : F32)}

# Local movement predicates: WASD only (arrows are look keys here).
def MC.is_fw(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 87), U32.is_eq(c, 119))

def MC.is_back(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 83), U32.is_eq(c, 115))

def MC.is_left(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 65), U32.is_eq(c, 97))

def MC.is_right(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 68), U32.is_eq(c, 100))

# Look keys: JLIK + arrows. Linux arrows are 37-40, Mac arrows 63232-63235.
def MC.is_lookL(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(U32.is_eq(c, 74), U32.is_eq(c, 106)), U32.is_eq(c, 37)), U32.is_eq(c, 63234))

def MC.is_lookR(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(U32.is_eq(c, 76), U32.is_eq(c, 108)), U32.is_eq(c, 39)), U32.is_eq(c, 63235))

def MC.is_lookU(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(U32.is_eq(c, 73), U32.is_eq(c, 105)), U32.is_eq(c, 38)), U32.is_eq(c, 63232))

def MC.is_lookD(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(U32.is_eq(c, 75), U32.is_eq(c, 107)), U32.is_eq(c, 40)), U32.is_eq(c, 63233))

# key-down chain (each link: match on Bool param, never computed).
def MC.kd_hot9(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 8)
    case False{}:
      a

def MC.kd_hot8(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 7)
    case False{}:
      MC.kd_hot9(PL.IsHot9(c), a, c)

def MC.kd_hot7(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 6)
    case False{}:
      MC.kd_hot8(PL.IsHot8(c), a, c)

def MC.kd_hot6(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 5)
    case False{}:
      MC.kd_hot7(PL.IsHot7(c), a, c)

def MC.kd_hot5(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 4)
    case False{}:
      MC.kd_hot6(PL.IsHot6(c), a, c)

def MC.kd_hot4(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 3)
    case False{}:
      MC.kd_hot5(PL.IsHot5(c), a, c)

def MC.kd_hot3(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 2)
    case False{}:
      MC.kd_hot4(PL.IsHot4(c), a, c)

def MC.kd_hot2(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 1)
    case False{}:
      MC.kd_hot3(PL.IsHot3(c), a, c)

def MC.kd_hot1(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_hot(a, 0)
    case False{}:
      MC.kd_hot2(PL.IsHot2(c), a, c)

def MC.kd_quit(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_quit(a, True{})
    case False{}:
      MC.kd_hot1(PL.IsHot1(c), a, c)

def MC.kd_snk(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_snk(a, True{})
    case False{}:
      MC.kd_quit(PL.IsQuitKey(c), a, c)

def MC.kd_spr(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_spr(a, True{})
    case False{}:
      MC.kd_snk(PL.IsSneak(c), a, c)

def MC.kd_atk(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_atk(a, True{})
    case False{}:
      MC.kd_spr(PL.IsSprint(c), a, c)

def MC.kd_fly(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_flytog(a, True{})
    case False{}:
      MC.kd_atk(PL.IsAttack(c), a, c)

def MC.kd_plc(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_plc(a, True{})
    case False{}:
      MC.kd_fly(PL.IsFlyKey(c), a, c)

def MC.kd_brk(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_brk(a, True{})
    case False{}:
      MC.kd_plc(PL.IsPlaceKey(c), a, c)

def MC.kd_down(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_down(a, True{})
    case False{}:
      MC.kd_brk(PL.IsBreakKey(c), a, c)

def MC.kd_jump(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_jump(a, True{})
    case False{}:
      MC.kd_down(PL.IsDownShift(c), a, c)

def MC.kd_lookD(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.add_look(a, 0.0, (0.0 - 0.12 : F32))
    case False{}:
      MC.kd_jump(PL.IsJump(c), a, c)

def MC.kd_lookU(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.add_look(a, 0.0, 0.12)
    case False{}:
      MC.kd_lookD(MC.is_lookD(c), a, c)

def MC.kd_lookR(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.add_look(a, 0.12, 0.0)
    case False{}:
      MC.kd_lookU(MC.is_lookU(c), a, c)

def MC.kd_lookL(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.add_look(a, (0.0 - 0.12 : F32), 0.0)
    case False{}:
      MC.kd_lookR(MC.is_lookR(c), a, c)

def MC.kd_right(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_right(a, True{})
    case False{}:
      MC.kd_lookL(MC.is_lookL(c), a, c)

def MC.kd_left(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_left(a, True{})
    case False{}:
      MC.kd_right(MC.is_right(c), a, c)

def MC.kd_back(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_back(a, True{})
    case False{}:
      MC.kd_left(MC.is_left(c), a, c)

def MC.kd_fw(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_fw(a, True{})
    case False{}:
      MC.kd_back(MC.is_back(c), a, c)

def MC.kd(a: Acc, +c: U32) -> Acc:
  +cc = c
  MC.kd_fw(MC.is_fw(cc), a, cc)

# key-up: clear held movement flags.
def MC.ku_jump(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_jump(a, False{})
    case False{}:
      a

def MC.ku_look(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      a
    case False{}:
      MC.ku_jump(PL.IsJump(c), a, c)

def MC.ku_snk(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_snk(a, False{})
    case False{}:
      MC.ku_look(MC.is_lookR(c), a, c)

def MC.ku_spr(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_spr(a, False{})
    case False{}:
      MC.ku_snk(PL.IsSneak(c), a, c)

def MC.ku_right(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_right(a, False{})
    case False{}:
      MC.ku_spr(PL.IsSprint(c), a, c)

def MC.ku_left(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_left(a, False{})
    case False{}:
      MC.ku_right(MC.is_right(c), a, c)

def MC.ku_back(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_back(a, False{})
    case False{}:
      MC.ku_left(MC.is_left(c), a, c)

def MC.ku_fw(on: Bool, a: Acc, +c: U32) -> Acc:
  match on:
    case True{}:
      MC.set_fw(a, False{})
    case False{}:
      MC.ku_back(MC.is_back(c), a, c)

def MC.ku(a: Acc, +c: U32) -> Acc:
  +cc = c
  MC.ku_fw(MC.is_fw(cc), a, cc)

def MC.key(a: Acc, c: U32, down: Bool) -> Acc:
  match down:
    case True{}:
      MC.kd(a, c)
    case False{}:
      MC.ku(a, c)

def MC.mb_plc(on: Bool, a: Acc) -> Acc:
  match on:
    case True{}:
      MC.set_plc(a, True{})
    case False{}:
      a

def MC.mb_brk(on: Bool, a: Acc, btn: U32) -> Acc:
  match on:
    case True{}:
      MC.set_brk(a, True{})
    case False{}:
      MC.mb_plc(PL.IsPlaceBtn(btn), a)

def MC.mouse(a: Acc, +btn: U32, down: Bool) -> Acc:
  match down:
    case True{}:
      MC.mb_brk(PL.IsBreakBtn(btn), a, btn)
    case False{}:
      a

def MC.press(a: Acc, e: Event) -> Acc:
  match a e:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd} Key{c, d}:
      MC.key(A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}, c, d)
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd} Mouse{x, y, btn, d}:
      MC.mouse(A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}, btn, d)
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd} Move{x, y}:
      A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd} Close{}:
      MC.set_quit(A{fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, quit, yd, pd}, True{})

def MC.fold(events: List<Event>, acc: Acc) -> Acc:
  match events:
    case Nil{}:
      acc
    case Con{h, t}:
      MC.fold(t, MC.press(acc, h))

# ---------------- edits overlay ----------------

def MC.edit_miss() -> U32 & Bool:
  (0, False{})

def MC.edit_hit(v: U32) -> U32 & Bool:
  (v, True{})

def MC.edit_pick(eq: Bool, v: U32, pv: U32, pf: Bool) -> U32 & Bool:
  match eq:
    case True{}:
      (v, True{})
    case False{}:
      (pv, pf)

def MC.edit_combine(eq: Bool, v: U32, prev: U32 & Bool) -> U32 & Bool:
  (pv, pf) = prev
  MC.edit_pick(eq, v, pv, pf)

def MC.edit_head(h: Edit, +t: List<&2, Edit>, +idx: U32, prev: U32 & Bool) -> U32 & Bool:
  match h:
    case E{i, v}:
      MC.edit_combine(U32.is_eq(i, idx), v, prev)

def MC.edit_lookup(+edits: List<&2, Edit>, +idx: U32) -> U32 & Bool:
  match edits:
    case Nil{}:
      MC.edit_miss()
    case h <> t:
      MC.edit_head(h, t, idx, MC.edit_lookup(t, idx))

def MC.elen(fuel: Nat, +edits: List<&2, Edit>) -> U32:
  match fuel edits:
    case 0n _:
      999
    case 1n+f Nil{}:
      0
    case 1n+f h <> t:
      (1 + MC.elen(f, t) : U32)

def MC.push_go(ok: Bool, +edits: List<&2, Edit>, idx: U32, v: U32) -> List<&2, Edit>:
  match ok:
    case True{}:
      E{idx, v} <> edits
    case False{}:
      edits

def MC.push(+edits: List<&2, Edit>, idx: U32, v: U32) -> List<&2, Edit>:
  MC.push_go(U32.is_lt(MC.elen(500n, edits), 512), edits, idx, v)

# ---------------- voxel sampling (pure) ----------------

def MC.flat_idx(x: U32, y: U32, z: U32) -> U32:
  t1 = U32.mul(y, 64)
  t2 = (t1 + z : U32)
  t3 = U32.mul(t2, 64)
  (t3 + x : U32)

# Per-column tree approximation: trunk h+1..h+2, canopy h+3..h+4.
def MC.tree_lo(lo: Bool) -> U32:
  match lo:
    case True{}:
      4
    case False{}:
      0

def MC.tree_hi(hi: Bool, lo: Bool) -> U32:
  match hi:
    case True{}:
      5
    case False{}:
      MC.tree_lo(lo)

def MC.tree_voxel(+y: U32, +h: U32) -> U32:
  MC.tree_hi(Bool.or(U32.is_eq(y, (h + 3 : U32)), U32.is_eq(y, (h + 4 : U32))), Bool.or(U32.is_eq(y, (h + 1 : U32)), U32.is_eq(y, (h + 2 : U32))))

def MC.tree_pick(is_tree: Bool, +seed: U32, +x: U32, +y: U32, +z: U32, +h: U32) -> U32:
  match is_tree:
    case True{}:
      MC.tree_voxel(y, h)
    case False{}:
      W.World.block_full(seed, x, y, z, h)

def MC.terrain(+seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  +h = W.World.height_full(seed, x, z)
  MC.tree_pick(Bool.and(U32.is_lt(U32.mod(W.World.hash(seed, x, z), 100), 2), U32.is_gt(h, 12)), seed, x, y, z, h)

def MC.voxel_pick(hit: Bool, v: U32, +seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  match hit:
    case True{}:
      v
    case False{}:
      MC.terrain(seed, x, y, z)

def MC.voxel_found(found: U32 & Bool, +seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  (v, hit) = found
  MC.voxel_pick(hit, v, seed, x, y, z)

def MC.voxel_oob(oob: Bool, +seed: U32, +edits: List<&2, Edit>, +x: U32, +y: U32, +z: U32) -> U32:
  match oob:
    case True{}:
      0
    case False{}:
      MC.voxel_found(MC.edit_lookup(edits, MC.flat_idx(x, y, z)), seed, x, y, z)

def MC.voxel(+seed: U32, +edits: List<&2, Edit>, +x: U32, +y: U32, +z: U32) -> U32:
  MC.voxel_oob(Bool.not(W.World.in_bounds(x, y, z)), seed, edits, x, y, z)

def MC.eye_water(+seed: U32, +edits: List<&2, Edit>, px: F32, py: F32, pz: F32) -> Bool:
  U32.is_eq(MC.voxel(seed, edits, F32.to_u32(px), F32.to_u32(py), F32.to_u32(pz)), 7)

# ---------------- raymarch (pure, parallel-safe) ----------------

# Face id from dominant ray axis (0 top,1 bottom,2 +x,3 -x,4 +z,5 -z).
def MC.face_x(pos: Bool) -> U32:
  match pos:
    case True{}:
      2
    case False{}:
      3

def MC.face_y(pos: Bool) -> U32:
  match pos:
    case True{}:
      1
    case False{}:
      0

def MC.face_z(pos: Bool) -> U32:
  match pos:
    case True{}:
      4
    case False{}:
      5

def MC.face_yz(y_dom: Bool, +dy: F32, +dz: F32) -> U32:
  match y_dom:
    case True{}:
      MC.face_y(F32.is_ge(dy, 0.0))
    case False{}:
      MC.face_z(F32.is_ge(dz, 0.0))

def MC.face_pick(x_dom: Bool, y_dom: Bool, +dx: F32, +dy: F32, +dz: F32) -> U32:
  match x_dom:
    case True{}:
      MC.face_x(F32.is_ge(dx, 0.0))
    case False{}:
      MC.face_yz(y_dom, dy, dz)

def MC.face_of(+dx: F32, +dy: F32, +dz: F32) -> U32:
  +ax = (dx * dx : F32)
  +ay = (dy * dy : F32)
  +az = (dz * dz : F32)
  MC.face_pick(Bool.and(F32.is_ge(ax, ay), F32.is_ge(ax, az)), F32.is_ge(ay, az), dx, dy, dz)

def MC.sky_fin(cloud: Bool, sun: U32) -> U32:
  match cloud:
    case True{}:
      16777215
    case False{}:
      sun

def MC.sky_at(+dx: F32, +dy: F32, +dz: F32, +time: F32, x: F32, z: F32) -> U32:
  MC.sky_fin(R.Render.cloud_hit(x, z, time), R.Render.sun_color(dx, dy, dz, time))

def MC.tex_hash(+ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  +a = (ix * 73 : U32)
  +b = (iy * 151 : U32)
  +c = (iz * 229 : U32)
  +d = (face * 37 : U32)
  U32.mod((((a + b : U32) + c : U32) + d : U32), 16)

def MC.tex_br(h: U32) -> F32:
  (0.82 + (U32.to_f32(h) * 0.012 : F32) : F32)

def MC.tex_scale(+color: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  +f = MC.tex_br(MC.tex_hash(ix, iy, iz, face))
  r g = R.Render.shade_chan(color, 16n, f) R.Render.shade_chan(color, 8n, f)
  b = R.Render.shade_chan(color, 0n, f)
  R.Render.pack(r, g, b)

def MC.daylight(+time: F32) -> F32:
  +ang = (time * 6.2831853 : F32)
  +e = F32.sin(ang)
  +dl = F32.clamp(((e + 0.25 : F32) * 2.0 : F32), 0.0, 1.0)
  (0.3 + (dl * 0.7 : F32) : F32)

def MC.day_scale(+color: U32, +time: F32) -> U32:
  +f = MC.daylight(time)
  r g = R.Render.shade_chan(color, 16n, f) R.Render.shade_chan(color, 8n, f)
  b = R.Render.shade_chan(color, 0n, f)
  R.Render.pack(r, g, b)

# ---------------- procedural textures ----------------
# No image sampler exists in Bend, so faces get 4x4 procedural texels from
# the hit voxel + fractional hit position. (u,v) depend on the face plane:
# top/bottom use (x,z), x-faces use (z,y), z-faces use (x,y).

def MC.frac(+a: F32) -> F32:
  (a - U32.to_f32(F32.to_u32(F32.floor(a))) : F32)

def MC.tex_uv_go(top: Bool, side_x: Bool, +hx: F32, +hy: F32, +hz: F32) -> F32 & F32:
  match top side_x:
    case True{} _:
      (MC.frac(hx), MC.frac(hz))
    case False{} True{}:
      (MC.frac(hz), MC.frac(hy))
    case False{} False{}:
      (MC.frac(hx), MC.frac(hy))

def MC.tex_uv(+face: U32, +hx: F32, +hy: F32, +hz: F32) -> F32 & F32:
  MC.tex_uv_go(Bool.or(U32.is_eq(face, 0), U32.is_eq(face, 1)), Bool.or(U32.is_eq(face, 2), U32.is_eq(face, 3)), hx, hy, hz)

def MC.pick2(on: Bool, a: U32, b: U32) -> U32:
  match on:
    case True{}:
      a
    case False{}:
      b

def MC.checker(tu: U32, tv: U32, a: U32, b: U32) -> U32:
  MC.pick2(U32.is_zero(U32.mod((tu + tv : U32), 2)), a, b)

def MC.pat_grass_side(top_row: Bool, tu: U32, tv: U32) -> U32:
  match top_row:
    case True{}:
      6142012
    case False{}:
      MC.checker(tu, tv, 9067051, 7946015)

def MC.pat_grass(top: Bool, bot: Bool, +tu: U32, +tv: U32) -> U32:
  match top bot:
    case True{} _:
      MC.checker(tu, tv, 6142012, 4885808)
    case False{} True{}:
      7946015
    case False{} False{}:
      MC.pat_grass_side(U32.is_zero(tv), tu, tv)

def MC.pat_mortar(tu: U32, tv: U32) -> U32:
  MC.pick2(Bool.or(U32.is_zero(tu), U32.is_zero(tv)), 7237230, 8947848)

def MC.pat_wood(tu: U32) -> U32:
  MC.pick2(U32.is_zero(U32.mod(tu, 2)), 7031338, 4860192)

def MC.pat_dither(tu: U32, tv: U32, ix: U32, iz: U32, a: U32, b: U32) -> U32:
  MC.pick2(U32.is_zero(U32.mod(((((tu + tv : U32) + ix : U32) + iz : U32) + 0 : U32), 2)), a, b)

def MC.pat11(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pick2(U32.is_zero(U32.mod(MC.tex_hash(ix, iy, iz, face), 4)), 1710618, 8947848)
    case False{}:
      MC.tex_scale(B.Block.color(bid), ix, iy, iz, face)

def MC.pat10(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pick2(Bool.or(Bool.or(U32.is_zero(tu), U32.is_zero(tv)), Bool.or(U32.is_eq(tu, 3), U32.is_eq(tv, 3))), 16777215, 14545663)
    case False{}:
      MC.pat11(U32.is_eq(bid, 11), bid, tu, tv, ix, iy, iz, face)

def MC.pat09(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pick2(U32.is_eq(tv, 3), 8023350, 11569743)
    case False{}:
      MC.pat10(U32.is_eq(bid, 10), bid, tu, tv, ix, iy, iz, face)

def MC.pat08(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_dither(tu, tv, ix, iz, 3355443, 1118481)
    case False{}:
      MC.pat09(U32.is_eq(bid, 9), bid, tu, tv, ix, iy, iz, face)

def MC.pat07(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pick2(U32.is_zero(U32.mod(tu, 2)), 3895252, 3108800)
    case False{}:
      MC.pat08(U32.is_eq(bid, 8), bid, tu, tv, ix, iy, iz, face)

def MC.pat06(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_dither(tu, tv, ix, iz, 14931867, 14079754)
    case False{}:
      MC.pat07(U32.is_eq(bid, 7), bid, tu, tv, ix, iy, iz, face)

def MC.pat05(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_dither(tu, tv, ix, iz, 3050286, 2061855)
    case False{}:
      MC.pat06(U32.is_eq(bid, 6), bid, tu, tv, ix, iy, iz, face)

def MC.pat04(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_wood(tu)
    case False{}:
      MC.pat05(U32.is_eq(bid, 5), bid, tu, tv, ix, iy, iz, face)

def MC.pat03(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_mortar(tu, tv)
    case False{}:
      MC.pat04(U32.is_eq(bid, 4), bid, tu, tv, ix, iy, iz, face)

def MC.pat02(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.checker(tu, tv, 9067051, 7946015)
    case False{}:
      MC.pat03(U32.is_eq(bid, 3), bid, tu, tv, ix, iy, iz, face)

def MC.pat01(eq: Bool, +bid: U32, +tu: U32, +tv: U32, +ix: U32, +iy: U32, +iz: U32, +face: U32) -> U32:
  match eq:
    case True{}:
      MC.pat_grass(U32.is_eq(face, 0), U32.is_eq(face, 1), tu, tv)
    case False{}:
      MC.pat02(U32.is_eq(bid, 2), bid, tu, tv, ix, iy, iz, face)

def MC.pat(+bid: U32, +face: U32, tu: U32, tv: U32, +ix: U32, +iy: U32, +iz: U32) -> U32:
  MC.pat01(U32.is_eq(bid, 1), bid, tu, tv, ix, iy, iz, face)

def MC.texel_go(uv: F32 & F32, +bid: U32, +face: U32, +ix: U32, +iy: U32, +iz: U32) -> U32:
  (u, v) = uv
  MC.pat(bid, face, F32.to_u32((u * 4.0 : F32)), F32.to_u32((v * 4.0 : F32)), ix, iy, iz)

def MC.texel(+bid: U32, +face: U32, +ix: U32, +iy: U32, +iz: U32, +hx: F32, +hy: F32, +hz: F32) -> U32:
  MC.texel_go(MC.tex_uv(face, hx, hy, hz), bid, face, ix, iy, iz)

def MC.hit_shade(+bid: U32, +steps: U32, +dx: F32, +dy: F32, +dz: F32, +ix: U32, +iy: U32, +iz: U32, +hx: F32, +hy: F32, +hz: F32, +time: F32) -> U32:
  +face = MC.face_of(dx, dy, dz)
  +tex = MC.texel(bid, face, ix, iy, iz, hx, hy, hz)
  +sh = R.Render.shade_face(tex, steps, face)
  MC.day_scale(sh, time)

# Single self-recursive raymarcher (Bend forbids mutual recursion, so the
# step/hit/march trio is one def). bid/empty ride along as params, seeded
# with (0, True) by pixel_go; each step computes the next pair as call args.
def MC.march(fuel: Nat, +seed: U32, +edits: List<&2, Edit>, ox: F32, oy: F32, oz: F32, +dx: F32, +dy: F32, +dz: F32, bid: U32, empty: Bool, +ix: U32, +iy: U32, +iz: U32, +steps: U32, +time: F32) -> U32:
  match fuel empty:
    case 0n False{}:
      MC.sky_at(dx, dy, dz, time, ox, oz)
    case 0n True{}:
      MC.sky_at(dx, dy, dz, time, ox, oz)
    case 1n+f False{}:
      MC.hit_shade(bid, steps, dx, dy, dz, ix, iy, iz, ox, oy, oz, time)
    case 1n+f True{}:
      +nx = (ox + (dx * 0.25 : F32) : F32)
      +ny = (oy + (dy * 0.25 : F32) : F32)
      +nz = (oz + (dz * 0.25 : F32) : F32)
      +jx = F32.to_u32(F32.floor(nx))
      +jy = F32.to_u32(F32.floor(ny))
      +jz = F32.to_u32(F32.floor(nz))
      +nb = MC.voxel(seed, edits, jx, jy, jz)
      MC.march(f, seed, edits, nx, ny, nz, dx, dy, dz, nb, U32.is_zero(nb), jx, jy, jz, (steps + 1 : U32), time)

# ---------------- pixels + image ----------------

def MC.cross(on: Bool, c: U32) -> U32:
  match on:
    case True{}:
      16777215
    case False{}:
      c

def MC.slot_block8(s: U32) -> U32:
  2

def MC.slot_block7(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      11
    case False{}:
      MC.slot_block8(s)

def MC.slot_block6(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      10
    case False{}:
      MC.slot_block7(U32.is_eq(s, 7), s)

def MC.slot_block5(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      5
    case False{}:
      MC.slot_block6(U32.is_eq(s, 6), s)

def MC.slot_block4(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      6
    case False{}:
      MC.slot_block5(U32.is_eq(s, 5), s)

def MC.slot_block3(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      9
    case False{}:
      MC.slot_block4(U32.is_eq(s, 4), s)

def MC.slot_block2(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      4
    case False{}:
      MC.slot_block3(U32.is_eq(s, 3), s)

def MC.slot_block1(eq: Bool, +s: U32) -> U32:
  match eq:
    case True{}:
      3
    case False{}:
      MC.slot_block2(U32.is_eq(s, 2), s)

# Mirrors PL.Hotbar.default slots [1,3,4,9,6,5,10,11,2].
def MC.slot_block(+s: U32) -> U32:
  MC.slot_block1(U32.is_eq(s, 1), s)

def MC.slot_color(x: U32, sel: U32) -> U32:
  +slot = U32.div(x, U32.div(MC.win_w(), 9))
  MC.cross(U32.is_eq(slot, sel), B.Block.color(MC.slot_block(slot)))

def MC.hud_go(is_hud: Bool, x: U32, sel: U32, vcolor: U32) -> U32:
  match is_hud:
    case True{}:
      MC.slot_color(x, sel)
    case False{}:
      vcolor

def MC.hud_bar() -> U32:
  (MC.win_h() - 10 : U32)

def MC.heart_top() -> U32:
  (MC.win_h() - 22 : U32)

def MC.heart_bot() -> U32:
  (MC.win_h() - 12 : U32)

def MC.half_w() -> U32:
  U32.div(MC.win_w(), 2)

def MC.cell_w() -> U32:
  U32.div(MC.win_w(), 20)

# Mob billboard: first mob whose 3D direction aligns with the ray.
def MC.mob_pick(hit: Bool, color: U32, prev: U32 & Bool) -> U32 & Bool:
  match hit:
    case True{}:
      (color, True{})
    case False{}:
      prev

def MC.mob_test(dist2: F32, dot: F32, color: U32, prev: U32 & Bool) -> U32 & Bool:
  MC.mob_pick(Bool.and(F32.is_lt(dist2, 576.0), F32.is_ge(dot, 0.9995)), color, prev)

def MC.mob_dot_len(ok: Bool, vx: F32, vy: F32, vz: F32, +d2: F32, +dx: F32, +dy: F32, +dz: F32, id: U32, prev: U32 & Bool) -> U32 & Bool:
  match ok:
    case True{}:
      +len = R.Render.nonzero(F32.sqrt(d2))
      MC.mob_test(d2, (((vx * dx : F32) + ((vy * dy : F32) + (vz * dz : F32) : F32) : F32) / len : F32), MB.Mob.color(id), prev)
    case False{}:
      prev

def MC.mob_dot_go(m: MB.Mob, ox: F32, oy: F32, oz: F32, +dx: F32, +dy: F32, +dz: F32, prev: U32 & Bool) -> U32 & Bool:
  match m:
    case MB.M{id, x, y, z, hp, seed}:
      +vx = (x - ox : F32)
      +vy = ((y + 0.5 : F32) - oy : F32)
      +vz = (z - oz : F32)
      +d2 = ((vx * vx : F32) + ((vy * vy : F32) + (vz * vz : F32) : F32) : F32)
      MC.mob_dot_len(F32.is_ge(d2, 0.0625), vx, vy, vz, d2, dx, dy, dz, id, prev)

def MC.mob_dot(+mobs: List<&2, MB.Mob>, +ox: F32, +oy: F32, +oz: F32, +dx: F32, +dy: F32, +dz: F32) -> U32 & Bool:
  match mobs:
    case Nil{}:
      (0, False{})
    case h <> t:
      MC.mob_dot_go(h, ox, oy, oz, dx, dy, dz, MC.mob_dot(t, ox, oy, oz, dx, dy, dz))

def MC.heart_ok(valid: Bool, full: Bool, base: U32) -> U32:
  match valid full:
    case True{} True{}:
      16711680
    case True{} False{}:
      3355443
    case False{} True{}:
      base
    case False{} False{}:
      base

def MC.heart_dot(+i: U32, hp: U32, base: U32) -> U32:
  MC.heart_ok(U32.is_lt(i, 10), U32.is_le((i * 2 : U32), hp), base)

def MC.food_dot(+j: U32, food: U32, base: U32) -> U32:
  MC.heart_ok(U32.is_lt(j, 10), U32.is_le((j * 2 : U32), food), base)

def MC.hearts_side(left: Bool, x: U32, hp: U32, food: U32, base: U32) -> U32:
  match left:
    case True{}:
      MC.heart_dot(U32.div(x, MC.cell_w()), hp, base)
    case False{}:
      MC.food_dot(U32.div((x - MC.half_w() : U32), MC.cell_w()), food, base)

def MC.post_hearts(is_row: Bool, +x: U32, hp: U32, food: U32, base: U32) -> U32:
  match is_row:
    case True{}:
      MC.hearts_side(U32.is_lt(x, MC.half_w()), x, hp, food, base)
    case False{}:
      base

def MC.post_flash(base: U32, hurt: U32) -> U32:
  R.Render.hurt_flash(base, hurt)

def MC.post_water(uw: Bool, c: U32) -> U32:
  match uw:
    case True{}:
      R.Render.water_tint(c)
    case False{}:
      c

def MC.pixel_post(+x: U32, +y: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, base: U32) -> U32:
  +c = MC.cross(R.Render.is_cross(x, y, MC.win_w(), MC.win_h()), base)
  +h = MC.hud_go(U32.is_ge(y, MC.hud_bar()), x, sel, c)
  +r = MC.post_hearts(Bool.and(U32.is_ge(y, MC.heart_top()), U32.is_lt(y, MC.heart_bot())), x, hp, food, h)
  MC.post_water(uw, MC.post_flash(r, hurt))

def MC.pixel_pick(hit: Bool, mc: U32, +seed: U32, +edits: List<&2, Edit>, ox: F32, oy: F32, oz: F32, +dx: F32, +dy: F32, +dz: F32, +x: U32, +y: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> U32:
  match hit:
    case True{}:
      MC.pixel_post(x, y, sel, hp, food, hurt, uw, mc)
    case False{}:
      MC.pixel_post(x, y, sel, hp, food, hurt, uw, MC.march(48n, seed, edits, ox, oy, oz, dx, dy, dz, 0, True{}, 0, 0, 0, 0, time))

def MC.pixel_mob(mhit: U32 & Bool, +seed: U32, +edits: List<&2, Edit>, ox: F32, oy: F32, oz: F32, +dx: F32, +dy: F32, +dz: F32, +x: U32, +y: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> U32:
  (mc, mh) = mhit
  MC.pixel_pick(mh, mc, seed, edits, ox, oy, oz, dx, dy, dz, x, y, sel, hp, food, hurt, uw, time)

def MC.pixel_go(+seed: U32, +edits: List<&2, Edit>, +mobs: List<&2, MB.Mob>, r: R.Ray, +x: U32, +y: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> U32:
  match r:
    case R.R{+ox, +oy, +oz, +dx, +dy, +dz}:
      MC.pixel_mob(MC.mob_dot(mobs, ox, oy, oz, dx, dy, dz), seed, edits, ox, oy, oz, dx, dy, dz, x, y, sel, hp, food, hurt, uw, time)

def MC.pixel(+seed: U32, +edits: List<&2, Edit>, +mobs: List<&2, MB.Mob>, +cam: R.Cam, +x: U32, +y: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> U32:
  MC.pixel_go(seed, edits, mobs, R.Render.pixel_ray(cam, U32.to_f32(x), U32.to_f32(y), MC.win_w(), MC.win_h()), x, y, sel, hp, food, hurt, uw, time)

def MC.build(+seed: U32, +edits: List<&2, Edit>, +mobs: List<&2, MB.Mob>, +cam: R.Cam, +size: Nat, +x0: U32, +y0: U32, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> Image:
  match size:
    case 0n:
      Pix{MC.pixel(seed, edits, mobs, cam, x0, y0, sel, hp, food, hurt, uw, time)}
    case 1n+s:
      +half = U32.pow(2, s)
      +x1 = (x0 + half : U32)
      +y1 = (y0 + half : U32)
      tl tr = MC.build(seed, edits, mobs, cam, s, x0, y0, sel, hp, food, hurt, uw, time) MC.build(seed, edits, mobs, cam, s, x1, y0, sel, hp, food, hurt, uw, time)
      bl br = MC.build(seed, edits, mobs, cam, s, x0, y1, sel, hp, food, hurt, uw, time) MC.build(seed, edits, mobs, cam, s, x1, y1, sel, hp, food, hurt, uw, time)
      Qua{tl, tr, bl, br}

def MC.frame(+seed: U32, +edits: List<&2, Edit>, +mobs: List<&2, MB.Mob>, +cam: R.Cam, +sel: U32, +hp: U32, +food: U32, +hurt: U32, +uw: Bool, +time: F32) -> Image:
  MC.build(seed, edits, mobs, cam, MC.quality(), 0, 0, sel, hp, food, hurt, uw, time)

# ---------------- view ----------------

def MC.view_cam(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, sel: U32, uw: Bool, cam: R.Cam) -> Pair(State, Image):
  (S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}, MC.frame(seed, edits, mobs, cam, sel, hp, food, hurt, uw, time))

def MC.view_go(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, sel: U32) -> Pair(State, Image):
  MC.view_cam(seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time, sel, MC.eye_water(seed, edits, px, py, pz), R.Render.cam_from(px, py, pz, yaw, pitch, 1.2))

def view(state: State) -> Pair(State, Image):
  match state:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.view_go(seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time, PL.Hotbar.selected(hb))

# ---------------- physics + movement ----------------

def MC.cap_x(lt: Bool, ux: U32) -> U32:
  match lt:
    case True{}:
      ux
    case False{}:
      63

def MC.clamp_xz(v: F32) -> U32:
  +ux = F32.to_u32(v)
  MC.cap_x(U32.is_lt(ux, 64), ux)

def MC.ground_y(+seed: U32, px: F32, pz: F32) -> F32:
  (U32.to_f32(W.World.height_full(seed, MC.clamp_xz(px), MC.clamp_xz(pz))) + 1.0 : F32)

def MC.do_look(s: State, dx: F32, dy: F32) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, (yaw + dx : F32), F32.clamp((pitch + dy : F32), (0.0 - 1.57 : F32), 1.57), vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.hot_go(lt: Bool, hb: PL.Hotbar, hot: U32) -> PL.Hotbar:
  match lt:
    case True{}:
      PL.Hotbar.select(hb, hot)
    case False{}:
      hb

def MC.do_hot(s: State, +hot: U32) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, MC.hot_go(U32.is_lt(hot, 9), hb, hot), edits, hp, food, hurt, mobs, tickn, time}

def MC.move_apply(s: State, dx: F32, dz: F32) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, (px + dx : F32), py, (pz + dz : F32), yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.do_strafe(s: State, +side: F32) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      +sx = F32.sin(yaw)
      +cx = F32.cos(yaw)
      MC.move_apply(S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}, (F32.neg(cx) * side : F32), (sx * side : F32))

def MC.spd_snk(snk: Bool) -> F32:
  match snk:
    case True{}:
      0.15
    case False{}:
      0.3

def MC.spd_pick(spr: Bool, snk: Bool) -> F32:
  match spr:
    case True{}:
      0.45
    case False{}:
      MC.spd_snk(snk)

def MC.spd(spr: Bool, snk: Bool) -> F32:
  MC.spd_pick(spr, snk)

def MC.mv_side(l: Bool, r: Bool, spd: F32) -> F32:
  match l r:
    case True{} False{}:
      (0.0 - spd : F32)
    case False{} True{}:
      spd
    case True{} True{}:
      0.0
    case False{} False{}:
      0.0

def MC.mv_fwd(f: Bool, b: Bool, spd: F32) -> F32:
  match f b:
    case True{} False{}:
      spd
    case False{} True{}:
      (0.0 - spd : F32)
    case True{} True{}:
      0.0
    case False{} False{}:
      0.0

def MC.do_move(s: State, f: Bool, b: Bool, l: Bool, r: Bool, +spd: F32) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      +fw = MC.mv_fwd(f, b, spd)
      +sd = MC.mv_side(l, r, spd)
      +cy = F32.cos(yaw)
      +sy = F32.sin(yaw)
      +nsy = F32.neg(sy)
      +ncy = F32.neg(cy)
      MC.move_apply(S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}, ((nsy * fw : F32) + (ncy * sd : F32) : F32), ((ncy * fw : F32) + (sy * sd : F32) : F32))

def MC.fly_go(fly: Bool, s: State) -> State:
  match fly:
    case True{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly2, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          S{seed, px, py, pz, yaw, pitch, vy, og, Bool.not(fly2), hb, edits, hp, food, hurt, mobs, tickn, time}
    case False{}:
      s

def MC.do_fly(s: State, tog: Bool) -> State:
  MC.fly_go(tog, s)

def MC.jump_og(og: Bool, s: State) -> State:
  match og:
    case True{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og2, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          S{seed, px, py, pz, yaw, pitch, 1.2, False{}, fly, hb, edits, hp, food, hurt, mobs, tickn, time}
    case False{}:
      s

def MC.jump_ground(jump: Bool, s: State) -> State:
  match jump:
    case True{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          MC.jump_og(og, S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time})
    case False{}:
      s

def MC.jump_ud(jump: Bool, down: Bool, s: State) -> State:
  match jump down:
    case True{} False{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          S{seed, px, (py + 0.5 : F32), pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}
    case False{} True{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          S{seed, px, (py - 0.5 : F32), pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}
    case True{} True{}:
      s
    case False{} False{}:
      s

def MC.jump_fly(fly: Bool, s: State, jump: Bool, down: Bool) -> State:
  match fly:
    case True{}:
      match s:
        case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly2, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
          MC.jump_ud(jump, down, S{seed, px, py, pz, yaw, pitch, vy, og, fly2, hb, edits, hp, food, hurt, mobs, tickn, time})
    case False{}:
      MC.jump_ground(jump, s)

def MC.do_jump(s: State, jump: Bool, down: Bool) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.jump_fly(fly, S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}, jump, down)

def MC.term_v(lt: Bool, v: F32) -> F32:
  match lt:
    case True{}:
      (0.0 - 1.5 : F32)
    case False{}:
      v

def MC.hp_go(ok: Bool, hp: U32, dmg: U32) -> U32:
  match ok:
    case True{}:
      (hp - dmg : U32)
    case False{}:
      0

def MC.hp_sub(+hp: U32, +dmg: U32) -> U32:
  MC.hp_go(U32.is_ge(hp, dmg), hp, dmg)

def MC.landed_hp(no_dmg: Bool, +seed: U32, px: F32, pz: F32, +yaw: F32, +pitch: F32, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, gy: F32, dmg: U32) -> State:
  match no_dmg:
    case True{}:
      S{seed, px, gy, pz, yaw, pitch, 0.0, True{}, fly, hb, edits, hp, food, hurt, mobs, tickn, time}
    case False{}:
      S{seed, px, gy, pz, yaw, pitch, 0.0, True{}, fly, hb, edits, MC.hp_sub(hp, dmg), food, 10, mobs, tickn, time}

def MC.landed(land: Bool, +seed: U32, px: F32, pz: F32, +yaw: F32, +pitch: F32, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, new_py: F32, new_vy: F32, gy: F32, v2: F32) -> State:
  match land:
    case True{}:
      +dmg = PH.Physics.fall_damage(((0.0 - v2 : F32) * 4.0 : F32))
      MC.landed_hp(U32.is_zero(dmg), seed, px, pz, yaw, pitch, fly, hb, edits, hp, food, hurt, mobs, tickn, time, gy, dmg)
    case False{}:
      S{seed, px, new_py, pz, yaw, pitch, new_vy, False{}, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.fall_step(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  +v2 = MC.term_v(F32.is_lt((vy - 0.3 : F32), (0.0 - 1.5 : F32)), (vy - 0.3 : F32))
  +np = (py + v2 : F32)
  +gy = MC.ground_y(seed, px, pz)
  MC.landed(F32.is_lt(np, gy), seed, px, pz, yaw, pitch, fly, hb, edits, hp, food, hurt, mobs, tickn, time, np, v2, gy, v2)

def MC.phys_fly(fly: Bool, +seed: U32, px: F32, py: F32, pz: F32, +yaw: F32, +pitch: F32, vy: F32, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  match fly:
    case True{}:
      S{seed, px, py, pz, yaw, pitch, 0.0, True{}, fly, hb, edits, hp, food, hurt, mobs, tickn, time}
    case False{}:
      MC.fall_step(seed, px, py, pz, yaw, pitch, vy, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

def MC.do_phys(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.phys_fly(fly, seed, px, py, pz, yaw, pitch, vy, hb, edits, hp, food, hurt, mobs, tickn, time)

# ---------------- break / place ----------------

def MC.march_idx(fuel: Nat, ex: F32, ey: F32, ez: F32, fx: F32, fy: F32, fz: F32) -> U32:
  match fuel:
    case 0n:
      MC.flat_idx(F32.to_u32(ex), F32.to_u32(ey), F32.to_u32(ez))
    case 1n+f:
      +ax = fx
      +ay = fy
      +az = fz
      MC.march_idx(f, (ex + (ax * 0.2 : F32) : F32), (ey + (ay * 0.2 : F32) : F32), (ez + (az * 0.2 : F32) : F32), ax, ay, az)

def MC.target_idx(px: F32, py: F32, pz: F32, +yaw: F32, +pitch: F32) -> U32:
  +cy = F32.cos(yaw)
  +sy = F32.sin(yaw)
  +cp = F32.cos(pitch)
  +sp = F32.sin(pitch)
  +nsy = F32.neg(sy)
  +ncy = F32.neg(cy)
  MC.march_idx(30n, px, (py + 1.6 : F32), pz, (nsy * cp : F32), sp, (ncy * cp : F32))

def MC.brk_go(ok: Bool, +edits: List<&2, Edit>, idx: U32) -> List<&2, Edit>:
  match ok:
    case True{}:
      MC.push(edits, idx, 0)
    case False{}:
      edits

def MC.brk_fin(ok: Bool, +seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, idx: U32) -> State:
  S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, MC.brk_go(ok, edits, idx), hp, food, hurt, mobs, tickn, time}

def MC.brk_with(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  +idx = MC.target_idx(px, py, pz, yaw, pitch)
  +x = U32.mod(idx, 64)
  +t = U32.div(idx, 64)
  +z = U32.mod(t, 64)
  +y = U32.div(t, 64)
  +b = MC.voxel(seed, edits, x, y, z)
  MC.brk_fin(Bool.and(PH.Physics.blocked(b), Bool.not(U32.is_eq(b, 8))), seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time, idx)

def MC.do_break(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.brk_with(seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

def MC.plc_go(empty: Bool, +edits: List<&2, Edit>, idx: U32, blk: U32) -> List<&2, Edit>:
  match empty:
    case True{}:
      MC.push(edits, idx, blk)
    case False{}:
      edits

def MC.plc_fin(empty: Bool, +seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32, idx: U32) -> State:
  S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, MC.plc_go(empty, edits, idx, PL.Hotbar.selected(hb)), hp, food, hurt, mobs, tickn, time}

def MC.plc_with(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  +idx = MC.target_idx(px, py, pz, yaw, pitch)
  +x = U32.mod(idx, 64)
  +t = U32.div(idx, 64)
  +z = U32.mod(t, 64)
  +y = U32.div(t, 64)
  +b = MC.voxel(seed, edits, x, y, z)
  MC.plc_fin(U32.is_eq(b, 0), seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time, idx)

def MC.do_place(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.plc_with(seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

def MC.time_wrap(ge: Bool, t: F32) -> F32:
  match ge:
    case True{}:
      (t - 1.0 : F32)
    case False{}:
      t

def MC.do_time(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      +nt = (time + 0.002 : F32)
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, MC.time_wrap(F32.is_ge(nt, 1.0), nt)}

# ---------------- mobs: adopt / step / attack ----------------

def MC.night(+time: F32) -> Bool:
  Bool.or(F32.is_lt(time, 0.2), F32.is_ge(time, 0.7))

def MC.adopt(l: List<MB.Mob>) -> List<&2, MB.Mob>:
  match l:
    case Nil{}:
      Nil{}
    case h <> t:
      h <> MC.adopt(t)

def MC.step_one_go(dead: Bool, nm: MB.Mob, rec: List<&2, MB.Mob>) -> List<&2, MB.Mob>:
  match dead:
    case True{}:
      rec
    case False{}:
      nm <> rec

def MC.step_mobs(+l: List<&2, MB.Mob>, +px: F32, +pz: F32, +night: Bool, +tick: U32) -> List<&2, MB.Mob>:
  match l:
    case Nil{}:
      Nil{}
    case h <> t:
      +nm = MB.Mob.step_one(h, px, pz, night, tick)
      MC.step_one_go(MB.Mob.dead(nm), nm, MC.step_mobs(t, px, pz, night, tick))

def MC.atk_hit(close: Bool, m: MB.Mob, rec: List<&2, MB.Mob>) -> List<&2, MB.Mob>:
  match close:
    case True{}:
      MB.Mob.hurt(m, 4) <> rec
    case False{}:
      m <> rec

def MC.atk_one(m: MB.Mob, +px: F32, +py: F32, +pz: F32, rec: List<&2, MB.Mob>) -> List<&2, MB.Mob>:
  match m:
    case MB.M{id, +x, +y, +z, hp, seed}:
      +dx = (x - px : F32)
      +dy = (y - py : F32)
      +dz = (z - pz : F32)
      +d2 = ((dx * dx : F32) + (dz * dz : F32) : F32)
      +ad = F32.max(dy, (0.0 - dy : F32))
      MC.atk_hit(Bool.and(F32.is_lt(d2, 20.25), F32.is_lt(ad, 3.0)), MB.M{id, x, y, z, hp, seed}, rec)

def MC.attack_mobs(+l: List<&2, MB.Mob>, +px: F32, +py: F32, +pz: F32) -> List<&2, MB.Mob>:
  match l:
    case Nil{}:
      Nil{}
    case h <> t:
      MC.atk_one(h, px, py, pz, MC.attack_mobs(t, px, py, pz))

def MC.atk_go(atk: Bool, +seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  match atk:
    case True{}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, MC.attack_mobs(mobs, px, py, pz), tickn, time}
    case False{}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.do_atk(s: State, atk: Bool) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.atk_go(atk, seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

# ---------------- survival: food / regen / starve / hurt / death ----------------

def MC.food_pick(drain: Bool, food: U32) -> U32:
  match drain:
    case True{}:
      (food - 1 : U32)
    case False{}:
      food

def MC.do_food(s: State, moving: Bool) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, MC.food_pick(Bool.and(Bool.and(moving, U32.is_zero(U32.mod(tickn, 200))), U32.is_gt(food, 0)), food), hurt, mobs, tickn, time}

def MC.regen_pick(grow: Bool, hp: U32) -> U32:
  match grow:
    case True{}:
      (hp + 1 : U32)
    case False{}:
      hp

def MC.do_regen(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, MC.regen_pick(Bool.and(Bool.and(U32.is_ge(food, 18), U32.is_lt(hp, 20)), U32.is_zero(U32.mod(tickn, 100))), hp), food, hurt, mobs, tickn, time}

def MC.starve_go(starving: Bool, +seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  match starving:
    case True{}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, MC.hp_sub(hp, 1), food, 10, mobs, tickn, time}
    case False{}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.do_starve(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.starve_go(Bool.and(U32.is_zero(food), U32.is_zero(U32.mod(tickn, 200))), seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

def MC.hurt_pick(fading: Bool, hurt: U32) -> U32:
  match fading:
    case True{}:
      (hurt - 1 : U32)
    case False{}:
      hurt

def MC.do_hurt(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, MC.hurt_pick(U32.is_gt(hurt, 0), hurt), mobs, tickn, time}

def MC.do_tickn(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, (tickn + 1 : U32), time}

def MC.death_go(dead: Bool, +seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +pitch: F32, +vy: F32, +og: Bool, +fly: Bool, +hb: PL.Hotbar, +edits: List<&2, Edit>, +hp: U32, +food: U32, +hurt: U32, +mobs: List<&2, MB.Mob>, +tickn: U32, +time: F32) -> State:
  match dead:
    case True{}:
      +gy = MC.ground_y(seed, 32.5, 32.5)
      S{seed, 32.5, (gy + 2.0 : F32), 32.5, 0.0, 0.0, 0.0, False{}, fly, hb, edits, 20, 20, 0, mobs, tickn, time}
    case False{}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time}

def MC.do_death(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      MC.death_go(U32.is_zero(hp), seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, mobs, tickn, time)

def MC.do_mobs(s: State) -> State:
  match s:
    case S{+seed, +px, +py, +pz, +yaw, +pitch, +vy, +og, +fly, +hb, +edits, +hp, +food, +hurt, +mobs, +tickn, +time}:
      S{seed, px, py, pz, yaw, pitch, vy, og, fly, hb, edits, hp, food, hurt, MC.step_mobs(mobs, px, pz, MC.night(time), tickn), tickn, time}

# ---------------- tick ----------------

def MC.a_break(do_it: Bool, s: State) -> State:
  match do_it:
    case True{}:
      MC.do_break(s)
    case False{}:
      s

def MC.a_place(do_it: Bool, s: State) -> State:
  match do_it:
    case True{}:
      MC.do_place(s)
    case False{}:
      s

def MC.apply(+fw: Bool, +back: Bool, +left: Bool, +right: Bool, jump: Bool, down: Bool, brk: Bool, plc: Bool, flytog: Bool, spr: Bool, snk: Bool, atk: Bool, hot: U32, yd: F32, pd: F32, s: State) -> State:
  +mv = Bool.or(Bool.or(fw, back), Bool.or(left, right))
  MC.do_time(MC.do_mobs(MC.do_death(MC.do_tickn(MC.do_hurt(MC.do_starve(MC.do_regen(MC.do_food(MC.a_place(plc, MC.a_break(brk, MC.do_atk(MC.do_phys(MC.do_jump(MC.do_fly(MC.do_move(MC.do_hot(MC.do_look(s, yd, pd), hot), fw, back, left, right, MC.spd(spr, snk)), flytog), jump, down)), atk))), mv))))))))

def MC.tq(quit: Bool, fw: Bool, back: Bool, left: Bool, right: Bool, jump: Bool, down: Bool, brk: Bool, plc: Bool, flytog: Bool, spr: Bool, snk: Bool, atk: Bool, hot: U32, yd: F32, pd: F32, s: State) -> IO(Maybe<State>):
  match quit:
    case True{}:
      IO.pure(Maybe<State>, None{})
    case False{}:
      IO.pure(Maybe<State>, Some{MC.apply(fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, yd, pd, s)})

def MC.tick_go(a: Acc, s: State) -> IO(Maybe<State>):
  match a:
    case A{+fw, +back, +left, +right, +jump, +down, +brk, +plc, +flytog, +spr, +snk, +atk, +hot, +quit, +yd, +pd}:
      MC.tq(quit, fw, back, left, right, jump, down, brk, plc, flytog, spr, snk, atk, hot, yd, pd, s)

def tick(events: List<Event>, state: State) -> IO(Maybe<State>):
  MC.tick_go(MC.fold(events, MC.acc_empty()), state)

# ---------------- spawn + main ----------------

def MC.spawn_go(+seed: U32, gy: F32) -> State:
  S{seed, 32.5, (gy + 2.0 : F32), 32.5, 0.0, 0.0, 0.0, False{}, False{}, PL.Hotbar.default(), Nil{}, 20, 20, 0, MC.adopt(MB.Mob.spawn(seed, 6n, False{})), 0, 0.3}

def MC.spawn(seed: U32) -> State:
  +s = seed
  MC.spawn_go(s, MC.ground_y(s, 32.5, 32.5))

def main() -> IO(Unit):
  App.run(~State, ~App{view, tick}, "BendCraft", MC.win_w(), MC.win_h(), MC.spawn(1337))

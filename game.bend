import Base

# game.bend — App wiring + main for BendCraft (standalone-checkable).
# Only import is Base; sibling shims (Game.*) mirror real modules so this
# file checks NOW; integrator swaps Game.gen -> W.World.gen,
# fallback_view -> R.Render.frame, etc., without changing view/tick types.
#
# App model: App.run(~S, ~app: App<S>, title, width, height, state) where
#   App{view: S -> Pair(S, Image), tick: List<Event> -> S -> IO(Maybe<S>)},
# view returns state beside image (affine), tick returns IO Maybe (None quits).
# Bend rules obeyed: affine (world Array threaded linearly, Data fields via +),
# termination-checked (recursion on Nat fuel first + List tail first),
# match only params/bound vars (computed Bools via helper defs, no if),
# Nat literals like 3n/8n/17n/30n, ops spaced+annotated (a + b : U32/F32).
#
# Controls (Key codes, down=True acts):
#   W/119/87 fwd, S/115/83 back, A/97/65 left, D/100/68 right (0.5 = 10*0.05,
#   dt 0.05 walk speed 10), Space/32 jump (vy 2.0) or fly-up, E/101/69 break,
#   Q/113/81 place (sel+1), F/102/70 fly toggle, 1-8/49-56 sel 0-7,
#   Left/37 Right/39 yaw +-0.1, Up/38 Down/40 pitch +-0.1, Close quits.
#   Mouse/Move ignored (kept for Ctrl.fold compat). Esc/27 unused (Close quits).
# HUD (App.run owns window, no IO.print at startup): fallback_view 256x256
# depth 8n quadtree, sky day 8900331/night 725030 by time<0.5, ground grass
# 6142012, crosshair white 16777215 at 128,128, bottom 16 rows (y>=240)
# hotbar 8x32px slots sel white highlight else slot+10.
# Physics: gravity vy-0.02, ground clamp flat 9.0 (fallback; world height
# lookup via World.get_xyz available, flat used to avoid mutual recursion).
# Break/place: eye (py+1.6) + dir(yaw/pitch cos/sin) marched 30n*0.2=6 blocks
# via Game.march fuel Nat, final Array.get (solid/air check) + Array.set
# threading world linearly. Time +=0.001 wrap at 1.0. Render.frame path:
#   cam = R.Render.cam_from(px,py,pz,yaw,pitch,fov) + R.Render.frame(~get,~color_of,cam,time)
# with ~get (x y z => World.get_xyz) ~color_of B.Block.color — swap view_img.

type Hud is Data:
  H{hp: U32, food: U32, armor: U32, xp: U32, level: U32, air: U32}

type Mode is Data:
  Menu{}
  Play{}
  Pause{}
  Dead{}

type GameState is Type:
  G{world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32}

# --- Survival HUD model (pure helpers, Data) ---

def Hud.full() -> Hud:
  H{20, 20, 0, 0, 0, 10}

def Hud.damage_go(hit: Bool, +food: U32, +armor: U32, +xp: U32, +level: U32, +air: U32, +hp: U32, +dmg: U32) -> Hud:
  match hit:
    case True{}:
      H{(hp - dmg : U32), food, armor, xp, level, air}
    case False{}:
      H{0, food, armor, xp, level, air}

def Hud.damage(hud: Hud, +dmg: U32) -> Hud:
  match hud:
    case H{+hp, +food, +armor, +xp, +level, +air}:
      Hud.damage_go(U32.is_le(dmg, hp), food, armor, xp, level, air, hp, dmg)

def Hud.heal_cap(over: Bool, +food: U32, +armor: U32, +xp: U32, +level: U32, +air: U32, +hp: U32, +amt: U32) -> Hud:
  match over:
    case True{}:
      H{20, food, armor, xp, level, air}
    case False{}:
      H{(hp + amt : U32), food, armor, xp, level, air}

def Hud.heal(hud: Hud, +amt: U32) -> Hud:
  match hud:
    case H{+hp, +food, +armor, +xp, +level, +air}:
      Hud.heal_cap(U32.is_gt((hp + amt : U32), 20), food, armor, xp, level, air, hp, amt)

def Hud.eat_cap(over: Bool, +hp: U32, +armor: U32, +xp: U32, +level: U32, +air: U32, +food: U32, +amt: U32) -> Hud:
  match over:
    case True{}:
      H{hp, 20, armor, xp, level, air}
    case False{}:
      H{hp, (food + amt : U32), armor, xp, level, air}

def Hud.eat(hud: Hud, +amt: U32) -> Hud:
  match hud:
    case H{+hp, +food, +armor, +xp, +level, +air}:
      Hud.eat_cap(U32.is_gt((food + amt : U32), 20), hp, armor, xp, level, air, food, amt)

def Hud.breathe_sub(empty: Bool, +hp: U32, +food: U32, +armor: U32, +xp: U32, +level: U32, +air: U32) -> Hud:
  match empty:
    case True{}:
      H{hp, food, armor, xp, level, 0}
    case False{}:
      H{hp, food, armor, xp, level, (air - 1 : U32)}

def Hud.breathe_go(uw: Bool, hud: Hud) -> Hud:
  match uw:
    case True{}:
      match hud:
        case H{+hp, +food, +armor, +xp, +level, +air}:
          Hud.breathe_sub(U32.is_zero(air), hp, food, armor, xp, level, air)
    case False{}:
      match hud:
        case H{+hp, +food, +armor, +xp, +level, +air}:
          H{hp, food, armor, xp, level, 10}

def Hud.breathe(hud: Hud, uw: Bool) -> Hud:
  Hud.breathe_go(uw, hud)

def Hud.xp_add_go(levelup: Bool, +hp: U32, +food: U32, +armor: U32, +level: U32, +air: U32, +xp: U32, +amt: U32) -> Hud:
  match levelup:
    case True{}:
      H{hp, food, armor, ((xp + amt : U32) - 100 : U32), (level + 1 : U32), air}
    case False{}:
      H{hp, food, armor, (xp + amt : U32), level, air}

def Hud.xp_add(hud: Hud, +amt: U32) -> Hud:
  match hud:
    case H{+hp, +food, +armor, +xp, +level, +air}:
      Hud.xp_add_go(U32.is_ge((xp + amt : U32), 100), hp, food, armor, level, air, xp, amt)

def Hud.xp_level(hud: Hud) -> U32:
  match hud:
    case H{hp, food, armor, xp, level, air}:
      level

# --- Pause/death/mode (pure, Data) ---

def Game.is_p(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 80), U32.is_eq(code, 112))

def Game.is_esc(+code: U32) -> Bool:
  U32.is_eq(code, 27)

def Game.is_r(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 82), U32.is_eq(code, 114))

def Game.is_pause_key(+code: U32) -> Bool:
  Bool.or(Game.is_p(code), Game.is_esc(code))

def Game.mode_toggle(mode: Mode) -> Mode:
  match mode:
    case Play{}:
      Pause{}
    case Pause{}:
      Play{}
    case Menu{}:
      Menu{}
    case Dead{}:
      Dead{}

def Game.mode_toggle_go(do_tog: Bool, mode: Mode) -> Mode:
  match do_tog:
    case True{}:
      Game.mode_toggle(mode)
    case False{}:
      mode

def Game.mode_respawn_go(do_it: Bool, mode: Mode) -> Mode:
  match do_it:
    case True{}:
      Play{}
    case False{}:
      mode

def Game.mode_respawn_key(is_rk: Bool, mode: Mode, down: Bool) -> Mode:
  match is_rk:
    case True{}:
      Game.mode_respawn_go(down, mode)
    case False{}:
      mode

def Game.is_deadmode(mode: Mode) -> Bool:
  match mode:
    case Dead{}:
      True{}
    case Play{}:
      False{}
    case Pause{}:
      False{}
    case Menu{}:
      False{}

def Game.mode_key_dead(is_deadmode: Bool, +code: U32, mode: Mode, down: Bool) -> Mode:
  match is_deadmode:
    case True{}:
      Game.mode_respawn_key(Game.is_r(code), mode, down)
    case False{}:
      Game.mode_toggle_go(Bool.and(down, Game.is_pause_key(code)), mode)

def Game.mode_key(+mode: Mode, +code: U32, down: Bool) -> Mode:
  Game.mode_key_dead(Game.is_deadmode(mode), code, mode, down)

def Game.in_menu(mode: Mode) -> Bool:
  match mode:
    case Menu{}:
      True{}
    case Play{}:
      False{}
    case Pause{}:
      False{}
    case Dead{}:
      False{}

def Game.pause_dim(base: U32) -> U32:
  U32.div(base, 2)

def Game.dead_tint(base: U32) -> U32:
  U32.or(base, 16711680)

def Game.is_dead(hud: Hud) -> Bool:
  match hud:
    case H{hp, food, armor, xp, level, air}:
      U32.is_zero(hp)

# --- Selected-item flash timer (pure) ---

def Game.flash_go(empty: Bool, +name: String) -> String:
  match empty:
    case True{}:
      SNil{}
    case False{}:
      name

def Game.flash(+name: String, ticks: U32) -> String:
  Game.flash_go(U32.is_zero(ticks), name)

def Game.flash_tick_go(empty: Bool, +ticks: U32) -> U32:
  match empty:
    case True{}:
      0
    case False{}:
      (ticks - 1 : U32)

def Game.flash_tick(+ticks: U32) -> U32:
  Game.flash_tick_go(U32.is_zero(ticks), ticks)

# --- HUD strip rendering (pure, pick-based, no mutual) ---

def Game.in_range(+v: U32, +lo: U32, +hi: U32) -> Bool:
  Bool.and(U32.is_ge(v, lo), U32.is_lt(v, hi))

def Game.in_hearts(+x: U32, +y: U32) -> Bool:
  Bool.and(Game.in_range(y, 224, 232), Game.in_range(x, 8, 168))

def Game.in_hunger(+x: U32, +y: U32) -> Bool:
  Bool.and(Game.in_range(y, 232, 240), Game.in_range(x, 8, 168))

def Game.in_armor(+x: U32, +y: U32) -> Bool:
  Bool.and(Game.in_range(y, 216, 224), Game.in_range(x, 8, 168))

def Game.in_xp(+x: U32, +y: U32) -> Bool:
  Bool.and(Game.in_range(y, 240, 242), Game.in_range(x, 0, 256))

def Game.in_air(+x: U32, +y: U32) -> Bool:
  Bool.and(Game.in_range(y, 208, 216), Game.in_range(x, 8, 168))

def Game.heart_need(+x: U32) -> U32:
  dx = (x - 8 : U32)
  hi = U32.div(dx, 16)
  hi1 = (hi + 1 : U32)
  (hi1 * 2 : U32)

def Game.heart_filled(+x: U32, +hp: U32) -> Bool:
  U32.is_le(Game.heart_need(x), hp)

def Game.heart_color(filled: Bool) -> U32:
  match filled:
    case True{}:
      16711680
    case False{}:
      3355443

def Game.hunger_filled(+x: U32, +food: U32) -> Bool:
  U32.is_le(Game.heart_need(x), food)

def Game.hunger_color(filled: Bool) -> U32:
  match filled:
    case True{}:
      9127188
    case False{}:
      3355443

def Game.armor_idx(+x: U32) -> U32:
  U32.div((x - 8 : U32), 16)

def Game.armor_filled(+x: U32, +armor: U32) -> Bool:
  U32.is_lt(Game.armor_idx(x), armor)

def Game.armor_color(filled: Bool) -> U32:
  match filled:
    case True{}:
      12632256
    case False{}:
      3355443

def Game.xp_len(+xp: U32) -> U32:
  (xp * 2 : U32)

def Game.xp_filled(+x: U32, +xp: U32) -> Bool:
  U32.is_lt(x, Game.xp_len(xp))

def Game.air_idx(+x: U32) -> U32:
  U32.div((x - 8 : U32), 16)

def Game.air_filled(+x: U32, +air: U32) -> Bool:
  U32.is_lt(Game.air_idx(x), air)

def Game.is_under(+air: U32) -> Bool:
  U32.is_lt(air, 10)

def Game.hud_pixel(+x: U32, +y: U32, hud: Hud, +sel: U32, base: U32) -> U32:
  match hud:
    case H{+hp, +food, +armor, +xp, +level, +air}:
      +ih = Game.in_hearts(x, y)
      +ihf = Game.heart_filled(x, hp)
      +ihc = Bool.pick(U32, ihf, 16711680, 3355443)
      +p1 = Bool.pick(U32, ih, ihc, base)
      +iu = Game.in_hunger(x, y)
      +iuf = Game.hunger_filled(x, food)
      +iuc = Bool.pick(U32, iuf, 9127188, 3355443)
      +p2 = Bool.pick(U32, iu, iuc, p1)
      +ia = Game.in_armor(x, y)
      +hasa = U32.is_gt(armor, 0)
      +iah = Bool.and(ia, hasa)
      +iaf = Game.armor_filled(x, armor)
      +iac = Bool.pick(U32, iaf, 12632256, 3355443)
      +p3 = Bool.pick(U32, iah, iac, p2)
      +ix = Game.in_xp(x, y)
      +ixf = Game.xp_filled(x, xp)
      +ixb = Bool.and(ix, ixf)
      +p4 = Bool.pick(U32, ixb, 65280, p3)
      +ir = Game.in_air(x, y)
      +und = Game.is_under(air)
      +iru = Bool.and(ir, und)
      +irf = Game.air_filled(x, air)
      +irc = Bool.pick(U32, irf, 4197597, 3355443)
      Bool.pick(U32, iru, irc, p4)

def Game.mode_tint(mode: Mode, base: U32) -> U32:
  match mode:
    case Menu{}:
      base
    case Play{}:
      base
    case Pause{}:
      Game.pause_dim(base)
    case Dead{}:
      Game.dead_tint(base)

def Game.menu_band(+y: U32) -> Bool:
  Game.in_range(y, 120, 136)

def Game.menu_dots(+x: U32, +y: U32) -> Bool:
  Bool.and(U32.is_eq(y, 100), U32.is_eq(U32.mod(x, 16), 0))

def Game.menu_pixel_dots(dots: Bool, +y: U32) -> U32:
  match dots:
    case True{}:
      16777215
    case False{}:
      (9127188 + y : U32)

def Game.menu_pixel_go(band: Bool, dots: Bool, +y: U32) -> U32:
  match band:
    case True{}:
      16777215
    case False{}:
      Game.menu_pixel_dots(dots, y)

def Game.menu_pixel(+x: U32, +y: U32) -> U32:
  Game.menu_pixel_go(Game.menu_band(y), Game.menu_dots(x, y), y)

def Game.menu_view(+d: Nat, +x: U32, +y: U32) -> Image:
  match d:
    case 0n:
      Pix{Game.menu_pixel(x, y)}
    case 1n+p:
      +half = U32.pow(2, p)
      a b = Game.menu_view(p, x, y) Game.menu_view(p, (x + half : U32), y)
      c e = Game.menu_view(p, x, (y + half : U32)) Game.menu_view(p, (x + half : U32), (y + half : U32))
      Qua{a, b, c, e}

def Game.respawn(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      G{world, 32.5, 20.0, 32.5, 0.0, 0.0, 0.0, False{}, False{}, sel, time, seed, Hud.full(), Play{}, tickn, 0}

def Game.hash(seed: U32, x: U32, z: U32) -> U32:
  t1 = U32.mul(x, 374761393)
  t2 = U32.mul(z, 668265263)
  t3 = U32.xor(seed, t1)
  +h = U32.xor(t3, t2)
  s = U32.shrn(h, 13n)
  q = U32.xor(h, s)
  U32.mul(q, 1274126177)

def Game.height_at(seed: U32, x: U32, z: U32) -> U32:
  h = Game.hash(seed, x, z)
  m = U32.mod(h, 10)
  (10 + m : U32)

# F3 debug (pure): coords/facing/biome/fps. Uses height_at above; F32.show is
# a law (native-only) but type-correct pure here; U32.show reduces in checker.
def Game.debug_part_seed(+seed: U32) -> String:
  String.append("seed:", U32.show(seed))

def Game.debug_part_px(+px: F32) -> String:
  String.append(",px:", F32.show(px))

def Game.debug_part_py(+py: F32) -> String:
  String.append(",py:", F32.show(py))

def Game.debug_part_pz(+pz: F32) -> String:
  String.append(",pz:", F32.show(pz))

def Game.debug_part_yaw(+yaw: F32) -> String:
  String.append(",yaw:", F32.show(yaw))

def Game.debug_part_bi(+bi: U32) -> String:
  String.append(",biome:", U32.show(bi))

def Game.debug_part_fps(+fps: U32) -> String:
  String.append(",fps:", U32.show(fps))

def Game.debug_part_tick(+tickn: U32) -> String:
  String.append(",tick:", U32.show(tickn))

def Game.debug_str(+seed: U32, +px: F32, +py: F32, +pz: F32, +yaw: F32, +fps: U32, +tickn: U32) -> String:
  bi = Game.height_at(seed, F32.to_u32(px), F32.to_u32(pz))
  s1 = Game.debug_part_seed(seed)
  s2 = Game.debug_part_px(px)
  s3 = Game.debug_part_py(py)
  s4 = Game.debug_part_pz(pz)
  s5 = Game.debug_part_yaw(yaw)
  s6 = Game.debug_part_bi(bi)
  s7 = Game.debug_part_fps(fps)
  s8 = Game.debug_part_tick(tickn)
  String.append(s1, String.append(s2, String.append(s3, String.append(s4, String.append(s5, String.append(s6, String.append(s7, s8)))))))

def Game.block_at_ore(c: Bool) -> U32:
  match c:
    case False{}:
      3
    case True{}:
      11

def Game.block_at_stone(+seed: U32, +x: U32, +y: U32, +z: U32) -> U32:
  hh = Game.hash((seed + y : U32), x, z)
  m = U32.mod(hh, 20)
  Game.block_at_ore(U32.is_eq(m, 0))

def Game.block_at_bed(+seed: U32, +x: U32, +y: U32, +z: U32, c: Bool) -> U32:
  match c:
    case False{}:
      Game.block_at_stone(seed, x, y, z)
    case True{}:
      8

def Game.block_at_sub(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      Game.block_at_bed(seed, x, y, z, U32.is_eq(y, 0))
    case True{}:
      2

def Game.block_at_beach(h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      1
    case True{}:
      6

def Game.block_at_surface(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      Game.block_at_sub(seed, x, y, z, h, U32.is_gt(y, (h - 3 : U32)))
    case True{}:
      Game.block_at_beach(h, U32.is_le(h, 12))

def Game.block_at_water(y: U32, c: Bool) -> U32:
  match c:
    case False{}:
      0
    case True{}:
      7

def Game.block_at_above(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32, c: Bool) -> U32:
  match c:
    case False{}:
      Game.block_at_surface(seed, x, y, z, h, U32.is_eq(y, h))
    case True{}:
      Game.block_at_water(y, U32.is_le(y, 11))

def Game.block_at(+seed: U32, +x: U32, +y: U32, +z: U32, +h: U32) -> U32:
  Game.block_at_above(seed, x, y, z, h, U32.is_gt(y, h))

def Game.idx(x: U32, y: U32, z: U32) -> U32:
  t1 = U32.mul(y, 64)
  t2 = (t1 + z : U32)
  t3 = U32.mul(t2, 64)
  (t3 + x : U32)

def Game.leaf_block_go(x: U32, y: U32, z: U32, seed: U32) -> U32:
  +xx = x
  +zz = z
  +ss = seed
  h = Game.height_at(ss, xx, zz)
  Game.block_at(ss, xx, y, zz, h)

def Game.leaf_block(base: U32, seed: U32) -> U32:
  +b = base
  x = U32.mod(b, 64)
  +t = U32.div(b, 64)
  z = U32.mod(t, 64)
  y = U32.div(t, 64)
  Game.leaf_block_go(x, y, z, seed)

def Game.gen_range(+d: Nat, +base: U32, +seed: U32) -> Array<U32>:
  match d:
    case 0n:
      ALeaf{Game.leaf_block(base, seed)}
    case 1n+p:
      +half = U32.pow(2, p)
      l r = Game.gen_range(p, base, seed) Game.gen_range(p, (base + half : U32), seed)
      ANode{l, r}

def Game.gen(seed: U32) -> Array<U32>:
  Game.gen_range(17n, 0, seed)

def Game.spawn(seed: U32) -> GameState:
  +s = seed
  G{Game.gen(s), 32.5, 20.0, 32.5, 0.0, 0.0, 0.0, False{}, False{}, 0, 0.3, s, Hud.full(), Menu{}, 0, 0}

def Game.hotbar_fin(eq: Bool, slot: U32) -> U32:
  match eq:
    case True{}:
      16777215
    case False{}:
      (slot + 10 : U32)

def Game.hotbar_go(slot: U32, sel: U32) -> U32:
  +s = slot
  Game.hotbar_fin(U32.is_eq(s, sel), s)

def Game.hotbar_color(x: U32, sel: U32) -> U32:
  +xx = x
  Game.hotbar_go(U32.div(xx, 32), sel)

def Game.sky_go(sky: Bool) -> U32:
  match sky:
    case True{}:
      8900331
    case False{}:
      725030

def Game.sky_color(t: F32) -> U32:
  Game.sky_go(F32.is_lt(t, 0.5))

def Game.is_cross(cx: Bool, cy: Bool) -> Bool:
  match cx:
    case True{}:
      True{}
    case False{}:
      cy

def Game.hotbar_go2(hb: Bool, x: U32, sel: U32) -> U32:
  match hb:
    case True{}:
      Game.hotbar_color(x, sel)
    case False{}:
      6142012

def Game.hotbar_or_ground(x: U32, sel: U32, y: U32) -> U32:
  Game.hotbar_go2(U32.is_lt(240, y), x, sel)

def Game.ground_go(sky: Bool, x: U32, y: U32, sel: U32, time: F32) -> U32:
  match sky:
    case True{}:
      Game.sky_color(time)
    case False{}:
      Game.hotbar_or_ground(x, sel, y)

def Game.ground_or_sky(x: U32, y: U32, sel: U32, time: F32) -> U32:
  +yy = y
  Game.ground_go(U32.is_lt(yy, 128), x, yy, sel, time)

def Game.leaf_fin(cross: Bool, x: U32, y: U32, sel: U32, time: F32) -> U32:
  match cross:
    case True{}:
      16777215
    case False{}:
      Game.ground_or_sky(x, y, sel, time)

def Game.leaf_go(x: U32, y: U32, sel: U32, time: F32, cx: Bool, cy: Bool) -> U32:
  Game.leaf_fin(Game.is_cross(cx, cy), x, y, sel, time)

def Game.leaf_color(x: U32, y: U32, sel: U32, time: F32) -> U32:
  +xx = x
  +yy = y
  +ss = sel
  +tt = time
  Game.leaf_go(xx, yy, ss, tt, U32.is_eq(xx, 128), U32.is_eq(yy, 128))

def Game.fallback_view(+d: Nat, +x: U32, +y: U32, +sel: U32, +time: F32, +hud: Hud, +mode: Mode) -> Image:
  match d:
    case 0n:
      Pix{Game.mode_tint(mode, Game.hud_pixel(x, y, hud, sel, Game.leaf_color(x, y, sel, time)))}
    case 1n+p:
      +half = U32.pow(2, p)
      a b = Game.fallback_view(p, x, y, sel, time, hud, mode) Game.fallback_view(p, (x + half : U32), y, sel, time, hud, mode)
      c e = Game.fallback_view(p, x, (y + half : U32), sel, time, hud, mode) Game.fallback_view(p, (x + half : U32), (y + half : U32), sel, time, hud, mode)
      Qua{a, b, c, e}

def Game.view_img(+sel: U32, +time: F32, +hud: Hud, +mode: Mode) -> Image:
  Game.fallback_view(8n, 0, 0, sel, time, hud, mode)

def Game.view_pick(inmenu: Bool, +sel: U32, +time: F32, +hud: Hud, +mode: Mode) -> Image:
  match inmenu:
    case True{}:
      Game.menu_view(8n, 0, 0)
    case False{}:
      Game.view_img(sel, time, hud, mode)

def Game.time_wrapped(ge: Bool, t: F32) -> F32:
  match ge:
    case True{}:
      (t - 1.0 : F32)
    case False{}:
      t

def Game.tick_time_add(t: F32) -> F32:
  +tt = t
  Game.time_wrapped(F32.is_ge((tt + 0.001 : F32), 1.0), (tt + 0.001 : F32))

def Game.apply_time(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, Game.tick_time_add(time), seed, hud, mode, (tickn + 1 : U32), Game.flash_tick(flash)}

def Game.tick_time(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.apply_time(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.landed(land: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, fly: Bool, sel: U32, time: F32, seed: U32, new_py: F32, new_vy: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match land:
    case True{}:
      G{world, px, 9.0, pz, yaw, pitch, 0.0, True{}, fly, sel, time, seed, hud, mode, tickn, flash}
    case False{}:
      G{world, px, new_py, pz, yaw, pitch, new_vy, False{}, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.fall_step(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +v = vy
  +p = py
  +new_vy = (v - 0.02 : F32)
  +new_py = (p + new_vy : F32)
  Game.landed(F32.is_lt(new_py, 9.0), world, px, p, pz, yaw, pitch, v, fly, sel, time, seed, new_py, new_vy, hud, mode, tickn, flash)

def Game.grav_go(fly: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match fly:
    case True{}:
      G{world, px, py, pz, yaw, pitch, 0.0, True{}, fly, sel, time, seed, hud, mode, tickn, flash}
    case False{}:
      Game.fall_step(world, px, py, pz, yaw, pitch, vy, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.tick_physics(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.grav_go(fly, world, px, py, pz, yaw, pitch, vy, sel, time, seed, hud, mode, tickn, flash)

def Game.move_fwd_apply(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, dx: F32, dz: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +xx = px
  +zz = pz
  G{world, (xx + dx : F32), py, (zz + dz : F32), yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.move_fwd(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +yy = yaw
  dx = (F32.cos(yy) * 0.5 : F32)
  dz = (F32.sin(yy) * 0.5 : F32)
  Game.move_fwd_apply(world, px, py, pz, yy, pitch, vy, on_ground, fly, sel, time, seed, dx, dz, hud, mode, tickn, flash)

def Game.do_fwd(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.move_fwd(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.move_back_apply(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, dx: F32, dz: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +xx = px
  +zz = pz
  G{world, (xx - dx : F32), py, (zz - dz : F32), yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.move_back(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +yy = yaw
  dx = (F32.cos(yy) * 0.5 : F32)
  dz = (F32.sin(yy) * 0.5 : F32)
  Game.move_back_apply(world, px, py, pz, yy, pitch, vy, on_ground, fly, sel, time, seed, dx, dz, hud, mode, tickn, flash)

def Game.do_back(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.move_back(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.strafe_apply(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, dx: F32, dz: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +xx = px
  +zz = pz
  G{world, (xx + dx : F32), py, (zz + dz : F32), yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.strafe_left(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +yy = yaw
  sx = F32.sin(yy)
  cx = F32.cos(yy)
  dx = (F32.neg(sx) * 0.5 : F32)
  dz = (cx * 0.5 : F32)
  Game.strafe_apply(world, px, py, pz, yy, pitch, vy, on_ground, fly, sel, time, seed, dx, dz, hud, mode, tickn, flash)

def Game.do_left(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.strafe_left(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.strafe_right(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +yy = yaw
  sx = F32.sin(yy)
  cx = F32.cos(yy)
  dx = (sx * 0.5 : F32)
  dz = (F32.neg(cx) * 0.5 : F32)
  Game.strafe_apply(world, px, py, pz, yy, pitch, vy, on_ground, fly, sel, time, seed, dx, dz, hud, mode, tickn, flash)

def Game.do_right(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.strafe_right(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.look_yaw(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, d: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +yy = yaw
  G{world, px, py, pz, (yy + d : F32), pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.do_look_left(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.look_yaw(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, (0.0 - 0.1 : F32), hud, mode, tickn, flash)

def Game.do_look_right(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.look_yaw(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, 0.1, hud, mode, tickn, flash)

def Game.look_pitch(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, d: F32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +pp = pitch
  G{world, px, py, pz, yaw, (pp + d : F32), vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.do_look_up(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.look_pitch(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, 0.1, hud, mode, tickn, flash)

def Game.do_look_down(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.look_pitch(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, (0.0 - 0.1 : F32), hud, mode, tickn, flash)

def Game.toggle_go(fly: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match fly:
    case True{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, False{}, sel, time, seed, hud, mode, tickn, flash}
    case False{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, True{}, sel, time, seed, hud, mode, tickn, flash}

def Game.do_fly(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.toggle_go(fly, world, px, py, pz, yaw, pitch, vy, on_ground, sel, time, seed, hud, mode, tickn, flash)

def Game.select_with(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, time: F32, seed: U32, ns: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, ns, time, seed, hud, mode, tickn, 30}

def Game.do_select(s: GameState, ns: U32) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.select_with(world, px, py, pz, yaw, pitch, vy, on_ground, fly, time, seed, ns, hud, mode, tickn, flash)

def Game.jump_go(fly: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match fly:
    case True{}:
      +pp = py
      G{world, px, (pp + 0.5 : F32), pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}
    case False{}:
      G{world, px, py, pz, yaw, pitch, 2.0, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.do_jump(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.jump_go(fly, world, px, py, pz, yaw, pitch, vy, on_ground, sel, time, seed, hud, mode, tickn, flash)

def Game.idx_combine(ux: U32, uy: U32, uz: U32) -> U32:
  +yy = uy
  a = (yy * 4096 : U32)
  b = (uz * 64 : U32)
  c = (a + b : U32)
  e = (c + ux : U32)
  (e % 131072 : U32)

def Game.idx_of(tx: F32, ty: F32, tz: F32) -> U32:
  ux = F32.to_u32(tx)
  uy = F32.to_u32(ty)
  uz = F32.to_u32(tz)
  Game.idx_combine(ux, uy, uz)

def Game.march(fuel: Nat, ex: F32, ey: F32, ez: F32, fx: F32, fy: F32, fz: F32) -> U32:
  match fuel:
    case 0n:
      Game.idx_of(ex, ey, ez)
    case 1n+f:
      +ax = fx
      +ay = fy
      +az = fz
      +sx = (ax * 0.2 : F32)
      +sy = (ay * 0.2 : F32)
      +sz = (az * 0.2 : F32)
      +nx = (ex + sx : F32)
      +ny = (ey + sy : F32)
      +nz = (ez + sz : F32)
      Game.march(f, nx, ny, nz, ax, ay, az)

def Game.target_go(px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, fx: F32, fz: F32, fy: F32) -> U32:
  +xx = px
  +yy = py
  +zz = pz
  ex = xx
  ey = (yy + 1.6 : F32)
  ez = zz
  Game.march(30n, ex, ey, ez, fx, fy, fz)

def Game.target_idx(px: F32, py: F32, pz: F32, yaw: F32, pitch: F32) -> U32:
  +yy = yaw
  +pp = pitch
  cy = F32.cos(yy)
  sy = F32.sin(yy)
  cp = F32.cos(pp)
  sp = F32.sin(pp)
  +cx = cy
  +sx = sy
  +cc = cp
  Game.target_go(px, py, pz, yy, pp, (cx * cc : F32), (sx * cc : F32), sp)

def Game.solid_go(air_or_water: Bool) -> Bool:
  match air_or_water:
    case True{}:
      False{}
    case False{}:
      True{}

def Game.solid_of(b: U32) -> Bool:
  +bb = b
  Game.solid_go(Bool.or(U32.is_eq(bb, 0), U32.is_eq(bb, 7)))

def Game.break_fin(solid: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, idx: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match solid:
    case True{}:
      G{Array.set(U32, world, idx, 0), px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}
    case False{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.break_go(wv: Array<U32> & U32, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, idx: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  (w2, v) = wv
  Game.break_fin(Game.solid_of(v), w2, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, idx, hud, mode, tickn, flash)

def Game.break_with(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +xx = px
  +yy = py
  +zz = pz
  +ya = yaw
  +pi = pitch
  +idx = Game.target_idx(xx, yy, zz, ya, pi)
  Game.break_go(Array.get(U32, world, idx), xx, yy, zz, ya, pi, vy, on_ground, fly, sel, time, seed, idx, hud, mode, tickn, flash)

def Game.do_break(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.break_with(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.place_fin(empty: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, idx: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match empty:
    case True{}:
      +ss = sel
      G{Array.set(U32, world, idx, (ss + 1 : U32)), px, py, pz, yaw, pitch, vy, on_ground, fly, ss, time, seed, hud, mode, tickn, flash}
    case False{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.place_go(wv: Array<U32> & U32, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, idx: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  (w2, v) = wv
  Game.place_fin(U32.is_eq(v, 0), w2, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, idx, hud, mode, tickn, flash)

def Game.place_with(world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  +xx = px
  +yy = py
  +zz = pz
  +ya = yaw
  +pi = pitch
  +ss = sel
  +idx = Game.target_idx(xx, yy, zz, ya, pi)
  Game.place_go(Array.get(U32, world, idx), xx, yy, zz, ya, pi, vy, on_ground, fly, ss, time, seed, idx, hud, mode, tickn, flash)

def Game.do_place(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.place_with(world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.on_key_other(code: U32, s: GameState) -> GameState:
  s

def Game.on_key_down_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_look_down(s)
    case False{}:
      Game.on_key_other(code, s)

def Game.on_key_down(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_down_go(U32.is_eq(c, 40), c, s)

def Game.on_key_up_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_look_up(s)
    case False{}:
      Game.on_key_down(code, s)

def Game.on_key_up(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_up_go(U32.is_eq(c, 38), c, s)

def Game.on_key_right_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_look_right(s)
    case False{}:
      Game.on_key_up(code, s)

def Game.on_key_right(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_right_go(U32.is_eq(c, 39), c, s)

def Game.on_key_left_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_look_left(s)
    case False{}:
      Game.on_key_right(code, s)

def Game.on_key_left(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_left_go(U32.is_eq(c, 37), c, s)

def Game.on_key_8_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 7)
    case False{}:
      Game.on_key_left(code, s)

def Game.on_key_8(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_8_go(U32.is_eq(c, 56), c, s)

def Game.on_key_7_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 6)
    case False{}:
      Game.on_key_8(code, s)

def Game.on_key_7(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_7_go(U32.is_eq(c, 55), c, s)

def Game.on_key_6_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 5)
    case False{}:
      Game.on_key_7(code, s)

def Game.on_key_6(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_6_go(U32.is_eq(c, 54), c, s)

def Game.on_key_5_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 4)
    case False{}:
      Game.on_key_6(code, s)

def Game.on_key_5(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_5_go(U32.is_eq(c, 53), c, s)

def Game.on_key_4_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 3)
    case False{}:
      Game.on_key_5(code, s)

def Game.on_key_4(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_4_go(U32.is_eq(c, 52), c, s)

def Game.on_key_3_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 2)
    case False{}:
      Game.on_key_4(code, s)

def Game.on_key_3(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_3_go(U32.is_eq(c, 51), c, s)

def Game.on_key_2_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 1)
    case False{}:
      Game.on_key_3(code, s)

def Game.on_key_2(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_2_go(U32.is_eq(c, 50), c, s)

def Game.on_key_1_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_select(s, 0)
    case False{}:
      Game.on_key_2(code, s)

def Game.on_key_1(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_1_go(U32.is_eq(c, 49), c, s)

def Game.on_key_f_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_fly(s)
    case False{}:
      Game.on_key_1(code, s)

def Game.on_key_f(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_f_go(Bool.or(U32.is_eq(c, 70), U32.is_eq(c, 102)), c, s)

def Game.on_key_q_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_place(s)
    case False{}:
      Game.on_key_f(code, s)

def Game.on_key_q(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_q_go(Bool.or(U32.is_eq(c, 81), U32.is_eq(c, 113)), c, s)

def Game.on_key_e_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_break(s)
    case False{}:
      Game.on_key_q(code, s)

def Game.on_key_e(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_e_go(Bool.or(U32.is_eq(c, 69), U32.is_eq(c, 101)), c, s)

def Game.on_key_space_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_jump(s)
    case False{}:
      Game.on_key_e(code, s)

def Game.on_key_space(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_space_go(U32.is_eq(c, 32), c, s)

def Game.on_key_d_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_right(s)
    case False{}:
      Game.on_key_space(code, s)

def Game.on_key_d(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_d_go(Bool.or(U32.is_eq(c, 68), U32.is_eq(c, 100)), c, s)

def Game.on_key_a_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_left(s)
    case False{}:
      Game.on_key_d(code, s)

def Game.on_key_a(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_a_go(Bool.or(U32.is_eq(c, 65), U32.is_eq(c, 97)), c, s)

def Game.on_key_s_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_back(s)
    case False{}:
      Game.on_key_a(code, s)

def Game.on_key_s(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_s_go(Bool.or(U32.is_eq(c, 83), U32.is_eq(c, 115)), c, s)

def Game.on_key_w_go(is_k: Bool, code: U32, s: GameState) -> GameState:
  match is_k:
    case True{}:
      Game.do_fwd(s)
    case False{}:
      Game.on_key_s(code, s)

def Game.on_key_w(code: U32, s: GameState) -> GameState:
  +c = code
  Game.on_key_w_go(Bool.or(U32.is_eq(c, 87), U32.is_eq(c, 119)), c, s)

def Game.death_go(is_d: Bool, world: Array<U32>, px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, vy: F32, on_ground: Bool, fly: Bool, sel: U32, time: F32, seed: U32, hud: Hud, mode: Mode, tickn: U32, flash: U32) -> GameState:
  match is_d:
    case True{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, Dead{}, tickn, flash}
    case False{}:
      G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}

def Game.tick_death(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.death_go(Game.is_dead(hud), world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash)

def Game.is_play(mode: Mode) -> Bool:
  match mode:
    case Play{}:
      True{}
    case Pause{}:
      False{}
    case Menu{}:
      False{}
    case Dead{}:
      False{}

def Game.idle_go(is_p: Bool, s: GameState) -> GameState:
  match is_p:
    case True{}:
      Game.tick_death(Game.tick_time(Game.tick_physics(s)))
    case False{}:
      s

def Game.tick_idle(s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.idle_go(Game.is_play(mode), G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash})

def Game.pause_key(+code: U32, down: Bool, s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      +nm = Game.mode_key(mode, code, down)
      G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, nm, tickn, flash}

def Game.on_key_play_go(is_pause: Bool, code: U32, s: GameState) -> GameState:
  match is_pause:
    case True{}:
      match s:
        case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
          G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, Pause{}, tickn, flash}
    case False{}:
      Game.on_key_w(code, s)

def Game.on_key_dead_go(is_rk: Bool, down: Bool, s: GameState) -> GameState:
  match is_rk down:
    case True{} True{}:
      Game.respawn(s)
    case True{} False{}:
      s
    case False{} True{}:
      s
    case False{} False{}:
      s

def Game.on_key_menu_go(start: Bool, s: GameState) -> GameState:
  match start:
    case True{}:
      match s:
        case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
          G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, Play{}, tickn, 30}
    case False{}:
      s

def Game.on_key_notmenu(mode: Mode, +code: U32, down: Bool, s: GameState) -> GameState:
  match mode:
    case Menu{}:
      s
    case Play{}:
      Game.on_key_play_go(Bool.and(down, Game.is_pause_key(code)), code, s)
    case Pause{}:
      Game.pause_key(code, down, s)
    case Dead{}:
      Game.on_key_dead_go(Game.is_r(code), down, s)

def Game.on_key_after_menu(is_menu: Bool, mode: Mode, +code: U32, down: Bool, s: GameState) -> GameState:
  match is_menu:
    case True{}:
      Game.on_key_menu_go(down, s)
    case False{}:
      Game.on_key_notmenu(mode, code, down, s)

def Game.on_key(code: U32, down: Bool, s: GameState) -> GameState:
  match s:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      Game.on_key_after_menu(Game.in_menu(mode), mode, code, down, G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash})

def view(state: GameState) -> Pair(GameState, Image):
  match state:
    case G{world, +px, +py, +pz, +yaw, +pitch, +vy, +on_ground, +fly, +sel, +time, +seed, +hud, +mode, +tickn, +flash}:
      (G{world, px, py, pz, yaw, pitch, vy, on_ground, fly, sel, time, seed, hud, mode, tickn, flash}, Game.view_pick(Game.in_menu(mode), sel, time, hud, mode))

def tick(events: List<Event>, state: GameState) -> IO(Maybe<GameState>):
  match events:
    case Nil{}:
      IO.pure(Maybe<GameState>, Some{Game.tick_idle(state)})
    case Con{e, rest}:
      match e:
        case Close{}:
          IO.pure(Maybe<GameState>, None{})
        case Key{c, d}:
          tick(rest, Game.on_key(c, d, state))
        case _:
          tick(rest, state)

def main() -> IO(Unit):
  App.run(~GameState, ~App{view, tick}, "BendCraft", 256, 256, Game.spawn(1337))
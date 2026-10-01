import Base

# physics.bend — pure player physics for the Minecraft clone.
# No world import here (avoids a circular import). Collision sampling
# against the voxel grid lives in world/game modules; this file provides
# pure math + per-axis resolve helpers that game.bend loops with lookups.

type Vec3 is Data:
  V{x: F32, y: F32, z: F32}

def Vec3.zero() -> Vec3:
  V{0.0, 0.0, 0.0}

def Vec3.add(a: Vec3, b: Vec3) -> Vec3:
  match a b:
    case V{ax, ay, az} V{bx, by, bz}:
      V{(ax + bx : F32), (ay + by : F32), (az + bz : F32)}

def Vec3.scale(+s: F32, v: Vec3) -> Vec3:
  match v:
    case V{x, y, z}:
      V{(s * x : F32), (s * y : F32), (s * z : F32)}

def Vec3.is_eq(a: Vec3, b: Vec3) -> Bool:
  match a b:
    case V{ax, ay, az} V{bx, by, bz}:
      Bool.and(Bool.and(F32.is_eq(ax, bx), F32.is_eq(ay, by)), F32.is_eq(az, bz))

type Player is Data:
  P{pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, on_ground: Bool, fly: Bool}

def Player.spawn() -> Player:
  P{V{32.5, 20.0, 32.5}, V{0.0, 0.0, 0.0}, 0.0, 0.0, False{}, False{}}

# Movement constants (defs returning F32, single source of truth).
def Physics.gravity() -> F32:
  28.0

def Physics.jump_vel() -> F32:
  9.0

def Physics.walk_speed() -> F32:
  5.0

def Physics.fly_speed() -> F32:
  8.0

def Physics.terminal() -> F32:
  F32.neg(30.0)

def Physics.epsilon() -> F32:
  0.001

# Clamp falling speed to terminal velocity.
def Physics.clamp_fall(vy: F32) -> F32:
  F32.max(vy, Physics.terminal())

# Clamp one axis into [lo, hi].
def Physics.clamp_axis(v: F32, lo: F32, hi: F32) -> F32:
  F32.clamp(v, lo, hi)

# Solid check (duplicated small on purpose, no world import):
# blocked = not (b == air(0) or b == water(7)).
def Physics.blocked(+block: U32) -> Bool:
  Bool.not(Bool.or(U32.is_eq(block, 0), U32.is_eq(block, 7)))

# True if any block id in the nearby list is solid.
# Only recursive def over List here; solid is first and shrinks via tail.
def Physics.any_blocked(solid: List<U32>) -> Bool:
  match solid:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(Physics.blocked(h), Physics.any_blocked(t))

# Vertical velocity after gravity over dt. Falls only when airborne and
# not flying; otherwise unchanged. Clamps to terminal.
def Physics.fall_vy(vy: F32, dt: F32, fly: Bool, on_ground: Bool) -> F32:
  match fly on_ground:
    case False{} False{}:
      Physics.clamp_fall((vy - (Physics.gravity() * dt : F32) : F32))
    case False{} True{}:
      vy
    case True{} False{}:
      vy
    case True{} True{}:
      vy

# Jump: grounded + pressed sets upward velocity, else keeps vy.
def Physics.jump_vy(vy: F32, on_ground: Bool, jump: Bool) -> F32:
  match on_ground jump:
    case True{} True{}:
      Physics.jump_vel()
    case True{} False{}:
      vy
    case False{} True{}:
      vy
    case False{} False{}:
      vy

# Friction/drag factor over dt: strong on ground, mild in air.
def Physics.fric_factor(dt: F32, on_ground: Bool) -> F32:
  match on_ground:
    case False{}:
      (1.0 - (0.5 * dt : F32) : F32)
    case True{}:
      F32.max((1.0 - (10.0 * dt : F32) : F32), 0.0)

# Grounded when there is support below and we are not moving up.
def Physics.grounded_go(below: Bool, slow: Bool) -> Bool:
  match below slow:
    case True{} True{}:
      True{}
    case True{} False{}:
      False{}
    case False{} True{}:
      False{}
    case False{} False{}:
      False{}

# Single-axis pure shifts.
def Physics.shift_x(pos: Vec3, delta: F32) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{(x + delta : F32), y, z}

def Physics.shift_y(pos: Vec3, delta: F32) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{x, (y + delta : F32), z}

def Physics.shift_z(pos: Vec3, delta: F32) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{x, y, (z + delta : F32)}

# Dispatch a pure shift from precomputed axis flags (avoids matching on U32).
def Physics.shift_go(pos: Vec3, delta: F32, is_x: Bool, is_y: Bool) -> Vec3:
  match is_x is_y:
    case True{} _:
      Physics.shift_x(pos, delta)
    case False{} True{}:
      Physics.shift_y(pos, delta)
    case False{} False{}:
      Physics.shift_z(pos, delta)

# Pure AABB overlap test on min/max corners.
def Physics.aabb_overlap(a_min: Vec3, a_max: Vec3, b_min: Vec3, b_max: Vec3) -> Bool:
  match a_min a_max b_min b_max:
    case V{+aminx, +aminy, +aminz} V{+amaxx, +amaxy, +amaxz} V{+bminx, +bminy, +bminz} V{+bmaxx, +bmaxy, +bmaxz}:
      Bool.and(Bool.and(F32.is_lt(aminx, bmaxx), F32.is_lt(bminx, amaxx)), Bool.and(Bool.and(F32.is_lt(aminy, bmaxy), F32.is_lt(bminy, amaxy)), Bool.and(F32.is_lt(aminz, bmaxz), F32.is_lt(bminz, amaxz))))

# Look helpers (defined before their Player wrappers).
def Player.turn_go(pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, og: Bool, fly: Bool, dx: F32, dy: F32) -> Player:
  P{pos, vel, (yaw + (dx * 0.003 : F32) : F32), F32.clamp((pitch + (dy * 0.003 : F32) : F32), F32.neg(1.55), 1.55), og, fly}

def Player.dir_go(+yaw: F32, +pitch: F32) -> Vec3:
  V{(F32.neg(F32.sin(yaw)) * F32.cos(pitch) : F32), F32.sin(pitch), (F32.neg(F32.cos(yaw)) * F32.cos(pitch) : F32)}

def Player.eye_go(pos: Vec3) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{x, (y + 1.6 : F32), z}

# Pure physics velocity step: gravity when airborne and not flying.
def Physics.step_vel(v: Vec3, on_ground: Bool, fly: Bool, dt: F32) -> Vec3:
  match v:
    case V{vx, vy, vz}:
      V{vx, Physics.fall_vy(vy, dt, fly, on_ground), vz}

# Gravity only (no ground check here; game.bend supplies fly mode).
def Physics.apply_gravity(vel: Vec3, dt: F32, fly: Bool) -> Vec3:
  match vel:
    case V{vx, vy, vz}:
      V{vx, Physics.fall_vy(vy, dt, fly, False{}), vz}

# Jump impulse when grounded and pressed.
def Physics.apply_jump(vel: Vec3, on_ground: Bool, jump: Bool) -> Vec3:
  match vel:
    case V{vx, vy, vz}:
      V{vx, Physics.jump_vy(vy, on_ground, jump), vz}

# Horizontal friction/drag; vertical untouched.
def Physics.apply_friction(vel: Vec3, on_ground: Bool, dt: F32) -> Vec3:
  match vel on_ground:
    case V{vx, vy, vz} False{}:
      +k = Physics.fric_factor(dt, False{})
      V{(vx * k : F32), vy, (vz * k : F32)}
    case V{vx, vy, vz} True{}:
      +k = Physics.fric_factor(dt, True{})
      V{(vx * k : F32), vy, (vz * k : F32)}

# Semi-implicit Euler position step: pos + vel * dt.
def Physics.step_pos(pos: Vec3, vel: Vec3, +dt: F32) -> Vec3:
  match pos vel:
    case V{px, py, pz} V{vx, vy, vz}:
      V{(px + (vx * dt : F32) : F32), (py + (vy * dt : F32) : F32), (pz + (vz * dt : F32) : F32)}

# Pure add of a delta triple (game.bend does collision around this).
def Physics.try_move(pos: Vec3, dx: F32, dy: F32, dz: F32) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{(x + dx : F32), (y + dy : F32), (z + dz : F32)}

# Grounded from vertical speed + support below (no world lookup here).
def Physics.is_on_ground(vy: F32, below: Bool) -> Bool:
  Physics.grounded_go(below, F32.is_le(vy, 0.0))

# Pure single-axis shift selected by axis id (0 = x, 1 = y, else z).
def Physics.shift_axis(pos: Vec3, delta: F32, +axis: U32) -> Vec3:
  Physics.shift_go(pos, delta, U32.is_eq(axis, 0), U32.is_eq(axis, 1))

# Per-axis resolve from a precomputed hit flag: stay + True on hit,
# else shift + False. game.bend loops this with world lookups.
def Physics.collide_axis(pos: Vec3, delta: F32, +axis: U32, hit: Bool) -> Vec3 & Bool:
  match hit:
    case True{}:
      (pos, True{})
    case False{}:
      (Physics.shift_go(pos, delta, U32.is_eq(axis, 0), U32.is_eq(axis, 1)), False{})

# Per-axis resolve from a small list of nearby block ids.
def Physics.move_axis(pos: Vec3, delta: F32, +axis: U32, solid: List<U32>) -> Vec3 & Bool:
  Physics.collide_axis(pos, delta, axis, Physics.any_blocked(solid))

# Pure collide between current and candidate positions.
def Physics.collide(pos: Vec3, new_pos: Vec3, hit: Bool) -> Vec3 & Bool:
  match hit:
    case True{}:
      (pos, True{})
    case False{}:
      (new_pos, False{})

# 8 AABB corners for a player at feet pos (half width 0.3, height 1.8).
# game.bend maps these through world lookups for collision.
def Physics.player_aabb_corners(+pos: Vec3) -> List<Vec3>:
  match pos:
    case V{+x, +y, +z}:
      V{(x - 0.3 : F32), y, (z - 0.3 : F32)} <> V{(x + 0.3 : F32), y, (z - 0.3 : F32)} <> V{(x - 0.3 : F32), y, (z + 0.3 : F32)} <> V{(x + 0.3 : F32), y, (z + 0.3 : F32)} <> V{(x - 0.3 : F32), (y + 1.8 : F32), (z - 0.3 : F32)} <> V{(x + 0.3 : F32), (y + 1.8 : F32), (z - 0.3 : F32)} <> V{(x - 0.3 : F32), (y + 1.8 : F32), (z + 0.3 : F32)} <> V{(x + 0.3 : F32), (y + 1.8 : F32), (z + 0.3 : F32)} <> Nil{}

# Yaw/pitch look; dx/dy are mouse deltas scaled by sensitivity.
def Player.turn(p: Player, +dx: F32, +dy: F32) -> Player:
  match p:
    case P{pos, vel, yaw, pitch, og, fly}:
      Player.turn_go(pos, vel, yaw, pitch, og, fly, dx, dy)

# Forward vector from yaw/pitch.
def Player.dir(p: Player) -> Vec3:
  match p:
    case P{pos, vel, yaw, pitch, og, fly}:
      Player.dir_go(yaw, pitch)

# Eye position (feet + 1.6 height).
def Player.eye(p: Player) -> Vec3:
  match p:
    case P{pos, vel, yaw, pitch, og, fly}:
      Player.eye_go(pos)

# Pure physics integrate (no input, no collision): gravity then move.
# Player.apply_input (wish dirs/jump) lives in the player module and runs
# before this; world/game collision runs after via try_move/collide_axis.
def Physics.integrate_go(pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, +og: Bool, +fly: Bool, +dt: F32) -> Player:
  +new_vel = Physics.step_vel(vel, og, fly, dt)
  new_pos = Physics.step_pos(pos, new_vel, dt)
  P{new_pos, new_vel, yaw, pitch, og, fly}

def Physics.integrate(p: Player, +dt: F32) -> Player:
  match p:
    case P{pos, vel, yaw, pitch, og, fly}:
      Physics.integrate_go(pos, vel, yaw, pitch, og, fly, dt)

# LAW: gravity never increases fall velocity (airborne, not flying).
def Physics.law_gravity_holds(+vy: F32, dt: F32) -> Bool:
  F32.is_le(Physics.fall_vy(vy, dt, False{}, False{}), vy)

# LAW: jumping while grounded sets upward velocity to jump_vel.
def Physics.law_jump_holds() -> Bool:
  F32.is_eq(Physics.jump_vy(0.0, True{}, True{}), Physics.jump_vel())

# LAW: zero dt does not move the player.
def Physics.law_zero_dt_holds(+pos: Vec3, vel: Vec3) -> Bool:
  Vec3.is_eq(Physics.step_pos(pos, vel, 0.0), pos)

# --- Sprint / sneak / swim / step / glide constants (additive) ---
# Sprint = Ctrl hold (walk 5.0 stays). Double-W not tracked; sprint is explicit.
def Physics.sprint_speed() -> F32:
  7.5

def Physics.sneak_speed() -> F32:
  2.0

def Physics.swim_speed() -> F32:
  3.0

def Physics.step_height() -> F32:
  0.6

def Physics.glide_rate() -> F32:
  0.15

def Physics.glide_max() -> F32:
  2.0

def Physics.air_drag() -> F32:
  0.98

def Physics.fly_drag() -> F32:
  0.95

def Physics.water_factor() -> F32:
  0.8

def Physics.ice_friction() -> F32:
  0.98

def Physics.ground_friction() -> F32:
  0.7

def Physics.drown_max() -> U32:
  300

def Physics.drown_ticks() -> U32:
  300

# Sprint selector: True -> sprint_speed, else walk_speed.
def Physics.speed_of(sprint: Bool) -> F32:
  match sprint:
    case True{}:
      Physics.sprint_speed()
    case False{}:
      Physics.walk_speed()

# Water drag on one axis: scale by water factor.
def Physics.water_drag(v: F32) -> F32:
  (v * Physics.water_factor() : F32)

# Swim lift: upward velocity when swimming in water, else 0.
def Physics.swim_lift(swim: Bool, in_water: Bool) -> F32:
  match swim in_water:
    case True{} True{}:
      Physics.swim_speed()
    case True{} False{}:
      0.0
    case False{} True{}:
      0.0
    case False{} False{}:
      0.0

# Step-up helper + main: 0.0 < dy <= step_height.
def Physics.can_step_go(le: Bool, gt: Bool) -> Bool:
  Bool.and(le, gt)

def Physics.can_step(+dy: F32) -> Bool:
  Physics.can_step_go(F32.is_le(dy, Physics.step_height()), F32.is_gt(dy, 0.0))

# Knockback: add horizontal impulse (vx+kx, vz+kz).
def Physics.knockback(vx: F32, vz: F32, kx: F32, kz: F32) -> F32 & F32:
  nx = (vx + kx : F32)
  nz = (vz + kz : F32)
  (nx, nz)

# Fall damage helper + main: 0 under 3.5, else (fall-3.5) rounded.
def Physics.fall_damage_go(small: Bool, fall: F32) -> U32:
  match small:
    case True{}:
      0
    case False{}:
      F32.to_u32(F32.round((fall - 3.5 : F32)))

def Physics.fall_damage(+fall: F32) -> U32:
  Physics.fall_damage_go(F32.is_lt(fall, 3.5), fall)

# Fluid drag: uniform scale helper, then air/fly/water selectors.
def Physics.scale_vel(vel: Vec3, +k: F32) -> Vec3:
  match vel:
    case V{vx, vy, vz}:
      V{(vx * k : F32), (vy * k : F32), (vz * k : F32)}

def Physics.apply_air(vel: Vec3) -> Vec3:
  Physics.scale_vel(vel, Physics.air_drag())

def Physics.apply_fly_drag(vel: Vec3) -> Vec3:
  Physics.scale_vel(vel, Physics.fly_drag())

def Physics.apply_water_vel(vel: Vec3) -> Vec3:
  Physics.scale_vel(vel, Physics.water_factor())

def Physics.apply_fluid_air(vel: Vec3, fly: Bool) -> Vec3:
  match fly:
    case True{}:
      Physics.apply_fly_drag(vel)
    case False{}:
      Physics.apply_air(vel)

def Physics.apply_fluid_water(vel: Vec3, in_water: Bool, fly: Bool) -> Vec3:
  match in_water:
    case True{}:
      Physics.apply_water_vel(vel)
    case False{}:
      Physics.apply_fluid_air(vel, fly)

def Physics.apply_fluid(vel: Vec3, in_water: Bool, fly: Bool) -> Vec3:
  Physics.apply_fluid_water(vel, in_water, fly)

# Head bump helper + main: zero upward vy on ceiling.
def Physics.bump_go(blocked: Bool, up: Bool, vy: F32) -> F32:
  match blocked up:
    case True{} True{}:
      0.0
    case True{} False{}:
      vy
    case False{} True{}:
      vy
    case False{} False{}:
      vy

def Physics.bump(+vy: F32, blocked_above: Bool) -> F32:
  Physics.bump_go(blocked_above, F32.is_gt(vy, 0.0), vy)

# Elytra-lite glide: sink rate from forward speed, clamped to max.
def Physics.glide_drop(fly_speed: F32) -> F32:
  F32.min((fly_speed * Physics.glide_rate() : F32), Physics.glide_max())

# Slippery ice: block 12 (reserved ice, blocks.bend has 0-11) -> 0.98 else 0.7.
def Physics.friction_pick(is_ice: Bool) -> F32:
  match is_ice:
    case True{}:
      Physics.ice_friction()
    case False{}:
      Physics.ground_friction()

def Physics.friction_of(block: U32) -> F32:
  Physics.friction_pick(U32.is_eq(block, 12))

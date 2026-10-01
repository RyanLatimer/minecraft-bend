import Base

type Mob is Data:
  M{id: U32, x: F32, y: F32, z: F32, hp: U32, seed: U32}

def Mob.hash(seed: U32, k: U32) -> U32:
  t = U32.xor(seed, k)
  U32.mul(t, 2246822519)

def Mob.maxhp3() -> U32:
  20

def Mob.maxhp2(+id: U32, c: Bool) -> U32:
  match c:
    case True{}:
      4
    case False{}:
      Mob.maxhp3()

def Mob.maxhp1(+id: U32, c: Bool) -> U32:
  match c:
    case True{}:
      8
    case False{}:
      Mob.maxhp2(id, U32.is_eq(id, 3))

def Mob.maxhp0(+id: U32, c: Bool) -> U32:
  match c:
    case True{}:
      10
    case False{}:
      Mob.maxhp1(id, U32.is_eq(id, 2))

def Mob.maxhp(+id: U32) -> U32:
  Mob.maxhp0(id, Bool.or(U32.is_eq(id, 0), U32.is_eq(id, 1)))

def Mob.color(+id: U32) -> U32:
  +c0 = U32.is_eq(id, 0)
  +c1 = U32.is_eq(id, 1)
  +c2 = U32.is_eq(id, 2)
  +c3 = U32.is_eq(id, 3)
  +c4 = U32.is_eq(id, 4)
  +c5 = U32.is_eq(id, 5)
  +c6 = U32.is_eq(id, 6)
  Bool.pick(U32, c0, 16761035, Bool.pick(U32, c1, 9127188, Bool.pick(U32, c2, 16777215, Bool.pick(U32, c3, 16776960, Bool.pick(U32, c4, 3046706, Bool.pick(U32, c5, 8947848, Bool.pick(U32, c6, 2313012, 16711935)))))))

def Mob.hostile(+id: U32) -> Bool:
  Bool.or(U32.is_eq(id, 4), Bool.or(U32.is_eq(id, 5), U32.is_eq(id, 6)))

def Mob.speed(id: U32) -> F32:
  Bool.pick(F32, Mob.hostile(id), 0.25, 0.15)

def Mob.wander_go(+id: U32, +x: F32, y: F32, +z: F32, hp: U32, +seed: U32, tick: U32) -> Mob:
  +tf = U32.to_f32(tick)
  +sf = U32.to_f32(seed)
  +ang = F32.sin((tf + sf : F32))
  +spd = Mob.speed(id)
  +dx = F32.mul(F32.cos(ang), spd)
  +dz = F32.mul(F32.sin(ang), spd)
  +nx = (x + dx : F32)
  +nz = (z + dz : F32)
  M{id, nx, y, nz, hp, seed}

def Mob.wander(m: Mob, tick: U32) -> Mob:
  match m:
    case M{id, x, y, z, hp, seed}:
      Mob.wander_go(id, x, y, z, hp, seed, tick)

def Mob.chase_go(+id: U32, +x: F32, y: F32, +z: F32, hp: U32, seed: U32, px: F32, pz: F32) -> Mob:
  +dx = (px - x : F32)
  +dz = (pz - z : F32)
  +dist = F32.hypot(dx, dz)
  +safe = (dist + 0.001 : F32)
  +spd = Mob.speed(id)
  +ux = F32.div(dx, safe)
  +uz = F32.div(dz, safe)
  +sx = F32.mul(ux, spd)
  +sz = F32.mul(uz, spd)
  +nx = (x + sx : F32)
  +nz = (z + sz : F32)
  M{id, nx, y, nz, hp, seed}

def Mob.chase(m: Mob, px: F32, pz: F32) -> Mob:
  match m:
    case M{id, x, y, z, hp, seed}:
      Mob.chase_go(id, x, y, z, hp, seed, px, pz)

def Mob.hurt_go(+hp: U32, +dmg: U32, c: Bool) -> U32:
  match c:
    case True{}:
      (hp - dmg : U32)
    case False{}:
      0

def Mob.hurt(m: Mob, +dmg: U32) -> Mob:
  match m:
    case M{id, x, y, z, +hp, seed}:
      +nhp = Mob.hurt_go(hp, dmg, U32.is_ge(hp, dmg))
      M{id, x, y, z, nhp, seed}

def Mob.dead(m: Mob) -> Bool:
  match m:
    case M{id, x, y, z, hp, seed}:
      U32.is_eq(hp, 0)

def Mob.step_one(m: Mob, +px: F32, +pz: F32, +night: Bool, +tick: U32) -> Mob:
  match m:
    case M{+id, +x, +y, +z, +hp, +seed}:
      +ish = Mob.hostile(id)
      +cond = Bool.and(ish, night)
      +ch = Mob.chase_go(id, x, y, z, hp, seed, px, pz)
      +wa = Mob.wander_go(id, x, y, z, hp, seed, tick)
      Bool.pick(Mob, cond, ch, wa)

def Mob.step_all_cons(is_d: Bool, nh: Mob, rec: List<Mob>) -> List<Mob>:
  match is_d:
    case True{}:
      rec
    case False{}:
      nh <> rec

def Mob.step_all(mobs: List<Mob>, +px: F32, +pz: F32, +night: Bool, +tick: U32) -> List<Mob>:
  match mobs:
    case Nil{}:
      Nil{}
    case +h <> t:
      rec = Mob.step_all(t, px, pz, night, tick)
      isd = Mob.dead(h)
      nh = Mob.step_one(h, px, pz, night, tick)
      Mob.step_all_cons(isd, nh, rec)

def Mob.spawn(+seed: U32, +n: Nat, +night: Bool) -> List<Mob>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +k = U32.from_nat(p)
      +h = Mob.hash(seed, k)
      +m3 = U32.mod(h, 3)
      +m4 = U32.mod(h, 4)
      +pid = (4 + m3 : U32)
      +id = Bool.pick(U32, night, pid, m4)
      +hp = Mob.maxhp(id)
      +mx = U32.mod(h, 16)
      +fx = U32.to_f32(mx)
      +nx = (32.0 + fx : F32)
      +qd = U32.div(h, 16)
      +mz = U32.mod(qd, 16)
      +fz = U32.to_f32(mz)
      +nz = (32.0 + fz : F32)
      +kk = (k + 999 : U32)
      +ms = Mob.hash(seed, kk)
      +yy = (32.0 - 12.0 : F32)
      head = {M{id, nx, yy, nz, hp, ms} : Mob}
      tail = Mob.spawn(seed, p, night)
      head <> tail

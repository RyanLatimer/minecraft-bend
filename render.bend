import Base

# Minecraft-clone software raycaster (256x256 Image quadtree, depth 8).
# Pure math + shading + image building live here. Voxel access comes in
# via closed templates (~get, ~color_of) supplied by game.bend, so this
# file has no imports besides Base (no circular imports, no Arrays).

type Cam is Data:
  C{px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, fov: F32}

type Ray is Data:
  R{ox: F32, oy: F32, oz: F32, dx: F32, dy: F32, dz: F32}

# Camera constructor helper.
def Render.cam_from(px: F32, py: F32, pz: F32, yaw: F32, pitch: F32, fov: F32) -> Cam:
  C{px, py, pz, yaw, pitch, fov}

# Division guard: replace 0.0 with a small epsilon (keeps math total).
def Render.nonzero_go(x: F32, z: Bool) -> F32:
  match z:
    case False{}:
      x
    case True{}:
      0.0001

def Render.nonzero(+x: F32) -> F32:
  Render.nonzero_go(x, F32.is_eq(x, 0.0))

# Extract byte k (0n=B, 8n=G, 16n=R) from a packed 0xRRGGBB color.
def Render.chan(c: U32, k: Nat) -> U32:
  U32.and(U32.shrn(c, k), 255)

# Pack R/G/B bytes into 0xRRGGBB.
def Render.pack(r: U32, g: U32, b: U32) -> U32:
  hi = U32.shln(r, 16n)
  md = U32.shln(g, 8n)
  U32.or(hi, U32.or(md, b))

# Lerp one channel a -> b by t (t in 0..1).
def Render.mix_chan(a: U32, b: U32, t: F32) -> U32:
  +af = U32.to_f32(a)
  bf = U32.to_f32(b)
  F32.to_u32(F32.clamp((af + ((bf - af : F32) * t : F32) : F32), 0.0, 255.0))

# Lerp packed colors c0 -> c1 by t.
def Render.mix_rgb(+c0: U32, +c1: U32, +t: F32) -> U32:
  r g = Render.mix_chan(Render.chan(c0, 16n), Render.chan(c1, 16n), t) Render.mix_chan(Render.chan(c0, 8n), Render.chan(c1, 8n), t)
  b = Render.mix_chan(Render.chan(c0, 0n), Render.chan(c1, 0n), t)
  Render.pack(r, g, b)

# Scale one channel by brightness b.
def Render.shade_chan(c: U32, k: Nat, b: F32) -> U32:
  F32.to_u32(F32.clamp((U32.to_f32(Render.chan(c, k)) * b : F32), 0.0, 255.0))

# Distance fog: brightness 1.0 -> 0.2 over ~64 steps, applied per channel.
def Render.shade(+c: U32, steps: U32) -> U32:
  +br = F32.clamp((1.0 - (U32.to_f32(steps) * 0.012 : F32) : F32), 0.2, 1.0)
  r g = Render.shade_chan(c, 16n, br) Render.shade_chan(c, 8n, br)
  b = Render.shade_chan(c, 0n, br)
  Render.pack(r, g, b)

# Sky gradient: day (horizon 0x87CEEB -> zenith 0x3B7DDD) lerped to
# night 0x0B1026 by a daylight factor from time (day cycle 0..1).
def Render.sky(dx: F32, dy: F32, dz: F32, time: F32) -> U32:
  up = F32.clamp(dy, 0.0, 1.0)
  day = Render.mix_rgb(8900331, 3898845, up)
  ang = (time * 6.2831853 : F32)
  e = F32.sin(ang)
  dl = F32.clamp(((e + 0.25 : F32) * 2.0 : F32), 0.0, 1.0)
  Render.mix_rgb(725030, day, dl)

# Primary ray through pixel (u, v) of a w-by-h frame.
# NDC = (u/w*2-1)*aspect etc., pinhole with tan(fov/2), then yaw (Y)
# and pitch (X) rotation, normalized. All divisions epsilon-guarded.
def Render.pixel_ray(cam: Cam, u: F32, v: F32, w: U32, h: U32) -> Ray:
  C{px, py, pz, +yaw, +pitch, fov} = cam
  +ws = Render.nonzero(U32.to_f32(w))
  +hs = Render.nonzero(U32.to_f32(h))
  aspect = (ws / hs : F32)
  qx = (u / ws : F32)
  qy = (v / hs : F32)
  nx = (((qx * 2.0 : F32) - 1.0 : F32) * aspect : F32)
  ny = (1.0 - (qy * 2.0 : F32) : F32)
  +t = F32.tan((fov / 2.0 : F32))
  +cx = (nx * t : F32)
  +cy = (ny * t : F32)
  +cz = (0.0 - 1.0 : F32)
  +sp = F32.sin(pitch)
  +cp = F32.cos(pitch)
  +sa = F32.sin(yaw)
  +ca = F32.cos(yaw)
  a1 = (cy * cp : F32)
  a2 = (cz * sp : F32)
  y1 = (a1 - a2 : F32)
  b1 = (cy * sp : F32)
  b2 = (cz * cp : F32)
  +z1 = (b1 + b2 : F32)
  c1 = (cx * ca : F32)
  c2 = (z1 * sa : F32)
  +x2 = (c1 + c2 : F32)
  d1 = (z1 * ca : F32)
  d2 = (cx * sa : F32)
  +z2 = (d1 - d2 : F32)
  +y2 = y1
  e1 = (x2 * x2 : F32)
  e2 = (y2 * y2 : F32)
  e3 = (z2 * z2 : F32)
  +len = Render.nonzero(F32.sqrt((e1 + (e2 + e3 : F32) : F32)))
  dx = (x2 / len : F32)
  dy = (y2 / len : F32)
  dz = (z2 / len : F32)
  R{px, py, pz, dx, dy, dz}

# Crosshair test: within 2px of frame center.
def Render.is_cross(+x: U32, +y: U32, +w: U32, +h: U32) -> Bool:
  +cx = U32.div(w, 2)
  +cy = U32.div(h, 2)
  nx = Bool.and(U32.is_ge(x, U32.sub(cx, 2)), U32.is_le(x, U32.add(cx, 2)))
  ny = Bool.and(U32.is_ge(y, U32.sub(cy, 2)), U32.is_le(y, U32.add(cy, 2)))
  Bool.and(nx, ny)

# Fixed-step raymarcher (0.25 voxels/step). fuel bounds the steps, so it
# is termination-safe. Hit => fog-shaded palette color, miss => sky.
# NOTE: ~get must answer 0 for out-of-bounds coords (including the huge
# U32 values that negative F32 positions convert to).
def Render.march(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, fuel: Nat, bid: U32, empty: Bool, px: F32, py: F32, pz: F32, +dx: F32, +dy: F32, +dz: F32, +steps: U32, +time: F32) -> U32:
  match fuel empty:
    case 0n False{}:
      Render.sky(dx, dy, dz, time)
    case 0n True{}:
      Render.sky(dx, dy, dz, time)
    case 1n+f False{}:
      Render.shade(color_of(bid), steps)
    case 1n+f True{}:
      +nx = (px + (dx * 0.25 : F32) : F32)
      +ny = (py + (dy * 0.25 : F32) : F32)
      +nz = (pz + (dz * 0.25 : F32) : F32)
      +nb = get(F32.to_u32(F32.floor(nx)), F32.to_u32(F32.floor(ny)), F32.to_u32(F32.floor(nz)))
      Render.march(~get, ~color_of, f, nb, U32.is_zero(nb), nx, ny, nz, dx, dy, dz, (steps + 1 : U32), time)

# Entry point game.bend calls: march a ray, return final U32 color.
def Render.trace(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, fuel: Nat, ox: F32, oy: F32, oz: F32, dx: F32, dy: F32, dz: F32, time: F32) -> U32:
  Render.march(~get, ~color_of, fuel, 0, True{}, ox, oy, oz, dx, dy, dz, 0, time)

# One framebuffer pixel: ray + trace + white crosshair dot.
def Render.pixel_go(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, r: Ray, +x: U32, +y: U32, +w: U32, +h: U32, +time: F32) -> U32:
  match r:
    case R{ox, oy, oz, dx, dy, dz}:
      t = Render.trace(~get, ~color_of, 64n, ox, oy, oz, dx, dy, dz, time)
      Bool.pick(U32, Render.is_cross(x, y, w, h), 16777215, t)

def Render.pixel(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, cam: Cam, +x: U32, +y: U32, +w: U32, +h: U32, +time: F32) -> U32:
  Render.pixel_go(~get, ~color_of, Render.pixel_ray(cam, U32.to_f32(x), U32.to_f32(y), w, h), x, y, w, h, time)

# Quadtree tile builder: size is depth (0n => one Pix). The 4 quadrants
# are built with parallel lets; size shrinks first, so it terminates.
def Render.build(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, +size: Nat, +cam: Cam, +x0: U32, +y0: U32, +w: U32, +h: U32, +time: F32) -> Image:
  match size:
    case 0n:
      Pix{Render.pixel(~get, ~color_of, cam, x0, y0, w, h, time)}
    case 1n+s:
      +half = U32.pow(2, s)
      +x1 = (x0 + half : U32)
      +y1 = (y0 + half : U32)
      tl tr = Render.build(~get, ~color_of, s, cam, x0, y0, w, h, time) Render.build(~get, ~color_of, s, cam, x1, y0, w, h, time)
      bl br = Render.build(~get, ~color_of, s, cam, x0, y1, w, h, time) Render.build(~get, ~color_of, s, cam, x1, y1, w, h, time)
      Qua{tl, tr, bl, br}

# Full 256x256 frame (depth 8).
def Render.frame(~get: U32 -> U32 -> U32 -> U32, ~color_of: U32 -> U32, cam: Cam, time: F32) -> Image:
  Render.build(~get, ~color_of, 8n, cam, 0, 0, 256, 256, time)

# ---- Additive pure helpers (appended; old defs untouched) ----
def Render.face_br05(n: Nat) -> F32:
  match n:
    case 0n:
      0.7
    case 1n+p:
      1.0

def Render.face_br04(n: Nat) -> F32:
  match n:
    case 0n:
      0.7
    case 1n+p:
      Render.face_br05(p)

def Render.face_br03(n: Nat) -> F32:
  match n:
    case 0n:
      0.8
    case 1n+p:
      Render.face_br04(p)

def Render.face_br02(n: Nat) -> F32:
  match n:
    case 0n:
      0.8
    case 1n+p:
      Render.face_br03(p)

def Render.face_br01(n: Nat) -> F32:
  match n:
    case 0n:
      0.55
    case 1n+p:
      Render.face_br02(p)

def Render.face_br00(n: Nat) -> F32:
  match n:
    case 0n:
      1.0
    case 1n+p:
      Render.face_br01(p)

def Render.face_br(face: U32) -> F32:
  Render.face_br00(U32.to_nat(face))

def Render.face_shade(+color: U32, face: U32) -> U32:
  +br = Render.face_br(face)
  r g = Render.shade_chan(color, 16n, br) Render.shade_chan(color, 8n, br)
  b = Render.shade_chan(color, 0n, br)
  Render.pack(r, g, b)

def Render.sun_dir(time: F32) -> F32 & F32 & F32:
  +ang = (time * 6.2831853 : F32)
  sx = F32.cos(ang)
  sy = F32.sin(ang)
  (sx, (sy, 0.0))

def Render.sun_hit(dx: F32, dy: F32, dz: F32, sx: F32, sy: F32, sz: F32) -> Bool:
  a1 = (dx * sx : F32)
  a2 = (dy * sy : F32)
  a3 = (dz * sz : F32)
  d12 = (a1 + a2 : F32)
  dot = (d12 + a3 : F32)
  F32.is_ge(dot, 0.9995)

def Render.sun_pick(hit: Bool, sky: U32) -> U32:
  match hit:
    case True{}:
      16777215
    case False{}:
      sky

def Render.sun_finish(sy: F32, sz: F32, sx: F32, +dx: F32, +dy: F32, +dz: F32, time: F32) -> U32:
  hit = Render.sun_hit(dx, dy, dz, sx, sy, sz)
  sky = Render.sky(dx, dy, dz, time)
  Render.sun_pick(hit, sky)

def Render.sun_mid(inner: F32 & F32, sx: F32, +dx: F32, +dy: F32, +dz: F32, time: F32) -> U32:
  (sy, sz) = inner
  Render.sun_finish(sy, sz, sx, dx, dy, dz, time)

def Render.sun_split(sun: F32 & F32 & F32, +dx: F32, +dy: F32, +dz: F32, +time: F32) -> U32:
  (sx, inner) = sun
  Render.sun_mid(inner, sx, dx, dy, dz, time)

def Render.sun_color(+dx: F32, +dy: F32, +dz: F32, +time: F32) -> U32:
  Render.sun_split(Render.sun_dir(time), dx, dy, dz, time)

def Render.cloud_pick(hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      False{}

def Render.cloud_hit(x: F32, z: F32, time: F32) -> Bool:
  t8 = (time * 8.0 : F32)
  xs = (x + t8 : F32)
  sc = (xs * 0.15 : F32)
  u = F32.to_u32(sc)
  m = U32.mod(u, 7)
  Render.cloud_pick(U32.is_lt(m, 2))

def Render.water_tint(+color: U32) -> U32:
  r = Render.shade_chan(color, 16n, 0.7)
  g = Render.shade_chan(color, 8n, 0.85)
  b = Render.shade_chan(color, 0n, 1.0)
  Render.pack(r, g, b)

def Render.mix_hurt(hit: Bool, +color: U32) -> U32:
  match hit:
    case True{}:
      Render.mix_rgb(color, 16711680, 0.5)
    case False{}:
      color

def Render.hurt_flash(+color: U32, ticks: U32) -> U32:
  Render.mix_hurt(U32.is_gt(ticks, 0), color)

def Render.vig_pick(edge: Bool, +color: U32) -> U32:
  match edge:
    case True{}:
      r = Render.shade_chan(color, 16n, 0.75)
      g = Render.shade_chan(color, 8n, 0.75)
      b = Render.shade_chan(color, 0n, 0.75)
      Render.pack(r, g, b)
    case False{}:
      color

def Render.vignette(+x: U32, +y: U32, +w: U32, +h: U32, +color: U32) -> U32:
  +qx = U32.div(w, 4)
  +qy = U32.div(h, 4)
  rx = U32.mul(qx, 3)
  ry = U32.mul(qy, 3)
  lx = U32.is_lt(x, qx)
  rxb = U32.is_ge(x, rx)
  ty = U32.is_lt(y, qy)
  by = U32.is_ge(y, ry)
  e1 = Bool.or(lx, rxb)
  e2 = Bool.or(ty, by)
  edge = Bool.or(e1, e2)
  Render.vig_pick(edge, color)

def Render.particle04(n: Nat) -> U32:
  match n:
    case 0n:
      16711935
    case 1n+p:
      16777215

def Render.particle03(n: Nat) -> U32:
  match n:
    case 0n:
      16753920
    case 1n+p:
      Render.particle04(p)

def Render.particle02(n: Nat) -> U32:
  match n:
    case 0n:
      3355443
    case 1n+p:
      Render.particle03(p)

def Render.particle01(n: Nat) -> U32:
  match n:
    case 0n:
      4197597
    case 1n+p:
      Render.particle02(p)

def Render.particle00(n: Nat) -> U32:
  match n:
    case 0n:
      11184810
    case 1n+p:
      Render.particle01(p)

def Render.particle(+kind: U32, +life: U32) -> U32:
  +base = Render.particle00(U32.to_nat(kind))
  lf = U32.to_f32(life)
  t = (lf / Render.nonzero(20.0) : F32)
  f = (1.0 - t : F32)
  +br = F32.clamp(f, 0.0, 1.0)
  r g = Render.shade_chan(base, 16n, br) Render.shade_chan(base, 8n, br)
  b = Render.shade_chan(base, 0n, br)
  Render.pack(r, g, b)

def Render.shade_face(color: U32, steps: U32, face: U32) -> U32:
  Render.face_shade(Render.shade(color, steps), face)

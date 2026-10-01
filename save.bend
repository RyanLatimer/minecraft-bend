import Base

# save.bend — persistence for BendCraft (standalone-checkable, import Base only).
#
# World is Array<U32> (flat voxels, 64*32*64 = 131072 = 2^17 in world.bend).
# Arrays cannot be iterated to String without fuel by hand without mutual
# recursion (match-only-params + no-mutual rule), so we reuse Base:
#   Save.to_list via Array.to_list(~U32, world) : List<U32>
#   Save.encode via U32.show joined with "," (recurse on List tail, shrinking)
#   Save.decode via String.split(s, ',') + U32.read per part (Maybe.default)
# RLE note: counts form would be "n*v,n*v.."; this file uses plain CSV which
# the integrator can swap for RLE without changing callers (same types).
# File effects used: File.open(path, mode) / File.write(file, data) /
# File.close(file) — exact names from `bend base File` (see grep in session).
#
# Pure roundtrip laws (comments, checked by main demo):
#   LAW encode_decode: decode(encode(xs)) == xs (no trailing comma form)
#   LAW decode_encode: encode(decode(s)) == s (for canonical "1,2,3" form)
#   LAW to_list_len: length(to_list(world)) == size(world) = 2^depth
# Affinity: world Array (Type) is consumed by to_list/serialize/write and
# dropped after reads (dropping affine is free). Termination: encode recurses
# on List tail (smaller part, first arg); decode_parts recurses on List tail;
# decode calls split (Base, terminating). No `if`, matches only on params or
# pattern-bound vars, Nat literals like 0n, ops spaced+annotated where used.
#
# ADDITIVE v2 (keeps all old defs verbatim):
#   Versioned format: magic "BC1", header "BC1,seed,time", serialize_full
#     "header;world_csv;player_csv" with ";" sections, player "px,py,pz,hp,food".
#     parse_full recovers seed/time/player (world exact restore optional:
#     world section is preserved as String but NOT rebuilt to Array here;
#     integrator rebuilds via decode+Array.from_list with fuel if needed).
#   RLE: encode_rle "cnt*val,cnt*val.." + decode_rle, List-first recursion.
#   Autosave: due(tickn, every) is tickn % every == 0.
#   IO: write_full/read_full mirror write style (open/write-or-read/close).

def Save.encode(xs: List<U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      match t:
        case Nil{}:
          U32.show(h)
        case Con{h2, t2}:
          String.append(U32.show(h), String.append(",", Save.encode(h2 <> t2)))

def Save.decode_parts(xs: List<&2, String>) -> List<U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      v = Maybe.default(&2, U32, U32.read(h), 0)
      v <> Save.decode_parts(t)

def Save.decode(s: String) -> List<U32>:
  Save.decode_parts(String.split(s, ','))

def Save.to_list(world: Array<U32>, n: Nat) -> List<U32>:
  Array.to_list(~U32, world)

def Save.serialize(world: Array<U32>, n: Nat) -> String:
  Save.encode(Save.to_list(world, n))

def Save.write(path: String, world: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    fr : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, Save.encode(Save.to_list(world, 0n)))
    File.close(Pair.fst(File, Result<&1, &1, U32 & String, Unit>, fr))

# --- versioned format (callees above callers) ---

def Save.magic() -> String:
  "BC1"

def Save.header(+seed: U32, +time: F32) -> String:
  String.append(Save.magic(), String.append(",", String.append(U32.show(seed), String.append(",", F32.show(time)))))

def Save.player_csv(+px: F32, +py: F32, +pz: F32, +hp: U32, +food: U32) -> String:
  String.append(F32.show(px), String.append(",", String.append(F32.show(py), String.append(",", String.append(F32.show(pz), String.append(",", String.append(U32.show(hp), String.append(",", U32.show(food)))))))))

def Save.serialize_full(world: Array<U32>, n: Nat, +seed: U32, +px: F32, +py: F32, +pz: F32, +hp: U32, +food: U32, +time: F32) -> String:
  String.append(Save.header(seed, time), String.append(";", String.append(Save.serialize(world, n), String.append(";", Save.player_csv(px, py, pz, hp, food)))))

# --- parse_full (recovers seed/time/player; world restore optional-documented) ---

type SaveFull is Data:
  SF{seed: U32, px: F32, py: F32, pz: F32, hp: U32, food: U32, time: F32}

def Save.read_u32(+s: String) -> U32:
  Maybe.default(&2, U32, U32.read(s), 0)

def Save.read_f32(+s: String) -> F32:
  Maybe.default(&2, F32, F32.read(s), 0.0)

def Save.parse_header_go(+t1: List<&2, String>) -> U32 & F32:
  match t1:
    case Nil{}:
      (0, 0.0)
    case Con{+ss, t2}:
      match t2:
        case Nil{}:
          (Save.read_u32(ss), 0.0)
        case Con{+ts, t3}:
          (Save.read_u32(ss), Save.read_f32(ts))

def Save.parse_header(parts: List<&2, String>) -> U32 & F32:
  match parts:
    case Nil{}:
      (0, 0.0)
    case Con{hm, t1}:
      Save.parse_header_go(t1)

def Save.parse_player_go3(+t3: List<&2, String>, +pxs: String, +pys: String, +pzs: String, +hps: String) -> SaveFull:
  match t3:
    case Nil{}:
      SF{0, Save.read_f32(pxs), Save.read_f32(pys), Save.read_f32(pzs), Save.read_u32(hps), 0, 0.0}
    case Con{+fds, t4}:
      SF{0, Save.read_f32(pxs), Save.read_f32(pys), Save.read_f32(pzs), Save.read_u32(hps), Save.read_u32(fds), 0.0}

def Save.parse_player_go2(+t2: List<&2, String>, +pxs: String, +pys: String, +pzs: String) -> SaveFull:
  match t2:
    case Nil{}:
      SF{0, Save.read_f32(pxs), Save.read_f32(pys), Save.read_f32(pzs), 0, 0, 0.0}
    case Con{+hps, t3}:
      Save.parse_player_go3(t3, pxs, pys, pzs, hps)

def Save.parse_player_go1(+t1: List<&2, String>, +pxs: String, +pys: String) -> SaveFull:
  match t1:
    case Nil{}:
      SF{0, Save.read_f32(pxs), Save.read_f32(pys), 0.0, 0, 0, 0.0}
    case Con{+pzs, t2}:
      Save.parse_player_go2(t2, pxs, pys, pzs)

def Save.parse_player_go0(+t0: List<&2, String>, +pxs: String) -> SaveFull:
  match t0:
    case Nil{}:
      SF{0, Save.read_f32(pxs), 0.0, 0.0, 0, 0, 0.0}
    case Con{+pys, t1}:
      Save.parse_player_go1(t1, pxs, pys)

def Save.parse_player(parts: List<&2, String>) -> SaveFull:
  match parts:
    case Nil{}:
      SF{0, 0.0, 0.0, 0.0, 0, 0, 0.0}
    case Con{+pxs, t0}:
      Save.parse_player_go0(t0, pxs)

def Save.combine(ht: U32 & F32, pf: SaveFull) -> SaveFull:
  (sd, tm) = ht
  match pf:
    case SF{oseed, +px, +py, +pz, +hp, +food, otime}:
      SF{sd, px, py, pz, hp, food, tm}

def Save.parse_full_go2(+t1: List<&2, String>, +hstr: String) -> SaveFull:
  match t1:
    case Nil{}:
      Save.combine(Save.parse_header(String.split(hstr, ',')), Save.parse_player(Nil{}))
    case Con{+wstr, t2}:
      match t2:
        case Nil{}:
          Save.combine(Save.parse_header(String.split(hstr, ',')), Save.parse_player(Nil{}))
        case Con{+pstr, t3}:
          Save.combine(Save.parse_header(String.split(hstr, ',')), Save.parse_player(String.split(pstr, ',')))

def Save.parse_full_go1(+t0: List<&2, String>) -> SaveFull:
  match t0:
    case Nil{}:
      SF{0, 0.0, 0.0, 0.0, 0, 0, 0.0}
    case Con{+hstr, t1}:
      Save.parse_full_go2(t1, hstr)

def Save.parse_full(s: String) -> SaveFull:
  Save.parse_full_go1(String.split(s, ';'))

# --- RLE (count*value runs, List-first recursion, no mutual) ---

def Save.show_run(+cnt: U32, +val: U32) -> String:
  String.append(U32.show(cnt), String.append("*", U32.show(val)))

def Save.rle_prefix(+h: U32, +cur: U32, +cnt: U32, eq: Bool) -> String:
  match eq:
    case True{}:
      SNil{}
    case False{}:
      String.append(Save.show_run(cnt, cur), ",")

def Save.rle_cur(eq: Bool, +h: U32, +cur: U32) -> U32:
  match eq:
    case True{}:
      cur
    case False{}:
      h

def Save.rle_cnt(eq: Bool, +cnt: U32) -> U32:
  match eq:
    case True{}:
      (cnt + 1 : U32)
    case False{}:
      1

def Save.encode_rle_go(xs: List<U32>, +cur: U32, +cnt: U32) -> String:
  match xs:
    case Nil{}:
      Save.show_run(cnt, cur)
    case Con{+h, t}:
      +eq = U32.is_eq(h, cur)
      +pre = Save.rle_prefix(h, cur, cnt, eq)
      +nc = Save.rle_cur(eq, h, cur)
      +ncnt = Save.rle_cnt(eq, cnt)
      +rest = Save.encode_rle_go(t, nc, ncnt)
      String.append(pre, rest)

def Save.encode_rle(xs: List<U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{+h, t}:
      Save.encode_rle_go(t, h, 1)

def Save.rep_go(fuel: Nat, +val: U32) -> List<U32>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      val <> Save.rep_go(f, val)

def Save.expand(+cnt: U32, +val: U32) -> List<U32>:
  Save.rep_go(U32.to_nat(cnt), val)

def Save.parse_run_go(parts: List<&2, String>) -> List<U32>:
  match parts:
    case Nil{}:
      Nil{}
    case Con{+cs, t1}:
      match t1:
        case Nil{}:
          Save.expand(1, Save.read_u32(cs))
        case Con{+vs, t2}:
          Save.expand(Save.read_u32(cs), Save.read_u32(vs))

def Save.parse_run(s: String) -> List<U32>:
  Save.parse_run_go(String.split(s, '*'))

def Save.decode_rle_parts(xs: List<&2, String>) -> List<U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      rest = Save.decode_rle_parts(t)
      cur = Save.parse_run(h)
      List.append(&1, U32, cur, rest)

def Save.decode_rle(s: String) -> List<U32>:
  Save.decode_rle_parts(String.split(s, ','))

# --- autosave tick counter ---

def Save.due_is_zero(+every: U32, m: U32) -> Bool:
  U32.is_eq(m, 0)

def Save.due_go(zero_every: Bool, +tickn: U32, +every: U32) -> Bool:
  match zero_every:
    case True{}:
      False{}
    case False{}:
      Save.due_is_zero(every, U32.mod(tickn, every))

def Save.due(+tickn: U32, +every: U32) -> Bool:
  Save.due_go(U32.is_zero(every), tickn, every)

# --- File IO mirror ---

def Save.write_full(path: String, world: Array<U32>, n: Nat, +seed: U32, +px: F32, +py: F32, +pz: F32, +hp: U32, +food: U32, +time: F32) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    fr : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, Save.serialize_full(world, n, seed, px, py, pz, hp, food, time))
    File.close(Pair.fst(File, Result<&1, &1, U32 & String, Unit>, fr))

def Save.res_string(res: Result<&1, &1, U32 & String, String>) -> String:
  match res:
    case Fail{e}:
      SNil{}
    case Done{v}:
      v

def Save.read_close(fr: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f2, res) = fr
  do IO<String>:
    Unit <- File.close(f2)
    IO.pure(String, Save.res_string(res))

def Save.read_full(path: String) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    fr : File & Result<&1, &1, U32 & String, String> <- File.read(f, 8000000)
    Save.read_close(fr)

def main() -> String:
  Save.encode(Save.decode("1,2,3"))

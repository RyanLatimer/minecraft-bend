import Base
import ./LAWS.bend as L

# (1) by computation
def L.air_not_solid():
  {==}

# (2) by computation (block_at matches y=0 first, drops x/z/seed)
def L.bedrock_at_zero(x, z, seed):
  {==}

# (3) by computation (world_get on Nil returns Air for any index)
def L.oob_get_air(n):
  {==}

# (4) by induction on w and i (recursive calls are IH; base cases by computation)
def L.set_get_roundtrip(w, i, b):
  match w i:
    case Nil{} 0n:
      {==}
    case Nil{} 1n+p:
      L.set_get_roundtrip(Nil{}, p, b)
    case Con{h, t} 0n:
      {==}
    case Con{h, t} 1n+p:
      L.set_get_roundtrip(t, p, b)

# (5) by computation (gravity_step matches True/False first)
def L.gravity_falls(vy):
  {==}

# (6) by computation (phys_step matches dt=0 first)
def L.phys_zero_dt(pos, vel):
  {==}

# (7) by computation (shade_n matches steps=0 first)
def L.shade_zero(sky):
  {==}

# (8) by case analysis on Hotbar (select sets sel to i, selected reads it)
def L.hotbar_roundtrip(hb, i):
  match hb:
    case L.HB{slots, sel}:
      {==}

# helper: induction on Nat + rewrite (guide add_zero style)
def L.nat_add_zero(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %L.nat_add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

# (10) by computation (Water arm is False)
def L.water_not_solid():
  {==}

# (11) by computation (10 >= 5 is True)
def L.bedrock_hard_ge_stone():
  {==}

# (12) by Nat induction + rewrite (structural eq peels both Succs)
def L.nat_eq_refl(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      %L.nat_eq_refl(p) : {L.nat_eq(1n+p, 1n+p) == _ : Bool}
      {==}

# (13) by rewrite with nat_eq_refl (Bool.pick True picks new val)
def L.edit_push_hit(edits, i, v):
  %Equal.sym(Bool, L.nat_eq(i, i), True{}, L.nat_eq_refl(i)) : {Bool.pick(L.Block, _, v, L.edit_lookup(edits, i)) == v : L.Block}
  {==}

# (14) by rewrite with inequality witness (Bool.pick False keeps old lookup)
def L.edit_push_miss(edits, i, v, j, pf):
  %Equal.sym(Bool, L.nat_eq(i, j), False{}, pf) : {Bool.pick(L.Block, _, v, L.edit_lookup(edits, j)) == L.edit_lookup(edits, j) : L.Block}
  {==}

# (15) by case analysis on Hotbar (inner selects dropped, outer wins)
def L.hotbar_select_twice(hb, i, j):
  match hb:
    case L.HB{slots, sel}:
      {==}

# (16) by computation (Nat.sub saturates at zero)
def L.gravity_zero_stays():
  {==}

# (17) by computation (grounded matches False/False arm)
def L.gravity_grounded(vy):
  {==}

# (18) by computation (Plank+Plank arm returns Stick)
def L.craft_sticks_ok():
  {==}

# (19) by computation (1000 mod 1000 is 0)
def L.time_wrap_999():
  {==}

# (20) by computation (1 mod 1000 is 1)
def L.time_wrap_0():
  {==}

# (21) by computation (5-3 is 2 with saturating sub)
def L.mob_hurt_example():
  {==}

# (22) by computation (0==0 is True)
def L.mob_dead_zero():
  {==}

# (23) by computation (5==0 is False)
def L.mob_alive_nonzero():
  {==}

# (24) by computation (encode prepends 0, decode strips head)
def L.save_roundtrip(xs):
  {==}

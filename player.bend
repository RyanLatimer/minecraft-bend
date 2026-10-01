import Base

type Vec3 is Data:
  V{x: F32, y: F32, z: F32}

type Player is Data:
  P{pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, on_ground: Bool, fly: Bool}

type Input is Data:
  I{fw: Bool, back: Bool, left: Bool, right: Bool, jump: Bool, down: Bool}

type Ctrl is Data:
  C{inp: Input, ldx: F32, ldy: F32, brk: Bool, plc: Bool, hot: U32, quit: Bool}

type Hotbar is Data:
  H{slots: List<&2, U32>, sel: U32}

type Slot is Data:
  S{block: U32, count: U32}

type Inv is Data:
  Inv{items: List<&2, Slot>}

def IsW(+code: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(code, 87), U32.is_eq(code, 119)), U32.is_eq(code, 38))

def IsA(+code: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(code, 65), U32.is_eq(code, 97)), U32.is_eq(code, 37))

def IsS(+code: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(code, 83), U32.is_eq(code, 115)), U32.is_eq(code, 40))

def IsD(+code: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(code, 68), U32.is_eq(code, 100)), U32.is_eq(code, 39))

def IsJump(+code: U32) -> Bool:
  U32.is_eq(code, 32)

def IsDownKey(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 67), U32.is_eq(code, 99))

def IsDownShift(+code: U32) -> Bool:
  Bool.or(IsDownKey(code), U32.is_eq(code, 16))

def IsBreakKey(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 69), U32.is_eq(code, 101))

def IsPlaceKey(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 81), U32.is_eq(code, 113))

def IsFlyKey(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 70), U32.is_eq(code, 102))

def IsQuitKey(+code: U32) -> Bool:
  U32.is_eq(code, 27)

def IsHot1(+code: U32) -> Bool:
  U32.is_eq(code, 49)

def IsHot2(+code: U32) -> Bool:
  U32.is_eq(code, 50)

def IsHot3(+code: U32) -> Bool:
  U32.is_eq(code, 51)

def IsHot4(+code: U32) -> Bool:
  U32.is_eq(code, 52)

def IsHot5(+code: U32) -> Bool:
  U32.is_eq(code, 53)

def IsHot6(+code: U32) -> Bool:
  U32.is_eq(code, 54)

def IsHot7(+code: U32) -> Bool:
  U32.is_eq(code, 55)

def IsHot8(+code: U32) -> Bool:
  U32.is_eq(code, 56)

def IsHot9(+code: U32) -> Bool:
  U32.is_eq(code, 57)

def IsBreakBtn(+btn: U32) -> Bool:
  U32.is_eq(btn, 0)

def IsPlaceBtn(+btn: U32) -> Bool:
  Bool.or(U32.is_eq(btn, 1), U32.is_eq(btn, 2))

def Input.empty() -> Input:
  I{False{}, False{}, False{}, False{}, False{}, False{}}

def Input.set_fw(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{v, back, left, right, jump, down}

def Input.set_back(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{fw, v, left, right, jump, down}

def Input.set_left(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{fw, back, v, right, jump, down}

def Input.set_right(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{fw, back, left, v, jump, down}

def Input.set_jump(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{fw, back, left, right, v, down}

def Input.set_down(inp: Input, v: Bool) -> Input:
  match inp:
    case I{fw, back, left, right, jump, down}:
      I{fw, back, left, right, jump, v}

def Ctrl.empty() -> Ctrl:
  C{Input.empty(), 0.0, 0.0, False{}, False{}, 0, False{}}

def Ctrl.set_fw(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{v, back, left, right, jump, down}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_back(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{fw, v, left, right, jump, down}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_left(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{fw, back, v, right, jump, down}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_right(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{fw, back, left, v, jump, down}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_jump(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{fw, back, left, right, v, down}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_down(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          C{I{fw, back, left, right, jump, v}, ldx, ldy, brk, plc, hot, quit}

def Ctrl.set_brk(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      C{inp, ldx, ldy, v, plc, hot, quit}

def Ctrl.set_plc(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      C{inp, ldx, ldy, brk, v, hot, quit}

def Ctrl.set_hot(ctrl: Ctrl, v: U32) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      C{inp, ldx, ldy, brk, plc, v, quit}

def Ctrl.set_quit(ctrl: Ctrl, v: Bool) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      C{inp, ldx, ldy, brk, plc, hot, v}

def Ctrl.add_look_go(inp: Input, ldx: F32, ldy: F32, brk: Bool, plc: Bool, hot: U32, quit: Bool, dx: F32, dy: F32) -> Ctrl:
  nx = (ldx + dx : F32)
  ny = (ldy + dy : F32)
  C{inp, nx, ny, brk, plc, hot, quit}

def Ctrl.add_look(ctrl: Ctrl, dx: F32, dy: F32) -> Ctrl:
  match ctrl:
    case C{inp, ldx, ldy, brk, plc, hot, quit}:
      Ctrl.add_look_go(inp, ldx, ldy, brk, plc, hot, quit, dx, dy)

def Ctrl.key_down_base(ctrl: Ctrl, code: U32) -> Ctrl:
  ctrl

def Ctrl.key_down_check_quit(is_q: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_q:
    case False{}:
      Ctrl.key_down_base(ctrl, code)
    case True{}:
      Ctrl.set_quit(ctrl, True{})

def Ctrl.key_down_check_h9(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_quit(IsQuitKey(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 8)

def Ctrl.key_down_check_h8(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h9(IsHot9(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 7)

def Ctrl.key_down_check_h7(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h8(IsHot8(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 6)

def Ctrl.key_down_check_h6(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h7(IsHot7(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 5)

def Ctrl.key_down_check_h5(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h6(IsHot6(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 4)

def Ctrl.key_down_check_h4(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h5(IsHot5(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 3)

def Ctrl.key_down_check_h3(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h4(IsHot4(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 2)

def Ctrl.key_down_check_h2(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h3(IsHot3(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 1)

def Ctrl.key_down_check_h1(is_h: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_h:
    case False{}:
      Ctrl.key_down_check_h2(IsHot2(code), ctrl, code)
    case True{}:
      Ctrl.set_hot(ctrl, 0)

def Ctrl.key_down_check_fly(is_f: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_f:
    case False{}:
      Ctrl.key_down_check_h1(IsHot1(code), ctrl, code)
    case True{}:
      ctrl

def Ctrl.key_down_check_plc(is_p: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_p:
    case False{}:
      Ctrl.key_down_check_fly(IsFlyKey(code), ctrl, code)
    case True{}:
      Ctrl.set_plc(ctrl, True{})

def Ctrl.key_down_check_brk(is_b: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_b:
    case False{}:
      Ctrl.key_down_check_plc(IsPlaceKey(code), ctrl, code)
    case True{}:
      Ctrl.set_brk(ctrl, True{})

def Ctrl.key_down_check_down(is_d: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_d:
    case False{}:
      Ctrl.key_down_check_brk(IsBreakKey(code), ctrl, code)
    case True{}:
      Ctrl.set_down(ctrl, True{})

def Ctrl.key_down_check_jump(is_j: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_j:
    case False{}:
      Ctrl.key_down_check_down(IsDownShift(code), ctrl, code)
    case True{}:
      Ctrl.set_jump(ctrl, True{})

def Ctrl.key_down_check_d(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_down_check_jump(IsJump(code), ctrl, code)
    case True{}:
      Ctrl.set_right(ctrl, True{})

def Ctrl.key_down_check_s(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_down_check_d(IsD(code), ctrl, code)
    case True{}:
      Ctrl.set_back(ctrl, True{})

def Ctrl.key_down_check_a(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_down_check_s(IsS(code), ctrl, code)
    case True{}:
      Ctrl.set_left(ctrl, True{})

def Ctrl.key_down_check_w(is_w: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_w:
    case False{}:
      Ctrl.key_down_check_a(IsA(code), ctrl, code)
    case True{}:
      Ctrl.set_fw(ctrl, True{})

def Ctrl.key_down(ctrl: Ctrl, +code: U32) -> Ctrl:
  Ctrl.key_down_check_w(IsW(code), ctrl, code)

def Ctrl.key_up_base(ctrl: Ctrl, code: U32) -> Ctrl:
  ctrl

def Ctrl.key_up_check_down(is_d: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_d:
    case False{}:
      Ctrl.key_up_base(ctrl, code)
    case True{}:
      Ctrl.set_down(ctrl, False{})

def Ctrl.key_up_check_jump(is_j: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_j:
    case False{}:
      Ctrl.key_up_check_down(IsDownShift(code), ctrl, code)
    case True{}:
      Ctrl.set_jump(ctrl, False{})

def Ctrl.key_up_check_d(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_up_check_jump(IsJump(code), ctrl, code)
    case True{}:
      Ctrl.set_right(ctrl, False{})

def Ctrl.key_up_check_s(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_up_check_d(IsD(code), ctrl, code)
    case True{}:
      Ctrl.set_back(ctrl, False{})

def Ctrl.key_up_check_a(is_k: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_k:
    case False{}:
      Ctrl.key_up_check_s(IsS(code), ctrl, code)
    case True{}:
      Ctrl.set_left(ctrl, False{})

def Ctrl.key_up_check_w(is_w: Bool, ctrl: Ctrl, +code: U32) -> Ctrl:
  match is_w:
    case False{}:
      Ctrl.key_up_check_a(IsA(code), ctrl, code)
    case True{}:
      Ctrl.set_fw(ctrl, False{})

def Ctrl.key_up(ctrl: Ctrl, +code: U32) -> Ctrl:
  Ctrl.key_up_check_w(IsW(code), ctrl, code)

def Ctrl.on_key(is_down: Bool, ctrl: Ctrl, code: U32) -> Ctrl:
  match is_down:
    case False{}:
      Ctrl.key_up(ctrl, code)
    case True{}:
      Ctrl.key_down(ctrl, code)

def Ctrl.mouse_base(ctrl: Ctrl, btn: U32) -> Ctrl:
  ctrl

def Ctrl.mouse_check_plc(is_p: Bool, ctrl: Ctrl, btn: U32) -> Ctrl:
  match is_p:
    case False{}:
      Ctrl.mouse_base(ctrl, btn)
    case True{}:
      Ctrl.set_plc(ctrl, True{})

def Ctrl.mouse_check_brk(is_b: Bool, ctrl: Ctrl, +btn: U32) -> Ctrl:
  match is_b:
    case False{}:
      Ctrl.mouse_check_plc(IsPlaceBtn(btn), ctrl, btn)
    case True{}:
      Ctrl.set_brk(ctrl, True{})

def Ctrl.on_mouse_down(is_down: Bool, ctrl: Ctrl, +btn: U32) -> Ctrl:
  match is_down:
    case False{}:
      ctrl
    case True{}:
      Ctrl.mouse_check_brk(IsBreakBtn(btn), ctrl, btn)

def Ctrl.on_move(ctrl: Ctrl, x: U32, y: U32) -> Ctrl:
  fx = U32.to_f32(x)
  fy = U32.to_f32(y)
  Ctrl.add_look(ctrl, fx, fy)

def Ctrl.on_close(ctrl: Ctrl) -> Ctrl:
  Ctrl.set_quit(ctrl, True{})

def Ctrl.apply(ctrl: Ctrl, e: Event) -> Ctrl:
  match ctrl e:
    case C{inp, ldx, ldy, brk, plc, hot, quit} Key{code, down}:
      Ctrl.on_key(down, C{inp, ldx, ldy, brk, plc, hot, quit}, code)
    case C{inp, ldx, ldy, brk, plc, hot, quit} Mouse{x, y, button, down}:
      Ctrl.on_mouse_down(down, C{inp, ldx, ldy, brk, plc, hot, quit}, button)
    case C{inp, ldx, ldy, brk, plc, hot, quit} Move{x, y}:
      Ctrl.on_move(C{inp, ldx, ldy, brk, plc, hot, quit}, x, y)
    case C{inp, ldx, ldy, brk, plc, hot, quit} Close{}:
      Ctrl.on_close(C{inp, ldx, ldy, brk, plc, hot, quit})

def Ctrl.from_events(events: List<Event>, acc: Ctrl) -> Ctrl:
  match events:
    case Nil{}:
      acc
    case Con{h, t}:
      Ctrl.from_events(t, Ctrl.apply(acc, h))

def Player.spawn(px: F32, py: F32, pz: F32) -> Player:
  P{V{px, py, pz}, V{0.0, 0.0, 0.0}, 0.0, 0.0, False{}, False{}}

def Player.clamp_pitch(p: F32, lo: F32, hi: F32) -> F32:
  F32.min(F32.max(p, lo), hi)

def Player.turn_go(pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, on_ground: Bool, fly: Bool, dx: F32, dy: F32) -> Player:
  nyaw = (yaw + (dx * 0.0025 : F32) : F32)
  npitch = (pitch + (dy * 0.0025 : F32) : F32)
  P{pos, vel, nyaw, Player.clamp_pitch(npitch, (0.0 - 1.5707963 : F32), 1.5707963), on_ground, fly}

def Player.turn(p: Player, dx: F32, dy: F32) -> Player:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      Player.turn_go(pos, vel, yaw, pitch, on_ground, fly, dx, dy)

def Player.apply_look(p: Player, ctrl: Ctrl) -> Player & Ctrl:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      match ctrl:
        case C{inp, ldx, ldy, brk, plc, hot, quit}:
          (Player.turn_go(pos, vel, yaw, pitch, on_ground, fly, ldx, ldy), C{inp, 0.0, 0.0, brk, plc, hot, quit})

def Player.eye_go(pos: Vec3, vel: Vec3, yaw: F32, pitch: F32, on_ground: Bool, fly: Bool) -> Vec3:
  match pos:
    case V{x, y, z}:
      V{x, (y + 1.62 : F32), z}

def Player.eye(p: Player) -> Vec3:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      Player.eye_go(pos, vel, yaw, pitch, on_ground, fly)

def Player.dir_go(pos: Vec3, vel: Vec3, +yaw: F32, +pitch: F32, on_ground: Bool, fly: Bool) -> Vec3:
  dx = F32.mul(F32.sin(yaw), F32.cos(pitch))
  dy = F32.sin(pitch)
  dz = F32.mul(F32.cos(yaw), F32.cos(pitch))
  V{dx, dy, dz}

def Player.dir(p: Player) -> Vec3:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      Player.dir_go(pos, vel, yaw, pitch, on_ground, fly)

def Player.wish_go(+yaw: F32, fw: Bool, back: Bool, left: Bool, right: Bool) -> F32 & F32:
  f_fw = Bool.pick(F32, fw, 1.0, 0.0)
  f_bk = Bool.pick(F32, back, 1.0, 0.0)
  s_lf = Bool.pick(F32, left, 1.0, 0.0)
  s_rt = Bool.pick(F32, right, 1.0, 0.0)
  +f = (f_fw - f_bk : F32)
  +s = (s_rt - s_lf : F32)
  fx = F32.sin(yaw)
  fz = F32.cos(yaw)
  sx = F32.cos(yaw)
  neg_sin = (0.0 - F32.sin(yaw) : F32)
  wx = ((f * fx : F32) + (s * sx : F32) : F32)
  wz = ((f * fz : F32) + (s * neg_sin : F32) : F32)
  (wx, wz)

def Player.wish_dir(p: Player, inp: Input) -> F32 & F32:
  match p:
    case P{pos, vel, +yaw, pitch, on_ground, fly}:
      match inp:
        case I{fw, back, left, right, jump, down}:
          Player.wish_go(yaw, fw, back, left, right)

def Player.toggle_fly(p: Player) -> Player:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      P{pos, vel, yaw, pitch, on_ground, Bool.not(fly)}

def Player.set_fly(p: Player, v: Bool) -> Player:
  match p:
    case P{pos, vel, yaw, pitch, on_ground, fly}:
      P{pos, vel, yaw, pitch, on_ground, v}

def Hotbar.default() -> Hotbar:
  H{[1, 3, 4, 9, 6, 5, 10, 11, 2], 0}

def Hotbar.get_go(xs: List<&2, U32>, n: Nat) -> Maybe<&2, U32>:
  match xs n:
    case Nil{} _:
      None{}
    case Con{h, t} 0n:
      Some{h}
    case Con{h, t} 1n+p:
      Hotbar.get_go(t, p)

def Hotbar.selected_or(+slots: List<&2, U32>, +sel: U32, res: Maybe<&2, U32>) -> U32:
  match res:
    case None{}:
      1
    case Some{v}:
      v

def Hotbar.selected(h: Hotbar) -> U32:
  match h:
    case H{+slots, +sel}:
      Hotbar.selected_or(slots, sel, Hotbar.get_go(slots, U32.to_nat(sel)))

def Hotbar.select_go(slots: List<&2, U32>, sel: U32, n: U32) -> Hotbar:
  H{slots, U32.mod(n, 9)}

def Hotbar.select(h: Hotbar, n: U32) -> Hotbar:
  match h:
    case H{slots, sel}:
      Hotbar.select_go(slots, sel, n)

def Hotbar.scroll_go(slots: List<&2, U32>, sel: U32, dir: U32) -> Hotbar:
  H{slots, U32.mod((sel + dir : U32), 9)}

def Hotbar.scroll(h: Hotbar, dir: U32) -> Hotbar:
  match h:
    case H{slots, sel}:
      Hotbar.scroll_go(slots, sel, dir)

def Inv.empty() -> Inv:
  Inv{Nil{}}

def Inv.add_go(xs: List<&2, Slot>, +b: U32, +n: U32) -> List<&2, Slot>:
  match xs:
    case Nil{}:
      S{b, n} <> Nil{}
    case Con{h, +t}:
      match h:
        case S{+block, +count}:
          rec = Inv.add_go(t, b, n)
          hit = U32.is_eq(block, b)
          new_c = (count + n : U32)
          Bool.pick(List<&2, Slot>, hit, S{b, new_c} <> t, S{block, count} <> rec)

def Inv.add(inv: Inv, b: U32, n: U32) -> Inv:
  match inv:
    case Inv{items}:
      Inv{Inv.add_go(items, b, n)}

def Inv.count_go(xs: List<&2, Slot>, +b: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      match h:
        case S{block, count}:
          rec = Inv.count_go(t, b)
          hit = U32.is_eq(block, b)
          Bool.pick(U32, hit, count, rec)

def Inv.count(inv: Inv, b: U32) -> U32:
  match inv:
    case Inv{items}:
      Inv.count_go(items, b)

def Inv.remove_go(xs: List<&2, Slot>, +b: U32, +n: U32) -> List<&2, Slot>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, +t}:
      match h:
        case S{+block, +count}:
          rec = Inv.remove_go(t, b, n)
          hit = U32.is_eq(block, b)
          enough = U32.is_ge(count, n)
          +new_c = (count - n : U32)
          Bool.pick(List<&2, Slot>, hit, Bool.pick(List<&2, Slot>, enough, Bool.pick(List<&2, Slot>, U32.is_eq(new_c, 0), t, S{b, new_c} <> t), t), S{block, count} <> rec)

def Inv.remove(inv: Inv, b: U32, n: U32) -> Inv:
  match inv:
    case Inv{items}:
      Inv{Inv.remove_go(items, b, n)}

# --- Sprint/sneak/attack/drop keys (additive, explicit codes + doc) ---
# Sprint = Ctrl (17). Double-W not tracked; sprint is explicit Ctrl hold.
# Sneak = Shift (16). Note IsDownShift already includes 16 (C/c or Shift);
#   sneak (16) is the Shift subset used for sneaking and eye height.
# Attack = R (82/114). Mouse break (btn 0) stays; R is keyboard attack.
# Drop = G (71/103).
def IsSprint(+code: U32) -> Bool:
  U32.is_eq(code, 17)

def IsSneak(+code: U32) -> Bool:
  U32.is_eq(code, 16)

def IsAttack(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 82), U32.is_eq(code, 114))

def IsDrop(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 71), U32.is_eq(code, 103))

# Attack reach 4.5 vs build reach 6.0.
def Player.reach() -> F32:
  4.5

def Player.build_reach() -> F32:
  6.0

# Eye height: stand 1.62, crouch 1.27.
def Player.eye_height(crouch: Bool) -> F32:
  match crouch:
    case True{}:
      1.27
    case False{}:
      1.62

# Hunger burns 1 when moving. Heal regens 1 when fed (food > 0).
def Player.hunger_tick(food: U32, moving: Bool) -> U32:
  match moving:
    case True{}:
      (food - 1 : U32)
    case False{}:
      food

def Player.heal_go(hp: U32, fed: Bool) -> U32:
  match fed:
    case True{}:
      (hp + 1 : U32)
    case False{}:
      hp

def Player.heal_tick(hp: U32, food: U32) -> U32:
  Player.heal_go(hp, U32.is_gt(food, 0))

# Hotbar: keep 9 slots. Count / find / swap helpers.
def Hotbar.count_go(xs: List<&2, U32>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      (1 + Hotbar.count_go(t) : U32)

def Hotbar.count(h: Hotbar) -> U32:
  match h:
    case H{slots, sel}:
      Hotbar.count_go(slots)

def Hotbar.find_go(xs: List<&2, U32>, +block: U32, +idx: U32) -> U32:
  match xs:
    case Nil{}:
      9
    case Con{h, t}:
      rec = Hotbar.find_go(t, block, (idx + 1 : U32))
      hit = U32.is_eq(h, block)
      Bool.pick(U32, hit, idx, rec)

def Hotbar.find(h: Hotbar, block: U32) -> U32:
  match h:
    case H{slots, sel}:
      Hotbar.find_go(slots, block, 0)

def Hotbar.set_go(xs: List<&2, U32>, n: Nat, v: U32) -> List<&2, U32>:
  match xs n:
    case Nil{} _:
      Nil{}
    case Con{h, t} 0n:
      v <> t
    case Con{h, t} 1n+p:
      h <> Hotbar.set_go(t, p, v)

def Hotbar.swap_go(+slots: List<&2, U32>, +sel: U32, +a: U32, +b: U32) -> Hotbar:
  va = Hotbar.selected_or(slots, sel, Hotbar.get_go(slots, U32.to_nat(a)))
  vb = Hotbar.selected_or(slots, sel, Hotbar.get_go(slots, U32.to_nat(b)))
  s1 = Hotbar.set_go(slots, U32.to_nat(a), vb)
  s2 = Hotbar.set_go(s1, U32.to_nat(b), va)
  H{s2, sel}

def Hotbar.swap(h: Hotbar, +a: U32, +b: U32) -> Hotbar:
  match h:
    case H{+slots, +sel}:
      Hotbar.swap_go(slots, sel, a, b)

# Extended controls: sprint/sneak/attack/drop. Ctrl is consumed by name
# elsewhere, so ExCtrl is a separate additive type with its own fold.
type ExCtrl is Data:
  X{sprint: Bool, sneak: Bool, attack: Bool, drop: Bool}

def ExCtrl.empty() -> ExCtrl:
  X{False{}, False{}, False{}, False{}}

def ExCtrl.set_sprint(ex: ExCtrl, v: Bool) -> ExCtrl:
  match ex:
    case X{sprint, sneak, attack, drop}:
      X{v, sneak, attack, drop}

def ExCtrl.set_sneak(ex: ExCtrl, v: Bool) -> ExCtrl:
  match ex:
    case X{sprint, sneak, attack, drop}:
      X{sprint, v, attack, drop}

def ExCtrl.set_attack(ex: ExCtrl, v: Bool) -> ExCtrl:
  match ex:
    case X{sprint, sneak, attack, drop}:
      X{sprint, sneak, v, drop}

def ExCtrl.set_drop(ex: ExCtrl, v: Bool) -> ExCtrl:
  match ex:
    case X{sprint, sneak, attack, drop}:
      X{sprint, sneak, attack, v}

def ExCtrl.from_base(prev: ExCtrl, code: U32) -> ExCtrl:
  prev

def ExCtrl.from_drop(is_d: Bool, prev: ExCtrl, +code: U32, down: Bool) -> ExCtrl:
  match is_d:
    case True{}:
      ExCtrl.set_drop(prev, down)
    case False{}:
      ExCtrl.from_base(prev, code)

def ExCtrl.from_attack(is_a: Bool, prev: ExCtrl, +code: U32, down: Bool) -> ExCtrl:
  match is_a:
    case True{}:
      ExCtrl.set_attack(prev, down)
    case False{}:
      ExCtrl.from_drop(IsDrop(code), prev, code, down)

def ExCtrl.from_sneak(is_s: Bool, prev: ExCtrl, +code: U32, down: Bool) -> ExCtrl:
  match is_s:
    case True{}:
      ExCtrl.set_sneak(prev, down)
    case False{}:
      ExCtrl.from_attack(IsAttack(code), prev, code, down)

def ExCtrl.from_sprint(is_sp: Bool, prev: ExCtrl, +code: U32, down: Bool) -> ExCtrl:
  match is_sp:
    case True{}:
      ExCtrl.set_sprint(prev, down)
    case False{}:
      ExCtrl.from_sneak(IsSneak(code), prev, code, down)

def ExCtrl.from_key(+code: U32, down: Bool, prev: ExCtrl) -> ExCtrl:
  ExCtrl.from_sprint(IsSprint(code), prev, code, down)

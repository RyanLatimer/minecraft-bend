import Base
import ./render.bend as R
import ./minecraft.bend as MC
import ./mobs.bend as MB

# bench.bend — headless perf test (no window needed).
# Renders one full 128x128 raymarched frame and prints a checksum.
# Build + time it:  bend bench.bend -o bench && time ./bench --threads 8

def Bench.sum(img: Image, acc: U32) -> U32:
  match img:
    case Pix{c}:
      (acc + c : U32)
    case Qua{tl, tr, bl, br}:
      +a = Bench.sum(tl, acc)
      +b = Bench.sum(tr, a)
      +c = Bench.sum(bl, b)
      Bench.sum(br, c)

def main() -> IO(Unit):
  do IO<Unit>:
    +cam = R.Render.cam_from(32.5, 24.0, 32.5, 0.0, 0.0, 1.2)
    +mobs = MC.MC.adopt(MB.Mob.spawn(1337, 6n, False{}))
    +img = MC.MC.frame(1337, Nil{}, mobs, cam, 0, 20, 20, 0, 0.3)
    +chk = Bench.sum(img, 0)
    IO.print(U32.show(chk))

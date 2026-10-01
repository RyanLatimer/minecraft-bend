import Base
# craft items 30-44 plus recipes smelt fuel eat
type Recipe is Data:
  R{out: U32, n: U32, a: U32, b: U32}
def Item.n44(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 44), "torch", "unknown")
def Item.n43(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 43), "pickaxe", Item.n44(id))
def Item.n42(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 42), "sword", Item.n43(id))
def Item.n41(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 41), "apple", Item.n42(id))
def Item.n40(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 40), "bread", Item.n41(id))
def Item.n39(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 39), "iron", Item.n40(id))
def Item.n38(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 38), "coal", Item.n39(id))
def Item.n37(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 37), "stick", Item.n38(id))
def Item.n36(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 36), "gunpowder", Item.n37(id))
def Item.n35(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 35), "string", Item.n36(id))
def Item.n34(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 34), "arrow", Item.n35(id))
def Item.n33(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 33), "bone", Item.n34(id))
def Item.n32(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 32), "feather", Item.n33(id))
def Item.n31(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 31), "beef", Item.n32(id))
def Item.n30(+id: U32) -> String:
  Bool.pick(String, U32.is_eq(id, 30), "pork", Item.n31(id))
def Item.name(+id: U32) -> String:
  Item.n30(id)
def Item.food41(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 41), 4, 0)
def Item.food40(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 40), 5, Item.food41(id))
def Item.food31(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 31), 3, Item.food40(id))
def Item.food30(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 30), 3, Item.food31(id))
def Item.food(+id: U32) -> U32:
  Item.food30(id)
def Item.stack43(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 43), 1, 64)
def Item.stack(+id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(id, 42), 1, Item.stack43(id))
def Craft.recipe7(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 7), R{34, 4, 32, 37}, R{0, 0, 0, 0})
def Craft.recipe6(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 6), R{10, 1, 6, 6}, Craft.recipe7(i))
def Craft.recipe5(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 5), R{39, 1, 13, 13}, Craft.recipe6(i))
# 4: 16+16->41 lawful aboard this game
def Craft.recipe4(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 4), R{41, 1, 16, 16}, Craft.recipe5(i))
def Craft.recipe3(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 3), R{43, 1, 4, 4}, Craft.recipe4(i))
def Craft.recipe2(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 2), R{42, 1, 4, 37}, Craft.recipe3(i))
def Craft.recipe1(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 1), R{44, 4, 37, 11}, Craft.recipe2(i))
def Craft.recipe0(+i: U32) -> Recipe:
  Bool.pick(Recipe, U32.is_eq(i, 0), R{37, 4, 9, 9}, Craft.recipe1(i))
def Craft.recipe(+i: U32) -> Recipe:
  Craft.recipe0(i)
def Craft.has(items: List<&2, U32>, +id: U32) -> Bool:
  match items:
    case Nil{}:
      False{}
    case Con{h, t}:
      rec = Craft.has(t, id)
      hit = U32.is_eq(h, id)
      Bool.or(hit, rec)
def Craft.can_go(r: Recipe, +items: List<&2, U32>) -> Bool:
  match r:
    case R{out, n, a, b}:
      ha = Craft.has(items, a)
      hb = Craft.has(items, b)
      Bool.and(ha, hb)
def Craft.can(+i: U32, +items: List<&2, U32>) -> Bool:
  Craft.can_go(Craft.recipe(i), items)
# smelt 6->10 else passthrough identity
def Craft.smelt6(+x: U32) -> U32:
  Bool.pick(U32, U32.is_eq(x, 6), 10, x)
def Craft.smelt(x: U32) -> U32:
  Craft.smelt6(x)
def Craft.fuel38(+b: U32) -> U32:
  Bool.pick(U32, U32.is_eq(b, 38), 1600, 0)
def Craft.fuel4(+b: U32) -> U32:
  Bool.pick(U32, U32.is_eq(b, 4), 300, Craft.fuel38(b))
def Craft.fuel(+b: U32) -> U32:
  Bool.pick(U32, U32.is_eq(b, 37), 100, Craft.fuel4(b))
def Craft.cap20_pick(hit: Bool, +x: U32) -> U32:
  match hit:
    case False{}:
      x
    case True{}:
      20
def Craft.cap20(+x: U32) -> U32:
  Craft.cap20_pick(U32.is_ge(x, 20), x)
def Craft.eat(hp: U32, food: U32, item: U32) -> U32 & U32:
  +g = Item.food(item)
  nhp = (hp + g : U32)
  nfood = (food + g : U32)
  (Craft.cap20(nhp), Craft.cap20(nfood))

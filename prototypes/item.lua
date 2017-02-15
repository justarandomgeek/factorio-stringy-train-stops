local item = copyPrototype("item","train-stop", "dynamic-train-stop")
item.icon = "__dynamic-train-stop__/graphics/dynamic-train-stop.png"
item.order = "a[train-system]-cb[train-stop]"

local recipe = copyPrototype("recipe","train-stop", "dynamic-train-stop")
recipe.ingredients = {
  {"train-stop", 1},
  {"advanced-circuit", 2}
}
recipe.enabled = false

local dynamic_train_stop = copyPrototype("train-stop", "train-stop", "dynamic-train-stop")
dynamic_train_stop.icon = "__dynamic-train-stop__/graphics/dynamic-train-stop.png"

data:extend({dynamic_train_stop,item, recipe})


local function copyPrototype(type, name, newName)
  if not data.raw[type][name] then error("type "..type.." "..name.." doesn't exist") end
  local p = table.deepcopy(data.raw[type][name])
  p.name = newName
  if p.minable and p.minable.result then
    p.minable.result = newName
  end
  if p.place_result then
    p.place_result = newName
  end
  if p.result then
    p.result = newName
  end
  return p
end

local item = copyPrototype("item","train-stop", "stringy-train-stop")
item.icon = "__stringy-train-stop__/graphics/stringy-train-stop.png"
item.icon_size = 32
item.order = "a[train-system]-cb[train-stop]"

local recipe = copyPrototype("recipe","train-stop", "stringy-train-stop")
recipe.ingredients = {
  {"train-stop", 1},
  {"advanced-circuit", 2}
}
recipe.enabled = false

local stringy_train_stop = copyPrototype("train-stop", "train-stop", "stringy-train-stop")
stringy_train_stop.icon = "__stringy-train-stop__/graphics/stringy-train-stop.png"
stringy_train_stop.icon_size = 32
stringy_train_stop.default_train_stopped_signal = {type = "virtual", name = "signal-grey"}
data:extend({stringy_train_stop,item, recipe})

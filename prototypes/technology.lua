data:extend({
  {
      type = "technology",
      name = "dynamic-train-stop",
      icon = "__dynamic-train-stop__/graphics/station-automation.png",
      icon_size = 128,
      prerequisites = {"circuit-network", "automated-rail-transportation"},
      effects =
      {
        {
            type = "unlock-recipe",
            recipe = "dynamic-train-stop"
        }
      },
      unit =
      {
        count = 50,
        ingredients =
        {
          {"science-pack-1", 1},
          {"science-pack-2", 1},
        },
        time = 20
      }
  }
})
data:extend({
  {
      type = "technology",
      name = "stringy-train-stop",
      icon = "__stringy-train-stop__/graphics/station-automation.png",
      icon_size = 128,
      prerequisites = {"circuit-network", "automated-rail-transportation"},
      effects =
      {
        {
            type = "unlock-recipe",
            recipe = "stringy-train-stop"
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

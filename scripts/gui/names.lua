-- Every element name in the priming window, in one place so the builder,
-- the view and the event dispatch cannot drift apart. All share the mod's
-- GUI prefix, which is how events tell our elements from other mods'.

local const = require("scripts.const")

local function named(suffix)
  return const.GUI_PREFIX .. suffix
end

return {
  window = const.WINDOW,
  close = named("close"),
  rows = named("rows"),
  recipe = named("recipe"),
  ingredients = named("ingredients"),
  output_slider = named("output_slider"),
  output_field = named("output_field"),
  output_icon = named("output_icon"),
  output_half = named("output_half"),
  output_max = named("output_max"),
  fuel = named("fuel"),
  fuel_slider = named("fuel_slider"),
  fuel_field = named("fuel_field"),
  fuel_half = named("fuel_half"),
  fuel_max = named("fuel_max"),
  fuel_note = named("fuel_note"),
  status = named("status"),
  blueprint = named("blueprint"),
  request = named("request"),
}

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
  recipe_overlay = named("recipe_overlay"),
  picker = named("picker"),
  pick = named("pick"),
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
  -- A chest window's own: the mode switch, items mode's block, its list of
  -- lines and trailing chooser, and the slots caption.
  mode = named("mode"),
  items = named("items"),
  item_rows = named("item_rows"),
  item_add = named("item_add"),
  slots = named("slots"),
  -- Handlers every items line shares, in its elements' tags; each element's
  -- own name is one of these plus "_" and the row id.
  row_item = named("row_item"),
  row_slider = named("row_slider"),
  row_slots = named("row_slots"),
  row_count = named("row_count"),
  row_half = named("row_half"),
  row_max = named("row_max"),
  status = named("status"),
  totals = named("totals"),
  blueprint = named("blueprint"),
  request = named("request"),
}

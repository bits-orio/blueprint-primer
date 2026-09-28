-- The window's two-column rows: recipe slot, ingredients and output for a
-- crafter or a chest in recipe mode, and the fuel row for a burner. Empty
-- controls only; view.refresh fills them from the Priming record.

local const = require("scripts.const")
local fuel = require("scripts.fuel")
local names = require("scripts.gui.names")
local widgets = require("scripts.gui.widgets")

local recipe_rows = {}

local SLOT = 40
local OVERLAY = 32
local ROW_SPACING = 8

-- One labelled line of the two-column layout; returns the control flow.
local function add_row(rows, caption)
  rows.add({ type = "label", style = "caption_label", caption = caption })
  local flow = rows.add({ type = "flow", direction = "horizontal" })
  flow.style.vertical_align = "center"
  flow.style.horizontal_spacing = ROW_SPACING
  return flow
end

-- Slider, number field, Half and Max: the same controls for crafts and for
-- a fuel-only target's fuel.
local function add_amount(flow, prefix, tooltip)
  widgets.slider(flow, names[prefix .. "_slider"], tooltip)
  widgets.number_field(flow, names[prefix .. "_field"], tooltip)
end

-- The recipe slot opens the picker (ADR-0009). Vanilla's "not unlocked"
-- sign is laid over it with a negative margin, the way core styles overlap
-- widgets, and ignores clicks so they reach the slot underneath.
local function add_recipe_slot(flow)
  flow.add({ type = "sprite-button", name = names.recipe, style = "slot_button" })
  local sign = flow.add({
    type = "sprite", name = names.recipe_overlay, sprite = "utility/crafting_machine_recipe_not_unlocked",
    resize_to_sprite = false, ignored_by_interaction = true,
  })
  sign.style.width = OVERLAY
  sign.style.height = OVERLAY
  sign.style.stretch_image_to_widget_size = true
  -- Back over the slot and the row gap, then in by half the size difference.
  sign.style.left_margin = (SLOT - OVERLAY) / 2 - SLOT - ROW_SPACING
end

-- A chest's slider stops where the chest is full, not at one stack.
local function output_tooltip(t)
  if t.kind == const.KIND_CHEST then return { "bp-primer.chest-output-tooltip" } end
  return { "bp-primer.output-tooltip" }
end

function recipe_rows.add_recipe(rows, t)
  add_recipe_slot(add_row(rows, { "bp-primer.recipe-label" }))
  add_row(rows, { "bp-primer.ingredients-label" }).add({
    type = "flow", name = names.ingredients, direction = "horizontal",
  }).style.horizontal_spacing = 0
  local output = add_row(rows, { "bp-primer.output-label" })
  add_amount(output, "output", output_tooltip(t))
  output.add({ type = "sprite-button", name = names.output_icon, style = "slot_button_in_shallow_frame" })
  widgets.button(output, names.output_half, "half")
  widgets.button(output, names.output_max, "max")
end

function recipe_rows.add_fuel(rows, t)
  local flow = add_row(rows, { "bp-primer.fuel-label" })
  flow.add({
    type = "choose-elem-button", name = names.fuel, elem_type = "item",
    elem_filters = fuel.filters(t), tooltip = { "bp-primer.fuel-tooltip" },
  })
  if t.kind == const.KIND_FUEL_ONLY then
    add_amount(flow, "fuel", { "bp-primer.fuel-amount-tooltip" })
    widgets.button(flow, names.fuel_half, "half")
    widgets.button(flow, names.fuel_max, "max")
    return
  end
  widgets.number_field(flow, names.fuel_field, { "bp-primer.fuel-field-tooltip" })
  flow.add({ type = "label", name = names.fuel_note })
end

return recipe_rows

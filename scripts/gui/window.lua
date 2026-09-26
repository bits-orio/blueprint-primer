-- Build and destroy the priming window. Building lays out empty controls;
-- every number, icon and enabled state is filled in by view.refresh, so
-- the layout here never depends on the record's current values.

local const = require("scripts.const")
local state = require("scripts.state")
local target = require("scripts.target")
local fuel = require("scripts.fuel")
local names = require("scripts.gui.names")
local priming = require("scripts.gui.priming")
local view = require("scripts.gui.view")

local window = {}

local function add_titlebar(frame, t)
  local bar = frame.add({ type = "flow", direction = "horizontal" })
  bar.style.horizontal_spacing = 8
  bar.drag_target = frame
  bar.add({
    type = "label",
    style = "frame_title",
    caption = { "bp-primer.title", t.prototype.localised_name },
    ignored_by_interaction = true,
  })
  local filler = bar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  filler.style.right_margin = 4
  filler.drag_target = frame
  bar.add({ type = "sprite-button", name = names.close, style = "close_button", sprite = "utility/close" })
end

-- One labelled line of the two-column layout; returns the control flow.
local function add_row(rows, caption)
  rows.add({ type = "label", style = "caption_label", caption = caption })
  local flow = rows.add({ type = "flow", direction = "horizontal" })
  flow.style.vertical_align = "center"
  flow.style.horizontal_spacing = 8
  return flow
end

local function add_button(flow, name, key)
  local button = flow.add({
    type = "button",
    name = name,
    caption = { "bp-primer." .. key },
    tooltip = { "bp-primer." .. key .. "-tooltip" },
  })
  button.style.minimal_width = 56
end

-- Every typed amount in the window: whole, non-negative numbers.
local function add_number_field(flow, name, tooltip)
  flow.add({
    type = "textfield", name = name, style = "slider_value_textfield",
    tooltip = tooltip, numeric = true, allow_decimal = false, allow_negative = false,
    lose_focus_on_confirm = true,
  })
end

-- Slider, number field, Half and Max: the same controls for crafts and for
-- a fuel-only target's fuel. The slider starts on a placeholder range,
-- since the engine refuses a minimum equal to the maximum.
local function add_amount(flow, prefix, tooltip)
  flow.add({
    type = "slider", name = names[prefix .. "_slider"], tooltip = tooltip,
    minimum_value = 0, maximum_value = 1, value = 1, value_step = 1, discrete_values = true,
  })
  add_number_field(flow, names[prefix .. "_field"], tooltip)
end

local function add_recipe_rows(rows, t)
  add_row(rows, { "bp-primer.recipe-label" }).add({
    type = "choose-elem-button", name = names.recipe, elem_type = "recipe",
    elem_filters = target.recipe_filters(t), tooltip = { "bp-primer.recipe-tooltip" },
  })
  add_row(rows, { "bp-primer.ingredients-label" }).add({
    type = "flow", name = names.ingredients, direction = "horizontal",
  }).style.horizontal_spacing = 0
  local output = add_row(rows, { "bp-primer.output-label" })
  add_amount(output, "output", { "bp-primer.output-tooltip" })
  output.add({ type = "sprite-button", name = names.output_icon, style = "slot_button_in_shallow_frame" })
  add_button(output, names.output_half, "half")
  add_button(output, names.output_max, "max")
end

local function add_fuel_row(rows, t)
  local flow = add_row(rows, { "bp-primer.fuel-label" })
  flow.add({
    type = "choose-elem-button", name = names.fuel, elem_type = "item",
    elem_filters = fuel.filters(t), tooltip = { "bp-primer.fuel-tooltip" },
  })
  if t.kind == const.KIND_FUEL_ONLY then
    add_amount(flow, "fuel", { "bp-primer.fuel-amount-tooltip" })
    add_button(flow, names.fuel_half, "half")
    add_button(flow, names.fuel_max, "max")
    return
  end
  add_number_field(flow, names.fuel_field, { "bp-primer.fuel-field-tooltip" })
  flow.add({ type = "label", name = names.fuel_note })
end

local function add_content(frame, t)
  local content = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  local rows = content.add({ type = "table", name = names.rows, column_count = 2 })
  rows.style.horizontal_spacing = 16
  rows.style.vertical_spacing = 8
  if t.kind ~= const.KIND_FUEL_ONLY then add_recipe_rows(rows, t) end
  if t.burner then add_fuel_row(rows, t) end
  local status = content.add({ type = "label", name = names.status })
  status.style.top_margin = 8
  status.style.single_line = false
  status.style.maximal_width = 400
end

-- Blueprint on the left, the confirming Request on the right, the way
-- vanilla dialogs put their back and confirm buttons.
local function add_buttons(frame)
  local flow = frame.add({ type = "flow", direction = "horizontal", style = "dialog_buttons_horizontal_flow" })
  flow.add({
    type = "button", name = names.blueprint, style = "dialog_button",
    caption = { "bp-primer.blueprint" }, tooltip = { "bp-primer.blueprint-tooltip" },
  })
  local filler = flow.add({ type = "empty-widget", style = "draggable_space" })
  filler.style.horizontally_stretchable = true
  filler.style.height = 32
  filler.drag_target = frame
  flow.add({
    type = "button", name = names.request, style = "confirm_button",
    caption = { "bp-primer.request" }, tooltip = { "bp-primer.request-tooltip" },
  })
end

function window.close(player)
  local frame = player.gui.screen[names.window]
  if frame and frame.valid then frame.destroy() end
  state.player(player.index).priming = nil
end

-- After a mod change the stored prototypes may be stale; drop every open
-- window rather than migrate half-built records.
function window.close_all()
  for _, player in pairs(game.players) do
    window.close(player)
  end
end

function window.open(player, t)
  window.close(player)
  state.player(player.index).priming = priming.new(t, player.index)
  local frame = player.gui.screen.add({ type = "frame", name = names.window, direction = "vertical" })
  frame.auto_center = true
  add_titlebar(frame, t)
  add_content(frame, t)
  add_buttons(frame)
  player.opened = frame
  view.refresh(player)
end

function window.notify(player, message)
  if type(message) == "string" then message = { message } end
  player.create_local_flying_text({ text = message, create_at_cursor = true })
end

return window

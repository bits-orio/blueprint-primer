-- Build and destroy the priming window. Building lays out empty controls;
-- every number, icon and enabled state is filled in by view.refresh, so
-- the layout here never depends on the record's current values.

local const = require("scripts.const")
local state = require("scripts.state")
local names = require("scripts.gui.names")
local priming = require("scripts.gui.priming")
local recipe_rows = require("scripts.gui.recipe_rows")
local item_table = require("scripts.gui.item_table")
local view = require("scripts.gui.view")

local window = {}

-- "Prime Stone furnace", or "Prime 6 × Stone furnace" for a group.
local function title(t, count)
  if count > 1 then return { "bp-primer.title-many", count, t.prototype.localised_name } end
  return { "bp-primer.title", t.prototype.localised_name }
end

local function add_titlebar(frame, t, count)
  local bar = frame.add({ type = "flow", direction = "horizontal" })
  bar.style.horizontal_spacing = 8
  bar.drag_target = frame
  bar.add({
    type = "label",
    style = "frame_title",
    caption = title(t, count),
    ignored_by_interaction = true,
  })
  local filler = bar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  filler.style.right_margin = 4
  filler.drag_target = frame
  bar.add({ type = "sprite-button", name = names.close, style = "close_button", sprite = "utility/close" })
end

-- A chest window's switch between its two modes (ADR-0013): left is
-- Recipe, right is Items. The view sets its state from the record.
local function add_mode_switch(content)
  local switch = content.add({
    type = "switch", name = names.mode, allow_none_state = false,
    left_label_caption = { "bp-primer.mode-recipe" }, right_label_caption = { "bp-primer.mode-items" },
    tooltip = { "bp-primer.mode-tooltip" },
  })
  switch.style.bottom_margin = 8
end

local function add_label(content, name, visible)
  local label = content.add({ type = "label", name = name })
  label.style.top_margin = 8
  label.visible = visible
  return label
end

-- Recipe mode's Output row (a slider, a field, the output icon, Half and
-- Max) is the widest part of a chest window, wider than an Items line. A
-- floor this wide on the content keeps the window from changing width when
-- the switch flips which block is visible; machines have no Items block
-- and never set it, so they render exactly as before.
local CHEST_CONTENT_WIDTH = 540

-- A chest builds both modes' controls once and the view shows one of them
-- (the picker's build-once precedent); a chest has no fuel row.
local function add_content(frame, t)
  local content = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  local chest = t.kind == const.KIND_CHEST
  if chest then
    add_mode_switch(content)
    content.style.minimal_width = CHEST_CONTENT_WIDTH
  end
  local rows = content.add({ type = "table", name = names.rows, column_count = 2 })
  rows.style.horizontal_spacing = 16
  rows.style.vertical_spacing = 8
  if t.kind ~= const.KIND_FUEL_ONLY then recipe_rows.add_recipe(rows, t) end
  if t.burner then recipe_rows.add_fuel(rows, t) end
  local picker = content.add({ type = "frame", name = names.picker, style = "inside_deep_frame", direction = "vertical" })
  picker.style.top_margin = 8
  picker.visible = false
  if chest then item_table.build(content) end
  add_label(content, names.totals, false)
  if chest then add_label(content, names.slots, true) end
  local status = add_label(content, names.status, true)
  status.style.single_line = false
  status.style.maximal_width = 400
end

-- A chest's buttons say chest, and its blueprint carries no recipe.
local function button_tooltip(t, key)
  if t.kind == const.KIND_CHEST then return { "bp-primer.chest-" .. key .. "-tooltip" } end
  return { "bp-primer." .. key .. "-tooltip" }
end

-- Blueprint on the left, the confirming Request on the right, the way
-- vanilla dialogs put their back and confirm buttons.
local function add_buttons(frame, t)
  local flow = frame.add({ type = "flow", direction = "horizontal", style = "dialog_buttons_horizontal_flow" })
  flow.add({
    type = "button", name = names.blueprint, style = "dialog_button",
    caption = { "bp-primer.blueprint" }, tooltip = button_tooltip(t, "blueprint"),
  })
  local filler = flow.add({ type = "empty-widget", style = "draggable_space" })
  filler.style.horizontally_stretchable = true
  filler.style.height = 32
  filler.drag_target = frame
  flow.add({
    type = "button", name = names.request, style = "confirm_button",
    caption = { "bp-primer.request" }, tooltip = button_tooltip(t, "request"),
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

-- `picked` is a resolved drag (scripts/selection.lua), when the window was
-- opened by one: its group and area travel in the Priming record.
function window.open(player, t, picked)
  window.close(player)
  local p = priming.new(t, player.index)
  if picked and #picked.group > 1 then p.group, p.area = picked.group, picked.area end
  state.player(player.index).priming = p
  local frame = player.gui.screen.add({ type = "frame", name = names.window, direction = "vertical" })
  frame.auto_center = true
  add_titlebar(frame, t, p.group and #p.group or 1)
  add_content(frame, t)
  add_buttons(frame, t)
  player.opened = frame
  view.refresh(player)
end

-- At the cursor, or at a map position when given one.
function window.notify(player, message, position)
  if type(message) == "string" then message = { message } end
  if position then return player.create_local_flying_text({ text = message, position = position }) end
  player.create_local_flying_text({ text = message, create_at_cursor = true })
end

return window

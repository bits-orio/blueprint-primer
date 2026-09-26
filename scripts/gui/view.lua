-- Fill the priming window from the player's Priming record. Recomputes
-- every number on each call and never rebuilds the frame; only the
-- ingredient icons are replaced, when the recipe or its quality changes.

local const = require("scripts.const")
local state = require("scripts.state")
local craft = require("scripts.craft")
local names = require("scripts.gui.names")
local priming = require("scripts.gui.priming")

local view = {}

local function index(element, found)
  if element.name ~= "" then found[element.name] = element end
  for _, child in pairs(element.children) do
    index(child, found)
  end
  return found
end

-- The engine refuses a slider whose minimum equals its maximum, so a
-- range of one value (or none) shows as a disabled 0..1 slider.
local function set_slider(slider, value, max)
  if max >= 2 then
    slider.set_slider_minimum_maximum(1, max)
  else
    slider.set_slider_minimum_maximum(0, 1)
  end
  slider.enabled = max >= 2
  slider.slider_value = value
end

-- The field being typed into is left alone, or every keystroke would be
-- rewritten mid-number.
local function set_text(field, value, skip)
  if field.name ~= skip then field.text = tostring(value) end
end

local function shown_quality(quality)
  if quality == const.NORMAL_QUALITY then return nil end
  return quality
end

local function add_ingredient(flow, ingredient, quality)
  local is_item = ingredient.type == "item"
  flow.add({
    type = "sprite-button",
    style = "slot_button_in_shallow_frame",
    sprite = ingredient.type .. "/" .. ingredient.name,
    quality = is_item and shown_quality(quality) or nil,
    elem_tooltip = { type = ingredient.type, name = ingredient.name },
    tooltip = not is_item and { "bp-primer.fluid-by-pipe" } or nil,
  })
end

local function refresh_ingredients(found, p)
  local flow = found[names.ingredients]
  if not flow then return end
  local ingredients = p.recipe and craft.ingredients(p.recipe) or {}
  -- A quality-only change (a locked furnace fed uncommon ore) re-badges them.
  if flow.tags.recipe ~= p.recipe or flow.tags.quality ~= p.quality then
    flow.clear()
    for _, ingredient in ipairs(ingredients) do
      add_ingredient(flow, ingredient, p.quality)
    end
    flow.tags = { recipe = p.recipe, quality = p.quality }
  end
  for i, button in ipairs(flow.children) do
    button.number = ingredients[i].amount * p.crafts
  end
end

local function refresh_output_icon(icon, p)
  icon.visible = p.recipe ~= nil
  if not p.recipe then return end
  local output = craft.output(p.recipe)
  local kind = output and output.type or "recipe"
  local name = output and output.name or p.recipe
  icon.sprite = kind .. "/" .. name
  icon.quality = shown_quality(p.quality)
  icon.elem_tooltip = { type = kind, name = name }
  -- "" rather than nil: a nil LocalisedString may render as the text "nil".
  icon.tooltip = not output and { "bp-primer.counts-crafts" } or ""
end

local function refresh_crafts(found, p, skip)
  local chooser = found[names.recipe]
  if not chooser then return end
  chooser.elem_value = p.recipe
  -- A locked chooser ignores clicks, so its tooltip says why.
  local locked = priming.recipe_locked(p)
  chooser.locked = locked
  chooser.tooltip = { locked and "bp-primer.recipe-locked-tooltip" or "bp-primer.recipe-tooltip" }
  refresh_ingredients(found, p)
  local cap = priming.cap(p)
  set_slider(found[names.output_slider], p.crafts, cap)
  set_text(found[names.output_field], priming.outputs(p), skip)
  found[names.output_field].enabled = cap >= 1
  found[names.output_half].enabled = cap >= 2
  found[names.output_max].enabled = cap >= 2
  refresh_output_icon(found[names.output_icon], p)
end

local function refresh_fuel(found, p, skip)
  local chooser = found[names.fuel]
  if not chooser then return end
  chooser.elem_value = p.fuel
  local field = found[names.fuel_field]
  set_text(field, p.fuel_count, skip)
  field.enabled = p.fuel ~= nil and p.fuel_count >= 1
  local slider = found[names.fuel_slider]
  if slider then
    local cap = priming.fuel_cap(p)
    set_slider(slider, p.fuel_count, cap)
    found[names.fuel_half].enabled = cap >= 2
    found[names.fuel_max].enabled = cap >= 2
  end
  local note = found[names.fuel_note]
  if note then
    local estimate = priming.estimate(p)
    note.caption = estimate and { "bp-primer.fuel-estimate", estimate } or ""
  end
end

-- A blocker explains a disabled Request; otherwise a built target gets a
-- reminder that requests top up rather than add.
local function refresh_footer(found, p)
  local blocker = priming.blocker(p)
  found[names.request].enabled = blocker == nil
  found[names.blueprint].enabled = blocker == nil
  local status = found[names.status]
  local message = blocker or (not p.target.is_ghost and "bp-primer.top-up-note") or nil
  status.visible = message ~= nil
  status.caption = message and { message } or ""
end

-- skip: the name of a text field the player is typing into, if any.
function view.refresh(player, skip)
  local frame = player.gui.screen[names.window]
  local p = state.player(player.index).priming
  if not (frame and frame.valid and p) then return end
  local found = index(frame, {})
  refresh_crafts(found, p, skip)
  refresh_fuel(found, p, skip)
  refresh_footer(found, p)
end

return view

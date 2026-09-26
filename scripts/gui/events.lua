-- GUI event handlers for the priming window. Each handler changes the
-- player's Priming record and nothing else; dispatch then refreshes the
-- view from the record. Elements are told apart by name, which also keeps
-- other mods' elements out.

local const = require("scripts.const")
local state = require("scripts.state")
local target = require("scripts.target")
local request = require("scripts.request")
local blueprint = require("scripts.blueprint")
local names = require("scripts.gui.names")
local picker = require("scripts.gui.picker")
local priming = require("scripts.gui.priming")
local window = require("scripts.gui.window")
local view = require("scripts.gui.view")

local events = {}

-- Why the record's machine can no longer be acted on: the player is now a
-- spectator, who cannot change machines in vanilla either; the machine is
-- gone (mined, destroyed, or a ghost that expired); or the player changed
-- force since the window opened (ADR-0005: always the acting player's
-- force). The entity's current force is compared, so a merge is caught too.
local function lost(player, p)
  if player.controller_type == defines.controllers.spectator then return const.REASON.SPECTATOR end
  if not target.revalidate(p.target) then return const.REASON.TARGET_GONE end
  if p.target.entity.force.index ~= player.force.index then return const.REASON.OTHER_FORCE end
  return nil
end

-- The player and their record, or nil after closing a window whose record
-- or machine is gone.
local function context(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return nil end
  local p = state.player(player.index).priming
  local why = p and lost(player, p)
  if not p or why then
    window.close(player)
    if why then window.notify(player, why) end
    return nil
  end
  return player, p
end

-- keep_text: leave the element's own text alone while it is being typed in.
-- If the machine's locked recipe changed underneath the window, the view
-- catches up and the action is dropped: a Request must never go out for a
-- recipe the player has not seen.
local function dispatch(handlers, event, keep_text)
  local element = event.element
  if not (element and element.valid) then return end
  local handler = handlers[element.name] or handlers[element.tags.handler]
  if not handler then return end
  local player, p = context(event)
  if not player then return end
  if priming.sync_locked(p) then
    window.notify(player, const.NOTICE.RECIPE_CHANGED)
    return view.refresh(player)
  end
  handler(player, p, element)
  view.refresh(player, keep_text and element.valid and element.name or nil)
end

-- Run Request or Blueprint; the window closes only on success, so a
-- refusal leaves every number in place for another try. A success may
-- carry a notice to show once the window is gone.
local function submit(player, p, act, fallback)
  if priming.blocker(p) then return end
  local ok, message = act()
  if not ok then return window.notify(player, message or fallback) end
  window.close(player)
  if message then window.notify(player, message) end
end

local function on_request(player, p)
  submit(player, p, function() return request.apply(p.target, p) end, "bp-primer.request-failed")
end

local function on_blueprint(player, p)
  submit(player, p, function() return blueprint.to_cursor(player, p.target, p) end, "bp-primer.blueprint-failed")
end

local function on_recipe_slot(player, p)
  local container = view.find(player, names.picker)
  if container then picker.toggle(container, p.target) end
end

-- Any listed recipe is allowed, researched or not (ADR-0009); a refusal
-- here means the machine changed under the open picker.
local function on_pick(player, p, element)
  local recipe = element.tags.recipe
  local container = view.find(player, names.picker)
  if container then picker.close(container) end
  if not priming.set_recipe(p, recipe) then
    window.notify(player, const.REASON.RECIPE_NOT_ALLOWED)
  end
end

local click = {
  [names.recipe] = on_recipe_slot,
  [names.pick] = on_pick,
  [names.output_half] = function(_, p) priming.preset_crafts(p, false) end,
  [names.output_max] = function(_, p) priming.preset_crafts(p, true) end,
  [names.fuel_half] = function(_, p) priming.preset_fuel(p, false) end,
  [names.fuel_max] = function(_, p) priming.preset_fuel(p, true) end,
  [names.request] = on_request,
  [names.blueprint] = on_blueprint,
}

local slider = {
  [names.output_slider] = function(_, p, element)
    priming.set_crafts(p, math.floor(element.slider_value + 0.5))
  end,
  [names.fuel_slider] = function(_, p, element)
    priming.set_fuel_count(p, math.floor(element.slider_value + 0.5))
  end,
}

-- An empty or partial field changes nothing; confirming it restores the
-- last good value, because the refresh after a confirm rewrites the text.
local text = {
  [names.output_field] = function(_, p, element)
    local outputs = tonumber(element.text)
    if outputs then priming.set_outputs(p, outputs) end
  end,
  [names.fuel_field] = function(_, p, element)
    local count = tonumber(element.text)
    if count then priming.set_fuel_count(p, count) end
  end,
}

-- A cleared or refused choice is reset by the refresh to the record's value.
local elem = {
  [names.fuel] = function(player, p, element)
    local item = element.elem_value
    if item and not priming.set_fuel(p, item, player.index) then
      window.notify(player, "bp-primer.fuel-not-accepted")
    end
  end,
}

function events.on_click(event)
  local element = event.element
  if element and element.valid and element.name == names.close then
    local player = game.get_player(event.player_index)
    if player and player.valid then window.close(player) end
    return
  end
  dispatch(click, event, false)
end

function events.on_value_changed(event)
  dispatch(slider, event, false)
end

function events.on_text_changed(event)
  dispatch(text, event, true)
end

function events.on_confirmed(event)
  dispatch(text, event, false)
end

function events.on_elem_changed(event)
  dispatch(elem, event, false)
end

-- E, Escape, or another GUI taking player.opened.
function events.on_closed(event)
  local element = event.element
  if not (element and element.valid and element.name == names.window) then return end
  local player = game.get_player(event.player_index)
  if player and player.valid then window.close(player) end
end

-- Dying, leaving, or changing force (an MTS team switch or spectate) clears
-- player.opened without raising on_gui_closed, which would strand the
-- window on screen with E and Escape no longer closing it.
function events.on_player_away(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then window.close(player) end
end

-- Becoming a spectator without a force change (a scenario or an admin's
-- set_controller) clears player.opened the same silent way. Only a window
-- that is no longer opened is closed, so a switch that keeps it opened,
-- such as remote view, leaves it alone.
function events.on_controller_changed(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local frame = player.gui.screen[names.window]
  if frame and frame.valid and player.opened ~= frame then window.close(player) end
end

return events

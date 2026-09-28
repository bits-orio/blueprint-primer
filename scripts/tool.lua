-- The three ways into the priming window: the primer tool's selection, the
-- shortcut-bar button, and the hover hotkey. A drag resolves one kind of
-- machine or chest (scripts/selection.lua); the hotkey, one. Each opens the
-- window, or hands the player the tool to pick with.

local const = require("scripts.const")
local target = require("scripts.target")
local selection = require("scripts.selection")
local window = require("scripts.gui.window")

local tool = {}

local function holding_tool(player)
  local cursor = player.cursor_stack
  return cursor and cursor.valid_for_read and cursor.name == const.TOOL
end

-- Once a machine is picked the tool has done its job, so it leaves the
-- cursor as the window opens. Only the tool is ever cleared: anything else
-- the player holds stays put.
local function open(player, t, picked)
  if holding_tool(player) then player.clear_cursor() end
  window.open(player, t, picked)
end

local function outline(player, entity, box_type)
  entity.surface.create_entity({
    name = "highlight-box", position = entity.position, bounding_box = entity.selection_box,
    box_type = box_type, render_player_index = player.index,
    time_to_live = const.HINT_TICKS, blink_interval = const.HINT_BLINK_TICKS,
  })
end

-- Just above the middle of the dragged area, where the eye already is; the
-- cursor sits at the drag's far corner, often at the screen edge.
local function above(area)
  local left_top, right_bottom = area.left_top or area[1], area.right_bottom or area[2]
  local x1, y1 = left_top.x or left_top[1], left_top.y or left_top[2]
  local x2 = right_bottom.x or right_bottom[1]
  return { x = (x1 + x2) / 2, y = y1 - 1 }
end

-- After a drag over several machines, show briefly which are being primed
-- (vanilla's copy colour) and which were skipped as another kind (its red
-- "not allowed"), for this player only (ADR-0011). Skipping also gets a
-- line of flying text naming what is primed.
local function hint(player, picked)
  if #picked.group < 2 and #picked.skipped == 0 then return end
  for _, t in ipairs(picked.group) do outline(player, t.entity, "copy") end
  for _, entity in ipairs(picked.skipped) do outline(player, entity, "not-allowed") end
  if #picked.skipped == 0 then return end
  -- A chest group is also one quality (selection.member); a machine group
  -- is not, so only the chest wording claims it.
  local notice = picked.primary.kind == const.KIND_CHEST and const.NOTICE.ONE_KIND_QUALITY or const.NOTICE.ONE_KIND
  window.notify(player, { notice, #picked.group, picked.primary.prototype.localised_name, #picked.skipped },
    above(picked.area))
end

-- Pressing the button while already holding the tool puts it away, like
-- vanilla's planner shortcuts. No cursor at all means a spectator.
local function toggle_tool(player)
  local cursor = player.cursor_stack
  if not cursor then return end
  if holding_tool(player) then
    player.clear_cursor()
    return
  end
  if not player.clear_cursor() then return window.notify(player, const.REASON.CURSOR_BLOCKED) end
  cursor.set_stack({ name = const.TOOL })
end

-- A hovered machine or chest the tool could never prime says why, as a
-- click with the tool would. Anything else hovered (a tree, bare ground)
-- hands over the tool instead; a neutral tree must not claim another force.
local function refusal_worth_saying(entity, why)
  if why == const.REASON.UNSUPPORTED or why == const.REASON.LOGISTIC_CHEST then return true end
  return why == const.REASON.OTHER_FORCE and target.from_entity(entity) ~= nil
end

-- The tool's entity filters leave logistic chests out, so a click on one
-- selects nothing; it still gets told why, not "nothing to prime". A click's
-- area is a single point, which misses the outer ring of the chest's
-- selection box (that box is what the engine actually clicked against), so
-- player.selected is checked first; the area search is only a fallback for
-- a drag, which has no player.selected of its own.
local function logistic_chest_selected(player)
  local selected = player.selected
  if not (selected and selected.valid and selected.force.index == player.force.index) then return false end
  if selected.type == const.LOGISTIC_CHEST_TYPE then return true end
  return selected.type == const.GHOST_TYPE and selected.ghost_type == const.LOGISTIC_CHEST_TYPE
end

local function logistic_chest_in(event, force)
  local surface = event.surface
  if not (surface and surface.valid) then return false end
  local built = surface.find_entities_filtered({
    area = event.area, type = const.LOGISTIC_CHEST_TYPE, force = force, limit = 1,
  })
  if #built > 0 then return true end
  return #surface.find_entities_filtered({
    area = event.area, type = const.GHOST_TYPE, ghost_type = const.LOGISTIC_CHEST_TYPE, force = force, limit = 1,
  }) > 0
end

local function nothing_to_prime(event, player, reason)
  if not reason and (logistic_chest_selected(player) or logistic_chest_in(event, player.force)) then
    reason = const.REASON.LOGISTIC_CHEST
  end
  window.notify(player, reason or "bp-primer.nothing-to-prime")
end

function tool.on_selected(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local picked, reason = selection.resolve(event.entities or {}, event.area, player.force)
  if not picked then return nothing_to_prime(event, player, reason) end
  picked.area = event.area
  open(player, picked.primary, picked)
  hint(player, picked)
end

function tool.on_shortcut(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  toggle_tool(player)
end

-- A spectator can hover machines but, as in vanilla, not change them.
function tool.on_hotkey(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  if player.controller_type == defines.controllers.spectator then return end
  local selected = player.selected
  if selected and selected.valid then
    local t, why = target.from_entity(selected, player.force)
    if t then return open(player, t) end
    if refusal_worth_saying(selected, why) then return window.notify(player, why) end
  end
  toggle_tool(player)
end

return tool

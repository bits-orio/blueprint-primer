-- The three ways into the priming window: the primer tool's selection, the
-- shortcut-bar button, and the hover hotkey. Each resolves one target and
-- opens the window, or hands the player the tool to pick one.

local const = require("scripts.const")
local target = require("scripts.target")
local window = require("scripts.gui.window")

local tool = {}

-- BoundingBox and MapPosition arrive either keyed or positional.
local function xy(position)
  return position.x or position[1], position.y or position[2]
end

local function centre(area)
  local x1, y1 = xy(area.left_top or area[1])
  local x2, y2 = xy(area.right_bottom or area[2])
  return (x1 + x2) / 2, (y1 + y2) / 2
end

local function distance_sq(entity, cx, cy)
  local x, y = xy(entity.position)
  return (x - cx) ^ 2 + (y - cy) ^ 2
end

-- Nearest the drag's centre wins (ADR-0001). target.from_entity only runs
-- on entities closer than the best so far, so a drag across a whole base
-- stays cheap. Returns the target, or the reason the nearest entity failed.
local function nearest_target(entities, area, force)
  local cx, cy = centre(area)
  local best, best_distance, reason, reason_distance
  for _, entity in pairs(entities) do
    local distance = entity.valid and distance_sq(entity, cx, cy)
    if distance and (not best_distance or distance < best_distance) then
      local t, why = target.from_entity(entity, force)
      if t then
        best, best_distance = t, distance
      elseif not reason_distance or distance < reason_distance then
        reason, reason_distance = why, distance
      end
    end
  end
  return best, reason
end

-- Pressing the button while already holding the tool puts it away, like
-- vanilla's planner shortcuts. No cursor at all means a spectator.
local function toggle_tool(player)
  local cursor = player.cursor_stack
  if not cursor then return end
  if cursor.valid_for_read and cursor.name == const.TOOL then
    player.clear_cursor()
    return
  end
  if not player.clear_cursor() then return window.notify(player, const.REASON.CURSOR_BLOCKED) end
  cursor.set_stack({ name = const.TOOL })
end

-- A hovered machine the tool could never prime says why, as a click with
-- the tool would. Anything else hovered (a chest, a tree, bare ground)
-- hands over the tool instead; a neutral tree must not claim another force.
local function refusal_worth_saying(entity, why)
  if why == const.REASON.UNSUPPORTED then return true end
  return why == const.REASON.OTHER_FORCE and target.from_entity(entity) ~= nil
end

function tool.on_selected(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local t, reason = nearest_target(event.entities or {}, event.area, player.force)
  if t then return window.open(player, t) end
  window.notify(player, reason or "bp-primer.nothing-to-prime")
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
    if t then return window.open(player, t) end
    if refusal_worth_saying(selected, why) then return window.notify(player, why) end
  end
  toggle_tool(player)
end

return tool

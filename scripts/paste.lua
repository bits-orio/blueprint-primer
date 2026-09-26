-- Shift+click settings paste carries a pending primed request (ADR-0008).
-- The source's Priming is derived the way a reopened window derives it,
-- then applied to the destination through request.apply, so the
-- destination gets its own top-up and its own fuel estimate.

local state = require("scripts.state")
local target = require("scripts.target")
local carried = require("scripts.carried")
local fuel = require("scripts.fuel")
local request = require("scripts.request")
local priming = require("scripts.gui.priming")
local window = require("scripts.gui.window")

local paste = {}

-- The destination Target once its request is written, else nil. Another
-- kind of machine, one whose burner cannot take the source's fuel, or one
-- that cannot take its recipe (request.apply refuses that, as the window
-- would), is left to vanilla. An electric machine needs no fuel, so it
-- takes the ingredients alone.
function paste.apply(source, destination, force, player_index)
  local from = carried.priming(source, force, player_index)
  local to = from and target.from_entity(destination, force)
  if not (to and to.kind == from.target.kind) then return nil end
  if from.fuel and to.burner and not fuel.accepts(to, from.fuel) then return nil end
  local p = priming.new(to, player_index, from)
  if priming.blocker(p) or not request.apply(to, p) then return nil end
  return to
end

-- The paste reads the source and changes only the destination. A window
-- open on it would show numbers the paste replaced, so it is reopened from
-- the new request, as ALT + P would. Its target is revalidated first, as
-- the next GUI event would, in case robots built the ghost it was opened on.
function paste.on_pasted(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local t = paste.apply(event.source, event.destination, player.force, player.index)
  local open = t and state.player(player.index).priming
  if open and target.revalidate(open.target) and open.target.entity == event.destination then
    window.open(player, t)
  end
end

return paste

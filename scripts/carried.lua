-- The priming a machine carries into a copy or a settings paste (ADR-0008):
-- derived the way a reopened window derives it, so the copy is primed like
-- the source rather than for whatever happens to be still in flight.

local const = require("scripts.const")
local target = require("scripts.target")
local pending = require("scripts.pending")
local priming = require("scripts.gui.priming")

local carried = {}

-- Pending ingredients are what make a crafter's request primed: vanilla
-- itself only asks a built crafter for fuel and modules. Fuel-only targets
-- (a locomotive's schedule paste, say) are left to vanilla.
function carried.priming(entity, force, player_index)
  local t = target.from_entity(entity, force)
  if not t or t.kind == const.KIND_FUEL_ONLY then return nil end
  if #pending.within(pending.plans(t), defines.inventory.crafter_input) == 0 then return nil end
  local p = priming.new(t, player_index)
  if priming.blocker(p) then return nil end
  return p
end

return carried

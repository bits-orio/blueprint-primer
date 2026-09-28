-- The priming a machine carries into a copy or a settings paste (ADR-0008):
-- derived the way a reopened window derives it, so the copy is primed like
-- the source rather than for whatever happens to be still in flight.

local const = require("scripts.const")
local target = require("scripts.target")
local pending = require("scripts.pending")
local request = require("scripts.request")
local priming = require("scripts.gui.priming")

local carried = {}

-- Pending ingredients are what make a crafter's request primed: vanilla
-- itself only asks a built crafter for fuel and modules. A chest is primed
-- by pending positions in its own inventory. Fuel-only targets (a
-- locomotive's schedule paste, say) are left to vanilla.
function carried.priming(entity, force, player_index)
  local t = target.from_entity(entity, force)
  if not t or t.kind == const.KIND_FUEL_ONLY then return nil end
  if #pending.within(pending.plans(t), target.input_inventory(t)) == 0 then return nil end
  local p = priming.new(t, player_index)
  if priming.blocker(p) then return nil end
  return p
end

-- Primes `to` like `from`: the same recipe, crafts and fuel (a chest's mode
-- and rows), fitted to this machine (its own cap, top-up and fuel estimate
-- unless the amount was typed). Shared by settings paste and a group
-- Request (ADR-0011).
function carried.apply(to, from, player_index)
  local p = priming.new(to, player_index, from)
  local blocked = priming.blocker(p)
  if blocked then return false, blocked end
  return request.apply(to, p)
end

return carried

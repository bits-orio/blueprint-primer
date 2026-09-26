-- state.lua: records left by 0.1.x (Factorio 1.1), whose `global` a 2.0 load
-- carries over as `storage`: `players[i] = {max_stack = false}` with no fuel
-- memory, and one server-wide `preferred_fuel`.

local check = require("lib.check")
local rig = require("lib.rig")
local state = require("__BlueprintPrimer__/scripts/state")
local target = require("__BlueprintPrimer__/scripts/target")
local fuel = require("__BlueprintPrimer__/scripts/fuel")

local cases = {}

-- Player indices no other case touches.
local LEGACY = 21
local MIGRATED = 22

local function legacy_record(surface)
  local stone = assert(target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(-30, 42)), rig.FORCE))
  storage.players[LEGACY] = { max_stack = false }
  check.eq("state legacy record: fuel.default does not crash", fuel.default(stone, LEGACY), "coal")
  fuel.remember(LEGACY, stone, "solid-fuel")
  check.eq("state legacy record: fuel.remember stores the pick",
    storage.players[LEGACY].fuel_by_category.chemical, "solid-fuel")
end

local function init_migrates()
  storage.players[MIGRATED] = { max_stack = true }
  storage.preferred_fuel = "coal"
  state.init()
  local record = storage.players[MIGRATED]
  check.same("state.init migrates 0.1.x storage", {
    max_stack = record.max_stack, memory = type(record.fuel_by_category), preferred = storage.preferred_fuel,
  }, { memory = "table" })
end

function cases.run(surface)
  check.run("state.legacy_record", function() legacy_record(surface) end)
  check.run("state.init_migrates", init_migrates)
end

return cases

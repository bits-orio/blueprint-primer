-- Headless contract and delivery tests for Machine Primer. Everything runs
-- from on_init (tick 0) except the delivery checks, which wait for robots and
-- furnaces to finish. dev/run-tests.sh reads the BP_TEST log lines.

local check = require("lib.check")
local rig = require("lib.rig")
local state = require("__BlueprintPrimer__/scripts/state")
local craft_cases = require("cases.craft")
local fuel_cases = require("cases.fuel")
local target_cases = require("cases.target")
local request_cases = require("cases.request")
local blueprint_cases = require("cases.blueprint")
local quality_cases = require("cases.quality")
local biochamber_cases = require("cases.biochamber")
local priming_cases = require("cases.priming")
local copy_cases = require("cases.copy")
local paste_cases = require("cases.paste")
local state_cases = require("cases.state")
local research_cases = require("cases.research")
local delivery = require("cases.delivery")

-- Long enough for robots to deliver and a stone furnace to smelt 50 ore.
local CHECK_TICK = 15000

local function space_age()
  return script.active_mods["space-age"] ~= nil
end

script.on_init(function()
  state.init()
  local surface = rig.prepare()
  rig.robots(surface)
  check.info("inventories fuel=" .. defines.inventory.fuel .. " crafter_input=" .. defines.inventory.crafter_input
    .. " crafter_modules=" .. defines.inventory.crafter_modules)
  craft_cases.run(surface)
  fuel_cases.run(surface)
  target_cases.run(surface)
  request_cases.run(surface)
  blueprint_cases.run(surface)
  priming_cases.run(surface)
  copy_cases.run(surface)
  research_cases.run(surface)
  paste_cases.run(surface)
  state_cases.run(surface)
  if space_age() then
    quality_cases.run(surface)
    biochamber_cases.run(surface)
  end
  delivery.setup(surface)
end)

script.on_nth_tick(CHECK_TICK, function(event)
  -- on_nth_tick also fires on tick 0; only the real check tick counts.
  if event.tick == 0 or storage.finished then return end
  storage.finished = true
  local surface = game.surfaces.nauvis
  delivery.verify(surface)
  check.run("priming.verify", priming_cases.verify)
  if space_age() then
    check.run("quality.verify", quality_cases.verify)
    check.run("biochamber.verify", biochamber_cases.verify)
  end
  check.done()
end)

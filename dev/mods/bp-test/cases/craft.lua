-- craft.lua: per-craft amounts, the slot cap, the output unit.

local check = require("lib.check")
local rig = require("lib.rig")
local craft = require("__BlueprintPrimer__/scripts/craft")

local cases = {}

local function slot_cap()
  check.eq("craft.slot_cap iron-plate", craft.slot_cap("iron-plate"), 50)
  check.eq("craft.slot_cap stone-brick", craft.slot_cap("stone-brick"), 25)
  check.eq("craft.slot_cap electronic-circuit", craft.slot_cap("electronic-circuit"), 66)
  check.eq("craft.slot_cap fluid-only recipe", craft.slot_cap("lubricant"), 0)
  -- One craft needs more than a stack (500 of a stack-100 item): one craft fits.
  check.eq("craft.slot_cap nuclear-reactor (over-stack amounts)", craft.slot_cap("nuclear-reactor"), 1)
  check.eq("craft.slot_cap bp-test-bulk (25 of a stack of 10)", craft.slot_cap("bp-test-bulk"), 1)
  check.eq("craft.slot_cap unknown recipe", craft.slot_cap("no-such-recipe"), 0)
end

local function ingredients()
  check.same("craft.ingredients electronic-circuit", craft.ingredients("electronic-circuit"), {
    { name = "iron-plate", type = "item", amount = 1, stack_size = 100, slot = 0 },
    { name = "copper-cable", type = "item", amount = 3, stack_size = 200, slot = 1 },
  })
  -- plastic-bar lists its fluid first in data; the fluid must not take a slot.
  local slots = {}
  for _, ingredient in ipairs(craft.ingredients("plastic-bar")) do slots[ingredient.name] = ingredient.slot or "none" end
  check.same("craft.ingredients fluid takes no slot", slots, { coal = 0, ["petroleum-gas"] = "none" })
end

local function output()
  check.same("craft.output iron-plate", craft.output("iron-plate"), { name = "iron-plate", type = "item", amount_per_craft = 1 })
  check.same("craft.output copper-cable", craft.output("copper-cable"), { name = "copper-cable", type = "item", amount_per_craft = 2 })
  check.eq("craft.output uranium-processing is nil", craft.output("uranium-processing"), nil)
  check.eq("craft.output advanced-oil-processing is nil", craft.output("advanced-oil-processing"), nil)
end

local function misplaced(recipe, input)
  local wrong = {}
  for _, ingredient in ipairs(craft.ingredients(recipe)) do
    if ingredient.type == "item" then
      input.insert { name = ingredient.name, count = 1 }
      local stack = input[ingredient.slot + 1]
      if not (stack.valid_for_read and stack.name == ingredient.name) then wrong[#wrong + 1] = ingredient.name end
    end
  end
  return wrong
end

-- The slot rule against the engine itself: insert each ingredient into a
-- built assembler on that recipe and see which stack the engine files it in.
local function slots_match_engine(surface)
  for i, recipe in ipairs { "advanced-circuit", "engine-unit", "processing-unit", "electronic-circuit" } do
    local machine = rig.built(surface, "assembling-machine-2", rig.at(-30 + 6 * i, -40), { recipe = recipe })
    local input = machine.get_inventory(defines.inventory.crafter_input)
    check.same("craft.ingredients slots match crafter_input " .. recipe, misplaced(recipe, input), {})
  end
end

function cases.run(surface)
  check.run("craft.slot_cap", slot_cap)
  check.run("craft.ingredients", ingredients)
  check.run("craft.output", output)
  check.run("craft.slots_match_engine", function() slots_match_engine(surface) end)
end

return cases

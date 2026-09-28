-- End to end for chests: requests written by the real modules, delivered by
-- real robots, slot by slot. setup() runs at tick 0; verify() after
-- CHECK_TICK. Positions are on the lab floor, inside the roboport's reach.
-- Robots carry one item at a time, so the amounts stay small (bricks stack
-- to 10) and the machine deliveries are not held up.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")

local chest_delivery = {}

local CHEST = defines.inventory.chest
local RECIPE_GHOST = { x = -20.5, y = 30.5 }
local ITEMS_GHOST = { x = -14.5, y = 30.5 }
local TOP_UP = { x = -8.5, y = 30.5 }

local function apply(case, t, p)
  local ok, why = request.apply(t, p)
  check.truthy("chest delivery apply " .. case, ok, why)
end

local function setup_recipe_ghost(surface)
  local t = assert(target.from_entity(rig.ghost(surface, "wooden-chest", RECIPE_GHOST), rig.FORCE))
  apply("recipe ghost", t, rig.priming(t, { recipe = "electronic-circuit", crafts = 2 }))
end

local function setup_items_ghost(surface)
  local t = assert(target.from_entity(rig.ghost(surface, "iron-chest", ITEMS_GHOST), rig.FORCE))
  apply("items ghost", t, rig.items_priming(t, rig.rows({ "bp-test-brick", 15 }, { "coal", 5 })))
end

-- 95 plates in the first slot and stone in the last: the top-up fills the
-- partial stack, then the highest free slot, and never touches the stone.
local function setup_top_up(surface)
  local e = rig.built(surface, "wooden-chest", TOP_UP)
  local inventory = e.get_inventory(CHEST)
  inventory[1].set_stack({ name = "iron-plate", count = 95 })
  inventory[16].set_stack({ name = "stone", count = 10 })
  local t = assert(target.from_entity(e, rig.FORCE))
  apply("top-up", t, rig.items_priming(t, rig.rows({ "iron-plate", 110 })))
end

function chest_delivery.setup(surface)
  check.run("chest_delivery.recipe_ghost setup", function() setup_recipe_ghost(surface) end)
  check.run("chest_delivery.items_ghost setup", function() setup_items_ghost(surface) end)
  check.run("chest_delivery.top_up setup", function() setup_top_up(surface) end)
end

local function chest_at(surface, position)
  return surface.find_entities_filtered({ position = position, radius = 0.5, type = "container" })[1]
end

-- "index=name xcount" for every occupied slot, in slot order.
local function slots(e)
  local list, inventory = {}, e.get_inventory(CHEST)
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack.valid_for_read then list[#list + 1] = index .. "=" .. stack.name .. "x" .. stack.count end
  end
  return list
end

local function verify(case, surface, position, want)
  local e = chest_at(surface, position)
  if not e then return check.fail(case, "chest never built") end
  check.same(case, slots(e), want)
end

function chest_delivery.verify(surface)
  check.run("chest_delivery.recipe_ghost", function()
    verify("chest delivery: recipe-mode ghost filled per slot", surface, RECIPE_GHOST,
      { "15=copper-cablex6", "16=iron-platex2" })
  end)
  check.run("chest_delivery.items_ghost", function()
    verify("chest delivery: items-mode ghost filled per slot", surface, ITEMS_GHOST,
      { "30=coalx5", "31=bp-test-brickx5", "32=bp-test-brickx10" })
  end)
  check.run("chest_delivery.top_up", function()
    verify("chest delivery: built chest topped up around a foreign item", surface, TOP_UP,
      { "1=iron-platex100", "15=iron-platex10", "16=stonex10" })
  end)
end

return chest_delivery

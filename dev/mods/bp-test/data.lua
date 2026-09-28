-- A fuel worth exactly ten stone-furnace iron-plate crafts (10 x 288 kJ), so
-- the delivery test can land a request precisely on a fuel-item boundary and
-- show that the one-second margin (ADR-0004) is what lets the last craft finish.
-- Hidden so it never competes in the default-fuel ranking.
data:extend {
  {
    type = "item",
    name = "bp-test-fuel",
    icon = "__base__/graphics/icons/coal.png",
    icon_size = 64,
    subgroup = "raw-resource",
    order = "z[bp-test-fuel]",
    stack_size = 50,
    fuel_category = "chemical",
    fuel_value = "2.88MJ",
    hidden = true,
  },
}

-- 2.0 names a recipe's category singly; 2.1 merged it into `categories`
-- and refuses the old field.
local major, minor = mods.base:match("^(%d+)%.(%d+)")
local function in_crafting(recipe)
  if tonumber(major) == 2 and tonumber(minor) == 0 then
    recipe.category = "crafting"
  else
    recipe.categories = { "crafting" }
  end
  return recipe
end

-- A recipe needing more of an item than one stack holds (25 of a stack-10
-- item), like the satellite's 100 low density structures of stack 50: the
-- slot cap is one craft, and robots must fit it into one input slot.
data:extend {
  {
    type = "item",
    name = "bp-test-brick",
    icon = "__base__/graphics/icons/stone-brick.png",
    icon_size = 64,
    subgroup = "raw-resource",
    order = "z[bp-test-brick]",
    stack_size = 10,
  },
  in_crafting {
    type = "recipe",
    name = "bp-test-bulk",
    enabled = true,
    energy_required = 1,
    ingredients = { { type = "item", name = "bp-test-brick", amount = 25 } },
    results = { { type = "item", name = "bp-test-brick", amount = 1 } },
  },
}

-- Crafters whose only category has no recipe at all: a burner one is still
-- fuel-only, an electric one cannot be primed (the recycler without Space Age).
data:extend { { type = "recipe-category", name = "bp-test-empty" } }

local function empty_crafter(source, name)
  local furnace = table.deepcopy(data.raw.furnace[source])
  furnace.name = name
  furnace.crafting_categories = { "bp-test-empty" }
  furnace.next_upgrade = nil
  furnace.fast_replaceable_group = nil
  furnace.hidden = true
  data:extend { furnace }
end

empty_crafter("stone-furnace", "bp-test-empty-burner")
empty_crafter("electric-furnace", "bp-test-empty-electric")

-- An assembler with a fixed recipe that takes items: 2.1 reads
-- fixed_recipe back as a LuaRecipePrototype, 2.0 as a string. Placeable, so
-- it can stand as a ghost.
local fixed = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
fixed.name = "bp-test-fixed"
fixed.fixed_recipe = "iron-gear-wheel"
fixed.next_upgrade = nil
fixed.fast_replaceable_group = nil
fixed.minable = { mining_time = 0.2, result = "bp-test-fixed" }
local fixed_item = table.deepcopy(data.raw.item["assembling-machine-2"])
fixed_item.name = "bp-test-fixed"
fixed_item.place_result = "bp-test-fixed"
data:extend { fixed, fixed_item }

-- A visible container with a filtered inventory: filtered, custom-stack and
-- weight-limited containers drop or truncate slot-targeted requests (spec
-- section 1), so target.lua and tool_filters.lua refuse them as chests even
-- though they otherwise look like one. Not hidden, so this exercises the
-- inventory_type check on its own, apart from the hidden check.
local filtered_chest = table.deepcopy(data.raw.container["iron-chest"])
filtered_chest.name = "bp-test-filtered-chest"
filtered_chest.inventory_type = "with_filters"
filtered_chest.minable = { mining_time = 0.2, result = "bp-test-filtered-chest" }
local filtered_chest_item = table.deepcopy(data.raw.item["iron-chest"])
filtered_chest_item.name = "bp-test-filtered-chest"
filtered_chest_item.place_result = "bp-test-filtered-chest"
data:extend { filtered_chest, filtered_chest_item }

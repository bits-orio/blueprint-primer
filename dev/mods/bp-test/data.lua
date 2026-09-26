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
  {
    type = "recipe",
    name = "bp-test-bulk",
    category = "crafting",
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

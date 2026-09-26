-- How early an item becomes obtainable, for the default-fuel rule (ADR-0004):
-- tier 0 = mined from a resource or made by a recipe enabled from the start;
-- tier n = 1 + depth of the shallowest technology unlocking a recipe that
-- makes it, where depth is the longest prerequisite chain.
--
-- The table is memoised in a file-level local. That is multiplayer-safe only
-- because it is a pure function of the prototypes: every peer computes the
-- same table whenever it first asks, and nothing in storage depends on when.

local const = require("scripts.const")

local fuel_tier = {}

local UNREACHABLE = const.UNREACHABLE_TIER

local tiers = nil

local function lower(map, key, value)
  local current = map[key]
  if current == nil or value < current then map[key] = value end
end

local function depth_of(tech, memo)
  local known = memo[tech.name]
  if known then return known end
  memo[tech.name] = 0 -- cycle guard; the engine rejects cycles at load anyway
  local deepest = -1
  for _, prerequisite in pairs(tech.prerequisites) do
    local d = depth_of(prerequisite, memo)
    if d > deepest then deepest = d end
  end
  memo[tech.name] = deepest + 1
  return deepest + 1
end

-- Hidden or disabled technologies cannot be researched in a normal game, so
-- the recipes only they unlock stay unreachable.
local function unlock_tiers()
  local by_recipe, memo = {}, {}
  for _, tech in pairs(prototypes.technology) do
    if tech.enabled and not tech.hidden then
      for _, effect in ipairs(tech.effects) do
        if effect.type == "unlock-recipe" then
          lower(by_recipe, effect.recipe, 1 + depth_of(tech, memo))
        end
      end
    end
  end
  return by_recipe
end

-- Hidden recipes are skipped: quality's recycling recipes are enabled from
-- the start and would otherwise make every fuel look free.
local function add_recipe_products(result)
  local unlocks = unlock_tiers()
  for name, recipe in pairs(prototypes.recipe) do
    if not recipe.hidden and not recipe.parameter then
      local tier = recipe.enabled and 0 or (unlocks[name] or UNREACHABLE)
      for _, product in ipairs(recipe.products) do
        if product.type == "item" then lower(result, product.name, tier) end
      end
    end
  end
end

local function add_resource_products(result)
  local resources = prototypes.get_entity_filtered { { filter = "type", type = "resource" } }
  for _, resource in pairs(resources) do
    for _, product in ipairs(resource.mineable_properties.products or {}) do
      if product.type == "item" then result[product.name] = 0 end
    end
  end
end

local function build()
  local result = {}
  add_recipe_products(result)
  add_resource_products(result)
  return result
end

function fuel_tier.of(item_name)
  tiers = tiers or build()
  return tiers[item_name] or UNREACHABLE
end

return fuel_tier

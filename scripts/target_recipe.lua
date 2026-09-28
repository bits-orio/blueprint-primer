-- The recipe questions about a Target: which recipes it may take, which one
-- it is on, and whether the window may change it. target.lua re-exports
-- these as target.current_recipe, target.allows_recipe, target.recipe_filters
-- and target.recipe_locked; this file never requires target.lua. A chest's
-- answers come from chest_recipe.lua: it has no categories of its own.

local const = require("scripts.const")
local pending = require("scripts.pending")
local recipes = require("scripts.recipes")
local chest_recipe = require("scripts.chest_recipe")

local target_recipe = {}

local NORMAL = const.NORMAL_QUALITY
local item_ingredient_count = recipes.item_ingredient_count

local function is_chest(t)
  return t.kind == const.KIND_CHEST
end

function target_recipe.filters_for(prototype)
  return recipes.filters_for(prototype.crafting_categories)
end

function target_recipe.filters(t)
  if t.kind == const.KIND_FUEL_ONLY then return {} end
  if is_chest(t) then return chest_recipe.filters() end
  return target_recipe.filters_for(t.prototype)
end

-- Memoised per prototype name in a file-level local: a pure function of the
-- prototypes, so every peer computes the same answer (see fuel_tier.lua).
local primable = {}

-- Whether any recipe of this crafter has an item a robot could deliver.
-- The quality recycler without Space Age has only hidden recipes, and the
-- captive biter spawner's one recipe has no ingredients.
function target_recipe.any_primable(prototype)
  local known = primable[prototype.name]
  if known == nil then
    local filters = target_recipe.filters_for(prototype)
    known = #filters > 0 and #prototypes.get_recipe_filtered(filters) > 0
    primable[prototype.name] = known
  end
  return known
end

local function in_categories(recipe, categories)
  for category in pairs(categories) do
    if recipe.has_category(category) then return true end
  end
  return false
end

-- Something must be requestable, and a furnace can only ever pick a recipe
-- with a single item ingredient.
local function has_requestable_items(t, recipe)
  local items = item_ingredient_count(recipe)
  if t.kind == const.KIND_FURNACE then return items == 1 end
  return items > 0
end

-- Unresearched recipes are allowed (ADR-0009): the tool plans, the force
-- researches. Blueprint-parameter placeholders are never real recipes.
function target_recipe.allows(t, recipe_name)
  if is_chest(t) then return chest_recipe.allows(t, recipe_name) end
  if not recipe_name or t.kind == const.KIND_FUEL_ONLY or not t.force.valid then return false end
  local recipe = t.force.recipes[recipe_name]
  if not recipe or recipe.hidden or recipe.prototype.parameter then return false end
  if not in_categories(recipe, t.prototype.crafting_categories) then return false end
  return has_requestable_items(t, recipe)
end

function target_recipe.unlocked(t, recipe_name)
  if not t.force.valid then return false end
  local recipe = t.force.recipes[recipe_name]
  return recipe ~= nil and recipe.enabled
end

-- A built furnace accepts only an item that feeds an unlocked recipe, so its
-- ingredients for an unresearched one would be dropped by the engine
-- (ADR-0009). Everything else can take them and waits for the research.
function target_recipe.deliverable(t, recipe_name)
  if t.kind ~= const.KIND_FURNACE or t.is_ghost then return true end
  return target_recipe.unlocked(t, recipe_name)
end

-- The recipe a machine is set to, where it can have one: an assembler,
-- ghost or built, and a built furnace. A ghost furnace and a chest have none.
local function recipe_set_on(t)
  if is_chest(t) or (t.is_ghost and t.prototype.type ~= "assembling-machine") then return nil end
  return (t.entity.get_recipe())
end

-- Whether the machine is set to a recipe robots can deliver nothing for:
-- only fluids in, like a Space Age biochamber cracking oil.
function target_recipe.on_fluid_only(t)
  local recipe = recipe_set_on(t)
  return recipe ~= nil and item_ingredient_count(recipe) == 0
end

-- RecipeID / QualityID read back as either a prototype or a plain name.
local function name_of(id)
  if id == nil or type(id) == "string" then return id end
  return id.name
end

local candidates = {}

local function candidate(prototype, recipe)
  if recipe.parameter then return false end
  local items = item_ingredient_count(recipe)
  if prototype.type == "furnace" then return items == 1 end
  return items > 0
end

-- The recipes the picker offers this Target, in inventory order, locked or
-- not: which are researched is the force's business, shown per player.
-- Memoised per prototype name like `primable`; a chest offers every recipe
-- some crafter could run.
function target_recipe.candidates(t)
  if is_chest(t) then return chest_recipe.candidates() end
  local prototype = t.prototype
  local known = candidates[prototype.name]
  if known then return known end
  known = recipes.sorted(target_recipe.filters_for(prototype), function(recipe) return candidate(prototype, recipe) end)
  candidates[prototype.name] = known
  return known
end

-- The engine's own furnace rule: the first matching recipe in inventory order.
local function furnace_recipe_for(t, item)
  local matching = prototypes.get_recipe_filtered {
    { filter = "has-ingredient-item", elem_filters = { { filter = "name", name = item } } },
  }
  local best, best_key
  for name, recipe in pairs(matching) do
    local key = recipes.inventory_order(recipe)
    if (not best or key < best_key) and target_recipe.allows(t, name) then
      best, best_key = name, key
    end
  end
  return best
end

-- A furnace has no settable recipe; whatever is already requested into its
-- input slot, on a ghost or on a built furnace's proxy, is the only
-- statement of intent it carries.
local function implied_by_plan(t, plans)
  for _, item in ipairs(pending.items_in(plans, defines.inventory.crafter_input)) do
    local recipe = furnace_recipe_for(t, item.name)
    if recipe then return recipe, item.quality end
  end
  return nil
end

-- A pending request is newer than the recipe the furnace last ran. The
-- last recipe gives its name only: the window has no quality control, so
-- keeping the quality of one stray uncommon ore would request every later
-- recipe at uncommon.
local function built_furnace_recipe(t)
  local entity = t.entity
  local recipe, quality = entity.get_recipe()
  if recipe then return recipe.name, quality and quality.name or NORMAL end
  local planned, planned_quality = implied_by_plan(t, pending.plans(t))
  if planned then return planned, planned_quality end
  local previous = entity.previous_recipe
  if not previous then return nil end
  return name_of(previous.name), NORMAL
end

local function assembler_recipe(t)
  local recipe, quality = t.entity.get_recipe()
  if recipe then return recipe.name, quality and quality.name or NORMAL end
  -- A string in 2.0, a LuaRecipePrototype in 2.1.
  local fixed = name_of(t.prototype.fixed_recipe)
  if fixed then return fixed, NORMAL end
  return nil
end

-- A chest is on no recipe: its recipe mode starts from the fed recipe,
-- which target.lua resolves (it needs target.from_entity).
function target_recipe.current(t)
  local entity = t.entity
  if not (entity and entity.valid) or t.kind == const.KIND_FUEL_ONLY or is_chest(t) then return nil end
  if t.kind == const.KIND_ASSEMBLER then return assembler_recipe(t) end
  if t.is_ghost then return implied_by_plan(t, pending.plans(t)) end
  return built_furnace_recipe(t)
end

-- The one rule for whether the window may choose a recipe (ADR-0007): a
-- fixed recipe never changes; a built assembler with a recipe is changed in
-- the vanilla GUI, since changing it here would return its contents; a built
-- furnace mid-way through a recipe finishes it first. Request refuses
-- exactly what this locks.
function target_recipe.locked(t)
  if t.kind == const.KIND_FUEL_ONLY or is_chest(t) then return false end
  if t.kind == const.KIND_ASSEMBLER and t.prototype.fixed_recipe then return true end
  if t.is_ghost then return false end
  local entity = t.entity
  return entity ~= nil and entity.valid and entity.get_recipe() ~= nil
end

return target_recipe

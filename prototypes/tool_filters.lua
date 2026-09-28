-- The primer tool's drag lights up only what it could prime (ADR-0011):
-- every crafter of the types the window handles, anything that burns fuel,
-- and plain chests. Built in data-final-fixes so machines and chests other
-- mods add are included. entity_filters match ghosts too (probed on
-- 2.0.77), so a ghost row lights up like a built one; whether a lit entity
-- really can be primed is still decided in script.

local const = require("scripts.const")

local function burns_fuel(prototype)
  local source = prototype.energy_source
  if source and source.type == "burner" then return true end
  return prototype.burner ~= nil
end

-- The data-stage side of target.lua's chest rule: a visible container with
-- a plain or barred inventory of at least one slot (inventory_type defaults
-- to "with_bar", per ContainerPrototype in prototype-api.json). Logistic
-- chests are another type and stay dark.
local function is_chest(type_name, prototype)
  if type_name ~= const.CHEST_TYPE or prototype.hidden then return false end
  if not const.CHEST_INVENTORY_TYPES[prototype.inventory_type or "with_bar"] then return false end
  return (prototype.inventory_size or 0) >= 1
end

local function primable_names()
  local names = {}
  for type_name, prototypes in pairs(data.raw) do
    for name, prototype in pairs(prototypes) do
      local is_entity = prototype.selection_box ~= nil
      if is_entity and (const.CRAFTER_TYPES[type_name] or burns_fuel(prototype) or is_chest(type_name, prototype)) then
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

local tool = data.raw["selection-tool"][const.TOOL]
local names = primable_names()
for _, mode in ipairs({ "select", "alt_select" }) do
  tool[mode].entity_filters = names
end

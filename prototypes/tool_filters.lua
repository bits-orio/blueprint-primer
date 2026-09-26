-- The primer tool's drag lights up only machines it could prime (ADR-0011):
-- every crafter of the types the window handles, and anything that burns
-- fuel. Built in data-final-fixes so machines other mods add are included.
-- entity_filters match ghosts too (probed on 2.0.77), so a ghost row lights
-- up like a built one; whether a lit machine really can be primed is still
-- decided in script.

local const = require("scripts.const")

local function burns_fuel(prototype)
  local source = prototype.energy_source
  if source and source.type == "burner" then return true end
  return prototype.burner ~= nil
end

local function machine_names()
  local names = {}
  for type_name, prototypes in pairs(data.raw) do
    for name, prototype in pairs(prototypes) do
      local is_entity = prototype.selection_box ~= nil
      if is_entity and (const.CRAFTER_TYPES[type_name] or burns_fuel(prototype)) then
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

local tool = data.raw["selection-tool"][const.TOOL]
local names = machine_names()
for _, mode in ipairs({ "select", "alt_select" }) do
  tool[mode].entity_filters = names
end

-- Chest family edge cases (ADR-0012): a filtered-inventory container that
-- looks like a chest but is refused, and a chest group split by quality.
-- Split out of chest.lua to stay under the file size limit.

local check = require("lib.check")
local rig = require("lib.rig")
local const = require("__BlueprintPrimer__/scripts/const")
local target = require("__BlueprintPrimer__/scripts/target")
local selection = require("__BlueprintPrimer__/scripts/selection")

local cases = {}

local at = rig.chest_at

local function inner(entity)
  return entity.type == "entity-ghost" and entity.ghost_name or entity.name
end

-- Inner names of entities, sorted.
local function names(list)
  local out = {}
  for i, entity in ipairs(list) do out[i] = inner(entity) end
  table.sort(out)
  return out
end

-- A visible container with a filtered inventory looks like a chest but is
-- never one (section 1): the engine drops or truncates a slot-targeted
-- request into it. Not hidden, so this is the inventory_type check alone.
local function tool_filter_names()
  local out = {}
  for _, prototype in ipairs(prototypes.item[const.TOOL].get_entity_filters(defines.selection_mode.select) or {}) do
    out[prototype.name] = true
  end
  return out
end

local function filtered_container(surface)
  local built = rig.built(surface, "bp-test-filtered-chest", at(-40.5, -50.5))
  local _, why = target.from_entity(built, rig.FORCE)
  check.same("chest refuses a filtered-inventory container",
    { target.family(built), why }, { nil, "bp-primer.not-primable" })
  check.eq("chest tool filters leave a filtered-inventory container out",
    tool_filter_names()["bp-test-filtered-chest"], nil)
end

-- A chest of another quality is not a member (it changes the slot count):
-- it goes to skipped, same as a chest of another kind.
local function quality_group(surface)
  if not script.active_mods["quality"] then return end
  local y = -52.5
  rig.built(surface, "iron-chest", at(-40.5, y), { quality = "legendary" })
  rig.built(surface, "iron-chest", at(-38.5, y))
  local entities = surface.find_entities_filtered({ area = { at(-42, y - 1), at(-37, y + 1) } })
  local picked = assert(selection.resolve(entities, { at(-41, y - 0.5), at(-40, y + 0.5) }, rig.FORCE))
  check.same("chest drag skips a chest of another quality",
    { #picked.group, names(picked.skipped) }, { 1, { "iron-chest" } })
end

function cases.run(surface)
  check.run("chest_families.filtered_container", function() filtered_container(surface) end)
  check.run("chest_families.quality_group", function() quality_group(surface) end)
end

return cases

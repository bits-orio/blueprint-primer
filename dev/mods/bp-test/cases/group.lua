-- ADR-0011: a drag primes every machine of the nearest one's kind, and a
-- group's Blueprint takes the whole dragged area. The selection event
-- cannot be raised headless, so selection.resolve gets the entities a
-- find_entities_filtered over the same area returns.

local check = require("lib.check")
local rig = require("lib.rig")
local const = require("__BlueprintPrimer__/scripts/const")
local selection = require("__BlueprintPrimer__/scripts/selection")
local group = require("__BlueprintPrimer__/scripts/group")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local Y = -25
local PLAYER = 9
local line = check.plan_line

local function tool_filters()
  local filters = {}
  for _, prototype in ipairs(prototypes.item[const.TOOL].get_entity_filters(defines.selection_mode.select) or {}) do
    filters[prototype.name] = true
  end
  check.truthy("group tool filters light up furnaces, assemblers and boilers",
    filters["stone-furnace"] and filters["assembling-machine-2"] and filters["boiler"])
  check.truthy("group tool filters light up plain chests", filters["wooden-chest"] and filters["steel-chest"])
  check.same("group tool filters leave logistic chests out",
    { filters["requester-chest"], filters["passive-provider-chest"] }, {})
end

-- A row: two stone furnace ghosts, a built stone furnace holding 4 ore, a
-- steel furnace ghost and a belt. The drag is centred on the first furnace.
local function row(surface)
  local area = { left_top = rig.at(-31, Y - 2), right_bottom = rig.at(-12, Y + 2) }
  rig.ghost(surface, "stone-furnace", rig.at(-30, Y))
  rig.ghost(surface, "stone-furnace", rig.at(-27, Y))
  local built = rig.built(surface, "stone-furnace", rig.at(-24, Y))
  built.insert { name = "iron-ore", count = 4 }
  rig.ghost(surface, "steel-furnace", rig.at(-21, Y))
  rig.built(surface, "transport-belt", rig.at(-17.5, Y - 0.5))
  local centre_area = { left_top = rig.at(-31, Y - 1), right_bottom = rig.at(-29, Y + 1) }
  local entities = surface.find_entities_filtered { area = { area.left_top, area.right_bottom } }
  return entities, centre_area, area, built
end

local function resolve_and_request(surface)
  local entities, centre_area, area, built = row(surface)
  local picked = assert(selection.resolve(entities, centre_area, rig.FORCE))
  check.same("group selection: stone furnaces grouped, steel skipped, belt ignored",
    { picked.primary.name, #picked.group, #picked.skipped, picked.skipped[1] and picked.skipped[1].name },
    { "stone-furnace", 3, 1, "entity-ghost" })
  local p = priming.new(picked.primary, PLAYER)
  p.recipe, p.crafts = "iron-plate", 10
  p.fuel, p.fuel_count, p.fuel_edited = "coal", 1, false
  p.group, p.area = picked.group, area
  check.eq("group totals before top-up", group.totals(p, PLAYER), "[item=iron-ore]30  [item=coal]3")
  local inventory = game.create_inventory(1)
  check.eq("group area blueprint written", group.write_area(inventory[1], p, rig.FORCE, PLAYER), true)
  local summary = {}
  for _, e in ipairs(inventory[1].get_blueprint_entities() or {}) do
    summary[#summary + 1] = e.name .. ":" .. table.concat(check.plan_summary(e.items), ",")
  end
  table.sort(summary)
  local input, fuel = defines.inventory.crafter_input, defines.inventory.fuel
  local primed = "stone-furnace:" .. table.concat(check.lines { line("iron-ore", input, 0, 10), line("coal", fuel, 0, 1) }, ",")
  check.same("group area blueprint primes the kind, copies the rest as vanilla",
    summary, { "steel-furnace:", primed, primed, primed, "transport-belt:" })
  inventory.destroy()
  local done, total = group.request(p, PLAYER)
  check.same("group Request primes every member", { done, total }, { 3, 3 })
  local proxy = built.item_request_proxy
  check.same("group Request tops the built member up", check.plan_summary(proxy and proxy.insert_plan),
    check.lines { line("iron-ore", input, 0, 6), line("coal", fuel, 0, 1) })
end

function cases.run(surface)
  check.run("group.tool_filters", tool_filters)
  check.run("group.resolve_request", function() resolve_and_request(surface) end)
end

return cases

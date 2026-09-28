-- Items mode (ADR-0013): the four ways to set a row, the row cap, adding
-- and removing rows, the chooser's filters, and the mode switch. A wooden
-- chest has 16 slots; plates stack to 100, cable to 200, coal to 50.

local check = require("lib.check")
local rig = require("lib.rig")
local const = require("__BlueprintPrimer__/scripts/const")
local target = require("__BlueprintPrimer__/scripts/target")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")
local items = require("__BlueprintPrimer__/scripts/gui/items")

local cases = {}

local at = rig.chest_at
local PLAYER = 9

local function fresh_priming(surface, x)
  return priming.new(assert(target.from_entity(rig.ghost(surface, "wooden-chest", at(x, 2.5)), rig.FORCE)), PLAYER)
end

local function counts(p)
  local list = {}
  for i, row in ipairs(p.items) do list[i] = row.name .. "=" .. row.count end
  return list
end

local function half_and_max(surface)
  local p = fresh_priming(surface, -40.5)
  check.same("chest items: a fresh chest with no fed machine has no rows, and is blocked",
    { p.mode, #p.items, priming.blocker(p) }, { "items", 0, "bp-primer.no-items" })
  check.eq("chest items: add a row at Half", items.add(p, "iron-plate"), true)
  items.add(p, "copper-cable")
  check.same("chest items: Half and Half split the chest", { counts(p), { priming.slots(p) } },
    { { "iron-plate=800", "copper-cable=1600" }, { 16, 16 } })
  check.same("chest items: no room for another row", { items.add(p, "coal") }, { false, const.NOTICE.CHEST_NO_ROOM })
  check.eq("chest items: a row makes it ready", priming.blocker(p), nil)
  local q = fresh_priming(surface, -38.5)
  items.add(q, "iron-plate")
  items.add(q, "coal")
  items.max(q, q.items[2].id)
  check.same("chest items: Half then Max fills the chest", { counts(q), items.slots_used(q) },
    { { "iron-plate=800", "coal=400" }, 16 })
end

local function set_rows(surface)
  local p = fresh_priming(surface, -36.5)
  items.add(p, "iron-plate")
  local id = p.items[1].id
  items.set_slots(p, id, 3)
  check.eq("chest items: slots set whole stacks", p.items[1].count, 300)
  items.set_count(p, id, 123)
  check.same("chest items: exact count, and its slots", { p.items[1].count, items.row_slots(p.items[1]) }, { 123, 2 })
  items.add(p, "copper-cable")
  check.same("chest items: row cap is what the other rows leave",
    { items.row_cap(p, id), items.slot_cap(p, p.items[2].id) }, { 800, 14 })
  items.set_count(p, id, 99999)
  items.set_slots(p, p.items[2].id, 99)
  check.same("chest items: counts clamp to the row cap", counts(p), { "iron-plate=800", "copper-cable=1600" })
  items.set_count(p, id, 0)
  check.eq("chest items: never below one", p.items[1].count, 1)
end

local function change_rows(surface)
  local p = fresh_priming(surface, -32.5)
  items.add(p, "iron-plate")
  items.add(p, "copper-cable")
  local id = p.items[1].id
  check.same("chest items: a listed item is refused", { items.add(p, "iron-plate") }, { false, const.NOTICE.ITEM_LISTED })
  check.same("chest items: picking a listed item on a row is refused",
    { items.set_item(p, id, "copper-cable", "normal") }, { false, const.NOTICE.ITEM_LISTED })
  items.set_count(p, id, 123)
  check.eq("chest items: another item keeps the row's slots", items.set_item(p, id, "coal", "normal"), true)
  check.eq("chest items: 2 slots of coal", p.items[1].count, 100)
  items.set_item(p, id, nil)
  check.same("chest items: clearing a chooser removes its row", counts(p), { "copper-cable=1600" })
  check.eq("chest items: ids keep increasing", p.next_row_id, 3)
end

local function chooser_filters()
  local listed = prototypes.get_item_filtered(items.filters())
  check.same("chest items: the chooser offers items robots deliver exactly",
    { listed["iron-plate"] ~= nil, listed["blueprint"], listed["deconstruction-planner"], listed["blueprint-book"],
      listed[const.TOOL] }, { true })
end

local function modes(surface)
  local p = fresh_priming(surface, -30.5)
  priming.set_mode(p, "recipe")
  check.same("chest mode: recipe with nothing to go on asks for a recipe",
    { p.mode, p.recipe, priming.blocker(p) }, { "recipe", nil, "bp-primer.pick-recipe" })
  priming.set_recipe(p, "electronic-circuit")
  priming.set_crafts(p, 20)
  priming.set_mode(p, "items")
  check.same("chest mode: empty rows start from the recipe", counts(p), { "iron-plate=20", "copper-cable=60" })
  items.set_count(p, p.items[1].id, 50)
  priming.set_mode(p, "recipe")
  check.same("chest mode: recipe keeps its own state", { p.recipe, p.crafts, (priming.slots(p)) },
    { "electronic-circuit", 20, 2 })
  priming.set_mode(p, "items")
  check.same("chest mode: rows are kept", counts(p), { "iron-plate=50", "copper-cable=60" })
end

function cases.run(surface)
  check.run("chest_items.half_and_max", function() half_and_max(surface) end)
  check.run("chest_items.set_rows", function() set_rows(surface) end)
  check.run("chest_items.change_rows", function() change_rows(surface) end)
  check.run("chest_items.filters", chooser_filters)
  check.run("chest_items.modes", function() modes(surface) end)
end

return cases

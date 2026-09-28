-- Carried chest requests (ADR-0008, ADR-0012): a copy of a built chest with
-- a pending proxy (vanilla drops all of it), settings paste chest to chest,
-- a group of chests, and an area blueprint carrying primed non-members.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local copy = require("__BlueprintPrimer__/scripts/copy")
local paste = require("__BlueprintPrimer__/scripts/paste")
local selection = require("__BlueprintPrimer__/scripts/selection")
local group = require("__BlueprintPrimer__/scripts/group")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")
local items = require("__BlueprintPrimer__/scripts/gui/items")
local chain = require("cases.chest").chain

local cases = {}

local at = rig.chest_at
local PLAYER = 9
local CHEST = defines.inventory.chest
local line = check.plan_line

local function snapshot(surface, area)
  local inventory = game.create_inventory(1)
  inventory[1].set_stack({ name = "blueprint" })
  local mapping = inventory[1].create_blueprint({ surface = surface, force = rig.FORCE, area = area })
  return inventory, inventory[1].get_blueprint_entities() or {}, mapping
end

local function named(entities, name)
  for _, entity in ipairs(entities) do
    if entity.name == name then return entity end
  end
end

local function prime_rows(entity, rows)
  local t = assert(target.from_entity(entity, rig.FORCE))
  assert(request.apply(t, rig.items_priming(t, rows)))
  return entity
end

local IRON_AND_COAL = check.lines {
  line("iron-plate", CHEST, 31, 100), line("iron-plate", CHEST, 30, 100), line("iron-plate", CHEST, 29, 50),
  line("coal", CHEST, 28, 50), line("coal", CHEST, 27, 10) }

local function copies(surface)
  prime_rows(rig.built(surface, "iron-chest", at(-40.5, 30.5)), rig.rows({ "iron-plate", 250 }, { "coal", 60 }))
  local inventory, entities, mapping = snapshot(surface, { at(-41.5, 29.5), at(-39.5, 31.5) })
  local c = named(entities, "iron-chest")
  check.eq("chest copy: vanilla drops a built chest's pending request", c.items, nil)
  check.eq("chest copy.carry changed it", copy.carry(entities, mapping, rig.FORCE, PLAYER), true)
  check.same("chest copy.carry restores the items rows", check.plan_summary(c.items), IRON_AND_COAL)
  inventory.destroy()
  -- Recipe mode on a chest that already held 10 plates: the copy is primed
  -- for the full amounts, as a fresh chest.
  local t = chain(surface, rig.built, -34.5, 30.5, "electronic-circuit")
  t.entity.get_inventory(CHEST).insert({ name = "iron-plate", count = 10 })
  local p = priming.new(t, PLAYER)
  priming.set_crafts(p, 20)
  assert(request.apply(t, p))
  inventory, entities, mapping = snapshot(surface, { at(-35.5, 28.5), at(-29.5, 32.5) })
  c = named(entities, "wooden-chest")
  check.eq("chest copy.carry recipe mode changed it", copy.carry(entities, mapping, rig.FORCE, PLAYER), true)
  check.same("chest copy.carry restores the full recipe amounts", check.plan_summary(c.items),
    check.lines { line("iron-plate", CHEST, 15, 20), line("copper-cable", CHEST, 14, 60) })
  inventory.destroy()
end

local function plan_of(ghost)
  return check.plan_summary(ghost.insert_plan)
end

local function pastes(surface)
  local source = prime_rows(rig.ghost(surface, "iron-chest", at(-26.5, 30.5)), rig.rows({ "iron-plate", 250 }, { "coal", 60 }))
  local same = rig.ghost(surface, "iron-chest", at(-24.5, 30.5))
  check.same("chest paste onto a chest", { paste.apply(source, same, rig.FORCE, PLAYER) ~= nil, plan_of(same) },
    { true, IRON_AND_COAL })
  local big = prime_rows(rig.ghost(surface, "iron-chest", at(-22.5, 30.5)), rig.rows({ "iron-plate", 3000 }, { "coal", 100 }))
  local small = rig.ghost(surface, "wooden-chest", at(-20.5, 30.5))
  local expected = {}
  for slot = 0, 15 do expected[#expected + 1] = line("iron-plate", CHEST, slot, 100) end
  check.same("chest paste onto a smaller chest keeps the earlier rows first",
    { paste.apply(big, small, rig.FORCE, PLAYER) ~= nil, plan_of(small) }, { true, check.lines(expected) })
end

-- Three wooden chest ghosts and a built one holding stone in its last slot.
local function chest_row(surface, y)
  for x = -40.5, -38.5 do rig.ghost(surface, "wooden-chest", at(x, y)) end
  local built = rig.built(surface, "wooden-chest", at(-37.5, y))
  built.get_inventory(CHEST)[16].set_stack({ name = "stone", count = 10 })
  local area = { at(-41, y - 1), at(-37, y + 1) }
  return surface.find_entities_filtered({ area = area }), area, built
end

local function groups(surface)
  local entities, area, built = chest_row(surface, 38.5)
  local picked = assert(selection.resolve(entities, { at(-41, 38), at(-40, 39) }, rig.FORCE))
  local p = priming.new(picked.primary, PLAYER)
  items.add(p, "iron-plate")
  items.set_count(p, p.items[1].id, 150)
  items.add(p, "coal")
  items.set_count(p, p.items[2].id, 20)
  local want = "[item=iron-plate]600  [item=coal]80"
  if script.active_mods["quality"] then
    items.add(p, "iron-plate", "uncommon")
    items.set_count(p, p.items[3].id, 20)
    want = want .. "  [item=iron-plate,quality=uncommon]80"
  end
  p.group, p.area = picked.group, area
  check.eq("chest group totals, keyed by quality", group.totals(p, PLAYER), want)
  check.same("chest group Request primes every chest", { group.request(p, PLAYER) }, { 4, 4 })
  local proxy = built.item_request_proxy
  local expected = { line("coal", CHEST, 12, 20), line("iron-plate", CHEST, 13, 50), line("iron-plate", CHEST, 14, 100) }
  if script.active_mods["quality"] then
    expected[#expected + 1] = line("iron-plate", CHEST, 11, 20, "uncommon")
  end
  check.same("chest group Request tops the built chest up around its stone",
    check.plan_summary(proxy and proxy.insert_plan), check.lines(expected))
end

-- "name:plan,plan" per blueprint entity, sorted.
local function area_summary(stack)
  local summary = {}
  for _, e in ipairs(stack.get_blueprint_entities() or {}) do
    summary[#summary + 1] = e.name .. ":" .. table.concat(check.plan_summary(e.items), ",")
  end
  table.sort(summary)
  return summary
end

-- Two wooden chest ghosts (the group), a primed built iron chest (skipped)
-- and a primed built stone furnace (ignored): the area blueprint carries both.
local function area_blueprint(surface)
  local y = 44.5
  rig.ghost(surface, "wooden-chest", at(-40.5, y))
  rig.ghost(surface, "wooden-chest", at(-39.5, y))
  prime_rows(rig.built(surface, "iron-chest", at(-37.5, y)), rig.rows({ "iron-plate", 250 }))
  local furnace = assert(target.from_entity(rig.built(surface, "stone-furnace", at(-35, y - 0.5)), rig.FORCE))
  assert(request.apply(furnace, rig.priming(furnace, { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 1 })))
  local area = { at(-41, y - 2), at(-33.5, y + 1.5) }
  local entities = surface.find_entities_filtered({ area = area })
  local picked = assert(selection.resolve(entities, { at(-41, y - 0.5), at(-40, y + 0.5) }, rig.FORCE))
  local p = priming.new(picked.primary, PLAYER)
  items.add(p, "iron-plate")
  items.set_count(p, p.items[1].id, 30)
  p.group, p.area = picked.group, area
  local inventory = game.create_inventory(1)
  check.eq("chest area blueprint written", group.write_area(inventory[1], p, rig.FORCE, PLAYER), true)
  local input, fuel = defines.inventory.crafter_input, defines.inventory.fuel
  local member = "wooden-chest:" .. line("iron-plate", CHEST, 15, 30)
  check.same("chest area blueprint primes members and carries primed non-members", area_summary(inventory[1]), {
    "iron-chest:" .. table.concat(check.lines { line("iron-plate", CHEST, 29, 50), line("iron-plate", CHEST, 30, 100),
      line("iron-plate", CHEST, 31, 100) }, ","),
    "stone-furnace:" .. table.concat(check.lines { line("coal", fuel, 0, 1), line("iron-ore", input, 0, 10) }, ","),
    member, member })
  inventory.destroy()
end

function cases.run(surface)
  check.run("chest_carry.copies", function() copies(surface) end)
  check.run("chest_carry.pastes", function() pastes(surface) end)
  check.run("chest_carry.groups", function() groups(surface) end)
  check.run("chest_carry.area_blueprint", function() area_blueprint(surface) end)
end

return cases

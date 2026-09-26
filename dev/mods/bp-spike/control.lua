-- Spike: do construction robots deliver EXACT partial insert-plan counts,
-- through every path the mod will use (ghost insert_plan, item-request-proxy
-- on a built entity, a single-entity blueprint), and is the fuel estimate the
-- true minimum? Each case logs BP_SPIKE lines; the driver greps them.

local CHECK_TICK = 20000

local function plan(item, inventory, count, stack)
  return { id = { name = item, quality = "normal" },
           items = { in_inventory = { { inventory = inventory, stack = stack or 0, count = count } } } }
end

local function fuel_estimate(machine_name, recipe_name, crafts, fuel_name)
  local mp = prototypes.entity[machine_name]
  local rp = prototypes.recipe[recipe_name]
  local speed = mp.get_crafting_speed("normal")
  local per_tick = mp.energy_usage
  local eff = mp.burner_prototype.effectivity
  local joules = crafts * rp.energy / speed * per_tick * 60
  local fv = prototypes.item[fuel_name].fuel_value
  local n = math.ceil(joules / (fv * eff) - 1e-9)
  log(string.format("BP_SPIKE estimate %s %s x%d: speed=%s usage=%sW eff=%s energy=%s J=%.0f fuel=%s(%.0f) -> %d",
    machine_name, recipe_name, crafts, speed, per_tick * 60, eff, rp.energy, joules, fuel_name, fv, n))
  return n
end

local cases = {}

local function ghost(surface, name, pos, recipe)
  local g = surface.create_entity { name = "entity-ghost", inner_name = name, position = pos, force = "player" }
  if recipe then g.set_recipe(recipe) end
  return g
end

script.on_init(function()
  local surface = game.surfaces.nauvis
  surface.request_to_generate_chunks({ 0, 0 }, 3)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -48, 47 do for y = -48, 47 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered { area = { { -48, -48 }, { 48, 48 } } }) do e.destroy() end
  game.forces.enemy.kill_all_units()
  game.map_settings.enemy_expansion.enabled = false
  game.forces.player.enable_all_recipes()

  -- Power + robots.
  local eei = surface.create_entity { name = "electric-energy-interface", position = { 0, -6 }, force = "player" }
  eei.power_production = 1e9; eei.electric_buffer_size = 1e10
  surface.create_entity { name = "medium-electric-pole", position = { 0, -4 }, force = "player" }
  local port = surface.create_entity { name = "roboport", position = { 0, 0 }, force = "player" }
  port.insert { name = "construction-robot", count = 50 }
  local chest = surface.create_entity { name = "storage-chest", position = { 3, -4 }, force = "player" }
  for _, s in ipairs {
    { "coal", 200 }, { "iron-ore", 300 }, { "stone", 100 }, { "stone-furnace", 10 }, { "steel-furnace", 10 },
    { "assembling-machine-1", 5 }, { "iron-plate", 100 }, { "copper-cable", 200 } } do
    chest.insert { name = s[1], count = s[2] }
  end

  local fs, fuel, ai = defines.inventory.furnace_source, defines.inventory.fuel, defines.inventory.crafter_input

  -- T1/T2: ghost stone furnace, 50 ore, exact estimate vs estimate-1.
  local est_stone = fuel_estimate("stone-furnace", "iron-plate", 50, "coal")
  local g1 = ghost(surface, "stone-furnace", { -20, 10 })
  g1.insert_plan = { plan("iron-ore", fs, 50), plan("coal", fuel, est_stone) }
  local g2 = ghost(surface, "stone-furnace", { -16, 10 })
  g2.insert_plan = { plan("iron-ore", fs, 50), plan("coal", fuel, est_stone - 1) }
  cases[#cases + 1] = { id = "T1 ghost stone exact", pos = { -20, 10 }, want_plates = 50, item = "iron-plate", ore = "iron-ore" }
  cases[#cases + 1] = { id = "T2 ghost stone minus1", pos = { -16, 10 }, want_less = 50, item = "iron-plate", ore = "iron-ore" }

  -- T3/T4: built steel furnace + item-request-proxy.
  local est_steel = fuel_estimate("steel-furnace", "iron-plate", 50, "coal")
  for i, n in ipairs { est_steel, est_steel - 1 } do
    local f = surface.create_entity { name = "steel-furnace", position = { -10 + i * 4, 10 }, force = "player" }
    surface.create_entity { name = "item-request-proxy", position = f.position, target = f, force = "player",
      modules = { plan("iron-ore", fs, 50), plan("coal", fuel, n) } }
  end
  cases[#cases + 1] = { id = "T3 proxy steel exact", pos = { -6, 10 }, want_plates = 50, item = "iron-plate", ore = "iron-ore" }
  cases[#cases + 1] = { id = "T4 proxy steel minus1", pos = { -2, 10 }, want_less = 50, item = "iron-plate", ore = "iron-ore" }

  -- T5: single-entity blueprint, stone furnace, 20 stone -> 10 bricks.
  local est_brick = fuel_estimate("stone-furnace", "stone-brick", 10, "coal")
  local inv = game.create_inventory(1)
  inv[1].set_stack { name = "blueprint" }
  inv[1].set_blueprint_entities { {
    entity_number = 1, name = "stone-furnace", position = { 0, 0 },
    items = { plan("stone", fs, 20), plan("coal", fuel, est_brick) } } }
  local built = inv[1].build_blueprint { surface = surface, force = "player", position = { 6, 10 },
    build_mode = defines.build_mode.forced }
  log("BP_SPIKE T5 blueprint built ghosts=" .. #built .. " plan=" .. serpent.line(built[1] and built[1].insert_plan))
  inv.destroy()
  cases[#cases + 1] = { id = "T5 blueprint stone bricks", pos = built[1] and built[1].position or { 6, 10 }, want_plates = 10, item = "stone-brick", ore = "stone" }

  -- T6: unpowered assembler ghost, multi-ingredient partial (5 crafts of circuits).
  local g6 = ghost(surface, "assembling-machine-1", { 14, 20 }, "electronic-circuit")
  g6.insert_plan = { plan("iron-plate", ai, 5, 0), plan("copper-cable", ai, 15, 1) }
  log("BP_SPIKE T6 ghost plan readback=" .. serpent.line(g6.insert_plan))
  cases[#cases + 1] = { id = "T6 assembler ghost partial", pos = { 14, 20 }, assembler = true }

  storage.cases = cases
end)

script.on_nth_tick(CHECK_TICK, function(ev)
  -- on_nth_tick also fires on tick 0; only the real check tick counts.
  if ev.tick == 0 or storage.done then return end
  storage.done = true
  local surface = game.surfaces.nauvis
  for _, c in ipairs(storage.cases) do
    local e = surface.find_entities_filtered { position = c.pos, radius = 1.5, type = { "furnace", "assembling-machine" } }[1]
    if not e then
      log("BP_SPIKE RESULT " .. c.id .. " FAIL no entity (ghost never revived?)")
    elseif c.assembler then
      local inv = e.get_inventory(defines.inventory.crafter_input)
      local got = inv.get_contents()
      local ok = inv.get_item_count("iron-plate") == 5 and inv.get_item_count("copper-cable") == 15
      log("BP_SPIKE RESULT " .. c.id .. (ok and " PASS " or " FAIL ") .. serpent.line(got))
    else
      local out = e.get_inventory(defines.inventory.furnace_result).get_item_count(c.item)
      local left_ore = e.get_inventory(defines.inventory.furnace_source).get_item_count(c.ore)
      local left_fuel = e.get_inventory(defines.inventory.fuel).get_item_count("coal")
      local ok
      if c.want_plates then ok = out == c.want_plates and left_ore == 0 and left_fuel == 0
      else ok = out < c.want_less end
      log(string.format("BP_SPIKE RESULT %s %s out=%d ore_left=%d coal_left=%d buffer=%.0fJ",
        c.id, ok and "PASS" or "FAIL", out, left_ore, left_fuel, e.burner and e.burner.remaining_burning_fuel or -1))
    end
  end
end)

script.on_nth_tick(1200, function(ev)
  if ev.tick > 6000 then return end
  local surface = game.surfaces.nauvis
  local port = surface.find_entities_filtered { name = "roboport" }[1]
  local net = port and port.logistic_network
  log(string.format("BP_SPIKE diag t=%d port_energy=%.0f net=%s bots_all=%s bots_avail=%s ghosts=%d proxies=%d chest_coal=%s",
    ev.tick, port and port.energy or -1, tostring(net ~= nil),
    net and net.all_construction_robots or -1, net and net.available_construction_robots or -1,
    #surface.find_entities_filtered { type = "entity-ghost" }, #surface.find_entities_filtered { type = "item-request-proxy" },
    net and net.get_item_count("coal") or -1))
end)

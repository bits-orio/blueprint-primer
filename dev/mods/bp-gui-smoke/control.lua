-- A fixed little world for driving Blueprint Primer's GUI by hand (or by
-- xdotool) in a real client. Everything sits at known tile offsets from the
-- player, who stands at the origin with zoom 1, so a machine at (dx, dy) is
-- on screen at centre + 32 * (dx, dy) pixels.

local STOCK = {
  { "coal", 200 }, { "stone", 100 },
  { "iron-plate", 100 },
  { "copper-cable", 200 }, { "solid-fuel", 50 }, { "wood", 50 },
}

local function flatten(surface)
  surface.request_to_generate_chunks({ 0, 0 }, 3)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -40, 39 do for y = -30, 29 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered { area = { { -40, -30 }, { 40, 30 } } }) do
    if e.type ~= "character" then e.destroy() end
  end
end

local function robots(surface)
  local eei = surface.create_entity { name = "electric-energy-interface", position = { -14, -6 }, force = "player" }
  eei.power_production = 1e9; eei.electric_buffer_size = 1e10
  surface.create_entity { name = "medium-electric-pole", position = { -14, -4 }, force = "player" }
  local port = surface.create_entity { name = "roboport", position = { -14, 0 }, force = "player" }
  port.insert { name = "construction-robot", count = 20 }
  local chest = surface.create_entity { name = "storage-chest", position = { -11, -4 }, force = "player" }
  for _, s in ipairs(STOCK) do chest.insert { name = s[1], count = s[2] } end
end

local function ghost(surface, name, pos, recipe)
  local g = surface.create_entity { name = "entity-ghost", inner_name = name, position = pos, force = "player" }
  if recipe then g.set_recipe(recipe) end
end

script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_disable_crashsite", true)
    remote.call("freeplay", "set_skip_intro", true)
  end
  local surface = game.surfaces.nauvis
  surface.always_day = true
  flatten(surface)
  game.forces.enemy.kill_all_units()
  game.map_settings.enemy_expansion.enabled = false
  -- Recipes stay as in a fresh freeplay game, so steel plate and engine
  -- units are unresearched for the ADR-0009 checks.
  robots(surface)
  ghost(surface, "stone-furnace", { 4, -3 })                                  -- A: ghost furnace
  local f = surface.create_entity { name = "stone-furnace", position = { 8, -3 }, force = "player" }
  f.get_inventory(defines.inventory.crafter_input).insert { name = "iron-ore", count = 5 } -- B: built furnace, 5 ore in
  ghost(surface, "assembling-machine-2", { 4.5, 3.5 }, "electronic-circuit")  -- C: ghost assembler
  surface.create_entity { name = "boiler", position = { 9.5, 3 }, force = "player" } -- D: fuel-only
  ghost(surface, "steel-furnace", { 13, -3 })                                 -- E: ghost steel furnace
  surface.create_entity { name = "steel-furnace", position = { 21, -3 }, force = "player" } -- I: empty built steel furnace
  local w = surface.create_entity { name = "stone-furnace", position = { 17, -3 }, force = "player" }
  w.get_inventory(defines.inventory.fuel).insert { name = "wood", count = 5 } -- F: furnace burning wood
  if prototypes.entity["captive-biter-spawner"] then                          -- G: fuel-only crafter
    surface.create_entity { name = "captive-biter-spawner", position = { 15, 4 }, force = "player" }
    local bio = surface.create_entity { name = "biochamber", position = { -4.5, 8.5 }, force = "player" } -- H
    if bio then bio.set_recipe("light-oil-cracking") end
  end
end)

script.on_event(defines.events.on_player_created, function(ev)
  local p = game.get_player(ev.player_index)
  p.teleport({ 0, 0 })
  p.zoom = 1
  log("BP_GUI ready")
end)

-- Dev-only state log: every 2 s, one line per crafter or ghost whose
-- requests or contents changed, so a driven test reads the log instead of
-- typing into the console. Polling is fine here; this mod never ships.
local function describe(e)
  local ghost = e.type == "entity-ghost"
  local proxy = (not ghost) and e.item_request_proxy
  local plan = ghost and e.insert_plan or (proxy and proxy.insert_plan) or {}
  local parts = {}
  for _, p in ipairs(plan) do
    for _, pos in ipairs(p.items.in_inventory or {}) do
      parts[#parts + 1] = p.id.name .. "@" .. pos.inventory .. "=" .. (pos.count or 1)
    end
  end
  local inside = ""
  if not ghost then
    for _, i in ipairs { defines.inventory.crafter_input, defines.inventory.fuel } do
      local inv = e.get_inventory(i)
      for _, c in ipairs(inv and inv.get_contents() or {}) do inside = inside .. c.name .. "=" .. c.count .. " " end
    end
  end
  return (ghost and ("ghost:" .. e.ghost_name) or e.name) .. " req[" .. table.concat(parts, ",") .. "] in[" .. inside .. "]"
end

script.on_nth_tick(120, function()
  storage.seen = storage.seen or {}
  local s = game.surfaces.nauvis
  for _, e in pairs(s.find_entities_filtered { area = { { -40, -30 }, { 40, 30 } }, type = { "furnace", "assembling-machine", "entity-ghost" } }) do
    local key = e.position.x .. "," .. e.position.y
    local line = describe(e)
    if storage.seen[key] ~= line then
      storage.seen[key] = line
      log("BP_STATE (" .. key .. ") " .. line)
    end
  end
end)

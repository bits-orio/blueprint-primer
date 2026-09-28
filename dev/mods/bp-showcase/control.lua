-- A tidy scene for mod-portal screenshots: grass, daylight, a working row of
-- stone furnaces with a steel furnace at its end, a planned row of furnace
-- ghosts below it, and a robot network kept out of frame to the west so
-- primed requests get delivered on screen. The player stands at (0, 8), so a centred window leaves the rows above it in view.

local function clear(surface)
  surface.request_to_generate_chunks({ 0, 0 }, 4)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -50, 40 do
    for y = -22, 22 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered { area = { { -50, -22 }, { 40, 22 } } }) do
    if e.type ~= "character" then e.destroy() end
  end
end

local function robots(surface)
  local eei = surface.create_entity { name = "electric-energy-interface", position = { -44, -8 }, force = "player" }
  eei.power_production = 1e9; eei.electric_buffer_size = 1e10
  surface.create_entity { name = "medium-electric-pole", position = { -44, -6 }, force = "player" }
  local port = surface.create_entity { name = "roboport", position = { -44, -3 }, force = "player" }
  port.insert { name = "construction-robot", count = 30 }
  local chest = surface.create_entity { name = "storage-chest", position = { -41, -7 }, force = "player" }
  for _, s in ipairs { { "iron-ore", 400 }, { "copper-ore", 200 }, { "stone", 100 }, { "coal", 200 } } do
    chest.insert { name = s[1], count = s[2] }
  end
end

local function furnaces(surface)
  for x = -6, 4, 2 do
    local f = surface.create_entity { name = "stone-furnace", position = { x, -4 }, force = "player" }
    f.insert { name = "coal", count = 3 }
  end
  local steel = surface.create_entity { name = "steel-furnace", position = { 6, -4 }, force = "player" }
  steel.insert { name = "coal", count = 3 }
  for x = -8.5, 7.5 do
    surface.create_entity { name = "transport-belt", position = { x, -6.5 }, direction = defines.direction.east, force = "player" }
  end
  for x = -6, 4, 2 do
    surface.create_entity { name = "entity-ghost", inner_name = "stone-furnace", position = { x, 5 }, force = "player" }
  end
end

script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_disable_crashsite", true)
    remote.call("freeplay", "set_skip_intro", true)
  end
  local surface = game.surfaces.nauvis
  surface.always_day = true
  clear(surface)
  game.forces.enemy.kill_all_units()
  game.map_settings.enemy_expansion.enabled = false
  robots(surface)
  furnaces(surface)
end)

script.on_event(defines.events.on_player_created, function(ev)
  local p = game.get_player(ev.player_index)
  p.teleport({ 0, 8 })
  p.zoom = 1
  log("BP_GUI ready")
end)

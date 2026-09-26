-- The test world: a flat lab floor near the origin with a powered roboport
-- network (the spike's rig), and a second floor far outside its range where
-- the synchronous contract cases place entities robots must never touch.

local rig = {}

rig.FORCE = "player"
rig.UNIT_ORIGIN = { x = 400, y = 0 }
local HALF = 48

local STOCK = {
  { "coal", 200 }, { "iron-ore", 300 }, { "stone", 100 }, { "stone-furnace", 20 },
  { "steel-furnace", 10 }, { "assembling-machine-2", 5 }, { "speed-module", 5 },
  { "iron-plate", 100 }, { "copper-cable", 200 }, { "bp-test-fuel", 10 }, { "bp-test-brick", 50 },
}

local function flatten(surface, centre)
  surface.request_to_generate_chunks(centre, 3)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = centre.x - HALF, centre.x + HALF - 1 do
    for y = centre.y - HALF, centre.y + HALF - 1 do
      tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  local area = { { centre.x - HALF, centre.y - HALF }, { centre.x + HALF, centre.y + HALF } }
  for _, e in pairs(surface.find_entities_filtered { area = area }) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

function rig.prepare()
  local surface = game.surfaces.nauvis
  flatten(surface, { x = 0, y = 0 })
  flatten(surface, rig.UNIT_ORIGIN)
  game.forces.enemy.kill_all_units()
  game.map_settings.enemy_expansion.enabled = false
  game.forces.player.enable_all_recipes()
  return surface
end

function rig.robots(surface)
  local eei = surface.create_entity { name = "electric-energy-interface", position = { 0, -6 }, force = rig.FORCE }
  eei.power_production = 1e9
  eei.electric_buffer_size = 1e10
  surface.create_entity { name = "medium-electric-pole", position = { 0, -4 }, force = rig.FORCE }
  local port = surface.create_entity { name = "roboport", position = { 0, 0 }, force = rig.FORCE }
  port.insert { name = "construction-robot", count = 50 }
  local chest = surface.create_entity { name = "storage-chest", position = { 3, -4 }, force = rig.FORCE }
  for _, s in ipairs(STOCK) do chest.insert { name = s[1], count = s[2] } end
end

-- Unit-area position: offsets from UNIT_ORIGIN, far from any robot.
function rig.at(dx, dy)
  return { x = rig.UNIT_ORIGIN.x + dx, y = rig.UNIT_ORIGIN.y + dy }
end

function rig.ghost(surface, name, position, opts)
  opts = opts or {}
  local ghost = surface.create_entity {
    name = "entity-ghost", inner_name = name, position = position,
    force = opts.force or rig.FORCE, quality = opts.quality,
  }
  if opts.recipe then ghost.set_recipe(opts.recipe) end
  return ghost
end

function rig.built(surface, name, position, opts)
  opts = opts or {}
  return surface.create_entity {
    name = name, position = position, force = opts.force or rig.FORCE,
    quality = opts.quality, recipe = opts.recipe,
  }
end

-- The crafting machine standing at a position once robots have built it.
function rig.machine_at(surface, position)
  return surface.find_entities_filtered {
    position = position, radius = 0.5, type = { "furnace", "assembling-machine" },
  }[1]
end

-- A Priming (DESIGN.md) with the defaults the window would start from.
function rig.priming(t, fields)
  local p = { target = t, recipe = nil, quality = "normal", crafts = 0, fuel = nil, fuel_count = 0, fuel_edited = false }
  for k, v in pairs(fields or {}) do p[k] = v end
  return p
end

return rig

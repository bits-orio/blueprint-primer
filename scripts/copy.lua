-- A blueprint or copy of a primed built machine is primed like it (ADR-0008).
-- Vanilla keeps the fuel of a pending item-request-proxy but drops its
-- crafter_input positions (a ghost keeps both), and once the fuel has been
-- delivered it keeps nothing. So a machine whose ingredients are still
-- pending gets its whole priming written in: the full ingredient amounts
-- and the fuel, exactly as Shift+click paste would give another machine.

local const = require("scripts.const")
local carried = require("scripts.carried")
local request = require("scripts.request")

local copy = {}

-- What a copy owns: modules and anything else vanilla wrote are kept.
local OWNED = { [defines.inventory.crafter_input] = true, [defines.inventory.fuel] = true }

-- A ghost's type is "entity-ghost", so it never gets here: vanilla already
-- carried its whole plan. The proxy is checked before building a Priming
-- because almost no copied machine has one, and a large copy runs this for
-- every machine on every peer. Stack indices are inventory slots, not places
-- on the map, so a mirrored or rotated source needs no transform.
local function carry_one(entity, source, force, player_index)
  if not (const.CRAFTER_TYPES[source.type] and source.item_request_proxy) then return false end
  local p = carried.priming(source, force, player_index)
  if not p then return false end
  entity.items = request.merge(entity.items, request.plans(p.target, p), OWNED)
  return true
end

-- `mapping` is the engine's blueprint entity index -> source entity. If
-- another mod reshaped the blueprint first it no longer lines up, so a
-- count or name mismatch leaves the blueprint alone. True if anything changed.
function copy.carry(entities, mapping, force, player_index)
  if table_size(mapping) ~= #entities then return false end
  local changed = false
  for index, source in pairs(mapping) do
    local entity = entities[index]
    if entity and source.valid and entity.name == source.name
      and carry_one(entity, source, force, player_index) then
      changed = true
    end
  end
  return changed
end

-- A blueprint with contents, or a book's active one. An empty blueprint the
-- player dragged with is not set up yet: its new contents are elsewhere.
local function setup_stack(stack)
  if not (stack and stack.valid_for_read) then return nil end
  if stack.is_blueprint_book then
    local inventory, index = stack.get_inventory(defines.inventory.item_main), stack.active_index
    return inventory and index and setup_stack(inventory[index]) or nil
  end
  if stack.is_blueprint and stack.is_blueprint_setup() then return stack end
  return nil
end

local function setup_record(record)
  if record and record.valid and record.type == "blueprint" and record.is_blueprint_setup() then return record end
  return nil
end

-- Where 2.0 puts the blueprint being set up. blueprint_to_setup comes first,
-- as in Krastorio2 and IR3: on "select new contents" event.stack can still
-- hold the old contents. The library record comes last.
local function find_blueprint(event, player)
  return setup_stack(player.blueprint_to_setup) or setup_stack(event.stack)
    or setup_stack(player.cursor_stack) or setup_record(event.record)
end

-- The write is guarded because a failure here would stop the game for the
-- player; if it fails, vanilla's blueprint stands.
function copy.on_setup(event)
  local player = game.get_player(event.player_index)
  local mapping = event.mapping
  if not (player and player.valid and mapping and mapping.valid) then return end
  local blueprint = find_blueprint(event, player)
  local entities = blueprint and blueprint.get_blueprint_entities()
  if entities and copy.carry(entities, mapping.get(), player.force, player.index) then
    pcall(blueprint.set_blueprint_entities, entities)
  end
end

return copy

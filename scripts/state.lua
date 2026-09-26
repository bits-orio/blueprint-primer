-- Storage layout. Everything that must survive save/load or stay in sync in
-- multiplayer lives here, keyed by player (ADR-0005): never a file-level local.

local state = {}

local function players()
  local all = storage.players
  if not all then
    all = {}
    storage.players = all
  end
  return all
end

-- A record written by 0.1.x (Factorio 1.1, whose `global` a 2.0 load carries
-- over as `storage`) is `{max_stack = false}` with no fuel memory. Backfilled
-- on every read, so no accessor can meet the old shape.
local function upgrade(record)
  if not record.fuel_by_category then record.fuel_by_category = {} end
  record.max_stack = nil
  return record
end

-- Called from on_init and on_configuration_changed. 0.1.x also kept one
-- preferred fuel for the whole server, which the per-player memory replaces.
function state.init()
  for _, record in pairs(players()) do upgrade(record) end
  storage.preferred_fuel = nil
end

-- The per-player record, created on demand so a player who joined before the
-- mod was added still gets one.
function state.player(player_index)
  local all = players()
  local record = all[player_index]
  if not record then
    record = { fuel_by_category = {}, priming = nil }
    all[player_index] = record
  end
  return upgrade(record)
end

function state.remove(player_index)
  local all = storage.players
  if all then all[player_index] = nil end
end

return state

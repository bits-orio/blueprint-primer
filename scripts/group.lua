-- A Priming's group: every machine (or chest) of one kind a drag selected
-- (ADR-0011). The window edits one set of numbers; each member is primed
-- like it through carried.apply, the path Shift+click paste uses, so each
-- one is topped up and fuelled on its own numbers.

local const = require("scripts.const")
local target = require("scripts.target")
local request = require("scripts.request")
local carried = require("scripts.carried")
local copy = require("scripts.copy")
local blueprint = require("scripts.blueprint")
local priming = require("scripts.gui.priming")

local group = {}

function group.size(p)
  return p.group and #p.group or 1
end

-- The members still there: a ghost robots built since is followed to the
-- built machine; one mined or expired drops out.
local function live_members(p)
  local live = {}
  for _, t in ipairs(p.group or { p.target }) do
    if target.revalidate(t) then live[#live + 1] = t end
  end
  return live
end

-- Request for every member. Returns how many took it, the member count, and
-- the reason the first refusal gave (nil when all took it).
function group.request(p, player_index)
  local members = live_members(p)
  local done, reason = 0, nil
  for _, t in ipairs(members) do
    local ok, why = carried.apply(t, p, player_index)
    if ok then done = done + 1 else reason = reason or why end
  end
  return done, #members, reason
end

-- Adds one plan's positions to the sums, keyed by item and quality.
local function sum_plan(plan, sums, order)
  local id = plan.id
  local key = id.name .. "/" .. (id.quality or const.NORMAL_QUALITY)
  if not sums[key] then
    sums[key] = 0
    order[#order + 1] = { key = key, name = id.name, quality = id.quality }
  end
  for _, position in ipairs(plan.items.in_inventory) do sums[key] = sums[key] + (position.count or 1) end
end

-- What robots will bring for the whole group, before topping up: the full
-- per-member plans summed per item and quality, as rich-text "[item=x]n"
-- pairs. Members share a prototype, so plans are computed once per quality.
function group.totals(p, player_index)
  local by_quality, sums, order = {}, {}, {}
  for _, t in ipairs(p.group or { p.target }) do
    local plans = by_quality[t.quality]
    if not plans then
      plans = request.plans(t, priming.new(t, player_index, p), { top_up = false })
      by_quality[t.quality] = plans
    end
    for _, plan in ipairs(plans) do sum_plan(plan, sums, order) end
  end
  local parts = {}
  for _, entry in ipairs(order) do
    parts[#parts + 1] = blueprint.item_tag(entry.name, entry.quality) .. sums[entry.key]
  end
  return table.concat(parts, "  ")
end

-- The members by unit number, to match create_blueprint's mapping.
local function by_unit(members)
  local index = {}
  for _, t in ipairs(members) do index[t.entity.unit_number] = t end
  return index
end

-- Write the primed request (and, for an assembler, the recipe) into the
-- blueprint entity copied from a member, as if onto a fresh machine.
local function prime_entity(entity, t, p, player_index)
  local mine = priming.new(t, player_index, p)
  entity.items = request.merge(entity.items, request.plans(t, mine, { top_up = false }), request.owned(t))
  if t.kind == const.KIND_ASSEMBLER and p.recipe then
    entity.recipe, entity.recipe_quality = p.recipe, p.quality or const.NORMAL_QUALITY
  end
end

-- The whole dragged area as vanilla would copy it, with every member
-- primed. create_blueprint raises no on_player_setup_blueprint, so every
-- other built entity with a pending primed request (vanilla drops a built
-- proxy's ingredient positions, and all of a chest's) is carried as a copy
-- would carry it (ADR-0008); everything else stays as vanilla wrote it.
-- Split from the cursor handling so headless tests, which have no player,
-- can check it.
function group.write_area(stack, p, force, player_index)
  if not (p.area and stack.set_stack({ name = "blueprint" })) then return false end
  local mapping = stack.create_blueprint({ surface = p.target.surface, force = force, area = p.area })
  local entities = stack.get_blueprint_entities()
  if not entities or #entities == 0 then return false end
  local members, lined_up = by_unit(live_members(p)), table_size(mapping) == #entities
  for index, source in pairs(mapping) do
    local t, entity = source.valid and members[source.unit_number], entities[index]
    if t and entity then
      prime_entity(entity, t, p, player_index)
    elseif entity and lined_up then
      copy.carry_one(entity, source, force, player_index)
    end
  end
  stack.set_blueprint_entities(entities)
  stack.preview_icons = stack.default_icons
  return true
end

function group.to_cursor(player, p)
  return blueprint.into_cursor(player, function(stack)
    return group.write_area(stack, p, player.force, player.index)
  end)
end

return group

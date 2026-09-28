-- Build the primed request as insert plans, and write it onto a target:
-- the ghost's own insert_plan, or an item-request-proxy for a built machine
-- (ADR-0002). Only the ingredient and fuel inventories are ours (a chest's
-- whole inventory); every other pending request (modules above all) is
-- carried over untouched.

local const = require("scripts.const")
local craft = require("scripts.craft")
local target = require("scripts.target")
local placement = require("scripts.placement")

local request = {}

local NORMAL = const.NORMAL_QUALITY
local REASON = const.REASON
local NOTICE = const.NOTICE

-- The engine keys a plan by item and quality, so an item wanted in two
-- inventories (an ingredient that is also the fuel) must share one plan.
local function new_collector()
  return { list = {}, by_key = {} }
end

local function plan_for(collector, id)
  local key = id.name .. "/" .. (id.quality or NORMAL)
  local plan = collector.by_key[key]
  if not plan then
    plan = { id = id, items = { in_inventory = {} } }
    collector.by_key[key] = plan
    collector.list[#collector.list + 1] = plan
  end
  return plan
end

local function add_position(collector, name, quality, position)
  local positions = plan_for(collector, { name = name, quality = quality }).items.in_inventory
  positions[#positions + 1] = position
end

local function add_ingredients(collector, t, priming, top_up)
  local input, quality = target.input_inventory(t), priming.quality or NORMAL
  for _, ingredient in ipairs(craft.ingredients(priming.recipe)) do
    if ingredient.type == "item" then
      local count = math.min(math.ceil(ingredient.amount * priming.crafts), craft.slot_limit(ingredient))
      if top_up then count = count - target.inventory_count(t, input, ingredient.name, quality) end
      if count > 0 then
        add_position(collector, ingredient.name, quality, { inventory = input, stack = ingredient.slot, count = count })
      end
    end
  end
end

-- Room for `item` at `quality` in one fuel stack: a built machine's stack
-- holding another fuel (or this fuel at another quality) can take none, and
-- a request into it would never be delivered.
local function stack_room(inventory, index, item, quality, stack_size)
  if not inventory then return stack_size end
  local stack = inventory[index + 1]
  if not stack.valid_for_read then return stack_size end
  if stack.name == item and stack.quality.name == quality then return stack_size - stack.count end
  return 0
end

-- Returns the fuel that found no room, which only a built machine's slots
-- holding another fuel can leave over. The fuel quality is normal unless
-- the machine already burns this fuel at another (fuel.quality_for).
local function add_fuel(collector, t, priming, top_up)
  local item, quality, fuel_define = priming.fuel, priming.fuel_quality or NORMAL, defines.inventory.fuel
  local stack_size = prototypes.item[item].stack_size
  local left = priming.fuel_count
  local inventory = top_up and t.entity.get_inventory(fuel_define) or nil
  if top_up then left = left - target.inventory_count(t, fuel_define, item, quality) end
  local slots = inventory and #inventory or t.burner.fuel_inventory_size
  for index = 0, slots - 1 do
    if left <= 0 then return 0 end
    local count = math.min(left, stack_room(inventory, index, item, quality, stack_size))
    if count > 0 then
      add_position(collector, item, quality, { inventory = fuel_define, stack = index, count = count })
      left = left - count
    end
  end
  return math.max(0, left)
end

-- A chest's want list through placement.lua; returns the items that found
-- no room beside what a built chest holds.
local function add_chest(collector, t, priming, top_up)
  local entries, shortfall = placement.place(t, placement.wants(priming), top_up)
  for _, entry in ipairs(entries) do add_position(collector, entry.name, entry.quality, entry.position) end
  return shortfall
end

-- Returns the plans and what did not fit: fuel for a machine, items for a
-- chest.
function request.plans(t, priming, opts)
  local top_up = opts and opts.top_up and not t.is_ghost
  local collector, shortfall = new_collector(), 0
  if t.kind == const.KIND_CHEST then return collector.list, add_chest(collector, t, priming, top_up) end
  if t.kind ~= const.KIND_FUEL_ONLY and priming.recipe and (priming.crafts or 0) > 0 then
    add_ingredients(collector, t, priming, top_up)
  end
  if t.burner and priming.fuel and (priming.fuel_count or 0) > 0 and prototypes.item[priming.fuel] then
    shortfall = add_fuel(collector, t, priming, top_up)
  end
  return collector.list, shortfall
end

-- Inventory ids are per entity type (1 is a car's fuel but also a chest's
-- own inventory: defines.inventory.chest == defines.inventory.fuel), so what
-- we own depends on the kind of target.
function request.owned(t)
  if t.kind == const.KIND_CHEST then return { [target.input_inventory(t)] = true } end
  local owned = { [defines.inventory.fuel] = true }
  if t.kind ~= const.KIND_FUEL_ONLY then owned[target.input_inventory(t)] = true end
  return owned
end
local owned_inventories = request.owned

local function absorb_foreign(collector, plan, owned)
  local kept = {}
  for _, position in ipairs(plan.items.in_inventory or {}) do
    if not owned[position.inventory] then kept[#kept + 1] = position end
  end
  local grid = plan.items.grid_count
  if #kept == 0 and not (grid and grid > 0) then return end
  local host = plan_for(collector, plan.id)
  for _, position in ipairs(kept) do table.insert(host.items.in_inventory, position) end
  if grid and grid > 0 then host.items.grid_count = (host.items.grid_count or 0) + grid end
end

-- Also how a copy gets back the ingredients vanilla dropped (copy.lua).
function request.merge(existing, ours, owned)
  local collector = new_collector()
  for _, plan in ipairs(existing or {}) do absorb_foreign(collector, plan, owned) end
  for _, plan in ipairs(ours) do
    for _, position in ipairs(plan.items.in_inventory) do
      add_position(collector, plan.id.name, plan.id.quality, position)
    end
  end
  return collector.list
end

-- Recipes are written only where target.recipe_locked allows (ADR-0007).
-- A furnace has no recipe to set: the request into its input implies it.
local function prepare_recipe(t, priming)
  local recipe, quality = priming.recipe, priming.quality or NORMAL
  if t.kind == const.KIND_FUEL_ONLY or not recipe then return true end
  -- A chest has no recipe to set; items mode asks for no recipe at all.
  if t.kind == const.KIND_CHEST and priming.mode ~= const.MODE_RECIPE then return true end
  if not target.allows_recipe(t, recipe) then return false, REASON.RECIPE_NOT_ALLOWED end
  if not target.recipe_deliverable(t, recipe) then return false, REASON.FURNACE_NOT_RESEARCHED end
  local current, current_quality = target.current_recipe(t)
  if current == recipe and current_quality == quality then return true end
  if target.recipe_locked(t) then return false, REASON.RECIPE_MISMATCH end
  if t.kind == const.KIND_ASSEMBLER then t.entity.set_recipe(recipe, quality) end
  return true
end

local function write_proxy(t, ours)
  local entity = t.entity
  local proxy = entity.item_request_proxy
  local merged = request.merge(proxy and proxy.insert_plan, ours, owned_inventories(t))
  if proxy then
    proxy.insert_plan = merged
    -- An emptied proxy with nothing to remove would linger as a dead marker.
    if #merged == 0 and #proxy.removal_plan == 0 then proxy.destroy() end
    return
  end
  if #merged == 0 then return end
  entity.surface.create_entity {
    name = const.PROXY_NAME, target = entity, position = entity.position,
    force = entity.force, modules = merged,
  }
end

-- `true, notice` on success, where the notice says whether anything is on
-- its way (a built machine may already hold everything); `false, reason`
-- otherwise. Fuel that cannot fit beside another fuel refuses the whole
-- request, so a machine is never primed to run dry part-way through; so do
-- a chest's items that cannot fit beside what it holds.
function request.apply(t, priming)
  if not target.revalidate(t) then return false, REASON.TARGET_GONE end
  local ours, shortfall = request.plans(t, priming, { top_up = true })
  if shortfall > 0 then
    return false, t.kind == const.KIND_CHEST and REASON.CHEST_FULL or REASON.FUEL_SLOT_TAKEN
  end
  local ok, reason = prepare_recipe(t, priming)
  if not ok then return false, reason end
  if t.is_ghost then
    t.entity.insert_plan = request.merge(t.entity.insert_plan, ours, owned_inventories(t))
  else
    write_proxy(t, ours)
  end
  return true, #ours > 0 and NOTICE.REQUESTED or NOTICE.ALREADY_STOCKED
end

return request

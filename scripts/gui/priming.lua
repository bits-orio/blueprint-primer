-- The Priming record's rules: its defaults and every change the window can
-- make to it. Pure state over the CORE modules with no GUI access, so the
-- view can recompute everything from the record alone. The caps and
-- settling live in caps.lua, a chest's rows in items.lua.

local const = require("scripts.const")
local craft = require("scripts.craft")
local fuel = require("scripts.fuel")
local target = require("scripts.target")
local placement = require("scripts.placement")
local caps = require("scripts.gui.caps")
local items = require("scripts.gui.items")
local reopen = require("scripts.gui.reopen")

local priming = {}

local REASON = const.REASON
local clamp, share, settle = caps.clamp, caps.share, caps.settle

priming.cap = caps.crafts
priming.fuel_cap = caps.fuel
priming.estimate = caps.estimate

local function is_fuel_only(p)
  return p.target.kind == const.KIND_FUEL_ONLY
end

local function is_chest(p)
  return p.target.kind == const.KIND_CHEST
end

-- Output units per craft; 1 when the product is not deterministic and the
-- slider counts crafts instead.
function priming.per_craft(p)
  local output = p.recipe and craft.output(p.recipe)
  return output and output.amount_per_craft or 1
end

function priming.outputs(p)
  return p.crafts * priming.per_craft(p)
end

-- The target's own recipe, or nil when the window could not prime it.
local function live_recipe(t)
  local recipe, quality = target.current_recipe(t)
  if recipe and not target.allows_recipe(t, recipe) then recipe = nil end
  return recipe, quality or const.NORMAL_QUALITY
end

-- `carried`: another machine's Priming to start from instead of this
-- target's own pending request (a settings paste, paste.lua). A chest also
-- gets a mode and its rows (items.lua); reopen picks the mode.
function priming.new(t, player_index, carried)
  local recipe, quality = live_recipe(t)
  local p = {
    target = t,
    recipe = recipe,
    quality = quality,
    crafts = 0,
    fuel = nil,
    fuel_quality = const.NORMAL_QUALITY,
    fuel_count = 0,
    fuel_edited = false,
  }
  if t.kind == const.KIND_CHEST then p.mode, p.items, p.next_row_id = const.MODE_ITEMS, {}, 1 end
  if t.burner then p.fuel, p.fuel_quality = fuel.default(t, player_index) end
  if is_fuel_only(p) and p.fuel then p.fuel_count = share(priming.fuel_cap(p), false) end
  if carried then reopen.carry(p, carried) else reopen.preset(p) end
  settle(p)
  return p
end

-- Only a real change drops a typed fuel amount, so Max pressed at the max,
-- or a slider echoing the value the view just wrote, keeps the player's fuel.
function priming.set_crafts(p, crafts)
  local cap = priming.cap(p)
  if cap < 1 then return end
  local wanted = clamp(math.floor(crafts), 1, cap)
  if wanted == p.crafts then return end
  p.crafts = wanted
  p.fuel_edited = false
  caps.refuel(p)
end

-- Typed output counts round up: asking for 5 cables at 2 per craft makes 6.
function priming.set_outputs(p, outputs)
  priming.set_crafts(p, math.ceil(outputs / priming.per_craft(p)))
end

function priming.set_fuel_count(p, count)
  if not p.fuel then return end
  p.fuel_count = clamp(math.floor(count), 1, math.max(1, priming.fuel_cap(p)))
  if not is_fuel_only(p) then p.fuel_edited = true end
end

-- Half (full = false) or Max (full = true) of the craft slider.
function priming.preset_crafts(p, full)
  local cap = priming.cap(p)
  if cap >= 1 then priming.set_crafts(p, share(cap, full)) end
end

-- Half or Max of a fuel-only target's fuel slider.
function priming.preset_fuel(p, full)
  priming.set_fuel_count(p, share(priming.fuel_cap(p), full))
end

function priming.set_recipe(p, name)
  if not (name and target.allows_recipe(p.target, name)) then return false end
  if name == p.recipe then return true end
  p.recipe = name
  p.fuel_edited = false
  settle(p)
  return true
end

function priming.set_fuel(p, item, player_index)
  if not (item and fuel.accepts(p.target, item)) then return false end
  -- Remembered even when unchanged: picking the default on purpose is a choice.
  fuel.remember(player_index, p.target, item)
  if item == p.fuel then return true end
  -- Picking the fuel a built machine burns at another quality must match
  -- it, or the request could never be delivered beside it.
  p.fuel, p.fuel_quality = item, fuel.quality_for(p.target, item)
  p.fuel_edited = false
  settle(p)
  return true
end

-- A chest's switch (ADR-0013). Both modes keep their own state and only the
-- active one is requested. Into Items, empty rows start from the recipe's
-- want list; into Recipe, a record with no recipe takes the fed recipe.
function priming.set_mode(p, mode)
  if not is_chest(p) or p.mode == mode then return end
  if mode ~= const.MODE_ITEMS and mode ~= const.MODE_RECIPE then return end
  if mode == const.MODE_ITEMS and #p.items == 0 then items.fill(p, placement.wants(p)) end
  if mode == const.MODE_RECIPE and not p.recipe then
    local recipe, quality = target.fed_recipe(p.target)
    if recipe then p.recipe, p.quality, p.crafts = recipe, quality, 0 end
  end
  p.mode = mode
  settle(p)
end

-- "Uses N of M slots": the whole stacks the active mode fills in a fresh
-- chest, and the chest's slots.
function priming.slots(p)
  return placement.slots_needed(placement.wants(p)), placement.slots(p.target)
end

-- Request's pre-check on a built chest: its top-up would not fit beside
-- what it holds (CHEST_FULL). A blueprint is for a fresh chest, so this
-- never blocks Blueprint.
function priming.chest_full(p)
  local t = p.target
  if not is_chest(p) or t.is_ghost or not (t.entity and t.entity.valid) then return false end
  local _, short = placement.place(t, placement.wants(p), true)
  return short > 0
end

-- The same rule request.apply enforces (target.recipe_locked, ADR-0007).
function priming.recipe_locked(p)
  return target.recipe_locked(p.target)
end

-- A locked chooser must show the machine's real recipe, but robots reviving
-- the ghost, or another player in the vanilla GUI, can change it under an
-- open window. Re-derive it then, as a fresh window would; true if changed.
function priming.sync_locked(p)
  if not priming.recipe_locked(p) then return false end
  local recipe, quality = live_recipe(p.target)
  if recipe == p.recipe and (not recipe or quality == p.quality) then return false end
  p.recipe, p.quality = recipe, quality
  p.fuel_edited = false
  settle(p)
  return true
end

-- Why Request and Blueprint cannot act yet, as a locale key; nil when ready.
function priming.blocker(p)
  if is_fuel_only(p) then
    return not p.fuel and REASON.NO_FUEL or nil
  end
  if p.mode == const.MODE_ITEMS then return items.blocker(p) end
  if not p.recipe then
    return priming.recipe_locked(p) and REASON.RECIPE_NOT_PRIMABLE or REASON.PICK_RECIPE
  end
  if priming.cap(p) < 1 then return is_chest(p) and REASON.CHEST_CAP_ZERO or REASON.CAP_ZERO end
  return nil
end

return priming

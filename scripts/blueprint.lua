-- The primed blueprint (ADR-0007): one machine (or chest) carrying the
-- window's recipe and primed request, put in the cursor to be stamped as
-- often as wanted.

local const = require("scripts.const")
local craft = require("scripts.craft")
local request = require("scripts.request")
local placement = require("scripts.placement")

local blueprint = {}

local REASON = const.REASON
local NORMAL = const.NORMAL_QUALITY

-- The recipe the copy is set to: the window's, for an assembler. A fuel-only
-- assembler (a biochamber cracking oil) keeps the recipe it is on, which the
-- window never shows; a fixed recipe the engine sets by itself, and a
-- furnace's blueprint entity has no recipe at all.
local function recipe_of(t, priming)
  if t.kind == const.KIND_ASSEMBLER then return priming.recipe, priming.quality or NORMAL end
  local source = t.entity
  if t.kind ~= const.KIND_FUEL_ONLY or t.prototype.type ~= "assembling-machine" then return nil end
  if t.prototype.fixed_recipe or not (source and source.valid) then return nil end
  local recipe, quality = source.get_recipe()
  return recipe and recipe.name, quality and quality.name or NORMAL
end

-- A built chest's bar, as a blueprint writes it (get_bar() - 1; probed on
-- 2.0.77 and 2.1.17), or nil when it has none. Placement ignores the bar,
-- which does not stop slot-targeted delivery; the copy just keeps it.
local function chest_bar(t)
  local source = t.entity
  if t.kind ~= const.KIND_CHEST or t.is_ghost or not (source and source.valid) then return nil end
  local inventory = source.get_inventory(defines.inventory.chest)
  if not (inventory and inventory.supports_bar()) then return nil end
  local bar = inventory.get_bar()
  if bar > #inventory then return nil end
  return bar - 1
end

-- The request is written as if onto a fresh machine: whatever the source
-- machine holds right now does not travel with the blueprint.
function blueprint.entity(t, priming)
  local entity = {
    entity_number = 1,
    name = t.name,
    position = { x = 0, y = 0 },
    quality = t.quality,
    direction = t.direction,
    orientation = t.orientation, -- vehicles and rolling stock, instead of direction
    items = request.plans(t, priming, { top_up = false }),
  }
  -- A flipped machine's fluid connections only line up if the copy is too.
  local source = t.entity
  if source and source.valid and source.mirroring then entity.mirror = true end
  local recipe, quality = recipe_of(t, priming)
  if recipe then entity.recipe, entity.recipe_quality = recipe, quality end
  entity.bar = chest_bar(t)
  return entity
end

-- An item as rich text, its quality shown when it is not normal.
function blueprint.item_tag(name, quality)
  if not quality or quality == const.NORMAL_QUALITY then return "[item=" .. name .. "]" end
  return "[item=" .. name .. ",quality=" .. quality .. "]"
end

local function output_signal(priming)
  local output = priming.recipe and craft.output(priming.recipe)
  if output then return output.type, output.name, output.amount_per_craft * priming.crafts end
  if priming.recipe then return "recipe", priming.recipe, priming.crafts end
  if priming.fuel then return "item", priming.fuel, priming.fuel_count end
  return nil
end

-- An items-mode chest names its first row and how many more follow.
local function items_label(t, rows)
  local first = rows[1]
  if not first then return "[entity=" .. t.name .. "]" end
  local more = #rows > 1 and (" +" .. (#rows - 1)) or ""
  return string.format("[entity=%s] %s x%s%s", t.name, blueprint.item_tag(first.name, first.quality), first.count, more)
end

-- Labels are plain strings, but rich-text tags render in the blueprint
-- library and tooltip, so the output shows as its icon and count.
local function label(t, priming)
  if priming.mode == const.MODE_ITEMS then return items_label(t, placement.wants(priming)) end
  local kind, name, count = output_signal(priming)
  if not kind then return "[entity=" .. t.name .. "]" end
  return string.format("[entity=%s] [%s=%s] x%s", t.name, kind, name, count)
end

local function machine_item(t)
  local items = t.prototype.items_to_place_this
  return items and items[1] and items[1].name or nil
end

local MAX_ROW_ICONS = 3

-- The machine, then its output; an items-mode chest shows up to three rows.
local function icons(t, priming)
  local list = {}
  local function add(signal) list[#list + 1] = { index = #list + 1, signal = signal } end
  local item = machine_item(t)
  if item then add({ type = "item", name = item, quality = t.quality }) end
  if priming.mode == const.MODE_ITEMS then
    for i, want in ipairs(placement.wants(priming)) do
      if i <= MAX_ROW_ICONS then add({ type = "item", name = want.name, quality = want.quality }) end
    end
    return list
  end
  local kind, name = output_signal(priming)
  if kind == "item" or kind == "fluid" or kind == "recipe" then add({ type = kind, name = name }) end
  return list
end

-- Turns any writable stack into the primed blueprint; split from to_cursor
-- so headless tests, which have no player, can check the result.
function blueprint.write(stack, t, priming)
  if not stack.set_stack { name = "blueprint" } then return false end
  stack.set_blueprint_entities { blueprint.entity(t, priming) }
  stack.label = label(t, priming)
  stack.preview_icons = icons(t, priming)
  return true
end

-- Temporary, like a vanilla copy: clearing the cursor discards it, while
-- putting it in the inventory by hand keeps it.
-- The player's emptied cursor stack to write a blueprint into, or nil and
-- why not. A player with no cursor at all (a spectator) is refused before
-- anything is cleared.
function blueprint.cursor(player)
  if not (player and player.valid) then return nil, REASON.INVALID end
  local stack = player.cursor_stack
  if not stack then return nil, REASON.SPECTATOR end
  if not player.clear_cursor() then return nil, REASON.CURSOR_BLOCKED end
  return stack
end

-- Runs write(stack) on the cursor; temporary, like a vanilla copy.
function blueprint.into_cursor(player, write)
  local stack, why = blueprint.cursor(player)
  if not stack then return false, why end
  if not write(stack) then return false, REASON.CURSOR_BLOCKED end
  player.cursor_stack_temporary = true
  return true
end

function blueprint.to_cursor(player, t, priming)
  return blueprint.into_cursor(player, function(stack) return blueprint.write(stack, t, priming) end)
end

return blueprint

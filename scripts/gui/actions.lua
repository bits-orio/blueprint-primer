-- The window's two actions, Request and Blueprint, for one target or a
-- dragged group. The window closes only on success, so a refusal leaves
-- every number in place for another try.

local request = require("scripts.request")
local blueprint = require("scripts.blueprint")
local group = require("scripts.group")
local priming = require("scripts.gui.priming")
local window = require("scripts.gui.window")

local actions = {}

-- A success may carry a notice to show once the window is gone.
local function submit(player, p, act, fallback)
  if priming.blocker(p) then return end
  local ok, message = act()
  if not ok then return window.notify(player, message or fallback) end
  window.close(player)
  if message then window.notify(player, message) end
end

-- A group reports how many of its members took the request; any that did
-- not are counted, with the first reason given.
local function request_group(player, p)
  local done, total, reason = group.request(p, player.index)
  if done == 0 then return false, reason end
  if done == total then return true, { "bp-primer.requested-many", done } end
  return true, { "bp-primer.requested-some", done, total, { reason or "bp-primer.request-failed" } }
end

function actions.request(player, p)
  local act = function() return request.apply(p.target, p) end
  if group.size(p) > 1 then act = function() return request_group(player, p) end end
  submit(player, p, act, "bp-primer.request-failed")
end

-- A group's blueprint is its whole dragged area (ADR-0011).
function actions.blueprint(player, p)
  local act = function() return blueprint.to_cursor(player, p.target, p) end
  if group.size(p) > 1 then act = function() return group.to_cursor(player, p) end end
  submit(player, p, act, "bp-primer.blueprint-failed")
end

return actions

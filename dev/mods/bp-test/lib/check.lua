-- Assertions that log instead of throwing, so one broken case never hides
-- the rest. dev/run-tests.sh greps the BP_TEST lines.

local check = {}

local function say(line)
  log("BP_TEST " .. line)
end

local function tally(key)
  storage.tally = storage.tally or { pass = 0, fail = 0 }
  storage.tally[key] = storage.tally[key] + 1
end

function check.pass(case)
  tally("pass")
  say("PASS " .. case)
end

function check.fail(case, detail)
  tally("fail")
  say("FAIL " .. case .. ": " .. tostring(detail))
end

function check.info(text)
  say("INFO " .. text)
end

local function show(value)
  if type(value) == "table" then return serpent.line(value, { sortkeys = true, comment = false }) end
  return tostring(value)
end

function check.eq(case, got, want)
  if got == want then return check.pass(case) end
  check.fail(case, "got " .. show(got) .. ", want " .. show(want))
end

-- Deep equality through a canonical serialisation: good enough for the plain
-- data tables the contract returns.
function check.same(case, got, want)
  if show(got) == show(want) then return check.pass(case) end
  check.fail(case, "got " .. show(got) .. ", want " .. show(want))
end

function check.near(case, got, want, tolerance)
  if type(got) == "number" and math.abs(got - want) <= (tolerance or 1e-6) then return check.pass(case) end
  check.fail(case, "got " .. show(got) .. ", want " .. show(want) .. " +- " .. show(tolerance or 1e-6))
end

function check.truthy(case, value, detail)
  if value then return check.pass(case) end
  check.fail(case, detail or ("got " .. show(value)))
end

-- Runs one case body; an error inside it becomes a FAIL line with its message.
function check.run(case, body)
  local ok, err = pcall(body)
  if not ok then check.fail(case, "error: " .. tostring(err)) end
end

function check.done()
  local t = storage.tally or { pass = 0, fail = 0 }
  say(string.format("DONE pass=%d fail=%d", t.pass, t.fail))
end

function check.plan_line(item, inventory, stack, count, quality)
  return string.format("%s@%s %d[%d]=%d", item, quality or "normal", inventory, stack, count)
end

-- Canonical, order-free view of insert plans: "item@quality inv[stack]=count".
function check.plan_summary(plans)
  local lines = {}
  for _, plan in ipairs(plans or {}) do
    local id = plan.id.name .. "@" .. (plan.id.quality or "normal")
    for _, p in ipairs(plan.items.in_inventory or {}) do
      lines[#lines + 1] = string.format("%s %d[%d]=%d", id, p.inventory, p.stack, p.count or 1)
    end
    if (plan.items.grid_count or 0) > 0 then lines[#lines + 1] = id .. " grid=" .. plan.items.grid_count end
  end
  table.sort(lines)
  return lines
end

function check.lines(list)
  table.sort(list)
  return list
end

return check

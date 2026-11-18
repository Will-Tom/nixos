-- Git bar glyph: runs ~/bin/dash-git-status every 15 minutes (it fetches
-- each repo) and shares the JSON with the panel through noctalia.state.
-- Red with a count when repos are dirty/unpushed or a backup unit failed.
-- Click toggles the Git panel; the panel's refresh asks for a new scan.

local SCRIPT = noctalia.expandPath("~/bin/dash-git-status")
local INTERVAL_MS = 15 * 60 * 1000
local running = false

local function render(raw)
  local d = raw and noctalia.json.decode(raw)
  local problems = 0
  if d == nil then
    problems = -1
  else
    for _, r in ipairs(d.repos or {}) do
      if r.error or (r.dirty or 0) > 0 or (r.ahead or 0) > 0 then problems += 1 end
    end
    for _, s in ipairs(d.services or {}) do if not s.ok then problems += 1 end end
    for _, t in ipairs(d.timers or {}) do if not t.ok then problems += 1 end end
  end
  local children = { ui.glyph({ name = "git-branch", color = problems ~= 0 and "error" or nil }) }
  if problems > 0 then table.insert(children, ui.label({ text = tostring(problems), color = "error" })) end
  barWidget.render(ui.row({ gap = 4, align = "center" }, children))
end

local function scan()
  if running then return end
  running = true
  noctalia.state.set("git-busy", true)
  noctalia.runAsync({ SCRIPT }, function(result)
    running = false
    noctalia.state.set("git-busy", false)
    if result.exitCode == 0 and result.stdout ~= "" then
      noctalia.state.set("git", result.stdout)
    end
  end)
end

noctalia.state.watch("git", render)
noctalia.state.watch("git-refresh", function(v) if v ~= nil then scan() end end)

function update() scan() end

function onClick()
  noctalia.togglePanel("willisk/dashboard:git-panel")
end

render(noctalia.state.get("git"))
noctalia.setUpdateInterval(INTERVAL_MS)
scan()

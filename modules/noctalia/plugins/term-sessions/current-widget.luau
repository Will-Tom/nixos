-- Bar text for the focused session terminal:
--   "Nixos Configuring - /etc/nixos - hx modules/umbriel.nix"
-- (session - directory - foreground command; the command is left out at the
-- prompt). Hidden when the focused window isn't a session terminal.
-- Polls `term-sessions focus` once a second; one run at a time.

local SCRIPT = noctalia.expandPath("~/bin/term-sessions")
local MAX_CMD = 60
local running = false
local last = nil

local function render(d)
  local parts = {}
  if d.session and d.session ~= "" then table.insert(parts, d.session) end
  if d.cwd and d.cwd ~= "" then table.insert(parts, d.cwd) end
  if d.cmd and d.cmd ~= "" then
    local cmd = d.cmd
    if #cmd > MAX_CMD then cmd = string.sub(cmd, 1, MAX_CMD - 1) .. "…" end
    table.insert(parts, cmd)
  end
  local text = table.concat(parts, " - ")
  if text == last then return end
  last = text
  if text == "" then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(ui.row({ gap = 6, align = "center" }, {
    ui.glyph({ name = "terminal-2" }),
    ui.label({ text = text }),
  }))
end

function update()
  if running then return end
  running = true
  noctalia.runAsync({ SCRIPT, "focus" }, function(res)
    running = false
    local d = res.exitCode == 0 and noctalia.json.decode(res.stdout) or nil
    render(d or {})
  end)
end

noctalia.setUpdateInterval(1000)
update()

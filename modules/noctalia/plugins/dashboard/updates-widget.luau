-- Updates bar glyph. Reads the state dash-update writes:
--   idle: plain glyph · checking/applying: blue · ready: green + change count
--   failed: red · applied with a kernel/systemd change: yellow "reboot".
-- Click toggles the Updates panel.

local DIR = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/dash-update"
local BUSY = "#4A9EFF"
local GOOD = "#4CAF50"
local WARN = "#E0B341"

local function read(name)
  local s = noctalia.readFile(DIR .. "/" .. name)
  return s and (s:gsub("%s+$", "")) or nil
end

local function countLines(s)
  if s == nil or s == "" then return 0 end
  local _, n = s:gsub("\n", "\n")
  return n + 1
end

local last = nil

function update()
  local state = read("state") or "idle"
  local glyph, color, text = "package", nil, nil
  if state == "checking" or state == "applying" then
    glyph, color = "loader-2", BUSY
  elseif state == "ready" then
    local n = countLines(read("real.txt"))
    glyph, color, text = "package", GOOD, tostring(n)
  elseif state == "check-failed" or state == "apply-failed" then
    glyph, color = "package", "error"
  elseif state == "applied" and (read("reboot.txt") or "") ~= "" then
    glyph, color, text = "refresh-alert", WARN, "reboot"
  end
  local key = state .. tostring(text)
  if key == last then return end
  last = key
  local children = { ui.glyph({ name = glyph, color = color }) }
  if text then table.insert(children, ui.label({ text = text, color = color })) end
  barWidget.render(ui.row({ gap = 4, align = "center" }, children))
end

function onClick()
  noctalia.togglePanel("willisk/dashboard:updates-panel")
end

noctalia.setUpdateInterval(1000)
update()

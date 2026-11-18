-- Filesystem bar glyph: red when a btrfs error counter is non-zero, the
-- snapshot timer isn't active, or the stats are missing. Data comes from
-- /run/dashboard/fs.json (root dashboard-fs-status timer, every 15 min).
-- Click toggles the Filesystem panel.

local PATH = "/run/dashboard/fs.json"
local last = nil

function update()
  local raw = noctalia.readFile(PATH)
  local d = raw and noctalia.json.decode(raw)
  local bad = d == nil
    or (d.errors or 0) > 0
    or d.snapshots == nil or d.snapshots.timer ~= "active"
  local color = bad and "error" or nil
  local key = bad and "bad" or "ok"
  if key == last then return end
  last = key
  barWidget.render(ui.row({ align = "center" }, { ui.glyph({ name = "database", color = color }) }))
  barWidget.setTooltip(bad and "Filesystem: needs attention" or "Filesystem: healthy")
end

function onClick()
  noctalia.togglePanel("willisk/dashboard:fs-panel")
end

noctalia.setUpdateInterval(60000)
update()

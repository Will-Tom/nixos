-- Filesystem panel: what dash-filesystem.sh showed, read from
-- /run/dashboard/fs.json (root dashboard-fs-status timer, every 15 min).

local PATH = "/run/dashboard/fs.json"
local MONO = "Liberation Mono"
local GOOD = "#4CAF50"
local DIM = "on_surface_variant"

local function mono(text, color)
  return ui.label({ text = text, fontFamily = MONO, fontSize = 12, color = color })
end

local function section(title, kids)
  local col = { ui.label({ text = title, fontWeight = "bold", fontSize = 13 }) }
  for _, k in ipairs(kids) do table.insert(col, k) end
  return ui.column({ gap = 3 }, col)
end

local function pad(s, n) return s .. string.rep(" ", math.max(1, n - #s)) end

local function render()
  local raw = noctalia.readFile(PATH)
  local d = raw and noctalia.json.decode(raw)
  local kids = {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({ text = "FILESYSTEM HEALTH", fontWeight = "bold", fontSize = 15 }),
      ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
    }),
  }

  if d == nil then
    table.insert(kids, ui.label({ text = "No data yet (" .. PATH .. "). The dashboard-fs-status timer writes it every 15 minutes.", color = "error" }))
    panel.render(ui.column({ gap = 12, padding = 14 }, kids))
    return
  end

  -- btrfs error counters
  local stats = {}
  for _, s in ipairs(d.stats or {}) do
    table.insert(stats, mono("  " .. pad(s.counter, 18) .. s.value, s.value > 0 and "error" or nil))
  end
  if (d.errors or 0) > 0 then
    table.insert(stats, ui.label({ text = "⚠ non-zero error counters — investigate", color = "error" }))
  elseif #stats > 0 then
    table.insert(stats, ui.label({ text = "all counters zero ✓", color = GOOD }))
  else
    table.insert(stats, ui.label({ text = "could not read stats", color = "error" }))
  end
  table.insert(kids, section("btrfs error counters (/persist)", stats))

  -- scrubs
  local scrub = {}
  for _, s in ipairs(d.scrub or {}) do
    local text
    if s.never then
      text = "never scrubbed"
    else
      text = (s.status ~= "" and s.status or "?") .. ", " .. s.errors .. (s.started ~= "" and ("  (" .. s.started .. ")") or "")
    end
    local color = s.never and DIM or (s.errors == "no errors found" and nil or "error")
    table.insert(scrub, mono("  " .. pad(s.fs, 10) .. text, color))
  end
  table.insert(kids, section("Last scrub", scrub))

  -- snapshots
  local sn = d.snapshots or {}
  local snap = {}
  if sn.exists then
    table.insert(snap, mono("  count:   " .. tostring(sn.count)))
    table.insert(snap, mono("  newest:  " .. (sn.newest ~= "" and sn.newest or "none")))
    table.insert(snap, mono("  oldest:  " .. (sn.oldest ~= "" and sn.oldest or "none")))
    if sn.timer == "active" then
      table.insert(snap, mono("  timer:   active ✓", GOOD))
    else
      table.insert(snap, mono("  timer:   " .. (sn.timer or "?") .. " ⚠", "error"))
    end
  else
    table.insert(snap, ui.label({ text = "/persist/.snapshots missing", color = "error" }))
  end
  table.insert(kids, section("btrbk snapshots (/persist/.snapshots)", snap))

  -- usage and devices
  local u = d.usage or {}
  local usage = {
    mono("  device size:  " .. (u.size or "?")),
    mono("  used:         " .. (u.used or "?")),
    mono("  free (est.):  " .. (u.free or "?")),
  }
  for _, dev in ipairs(d.devices or {}) do
    table.insert(usage, mono("  " .. dev.name .. "  " .. dev.size .. "   " .. table.concat(dev.parts or {}, ", "), DIM))
  end
  table.insert(kids, section("Drive usage", usage))

  table.insert(kids, mono("checked " .. (d.checked or "?"), DIM))
  panel.render(ui.column({ gap = 12, padding = 14 }, kids))
end

function onOpen() render() end

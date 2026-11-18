-- Git panel: what dash-git.sh showed. The bar widget runs the scan and
-- shares its JSON through noctalia.state ("git"); refresh asks it to rescan.

local MONO = "Liberation Mono"
local GOOD = "#4CAF50"
local BUSY = "#4A9EFF"
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
  local raw = noctalia.state.get("git")
  local d = raw and noctalia.json.decode(raw)
  local busy = noctalia.state.get("git-busy") == true

  local kids = {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({ text = "GIT BACKUP STATUS", fontWeight = "bold", fontSize = 15 }),
      ui.row({ gap = 4, align = "center" }, {
        ui.button({ glyph = busy and "loader-2" or "refresh", variant = "ghost", enabled = not busy,
          tooltip = "Fetch and rescan",
          onClick = function()
            noctalia.state.set("git-refresh", (noctalia.state.get("git-refresh") or 0) + 1)
          end }),
        ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
      }),
    }),
  }

  if d == nil then
    table.insert(kids, ui.label({ text = busy and "Scanning…" or "No data yet.", color = busy and BUSY or DIM }))
    panel.render(ui.column({ gap = 12, padding = 14 }, kids))
    return
  end

  local repos = {}
  for _, r in ipairs(d.repos or {}) do
    if r.error then
      table.insert(repos, mono("  " .. pad(r.name, 18) .. r.error, "error"))
    else
      local msg, color = "clean, pushed ✓", GOOD
      if (r.dirty or 0) > 0 or (r.ahead or 0) > 0 then
        local parts = {}
        if r.dirty > 0 then table.insert(parts, r.dirty .. " uncommitted") end
        if r.ahead > 0 then table.insert(parts, r.ahead .. " unpushed") end
        if (r.behind or 0) > 0 then table.insert(parts, r.behind .. " behind") end
        msg, color = table.concat(parts, ", "), "error"
      elseif (r.behind or 0) > 0 then
        msg = "clean, " .. r.behind .. " behind"
      end
      table.insert(repos, mono("  " .. pad(r.name, 18) .. msg, color))
      table.insert(repos, mono("  " .. pad("", 18) .. "last: " .. r.last
        .. ((r.size or "") ~= "" and ("  (" .. r.size .. ")") or ""), DIM))
    end
  end
  table.insert(kids, section("Repositories", repos))

  local svcs = {}
  for _, s in ipairs(d.services or {}) do
    table.insert(svcs, mono("  " .. pad(s.label, 18) .. (s.ok and "ok" or s.state), s.ok and GOOD or "error"))
    if (s.last or "") ~= "" then table.insert(svcs, mono("  " .. pad("", 18) .. "last run: " .. s.last, DIM)) end
  end
  table.insert(kids, section("Backup services", svcs))

  local timers = {}
  for _, t in ipairs(d.timers or {}) do
    table.insert(timers, mono("  " .. pad(t.name, 34) .. (t.ok and "active ✓" or (t.state .. " ⚠")), t.ok and GOOD or "error"))
  end
  table.insert(kids, section("Backup timers", timers))

  table.insert(kids, mono("checked " .. (d.checked or "?") .. (busy and "   (rescanning…)" or ""), DIM))
  panel.render(ui.column({ gap = 12, padding = 14 }, kids))
end

noctalia.state.watch("git", function() render() end)
noctalia.state.watch("git-busy", function() render() end)

function onOpen() render() end

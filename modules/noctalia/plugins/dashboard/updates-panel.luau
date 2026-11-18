-- Updates panel: preview, review and apply system updates.
--   idle            locked nixpkgs, last preview, [Check for updates]
--   checking        live build log
--   ready           real changes (nvd [U]/[A]/[R]), closure size,
--                   [See full diff] [Accept] [Discard]
--   applying        switch log (password prompt comes from polkit)
--   applied         reboot recommendation if kernel/systemd changed
--   *-failed        log tail, [Retry] [Discard]
-- All state lives in files written by ~/bin/dash-update, so the panel can be
-- closed and reopened (or noctalia restarted) at any point.

local DASH = noctalia.expandPath("~/bin/dash-update")
local DIR = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/dash-update"
local LAST_PREVIEW = noctalia.expandPath("~/.local/state/dashboard/last-preview")
local APPLY_LOG = "/run/dashboard/apply.log"
local MONO = "Liberation Mono"

local GOOD = "#4CAF50"
local WARN = "#E0B341"
local BUSY = "#4A9EFF"
local DIM = "on_surface_variant"

local showFull = false
local lastSig = nil

local function read(path)
  local s = noctalia.readFile(path)
  return s and (s:gsub("%s+$", "")) or ""
end

local function lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do
    if l ~= "" then table.insert(t, l) end
  end
  return t
end

local function tail(s, n)
  local t = lines(s)
  local out = {}
  for i = math.max(1, #t - n + 1), #t do table.insert(out, t[i]) end
  return table.concat(out, "\n")
end

local function mono(text, color, size)
  return ui.label({ text = text, fontFamily = MONO, fontSize = size or 12, color = color })
end

local function heading(text)
  return ui.label({ text = text, fontWeight = "bold", fontSize = 14 })
end

local function lockedRev()
  local raw = noctalia.readFile("/etc/nixos/flake.lock")
  local d = raw and noctalia.json.decode(raw)
  local n = d and d.nodes and d.nodes.nixpkgs and d.nodes.nixpkgs.locked
  if not n then return "unknown" end
  local when = ""
  if n.lastModified then
    local ok, s = pcall(os.date, "%Y-%m-%d", n.lastModified)
    if ok then when = "  (" .. s .. ")" end
  end
  return string.sub(n.rev or "?", 1, 12) .. when
end

local function changeColor(line)
  if line:match("^%[U") then return BUSY end
  if line:match("^%[A") then return GOOD end
  if line:match("^%[R") then return "error" end
  return nil
end

local function run(cmd)
  noctalia.runAsync({ DASH, cmd }, function() lastSig = nil; update() end)
end

local function logBox(text, color)
  return ui.scroll({ flexGrow = 1, padding = 8, radius = 6, fill = "surface_container", stickToBottom = true },
    { mono(text ~= "" and text or "…", color) })
end

local function buttons(list)
  return ui.row({ gap = 8, justify = "end" }, list)
end

local function body(state)
  if state == "checking" then
    return {
      ui.row({ gap = 8, align = "center" }, { ui.glyph({ name = "loader-2", color = BUSY }),
        ui.label({ text = "Updating inputs on a scratch copy and building (not switching)…" }) }),
      logBox(tail(read(DIR .. "/log"), 200), DIM),
    }
  end

  if state == "applying" then
    return {
      ui.row({ gap = 8, align = "center" }, { ui.glyph({ name = "loader-2", color = BUSY }),
        ui.label({ text = "Switching… enter your password in the prompt if asked." }) }),
      logBox(tail(read(APPLY_LOG), 200), DIM),
    }
  end

  if state == "ready" then
    local real = lines(read(DIR .. "/real.txt"))
    local churn, closure = read(DIR .. "/summary"):match("^(.-)|(.*)$")
    local kids = {}
    if showFull then
      table.insert(kids, mono(read(DIR .. "/full.txt")))
    elseif #real == 0 then
      table.insert(kids, ui.label({ text = "No version changes, only closure dedup / rebuilds.", color = DIM }))
    else
      for _, l in ipairs(real) do table.insert(kids, mono(l, changeColor(l))) end
    end
    return {
      heading(showFull and "Full diff" or ("Real changes (" .. #real .. ")")),
      ui.scroll({ flexGrow = 1, padding = 8, radius = 6, fill = "surface_container", gap = 2 }, kids),
      mono((closure or "") .. "   ·   " .. (churn or "0") .. " closure-only changes hidden", DIM),
      buttons({
        ui.button({ text = showFull and "Real changes" or "See full diff", variant = "outline",
          onClick = function() showFull = not showFull; lastSig = nil; update() end }),
        ui.button({ text = "Discard", variant = "outline", onClick = function() run("discard") end }),
        ui.button({ text = "Accept", variant = "primary", glyph = "check", onClick = function() run("apply") end }),
      }),
    }
  end

  if state == "applied" then
    local reboot = read(DIR .. "/reboot.txt")
    local kids = { ui.label({ text = "Switched. Updated flake.lock staged (committed on next backup).", color = GOOD }) }
    if reboot ~= "" then
      table.insert(kids, ui.label({ text = "Kernel/systemd changed — a reboot is recommended:", color = WARN }))
      table.insert(kids, mono(reboot, WARN))
    else
      table.insert(kids, ui.label({ text = "No kernel/systemd change — no reboot needed.", color = GOOD }))
    end
    table.insert(kids, ui.spacer({ flexGrow = 1 }))
    table.insert(kids, buttons({ ui.button({ text = "Done", variant = "primary", onClick = function() run("discard") end }) }))
    return kids
  end

  if state == "check-failed" or state == "apply-failed" then
    local what = state == "check-failed" and "Build failed — nothing changed." or "Switch failed or was cancelled — flake.lock restored."
    local log = read(DIR .. "/log")
    if state == "apply-failed" then log = log .. "\n" .. read(APPLY_LOG) end
    return {
      ui.label({ text = what, color = "error" }),
      logBox(tail(log, 200), "error"),
      buttons({
        ui.button({ text = "Discard", variant = "outline", onClick = function() run("discard") end }),
        ui.button({ text = "Retry", variant = "primary",
          onClick = function() run(state == "check-failed" and "check" or "apply") end }),
      }),
    }
  end

  -- idle
  local last = read(LAST_PREVIEW)
  return {
    mono("Locked nixpkgs:     " .. lockedRev(), DIM),
    mono("Last full preview:  " .. (last ~= "" and last or "never"), DIM),
    ui.label({ text = "Builds an update preview on a scratch copy (slow, needs network). Nothing changes until you accept.", color = DIM }),
    ui.spacer({ flexGrow = 1 }),
    buttons({ ui.button({ text = "Check for updates", variant = "primary", glyph = "refresh",
      onClick = function() run("check") end }) }),
  }
end

function update()
  local state = read(DIR .. "/state")
  if state == "" then state = "idle" end
  if state ~= "ready" then showFull = false end
  -- Re-render only when something visible changed (keeps scroll position)
  local sig = state .. tostring(showFull)
  if state == "checking" then sig ..= #read(DIR .. "/log") end
  if state == "applying" then sig ..= #read(APPLY_LOG) end
  if sig == lastSig then return end
  lastSig = sig

  local header = ui.row({ align = "center", justify = "space_between" }, {
    ui.label({ text = "SYSTEM UPDATES", fontWeight = "bold", fontSize = 15 }),
    ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
  })
  local kids = { header }
  for _, k in ipairs(body(state)) do table.insert(kids, k) end
  panel.render(ui.column({ gap = 10, padding = 14, flexGrow = 1 }, kids))
end

function onOpen()
  lastSig = nil
  panel.setWantsSecondTicks(true)
  -- A check/apply that died with noctalia (or a reboot) shows as failed
  noctalia.runAsync({ DASH, "reconcile" }, function() lastSig = nil; update() end)
  update()
end

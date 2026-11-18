-- Shows the keyboard mode on the bar:
--   an active umbriel submap (MODAL, RESIZE, POWER) upper-cased in red,
--   otherwise SUPER in blue while Super is held (from `keyd listen`),
--   otherwise NORMAL in the normal text color.
-- Next to it, a toast like "SUPER + T - Terminal" in the normal text color,
-- sent by keybinds through `noctalia msg plugin ... toast <text>`
-- (~/bin/bar-toast). It holds, then fades; a new toast replaces it at once.

local SUBMAP_COLOR = "#FF0000"
local SUPER_COLOR = "#4A9EFF"

local TICK_MS = 50     -- update interval while a toast is visible
local HOLD_TICKS = 30  -- 1.5 s fully visible
local FADE_TICKS = 20  -- then 1 s fade out
local IDLE_MS = 1000

local submap = nil      -- active umbriel submap name, nil when none
local superHeld = false -- keyd meta layer active
local toast = nil       -- current toast text, nil when none
local toastTicks = 0

local function badge()
  if submap ~= nil and submap ~= "" then
    return string.upper(submap), SUBMAP_COLOR
  elseif superHeld then
    return "SUPER", SUPER_COLOR
  else
    return "NORMAL", "on_surface"
  end
end

local function render()
  local text, color = badge()
  local container = barWidget.isVertical() and ui.column or ui.row
  local children = { ui.label({ key = "badge", text = text, color = color }) }
  if toast ~= nil then
    local opacity = 1.0
    if toastTicks > HOLD_TICKS then
      opacity = math.max(0, 1 - (toastTicks - HOLD_TICKS) / FADE_TICKS)
    end
    table.insert(children, ui.label({ key = "toast", text = toast, opacity = opacity }))
  end
  barWidget.render(container({ gap = 12, align = "center" }, children))
end

-- umbriel submap events
local id = noctalia.compositor.subscribe({ events = { "submap" } }, function(event, data)
  if event == "submap" then
    submap = data
    render()
  elseif event == "reset" then
    submap = nil
    render()
  elseif event == "error" then
    noctalia.log(`submap-mode: {data}`)
  end
end)

if id == nil then
  noctalia.log(`submap-mode: no event stream on {noctalia.compositor.name()}`)
end

-- keyd layer changes: "+meta" / "-meta". Loop so it reconnects if keyd
-- restarts (runStream has no exit callback).
noctalia.runStream("while true; do keyd listen; sleep 2; done", function(line)
  if line == "+meta" then
    superHeld = true
    render()
  elseif line == "-meta" then
    superHeld = false
    render()
  end
end)

-- `noctalia msg plugin willisk/submap-mode:mode all toast <text>`
function onIpc(event, payload)
  if event == "toast" and payload ~= nil and payload ~= "" then
    toast = payload
    toastTicks = 0
    noctalia.setUpdateInterval(TICK_MS)
    render()
  end
end

function update()
  if toast ~= nil then
    toastTicks += 1
    if toastTicks >= HOLD_TICKS + FADE_TICKS then
      toast = nil
      noctalia.setUpdateInterval(IDLE_MS)
    end
  end
  render()
end

noctalia.setUpdateInterval(IDLE_MS)

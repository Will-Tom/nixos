-- Shows the keyboard mode on the bar:
--   an active umbriel submap (MODAL, RESIZE, POWER) upper-cased in red,
--   otherwise SUPER in blue while Super is held (from `keyd listen`),
--   otherwise NORMAL in the normal text color.

local SUBMAP_COLOR = "#FF0000"
local SUPER_COLOR = "#4A9EFF"

local submap = nil      -- active umbriel submap name, nil when none
local superHeld = false -- keyd meta layer active

local function render()
  if submap ~= nil and submap ~= "" then
    barWidget.setText(string.upper(submap))
    barWidget.setColor(SUBMAP_COLOR)
  elseif superHeld then
    barWidget.setText("SUPER")
    barWidget.setColor(SUPER_COLOR)
  else
    barWidget.setText("NORMAL")
    barWidget.setColor("on_surface")
  end
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

-- Also draw on the regular update tick, so the widget has text before the
-- first event arrives.
function update()
  render()
end

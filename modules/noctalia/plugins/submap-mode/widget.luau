-- Shows the active umbriel submap on the bar: NORMAL in the normal text
-- color, anything else (MODAL, RESIZE, POWER) upper-cased in red.

local ACTIVE_COLOR = "#FF0000"

local current = nil -- active submap name, nil when none

local function render()
  if current == nil or current == "" then
    barWidget.setText("NORMAL")
    barWidget.setColor("on_surface")
  else
    barWidget.setText(string.upper(current))
    barWidget.setColor(ACTIVE_COLOR)
  end
end

local id = noctalia.compositor.subscribe({ events = { "submap" } }, function(event, data)
  if event == "submap" then
    current = data
    render()
  elseif event == "reset" then
    current = nil
    render()
  elseif event == "error" then
    noctalia.log(`submap-mode: {data}`)
  end
end)

if id == nil then
  noctalia.log(`submap-mode: no event stream on {noctalia.compositor.name()}`)
end

-- Also draw on the regular update tick, so the widget has text before the
-- first event arrives.
function update()
  render()
end

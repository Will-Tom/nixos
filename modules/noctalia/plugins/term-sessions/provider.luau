-- Launcher provider behind "/ts". The query is "<verb> <text>":
--   open    /  pick a session to reopen its windows
--   move    m  put the focused terminal in a session (existing or new)
--   merge   M  move the focused session's terminals into another session
--   clone   c  name for a copy of the focused session
--   join    C  copy the focused session's terminals into an existing session
--   rename  r  new name for the focused session
-- Activating a result runs `~/bin/term-sessions <verb> <session>`.

local SCRIPT = noctalia.expandPath("~/bin/term-sessions")

local VERBS = {
  open   = { title = "Open %s",           new = false },
  move   = { title = "Move terminal to %s", new = true },
  merge  = { title = "Merge into %s",     new = false },
  clone  = { title = "Clone as %s",       new = true, nameOnly = true },
  join   = { title = "Clone into %s",     new = false },
  rename = { title = "Rename to %s",      new = true, nameOnly = true },
}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function subtitle(s)
  local parts = { s.shells .. (s.shells == 1 and " terminal" or " terminals") }
  if s.open < s.shells then table.insert(parts, (s.shells - s.open) .. " in background") end
  if s.focused then table.insert(parts, "focused session") end
  return table.concat(parts, " · ")
end

function onQuery(query)
  local verb, text = query:match("^(%a+)%s*(.*)$")
  local spec = verb and VERBS[verb]
  if not spec then
    launcher.setResults(query, {
      { id = "", title = "Sessions: open · move · merge · clone · join · rename", query = "/ts open ", glyph = "terminal-2" },
    })
    return
  end
  text = trim(text or "")

  noctalia.runAsync({ SCRIPT, "list" }, function(res)
    local sessions = (res.exitCode == 0 and noctalia.json.decode(res.stdout)) or {}
    local results = {}
    local exact = false
    if not spec.nameOnly then
      for _, s in ipairs(sessions) do
        local skip = ((verb == "merge" or verb == "join") and s.focused)
        local score = text == "" and 1 or noctalia.fuzzyScore(text, s.name)
        if not skip and score then
          if s.name == text then exact = true end
          table.insert(results, {
            id = verb .. "\t" .. s.name,
            title = string.format(spec.title, s.name),
            subtitle = subtitle(s),
            glyph = "terminal-2",
            score = score,
          })
        end
      end
    end
    if spec.new and text ~= "" and not exact and not text:find("%s") then
      table.insert(results, {
        id = verb .. "\t" .. text,
        title = string.format(spec.title, text),
        subtitle = spec.nameOnly and "Press Enter to confirm" or "New session",
        glyph = "plus",
        score = 1e9,
      })
    elseif spec.nameOnly and text == "" then
      table.insert(results, { id = "", title = "Type a session name", glyph = "pencil" })
    end
    if #results == 0 then
      table.insert(results, { id = "", title = "No matching sessions", glyph = "terminal-2" })
    end
    launcher.setResults(query, results)
  end)
end

function onActivate(id)
  local verb, name = id:match("^(%a+)\t(.+)$")
  if verb and name then
    noctalia.runAsync({ SCRIPT, verb, name })
  end
end

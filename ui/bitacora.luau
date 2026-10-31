-- Bitácora · its logic: which shells there are, in which tab and where in it;
-- what the tabs and the line under them say; and the desktop's colours.
-- The shells themselves are the engine's (`terminal term.$i` in bitacora.plm):
-- here they are only started (`s.$i.on`), placed and ended.

local MAXS = 12 -- shells
local MAXT = 10 -- tabs (a whole caravan fits)
local HOME = ""
do
    local ok, h = pcall(sys.ask, "env", "HOME")
    HOME = if ok and type(h) == "string" then h else ""
end
local function env(name: string): string
    local ok, v = pcall(sys.ask, "env", name)
    return if ok and type(v) == "string" then v else ""
end
-- (Under pleamar-wm its shells go through its layer of terminals: there are agents to read.)
local DATA = if env("XDG_DATA_HOME") ~= "" then env("XDG_DATA_HOME") else HOME .. "/.local/share"

-- A tab: its own number (they do not move when one closes), its panes in order,
-- how it was first split (0 beside, 1 below) and the pane that had the keys.
type Tab = { id: number, panes: { number }, dir: number, focus: number, ring: boolean }
local tabs: { Tab } = {}
local cur = 0 -- the id of the tab in front
local next_id = 1
local alive_seen = {} -- shell → it lived once (to tell an end from a start that failed)

-- ── the agents in its shells (pleamar-wm says, in its session) and the caravan's companions (Calima's) ──
-- Each shell's agent: its companion's name (the terminal was opened for one), which agent, how it is (0 none,
-- 1 working, 2 ready, 3 asks you) and its title. Filled every second from `pleamar-wm term list --json`.
type Agent = { who: string, agent: string, st: number, title: string }
local agents: { [number]: Agent } = {}
local pair_of: { [number]: number } = {} -- shell → the shell it is wired to (an agent beside it)
local pair_flow = 0
local fichas = {} -- companion id → { nombre, color, glifo }, false while it is read or if there is none
local in_session = env("PLEAMAR_REAL_SHELL") ~= ""
-- The companion this window was opened for (`pleamar-wm link open --name`): only its first shell is it.
local MY_NAME = env("BITACORA_NAME")
local name_given = false
local EXEC = env("BITACORA_EXEC")

local function tab_of(id: number): (Tab?, number)
    for k, t in ipairs(tabs) do
        if t.id == id then
            return t, k
        end
    end
    return nil, 0
end

-- ── where each one is: its folder, said short ──
local function short(path: string): string
    if HOME ~= "" and string.sub(path, 1, #HOME) == HOME then
        return "~" .. string.sub(path, #HOME + 1)
    end
    return path
end
local function base(path: string): string
    if path == "" then
        return ""
    end
    if path == HOME then
        return "~"
    end
    return string.match(path, "([^/]+)/*$") or path
end
local function folder_of(s: number): string
    local f = text[string.format("term.%d.folder", s)] or ""
    -- (A shell just started has not said it yet: where it was started.)
    return if f ~= "" then f else text[string.format("s.%d.start", s)] or ""
end

-- Its glyph: five rows of five grains, mirrored, from a name (Calima's caravan draws its companions the same way).
local function glyph_of(name: string): { number }
    local h = 5381
    for i = 1, #name do
        h = (h * 33 + string.byte(name, i)) % 2147483647
    end
    local rows = {}
    for r = 1, 5 do
        local b = (h // (8 ^ (r - 1))) % 8
        local c0, c1, c2 = b % 2, (b // 2) % 2, (b // 4) % 2
        rows[r] = c0 + 2 * c1 + 4 * c2 + 8 * c1 + 16 * c0
    end
    if rows[3] == 0 then
        rows[3] = 4
    end
    return rows
end

-- A companion's card, as Calima keeps it (`caravana-ID.json`): read once, and the tabs told when it comes.
local publish_tabs: () -> ()
local function ficha(id: string)
    if id == "" or not string.match(id, "^[%w%-_]+$") then
        return nil
    end
    local f = fichas[id]
    if f ~= nil then
        return f or nil
    end
    fichas[id] = false
    run("cat", { DATA .. "/pleamar/calima/caravana-" .. id .. ".json" }, function(out, code)
        local ok, d = pcall(json.decode, tostring(out or ""))
        if code == 0 and ok and type(d) == "table" then
            local g = {}
            for r = 1, 5 do
                g[r] = math.floor(tonumber(type(d.glifo) == "table" and d.glifo[r]) or 0)
            end
            fichas[id] = { nombre = tostring(d.nombre or id), color = math.floor(tonumber(d.color) or 0) % 8, glifo = g }
            publish_tabs()
        end
    end)
    return nil
end

local function agent_of(s: number): Agent?
    local a = agents[s]
    return if a and a.agent ~= "" then a else nil
end

-- An agent's name as it is said: «Claude», «Codex».
local function agent_word(a: Agent): string
    local f = ficha(a.who)
    if f then
        return f.nombre
    end
    local w = if a.agent ~= "" then a.agent else tr("Agent")
    return string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)
end

-- What a tab is called: its companion's name; an agent's task (its title, without the sign of how it is);
-- what its shell runs, if it says (a title that is not just where it is); or the folder it is in.
local function name_of(t: Tab): string
    local s = t.focus
    local a = agent_of(s)
    if a then
        local f = ficha(a.who)
        if f then
            return f.nombre
        end
        local task = string.gsub(string.gsub(a.title, "^[^%w%s]+%s*", ""), "%s+$", "")
        return if task ~= "" then task else agent_word(a)
    end
    local title = text[string.format("term.%d.title", s)] or ""
    local folder = folder_of(s)
    title = string.gsub(title, "^[%w%._%-]+@[%w%._%-]+:%s*", "")
    if HOME ~= "" and string.sub(title, 1, #HOME) == HOME then
        title = "~" .. string.sub(title, #HOME + 1)
    end
    local plain = title == "" or title == short(folder) or title == folder or string.match(title, "^~") ~= nil or string.match(title, "^/") ~= nil
    if not plain then
        return title
    end
    local b = base(folder)
    return if b ~= "" then b else "~"
end

local STATE_WORD = { "working", "ready", "asks you" }
local function publish_status()
    local t = tab_of(cur)
    if t == nil then
        return
    end
    local s = t.focus
    local folder = folder_of(s)
    text["st.where"] = short(folder)
    local title = text[string.format("term.%d.title", s)] or ""
    local a = agent_of(s)
    if a then
        text["st.what"] = agent_word(a) .. " · " .. tr(STATE_WORD[a.st] or "ready")
    else
        text["st.what"] = if name_of(t) ~= base(folder) then name_of(t) else ""
    end
    local cols, rows = tonumber(fact[string.format("term.%d.cols", s)]) or 0, tonumber(fact[string.format("term.%d.rows", s)]) or 0
    text["st.size"] = if cols > 0 then string.format("%d×%d", cols, rows) else ""
    local g = glyph_of(folder)
    for r = 0, 4 do
        fact["st.g" .. r] = g[r + 1]
    end
    local _ = title
end

publish_tabs = function()
    local rows = {}
    for _, t in ipairs(tabs) do
        local name = name_of(t)
        local g = glyph_of(folder_of(t.focus))
        local tone = -1
        local a = agent_of(t.focus)
        local f = if a then ficha(a.who) else nil
        if f then
            g = f.glifo
            tone = f.color
        end
        -- How its agents are: one that asks you first, then one at work, then the one with the keys.
        local ag = if a then a.st else 0
        for _, q in ipairs(t.panes) do
            local qa = agent_of(q)
            if qa and qa.st == 3 then
                ag = 3
            elseif qa and qa.st == 1 and ag ~= 3 then
                ag = 1
            end
        end
        table.insert(rows, { name = name, here = t.id == cur, g0 = g[1], g1 = g[2], g2 = g[3], g3 = g[4], g4 = g[5], ring = t.ring, ti = t.id, tone = tone, ag = ag })
    end
    model.tabs = rows
    for s = 0, MAXS - 1 do
        local a = agent_of(s)
        local f = if a then ficha(a.who) else nil
        fact[string.format("s.%d.ag", s)] = if a then a.st else 0
        fact[string.format("s.%d.tone", s)] = if f then f.color else -1
    end
    -- The wire of an agent beside a pane, in the tab in front.
    local t = tab_of(cur)
    local pa, pb = -1, -1
    if t then
        for _, q in ipairs(t.panes) do
            local o = pair_of[q]
            if o ~= nil and pa < 0 then
                for _, r in ipairs(t.panes) do
                    if r == o then
                        pa, pb = q, o
                    end
                end
            end
        end
    end
    fact["pair.a"], fact["pair.b"] = pa, pb
    local pa_agent = if pb >= 0 then (agent_of(pb) or agent_of(pa)) else nil
    fact["pair.st"] = if pa_agent then pa_agent.st else 0
    fact["pair.flow"] = if pa >= 0 then pair_flow else 0
    fact["panes"] = if t then #t.panes else 1
    fact["tab.cur"] = cur
    publish_status()
end

-- ── where each pane goes in its tab: one; two beside or one under the other;
-- three, the first big; four, a grid ──
local function lay_out(t: Tab)
    local n = #t.panes
    local places
    if n == 1 then
        places = { { 0, 0, 1, 1 } }
    elseif n == 2 then
        places = if t.dir == 0 then { { 0, 0, 0.5, 1 }, { 0.5, 0, 0.5, 1 } } else { { 0, 0, 1, 0.5 }, { 0, 0.5, 1, 0.5 } }
    elseif n == 3 then
        places = if t.dir == 0
            then { { 0, 0, 0.5, 1 }, { 0.5, 0, 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 } }
            else { { 0, 0, 1, 0.5 }, { 0, 0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 } }
    else
        places = { { 0, 0, 0.5, 0.5 }, { 0.5, 0, 0.5, 0.5 }, { 0, 0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 } }
    end
    for k, s in ipairs(t.panes) do
        local p = places[k]
        local f = string.format("s.%d.", s)
        fact[f .. "x"] = p[1]
        fact[f .. "y"] = p[2]
        fact[f .. "w"] = p[3]
        fact[f .. "h"] = p[4]
    end
end

local function free_shell(): number?
    for s = 0, MAXS - 1 do
        if (tonumber(fact[string.format("s.%d.on", s)]) or 0) < 0.5 then
            return s
        end
    end
    return nil
end

local function give_keys(s: number)
    -- (The terminal starts the frame after it is shown: the keys wait for it there.)
    focus(string.format("term.%d", s))
    after(60, function()
        focus(string.format("term.%d", s))
    end)
end

local pending_cmd: { [number]: string } = {} -- shell → what to type in it once its prompt is there
local function start_shell(s: number, t: Tab, folder: string, name: string?, cmd: string?)
    local f = string.format("s.%d.", s)
    alive_seen[s] = false
    agents[s] = nil
    pending_cmd[s] = if cmd and cmd ~= "" then cmd else nil
    text[f .. "start"] = folder
    -- The companion this window was opened for is its first shell, and no other: a new tab is yours.
    -- (One opened from outside for a companion, `open_named`, is that one's.)
    if name and name ~= "" then
        text[f .. "env"] = "PLEAMAR_NAME=" .. name
    else
        text[f .. "env"] = if MY_NAME ~= "" and not name_given then "PLEAMAR_NAME=" .. MY_NAME else ""
        name_given = name_given or MY_NAME ~= ""
    end
    fact[f .. "tab"] = t.id
    fact[f .. "on"] = 1
end

local toast_seq = 0
local function say(word: string)
    toast_seq += 1
    local mine = toast_seq
    text["toast"] = word
    fact["toast.on"] = true
    after(1800, function()
        if mine == toast_seq then
            fact["toast.on"] = false
        end
    end)
end

local function show_tab(id: number)
    local t = tab_of(id)
    if t == nil then
        return
    end
    cur = id
    t.ring = false
    publish_tabs()
    give_keys(t.focus)
end

local function new_tab(folder: string?, name: string?, cmd: string?, behind: boolean?): boolean
    if #tabs >= MAXT then
        say(tr("Ten tabs at most: close one first"))
        return false
    end
    local s = free_shell()
    if s == nil then
        say(tr("Twelve shells at most: close one first"))
        return false
    end
    local here = tab_of(cur)
    local where = folder or (if here then folder_of(here.focus) else "") or ""
    if where == "" then
        where = env("BITACORA_FOLDER")
    end
    local t: Tab = { id = next_id, panes = { s }, dir = 0, focus = s, ring = false }
    next_id += 1
    table.insert(tabs, t)
    lay_out(t)
    start_shell(s, t, where, name, cmd)
    if behind and cur ~= 0 then
        publish_tabs()
    else
        show_tab(t.id)
    end
    return true
end

-- A shell that goes takes its wire with it.
local function unpair(s: number)
    local o = pair_of[s]
    if o == nil then
        return
    end
    pair_of[s], pair_of[o] = nil, nil
    local pid = math.floor(tonumber(fact[string.format("term.%d.pid", o)]) or 0)
    if in_session and pid > 0 then
        run("pleamar-wm", { "term", "unpair", tostring(pid) }, function() end)
    end
end

local function close_tab(id: number)
    local t, k = tab_of(id)
    if t == nil then
        return
    end
    for _, s in ipairs(t.panes) do
        unpair(s)
        agents[s] = nil
        fact[string.format("s.%d.on", s)] = 0
        fact[string.format("s.%d.tab", s)] = -1
    end
    table.remove(tabs, k)
    if #tabs == 0 then
        emit("closed_all")
        return
    end
    if cur == id then
        show_tab(tabs[math.min(k, #tabs)].id)
    else
        publish_tabs()
    end
end

-- A pane goes (its shell ended, or Ctrl+Shift+W): the rest of its tab take its room; its last one takes the tab.
local function close_shell(s: number)
    unpair(s)
    agents[s] = nil
    for _, t in ipairs(tabs) do
        for k, p in ipairs(t.panes) do
            if p == s then
                if #t.panes == 1 then
                    close_tab(t.id)
                    return
                end
                table.remove(t.panes, k)
                fact[string.format("s.%d.on", s)] = 0
                fact[string.format("s.%d.tab", s)] = -1
                if t.focus == s then
                    t.focus = t.panes[math.min(k, #t.panes)]
                end
                lay_out(t)
                publish_tabs()
                if t.id == cur then
                    give_keys(t.focus)
                end
                return
            end
        end
    end
end

local function split(dir: number)
    local t = tab_of(cur)
    if t == nil then
        return
    end
    if #t.panes >= 4 then
        say(tr("Four panes a tab at most"))
        return
    end
    local s = free_shell()
    if s == nil then
        say(tr("Eight shells at most: close one first"))
        return
    end
    if #t.panes == 1 then
        t.dir = dir
    end
    -- Beside the one with the keys.
    local at = #t.panes + 1
    for k, p in ipairs(t.panes) do
        if p == t.focus then
            at = k + 1
        end
    end
    table.insert(t.panes, at, s)
    start_shell(s, t, folder_of(t.focus))
    t.focus = s
    lay_out(t)
    publish_tabs()
    give_keys(s)
end

-- Alt+arrows: to the pane that way, the nearest whose middle is past this one's edge.
local function move_focus(way: number)
    local t = tab_of(cur)
    if t == nil or #t.panes < 2 then
        return
    end
    local function box(s: number)
        local f = string.format("s.%d.", s)
        return tonumber(fact[f .. "x"]) or 0, tonumber(fact[f .. "y"]) or 0, tonumber(fact[f .. "w"]) or 1, tonumber(fact[f .. "h"]) or 1
    end
    local x, y, w, h = box(t.focus)
    local cx, cy = x + w / 2, y + h / 2
    local best, best_d = nil, math.huge
    for _, s in ipairs(t.panes) do
        if s ~= t.focus then
            local x2, y2, w2, h2 = box(s)
            local mx, my = x2 + w2 / 2, y2 + h2 / 2
            local ok = (way == 0 and mx < x) or (way == 1 and mx > x + w) or (way == 2 and my < y) or (way == 3 and my > y + h)
            if ok then
                local d = math.abs(mx - cx) + math.abs(my - cy)
                if d < best_d then
                    best, best_d = s, d
                end
            end
        end
    end
    if best then
        t.focus = best
        publish_tabs()
        give_keys(best)
    end
end

-- ── what the shells say ──
local branch_for = ""
local function look_branch(folder: string)
    if folder == branch_for then
        return
    end
    branch_for = folder
    if folder == "" then
        fact["st.git"] = false
        return
    end
    run("git", { "-C", folder, "branch", "--show-current" }, function(out, code)
        if folder ~= branch_for then
            return
        end
        local b = string.gsub(tostring(out or ""), "%s+$", "")
        if code ~= 0 then
            fact["st.git"] = false
            return
        end
        if b ~= "" then
            text["st.branch"] = b
            fact["st.git"] = true
            return
        end
        -- (Not on a branch: the commit it is on.)
        run("git", { "-C", folder, "rev-parse", "--short", "HEAD" }, function(o2, c2)
            if folder == branch_for then
                text["st.branch"] = string.gsub(tostring(o2 or ""), "%s+$", "")
                fact["st.git"] = c2 == 0
            end
        end)
    end)
end

for s = 0, MAXS - 1 do
    local p = string.format("term.%d.", s)
    on("fact:" .. p .. "focus", function(v)
        if (tonumber(v) or 0) > 0.5 then
            for _, t in ipairs(tabs) do
                for _, q in ipairs(t.panes) do
                    if q == s then
                        t.focus = s
                        if t.id ~= cur then
                            cur = t.id
                        end
                    end
                end
            end
            publish_tabs()
            look_branch(folder_of(s))
        end
    end)
    on("text:" .. p .. "folder", function()
        publish_tabs()
        local t = tab_of(cur)
        if t and t.focus == s then
            look_branch(folder_of(s))
        end
    end)
    on("text:" .. p .. "title", publish_tabs)
    on("fact:" .. p .. "cols", publish_status)
    on("fact:" .. p .. "rows", publish_status)
    on("fact:" .. p .. "alive", function(v)
        local on_ = (tonumber(fact[string.format("s.%d.on", s)]) or 0) > 0.5
        if (tonumber(v) or 0) > 0.5 then
            -- `bitacora -e COMMAND`: its first shell becomes that command, and ends with it. (Once its prompt
            -- is there, so that it is not written twice; cleared, and with a space before it so no history keeps it.)
            -- What a companion's tab was opened to run (`open_named`), typed once its prompt is there.
            if pending_cmd[s] and not alive_seen[s] then
                local line = pending_cmd[s] .. "\r"
                pending_cmd[s] = nil
                after(350, function()
                    pcall(sys.call, "terminal.write", string.format("term.%d", s), line)
                end)
            end
            if EXEC ~= "" and not alive_seen[s] then
                local line = " clear; exec " .. EXEC .. "\r"
                EXEC = ""
                after(350, function()
                    pcall(sys.call, "terminal.write", string.format("term.%d", s), line)
                end)
            end
            alive_seen[s] = true
        elseif on_ and alive_seen[s] then
            -- Its shell ended (exit, Ctrl+D): its pane goes, as in any terminal.
            close_shell(s)
        end
    end)
    on("fact:" .. p .. "bell", function()
        local f = string.format("s.%d.ring", s)
        fact[f] = 1
        after(700, function()
            fact[f] = 0
        end)
        for _, t in ipairs(tabs) do
            for _, q in ipairs(t.panes) do
                if q == s and t.id ~= cur then
                    t.ring = true
                    publish_tabs()
                end
            end
        end
    end)
end

on("new_tab", function()
    new_tab(nil)
end)
-- A companion's tab, asked from outside (Calima's caravan): `text open.name …`, `text open.folder …`,
-- `text open.cmd …`, then `emit open_named`. One that is here already is only brought forward if asked.
local function open_named()
    local name, folder, cmd = text["open.name"] or "", text["open.folder"] or "", text["open.cmd"] or ""
    local front = fact["open.front"] == true
    text["open.name"], text["open.cmd"] = "", ""
    fact["open.front"] = false
    if name == "" or not string.match(name, "^[%w%-_]+$") then
        return
    end
    for s = 0, MAXS - 1 do
        -- (By the name its shell was given: one just opened, its agent still starting, is it too.)
        local given = text[string.format("s.%d.env", s)] == "PLEAMAR_NAME=" .. name or (agents[s] ~= nil and agents[s].who == name)
        if given and (tonumber(fact[string.format("s.%d.on", s)]) or 0) > 0.5 then
            if front then
                for _, t in ipairs(tabs) do
                    for _, q in ipairs(t.panes) do
                        if q == s then
                            t.focus = s
                            show_tab(t.id)
                        end
                    end
                end
            end
            return
        end
    end
    if folder ~= "" and HOME ~= "" and string.sub(folder, 1, 1) == "~" then
        folder = HOME .. string.sub(folder, 2)
    end
    new_tab(if folder ~= "" then folder else nil, name, cmd, not front)
end
-- (What `--say` sets reaches the logic through the scene, and the event straight: a moment, and they are here.)
on("open_named", function()
    after(120, open_named)
end)
on("close_pane", function()
    local t = tab_of(cur)
    if t then
        close_shell(t.focus)
    end
end)
on("close_tab", function(v)
    close_tab(math.floor(tonumber(v) or cur))
end)
on("split", function(v)
    split(math.floor(tonumber(v) or 0))
end)
on("go_tab", function(v)
    show_tab(math.floor(tonumber(v) or cur))
end)
on("next_tab", function(v)
    local _, k = tab_of(cur)
    if k == 0 or #tabs < 2 then
        return
    end
    local d = if (tonumber(v) or 1) < 0 then -1 else 1
    local n = ((k - 1 + d) % #tabs) + 1
    show_tab(tabs[n].id)
end)
on("move_focus", function(v)
    move_focus(math.floor(tonumber(v) or 0))
end)
on("zoom_by", function(v)
    local d = tonumber(v) or 0
    local z = if d == 0 then 13.5 else math.clamp((tonumber(fact["zoom"]) or 13.5) + d, 8, 30)
    fact["zoom"] = z
    pcall(sys.call, "files.write", "zoom", tostring(z))
end)
on("new_window", function()
    local t = tab_of(cur)
    local where = if t then folder_of(t.focus) else ""
    local bin = env("BITACORA_BIN")
    -- (Loose from this one, `setsid -f`: closing this window does not take the new one with it.)
    run("setsid", { "-f", if bin ~= "" then bin else "bitacora", where }, function(_, code)
        say(if code == 0 then tr("A new window") else tr("A new window could not be opened"))
    end)
end)

-- ── looking for something in the history ──
local function focused_shell(): number?
    local t = tab_of(cur)
    return if t then t.focus else nil
end
on("find_open", function()
    local s = focused_shell()
    if s == nil then
        return
    end
    fact["find.s"] = s
    fact["find.miss"] = false
    fact["find.on"] = true
    focus("find.q")
    if (text["find.q"] or "") ~= "" then
        local ok = pcall(sys.call, "terminal.find", string.format("term.%d", s), text["find.q"])
        fact["find.miss"] = not ok
    end
end)
local function find_close()
    local s = math.floor(tonumber(fact["find.s"]) or 0)
    fact["find.on"] = false
    fact["find.miss"] = false
    pcall(sys.call, "terminal.find_end", string.format("term.%d", s))
    give_keys(s)
end
on("find_close", find_close)
-- (As it is written: from the end up, each letter.)
on("text:find.q", function(q)
    if not fact["find.on"] then
        return
    end
    local s = math.floor(tonumber(fact["find.s"]) or 0)
    if tostring(q or "") == "" then
        fact["find.miss"] = false
        pcall(sys.call, "terminal.find_end", string.format("term.%d", s))
        return
    end
    local ok = pcall(sys.call, "terminal.find", string.format("term.%d", s), tostring(q))
    fact["find.miss"] = not ok
end)
on("find_go", function(v)
    local k = math.floor(tonumber(v) or 1)
    if k == 2 then
        find_close()
        return
    end
    local s = math.floor(tonumber(fact["find.s"]) or 0)
    local q = text["find.q"] or ""
    -- 0 (and Enter): the one before, up its history; 1: the next, down.
    local older = k == 0
    local ok = pcall(sys.call, if older then "terminal.find" else "terminal.find_newer", string.format("term.%d", s), q)
    fact["find.miss"] = not ok
    focus("find.q")
end)

-- ── the agents in its shells: pleamar-wm's layer of terminals says, every second ──
local looking = false
local function look_agents()
    if looking then
        return
    end
    looking = true
    run("pleamar-wm", { "term", "list", "--json" }, function(out, code)
        looking = false
        local ok, d = pcall(json.decode, tostring(out or ""))
        if code ~= 0 or not ok or type(d) ~= "table" then
            return
        end
        local by = {}
        for _, l in ipairs(d.layers or {}) do
            by[math.floor(tonumber(l.id) or -1)] = l
        end
        local changed = false
        for s = 0, MAXS - 1 do
            local pid = math.floor(tonumber(fact[string.format("term.%d.pid", s)]) or 0)
            local l = if pid > 0 then by[pid] else nil
            local a: Agent? = nil
            if l and tostring(l.agent or "") ~= "" then
                local hook = tostring(l.hook or "")
                local st = if hook == "asking" then 3 elseif (if hook ~= "" then hook == "working" else l.state == "working") then 1 else 2
                a = { who = tostring(l.name or ""), agent = tostring(l.agent), st = st, title = tostring(l.title or "") }
            end
            local was = agents[s]
            if (was == nil) ~= (a == nil) or (was and a and (was.st ~= a.st or was.who ~= a.who or was.title ~= a.title)) then
                changed = true
                -- One that finished in a tab behind: its tab gets the dot, as a bell would.
                if was and a and was.st == 1 and a.st == 2 then
                    for _, t in ipairs(tabs) do
                        for _, q in ipairs(t.panes) do
                            if q == s and t.id ~= cur then
                                t.ring = true
                            end
                        end
                    end
                end
            end
            agents[s] = a
        end
        local flow = 0
        for _, p in ipairs(d.pairs or {}) do
            for a, b in pairs(pair_of) do
                if math.floor(tonumber(fact[string.format("term.%d.pid", a)]) or 0) == math.floor(tonumber(p.a) or -1)
                    and math.floor(tonumber(fact[string.format("term.%d.pid", b)]) or 0) == math.floor(tonumber(p.b) or -1) then
                    flow = math.floor(tonumber(p.flow) or 0)
                end
            end
        end
        if flow ~= pair_flow then
            pair_flow = flow
            changed = true
        end
        if changed then
            publish_tabs()
        end
    end)
end
if in_session then
    every(1000, look_agents)
end
-- The beat: only while something works, so that a window at rest stays at rest.
every(650, function()
    local busy = pair_flow ~= 0
    for _, a in pairs(agents) do
        if a.st == 1 then
            busy = true
        end
    end
    if busy or (tonumber(fact["beat"]) or 0) > 0.5 then
        fact["beat"] = if (tonumber(fact["beat"]) or 0) > 0.5 then 0 else 1
    end
end)

-- From outside (Calima's island, «View»): the tab whose shell is that one, in front, and the pane with the keys.
on("show_layer", function(v)
    local pid = math.floor(tonumber(v) or -1)
    for s = 0, MAXS - 1 do
        if pid > 0 and math.floor(tonumber(fact[string.format("term.%d.pid", s)]) or 0) == pid then
            for _, t in ipairs(tabs) do
                for _, q in ipairs(t.panes) do
                    if q == s then
                        t.focus = s
                        show_tab(t.id)
                        return
                    end
                end
            end
        end
    end
end)

-- ── an agent beside the pane with the keys, wired to it: it reads that pane and runs things in it as in a
-- window wired to its own (`pleamar-wm term pair`) ──
local AGENT = if env("BITACORA_AGENT") ~= "" then env("BITACORA_AGENT") else "claude"
local function agent_beside()
    local t = tab_of(cur)
    if t == nil then
        return
    end
    local mine = t.focus
    split(0)
    local s2 = t.focus
    if s2 == mine then
        return
    end
    unpair(mine)
    pair_of[mine], pair_of[s2] = s2, mine
    publish_tabs()
    local tries = 0
    local function start()
        pcall(sys.call, "terminal.write", string.format("term.%d", s2), AGENT .. "\r")
    end
    local function try()
        tries += 1
        local p1 = math.floor(tonumber(fact[string.format("term.%d.pid", mine)]) or 0)
        local p2 = math.floor(tonumber(fact[string.format("term.%d.pid", s2)]) or 0)
        if not in_session then
            start()
            return
        end
        if p1 <= 0 or p2 <= 0 then
            if tries < 24 then
                after(250, try)
            end
            return
        end
        -- (Wired before the agent starts: it is told what it is wired to when it starts.)
        run("pleamar-wm", { "term", "pair", tostring(p1), tostring(p2), "--label", "beside" }, function(_, code)
            if code ~= 0 and tries < 24 then
                after(250, try)
                return
            end
            if code ~= 0 then
                say(tr("The agent could not be wired to this pane"))
            end
            start()
        end)
    end
    after(200, try)
end
on("agent_beside", agent_beside)

-- ── «Send to…»: what is selected, as a letter to one of the caravan's companions ──
local sending = ""
local comp_ids = {}
local function send_open(s: number)
    local ok, sel = pcall(sys.ask, "terminal.selection", string.format("term.%d", s))
    if not ok or type(sel) ~= "string" or sel == "" then
        say(tr("Select something first"))
        give_keys(s)
        return
    end
    sending = tr("From my terminal, in %s:"):format(short(folder_of(s))) .. "\n\n```\n" .. sel .. "\n```"
    run("pleamar-wm", { "link", "caravan", "--json" }, function(out, code)
        local okj, d = pcall(json.decode, tostring(out or ""))
        local rows = {}
        comp_ids = {}
        if code == 0 and okj and type(d) == "table" then
            local busy = {}
            for _, n in ipairs(d.named or {}) do
                busy[tostring(n.name)] = tostring(n.state or "") == "working"
            end
            for _, b in ipairs(d.boxes or {}) do
                local id = tostring(b.name or "")
                if id ~= "" and #rows < 10 then
                    local f = ficha(id)
                    local g = if f then f.glifo else glyph_of(id)
                    table.insert(comp_ids, id)
                    table.insert(rows, { name = if f then f.nombre else id, tone = if f then f.color else 0, g0 = g[1], g1 = g[2], g2 = g[3], g3 = g[4], g4 = g[5], busy = busy[id] == true, ci = #comp_ids })
                end
            end
        end
        model.comps = rows
        fact["send.on"] = true
        -- (The cards of the ones not read yet come in a moment: the names then.)
        after(400, function()
            if not fact["send.on"] then
                return
            end
            local again = {}
            for k, id in ipairs(comp_ids) do
                local f = ficha(id)
                local r = rows[k]
                if f and r then
                    r.name, r.tone, r.g0, r.g1, r.g2, r.g3, r.g4 = f.nombre, f.color, f.glifo[1], f.glifo[2], f.glifo[3], f.glifo[4], f.glifo[5]
                end
                table.insert(again, r)
            end
            model.comps = again
        end)
    end)
end
on("send_to", function(v)
    local id = comp_ids[math.floor(tonumber(v) or 0)]
    fact["send.on"] = false
    local s = math.floor(tonumber(fact["menu.s"]) or 0)
    give_keys(s)
    if id == nil or sending == "" then
        return
    end
    local f = ficha(id)
    local who = if f then f.nombre else id
    run("pleamar-wm", { "link", "post", id, sending, "--from", "Bitácora" }, function(out, code)
        if code == 0 then
            say(tr("Sent to %s"):format(who))
        else
            say(tr("%s did not get it: %s"):format(who, string.sub(string.gsub(tostring(out or ""), "%s+$", ""), 1, 80)))
        end
    end, { errors = true })
    sending = ""
end)

-- ── the menu of the right button ──
on("menu_do", function(v)
    local k = math.floor(tonumber(v) or -1)
    local s = math.floor(tonumber(fact["menu.s"]) or 0)
    local name = string.format("term.%d", s)
    fact["menu.on"] = false
    -- (The pane pressed is the one acted on: it takes the keys first.)
    for _, t in ipairs(tabs) do
        for _, q in ipairs(t.panes) do
            if q == s then
                t.focus = s
            end
        end
    end
    if k == 0 then
        local ok = pcall(sys.call, "terminal.copy", name)
        say(if ok then tr("Copied") else tr("Nothing is selected"))
    elseif k == 1 then
        pcall(sys.call, "terminal.paste", name)
    elseif k == 2 then
        pcall(sys.call, "terminal.select_all", name)
    elseif k == 3 or k == 4 then
        split(k - 3)
        return
    elseif k == 5 then
        new_tab(nil)
        return
    elseif k == 6 then
        pcall(sys.call, "terminal.forget", name)
        say(tr("History forgotten"))
    elseif k == 7 then
        emit("new_window")
    elseif k == 8 then
        close_shell(s)
        return
    elseif k == 9 then
        emit("find_open")
        return
    elseif k == 10 then
        send_open(s)
        return
    elseif k == 11 then
        agent_beside()
        return
    end
    give_keys(s)
end)

-- ── the desktop's colours: Calima's Taller says them in a file, and they are followed ──
local theme_files = {}
do
    local c = env("PLEAMAR_CONFIG")
    if c ~= "" then
        table.insert(theme_files, c .. "/state/caravan-theme.json")
    end
    local st = env("XDG_STATE_HOME")
    table.insert(theme_files, (if st ~= "" then st else HOME .. "/.local/state") .. "/pleamar-wm/caravan-theme.json")
    local cf = env("XDG_CONFIG_HOME")
    table.insert(theme_files, (if cf ~= "" then cf else HOME .. "/.config") .. "/calima/state/caravan-theme.json")
end
local function hex(h: string?): (number?, number?, number?)
    if type(h) ~= "string" then
        return nil
    end
    local r, g, b = string.match(h, "^#(%x%x)(%x%x)(%x%x)")
    if not r then
        return nil
    end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end
local last_theme = ""
local function read_theme(k: number)
    local path = theme_files[k]
    if path == nil then
        return
    end
    run("cat", { path }, function(out, code)
        if code ~= 0 or out == nil or out == "" then
            read_theme(k + 1)
            return
        end
        if out == last_theme then
            return
        end
        local ok, th = pcall(json.decode, out)
        if not ok or type(th) ~= "table" then
            return
        end
        last_theme = out
        local ar, ag, ab = hex(th.accent)
        if ar then
            fact["th.ar"], fact["th.ag"], fact["th.ab"] = ar, ag, ab
        end
        local sr, sg, sb = hex(th.surface)
        if sr then
            fact["th.sr"], fact["th.sg"], fact["th.sb"] = sr, sg, sb
        end
        local ir, ig, ib = hex(th.ink)
        if ir then
            fact["th.ir"], fact["th.ig"], fact["th.ib"] = ir, ig, ib
        end
        fact["th.dk"] = if th.dark == false then 0 else 1
        fact["th.round"] = math.clamp(math.floor(tonumber(th.round) or 1), 0, 2)
    end)
end
read_theme(1)
every(3000, function()
    read_theme(1)
end)

-- ── it opens with one tab, where it was started ──
do
    local ok, z = pcall(sys.ask, "files.read", "zoom")
    if ok and tonumber(z) then
        fact["zoom"] = math.clamp(tonumber(z), 8, 30)
    end
end
new_tab(env("BITACORA_FOLDER"))

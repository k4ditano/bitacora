-- Bitácora · its logic: which shells there are, in which tab and where in it;
-- what the tabs and the line under them say; and the desktop's colours.
-- The shells themselves are the engine's (`terminal term.$i` in bitacora.plm):
-- here they are only started (`s.$i.on`), placed and ended.

local MAXS = 8 -- shells
local MAXT = 6 -- tabs
local HOME = ""
do
    local ok, h = pcall(sys.ask, "env", "HOME")
    HOME = if ok and type(h) == "string" then h else ""
end
local function env(name: string): string
    local ok, v = pcall(sys.ask, "env", name)
    return if ok and type(v) == "string" then v else ""
end

-- A tab: its own number (they do not move when one closes), its panes in order,
-- how it was first split (0 beside, 1 below) and the pane that had the keys.
type Tab = { id: number, panes: { number }, dir: number, focus: number, ring: boolean }
local tabs: { Tab } = {}
local cur = 0 -- the id of the tab in front
local next_id = 1
local alive_seen = {} -- shell → it lived once (to tell an end from a start that failed)

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

-- What a tab is called: what its shell runs, if it says (a title that is not
-- just where it is), or the folder it is in.
local function name_of(t: Tab): string
    local s = t.focus
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

local function publish_status()
    local t = tab_of(cur)
    if t == nil then
        return
    end
    local s = t.focus
    local folder = folder_of(s)
    text["st.where"] = short(folder)
    local title = text[string.format("term.%d.title", s)] or ""
    text["st.what"] = if name_of(t) ~= base(folder) then name_of(t) else ""
    local cols, rows = tonumber(fact[string.format("term.%d.cols", s)]) or 0, tonumber(fact[string.format("term.%d.rows", s)]) or 0
    text["st.size"] = if cols > 0 then string.format("%d×%d", cols, rows) else ""
    local g = glyph_of(folder)
    for r = 0, 4 do
        fact["st.g" .. r] = g[r + 1]
    end
    local _ = title
end

local function publish_tabs()
    local rows = {}
    for _, t in ipairs(tabs) do
        local name = name_of(t)
        local g = glyph_of(folder_of(t.focus))
        table.insert(rows, { name = name, here = t.id == cur, g0 = g[1], g1 = g[2], g2 = g[3], g3 = g[4], g4 = g[5], ring = t.ring, ti = t.id })
    end
    model.tabs = rows
    local t = tab_of(cur)
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

local function start_shell(s: number, t: Tab, folder: string)
    local f = string.format("s.%d.", s)
    alive_seen[s] = false
    text[f .. "start"] = folder
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

local function new_tab(folder: string?)
    if #tabs >= MAXT then
        say(tr("Six tabs at most: close one first"))
        return
    end
    local s = free_shell()
    if s == nil then
        say(tr("Eight shells at most: close one first"))
        return
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
    start_shell(s, t, where)
    show_tab(t.id)
end

local function close_tab(id: number)
    local t, k = tab_of(id)
    if t == nil then
        return
    end
    for _, s in ipairs(t.panes) do
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

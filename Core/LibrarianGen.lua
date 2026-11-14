-- Librarian Quests (module #6, research skills, v0.12), hosted by Head Librarian Tamsin
-- Quillfeather at the Knowledge Exchange library in Gadgetzan. Generators + registry +
-- the Library Passport book. Pure Lua (no WoW API).
--
-- Shelves, ABC order, contents pages, indexes, keywords, citations, two-source
-- comparisons and data tables are generated from small data lists; fact/opinion, notes,
-- sources and the research process are curated. Tables, indexes and citations are shown
-- left-aligned (p.code).
local _, ns = ...
local Util = ns.Util
local D = ns.LibrarianData
local NA = ns.Naturalist
local random, abs = Util.Random, math.abs

local LB = {}
ns.Librarian = LB

LB.MODULE_ID = "librarian"
LB.MAX_TEXT = 480
LB.MAX_CHOICE = 80

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end
local function pick(t) return t[random(1, #t)] end
local function choices(answer, distractors, n) return ns.Modules.TextChoices(answer, distractors, n) end
local LevelFor = NA.LevelFor

local function curated(bagKey, list, band, hintKey)
  return function(level)
    return NA.FromEntry(NA.Draw("lib_" .. bagKey, list, level), band, hintKey)
  end
end

-- n distinct topics (optionally all with different first letters)
function LB.Topics(n, distinctFirst)
  local out, firsts = {}, {}
  for _, t in ipairs(Util.Shuffle({ unpack(D.TOPICS) })) do
    local f = t:sub(1, 1)
    if #out < n and not (distinctFirst and firsts[f]) then
      out[#out + 1] = t
      firsts[f] = true
    end
  end
  return out
end

local function sorted(t)
  local c = { unpack(t) }
  table.sort(c)
  return c
end

-- contents pages: topics in order with increasing start pages
function LB.Contents(n, first, maxGap)
  local topics = LB.Topics(n)
  local rows, page = {}, first or 2
  for i, t in ipairs(topics) do
    rows[i] = { topic = t, page = page }
    page = page + random(3, maxGap or 8)
  end
  return rows, page -- page = first page after the last part
end

local function contentsText(rows)
  local lines = {}
  for _, r in ipairs(rows) do lines[#lines + 1] = r.topic .. " ..... " .. r.page end
  return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Generators
------------------------------------------------------------------------
local gen = {}

-- INITIATE (ages 5-7): always 3 big buttons --------------------------------
function gen.lib_shelves(level)
  local lv = LevelFor(level)
  if lv == 1 then
    local topics = LB.Topics(3)
    local lines = {}
    for i, t in ipairs(topics) do lines[i] = fmt("LIB_SHELF_N", i, t) end
    local k = random(1, 3)
    local a = fmt("LIB_SHELF", k)
    local ds = {}
    for i = 1, 3 do if i ~= k then ds[#ds + 1] = fmt("LIB_SHELF", i) end end
    return { text = fmt("LIB_Q_SHELF", table.concat(lines, "\n"), topics[k]), answer = a, choices = choices(a, ds, 3),
      hint = L().LIB_H_SHELVES, explain = fmt("LIB_E_SHELF", topics[k], k), code = true }
  end
  -- letter-range shelves
  local ranges = lv == 2 and { { "A", "H" }, { "I", "Q" }, { "R", "Z" } } or { { "A", "E" }, { "F", "L" }, { "M", "R" }, { "S", "Z" } }
  local topic = pick(D.TOPICS)
  local f = topic:sub(1, 1)
  local lines, ans, labels = {}, nil, {}
  for i, r in ipairs(ranges) do
    labels[i] = r[1] .. "-" .. r[2]
    lines[i] = fmt("LIB_SHELF_N", i, labels[i])
    if f >= r[1] and f <= r[2] then ans = i end
  end
  local a = fmt("LIB_SHELF", ans)
  local ds = {}
  for i = 1, #ranges do if i ~= ans then ds[#ds + 1] = fmt("LIB_SHELF", i) end end
  return { text = fmt("LIB_Q_SHELF_ABC", table.concat(lines, "\n"), topic), answer = a, choices = choices(a, ds, 3),
    hint = L().LIB_H_SHELVES, explain = fmt("LIB_E_SHELF_ABC", topic, f, labels[ans]), code = true }
end

function gen.lib_abc(level)
  local lv = LevelFor(level)
  local words
  if lv == 3 then
    -- same first letter: decide by the second letter
    local groups = {}
    for _, t in ipairs(D.TOPICS) do
      local f = t:sub(1, 1)
      groups[f] = groups[f] or {}
      groups[f][#groups[f] + 1] = t
    end
    local pairs2 = {}
    for _, g in pairs(groups) do if #g >= 2 then pairs2[#pairs2 + 1] = g end end
    table.sort(pairs2, function(a, b) return a[1] < b[1] end)
    local g = pick(pairs2)
    local two = Util.Shuffle({ unpack(g) })
    local letter = two[1]:sub(1, 1)
    words = { two[1], two[2] }
    -- the other word starts later in the alphabet, so the second letter decides
    for _, t in ipairs(Util.Shuffle({ unpack(D.TOPICS) })) do
      if #words < 3 and t:sub(1, 1) > letter then words[#words + 1] = t end
    end
  else
    words = LB.Topics(3, true)
  end
  local s = sorted(words)
  local last = lv == 2 and random() < 0.4
  local a = last and s[#s] or s[1]
  local ds = {}
  for _, w in ipairs(words) do if w ~= a then ds[#ds + 1] = w end end
  return { text = fmt(last and "LIB_Q_ABC_LAST" or "LIB_Q_ABC_FIRST", table.concat(Util.Shuffle({ unpack(words) }), ", ")),
    answer = a, choices = choices(a, ds, 3), hint = L().LIB_H_ABC, explain = fmt("LIB_E_ABC", table.concat(s, ", ")) }
end

function gen.lib_toc_simple(level)
  local lv = LevelFor(level)
  local rows, after = LB.Contents(3, random(2, 4), lv == 1 and 5 or 8)
  local k = random(1, 3)
  if lv == 3 and random() < 0.5 then
    -- which part is page N on?
    local hi = (rows[k + 1] and rows[k + 1].page or after) - 1
    local pg = random(rows[k].page, hi)
    local a = rows[k].topic
    local ds = {}
    for i, r in ipairs(rows) do if i ~= k then ds[#ds + 1] = r.topic end end
    return { text = fmt("LIB_Q_TOC_WHICH", contentsText(rows), pg), answer = a, choices = choices(a, ds, 3),
      hint = L().LIB_H_TOC, explain = fmt("LIB_E_TOC_WHICH", a, rows[k].page, hi), code = true }
  end
  local ds = {}
  for i, r in ipairs(rows) do if i ~= k then ds[#ds + 1] = r.page end end
  return { text = fmt("LIB_Q_TOC_PAGE", contentsText(rows), rows[k].topic), answer = rows[k].page,
    choices = choices(rows[k].page, ds, 3), hint = L().LIB_H_TOC, explain = fmt("LIB_E_TOC_PAGE", rows[k].topic, rows[k].page), code = true }
end

function gen.lib_keywords_young(level)
  if random() < 0.35 then return NA.FromEntry(NA.Draw("lib_kwy", D.KEYWORDS_YOUNG, level), "initiate", "LIB_H_KEYWORDS") end
  local animal = pick(D.ANIMALS)
  local cap = animal:gsub("^%l", string.upper)
  local verb = pick({ { "eat", "LIB_Q_KW_EAT" }, { "live", "LIB_Q_KW_LIVE" }, { "sleep", "LIB_Q_KW_SLEEP" } })
  local fillers = { "What", "Do", "Where", "How", "The" }
  local ds = {}
  for _, w in ipairs(Util.Shuffle(fillers)) do if #ds < 2 then ds[#ds + 1] = w end end
  return { text = fmt(verb[2], animal), answer = cap, choices = choices(cap, ds, 3), hint = L().LIB_H_KEYWORDS,
    explain = fmt("LIB_E_KW_YOUNG", cap) }
end

gen.lib_truesilly = curated("truesilly", D.TRUESILLY, "initiate", "LIB_H_TRUESILLY")

-- ADEPT (ages 8-10) --------------------------------------------------------
-- index: topics in ABC order with one or two page numbers
function LB.Index(n)
  local topics = sorted(LB.Topics(n))
  local rows, used = {}, {}
  for i, t in ipairs(topics) do
    local pages = {}
    for _ = 1, (random() < 0.35 and 2 or 1) do
      local p
      repeat p = random(3, 60) until not used[p]
      used[p] = true
      pages[#pages + 1] = p
    end
    table.sort(pages)
    rows[i] = { topic = t, pages = pages }
  end
  return rows
end

local function indexText(rows)
  local lines = {}
  for _, r in ipairs(rows) do lines[#lines + 1] = r.topic .. ", " .. table.concat(r.pages, ", ") end
  return table.concat(lines, "\n")
end

function gen.lib_index(level)
  local lv = LevelFor(level)
  local rows = LB.Index(lv == 1 and 4 or 5)
  local kind = random(1, lv == 1 and 2 or 3)
  local k = random(1, #rows)
  local r = rows[k]
  local head = fmt("LIB_INDEX_HEAD", indexText(rows))
  if kind == 1 then
    local ans = r.pages[1]
    local ds = {}
    for i, o in ipairs(rows) do if i ~= k then ds[#ds + 1] = o.pages[1] end end
    return { text = head .. "\n" .. fmt("LIB_Q_INDEX_PAGE", r.topic), answer = ans, distractors = ds, minChoice = 1,
      hint = L().LIB_H_INDEX, explain = #r.pages > 1 and fmt("LIB_E_INDEX_PAGE", r.topic, table.concat(r.pages, " and "), ans) or fmt("LIB_E_INDEX_PAGE1", r.topic, ans), code = true }
  elseif kind == 2 then
    local pg = r.pages[#r.pages]
    local ds = {}
    for i, o in ipairs(rows) do if i ~= k then ds[#ds + 1] = o.topic end end
    return { text = head .. "\n" .. fmt("LIB_Q_INDEX_WHICH", pg), answer = r.topic, choices = choices(r.topic, ds, lv == 1 and 4 or 4),
      hint = L().LIB_H_INDEX, explain = fmt("LIB_E_INDEX_WHICH", pg, r.topic), code = true }
  end
  -- how many pages in all mention these two topics?
  local o = rows[(k % #rows) + 1]
  local ans = #r.pages + #o.pages
  return { text = head .. "\n" .. fmt("LIB_Q_INDEX_COUNT", r.topic, o.topic), answer = ans, distractors = { ans + 1, ans - 1, 1 },
    minChoice = 1, hint = L().LIB_H_INDEX, explain = fmt("LIB_E_INDEX_COUNT", r.topic, #r.pages, o.topic, #o.pages, ans), code = true }
end

-- chapters with page ranges
function gen.lib_toc(level)
  local lv = LevelFor(level)
  local rows, after = LB.Contents(lv == 1 and 3 or 4, random(3, 9), lv == 3 and 15 or 10)
  local lines = {}
  for i, r in ipairs(rows) do lines[i] = fmt("LIB_CHAPTER", i, r.topic, r.page) end
  local text = table.concat(lines, "\n") .. "\n" .. fmt("LIB_TOC_END", after - 1)
  local k = random(1, #rows)
  local last = (rows[k + 1] and rows[k + 1].page or after) - 1
  if random() < 0.5 then
    local pg = random(rows[k].page, last)
    local a = rows[k].topic
    local ds = {}
    for i, r in ipairs(rows) do if i ~= k then ds[#ds + 1] = r.topic end end
    return { text = text .. "\n" .. fmt("LIB_Q_TOC_WHICH2", pg), answer = a, choices = choices(a, ds, 4),
      hint = L().LIB_H_TOC2, explain = fmt("LIB_E_TOC_WHICH", a, rows[k].page, last), code = true }
  end
  local ans = last - rows[k].page + 1
  return { text = text .. "\n" .. fmt("LIB_Q_TOC_LONG", k, rows[k].topic), answer = ans,
    distractors = { ans - 1, ans + 1, last }, minChoice = 1, hint = L().LIB_H_TOC2,
    explain = fmt("LIB_E_TOC_LONG", rows[k].page, last, ans), code = true }
end

-- question -> best search words
function gen.lib_keywords(level)
  local lv = LevelFor(level)
  local t = pick(D.KEYWORD_TEMPLATES)
  local animal = pick(D.ANIMALS)
  local a = t.a:format(animal)
  local ds = {}
  for _, d in ipairs(t.d) do ds[#ds + 1] = d:find("%%s") and d:format(animal) or d end
  if lv == 3 and random() < 0.4 then
    return { text = fmt("LIB_Q_KW_WORST", t.q:format(animal)), answer = ds[1], choices = choices(ds[1], { a, ds[3] }, 3),
      hint = L().LIB_H_KEYWORDS2, explain = fmt("LIB_E_KW_WORST", ds[1], a) }
  end
  return { text = fmt("LIB_Q_KW", t.q:format(animal)), answer = a, choices = choices(a, ds, 4),
    hint = L().LIB_H_KEYWORDS2, explain = fmt("LIB_E_KW", a) }
end

gen.lib_factopinion = curated("factop", D.FACTOPINION, "adept", "LIB_H_FACTOPINION")
gen.lib_notes = curated("notes", D.NOTES, "adept", "LIB_H_NOTES")

-- MAGISTER (ages 11-13) ----------------------------------------------------
gen.lib_sources = curated("sources", D.SOURCES, "magister", "LIB_H_SOURCES")

-- citations: Last, First. Title. Year.
function LB.Citation(b, parts)
  local out = {}
  if parts.author ~= false then out[#out + 1] = b.last .. ", " .. b.first .. "." end
  if parts.title ~= false then out[#out + 1] = b.title .. "." end
  if parts.year ~= false then out[#out + 1] = tostring(b.year) .. "." end
  return table.concat(out, " ")
end

function gen.lib_citing(level)
  local lv = LevelFor(level)
  if random() < 0.3 then return NA.FromEntry(NA.Draw("lib_cite", D.CITE, level), "magister", "LIB_H_CITING") end
  local b = pick(D.BOOKS)
  local info = fmt("LIB_BOOK_INFO", b.title, b.first .. " " .. b.last, b.year)
  local kind = random(1, lv == 1 and 2 or 3)
  if kind == 1 then
    local a = LB.Citation(b, {})
    return { text = info .. "\n" .. L().LIB_Q_CITE_COMPLETE, answer = a,
      choices = choices(a, { LB.Citation(b, { author = false }), LB.Citation(b, { year = false }), LB.Citation(b, { title = false }) }, 4),
      hint = L().LIB_H_CITING, explain = fmt("LIB_E_CITE_COMPLETE", a), code = true }
  elseif kind == 2 then
    local cite = LB.Citation(b, {})
    local a = b.first .. " " .. b.last
    local o = pick(D.BOOKS)
    if o == b then o = D.BOOKS[(#D.BOOKS > 1) and ((b == D.BOOKS[1]) and 2 or 1) or 1] end
    return { text = fmt("LIB_Q_CITE_AUTHOR", cite), answer = a, choices = choices(a, { b.title, tostring(b.year), o.first .. " " .. o.last }, 4),
      hint = L().LIB_H_CITING, explain = fmt("LIB_E_CITE_AUTHOR", a), code = true }
  end
  -- which part is missing?
  local missing = pick({ "author", "title", "year" })
  local parts = { [missing] = false }
  local a = L()["LIB_PART_" .. missing:upper()]
  local ds = {}
  for _, k in ipairs({ "author", "title", "year" }) do if k ~= missing then ds[#ds + 1] = L()["LIB_PART_" .. k:upper()] end end
  ds[#ds + 1] = L().LIB_PART_NONE
  return { text = fmt("LIB_Q_CITE_MISSING", LB.Citation(b, parts)), answer = a, distractors = ds, typed = true,
    alts = { missing, "the " .. missing }, hint = L().LIB_H_CITING, explain = fmt("LIB_E_CITE_MISSING", a), code = true }
end

-- two sources about one event
function gen.lib_compare(level)
  local lv = LevelFor(level)
  local c = pick(D.COMPARE)
  local na = random(5, 15)
  local nb = na + random(3, 12)
  local text = "A) " .. c.a:format(na) .. "\nB) " .. c.b:format(nb)
  local kind = random(1, lv == 1 and 2 or 4)
  local others = {}
  for _, o in ipairs(D.COMPARE) do if o ~= c then others[#others + 1] = o end end
  others = Util.Shuffle(others)
  if kind == 1 then
    return { text = text .. "\n" .. L().LIB_Q_AGREE, answer = c.agree,
      choices = choices(c.agree, { fmt("LIB_COMPARE_SAME_NUMBER", c.thing), others[1].agree, L().LIB_COMPARE_NOTHING }, 4),
      hint = L().LIB_H_COMPARE, explain = fmt("LIB_E_AGREE", c.agree), code = true }
  elseif kind == 2 then
    return { text = text .. "\n" .. L().LIB_Q_DIFFER, answer = c.differ,
      choices = choices(c.differ, { L().LIB_COMPARE_WHERE, L().LIB_COMPARE_WHAT, others[1].differ }, 4),
      hint = L().LIB_H_COMPARE, explain = fmt("LIB_E_DIFFER", c.differ), code = true }
  elseif kind == 3 then
    return { text = text .. "\n" .. L().LIB_Q_RELIABLE, answer = c.reliable,
      choices = choices(c.reliable, { fmt("LIB_COMPARE_B_BIGGER", c.thing), L().LIB_COMPARE_LONGER, L().LIB_COMPARE_BOTH }, 4),
      hint = L().LIB_H_COMPARE, explain = fmt("LIB_E_RELIABLE", c.reliable), code = true }
  end
  local ans = nb - na
  return { text = text .. "\n" .. fmt("LIB_Q_COMPARE_DIFF", c.thing), answer = ans, distractors = { na, nb, ans + 1 },
    minChoice = 1, hint = L().LIB_H_COMPARE, explain = fmt("LIB_E_COMPARE_DIFF", nb, na, ans), code = true }
end

-- reading a data table
function gen.lib_tables(level)
  local lv = LevelFor(level)
  local t = pick(D.TABLES)
  local vals, seen = {}, {}
  for i = 1, #t.rows do
    local v
    repeat v = random(2, lv == 1 and 12 or 40) until not seen[v]
    seen[v] = true
    vals[i] = v
  end
  local lines = { t.title .. " (" .. t.col .. ")" }
  for i, r in ipairs(t.rows) do lines[#lines + 1] = r .. ": " .. vals[i] end
  local text = table.concat(lines, "\n")
  local kind = random(1, lv == 1 and 2 or 4)
  if kind == 1 then
    local k = random(1, #t.rows)
    return { text = text .. "\n" .. fmt("LIB_Q_TABLE_LOOKUP", t.col:lower(), t.rows[k]), answer = vals[k],
      distractors = { vals[(k % #vals) + 1] }, minChoice = 1, hint = L().LIB_H_TABLES,
      explain = fmt("LIB_E_TABLE_LOOKUP", t.rows[k], vals[k]), code = true }
  elseif kind == 2 then
    local most = random() < 0.5
    local best = 1
    for i, v in ipairs(vals) do if (most and v > vals[best]) or (not most and v < vals[best]) then best = i end end
    local a = t.rows[best]
    local ds = {}
    for i, r in ipairs(t.rows) do if i ~= best then ds[#ds + 1] = r end end
    return { text = text .. "\n" .. fmt(most and "LIB_Q_TABLE_MOST" or "LIB_Q_TABLE_LEAST", t.col:lower()), answer = a,
      choices = choices(a, Util.Shuffle(ds), 4), hint = L().LIB_H_TABLES, explain = fmt("LIB_E_TABLE_BEST", a, vals[best]), code = true }
  elseif kind == 3 then
    local i, j = random(1, #vals), random(1, #vals)
    if i == j then j = (i % #vals) + 1 end
    local ans = abs(vals[i] - vals[j])
    return { text = text .. "\n" .. fmt("LIB_Q_TABLE_DIFF", t.col:lower(), t.rows[i], t.rows[j]), answer = ans,
      distractors = { vals[i] + vals[j], ans + 1, ans - 1 }, minChoice = 0, hint = L().LIB_H_TABLES,
      explain = fmt("LIB_E_TABLE_DIFF", math.max(vals[i], vals[j]), math.min(vals[i], vals[j]), ans), code = true }
  end
  local sum = 0
  for _, v in ipairs(vals) do sum = sum + v end
  return { text = text .. "\n" .. fmt("LIB_Q_TABLE_TOTAL", t.col:lower()), answer = sum, distractors = { sum + 10, sum - 1, sum + 1 },
    hint = L().LIB_H_TABLES, explain = fmt("LIB_E_TABLE_TOTAL", sum), code = true }
end

gen.lib_skim = curated("skim", D.SKIM, "magister", "LIB_H_SKIM")

------------------------------------------------------------------------
-- Answer check: numbers typed or picked, typed words with spellings, buttons
------------------------------------------------------------------------
function LB.Check(p, given)
  if type(p.answer) == "number" then
    if p.mode == "choice" then return tostring(given) == tostring(p.answer) end
    local n = Util.ParseNumber(given)
    return n ~= nil and abs(n - p.answer) < 1e-9
  end
  return NA.Check(p, given)
end

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
LB.BANDS = {
  initiate = { id = "initiate", nodes = { "lib_shelves", "lib_abc", "lib_toc_simple", "lib_keywords_young", "lib_truesilly" } },
  adept    = { id = "adept",    nodes = { "lib_index", "lib_toc", "lib_keywords", "lib_factopinion", "lib_notes" } },
  magister = { id = "magister", nodes = { "lib_sources", "lib_citing", "lib_compare", "lib_tables", "lib_skim" } },
}
LB.NODES = {}
for id, fn in pairs(gen) do LB.NODES[id] = { key = "LIB_NODE_" .. id:sub(5):upper(), gen = fn } end
LB.GEN = gen

LB.LISTS = {
  lib_keywords_young = { D.KEYWORDS_YOUNG }, lib_truesilly = { D.TRUESILLY }, lib_factopinion = { D.FACTOPINION },
  lib_notes = { D.NOTES }, lib_sources = { D.SOURCES }, lib_citing = { D.CITE }, lib_skim = { D.SKIM },
}

LB.MODULE = ns.Modules.Register({
  id = LB.MODULE_ID,
  nameKey = "MOD_LIBRARIAN", descKey = "MOD_LIBRARIAN_DESC",
  icon = "Interface\\Icons\\INV_Misc_Book_01",
  startSound = "page",
  loreKey = "LIB_LORE", titleKey = "LIB_TITLE",
  placementKey = "LIB_TRIAL", examKey = "LIB_EXAM",
  placementLoreKey = "LIB_TRIAL_LORE", examLoreKey = "LIB_EXAM_LORE",
  placementResultKey = "LIB_TRIAL_RESULT", examPassKey = "LIB_EXAM_PASS",
  trialRightKey = "LIB_TRIAL_RIGHT", trialWrongKey = "LIB_TRIAL_WRONG",
  bands = LB.BANDS, nodes = LB.NODES,
  choiceOnlyBands = { initiate = true },
  check = LB.Check,
  textAnswers = true,
  game = { key = "LIB_PASSPORT_LINK", tileKey = "LIB_PASSPORT_TILE", tipKey = "LIB_PASSPORT_TIP", view = "journal" },
  guideEvents = { ROUNDSTART = { "LIBSTART", every = 1 }, CORRECT = { "LIBCORRECT", every = 3 }, WRONG = { "LIBWRONG", every = 3 } },
})

ns.Journal.RegisterBook({
  moduleId = LB.MODULE_ID, items = D.STAMPS, prefix = "PASSPORT",
  openEvent = "LIBPASSPORT", newEvent = "LIBSTAMP", sound = "stamp",
})

-- World Tongues (v1.1): the Steamwheedle Tongues Exchange in Gadgetzan, where Fizzwick's
-- goblin traders learn the languages of every land they sell to. Real-world languages,
-- data-driven: every course in ns.TonguesData.courses becomes one module (Japanese first,
-- a small Spanish starter). Each lesson is one skill with the usual Spark/Rune/Glyph tiers,
-- 85% mastery and spaced review. Courses are unbanded (one course for every age); the
-- player's age band only changes the answer style:
--   Initiate (5-7)  3 big buttons, romaji shown under kana in the explanation
--   Adept (8-10)    4 buttons; typed romaji on Glyph
--   Magister (11-13 and grown-up learners) 4 buttons on Spark, typed romaji from Rune on
-- Question types: kana -> romaji, romaji -> kana, meaning -> word, word -> meaning,
-- fill in the blank (X wa Y desu), matching (three pairs at once). No audio is needed.
-- Pure Lua (no WoW API). All Japanese text is drawn with the bundled course font.
local _, ns = ...
local Util = ns.Util
local D = ns.TonguesData
local random = Util.Random

local WT = {}
ns.Tongues = WT

WT.SEP = " \194\183 " -- " · " between matched answers

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end

------------------------------------------------------------------------
-- Answer checking (pure, unit-tested)
------------------------------------------------------------------------
-- lowercase, macrons -> double vowels, drop spaces/punctuation
function WT.Normalize(s)
  s = tostring(s or ""):lower()
  s = s:gsub("\197\141", "ou"):gsub("\197\171", "uu"):gsub("\196\129", "aa"):gsub("\196\147", "ee"):gsub("\196\171", "ii")
  s = s:gsub("[%s%-'%.,!%?]", "")
  return s
end

-- A looser key: "ou"/"oo" -> "o", "uu" -> "u" (accepts tokyo, toukyou, tookyoo alike)
function WT.Loose(s)
  s = WT.Normalize(s)
  s = s:gsub("ou", "o"):gsub("oo", "o"):gsub("uu", "u")
  return s
end

function WT.Check(p, given)
  if p.mode == "choice" then return tostring(given) == tostring(p.answer) end
  local g = WT.Normalize(given)
  if g == "" then return false end
  if g == WT.Normalize(p.answer) or WT.Loose(given) == WT.Loose(p.answer) then return true end
  if p.native and g == WT.Normalize(p.native) then return true end -- typed with a Japanese IME
  for _, alt in ipairs(p.alts or {}) do if g == WT.Normalize(alt) then return true end end
  return false
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function band()
  local P = ns.Progress
  return (P and P.char and P.GetBand and P.GetBand()) or "adept"
end
function WT.Buttons() return band() == "initiate" and 3 or 4 end

-- Pool grows with the level: 10 / 20 / 30 entries, then the whole lesson.
function WT.Pool(entries, level)
  local n = ({ 10, 20, 30 })[level or 5] or #entries
  if #entries <= n then return entries end
  local out = {}
  for i = 1, n do out[i] = entries[i] end
  return out
end

-- Can `e` be asked "reading -> native"? Not when another entry shares the reading (じ / ぢ).
function WT.Unique(entries, e, field)
  for _, o in ipairs(entries) do
    if o ~= e and o[field] == e[field] then return false end
  end
  return true
end

-- up to n-1 wrong answers from the same lesson: field differs from the target's (and from
-- anything that shares the target's reading, so no second correct button)
function WT.Distractors(pool, e, field, n, entries)
  local out, seen = {}, { [e[field]] = true }
  local cand = {}
  for _, o in ipairs(pool) do cand[#cand + 1] = o end
  if #cand < n + 2 and entries then for _, o in ipairs(entries) do cand[#cand + 1] = o end end
  Util.Shuffle(cand)
  for _, o in ipairs(cand) do
    if #out >= n - 1 then break end
    if o ~= e and not seen[o[field]] and o[2] ~= e[2] and (e[3] == nil or o[3] ~= e[3]) then
      seen[o[field]] = true
      out[#out + 1] = o[field]
    end
  end
  return out
end

local function choices(answer, wrong) return ns.Modules.TextChoices(answer, wrong, #wrong + 1) end

local function entryOf(lesson, level)
  local pool = WT.Pool(lesson.entries, level)
  return pool[random(1, #pool)], pool
end

local function explain(e)
  if e[3] then return fmt("WT_E_IS", e[1], e[2], e[3]) end
  return fmt("WT_E_KANA", e[1], e[2])
end
WT.Explain = explain

------------------------------------------------------------------------
-- Question builders (each returns a problem table)
------------------------------------------------------------------------
local Q = {}
WT.Q = Q

-- kana / kanji / word -> romaji (typeable on higher tiers)
function Q.toReading(lesson, e, pool)
  local n = WT.Buttons()
  return { text = fmt("WT_Q_READ", e[1]), answer = e[2], native = e[1],
    distractors = WT.Distractors(pool, e, 2, n, lesson.entries), maxChoices = n,
    hint = L().WT_H_READ, explain = explain(e), kind = "toReading" }
end

-- romaji -> native (buttons)
function Q.toNative(lesson, e, pool)
  local wrong = WT.Distractors(pool, e, 1, WT.Buttons(), lesson.entries)
  return { text = fmt("WT_Q_WRITE", e[2]), answer = e[1], choices = choices(e[1], wrong),
    hint = L().WT_H_WRITE, explain = explain(e), kind = "toNative" }
end

-- English meaning -> native word
function Q.meaningToWord(lesson, e, pool)
  local wrong = WT.Distractors(pool, e, 1, WT.Buttons(), lesson.entries)
  return { text = fmt("WT_Q_SAY", e[3]), answer = e[1], choices = choices(e[1], wrong),
    hint = L().WT_H_MEANING, explain = explain(e), kind = "meaningToWord" }
end

-- native word -> English meaning
function Q.wordToMeaning(lesson, e, pool)
  local wrong = WT.Distractors(pool, e, 3, WT.Buttons(), lesson.entries)
  return { text = fmt("WT_Q_MEANS", e[1], e[2]), answer = e[3], choices = choices(e[3], wrong),
    hint = L().WT_H_MEANING, explain = explain(e), kind = "wordToMeaning" }
end

-- three pairs at once: pick the right order of readings (or meanings for kanji)
function Q.matching(lesson, e, pool)
  local field = lesson.kind == "kanji" and 3 or 2
  local picked, used = { e }, { [e[field]] = true, [e[1]] = true }
  local cand = {}
  for _, o in ipairs(pool) do cand[#cand + 1] = o end
  Util.Shuffle(cand)
  for _, o in ipairs(cand) do
    if #picked >= 3 then break end
    if not used[o[field]] and not used[o[1]] then used[o[field]], used[o[1]] = true, true; picked[#picked + 1] = o end
  end
  if #picked < 3 then return Q.toReading(lesson, e, pool) end
  local natives, answers = {}, {}
  for i, o in ipairs(picked) do natives[i], answers[i] = o[1], o[field] end
  local a = answers
  local function seq(i, j, k) return a[i] .. WT.SEP .. a[j] .. WT.SEP .. a[k] end
  local right = seq(1, 2, 3)
  local wrong = { seq(2, 1, 3), seq(1, 3, 2), seq(3, 2, 1), seq(2, 3, 1) }
  Util.Shuffle(wrong)
  local n = WT.Buttons()
  local list = {}
  for i = 1, n - 1 do list[i] = wrong[i] end
  local parts = {}
  for i, o in ipairs(picked) do parts[i] = explain(o) end
  return { text = fmt(field == 3 and "WT_Q_MATCH_MEANING" or "WT_Q_MATCH", table.concat(natives, "   ")),
    answer = right, choices = choices(right, list), hint = L().WT_H_MATCH,
    explain = table.concat(parts, "\n"), kind = "matching" }
end

-- numbers: digits -> word, word -> digits (typeable)
function Q.number(lesson, level)
  local top = ({ 10, 20, 50 })[level] or 100
  local v = random(1, top)
  local e = D.Number(v)
  if random(1, 2) == 1 then
    local wrongs, seen = {}, { [v] = true }
    local n = WT.Buttons()
    local guard = 0
    while #wrongs < n - 1 and guard < 50 do
      guard = guard + 1
      local w = Util.Clamp(v + random(-12, 12), 1, 100)
      if not seen[w] then seen[w] = true; wrongs[#wrongs + 1] = D.Number(w)[1] end
    end
    return { text = fmt("WT_Q_NUMBER_SAY", v), answer = e[1], choices = choices(e[1], wrongs),
      hint = L().WT_H_NUMBER, explain = explain(e), kind = "numberToWord" }
  end
  return { text = fmt("WT_Q_NUMBER_READ", e[1], e[2]), answer = v, maxChoice = 100, minChoice = 1,
    hint = L().WT_H_NUMBER, explain = explain(e), kind = "wordToNumber" }
end

-- Japanese sentence pattern X wa Y desu. Built from parts so every sentence is correct.
WT.SUBJECTS = {
  { "わたし", "watashi", "I", people = true },
  { "これ", "kore", "this" },
  { "それ", "sore", "that (near you)" },
  { "あれ", "are", "that (over there)" },
}
WT.NOUNS = {
  { "がくせい", "gakusei", "a student", people = true },
  { "せんせい", "sensei", "a teacher", people = true },
  { "いしゃ", "isha", "a doctor", people = true },
  { "こども", "kodomo", "a child", people = true },
  { "ほん", "hon", "a book" }, { "みず", "mizu", "water" }, { "ねこ", "neko", "a cat" },
  { "いぬ", "inu", "a dog" }, { "りんご", "ringo", "an apple" }, { "やま", "yama", "a mountain" },
}
function WT.Sentence(subj, noun)
  return { subj[1] .. "は" .. noun[1] .. "です", subj[2] .. " wa " .. noun[2] .. " desu",
    subj[3] .. " " .. (subj[1] == "わたし" and "am" or "is") .. " " .. noun[3] }
end
function Q.sentence(lesson, level)
  local subj = WT.SUBJECTS[random(1, #WT.SUBJECTS)]
  local nouns = {}
  for _, nn in ipairs(WT.NOUNS) do if (nn.people or false) == (subj.people or false) then nouns[#nouns + 1] = nn end end
  local noun = nouns[random(1, #nouns)]
  local s = WT.Sentence(subj, noun)
  local kind = random(1, level <= 2 and 2 or 3)
  if kind == 1 then -- fill the noun
    local wrong, seen = {}, { [noun[1]] = true }
    for _, o in ipairs(Util.Shuffle({ unpack(WT.NOUNS) })) do
      if #wrong < WT.Buttons() - 1 and not seen[o[1]] then seen[o[1]] = true; wrong[#wrong + 1] = o[1] end
    end
    return { text = fmt("WT_Q_BLANK", subj[1] .. "は ＿＿ です", s[3]), answer = noun[1], choices = choices(noun[1], wrong),
      hint = L().WT_H_SENTENCE, explain = fmt("WT_E_IS", s[1], s[2], s[3]), kind = "blank" }
  elseif kind == 2 then -- fill the particle: は is read "wa" when it marks the topic
    local wrong = { "を", "の", "が" }
    local n = WT.Buttons()
    local list = {}
    for i = 1, n - 1 do list[i] = wrong[i] end
    return { text = fmt("WT_Q_BLANK", subj[1] .. " ＿ " .. noun[1] .. "です", s[3]), answer = "は", choices = choices("は", list),
      hint = L().WT_H_PARTICLE, explain = fmt("WT_E_PARTICLE", s[1], s[2]), kind = "particle" }
  end
  -- meaning -> whole sentence
  local wrong, seen = {}, { [s[1]] = true }
  for _, o in ipairs(Util.Shuffle({ unpack(nouns) })) do
    local w = WT.Sentence(subj, o)[1]
    if #wrong < WT.Buttons() - 1 and not seen[w] then seen[w] = true; wrong[#wrong + 1] = w end
  end
  for _, o in ipairs(Util.Shuffle({ unpack(WT.SUBJECTS) })) do
    local w = WT.Sentence(o, noun)[1]
    if #wrong < WT.Buttons() - 1 and not seen[w] and (o.people or false) == (subj.people or false) then seen[w] = true; wrong[#wrong + 1] = w end
  end
  return { text = fmt("WT_Q_SAY", s[3]), answer = s[1], choices = choices(s[1], wrong),
    hint = L().WT_H_SENTENCE, explain = fmt("WT_E_IS", s[1], s[2], s[3]), kind = "sentence" }
end

------------------------------------------------------------------------
-- One generator per lesson
------------------------------------------------------------------------
function WT.Generate(lesson, level)
  level = level or 1
  if lesson.kind == "numbers" then return Q.number(lesson, level) end
  if lesson.kind == "sentences" then return Q.sentence(lesson, level) end
  local e, pool = entryOf(lesson, level)
  local types
  if lesson.kind == "kana" then
    types = level >= 4 and { "toReading", "toNative", "matching", "toReading" } or (level >= 2 and { "toReading", "toNative" } or { "toReading" })
  elseif lesson.kind == "kanji" then
    types = level >= 3 and { "wordToMeaning", "meaningToWord", "toReading", "matching" } or { "wordToMeaning", "meaningToWord" }
  else
    types = level >= 3 and { "wordToMeaning", "meaningToWord", "toReading", "toNative" } or { "wordToMeaning", "meaningToWord" }
  end
  local t = types[random(1, #types)]
  if t == "toNative" and not WT.Unique(lesson.entries, e, 2) then t = "toReading" end
  if t == "meaningToWord" and not WT.Unique(lesson.entries, e, 3) then t = "wordToMeaning" end
  return Q[t](lesson, e, pool)
end

-- Typed answers: Magister from Rune, Adept on Glyph, and every trial; buttons otherwise.
function WT.InputMode(node, tier, purpose)
  local b = band()
  if b == "initiate" then return "choice", 3 end
  if b == "magister" and (tier or 1) >= 2 then return "input" end
  if (tier or 1) >= 3 then return "input" end
  return "choice", 4
end

------------------------------------------------------------------------
-- Registry: one module per course (World Tongues tile = the first course)
------------------------------------------------------------------------
WT.MODULES = {}
WT.LESSON_BY_NODE = {}
for ci, cid in ipairs(D.order) do
  local course = D.courses[cid]
  local nodes, list = {}, {}
  for _, lesson in ipairs(course.lessons) do
    local nodeId = "wt_" .. cid .. "_" .. lesson.id
    local key = "WT_NODE_" .. cid:upper() .. "_" .. lesson.id:upper()
    nodes[nodeId] = { key = key, descKey = key .. "_DESC", icon = course.icon,
      gen = function(level) return WT.Generate(lesson, level) end }
    WT.LESSON_BY_NODE[nodeId] = lesson
    list[#list + 1] = nodeId
  end
  local nextId = D.order[ci % #D.order + 1]
  local id = "tongues_" .. cid
  WT.MODULES[#WT.MODULES + 1] = ns.Modules.Register({
    id = id, area = "tongues", areaKey = "MOD_TONGUES",
    nameKey = ci == 1 and "MOD_TONGUES" or ("WT_COURSE_" .. cid:upper()),
    descKey = ci == 1 and "MOD_TONGUES_DESC" or ("WT_COURSE_" .. cid:upper() .. "_DESC"),
    icon = ci == 1 and "Interface\\Icons\\INV_Misc_Note_06" or "Interface\\Icons\\INV_Letter_06",
    startSound = "page",
    loreKey = "WT_LORE_" .. cid:upper(), titleKey = "WT_TITLE_" .. cid:upper(),
    bands = { everyone = { id = "everyone", nodes = list } }, nodes = nodes,
    unbanded = true, noTrials = true, hidden = ci > 1,
    courseFont = true, -- UI: draw question, buttons and feedback with ns.Compat.CourseFont()
    check = WT.Check, inputMode = WT.InputMode,
    textAnswers = true, pageSize = 5,
    linkModule = "tongues_" .. nextId, linkKey = "WT_SWITCH_" .. nextId:upper(),
    course = cid,
  })
end

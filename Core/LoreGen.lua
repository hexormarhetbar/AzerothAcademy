-- Lore Chronicles: reading comprehension + writing (module #3), hosted by Chronicler
-- Zixi Inkspark in Gadgetzan's Story Vault. Plus the optional unbanded
-- "Lore Quiz for Everyone" track (module "lorequiz", no trials, reached from the
-- Lore Chronicles skill list or /aa quiz).
local _, ns = ...
local Util = ns.Util
local D = ns.LoreData
local random, abs = Util.Random, math.abs

local LC = {}
ns.Lore = LC

LC.MAX_TEXT = 480     -- tests keep every generated problem readable in the problem view
LC.MAX_CHOICE = 80
LC.MIN_WORDS = 3      -- written answers need at least a short sentence

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end

------------------------------------------------------------------------
-- Text helpers (pure, unit-tested)
------------------------------------------------------------------------
-- lowercase, punctuation -> spaces (apostrophes dropped), spaces collapsed
function LC.Normalize(s)
  s = tostring(s or ""):lower()
  s = s:gsub("'", ""):gsub("[^%w]+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function LC.Words(s)
  local out = {}
  for w in LC.Normalize(s):gmatch("%S+") do out[#out + 1] = w end
  return out
end

-- Keyword rubric: each group counts once if any keyword is present.
--   multi-word keyword -> substring of the normalized answer
--   keyword of 4+ letters -> prefix of a word ("enem" matches "enemies")
--   shorter keyword -> exact word
function LC.KeywordHit(words, joined, kw)
  kw = LC.Normalize(kw)
  if kw:find(" ", 1, true) then return (" " .. joined .. " "):find(" " .. kw .. " ", 1, true) ~= nil end
  for _, w in ipairs(words) do
    if w == kw or (#kw >= 4 and w:sub(1, #kw) == kw) then return true end
  end
  return false
end

-- returns ok, matched, need
function LC.Rubric(text, groups, need)
  local words = LC.Words(text)
  local joined = table.concat(words, " ")
  local matched = 0
  for _, g in ipairs(groups) do
    for _, kw in ipairs(g) do
      if LC.KeywordHit(words, joined, kw) then matched = matched + 1; break end
    end
  end
  need = need or #groups
  return matched >= need and #words >= LC.MIN_WORDS, matched, need
end

function LC.Check(p, given, ctx)
  if p.mode ~= "choice" and p.rubric then
    local okv, matched, need = LC.Rubric(given, p.rubric, p.need)
    return okv, { rubric = true, matched = matched, need = need }
  end
  if p.mode ~= "choice" and p.build then
    local g = LC.Normalize(given)
    if g == "" then return false end
    if g == LC.Normalize(p.answer) then return true end
    for _, alt in ipairs(p.alts or {}) do if g == LC.Normalize(alt) then return true end end
    return false
  end
  return tostring(given) == tostring(p.answer)
end

-- generator level 1..5 -> data level 1..3
function LC.LevelFor(level)
  level = tonumber(level) or 1
  if level <= 2 then return 1 elseif level == 3 then return 2 end
  return 3
end

-- entries at the wanted lv, or the nearest lv that has any
function LC.Pool(list, level)
  local want = LC.LevelFor(level)
  for dist = 0, 2 do
    local out = {}
    for _, e in ipairs(list) do if abs((e.lv or 1) - want) == dist then out[#out + 1] = e end end
    if #out > 0 then return out end
  end
  return list
end

-- Shuffle bags: every passage of a pool is seen before any repeats.
LC.bags = {}
function LC.Draw(bagKey, list, level)
  local pool = LC.Pool(list, level)
  local key = bagKey .. ":" .. LC.LevelFor(level)
  local bag = LC.bags[key]
  if not bag or bag.pos > #bag.order or bag.size ~= #pool then
    local order = {}
    for i = 1, #pool do order[i] = i end
    bag = { order = Util.Shuffle(order), pos = 1, size = #pool }
    LC.bags[key] = bag
  end
  local e = pool[bag.order[bag.pos]]
  bag.pos = bag.pos + 1
  LC.lastEntry = e
  return e
end

local function choices(answer, distractors, n)
  return ns.Modules.TextChoices(answer, distractors, n)
end

local function block(passage, question) return passage .. "\n\n" .. question end

-- word tiles: the words of a sentence (final punctuation removed)
function LC.Tiles(s)
  local out = {}
  for w in tostring(s):gsub("[%.!%?]$", ""):gmatch("%S+") do out[#out + 1] = w end
  return out
end

local function joinSentence(words) return table.concat(words, " ") .. "." end

-- wrong word orders that keep the first and last word in place
function LC.ScrambledOrders(s, n)
  local words = LC.Tiles(s)
  local out, seen = {}, { [LC.Normalize(s)] = true }
  for _ = 1, 60 do
    if #out >= n then break end
    local w = { unpack(words) }
    if random() < 0.5 and #w >= 4 then
      local i = random(2, #w - 2) -- swap two neighbours in the middle
      w[i], w[i + 1] = w[i + 1], w[i]
    else
      local mid = {}
      for i = 2, #w - 1 do mid[#mid + 1] = w[i] end
      mid = Util.Shuffle(mid)
      for i = 2, #w - 1 do w[i] = mid[i - 1] end
    end
    local cand = joinSentence(w)
    local k = LC.Normalize(cand)
    if not seen[k] then seen[k] = true; out[#out + 1] = cand end
  end
  return out
end

-- shuffled tiles, never in the right order
function LC.ShuffledTiles(s)
  local words = LC.Tiles(s)
  local t
  for _ = 1, 20 do
    t = Util.Shuffle({ unpack(words) })
    if table.concat(t, " ") ~= table.concat(words, " ") then break end
  end
  local shown = {}
  for i, w in ipairs(t) do shown[i] = "[" .. w .. "]" end
  return table.concat(shown, " "), t
end

------------------------------------------------------------------------
-- Generators. Problem fields: text, answer, hint, explain, choices (preset buttons)
-- or distractors + chooseText (buttons on Spark, typed on Rune/Glyph), plus
-- build/rubric/need/wide for typed answers.
------------------------------------------------------------------------
local gen = {}

-- INITIATE (ages 5-7): always 3 big buttons
function gen.lc_sentence(level)
  local e = LC.Draw("sentence", D.SENTENCES, level)
  return { text = block(e.s, e.q), answer = e.a, choices = choices(e.a, e.d, 3),
    hint = L().LC_H_SENTENCE, explain = fmt("LC_E_FOUND", e.a), passage = e.s }
end

function gen.lc_sequence(level)
  local e = LC.Draw("sequence", D.SEQUENCES, level)
  local s = e.steps
  local passage = table.concat(s, " ")
  local kind = random(1, LC.LevelFor(level) >= 3 and 3 or 2)
  local q, a, d
  if kind == 1 then q, a, d = L().LC_Q_FIRST, s[1], { s[2], s[3] }
  elseif kind == 2 then q, a, d = L().LC_Q_LAST, s[3], { s[1], s[2] }
  else q, a, d = fmt("LC_Q_AFTER", s[1]), s[2], { s[3], s[1] } end
  return { text = block(passage, q), answer = a, choices = choices(a, d, 3),
    hint = L().LC_H_SEQUENCE, explain = fmt("LC_E_SEQ", s[1], s[2], s[3]), passage = passage }
end

local function storyNode(field, hintKey)
  return function(level)
    local e = LC.Draw("story_" .. field, D.STORIES, level)
    local q = e[field]
    return { text = block(e.text, q[1]), answer = q[2], choices = choices(q[2], q[3], 3),
      hint = L()[hintKey], explain = fmt("LC_E_FOUND", q[2]), passage = e.text }
  end
end
gen.lc_who = storyNode("who", "LC_H_WHO")
gen.lc_what = storyNode("what", "LC_H_WHAT")
gen.lc_where = storyNode("where", "LC_H_WHERE")

-- ADEPT (ages 8-10)
function gen.lc_main_idea(level)
  local e = LC.Draw("main", D.PASSAGES_A, level)
  return { text = block(e.text, L().LC_Q_MAIN), answer = e.main[1], choices = choices(e.main[1], e.main[2], 4),
    hint = L().LC_H_MAIN, explain = fmt("LC_E_MAIN", e.main[1]), passage = e.text }
end

function gen.lc_feelings(level)
  local e = LC.Draw("feel", D.PASSAGES_A, level)
  local f = e.feel
  return { text = block(e.text, f[1]), answer = f[2], choices = choices(f[2], f[3], 4),
    hint = L().LC_H_FEEL, explain = fmt("LC_E_CLUE", f[2]), passage = e.text }
end

function gen.lc_cause(level)
  local e = LC.Draw("cause", D.PASSAGES_A, level)
  local c = e.cause
  return { text = block(e.text, c[1]), answer = c[2], choices = choices(c[2], c[3], 4),
    hint = L().LC_H_CAUSE, explain = fmt("LC_E_CAUSE", c[2]), passage = e.text }
end

function gen.lc_vocab(level)
  local e = LC.Draw("vocab", D.PASSAGES_A, level)
  local v = e.vocab
  return { text = block(e.text, fmt("LC_Q_VOCAB", v[1])), answer = v[2], choices = choices(v[2], v[3], 4),
    hint = L().LC_H_VOCAB, explain = fmt("LC_E_VOCAB", v[1], v[2]), passage = e.text, word = v[1] }
end

function gen.lc_build(level)
  local e = LC.Draw("build", D.BUILD, level)
  local shown = LC.ShuffledTiles(e.s)
  return { text = fmt("LC_Q_BUILD", shown), chooseText = fmt("LC_Q_BUILD_CHOOSE", shown),
    answer = e.s, distractors = LC.ScrambledOrders(e.s, 3), build = true, wide = true,
    hint = L().LC_H_BUILD, explain = fmt("LC_E_BUILD", e.s) }
end

-- MAGISTER (ages 11-13)
function gen.lc_inference(level)
  local e = LC.Draw("infer", D.PASSAGES_M, level)
  local f = e.infer
  return { text = block(e.text, f[1]), answer = f[2], choices = choices(f[2], f[3], 4),
    hint = L().LC_H_INFER, explain = fmt("LC_E_INFER", f[2]), passage = e.text }
end

function gen.lc_compare(level)
  local e = LC.Draw("compare", D.COMPARE, level)
  local q = e.qs[random(1, #e.qs)]
  local first, second = e.horde, e.alliance
  if random() < 0.5 then first, second = second, first end -- neither side always goes first
  local passage = fmt("LC_COMPARE_HEAD", e.place) .. "\n" .. first .. "\n" .. second
  return { text = block(passage, q[1]), answer = q[2], choices = choices(q[2], q[3], 4),
    hint = L().LC_H_COMPARE, explain = fmt("LC_E_COMPARE", q[2]), passage = passage }
end

function gen.lc_bigpicture(level)
  local e = LC.Draw("big", D.PASSAGES_M, level)
  if random() < 0.5 then
    return { text = block(e.text, L().LC_Q_PURPOSE), answer = e.purpose[1], choices = choices(e.purpose[1], e.purpose[2], 4),
      hint = L().LC_H_PURPOSE, explain = fmt("LC_E_PURPOSE", e.purpose[1]), passage = e.text }
  end
  return { text = block(e.text, L().LC_Q_SUMMARY), answer = e.summary[1], choices = choices(e.summary[1], e.summary[2], 4),
    hint = L().LC_H_SUMMARY, explain = fmt("LC_E_SUMMARY", e.summary[1]), passage = e.text }
end

function gen.lc_grammar(level)
  local e = LC.Draw("grammar", D.GRAMMAR, level)
  return { text = L().LC_Q_GRAMMAR, answer = e.a, choices = choices(e.a, e.d, 4),
    hint = L().LC_H_GRAMMAR, explain = e.why }
end

function gen.lc_written(level)
  local e = LC.Draw("write", D.WRITE, level)
  return { text = block(e.text, e.q) .. "\n" .. L().LC_Q_WRITE_TIP, chooseText = block(e.text, e.q),
    answer = e.model, distractors = e.d, rubric = e.rubric, need = e.need, wide = true,
    hint = L().LC_H_WRITTEN, explain = fmt("LC_E_WRITE", e.model), passage = e.text }
end

------------------------------------------------------------------------
-- Lore Quiz for Everyone (unbanded, always 4 buttons)
------------------------------------------------------------------------
local quizGen = {}
for id in pairs(D.QUIZ) do
  quizGen[id] = function(level)
    local e = LC.Draw(id, D.QUIZ[id], level)
    return { text = e.q, answer = e.a, choices = choices(e.a, e.d, 4),
      hint = L().LQ_HINT, explain = fmt("LQ_E", e.a) }
  end
end

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
LC.BANDS = {
  initiate = { id = "initiate", nodes = { "lc_sentence", "lc_sequence", "lc_who", "lc_what", "lc_where" } },
  adept    = { id = "adept",    nodes = { "lc_main_idea", "lc_feelings", "lc_cause", "lc_vocab", "lc_build" } },
  magister = { id = "magister", nodes = { "lc_inference", "lc_compare", "lc_bigpicture", "lc_grammar", "lc_written" } },
}
-- v0.14: cameo stories (Thrall / Magni) tag their problems so Fizzwick can introduce them
for id, fn in pairs(gen) do
  gen[id] = function(level)
    LC.lastEntry = nil
    local p = fn(level)
    p.cameo = LC.lastEntry and LC.lastEntry.cameo or nil
    return p
  end
end
LC.CAMEOS = { thrall = "LORE_CAMEO_THRALL", magni = "LORE_CAMEO_MAGNI" }
LC.NODES = {}
for id, fn in pairs(gen) do LC.NODES[id] = { key = "LC_NODE_" .. id:sub(4):upper(), gen = fn } end
LC.GEN = gen

LC.MODULE = ns.Modules.Register({
  id = "lore",
  nameKey = "MOD_LORE", descKey = "MOD_LORE_DESC",
  icon = "Interface\\Icons\\INV_Misc_Book_09",
  startSound = "scroll",
  loreKey = "LORE_LORE", titleKey = "LORE_TITLE",
  placementKey = "LORE_TRIAL", examKey = "LORE_EXAM",
  placementLoreKey = "LORE_TRIAL_LORE", examLoreKey = "LORE_EXAM_LORE",
  placementResultKey = "LORE_TRIAL_RESULT", examPassKey = "LORE_EXAM_PASS",
  trialRightKey = "LORE_TRIAL_RIGHT", trialWrongKey = "LORE_TRIAL_WRONG",
  bands = LC.BANDS, nodes = LC.NODES,
  choiceOnlyBands = { initiate = true },
  check = LC.Check,
  textAnswers = true,
  linkModule = "lorequiz", linkKey = "LORE_QUIZ_LINK",
})

LC.QUIZ_BANDS = { everyone = { id = "everyone", nodes = { "lq_horde", "lq_alliance", "lq_neutral", "lq_places", "lq_legends" } } }
LC.QUIZ_NODES = {}
for id, fn in pairs(quizGen) do LC.QUIZ_NODES[id] = { key = "LQ_NODE_" .. id:sub(4):upper(), gen = fn } end
LC.QUIZ_GEN = quizGen

LC.QUIZ_MODULE = ns.Modules.Register({
  id = "lorequiz",
  area = "lore", -- v1.1: hidden or shown together with Lore Chronicles
  nameKey = "MOD_LOREQUIZ", descKey = "MOD_LOREQUIZ_DESC",
  icon = "Interface\\Icons\\INV_Misc_Book_11",
  startSound = "scroll",
  loreKey = "LQ_LORE", titleKey = "LQ_TITLE",
  bands = LC.QUIZ_BANDS, nodes = LC.QUIZ_NODES,
  unbanded = true, noTrials = true, hidden = true,
  check = LC.Check,
  textAnswers = true,
  linkModule = "lore", linkKey = "LQ_BACK",
})

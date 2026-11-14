-- Scribe's Scrolls: spelling, vocabulary and typing. Registered as module #2.
-- Spelling works without audio: scrambled letters, fill-the-missing-letters,
-- choose-the-correct-spelling and definition -> spell prompts.
local _, ns = ...
local Util = ns.Util
local D = ns.ScribeData
local random, floor, max, min, abs = Util.Random, math.floor, math.max, math.min, math.abs

local SC = {}
ns.Scribe = SC

-- Typing: first-try pass mark by tier (accuracy after whitespace clean-up).
SC.TYPING_PASS = { 0.85, 0.90, 0.95 }
SC.MAX_WPM = 200

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end

------------------------------------------------------------------------
-- Text helpers (pure, unit-tested)
------------------------------------------------------------------------
function SC.Clean(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return s
end

-- Case/whitespace tolerant; ignores surrounding quotes and a trailing . ! or ?
-- Letters themselves must match exactly (that IS the spelling test).
function SC.NormalizeWord(s)
  s = SC.Clean(s):lower()
  s = s:gsub('^["\']+', ""):gsub('["\']+$', "")
  s = s:gsub("[%.!%?]+$", "")
  return SC.Clean(s)
end

function SC.Levenshtein(a, b)
  local la, lb = #a, #b
  if la == 0 then return lb end
  if lb == 0 then return la end
  local prev, cur = {}, {}
  for j = 0, lb do prev[j] = j end
  for i = 1, la do
    cur[0] = i
    local ca = a:byte(i)
    for j = 1, lb do
      local cost = (ca == b:byte(j)) and 0 or 1
      cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev, cur = cur, prev
  end
  return prev[lb]
end

-- Accuracy 0..1 = 1 - edits / length of the target.
function SC.TypingAccuracy(target, typed, caseSensitive)
  local t, g = SC.Clean(target), SC.Clean(typed)
  if not caseSensitive then t, g = t:lower(), g:lower() end
  if #t == 0 then return #g == 0 and 1 or 0 end
  return max(0, 1 - SC.Levenshtein(t, g) / #t)
end

-- Words per minute, standard 5 characters per word. elapsed in seconds.
function SC.WPM(target, elapsed)
  local chars = #SC.Clean(target)
  local secs = max(1, tonumber(elapsed) or 0)
  return min(SC.MAX_WPM, floor((chars / 5) / (secs / 60) + 0.5))
end

function SC.Check(p, given, ctx)
  if p.mode == "typing" then
    local tier = (ctx and ctx.tier) or p.tier or 1
    local acc = SC.TypingAccuracy(p.answer, given, tier >= 3)
    local need = SC.TYPING_PASS[Util.Clamp(tier, 1, 3)]
    local info = { accuracy = acc, wpm = SC.WPM(p.answer, ctx and ctx.elapsed), need = need }
    return acc >= need - 1e-9, info
  end
  local g = SC.NormalizeWord(given)
  if g == "" then return false end
  if g == SC.NormalizeWord(p.answer) then return true end
  for _, a in ipairs(p.accept or {}) do
    if g == SC.NormalizeWord(a) then return true end
  end
  return false
end

local function spelled(w) return (w:upper():gsub(".", "%0-"):gsub("%-$", "")) end
SC.Spelled = spelled

-- entries with lv close to the asked level (falls back to the whole list)
local function nearLevel(list, level, spread)
  local out = {}
  for _, e in ipairs(list) do
    if not e.lv or abs(e.lv - level) <= (spread or 1) then out[#out + 1] = e end
  end
  if #out == 0 then return list end
  return out
end

local function swapAdjacent(w)
  if #w < 3 then return w .. w:sub(-1) end
  local i = random(2, #w - 1)
  return w:sub(1, i - 1) .. w:sub(i + 1, i + 1) .. w:sub(i, i) .. w:sub(i + 2)
end

-- Misspellings: curated first, then generated, never equal to the word.
local function misspellings(w, curated, need)
  local out, seen = {}, { [w:lower()] = true }
  for _, b in ipairs(curated or {}) do
    if not seen[b:lower()] then out[#out + 1] = b; seen[b:lower()] = true end
  end
  local guard = 0
  while #out < need and guard < 40 do
    guard = guard + 1
    local cand
    local r = random(1, 3)
    if r == 1 then cand = swapAdjacent(w)
    elseif r == 2 then
      local i = random(2, #w)
      cand = w:sub(1, i) .. w:sub(i, i) .. w:sub(i + 1) -- doubled letter
    else
      local i = random(2, #w)
      cand = w:sub(1, i - 1) .. w:sub(i + 1) -- dropped letter
    end
    if cand ~= "" and not seen[cand:lower()] then out[#out + 1] = cand; seen[cand:lower()] = true end
  end
  return out
end
SC.Misspellings = misspellings

local function scramble(w)
  local letters = {}
  for c in w:gmatch(".") do letters[#letters + 1] = c:upper() end
  for _ = 1, 10 do
    Util.Shuffle(letters)
    if table.concat(letters):lower() ~= w then break end
  end
  return table.concat(letters, " ")
end

local function blanks(w, count)
  local chars = {}
  for c in w:gmatch(".") do chars[#chars + 1] = c end
  local idx = {}
  for i = 2, #chars do idx[#idx + 1] = i end
  Util.Shuffle(idx)
  for k = 1, min(count, #idx) do chars[idx[k]] = "_" end
  return table.concat(chars, " ")
end

------------------------------------------------------------------------
-- Generators: gen(level) -> problem
------------------------------------------------------------------------
local gen = {}

-- INITIATE ------------------------------------------------------------
function gen.sc_letters(level)
  local w = Util.Pick(D.LETTER_WORDS)
  if level >= 5 then
    local e = Util.Pick(D.CVC)
    w = e.w
    local mid = w:sub(2, 2)
    return { text = fmt("SC_Q_MIDDLE", w), answer = mid, hint = L().SC_H_LETTER,
      explain = fmt("SC_E_MIDDLE", spelled(w), mid), distractors = { w:sub(1, 1), w:sub(3, 3), "u", "e", "o" } }
  end
  local last = level >= 3
  local ans = last and w:sub(-1) or w:sub(1, 1)
  local other = last and w:sub(1, 1) or w:sub(-1)
  local pool = { other }
  for _, c in ipairs({ "a", "b", "d", "m", "s", "t", "p", "r", "n" }) do pool[#pool + 1] = c end
  return { text = fmt(last and "SC_Q_LAST" or "SC_Q_FIRST", w), answer = ans, hint = L().SC_H_LETTER,
    explain = fmt(last and "SC_E_LAST" or "SC_E_FIRST", w, ans), distractors = pool }
end

function gen.sc_cvc(level)
  local e = Util.Pick(D.CVC)
  local w = e.w
  local v = w:sub(2, 2)
  if level <= 2 then
    local vowels = {}
    for _, x in ipairs(Util.Shuffle({ "a", "e", "i", "o", "u" })) do if x ~= v then vowels[#vowels + 1] = x end end
    return { text = fmt("SC_Q_CVC_MISSING", w:sub(1, 1) .. " _ " .. w:sub(3, 3), e.def), answer = v,
      hint = L().SC_H_CVC, explain = fmt("SC_E_CVC", w, e.def), distractors = vowels, choiceOnly = true }
  end
  local wrong = {}
  for _, x in ipairs(Util.Shuffle({ "a", "e", "i", "o", "u" })) do
    if x ~= v then wrong[#wrong + 1] = w:sub(1, 1) .. x .. w:sub(3, 3) end
  end
  return { text = fmt("SC_Q_CVC_SPELL", e.def), answer = w, hint = L().SC_H_CVC,
    explain = fmt("SC_E_CVC", w, e.def), distractors = wrong, choiceOnly = true }
end

function gen.sc_sight(level)
  local e = Util.Pick(nearLevel(D.SIGHT, level, 1))
  if level >= 3 then
    return { text = fmt("SC_Q_SIGHT_SENT", e.s), answer = e.w, hint = L().SC_H_SIGHT,
      explain = fmt("SC_E_SPELL", spelled(e.w)), distractors = misspellings(e.w, e.bad, 3), choiceOnly = true }
  end
  return { text = L().SC_Q_SIGHT, answer = e.w, hint = L().SC_H_SIGHT,
    explain = fmt("SC_E_SPELL", spelled(e.w)), distractors = misspellings(e.w, e.bad, 3), choiceOnly = true }
end

local function meaningDistractors(list, e, field)
  local out = {}
  for _, o in ipairs(Util.Shuffle({ unpack(list) })) do
    if o ~= e and (e.grp == nil or o.grp ~= e.grp) and o.def ~= e.def then out[#out + 1] = o[field] end
  end
  return out
end
SC.MeaningDistractors = meaningDistractors

function gen.sc_meaning(level)
  local e = Util.Pick(nearLevel(D.MEANINGS, level, 1))
  if level >= 4 then
    return { text = fmt("SC_Q_MEANING_REV", e.def), answer = e.w, hint = L().SC_H_MEANING,
      explain = fmt("SC_E_MEANING", e.w, e.def), distractors = meaningDistractors(D.MEANINGS, e, "w"), choiceOnly = true }
  end
  return { text = fmt("SC_Q_MEANING", e.w), answer = e.def, hint = L().SC_H_MEANING,
    explain = fmt("SC_E_MEANING", e.w, e.def), distractors = meaningDistractors(D.MEANINGS, e, "def"), choiceOnly = true }
end

local function typing(list, level)
  local lv = Util.Clamp(level, 1, 5)
  local s = Util.Pick(list[lv])
  return { text = fmt("SC_Q_TYPE", s), answer = s, hint = L().SC_H_TYPE, explain = fmt("SC_E_TYPE", s),
    forceMode = "typing", typingTarget = s }
end
function gen.sc_type_words(level) return typing(D.TYPE_WORDS, level) end

-- ADEPT ---------------------------------------------------------------
local PLURAL_RULE = { s = "SC_RULE_S", es = "SC_RULE_ES", ies = "SC_RULE_IES", ves = "SC_RULE_VES", irregular = "SC_RULE_IRR" }
local PLURAL_LEVEL = { s = 3, es = 3, ies = 4, ves = 5, irregular = 5 }

function gen.sc_patterns(level)
  local kind
  if level <= 1 then kind = "silent"
  elseif level == 2 then kind = (random() < 0.5) and "silent" or "digraph"
  elseif level == 3 then kind = (random() < 0.5) and "digraph" or "plural"
  else kind = (random() < 0.3) and "digraph" or "plural" end
  if kind == "silent" then
    local e = Util.Pick(D.SILENT_E)
    local b = e.base
    local wrong = { b .. "ee", b .. b:sub(-1) .. "e", e.w:sub(1, -3) .. e.w:sub(-1) .. e.w:sub(-2, -2) }
    return { text = fmt("SC_Q_SILENTE", b, e.def), answer = e.w, hint = L().SC_H_SILENTE,
      explain = fmt("SC_E_SILENTE", b, e.w, e.def), distractors = wrong }
  elseif kind == "digraph" then
    local e = Util.Pick(D.DIGRAPH)
    local i = e.w:find(e.dg, 1, true)
    local shown = {}
    for k = 1, #e.w do
      local c = e.w:sub(k, k)
      if k == i or k == i + 1 then c = "_" end
      shown[#shown + 1] = c
    end
    return { text = fmt("SC_Q_DIGRAPH", e.def, table.concat(shown, " ")), answer = e.w, hint = L().SC_H_DIGRAPH,
      explain = fmt("SC_E_DIGRAPH", e.w, e.dg, e.def), distractors = e.wrong }
  end
  local pool = {}
  for _, e in ipairs(D.PLURALS) do
    if PLURAL_LEVEL[e.kind] <= max(3, level) and (level < 5 or PLURAL_LEVEL[e.kind] >= 4) then pool[#pool + 1] = e end
  end
  local e = Util.Pick(pool)
  return { text = fmt("SC_Q_PLURAL", e.one), answer = e.w, hint = fmt("SC_H_PLURAL", e.one),
    explain = fmt("SC_E_PLURAL", e.one, e.w, L()[PLURAL_RULE[e.kind]]), distractors = e.wrong }
end

local function contextProblem(list, level)
  local e = Util.Pick(nearLevel(list, level, 1))
  return { text = fmt("SC_Q_CONTEXT", e.s, e.w), answer = e.def, hint = L().SC_H_CONTEXT,
    explain = fmt("SC_E_MEANING", e.w, e.def), distractors = meaningDistractors(list, e, "def"), choiceOnly = true }
end
function gen.sc_context(level) return contextProblem(D.CONTEXT_A, level) end

function SC.RelationDistractors(prompt, answer)
  local C = D.WORD_CLUSTER
  local bad = { [C[prompt] or prompt] = true, [C[answer] or answer] = true }
  local out, seen = {}, {}
  for _, list in ipairs({ D.SYNONYMS, D.ANTONYMS }) do
    for _, e in ipairs(list) do
      for _, w in ipairs({ e.a, e.b }) do
        if not bad[C[w] or w] and not seen[w] then out[#out + 1] = w; seen[w] = true end
      end
    end
  end
  return Util.Shuffle(out)
end

function gen.sc_synonyms(level)
  local anti = random() < 0.5
  local e = Util.Pick(nearLevel(anti and D.ANTONYMS or D.SYNONYMS, level, 1))
  local prompt, answer = e.a, e.b
  if random() < 0.5 then prompt, answer = e.b, e.a end
  return { text = fmt(anti and "SC_Q_ANT" or "SC_Q_SYN", prompt), answer = answer,
    hint = anti and L().SC_H_ANT or L().SC_H_SYN,
    explain = fmt(anti and "SC_E_ANT" or "SC_E_SYN", answer, prompt),
    distractors = SC.RelationDistractors(prompt, answer), choiceOnly = true }
end

local function spellProblem(list, level)
  local e = Util.Pick(nearLevel(list, level, 1))
  local w = e.w
  local text
  if level <= 1 then text = fmt("SC_Q_SCRAMBLE", e.def, scramble(w))
  elseif level == 2 then text = fmt("SC_Q_MISSING", e.def, blanks(w, 1))
  elseif level == 3 then text = fmt("SC_Q_MISSING", e.def, blanks(w, max(2, floor(#w / 3))))
  elseif level == 4 then text = fmt("SC_Q_DEFSPELL", e.def, #w, w:sub(1, 1):upper())
  else text = fmt("SC_Q_DEFSPELL_HARD", e.def, #w) end
  return { text = text, answer = w, hint = L().SC_H_SPELL, explain = fmt("SC_E_SPELL", spelled(w)),
    distractors = misspellings(w, e.bad, 3), chooseText = fmt("SC_Q_CHOOSE", e.def) }
end
function gen.sc_spell_adept(level) return spellProblem(D.SPELL_A, level) end
function gen.sc_type_phrases(level) return typing(D.TYPE_PHRASES, level) end

-- MAGISTER ------------------------------------------------------------
local function affixMeaning(list, keyQ)
  local e = Util.Pick(list)
  local d = {}
  for _, o in ipairs(Util.Shuffle({ unpack(list) })) do if o.m ~= e.m then d[#d + 1] = o.m end end
  local q = keyQ == "SC_Q_ROOT" and fmt(keyQ, e.p, e.ex) or fmt(keyQ, e.ex, e.p)
  return { text = q, answer = e.m, hint = L().SC_H_AFFIX, explain = fmt("SC_E_AFFIX", e.p, e.m, e.ex),
    distractors = d, choiceOnly = true }
end

function gen.sc_affixes(level)
  if level <= 1 then return affixMeaning(D.PREFIXES, "SC_Q_PREFIX") end
  if level == 2 then return affixMeaning(random() < 0.5 and D.SUFFIXES or D.PREFIXES, random() < 0.5 and "SC_Q_SUFFIX" or "SC_Q_PREFIX") end
  if level == 4 and random() < 0.5 then return affixMeaning(D.ROOTS, "SC_Q_ROOT") end
  local pool = {}
  for _, e in ipairs(D.AFFIX_BUILD) do
    if (level >= 5 and e.lv >= 4) or (level < 5 and e.lv <= max(3, level)) then pool[#pool + 1] = e end
  end
  local e = Util.Pick(pool)
  return { text = fmt(e.how == "prefix" and "SC_Q_BUILD_PRE" or "SC_Q_BUILD_SUF", e.base, e.def), answer = e.w,
    hint = L().SC_H_BUILD, explain = fmt("SC_E_BUILD", e.base, e.w, e.def), distractors = misspellings(e.w, e.bad, 3) }
end

function gen.sc_confused(level)
  local e = Util.Pick(D.CONFUSED)
  local d = {}
  for _, c in ipairs(e.c) do if c ~= e.a then d[#d + 1] = c end end
  return { text = fmt("SC_Q_CONFUSED", e.s), answer = e.a, hint = L().SC_H_CONFUSED,
    explain = e.why, distractors = d, choiceOnly = true, maxChoices = #e.c }
end

function gen.sc_vocab(level) return contextProblem(D.CONTEXT_M, level) end
function gen.sc_spell_magister(level) return spellProblem(D.SPELL_M, level) end
function gen.sc_type_sentences(level) return typing(D.TYPE_SENTENCES, level) end

-- Problem fields returned above: text, answer (string), hint, explain,
-- distractors (strings), and optionally choiceOnly (always buttons),
-- forceMode = "typing", chooseText (prompt to use when shown as buttons).

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
SC.BANDS = {
  initiate = { id = "initiate", nodes = { "sc_letters", "sc_cvc", "sc_sight", "sc_meaning", "sc_type_words" } },
  adept    = { id = "adept",    nodes = { "sc_patterns", "sc_context", "sc_synonyms", "sc_spell_adept", "sc_type_phrases" } },
  magister = { id = "magister", nodes = { "sc_affixes", "sc_confused", "sc_vocab", "sc_spell_magister", "sc_type_sentences" } },
}
SC.NODES = {}
for id, fn in pairs(gen) do
  SC.NODES[id] = { key = "SC_NODE_" .. id:sub(4):upper(), gen = fn }
end

SC.MODULE = ns.Modules.Register({
  id = "scribe",
  nameKey = "MOD_SCRIBE", descKey = "MOD_SCRIBE_DESC",
  -- v0.6: a mini-game reached from the skill list and the hub tile
  game = { view = "boarding", key = "BOARD_OPEN", tileKey = "BOARD_TILE", tipKey = "BOARD_TILE_TIP", icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01" },
  icon = "Interface\\Icons\\INV_Scroll_03",
  startSound = "scroll",
  loreKey = "SCRIBE_LORE", titleKey = "SCRIBE_TITLE",
  placementKey = "SCRIBE_TRIAL", examKey = "SCRIBE_EXAM",
  placementLoreKey = "SCRIBE_TRIAL_LORE", examLoreKey = "SCRIBE_EXAM_LORE",
  placementResultKey = "SCRIBE_TRIAL_RESULT", examPassKey = "SCRIBE_EXAM_PASS",
  trialRightKey = "SCRIBE_TRIAL_RIGHT", trialWrongKey = "SCRIBE_TRIAL_WRONG",
  bands = SC.BANDS, nodes = SC.NODES,
  choiceOnlyBands = { initiate = true },
  check = SC.Check,
  textAnswers = true,
})

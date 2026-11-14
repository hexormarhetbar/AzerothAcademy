-- Azeroth Naturalist (module #4, science), hosted by Field Warden Bramble Quickroot at the
-- Knowledge Exchange's greenhouse in Gadgetzan. Generators + registry + the Field Journal.
-- Pure Lua (no WoW API).
--
-- Field Journal (ns.Journal): mastering a Naturalist skill at a tier collects that tier's
-- specimen entry (NaturalistData.SPECIMENS). Entries live account-wide in
-- AzerothAcademyDB.journal (schema 6), so a family shares one journal; Journal.Sync()
-- re-collects anything the current character has mastered (e.g. after a reset of the journal
-- or on a new install with old progress).
local _, ns = ...
local Util = ns.Util
local D = ns.NaturalistData
local random, abs = Util.Random, math.abs

local NA = {}
ns.Naturalist = NA

NA.MAX_TEXT = 480
NA.MAX_CHOICE = 80
NA.MODULE_ID = "naturalist"

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end

------------------------------------------------------------------------
-- Helpers (pure, unit-tested)
------------------------------------------------------------------------
-- lowercase, punctuation -> space, leading article dropped ("A solid" == "solid")
function NA.Normalize(s)
  s = tostring(s or ""):lower()
  s = s:gsub("'", ""):gsub("[^%w]+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("^an? ", ""):gsub("^the ", "")
  return s
end

function NA.Cap(s) return (tostring(s):gsub("^%l", string.upper)) end

-- generator level 1..5 -> data level 1..3
function NA.LevelFor(level)
  level = tonumber(level) or 1
  if level <= 2 then return 1 elseif level == 3 then return 2 end
  return 3
end

-- entries at the wanted lv, or the nearest lv that has any
function NA.Pool(list, level)
  local want = NA.LevelFor(level)
  for dist = 0, 2 do
    local out = {}
    for _, e in ipairs(list) do if abs((e.lv or 1) - want) == dist then out[#out + 1] = e end end
    if #out > 0 then return out end
  end
  return list
end

-- Shuffle bags: every entry of a pool is seen before any repeats.
NA.bags = {}
function NA.Draw(bagKey, list, level)
  local pool = NA.Pool(list, level)
  local key = bagKey .. ":" .. NA.LevelFor(level)
  local bag = NA.bags[key]
  if not bag or bag.pos > #bag.order or bag.size ~= #pool then
    local order = {}
    for i = 1, #pool do order[i] = i end
    bag = { order = Util.Shuffle(order), pos = 1, size = #pool }
    NA.bags[key] = bag
  end
  local e = pool[bag.order[bag.pos]]
  bag.pos = bag.pos + 1
  return e
end

local function pick(t) return t[random(1, #t)] end

local function nButtons(band) return band == "initiate" and 3 or 4 end

local function choices(answer, distractors, n) return ns.Modules.TextChoices(answer, distractors, n) end

-- Typed answers: on Rune/Glyph tiers (and in trials) Adept/Magister type entries that have
-- a short accepted spelling list; everything else is always buttons.
function NA.Check(p, given)
  if p.mode ~= "choice" and p.typed then
    local g = NA.Normalize(given)
    if g == "" then return false end
    if g == NA.Normalize(p.answer) then return true end
    for _, alt in ipairs(p.alts or {}) do if g == NA.Normalize(alt) then return true end end
    return false
  end
  return tostring(given) == tostring(p.answer)
end

-- curated entry -> problem
function NA.FromEntry(e, band, hintKey)
  local p = { text = e.q, answer = e.a, explain = e.why, hint = L()[hintKey] }
  if e.t and band ~= "initiate" then
    p.distractors, p.alts, p.typed = e.d, e.t, true
  else
    p.choices = choices(e.a, e.d, nButtons(band))
  end
  return p
end

local function curated(bagKey, list, band, hintKey)
  return function(level)
    return NA.FromEntry(NA.Draw(bagKey, list, level), band, hintKey)
  end
end

------------------------------------------------------------------------
-- Generators
------------------------------------------------------------------------
local gen = {}

-- INITIATE (ages 5-7): always 3 big buttons --------------------------------
-- habitats too alike to be each other's wrong answer
NA.CLASH = {}
for _, pair in ipairs({ { "snow", "mountain" }, { "forest", "grassland" }, { "forest", "jungle" },
  { "desert", "grassland" }, { "sea", "swamp" } }) do
  local a, b = pair[1], pair[2]
  NA.CLASH[a] = NA.CLASH[a] or {}; NA.CLASH[a][b] = true
  NA.CLASH[b] = NA.CLASH[b] or {}; NA.CLASH[b][a] = true
end
function gen.nat_habitats(level)
  local lv = NA.LevelFor(level)
  local kind = random(1, lv == 1 and 2 or 3)
  local hs = Util.Shuffle({ unpack(D.HABITATS) })
  local h = hs[1]
  -- wrong answers come from clearly different habitats (a ram could live in snow, a deer on a plain)
  local others = {}
  for i = 2, #hs do
    if not (NA.CLASH[h.id] and NA.CLASH[h.id][hs[i].id]) then others[#others + 1] = hs[i] end
  end
  local o1, o2 = others[1], others[2]
  local who = pick(h.life)
  local zone = pick(h.zones)
  local hint = L().NAT_H_HABITATS
  if kind == 1 then
    local function place(x, z) return (z or pick(x.zones)) .. " (" .. x.desc .. ")" end
    local a = place(h, zone)
    return { text = fmt("NAT_Q_HOME", who[1]), answer = a, choices = choices(a, { place(o1), place(o2) }, 3),
      hint = hint, explain = fmt("NAT_E_HOME", NA.Cap(who[1]), h.desc, zone) }
  elseif kind == 2 then
    local a = NA.Cap(who[1])
    return { text = fmt("NAT_Q_LIVES", zone, h.desc), answer = a,
      choices = choices(a, { NA.Cap(pick(o1.life)[1]), NA.Cap(pick(o2.life)[1]) }, 3),
      hint = hint, explain = fmt("NAT_E_HOME", a, h.desc, zone) }
  end
  local plant = who[2] == "plant"
  local a = plant and L().NAT_PLANT or L().NAT_ANIMAL
  return { text = fmt("NAT_Q_PLANT_ANIMAL", who[1]), answer = a,
    choices = choices(a, { plant and L().NAT_ANIMAL or L().NAT_PLANT, L().NAT_ROCK }, 3),
    hint = L().NAT_H_PLANT_ANIMAL, explain = fmt(plant and "NAT_E_PLANT" or "NAT_E_ANIMAL", NA.Cap(who[1])) }
end

function gen.nat_living(level)
  local lv = NA.LevelFor(level)
  if lv >= 2 and random() < 0.5 then
    return NA.FromEntry(NA.Draw("living", D.LIVING_CLUES, level), "initiate", "NAT_H_LIVING")
  end
  local living = Util.Shuffle({ unpack(D.LIVING) })
  local still = Util.Shuffle({ unpack(D.NONLIVING) })
  if lv >= 2 and random() < 0.5 then
    local a = NA.Cap(still[1])
    return { text = L().NAT_Q_NOT_LIVING, answer = a, choices = choices(a, { NA.Cap(living[1]), NA.Cap(living[2]) }, 3),
      hint = L().NAT_H_LIVING, explain = fmt("NAT_E_NOT_LIVING", a) }
  end
  local a = NA.Cap(living[1])
  return { text = L().NAT_Q_LIVING, answer = a, choices = choices(a, { NA.Cap(still[1]), NA.Cap(still[2]) }, 3),
    hint = L().NAT_H_LIVING, explain = fmt("NAT_E_LIVING", a) }
end

gen.nat_needs = curated("needs", D.NEEDS, "initiate", "NAT_H_NEEDS")
gen.nat_daynight = curated("daynight", D.DAYNIGHT, "initiate", "NAT_H_DAYNIGHT")
gen.nat_seasons = curated("seasons", D.SEASONS, "initiate", "NAT_H_SEASONS")

-- ADEPT (ages 8-10) --------------------------------------------------------
-- other chains' producers (never eat animals) / top predators (never producers)
local function others(chain, idx)
  local out = {}
  for _, c in ipairs(D.CHAINS) do
    if c ~= chain then
      local name = idx == 1 and c.chain[1] or c.chain[#c.chain]
      local clash = false
      for _, m in ipairs(chain.chain) do if m == name then clash = true end end
      if not clash then out[#out + 1] = name end
    end
  end
  return Util.Shuffle(out)
end

local function capList(t) local out = {} for i, v in ipairs(t) do out[i] = NA.Cap(v) end return out end

function gen.nat_foodchains(level)
  local lv = NA.LevelFor(level)
  if random() < 0.45 then return NA.FromEntry(NA.Draw("food", D.FOODCHAIN, level), "adept", "NAT_H_FOODCHAINS") end
  local c = pick(D.CHAINS)
  local ch = c.chain
  local shown = table.concat(ch, " -> ")
  local head = fmt("NAT_CHAIN_HEAD", c.zone, shown)
  local kind = random(1, lv == 1 and 3 or 5)
  local hint, a, ds, q, explain = L().NAT_H_FOODCHAINS
  if kind == 1 then
    a = ch[1]
    ds = { unpack(ch, 2) }
    for _, x in ipairs(others(c, #ch)) do ds[#ds + 1] = x end
    q, explain = L().NAT_Q_PRODUCER, fmt("NAT_E_PRODUCER", NA.Cap(ch[1]))
  elseif kind == 2 then
    local i = random(1, #ch - 1)
    a = ch[i + 1]
    -- wrong answers come only from BELOW the eater (food never eats its eater) or other
    -- chains' plants, so no wrong answer could secretly be right (snakes do eat caterpillars!)
    ds = { ch[i] }
    for j = 1, i - 1 do ds[#ds + 1] = ch[j] end
    for _, x in ipairs(others(c, 1)) do ds[#ds + 1] = x end
    q, explain = fmt("NAT_Q_EATS", ch[i]), fmt("NAT_E_EATS", NA.Cap(ch[i + 1]), ch[i])
  elseif kind == 3 then
    a = ch[#ch]
    ds = { unpack(ch, 1, #ch - 1) }
    for _, x in ipairs(others(c, 1)) do ds[#ds + 1] = x end
    q, explain = L().NAT_Q_TOP, fmt("NAT_E_TOP", NA.Cap(a))
  elseif kind == 4 then
    local p = { text = head .. "\n" .. L().NAT_Q_ENERGY, answer = L().NAT_SUN, hint = hint, explain = L().NAT_E_ENERGY }
    p.choices = choices(p.answer, { "The " .. ch[#ch], L().NAT_MOON, L().NAT_RAIN }, 4)
    return p
  else
    -- typed on Rune/Glyph: the second link of every chain eats only plants
    return { text = head .. "\n" .. fmt("NAT_Q_HERBIVORE", ch[2]), answer = L().NAT_HERBIVORE,
      distractors = { L().NAT_CARNIVORE, L().NAT_PRODUCER, L().NAT_DECOMPOSER }, typed = true, alts = { "herbivore", "herbivores" },
      hint = hint, explain = fmt("NAT_E_HERBIVORE", NA.Cap(ch[2]), ch[1]) }
  end
  local capped = capList(ds)
  local A = NA.Cap(a)
  return { text = head .. "\n" .. q, answer = A, choices = choices(A, capped, 4), hint = hint, explain = explain }
end

NA.WATER_STEPS = { "Evaporation", "Condensation", "Precipitation", "Collection" }
function gen.nat_watercycle(level)
  if NA.LevelFor(level) >= 2 and random() < 0.25 then
    local i = random(1, 4)
    local a = NA.WATER_STEPS[i % 4 + 1]
    local ds = {}
    for _, s in ipairs(NA.WATER_STEPS) do if s ~= a then ds[#ds + 1] = s end end
    return { text = fmt("NAT_Q_WATER_NEXT", NA.WATER_STEPS[i]), answer = a, distractors = ds, typed = true,
      alts = (a == "Collection") and { "runoff", "collecting" } or { a:lower() }, hint = L().NAT_H_WATERCYCLE, explain = L().NAT_E_WATER_ORDER }
  end
  return NA.FromEntry(NA.Draw("water", D.WATER, level), "adept", "NAT_H_WATERCYCLE")
end

NA.STATES = { solid = "Solid", liquid = "Liquid", gas = "Gas" }
function gen.nat_matter(level)
  if random() < 0.4 then
    local s = pick(D.SUBSTANCES)
    if random() < 0.6 then
      local a = NA.STATES[s[2]]
      local ds = {}
      for _, v in pairs(NA.STATES) do if v ~= a then ds[#ds + 1] = v end end
      table.sort(ds)
      ds[#ds + 1] = L().NAT_PLASMA
      return { text = fmt("NAT_Q_STATE", s[1]), answer = a, distractors = ds, typed = true, alts = { s[2] },
        hint = L().NAT_H_MATTER, explain = fmt("NAT_E_STATE", NA.Cap(s[1]), s[2]) }
    end
    local a = NA.Cap(s[1])
    local ds = {}
    for _, o in ipairs(Util.Shuffle({ unpack(D.SUBSTANCES) })) do
      if o[2] ~= s[2] and #ds < 3 then ds[#ds + 1] = NA.Cap(o[1]) end
    end
    return { text = fmt("NAT_Q_WHICH_STATE", s[2]), answer = a, choices = choices(a, ds, 4),
      hint = L().NAT_H_MATTER, explain = fmt("NAT_E_STATE", a, s[2]) }
  end
  return NA.FromEntry(NA.Draw("matter", D.MATTER, level), "adept", "NAT_H_MATTER")
end

gen.nat_adapt = curated("adapt", D.ADAPT, "adept", "NAT_H_ADAPT")

function gen.nat_lifecycle(level)
  if random() < 0.5 then return NA.FromEntry(NA.Draw("life", D.LIFECYCLE, level), "adept", "NAT_H_LIFECYCLE") end
  local c = pick(D.CYCLES)
  local st = c.steps
  local shown = table.concat(st, " -> ")
  local a, q
  if NA.LevelFor(level) == 1 and random() < 0.4 then
    a, q = st[1], fmt("NAT_Q_CYCLE_FIRST", c.name)
  else
    local i = random(1, #st - 1)
    a, q = st[i + 1], fmt("NAT_Q_CYCLE_NEXT", c.name, st[i])
  end
  local ds, seen = {}, { [a] = true }
  for _, s in ipairs(st) do if not seen[s] then ds[#ds + 1] = s; seen[s] = true end end
  ds = Util.Shuffle(ds)
  for _, o in ipairs(Util.Shuffle({ unpack(D.CYCLES) })) do
    if o ~= c then
      for _, s in ipairs(o.steps) do if not seen[s] then ds[#ds + 1] = s; seen[s] = true; break end end
    end
  end
  local alts = { a }
  for _, x in ipairs((c.alts or {})[a] or {}) do alts[#alts + 1] = x end
  local capped = {}
  for i = 1, 3 do capped[i] = NA.Cap(ds[i]) end
  return { text = q, answer = NA.Cap(a), distractors = capped, typed = true, alts = alts,
    hint = L().NAT_H_LIFECYCLE, explain = fmt("NAT_E_CYCLE", c.name, shown) }
end

-- MAGISTER (ages 11-13) ----------------------------------------------------
gen.nat_fairtest = curated("fair", D.FAIRTEST, "magister", "NAT_H_FAIRTEST")
gen.nat_explain = curated("explain", D.EXPLAIN, "magister", "NAT_H_EXPLAIN")
gen.nat_ecosystems = curated("eco", D.ECO, "magister", "NAT_H_ECOSYSTEMS")
gen.nat_forces = curated("forces", D.FORCES, "magister", "NAT_H_FORCES")
gen.nat_energy = curated("energy", D.ENERGY, "magister", "NAT_H_ENERGY")

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
NA.BANDS = {
  initiate = { id = "initiate", nodes = { "nat_habitats", "nat_needs", "nat_living", "nat_daynight", "nat_seasons" } },
  adept    = { id = "adept",    nodes = { "nat_foodchains", "nat_watercycle", "nat_matter", "nat_adapt", "nat_lifecycle" } },
  magister = { id = "magister", nodes = { "nat_fairtest", "nat_explain", "nat_ecosystems", "nat_forces", "nat_energy" } },
}
NA.NODES = {}
for id, fn in pairs(gen) do NA.NODES[id] = { key = "NAT_NODE_" .. id:sub(5):upper(), gen = fn } end
NA.GEN = gen

-- Curated lists per node (for tests and question counts)
NA.LISTS = {
  nat_needs = { D.NEEDS }, nat_daynight = { D.DAYNIGHT }, nat_seasons = { D.SEASONS }, nat_living = { D.LIVING_CLUES },
  nat_foodchains = { D.FOODCHAIN }, nat_watercycle = { D.WATER }, nat_matter = { D.MATTER }, nat_adapt = { D.ADAPT },
  nat_lifecycle = { D.LIFECYCLE }, nat_fairtest = { D.FAIRTEST }, nat_explain = { D.EXPLAIN }, nat_ecosystems = { D.ECO },
  nat_forces = { D.FORCES }, nat_energy = { D.ENERGY },
}

NA.MODULE = ns.Modules.Register({
  id = NA.MODULE_ID,
  nameKey = "MOD_NATURALIST", descKey = "MOD_NATURALIST_DESC",
  icon = "Interface\\Icons\\INV_Misc_Herb_01",
  startSound = "page",
  loreKey = "NAT_LORE", titleKey = "NAT_TITLE",
  placementKey = "NAT_TRIAL", examKey = "NAT_EXAM",
  placementLoreKey = "NAT_TRIAL_LORE", examLoreKey = "NAT_EXAM_LORE",
  placementResultKey = "NAT_TRIAL_RESULT", examPassKey = "NAT_EXAM_PASS",
  trialRightKey = "NAT_TRIAL_RIGHT", trialWrongKey = "NAT_TRIAL_WRONG",
  bands = NA.BANDS, nodes = NA.NODES,
  choiceOnlyBands = { initiate = true },
  check = NA.Check,
  textAnswers = true,
  -- v0.9: Field Journal (tile button + skill-list link, like the v0.6 mini-game)
  game = { key = "NAT_JOURNAL_LINK", tileKey = "NAT_JOURNAL_TILE", tipKey = "NAT_JOURNAL_TIP", view = "journal" },
  -- Fizzwick says Naturalist lines in place of some generic ones (every = 1: always)
  guideEvents = { ROUNDSTART = { "NATSTART", every = 1 }, CORRECT = { "NATCORRECT", every = 3 }, WRONG = { "NATWRONG", every = 3 } },
  -- In-Flight Lessons: skills that fit looking down from a flight path, tried first
  flightNodes = {
    initiate = { "nat_habitats", "nat_daynight", "nat_seasons" },
    adept = { "nat_watercycle", "nat_foodchains", "nat_adapt" },
    magister = { "nat_ecosystems", "nat_forces", "nat_energy" },
  },
  flightEvent = "NATFLIGHT",
})

------------------------------------------------------------------------
-- Field Journal
------------------------------------------------------------------------
local J = {}
ns.Journal = J

local function entries()
  local P = ns.Progress
  if not (P and P.account) then return nil end
  if type(P.account.journal) ~= "table" then P.account.journal = {} end
  if type(P.account.journal.entries) ~= "table" then P.account.journal.entries = {} end
  return P.account.journal.entries
end

function J.Key(nodeId, tier) return tostring(nodeId) .. ":" .. tostring(tier) end

-- every specimen knows where it lives (so a "new specimen" can open its own page)
for nodeId, list in pairs(D.SPECIMENS) do
  for t, spec in ipairs(list) do spec.nodeId, spec.tier = nodeId, t end
end

function J.Specimen(nodeId, tier)
  local list = D.SPECIMENS[nodeId or ""]
  return list and list[tier] or nil
end

-- Every specimen in display order: { nodeId, tier, band, spec }
function J.All()
  local out = {}
  for _, band in ipairs(ns.Modules.BAND_ORDER) do
    for _, nodeId in ipairs(ns.Modules.Nodes(NA.MODULE_ID, band)) do
      for t = 1, 3 do
        local spec = J.Specimen(nodeId, t)
        if spec then out[#out + 1] = { nodeId = nodeId, tier = t, band = band, spec = spec } end
      end
    end
  end
  return out
end

function J.Has(nodeId, tier)
  local e = entries()
  return e ~= nil and e[J.Key(nodeId, tier)] ~= nil
end

function J.Entry(nodeId, tier)
  local e = entries()
  return e and e[J.Key(nodeId, tier)]
end

-- Called when a tier is newly mastered. Returns the specimen if it is new to the journal.
function J.Collect(nodeId, tier, now)
  local spec = J.Specimen(nodeId, tier)
  local e = entries()
  if not spec or not e then return nil end
  local k = J.Key(nodeId, tier)
  if e[k] then return nil end
  e[k] = { at = now or Util.Now() }
  return spec
end

-- Collect every specimen whose tier the current character has mastered. Returns the new ones.
function J.Sync(now)
  local P = ns.Progress
  local out = {}
  if not (P and P.char and type(P.char.modules) == "table") then return out end
  local st = P.char.modules[NA.MODULE_ID]
  if type(st) ~= "table" or type(st.nodes) ~= "table" then return out end
  for _, it in ipairs(J.All()) do
    local nr = st.nodes[it.nodeId]
    local tr = type(nr) == "table" and type(nr.tiers) == "table" and nr.tiers[it.tier]
    if type(tr) == "table" and tr.mastered then
      local spec = J.Collect(it.nodeId, it.tier, tr.masteredAt or now)
      if spec then out[#out + 1] = spec end
    end
  end
  return out
end

-- have, total (optionally for one band)
function J.Count(band)
  local have, total = 0, 0
  for _, it in ipairs(J.All()) do
    if not band or it.band == band then
      total = total + 1
      if J.Has(it.nodeId, it.tier) then have = have + 1 end
    end
  end
  return have, total
end

-- "missing" | "collected" | "faded" (collected, but this character's tier is fading or due a review)
function J.Status(nodeId, tier, now)
  if not J.Has(nodeId, tier) then return "missing" end
  local P = ns.Progress
  local st = P and P.char and type(P.char.modules) == "table" and P.char.modules[NA.MODULE_ID]
  local nr = type(st) == "table" and type(st.nodes) == "table" and st.nodes[nodeId]
  local tr = type(nr) == "table" and type(nr.tiers) == "table" and nr.tiers[tier]
  if type(tr) == "table" and (tr.fading or (ns.Review and ns.Review.IsDue(tr, now or Util.Now()))) then return "faded" end
  return "collected"
end

function J.FadedCount(now)
  local n = 0
  for _, it in ipairs(J.All()) do
    if J.Status(it.nodeId, it.tier, now) == "faded" then n = n + 1 end
  end
  return n
end

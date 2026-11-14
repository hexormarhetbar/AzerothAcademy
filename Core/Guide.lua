-- Professor Fizzwick Coppercoil: the Academy's guide, plus faction leader cameos.
-- Pure Lua (no WoW API). It decides WHICH line to say; UI/Guide.lua shows it.
--
-- Lines live in the locale files as FZ_<EVENT>_<n> (n = 1, 2, 3 ...). Adding a line
-- is just adding the next number. Lines are drawn from a shuffle bag, so every
-- line of an event is used once before any repeats, and the same line never
-- plays twice in a row (also not across a bag refill).
local _, ns = ...
local Util = ns.Util

local G = {}
ns.Guide = G

G.EVENTS = {
  "GREET", "ROUNDSTART", "CORRECT", "COMBO", "OVERCHARGE", "WRONG", "HINT",
  "MASTERED", "RANKUP", "EXAMSTART", "EXAMPASS", "EXAMTRY", "TRIALSTART",
  "TRIALDONE", "REVIEW", "FADING",
  -- v0.6: Murloc Boarding Party, said from the ship's wheel
  "BOARDSTART", "BOARDWAVE", "BOARDBOSS", "BOARDSPLASH", "BOARDBROADSIDE", "BOARDWHEEL", "BOARDWIN", "BOARDLOSE",
  -- v0.7: In-Flight Lessons
  "FLIGHTSTART", "FLIGHTDONE", "FLIGHTLAND",
}

-- Who can appear and how the UI should try to show them. Model IDs are tried in
-- order (SetDisplayInfo first, then SetCreature); everything falls back to the icon.
-- IDs come from the game's own creature data (see DESIGN.md for sources + confidence).
G.CAST = {
  fizzwick = {
    nameKey = "FZ_NAME",
    displays = { 7340, 7217, 7136 },   -- Gadgetzan goblins: Nixx Sprocketspring, Krinkle Goodsteel, Sovik
    creatures = { 8126, 5411, 3413 },
    icon = "Interface\\Icons\\Trade_Engineering",
  },
  parrot = {
    nameKey = "FZ_PARROT",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
  },
  horde = {
    nameKey = "CAMEO_HORDE_NAME",
    displays = { 4527 },               -- Thrall
    creatures = { 4949 },
    icon = "Interface\\Icons\\INV_BannerPVP_01",
    linePrefix = "CAMEO_HORDE",
  },
  alliance = {
    nameKey = "CAMEO_ALLIANCE_NAME",
    displays = { 3597 },               -- King Magni Bronzebeard (v0.5; was Bolvar 5566 in v0.4)
    creatures = { 2784 },
    icon = "Interface\\Icons\\INV_BannerPVP_02",
    linePrefix = "CAMEO_ALLIANCE",
  },
}

-- Shuffle bags -----------------------------------------------------------------
G.bags = {}

local function enUS() return (ns.LocaleData and ns.LocaleData.enUS) or {} end

-- Number of consecutive lines PREFIX_1..PREFIX_n defined in enUS.
function G.Count(prefix)
  local d, n = enUS(), 0
  while d[prefix .. "_" .. (n + 1)] do n = n + 1 end
  return n
end

-- Next key for a prefix (e.g. "FZ_CORRECT"), or nil if there are no lines.
function G.NextKey(prefix)
  local bag = G.bags[prefix]
  if not bag or #bag.items == 0 then
    local n = G.Count(prefix)
    if n == 0 then return nil end
    local items = {}
    for i = 1, n do items[i] = i end
    Util.Shuffle(items)
    local last = bag and bag.last
    -- items are popped from the end: never start a new bag with the line just said
    if last and n > 1 and items[n] == last then items[n], items[1] = items[1], items[n] end
    bag = { items = items, last = last }
    G.bags[prefix] = bag
  end
  local i = table.remove(bag.items)
  bag.last = i
  return prefix .. "_" .. i
end

-- Fizzwick's line for an event. Extra args fill a %s (e.g. the hint text).
function G.Line(event, ...)
  local key = G.NextKey("FZ_" .. event)
  if not key then return nil end
  local text = ns.L[key]
  if select("#", ...) > 0 then
    local ok, res = pcall(string.format, text, ...)
    if ok then text = res end
  end
  return text, key
end

-- v0.8: a specific line (used to let a recorded line go first). It is taken out of the
-- current shuffle bag so it doesn't come straight back.
function G.LineKey(key, ...)
  local text = ns.L[key]
  if not text or not enUS()[key] then return nil end
  if select("#", ...) > 0 then
    local ok, res = pcall(string.format, text, ...)
    if ok then text = res end
  end
  local prefix, n = key:match("^(.*)_(%d+)$")
  local bag = prefix and G.bags[prefix]
  if prefix and not bag then
    bag = { items = {} } -- empty: the next Line() deals a fresh bag that won't start with this one
    G.bags[prefix] = bag
  end
  if bag then
    n = tonumber(n)
    for i = #bag.items, 1, -1 do if bag.items[i] == n then table.remove(bag.items, i) end end
    bag.last = n
  end
  return text, key
end

function G.ResetBags() G.bags = {} end

-- Faction cameos -----------------------------------------------------------------
-- Rare on purpose: only rank-ups, exam passes and every 5th mastered tier, and
-- never two within CAMEO_GAP seconds. Neutral / unknown faction: no cameo
-- (Fizzwick celebrates alone). Text only, never voice.
G.CAMEO_KINDS = { RANKUP = true, EXAMPASS = true, MILESTONE = true }
G.CAMEO_GAP = 300
G.MILESTONE_EVERY = 5

function G.LeaderFor(faction)
  if faction == "Horde" then return "horde" end
  if faction == "Alliance" then return "alliance" end
  return nil
end

function G.IsMilestone(totalMastered)
  return (totalMastered or 0) > 0 and totalMastered % G.MILESTONE_EVERY == 0
end

-- Returns { who, cast, name, text, key } or nil. Records the time when it says yes.
function G.Cameo(kind, faction, now, settings)
  if not G.CAMEO_KINDS[kind] then return nil end
  if settings and settings.cameos == false then return nil end
  local who = G.LeaderFor(faction)
  if not who then return nil end
  now = now or Util.Now()
  if G.lastCameoAt and now - G.lastCameoAt < G.CAMEO_GAP then return nil end
  local cast = G.CAST[who]
  local key = G.NextKey(cast.linePrefix .. "_" .. kind)
  if not key then return nil end
  G.lastCameoAt = now
  return { who = who, kind = kind, cast = cast, name = ns.L[cast.nameKey], text = ns.L[key], key = key }
end

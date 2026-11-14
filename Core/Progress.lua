-- Progression: shards, ranks, bonus minutes, parent settings, PIN, profile.
-- Pure Lua. Bound to SavedVariables tables by Main.lua (or by the test harness).
local _, ns = ...
local Util = ns.Util

local P = {}
ns.Progress = P

P.RANKS = {
  { key = "RANK_INITIATE",   min = 0 },
  { key = "RANK_APPRENTICE", min = 250 },
  { key = "RANK_JOURNEYMAN", min = 750 },
  { key = "RANK_ADEPT",      min = 1500 },
  { key = "RANK_MAGISTER",   min = 3000 },
  { key = "RANK_ARCHMAGE",   min = 6000 },
}

P.BANDS = {
  { id = "initiate", key = "BAND_INITIATE", ages = "5-7" },
  { id = "adept",    key = "BAND_ADEPT",    ages = "8-10" },
  { id = "magister", key = "BAND_MAGISTER", ages = "11-13" },
}
P.BAND_BY_ID = {}
for _, b in ipairs(P.BANDS) do P.BAND_BY_ID[b.id] = b end

P.LIMITS = { minutesPerMasteryMax = 60, dailyCapMax = 240 }

P.SCHEMA = 8

local ACCOUNT_DEFAULTS = {
  version = P.SCHEMA,
  settings = {
    minutesPerMastery = 10, dailyCap = 60, unlockAllTiers = false, reviews = true,
    -- v0.4 (schema 4): presentation settings
    sound = { enabled = true, channel = "SFX", level = "all", custom = true },
    reducedMotion = false,
    cameos = true,
    -- v0.6.1: minimap button (no schema change: filled in by ApplyDefaults)
    minimap = { hide = false, angle = 225 },
    -- v0.7 (schema 5): In-Flight Lessons. mode = "off" | "toast" | "auto".
    -- Replaces the old taxiNudge chat reminder (migrated below).
    flight = { mode = "toast" },
    -- v0.8: Fizzwick's recorded voice (volume + mute follow `sound`). No schema change.
    voice = { enabled = true },
    -- v0.10 (schema 7): Duel of Wits. Group / guild / friend duels are on by
    -- default; random challengers are OFF until a parent turns them on.
    -- alias = { adjective index, creature index } into ns.Duel.ALIAS_A / ALIAS_B.
    duel = { enabled = true, friendsOnly = false, random = false, alias = { 1, 1 } },
    -- v1.1 (schema 8): in-game language picker. "auto" = follow the game client (GetLocale()).
    language = "auto",
    -- v1.1 (schema 8): area selection. areas[areaId] = false hides that area from the hub,
    -- Quick Drill, reviews, flights and duels. Missing / true = shown (default: everything on).
    areas = {},
    -- v1.1: World Tongues. course = last course picked in the course list (ns.Tongues.COURSES).
    tongues = { course = "ja" },
  },
  minutes = { day = "", earned = 0 },
  ui = {},
  -- v0.9 (schema 6): Azeroth Naturalist Field Journal, account-wide so every
  -- character's mastered specimens land in one book. entries["nodeId:tier"] = { at = time }
  journal = { entries = {} },
  -- v0.10 (schema 7): duel safety + anti-farming. blocked[normalized name] = true.
  -- minutes/day track duel bonus minutes, which still count against the daily cap.
  duel = { blocked = {}, day = "", minutes = 0 },
}

local CHAR_DEFAULTS = {
  version = P.SCHEMA,
  profile = {},
  shards = 0,
  modules = {},
  stats = { rounds = 0, problems = 0, firstCorrect = 0, time = 0 },
  duel = { played = 0, wins = 0, finished = 0 },
}

local MODULE_DEFAULTS = { nodes = {}, placement = {}, exams = {} }

-- v0.1 (schema 1) -> v0.2 (schema 2):
--   char.nodes            -> char.modules.runeforger.nodes   (module-agnostic storage)
--   mastered tiers        -> get a spaced-review schedule starting from masteredAt
--   kids who already played a band are not forced into the placement trial
local function migrate(account, char)
  P.migrated = nil
  P.upgradedFrom = nil
  local startVersion = char.version or 1
  if (account.version or 1) < 5 then
    -- v0.7 (schema 5): the chat-only flight nudge became In-Flight Lessons.
    -- A parent who had turned the nudge off gets flights "off" too.
    local st = account.settings
    if type(st) == "table" and st.taxiNudge == false and type(st.flight) == "table" then st.flight.mode = "off" end
  end
  if (char.version or 1) < 2 then
    local old = char.nodes
    char.nodes = nil
    char.version = 2
    if type(old) == "table" then
      local st = P.GetModuleState("runeforger")
      local now = Util.Now()
      local playedBands = {}
      for nodeId, rec in pairs(old) do
        if type(rec) == "table" then
          st.nodes[nodeId] = rec
          local node
          if ns.Modules then node = select(2, ns.Modules.FindNode(nodeId)) end
          for t = 1, 3 do
            local tr = type(rec.tiers) == "table" and rec.tiers[t]
            if type(tr) == "table" then
              if (tr.attempts or 0) > 0 and node then playedBands[node.band] = true end
              if tr.mastered and type(tr.review) ~= "table" and ns.Review then
                ns.Review.Schedule(tr, tr.masteredAt or now)
              end
            end
          end
        end
      end
      for band in pairs(playedBands) do
        if not st.placement[band] then st.placement[band] = { status = "skipped", migrated = true, date = now } end
      end
    end
    P.migrated = true
  end
  if (char.version or 1) < 3 then
    -- v0.3 (schema 3): Scribe's Scrolls arrives. Its state is created lazily
    -- under char.modules.scribe, so nothing existing has to move.
    char.version = 3
  end
  if (char.version or 1) < 4 then
    -- v0.4 (schema 4): sound / reduced-motion / cameo settings. ApplyDefaults in
    -- Bind already filled them in without touching existing values.
    char.version = 4
  end
  if (char.version or 1) < 5 then
    -- v0.7 (schema 5): account-level flight setting only; nothing per character moves.
    char.version = 5
  end
  if (char.version or 1) < 6 then
    -- v0.9 (schema 6): the Field Journal (account.journal, filled by ApplyDefaults).
    -- Nothing per character moves; Bind syncs mastered Naturalist tiers into it.
    char.version = 6
  end
  if (char.version or 1) < 7 then
    -- v0.10 (schema 7): Duel of Wits. Settings, block list and duel stats are
    -- filled in by ApplyDefaults; nothing existing moves.
    char.version = 7
  end
  if (char.version or 1) < 8 then
    -- v1.1 (schema 8): language picker, area selection and World Tongues settings are filled
    -- in by ApplyDefaults. The Parent Panel became Settings and its PIN is now optional: an
    -- existing PIN is KEPT untouched (account.pin), so a family that set one stays locked.
    char.version = 8
  end
  local acs = type(account.settings) == "table" and account.settings
  if acs then
    if type(acs.language) ~= "string" or (acs.language ~= "auto" and not (ns.LANGUAGE_BY_CODE and ns.LANGUAGE_BY_CODE[acs.language])) then
      acs.language = "auto"
    end
    if type(acs.areas) ~= "table" then acs.areas = {} end
  end
  local dset = type(account.settings) == "table" and account.settings.duel
  if type(dset) == "table" and not dset.aliasPicked and type(dset.alias) == "table" then
    -- every account (new or upgraded) starts with its own random duel alias
    dset.alias[1], dset.alias[2] = Util.Random(1, 12), Util.Random(1, 12)
    dset.aliasPicked = true
  end
  if startVersion < P.SCHEMA then P.upgradedFrom = startVersion end
  if (account.version or 1) < P.SCHEMA then account.version = P.SCHEMA end
end

function P.Bind(account, char)
  P.account = Util.ApplyDefaults(account or {}, ACCOUNT_DEFAULTS)
  P.char = Util.ApplyDefaults(char or {}, CHAR_DEFAULTS)
  migrate(P.account, P.char)
  -- v1.1: the saved language choice takes effect as soon as the saved variables are bound
  if ns.SetLocale then ns.SetLocale(P.account.settings.language) end
  -- v0.9: make sure every Naturalist tier this character mastered has its journal page
  -- (covers a new account file, a reset journal, or a tier mastered on an old version).
  if ns.Journal then ns.Journal.Sync() end
  return P.account, P.char
end

function P.GetModuleState(moduleId)
  local mods = P.char.modules
  if type(mods[moduleId]) ~= "table" then mods[moduleId] = {} end
  return Util.ApplyDefaults(mods[moduleId], MODULE_DEFAULTS)
end

-- Total mastered tiers across every subject (drives milestone cameos).
function P.TotalMastered()
  local n = 0
  for _, st in pairs(P.char and P.char.modules or {}) do
    if type(st) == "table" and type(st.nodes) == "table" then
      for _, rec in pairs(st.nodes) do
        if type(rec) == "table" and type(rec.tiers) == "table" then
          for t = 1, 3 do
            if type(rec.tiers[t]) == "table" and rec.tiers[t].mastered then n = n + 1 end
          end
        end
      end
    end
  end
  return n
end

-- Profile -----------------------------------------------------------------
function P.GetBand() return P.char and P.char.profile.band end

function P.SetBand(id)
  if not P.BAND_BY_ID[id] then return false end
  P.char.profile.band = id
  if not P.char.profile.created then P.char.profile.created = Util.Now() end
  return true
end

function P.ResetProfile()
  Util.Wipe(P.char)
  Util.ApplyDefaults(P.char, CHAR_DEFAULTS)
end

-- Ranks / shards -------------------------------------------------------------
function P.GetRankIndex(shards)
  local idx = 1
  for i, r in ipairs(P.RANKS) do
    if shards >= r.min then idx = i end
  end
  return idx
end

function P.GetRankInfo(shards)
  shards = shards or (P.char and P.char.shards) or 0
  local idx = P.GetRankIndex(shards)
  local cur, nxt = P.RANKS[idx], P.RANKS[idx + 1]
  local info = { index = idx, key = cur.key, min = cur.min, shards = shards }
  if nxt then
    info.nextKey, info.nextMin = nxt.key, nxt.min
    info.pct = (shards - cur.min) / (nxt.min - cur.min)
  else
    info.pct = 1
  end
  return info
end

-- Returns gained, rankedUp(bool), newRankIndex
function P.AddShards(n)
  n = math.max(0, math.floor(n or 0))
  local before = P.GetRankIndex(P.char.shards)
  P.char.shards = P.char.shards + n
  local after = P.GetRankIndex(P.char.shards)
  return n, after > before, after
end

-- Bonus minutes (account-wide so a second character can't double the cap) ----
function P.GetTodayMinutes()
  local m, day = P.account.minutes, Util.DayKey()
  if m.day ~= day then
    m.day, m.earned = day, 0
  end
  return m.earned, P.account.settings.dailyCap
end

function P.AwardMastery()
  local earned, cap = P.GetTodayMinutes()
  local per = P.account.settings.minutesPerMastery or 0
  local grant = math.max(0, math.min(per, cap - earned))
  P.account.minutes.earned = earned + grant
  return grant
end

function P.SetMinuteRules(perMastery, cap)
  perMastery, cap = tonumber(perMastery), tonumber(cap)
  if not perMastery or not cap then return false end
  perMastery, cap = math.floor(perMastery), math.floor(cap)
  if perMastery < 0 or perMastery > P.LIMITS.minutesPerMasteryMax then return false end
  if cap < 0 or cap > P.LIMITS.dailyCapMax then return false end
  P.account.settings.minutesPerMastery = perMastery
  P.account.settings.dailyCap = cap
  return true
end

-- PIN (soft lock only) -------------------------------------------------------
local function pinHash(salt, pin)
  return Util.Hash(salt .. ":" .. pin .. ":AzerothAcademy") .. Util.Hash(pin .. salt)
end

function P.IsValidPin(pin)
  return type(pin) == "string" and pin:match("^%d%d%d%d%d?%d?$") ~= nil
end

function P.HasPin()
  return P.account and type(P.account.pin) == "table" and P.account.pin.hash ~= nil
end

function P.SetPin(pin)
  if not P.IsValidPin(pin) then return false end
  local salt = tostring(math.random(100000, 999999))
  P.account.pin = { salt = salt, hash = pinHash(salt, pin) }
  return true
end

-- v1.1: the PIN is optional (off by default). Removing it needs the panel to be unlocked.
function P.ClearPin()
  P.account.pin = nil
  return true
end

function P.CheckPin(pin)
  if not P.HasPin() then return true end
  if type(pin) ~= "string" then return false end
  return pinHash(P.account.pin.salt, pin) == P.account.pin.hash
end

-- Node records -----------------------------------------------------------------
function P.GetNodeRec(nodeId)
  local module = ns.Modules and ns.Modules.FindNode(nodeId)
  local nodes = P.GetModuleState(module and module.id or "misc").nodes
  local rec = nodes[nodeId]
  if type(rec) ~= "table" then
    rec = {}
    nodes[nodeId] = rec
  end
  rec.tiers = rec.tiers or {}
  for t = 1, 3 do
    local tr = rec.tiers[t]
    if type(tr) ~= "table" then
      tr = {}
      rec.tiers[t] = tr
    end
    Util.ApplyDefaults(tr, { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false, fading = false })
  end
  return rec
end

-- v0.10: duel bonus minutes. At most `per` for one duel, at most `dayMax` per
-- day from duels, and never past the parent's daily cap (shared with mastery).
function P.AwardDuelMinutes(per, dayMax)
  local earned, cap = P.GetTodayMinutes()
  local d, day = P.account.duel, Util.DayKey()
  if d.day ~= day then d.day, d.minutes = day, 0 end
  local grant = math.max(0, math.min(per or 0, (dayMax or 0) - d.minutes, cap - earned))
  d.minutes = d.minutes + grant
  P.account.minutes.earned = earned + grant
  return grant
end

function P.GetTierRec(nodeId, tier)
  return P.GetNodeRec(nodeId).tiers[tier]
end

-- v1.1 Language picker ----------------------------------------------------------
-- choice: "auto" or a code from ns.LANGUAGE_CHOICES. Returns the code now in use, or nil.
function P.GetLanguage()
  local st = P.account and P.account.settings
  return (st and st.language) or "auto"
end

function P.SetLanguage(choice)
  if type(choice) ~= "string" then return nil end
  if choice ~= "auto" then
    local c = ns.LANGUAGE_BY_CODE and ns.LANGUAGE_BY_CODE[choice]
    if not c then return nil end
    choice = c.code -- esMX -> esES
  end
  P.account.settings.language = choice
  return ns.SetLocale(choice)
end

-- v1.1 Area selection -------------------------------------------------------------
-- An area is a hub subject plus its companion modules (Lore Quiz belongs to Lore Chronicles,
-- every World Tongues course part belongs to "tongues"). See Modules.AREAS.
function P.IsAreaShown(areaId)
  local st = P.account and P.account.settings
  local areas = st and st.areas
  return not (type(areas) == "table" and areas[areaId] == false)
end

-- Hiding the last visible area is refused (the Academy would be empty).
function P.SetAreaShown(areaId, shown)
  local areas = P.account.settings.areas
  if not shown then
    local left = 0
    for _, a in ipairs(ns.Modules.Areas()) do
      if a.id ~= areaId and P.IsAreaShown(a.id) then left = left + 1 end
    end
    if left == 0 then return false end
    areas[areaId] = false
  else
    areas[areaId] = nil
  end
  return true
end

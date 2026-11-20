-- Azeroth Academy - Duel of Wits: multiplayer learning races (pure Lua).
-- The engine never touches WoW. Main/UI give it a transport (send), a clock
-- (now) and a few questions it may ask (band, settings, combat...). That is
-- what lets tests/harness.lua run several "clients" on a fake chat bus with
-- lost, late and out-of-order messages.
--
-- Topology: the challenger hosts. Racers talk to the host by whisper; the host
-- talks to racers on the group channel (PARTY/RAID/GUILD) or by whisper.
-- Every racer builds its own questions from the shared seed + its own age band,
-- so nobody waits on the network to see the next question.
local _, ns = ...
local Util, DP = ns.Util, ns.DuelProto
local floor, max, min = math.floor, math.max, math.min

local D = {}
ns.Duel = D

D.MIN_RACERS, D.MAX_RACERS = 2, 5
D.LENGTHS = { 5, 10 }
D.COUNTDOWN = 3          -- 3-2-1
D.PENALTY = 3            -- seconds added for each wrong answer
D.MIN_ANSWER = 0.4       -- anti-cheat: nobody answers faster than this, on average
D.SLACK = 8              -- anti-cheat: allowed clock/latency slack in seconds
D.INVITE_TIMEOUT = 25    -- invite popup auto-declines after this
D.LOBBY_TIMEOUT = 120    -- an empty lobby closes itself
D.LOBBY_PING = 10        -- host re-sends the lobby so late/lost messages heal
D.SILENCE = 15           -- a racer (or host) silent this long has left
D.KEEPALIVE = 4          -- racers report at least this often during a race
D.RETRY, D.MAX_TRIES = 2, 5
D.EMOTE_GAP, D.EMOTE_MAX = 3, 6
D.QUEUE_BEACON, D.QUEUE_MAX, D.QUEUE_MATCH_WAIT = 8, 300, 20
D.REWARD = { perCorrect = 2, finish = 5, win = 10, maxShards = 40, minutes = 2, minutesDay = 10 }

function D.MaxRace(length) return (length or 5) * 45 + 20 end

-- Preset emotes. Only the number goes over the wire; there is no free text.
D.EMOTES = { "DUEL_EMOTE_GG", "DUEL_EMOTE_WP", "DUEL_EMOTE_REMATCH", "DUEL_EMOTE_FUN" }
D.ALIAS_COUNT = 12 -- DUEL_ADJ_1..12 x DUEL_CRE_1..12 in the locale

D.SUBJECTS = {
  { id = "runeforger", module = "runeforger" },
  { id = "scribe",     module = "scribe" },
  { id = "typing",     module = "scribe", typing = true, nameKey = "DUEL_SUBJ_TYPING" },
  { id = "lore",       module = "lore" },
  { id = "naturalist", module = "naturalist" },
  { id = "lorequiz",   module = "lorequiz" },
  { id = "gnomish",    module = "gnomish" },
  { id = "librarian",  module = "librarian" },
  { id = "mechanics",  module = "mechanics" },
  -- v1.1 language duels (protocol 2). Levels follow each racer's own age band.
  -- kana: shared Japanese kana speed race. words: each racer races on their OWN course
  -- (Settings > World Tongues course). phrasebook: co-op, the racers take turns filling the
  -- lines of one shared dialogue (preset choices only, never free text).
  { id = "kana", module = "tongues_ja", proto = 2, lang = true, nameKey = "DUEL_SUBJ_KANA",
    nodes = { "wt_ja_hira", "wt_ja_kata", "wt_ja_hira_marks", "wt_ja_kata_marks" } },
  { id = "words", module = "tongues_ja", proto = 2, lang = true, ownCourse = true, nameKey = "DUEL_SUBJ_WORDS",
    lessons = { "greetings", "colors", "family", "food", "numbers", "phrases" } },
  { id = "phrasebook", module = "tongues_ja", proto = 2, lang = true, coop = true, nameKey = "DUEL_SUBJ_PHRASEBOOK" },
}
D.SUBJECT_BY_ID = {}
for _, s in ipairs(D.SUBJECTS) do D.SUBJECT_BY_ID[s.id] = s end
D.TYPE_NODE = { initiate = "sc_type_words", adept = "sc_type_phrases", magister = "sc_type_sentences" }

local function L() return ns.L or {} end

function D.Subjects()
  local out = {}
  for _, s in ipairs(D.SUBJECTS) do
    -- v1.1: subjects whose area is switched off in Settings are not offered
    if ns.Modules and ns.Modules.Get(s.module) and ns.Modules.IsShown(s.module) then out[#out + 1] = s end
  end
  return out
end

function D.SubjectName(id)
  local s = D.SUBJECT_BY_ID[id]
  if not s then return tostring(id) end
  local m = ns.Modules and ns.Modules.Get(s.module)
  local key = s.nameKey or (m and m.nameKey) or s.id
  return L()[key] or key
end

function D.BandIndex(band)
  for i, b in ipairs(ns.Progress.BANDS) do if b.id == band then return i end end
  return nil
end

function D.AliasText(a, b)
  a, b = tonumber(a) or 1, tonumber(b) or 1
  local adj = L()["DUEL_ADJ_" .. a] or "Brave"
  local cre = L()["DUEL_CRE_" .. b] or "Kodo"
  return adj .. " " .. cre
end

------------------------------------------------------------------------
-- Names
------------------------------------------------------------------------
function D.Norm(name, realm)
  name = tostring(name or "")
  if not name:find("-", 1, true) and realm and realm ~= "" then name = name .. "-" .. realm end
  return name
end
function D.Short(name) return (tostring(name):match("^([^%-]+)")) or tostring(name) end
-- v1.2.4: a player's key is the character name without any realm, lower case. Clients do not
-- agree on realm spellings (WoW Forever reports realms like "CAMWOWUS1Realm1PvE"), and a duel
-- only ever has up to 5 people from one group / guild, so the bare name is what identifies them.
function D.Key(name)
  local short = D.Short(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return short:lower()
end
local nkey = D.Key
-- v1.2.4: messages meant for one player travel on the group (or guild) channel with this last
-- field naming who it is for ("@>name"); peers it is not for ignore it. Older clients ignore
-- the extra field (every message is read by position).
D.TO_MARK = "@>"

------------------------------------------------------------------------
-- Question sets (deterministic)
------------------------------------------------------------------------
-- v1.1: protocol a subject needs (language duels are protocol 2)
function D.ProtoFor(subjectId)
  local s = D.SUBJECT_BY_ID[subjectId or ""]
  return (s and s.proto) or 1
end

function D.SubjectNodes(sub, band, course)
  local Mods = ns.Modules
  if sub.nodes then
    local out = {}
    for _, id in ipairs(sub.nodes) do if Mods.FindNode(id) then out[#out + 1] = id end end
    return out
  end
  if sub.lessons then
    course = (course and Mods.Get("tongues_" .. course)) and course or "ja"
    local out = {}
    for _, l in ipairs(sub.lessons) do
      local id = "wt_" .. course .. "_" .. l
      if Mods.FindNode(id) then out[#out + 1] = id end
    end
    return out
  end
  if sub.typing then
    local n = D.TYPE_NODE[band]
    return n and { n } or {}
  end
  local out = {}
  for _, id in ipairs(Mods.Nodes(sub.module, band)) do
    if not id:match("^sc_type_") then out[#out + 1] = id end
  end
  return out
end

function D.Usable(p, sub)
  if not p or type(p.text) ~= "string" then return false end
  if sub.typing then return p.mode == "typing" end
  return p.mode == "choice" and type(p.choices) == "table" and #p.choices >= 2
end

local function bagTables()
  local out = {}
  for _, t in ipairs({ ns.Lore, ns.Naturalist }) do if type(t) == "table" and t.bags then out[#out + 1] = t end end
  return out
end

-- v1.1 language duels: generator level from the racer's own band
D.LANG_LEVELS = { initiate = { 1, 2 }, adept = { 2, 3 }, magister = { 3, 5 } }

-- Same (subject, band, seed, length[, course, role]) => same questions on every client.
-- course: the racer's own World Tongues course ("words"); role: 0/1 line owner (phrasebook).
function D.BuildSet(subjectId, band, seed, length, course, role)
  local sub = D.SUBJECT_BY_ID[subjectId]
  local Mods = ns.Modules
  local mod = sub and Mods.Get(sub.module)
  if not mod then return nil end
  length = tonumber(length) or 5
  if sub.coop then
    if length < 1 or length > 20 or not ns.Tongues then return nil end
    return ns.Tongues.PhrasebookSet(Util.NewRNG(Util.HashNum(tostring(seed) .. ":phrasebook")), length, role or 0)
  end
  local ownBand = band
  if mod.unbanded then band = "everyone" end
  local nodes = D.SubjectNodes(sub, band, course)
  if #nodes == 0 or length < 1 or length > 20 then return nil end
  local lv = sub.lang and (D.LANG_LEVELS[ownBand or ""] or D.LANG_LEVELS.adept)
  local rng = Util.NewRNG(Util.HashNum(table.concat({ tostring(seed), subjectId, tostring(lv and ownBand or band), tostring(length) }, ":")))
  -- the Lore/Naturalist "no repeats" bags are history; a duel must not depend on it
  local saved = {}
  for _, t in ipairs(bagTables()) do saved[t] = t.bags; t.bags = {} end
  local okp, set = pcall(Util.WithRNG, rng, function()
    local out, pool = {}, {}
    for _ = 1, length do
      local p
      for _ = 1, 12 do
        if #pool == 0 then pool = Util.Shuffle({ unpack(nodes) }) end
        local nodeId = table.remove(pool)
        local level = sub.typing and rng(1, 2) or (lv and rng(lv[1], lv[2])) or rng(1, 3)
        local cand = Mods.Generate(nodeId, level, 1, "practice")
        if D.Usable(cand, sub) then p = cand; break end
      end
      if not p then return nil end
      out[#out + 1] = p
    end
    return out
  end)
  for t, b in pairs(saved) do t.bags = b end
  if not okp or type(set) ~= "table" or #set ~= length then return nil end
  return set
end

------------------------------------------------------------------------
-- Scoring, validation, ranking (pure)
------------------------------------------------------------------------
function D.Score(answered, correct, elapsed)
  return (elapsed or 0) + ((answered or 0) - (correct or 0)) * D.PENALTY
end

-- Host-side sanity check of a racer report. prev = last accepted report.
function D.Validate(rep, prev, length, hostElapsed)
  local a, c, e = rep.answered, rep.correct, rep.elapsed
  if type(a) ~= "number" or type(c) ~= "number" or type(e) ~= "number" then return false, "type" end
  if a ~= floor(a) or c ~= floor(c) or a < 0 or c < 0 then return false, "range" end
  if a > length or c > a then return false, "count" end
  if prev and (a < (prev.answered or 0) or c < (prev.correct or 0)) then return false, "backwards" end
  if a > 0 and e < a * D.MIN_ANSWER then return false, "fast" end
  if hostElapsed and e > hostElapsed + D.SLACK then return false, "clock" end
  if (rep.wpm or 0) > 250 or (rep.acc or 0) > 100 or (rep.acc or 0) < 0 then return false, "typing" end
  return true
end

local STATUS_ORDER = { finished = 1, dnf = 1, racing = 2, joined = 3, left = 4 }
-- rows: { name, answered, correct, time, status, valid } -> sorted copy with .rank
function D.Rank(rows)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = r end
  local function bucket(r)
    if r.valid == false then return 9 end
    return STATUS_ORDER[r.status] or 5
  end
  table.sort(out, function(a, b)
    local ba, bb = bucket(a), bucket(b)
    if ba ~= bb then return ba < bb end
    if (a.correct or 0) ~= (b.correct or 0) then return (a.correct or 0) > (b.correct or 0) end
    local ta, tb = a.time or 1e9, b.time or 1e9
    if math.abs(ta - tb) > 0.05 then return ta < tb end
    return tostring(a.name) < tostring(b.name)
  end)
  for i, r in ipairs(out) do
    local prev = out[i - 1]
    if prev and bucket(prev) == bucket(r) and bucket(r) <= 1 and (prev.correct or 0) == (r.correct or 0)
      and math.abs((prev.time or 0) - (r.time or 0)) <= 0.05 then
      r.rank = prev.rank
    else
      r.rank = i
    end
  end
  return out
end

-- Shards + minutes + practice stats for this client, once per duel.
function D.ComputeReward(ranked, meKey, length)
  local me, others = nil, 0
  for _, r in ipairs(ranked) do
    if nkey(r.name) == meKey then me = r
    elseif r.valid ~= false and (r.answered or 0) >= math.ceil(length / 2) then others = others + 1 end
  end
  if not me then return { shards = 0, minutes = false, win = false } end
  local R = D.REWARD
  local finished = me.status == "finished" and (me.answered or 0) >= length
  local win = others > 0 and me.rank == 1 and (me.status == "finished" or me.status == "dnf")
  local shards = 0
  if me.status ~= "left" then
    shards = (me.correct or 0) * R.perCorrect + (finished and R.finish or 0) + (win and R.win or 0)
  end
  return { shards = min(R.maxShards, shards), minutes = finished and others > 0, win = win, finished = finished, me = me, others = others }
end

------------------------------------------------------------------------
-- Engine
------------------------------------------------------------------------
local Engine = {}
Engine.__index = Engine

-- o = { me, realm, now(), send(msg, channel, target), band(), display(),
--       settings(), context() -> {combat, instance}, isFriend(name),
--       isBlocked(name), groupChannel() -> "RAID"|"PARTY"|nil, inGuild(),
--       queueChannel() -> channel index|nil, queueJoin(), queueLeave(),
--       notify(event, ...), addonVersion }
function D.NewEngine(o)
  local E = setmetatable({ o = o, q = DP.NewQueue(8, 1), asm = DP.NewAssembler(), counter = 0,
    duel = nil, invite = nil, queue = nil, stats = { dropped = 0, received = 0 } }, Engine)
  E.me = D.Norm(o.me, o.realm)
  E.meKey = nkey(E.me)
  return E
end

function Engine:Now() return self.o.now() end
function Engine:Notify(ev, ...) if self.o.notify then self.o.notify(ev, ...) end end
function Engine:Settings() return (self.o.settings and self.o.settings()) or {} end
function Engine:Context() return (self.o.context and self.o.context()) or {} end

function Engine:Flush() self.q:Flush(self:Now(), self.o.send) end

function Engine:Log(fmt, ...)
  if self.o.log then
    local okf, text = pcall(string.format, fmt, ...)
    pcall(self.o.log, okf and text or tostring(fmt))
  end
end

-- v1.2.4: how a message for one player travels. Whispers to "Name-Realm" fail on WoW Forever
-- ("No player named ... is currently playing"), so a player in our party / raid is reached on
-- the group channel, a guild duel on the guild channel; only a stranger gets a real whisper.
function Engine:Route(target)
  local grp = self.o.groupChannel and self.o.groupChannel()
  if grp and (not self.o.inGroup or self.o.inGroup(target)) then return grp end
  local d = self.duel
  if d and d.scope == "GUILD" and self.o.inGuild and self.o.inGuild() then return "GUILD" end
  return nil
end

function Engine:Send(channel, target, key, mtype, ...)
  -- v1.1: protocol 1 unless the duel / queue is on a language subject
  local subject = (self.duel and self.duel.subject) or (self.queue and self.queue.subject)
  DP.sendVersion = D.ProtoFor(subject)
  local msg
  if channel == "WHISPER" then
    local via = self:Route(target)
    if via then
      local args = { ... }
      args[select("#", ...) + 1] = D.TO_MARK .. D.Short(target)
      msg = DP.Encode(mtype, unpack(args, 1, select("#", ...) + 1))
      self:Log("send %s to %s via %s", mtype, D.Short(target), via)
      channel, target = via, nil
      if key then key = key .. ":" .. nkey(args[#args]) end
    else
      msg = DP.Encode(mtype, ...)
      target = self.o.whisperName and self.o.whisperName(target) or target
      self:Log("send %s to %s by whisper", mtype, tostring(target))
    end
  else
    msg = DP.Encode(mtype, ...)
    self:Log("send %s on %s", mtype, tostring(channel))
  end
  DP.sendVersion = nil
  self.q:Push(msg, channel, target, key)
  self:Flush()
end

-- v1.2.4: the client said a whisper target is not online (system "No player named ...").
-- Stop retrying it, and leave a duel that can only reach that player by whisper.
function Engine:Unreachable(name)
  local k = nkey(name)
  local d = self.duel
  if not d then return false end
  for wk in pairs(d.wait) do if wk:sub(1, #k + 1) == k .. "|" then d.wait[wk] = nil end end
  local involved = (d.hostKey == k) or (d.racers[k] ~= nil) or (d.target and nkey(d.target) == k)
  if not involved or d.unreachableTold then return false end
  d.unreachableTold = true
  self:Log("%s cannot be reached by whisper", D.Short(name))
  self:Notify("unreachable", d, D.Short(name))
  if (d.state == "lobby" or d.state == "countdown") and not self:Route(name) then self:Leave("unreachable") end
  return true
end

-- Reliable whisper: re-sent every RETRY seconds until an ACK arrives.
function Engine:Reliable(target, already, mtype, ...)
  local d = self.duel
  if not d then return end
  local args = { ... }
  local k = nkey(target) .. "|" .. mtype
  d.wait[k] = { target = target, mtype = mtype, args = args, at = self:Now(), tries = 1 }
  if not already then self:Send("WHISPER", target, nil, mtype, unpack(args)) end
end

function Engine:Busy()
  local d = self.duel
  return d and (d.state == "lobby" or d.state == "countdown" or d.state == "race")
end

function Engine:InRace()
  local d = self.duel
  return d and (d.state == "countdown" or d.state == "race")
end

local function newRacer(name, display, band, a, b, status, now)
  return { name = name, key = nkey(name), display = display or "", band = band, aA = tonumber(a) or 1, aB = tonumber(b) or 1,
    status = status or "joined", answered = 0, correct = 0, elapsed = 0, time = 0, wpm = 0, acc = 0,
    seq = 0, heard = now, valid = true }
end

function Engine:MyAlias()
  local al = self:Settings().alias or {}
  return tonumber(al[1]) or 1, tonumber(al[2]) or 1
end

-- What other players see for a racer. Random-queue duels never show names.
function D.DisplayFor(r, scope)
  if scope == "QUEUE" or not r.display or r.display == "" then return D.AliasText(r.aA, r.aB) end
  return r.display
end

function Engine:Racer(name)
  local d = self.duel
  return d and d.racers[nkey(name)]
end

function Engine:AddRacer(r)
  local d = self.duel
  if not d.racers[r.key] then d.order[#d.order + 1] = r.key end
  d.racers[r.key] = r
  return r
end

function Engine:Joined()
  local d, n = self.duel, 0
  if not d then return 0 end
  for _, k in ipairs(d.order) do
    local s = d.racers[k].status
    if s ~= "left" and s ~= "declined" then n = n + 1 end
  end
  return n
end

-- Host -> racers. Group duels use one broadcast; whisper/queue duels whisper each.
function Engine:Broadcast(key, mtype, ...)
  local d = self.duel
  if d.scope == "PARTY" or d.scope == "RAID" or d.scope == "GUILD" then
    self:Send(d.scope, nil, key, mtype, ...)
  else
    for _, k in ipairs(d.order) do
      local r = d.racers[k]
      if k ~= self.meKey and r.status ~= "left" and r.status ~= "declined" then
        self:Send("WHISPER", r.name, key and (key .. k), mtype, ...)
      end
    end
  end
end

function Engine:Others()
  local d, out = self.duel, {}
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    if k ~= self.meKey and r.status ~= "left" and r.status ~= "declined" then out[#out + 1] = r end
  end
  return out
end

------------------------------------------------------------------------
-- Why would this client refuse an invite?
------------------------------------------------------------------------
function Engine:DeclineReason(sender, scope)
  local st, ctx = self:Settings(), self:Context()
  if self.o.isBlocked and self.o.isBlocked(sender) then return "blocked" end
  if st.enabled == false then return "parent" end
  if scope == "QUEUE" then
    if not st.random or st.friendsOnly then return "parent" end
  elseif st.friendsOnly and not (self.o.isFriend and self.o.isFriend(sender)) then
    return "friendsOnly"
  end
  if ctx.combat then return "combat" end
  if ctx.instance then return "instance" end
  if self:Busy() or self.invite then return "busy" end
  if not (self.o.band and self.o.band()) then return "busy" end
  return nil
end

------------------------------------------------------------------------
-- Hosting
------------------------------------------------------------------------
function Engine:Host(subject, length, scope, target)
  local st, ctx = self:Settings(), self:Context()
  if not D.SUBJECT_BY_ID[subject] then return nil, "subject" end
  length = (tonumber(length) == 10) and 10 or 5
  if st.enabled == false and scope ~= "QUEUE" then return nil, "parent" end
  if ctx.combat then return nil, "combat" end
  if ctx.instance then return nil, "instance" end
  if self:Busy() then return nil, "busy" end
  local band = self.o.band and self.o.band()
  if not band then return nil, "band" end
  if scope == "WHISPER" or scope == "QUEUE" then
    if not target or target == "" then return nil, "target" end
    target = D.Norm(target, self.o.realm)
    if nkey(target) == self.meKey then return nil, "self" end
    if self.o.isBlocked and self.o.isBlocked(target) then return nil, "blocked" end
  elseif scope == "PARTY" or scope == "RAID" then
    scope = self.o.groupChannel and self.o.groupChannel()
    if not scope then return nil, "nogroup" end
  elseif scope == "GUILD" then
    if not (self.o.inGuild and self.o.inGuild()) then return nil, "noguild" end
  else
    return nil, "scope"
  end
  self.counter = self.counter + 1
  local now = self:Now()
  local id = string.format("%d%02d", floor(now) % 100000, self.counter % 100)
  local d = { id = id, host = self.me, hostKey = self.meKey, isHost = true, scope = scope, target = target,
    subject = subject, length = length, state = "lobby", racers = {}, order = {}, created = now,
    lastPing = now, wait = {}, seqOut = 0, stateSeq = 0, declined = {}, emotes = 0, lastEmote = -99 }
  self.duel, self.invite = d, nil
  local a, b = self:MyAlias()
  local display = scope == "QUEUE" and "" or (self.o.display and self.o.display() or D.Short(self.me))
  self:AddRacer(newRacer(self.me, display, band, a, b, "joined", now))
  local inv = { id, subject, length, scope, display, band, a, b, self.o.addonVersion or "" }
  if scope == "WHISPER" or scope == "QUEUE" then
    self:Send("WHISPER", target, nil, "INV", unpack(inv))
  else
    self:Send(scope, nil, nil, "INV", unpack(inv))
  end
  self:Notify("lobby", d)
  return d
end

function Engine:SendLobby()
  local d = self.duel
  local f = { d.id, d.subject, d.length, d.scope, #d.order }
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    f[#f + 1] = r.name; f[#f + 1] = r.display; f[#f + 1] = r.band
    f[#f + 1] = r.aA; f[#f + 1] = r.aB; f[#f + 1] = r.status
  end
  d.lastPing = self:Now()
  self:Broadcast("lob", "LOB", unpack(f))
end

function Engine:Start()
  local d = self.duel
  if not d or not d.isHost or d.state ~= "lobby" then return false, "state" end
  -- drop anyone who never joined; they would only be noise in the race
  local keep = {}
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    if r.status == "joined" then keep[#keep + 1] = k else d.racers[k] = nil end
  end
  d.order = keep
  if #keep < D.MIN_RACERS then self:Log("start refused: only %d in the room", #keep) return false, "few" end
  -- v1.1 phrasebook is a two-trader dialogue (one role each)
  local sub = D.SUBJECT_BY_ID[d.subject]
  if sub and sub.coop and #keep ~= 2 then return false, "two" end
  local now = self:Now()
  d.seed = Util.Random(1, 2147483000)
  -- typing races: one passage for everyone, at the youngest racer's level
  local young, yi = nil, 99
  for _, k in ipairs(keep) do
    local bi = D.BandIndex(d.racers[k].band) or 1
    if bi < yi then young, yi = d.racers[k].band, bi end
  end
  d.typeBand = young
  local f = { d.id, d.seed, D.COUNTDOWN, d.typeBand, d.subject, d.length, d.scope, #keep }
  for _, k in ipairs(keep) do
    local r = d.racers[k]
    f[#f + 1] = r.name; f[#f + 1] = r.display; f[#f + 1] = r.band; f[#f + 1] = r.aA; f[#f + 1] = r.aB
    r.status, r.heard = "racing", now
  end
  d.startArgs = f
  local group = d.scope == "PARTY" or d.scope == "RAID" or d.scope == "GUILD"
  if group then self:Send(d.scope, nil, nil, "STA", unpack(f)) end
  for _, k in ipairs(keep) do
    if k ~= self.meKey then self:Reliable(d.racers[k].name, group, "STA", unpack(f)) end
  end
  self:BeginCountdown(now, D.COUNTDOWN)
  return true
end

function Engine:BeginCountdown(now, secs)
  local d = self.duel
  d.state = "countdown"
  d.startAt = now + secs
  d.hostHeard = now
  local band = (self.o.band and self.o.band()) or d.typeBand
  local sub = D.SUBJECT_BY_ID[d.subject]
  d.myBand = (sub and sub.typing) and d.typeBand or band
  -- v1.1: own World Tongues course ("words") and phrasebook role (turn order in the dialogue)
  local role = 0
  for i, k in ipairs(d.order or {}) do if k == self.meKey then role = (i - 1) % 2 end end
  d.role = role
  d.set = D.BuildSet(d.subject, d.myBand, d.seed, d.length, self.o.course and self.o.course() or nil, role)
  d.me = { index = 1, answered = 0, correct = 0, penalty = 0, wpmSum = 0, accSum = 0, log = {}, lastSent = -99 }
  if not d.set then
    self:Log("could not build the questions (%s, %s)", tostring(d.subject), tostring(d.myBand))
    self:Leave("noset")
    return
  end
  if self.queue then self:QueueLeave("matched") end
  self:Log("countdown %ss (seed %s, %d questions)", tostring(secs), tostring(d.seed), #d.set)
  self:Notify("countdown", d)
end

------------------------------------------------------------------------
-- Joining
------------------------------------------------------------------------
function Engine:Accept()
  local inv = self.invite
  if not inv then return false end
  self.invite = nil
  local reason = self:DeclineReason(inv.host, inv.scope)
  if reason then self.invite = inv; self:Decline(reason); return false, reason end
  local now = self:Now()
  local d = { id = inv.id, host = inv.host, hostKey = nkey(inv.host), isHost = false, scope = inv.scope,
    subject = inv.subject, length = inv.length, state = "lobby", racers = {}, order = {}, created = now,
    hostHeard = now, wait = {}, seqOut = 0, stateSeq = -1, emotes = 0, lastEmote = -99 }
  self.duel = d
  self:AddRacer(newRacer(inv.host, inv.display, inv.band, inv.aA, inv.aB, "joined", now))
  local a, b = self:MyAlias()
  local band = self.o.band()
  local display = inv.scope == "QUEUE" and "" or (self.o.display and self.o.display() or D.Short(self.me))
  self:AddRacer(newRacer(self.me, display, band, a, b, "joined", now))
  self:Reliable(inv.host, false, "ACC", inv.id, band, display, a, b, self.o.addonVersion or "")
  self:Notify("lobby", d)
  return true
end

function Engine:Decline(reason)
  local inv = self.invite
  if not inv then return end
  self.invite = nil
  self:Send("WHISPER", inv.host, nil, "DEC", inv.id, reason == "blocked" and "busy" or (reason or "declined"))
  self:Notify("inviteGone", inv, reason or "declined")
end

------------------------------------------------------------------------
-- Racing
------------------------------------------------------------------------
function Engine:Current()
  local d = self.duel
  if not d or d.state ~= "race" or not d.set or not d.me then return nil end
  return d.set[d.me.index], d.me.index
end

function Engine:MyReport()
  local d = self.duel
  local m = d.me
  local elapsed = (m.doneAt or self:Now()) - (d.raceStart or self:Now())
  local typed = m.answered > 0 and m.answered or 1
  return m.answered, m.correct, elapsed, floor(m.wpmSum / typed + 0.5), floor(m.accSum / typed * 100 + 0.5)
end

function Engine:UpdateMeRow()
  local d = self.duel
  local r = d.racers[self.meKey]
  if not r then return end
  local a, c, e, w, acc = self:MyReport()
  r.answered, r.correct, r.elapsed, r.wpm, r.acc = a, c, e, w, acc
  r.time = D.Score(a, c, e)
  if d.me.doneAt and r.status == "racing" then r.status = "finished" end
end

function Engine:SendProgress(final)
  local d = self.duel
  local a, c, e, w, acc = self:MyReport()
  d.seqOut = d.seqOut + 1
  d.me.lastSent = self:Now()
  local f = { d.id, d.seqOut, a, c, floor(e * 1000), w, acc }
  if d.isHost then return end
  if final then
    self:Reliable(d.host, false, "FIN", unpack(f))
  else
    self:Send("WHISPER", d.host, "prg", "PRG", unpack(f))
  end
end

-- Returns correct, info, problem, finished
function Engine:Answer(given)
  local d = self.duel
  local p = self:Current()
  if not p then return nil end
  local now = self:Now()
  local m = d.me
  local dt = now - (m.shownAt or d.raceStart or now)
  local okv, info = ns.Modules.Check(p, given, { elapsed = dt, tier = 1 })
  m.answered = m.answered + 1
  if okv then m.correct = m.correct + 1 else m.penalty = m.penalty + D.PENALTY end
  if type(info) == "table" then
    m.wpmSum = m.wpmSum + (info.wpm or 0)
    m.accSum = m.accSum + (info.accuracy or 0)
  end
  m.log[#m.log + 1] = { nodeId = p.nodeId, correct = okv, dt = dt }
  m.index = m.index + 1
  m.shownAt = now
  local done = m.answered >= d.length
  if done then m.doneAt = now end
  self:UpdateMeRow()
  self:SendProgress(done)
  if d.isHost then self:HostCheckEnd() end
  self:Notify("progress", d)
  return okv, info, p, done
end

------------------------------------------------------------------------
-- Leaving / ending
------------------------------------------------------------------------
function Engine:Leave(reason)
  local d = self.duel
  if not d then return end
  if d.state == "done" or d.state == "cancelled" then self.duel = nil; return end
  local r = d.racers[self.meKey]
  if r then r.status = "left" end
  if d.isHost then
    if d.state == "lobby" then
      self:Broadcast(nil, "CAN", d.id, reason or "left")
    else
      self:Broadcast(nil, "LEV", d.id, reason or "left")
    end
  elseif reason ~= "unreachable" then
    self:Send("WHISPER", d.host, nil, "LEV", d.id, reason or "left")
  end
  d.state = "cancelled"
  d.leftReason = reason
  self:Notify("left", d, reason)
  self.duel = nil
end

function Engine:Close()
  if self:Busy() then self:Leave("left") else self.duel = nil end
end

function Engine:OnCombat()
  if self.invite then self:Decline("combat") end
  if self.queue then self:QueueLeave("combat") end
  if self:Busy() then self:Leave("combat") end
end

function Engine:Rows()
  local d, rows = self.duel, {}
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    rows[#rows + 1] = { name = r.name, key = k, display = D.DisplayFor(r, d.scope), answered = r.answered, correct = r.correct,
      time = r.time, wpm = r.wpm, acc = r.acc, status = r.status, valid = r.valid, isMe = (k == self.meKey) }
  end
  return rows
end

function Engine:HostCheckEnd(force)
  local d = self.duel
  if not d or not d.isHost or d.state ~= "race" then return end
  for _, k in ipairs(d.order) do
    local s = d.racers[k].status
    if s == "racing" then
      if not force then return end
      d.racers[k].status = "dnf"
      d.racers[k].time = D.MaxRace(d.length) + (d.racers[k].answered - d.racers[k].correct) * D.PENALTY
    end
  end
  self:Finish()
  local f = { d.id, #d.order }
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    f[#f + 1] = r.answered; f[#f + 1] = r.correct; f[#f + 1] = floor((r.elapsed or 0) * 1000)
    f[#f + 1] = r.wpm; f[#f + 1] = r.acc; f[#f + 1] = r.status; f[#f + 1] = r.valid and 1 or 0
  end
  local group = d.scope == "PARTY" or d.scope == "RAID" or d.scope == "GUILD"
  if group then self:Send(d.scope, nil, nil, "RES", unpack(f)) end
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    if k ~= self.meKey and r.status ~= "left" then self:Reliable(r.name, group, "RES", unpack(f)) end
  end
end

-- v1.1 co-op phrasebook: one team result (sum of every valid racer), no winner.
function D.TeamUp(d)
  local sub = D.SUBJECT_BY_ID[d.subject or ""]
  if not (sub and sub.coop and d.ranked) then return nil end
  local c, a = 0, 0
  for _, r in ipairs(d.ranked) do
    if r.valid ~= false then c, a = c + (r.correct or 0), a + (r.answered or 0) end
  end
  d.team = { correct = c, answered = a, total = d.length * #d.ranked }
  if d.reward then
    if d.reward.win then d.reward.shards = math.max(0, d.reward.shards - D.REWARD.win) end
    d.reward.win = false
  end
  return d.team
end

-- Local end of the duel (host, or racer on RES / host lost).
function Engine:Finish(partial)
  local d = self.duel
  if d.state == "done" then return end
  d.state = "done"
  d.partial = partial
  self:UpdateMeRow()
  d.ranked = D.Rank(self:Rows())
  d.reward = D.ComputeReward(d.ranked, self.meKey, d.length)
  D.TeamUp(d)
  if not d.rewarded then
    d.rewarded = true
    D.ApplyReward(d)
  end
  self:Notify("result", d)
end

-- Progress side effects. Practice stats only: never the mastery window.
function D.ApplyReward(d)
  local P = ns.Progress
  if not (P and P.char and P.account) then return end
  local rw = d.reward
  local cs = P.char.duel
  cs.played = cs.played + 1
  if rw.win then cs.wins = cs.wins + 1 end
  if rw.finished then cs.finished = cs.finished + 1 end
  rw.shardsGot, rw.rankUp = P.AddShards(rw.shards)
  rw.minutesGot = rw.minutes and P.AwardDuelMinutes(D.REWARD.minutes, D.REWARD.minutesDay) or 0
  local stats = P.char.stats
  for _, e in ipairs((d.me and d.me.log) or {}) do
    local okNode = e.nodeId and ns.Modules.FindNode(e.nodeId)
    if okNode then
      local rec = P.GetTierRec(e.nodeId, 1)
      rec.attempts = rec.attempts + 1
      if e.correct then rec.correct = rec.correct + 1 end
      rec.time = rec.time + min(120, e.dt or 0)
      rec.duel = (rec.duel or 0) + 1
    end
    stats.problems = stats.problems + 1
    if e.correct then stats.firstCorrect = stats.firstCorrect + 1 end
    stats.time = stats.time + min(120, e.dt or 0)
  end
end

------------------------------------------------------------------------
-- Emotes and blocking (preset ids only)
------------------------------------------------------------------------
function Engine:Emote(idx)
  local d = self.duel
  idx = tonumber(idx)
  if not d or not idx or not D.EMOTES[idx] then return false end
  local now = self:Now()
  if now - d.lastEmote < D.EMOTE_GAP or d.emotes >= D.EMOTE_MAX then return false, "slow" end
  d.lastEmote, d.emotes = now, d.emotes + 1
  for _, r in ipairs(self:Others()) do self:Send("WHISPER", r.name, nil, "EMO", d.id, idx) end
  return true
end

------------------------------------------------------------------------
-- Timers: retries, keepalives, silence, countdown, race limit, queue
------------------------------------------------------------------------
function Engine:Update()
  local now = self:Now()
  self.asm:Expire(now)
  local inv = self.invite
  if inv and now - inv.at > D.INVITE_TIMEOUT then self:Decline("timeout") end
  local d = self.duel
  if d and d.state ~= "done" and d.state ~= "cancelled" then
    for k, w in pairs(d.wait) do
      if now - w.at >= D.RETRY then
        if w.tries >= D.MAX_TRIES then
          d.wait[k] = nil
        else
          w.tries, w.at = w.tries + 1, now
          self:Send("WHISPER", w.target, nil, w.mtype, unpack(w.args))
        end
      end
    end
    if d.isHost then self:HostTick(now) else self:RacerTick(now) end
  elseif d and d.state == "done" and d.isHost then
    -- keep re-sending results to racers that have not confirmed them
    for k, w in pairs(d.wait) do
      if now - w.at >= D.RETRY then
        if w.tries >= D.MAX_TRIES then d.wait[k] = nil
        else w.tries, w.at = w.tries + 1, now; self:Send("WHISPER", w.target, nil, w.mtype, unpack(w.args)) end
      end
    end
  end
  self:QueueTick(now)
  self:Flush()
end

function Engine:TickCountdown(now)
  local d = self.duel
  if d.state == "countdown" and now >= d.startAt then
    d.state = "race"
    d.raceStart = d.startAt
    d.me.shownAt = now
    self:Log("race begins")
    self:Notify("race", d)
  end
end

function Engine:HostTick(now)
  local d = self.duel
  if d.state == "lobby" then
    if self:Joined() <= 1 and now - d.created > (d.scope == "QUEUE" and D.QUEUE_MATCH_WAIT or D.LOBBY_TIMEOUT) then
      self:Leave("timeout")
      if self.queue then self.queue.pending = nil end
      return
    end
    if self:Joined() > 1 and now - d.lastPing >= D.LOBBY_PING then self:SendLobby() end
    return
  end
  self:TickCountdown(now)
  if d.state ~= "race" then return end
  local changed = false
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    if k ~= self.meKey and r.status == "racing" and now - r.heard > D.SILENCE then
      r.status = "left"; changed = true
      self:Notify("racerLeft", d, r, "silent")
    end
  end
  if now - d.raceStart > D.MaxRace(d.length) then
    self:HostCheckEnd(true)
    return
  end
  local interval = (d.scope == "WHISPER" or d.scope == "QUEUE") and max(1.2, 1.2 * (#d.order - 1)) or 1
  if changed or (d.stateDirty and now - (d.lastState or -99) >= interval) or now - (d.lastState or -99) >= D.KEEPALIVE then
    self:SendState(now)
  end
  if changed then self:HostCheckEnd() end
end

function Engine:SendState(now)
  local d = self.duel
  d.stateSeq = d.stateSeq + 1
  d.lastState, d.stateDirty = now, false
  local f = { d.id, d.stateSeq, #d.order }
  for _, k in ipairs(d.order) do
    local r = d.racers[k]
    f[#f + 1] = r.answered; f[#f + 1] = r.correct; f[#f + 1] = floor((r.time or 0) * 10); f[#f + 1] = r.status
  end
  self:Broadcast("st8", "ST8", unpack(f))
end

function Engine:RacerTick(now)
  local d = self.duel
  local hostSilent = now - (d.hostHeard or now) > D.SILENCE
  if d.state == "lobby" then
    if now - (d.hostHeard or now) > D.SILENCE * 3 and now - d.created > D.SILENCE * 3 then
      d.state = "cancelled"; self:Notify("cancel", d, "host"); self.duel = nil
    end
    return
  end
  self:TickCountdown(now)
  if d.state ~= "race" then return end
  if hostSilent and not d.hostLost then
    d.hostLost = true
    local h = d.racers[d.hostKey]
    if h and h.status == "racing" then h.status = "left" end
    self:Notify("hostLost", d)
  end
  if not d.me.doneAt and now - d.me.lastSent >= D.KEEPALIVE then self:SendProgress(false) end
  local limit = D.MaxRace(d.length)
  if not d.me.doneAt and now - d.raceStart > limit then
    d.me.doneAt = now
    local r = d.racers[self.meKey]
    self:UpdateMeRow()
    r.status = "dnf"
  end
  -- results never came (host gone, or lost RES): finish with what we know
  if d.me.doneAt and (d.hostLost or now - d.raceStart > limit + D.SILENCE * 2) then
    for _, k in ipairs(d.order) do
      local r = d.racers[k]
      if k ~= self.meKey and r.status == "racing" then r.status = d.hostLost and "left" or "dnf" end
    end
    self:Finish(true)
  end
end

------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------
local H = {}

function Engine:Receive(raw, channel, sender)
  if type(raw) ~= "string" or not sender then return end
  sender = D.Norm(sender, self.o.realm)
  if nkey(sender) == self.meKey then return end
  local now = self:Now()
  raw = self.asm:Feed(raw, sender, now)
  if not raw then return end
  local ver, mtype, f = DP.Decode(raw)
  if not ver then self.stats.dropped = self.stats.dropped + 1; return end
  self.stats.received = self.stats.received + 1
  -- v1.1: read protocol 1 and 2; a language subject arriving as protocol 1 is not ours
  local tooOld = (mtype == "INV" or mtype == "QBC") and ver < D.ProtoFor(f[2])
  if (ver < (DP.MIN_VERSION or DP.VERSION) or ver > DP.VERSION or tooOld) and mtype ~= "VER" then
    if mtype == "INV" then
      -- handshake failure: tell the host which version we speak, tell our kid why
      self:Send("WHISPER", sender, nil, "VER", f[1] or "", DP.VERSION)
      self:Notify("version", D.Short(sender), ver, DP.VERSION)
    end
    self:Log("dropped %s from %s (protocol %s)", tostring(mtype), D.Short(sender), tostring(ver))
    self.stats.dropped = self.stats.dropped + 1
    return
  end
  -- v1.2.4: a message for one player, sent on the group / guild channel
  local last = f[#f]
  if type(last) == "string" and last:sub(1, #D.TO_MARK) == D.TO_MARK then
    f[#f] = nil
    if nkey(last:sub(#D.TO_MARK + 1)) ~= self.meKey then return end
  end
  self:Log("got %s from %s on %s", mtype, D.Short(sender), tostring(channel))
  local h = H[mtype]
  if h then h(self, f, sender, channel, now) end
end

local function num(v, def) return tonumber(v) or def or 0 end

-- returns duel if f[1] matches the current duel id and the sender is its host
function Engine:FromHost(f, sender)
  local d = self.duel
  if not d or d.isHost or d.id ~= f[1] or nkey(sender) ~= d.hostKey then return nil end
  d.hostHeard = self:Now()
  return d
end

function Engine:FromRacer(f, sender)
  local d = self.duel
  if not d or not d.isHost or d.id ~= f[1] then return nil end
  local r = d.racers[nkey(sender)]
  if r then r.heard = self:Now() end
  return d, r
end

H.INV = function(self, f, sender, channel, now)
  local id, subject, length, scope = f[1], f[2], num(f[3], 5), f[4]
  if not id or not D.SUBJECT_BY_ID[subject] then return end
  local sub = D.SUBJECT_BY_ID[subject]
  if not ns.Modules.IsShown(sub.module) then
    self:Send("WHISPER", sender, nil, "DEC", id, "parent")
    return
  end
  if (length ~= 5 and length ~= 10) then return end
  if self.duel and self.duel.id == id then return end
  if self.invite and self.invite.id == id then return end
  local reason = self:DeclineReason(sender, scope)
  local q = self.queue
  if scope == "QUEUE" and not reason then
    if not q or q.subject ~= subject or q.length ~= length or (q.pending and nkey(q.pending) ~= nkey(sender)) then reason = "busy" end
  end
  if reason then
    self:Send("WHISPER", sender, nil, "DEC", id, reason == "blocked" and "busy" or reason)
    self:Notify("autoDecline", scope == "QUEUE" and "" or D.Short(sender), reason, subject)
    return
  end
  self.invite = { id = id, host = sender, scope = scope, subject = subject, length = length,
    display = scope == "QUEUE" and "" or (f[5] ~= "" and f[5] or D.Short(sender)), band = f[6],
    aA = num(f[7], 1), aB = num(f[8], 1), version = f[9], at = now }
  if scope == "QUEUE" then
    q.pending, q.pendingAt = sender, now
    self:Accept()
  else
    self:Notify("invite", self.invite)
  end
end

H.VER = function(self, f, sender)
  local d = self.duel
  local theirs = num(f[2], 0)
  if d and d.isHost and d.id == f[1] then
    d.declined[#d.declined + 1] = { display = D.Short(sender), reason = "version" }
    if d.scope == "WHISPER" or d.scope == "QUEUE" then self:Leave("version") end
  end
  self:Notify("version", D.Short(sender), theirs, DP.VERSION)
end

H.ACC = function(self, f, sender, channel, now)
  local d = self.duel
  if not d or not d.isHost or d.id ~= f[1] then return end
  local k = nkey(sender)
  self:Send("WHISPER", sender, nil, "ACK", d.id, "ACC")
  if d.racers[k] and d.racers[k].status == "joined" then
    if d.state == "lobby" then self:SendLobby() end
    return
  end
  if d.state ~= "lobby" or self:Joined() >= D.MAX_RACERS
    or ((d.scope == "WHISPER" or d.scope == "QUEUE") and nkey(d.target) ~= k) then
    self:Send("WHISPER", sender, nil, "FUL", d.id)
    return
  end
  if self.o.isBlocked and self.o.isBlocked(sender) then
    self:Send("WHISPER", sender, nil, "FUL", d.id)
    return
  end
  local display = d.scope == "QUEUE" and "" or (f[3] ~= "" and f[3] or D.Short(sender))
  local r = self:AddRacer(newRacer(sender, display, f[2], f[4], f[5], "joined", now))
  r.version = f[6]
  self:Log("%s joined the room (v%s)", D.Short(sender), tostring(f[6]))
  self:SendLobby()
  self:Notify("lobby", d, r)
  if d.scope == "QUEUE" then self:Start() end
end

H.DEC = function(self, f, sender)
  local d = self.duel
  if not d or not d.isHost or d.id ~= f[1] then return end
  local reason = f[2] or "declined"
  local disp = d.scope == "QUEUE" and "" or D.Short(sender)
  d.declined[#d.declined + 1] = { display = disp, reason = reason }
  self:Notify("declined", d, disp, reason)
  if (d.scope == "WHISPER" or d.scope == "QUEUE") and d.state == "lobby" then
    if self.queue then self.queue.pending = nil end
    self:Leave("declined")
  end
end

H.FUL = function(self, f, sender)
  local d = self:FromHost(f, sender)
  if d and d.state == "lobby" then
    d.state = "cancelled"; self.duel = nil
    self:Notify("cancel", d, "full")
  end
end

H.CAN = function(self, f, sender)
  local d = self:FromHost(f, sender)
  if d and (d.state == "lobby" or d.state == "countdown") then
    d.state = "cancelled"; self.duel = nil
    self:Notify("cancel", d, f[2] or "host")
  end
  if self.invite and self.invite.id == f[1] and nkey(self.invite.host) == nkey(sender) then
    local inv = self.invite
    self.invite = nil
    self:Notify("inviteGone", inv, "cancelled")
  end
end

H.ACK = function(self, f, sender)
  local d = self.duel
  if not d or d.id ~= f[1] then return end
  d.wait[nkey(sender) .. "|" .. tostring(f[2])] = nil
  if d.isHost then local r = d.racers[nkey(sender)]; if r then r.heard = self:Now() end
  else d.hostHeard = self:Now() end
end

H.LOB = function(self, f, sender, channel, now)
  local d = self:FromHost(f, sender)
  if not d or d.state ~= "lobby" then return end
  d.wait[d.hostKey .. "|ACC"] = nil
  local n = min(num(f[5], 0), D.MAX_RACERS)
  local seen = {}
  for i = 0, n - 1 do
    local b = 6 + i * 6
    local name = f[b]
    if name then
      local k = nkey(name)
      seen[k] = true
      local r = d.racers[k] or self:AddRacer(newRacer(name, f[b + 1], f[b + 2], f[b + 3], f[b + 4], "joined", now))
      if k ~= self.meKey then
        r.display, r.band, r.aA, r.aB, r.status = d.scope == "QUEUE" and "" or (f[b + 1] or ""), f[b + 2], num(f[b + 3], 1), num(f[b + 4], 1), f[b + 5] or "joined"
      end
    end
  end
  if not seen[self.meKey] then
    -- the host does not list us (yet); keep our ACC retrying
    return
  end
  self:Notify("lobby", d)
end

H.STA = function(self, f, sender, channel, now)
  local d = self.duel
  if not d or d.isHost or d.id ~= f[1] or nkey(sender) ~= d.hostKey then return end
  d.hostHeard = now
  self:Send("WHISPER", sender, nil, "ACK", d.id, "STA")
  if d.state ~= "lobby" then return end
  d.wait[d.hostKey .. "|ACC"] = nil
  local n = min(num(f[8], 0), D.MAX_RACERS)
  local racers, order, inIt = {}, {}, false
  for i = 0, n - 1 do
    local b = 9 + i * 5
    local name = f[b]
    if name then
      local r = newRacer(name, d.scope == "QUEUE" and "" or f[b + 1], f[b + 2], f[b + 3], f[b + 4], "racing", now)
      if r.key == self.meKey then inIt = true end
      racers[r.key] = r; order[#order + 1] = r.key
    end
  end
  if not inIt then
    d.state = "cancelled"; self.duel = nil
    self:Notify("cancel", d, "full")
    return
  end
  d.racers, d.order = racers, order
  d.seed, d.typeBand = num(f[2], 1), f[4]
  self:BeginCountdown(now, Util.Clamp(num(f[3], D.COUNTDOWN), 0, 10))
end

local function applyReport(self, d, r, f, final)
  local seq = num(f[2], 0)
  local rep = { answered = num(f[3], -1), correct = num(f[4], -1), elapsed = num(f[5], -1) / 1000, wpm = num(f[6], 0), acc = num(f[7], 0) }
  if seq <= r.seq and not final then return end -- stale / duplicate / out of order
  if r.status ~= "racing" and not (final and r.status == "finished") then return end
  if seq > r.seq then
    r.seq = seq
    local hostElapsed = self:Now() - (d.raceStart or d.startAt or self:Now())
    local ok = D.Validate(rep, r, d.length, max(0, hostElapsed))
    if not ok then
      r.valid = false
      self:Notify("invalid", d, r)
    else
      r.answered, r.correct, r.elapsed, r.wpm, r.acc = rep.answered, rep.correct, rep.elapsed, rep.wpm, rep.acc
      r.time = D.Score(rep.answered, rep.correct, rep.elapsed)
    end
    if final then r.status = "finished" end
    d.stateDirty = true
  end
end

H.PRG = function(self, f, sender)
  local d, r = self:FromRacer(f, sender)
  if not d or not r or (d.state ~= "race" and d.state ~= "countdown") then return end
  applyReport(self, d, r, f, false)
  self:Notify("state", d)
end

H.FIN = function(self, f, sender)
  local d, r = self:FromRacer(f, sender)
  if not d or not r then return end
  self:Send("WHISPER", sender, nil, "ACK", d.id, "FIN")
  if d.state ~= "race" and d.state ~= "countdown" then return end
  applyReport(self, d, r, f, true)
  self:Notify("state", d)
  self:HostCheckEnd()
end

H.ST8 = function(self, f, sender)
  local d = self:FromHost(f, sender)
  if not d or (d.state ~= "race" and d.state ~= "countdown") then return end
  local seq = num(f[2], 0)
  if seq <= d.stateSeq then return end
  d.stateSeq = seq
  local n = min(num(f[3], 0), #d.order)
  for i = 1, n do
    local k = d.order[i]
    local b = 4 + (i - 1) * 4
    local r = d.racers[k]
    if r and k ~= self.meKey then
      r.answered, r.correct, r.time = num(f[b], 0), num(f[b + 1], 0), num(f[b + 2], 0) / 10
      r.status = f[b + 3] or r.status
    end
  end
  self:Notify("state", d)
end

H.RES = function(self, f, sender)
  local d = self.duel
  if not d or d.isHost or d.id ~= f[1] or nkey(sender) ~= d.hostKey then return end
  self:Send("WHISPER", sender, nil, "ACK", d.id, "RES")
  if d.state == "done" and not d.partial then return end
  local n = min(num(f[2], 0), #d.order)
  for i = 1, n do
    local k = d.order[i]
    local b = 3 + (i - 1) * 7
    local r = d.racers[k]
    if r then
      r.answered, r.correct, r.elapsed = num(f[b], 0), num(f[b + 1], 0), num(f[b + 2], 0) / 1000
      r.wpm, r.acc, r.status, r.valid = num(f[b + 3], 0), num(f[b + 4], 0), f[b + 5] or "finished", f[b + 6] ~= "0"
      r.time = r.status == "dnf" and (D.MaxRace(d.length) + (r.answered - r.correct) * D.PENALTY) or D.Score(r.answered, r.correct, r.elapsed)
      if k == self.meKey then r.mine = true end
    end
  end
  if d.state == "done" then
    -- we had finished locally (partial) and the real results arrived late: re-rank only
    d.ranked = D.Rank(self:Rows())
    d.partial = false
    D.TeamUp(d)
    self:Notify("result", d)
    return
  end
  d.me = d.me or { index = 1, answered = 0, correct = 0, penalty = 0, wpmSum = 0, accSum = 0, log = {}, lastSent = 0 }
  if not d.me.doneAt then d.me.doneAt = self:Now() end
  self:FinishFromHost()
end

function Engine:FinishFromHost()
  local d = self.duel
  d.state = "done"
  d.ranked = D.Rank(self:Rows())
  d.reward = D.ComputeReward(d.ranked, self.meKey, d.length)
  D.TeamUp(d)
  if not d.rewarded then d.rewarded = true; D.ApplyReward(d) end
  self:Notify("result", d)
end

H.LEV = function(self, f, sender)
  local d = self.duel
  if not d or d.id ~= f[1] then return end
  local k = nkey(sender)
  local r = d.racers[k]
  if not r then return end
  if d.isHost then
    if d.state == "lobby" then
      r.status = "left"
      self:SendLobby()
      self:Notify("lobby", d)
    elseif d.state == "countdown" or d.state == "race" then
      if r.status == "racing" then r.status = "left" end
      d.stateDirty = true
      self:Notify("racerLeft", d, r, f[2])
      self:HostCheckEnd()
    end
  elseif k == d.hostKey then
    if d.state == "countdown" or d.state == "race" then
      d.hostLost = true
      r.status = "left"
      self:Notify("hostLost", d)
    end
  end
end

H.EMO = function(self, f, sender)
  local d = self.duel
  if not d or d.id ~= f[1] then return end
  local r = d.racers[nkey(sender)]
  local idx = num(f[2], 0)
  if not r or not D.EMOTES[idx] then return end
  if self.o.isBlocked and self.o.isBlocked(sender) then return end
  local now = self:Now()
  if r.lastEmote and now - r.lastEmote < D.EMOTE_GAP - 0.5 then return end
  r.emotes = (r.emotes or 0) + 1
  if r.emotes > D.EMOTE_MAX then return end
  r.lastEmote = now
  self:Notify("emote", d, D.DisplayFor(r, d.scope), idx)
end

------------------------------------------------------------------------
-- Phase 2: random challengers (parent-gated, OFF by default)
-- Queued clients sit in a hidden custom channel and send a tiny beacon:
-- subject, length, band, nonce. Nothing else about the player is sent. When
-- two beacons match (same subject + length, bands at most one apart), the
-- smaller nonce hosts and whispers a "QUEUE" invite, which the other side
-- auto-accepts because it asked for exactly that match. Names are never shown:
-- both sides only see each other's preset alias.
------------------------------------------------------------------------
function Engine:QueueAllowed()
  local st, ctx = self:Settings(), self:Context()
  if st.enabled == false or not st.random then return false, "parent" end
  if st.friendsOnly then return false, "friendsOnly" end
  if ctx.combat then return false, "combat" end
  if ctx.instance then return false, "instance" end
  if self:Busy() then return false, "busy" end
  if not (self.o.band and self.o.band()) then return false, "band" end
  return true
end

function Engine:QueueJoin(subject, length)
  local okq, why = self:QueueAllowed()
  if not okq then return false, why end
  if not D.SUBJECT_BY_ID[subject] then return false, "subject" end
  local now = self:Now()
  self.queue = { subject = subject, length = (tonumber(length) == 10) and 10 or 5, since = now, lastBeacon = -99,
    nonce = string.format("%09d", Util.Random(1, 999999999)) }
  if self.o.queueJoin then self.o.queueJoin() end
  self:Notify("queue", "searching", self.queue)
  return true
end

function Engine:QueueLeave(reason)
  if not self.queue then return end
  local q = self.queue
  self.queue = nil
  if self.o.queueLeave then self.o.queueLeave() end
  self:Notify("queue", reason or "left", q)
end

function Engine:QueueTick(now)
  local q = self.queue
  if not q then return end
  if now - q.since > D.QUEUE_MAX then self:QueueLeave("timeout"); return end
  local okq, why = self:QueueAllowed()
  if not okq and not (why == "busy" and q.pending) then self:QueueLeave(why); return end
  if q.pending then
    if now - (q.pendingAt or now) > D.QUEUE_MATCH_WAIT and not self:Busy() then q.pending = nil end
    return
  end
  if self:Busy() then return end
  local chan = self.o.queueChannel and self.o.queueChannel()
  if chan and now - q.lastBeacon >= D.QUEUE_BEACON then
    q.lastBeacon = now
    self:Send("CHANNEL", chan, "q", "Q", q.subject, q.length, self.o.band() or "", q.nonce)
  end
end

H.Q = function(self, f, sender, channel, now)
  local q = self.queue
  if not q or q.pending or self:Busy() or channel ~= "CHANNEL" then return end
  local subject, length, band, nonce = f[1], num(f[2], 0), f[3], tostring(f[4] or "")
  if subject ~= q.subject or length ~= q.length or nonce == "" or nonce == q.nonce then return end
  if self.o.isBlocked and self.o.isBlocked(sender) then return end
  local sub = D.SUBJECT_BY_ID[subject]
  local mod = sub and ns.Modules.Get(sub.module)
  local mine, theirs = D.BandIndex(self.o.band()), D.BandIndex(band)
  if not mod then return end
  if not mod.unbanded and (not mine or not theirs or math.abs(mine - theirs) > 1) then return end
  if q.nonce < nonce then
    q.pending, q.pendingAt = sender, now
    local d = self:Host(subject, length, "QUEUE", sender)
    if not d then q.pending = nil end
  else
    -- they host; make sure they hear our beacon soon
    if now - q.lastBeacon > 2 then q.lastBeacon = -99 end
  end
end

D.Engine = Engine

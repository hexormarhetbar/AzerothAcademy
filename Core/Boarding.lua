-- Murloc Boarding Party (v0.6): a typing mini-game inside Scribe's Scrolls. Pure logic.
-- You crew a Steamwheedle ship out of Booty Bay. Murlocs climb aboard in waves, each
-- carrying a crew order. Typing an order sends the crew to knock that murloc overboard.
-- Murlocs creep from the rail (pos 0) toward the captain's wheel (pos B.DECK). Typos make
-- the crew stumble but never undo typed letters. Clean knockouts fill the broadside meter;
-- a full meter fires a broadside that clears the deck. After the last wave comes the
-- Murloc Tidehunter carrying a whole sentence.
--   Initiate: letters and short words, slow, no fail state (murlocs wait at the wheel).
--   Adept: crew orders, three "steady wheel" points.
--   Magister: full sentences, case and punctuation count, timed with WPM and a par time.
local _, ns = ...
local Util = ns.Util

local B = {}
ns.Boarding = B

B.DECK = 100
B.WAIT_AT = 94          -- no-fail band: murlocs stop here and wait
B.METER_MAX = 6         -- broadside meter points (+1 per knockout, +1 more when clean)
B.WAVE_BREAK = 2.5      -- seconds between waves
B.STUN = 3              -- broadside stuns the Tidehunter this long
B.EMPTY_DECK_WAIT = 1.0 -- with nobody on deck the next murloc arrives within this many seconds
B.LOG_SIZE = 10

B.ROUTES = {
  { id = "bootybay",  key = "BOARD_ROUTE_BOOTYBAY",  waves = 2, pace = 1.00, icon = "Interface\\Icons\\INV_Misc_Coin_02" },
  { id = "ratchet",   key = "BOARD_ROUTE_RATCHET",   waves = 3, pace = 0.88, icon = "Interface\\Icons\\INV_Misc_Anchor", unlock = "bootybay" },
  { id = "maelstrom", key = "BOARD_ROUTE_MAELSTROM", waves = 4, pace = 0.76, icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental", unlock = "ratchet" },
}
B.ROUTE_BY_ID = {}
for i, r in ipairs(B.ROUTES) do r.index = i; B.ROUTE_BY_ID[r.id] = r end

-- cross = seconds for a murloc to walk the whole deck: base + perChar * #order (x route pace)
-- cps = design typing speed (chars/second): new murlocs arrive no faster than that
B.BANDS = {
  initiate = { perWave = { 3, 4, 4, 5 }, maxOnDeck = 2, gap = 5.0, cps = 0.35, base = 26, perChar = 3.0,
    failState = false, timed = false, exact = false, bossSlow = 1.6, shardsPer = 2 },
  adept    = { perWave = { 3, 4, 4, 5 }, maxOnDeck = 3, gap = 4.0, cps = 0.85, base = 14, perChar = 2.4,
    failState = true, wheel = 3, timed = false, exact = false, bossSlow = 1.5, shardsPer = 2 },
  magister = { perWave = { 2, 3, 3, 4 }, maxOnDeck = 3, gap = 5.0, cps = 1.8, base = 10, perChar = 1.2,
    failState = true, wheel = 3, timed = true, exact = true, bossSlow = 1.4, shardsPer = 3,
    par = { bootybay = 150, ratchet = 215, maelstrom = 285 } },
}

-- Typing form of an order. Younger bands: lowercase, punctuation skipped automatically.
-- Returns need (string to type) and map[i] = index in the shown text of need char i.
function B.Prepare(text, exact)
  local need, map = {}, {}
  local lastSpace = true
  for i = 1, #text do
    local c = text:sub(i, i)
    if exact then
      if c ~= " " or not lastSpace then need[#need + 1] = c; map[#need] = i end
      lastSpace = (c == " ")
    elseif c:match("%w") then
      need[#need + 1] = c:lower(); map[#need] = i; lastSpace = false
    elseif c == " " and not lastSpace then
      need[#need + 1] = " "; map[#need] = i; lastSpace = true
    end
  end
  while need[#need] == " " do need[#need] = nil; map[#map] = nil end
  return table.concat(need), map
end

-- How much of the shown text is covered after `progress` typed chars (punctuation that
-- follows the last typed char is covered too, because it is skipped automatically).
function B.Covered(m, progress)
  if progress <= 0 then return 0 end
  if progress >= #m.need then return #m.text end
  return m.map[progress]
end

-- Order pools per band; Initiate starts with letters and moves to words.
local function pool(band, wave)
  local D = ns.BoardingData
  if band == "initiate" then return wave <= 1 and D.LETTERS or D.WORDS end
  if band == "adept" then return D.PHRASES end
  return D.SENTENCES
end

-- Game ---------------------------------------------------------------------------------
local Game = {}
Game.__index = Game

function B.New(bandId, routeId)
  local cfg = B.BANDS[bandId]
  local route = B.ROUTE_BY_ID[routeId or "bootybay"]
  if not (cfg and route) then return nil end
  local g = setmetatable({
    band = bandId, cfg = cfg, route = route, routeId = route.id,
    time = 0, wave = 0, waveSpawned = 0, waveSize = 0, spawnTimer = 0, breakTimer = 0,
    murlocs = {}, events = {}, nextId = 0,
    typed = "", target = nil,
    meter = 0, streak = 0, bestStreak = 0,
    splashed = 0, typos = 0, chars = 0, wheelHits = 0,
    wheel = cfg.failState and cfg.wheel or nil,
    bossSpawned = false, done = false, won = false, paused = false,
    bags = {},
  }, Game)
  g:NextWave()
  return g
end

function Game:Emit(kind, m, extra)
  local e = { type = kind, murloc = m }
  if extra then for k, v in pairs(extra) do e[k] = v end end
  self.events[#self.events + 1] = e
  return e
end

function Game:PopEvents()
  local e = self.events
  self.events = {}
  return e
end

-- No repeats until the pool is used up; never two identical orders on deck at once.
function Game:Draw(list)
  local bag = self.bags[list]
  if not bag or #bag == 0 then
    bag = {}
    for i = 1, #list do bag[i] = list[i] end
    Util.Shuffle(bag)
    self.bags[list] = bag
  end
  for i = #bag, 1, -1 do
    local text = bag[i]
    local clash = false
    for _, m in ipairs(self.murlocs) do
      local n = B.Prepare(text, self.cfg.exact)
      if m.need:sub(1, 1) == n:sub(1, 1) then clash = true end
    end
    if not clash or i == 1 then return table.remove(bag, i) end
  end
  return table.remove(bag)
end

function Game:CrossTime(need, boss)
  local t = (self.cfg.base + self.cfg.perChar * #need) * self.route.pace
  if boss then t = t * self.cfg.bossSlow end
  return t
end

function Game:Spawn(text, boss)
  self.nextId = self.nextId + 1
  local need, map = B.Prepare(text, self.cfg.exact)
  local m = { id = self.nextId, text = text, need = need, map = map, pos = 0, boss = boss or false,
    typos = 0, stun = 0, lane = (self.nextId - 1) % 3 + 1 }
  m.speed = B.DECK / self:CrossTime(need, boss)
  self.murlocs[#self.murlocs + 1] = m
  self:Emit(boss and "boss" or "spawn", m)
  return m
end

function Game:NextWave()
  self.wave = self.wave + 1
  self.waveSpawned = 0
  self.waveSize = self.cfg.perWave[math.min(self.wave, #self.cfg.perWave)]
  self.spawnTimer = 0.5
  self:Emit("wave", nil, { wave = self.wave, waves = self.route.waves })
end

function Game:Alive(includeBoss)
  local n = 0
  for _, m in ipairs(self.murlocs) do if includeBoss or not m.boss then n = n + 1 end end
  return n
end

function Game:Remove(m)
  for i, x in ipairs(self.murlocs) do
    if x == m then table.remove(self.murlocs, i) break end
  end
  if self.target == m then self.target, self.typed = nil, "" end
end

function Game:Finish(won)
  if self.done then return end
  self.done, self.won = true, won
  self.target, self.typed = nil, ""
  self:Emit(won and "win" or "lose")
end

function Game:Tick(dt)
  if self.done or self.paused then return end
  dt = math.max(0, math.min(dt or 0, 0.5)) -- a long hitch must not teleport murlocs
  self.time = self.time + dt
  -- spawning
  if self.breakTimer > 0 then
    self.breakTimer = self.breakTimer - dt
    if self.breakTimer <= 0 then self:NextWave() end
  elseif not self.bossSpawned then
    self.spawnTimer = self.spawnTimer - dt
    -- an empty deck means the crew is quick: the next murloc climbs up right away
    if self:Alive() == 0 and self.spawnTimer > B.EMPTY_DECK_WAIT then self.spawnTimer = B.EMPTY_DECK_WAIT end
    if self.waveSpawned < self.waveSize and self.spawnTimer <= 0 and self:Alive() < self.cfg.maxOnDeck then
      local m = self:Spawn(self:Draw(pool(self.band, self.wave)))
      self.waveSpawned = self.waveSpawned + 1
      -- the next one comes when a kid at the band's design speed could have typed this one
      self.spawnTimer = math.max(self.cfg.gap, #m.need / self.cfg.cps * self.route.pace)
    end
  end
  -- creeping toward the wheel
  for i = #self.murlocs, 1, -1 do
    local m = self.murlocs[i]
    if m.stun > 0 then
      m.stun = m.stun - dt
    else
      m.pos = m.pos + m.speed * dt
    end
    if not self.cfg.failState then
      if m.pos >= B.WAIT_AT then
        m.pos = B.WAIT_AT
        if not m.waiting then m.waiting = true; self:Emit("atWheel", m) end
      end
    elseif m.pos >= B.DECK then
      self.wheel = self.wheel - 1
      self.wheelHits = self.wheelHits + 1
      self.streak = 0
      self:Emit("wheel", m, { left = self.wheel })
      if m.boss then
        m.pos = B.DECK * 0.4 -- the crew shoves the Tidehunter back, it keeps coming
      else
        self:Remove(m)
      end
      if self.wheel <= 0 then self:Finish(false) return end
    end
  end
  -- wave over?
  if not self.bossSpawned and self.breakTimer <= 0 and self.waveSpawned >= self.waveSize and self:Alive() == 0 then
    if self.wave < self.route.waves then
      self.breakTimer = B.WAVE_BREAK
      self:Emit("waveClear", nil, { wave = self.wave })
    else
      self.bossSpawned = true
      self:Spawn(Util.Pick(ns.BoardingData.BOSS[self.band]), true)
    end
  end
end

function Game:Knockout(m)
  local clean = m.typos == 0
  self.splashed = self.splashed + 1
  self.streak = self.streak + 1
  if self.streak > self.bestStreak then self.bestStreak = self.streak end
  local was = self.meter
  self.meter = math.min(B.METER_MAX, self.meter + (clean and 2 or 1))
  self:Remove(m)
  self:Emit("splash", m, { clean = clean, streak = self.streak })
  if was < B.METER_MAX and self.meter >= B.METER_MAX then self:Emit("broadsideReady") end
  if m.boss then self:Finish(true) end
end

local function norm(self, c) return self.cfg.exact and c or c:lower() end

-- Feed the whole edit-box text. Returns the text the box should show (typos are refused,
-- so the box goes back to the last good text) and a status:
--   "ok" (progress), "back" (backspace), "stumble" (typo), "splash" (order finished), "idle"
function Game:Input(text)
  if self.done or self.paused then return "", "idle" end
  text = text or ""
  if text == self.typed then return text, "idle" end
  if #text < #self.typed and self.typed:sub(1, #text) == text then
    self.typed = text
    if text == "" then self.target = nil end
    return text, "back"
  end
  if text:sub(1, #self.typed) ~= self.typed then return self.typed, "idle" end -- edited in the middle
  local status = "ok"
  for i = #self.typed + 1, #text do
    local c = norm(self, text:sub(i, i))
    if not self.target then
      if c == " " then return self.typed, "idle" end
      local best
      for _, m in ipairs(self.murlocs) do
        if m.need:sub(1, 1) == c and (not best or m.pos > best.pos) then best = m end
      end
      if not best then
        self.typos = self.typos + 1
        self.streak = 0
        self:Emit("stumble")
        return self.typed, "stumble"
      end
      self.target = best
      self:Emit("target", best)
    end
    local m = self.target
    local want = m.need:sub(#self.typed + 1, #self.typed + 1)
    if c == want then
      self.typed = self.typed .. text:sub(i, i)
      self.chars = self.chars + 1
      if #self.typed >= #m.need then
        self:Knockout(m)
        return "", "splash"
      end
    else
      self.typos = self.typos + 1
      m.typos = m.typos + 1
      self.streak = 0
      self:Emit("stumble", m)
      return self.typed, "stumble"
    end
  end
  return self.typed, status
end

-- Let go of the current target (the box is cleared; letters typed so far are dropped).
function Game:ClearTarget()
  self.target, self.typed = nil, ""
end

function Game:BroadsideReady() return self.meter >= B.METER_MAX and not self.done end

function Game:Broadside()
  if not self:BroadsideReady() then return false end
  self.meter = 0
  local cleared = 0
  for i = #self.murlocs, 1, -1 do
    local m = self.murlocs[i]
    if m.boss then
      m.pos, m.stun = 0, B.STUN
      self:Emit("bossHit", m)
    else
      table.remove(self.murlocs, i)
      cleared = cleared + 1
      self.splashed = self.splashed + 1
      self:Emit("splash", m, { broadside = true })
    end
  end
  if self.target and not self.target.boss then self.target, self.typed = nil, "" end
  self:Emit("broadside", nil, { cleared = cleared })
  return true, cleared
end

function Game:WPM()
  if self.time < 1 then return 0 end
  return math.floor(self.chars / 5 / (self.time / 60) + 0.5)
end

function Game:Accuracy()
  local total = self.chars + self.typos
  if total == 0 then return 100 end
  return math.floor(self.chars / total * 100 + 0.5)
end

function Game:Par() return self.cfg.par and self.cfg.par[self.routeId] or nil end

-- Progress (saved under char.modules.scribe.boarding; created on first play) -----------
local DEFAULTS = { voyages = 0, wins = 0, splashed = 0, typos = 0, chars = 0, time = 0 }

function B.State()
  local st = ns.Progress.GetModuleState("scribe")
  if type(st.boarding) ~= "table" then st.boarding = {} end
  local b = Util.ApplyDefaults(st.boarding, DEFAULTS)
  if type(b.best) ~= "table" then b.best = {} end
  if type(b.cleared) ~= "table" then b.cleared = {} end
  if type(b.log) ~= "table" then b.log = {} end
  return b
end

function B.Unlocked(routeId)
  local r = B.ROUTE_BY_ID[routeId]
  if not r then return false end
  if not r.unlock then return true end
  local s = ns.Progress.account and ns.Progress.account.settings
  if s and s.unlockAllTiers then return true end
  local cleared = B.State().cleared
  for _, v in pairs(cleared) do if type(v) == "table" and v[r.unlock] then return true end end
  return false
end

function B.BestRoute()
  local best = B.ROUTES[1].id
  for _, r in ipairs(B.ROUTES) do if B.Unlocked(r.id) then best = r.id end end
  return best
end

-- Score the finished game, save it, pay shards. Returns a summary for the result screen.
function B.Record(g, now)
  local st = B.State()
  local P = ns.Progress
  local wpm, acc = g:WPM(), g:Accuracy()
  local r = { band = g.band, routeId = g.routeId, won = g.won, splashed = g.splashed, typos = g.typos,
    chars = g.chars, time = math.floor(g.time + 0.5), wpm = wpm, accuracy = acc, bestStreak = g.bestStreak,
    wheelHits = g.wheelHits, date = now or Util.Now() }
  local shards = g.splashed * g.cfg.shardsPer
  if g.won then shards = shards + 10 end
  st.cleared[g.band] = type(st.cleared[g.band]) == "table" and st.cleared[g.band] or {}
  local nextRoute = B.ROUTES[g.route.index + 1]
  local wasUnlocked = nextRoute and B.Unlocked(nextRoute.id)
  if g.won and not st.cleared[g.band][g.routeId] then
    st.cleared[g.band][g.routeId] = true
    r.firstClear = true
    shards = shards + 15
  end
  if nextRoute and not wasUnlocked and B.Unlocked(nextRoute.id) then r.unlocked = nextRoute.id end
  local par = g:Par()
  if par and g.won then
    r.par = par
    if g.time <= par then r.underPar = true; shards = shards + 5 end
  end
  local best = st.best[g.band]
  if type(best) ~= "table" then best = { wpm = 0, accuracy = 0 }; st.best[g.band] = best end
  if g.chars >= 10 and wpm > (best.wpm or 0) then best.wpm = wpm; r.newBestWpm = true end
  if g.won and (not best.time or g.time < best.time) and g.routeId == "maelstrom" then best.time = r.time end
  st.voyages = st.voyages + 1
  if g.won then st.wins = st.wins + 1 end
  st.splashed = st.splashed + g.splashed
  st.typos = st.typos + g.typos
  st.chars = st.chars + g.chars
  st.time = st.time + r.time
  r.shards = shards
  local _, rankUp = P.AddShards(shards)
  r.rankUp = rankUp
  P.char.stats.rounds = P.char.stats.rounds + 1
  P.char.stats.time = P.char.stats.time + r.time
  table.insert(st.log, 1, { date = r.date, band = r.band, route = r.routeId, won = r.won, wpm = wpm, accuracy = acc, splashed = r.splashed })
  while #st.log > B.LOG_SIZE do table.remove(st.log) end
  return r
end

-- Parent report lines (Scribe's Scrolls section). Empty until the first voyage.
function B.ReportLines()
  local st = B.State()
  if st.voyages == 0 then return {} end
  local L = ns.L
  local out = {}
  out[#out + 1] = string.format("  Murloc Boarding Party: %d voyages (%d won), %d murlocs splashed, accuracy %s, time %s",
    st.voyages, st.wins, st.splashed,
    (st.chars + st.typos) > 0 and string.format("%d%%", math.floor(st.chars / (st.chars + st.typos) * 100 + 0.5)) or "-",
    Util.FormatDuration(st.time))
  local bests = {}
  for _, b in ipairs(ns.Progress.BANDS) do
    local best = st.best[b.id]
    if type(best) == "table" and (best.wpm or 0) > 0 then bests[#bests + 1] = L[b.key] .. " " .. best.wpm .. " WPM" end
  end
  if #bests > 0 then out[#out + 1] = "  Best typing speed: " .. table.concat(bests, ", ") end
  local routes = {}
  for _, r in ipairs(B.ROUTES) do
    routes[#routes + 1] = L[r.key] .. (B.Unlocked(r.id) and "" or " (locked)")
  end
  out[#out + 1] = "  Routes: " .. table.concat(routes, ", ")
  local last = st.log[1]
  if last then
    local route = B.ROUTE_BY_ID[last.route]
    out[#out + 1] = string.format("  Last voyage: %s, %s, %d WPM, %d%% accuracy", route and L[route.key] or tostring(last.route),
      last.won and "won" or "lost", last.wpm or 0, last.accuracy or 0)
  end
  return out
end

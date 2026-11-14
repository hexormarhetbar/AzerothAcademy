-- Mechanics Academy (module #7, group tactics with reading and math drills, v0.13), hosted by
-- Coach Brakka Steelwhistle at the Training Ring in Gadgetzan. Generators + registry + the
-- Tactics Deck book. Pure Lua (no WoW API).
--
-- Class and race lists depend on the game client: Adapters/Compat.lua sets
-- ns.Env.modernClasses = true on clients that have the newer classes and races (Retail);
-- WoW Forever and Classic Era use the original nine classes and eight races.
-- "Avoid the fire" puzzles carry p.grid = { w, h, fire = {{x, y, label}}, marks, bot, icons }
-- drawn by UI/Widgets.lua W.Grid; the harness re-checks every answer square.
local _, ns = ...
local Util = ns.Util
local D = ns.MechanicsData
local NA = ns.Naturalist
local random, floor, abs = Util.Random, math.floor, math.abs

local MA = {}
ns.Mechanics = MA

MA.MODULE_ID = "mechanics"
MA.MAX_TEXT = 480
MA.MAX_CHOICE = 80
MA.HERO_ICON = "Interface\\Icons\\Ability_Warrior_BattleShout"

local function L() return ns.L end
-- capitalized: boss names ("the Sand Wyrm") can start a sentence
local function fmt(key, ...) return (string.format(ns.L[key], ...):gsub("^%l", string.upper)) end
local function pick(t) return t[random(1, #t)] end
local function choices(answer, distractors, n) return ns.Modules.TextChoices(answer, distractors, n) end
local LevelFor = NA.LevelFor

local function curated(bagKey, list, band, hintKey)
  return function(level)
    return NA.FromEntry(NA.Draw("mech_" .. bagKey, list, level), band, hintKey)
  end
end

local function names(n)
  local out = {}
  for i, v in ipairs(Util.Shuffle({ unpack(D.NAMES) })) do if i <= n then out[i] = v end end
  return out
end

------------------------------------------------------------------------
-- Client-dependent lists (Compat decides; tests flip ns.Env.modernClasses)
------------------------------------------------------------------------
function MA.Modern() return ns.Env and ns.Env.modernClasses == true end

function MA.Classes(filter)
  local out = {}
  for _, c in ipairs(D.CLASSES) do
    if (not c.modern or MA.Modern()) and (not filter or filter(c)) then out[#out + 1] = c end
  end
  return out
end

function MA.Races()
  local out = {}
  for _, r in ipairs(D.RACES) do if not r.modern or MA.Modern() then out[#out + 1] = r end end
  return out
end

local function others(list, except, n)
  local out = {}
  for _, v in ipairs(Util.Shuffle({ unpack(list) })) do
    if v ~= except and #out < n then out[#out + 1] = v end
  end
  return out
end

------------------------------------------------------------------------
-- Fire grid helpers (pure)
------------------------------------------------------------------------
MA.NEIGHBORS = { U = { 0, -1 }, D = { 0, 1 }, L = { -1, 0 }, R = { 1, 0 } }
MA.DIR_ORDER = { "U", "D", "L", "R" }

local function key(x, y) return y * 100 + x end

function MA.FireSet(grid)
  local s = {}
  for _, f in ipairs(grid.fire or {}) do s[key(f[1], f[2])] = true end
  return s
end

-- next to fire (up/down/left/right)?
function MA.NearFire(fires, x, y)
  for _, d in pairs(MA.NEIGHBORS) do if fires[key(x + d[1], y + d[2])] then return true end end
  return false
end

local function randomCells(w, h, n, avoid)
  local out, used = {}, {}
  for k in pairs(avoid or {}) do used[k] = true end
  local guard = 0
  while #out < n and guard < 500 do
    guard = guard + 1
    local x, y = random(1, w), random(1, h)
    if not used[key(x, y)] then used[key(x, y)] = true; out[#out + 1] = { x, y } end
  end
  return out
end

------------------------------------------------------------------------
-- Generators
------------------------------------------------------------------------
local gen = {}

-- INITIATE (ages 5-7): always 3 big buttons --------------------------------
function gen.mech_roles(level)
  if random() < 0.5 then return NA.FromEntry(NA.Draw("mech_roles", D.ROLES, level), "initiate", "MECH_H_ROLES") end
  local role = pick({ "tank", "heal", "dps" })
  local who = pick(D.NAMES)
  local a = L()["MECH_ROLE_" .. role:upper()]
  local ds = {}
  for _, r in ipairs({ "tank", "heal", "dps" }) do if r ~= role then ds[#ds + 1] = L()["MECH_ROLE_" .. r:upper()] end end
  return { text = fmt("MECH_Q_ROLE", who, pick(D.ROLE_CLUES[role])), answer = a, choices = choices(a, ds, 3),
    hint = L().MECH_H_ROLES, explain = fmt("MECH_E_ROLE", who, a) }
end

-- "Avoid the fire": letters on a small arena, only one is safe
function MA.FirePuzzle(lv)
  local letters = { "A", "B", "C" }
  if lv <= 2 then
    local w, h = lv == 1 and 4 or 5, lv == 1 and 4 or 5
    for _ = 1, 200 do
      local fireCells = randomCells(w, h, lv == 1 and random(4, 6) or random(3, 4))
      local fires = {}
      for _, c in ipairs(fireCells) do fires[key(c[1], c[2])] = true end
      -- the safe square: not on fire (lv1) / not on or next to fire (lv2)
      local safeOk = function(x, y) return not fires[key(x, y)] and (lv == 1 or not MA.NearFire(fires, x, y)) end
      local free = {}
      for y = 1, h do for x = 1, w do if safeOk(x, y) then free[#free + 1] = { x, y } end end end
      local bad = {}
      if lv == 1 then
        bad = { unpack(fireCells) }
      else
        for y = 1, h do for x = 1, w do
          if not fires[key(x, y)] and MA.NearFire(fires, x, y) then bad[#bad + 1] = { x, y } end
        end end
      end
      if #free >= 1 and #bad >= 2 then
        local safe = pick(free)
        bad = Util.Shuffle(bad)
        local spots = Util.Shuffle({ safe, bad[1], bad[2] })
        local grid = { w = w, h = h, fire = {}, marks = {} }
        local answer
        local labelAt = {}
        for i, s in ipairs(spots) do
          labelAt[key(s[1], s[2])] = letters[i]
          if s == safe then answer = letters[i] end
        end
        for _, c in ipairs(fireCells) do grid.fire[#grid.fire + 1] = { c[1], c[2], labelAt[key(c[1], c[2])] } end
        for _, s in ipairs(spots) do
          if not fires[key(s[1], s[2])] then grid.marks[#grid.marks + 1] = { s[1], s[2], labelAt[key(s[1], s[2])] } end
        end
        return grid, answer, letters
      end
    end
  end
  -- lv3: the hero is surrounded on three sides; which way is out?
  local w, h = 5, 5
  local hx, hy = random(2, 4), random(2, 4)
  local out = pick(MA.DIR_ORDER)
  local grid = { w = w, h = h, fire = {}, bot = { hx, hy, "" }, icons = { bot = MA.HERO_ICON } }
  local taken = { [key(hx, hy)] = true }
  for _, d in ipairs(MA.DIR_ORDER) do
    local v = MA.NEIGHBORS[d]
    if d ~= out then
      grid.fire[#grid.fire + 1] = { hx + v[1], hy + v[2] }
      taken[key(hx + v[1], hy + v[2])] = true
    end
  end
  local ov = MA.NEIGHBORS[out]
  taken[key(hx + ov[1], hy + ov[2])] = true
  for _, c in ipairs(randomCells(w, h, random(1, 3), taken)) do
    -- extra fire never touches the escape square
    if abs(c[1] - (hx + ov[1])) + abs(c[2] - (hy + ov[2])) > 1 then grid.fire[#grid.fire + 1] = { c[1], c[2] } end
  end
  return grid, out, nil
end

function gen.mech_fire(level)
  local lv = LevelFor(level)
  local grid, answer, letters = MA.FirePuzzle(lv)
  if lv <= 2 then
    local ds = {}
    for _, l in ipairs(letters) do if l ~= answer then ds[#ds + 1] = l end end
    local c = { answer, ds[1], ds[2] }
    table.sort(c)
    return { text = L()[lv == 1 and "MECH_Q_FIRE" or "MECH_Q_FIRE_SPREAD"], answer = answer, choices = c, grid = grid,
      hint = L()[lv == 1 and "MECH_H_FIRE" or "MECH_H_FIRE2"], explain = fmt(lv == 1 and "MECH_E_FIRE" or "MECH_E_FIRE_SPREAD", answer) }
  end
  local a = L()["MECH_DIR_" .. answer]
  local ds = {}
  for _, d in ipairs(MA.DIR_ORDER) do if d ~= answer then ds[#ds + 1] = L()["MECH_DIR_" .. d] end end
  return { text = L().MECH_Q_FIRE_ESCAPE, answer = a, choices = choices(a, Util.Shuffle(ds), 3), grid = grid, escape = answer,
    hint = L().MECH_H_FIRE3, explain = fmt("MECH_E_FIRE_ESCAPE", a) }
end

function gen.mech_count(level)
  local lv = LevelFor(level)
  local foe = pick(D.ENEMIES)
  if lv == 1 then
    local a, b = random(2, 5), random(2, 4)
    return { text = fmt("MECH_Q_COUNT_ADD", a, foe, b, foe), answer = a + b, minChoice = 1, hint = L().MECH_H_COUNT,
      explain = fmt("MECH_E_ADD", a, b, a + b) }
  elseif lv == 2 then
    local a = random(4, 10)
    local b = random(1, a - 1)
    return { text = fmt("MECH_Q_COUNT_SUB", a, foe, b), answer = a - b, minChoice = 0, hint = L().MECH_H_COUNT,
      explain = fmt("MECH_E_SUB", a, b, a - b) }
  end
  if random() < 0.5 then
    local d = random(2, 4)
    return { text = fmt("MECH_Q_COUNT_GROUP", d), answer = 2 + d, minChoice = 1, hint = L().MECH_H_COUNT,
      explain = fmt("MECH_E_GROUP", d, 2 + d) }
  end
  local g, n = random(2, 3), random(2, 4)
  return { text = fmt("MECH_Q_COUNT_PACKS", g, n, foe), answer = g * n, minChoice = 1, hint = L().MECH_H_COUNT,
    explain = fmt("MECH_E_PACKS", g, n, g * n) }
end

-- who needs healing first? (most health missing)
function gen.mech_health(level)
  local lv = LevelFor(level)
  local who = names(3)
  local hp, max = {}, {}
  if lv == 3 and random() < 0.5 then
    -- different health pools: compare what is missing
    for _ = 1, 50 do
      local missing = {}
      for i = 1, 3 do
        max[i] = pick({ 20, 50, 100 })
        hp[i] = random(1, max[i] / 10) * 10
        if hp[i] > max[i] then hp[i] = max[i] end
        missing[i] = max[i] - hp[i]
      end
      local best, tie = 1, false
      for i = 2, 3 do
        if missing[i] > missing[best] then best, tie = i, false elseif missing[i] == missing[best] then tie = true end
      end
      for i = 1, 3 do if i ~= best and missing[i] == missing[best] then tie = true end end
      if not tie and missing[best] > 0 then
        local lines = {}
        for i = 1, 3 do lines[i] = fmt("MECH_HP_LINE", who[i], hp[i], max[i]) end
        local ds = {}
        for i = 1, 3 do if i ~= best then ds[#ds + 1] = who[i] end end
        return { text = fmt("MECH_Q_HP_MISSING", table.concat(lines, "\n")), answer = who[best], choices = choices(who[best], ds, 3),
          hint = L().MECH_H_HEALTH3, explain = fmt("MECH_E_HP_MISSING", who[best], missing[best]), code = true }
      end
    end
  end
  local top = lv == 1 and 10 or 100
  local step = lv == 1 and 1 or 10
  local vals = {}
  for _, v in ipairs(Util.Shuffle({ 1, 2, 3, 4, 5, 6, 7, 8, 9 })) do if #vals < 3 then vals[#vals + 1] = v * step end end
  if lv >= 2 and random() < 0.4 then
    local i = random(1, 3)
    return { text = fmt("MECH_Q_HP_LOST", who[i], vals[i], top), answer = top - vals[i], minChoice = 0, hint = L().MECH_H_HEALTH,
      explain = fmt("MECH_E_HP_LOST", top, vals[i], top - vals[i]) }
  end
  local lines, low = {}, 1
  for i = 1, 3 do
    lines[i] = fmt("MECH_HP_LINE", who[i], vals[i], top)
    if vals[i] < vals[low] then low = i end
  end
  local ds = {}
  for i = 1, 3 do if i ~= low then ds[#ds + 1] = who[i] end end
  return { text = fmt("MECH_Q_HP_LOW", table.concat(lines, "\n")), answer = who[low], choices = choices(who[low], ds, 3),
    hint = L().MECH_H_HEALTH, explain = fmt("MECH_E_HP_LOW", who[low], vals[low]), code = true }
end

gen.mech_teamwork = curated("teamwork", D.TEAMWORK, "initiate", "MECH_H_TEAMWORK")

-- ADEPT (ages 8-10) --------------------------------------------------------
function gen.mech_threat(level)
  local lv = LevelFor(level)
  local who = names(3)
  if lv == 1 then
    local vals = {}
    for _, v in ipairs(Util.Shuffle({ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 })) do if #vals < 3 then vals[#vals + 1] = v * 100 end end
    local lines, top = {}, 1
    for i = 1, 3 do
      lines[i] = fmt("MECH_THREAT_LINE", who[i], vals[i])
      if vals[i] > vals[top] then top = i end
    end
    local ds = {}
    for i = 1, 3 do if i ~= top then ds[#ds + 1] = who[i] end end
    return { text = fmt("MECH_Q_THREAT_WHO", table.concat(lines, "\n")), answer = who[top], choices = choices(who[top], ds, 3),
      hint = L().MECH_H_THREAT, explain = fmt("MECH_E_THREAT_WHO", who[top], vals[top]), code = true }
  elseif lv == 2 then
    local t = random(8, 30) * 50
    local y = random(2, t / 50 - 2) * 50
    return { text = fmt("MECH_Q_THREAT_GAP", t, y), answer = t - y, distractors = { t + y, y }, hint = L().MECH_H_THREAT,
      explain = fmt("MECH_E_THREAT_GAP", t, y, t - y) }
  end
  local z, k = random(2, 9) * 10, random(3, 12)
  local y = random(1, 20) * 10
  local t = y + z * k
  return { text = fmt("MECH_Q_THREAT_TIME", t, y, z), answer = k, distractors = { k + 1, k - 1 }, minChoice = 1,
    hint = L().MECH_H_THREAT3, explain = fmt("MECH_E_THREAT_TIME", t, y, t - y, z, k) }
end

gen.mech_positioning = curated("pos", D.POSITIONING, "adept", "MECH_H_POSITIONING")

function gen.mech_interrupts(level)
  local lv = LevelFor(level)
  local boss = pick(D.BOSSES)
  if lv == 1 then
    local f, s = random(2, 6), random(5, 12)
    local n = random(2, 4)
    return { text = fmt("MECH_Q_CAST_NTH", boss, f, s, n), answer = f + (n - 1) * s, minChoice = 1,
      distractors = { f + n * s, n * s }, hint = L().MECH_H_INTERRUPTS,
      explain = fmt("MECH_E_CAST_NTH", f, n - 1, s, f + (n - 1) * s) }
  elseif lv == 2 and random() < 0.6 then
    local s = random(4, 15)
    local k = random(3, 8)
    local t = s * k + random(0, s - 1)
    return { text = fmt("MECH_Q_CAST_COUNT", boss, s, t), answer = k, distractors = { k + 1, k - 1 }, minChoice = 1,
      hint = L().MECH_H_INTERRUPTS, explain = fmt("MECH_E_CAST_COUNT", t, s, k) }
  end
  -- can the group interrupt every cast?
  local players = lv == 3 and 2 or 1
  local s = random(6, 14)
  local c
  if random() < 0.5 then c = random(4, s * players) else c = s * players + random(1, 8) end
  local yes = c <= s * players
  local a = yes and L().MECH_YES or L().MECH_NO
  return { text = fmt(players == 1 and "MECH_Q_KICK_ONE" or "MECH_Q_KICK_TWO", boss, s, c), answer = a,
    choices = choices(a, { yes and L().MECH_NO or L().MECH_YES }, 2), hint = L().MECH_H_INTERRUPTS2,
    explain = fmt(yes and "MECH_E_KICK_YES" or "MECH_E_KICK_NO", c, s * players) }
end

function gen.mech_cooldowns(level)
  local lv = LevelFor(level)
  local ab = pick(D.ABILITIES)
  if lv == 1 then
    local u, c = random(1, 30), pick({ 10, 15, 20, 30, 45, 60 })
    return { text = fmt("MECH_Q_CD_READY", ab, u, c), answer = u + c, distractors = { c, u + c + 10 }, minChoice = 1,
      hint = L().MECH_H_COOLDOWNS, explain = fmt("MECH_E_CD_READY", u, c, u + c) }
  elseif lv == 2 or random() < 0.5 then
    local c = pick({ 10, 15, 20, 30, 45, 60 })
    local k = random(2, 6)
    local t = c * k + random(1, c - 1)
    return { text = fmt("MECH_Q_CD_USES", ab, c, t), answer = k + 1, distractors = { k, floor(t / c) + 2 }, minChoice = 1,
      hint = L().MECH_H_COOLDOWNS2, explain = fmt("MECH_E_CD_USES", c, k * c, k + 1) }
  end
  -- minutes and seconds
  local cdMin = random(1, 3)
  local usedS = random(1, 11) * 5
  local readyS = cdMin * 60 + usedS
  local function mmss(s) return string.format("%d:%02d", floor(s / 60), s % 60) end
  local a = mmss(readyS)
  local ds = { mmss(readyS + 60), mmss(usedS + cdMin * 100), mmss(readyS - 60) }
  return { text = fmt("MECH_Q_CD_MINUTES", ab, cdMin, mmss(usedS)), answer = a, choices = choices(a, ds, 4),
    hint = L().MECH_H_COOLDOWNS3, explain = fmt("MECH_E_CD_MINUTES", mmss(usedS), cdMin, a), code = true }
end

function gen.mech_classes(level)
  local lv = LevelFor(level)
  local all = MA.Classes()
  local kind = random(1, lv == 1 and 2 or (lv == 2 and 4 or 5))
  if kind == 1 then
    local c = pick(all)
    local ds = {}
    for _, o in ipairs(others(all, c, 3)) do ds[#ds + 1] = o.name end
    return { text = fmt("MECH_Q_CLASS_CLUE", c.hint), answer = c.name, distractors = ds, typed = true, alts = { c.name:lower() },
      hint = L().MECH_H_CLASSES, explain = fmt("MECH_E_CLASS_CLUE", c.name) }
  end
  local roleOf = { [2] = "heal", [3] = "heal", [4] = "tank" }
  if kind == 5 then
    local healers = {}
    for _, c in ipairs(MA.Classes(function(x) return x.heal end)) do healers[#healers + 1] = c.name end
    local n = #healers
    return { text = fmt("MECH_Q_CLASS_COUNT", #all), answer = n, distractors = { n + 2, n - 1, #all }, minChoice = 1,
      hint = L().MECH_H_CLASSES2, explain = fmt("MECH_E_CLASS_COUNT", n, table.concat(healers, ", ")) }
  end
  local role = roleOf[kind]
  local yesList = MA.Classes(function(c) return c[role] end)
  local noList = MA.Classes(function(c) return not c[role] end)
  local wantYes = kind ~= 3
  local a = pick(wantYes and yesList or noList)
  local ds = {}
  for _, o in ipairs(others(wantYes and noList or yesList, nil, 3)) do ds[#ds + 1] = o.name end
  local q = kind == 2 and "MECH_Q_CLASS_HEAL" or (kind == 3 and "MECH_Q_CLASS_NOHEAL" or "MECH_Q_CLASS_TANK")
  return { text = L()[q], answer = a.name, choices = choices(a.name, ds, 4), hint = L().MECH_H_CLASSES2,
    explain = fmt(wantYes and "MECH_E_CLASS_CAN" or "MECH_E_CLASS_CANNOT", a.name, L()["MECH_ROLE_" .. role:upper()]:lower()) }
end

-- MAGISTER (ages 11-13) ----------------------------------------------------
function gen.mech_dps(level)
  local lv = LevelFor(level)
  if lv == 1 then
    local d, s = random(4, 30) * 5, random(2, 12) * 5
    return { text = fmt("MECH_Q_DPS_TOTAL", d, s), answer = d * s, distractors = { d + s, d * s + d }, minChoice = 1,
      hint = L().MECH_H_DPS, explain = fmt("MECH_E_DPS_TOTAL", d, s, d * s) }
  elseif lv == 2 then
    if random() < 0.5 then
      local who = names(4)
      local vals, lines, sum = {}, {}, 0
      for i = 1, 4 do
        vals[i] = random(6, 40) * 5
        sum = sum + vals[i]
        lines[i] = fmt("MECH_DPS_LINE", who[i], vals[i])
      end
      return { text = fmt("MECH_Q_DPS_GROUP", table.concat(lines, "\n")), answer = sum, distractors = { sum + 10, sum - 5 },
        minChoice = 1, hint = L().MECH_H_DPS, explain = fmt("MECH_E_DPS_GROUP", sum), code = true }
    end
    local g, t = random(10, 60) * 10, random(5, 30) * 2
    return { text = fmt("MECH_Q_DPS_TIME", pick(D.BOSSES), g * t, g), answer = t, distractors = { t + 2, t * 2 }, minChoice = 1,
      hint = L().MECH_H_DPS2, explain = fmt("MECH_E_DPS_TIME", g * t, g, t) }
  end
  -- enrage timer
  local g, t = random(10, 60) * 10, random(30, 120)
  local e = t + random(5, 60)
  if random() < 0.5 then
    local fast = random() < 0.5
    if not fast then e = t - random(5, 25) end
    local a = fast and L().MECH_YES or L().MECH_NO
    return { text = fmt("MECH_Q_ENRAGE_BEAT", pick(D.BOSSES), g * t, g, e), answer = a,
      choices = choices(a, { fast and L().MECH_NO or L().MECH_YES }, 2), hint = L().MECH_H_DPS3,
      explain = fmt(fast and "MECH_E_ENRAGE_YES" or "MECH_E_ENRAGE_NO", g * t, g, t, e) }
  end
  return { text = fmt("MECH_Q_ENRAGE_SPARE", pick(D.BOSSES), g * t, g, e), answer = e - t, distractors = { t, e }, minChoice = 1,
    hint = L().MECH_H_DPS3, explain = fmt("MECH_E_ENRAGE_SPARE", g * t, g, t, e, e - t) }
end

function gen.mech_mana(level)
  local lv = LevelFor(level)
  if lv == 1 then
    local c = pick({ 20, 25, 40, 50, 60, 75, 100 })
    local n = random(3, 15)
    local m = c * n + random(0, c - 1)
    return { text = fmt("MECH_Q_MANA_CASTS", m, c), answer = n, distractors = { n + 1, n - 1 }, minChoice = 1,
      hint = L().MECH_H_MANA, explain = fmt("MECH_E_MANA_CASTS", m, c, n) }
  elseif lv == 2 then
    local m, r, t = random(5, 30) * 100, random(2, 10) * 5, random(3, 12) * 10
    return { text = fmt("MECH_Q_MANA_REGEN", m, r, t), answer = m + r * t, distractors = { m + r, r * t }, minChoice = 1,
      hint = L().MECH_H_MANA2, explain = fmt("MECH_E_MANA_REGEN", r, t, r * t, m, m + r * t) }
  end
  -- which heal gives more healing for the same mana?
  for _ = 1, 50 do
    local m = random(10, 30) * 100
    local ca, ha = random(3, 8) * 50, random(6, 20) * 50
    local cb, hb = random(1, 3) * 25, random(2, 8) * 25
    local ta, tb = floor(m / ca) * ha, floor(m / cb) * hb
    if ta ~= tb and ca ~= cb then
      local big, small = L().MECH_HEAL_BIG, L().MECH_HEAL_SMALL
      if random() < 0.5 then
        local a = ta > tb and big or small
        return { text = fmt("MECH_Q_MANA_WHICH", m, big, ca, ha, small, cb, hb), answer = a,
          choices = choices(a, { ta > tb and small or big, L().MECH_HEAL_SAME }, 3), hint = L().MECH_H_MANA3,
          explain = fmt("MECH_E_MANA_WHICH", big, floor(m / ca), ta, small, floor(m / cb), tb), code = true }
      end
      return { text = fmt("MECH_Q_MANA_TOTAL", m, small, cb, hb), answer = tb, distractors = { tb + hb, floor(m / cb) },
        minChoice = 1, hint = L().MECH_H_MANA3, explain = fmt("MECH_E_MANA_TOTAL", m, cb, floor(m / cb), hb, tb) }
    end
  end
end

-- priority list: use the first ability whose rule is true
function gen.mech_rotation(level)
  local lv = LevelFor(level)
  local abil = {}
  for _, v in ipairs(Util.Shuffle({ unpack(D.ABILITIES) })) do if #abil < 4 then abil[#abil + 1] = v end end
  local rules = {}
  local combo, ready, hp = random(0, 5), random() < 0.5, random(5, 100)
  if lv == 3 then rules[#rules + 1] = { text = fmt("MECH_RULE_LOW", abil[4]), ok = hp < 20, ab = abil[4] } end
  rules[#rules + 1] = { text = fmt("MECH_RULE_COMBO", abil[1]), ok = combo == 5, ab = abil[1] }
  rules[#rules + 1] = { text = fmt("MECH_RULE_READY", abil[2], abil[2]), ok = ready, ab = abil[2] }
  if lv >= 2 then
    -- the rule order is shuffled above the fallback, so kids must read it
    local fixed = {}
    for _, r in ipairs(rules) do fixed[#fixed + 1] = r end
    rules = Util.Shuffle(fixed)
  end
  rules[#rules + 1] = { text = fmt("MECH_RULE_ELSE", abil[3]), ok = true, ab = abil[3] }
  local lines, answer = {}, nil
  for i, r in ipairs(rules) do
    lines[i] = i .. ". " .. r.text
    if not answer and r.ok then answer = r.ab end
  end
  local state = fmt("MECH_STATE", combo, abil[2], ready and L().MECH_READY or L().MECH_NOT_READY)
  if lv == 3 then state = state .. "\n" .. fmt("MECH_STATE_HP", hp) end
  local ds = {}
  for _, r in ipairs(rules) do if r.ab ~= answer then ds[#ds + 1] = r.ab end end
  return { text = fmt("MECH_Q_ROTATION", table.concat(lines, "\n"), state), answer = answer, choices = choices(answer, ds, 4),
    hint = L().MECH_H_ROTATION, explain = fmt("MECH_E_ROTATION", answer), code = true, rules = rules,
    state = { combo = combo, ready = ready, hp = hp } }
end

function gen.mech_bossmech(level)
  if random() < 0.6 then return NA.FromEntry(NA.Draw("mech_boss", D.BOSSMECH, level), "magister", "MECH_H_BOSSMECH") end
  local h = random(10, 90) * 100
  local p = pick({ 20, 25, 30, 40, 50, 60, 75 })
  local a = h * p / 100
  return { text = fmt("MECH_Q_PHASE", pick(D.BOSSES), h, p), answer = a, distractors = { h - a, a + 100 }, minChoice = 1,
    hint = L().MECH_H_PHASE, explain = fmt("MECH_E_PHASE", h, p, a) }
end

function gen.mech_races(level)
  local lv = LevelFor(level)
  local all = MA.Races()
  local r = pick(all)
  local kind = random(1, lv == 1 and 2 or 3)
  local ds = {}
  if kind == 1 then
    for _, o in ipairs(others(all, r, 3)) do ds[#ds + 1] = o.name end
    return { text = fmt("MECH_Q_RACE_WHO", r.trait), answer = r.name, choices = choices(r.name, ds, 4),
      hint = L().MECH_H_RACES, explain = fmt("MECH_E_RACE", r.name, r.trait, r.does) }
  elseif kind == 2 then
    for _, o in ipairs(others(all, r, 3)) do ds[#ds + 1] = o.trait end
    return { text = fmt("MECH_Q_RACE_TRAIT", r.name), answer = r.trait, choices = choices(r.trait, ds, 4),
      hint = L().MECH_H_RACES, explain = fmt("MECH_E_RACE", r.name, r.trait, r.does) }
  end
  for _, o in ipairs(others(all, r, 3)) do ds[#ds + 1] = o.trait end
  return { text = fmt("MECH_Q_RACE_DOES", r.does), answer = r.trait, choices = choices(r.trait, ds, 4),
    hint = L().MECH_H_RACES, explain = fmt("MECH_E_RACE", r.name, r.trait, r.does) }
end

------------------------------------------------------------------------
-- Answer check: numbers typed or picked, typed words with spellings, buttons
------------------------------------------------------------------------
function MA.Check(p, given)
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
MA.BANDS = {
  initiate = { id = "initiate", nodes = { "mech_roles", "mech_fire", "mech_count", "mech_health", "mech_teamwork" } },
  adept    = { id = "adept",    nodes = { "mech_threat", "mech_positioning", "mech_interrupts", "mech_cooldowns", "mech_classes" } },
  magister = { id = "magister", nodes = { "mech_dps", "mech_mana", "mech_rotation", "mech_bossmech", "mech_races" } },
}
MA.NODES = {}
for id, fn in pairs(gen) do MA.NODES[id] = { key = "MECH_NODE_" .. id:sub(6):upper(), gen = fn } end
MA.GEN = gen
MA.LISTS = {
  mech_roles = { D.ROLES }, mech_teamwork = { D.TEAMWORK }, mech_positioning = { D.POSITIONING }, mech_bossmech = { D.BOSSMECH },
}

MA.MODULE = ns.Modules.Register({
  id = MA.MODULE_ID,
  nameKey = "MOD_MECHANICS", descKey = "MOD_MECHANICS_DESC",
  icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
  startSound = "drill",
  loreKey = "MECH_LORE", titleKey = "MECH_TITLE",
  placementKey = "MECH_TRIAL", examKey = "MECH_EXAM",
  placementLoreKey = "MECH_TRIAL_LORE", examLoreKey = "MECH_EXAM_LORE",
  placementResultKey = "MECH_TRIAL_RESULT", examPassKey = "MECH_EXAM_PASS",
  trialRightKey = "MECH_TRIAL_RIGHT", trialWrongKey = "MECH_TRIAL_WRONG",
  bands = MA.BANDS, nodes = MA.NODES,
  choiceOnlyBands = { initiate = true },
  check = MA.Check,
  textAnswers = true,
  game = { key = "MECH_DECK_LINK", tileKey = "MECH_DECK_TILE", tipKey = "MECH_DECK_TIP", view = "journal" },
  guideEvents = { ROUNDSTART = { "MECHSTART", every = 1 }, CORRECT = { "MECHCORRECT", every = 3 }, WRONG = { "MECHWRONG", every = 3 } },
})

-- Tactics Deck: one tactics card per mastered tier (shared collection system)
ns.Journal.RegisterBook({
  moduleId = MA.MODULE_ID, items = D.CARDS, prefix = "TACTICS",
  openEvent = "MECHDECK", newEvent = "MECHCARD", sound = "drill",
})

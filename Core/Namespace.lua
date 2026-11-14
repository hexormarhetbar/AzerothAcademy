-- Azeroth Academy - shared namespace and pure utilities.
-- CORE RULE: nothing in Core\ may call WoW UI or game APIs directly.
-- Clock/date access goes through ns.Env (set by the adapter) so the core can
-- run headless in plain Lua 5.1 for tests.
local ADDON, ns = ...

ns.ADDON = ADDON or "AzerothAcademy"
ns.VERSION = "0.14.0"
ns.Env = ns.Env or {}

local Util = {}
ns.Util = Util

local mrandom, floor, abs = math.random, math.floor, math.abs

-- v0.10 Duel of Wits: every generator draws through this one function, so a
-- duel can swap in a seeded generator (Util.WithRNG) and two players' clients
-- build the exact same question set. Outside a duel it is plain math.random.
local function random(a, b)
  local g = Util.rng
  if g then return g(a, b) end
  if b then return mrandom(a, b) elseif a then return mrandom(a) end
  return mrandom()
end
Util.Random = random

-- Park-Miller "minimal standard" generator. Same seed = same numbers on every
-- client and every Lua build (WoW's math.randomseed is not dependable).
function Util.NewRNG(seed)
  local s = floor(abs(tonumber(seed) or 1)) % 2147483646 + 1
  return function(a, b)
    s = (s * 16807) % 2147483647
    local r = (s - 1) / 2147483646 -- [0, 1)
    if not a then return r end
    if not b then a, b = 1, a end
    return a + floor(r * (b - a + 1))
  end
end

-- Run fn with Util.Random routed to rng; always restores the previous source.
function Util.WithRNG(rng, fn, ...)
  local prev = Util.rng
  Util.rng = rng
  local res = { pcall(fn, ...) }
  Util.rng = prev
  if not res[1] then error(res[2], 0) end
  return unpack(res, 2)
end

-- Numeric string hash (djb2, 31-bit) for building seeds from text.
function Util.HashNum(s)
  local h = 5381
  s = tostring(s)
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

function Util.Clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

function Util.Rand(a, b) return random(a, b) end

function Util.Pick(t) return t[random(1, #t)] end

function Util.Shuffle(t)
  for i = #t, 2, -1 do
    local j = random(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

function Util.Now()
  local f = ns.Env.time or time or (os and os.time)
  return f and f() or 0
end

function Util.DayKey(t)
  local f = ns.Env.date or date or (os and os.date)
  if not f then return "0000-00-00" end
  return f("%Y-%m-%d", t or Util.Now())
end

function Util.DateText(t)
  local f = ns.Env.date or date or (os and os.date)
  if not f then return "" end
  return f("%Y-%m-%d %H:%M", t or Util.Now())
end

-- 12345 -> "12,345" (TODO: locale-aware separators)
function Util.Commas(n)
  local s = tostring(n)
  local sign, int = s:match("^(-?)(%d+)$")
  if not int then return s end
  int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if int:sub(1, 1) == "," then int = int:sub(2) end
  return sign .. int
end

-- Not cryptography. A PIN hash only keeps the PIN from sitting in plain text
-- inside SavedVariables. Anyone with file access can reset it.
function Util.Hash(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return string.format("%08x", h)
end

-- Parse a typed number. Accepts "42", " -7 ", "1,200", unicode minus.
-- Rejects hex, exponents and garbage.
function Util.ParseNumber(s)
  if type(s) == "number" then return s end
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s", "")
  s = s:gsub(",", "")
  s = s:gsub("\226\136\146", "-") -- U+2212 minus sign
  if s == "" or not s:match("^%-?%d+%.?%d*$") then return nil end
  return tonumber(s)
end

function Util.IsInteger(n)
  return type(n) == "number" and n == floor(n) and abs(n) < 1e12
end

-- Build `count` unique numeric choices containing `answer`.
-- `preferred` = plausible mistakes to try first (e.g. off-by-one table facts).
function Util.MakeChoices(answer, count, spread, minVal, preferred, maxVal)
  local out, seen = { answer }, { [answer] = true }
  local function add(c)
    if #out < count and c ~= nil and not seen[c] and (minVal == nil or c >= minVal) and (maxVal == nil or c <= maxVal) then
      seen[c] = true
      out[#out + 1] = c
    end
  end
  if preferred then
    local pref = {}
    for i = 1, #preferred do pref[i] = preferred[i] end
    Util.Shuffle(pref)
    for i = 1, #pref do add(pref[i]) end
  end
  spread = math.max(spread or 3, count)
  local guard = 0
  while #out < count and guard < 200 do
    guard = guard + 1
    local d = random(1, spread)
    if random(1, 2) == 1 then d = -d end
    add(answer + d)
  end
  local c, guard2 = answer, 0
  while #out < count and guard2 < 1000 do
    guard2 = guard2 + 1
    c = c + 1
    add(c)
    add(answer - guard2)
  end
  return Util.Shuffle(out)
end

function Util.FormatDuration(sec)
  sec = floor((sec or 0) + 0.5)
  if sec < 60 then return sec .. "s" end
  local m = floor(sec / 60)
  if m < 60 then return string.format("%dm %02ds", m, sec % 60) end
  return string.format("%dh %02dm", floor(m / 60), m % 60)
end

-- Copy missing keys from defaults into dst (recursive for tables).
function Util.ApplyDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      Util.ApplyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function Util.Wipe(t)
  for k in pairs(t) do t[k] = nil end
  return t
end

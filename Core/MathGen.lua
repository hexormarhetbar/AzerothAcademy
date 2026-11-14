-- Rune Forger procedural problem generators.
-- Every generator takes a difficulty level 1..5 and returns a problem table:
--   text      string shown to the kid
--   answer    number (or string for some multiple-choice items)
--   display   optional bare expression ("3 + 4 x 2 = ?") embedded in text
--   verify    Lua boolean expression using ANS; used by the test harness
--   hint      strategy hint (never gives the answer away)
--   explain   worked explanation shown after the second miss
--   icons     optional {count, texture} for counting problems (UI draws them)
--   choices   optional preset choices; otherwise Generate() builds them
--   distractors  plausible wrong answers to prefer as choices
--   allowNegative / minChoice  constraints for generated choices
local _, ns = ...
local Util = ns.Util
local R, Pick = Util.Rand, Util.Pick
local floor, abs, max, min = math.floor, math.abs, math.max, math.min

local G = {}
ns.MathGen = G

G.TIMES, G.DIVIDE = "\195\151", "\195\183" -- U+00D7 and U+00F7 (Latin-1, FRIZQT has them)
local X, D = G.TIMES, G.DIVIDE

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end

-- Show a negative number in brackets when it is not the first term.
local function n2s(n) if n < 0 then return "(" .. n .. ")" end return tostring(n) end

G.ICONS = {
  { key = "ICON_COINS", texture = "Interface\\Icons\\INV_Misc_Coin_01" },
  { key = "ICON_STARS", texture = "Interface\\Icons\\Spell_Nature_StarFall" },
  { key = "ICON_LIGHT", texture = "Interface\\Icons\\Spell_Holy_HolyBolt" },
  { key = "ICON_BOOKS", texture = "Interface\\Icons\\INV_Misc_Book_09" },
}

local gen = {}

------------------------------------------------------------------------
-- INITIATE (5-7)
------------------------------------------------------------------------
function gen.counting(level)
  local hi = ({ 5, 8, 10, 15, 20 })[level]
  local lo = level >= 4 and 6 or 1
  local n = R(lo, hi)
  local icon = Pick(G.ICONS)
  return {
    text = fmt("Q_COUNT", L()[icon.key]), answer = n,
    icons = { count = n, texture = icon.texture },
    hint = L().Q_COUNT_HINT, explain = fmt("Q_COUNT_EXPLAIN", n),
    verify = "ANS==" .. n, minChoice = 1, spread = 2,
    meta = { kind = "count", n = n },
  }
end

local ADD_WORDS = { "Q_ADD_1", "Q_ADD_2", "Q_ADD_3", "Q_ADD_4" }

local function addProblem(a, b, plainChance)
  local s = a + b
  local display = a .. " + " .. b .. " = ?"
  local text
  if a < 2 or R(1, 100) <= plainChance then
    text = fmt("Q_ADD_PLAIN", display)
  else
    text = fmt(Pick(ADD_WORDS), a, b)
  end
  return {
    text = text, answer = s, display = (text:find(display, 1, true) and display) or nil,
    hint = L().Q_ADD_HINT, explain = fmt("Q_ADD_EXPLAIN", max(a, b), min(a, b), s),
    verify = a .. "+" .. b .. "==ANS", distractors = { s - 1, s + 1, s + 2, s - 2 },
  }
end

function gen.add10(level)
  local hi = ({ 5, 7, 10, 10, 10 })[level]
  local lo = level >= 4 and 6 or 2
  local s = R(lo, hi)
  local a = R(1, s - 1)
  return addProblem(a, s - a, 35)
end

function gen.add20(level)
  if level == 5 then
    local a, b = R(2, 8), R(2, 8)
    local c = R(1, min(9, 20 - a - b))
    local s = a + b + c
    return {
      text = fmt("Q_ADD3", a, b, c), answer = s,
      hint = L().Q_ADD_HINT, explain = string.format("%d + %d = %d, %d + %d = %d", a, b, a + b, a + b, c, s),
      verify = a .. "+" .. b .. "+" .. c .. "==ANS", distractors = { s - 1, s + 1, s + 10, s - 10 },
    }
  end
  local ranges = { { 8, 12 }, { 10, 15 }, { 11, 20 }, { 11, 18 } }
  local r = ranges[level]
  local s = R(r[1], r[2])
  local a
  if level == 4 then
    -- force "making ten": ones digits add past 10
    a = R(max(2, s - 9), min(9, s - 2))
  else
    a = R(max(1, s - 10), min(10, s - 1))
  end
  return addProblem(a, s - a, 40)
end

local SUB_WORDS = { "Q_SUB_1", "Q_SUB_2", "Q_SUB_3" }

function gen.sub20(level)
  local a, b
  if level == 1 then a = R(3, 10); b = R(1, a - 1)
  elseif level == 2 then a = R(8, 14); b = R(1, a - 2)
  elseif level == 3 then a = R(11, 20); b = R(1, a)
  elseif level == 4 then a = R(10, 18); b = R((a % 10) + 1, 9)
  else a = R(12, 20); b = R(5, a) end
  local d = a - b
  local display = a .. " - " .. b .. " = ?"
  local text
  if R(1, 100) <= 40 then text = fmt("Q_ADD_PLAIN", display) else text = fmt(Pick(SUB_WORDS), a, b) end
  return {
    text = text, answer = d, display = (text:find(display, 1, true) and display) or nil,
    hint = L().Q_SUB_HINT, explain = fmt("Q_SUB_EXPLAIN", a, b, d),
    verify = a .. "-" .. b .. "==ANS", distractors = { d + 1, d - 1, a + b },
  }
end

function gen.compare(level)
  local lo, hi, gap = 1, 10, 3
  if level == 2 then hi, gap = 20, 2
  elseif level == 3 then hi, gap = 20, 1
  elseif level == 4 then lo, hi, gap = 10, 50, 1
  elseif level == 5 then lo, hi, gap = 20, 100, 1 end
  local dir = (level >= 3 and R(1, 2) == 2) and "less" or "more"
  local allowSame = level >= 3
  local a, b
  if allowSame and R(1, 6) == 1 then
    a = R(lo, hi); b = a
  else
    repeat
      a, b = R(lo, hi), R(lo, hi)
      if level == 5 then b = a + (R(1, 2) == 1 and -1 or 1) * R(1, 3) end
    until abs(a - b) >= gap and b >= 0
  end
  local answer, explain
  if a == b then
    answer, explain = L().SAME, L().Q_CMP_EXPLAIN_SAME
  elseif dir == "more" then
    answer = max(a, b); explain = fmt("Q_CMP_EXPLAIN_MORE", tostring(answer))
  else
    answer = min(a, b); explain = fmt("Q_CMP_EXPLAIN_LESS", tostring(answer))
  end
  local choices
  if a == b then choices = { a, L().SAME }
  elseif allowSame then choices = { a, b, L().SAME }
  else choices = { a, b } end
  return {
    text = fmt(dir == "more" and "Q_CMP_MORE" or "Q_CMP_LESS", a, b), answer = answer,
    choices = choices, hint = L().Q_CMP_HINT, explain = explain,
    meta = { kind = "compare", a = a, b = b, dir = dir },
  }
end

------------------------------------------------------------------------
-- ADEPT (8-10)
------------------------------------------------------------------------
local function tableFactors(level)
  if level == 1 then return Pick({ 2, 5, 10 }), R(1, 10)
  elseif level == 2 then return R(2, 6), R(1, 10)
  elseif level == 3 then return R(2, 9), R(2, 10)
  elseif level == 4 then return R(2, 12), R(2, 12) end
  return R(6, 12), R(6, 12)
end

function gen.times(level)
  local a, b = tableFactors(level)
  if R(1, 2) == 1 then a, b = b, a end
  local p = a * b
  local expr = a .. " " .. X .. " " .. b
  local display = expr .. " = ?"
  local text
  if R(1, 4) == 1 and a >= 2 then text = fmt("Q_TIMES_1", a, b) else text = fmt("Q_TIMES_PLAIN", display) end
  return {
    text = text, answer = p, display = (text:find(display, 1, true) and display) or nil,
    hint = fmt("Q_TIMES_HINT", a, b), explain = fmt("Q_TIMES_EXPLAIN", expr, p),
    verify = a .. "*" .. b .. "==ANS",
    distractors = { a * (b + 1), a * (b - 1), (a + 1) * b, a + b },
  }
end

function gen.division(level)
  local b, q = tableFactors(level)
  if b < 2 then b, q = q, b end
  if b < 2 then b = 2 end
  local a = b * q
  local expr = a .. " " .. D .. " " .. b
  local display = expr .. " = ?"
  local text
  if R(1, 4) == 1 and b <= 10 then text = fmt("Q_DIV_1", a, b) else text = fmt("Q_DIV_PLAIN", display) end
  return {
    text = text, answer = q, display = (text:find(display, 1, true) and display) or nil,
    hint = fmt("Q_DIV_HINT", b, a),
    explain = fmt("Q_DIV_EXPLAIN", b .. " " .. X .. " " .. q, a, expr, q),
    verify = a .. "/" .. b .. "==ANS", distractors = { q + 1, q - 1, q + b, a - b },
  }
end

local PLACE_KEYS = { "PV_ONES", "PV_TENS", "PV_HUNDREDS", "PV_THOUSANDS", "PV_TENTHOUSANDS" }

function gen.placevalue(level)
  local ndig = ({ 2, 3, 4, 4, 5 })[level]
  local digits, used = {}, {}
  for i = 1, ndig do
    local d
    repeat d = R(i == 1 and 1 or 0, 9) until not used[d]
    used[d] = true
    digits[i] = d
  end
  local n = 0
  for i = 1, ndig do n = n * 10 + digits[i] end
  local nText = Util.Commas(n)
  local pos = R(0, ndig - 1) -- 0 = ones
  local digit = floor(n / 10 ^ pos) % 10
  local placeName = L()[PLACE_KEYS[pos + 1]]
  local asValue = level >= 3 and R(1, 2) == 1
  if asValue and digit == 0 then asValue = false end
  if asValue then
    local value = digit * 10 ^ pos
    return {
      text = fmt("Q_PV_VALUE", nText, digit), answer = value,
      hint = L().Q_PV_HINT, explain = fmt("Q_PV_EXPLAIN_VALUE", digit, placeName, Util.Commas(value)),
      verify = string.format("math.floor(%d/%d)%%10*%d==ANS", n, 10 ^ pos, 10 ^ pos),
      distractors = { digit, digit * 10 ^ ((pos + 1) % ndig), digit * 10 ^ max(0, pos - 1) },
      spread = 3, meta = { kind = "pv", n = n, digit = digit },
    }
  end
  local others = {}
  for i = 1, ndig do if digits[i] ~= digit then others[#others + 1] = digits[i] end end
  return {
    text = fmt("Q_PV_DIGIT", placeName, nText), answer = digit,
    hint = L().Q_PV_HINT, explain = fmt("Q_PV_EXPLAIN_DIGIT", placeName, nText, digit),
    verify = string.format("math.floor(%d/%d)%%10==ANS", n, 10 ^ pos),
    distractors = others, spread = 3, maxChoice = 9,
  }
end

function gen.fractions(level)
  local dens = ({ { 2 }, { 2, 4 }, { 2, 3, 4, 5 }, { 3, 4, 5, 6, 8, 10 }, { 3, 4, 5, 6, 8, 10, 12 } })[level]
  local d = Pick(dens)
  local n = 1
  if level == 3 and R(1, 2) == 1 then n = R(1, d - 1) elseif level >= 4 then n = R(1, d - 1) end
  local k = R(2, level <= 2 and 5 or (level <= 3 and 8 or 12))
  local whole = d * k
  local ans = n * k
  local which = R(1, 3)
  local text
  if which == 1 then text = fmt("Q_FRAC_1", whole, n, d)
  elseif which == 2 then text = fmt("Q_FRAC_2", n, d, whole)
  else text = fmt("Q_FRAC_3", whole, n, d) end
  return {
    text = text, answer = ans,
    hint = fmt("Q_FRAC_HINT", whole, d), explain = fmt("Q_FRAC_EXPLAIN", whole, d, k, n, ans),
    verify = string.format("%d*%d/%d==ANS", whole, n, d),
    distractors = { k, whole - ans, ans + k, d },
  }
end

function gen.word(level)
  local ops
  if level == 1 then ops = { "add", "sub" }
  elseif level == 2 then ops = { "add", "sub", "mul" }
  elseif level == 3 then ops = { "mul", "div", "add", "sub" }
  else ops = { "mul", "div", "add", "sub" } end
  local op = Pick(ops)
  local big = level >= 4
  local key, a, b, ans, expr, verify, hintKey
  if op == "add" then
    if R(1, 2) == 1 then
      key = "WP_ADD_1"; a = R(big and 25 or 5, big and 250 or (level == 1 and 15 or 60)); b = R(big and 25 or 3, big and 250 or (level == 1 and 10 or 40))
    else
      key = "WP_ADD_2"; a = R(1, 50); b = R(1, 10)
    end
    ans = a + b; expr = a .. " + " .. b; verify = a .. "+" .. b; hintKey = "WP_HINT_ADD"
  elseif op == "sub" then
    if R(1, 2) == 1 then
      key = "WP_SUB_1"; a = R(level == 1 and 5 or 10, big and 60 or (level == 1 and 15 or 30)); b = R(1, a - 1)
    else
      key = "WP_SUB_2"; a = R(level == 1 and 8 or 20, big and 500 or (level == 1 and 20 or 99)); b = R(1, a - 1)
    end
    ans = a - b; expr = a .. " - " .. b; verify = a .. "-" .. b; hintKey = "WP_HINT_SUB"
  elseif op == "mul" then
    if R(1, 2) == 1 then
      key = "WP_MUL_1"; a = big and R(12, 60) or R(2, 10) * (level >= 3 and 5 or 1); b = R(2, level == 5 and 9 or 5)
    else
      key = "WP_MUL_2"; a = R(2, level >= 3 and 9 or 5); b = R(2, level >= 4 and 12 or 6)
    end
    ans = a * b; expr = a .. " " .. X .. " " .. b; verify = a .. "*" .. b; hintKey = "WP_HINT_MUL"
  else
    local q
    if R(1, 2) == 1 then
      key = "WP_DIV_1"; b = R(2, 5); q = R(2, big and 40 or 12)
    else
      key = "WP_DIV_2"; b = R(2, 6); q = R(2, big and 20 or 10)
    end
    a = b * q; ans = q; expr = a .. " " .. D .. " " .. b; verify = a .. "/" .. b; hintKey = "WP_HINT_DIV"
  end
  return {
    text = fmt(key, a, b), answer = ans,
    hint = L()[hintKey], explain = fmt("WP_EXPLAIN", expr, Util.Commas(ans)),
    verify = verify .. "==ANS", distractors = { a + b, abs(a - b), a * b, ans + 1, ans - 1 },
  }
end

------------------------------------------------------------------------
-- MAGISTER (11-13)
------------------------------------------------------------------------
function gen.percent(level)
  if level == 4 and R(1, 2) == 1 then
    local a, b = R(5, 30), R(1, 15)
    return {
      text = fmt("Q_PCT_CRIT", a, b), answer = a + b,
      hint = L().Q_PCT_HINT_ADD, explain = fmt("Q_PCT_EXPLAIN_ADD", a, b, a + b),
      verify = a .. "+" .. b .. "==ANS", distractors = { a * b, a + b + 1, a - b },
    }
  end
  if level == 5 then
    local base = 20 * R(2, 15)
    local p = Pick({ 5, 10, 15, 20, 25, 30, 40, 50, 75 })
    local part = base * p / 100
    if R(1, 2) == 1 then
      return {
        text = fmt("Q_PCT_SALE", base, p), answer = base - part,
        hint = L().Q_PCT_HINT, explain = fmt("Q_PCT_EXPLAIN_SALE", p, base, part, base, part, base - part),
        verify = string.format("%d-%d*%d/100==ANS", base, base, p), distractors = { part, base - p, base + part },
      }
    end
    return {
      text = fmt("Q_PCT_UP", base, p), answer = base + part,
      hint = L().Q_PCT_HINT, explain = fmt("Q_PCT_EXPLAIN_UP", p, base, part, base, part, base + part),
      verify = string.format("%d+%d*%d/100==ANS", base, base, p), distractors = { part, base + p, base - part },
    }
  end
  local p, base
  if level == 1 then p = Pick({ 10, 50 }); base = 20 * R(1, 5)
  elseif level == 2 then p = Pick({ 10, 20, 25, 50, 75 }); base = 20 * R(1, 10)
  else p = 5 * R(1, 19); base = 20 * R(1, level == 3 and 10 or 20) end
  local ans = base * p / 100
  return {
    text = fmt("Q_PCT_1", p, base), answer = ans,
    hint = L().Q_PCT_HINT, explain = fmt("Q_PCT_EXPLAIN", p, base, ans),
    verify = string.format("%d*%d/100==ANS", base, p), distractors = { base - ans, ans * 2, ans + 10 },
  }
end

function gen.negatives(level)
  local a, b, c, expr, ans, verify
  local hint = L().Q_NEG_HINT
  local text
  if level == 1 then
    a, b = -R(1, 10), R(1, 15)
    ans = a + b
    if R(1, 3) == 1 then
      text = fmt("Q_NEG_WARM", a, b)
    end
    expr = a .. " + " .. b; verify = a .. "+" .. b
  elseif level == 2 then
    a = R(1, 10); b = a + R(1, 10)
    ans = a - b
    if R(1, 3) == 1 then text = fmt("Q_NEG_COLD", a, b) end
    expr = a .. " - " .. b; verify = a .. "-" .. b
  elseif level == 3 then
    if R(1, 2) == 1 then
      a, b = R(-10, 10), -R(1, 10)
      ans = a - b; expr = a .. " - " .. n2s(b); verify = a .. "-(" .. b .. ")"
    else
      a, b = -R(1, 12), -R(1, 12)
      ans = a + b; expr = a .. " + " .. n2s(b); verify = a .. "+(" .. b .. ")"
    end
  elseif level == 4 then
    a, b = R(2, 9), R(2, 9)
    local s = R(1, 3)
    if s == 1 then a = -a elseif s == 2 then b = -b else a, b = -a, -b end
    ans = a * b; expr = a .. " " .. X .. " " .. n2s(b); verify = a .. "*(" .. b .. ")"; hint = L().Q_NEG_HINT_MUL
  else
    if R(1, 2) == 1 then
      b, c = R(2, 9), R(2, 9)
      if R(1, 2) == 1 then b = -b end
      if R(1, 2) == 1 then c = -c end
      a = b * c
      ans = c; expr = a .. " " .. D .. " " .. n2s(b); verify = a .. "/(" .. b .. ")"; hint = L().Q_NEG_HINT_MUL
    else
      a, b, c = -R(2, 9), R(2, 9), R(-15, 15)
      ans = a * b + c
      expr = a .. " " .. X .. " " .. b .. (c < 0 and (" - " .. -c) or (" + " .. c))
      verify = a .. "*" .. b .. "+(" .. c .. ")"; hint = L().Q_NEG_HINT_MUL
    end
  end
  local display = expr .. " = ?"
  text = text or fmt("Q_NEG_PLAIN", display)
  return {
    text = text, answer = ans, display = (text:find(display, 1, true) and display) or nil,
    hint = hint, explain = fmt("Q_NEG_EXPLAIN", expr .. " = " .. ans),
    verify = verify .. "==ANS", allowNegative = true, distractors = { -ans, ans + 1, ans - 1 },
  }
end

function gen.order(level)
  local expr, ans, wrong, steps, verify
  if level == 1 then
    local a, b, c = R(1, 10), R(2, 5), R(2, 5)
    ans = a + b * c; wrong = (a + b) * c
    expr = string.format("%d + %d %s %d", a, b, X, c); verify = string.format("%d+%d*%d", a, b, c)
    steps = string.format("%d %s %d = %d, %d + %d = %d", b, X, c, b * c, a, b * c, ans)
  elseif level == 2 then
    local a, b = R(2, 9), R(2, 9)
    local c = R(1, a * b - 1)
    if R(1, 2) == 1 then
      ans = a * b - c; wrong = a * (b - c)
      expr = string.format("%d %s %d - %d", a, X, b, c); verify = string.format("%d*%d-%d", a, b, c)
      steps = string.format("%d %s %d = %d, %d - %d = %d", a, X, b, a * b, a * b, c, ans)
    else
      c = R(1, 20)
      ans = c + a * b; wrong = (c + a) * b
      expr = string.format("%d + %d %s %d", c, a, X, b); verify = string.format("%d+%d*%d", c, a, b)
      steps = string.format("%d %s %d = %d, %d + %d = %d", a, X, b, a * b, c, a * b, ans)
    end
  elseif level == 3 then
    local a, b, c = R(1, 9), R(1, 9), R(2, 6)
    if R(1, 2) == 1 then
      ans = (a + b) * c; wrong = a + b * c
      expr = string.format("(%d + %d) %s %d", a, b, X, c); verify = string.format("(%d+%d)*%d", a, b, c)
      steps = string.format("%d + %d = %d, %d %s %d = %d", a, b, a + b, a + b, X, c, ans)
    else
      ans = c * (a + b); wrong = c * a + b
      expr = string.format("%d %s (%d + %d)", c, X, a, b); verify = string.format("%d*(%d+%d)", c, a, b)
      steps = string.format("%d + %d = %d, %d %s %d = %d", a, b, a + b, c, X, a + b, ans)
    end
  elseif level == 4 then
    if R(1, 2) == 1 then
      local a, b, c = R(5, 20), R(2, 9), R(2, 9)
      local d = R(1, a + b * c - 1)
      ans = a + b * c - d; wrong = (a + b) * c - d
      expr = string.format("%d + %d %s %d - %d", a, b, X, c, d); verify = string.format("%d+%d*%d-%d", a, b, c, d)
      steps = string.format("%d %s %d = %d, %d + %d - %d = %d", b, X, c, b * c, a, b * c, d, ans)
    else
      local b, q, c = R(2, 9), R(2, 9), R(1, 20)
      local a = b * q
      ans = a / b + c; wrong = a / (b + c)
      expr = string.format("%d %s %d + %d", a, D, b, c); verify = string.format("%d/%d+%d", a, b, c)
      steps = string.format("%d %s %d = %d, %d + %d = %d", a, D, b, q, q, c, ans)
    end
  else
    local kind = R(1, 3)
    if kind == 1 then
      local a, b, c = R(1, 9), R(1, 9), R(2, 6)
      local prod = (a + b) * c
      local divs = {}
      for k = 2, 12 do if prod % k == 0 then divs[#divs + 1] = k end end
      local d = Pick(divs) -- prod >= 4 and even or has a factor >=2; c>=2 guarantees one
      ans = prod / d; wrong = a + b * c / d
      expr = string.format("(%d + %d) %s %d %s %d", a, b, X, c, D, d); verify = string.format("(%d+%d)*%d/%d", a, b, c, d)
      steps = string.format("%d + %d = %d, %d %s %d = %d, %d %s %d = %d", a, b, a + b, a + b, X, c, prod, prod, D, d, ans)
    elseif kind == 2 then
      local a, b, c, d = R(3, 12), R(3, 12), R(2, 6), R(2, 6)
      if a * b <= c * d then a = a + c * d end
      ans = a * b - c * d; wrong = (a * b - c) * d
      expr = string.format("%d %s %d - %d %s %d", a, X, b, c, X, d); verify = string.format("%d*%d-%d*%d", a, b, c, d)
      steps = string.format("%d %s %d = %d, %d %s %d = %d, %d - %d = %d", a, X, b, a * b, c, X, d, c * d, a * b, c * d, ans)
    else
      local a, b, c, d = R(6, 15), R(1, 5), R(1, 6), R(1, 6)
      ans = (a - b) * (c + d); wrong = a - b * c + d
      expr = string.format("(%d - %d) %s (%d + %d)", a, b, X, c, d); verify = string.format("(%d-%d)*(%d+%d)", a, b, c, d)
      steps = string.format("%d - %d = %d, %d + %d = %d, %d %s %d = %d", a, b, a - b, c, d, c + d, a - b, X, c + d, ans)
    end
  end
  local display = expr .. " = ?"
  local dis = { ans + 1, ans - 1 }
  if wrong == floor(wrong) and wrong ~= ans then dis[#dis + 1] = wrong end
  return {
    text = fmt("Q_ORDER", display), answer = ans, display = display,
    hint = L().Q_ORDER_HINT, explain = fmt("Q_ORDER_EXPLAIN", steps),
    verify = verify .. "==ANS", distractors = dis,
  }
end

function gen.equations(level)
  local x, a, b, c, display, steps
  if level == 1 then
    x, a = R(1, 20), R(1, 20)
    b = x + a
    display = string.format("x + %d = %d", a, b)
    steps = string.format("x = %d - %d = %d", b, a, x)
  elseif level == 2 then
    if R(1, 2) == 1 then
      x = R(5, 30); a = R(1, x - 1); b = x - a
      display = string.format("x - %d = %d", a, b)
      steps = string.format("x = %d + %d = %d", b, a, x)
    else
      a, x = R(2, 10), R(1, 12); b = a * x
      display = string.format("%dx = %d", a, b)
      steps = string.format("x = %d %s %d = %d", b, D, a, x)
    end
  elseif level == 3 then
    if R(1, 2) == 1 then
      a, b = R(2, 10), R(2, 12); x = a * b
      display = string.format("x %s %d = %d", D, a, b)
      steps = string.format("x = %d %s %d = %d", b, X, a, x)
    else
      a, x = R(3, 15), R(3, 15); b = a * x
      display = string.format("%dx = %d", a, b)
      steps = string.format("x = %d %s %d = %d", b, D, a, x)
    end
  elseif level == 4 then
    a, x, b = R(2, 9), R(1, 12), R(1, 30)
    c = a * x + b
    display = string.format("%dx + %d = %d", a, b, c)
    steps = string.format("%dx = %d - %d = %d, x = %d %s %d = %d", a, c, b, a * x, a * x, D, a, x)
  else
    if R(1, 2) == 1 then
      a, x = R(2, 9), R(2, 12)
      b = R(1, a * x - 1)
      c = a * x - b
      display = string.format("%dx - %d = %d", a, b, c)
      steps = string.format("%dx = %d + %d = %d, x = %d %s %d = %d", a, c, b, a * x, a * x, D, a, x)
    else
      a, x, b = R(2, 6), R(1, 10), R(1, 9)
      c = a * (x + b)
      display = string.format("%d(x + %d) = %d", a, b, c)
      steps = string.format("x + %d = %d %s %d = %d, x = %d - %d = %d", b, c, D, a, x + b, x + b, b, x)
    end
  end
  return {
    text = fmt("Q_EQ", display), answer = x, display = display,
    hint = L().Q_EQ_HINT, explain = fmt("Q_EQ_EXPLAIN", steps),
    distractors = { x + 1, x - 1, x * 2 },
    meta = { kind = "equation", display = display },
  }
end

function gen.area(level)
  local text, ans, steps, verify
  local kind
  if level == 1 then kind = "rect"
  elseif level == 2 then kind = Pick({ "rect", "square" })
  elseif level == 3 then kind = Pick({ "rect", "tri" })
  elseif level == 4 then kind = Pick({ "missing", "tri", "rect" })
  else kind = Pick({ "L", "missing", "tri" }) end
  local big = level >= 3
  if kind == "rect" then
    local l, w = R(2, big and 15 or (level == 1 and 6 or 12)), R(2, level == 1 and 5 or 12)
    ans = l * w; text = fmt("Q_AREA_RECT", l, w)
    steps = string.format("%d %s %d = %d", l, X, w, ans); verify = l .. "*" .. w
  elseif kind == "square" then
    local s = R(2, 12)
    ans = s * s; text = fmt("Q_AREA_SQUARE", s)
    steps = string.format("%d %s %d = %d", s, X, s, ans); verify = s .. "*" .. s
  elseif kind == "tri" then
    local base, h = 2 * R(1, big and 10 or 6), R(2, 12)
    ans = base * h / 2; text = fmt("Q_AREA_TRI", base, h)
    steps = string.format("%d %s %d %s 2 = %d", base, X, h, D, ans); verify = base .. "*" .. h .. "/2"
  elseif kind == "missing" then
    local w, l = R(2, 10), R(2, 12)
    local area = l * w
    ans = l; text = fmt("Q_AREA_MISSING", area, w)
    steps = string.format("%d %s %d = %d", area, D, w, l); verify = area .. "/" .. w
  else
    local a, b, c, d = R(2, 10), R(2, 8), R(2, 8), R(2, 6)
    ans = a * b + c * d; text = fmt("Q_AREA_L", a, b, c, d)
    steps = string.format("%d %s %d + %d %s %d = %d + %d = %d", a, X, b, c, X, d, a * b, c * d, ans)
    verify = string.format("%d*%d+%d*%d", a, b, c, d)
  end
  return {
    text = text, answer = ans,
    hint = L().Q_AREA_HINT, explain = fmt("Q_AREA_EXPLAIN", steps),
    verify = verify .. "==ANS", distractors = { ans + 2, ans - 2, ans * 2 },
  }
end

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
G.BANDS = {
  initiate = { id = "initiate", nodes = { "counting", "add10", "add20", "sub20", "compare" } },
  adept    = { id = "adept",    nodes = { "times", "division", "placevalue", "fractions", "word" } },
  magister = { id = "magister", nodes = { "percent", "negatives", "order", "equations", "area" } },
}

local NODE_KEYS = {
  counting = "NODE_COUNTING", add10 = "NODE_ADD10", add20 = "NODE_ADD20", sub20 = "NODE_SUB20",
  compare = "NODE_COMPARE", times = "NODE_TIMES", division = "NODE_DIVISION",
  placevalue = "NODE_PLACEVALUE", fractions = "NODE_FRACTIONS", word = "NODE_WORD",
  percent = "NODE_PERCENT", negatives = "NODE_NEGATIVES", order = "NODE_ORDER",
  equations = "NODE_EQUATIONS", area = "NODE_AREA",
}
G.NODES = {}
for id, key in pairs(NODE_KEYS) do
  G.NODES[id] = { key = key, descKey = key .. "_DESC", gen = gen[id] }
end

-- Rune Forger is simply the first registered module. The engine knows nothing about math.
G.MODULE = ns.Modules.Register({
  id = "runeforger",
  nameKey = "MOD_RUNEFORGER", descKey = "MOD_RUNEFORGER_DESC",
  icon = "Interface\\Icons\\INV_Misc_Rune_01",
  startSound = "forge",
  loreKey = "FORGE_LORE", titleKey = "FORGE_TITLE",
  placementKey = "TRIAL_PLACEMENT", examKey = "TRIAL_EXAM", reviewKey = "REVIEW_RUNES",
  placementLoreKey = "TRIAL_PLACEMENT_LORE", examLoreKey = "TRIAL_EXAM_LORE",
  bands = G.BANDS, nodes = G.NODES,
  choiceOnlyBands = { initiate = true },
})

-- v0.1 API kept as thin wrappers over the generic pipeline.
function G.Generate(nodeId, level, tier, purpose) return ns.Modules.Generate(nodeId, level, tier, purpose) end
G.Check = ns.Modules.Check
G.FormatAnswer = ns.Modules.FormatAnswer

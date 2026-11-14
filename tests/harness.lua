-- Headless test harness for Azeroth Academy's shared core.
-- Run from the addon folder:  lua tests/harness.lua [iterations]
-- Loads the Core + Locales files exactly as the .toc does (with the addon
-- varargs), with no WoW API present, and hammers the generators, mastery,
-- sessions, progression, PIN and report code.
local ITER = tonumber(arg and arg[1]) or 400
math.randomseed(tonumber(os.getenv("SEED") or "") or os.time())

local function newNS(locale)
  local ns = { Env = { time = os.time, date = os.date, locale = locale or "enUS" } }
  -- Load the shared core straight from the .toc (Core\ and Locales\ only, in order).
  local files = {}
  for line in io.lines("AzerothAcademy.toc") do
    line = line:gsub("\r", "")
    if line:match("^Core\\") or line:match("^Locales\\") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  for _, f in ipairs(files) do
    local chunk = assert(loadfile(f))
    chunk("AzerothAcademy", ns)
  end
  return ns
end

local ns = newNS()
local P, M, G, S, Util = ns.Progress, ns.Mastery, ns.MathGen, ns.Session, ns.Util
P.Bind({}, {})

local checks, failures = 0, 0
local function ok(cond, msg)
  checks = checks + 1
  if not cond then
    failures = failures + 1
    if failures <= 40 then print("FAIL: " .. msg) end
  end
  return cond
end

local function evalBool(expr, env)
  local f, err = loadstring("return " .. expr)
  if not f then return nil, err end
  setfenv(f, env)
  local okk, res = pcall(f)
  if not okk then return nil, res end
  return res
end

local function luaExpr(s)
  return (s:gsub("\195\151", "*"):gsub("\195\183", "/"))
end

local function hasFormatLeftovers(s)
  return type(s) ~= "string" or s:find("%%[ds%%]") ~= nil or s:find("nil", 1, true) ~= nil
end

-------------------------------------------------------------------------
-- 1. Generators
-------------------------------------------------------------------------
local genCount = 0
local perNode = {}
for nodeId, node in pairs(G.NODES) do
  perNode[nodeId] = 0
  for level = 1, 5 do
    for tier = 1, 3 do
      for _ = 1, ITER do
        local okk, p = pcall(G.Generate, nodeId, level, tier)
        genCount = genCount + 1
        perNode[nodeId] = perNode[nodeId] + 1
        local tag = string.format("[%s L%d T%d]", nodeId, level, tier)
        if ok(okk and type(p) == "table", tag .. " generator error: " .. tostring(p)) then
          tag = tag .. " '" .. tostring(p.text) .. "' ans=" .. tostring(p.answer)
          ok(type(p.text) == "string" and #p.text > 5, tag .. " empty text")
          ok(not hasFormatLeftovers(p.text), tag .. " text format leftovers")
          ok(not hasFormatLeftovers(p.hint), tag .. " hint leftovers: " .. tostring(p.hint))
          ok(not hasFormatLeftovers(p.explain), tag .. " explain leftovers: " .. tostring(p.explain))
          if type(p.answer) == "number" then
            ok(Util.IsInteger(p.answer), tag .. " non-integer answer")
            if not p.allowNegative then ok(p.answer >= 0, tag .. " negative answer") end
          else
            ok(p.answer == ns.L.SAME, tag .. " unexpected string answer")
          end
          if p.verify then
            local res, err = evalBool(p.verify, { ANS = p.answer, math = math })
            ok(res == true, tag .. " verify failed: " .. p.verify .. " " .. tostring(err))
          end
          if p.display and not (p.meta and p.meta.kind == "equation") then
            ok(p.text:find(p.display, 1, true) ~= nil, tag .. " display not in text")
            local e = luaExpr(p.display):gsub("%s*=%s*%?%s*$", "")
            local res, err = evalBool(e .. "==ANS", { ANS = p.answer })
            ok(res == true, tag .. " display mismatch: " .. e .. " " .. tostring(err))
          end
          local meta = p.meta
          if meta and meta.kind == "equation" then
            ok(p.text:find(meta.display, 1, true) ~= nil, tag .. " equation display missing")
            local lhs, rhs = meta.display:match("^(.-)%s*=%s*(.-)$")
            local e = luaExpr(lhs):gsub("(%d)x", "%1*ANS"):gsub("(%d)%(", "%1*("):gsub("x", "ANS")
            local res, err = evalBool("(" .. e .. ")==(" .. luaExpr(rhs) .. ")", { ANS = p.answer })
            ok(res == true, tag .. " equation substitution failed: " .. e .. " = " .. rhs .. " " .. tostring(err))
          elseif meta and meta.kind == "compare" then
            local expect
            if meta.a == meta.b then expect = ns.L.SAME
            elseif meta.dir == "more" then expect = math.max(meta.a, meta.b)
            else expect = math.min(meta.a, meta.b) end
            ok(tostring(expect) == tostring(p.answer), tag .. " compare wrong")
          elseif meta and meta.kind == "count" then
            ok(p.icons and p.icons.count == p.answer and p.icons.count >= 1 and p.icons.count <= 20, tag .. " icon count")
          elseif meta and meta.kind == "pv" then
            local seen = {}
            for d in tostring(meta.n):gmatch("%d") do
              ok(not seen[d], tag .. " repeated digit makes question ambiguous")
              seen[d] = true
            end
          end
          -- mode / choices
          if node.band == "initiate" then ok(p.mode == "choice", tag .. " initiate must be multiple choice") end
          if tier >= 2 and node.band ~= "initiate" and not p.meta then ok(p.mode == "input", tag .. " expected typed input") end
          if p.mode == "choice" then
            local c = p.choices
            ok(type(c) == "table" and #c >= 2 and #c <= 4, tag .. " choice count")
            if node.band == "initiate" then ok(#c <= 3, tag .. " initiate max 3 choices") end
            local hits, seen = 0, {}
            for _, v in ipairs(c) do
              local k = tostring(v)
              ok(not seen[k], tag .. " duplicate choice " .. k)
              seen[k] = true
              if k == tostring(p.answer) then hits = hits + 1 end
              if type(v) == "number" then
                ok(Util.IsInteger(v), tag .. " non-integer choice")
                if not p.allowNegative then ok(v >= (p.minChoice or 0), tag .. " choice below minimum " .. k) end
                if p.maxChoice then ok(v <= p.maxChoice, tag .. " choice above maximum " .. k) end
              end
            end
            ok(hits == 1, tag .. " answer must appear exactly once in choices")
            ok(G.Check(p, p.answer), tag .. " Check(answer) false")
            for _, v in ipairs(c) do
              if tostring(v) ~= tostring(p.answer) then ok(not G.Check(p, v), tag .. " wrong choice accepted") end
            end
          else
            ok(G.Check(p, tostring(p.answer)), tag .. " Check(typed answer)")
            ok(G.Check(p, "  " .. tostring(p.answer) .. " "), tag .. " Check(spaces)")
            ok(G.Check(p, Util.Commas(p.answer)), tag .. " Check(commas)")
            ok(not G.Check(p, tostring(p.answer + 1)), tag .. " off-by-one accepted")
            ok(not G.Check(p, ""), tag .. " empty accepted")
            ok(not G.Check(p, "abc"), tag .. " garbage accepted")
            ok(not G.Check(p, "0x" .. tostring(p.answer)), tag .. " hex accepted")
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------
-- 2. Utility + parsing
-------------------------------------------------------------------------
ok(Util.ParseNumber("1,200") == 1200, "parse commas")
ok(Util.ParseNumber(" -7 ") == -7, "parse negative")
ok(Util.ParseNumber("\226\136\1465") == -5, "parse unicode minus")
ok(Util.ParseNumber("1e3") == nil, "reject exponent")
ok(Util.ParseNumber("12abc") == nil, "reject junk")
ok(Util.Commas(1234567) == "1,234,567", "commas")
ok(Util.Commas(-1234) == "-1,234", "commas negative")
ok(Util.Commas(999) == "999", "commas small")

-------------------------------------------------------------------------
-- 3. Mastery window
-------------------------------------------------------------------------
do
  ok(M.Required() == 9, "85% of 10 requires 9")
  local rec = { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false }
  local newly
  for i = 1, 9 do newly = M.Record(rec, true, 1); ok(not newly, "not mastered before 10 attempts (" .. i .. ")") end
  newly = M.Record(rec, false, 1)
  ok(newly and rec.mastered, "9/10 masters on the 10th attempt")
  local rec2 = { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false }
  for i = 1, 10 do M.Record(rec2, i > 2, 1) end -- 8/10
  ok(not rec2.mastered, "8/10 does not master")
  M.Record(rec2, true, 1) -- window slides: drops a miss -> 9/10
  ok(rec2.mastered, "sliding window masters at 9/10")
  ok(#rec2.recent == 10, "window stays at 10")
  ok(rec2.attempts == 11 and rec2.correct == 9, "lifetime totals kept")
end

-------------------------------------------------------------------------
-- 4. Progression, minutes, PIN, ranks
-------------------------------------------------------------------------
do
  P.Bind({}, {})
  ok(P.GetRankInfo(0).key == "RANK_INITIATE", "rank 0")
  ok(P.GetRankInfo(249).key == "RANK_INITIATE", "rank 249")
  ok(P.GetRankInfo(250).key == "RANK_APPRENTICE", "rank 250")
  ok(P.GetRankInfo(6000).key == "RANK_ARCHMAGE" and P.GetRankInfo(6000).pct == 1, "rank max")
  local _, up = P.AddShards(260)
  ok(up, "rank up detected at 260")
  local total = 0
  for _ = 1, 8 do total = total + P.AwardMastery() end
  ok(total == 60, "daily cap 60 respected with 10/mastery (got " .. total .. ")")
  ok(P.SetMinuteRules(15, 45), "set rules")
  P.account.minutes.day = "1999-01-01" -- simulate a new day
  local e = P.GetTodayMinutes()
  ok(e == 0, "minutes reset on new day")
  total = 0
  for _ = 1, 5 do total = total + P.AwardMastery() end
  ok(total == 45, "custom cap 45 with 15/mastery (got " .. total .. ")")
  ok(not P.SetMinuteRules(-1, 10), "reject negative minutes")
  ok(not P.SetMinuteRules(10, 999), "reject huge cap")
  ok(not P.SetMinuteRules("abc", 10), "reject junk")
  ok(not P.HasPin() and P.CheckPin("whatever"), "no pin = open")
  ok(not P.SetPin("12"), "short pin rejected")
  ok(not P.SetPin("12a4"), "non-digit pin rejected")
  ok(P.SetPin("4821"), "pin set")
  ok(P.HasPin(), "has pin")
  ok(P.CheckPin("4821"), "pin accepted")
  ok(not P.CheckPin("4822"), "wrong pin rejected")
  ok(not tostring(P.account.pin.hash):find("4821", 1, true), "pin not stored in plain text")
  ok(P.SetBand("adept") and P.GetBand() == "adept", "set band")
  ok(not P.SetBand("wizard"), "reject bad band")
  P.ResetProfile()
  ok(P.GetBand() == nil and P.char.shards == 0, "reset profile clears character")
  ok(P.HasPin(), "reset profile keeps parent PIN")
end

-------------------------------------------------------------------------
-- 5. Sessions: perfect student, struggling student, random students
-------------------------------------------------------------------------
local function answerFor(p, correct)
  if correct then return p.answer end
  if p.mode == "choice" then
    for _, v in ipairs(p.choices) do if tostring(v) ~= tostring(p.answer) then return v end end
  end
  if type(p.answer) == "number" then return tostring(p.answer + 7) end
  return "zzqx"
end

local function playRound(nodeId, tier, pCorrect, clock)
  local s = S.New(nodeId, tier, clock)
  local shardsBefore = P.char.shards
  local results = {}
  while true do
    local p = s:Next(clock)
    if not p then break end
    ok(s.level >= s.minLevel and s.level <= s.maxLevel, "level within tier range")
    local guard = 0
    repeat
      guard = guard + 1
      clock = clock + 3
      local r = s:Submit(answerFor(p, math.random() < pCorrect), clock)
      ok(r ~= nil, "submit returns result")
      results[#results + 1] = r
      if r.retry then ok(r.hint and #r.hint > 0, "retry gives hint") end
      if r.final and not r.correct then ok(r.explain and r.answerText, "final miss explains") end
      ok(r.shards >= 0, "never lose shards")
    until r.final or guard > 3
    ok(guard <= 2, "at most one retry")
    ok(s:Submit(p.answer, clock) == nil, "no double submit after final")
  end
  local sum = s:Finish()
  ok(sum.completed, "round completed")
  ok(P.char.shards - shardsBefore == sum.shards, "shard ledger matches summary")
  local sum2 = s:Finish()
  ok(sum2.shards == sum.shards, "finish is idempotent")
  return sum, results, clock
end

do
  -- Perfect student on 'times' Spark: masters on attempt 10 (round 2, problem 4)
  P.Bind({}, {})
  P.SetBand("adept")
  local clock = 100
  local s1, r1
  s1, r1, clock = playRound("times", 1, 1.0, clock)
  ok(not s1.masteredNow, "not mastered after 6")
  -- adaptivity: 3 right -> level up within Spark range (1..3)
  ok(r1[3].levelChange == 1 and r1[6].levelChange == 1, "steps up after 3 and 6 first-try corrects")
  ok(r1[3].combo == 3 and r1[5].overcharge, "combo at 3, overcharge at 5")
  -- shards: 10,10,15,15,30,30 + round bonus 10
  ok(s1.shards == 10 + 10 + 15 + 15 + 30 + 30 + 10, "shard math for perfect round (got " .. s1.shards .. ")")
  local s2
  s2, _, clock = playRound("times", 1, 1.0, clock)
  ok(s2.masteredNow and s2.tierMastered, "mastered Spark in round 2")
  ok(s2.minutes == 10, "10 bonus minutes for the mastery")
  ok(M.IsTierUnlocked("times", 2), "Rune unlocked after Spark mastery")
  ok(not M.IsTierUnlocked("times", 3), "Glyph still locked")
  ok(M.CurrentTier("times") == 2, "current tier advances to Rune")

  -- Struggling student: steps down, never below tier minimum, never loses shards
  local s3, r3
  s3, r3, clock = playRound("division", 2, 0.0, clock)
  ok(s3.firstCorrect == 0 and s3.shards == 10, "all-wrong round earns only the completion bonus")
  local sawDown = false
  for _, r in ipairs(r3) do if r.levelChange == -1 then sawDown = true end end
  ok(not sawDown, "already at Rune minimum, cannot step below")
  local sess = S.New("division", 2, clock)
  sess.level = 4
  sess:Next(clock)
  local a = sess:Submit("999999", clock + 1)
  local b = sess:Submit("999999", clock + 2)
  ok(a.retry and b.final and b.levelChange == -1 and sess.level == 3, "2 misses step difficulty down")

  -- Random students across every node and tier
  for _ = 1, math.max(4, math.floor(ITER / 40)) do
    for nodeId in pairs(G.NODES) do
      for tier = 1, 3 do
        _, _, clock = playRound(nodeId, tier, math.random(), clock)
      end
    end
  end
  local earned, cap = P.GetTodayMinutes()
  ok(earned <= cap, "minutes never exceed the daily cap (" .. earned .. "/" .. cap .. ")")
end

-------------------------------------------------------------------------
-- 6. Recommend, report, locale fallback
-------------------------------------------------------------------------
do
  P.Bind({}, {})
  P.SetBand("magister")
  local node, tier = M.Recommend("magister")
  ok(node == "percent" and tier == 1, "recommend first node for new student")
  playRound("percent", 1, 1.0, 0)
  node = M.Recommend("magister")
  ok(node ~= "percent", "recommend rotates to an untouched node")
  local text = ns.Report.Build({ player = "Tester-Realm" })
  ok(type(text) == "string" and text:find("Percentages", 1, true) and text:find("Tester-Realm", 1, true), "report builds")
  ok(not text:find("nil", 1, true), "report has no nils")

  local de = newNS("deDE")
  ok(de.L.ADDON_TITLE == "Azeroth Academy", "deDE falls back to enUS")
  ok(de.L.SOME_MISSING_KEY == "SOME_MISSING_KEY", "missing key falls back to key")
end

-------------------------------------------------------------------------
-- 7. v0.2: module registry - a new subject plugs in without touching the engine
-------------------------------------------------------------------------
do
  local tns = newNS()
  local Mods = tns.Modules
  tns.Progress.Bind({}, {})
  ok(Mods.list[1].id == "runeforger" and Mods.list[2].id == "scribe", "Rune Forger is module #1, Scribe's Scrolls #2")
  local function toyGen(level)
    local a = level * 2
    return { text = "Double " .. level .. " for the scribe.", answer = a, verify = level .. "*2==ANS",
      hint = "Add it to itself.", explain = level .. " + " .. level .. " = " .. a }
  end
  local toy = Mods.Register({
    id = "scribe_test", nameKey = "MOD_SCRIBE",
    bands = { initiate = { nodes = { "tst_a" } }, adept = { nodes = { "tst_b", "tst_c" } } },
    nodes = { tst_a = { key = "Toy A", gen = toyGen }, tst_b = { key = "Toy B", gen = toyGen }, tst_c = { key = "Toy C", gen = toyGen } },
    choiceOnlyBands = { initiate = true },
    inputMode = function(node, tier) if node.id == "tst_c" then return "input" end end,
  })
  ok(toy and Mods.Get("scribe_test") == toy, "toy module registered")
  local wordMod = Mods.Register({ id = "word_test", bands = { adept = { nodes = { "tst_w" } } },
    nodes = { tst_w = { key = "Toy W", gen = function() return { text = "Spell it", answer = "Murloc", verify = "true" } end } },
    check = function(p, given) return tostring(given):lower() == p.answer:lower() end })
  local pw = Mods.Generate("tst_w", 1, 2)
  ok(wordMod and Mods.Check(pw, "mURLOC") and not Mods.Check(pw, "gnoll"), "module check hook (text answers)")
  ok(not pcall(Mods.Register, { id = "scribe_test", bands = {}, nodes = {} }), "duplicate module id rejected")
  ok(not pcall(Mods.Register, { id = "dupe", bands = { adept = { nodes = { "times" } } }, nodes = { times = { gen = toyGen } } }),
    "node ids must be unique across modules")
  ok(not pcall(Mods.Register, { id = "half", bands = { adept = { nodes = { "ok1", "times" } } }, nodes = { ok1 = { gen = toyGen }, times = { gen = toyGen } } })
    and Mods.FindNode("ok1") == nil and Mods.Get("half") == nil, "a rejected module leaves no partial registration")
  ok(not pcall(Mods.Register, { id = "broken", bands = { adept = { nodes = { "x1" } } }, nodes = { x1 = {} } }), "node without gen rejected")
  local pa = Mods.Generate("tst_a", 3, 2)
  ok(pa.mode == "choice" and #pa.choices == 3, "choice-only band honoured for a new module")
  local pc = Mods.Generate("tst_c", 3, 1)
  ok(pc.mode == "input", "module inputMode override honoured")
  local sess = tns.Session.New("tst_b", 1, 0)
  ok(sess and sess.moduleId == "scribe_test", "engine runs a round on the new module")
  local clk = 0
  while true do
    local p = sess:Next(clk)
    if not p then break end
    clk = clk + 2
    local r = sess:Submit(p.answer, clk)
    ok(r.correct, "toy answer accepted")
  end
  local sum = sess:Finish()
  ok(sum.completed and sum.firstCorrect == 6, "toy round completes")
  ok(tns.Progress.char.modules.scribe_test.nodes.tst_b.tiers[1].attempts == 6, "progress stored under the module's own state")
  ok(tns.Progress.char.modules.runeforger == nil or next(tns.Progress.char.modules.runeforger.nodes) == nil, "no leakage into Rune Forger")
  ok(tns.Report.Build({}):find("Toy B", 1, true), "report covers every registered module")
  local tr = tns.Trial.New("scribe_test", "adept", "placement", 0)
  ok(tr and tr.total == 4, "trials work for any module (2 skills x 2)")
end

-------------------------------------------------------------------------
-- 8. v0.2: placement trial (The Forgemaster's Trial)
-------------------------------------------------------------------------
local function runTrial(tns, band, kind, pattern, moduleId)
  local tr = tns.Trial.New(moduleId or "runeforger", band, kind, 0)
  local i, levels = 0, {}
  while true do
    local p = tr:Next(i)
    if not p then break end
    i = i + 1
    levels[i] = p.level
    if moduleId and moduleId ~= "runeforger" then
      ok(p.mode ~= "choice" or p.choiceOnly or band == "initiate", "scribe trial: buttons only for choice-only problems")
    elseif band ~= "initiate" then ok(p.mode == "input", "trial uses typed answers for older bands") else ok(p.mode == "choice", "trial uses buttons for Initiate") end
    local right = pattern(i, tr.step)
    local r = tr:Submit(answerFor(p, right), i)
    ok(r.final and not r.retry and r.correct == right, "trial: one try, no hints")
    ok(tr:Submit(p.answer, i) == nil, "trial: no second try")
  end
  return tr:Finish(), levels, tr
end

do
  local tns = newNS()
  local TP, TT, TM = tns.Progress, tns.Trial, tns.Mastery
  local save = answerFor
  TP.Bind({}, {})
  TP.SetBand("adept")
  ok(TT.NeedsPlacement("runeforger", "adept"), "fresh profile needs placement")
  local shardsBefore = TP.char.shards
  local res, levels = runTrial(tns, "adept", "placement", function() return true end)
  ok(res.completed and res.correct == 10 and res.total == 10, "perfect placement 10/10")
  ok(levels[1] == 2 and levels[2] == 4, "adaptive: level 2 then 4 after a correct answer")
  ok(TP.char.shards - shardsBefore == TT.PLACEMENT_SHARDS, "placement awards shards")
  ok(not TT.NeedsPlacement("runeforger", "adept"), "placement recorded")
  ok(TT.StartTier("times") == 3 and TM.IsTierUnlocked("times", 3) and TM.CurrentTier("times") == 3, "perfect trial starts at Glyph")
  ok(not TP.GetTierRec("times", 1).mastered, "placement never fakes mastery")
  ok(TM.IsTierUnlocked("times", 2), "lower tiers stay playable")

  res, levels = runTrial(tns, "adept", "placement", function(_, step) return step == 1 end)
  ok(levels[2] == 4, "second problem harder after a right answer")
  ok(res.perSkill.times.level == 2 and TT.StartTier("division") == 2, "right then wrong = start at Rune")
  ok(not TM.IsTierUnlocked("division", 3), "Glyph stays locked when placed at Rune")

  res, levels = runTrial(tns, "adept", "placement", function() return false end)
  ok(levels[2] == 1, "second problem easier after a miss")
  ok(res.perSkill.word.level == 1 and TM.CurrentTier("word") == 1 and not TM.IsTierUnlocked("word", 2), "all wrong = Spark")
  local pl = TT.GetPlacement("runeforger", "adept")
  ok(#pl.history == 3 and pl.history[1].correct == 10, "history keeps the first placement as baseline")

  ok(TT.SetOverride("word", 3) and TT.StartTier("word") == 3 and TM.IsTierUnlocked("word", 3), "parent override raises start tier")
  ok(TT.SetOverride("times", 1) and TT.StartTier("times") == 1, "parent override lowers start tier")
  ok(not TT.SetOverride("times", 7), "invalid override rejected")
  TT.ResetPlacement("runeforger", "adept")
  ok(TT.NeedsPlacement("runeforger", "adept") and #TT.GetPlacement("runeforger", "adept").history == 3, "re-run keeps history")
  runTrial(tns, "adept", "placement", function() return true end)
  ok(TT.StartTier("times") == 3, "a fresh trial replaces parent overrides")

  -- unfinished trial changes nothing
  local tr = TT.New("runeforger", "magister", "placement", 0)
  local p = tr:Next(0)
  tr:Submit(p.answer, 1)
  local r2 = tr:Finish()
  ok(not r2.completed and TT.NeedsPlacement("runeforger", "magister"), "unfinished trial is not saved")
  TT.Skip("runeforger", "magister")
  ok(not TT.NeedsPlacement("runeforger", "magister") and TT.StartTier("percent") == 1, "skip = no trial, start at Spark")

  -- initiate trial uses buttons; random answers never error
  for _ = 1, 30 do runTrial(tns, "initiate", "placement", function() return math.random() < 0.5 end) end
  answerFor = save
end

-------------------------------------------------------------------------
-- 9. v0.2: spaced review (1, 3, 7 days) and fading
-------------------------------------------------------------------------
do
  local tns = newNS()
  local NOW = 1800000000
  tns.Env.time = function() return NOW end
  local RP, RR, RS, RM = tns.Progress, tns.Review, tns.Session, tns.Mastery
  RP.Bind({}, {})
  RP.SetBand("adept")
  local DAY = RR.DAY
  local function round(nodeId, tier, pc)
    local s = RS.New(nodeId, tier, 0)
    local c = 0
    while true do
      local p = s:Next(c)
      if not p then break end
      repeat c = c + 1; local r = s:Submit(answerFor(p, math.random() < pc), c) until r.final
    end
    return s:Finish()
  end
  local function review(items, pc)
    local s = RS.NewReview(items, 0)
    local c = 0
    while true do
      local p = s:Next(c)
      if not p then break end
      ok(p.level == 2, "review uses fixed mid-tier difficulty (Spark=2)")
      repeat c = c + 1; local r = s:Submit(answerFor(p, math.random() < pc), c) until r.final
    end
    return s:Finish(), s
  end
  round("times", 1, 1.0); round("times", 1, 1.0)
  local rec = RP.GetTierRec("times", 1)
  ok(rec.mastered and rec.review and rec.review.stage == 1 and rec.review.due == NOW + DAY, "mastery schedules a 1-day review")
  ok(#RR.Due() == 0, "nothing due on day 0")
  NOW = NOW + DAY
  local due = RR.Due()
  ok(#due == 1 and due[1].nodeId == "times" and due[1].tier == 1, "review due after 1 day")
  local sum, s = review(due, 1.0)
  ok(s.total == 3 and sum.mode == "review" and sum.reviews[1].passed, "perfect review passes (3 problems)")
  ok(rec.review.stage == 2 and rec.review.due == NOW + 3 * DAY, "next review in 3 days")
  NOW = NOW + 2 * DAY
  ok(#RR.Due() == 0, "not due before 3 days")
  NOW = NOW + DAY
  review(RR.Due(), 1.0)
  ok(rec.review.stage == 3 and rec.review.due == NOW + 7 * DAY, "next review in 7 days")
  NOW = NOW + 7 * DAY
  sum = review(RR.Due(), 1.0)
  ok(rec.review.done and sum.reviews[1].solid and #RR.Due() == 0, "after the 7-day review the rune is solid")
  NOW = NOW + 100 * DAY
  ok(#RR.Due() == 0, "solid runes never come back")

  -- failing a review: fading, no loss
  round("division", 1, 1.0); round("division", 1, 1.0)
  local drec = RP.GetTierRec("division", 1)
  NOW = NOW + DAY
  local shards = RP.char.shards
  sum = review(RR.Due(), 0.0)
  ok(not sum.reviews[1].passed and drec.fading and drec.mastered, "missed review = fading, mastery kept")
  ok(RP.char.shards >= shards, "missed review takes nothing away")
  ok(drec.review.stage == 1 and drec.review.due == NOW + DAY, "fading tier restarts at 1 day")
  ok(#RR.Fading() == 1, "fading list")
  local rn, rt = RM.Recommend("adept")
  ok(rn == "division" and rt == 1, "quick drill suggests the fading rune first")
  round("division", 1, 1.0)
  ok(not drec.fading, "a strong practice round clears fading")

  -- two items in one review; reviews can be switched off
  round("placevalue", 1, 1.0); round("placevalue", 1, 1.0)
  round("fractions", 1, 1.0); round("fractions", 1, 1.0)
  NOW = NOW + DAY
  due = RR.Due()
  ok(#due >= 2, "several reviews due")
  local _, s2 = review(due, 1.0)
  ok(s2.total == 6 and #s2.reviewResults == 2, "review round covers 2 runes x 3 problems")
  RP.account.settings.reviews = false
  NOW = NOW + 30 * DAY
  ok(#RR.Due() == 0, "parent can switch reviews off")
  RP.account.settings.reviews = true
  ok(#RR.Due() > 0, "and back on")
  -- leaving a review early changes nothing
  local before = RR.Due()[1]
  local sx = RS.NewReview({ before }, 0)
  local px = sx:Next(0)
  sx:Submit(answerFor(px, false), 1); sx:Submit(answerFor(px, false), 2)
  sx:Finish()
  ok(not RP.GetTierRec(before.nodeId, before.tier).fading, "unfinished review is not applied")
end

-------------------------------------------------------------------------
-- 10. v0.2: post-test (Rune Mastery Exam) + placement comparison
-------------------------------------------------------------------------
do
  local tns = newNS()
  local EP, ET = tns.Progress, tns.Trial
  EP.Bind({}, {})
  EP.SetBand("magister")
  runTrial(tns, "magister", "placement", function(i) return i % 3 == 0 end)
  local unlocked, done, need = ET.ExamStatus("runeforger", "magister")
  ok(not unlocked and done == 0 and need == 4, "exam locked until 4 of 5 skills are mastered")
  for i, nodeId in ipairs(tns.Modules.Nodes("runeforger", "magister")) do
    if i <= 3 then EP.GetTierRec(nodeId, 2).mastered = true end
  end
  ok(not ET.ExamStatus("runeforger", "magister"), "3 of 5 is not enough")
  EP.GetTierRec("equations", 3).mastered = true
  unlocked, done = ET.ExamStatus("runeforger", "magister")
  ok(unlocked and done == 4, "Rune or Glyph mastery on 4 of 5 unlocks the exam")
  local shards, mins = EP.char.shards, EP.account.minutes.earned
  local res = runTrial(tns, "magister", "exam", function() return true end)
  ok(res.passed and res.firstPass, "perfect exam passes")
  ok(EP.char.shards - shards == ET.EXAM_SHARDS + ET.EXAM_PASS_SHARDS, "exam pass shards")
  ok(EP.account.minutes.earned - mins == 10, "exam pass bonus minutes")
  ok(not ET.NeedsPlacement("runeforger", "magister") and ET.StartTier("percent") ~= nil, "exam does not touch placement")
  shards = EP.char.shards
  local res2 = runTrial(tns, "magister", "exam", function() return false end)
  ok(not res2.passed and not res2.firstPass and EP.char.shards - shards == ET.EXAM_SHARDS, "failed retake still rewards effort")
  local cmp = ET.Comparison("runeforger", "magister")
  ok(cmp.placement and cmp.exam and cmp.best and cmp.best.correct == 10 and cmp.exam.correct == 0 and cmp.passed, "comparison: baseline, latest, best")
  local text = tns.Report.Build({})
  ok(text:find("Growth:", 1, true) and text:find("Rune Mastery Exam", 1, true) and text:find("PASSED", 1, true), "report compares placement vs exam")
  EP.account.settings.unlockAllTiers = true
  ok(ET.ExamStatus("runeforger", "initiate"), "parent testing toggle unlocks the exam")
end

-------------------------------------------------------------------------
-- 11. v0.2: SavedVariables migration from v0.1
-------------------------------------------------------------------------
do
  local tns = newNS()
  local MT = 1700000000
  local account = {
    version = 1, settings = { minutesPerMastery = 15, dailyCap = 45, unlockAllTiers = false, taxiNudge = true },
    minutes = { day = "2026-11-13", earned = 20 }, pin = { salt = "123456", hash = "abc" }, ui = { point = "CENTER", x = 5, y = 6 },
  }
  local char = {
    version = 1, profile = { band = "adept", created = 1 }, shards = 812,
    stats = { rounds = 9, problems = 54, firstCorrect = 45, time = 600 },
    nodes = {
      times = { tiers = {
        { attempts = 18, correct = 17, time = 90, recent = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, mastered = true, masteredAt = MT },
        { attempts = 4, correct = 2, time = 30, recent = { 1, 0, 1, 0 }, mastered = false },
        { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false } } },
    },
  }
  tns.Progress.Bind(account, char)
  local MP = tns.Progress
  ok(MP.migrated and char.version == MP.SCHEMA and account.version == MP.SCHEMA and MP.upgradedFrom == 1, "schema bumped to current")
  ok(char.nodes == nil, "old char.nodes removed")
  local rec = MP.GetTierRec("times", 1)
  ok(rec.mastered and rec.attempts == 18 and #rec.recent == 10, "v0.1 progress carried into module storage")
  ok(rec.review and rec.review.due == MT + tns.Review.DAY, "already-mastered tiers get a review schedule")
  ok(MP.GetTierRec("times", 2).attempts == 4 and MP.GetTierRec("times", 2).fading == false, "other tiers intact + new fields defaulted")
  ok(char.shards == 812 and char.stats.rounds == 9 and MP.GetBand() == "adept", "shards, stats, band kept")
  ok(account.settings.minutesPerMastery == 15 and account.settings.dailyCap == 45 and account.settings.reviews == true, "settings kept, new defaults added")
  ok(account.pin.hash == "abc" and account.ui.x == 5, "PIN and window position kept")
  ok(not tns.Trial.NeedsPlacement("runeforger", "adept"), "kids who already played are not forced into the trial")
  ok(tns.Trial.NeedsPlacement("runeforger", "magister"), "untouched bands still offer the trial")
  ok(#tns.Review.Due() == 1, "migrated mastered tier is due for review")
  tns.Progress.Bind(account, char)
  ok(not MP.migrated and MP.GetTierRec("times", 1).attempts == 18, "migration is idempotent")
  ok(tns.Report.Build({}):find("carried over from v0.1", 1, true), "report notes the migration")
end

-------------------------------------------------------------------------
-- 12. v0.3: Scribe's Scrolls word data validation (every entry)
-------------------------------------------------------------------------
do
  local D = ns.ScribeData
  local function nonEmpty(v) return type(v) == "string" and v:match("%S") ~= nil end
  local function ascii(v) return type(v) == "string" and not v:find("[^\32-\126]") end
  local function letters(v) return type(v) == "string" and v:match("^[a-z]+$") ~= nil end
  local function uniqueBy(list, field, name)
    local seen = {}
    for i, e in ipairs(list) do
      local k = type(e) == "table" and e[field] or e
      ok(k ~= nil and not seen[tostring(k):lower()], name .. ": duplicate or missing id '" .. tostring(k) .. "' at " .. i)
      seen[tostring(k):lower()] = true
    end
  end
  local function badList(name, w, bad)
    ok(type(bad) == "table" and #bad >= 2, name .. " " .. w .. ": needs 2+ misspellings")
    local seen = {}
    for _, b in ipairs(bad or {}) do
      ok(nonEmpty(b) and b:lower() ~= w:lower(), name .. " " .. w .. ": misspelling equals the word: " .. tostring(b))
      ok(not seen[b:lower()], name .. " " .. w .. ": duplicate misspelling " .. b)
      seen[b:lower()] = true
    end
  end
  local function lvOk(name, e) ok(e.lv == nil or (e.lv >= 1 and e.lv <= 5), name .. " " .. tostring(e.w) .. ": lv out of range") end

  uniqueBy(D.CVC, "w", "CVC")
  for _, e in ipairs(D.CVC) do
    ok(letters(e.w) and #e.w == 3 and e.w:sub(2, 2):match("[aeiou]") and not e.w:sub(1, 1):match("[aeiou]")
      and not e.w:sub(3, 3):match("[aeiou]"), "CVC shape: " .. e.w)
    ok(nonEmpty(e.def) and not e.def:lower():find(e.w, 1, true), "CVC def present and does not give away the word: " .. e.w)
  end
  uniqueBy(D.LETTER_WORDS, nil, "LETTER_WORDS")
  for _, w in ipairs(D.LETTER_WORDS) do ok(letters(w) and #w >= 3, "letter word: " .. w) end
  for name, list in pairs({ SIGHT = D.SIGHT, SPELL_A = D.SPELL_A, SPELL_M = D.SPELL_M }) do
    uniqueBy(list, "w", name)
    for _, e in ipairs(list) do
      ok(letters(e.w), name .. ": word must be lowercase letters: " .. e.w)
      badList(name, e.w, e.bad)
      lvOk(name, e)
      if e.s then
        local _, n = e.s:gsub("___", "")
        ok(n == 1 and ascii(e.s), name .. " " .. e.w .. ": sentence needs exactly one ___")
      end
      if e.def then ok(nonEmpty(e.def) and not e.def:lower():find(e.w, 1, true), name .. " " .. e.w .. ": def present, no giveaway") end
    end
  end
  for _, e in ipairs(D.SIGHT) do ok(e.s ~= nil, "SIGHT needs a sentence: " .. e.w) end
  for name, list in pairs({ MEANINGS = D.MEANINGS, CONTEXT_A = D.CONTEXT_A, CONTEXT_M = D.CONTEXT_M }) do
    uniqueBy(list, "w", name)
    local defs = {}
    for _, e in ipairs(list) do
      ok(letters(e.w) and nonEmpty(e.def), name .. ": entry " .. tostring(e.w))
      ok(not defs[e.def], name .. ": duplicate definition " .. tostring(e.def))
      defs[e.def] = true
      ok(not e.def:lower():find("%f[%a]" .. e.w .. "%f[%A]"), name .. " " .. e.w .. ": definition contains the word")
      lvOk(name, e)
      if e.s then ok(e.s:lower():find(e.w, 1, true) and ascii(e.s), name .. " " .. e.w .. ": sentence must use the word") end
    end
    ok(#list >= 8, name .. ": enough entries for 3 distractors")
  end
  for _, e in ipairs(D.MEANINGS) do ok(e.grp ~= nil, "MEANINGS group: " .. e.w) end
  -- near-synonym groups are never offered against each other
  for _, list in ipairs({ D.MEANINGS, D.CONTEXT_A, D.CONTEXT_M }) do
    local byDef = {}
    for _, e in ipairs(list) do byDef[e.def] = e end
    for _, e in ipairs(list) do
      for _ = 1, 20 do
        for _, d in ipairs(ns.Scribe.MeaningDistractors(list, e, "def")) do
          local o = byDef[d]
          ok(o and o ~= e and (e.grp == nil or o.grp ~= e.grp), "meaning distractor shares a group: " .. e.w .. " / " .. tostring(o and o.w))
        end
      end
    end
  end
  uniqueBy(D.SILENT_E, "w", "SILENT_E")
  for _, e in ipairs(D.SILENT_E) do
    ok(e.w == e.base .. "e" and nonEmpty(e.def), "silent e: " .. e.w .. " = " .. e.base .. " + e")
  end
  uniqueBy(D.DIGRAPH, "w", "DIGRAPH")
  for _, e in ipairs(D.DIGRAPH) do
    ok(e.w:find(e.dg, 1, true) and ({ sh = 1, ch = 1, th = 1, wh = 1, ck = 1 })[e.dg], "digraph present: " .. e.w)
    badList("DIGRAPH", e.w, e.wrong)
    ok(nonEmpty(e.def), "digraph def: " .. e.w)
  end
  uniqueBy(D.PLURALS, "one", "PLURALS")
  for _, e in ipairs(D.PLURALS) do
    badList("PLURALS", e.w, e.wrong)
    local k = e.kind
    if k == "s" then ok(e.w == e.one .. "s", "plural -s: " .. e.w)
    elseif k == "es" then ok(e.w == e.one .. "es" and e.one:match("[sxh]$"), "plural -es: " .. e.w)
    elseif k == "ies" then ok(e.w == e.one:sub(1, -2) .. "ies" and e.one:match("[^aeiou]y$"), "plural -ies: " .. e.w)
    elseif k == "ves" then ok(e.w:match("ves$") and e.one:match("fe?$"), "plural -ves: " .. e.w)
    else ok(k == "irregular", "plural kind: " .. e.w) end
  end
  for name, list in pairs({ SYNONYMS = D.SYNONYMS, ANTONYMS = D.ANTONYMS }) do
    local seen = {}
    for _, e in ipairs(list) do
      ok(D.WORD_CLUSTER[e.a] and D.WORD_CLUSTER[e.b], name .. ": cluster missing for " .. e.a .. "/" .. e.b)
      ok(e.a ~= e.b, name .. ": pair repeats a word")
      local key = e.a .. "/" .. e.b
      ok(not seen[key], name .. ": duplicate pair " .. key)
      seen[key] = true
      if name == "SYNONYMS" then ok(D.WORD_CLUSTER[e.a] == D.WORD_CLUSTER[e.b], "synonyms share a cluster: " .. key)
      else ok(D.WORD_CLUSTER[e.a] ~= D.WORD_CLUSTER[e.b], "antonyms differ in cluster: " .. key) end
      ok(#ns.Scribe.RelationDistractors(e.a, e.b) >= 3, name .. ": distractors available for " .. key)
    end
  end
  for name, list in pairs({ PREFIXES = D.PREFIXES, SUFFIXES = D.SUFFIXES, ROOTS = D.ROOTS }) do
    uniqueBy(list, "p", name)
    uniqueBy(list, "m", name .. " meanings")
    for _, e in ipairs(list) do ok(nonEmpty(e.ex) and nonEmpty(e.m), name .. ": " .. e.p) end
  end
  uniqueBy(D.AFFIX_BUILD, "w", "AFFIX_BUILD")
  for _, e in ipairs(D.AFFIX_BUILD) do
    badList("AFFIX_BUILD", e.w, e.bad)
    ok(nonEmpty(e.def) and (e.how == "prefix" or e.how == "suffix"), "affix build: " .. e.w)
    if e.lv < 5 then
      if e.how == "prefix" then ok(e.w:sub(-#e.base) == e.base, "prefix keeps the base: " .. e.w)
      else ok(e.w:sub(1, #e.base) == e.base, "suffix keeps the base: " .. e.w) end
    end
  end
  local seenS = {}
  for _, e in ipairs(D.CONFUSED) do
    local _, n = e.s:gsub("___", "")
    ok(n == 1 and ascii(e.s), "confused: one blank: " .. e.s)
    local found, uniq = 0, {}
    for _, c in ipairs(e.c) do
      if c == e.a then found = found + 1 end
      ok(not uniq[c:lower()], "confused: duplicate choice " .. c); uniq[c:lower()] = true
    end
    ok(found == 1 and #e.c >= 2 and nonEmpty(e.why), "confused: answer in choices once: " .. e.s)
    ok(not seenS[e.s], "confused: duplicate sentence"); seenS[e.s] = true
    if e.s:sub(1, 3) == "___" then ok(e.a:match("^%u"), "confused: capitalized at sentence start: " .. e.s) end
  end
  for name, t in pairs({ TYPE_WORDS = D.TYPE_WORDS, TYPE_PHRASES = D.TYPE_PHRASES, TYPE_SENTENCES = D.TYPE_SENTENCES }) do
    local seen = {}
    for lv = 1, 5 do
      ok(type(t[lv]) == "table" and #t[lv] >= 2, name .. ": level " .. lv .. " needs 2+ lines")
      for _, line in ipairs(t[lv] or {}) do
        ok(ascii(line) and nonEmpty(line) and line == ns.Scribe.Clean(line), name .. ": plain ASCII, clean spacing: " .. line)
        ok(not seen[line], name .. ": duplicate line " .. line); seen[line] = true
      end
    end
  end
end

-------------------------------------------------------------------------
-- 13. v0.3: Scribe generators, every node x level x tier x purpose
-------------------------------------------------------------------------
do
  local SC = ns.Scribe
  local Mods = ns.Modules
  local modes = { choice = 0, text = 0, typing = 0 }
  for _, band in ipairs({ "initiate", "adept", "magister" }) do
    for _, nodeId in ipairs(Mods.Nodes("scribe", band)) do
      local _, node = Mods.FindNode(nodeId)
      ok(ns.L[node.key] ~= node.key and ns.L[node.descKey] ~= node.descKey, "scribe node localized: " .. nodeId)
      for level = 1, 5 do
        for tier = 1, 3 do
          for _, purpose in ipairs({ "practice", "trial" }) do
            for _ = 1, math.max(20, math.floor(ITER / 6)) do
              local okk, p = pcall(Mods.Generate, nodeId, level, tier, purpose)
              local tag = string.format("[%s L%d T%d %s]", nodeId, level, tier, purpose)
              genCount = genCount + 1
              if ok(okk and type(p) == "table", tag .. " error: " .. tostring(p)) then
                tag = tag .. " '" .. tostring(p.text) .. "' ans=" .. tostring(p.answer)
                ok(type(p.answer) == "string" and p.answer:match("%S"), tag .. " answer must be a non-empty string")
                ok(type(p.text) == "string" and #p.text > 5 and not hasFormatLeftovers(p.text), tag .. " text")
                ok(type(p.hint) == "string" and #p.hint > 5 and not hasFormatLeftovers(p.hint), tag .. " hint")
                ok(type(p.explain) == "string" and #p.explain > 5 and not hasFormatLeftovers(p.explain), tag .. " explain")
                ok(modes[p.mode] ~= nil, tag .. " mode " .. tostring(p.mode))
                modes[p.mode] = (modes[p.mode] or 0) + 1
                if band == "initiate" and p.mode ~= "typing" then ok(p.mode == "choice", tag .. " Initiate uses buttons") end
                if p.mode == "choice" then
                  local n, seen, hits = #p.choices, {}, 0
                  ok(n >= 2 and n <= 4, tag .. " choice count " .. n)
                  if band == "initiate" then ok(n <= 3, tag .. " young kids get at most 3 choices") end
                  for _, c in ipairs(p.choices) do
                    ok(type(c) == "string" and c:match("%S"), tag .. " empty choice")
                    ok(not seen[c:lower()], tag .. " duplicate choice " .. tostring(c)); seen[c:lower()] = true
                    if c == p.answer then hits = hits + 1 end
                  end
                  ok(hits == 1, tag .. " answer appears exactly once in choices")
                  ok(Mods.Check(p, p.answer), tag .. " answer accepted")
                  for _, c in ipairs(p.choices) do
                    if c ~= p.answer then ok(not Mods.Check(p, c), tag .. " distractor accepted: " .. c) end
                  end
                elseif p.mode == "text" then
                  ok(Mods.Check(p, p.answer) and Mods.Check(p, "  " .. p.answer:upper() .. "  ") and Mods.Check(p, p.answer .. "."),
                    tag .. " text checker is case/space tolerant")
                  ok(not Mods.Check(p, p.answer .. "x") and not Mods.Check(p, p.answer:sub(2)), tag .. " text checker: letters must match")
                  for _, d in ipairs(p.distractors or {}) do ok(not Mods.Check(p, d), tag .. " misspelling accepted: " .. d) end
                  ok(not Mods.Check(p, "") and not Mods.Check(p, "   "), tag .. " blank rejected")
                else
                  local c1, info = Mods.Check(p, p.answer, { elapsed = 10, tier = tier })
                  ok(c1 and info and info.accuracy == 1 and info.wpm >= 0, tag .. " perfect typing accepted")
                  ok(not Mods.Check(p, "zzqx", { elapsed = 10, tier = tier }), tag .. " garbage typing rejected")
                end
              end
            end
          end
        end
      end
    end
  end
  ok(modes.choice > 0 and modes.text > 0 and modes.typing > 0, "scribe uses all three answer modes")
end

-------------------------------------------------------------------------
-- 14. v0.3: checker + typing scoring unit tests
-------------------------------------------------------------------------
do
  local SC = ns.Scribe
  local p = { mode = "text", answer = "treasure", moduleId = "scribe" }
  ok(ns.Modules.Check(p, "treasure") and ns.Modules.Check(p, " TREASURE ") and ns.Modules.Check(p, "Treasure!")
    and ns.Modules.Check(p, '"treasure"'), "text: case, spaces, quotes and end punctuation ignored")
  ok(not ns.Modules.Check(p, "tresure") and not ns.Modules.Check(p, "treasures") and not ns.Modules.Check(p, "trea sure"),
    "text: letters must be exact")
  p.accept = { "treasures" }
  ok(ns.Modules.Check(p, "Treasures"), "text: accept list")
  ok(SC.Levenshtein("kitten", "sitting") == 3 and SC.Levenshtein("", "abc") == 3 and SC.Levenshtein("abc", "abc") == 0, "levenshtein")
  ok(SC.TypingAccuracy("For the Horde!", "For the Horde!") == 1, "typing: perfect = 100%")
  ok(SC.TypingAccuracy("For the Horde!", "for   the horde!") == 1, "typing: spaces and case forgiven (Spark/Rune)")
  ok(SC.TypingAccuracy("For the Horde!", "for the horde!", true) < 1, "typing: case counts at Glyph")
  ok(math.abs(SC.TypingAccuracy("abcdefghij", "abcdefghiX") - 0.9) < 1e-9, "typing: one typo in 10 = 90%")
  ok(SC.TypingAccuracy("abc", "") == 0 and SC.TypingAccuracy("abc", "abcdefghijk") == 0, "typing: accuracy floors at 0")
  ok(SC.WPM(string.rep("a", 60), 12) == 60, "WPM: 60 chars in 12 s = 60 WPM")
  ok(SC.WPM("abcde", 0) == 60 and SC.WPM("abcde", nil) == 60, "WPM: elapsed clamps to 1 s")
  ok(SC.WPM(string.rep("a", 500), 1) == SC.MAX_WPM, "WPM capped")
  local tp = { mode = "typing", answer = "abcdefghij", moduleId = "scribe" }
  local c1 = ns.Modules.Check(tp, "abcdefghiX", { tier = 1, elapsed = 5 })
  local c2 = ns.Modules.Check(tp, "abcdefghiX", { tier = 2, elapsed = 5 })
  local c3 = ns.Modules.Check(tp, "abcdefghiX", { tier = 3, elapsed = 5 })
  ok(c1 and c2 and not c3, "typing pass mark: 85% / 90% / 95% by tier")
  -- typing through a real session: elapsed comes from the UI clock
  local tns = newNS()
  tns.Progress.Bind({}, {})
  local s = tns.Session.New("sc_type_sentences", 1, 100)
  local pr = s:Next(100)
  local r = s:Submit(pr.answer, 112)
  local expect = tns.Scribe.WPM(pr.answer, 12)
  ok(r.correct and r.typing and r.typing.wpm == expect and r.typing.accuracy == 1, "session passes elapsed time to typing scoring")
  ok(tns.Progress.GetTierRec("sc_type_sentences", 1).bestWpm == expect and r.newBestWpm, "best WPM recorded")
  pr = s:Next(200)
  r = s:Submit("zzqx", 203)
  ok(not r.correct and r.retry and (tns.Progress.GetTierRec("sc_type_sentences", 1).bestWpm == expect), "inaccurate typing never sets best WPM")
  ok(tns.Report.Build({ moduleId = "scribe" }):find("best " .. expect .. " WPM", 1, true), "report shows best WPM")
end

-------------------------------------------------------------------------
-- 15. v0.3: Scribe's Scrolls through the whole engine
-------------------------------------------------------------------------
do
  local tns = newNS()
  local NOW = 1800000000
  tns.Env.time = function() return NOW end
  local SP, ST, SR = tns.Progress, tns.Trial, tns.Review
  SP.Bind({}, {})
  for _, band in ipairs({ "initiate", "adept", "magister" }) do
    SP.SetBand(band)
    ok(ST.NeedsPlacement("scribe", band), "scribe offers its own trial: " .. band)
    local res = runTrial(tns, band, "placement", function() return true end, "scribe")
    ok(res.completed and res.correct == 10, "scribe placement perfect: " .. band)
    for _, nodeId in ipairs(tns.Modules.Nodes("scribe", band)) do
      ok(ST.StartTier(nodeId) == 3, "scribe start tier from trial: " .. nodeId)
    end
    runTrial(tns, band, "placement", function() return false end, "scribe")
    ok(ST.StartTier(tns.Modules.Nodes("scribe", band)[1]) == 1, "scribe all-wrong trial: Spark")
    ok(ST.NeedsPlacement("runeforger", band), "subjects keep separate placement: " .. band)
    -- practice to mastery, review, exam
    local nodes = tns.Modules.Nodes("scribe", band)
    for i, nodeId in ipairs(nodes) do
      for t = 1, 2 do
        if i <= 4 then
          for _ = 1, 2 do
            local s = tns.Session.New(nodeId, t, 0)
            local c = 0
            while true do
              local p = s:Next(c)
              if not p then break end
              c = c + 3
              s:Submit(p.answer, c)
            end
            s:Finish()
          end
          ok(SP.GetTierRec(nodeId, t).mastered, "scribe mastery through rounds: " .. nodeId .. " T" .. t)
        end
      end
    end
    ok(SP.char.modules.scribe.nodes[nodes[1]] ~= nil and SP.char.modules.runeforger.nodes[nodes[1]] == nil, "scribe data under its own module")
    ok(ST.ExamStatus("scribe", band), "scribe exam unlocks: " .. band)
    local ex = runTrial(tns, band, "exam", function() return true end, "scribe")
    ok(ex.passed and ex.firstPass and ex.minutes >= 0, "scribe exam passes: " .. band)
  end
  NOW = NOW + SR.DAY + 5
  local due = SR.Due()
  local anyScribe = false
  for _, d in ipairs(due) do if d.moduleId == "scribe" then anyScribe = true end end
  ok(anyScribe, "scribe tiers get spaced reviews")
  local s = tns.Session.NewReview(due, 0)
  local c = 0
  while true do
    local p = s:Next(c)
    if not p then break end
    repeat c = c + 2; local r = s:Submit(answerFor(p, false), c) until r.final
  end
  local sum = s:Finish()
  ok(sum.mode == "review" and #tns.Review.Fading() > 0, "scribe review can fade")
  local full = tns.Report.Build({})
  local only = tns.Report.Build({ moduleId = "scribe" })
  ok(full:find("RUNE FORGER", 1, true) and full:find("SCRIBE'S SCROLLS", 1, true), "full report covers both subjects")
  ok(only:find("SCRIBE'S SCROLLS", 1, true) and not only:find("RUNE FORGER", 1, true), "report can filter to one subject")
  ok(only:find("The Scribe's Trial vs Scroll Mastery Exam", 1, true) and only:find("Growth:", 1, true), "scribe placement vs exam in report")
  ok(tns.Mastery.Recommend("magister", "scribe") ~= nil, "quick drill recommends scribe skills")
end

-------------------------------------------------------------------------
-- 16. v0.3: migration from v0.2 SavedVariables
-------------------------------------------------------------------------
do
  local tns = newNS()
  local account = { version = 2, settings = { minutesPerMastery = 12, dailyCap = 50, unlockAllTiers = false, taxiNudge = false, reviews = false },
    minutes = { day = "2026-11-13", earned = 24 }, pin = { salt = "999999", hash = "zzz" }, ui = { point = "TOP", x = 1, y = 2 } }
  local char = { version = 2, profile = { band = "magister", created = 5 }, shards = 2222,
    stats = { rounds = 30, problems = 180, firstCorrect = 150, time = 900 },
    modules = { runeforger = {
      nodes = { percent = { tiers = {
        { attempts = 12, correct = 11, time = 60, recent = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, mastered = true, masteredAt = 1, fading = true,
          review = { stage = 2, due = 99 } },
        { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false, fading = false },
        { attempts = 0, correct = 0, time = 0, recent = {}, mastered = false, fading = false } } } },
      placement = { magister = { status = "done", date = 1, result = { correct = 7, total = 10, perSkill = {} }, history = { { correct = 7 } },
        override = { percent = 2 } } },
      exams = { magister = { attempts = { { correct = 9, total = 10 } }, best = { correct = 9, total = 10, avgLevel = 2.6 }, passed = true } },
    } } }
  tns.Progress.Bind(account, char)
  local P3 = tns.Progress
  ok(char.version == P3.SCHEMA and account.version == P3.SCHEMA and P3.upgradedFrom == 2 and not P3.migrated, "v0.2 -> v0.3 schema bump")
  local rec = P3.GetTierRec("percent", 1)
  ok(rec.mastered and rec.fading and rec.review.stage == 2 and rec.review.due == 99, "v0.2 review state untouched")
  ok(tns.Trial.StartTier("percent") == 2 and not tns.Trial.NeedsPlacement("runeforger", "magister"), "v0.2 placement + override kept")
  ok(char.modules.runeforger.exams.magister.passed, "v0.2 exam kept")
  ok(account.settings.reviews == false and account.settings.taxiNudge == false and account.pin.hash == "zzz", "v0.2 settings + PIN kept")
  ok(char.shards == 2222 and char.stats.rounds == 30 and P3.GetBand() == "magister", "v0.2 shards/stats/band kept")
  ok(tns.Trial.NeedsPlacement("scribe", "magister"), "new subject offers its trial after upgrade")
  tns.Progress.Bind(account, char)
  ok(P3.upgradedFrom == nil and char.version == P3.SCHEMA, "v0.3 migration idempotent")
end

-------------------------------------------------------------------------
-- 17. v0.4: Fizzwick dialogue, cameos, sound registry, neutral hosts, schema 4
-------------------------------------------------------------------------
do
  local tns = newNS()
  local Gd, L, en = tns.Guide, tns.L, tns.LocaleData.enUS
  tns.Progress.Bind({}, {})
  -- every event has lines; every line is clean
  for _, ev in ipairs(Gd.EVENTS) do
    local n = Gd.Count("FZ_" .. ev)
    ok(n >= 2, "Fizzwick has lines for " .. ev .. " (" .. n .. ")")
    for i = 1, n do
      local text = en["FZ_" .. ev .. "_" .. i]
      if ev == "HINT" then
        local _, c = text:gsub("%%s", "")
        ok(c == 1, "hint line " .. i .. " has exactly one %s")
      else
        ok(not hasFormatLeftovers(text), "FZ_" .. ev .. "_" .. i .. " has no placeholders")
      end
      ok(#text <= 110, "FZ_" .. ev .. "_" .. i .. " is short enough for the strip")
    end
  end
  -- never mocks a wrong answer
  local banned = { "stupid", "dumb", "idiot", "wrong again", "obviously", "easy one", "silly", "terrible", "bad at", "loser", "fail" }
  for _, ev in ipairs({ "WRONG", "EXAMTRY", "FADING", "BOARDWHEEL", "BOARDLOSE" }) do
    for i = 1, Gd.Count("FZ_" .. ev) do
      local t = en["FZ_" .. ev .. "_" .. i]:lower()
      for _, b in ipairs(banned) do ok(not t:find(b, 1, true), "encouragement line has no '" .. b .. "': " .. t) end
    end
  end
  -- shuffle bag: no repeats inside a bag, never the same line twice in a row
  for _, ev in ipairs(Gd.EVENTS) do
    local n = Gd.Count("FZ_" .. ev)
    Gd.ResetBags()
    local last
    for round = 1, 6 do
      local seen = {}
      for _ = 1, n do
        local _, key = Gd.Line(ev, "x")
        ok(not seen[key], ev .. " repeats inside one bag")
        ok(key ~= last, ev .. " never says the same line twice in a row")
        seen[key], last = true, key
      end
      local cnt = 0
      for _ in pairs(seen) do cnt = cnt + 1 end
      ok(cnt == n, ev .. " uses every line once per bag (round " .. round .. ")")
    end
  end
  local hintText = Gd.Line("HINT", "Count up!")
  ok(hintText:find("Count up!", 1, true) ~= nil, "hint text is inserted into the parrot line")
  ok(Gd.Line("NO_SUCH_EVENT") == nil, "unknown event says nothing")

  -- cameos
  local function freshCameo() Gd.lastCameoAt = nil end
  freshCameo()
  ok(Gd.Cameo("RANKUP", "Neutral", 1000, {}) == nil, "neutral: no cameo")
  ok(Gd.Cameo("RANKUP", nil, 1000, {}) == nil, "unknown faction: no cameo")
  ok(Gd.Cameo("CORRECT", "Horde", 1000, {}) == nil, "cameos only on big moments")
  ok(Gd.Cameo("RANKUP", "Horde", 1000, { cameos = false }) == nil, "parent can turn cameos off")
  local c = Gd.Cameo("RANKUP", "Horde", 1000, { cameos = true })
  ok(c and c.who == "horde" and c.name == L.CAMEO_HORDE_NAME and c.cast.displays[1] == 4527 and c.text ~= "", "Horde gets Thrall")
  ok(Gd.Cameo("EXAMPASS", "Horde", 1000 + Gd.CAMEO_GAP - 1, {}) == nil, "cameos are rate limited")
  local a = Gd.Cameo("EXAMPASS", "Alliance", 1000 + Gd.CAMEO_GAP, {})
  ok(a and a.who == "alliance" and a.cast.displays[1] == 3597 and a.cast.creatures[1] == 2784 and a.name == L.CAMEO_ALLIANCE_NAME
    and L.CAMEO_ALLIANCE_NAME:find("Magni") and a.cast.icon, "Alliance gets Magni (with icon fallback) after the gap")
  for _, who in ipairs({ "HORDE", "ALLIANCE" }) do
    for kind in pairs(Gd.CAMEO_KINDS) do
      ok(Gd.Count("CAMEO_" .. who .. "_" .. kind) >= 2, who .. " has " .. kind .. " cameo lines")
    end
  end
  ok(not Gd.IsMilestone(0) and not Gd.IsMilestone(4) and Gd.IsMilestone(5) and Gd.IsMilestone(10), "milestone every 5th mastery")
  ok(Gd.CAST.fizzwick.displays[1] == 7340 and Gd.CAST.fizzwick.icon and Gd.CAST.parrot.icon, "Fizzwick cast has model + icon fallback")

  -- faction-neutral host framing (lessons may mention any city; the HOSTS may not pick a side)
  local hostKeys = { "FORGE_LORE", "FORGE_TIER_HELP", "TRIAL_PLACEMENT_LORE", "TRIAL_EXAM_LORE", "SCRIBE_LORE", "SCRIBE_TRIAL_LORE",
    "SCRIBE_EXAM_LORE", "LORE_LORE", "LORE_TRIAL_LORE", "LORE_EXAM_LORE", "LORE_TRIAL_RESULT", "LORE_TRIAL_RIGHT",
    "LORE_TRIAL_WRONG", "LQ_LORE", "FZ_INTRO", "PRAISE_1", "PRAISE_2", "PRAISE_3", "PRAISE_4", "PRAISE_5", "REVIEW_RUNES", "REVIEW_BUTTON", "REVIEW_DUE_CHAT", "REVIEW_TITLE" }
  for _, ev in ipairs(Gd.EVENTS) do
    for i = 1, Gd.Count("FZ_" .. ev) do hostKeys[#hostKeys + 1] = "FZ_" .. ev .. "_" .. i end
  end
  local sided = { "Stormwind", "Orgrimmar", "Ironforge", "Darnassus", "Undercity", "Thunder Bluff", "Kirin Tor", "Dalaran", "Khadgar", "Alliance", "Horde" }
  for _, k in ipairs(hostKeys) do
    local t = en[k]
    ok(t ~= nil, "host string exists: " .. k)
    for _, w in ipairs(sided) do ok(not (t or ""):find(w, 1, true), k .. " stays faction-neutral (found " .. w .. ")") end
  end
  for _, k in ipairs({ "REVIEW_RUNES", "REVIEW_BUTTON", "REVIEW_DUE_CHAT", "REVIEW_TITLE", "NO_REVIEWS" }) do
    ok(not en[k]:lower():find("rune", 1, true), k .. " is subject-neutral")
  end

  -- sound registry
  local SE = tns.SoundEvents
  local need = { "correct", "wrong", "combo", "overcharge", "forge", "scroll", "rankup", "exampass", "click", "chirp" }
  for _, e in ipairs(need) do ok(SE.EVENTS[e] ~= nil, "sound event " .. e .. " exists") end
  local inOrder = {}
  for _, e in ipairs(SE.ORDER) do inOrder[e] = true end
  for e, def in pairs(SE.EVENTS) do
    ok(inOrder[e], e .. " listed in ORDER")
    local hasNum = false
    for _, k in ipairs(def.kits) do if type(k) == "number" then hasNum = true end end
    ok(hasNum, e .. " has a numeric SoundKit fallback")
    ok(SE.FilePath(e) == "Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\" .. e .. ".ogg", e .. " custom path")
  end
  local plan = SE.Plan("correct", nil, nil)
  ok(plan[1].file and plan[2].kit == "IG_QUEST_LIST_COMPLETE" and plan[3].kit == 878, "default plan: custom file then kits")
  ok(SE.Plan("correct", { enabled = false }) == nil, "mute plays nothing")
  ok(SE.Plan("click", { level = "important" }) == nil and SE.Plan("correct", { level = "important" }) ~= nil, "important-only filter")
  ok(SE.Plan("correct", { custom = false })[1].kit ~= nil, "custom files can be turned off")
  ok(SE.Plan("correct", {}, { correct = true })[1].kit ~= nil, "a missing custom file is skipped")
  ok(SE.Plan("nope", {}) == nil, "unknown sound event is ignored")
  ok(SE.Channel({ channel = "Dialog" }) == "Dialog" and SE.Channel({ channel = "Bogus" }) == "SFX" and SE.Channel(nil) == "SFX", "channel validation")
  ok(SE.Cycle(SE.CHANNELS, "Ambience") == "SFX" and SE.Cycle(SE.LEVELS, "all") == "important", "setting cycles wrap")
  -- the README documents every event + the voice brief
  local f = io.open("Media/Sounds/README.md")
  ok(f ~= nil, "Media/Sounds/README.md exists")
  if f then
    local readme = f:read("*a")
    f:close()
    for e in pairs(SE.EVENTS) do ok(readme:find("`" .. e .. ".ogg`", 1, true) ~= nil, "README lists " .. e .. ".ogg") end
    ok(readme:find("Voice design brief", 1, true) ~= nil, "README has the narrator voice brief")
    -- v0.8: voice section documents the voice_id and every clip
    ok(readme:find(tns.Voice.VOICE_ID, 1, true) ~= nil, "README records the voice_id")
    for _, clip in pairs(tns.Voice.LINES) do ok(readme:find("`VO/" .. clip.file .. ".ogg`", 1, true) ~= nil, "README lists VO/" .. clip.file .. ".ogg") end
    for _, clip in pairs(tns.Voice.EVENT_CLIPS) do ok(readme:find("`VO/" .. clip.file .. ".ogg`", 1, true) ~= nil, "README lists VO/" .. clip.file .. ".ogg") end
  end

  -- v0.8: every sound file the addon references exists in the package folder,
  -- is a real Ogg file, and isn't excluded by the packager
  local function isOgg(path)
    local fh = io.open(path, "rb")
    if not fh then return false end
    local magic = fh:read(4)
    local size = fh:seek("end")
    fh:close()
    return magic == "OggS" and size > 1000
  end
  local referenced = {}
  for e in pairs(SE.EVENTS) do referenced[#referenced + 1] = "Media/Sounds/" .. e .. ".ogg" end
  for _, clip in pairs(tns.Voice.LINES) do referenced[#referenced + 1] = "Media/Sounds/VO/" .. clip.file .. ".ogg" end
  for _, clip in pairs(tns.Voice.EVENT_CLIPS) do referenced[#referenced + 1] = "Media/Sounds/VO/" .. clip.file .. ".ogg" end
  ok(#referenced >= 30, "at least 30 referenced sound files (got " .. #referenced .. ")")
  for _, path in ipairs(referenced) do ok(isOgg(path), path .. " exists and is Ogg") end
  local pk = io.open("tools/pack.py")
  ok(pk ~= nil, "tools/pack.py exists")
  if pk then
    local src = pk:read("*a")
    pk:close()
    local skip = src:match("SKIP_EXT = (%b())") or ""
    ok(skip ~= "" and not skip:find("ogg", 1, true), "packager does not exclude .ogg files")
  end

  -- v0.8: Fizzwick's voice rules
  local V = tns.Voice
  local en0 = tns.LocaleData.enUS
  local isEvent = {}
  for _, e in ipairs(tns.Guide.EVENTS) do isEvent[e] = true end
  for key, clip in pairs(V.LINES) do
    ok(en0[key] ~= nil, key .. " (voiced) exists in enUS")
    ok(type(clip.dur) == "number" and clip.dur > 0.5 and clip.dur < 7, key .. " has a measured duration under 7 s")
    local ev = key:match("^FZ_(.+)_%d+$")
    ok(ev == "BYE" or isEvent[ev] or ev == "FLIGHTSTART" or ev == "FLIGHTLAND", key .. " belongs to a Guide event")
    ok(V.KeyFor(ev) == key, "KeyFor(" .. ev .. ") finds " .. key)
  end
  ok(V.KeyFor("NOPE") == nil, "no clip for unknown events")
  ok(V.Path(V.LINES.FZ_GREET_1) == "Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\VO\\greet.ogg", "VO path")
  ok(V.Enabled(nil) and V.Enabled({}) and V.Enabled({ voice = { enabled = true } }), "voice on by default")
  ok(not V.Enabled({ voice = { enabled = false } }), "voice can be switched off")
  ok(not V.Enabled({ sound = { enabled = false } }), "sound mute silences the voice too")
  local vs = V.NewState()
  ok(V.PreferKey(vs, "CORRECT", {}, 0) == "FZ_CORRECT_1", "first CORRECT prefers the voiced line")
  ok(V.Decide(vs, "CORRECT", "FZ_CORRECT_2", 0, {}) == nil, "an unvoiced line plays nothing")
  local c1 = V.Decide(vs, "CORRECT", "FZ_CORRECT_1", 0, {})
  ok(c1 == V.LINES.FZ_CORRECT_1, "voiced line plays with its own text")
  V.Started(vs, "CORRECT", c1, 0)
  ok(V.PreferKey(vs, "CORRECT", {}, 100) == nil, "voiced line is only forced once per session")
  local _, why = V.Decide(vs, "COMBO", "FZ_COMBO_1", 1, {})
  ok(why == "busy", "nothing overlaps a clip that is still playing")
  ok(V.PreferKey(vs, "COMBO", {}, 1) == nil, "no forced line while another clip talks")
  _, why = V.Decide(vs, "COMBO", "FZ_COMBO_1", 4, {})
  ok(why == "gap", "minimum gap between clips")
  ok(V.Decide(vs, "COMBO", "FZ_COMBO_1", 9, {}) ~= nil, "plays after the gap")
  _, why = V.Decide(vs, "CORRECT", "FZ_CORRECT_1", 20, {})
  ok(why == "repeat", "same clip is throttled")
  ok(V.Decide(vs, "CORRECT", "FZ_CORRECT_1", 60, {}) ~= nil, "same clip again after the repeat gap")
  ok(V.Decide(vs, "RANKUP", "FZ_RANKUP_1", 1, {}) ~= nil, "rank-up may interrupt")
  ok(V.Decide(vs, "HINT", nil, 60, {}) == V.EVENT_CLIPS.HINT, "parrot hint uses the event clip")
  _, why = V.Decide(vs, "HINT", nil, 60, { voice = { enabled = false } })
  ok(why == "off", "voice off plays nothing")
  vs.missing.combo = true
  _, why = V.Decide(vs, "COMBO", "FZ_COMBO_1", 200, {})
  ok(why == "missing", "a file that failed is not retried")
  -- LineKey returns that exact line and takes it out of the bag
  tns.Guide.ResetBags()
  local lt, lk = tns.Guide.LineKey("FZ_CORRECT_1")
  ok(lk == "FZ_CORRECT_1" and lt == tns.L.FZ_CORRECT_1, "LineKey gives the exact line")
  local nextText, nextKey = tns.Guide.Line("CORRECT")
  ok(nextText and nextKey ~= "FZ_CORRECT_1", "the forced line doesn't come straight back")
  ok(tns.Guide.LineKey("FZ_NOPE_1") == nil, "LineKey ignores unknown keys")

  -- modules declare their round-start sound
  ok(tns.Modules.Get("runeforger").startSound == "forge" and tns.Modules.Get("scribe").startSound == "scroll", "subject start sounds")

  -- TotalMastered counts across subjects
  local Pm = tns.Progress
  Pm.GetTierRec("add20", 1).mastered = true
  Pm.GetTierRec("sc_cvc", 1).mastered = true
  Pm.GetTierRec("sc_cvc", 2).mastered = true
  ok(Pm.TotalMastered() == 3, "TotalMastered counts every subject")
end

-- v0.3 -> v0.4 migration: settings defaults appear, nothing else moves
do
  local tns = newNS()
  local account = { version = 3, settings = { minutesPerMastery = 7, dailyCap = 33, unlockAllTiers = true, taxiNudge = false, reviews = false },
    minutes = { day = "2026-11-13", earned = 5 }, pin = { salt = "1", hash = "h" }, ui = {} }
  local char = { version = 3, profile = { band = "adept", created = 3 }, shards = 777,
    stats = { rounds = 4, problems = 24, firstCorrect = 20, time = 100 },
    modules = { scribe = { nodes = { sc_synonyms = { tiers = { { attempts = 5, correct = 5, time = 9, recent = { 1, 1, 1, 1, 1 }, mastered = false, fading = false, bestWpm = 31 } } } },
      placement = { adept = { status = "done", date = 1 } }, exams = {} } } }
  tns.Progress.Bind(account, char)
  local P4 = tns.Progress
  local st = account.settings
  ok(char.version == P4.SCHEMA and account.version == P4.SCHEMA and P4.upgradedFrom == 3 and not P4.migrated, "v0.3 -> v0.4 (-> current) schema bump")
  ok(st.flight.mode == "off", "v0.3 nudge-off parent gets in-flight lessons off")
  ok(st.sound and st.sound.enabled == true and st.sound.channel == "SFX" and st.sound.level == "all" and st.sound.custom == true, "sound defaults added")
  ok(st.reducedMotion == false and st.cameos == true, "motion + cameo defaults added")
  ok(st.minutesPerMastery == 7 and st.dailyCap == 33 and st.unlockAllTiers == true and st.reviews == false and st.taxiNudge == false, "old settings kept")
  ok(char.shards == 777 and P4.GetTierRec("sc_synonyms", 1).bestWpm == 31 and not tns.Trial.NeedsPlacement("scribe", "adept"), "v0.3 progress kept")
  -- an existing partial sound table keeps the parent's choices
  local acc2 = { version = 3, settings = { sound = { enabled = false, channel = "Dialog" } } }
  tns.Progress.Bind(acc2, { version = 3 })
  ok(acc2.settings.sound.enabled == false and acc2.settings.sound.channel == "Dialog" and acc2.settings.sound.level == "all", "partial sound settings merged, not overwritten")
  tns.Progress.Bind(account, char)
  ok(P4.upgradedFrom == nil and char.version == P4.SCHEMA, "v0.4 migration idempotent")
end

-------------------------------------------------------------------------
-- 18. v0.5: Lore Chronicles data, generators, rubric, engine; Lore Quiz; art slots
-------------------------------------------------------------------------
local loreGenCount = 0
do
  local tns = newNS()
  local D, LC, Mods = tns.LoreData, tns.Lore, tns.Modules
  local lower = string.lower
  local function distinct(answer, ds, tag, want)
    local seen = { [lower(answer)] = true }
    ok(type(ds) == "table" and #ds == want, tag .. " has " .. want .. " distractors")
    for _, d in ipairs(ds or {}) do
      ok(type(d) == "string" and d ~= "", tag .. " distractor is text")
      ok(not seen[lower(d)], tag .. " distractor repeats or equals the answer: " .. tostring(d))
      seen[lower(d)] = true
      ok(#d <= LC.MAX_CHOICE, tag .. " distractor too long: " .. tostring(d))
    end
    ok(#answer <= LC.MAX_CHOICE, tag .. " answer too long: " .. answer)
  end
  local function lvOk(e, tag) ok(e.lv == 1 or e.lv == 2 or e.lv == 3, tag .. " has lv 1-3") end
  local function levels(list, tag)
    local c = { 0, 0, 0 }
    for _, e in ipairs(list) do if c[e.lv] then c[e.lv] = c[e.lv] + 1 end end
    ok(c[1] > 0 and c[2] > 0 and c[3] > 0, tag .. " covers all three levels")
  end
  local function noDupes(list, field, tag)
    local seen = {}
    for _, e in ipairs(list) do
      local k = type(field) == "function" and field(e) or e[field]
      ok(not seen[k], tag .. " duplicate entry: " .. tostring(k))
      seen[k] = true
    end
  end

  -- Initiate data: answers are literal and found in the text
  for i, e in ipairs(D.SENTENCES) do
    local tag = "sentence " .. i
    lvOk(e, tag)
    ok(e.s:find(e.a, 1, true) ~= nil, tag .. " answer is in the sentence: " .. e.a)
    ok(e.q:sub(-1) == "?", tag .. " question ends with ?")
    distinct(e.a, e.d, tag, 2)
    for _, d in ipairs(e.d) do ok(not lower(e.s):find(lower(d), 1, true), tag .. " distractor also in the sentence: " .. d) end
  end
  levels(D.SENTENCES, "sentences"); noDupes(D.SENTENCES, "s", "sentences")
  for i, e in ipairs(D.STORIES) do
    local tag = "story " .. i
    lvOk(e, tag)
    for _, f in ipairs({ "who", "what", "where" }) do
      local q = e[f]
      ok(type(q) == "table" and q[1]:sub(-1) == "?", tag .. " " .. f .. " question")
      ok(e.text:find(q[2], 1, true) ~= nil, tag .. " " .. f .. " answer is in the story: " .. tostring(q[2]))
      distinct(q[2], q[3], tag .. " " .. f, 2)
    end
  end
  levels(D.STORIES, "stories"); noDupes(D.STORIES, "text", "stories")
  for i, e in ipairs(D.SEQUENCES) do
    local tag = "sequence " .. i
    lvOk(e, tag)
    ok(#e.steps == 3, tag .. " has 3 steps")
    distinct(e.steps[1], { e.steps[2], e.steps[3] }, tag, 2)
  end
  levels(D.SEQUENCES, "sequences")

  -- Adept data
  for i, e in ipairs(D.PASSAGES_A) do
    local tag = "adept passage " .. i
    lvOk(e, tag)
    distinct(e.main[1], e.main[2], tag .. " main", 3)
    distinct(e.feel[2], e.feel[3], tag .. " feel", 3)
    distinct(e.cause[2], e.cause[3], tag .. " cause", 3)
    distinct(e.vocab[2], e.vocab[3], tag .. " vocab", 3)
    ok((" " .. lower(e.text) .. " "):find("[^%a]" .. lower(e.vocab[1]) .. "[^%a]") ~= nil, tag .. " vocab word is in the passage: " .. e.vocab[1])
  end
  levels(D.PASSAGES_A, "adept passages"); noDupes(D.PASSAGES_A, function(e) return e.vocab[1] end, "vocab words")
  for i, e in ipairs(D.BUILD) do
    local tag = "build " .. i
    lvOk(e, tag)
    local tiles = LC.Tiles(e.s)
    ok(#tiles >= 5, tag .. " has at least 5 tiles")
    ok(table.concat(tiles, " ") .. "." == e.s, tag .. " tiles rebuild the sentence")
    local orders = LC.ScrambledOrders(e.s, 3)
    ok(#orders == 3, tag .. " gets 3 wrong orders")
    local sorted = { unpack(tiles) }; table.sort(sorted)
    for _, o in ipairs(orders) do
      ok(LC.Normalize(o) ~= LC.Normalize(e.s), tag .. " wrong order differs from the answer")
      local t2 = LC.Tiles(o)
      ok(t2[1] == tiles[1] and t2[#t2] == tiles[#tiles], tag .. " wrong order keeps first and last tile")
      table.sort(t2)
      ok(table.concat(t2, " ") == table.concat(sorted, " "), tag .. " wrong order uses the same tiles")
    end
    local shown, shuffled = LC.ShuffledTiles(e.s)
    ok(table.concat(shuffled, " ") ~= table.concat(tiles, " ") and shown:find("[", 1, true), tag .. " tiles shown shuffled")
  end
  levels(D.BUILD, "build sentences"); noDupes(D.BUILD, "s", "build sentences")

  -- Magister data
  for i, e in ipairs(D.PASSAGES_M) do
    local tag = "magister passage " .. i
    lvOk(e, tag)
    distinct(e.infer[2], e.infer[3], tag .. " infer", 3)
    distinct(e.purpose[1], e.purpose[2], tag .. " purpose", 3)
    distinct(e.summary[1], e.summary[2], tag .. " summary", 3)
    ok(e.purpose[1]:sub(1, 3) == "to ", tag .. " purpose reads 'to ...'")
  end
  levels(D.PASSAGES_M, "magister passages")
  for i, e in ipairs(D.COMPARE) do
    local tag = "compare " .. i
    lvOk(e, tag)
    ok(type(e.place) == "string" and e.horde ~= "" and e.alliance ~= "", tag .. " has a place and both accounts")
    ok(math.abs(#e.horde - #e.alliance) < 80, tag .. " both accounts get similar space")
    ok(#e.qs == 2, tag .. " has 2 questions")
    for j, q in ipairs(e.qs) do distinct(q[2], q[3], tag .. " q" .. j, 3) end
  end
  levels(D.COMPARE, "compare")
  for i, e in ipairs(D.GRAMMAR) do
    local tag = "grammar " .. i
    lvOk(e, tag)
    distinct(e.a, e.d, tag, 3)
    ok(type(e.why) == "string" and #e.why > 10, tag .. " explains why")
  end
  levels(D.GRAMMAR, "grammar"); noDupes(D.GRAMMAR, "a", "grammar")
  for i, e in ipairs(D.WRITE) do
    local tag = "written " .. i
    lvOk(e, tag)
    ok(e.need >= 1 and e.need <= #e.rubric, tag .. " need fits the rubric")
    ok(LC.Rubric(e.model, e.rubric, e.need), tag .. " model answer passes its own rubric")
    for _, d in ipairs(e.d) do ok(not LC.Rubric(d, e.rubric, e.need), tag .. " wrong answer passes the rubric: " .. d) end
    for _, junk in ipairs({ "I do not know", "zzqx", "yes", "the the the" }) do
      ok(not LC.Rubric(junk, e.rubric, e.need), tag .. " junk passes: " .. junk)
    end
    distinct(e.model, e.d, tag, 3)
  end
  levels(D.WRITE, "written")

  -- Lore Quiz data
  local quizNodes = Mods.Nodes("lorequiz", "everyone")
  ok(#quizNodes == 5, "quiz has 5 topics")
  for _, id in ipairs(quizNodes) do
    local list = D.QUIZ[id]
    ok(type(list) == "table" and #list == 12, id .. " has 12 questions")
    local c = { 0, 0, 0 }
    for i, e in ipairs(list or {}) do
      lvOk(e, id .. " " .. i)
      c[e.lv] = (c[e.lv] or 0) + 1
      distinct(e.a, e.d, id .. " " .. i, 3)
      ok(e.q:sub(-1) == "?", id .. " " .. i .. " is a question")
    end
    ok(c[1] == 4 and c[2] == 4 and c[3] == 4, id .. " has 4 questions per level")
    noDupes(list or {}, "q", id)
  end

  -- Rubric + checker unit tests
  ok(LC.Normalize("  Hello,   World! It's ") == "hello world its", "normalize")
  ok(LC.Rubric("They were old enemies who fought together.", { { "enem" }, { "together" } }, 2), "4+ letter keywords match as prefixes")
  ok(not LC.Rubric("He threw the ball very far.", { { "all" } }, 1), "short keywords must match whole words")
  ok(LC.Rubric("They fought side by side bravely.", { { "side by side" } }, 1), "multi-word keyword")
  ok(not LC.Rubric("enemies together", { { "enem" }, { "together" } }, 2), "written answers need 3+ words")
  local okR, matched, need = LC.Rubric("Old enemies were brave.", { { "enem" }, { "together" } }, 2)
  ok(not okR and matched == 1 and need == 2, "rubric counts matched key ideas")
  local pr = { mode = "text", rubric = { { "fish" }, { "sea" } }, need = 2, answer = "x" }
  local c1, info = LC.Check(pr, "She caught a fish in the sea.")
  ok(c1 and info.rubric and info.matched == 2 and info.need == 2, "rubric check returns info")
  local pb = { mode = "text", build = true, answer = "The wolf howled at the moon." }
  ok(LC.Check(pb, "the wolf howled at the moon") and LC.Check(pb, "  The  wolf howled at the moon!! "), "built sentence: case/punctuation forgiven")
  ok(not LC.Check(pb, "The moon howled at the wolf."), "built sentence: order matters")
  ok(LC.LevelFor(1) == 1 and LC.LevelFor(2) == 1 and LC.LevelFor(3) == 2 and LC.LevelFor(4) == 3 and LC.LevelFor(5) == 3, "level mapping")

  -- Shuffle bags: a full pool before any repeat
  for _, lv in ipairs({ 1, 3, 5 }) do
    local pool = LC.Pool(D.GRAMMAR, lv)
    tns.Lore.bags = {}
    local seen, dup = {}, false
    for _ = 1, #pool do
      local p = Mods.Generate("lc_grammar", lv, 1, "practice")
      if seen[p.answer] then dup = true end
      seen[p.answer] = true
    end
    ok(not dup, "shuffle bag: no repeats inside one pass (level " .. lv .. ")")
  end

  -- Generators: every node x level x tier x purpose
  local lore = Mods.Get("lore")
  for _, band in ipairs(Mods.BAND_ORDER) do
    for _, nodeId in ipairs(Mods.Nodes("lore", band)) do
      for level = 1, 5 do
        for tier = 1, 3 do
          for _, purpose in ipairs({ "practice", "trial" }) do
            for _ = 1, math.max(4, math.floor(ITER / 40)) do
              local okk, p = pcall(Mods.Generate, nodeId, level, tier, purpose)
              loreGenCount = loreGenCount + 1
              local tag = string.format("[%s L%d T%d %s]", nodeId, level, tier, purpose)
              if ok(okk and type(p) == "table", tag .. " generator error: " .. tostring(p)) then
                tag = tag .. " '" .. tostring(p.text):sub(1, 60) .. "'"
                ok(type(p.text) == "string" and #p.text > 10 and #p.text <= LC.MAX_TEXT, tag .. " text length " .. #tostring(p.text))
                ok(not hasFormatLeftovers(p.text) and not hasFormatLeftovers(p.hint) and not hasFormatLeftovers(p.explain), tag .. " format leftovers")
                if p.passage then ok(p.text:find(p.passage, 1, true) ~= nil, tag .. " passage is shown") end
                if p.word then ok(lower(p.passage):find(lower(p.word), 1, true) ~= nil, tag .. " vocab word in the passage") end
                if p.mode == "choice" then
                  local n, seen = 0, {}
                  for _, c in ipairs(p.choices) do
                    if c == p.answer then n = n + 1 end
                    ok(not seen[lower(c)], tag .. " duplicate choice " .. c)
                    seen[lower(c)] = true
                    ok(#c <= LC.MAX_CHOICE, tag .. " choice too long")
                  end
                  ok(n == 1, tag .. " answer appears exactly once")
                  ok(#p.choices == (band == "initiate" and 3 or 4), tag .. " number of buttons")
                  for _, c in ipairs(p.choices) do
                    ok(Mods.Check(p, c) == (c == p.answer), tag .. " check of choice " .. c)
                  end
                  if p.build or p.rubric then ok(tier == 1 and purpose == "practice", tag .. " typed skills only use buttons on Spark practice") end
                else
                  ok(p.mode == "text" and (p.build or p.rubric) and p.wide, tag .. " typed lore answers are wide build/written answers")
                  ok(band ~= "initiate", tag .. " initiate never types")
                  ok(Mods.Check(p, p.answer), tag .. " model answer accepted")
                  ok(not Mods.Check(p, "zzqx"), tag .. " junk rejected")
                end
              end
            end
          end
        end
      end
    end
  end
  ok(lore.choiceOnlyBands.initiate and lore.textAnswers, "lore module flags")

  -- Through the whole engine: trial, mastery, exam, review, report
  local NOW = 1800000000
  tns.Env.time = function() return NOW end
  local LP, LT, LR = tns.Progress, tns.Trial, tns.Review
  LP.Bind({}, {})
  for _, band in ipairs({ "initiate", "adept", "magister" }) do
    LP.SetBand(band)
    ok(LT.NeedsPlacement("lore", band), "lore offers its own trial: " .. band)
    local res = runTrial(tns, band, "placement", function() return true end, "lore")
    ok(res.completed and res.correct == 10, "lore placement perfect: " .. band)
    runTrial(tns, band, "placement", function() return false end, "lore")
    ok(LT.StartTier(Mods.Nodes("lore", band)[1]) == 1, "lore all-wrong trial: Spark")
    for i, nodeId in ipairs(Mods.Nodes("lore", band)) do
      for t = 1, 2 do
        if i <= 4 then
          for _ = 1, 2 do
            local s = tns.Session.New(nodeId, t, 0)
            local c = 0
            while true do
              local p = s:Next(c)
              if not p then break end
              c = c + 3
              s:Submit(p.answer, c)
            end
            s:Finish()
          end
          ok(LP.GetTierRec(nodeId, t).mastered, "lore mastery through rounds: " .. nodeId .. " T" .. t)
        end
      end
    end
    ok(LT.ExamStatus("lore", band), "lore exam unlocks: " .. band)
    local ex = runTrial(tns, band, "exam", function() return true end, "lore")
    ok(ex.passed and ex.firstPass, "lore exam passes: " .. band)
  end
  -- a typed written answer inside a session reports rubric info
  local ws = tns.Session.New("lc_written", 2, 0)
  local wp = ws:Next(0)
  ok(wp.mode == "text" and wp.rubric, "Rune-tier written answer is typed")
  local wr = ws:Submit("I do not know.", 5)
  ok(wr and not wr.correct and wr.typing and wr.typing.rubric and wr.typing.need == wp.need, "written answer miss reports key ideas")

  -- Lore Quiz for Everyone: unbanded, no trials, hidden from the hub
  local quiz = Mods.Get("lorequiz")
  ok(quiz.unbanded and quiz.noTrials and quiz.hidden, "quiz flags")
  for _, band in ipairs({ "initiate", "adept", "magister", "everyone" }) do
    ok(#Mods.Nodes("lorequiz", band) == 5, "quiz shows the same 5 topics for " .. band)
    ok(not LT.NeedsPlacement("lorequiz", band) and not LT.ExamStatus("lorequiz", band) and LT.New("lorequiz", band, "exam", 0) == nil, "quiz has no trials: " .. band)
  end
  ok(#Mods.BandIds(quiz) == 1 and #Mods.BandIds(lore) == 3, "band ids")
  local visibleQuiz = false
  for _, m in ipairs(Mods.Visible()) do if m.id == "lorequiz" then visibleQuiz = true end end
  ok(not visibleQuiz and #Mods.Visible() == #Mods.list - 1, "quiz has no hub tile")
  ok(lore.linkModule == "lorequiz" and quiz.linkModule == "lore", "lore and quiz link to each other")
  ok(tns.Mastery.Recommend("adept", "lorequiz") ~= nil, "quick drill works for the quiz")
  for _, nodeId in ipairs(Mods.Nodes("lorequiz", "everyone")) do
    for level = 1, 5 do
      for tier = 1, 3 do
        local p = Mods.Generate(nodeId, level, tier, "practice")
        loreGenCount = loreGenCount + 1
        local n = 0
        for _, c in ipairs(p.choices or {}) do if c == p.answer then n = n + 1 end end
        ok(p.mode == "choice" and #p.choices == 4 and n == 1, "quiz always 4 buttons, answer once: " .. nodeId)
      end
    end
    for _ = 1, 2 do
      local s = tns.Session.New(nodeId, 1, 0)
      local c = 0
      while true do
        local p = s:Next(c)
        if not p then break end
        c = c + 3
        s:Submit(p.answer, c)
      end
      s:Finish()
    end
    ok(LP.GetTierRec(nodeId, 1).mastered, "quiz mastery: " .. nodeId)
  end
  NOW = NOW + LR.DAY + 5
  local due = LR.Due()
  local seenTier, anyLore, anyQuiz = {}, false, false
  for _, d in ipairs(due) do
    local k = d.nodeId .. d.tier
    ok(not seenTier[k], "each tier is due once: " .. k)
    seenTier[k] = true
    if d.moduleId == "lore" then anyLore = true end
    if d.moduleId == "lorequiz" then anyQuiz = true end
  end
  ok(anyLore and anyQuiz, "lore and quiz tiers get spaced reviews")
  local full = tns.Report.Build({})
  ok(full:find("LORE CHRONICLES", 1, true) and full:find("The Chronicler's Trial vs Chronicle Mastery Exam", 1, true), "report covers Lore Chronicles with trial vs exam")
  local qr = tns.Report.Build({ moduleId = "lorequiz" })
  local _, sections = qr:gsub("%-%- Everyone %(all ages%) %-%-", "")
  ok(qr:find("LORE QUIZ FOR EVERYONE", 1, true) and sections == 1 and qr:find("No placement trial", 1, true)
    and not qr:find("Placement:", 1, true), "quiz report: one everyone section, no trial lines")
end

-- Art slots (v0.5.1: posed art + head crops)
do
  local tns = newNS()
  local A = tns.Art
  local all = { fizzwick_strip = { frames = 4 } }
  for _, n in ipairs(A.AllNames()) do all[n] = true end
  ok(#A.POSES == 11 and #A.AllNames() == 26, "11 poses, 26 art files (full + head crops)")
  ok(A.FizzwickFor("CORRECT", {}) == nil and A.FizzwickFor("CORRECT", nil) == nil and A.Sprocket("curious", {}) == nil, "no manifest = use the model")
  local expect = { GREET = "greet", ROUNDSTART = "talking", EXAMSTART = "talking", HINT = "teaching", EXPLAIN = "teaching",
    COMBO = "excited", OVERCHARGE = "excited", RANKUP = "celebrating", EXAMPASS = "celebrating", MASTERED = "proud",
    WRONG = "encouraging", EXAMTRY = "encouraging", BEST = "surprised", IDLE = "thinking", nope = "greet" }
  for ev, pose in pairs(expect) do
    ok(select(3, A.FizzwickFor(ev, all)) == pose, "event " .. ev .. " -> " .. pose)
  end
  ok(A.FizzwickFor("CORRECT", all) == A.DIR .. "fizzwick_talking", "full figure by default")
  ok(A.FizzwickFor("CORRECT", all, nil, true) == A.DIR .. "fizzwick_talking_head", "small slots use the head crop")
  ok(A.FizzwickFor("CORRECT", { fizzwick_talking = true }, nil, true) == A.DIR .. "fizzwick_talking", "no head crop -> full figure in a small slot")
  ok(select(3, A.FizzwickFor("COMBO", { fizzwick_greet = true })) == "greet", "missing pose falls back to greet")
  ok(A.FizzwickFor("COMBO", { fizzwick_greet_head = true }, nil, true) == A.DIR .. "fizzwick_greet_head", "missing pose -> greet head crop")
  ok(A.FizzwickFor("COMBO", { fizzwick_talking = true }) == nil, "an unrelated pose is never used (greet is the only fallback)")
  ok(A.FizzwickFor("WRONG", all, { fizzwick_encouraging_head = true }, true) == A.DIR .. "fizzwick_encouraging",
    "a head crop the client refused -> the full figure")
  ok(A.FizzwickFor("WRONG", all, { fizzwick_encouraging_head = true, fizzwick_encouraging = true }, true) == A.DIR .. "fizzwick_greet_head",
    "a refused pose -> greet")
  ok(A.IdlePose("lore") == "researching" and A.IdlePose("lorequiz") == "researching" and A.IdlePose("runeforger") == "tinkering"
    and A.IdlePose("scribe") == "thinking" and A.IdlePose(nil) == "thinking", "idle pose per subject")
  ok(A.Sprocket("squawk", all, nil, true) == A.DIR .. "sprocket_squawk_head" and A.Sprocket("curious", all) == A.DIR .. "sprocket_curious",
    "sprocket squawk/curious, head crop when small")
  ok(select(3, A.Sprocket("squawk", { sprocket_curious = true })) == "curious", "sprocket falls back to the other state")
  ok(A.Sprocket("squawk", all, { sprocket_squawk = true, sprocket_squawk_head = true, sprocket_curious = true, sprocket_curious_head = true }) == nil,
    "all sprocket files refused -> gear icon")
  local st = A.Strip(all)
  ok(st and st.frames == 4 and #st.coords == 4 and st.coords[2][1] == 0.25 and st.coords[4][2] == 1, "strip frames")
  ok(A.Strip({ fizzwick_strip = { frames = 3 } }) == nil and A.Strip({ fizzwick_strip = true }) == nil, "bad strips ignored")
  ok(A.Count(all) == 27 and A.Count({}) == 0, "art count")
  for ev in pairs(A.EVENT_POSE) do
    local found = (ev == "IDLE" or ev == "EXPLAIN" or ev == "BEST")
    for _, e in ipairs(tns.Guide.EVENTS) do if e == ev then found = true end end
    ok(found, "art pose for a real guide event: " .. ev)
  end
  for _, ev in ipairs(tns.Guide.EVENTS) do ok(A.EVENT_POSE[ev] ~= nil, "guide event has a pose: " .. ev) end
  local used = {}
  for _, p in pairs(A.EVENT_POSE) do used[p] = true end
  for _, p in pairs(A.SUBJECT_POSE) do used[p] = true end
  for _, p in ipairs(A.POSES) do ok(used[p], "pose is used by some event: " .. p) end

  -- shipped files: the manifest lists exactly the TGAs in Media/Art, all valid
  local function slurp(path, mode)
    local f = io.open(path, mode or "r")
    if not f then return "" end
    local s = f:read("*a"); f:close(); return s
  end
  local mns = {}
  local chunk = assert(loadstring(slurp("Media/Art/Manifest.lua")))
  setfenv(chunk, { })
  chunk("AzerothAcademy", mns)
  local manifest = mns.ArtManifest or {}
  ok(A.Count(manifest) == 26, "shipped manifest lists all 26 posed files")
  for _, n in ipairs(A.AllNames()) do
    ok(manifest[n] == true, "manifest lists " .. n)
    local h = slurp("Media/Art/" .. n .. ".tga", "rb")
    local size = n:find("_head$") and 256 or 512
    local w = #h >= 18 and (h:byte(13) + h:byte(14) * 256) or 0
    local hh = #h >= 18 and (h:byte(15) + h:byte(16) * 256) or 0
    local body = #h - 18 - h:byte(1) -- id field; an optional 26-byte TGA 2.0 footer may follow
    ok((body == size * size * 4 or body == size * size * 4 + 26) and h:byte(3) == 2 and h:byte(17) == 32 and h:byte(18) == 8 and w == size and hh == size,
      n .. ".tga is " .. size .. "x" .. size .. " 32-bit uncompressed, bottom-left origin")
  end
  ok(manifest.fizzwick_strip == nil and slurp("Media/Art/fizzwick_strip.tga", "rb") == "", "no talk strip shipped")
  local script, readme = slurp("tools/convert_art.sh"), slurp("Media/Art/README.md")
  ok(#script > 0 and #readme > 0 and #slurp("tools/make_heads.py") > 0, "convert script, head-crop tool and art README exist")
  for _, p in ipairs(A.POSES) do
    ok(script:find(" " .. p .. " ", 1, true) or script:find(" " .. p .. "\"", 1, true), "script handles pose " .. p)
    ok(readme:find("fizzwick_" .. p, 1, true), "README documents fizzwick_" .. p)
  end
  ok(script:find("sprocket_squawk", 1, true) and script:find("sprocket_curious", 1, true) and readme:find("sprocket_squawk", 1, true)
    and readme:find("sprocket_curious", 1, true) and readme:find("fizzwick_strip", 1, true), "sprocket states + strip documented")
  ok(script:find("-flip -orient BottomLeft", 1, true) and script:find("make_heads.py", 1, true) and script:find("_head", 1, true)
    and script:find("Manifest.lua", 1, true), "script writes bottom-left TGAs, head crops and the manifest")
end

-- Per-skill icons (v0.5.1)
do
  local tns = newNS()
  local seen, count = {}, 0
  for _, m in ipairs(tns.Modules.list) do
    for nodeId, node in pairs(m.nodes) do
      count = count + 1
      ok(type(node.icon) == "string" and node.icon:find("^Interface\\Icons\\") and node.icon ~= m.icon, "skill has its own icon: " .. nodeId)
      ok(not seen[node.icon], "icon not shared with another skill: " .. nodeId .. " (" .. tostring(node.icon) .. ")")
      seen[node.icon or ""] = true
      ok(tns.SkillIcons[nodeId] == node.icon, "icon comes from SkillIcons: " .. nodeId)
    end
  end
  ok(count >= 50, "icons checked for " .. count .. " skills")
  for id in pairs(tns.SkillIcons) do ok(tns.Modules.FindNode(id) ~= nil, "SkillIcons entry is a real skill: " .. id) end
end

-------------------------------------------------------------------------
-- 19. v0.6: Murloc Boarding Party (typing mini-game)
-------------------------------------------------------------------------
do
  local tns = newNS()
  local B, D, P = tns.Boarding, tns.BoardingData, tns.Progress
  P.Bind({}, {})
  P.SetBand("adept")
  -- typing form
  local need, map = B.Prepare("Fire the cannon!", false)
  ok(need == "fire the cannon" and map[1] == 1 and map[#need] == 15, "younger bands: lowercase, punctuation skipped")
  local m0 = { text = "Fire the cannon!", need = need, map = map }
  ok(B.Covered(m0, 0) == 0 and B.Covered(m0, 4) == 4 and B.Covered(m0, #need) == 16, "covered text includes the skipped '!'")
  ok(B.Prepare("Hold it, crew!", false) == "hold it crew", "comma skipped, spaces kept single")
  ok(B.Prepare("Load the port cannons.", true) == "Load the port cannons.", "magister types the exact text")
  ok(B.Prepare("a  b", true) == "a b", "double spaces collapse")
  -- data
  local sided = { "Stormwind", "Orgrimmar", "Ironforge", "Darnassus", "Undercity", "Thunder Bluff", "Alliance", "Horde" }
  local function checkList(name, list, maxLen, rule)
    local seen = {}
    ok(#list >= 6, name .. " has enough orders (" .. #list .. ")")
    for _, t in ipairs(list) do
      ok(not seen[t], name .. " has no duplicate: " .. t)
      seen[t] = true
      ok(#t <= maxLen, name .. " order fits on the deck: " .. t)
      if rule then ok(rule(t), name .. " order follows the band rule: " .. t) end
      for _, w in ipairs(sided) do ok(not t:find(w, 1, true), name .. " stays faction-neutral: " .. t) end
    end
  end
  checkList("letters", D.LETTERS, 1, function(t) return t:match("^%l$") end)
  checkList("words", D.WORDS, 4, function(t) return t:match("^%l+$") end)
  checkList("phrases", D.PHRASES, 24, function(t) return t:match("^%u") and t:match("!$") end)
  checkList("sentences", D.SENTENCES, 56, function(t) return t:match("^%u") and t:match("[%.!]$") end)
  checkList("initiate boss", D.BOSS.initiate, 20, function(t) return t:match("^%u[%a ,]+[%.!]$") end)
  checkList("adept boss", D.BOSS.adept, 60)
  checkList("magister boss", D.BOSS.magister, 90)
  local firsts = {}
  for _, t in ipairs(D.PHRASES) do firsts[t:sub(1, 1):lower()] = true end
  local nf = 0
  for _ in pairs(firsts) do nf = nf + 1 end
  ok(nf >= 8, "phrases start with many different letters (" .. nf .. ") so targets rarely clash")

  -- a tiny driver: tick and type like a kid with `cps` characters per second
  local function drive(g, cps, opts)
    opts = opts or {}
    local budget, guard = 0, 0
    local events = {}
    while not g.done and guard < 40000 do
      guard = guard + 1
      g:Tick(0.1)
      for _, e in ipairs(g:PopEvents()) do events[e.type] = (events[e.type] or 0) + 1 end
      budget = budget + cps * 0.1
      while budget >= 1 and not g.done do
        budget = budget - 1
        local t = g.target
        if not t then
          for _, m in ipairs(g.murlocs) do if not t or m.pos > t.pos then t = m end end
        end
        if t then
          local c = t.need:sub(#g.typed + 1, #g.typed + 1)
          if opts.typoEvery and math.random(opts.typoEvery) == 1 then
            g:Input(g.typed .. "#")
          end
          g:Input(g.typed .. c)
        end
        for _, e in ipairs(g:PopEvents()) do events[e.type] = (events[e.type] or 0) + 1 end
      end
      if opts.broadside and g:BroadsideReady() then g:Broadside() end
    end
    for _, e in ipairs(g:PopEvents()) do events[e.type] = (events[e.type] or 0) + 1 end
    return events, guard
  end

  -- every band x route can be won by a steady typist; waves and the boss happen
  local speeds = { initiate = 0.6, adept = 2.5, magister = 4 }
  for _, band in ipairs({ "initiate", "adept", "magister" }) do
    for _, r in ipairs(B.ROUTES) do
      local g = B.New(band, r.id)
      local ev = drive(g, speeds[band], { broadside = true })
      ok(g.done and g.won, band .. "/" .. r.id .. ": a steady typist wins (" .. tostring(g.won) .. ", wheel " .. tostring(g.wheel) .. ")")
      ok(g.wave == r.waves and g.bossSpawned and ev.boss == 1 and ev.win == 1, band .. "/" .. r.id .. ": all waves then the Tidehunter")
      ok(g.splashed >= r.waves * 2 + 1 and g.typos == 0, band .. "/" .. r.id .. ": murlocs splashed, no typos")
      if band == "magister" then
        local wpm = g:WPM()
        ok(wpm >= 20 and wpm <= 48, "magister WPM is measured (" .. wpm .. " at 4 chars/s = 48 max)")
      end
    end
  end
  -- Initiate never fails, even typing very slowly
  do
    local g = B.New("initiate", "bootybay")
    local ev = drive(g, 0.12)
    ok(g.done and g.won and g.wheel == nil, "initiate: no fail state, a very slow typist still finishes")
    ok((ev.atWheel or 0) >= 1 and not ev.wheel and not ev.lose, "initiate: murlocs wait at the wheel")
  end
  -- Adept can lose: nobody types
  do
    local g = B.New("adept", "bootybay")
    local ev = drive(g, 0)
    ok(g.done and not g.won and g.wheel == 0 and ev.wheel == 3 and ev.lose == 1, "adept: three murlocs at the wheel end the voyage")
  end
  -- typing rules
  do
    local g = B.New("adept", "bootybay")
    g.murlocs = {}
    g:PopEvents()
    local a = g:Spawn("Raise the sail!")
    local b = g:Spawn("Ring the bell!")
    a.pos, b.pos = 10, 30
    local shown, st = g:Input("r")
    ok(shown == "r" and st == "ok" and g.target == b, "the first letter picks the murloc closest to the wheel")
    shown, st = g:Input("rx")
    ok(shown == "r" and st == "stumble" and g.typos == 1 and b.typos == 1 and #g.typed == 1, "a typo is refused and costs no progress")
    shown = g:Input("ri")
    ok(shown == "ri" and g.chars == 2, "typing continues after a stumble")
    shown, st = g:Input("r")
    ok(shown == "r" and st == "back" and g.target == b, "backspace works")
    shown, st = g:Input("")
    ok(g.target == nil and st == "back", "clearing the box lets go of the target")
    g:Input("Q")
    ok(g.target == nil and g.typos == 2, "a letter no murloc starts with is a stumble")
    g:Input("R")
    ok(g.target == b, "capitals are fine for younger bands")
    local cur = "R"
    for i = 2, #b.need do cur = cur .. b.need:sub(i, i) end
    shown, st = g:Input(cur)
    ok(st == "splash" and shown == "" and g.splashed == 1 and g.target == nil and #g.murlocs == 1, "a finished order knocks the murloc overboard")
    ok(g.meter == 1, "a knockout with a typo fills the meter by 1")
    g:Input("Raise the sail")
    ok(g.splashed == 2 and g.meter == 3, "a clean knockout fills the meter by 2 (punctuation skipped)")
    ok(g:Input("x") == "" and g.typos == 3, "typing with an empty deck is a harmless stumble")
  end
  do
    local g = B.New("magister", "bootybay")
    g.murlocs = {}
    local m = g:Spawn("Hold the wheel steady.")
    m.pos = 5
    g:Input("h")
    ok(g.target == nil and g.typos == 1, "magister: capitals count")
    g:Input("Hold the wheel steady")
    ok(g.target == m and g.splashed == 0, "magister: the period counts too")
    g:Input("Hold the wheel steady.")
    ok(g.splashed == 1, "magister: exact sentence splashes")
  end
  -- broadside
  do
    local g = B.New("adept", "bootybay")
    g.murlocs = {}
    g.meter = B.METER_MAX - 1
    local a = g:Spawn("Swab the deck!")
    g:Input("swab the deck")
    ok(g:BroadsideReady(), "a full meter readies the broadside")
    local evs = g:PopEvents()
    local ready = false
    for _, e in ipairs(evs) do if e.type == "broadsideReady" then ready = true end end
    ok(ready and a ~= nil, "broadsideReady event fires once")
    g:Spawn("Coil the rope!"); g:Spawn("Light the lantern!")
    local boss = g:Spawn("All hands, push the big murloc back into the sea!", true)
    boss.pos = 60
    g:Input("co")
    local fired, cleared = g:Broadside()
    ok(fired and cleared == 2 and #g.murlocs == 1 and g.murlocs[1] == boss, "the broadside clears every regular murloc")
    ok(boss.pos == 0 and boss.stun == B.STUN and g.meter == 0 and g.target == nil and g.typed == "", "the Tidehunter is knocked back and stunned")
    local p0 = boss.pos
    g:Tick(0.5)
    ok(boss.pos == p0, "a stunned Tidehunter does not move")
    ok(not g:Broadside(), "no second broadside until the meter refills")
  end
  -- pause, hitch clamp
  do
    local g = B.New("adept", "bootybay")
    g:Tick(1)
    local m = g.murlocs[1]
    ok(m ~= nil, "the first murloc climbs aboard quickly")
    local p = m.pos
    g.paused = true
    g:Tick(5)
    ok(m.pos == p and g:Input("x") == "", "paused: nothing moves, typing is ignored")
    g.paused = false
    g:Tick(30)
    ok(m.pos - p <= m.speed * 0.5 + 1e-6, "a long frame hitch moves murlocs at most half a second")
  end
  -- no two murlocs on deck start with the same letter while the pool allows it
  do
    local clashes = 0
    for _ = 1, 20 do
      local g = B.New("adept", "ratchet")
      for _ = 1, 400 do
        g:Tick(0.2)
        local seen = {}
        for _, m in ipairs(g.murlocs) do
          local c = m.need:sub(1, 1)
          if seen[c] then clashes = clashes + 1 end
          seen[c] = true
        end
        if #g.murlocs >= 3 then for _, m in ipairs(g.murlocs) do m.pos = 0 end end
        if g.done then break end
      end
    end
    ok(clashes == 0, "murlocs on deck never share a first letter (" .. clashes .. " clashes)")
  end
  -- saving, rewards, routes, report
  do
    ok(B.Unlocked("bootybay") and not B.Unlocked("ratchet") and not B.Unlocked("maelstrom") and B.BestRoute() == "bootybay", "only Booty Bay Harbor is open at first")
    local shards0, mastered0 = P.char.shards, P.TotalMastered()
    local g = B.New("adept", "bootybay")
    drive(g, 3)
    local r = B.Record(g, 1000)
    ok(r.won and r.firstClear and r.unlocked == "ratchet" and B.Unlocked("ratchet") and not B.Unlocked("maelstrom"), "clearing a route unlocks the next")
    ok(r.shards == g.splashed * 2 + 10 + 15 and P.char.shards == shards0 + r.shards, "shards: 2 per murloc + 10 win + 15 first clear")
    ok(r.newBestWpm and r.wpm > 0, "first voyage sets a best WPM")
    local st = B.State()
    ok(P.char.modules.scribe.boarding == st and st.voyages == 1 and st.wins == 1 and #st.log == 1 and st.log[1].route == "bootybay", "voyage saved under the Scribe module")
    ok(P.TotalMastered() == mastered0, "the mini-game does not touch mastery")
    local g2 = B.New("adept", "bootybay")
    drive(g2, 3)
    local r2 = B.Record(g2, 1001)
    ok(not r2.firstClear and not r2.unlocked and r2.shards == g2.splashed * 2 + 10, "no first-clear bonus the second time")
    local g3 = B.New("adept", "ratchet")
    drive(g3, 0)
    local r3 = B.Record(g3, 1002)
    ok(not r3.won and r3.shards == 0 and not B.Unlocked("maelstrom") and st.voyages == 3 and st.log[1].won == false, "a lost voyage is logged, nothing unlocked")
    for i = 1, 12 do B.Record(B.New("initiate", "bootybay"), 2000 + i) end
    ok(#st.log == B.LOG_SIZE and st.log[1].date == 2012, "the voyage log keeps the newest " .. B.LOG_SIZE)
    P.account.settings.unlockAllTiers = true
    ok(B.Unlocked("maelstrom"), "the parent 'unlock all' setting opens every route")
    P.account.settings.unlockAllTiers = false
    local gm = B.New("magister", "bootybay")
    drive(gm, 5)
    local rm = B.Record(gm, 3000)
    ok(rm.par == 150 and rm.underPar and rm.time <= 150, "magister: par time bonus (" .. rm.time .. "s)")
    local rep = tns.Report.Build({ moduleId = "scribe" })
    ok(rep:find("Murloc Boarding Party: 16 voyages", 1, true) and rep:find("Best typing speed:", 1, true)
      and rep:find("Routes: Booty Bay Harbor, Booty Bay to Ratchet, Ratchet to the Maelstrom (locked)", 1, true), "report shows the voyage log")
    local rr = tns.Report.Build({ moduleId = "runeforger" })
    ok(not rr:find("Murloc", 1, true), "other subjects' reports don't mention the game")
    ok(P.SCHEMA >= 5, "no schema change for the voyage (data created on first play); v0.7 flight setting is schema 5")
  end
  ok(tns.Modules.Get("scribe").game.view == "boarding", "Scribe's Scrolls registers the mini-game")
  for _, e in ipairs({ "splash", "cannon", "gurgle" }) do
    local def = tns.SoundEvents.EVENTS[e]
    ok(def and type(def.kits[1]) == "number", "built-in sound for " .. e)
  end
end

-------------------------------------------------------------------------
-- 20. v0.6.1: minimap button math + setting
-------------------------------------------------------------------------
do
  local tns = newNS()
  local MM = tns.MinimapMath
  local function near(a, b) return math.abs(a - b) < 1e-6 end
  local x, y = MM.Position(0, "ROUND", 140)
  ok(near(x, 75) and near(y, 0), "angle 0 = east on the rim (radius = width/2 + 5)")
  x, y = MM.Position(90, nil, 140)
  ok(near(x, 0) and near(y, 75), "angle 90 = north")
  x, y = MM.Position(225, "ROUND", 140)
  ok(near(math.sqrt(x * x + y * y), 75) and x < 0 and y < 0, "default 225 = lower left, on the circle")
  x, y = MM.Position(45, "SQUARE", 140)
  local d = (math.sqrt(2 * 75 * 75) - 10) * math.cos(math.rad(45))
  ok(near(x, d) and near(y, d) and x > 60, "square minimap: into the corner (pulled in 10px like LibDBIcon)")
  x, y = MM.Position(10, "SQUARE", 140)
  ok(near(x, 75) and y > 0 and y < 75, "square minimap: on the right edge")
  local rx, ry = MM.Position(45, "CORNER-TOPRIGHT", 140)
  ok(near(math.sqrt(rx * rx + ry * ry), 75), "CORNER-TOPRIGHT: top-right quadrant is round")
  local sx, sy = MM.Position(225, "CORNER-TOPRIGHT", 140)
  ok(near(sx, -d) and near(sy, -d), "CORNER-TOPRIGHT: other quadrants square")
  ok(select(1, MM.Position(0, "WEIRD", 140)) == 75, "unknown shape = round")
  ok(near(MM.AngleFrom(1, 0), 0) and near(MM.AngleFrom(0, 1), 90) and near(MM.AngleFrom(-1, 0), 180) and near(MM.AngleFrom(0, -5), 270),
    "cursor offset -> angle")
  ok(MM.AngleFrom(0, 0) == MM.DEFAULT_ANGLE, "cursor exactly at the center keeps a sane angle")
  ok(MM.Normalize(-90) == 270 and MM.Normalize(725) == 5 and MM.Normalize(nil) == 225 and MM.Normalize(0 / 0) == 225, "angles normalized")
  local acct = { settings = { cameos = false } }
  tns.Progress.Bind(acct, {})
  ok(acct.settings.minimap.hide == false and acct.settings.minimap.angle == 225 and acct.settings.cameos == false,
    "minimap setting added to old saved data without touching other settings")
  local acct2 = { settings = { minimap = { hide = true, angle = 10 } } }
  tns.Progress.Bind(acct2, {})
  ok(acct2.settings.minimap.hide == true and acct2.settings.minimap.angle == 10, "saved minimap angle/hide kept")
end

-------------------------------------------------------------------------
-- 21. v0.7: In-Flight Lessons trigger rules + schema 5
-------------------------------------------------------------------------
do
  local tns = newNS()
  local F, P = tns.Flight, tns.Progress
  ok(P.SCHEMA >= 5, "schema 5+")
  -- fresh install
  local acct = P.Bind({}, {})
  ok(acct.settings.flight.mode == "toast" and F.Mode(acct.settings) == "toast", "default mode: toast")
  ok(acct.settings.taxiNudge == nil, "old taxiNudge default gone")
  -- v0.6.1 (schema 4) upgrades
  local a1 = { version = 4, settings = { taxiNudge = false, dailyCap = 30, minimap = { hide = true, angle = 10 } } }
  local c1 = { version = 4, profile = { band = "adept" }, shards = 55 }
  P.Bind(a1, c1)
  ok(a1.version == P.SCHEMA and c1.version == P.SCHEMA and P.upgradedFrom == 4, "v0.6.1 -> v0.7 bump")
  ok(a1.settings.flight.mode == "off", "nudge turned off -> flight lessons off")
  ok(a1.settings.dailyCap == 30 and a1.settings.minimap.hide == true and c1.shards == 55, "everything else kept")
  a1.settings.flight.mode = "auto"
  P.Bind(a1, c1)
  ok(a1.settings.flight.mode == "auto" and P.upgradedFrom == nil, "migration runs once: a later choice sticks")
  local a2 = { version = 4, settings = { taxiNudge = true } }
  P.Bind(a2, { version = 4 })
  ok(a2.settings.flight.mode == "toast", "nudge on -> toast")
  local a3 = { version = 5, settings = { flight = { mode = "warp" } } }
  P.Bind(a3, { version = 5 })
  ok(F.Mode(a3.settings) == "toast" and F.Mode(nil) == "toast" and F.Mode({ flight = { mode = "auto" } }) == "auto", "odd mode -> default")
  ok(F.ValidMode("off") and F.ValidMode("auto") and not F.ValidMode("on"), "valid modes")

  -- cap: 0 never blocks, reached blocks
  ok(not F.CapReached(0, 0) and not F.CapReached(10, 60) and F.CapReached(60, 60) and F.CapReached(70, 60), "cap rule")

  local function ctx(over)
    local c = { mode = "toast", inCombat = false, inInstance = false, academyOpen = false, hasBand = true, capReached = false }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
  end
  -- edges
  local tr = F.NewTracker()
  ok(F.Update(tr, false, 0) == nil, "no edge on the ground")
  ok(F.Decide(tr, 0, ctx()) == "skip", "nothing on the ground")
  ok(F.Update(tr, true, 100) == "takeoff" and tr.flight == 1, "takeoff edge")
  ok(F.Update(tr, true, 101) == nil, "no repeat edge while flying (poll + events both safe)")
  ok(F.Decide(tr, 101, ctx()) == "wait", "waits a couple of seconds after takeoff")
  local d = F.Decide(tr, 100 + F.TAKEOFF_DELAY, ctx())
  ok(d == "toast", "toast after the delay")
  F.MarkOffered(tr)
  ok(select(2, F.Decide(tr, 200, ctx())) == "already", "at most once per flight")
  ok(F.CanOfferAnother(tr), "another round while flying")
  ok(F.Update(tr, false, 300) == "landed" and not F.CanOfferAnother(tr), "landed: no more 'another round'")
  F.Update(tr, true, 400)
  ok(tr.flight == 2 and not tr.offered and F.Decide(tr, 403, ctx()) == "toast", "next flight offers again")
  -- modes
  F.Update(tr, false, 500); F.Update(tr, true, 500)
  ok(select(2, F.Decide(tr, 510, ctx({ mode = "off" }))) == "off", "mode off: never")
  ok(F.Decide(tr, 510, ctx({ mode = "auto" })) == "auto", "mode auto")
  ok(F.Decide(tr, 510, ctx({ mode = "bogus" })) == "toast", "bad mode -> toast")
  -- suppression
  local d2, r2 = F.Decide(tr, 510, ctx({ inCombat = true }))
  ok(d2 == "wait" and r2 == "combat", "combat: hold off (not skip), try again this flight")
  ok(F.Decide(tr, 511, ctx()) == "toast", "after combat, still on the taxi: offered")
  ok(select(2, F.Decide(tr, 510, ctx({ inInstance = true }))) == "instance", "no popup in instances")
  ok(select(2, F.Decide(tr, 510, ctx({ academyOpen = true }))) == "open", "no popup when the Academy is open")
  ok(select(2, F.Decide(tr, 510, ctx({ hasBand = false }))) == "noband", "no popup before a path is chosen")
  ok(select(2, F.Decide(tr, 510, ctx({ capReached = true }))) == "cap", "no popup once the daily cap is reached")
  ok(F.Decide(tr, 510, ctx({ inCombat = true, mode = "off" })) == "skip", "off beats combat")
  -- session mute
  F.Mute(tr)
  ok(select(2, F.Decide(tr, 510, ctx())) == "muted", "'not this session' mutes")
  F.Update(tr, false, 600); F.Update(tr, true, 600)
  ok(select(2, F.Decide(tr, 610, ctx())) == "muted", "mute lasts across flights")
  ok(F.Decide(tr, 610, ctx({ test = true })) == "toast", "/aa flight test ignores the mute")
  ok(F.NewTracker().muted == false, "a new session is unmuted")
  -- slash parsing
  local function pc(a) return table.concat({ F.ParseCommand(a) }, ":") end
  ok(pc("") == "status" and pc("off") == "set:off" and pc(" Auto ") == "set:auto" and pc("toast") == "set:toast" and pc("on") == "set:toast",
    "/aa flight parsing")
  ok(pc("test") == "test" and pc("land") == "land" and pc("banana") == "help", "/aa flight test/land/help")
  -- quick round size
  P.Bind({}, { profile = { band = "adept" } })
  local s5 = tns.Session.New("sc_type_sentences", 1, 0, F.ROUND_SIZE)
  ok(s5 and s5.total == 5, "flight round is 5 problems")
  ok(tns.Session.New("sc_type_sentences", 1, 0).total == tns.Session.ROUND_SIZE, "normal rounds unchanged")
  ok(tns.Session.New("sc_type_sentences", 1, 0, 99).total == tns.Session.ROUND_SIZE and tns.Session.New("sc_type_sentences", 1, 0, 0).total == 1, "size clamped")
end

-------------------------------------------------------------------------
-- 22. v0.9: Azeroth Naturalist data, generators, typed checks, engine, Field Journal
-------------------------------------------------------------------------
local natGenCount, natItems = 0, {}
do
  local tns = newNS()
  local D, NA, Mods, J = tns.NaturalistData, tns.Naturalist, tns.Modules, tns.Journal
  local NL = tns.L
  local lower = string.lower
  local sided = { "Stormwind", "Orgrimmar", "Ironforge", "Darnassus", "Undercity", "Thunder Bluff", "Kirin Tor", "Dalaran", "Khadgar", "Alliance", "Horde" }
  local function neutral(s, tag)
    for _, w in ipairs(sided) do ok(not tostring(s):find(w, 1, true), tag .. " stays faction-neutral (" .. w .. ")") end
  end
  local nat = Mods.Get("naturalist")
  ok(nat and nat.nameKey == "MOD_NATURALIST" and nat.choiceOnlyBands.initiate and nat.textAnswers and nat.check == NA.Check, "naturalist module registered")
  ok(nat.game and nat.game.view == "journal" and NL[nat.game.key] and NL[nat.game.tileKey] and NL[nat.game.tipKey], "journal link on the skill list")
  ok(nat.startSound == "page" and tns.SoundEvents.EVENTS.page and tns.SoundEvents.EVENTS.specimen, "naturalist sounds exist")
  ok(tns.Art.SUBJECT_POSE.naturalist == "researching", "Fizzwick researches in the greenhouse")
  for _, k in ipairs({ "NAT_LORE", "NAT_TITLE", "NAT_TRIAL", "NAT_EXAM", "NAT_TRIAL_LORE", "NAT_EXAM_LORE", "NAT_TRIAL_RESULT", "NAT_EXAM_PASS", "NAT_TRIAL_RIGHT", "NAT_TRIAL_WRONG" }) do
    ok(type(NL[k]) == "string" and NL[k] ~= "", "locale " .. k)
    neutral(NL[k], k)
  end
  for _, ev in ipairs({ "NATSTART", "NATCORRECT", "NATWRONG", "NATSPECIMEN", "NATJOURNAL", "NATFLIGHT" }) do
    local found = false
    for _, e in ipairs(tns.Guide.EVENTS) do if e == ev then found = true end end
    ok(found and tns.Art.EVENT_POSE[ev], "guide event + pose: " .. ev)
  end
  for _, map in pairs(nat.guideEvents) do ok(tns.Art.EVENT_POSE[map[1]] and (map.every or 1) >= 1, "module guide event mapping: " .. map[1]) end

  -- bands: 5 skills each, every node has a name, description, icon and 3 specimens
  local nodeSeen, specIds = {}, {}
  for _, band in ipairs(Mods.BAND_ORDER) do
    local nodes = Mods.Nodes("naturalist", band)
    ok(#nodes == 5, "naturalist " .. band .. " has 5 skills")
    for _, nodeId in ipairs(nodes) do
      local _, node = Mods.FindNode(nodeId)
      ok(not nodeSeen[nodeId], "unique node " .. nodeId); nodeSeen[nodeId] = true
      ok(NL[node.key] and NL[node.key .. "_DESC"] and #NL[node.key .. "_DESC"] <= 44, "node name + short description: " .. nodeId)
      ok(tns.SkillIcons[nodeId] ~= nil, "skill icon: " .. nodeId)
      local list = D.SPECIMENS[nodeId]
      ok(type(list) == "table" and #list == 3, "3 specimens: " .. nodeId)
      for t = 1, 3 do
        local sp = list and list[t]
        if ok(sp, nodeId .. " specimen T" .. t) then
          ok(not specIds[sp.id], "unique specimen id " .. tostring(sp.id)); specIds[sp.id] = true
          ok(type(sp.name) == "string" and #sp.name <= 32, "specimen name fits: " .. tostring(sp.name))
          ok(type(sp.zone) == "string" and sp.zone ~= "", "specimen zone: " .. sp.name)
          ok(type(sp.icon) == "string" and sp.icon:find("^Interface\\Icons\\") ~= nil, "specimen uses an in-game icon: " .. sp.name)
          ok(type(sp.note) == "string" and #sp.note >= 30 and #sp.note <= 200, "specimen note length: " .. sp.name)
          ok(sp.nodeId == nodeId and sp.tier == t, "specimen knows its page: " .. sp.name)
          neutral(sp.name .. sp.zone .. sp.note, "specimen " .. sp.name)
        end
      end
      local flight = nat.flightNodes[band]
      ok(type(flight) == "table" and #flight >= 1, "flight skills for " .. band)
    end
    for _, id in ipairs(nat.flightNodes[band]) do ok(select(2, Mods.FindNode(id)).band == band, "flight skill in its band: " .. id) end
  end

  -- curated data: levels, endings, distinct distractors, lengths, no duplicates
  local function checkEntries(name, list, band)
    local seen, c = {}, { 0, 0, 0 }
    for i, e in ipairs(list) do
      local tag = name .. " " .. i
      ok(e.lv == 1 or e.lv == 2 or e.lv == 3, tag .. " lv 1-3")
      if c[e.lv] then c[e.lv] = c[e.lv] + 1 end
      ok(type(e.q) == "string" and (e.q:sub(-1) == "?" or e.q:sub(-1) == "."), tag .. " question ends with ?, ... or a full stop: " .. tostring(e.q))
      ok(#e.q <= NA.MAX_TEXT, tag .. " question length")
      ok(not seen[e.q], tag .. " duplicate question"); seen[e.q] = true
      ok(type(e.a) == "string" and e.a ~= "" and #e.a <= NA.MAX_CHOICE, tag .. " answer")
      ok(type(e.why) == "string" and #e.why >= 15, tag .. " explanation")
      local need = band == "initiate" and 2 or 3
      ok(type(e.d) == "table" and #e.d >= need, tag .. " has " .. need .. "+ distractors")
      local ds = { [NA.Normalize(e.a)] = true }
      for _, d in ipairs(e.d or {}) do
        ok(type(d) == "string" and #d <= NA.MAX_CHOICE, tag .. " distractor length")
        ok(not ds[NA.Normalize(d)], tag .. " distractor repeats or equals the answer: " .. tostring(d))
        ds[NA.Normalize(d)] = true
      end
      if e.t then
        ok(band ~= "initiate", tag .. " initiate never types")
        for _, alt in ipairs(e.t) do
          ok(type(alt) == "string" and not ds[NA.Normalize(alt)] or NA.Normalize(alt) == NA.Normalize(e.a), tag .. " typed alt is not a wrong answer: " .. tostring(alt))
        end
      end
      neutral(e.q .. e.a .. e.why .. table.concat(e.d or {}, " "), tag)
    end
    -- (living-thing clues only add to the generated living / not-living items, which are level 1)
    ok(name == "nat_living" or (c[1] > 0 and c[2] > 0 and c[3] > 0), name .. " covers levels 1-3 (" .. c[1] .. "/" .. c[2] .. "/" .. c[3] .. ")")
    return #list
  end
  for nodeId, lists in pairs(NA.LISTS) do
    local _, node = Mods.FindNode(nodeId)
    local n = 0
    for _, list in ipairs(lists) do n = n + checkEntries(nodeId, list, node.band) end
    natItems[node.band] = (natItems[node.band] or 0) + n
  end
  -- generated-item data
  ok(#D.HABITATS == 8, "8 habitats")
  local hab = 0
  for _, h in ipairs(D.HABITATS) do
    ok(#h.zones >= 2 and #h.life >= 2 and #h.desc <= 30, "habitat " .. h.id)
    for _, lf in ipairs(h.life) do ok(lf[2] == "plant" or lf[2] == "animal", "habitat life kind " .. lf[1]); hab = hab + 1 end
  end
  natItems.initiate = natItems.initiate + hab + #D.LIVING + #D.NONLIVING
  ok(#D.LIVING >= 8 and #D.NONLIVING >= 8, "living / non-living lists")
  for _, ch in ipairs(D.CHAINS) do
    ok(#ch.chain >= 3 and ch.zone, "food chain " .. tostring(ch.zone))
  end
  natItems.adept = natItems.adept + #D.CHAINS + #D.SUBSTANCES + #D.CYCLES
  for _, sb in ipairs(D.SUBSTANCES) do ok(sb[2] == "solid" or sb[2] == "liquid" or sb[2] == "gas", "substance state " .. sb[1]) end
  for _, cy in ipairs(D.CYCLES) do ok(#cy.steps >= 3, "life cycle " .. cy.name) end

  -- helpers
  ok(NA.Normalize("  The Sun! ") == "sun" and NA.Normalize("A solid") == "solid" and NA.Normalize("an Egg.") == "egg", "normalize drops articles + punctuation")
  ok(NA.Normalize("It's water vapor") == "its water vapor", "normalize apostrophes")
  ok(NA.LevelFor(1) == 1 and NA.LevelFor(3) == 2 and NA.LevelFor(5) == 3, "level mapping")
  local tp = { mode = "text", typed = true, answer = "Condensation", alts = { "condensing" } }
  ok(NA.Check(tp, "condensation") and NA.Check(tp, " Condensing. ") and NA.Check(tp, "the condensation"), "typed answer: case, article and alt forgiven")
  ok(not NA.Check(tp, "evaporation") and not NA.Check(tp, "") and not NA.Check(tp, "   "), "typed answer: wrong / blank rejected")
  ok(NA.Check({ mode = "choice", answer = "Gas" }, "Gas") and not NA.Check({ mode = "choice", answer = "Gas" }, "gas"), "buttons compare exactly")
  NA.bags = {}
  local pool, seen, dup = NA.Pool(D.NEEDS, 1), {}, false
  for _ = 1, #pool do
    local e = NA.Draw("needs", D.NEEDS, 1)
    if seen[e] then dup = true end
    seen[e] = true
  end
  ok(not dup, "shuffle bag: no repeats inside one pass")

  -- generators: every node x level x tier x purpose
  local NOW0 = 1800000000
  tns.Env.time = function() return NOW0 end
  tns.Progress.Bind({}, {})
  for _, band in ipairs(Mods.BAND_ORDER) do
    for _, nodeId in ipairs(Mods.Nodes("naturalist", band)) do
      local typedSeen = false
      for level = 1, 5 do
        for tier = 1, 3 do
          for _, purpose in ipairs({ "practice", "trial" }) do
            for _ = 1, math.max(6, math.floor(ITER / 25)) do
              local okk, p = pcall(Mods.Generate, nodeId, level, tier, purpose)
              natGenCount = natGenCount + 1
              local tag = string.format("[%s L%d T%d %s]", nodeId, level, tier, purpose)
              if ok(okk and type(p) == "table", tag .. " generator error: " .. tostring(p)) then
                tag = tag .. " '" .. tostring(p.text):sub(1, 60) .. "'"
                ok(type(p.text) == "string" and #p.text > 10 and #p.text <= NA.MAX_TEXT, tag .. " text length")
                ok(not hasFormatLeftovers(p.text) and not hasFormatLeftovers(p.hint) and not hasFormatLeftovers(p.explain), tag .. " format leftovers")
                ok(type(p.answer) == "string" and p.answer ~= "", tag .. " answer is text")
                if p.mode == "choice" then
                  local n, seenC = 0, {}
                  for _, c in ipairs(p.choices) do
                    if c == p.answer then n = n + 1 end
                    ok(not seenC[NA.Normalize(c)], tag .. " duplicate choice " .. c)
                    seenC[NA.Normalize(c)] = true
                    ok(#c <= NA.MAX_CHOICE, tag .. " choice too long: " .. c)
                    ok(Mods.Check(p, c) == (c == p.answer), tag .. " check of choice " .. c)
                  end
                  ok(n == 1, tag .. " answer appears exactly once")
                  ok(#p.choices == (band == "initiate" and 3 or 4), tag .. " number of buttons " .. #p.choices)
                else
                  typedSeen = true
                  ok(p.mode == "text" and p.typed, tag .. " typed problems are text")
                  ok(band ~= "initiate", tag .. " initiate never types")
                  ok(tier >= 2 or purpose == "trial", tag .. " Spark practice is always buttons")
                  ok(Mods.Check(p, p.answer) and Mods.Check(p, lower(p.answer)) and Mods.Check(p, "  " .. p.answer .. ". "), tag .. " typed answer accepted")
                  ok(not Mods.Check(p, "zzqx") and not Mods.Check(p, ""), tag .. " junk rejected")
                  for _, d in ipairs(p.distractors or {}) do ok(not Mods.Check(p, d), tag .. " typed wrong answer rejected: " .. d) end
                end
              end
            end
          end
        end
      end
      if band ~= "initiate" and nodeId ~= "nat_adapt" and nodeId ~= "nat_fairtest" and nodeId ~= "nat_explain" then
        ok(typedSeen, "some typed answers on Rune/Glyph for " .. nodeId)
      end
    end
  end

  -- habitat sanity: wrong answers never come from a look-alike habitat
  for _ = 1, 300 do
    local p = Mods.Generate("nat_habitats", 1, 1, "practice")
    for _, h in ipairs(D.HABITATS) do
      if p.answer:find("(" .. h.desc .. ")", 1, true) then
        for _, c in ipairs(p.choices) do
          for _, o in ipairs(D.HABITATS) do
            if c ~= p.answer and c:find("(" .. o.desc .. ")", 1, true) then ok(not (NA.CLASH[h.id] and NA.CLASH[h.id][o.id]), "habitat distractor too alike: " .. c) end
          end
        end
      end
    end
  end
  -- food-chain sanity: a distractor in "which one eats X" never sits above X in its chain
  for _ = 1, 400 do
    local p = Mods.Generate("nat_foodchains", 4, 1, "practice")
    if p.text:find("eats the", 1, true) and p.choices then
      for _, ch in ipairs(D.CHAINS) do
        local head = string.format(NL.NAT_CHAIN_HEAD, ch.zone, table.concat(ch.chain, " -> "))
        if p.text:find(head, 1, true) then
          local pos = {}
          for i, x in ipairs(ch.chain) do pos[x] = i end
          local food = p.text:match("eats the (.-)%?")
          for _, c in ipairs(p.choices) do
            if c ~= p.answer and pos[c] and pos[food] then ok(pos[c] <= pos[food], "food chain distractor could be a predator: " .. c) end
          end
        end
      end
    end
  end

  -- engine: trial, mastery -> specimens, exam, review -> faded ink, sync, migration
  local NOW = 1800000000
  tns.Env.time = function() return NOW end
  local LP, LT, LR = tns.Progress, tns.Trial, tns.Review
  local acct, char = LP.Bind({}, {})
  ok(acct.version == 6 and char.version == 6 and type(acct.journal.entries) == "table", "schema 6 with a journal")
  ok(select(1, J.Count()) == 0 and select(2, J.Count()) == 45, "empty journal: 0 / 45")
  local collected = 0
  for _, band in ipairs({ "initiate", "adept", "magister" }) do
    LP.SetBand(band)
    ok(LT.NeedsPlacement("naturalist", band), "naturalist offers its own trial: " .. band)
    local res = runTrial(tns, band, "placement", function() return true end, "naturalist")
    ok(res.completed and res.correct == 10, "naturalist placement perfect: " .. band)
    runTrial(tns, band, "placement", function() return false end, "naturalist")
    ok(LT.StartTier(Mods.Nodes("naturalist", band)[1]) == 1, "naturalist all-wrong trial: Spark")
    for i, nodeId in ipairs(Mods.Nodes("naturalist", band)) do
      for t = 1, 2 do
        if i <= 4 then
          local got
          for _ = 1, 2 do
            local s = tns.Session.New(nodeId, t, 0)
            local c = 0
            while true do
              local p = s:Next(c)
              if not p then break end
              c = c + 3
              local r = s:Submit(p.answer, c)
              if r and r.specimen then
                ok(r.mastered, "specimen only with a new mastery")
                got = r.specimen
              end
            end
            local sum = s:Finish()
            if got and sum.specimens and #sum.specimens > 0 then ok(sum.specimens[1] == got, "round summary lists the specimen") end
          end
          ok(LP.GetTierRec(nodeId, t).mastered, "naturalist mastery through rounds: " .. nodeId .. " T" .. t)
          ok(got == J.Specimen(nodeId, t) and J.Has(nodeId, t) and J.Status(nodeId, t) == "collected", "mastery collects the specimen: " .. nodeId .. " T" .. t)
          collected = collected + 1
        end
      end
    end
    ok(select(1, J.Count(band)) == 8, "8 pages per band after 4 skills x 2 tiers: " .. band)
    ok(LT.ExamStatus("naturalist", band), "naturalist exam unlocks: " .. band)
    local ex = runTrial(tns, band, "exam", function() return true end, "naturalist")
    ok(ex.passed and ex.firstPass, "naturalist exam passes: " .. band)
  end
  ok(select(1, J.Count()) == collected and collected == 24, "journal total " .. collected)
  ok(J.Collect("nat_needs", 1) == nil, "a page is only collected once")
  ok(J.Collect("lc_grammar", 1) == nil and J.Specimen("rf_add", 1) == nil, "other subjects have no specimens")
  -- re-mastery after a fade gives no duplicate
  local s2 = tns.Session.New("lc_grammar", 1, 0)
  ok(s2 and #s2:Finish().specimens == 0, "other subjects' rounds have no specimens")
  -- review time: due tiers show faded ink, passing restores it
  NOW = NOW + LR.DAY + 5
  ok(J.FadedCount() > 0, "due reviews fade journal pages (" .. J.FadedCount() .. ")")
  local due = LR.Due()
  local anyNat = false
  for _, d in ipairs(due) do if d.moduleId == "naturalist" then anyNat = true end end
  ok(anyNat, "naturalist tiers come up in Review Time")
  local before = J.FadedCount()
  for _ = 1, 30 do
    local d = LR.Due()
    if #d == 0 then break end
    local s = tns.Session.NewReview(d, 0)
    local c = 0
    while true do
      local p = s:Next(c)
      if not p then break end
      c = c + 3
      s:Submit(p.answer, c)
    end
    s:Finish()
  end
  ok(J.FadedCount() < before and J.FadedCount() == 0, "passing reviews restores the ink")
  ok(select(1, J.Count()) == 24, "reviews never remove pages")
  -- fading (failed review) keeps the page but marks it faded
  local tr = LP.GetTierRec("nat_needs", 1)
  tr.fading = true
  ok(J.Status("nat_needs", 1) == "faded" and J.Has("nat_needs", 1), "fading tier = faded page, still collected")
  tr.fading = nil
  -- Flight prefers the module's sky skills while any is open
  LP.SetBand("initiate")
  local pref = nat.flightNodes.initiate
  local rid = tns.Mastery.Recommend("initiate", "naturalist", pref)
  local inPref = false
  for _, id in ipairs(pref) do if id == rid then inPref = true end end
  ok(inPref, "flight round picks a sky skill: " .. tostring(rid))
  ok(tns.Mastery.Recommend("initiate", "naturalist") ~= nil, "normal recommend unchanged")
  -- account-wide: a reset character keeps the journal; sync is a no-op then re-fills
  LP.ResetProfile()
  ok(select(1, J.Count()) == 24, "profile reset keeps the family journal")
  ok(#J.Sync() == 0, "sync with no mastery adds nothing")
  local acct2 = { version = 6, journal = { entries = {} } }
  LP.Bind(acct2, char)
  ok(select(1, J.Count()) == 0, "new account file starts empty")
  -- schema 5 -> 6: mastered Naturalist tiers from older progress land in the journal
  local oldChar = { version = 5, profile = { band = "adept" }, shards = 12, modules = { naturalist = { nodes = {
    nat_matter = { tiers = { { mastered = true, masteredAt = NOW - 100, attempts = 10, recent = {} }, {}, {} } } }, placement = {}, exams = {} } } }
  local oldAcct = { version = 5, settings = { dailyCap = 45 } }
  LP.Bind(oldAcct, oldChar)
  ok(oldAcct.version == 6 and oldChar.version == 6 and LP.upgradedFrom == 5, "v0.8 -> v0.9 bump")
  ok(type(oldAcct.journal) == "table" and J.Has("nat_matter", 1) and not J.Has("nat_matter", 2), "migration syncs mastered tiers into the journal")
  ok(oldAcct.settings.dailyCap == 45 and oldChar.shards == 12, "migration keeps everything else")
  ok(J.Entry("nat_matter", 1).at == NOW - 100, "synced page keeps its mastery date")
  -- report mentions nothing broken for naturalist
  local okRep, rep = pcall(tns.Report.Build, { moduleId = "naturalist" })
  ok(okRep and rep:find("Field Journal: 1 / 45", 1, true), "progress report shows the journal: " .. tostring(rep):sub(-200))
end

-------------------------------------------------------------------------
print(string.format("Generated %d problems: %d Rune Forger nodes x 5 levels x 3 tiers (%d per node) + 15 Scribe nodes x 5 levels x 3 tiers x 2 purposes.", genCount,
  (function() local n = 0 for _ in pairs(perNode) do n = n + 1 end return n end)(), ITER * 15))
print(string.format("Lore Chronicles + Lore Quiz: %d generated problems checked.", loreGenCount))
print(string.format("Azeroth Naturalist: %d generated problems checked; question bank: Initiate %d, Adept %d, Magister %d items (curated + generator data).",
  natGenCount, natItems.initiate or 0, natItems.adept or 0, natItems.magister or 0))
print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

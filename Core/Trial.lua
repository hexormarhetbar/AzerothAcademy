-- Trials: the placement test ("The Forgemaster's Trial") and the band post-test
-- ("Rune Mastery Exam"). Both use the SAME adaptive format so results compare cleanly:
--   per skill, problem 1 at level 2; if right -> problem 2 at level 4, if wrong -> level 1.
--   skill level: missed #1 -> 1 (start Spark) | #1 right, #2 missed -> 2 (Rune) | both -> 3 (Glyph)
-- No hints, no retries, no lost rewards. Trial objects expose the same interface as a
-- Session (Next/Submit/Finish/Header/Charge) so the same problem screen drives them.
local _, ns = ...
local Util = ns.Util

local T = {}
T.__index = T
ns.Trial = T

T.PER_SKILL = 2
T.LEVEL_FIRST, T.LEVEL_UP, T.LEVEL_DOWN = 2, 4, 1
T.PLACEMENT_SHARDS = 20
T.EXAM_SHARDS = 50
T.EXAM_PASS_SHARDS = 100
T.EXAM_PASS = 0.8          -- 8 of 10 correct passes the exam
T.EXAM_UNLOCK_RATIO = 0.8  -- 4 of 5 skills with Rune (or Glyph) mastered
T.HISTORY_MAX = 10

local function modState(moduleId) return ns.Progress.GetModuleState(moduleId) end
-- v1.1: World Tongues courses are open to every age, but still have placement and exams.
local function bandFor(moduleId, band)
  local m = ns.Modules.Get(moduleId)
  return (m and m.unbanded) and "everyone" or band
end

------------------------------------------------------------------------
-- Placement state helpers
------------------------------------------------------------------------
function T.GetPlacement(moduleId, band)
  return modState(moduleId).placement[bandFor(moduleId, band)]
end

local function ensurePlacement(moduleId, band)
  band = bandFor(moduleId, band)
  local st = modState(moduleId)
  st.placement[band] = st.placement[band] or {}
  return st.placement[band]
end

local function noTrials(moduleId)
  local m = ns.Modules.Get(moduleId)
  return m and m.noTrials
end
T.NoTrials = noTrials

function T.NeedsPlacement(moduleId, band)
  if noTrials(moduleId) then return false end
  local pl = T.GetPlacement(moduleId, band)
  return not (pl and pl.status)
end

function T.Skip(moduleId, band)
  local pl = ensurePlacement(moduleId, band)
  pl.status, pl.date = "skipped", Util.Now()
end

-- Parent re-run: the trial will be offered again on next entry.
function T.ResetPlacement(moduleId, band)
  local pl = ensurePlacement(moduleId, band)
  pl.status = nil
end

-- Effective starting tier for a skill: parent override > placement result > Spark.
function T.StartTier(nodeId)
  local module, node = ns.Modules.FindNode(nodeId)
  if not node or not ns.Progress.char then return 1 end
  local pl = modState(module.id).placement[node.band]
  if not pl then return 1 end
  if pl.override and pl.override[nodeId] then return pl.override[nodeId] end
  if pl.result and pl.result.perSkill and pl.result.perSkill[nodeId] then
    return pl.result.perSkill[nodeId].level or 1
  end
  return 1
end

function T.SetOverride(nodeId, tier)
  local module, node = ns.Modules.FindNode(nodeId)
  if not node then return false end
  tier = tonumber(tier)
  if tier and (tier < 1 or tier > 3) then return false end
  local pl = ensurePlacement(module.id, node.band)
  pl.override = pl.override or {}
  pl.override[nodeId] = tier and math.floor(tier) or nil
  return true
end

------------------------------------------------------------------------
-- Exam eligibility
------------------------------------------------------------------------
function T.SkillDone(nodeId)
  local P = ns.Progress
  return P.GetTierRec(nodeId, 2).mastered or P.GetTierRec(nodeId, 3).mastered
end

-- returns unlocked(bool), done(n), needed(n)
function T.ExamStatus(moduleId, band)
  if noTrials(moduleId) then return false, 0, 0 end
  local nodes = ns.Modules.Nodes(moduleId, band)
  local done = 0
  for _, nodeId in ipairs(nodes) do if T.SkillDone(nodeId) then done = done + 1 end end
  local needed = math.ceil(#nodes * T.EXAM_UNLOCK_RATIO - 1e-9)
  local P = ns.Progress
  local forced = P.account and P.account.settings.unlockAllTiers
  return (#nodes > 0 and done >= needed) or forced and true or false, done, needed
end

function T.GetExam(moduleId, band) return modState(moduleId).exams[bandFor(moduleId, band)] end

-- Placement (first ever, the true "before") vs latest and best exam ("after").
function T.Comparison(moduleId, band)
  local pl = T.GetPlacement(moduleId, band)
  local ex = T.GetExam(moduleId, band)
  local before = pl and pl.history and pl.history[1]
  local latest = ex and ex.attempts and ex.attempts[#ex.attempts]
  return { placement = before, latestPlacement = pl and pl.result, exam = latest, best = ex and ex.best, passed = ex and ex.passed }
end

------------------------------------------------------------------------
-- Trial object
------------------------------------------------------------------------
function T.New(moduleId, band, kind, now)
  band = bandFor(moduleId, band)
  local module = ns.Modules.Get(moduleId)
  if not module or module.noTrials or not module.bands[band] then return nil end
  local skills = {}
  for i, id in ipairs(module.bands[band].nodes) do skills[i] = id end
  return setmetatable({
    isTrial = true, kind = kind == "exam" and "exam" or "placement",
    moduleId = moduleId, module = module, band = band, skills = skills,
    total = #skills * T.PER_SKILL, index = 0, solved = 0, firstCorrect = 0, streak = 0,
    bestStreak = 0, perSkill = {}, noHints = true, resultView = "trialResult",
    startedAt = now or 0, tries = 0,
  }, T)
end

function T:Next(now)
  if self.index >= self.total then
    self.done = true
    return nil
  end
  self.index = self.index + 1
  local skillIdx = math.floor((self.index - 1) / T.PER_SKILL) + 1
  local step = (self.index - 1) % T.PER_SKILL + 1
  local nodeId = self.skills[skillIdx]
  local ps = self.perSkill[nodeId]
  if not ps then
    ps = { answers = {}, levels = {} }
    self.perSkill[nodeId] = ps
  end
  local level = T.LEVEL_FIRST
  if step > 1 then level = ps.answers[step - 1] and T.LEVEL_UP or T.LEVEL_DOWN end
  self.nodeId, self.step = nodeId, step
  local _, node = ns.Modules.FindNode(nodeId)
  self.node = node
  local p = ns.Modules.Generate(nodeId, level, 2, "trial")
  for _ = 1, 6 do
    if not (self.lastText and p.text == self.lastText) then break end
    p = ns.Modules.Generate(nodeId, level, 2, "trial")
  end
  self.lastText = p.text
  ps.levels[step] = level
  self.problem, self.problemDone, self.tries, self.shownAt = p, false, 0, now or 0
  return p
end

function T:IsLastProblem() return self.index >= self.total end

function T:Submit(given, now)
  local p = self.problem
  if not p or self.problemDone then return nil end
  local correct, info = ns.Modules.Check(p, given, { elapsed = math.max(0, (now or 0) - (self.shownAt or 0)), tier = 2 })
  self.tries = 1
  self.problemDone = true
  local ps = self.perSkill[self.nodeId]
  ps.answers[#ps.answers + 1] = correct
  if correct then
    self.solved = self.solved + 1
    self.firstCorrect = self.firstCorrect + 1
    self.streak = self.streak + 1
    if self.streak > self.bestStreak then self.bestStreak = self.streak end
  else
    self.streak = 0
  end
  return {
    correct = correct, final = true, tries = 1, shards = 0, levelChange = 0, trial = true, typing = info,
    explain = p.explain, answerText = ns.Modules.FormatAnswer(p),
    charge = self.index / self.total, streak = self.streak,
  }
end

function T:Header()
  local L = ns.L
  local nameKey = self.kind == "exam" and (self.module.examKey or "TRIAL_EXAM") or (self.module.placementKey or "TRIAL_PLACEMENT")
  return string.format(L.TRIAL_HEADER, L[nameKey], L[self.node.key], self.index, self.total)
end

function T:Charge()
  local answered = self.index - (self.problemDone and 0 or 1)
  return answered / self.total, string.format(ns.L.TRIAL_PROGRESS, answered, self.total)
end

local function skillLevel(ps)
  if not ps or not ps.answers[1] then return 1 end
  return ps.answers[2] and 3 or 2
end

local function compact(result)
  local per = {}
  for id, v in pairs(result.perSkill) do per[id] = { level = v.level, correct = v.correct } end
  return { kind = result.kind, date = result.date, correct = result.correct, total = result.total,
    avgLevel = result.avgLevel, passed = result.passed, perSkill = per }
end

local function pushHistory(list, entry)
  list[#list + 1] = entry
  -- keep the very first entry (the true baseline) plus the most recent ones
  while #list > T.HISTORY_MAX do table.remove(list, 2) end
end

-- Persist + reward (idempotent). Unfinished trials are not saved.
function T:Finish()
  if self.summary then return self.summary end
  local completed = self.index >= self.total and self.problemDone
  local perSkill, sum = {}, 0
  for _, nodeId in ipairs(self.skills) do
    local ps = self.perSkill[nodeId]
    local c = 0
    if ps then for _, a in ipairs(ps.answers) do if a then c = c + 1 end end end
    local lv = skillLevel(ps)
    perSkill[nodeId] = { level = lv, correct = c }
    sum = sum + lv
  end
  local result = {
    kind = self.kind, moduleId = self.moduleId, band = self.band, date = Util.Now(),
    correct = self.firstCorrect, total = self.total, perSkill = perSkill,
    avgLevel = #self.skills > 0 and sum / #self.skills or 0, completed = completed,
    shards = 0, minutes = 0, skills = self.skills,
  }
  if completed then
    local st = modState(self.moduleId)
    local P = ns.Progress
    local function award(n)
      local gained, up = P.AddShards(n)
      result.shards = result.shards + gained
      if up then result.rankUp = true end
    end
    if self.kind == "placement" then
      local pl = ensurePlacement(self.moduleId, self.band)
      pl.status, pl.date = "done", result.date
      pl.result = compact(result)
      pl.override = nil -- a fresh trial replaces old parent overrides
      pl.history = pl.history or {}
      pushHistory(pl.history, compact(result))
      award(T.PLACEMENT_SHARDS)
    else
      local ex = st.exams[self.band] or { attempts = {} }
      st.exams[self.band] = ex
      result.passed = result.correct >= math.ceil(result.total * T.EXAM_PASS - 1e-9)
      award(T.EXAM_SHARDS)
      if result.passed and not ex.passed then
        ex.passed, ex.passedAt = true, result.date
        result.firstPass = true
        award(T.EXAM_PASS_SHARDS)
        result.minutes = P.AwardMastery()
      end
      local entry = compact(result)
      pushHistory(ex.attempts, entry)
      if not ex.best or entry.correct > ex.best.correct or
        (entry.correct == ex.best.correct and entry.avgLevel > ex.best.avgLevel) then
        ex.best = compact(result)
      end
    end
  end
  self.summary = result
  return result
end

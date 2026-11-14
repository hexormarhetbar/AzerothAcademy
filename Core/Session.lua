-- The round engine. Module-agnostic: it only knows "a plan of (nodeId, tier) slots",
-- resolves generators through ns.Modules, and records results through Progress/Mastery.
--   practice round: 6 slots of one skill+tier, adaptive difficulty
--   review round:   up to 2 due tiers x 3 problems, fixed mid-tier difficulty
-- The UI passes in a clock value (GetTime()) and the kid's answer.
local _, ns = ...
local Util = ns.Util

local S = {}
S.__index = S
ns.Session = S

S.ROUND_SIZE = 6
S.COMBO_AT = 3
S.OVERCHARGE_AT = 5
S.COMBO_BONUS = 5
S.RETRY_SHARDS = 3
S.ROUND_BONUS = 10
S.MASTERY_BONUS = 50
S.STEP_UP_AFTER = 3   -- first-try corrects in a row
S.STEP_DOWN_AFTER = 2 -- misses in a row
S.MAX_PROBLEM_SECONDS = 120

local function create(mode, plan, now)
  local first = plan[1]
  local module, node = ns.Modules.FindNode(first.nodeId)
  local t = ns.Mastery.TIERS[first.tier]
  return setmetatable({
    mode = mode, plan = plan, adaptive = (mode == "practice"),
    moduleId = module.id, module = module,
    nodeId = first.nodeId, tier = first.tier, node = node,
    level = t.base, minLevel = t.base, maxLevel = t.max,
    index = 0, total = #plan,
    firstCorrect = 0, solved = 0, streak = 0, bestStreak = 0,
    rightRun = 0, wrongRun = 0,
    shards = 0, minutes = 0, masteredNow = false, rankUp = false,
    tries = 0, startedAt = now or 0, done = false, finished = false, log = {},
    items = {}, itemOrder = {}, specimens = {},
  }, S)
end

-- Practice round on one skill + tier (v0.1 signature kept).
-- size (v0.7, optional): fewer problems for a quick in-flight round (1..ROUND_SIZE).
function S.New(nodeId, tier, now, size)
  local _, node = ns.Modules.FindNode(nodeId)
  if not node then return nil end
  tier = Util.Clamp(tier or 1, 1, 3)
  size = Util.Clamp(math.floor(tonumber(size) or S.ROUND_SIZE), 1, S.ROUND_SIZE)
  local plan = {}
  for i = 1, size do plan[i] = { nodeId = nodeId, tier = tier } end
  return create("practice", plan, now)
end

-- Review round. items = { {nodeId=, tier=}, ... } (extra items are ignored).
function S.NewReview(items, now)
  local R = ns.Review
  local plan = {}
  for i = 1, math.min(#items, R.MAX_ITEMS) do
    local it = items[i]
    if select(2, ns.Modules.FindNode(it.nodeId)) then
      for _ = 1, R.ITEM_PROBLEMS do plan[#plan + 1] = { nodeId = it.nodeId, tier = it.tier } end
    end
  end
  if #plan == 0 then return nil end
  return create("review", plan, now)
end

local function itemKey(nodeId, tier) return nodeId .. "#" .. tier end

function S:Next(now)
  if self.index >= self.total then
    self.done = true
    return nil
  end
  self.index = self.index + 1
  local slot = self.plan[self.index]
  local _, node = ns.Modules.FindNode(slot.nodeId)
  self.nodeId, self.tier, self.node = slot.nodeId, slot.tier, node
  self.tries = 0
  self.problemDone = false
  self.shownAt = now or 0
  local level
  if self.adaptive then
    level = self.level
  else
    local t = ns.Mastery.TIERS[slot.tier]
    level = Util.Clamp(t.base + 1, t.base, t.max)
  end
  local purpose = self.mode
  local p = ns.Modules.Generate(slot.nodeId, level, slot.tier, purpose)
  for _ = 1, 6 do
    if not (self.lastText and p.text == self.lastText) then break end
    p = ns.Modules.Generate(slot.nodeId, level, slot.tier, purpose)
  end
  self.lastText = p.text
  self.problem = p
  local key = itemKey(slot.nodeId, slot.tier)
  if not self.items[key] then
    self.items[key] = { nodeId = slot.nodeId, tier = slot.tier, correct = 0, total = 0 }
    self.itemOrder[#self.itemOrder + 1] = key
  end
  return p
end

function S:IsLastProblem() return self.index >= self.total end

local function award(self, n, r)
  if n <= 0 then return end
  local gained, up = ns.Progress.AddShards(n)
  self.shards = self.shards + gained
  r.shards = (r.shards or 0) + gained
  if up then
    self.rankUp = true
    r.rankUp = true
  end
end

-- Returns a result table, or nil if no problem is pending.
function S:Submit(given, now)
  local p = self.problem
  if not p or self.problemDone then return nil end
  local elapsed = math.max(0, (now or 0) - (self.shownAt or 0))
  local correct, info = ns.Modules.Check(p, given, { elapsed = elapsed, tier = self.tier })
  self.tries = self.tries + 1
  local r = { correct = correct, tries = self.tries, shards = 0, levelChange = 0, typing = info }
  local dt = Util.Clamp((now or 0) - (self.shownAt or 0), 0, S.MAX_PROBLEM_SECONDS)
  self.shownAt = now or self.shownAt

  local P, M = ns.Progress, ns.Mastery
  local rec = P.GetTierRec(self.nodeId, self.tier)
  if info and info.wpm and correct then
    -- typing skills keep a personal best speed (only for accurate attempts)
    if info.wpm > (rec.bestWpm or 0) then rec.bestWpm = info.wpm; r.newBestWpm = true end
  end
  local stats = P.char.stats
  stats.time = stats.time + dt
  if self.tries == 1 then
    stats.problems = stats.problems + 1
    if correct then stats.firstCorrect = stats.firstCorrect + 1 end
    local item = self.items[itemKey(self.nodeId, self.tier)]
    item.total = item.total + 1
    if correct then item.correct = item.correct + 1 end
    if M.Record(rec, correct, dt) then
      self.masteredNow = true
      r.mastered = true
      local grant = P.AwardMastery()
      self.minutes = self.minutes + grant
      r.minutes = grant
      award(self, S.MASTERY_BONUS, r)
      -- v0.9: subjects with a Field Journal hand out a specimen page per mastered tier
      if ns.Journal and ns.Journal.Specimen(self.nodeId, self.tier) then
        local spec = ns.Journal.Collect(self.nodeId, self.tier)
        if spec then
          r.specimen = spec
          self.specimens[#self.specimens + 1] = spec
        end
      end
    end
  else
    rec.time = rec.time + dt -- retries still count as time spent learning
  end

  local gain = 0
  if correct then
    self.solved = self.solved + 1
    r.final = true
    if self.tries == 1 then
      self.firstCorrect = self.firstCorrect + 1
      self.streak = self.streak + 1
      if self.streak > self.bestStreak then self.bestStreak = self.streak end
      self.wrongRun = 0
      self.rightRun = self.rightRun + 1
      if self.adaptive and self.rightRun >= S.STEP_UP_AFTER then
        self.rightRun = 0
        if self.level < self.maxLevel then
          self.level = self.level + 1
          r.levelChange = 1
        end
      end
      gain = M.TIERS[self.tier].shards
      if self.streak >= S.COMBO_AT then
        r.combo = self.streak
        gain = gain + S.COMBO_BONUS
      end
      if self.streak >= S.OVERCHARGE_AT then
        r.overcharge = true
        gain = gain * 2
      end
    else
      gain = S.RETRY_SHARDS
    end
  else
    self.streak = 0
    self.rightRun = 0
    self.wrongRun = self.wrongRun + 1
    if self.adaptive and self.wrongRun >= S.STEP_DOWN_AFTER then
      self.wrongRun = 0
      if self.level > self.minLevel then
        self.level = self.level - 1
        r.levelChange = -1
      end
    end
    if self.tries >= 2 then
      r.final = true
      r.explain = p.explain
      r.answerText = ns.Modules.FormatAnswer(p)
    else
      r.retry = true
      r.hint = p.hint
    end
  end
  award(self, gain, r)
  if r.final then
    self.problemDone = true
    self.log[#self.log + 1] = { correct = correct, tries = self.tries, level = p.level, nodeId = self.nodeId, tier = self.tier }
  end
  r.charge = self.solved / self.total
  r.streak = self.streak
  return r
end

function S:Header()
  local L = ns.L
  local fmtKey = self.mode == "review" and "REVIEW_HEADER" or "PROBLEM_HEADER"
  return string.format(L[fmtKey], L[self.node.key], L[ns.Mastery.TIERS[self.tier].key], self.index, self.total)
end

function S:Charge()
  return self.solved / self.total, ns.L.CHARGE .. string.format("  %d/%d", self.solved, self.total)
end

-- Close out the round (idempotent). Returns a summary for the reward screen.
function S:Finish()
  local completed = self.index >= self.total and self.problemDone
  local R = ns.Review
  if not self.finished then
    self.finished = true
    self.done = true
    self.reviewResults = {}
    if completed then
      local dummy = {}
      award(self, S.ROUND_BONUS, dummy)
      ns.Progress.char.stats.rounds = ns.Progress.char.stats.rounds + 1
      local now = Util.Now()
      for _, key in ipairs(self.itemOrder) do
        local it = self.items[key]
        local rec = ns.Progress.GetTierRec(it.nodeId, it.tier)
        if self.mode == "review" then
          local passed = R.Apply(rec, it.correct, it.total, now)
          self.reviewResults[#self.reviewResults + 1] = {
            nodeId = it.nodeId, tier = it.tier, correct = it.correct, total = it.total,
            passed = passed, fading = rec.fading, solid = rec.review and rec.review.done or false,
          }
        else
          self.fadingCleared = R.NoteRound(rec, it.correct, it.total) or nil
        end
      end
    end
  end
  local rec = ns.Progress.GetTierRec(self.nodeId, self.tier)
  local recentCorrect, recentTotal = ns.Mastery.RecentCorrect(rec)
  local earned, cap = ns.Progress.GetTodayMinutes()
  return {
    mode = self.mode, moduleId = self.moduleId,
    nodeId = self.nodeId, tier = self.tier, completed = completed,
    firstCorrect = self.firstCorrect, total = self.total, bestStreak = self.bestStreak,
    shards = self.shards, minutes = self.minutes, minutesToday = earned, minutesCap = cap,
    masteredNow = self.masteredNow, tierMastered = rec.mastered, rankUp = self.rankUp,
    recentCorrect = recentCorrect, recentTotal = recentTotal, fading = rec.fading,
    fadingCleared = self.fadingCleared, reviews = self.reviewResults,
    specimens = self.specimens,
    rank = ns.Progress.GetRankInfo(),
  }
end

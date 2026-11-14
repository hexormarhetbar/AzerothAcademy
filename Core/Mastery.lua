-- Mastery: per node, per tier rolling window of first-attempt results.
-- Mastered = at least 85% correct over the last 10 attempts (i.e. 9 of 10).
local _, ns = ...
local Util = ns.Util

local M = {}
ns.Mastery = M

M.WINDOW = 10
M.THRESHOLD = 0.85
-- Each tier has its own difficulty range on a 1..5 scale.
M.TIERS = {
  { key = "TIER_SPARK", base = 1, max = 3, shards = 10 },
  { key = "TIER_RUNE",  base = 2, max = 4, shards = 15 },
  { key = "TIER_GLYPH", base = 3, max = 5, shards = 20 },
}

function M.Required()
  return math.ceil(M.WINDOW * M.THRESHOLD - 1e-9)
end

function M.RecentCorrect(rec)
  local n = 0
  for i = 1, #rec.recent do n = n + (rec.recent[i] or 0) end
  return n, #rec.recent
end

function M.WindowMet(rec)
  local n, total = M.RecentCorrect(rec)
  return total >= M.WINDOW and n >= M.Required()
end

-- Record one first-attempt result. Returns true if this attempt newly mastered the tier.
function M.Record(rec, correct, dt)
  rec.attempts = rec.attempts + 1
  if correct then rec.correct = rec.correct + 1 end
  rec.time = rec.time + (dt or 0)
  rec.recent[#rec.recent + 1] = correct and 1 or 0
  while #rec.recent > M.WINDOW do table.remove(rec.recent, 1) end
  if not rec.mastered and M.WindowMet(rec) then
    rec.mastered = true
    rec.masteredAt = Util.Now()
    if ns.Review then ns.Review.Schedule(rec, rec.masteredAt) end
    return true
  end
  return false
end

function M.Accuracy(rec)
  if not rec or rec.attempts == 0 then return nil end
  return rec.correct / rec.attempts
end

local function startTier(nodeId)
  return ns.Trial and ns.Trial.StartTier(nodeId) or 1
end

function M.IsTierUnlocked(nodeId, tier)
  if tier <= 1 then return true end
  local P = ns.Progress
  if P.account and P.account.settings.unlockAllTiers then return true end
  if startTier(nodeId) >= tier then return true end -- placement / parent override
  return P.GetTierRec(nodeId, tier - 1).mastered
end

-- The tier a kid should work on next for this node (respects the placement start tier).
function M.CurrentTier(nodeId)
  local from = startTier(nodeId)
  for t = from, 3 do
    if M.IsTierUnlocked(nodeId, t) and not ns.Progress.GetTierRec(nodeId, t).mastered then
      return t
    end
  end
  return 3
end

function M.MasteredCount(nodeId)
  local n = 0
  for t = 1, 3 do
    if ns.Progress.GetTierRec(nodeId, t).mastered then n = n + 1 end
  end
  return n
end

-- Pick a node for a quick drill: fading tiers first, then least-mastered, then fewest attempts.
-- prefer (v0.9, optional): a list of node ids to try first (e.g. a subject's in-flight
-- skills). Ignored once every preferred skill in this band is fully mastered.
function M.Recommend(bandId, moduleId, prefer)
  local nodes = ns.Modules.Nodes(moduleId or "runeforger", bandId)
  if #nodes == 0 then return nil end
  if type(prefer) == "table" and #prefer > 0 then
    local want, sub, open = {}, {}, false
    for _, id in ipairs(prefer) do want[id] = true end
    for _, id in ipairs(nodes) do
      if want[id] then
        sub[#sub + 1] = id
        if M.MasteredCount(id) < 3 then open = true end
      end
    end
    if open then nodes = sub end
  end
  for _, nodeId in ipairs(nodes) do
    for t = 1, 3 do
      if ns.Progress.GetTierRec(nodeId, t).fading then return nodeId, t end
    end
  end
  local best, bestScore
  for i, nodeId in ipairs(nodes) do
    local attempts = 0
    for t = 1, 3 do attempts = attempts + ns.Progress.GetTierRec(nodeId, t).attempts end
    local score = M.MasteredCount(nodeId) * 100000 + attempts * 10 + i
    if not bestScore or score < bestScore then best, bestScore = nodeId, score end
  end
  return best, best and M.CurrentTier(best)
end

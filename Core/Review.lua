-- Spaced review: a mastered tier comes back after 1, 3 and 7 days.
-- Pass a review -> next interval (after the 7-day review it is "solid").
-- Miss a review -> the tier is flagged "fading" (mastery and rewards are kept) and the
-- schedule restarts at 1 day. A strong practice round (5/6) or a passed review clears it.
local _, ns = ...
local Util = ns.Util

local R = {}
ns.Review = R

R.DAY = 86400
R.INTERVALS = { 1, 3, 7 } -- days
R.ITEM_PROBLEMS = 3       -- problems per reviewed tier
R.MAX_ITEMS = 2           -- tiers per review round (2 x 3 = 6 problems)
R.CLEAR_FADING_AT = 5     -- first-try corrects in a 6-problem practice round

function R.PassMark(total) return math.ceil(total * 2 / 3) end

function R.Schedule(rec, from)
  rec.review = { stage = 1, due = (from or Util.Now()) + R.INTERVALS[1] * R.DAY }
end

function R.IsDue(rec, now)
  return rec and rec.mastered and type(rec.review) == "table" and not rec.review.done
    and (rec.review.due or 0) <= (now or Util.Now())
end

local function enabled()
  local P = ns.Progress
  return not (P.account and P.account.settings.reviews == false)
end

-- Walk every existing tier record of every registered module (never creates records).
local function eachTier(fn)
  local P = ns.Progress
  if not P.char or type(P.char.modules) ~= "table" then return end
  for _, module in ipairs(ns.Modules.list) do
    local st = P.char.modules[module.id]
    -- v1.1: areas switched off in Settings have no reviews due (records are kept)
    if st and type(st.nodes) == "table" and ns.Modules.IsShown(module) then
      for _, bandId in ipairs(ns.Modules.BandIds(module)) do
        for _, nodeId in ipairs(ns.Modules.Nodes(module.id, bandId)) do
          local nr = st.nodes[nodeId]
          if type(nr) == "table" and type(nr.tiers) == "table" then
            for t = 1, 3 do
              if type(nr.tiers[t]) == "table" then fn(module.id, nodeId, t, nr.tiers[t]) end
            end
          end
        end
      end
    end
  end
end
R.EachTier = eachTier

-- Due reviews, most overdue first: { {moduleId, nodeId, tier, due, fading}, ... }
function R.Due(now)
  now = now or Util.Now()
  local out = {}
  if not enabled() then return out end
  eachTier(function(moduleId, nodeId, tier, rec)
    if R.IsDue(rec, now) then
      out[#out + 1] = { moduleId = moduleId, nodeId = nodeId, tier = tier, due = rec.review.due, fading = rec.fading }
    end
  end)
  table.sort(out, function(a, b)
    if a.due ~= b.due then return a.due < b.due end
    if a.nodeId ~= b.nodeId then return a.nodeId < b.nodeId end
    return a.tier < b.tier
  end)
  return out
end

function R.Fading()
  local out = {}
  eachTier(function(moduleId, nodeId, tier, rec)
    if rec.fading then out[#out + 1] = { moduleId = moduleId, nodeId = nodeId, tier = tier } end
  end)
  return out
end

-- Apply a finished review of one tier. Returns passed(bool).
function R.Apply(rec, correct, total, now)
  now = now or Util.Now()
  if type(rec.review) ~= "table" then R.Schedule(rec, now) end
  local rv = rec.review
  local passed = correct >= R.PassMark(total)
  if passed then
    rec.fading = false
    rv.stage = (rv.stage or 1) + 1
    if rv.stage > #R.INTERVALS then
      rv.done = true
      rv.due = nil
    else
      rv.due = now + R.INTERVALS[rv.stage] * R.DAY
    end
  else
    rec.fading = true
    rv.done = nil
    rv.stage = 1
    rv.due = now + R.INTERVALS[1] * R.DAY
  end
  rv.last = { date = now, passed = passed, correct = correct, total = total }
  return passed
end

-- A normal practice round on a fading tier can clear the flag. Returns true if cleared.
function R.NoteRound(rec, firstCorrect, total)
  if rec.fading and total >= 6 and firstCorrect >= R.CLEAR_FADING_AT then
    rec.fading = false
    return true
  end
  return false
end

-- Plain-text progress report for the parent export box. Covers every registered module.
local _, ns = ...
local Util = ns.Util

local Report = {}
ns.Report = Report

local function pct(rec)
  local a = ns.Mastery.Accuracy(rec)
  return a and string.format("%d%%", math.floor(a * 100 + 0.5)) or "-"
end

local function dayText(t)
  if not t then return "-" end
  local f = ns.Env.date or date or (os and os.date)
  return f and f("%Y-%m-%d", t) or tostring(t)
end

local function trialLine(L, label, r)
  if not r then return string.format("  %-16s " .. L.RPT_NOT_TAKEN, label) end
  return string.format("  %-16s %s  " .. L.RPT_TRIAL_LINE .. "%s", label, dayText(r.date), r.correct or 0,
    r.total or 0, r.avgLevel or 0, r.passed and ("  " .. L.RPT_PASSED) or "")
end

-- info = { player = "Name-Realm", moduleId = nil (all subjects) | "runeforger" | "scribe" ... }
function Report.Build(info)
  info = info or {}
  local L, P, M, T, R = ns.L, ns.Progress, ns.Mastery, ns.Trial, ns.Review
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  local bandId = P.GetBand()
  local band = bandId and P.BAND_BY_ID[bandId]
  local rank = P.GetRankInfo()
  local earned, cap = P.GetTodayMinutes()
  local st = P.char.stats
  local tierNames = { L.TIER_SPARK, L.TIER_RUNE, L.TIER_GLYPH }

  add(string.format(L.RPT_TITLE, ns.VERSION))
  add(string.format(L.RPT_GENERATED, Util.DateText()) .. (info.player and ("  |  " .. string.format(L.RPT_CHARACTER, info.player)) or ""))
  add(string.format(L.RPT_PATH, band and string.format(L.RPT_PATH_BAND, L[band.key], band.ages) or L.RPT_NOT_SET))
  add(string.format(L.RPT_RANK, L[rank.key], P.char.shards))
  add(string.format(L.RPT_MINUTES, earned, cap, P.account.settings.minutesPerMastery))
  add(string.format(L.RPT_ROUNDS,
    st.rounds, st.problems, st.problems > 0 and string.format("%d%%", math.floor(st.firstCorrect / st.problems * 100 + 0.5)) or "-",
    Util.FormatDuration(st.time)))

  local due, fading = R.Due(), R.Fading()
  add(string.format(L.RPT_DUE, #due, #fading))

  local trouble = {}
  if info.moduleId and ns.Modules.Get(info.moduleId) then
    add(string.format(L.RPT_SUBJECT, L[ns.Modules.Get(info.moduleId).nameKey]))
  else
    add(L.RPT_SUBJECTS_ALL)
  end
  for _, module in ipairs(ns.Modules.list) do
   if not info.moduleId or info.moduleId == module.id or not ns.Modules.Get(info.moduleId) then
    add("")
    add(string.format(L.RPT_MODULE_HEAD, string.upper(L[module.nameKey])))
    add(L.RPT_FORMAT)
    for _, b in ipairs(module.unbanded and { ns.Modules.EVERYONE } or P.BANDS) do
      local nodes = ns.Modules.Nodes(module.id, b.id)
      local any = b.id == bandId
      for _, nodeId in ipairs(nodes) do
        local nr = P.GetNodeRec(nodeId)
        for t = 1, 3 do if nr.tiers[t].attempts > 0 then any = true end end
      end
      if any and #nodes > 0 then
        add("-- " .. L[b.key] .. " (" .. b.ages .. ") --")
        for _, nodeId in ipairs(nodes) do
          local _, node = ns.Modules.FindNode(nodeId)
          local parts, time, wpm = {}, 0, 0
          for t = 1, 3 do
            local rec = P.GetTierRec(nodeId, t)
            time = time + rec.time
            if (rec.bestWpm or 0) > wpm then wpm = rec.bestWpm end
            local rc, rt = M.RecentCorrect(rec)
            parts[#parts + 1] = string.format("%s: %s (%d) %d/%d%s%s", tierNames[t], pct(rec), rec.attempts, rc, rt,
              rec.mastered and (" [" .. L.RPT_MASTERED .. "]") or "", rec.fading and (" [" .. L.RPT_FADING .. "]") or "")
            if rt >= 5 and rc / rt < 0.6 then
              trouble[#trouble + 1] = string.format(L.RPT_TROUBLE, L[node.key], tierNames[t], rc, rt)
            end
            if rec.fading then
              trouble[#trouble + 1] = string.format(L.RPT_TROUBLE_FADING, L[node.key], tierNames[t])
            end
          end
          add(string.format(L.RPT_NODE_LINE, L[node.key], table.concat(parts, " | "),
            tierNames[T.StartTier(nodeId)], Util.FormatDuration(time)) .. (wpm > 0 and (" | " .. string.format(L.RPT_BEST_WPM, wpm)) or ""))
        end
        -- Placement vs post-test
        local cmp = module.noTrials and {} or T.Comparison(module.id, b.id)
        local pl = T.GetPlacement(module.id, b.id)
        if module.noTrials then
          add("  " .. L.RPT_NO_TRIALS)
        else
        add("  " .. string.format(L.RPT_VS, L[module.placementKey or "TRIAL_PLACEMENT"], L[module.examKey or "TRIAL_EXAM"]))
        if pl and pl.status == "skipped" and not cmp.placement then
          add("  " .. (pl.migrated and L.RPT_SKIPPED_MIGRATED or L.RPT_SKIPPED))
        end
        add(trialLine(L, L.RPT_L_PLACEMENT, cmp.placement))
        add(trialLine(L, L.RPT_L_LATEST, cmp.exam))
        if cmp.best and cmp.exam and (cmp.best.date ~= cmp.exam.date or cmp.best.correct ~= cmp.exam.correct) then add(trialLine(L, L.RPT_L_BEST, cmp.best)) end
        if cmp.placement and cmp.exam then
          local growth = {}
          for _, nodeId in ipairs(nodes) do
            local a = cmp.placement.perSkill and cmp.placement.perSkill[nodeId]
            local z = cmp.exam.perSkill and cmp.exam.perSkill[nodeId]
            if a and z then
              local _, node = ns.Modules.FindNode(nodeId)
              growth[#growth + 1] = string.format("%s %s->%s", L[node.key], tierNames[a.level], tierNames[z.level])
            end
          end
          add("  " .. string.format(L.RPT_GROWTH, cmp.exam.correct - cmp.placement.correct,
            cmp.placement.correct, cmp.exam.correct, cmp.exam.total, table.concat(growth, ", ")))
        end
        end -- noTrials
      end
    end
    if module.game and ns.Boarding then
      for _, l in ipairs(ns.Boarding.ReportLines()) do add(l) end
    end
   end
  end
  add("")
  if #due > 0 then
    local names = {}
    for _, d in ipairs(due) do
      local _, node = ns.Modules.FindNode(d.nodeId)
      names[#names + 1] = L[node.key] .. " (" .. tierNames[d.tier] .. ")"
    end
    add(string.format(L.RPT_REVIEWS_DUE, table.concat(names, ", ")))
  end
  if #trouble > 0 then
    add(L.RPT_NEEDS)
    for _, s in ipairs(trouble) do add("  * " .. s) end
  else
    add(L.RPT_NEEDS_NONE)
  end
  if ns.Journal then
    for _, b in ipairs(ns.Journal.Books()) do
      if not info.moduleId or info.moduleId == b.moduleId then
        local have, total = ns.Journal.Count(nil, b.moduleId)
        add(string.format(ns.Journal.Str(b.moduleId, "STATUS"), have, total))
      end
    end
  end
  add("")
  add(L.RPT_PRIVACY)
  return table.concat(lines, "\n")
end

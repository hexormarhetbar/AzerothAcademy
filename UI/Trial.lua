-- Trial screens shared by every module: the intro card for the placement trial
-- ("The Forgemaster's Trial") or the Mastery Exam, and the result card.
-- The questions themselves run on the normal problem screen (Trial objects speak
-- the Session interface), so this file only shows before/after.
local _, ns = ...
local W, H = ns.W, ns.Hub
local L = ns.L

local function tierName(t) return L[ns.Mastery.TIERS[t].key] end
local function say(event) if ns.GuideUI then ns.GuideUI.Say(event) end end

------------------------------------------------------------------------
-- View: trial intro (arg: "placement" | "exam")
------------------------------------------------------------------------
H.RegisterView("trial", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local icon = W.FramedIcon(v, 56, "Interface\\Icons\\INV_Hammer_20")
  icon:SetPoint("TOP", 0, -20)
  -- v1.0.0-rc: subjects with a host (Zixi, Quill) show the host instead of the subject icon
  local host = ns.GuideUI and ns.GuideUI.Portrait(v, 72, 72, nil, true)
  if host then host:SetPoint("CENTER", icon, "CENTER", 0, -4); host:Hide() end
  v.host = host
  local title = W.Text(v, 22, "", W.GOLD, "CENTER")
  title:SetPoint("TOP", icon, "BOTTOM", 0, -16)
  local lore = W.Text(v, 13, "", W.ARCANE, "CENTER")
  lore:SetPoint("TOP", title, "BOTTOM", 0, -14)
  lore:SetWidth(480)
  local details = W.Text(v, 11, "", W.GRAY, "CENTER")
  details:SetPoint("TOP", lore, "BOTTOM", 0, -12)
  details:SetWidth(480)
  local status = W.Text(v, 12, "", W.AMBER, "CENTER")
  status:SetPoint("TOP", details, "BOTTOM", 0, -10)
  status:SetWidth(480)

  local start = W.Button(v, L.TRIAL_START, 170, 34, function()
    ns.Lessons.StartTrial(v.kind)
  end, 14)
  start:SetPoint("BOTTOM", -95, 40)
  local skip = W.Button(v, L.TRIAL_SKIP, 170, 34, function()
    if v.kind == "placement" then
      ns.Trial.Skip(ns.Lessons.CurrentModule().id, ns.Progress.GetBand())
      H.ShowView("forge")
    else
      H.ShowView("forge")
    end
  end, 14)
  skip:SetPoint("BOTTOM", 95, 40)

  function v:OnShowView(kind)
    if kind then self.kind = kind end
    self.kind = self.kind or "placement"
    local module = ns.Lessons.CurrentModule()
    local band = ns.Progress.GetBand()
    if not band then
      H.ShowView("profile")
      return
    end
    if module.noTrials then -- e.g. the Lore Quiz for Everyone has no trials
      H.ShowView("forge")
      return
    end
    local nodes = ns.Modules.Nodes(module.id, band)
    if module.icon then icon:SetTexture(module.icon) end
    local hostId = ns.Art.HostFor(module.id)
    if host and hostId then
      ns.GuideUI.ShowHost(host, hostId, self.kind == "exam" and "exam" or "placement", true)
      host:Show(); icon:Hide()
    else
      if host then host:Hide() end
      icon:Show()
    end
    details:SetText(string.format(L.TRIAL_DETAILS, #nodes * ns.Trial.PER_SKILL, ns.Trial.PER_SKILL))
    if self.kind == "exam" then
      title:SetText(L[module.examKey or "TRIAL_EXAM"])
      lore:SetText(L[module.examLoreKey or "TRIAL_EXAM_LORE"])
      start:SetText(L.EXAM_START)
      skip:SetText(L.NOT_YET)
      local unlocked, done, need = ns.Trial.ExamStatus(module.id, band)
      if unlocked then
        start:Enable()
        status:SetText("")
      else
        start:Disable()
        status:SetText(string.format(L.EXAM_LOCKED, done, need))
      end
    else
      title:SetText(L[module.placementKey or "TRIAL_PLACEMENT"])
      lore:SetText(L[module.placementLoreKey or "TRIAL_PLACEMENT_LORE"])
      start:SetText(L.TRIAL_START)
      skip:SetText(L.TRIAL_SKIP)
      start:Enable()
      status:SetText("")
    end
  end
  return v
end)

------------------------------------------------------------------------
-- View: trial result (arg: result table from Trial:Finish())
------------------------------------------------------------------------
H.RegisterView("trialResult", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local title = W.Text(v, 22, "", W.GOLD, "CENTER")
  title:SetPoint("TOP", 0, -14)
  title:SetWidth(540)
  local score = W.Text(v, 16, "", W.WHITE, "CENTER")
  score:SetPoint("TOP", title, "BOTTOM", 0, -10)
  local lines = {}
  local prev = score
  for i = 1, 6 do
    local fs = W.Text(v, 12, "", W.WHITE, "CENTER")
    fs:SetPoint("TOP", prev, "BOTTOM", 0, i == 1 and -14 or -5)
    fs:SetWidth(520)
    lines[i] = fs
    prev = fs
  end
  local note = W.Text(v, 11, "", W.GRAY, "CENTER")
  note:SetPoint("TOP", prev, "BOTTOM", 0, -12)
  note:SetWidth(500)
  local reward = W.Text(v, 13, "", W.GOLD, "CENTER")
  reward:SetPoint("TOP", note, "BOTTOM", 0, -8)
  reward:SetWidth(520)

  if ns.GuideUI then
    v.hero = ns.GuideUI.Hero(v, 130) -- v0.5.1 posed art, hidden without art
    v.hero:SetPoint("TOPLEFT", -6, -40)
    -- v1.0.0-rc: the subject's host stands on the other side (full figure, art only)
    v.hostHero = ns.GuideUI.Portrait(v, 130, 130, nil, true)
    v.hostHero:SetPoint("TOPRIGHT", 6, -40)
    v.hostHero:Hide()
  end
  local function showHostHero(moduleId, moment)
    local hh, hostId = v.hostHero, ns.Art.HostFor(moduleId)
    if not hh then return end
    if hostId and ns.GuideUI.ShowHost(hh, hostId, moment, false) == "art" then
      hh:Show()
      if not W.ReducedMotion() then W.Reveal(hh.art, 0.5) end
    else
      hh:Hide()
    end
  end
  local cont = W.Button(v, L.CONTINUE, 160, 32, function() H.ShowView("forge") end, 14)
  cont:SetPoint("BOTTOM", -85, 8)
  local hub = W.Button(v, L.HUB, 160, 32, function() H.ShowView("home") end, 14)
  hub:SetPoint("BOTTOM", 85, 8)

  function v:OnShowView(result)
    if result then self.result = result end
    local r = self.result
    if not r then
      H.ShowView("forge")
      return
    end
    for _, fs in ipairs(lines) do fs:SetText("") end
    reward:SetText("")
    local module = ns.Modules.Get(r.moduleId) or ns.Lessons.CurrentModule()
    if not r.completed then
      title:SetText(L[r.kind == "exam" and (module.examKey or "TRIAL_EXAM") or (module.placementKey or "TRIAL_PLACEMENT")])
      score:SetText("")
      note:SetText(L.TRIAL_UNFINISHED)
      showHostHero(module.id, "unfinished")
      return
    end
    score:SetText(string.format(L.TRIAL_RESULT_SCORE, r.correct, r.total))
    if v.hero then
      v.heroPose = (r.kind == "exam") and (r.passed and "celebrating" or "encouraging") or "proud"
      ns.GuideUI.ShowHero(v.hero, v.heroPose)
    end
    v.hostMoment = (r.kind == "exam") and (r.passed and "passed" or "tryagain") or "placed"
    showHostHero(module.id, v.hostMoment)
    local base = r.kind == "exam" and ns.Trial.Comparison(r.moduleId, r.band).placement
    for i, nodeId in ipairs(r.skills or {}) do
      if lines[i] then
        local _, node = ns.Modules.FindNode(nodeId)
        local lv = r.perSkill[nodeId] and r.perSkill[nodeId].level or 1
        if r.kind == "exam" then
          local was = base and base.perSkill and base.perSkill[nodeId]
          if was then
            lines[i]:SetText(string.format(L.EXAM_SKILL_LINE, L[node.key], tierName(was.level), tierName(lv)))
          else
            lines[i]:SetText(string.format(L.EXAM_SKILL_LINE_NOPL, L[node.key], tierName(lv)))
          end
        else
          lines[i]:SetText(string.format(L.TRIAL_SKILL_LINE, L[node.key], tierName(ns.Trial.StartTier(nodeId))))
        end
      end
    end
    local rewardText = string.format(L.TRIAL_SHARDS, r.shards or 0)
    if (r.minutes or 0) > 0 then rewardText = rewardText .. "   " .. string.format(L.EXAM_MINUTES, r.minutes) end
    reward:SetText(rewardText)
    if r.kind == "exam" then
      local band = ns.Progress.BAND_BY_ID[r.band]
      if r.passed then
        title:SetText(string.format(L[module.examPassKey or "EXAM_RESULT_PASS"], band and L[band.key] or r.band))
        W.Sparks(v, 20, W.GOLD)
        if result then
          ns.Compat.Sound("exampass")
          say("EXAMPASS")
          if ns.GuideUI then ns.GuideUI.Cameo("EXAMPASS") end
        end
      else
        title:SetText(L.EXAM_RESULT_TRY)
        if result then
          say("EXAMTRY")
          if r.rankUp and ns.GuideUI then ns.GuideUI.Celebrate(ns.Progress.GetRankInfo().key) end
        end
      end
      note:SetText("")
    else
      title:SetText(L[module.placementResultKey or "TRIAL_RESULT_PLACEMENT"])
      note:SetText(L.TRIAL_RESULT_NOTE)
      if result then
        ns.Compat.Sound("reward")
        say("TRIALDONE")
        if r.rankUp and ns.GuideUI then ns.GuideUI.Celebrate(ns.Progress.GetRankInfo().key) end
      end
    end
  end
  return v
end)

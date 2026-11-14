-- Lesson UI for ANY registered module: skill list ("forge"), problem screen, reward screen.
-- Rune Forger is just the default module; nothing here is math-specific.
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

local RF = {}
ns.Lessons = RF
ns.RuneForger = RF -- v0.1 name kept for slash commands / tests

RF.moduleId = "runeforger"

local function now() return GetTime and GetTime() or 0 end

local function tierName(t) return L[ns.Mastery.TIERS[t].key] end

-- Fizzwick speaks (if the guide UI is loaded).
local function say(event, ...)
  if ns.GuideUI then return ns.GuideUI.Say(event, ...) end
end

-- v0.9: a subject can swap generic Fizzwick events for its own (module.guideEvents,
-- e.g. Naturalist CORRECT -> NATCORRECT every 3rd time). Counters live per session.
RF.guideCount = {}
function RF.EventFor(module, event)
  local map = module and module.guideEvents and module.guideEvents[event]
  if not map then return event end
  local key = (module.id or "?") .. ":" .. event
  local n = (RF.guideCount[key] or 0) + 1
  RF.guideCount[key] = n
  if (n - 1) % (map.every or 1) == 0 then return map[1] end
  return event
end
local function sayFor(module, event)
  return say(RF.EventFor(module, event))
end

RF.REVIEW_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"

-- Icon for a finished round/review (the subject's own icon; reviews get a clock).
function RF.RewardIcon(summary)
  if summary and summary.mode == "review" then return RF.REVIEW_ICON end
  local module = summary and (ns.Modules.Get(summary.moduleId or "") or ns.Modules.FindNode(summary.nodeId or ""))
  return (module and module.icon) or RF.CurrentModule().icon
end

function RF.CurrentModule() return ns.Modules.Get(RF.moduleId) or ns.Modules.list[1] end

function RF.OpenModule(moduleId)
  RF.moduleId = moduleId
  H.ShowView("forge")
end

-- opts (v0.7): { size = n, flight = true } for In-Flight Lessons.
function RF.StartRound(nodeId, tier, opts)
  local module = ns.Modules.FindNode(nodeId)
  if module then RF.moduleId = module.id end
  RF.session = ns.Session.New(nodeId, tier, now(), opts and opts.size)
  if not RF.session then return end
  RF.session.flight = opts and opts.flight or nil
  H.ShowView("problem", "new")
end

function RF.StartReview(opts)
  local due = ns.Review.Due()
  if #due == 0 then
    C.Print(L.NO_REVIEWS)
    H.RefreshCurrent()
    return
  end
  RF.session = ns.Session.NewReview(due, now())
  if RF.session then
    RF.session.flight = opts and opts.flight or nil
    H.ShowView("problem", "new")
  end
end

function RF.StartTrial(kind)
  local band = ns.Progress.GetBand()
  if not band then return end
  RF.session = ns.Trial.New(RF.CurrentModule().id, band, kind, now())
  if RF.session then H.ShowView("problem", "new") end
end

function RF.QuickDrill()
  local band = ns.Progress.GetBand()
  if not band then
    H.Open()
    return
  end
  if not H.IsShown() then H.Open("home") end
  if not H.IsShown() then return end
  local module = RF.CurrentModule()
  if ns.Trial.NeedsPlacement(module.id, band) then
    H.ShowView("trial", "placement")
    return
  end
  local nodeId, tier = ns.Mastery.Recommend(band, module.id)
  if nodeId then RF.StartRound(nodeId, tier) end
end

------------------------------------------------------------------------
-- View: forge (node list for the current band)
------------------------------------------------------------------------
H.RegisterView("forge", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local title = W.Text(v, 17, "", W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", 4, -2)
  local lore = W.Text(v, 11, L.FORGE_LORE, W.ARCANE, "LEFT")
  lore:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  lore:SetWidth(540)
  local help = W.Text(v, 10, L.FORGE_TIER_HELP, W.GRAY, "LEFT")
  help:SetPoint("TOPLEFT", lore, "BOTTOMLEFT", 0, -3)
  help:SetWidth(540)

  local back = W.Button(v, L.BACK, 90, 22, function() H.ShowView("home") end)
  back:SetPoint("TOPRIGHT", 0, 0)
  local exam = W.Button(v, L.EXAM_BUTTON, 150, 22, function() H.ShowView("trial", "exam") end)
  exam:SetPoint("RIGHT", back, "LEFT", -6, 0)
  -- v0.5: a module can link to a companion module (Lore Chronicles <-> Lore Quiz for Everyone)
  local link = W.Button(v, "", 200, 22, function(self)
    if self.gameView then C.Sound("click"); H.ShowView(self.gameView, "setup") return end
    if self.moduleId then C.Sound("click"); RF.OpenModule(self.moduleId) end
  end)
  link:SetPoint("BOTTOMRIGHT", 0, 0)
  link:Hide()
  v.link = link

  local rows = {}
  for i = 1, 5 do
    local row = C.CreateFrame("Frame", nil, v, nil, true)
    row:SetSize(550, 56)
    row:SetPoint("TOPLEFT", 0, -62 - (i - 1) * 62)
    C.ApplyBackdrop(row, 0.09, 0.06, 0.16, 0.9, 0.35, 0.28, 0.55)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(36, 36)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    row.name = W.Text(row, 14, "", W.GOLD, "LEFT")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)
    row.desc = W.Text(row, 10, "", W.GRAY, "LEFT")
    row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.desc:SetWidth(220)
    row.recent = W.Text(row, 10, "", W.WHITE, "LEFT")
    row.recent:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -1)
    row.recent:SetWidth(228)
    row.tiers = {}
    for t = 3, 1, -1 do
      local b = W.Button(row, tierName(t), 78, 26, nil, 11)
      b:SetPoint("RIGHT", row, "RIGHT", -10 - (3 - t) * 84, 0)
      b:SetScript("OnClick", function(self)
        C.Sound("click")
        if self.nodeId then RF.StartRound(self.nodeId, t) end
      end)
      row.tiers[t] = b
    end
    rows[i] = row
  end

  function v:OnShowView()
    local P, M, T = ns.Progress, ns.Mastery, ns.Trial
    local bandId = P.GetBand()
    local band = P.BAND_BY_ID[bandId]
    if not band then return end
    local module = RF.CurrentModule()
    if module.unbanded then bandId, band = "everyone", ns.Modules.EVERYONE end
    if T.NeedsPlacement(module.id, bandId) then
      H.ShowView("trial", "placement")
      return
    end
    local ages = module.unbanded and L.BAND_AGES_ALL or string.format(L.BAND_AGES, band.ages)
    title:SetText(string.format(L[module.titleKey or "FORGE_TITLE"], L[band.key] .. " (" .. ages .. ")"))
    lore:SetText(L[module.loreKey or "FORGE_LORE"])
    link.gameView = nil
    if module.linkModule and ns.Modules.Get(module.linkModule) then
      link.moduleId = module.linkModule
      link:SetText(L[module.linkKey])
      link:Show()
    elseif module.game and H.HasView(module.game.view) then
      -- v0.6: Scribe's Scrolls -> Murloc Boarding Party
      link.moduleId, link.gameView = nil, module.game.view
      link:SetText("|cff66ccff" .. L[module.game.key] .. "|r")
      link:Show()
    else
      link.moduleId = nil
      link:Hide()
    end
    local examOpen, done, need = T.ExamStatus(module.id, bandId)
    if module.noTrials then
      exam:Hide()
    else
      exam:Show()
    end
    if examOpen then
      exam:Enable()
      exam:SetText("|cffffd100" .. L.EXAM_BUTTON .. "|r")
    else
      exam:Disable()
      exam:SetText(string.format(L.EXAM_LOCKED, done, need))
    end
    local nodes = ns.Modules.Nodes(module.id, bandId)
    local nowT = ns.Util.Now()
    for i, row in ipairs(rows) do
      local nodeId = nodes[i]
      if nodeId then
        row:Show()
        local _, node = ns.Modules.FindNode(nodeId)
        row.icon:SetTexture(node.icon or module.icon)
        row.name:SetText(L[node.key])
        row.desc:SetText(L[node.descKey])
        local cur = M.CurrentTier(nodeId)
        local rec = P.GetTierRec(nodeId, cur)
        local rc, rt = M.RecentCorrect(rec)
        local status
        if M.MasteredCount(nodeId) == 3 then
          status = "|cffffd100" .. L.FORGE_MASTERED .. "|r"
        else
          status = tierName(cur) .. " - " .. string.format(L.FORGE_RECENT, rc, rt)
        end
        -- one marker at most (fading beats review due) so the line fits beside the tier buttons
        local marker
        for t = 1, 3 do
          local tr = P.GetTierRec(nodeId, t)
          if tr.fading then
            marker = "|cffff8800" .. tierName(t) .. " " .. L.FADING .. "|r"
            break
          elseif not marker and ns.Review.IsDue(tr, nowT) then
            marker = "|cff66ccff" .. tierName(t) .. " " .. L.REVIEW_DUE .. "|r"
          end
        end
        if marker then status = status .. "  " .. marker end
        row.recent:SetText(status)
        local mc = M.MasteredCount(nodeId)
        if row.icon.SetDesaturated then row.icon:SetDesaturated(mc == 0) end
        for t = 1, 3 do
          local b = row.tiers[t]
          b.nodeId = nodeId
          local tr = P.GetTierRec(nodeId, t)
          local unlocked = M.IsTierUnlocked(nodeId, t)
          if unlocked then b:Enable() else b:Disable() end
          local label = tierName(t)
          if tr.mastered then label = "|cffffd100" .. label .. " *|r" end
          b:SetText(label)
        end
      else
        row:Hide()
      end
    end
  end
  return v
end)

------------------------------------------------------------------------
-- View: problem screen
------------------------------------------------------------------------
local PRAISE = { "PRAISE_1", "PRAISE_2", "PRAISE_3", "PRAISE_4", "PRAISE_5" }

H.RegisterView("problem", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  v.token = 0

  local header = W.Text(v, 12, "", W.GOLD, "LEFT")
  header:SetPoint("TOPLEFT", 4, -2)
  header:SetWidth(420)
  local diff = W.Text(v, 10, "", W.GRAY, "LEFT")
  diff:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)

  local exit = W.Button(v, L.EXIT_ROUND, 110, 22, function()
    RF.session = nil
    C.Print(L.PROGRESS_SAVED)
    H.ShowView("forge")
  end)
  exit:SetPoint("TOPRIGHT", 0, 0)

  local charge = W.Bar(v, 410, 22, W.ARCANE)
  charge:SetPoint("TOPLEFT", 0, -36)
  local combo = W.Text(v, 13, "", W.AMBER, "RIGHT")
  combo:SetPoint("LEFT", charge, "RIGHT", 6, 0)
  combo:SetWidth(134)
  -- combo meter glow: a warm halo around the charge bar while a streak is going
  local comboGlow = v:CreateTexture(nil, "BACKGROUND")
  comboGlow:SetPoint("TOPLEFT", charge, "TOPLEFT", -5, 5)
  comboGlow:SetPoint("BOTTOMRIGHT", charge, "BOTTOMRIGHT", 5, -5)
  C.SetColor(comboGlow, 1, 0.65, 0.15, 1)
  if comboGlow.SetBlendMode then comboGlow:SetBlendMode("ADD") end
  comboGlow:Hide()
  v.comboGlow = comboGlow
  local function setCombo(streak, overcharge)
    if overcharge then
      combo:SetText(string.format(L.OVERCHARGE, streak))
      C.SetColor(comboGlow, 1, 0.85, 0.2, 1)
      W.Pulse(comboGlow, true, 0.8)
    elseif streak and streak >= ns.Session.COMBO_AT then
      combo:SetText(string.format(L.COMBO, streak))
      C.SetColor(comboGlow, 1, 0.65, 0.15, 1)
      W.Pulse(comboGlow, true, 0.5)
    else
      combo:SetText("")
      W.Pulse(comboGlow, false)
    end
  end

  -- The "anvil": problem card that glows on correct answers.
  local card = C.CreateFrame("Frame", nil, v, nil, true)
  card:SetPoint("TOPLEFT", 0, -66)
  card:SetPoint("TOPRIGHT", 0, -66)
  card:SetHeight(160)
  C.ApplyBackdrop(card, 0.07, 0.05, 0.13, 0.95, 0.55, 0.42, 0.95)
  v.card = card

  local icons = {}
  for i = 1, 20 do
    local t = card:CreateTexture(nil, "ARTWORK")
    t:SetSize(26, 26)
    local col, row = (i - 1) % 10, math.floor((i - 1) / 10)
    t:SetPoint("TOPLEFT", card, "TOP", -150 + col * 30, -10 - row * 30)
    t:Hide()
    icons[i] = t
  end

  local qtext = W.Text(card, 20, "", W.WHITE, "CENTER")
  qtext:SetWidth(520)
  -- v0.11: Gnomish Engineering command grid (left side of the card)
  local grid = W.Grid(card, 6, 22)
  grid:SetPoint("LEFT", card, "LEFT", 12, 0)
  v.grid = grid

  -- Answer area
  local answerArea = CreateFrame("Frame", nil, v)
  answerArea:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -8)
  answerArea:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, -8)
  answerArea:SetHeight(76)

  local choiceButtons = {}
  for i = 1, 4 do
    local b = W.Button(answerArea, "", 120, 52, nil, 22)
    b:SetScript("OnClick", function(self) v:Answer(self.value, self) end)
    b:Hide()
    choiceButtons[i] = b
  end

  local input = W.EditBox(answerArea, 150, 38, 22)
  input:SetPoint("CENTER", answerArea, "CENTER", -50, 0)
  input:SetMaxLetters(160)
  input:SetScript("OnEnterPressed", function(self) v:Answer(self:GetText()) end)
  local submit = W.Button(answerArea, L.SUBMIT, 100, 36, function() v:Answer(input:GetText()) end, 14)
  submit:SetPoint("LEFT", input, "RIGHT", 12, 0)
  local inputHelp = W.Text(answerArea, 10, L.TYPE_ANSWER, W.GRAY, "CENTER")
  inputHelp:SetPoint("TOP", input, "BOTTOM", 25, -2)

  local feedback = W.Text(v, 13, "", W.WHITE, "CENTER")
  feedback:SetPoint("TOPLEFT", answerArea, "BOTTOMLEFT", 10, -6)
  feedback:SetPoint("TOPRIGHT", answerArea, "BOTTOMRIGHT", -10, -6)
  local banner = W.Text(v, 14, "", W.GOLD, "CENTER")
  banner:SetPoint("TOP", feedback, "BOTTOM", 0, -4)
  banner:SetWidth(540)

  local hintBtn = W.Button(v, L.HINT, 80, 24, function()
    local p = RF.session and RF.session.problem
    if p then
      feedback:SetTextColor(W.ARCANE[1], W.ARCANE[2], W.ARCANE[3])
      feedback:SetText(p.hint or "")
      if ns.GuideUI then ns.GuideUI.Parrot(p.hint or "") end
    end
  end)
  hintBtn:SetPoint("BOTTOMLEFT", 0, 0)
  local nextBtn = W.Button(v, L.NEXT, 110, 26, function() v:Advance() end, 13)
  nextBtn:SetPoint("BOTTOMRIGHT", 0, 0)
  nextBtn:Hide()

  local function setFeedback(text, color)
    local c = color or W.WHITE
    feedback:SetTextColor(c[1], c[2], c[3])
    feedback:SetText(text or "")
  end

  function v:Render()
    local s = RF.session
    local p = s and s.problem
    if not p then return end
    header:SetText(s:Header())
    diff:SetText(string.format(L.DIFFICULTY, string.rep("|cffffd100*|r", p.level) .. string.rep("|cff555555*|r", 5 - p.level)))
    charge:SetProgress(s:Charge())
    if s.noHints then hintBtn:Hide() else hintBtn:Show() end
    setCombo(not s.isTrial and s.streak or 0, false)

    -- icons for counting problems
    local count = p.icons and p.icons.count or 0
    for i, t in ipairs(icons) do
      if i <= count then
        t:SetTexture(p.icons.texture)
        t:Show()
      else
        t:Hide()
      end
    end
    qtext:ClearAllPoints()
    qtext:SetWidth(520)
    qtext:SetJustifyH(p.code and "LEFT" or "CENTER")
    if p.grid then
      grid:Draw(p.grid)
      local gw = grid:GetWidth()
      qtext:SetWidth(520 - gw - 10)
      qtext:SetPoint("LEFT", card, "LEFT", 12 + gw + 16, 0)
      local len = #(p.text or "")
      W.SetFontSize(qtext, len > 140 and 12 or (len > 90 and 14 or 16))
    else
      grid:Hide()
    end
    if count > 0 and not p.grid then
      qtext:SetPoint("TOP", card, "TOP", 0, -10 - (count > 10 and 64 or 34) - 6)
      W.SetFontSize(qtext, 18)
    elseif not p.grid then
      qtext:SetPoint("CENTER", card, "CENTER", 0, 0)
      local len = #(p.text or "")
      local size = (s.node.band == "initiate") and 22 or 19
      if len > 320 then size = 12 elseif len > 170 then size = 13 elseif len > 110 then size = 15 elseif len > 60 then size = math.min(size, 17) end
      if p.code then
        local _, nl = (p.text or ""):gsub("\n", "")
        size = math.min(size, nl >= 5 and 13 or 15)
      end
      W.SetFontSize(qtext, size)
    end
    qtext:SetText(p.text)

    -- answers
    for _, b in ipairs(choiceButtons) do b:Hide() end
    input:Hide(); submit:Hide(); inputHelp:Hide()
    if p.mode == "choice" then
      local n = #p.choices
      local longest = 0
      for _, val in ipairs(p.choices) do longest = math.max(longest, #tostring(val)) end
      if longest > 12 then
        -- long answers (definitions): two columns of wide buttons
        for i, val in ipairs(p.choices) do
          local b = choiceButtons[i]
          local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
          b:SetSize(262, 34)
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", answerArea, "TOPLEFT", 8 + col * 270, -2 - row * 38)
          b.value = val
          b:SetText(tostring(val))
          -- v0.5: sentence answers (Lore Chronicles) wrap onto two lines
          W.SetButtonFontSize(b, longest > 44 and 10 or (longest > 30 and 11 or 13))
          W.ButtonWrap(b, longest > 30 and 250 or nil)
          b:Enable()
          b:Show()
        end
      else
        local w = (n <= 3) and 150 or 120
        local gap = 14
        local total = n * w + (n - 1) * gap
        for i, val in ipairs(p.choices) do
          local b = choiceButtons[i]
          b:SetSize(w, 52)
          b:ClearAllPoints()
          b:SetPoint("LEFT", answerArea, "CENTER", -total / 2 + (i - 1) * (w + gap), 0)
          b.value = val
          b:SetText(type(val) == "number" and ns.Util.Commas(val) or tostring(val))
          W.SetButtonFontSize(b, 22)
          W.ButtonWrap(b, nil)
          b:Enable()
          b:Show()
        end
      end
    else
      -- "input" = numbers, "text" = a word, "typing" = copy a line exactly
      local width = (p.mode == "typing" or p.wide) and 420 or ((p.mode == "text") and 240 or 150)
      input:SetWidth(width)
      input:ClearAllPoints()
      input:SetPoint("CENTER", answerArea, "CENTER", -56, 6)
      inputHelp:SetText(p.mode == "typing" and L.TYPE_TYPING or (p.rubric and L.TYPE_SENTENCE) or (p.build and L.TYPE_BUILD)
        or (p.mode == "text" and L.TYPE_TEXT or L.TYPE_ANSWER))
      input:SetText("")
      input:Show(); submit:Show(); inputHelp:Show()
      input:Enable(); submit:Enable()
      input:SetFocus()
    end
    nextBtn:Hide()
    banner:SetText("")
    setFeedback("")
    self.locked = false
    if ns.GuideUI then ns.GuideUI.ProblemShown(s.moduleId, not s.noHints) end
    -- v0.14: Fizzwick introduces Thrall and Magni cameo stories (not during trials or exams)
    if p.cameo and not p.cameoShown and ns.GuideUI and not s.isTrial and ns.Lore and ns.Lore.CAMEOS[p.cameo] then
      p.cameoShown = true
      ns.GuideUI.Say("LORECAMEO", L[ns.Lore.CAMEOS[p.cameo]])
    end
  end

  function v:Advance()
    self.token = self.token + 1
    local s = RF.session
    if not s then
      H.ShowView("forge")
      return
    end
    local p = s:Next(now())
    if not p then
      local summary = s:Finish()
      if summary and s.flight then summary.flight = true end
      RF.session = nil
      H.ShowView(s.resultView or "reward", summary)
      return
    end
    self:Render()
  end

  function v:Lock()
    self.locked = true
    for _, b in ipairs(choiceButtons) do b:Disable() end
    input:ClearFocus()
    input:Disable(); submit:Disable()
  end

  function v:Answer(value, button)
    local s = RF.session
    if self.locked or not s or not s.problem then return end
    local mode = s.problem.mode
    if mode == "input" and ns.Util.ParseNumber(value) == nil then
      setFeedback(L.TYPE_ANSWER, W.GRAY)
      input:SetFocus()
      return
    end
    if (mode == "text" or mode == "typing") and not tostring(value or ""):match("%S") then
      setFeedback(mode == "typing" and L.TYPE_TYPING or L.TYPE_TEXT, W.GRAY)
      input:SetFocus()
      return
    end
    local r = s:Submit(value, now())
    if not r then return end
    charge:SetProgress(s:Charge())

    local typingText
    if r.typing and r.typing.rubric then
      -- v0.5: written answers report how many key ideas were found
      typingText = string.format(L.LORE_RUBRIC, r.typing.matched or 0, r.typing.need or 0)
    elseif r.typing and r.typing.wpm then
      typingText = string.format(L.TYPING_RESULT, math.floor(r.typing.accuracy * 100 + 0.5), r.typing.wpm)
      if not r.correct then typingText = typingText .. " " .. string.format(L.TYPING_NEED, math.floor(r.typing.need * 100 + 0.5)) end
      if r.newBestWpm then typingText = typingText .. "  |cffffd100" .. string.format(L.TYPING_BEST, r.typing.wpm) .. "|r" end
    end
    local module = ns.Modules.Get(s.moduleId) or RF.CurrentModule()

    if r.trial then
      if r.correct then
        W.Flash(card, W.GREEN, 0.6)
        C.Sound("correct")
        sayFor(module, "CORRECT")
        setFeedback(L[module.trialRightKey or "TRIAL_RIGHT"] .. (typingText and ("\n" .. typingText) or ""), W.GREEN)
        self:Lock()
        local token = self.token
        C.After(1.0, function()
          if v.token == token and v:IsShown() and RF.session == s then v:Advance() end
        end)
      else
        C.Sound("wrong")
        sayFor(module, "WRONG")
        setFeedback(string.format(L[module.trialWrongKey or "TRIAL_WRONG"], r.answerText or "?") .. (typingText and ("\n" .. typingText) or ""), W.WHITE)
        self:Lock()
        nextBtn:SetText(L.NEXT)
        nextBtn:Show()
      end
      return
    end

    if r.correct then
      W.Flash(card, r.overcharge and W.GOLD or W.GREEN, 0.7)
      W.Sparks(card, r.overcharge and 14 or 8, r.overcharge and W.GOLD or W.ARCANE)
      C.Sound(r.overcharge and "overcharge" or (r.combo and "combo" or "correct"))
      if r.overcharge or r.combo then say(r.overcharge and "OVERCHARGE" or "COMBO") else sayFor(module, "CORRECT") end
      if r.tries > 1 then
        setFeedback(L.RETRY_PRAISE, W.GREEN)
      else
        setFeedback(L[PRAISE[math.random(1, #PRAISE)]], W.GREEN)
      end
      if typingText then banner:SetText(typingText) end
      if r.newBestWpm and ns.GuideUI then ns.GuideUI.Pose("surprised") end -- v0.5.1: new personal best
      setCombo(r.combo or r.streak, r.overcharge)
      if r.shards > 0 then W.Float(card, string.format(L.SHARDS_FLOAT, r.shards), W.GOLD, 0, 50) end
      self:Lock()
      local token = self.token
      C.After(r.mastered and 2.2 or 1.1, function()
        if v.token == token and v:IsShown() and RF.session == s then v:Advance() end
      end)
    elseif r.retry then
      W.Flash(card, W.AMBER, 0.5)
      C.Sound("wrong")
      sayFor(module, "WRONG")
      setCombo(0, false)
      setFeedback(string.format(L.RETRY_PREFIX, r.hint or "") .. (typingText and ("\n" .. typingText) or ""), W.AMBER)
      if button then button:Disable() end
      if s.problem.mode ~= "choice" then
        if not s.problem.wide then input:SetText("") end -- sentences stay so they can be fixed
        input:SetFocus()
      end
    else
      C.Sound("wrong")
      sayFor(module, "WRONG")
      if ns.GuideUI then ns.GuideUI.Pose("teaching") end -- v0.5.1: worked example
      setCombo(0, false)
      setFeedback(string.format(L.EXPLAIN_PREFIX, r.answerText or "?", r.explain or ""), W.WHITE)
      if typingText then banner:SetText(typingText) end
      self:Lock()
      -- highlight the right answer on the buttons
      for _, b in ipairs(choiceButtons) do
        if b:IsShown() and tostring(b.value) == tostring(s.problem.answer) then
          b:SetText("|cff33ff66" .. (type(b.value) == "number" and ns.Util.Commas(b.value) or tostring(b.value)) .. "|r")
        end
      end
      nextBtn:SetText(L.NEXT)
      nextBtn:Show()
    end

    if r.mastered then
      C.Sound("reward")
      local text
      if (r.minutes or 0) > 0 then
        text = string.format(L.MASTERED_BANNER, tierName(s.tier), r.minutes)
      else
        text = string.format(L.MASTERED_BANNER_NOMIN, tierName(s.tier))
      end
      if r.specimen then
        -- v0.9 Field Journal: a new specimen page for this mastered tier
        local book = ns.Journal.Book(r.specimen.moduleId) or {}
        C.Sound(book.sound or "specimen")
        say(book.newEvent or "NATSPECIMEN")
        text = text .. "\n|cff66ddaa" .. string.format(ns.Journal.Str(r.specimen.moduleId, "NEW"), r.specimen.name) .. "|r"
      else
        say("MASTERED")
      end
      banner:SetText(text)
    end
    if r.rankUp then
      local info = ns.Progress.GetRankInfo()
      C.Print(string.format(L.RANK_UP, L[info.key]))
    end
  end

  function v:OnShowView(mode)
    if not RF.session then
      H.ShowView("forge")
      return
    end
    if mode == "new" or not RF.session.problem then
      local s = RF.session
      if s.isTrial then
        say(s.kind == "exam" and "EXAMSTART" or "TRIALSTART")
      elseif s.mode == "review" then
        say("REVIEW")
      else
        sayFor(s.module, "ROUNDSTART")
      end
      local module = ns.Modules.Get(s.moduleId or "") or RF.CurrentModule()
      C.Sound(module.startSound or "forge")
      self:Advance()
    else
      -- resuming (after combat or reopening): redraw the pending problem
      self:Render()
      if RF.session.problemDone then
        self:Lock()
        nextBtn:Show()
      end
    end
  end

  function v:OnHubHidden()
    -- Cancel a pending auto-advance; on reopen the finished problem shows a Next button.
    self.token = self.token + 1
    input:ClearFocus()
  end

  return v
end)

------------------------------------------------------------------------
-- View: reward screen
------------------------------------------------------------------------
H.RegisterView("reward", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local glyph = W.FramedIcon(v, 60, "Interface\\Icons\\INV_Misc_Rune_01")
  glyph:SetPoint("TOP", 0, -16)
  v.glyph = glyph
  local title = W.Text(v, 22, "", W.GOLD, "CENTER")
  title:SetPoint("TOP", glyph, "BOTTOM", 0, -14)
  local lines = {}
  local prev = title
  for i = 1, 6 do
    local fs = W.Text(v, 13, "", W.WHITE, "CENTER")
    fs:SetPoint("TOP", prev, "BOTTOM", 0, i == 1 and -12 or -6)
    fs:SetWidth(520)
    lines[i] = fs
    prev = fs
  end
  local rankBar = W.Bar(v, 300, 22, W.ARCANE)
  rankBar:SetPoint("TOP", prev, "BOTTOM", 0, -10)
  -- v0.5.1: full-figure Fizzwick (posed art) at the left; hidden without art
  if ns.GuideUI then
    v.hero = ns.GuideUI.Hero(v, 150)
    v.hero:SetPoint("TOPLEFT", -6, -30)
  end

  local again = W.Button(v, L.FORGE_AGAIN, 140, 30, function()
    local sm = v.summary
    if not sm then return end
    if sm.mode == "review" then
      for _, rv in ipairs(sm.reviews or {}) do
        if rv.fading then RF.StartRound(rv.nodeId, rv.tier) return end
      end
      RF.StartReview()
    else
      RF.StartRound(sm.nodeId, ns.Mastery.CurrentTier(sm.nodeId))
    end
  end, 13)
  again:SetPoint("BOTTOM", -150, 6)
  local backForge = W.Button(v, L.BACK_TO_FORGE, 140, 30, function() H.ShowView("forge") end, 13)
  backForge:SetPoint("BOTTOM", 0, 6)
  local hub = W.Button(v, L.HUB, 140, 30, function() H.ShowView("home") end, 13)
  hub:SetPoint("BOTTOM", 150, 6)
  -- v0.7 In-Flight Lessons: another short round while still in the air
  local another = W.Button(v, L.FLIGHT_ANOTHER, 170, 26, function()
    if ns.FlightUI then ns.FlightUI.AnotherRound() end
  end, 12)
  another:SetPoint("BOTTOM", backForge, "TOP", 0, 8)
  another:Hide()
  v.another = another
  -- v0.9: jump to the Field Journal after collecting a specimen
  local journalBtn = W.Button(v, L.JOURNAL_OPEN, 140, 26, function()
    local sp = v.summary and v.summary.specimens
    H.ShowView("journal", sp and sp[1] and { nodeId = sp[1].nodeId, tier = sp[1].tier, moduleId = sp[1].moduleId } or nil)
  end, 12)
  journalBtn:SetPoint("BOTTOM", hub, "TOP", 0, 8)
  journalBtn:Hide()
  v.journalBtn = journalBtn
  function v:UpdateFlight()
    local sm = self.summary
    if sm and sm.flight and ns.FlightUI and ns.FlightUI.CanOfferAnother() then another:Show() else another:Hide() end
  end

  function v:OnShowView(summary)
    if summary then self.summary = summary end
    local s = self.summary
    if not s then
      H.ShowView("forge")
      return
    end
    local M = ns.Mastery
    glyph:SetTexture(RF.RewardIcon(s))
    if v.hero then
      local pose = "encouraging"
      if s.masteredNow then pose = "proud"
      elseif s.mode == "review" then pose = "talking"
      elseif (s.total or 0) > 0 and s.firstCorrect == s.total then pose = "excited" end
      v.heroPose = pose
      ns.GuideUI.ShowHero(v.hero, pose)
    end
    if glyph.SetDesaturated then glyph:SetDesaturated(false) end
    v.revealMode = W.Reveal(glyph, 0.7)
    if s.mode == "review" then
      title:SetText(L.REVIEW_TITLE)
      local anyFading = false
      for i = 1, 3 do
        local rv = s.reviews and s.reviews[i]
        if rv then
          local _, node = ns.Modules.FindNode(rv.nodeId)
          local key = rv.passed and (rv.solid and "REVIEW_SOLID" or "REVIEW_PASSED") or "REVIEW_FADING"
          local color = rv.passed and "|cff4dff66" or "|cffff8800"
          lines[i]:SetText(color .. string.format(L[key], L[node.key], tierName(rv.tier), rv.correct, rv.total) .. "|r")
          if rv.fading then anyFading = true end
        else
          lines[i]:SetText("")
        end
      end
      W.CountUp(lines[4], s.shards, "|cffffd100" .. L.REWARD_SHARDS .. "|r")
      lines[5]:SetText(s.masteredNow and ("|cffffd100" .. string.format(L.REWARD_MASTERED, tierName(s.tier)) .. "|r") or "")
      local due = #ns.Review.Due()
      again:SetText(anyFading and L.PRACTICE or L.REVIEW_RUNES)
      if anyFading or due > 0 then again:Show() else again:Hide() end
    else
      again:SetText(L.FORGE_AGAIN)
      again:Show()
      title:SetText(string.format(L.REWARD_TITLE, tierName(s.tier)))
      lines[1]:SetText(string.format(L.REWARD_FIRST, s.firstCorrect, s.total))
      lines[2]:SetText(string.format(L.REWARD_COMBO, s.bestStreak))
      W.CountUp(lines[3], s.shards, "|cffffd100" .. L.REWARD_SHARDS .. "|r")
      lines[4]:SetText("|cff4dff66" .. string.format(L.REWARD_MINUTES, s.minutes, s.minutesToday, s.minutesCap) .. "|r")
      if s.masteredNow then
        local msg = string.format(L.REWARD_MASTERED, tierName(s.tier))
        if s.tier < 3 then msg = msg .. " " .. string.format(L.REWARD_UNLOCKED, tierName(s.tier + 1)) end
        lines[5]:SetText("|cffffd100" .. msg .. "|r")
      elseif s.tierMastered then
        lines[5]:SetText(string.format(L.REWARD_MASTERED, tierName(s.tier)))
      elseif s.recentTotal < M.WINDOW then
        lines[5]:SetText(string.format(L.REWARD_NEED_MORE, s.recentTotal, M.WINDOW))
      else
        lines[5]:SetText(string.format(L.REWARD_PROGRESS, s.recentCorrect, s.recentTotal, M.Required(), M.WINDOW))
      end
      if s.fadingCleared then
        local _, node = ns.Modules.FindNode(s.nodeId)
        lines[5]:SetText("|cff4dff66" .. string.format(L.FADING_CLEARED, L[node.key]) .. "|r")
      end
    end
    local info = ns.Progress.GetRankInfo()
    lines[6]:SetText(string.format(L.RANK_LINE, L[info.key]) .. (s.rankUp and ("  |cffffd100" .. string.format(L.RANK_UP, L[info.key]) .. "|r") or ""))
    if info.nextKey then
      rankBar:SetProgress(info.pct, string.format(L.RANK_PROGRESS, info.shards, info.nextMin, L[info.nextKey]))
    else
      rankBar:SetProgress(1, L.RANK_MAX)
    end
    if s.masteredNow or s.rankUp then
      C.Sound("reward")
      W.Sparks(v, 16, W.GOLD)
    end
    self:UpdateFlight()
    local specimens = s.specimens or {}
    if #specimens > 0 then
      local names = {}
      for _, sp in ipairs(specimens) do names[#names + 1] = sp.name end
      local cur = lines[5]:GetText() or ""
      local mid = specimens[1].moduleId
      lines[5]:SetText(cur .. (cur ~= "" and "\n" or "") .. "|cff66ddaa" .. string.format(ns.Journal.Str(mid, "NEW"), table.concat(names, ", ")) .. "|r")
      journalBtn:SetText(ns.Journal.Str(mid, "OPEN"))
      journalBtn:Show()
    else
      journalBtn:Hide()
    end
    -- Fizzwick + celebrations (only the first time this summary is shown)
    if summary and s.flight and not (s.rankUp or s.masteredNow) then
      say((ns.FlightUI and ns.FlightUI.CanOfferAnother()) and "FLIGHTDONE" or "FLIGHTLAND")
    elseif summary then
      if s.rankUp and ns.GuideUI then
        ns.GuideUI.Celebrate(info.key)
      elseif s.masteredNow then
        local book = #specimens > 0 and ns.Journal.Book(specimens[1].moduleId)
        say(book and (book.newEvent or "NATSPECIMEN") or "MASTERED")
        if ns.GuideUI and ns.Guide.IsMilestone(ns.Progress.TotalMastered()) then ns.GuideUI.Cameo("MILESTONE") end
      elseif s.mode == "review" then
        local fading = false
        for _, rv in ipairs(s.reviews or {}) do if rv.fading then fading = true end end
        say(fading and "FADING" or "CORRECT")
      end
    end
  end
  return v
end)

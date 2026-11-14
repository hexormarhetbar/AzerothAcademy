-- Parent Panel: PIN gate, per-node stats, minute rules, band, reset, export.
-- The PIN is a soft lock for young kids, NOT security (SavedVariables are plain files).
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

H.RegisterView("parent", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  v.unlocked = false
  v.hideGuide = true -- full height: the Parent Panel needs the room

  local title = W.Text(v, 17, L.PARENT_PANEL, W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", 4, -2)
  local back = W.Button(v, L.BACK, 90, 22, function()
    v.unlocked = false
    H.ShowView("home")
  end)
  back:SetPoint("TOPRIGHT", 0, 0)

  ----------------------------------------------------------------------
  -- PIN gate
  ----------------------------------------------------------------------
  local gate = CreateFrame("Frame", nil, v)
  gate:SetPoint("TOPLEFT", 0, -40)
  gate:SetPoint("BOTTOMRIGHT", 0, 0)
  local gateTitle = W.Text(gate, 15, "", W.WHITE, "CENTER")
  gateTitle:SetPoint("TOP", 0, -40)
  local pin1 = W.EditBox(gate, 140, 32, 20)
  pin1:SetPoint("TOP", gateTitle, "BOTTOM", 0, -16)
  local pin2Label = W.Text(gate, 12, L.PIN_CONFIRM, W.GRAY, "CENTER")
  pin2Label:SetPoint("TOP", pin1, "BOTTOM", 0, -10)
  local pin2 = W.EditBox(gate, 140, 32, 20)
  pin2:SetPoint("TOP", pin2Label, "BOTTOM", 0, -6)
  for _, e in ipairs({ pin1, pin2 }) do
    if e.SetNumeric then e:SetNumeric(true) end
    if e.SetPassword then e:SetPassword(true) end
    e:SetMaxLetters(6)
  end
  local gateBtn = W.Button(gate, "", 140, 28, nil, 13)
  gateBtn:SetPoint("TOP", pin2, "BOTTOM", 0, -16)
  local gateMsg = W.Text(gate, 12, "", W.AMBER, "CENTER")
  gateMsg:SetPoint("TOP", gateBtn, "BOTTOM", 0, -10)
  gateMsg:SetWidth(480)
  local note = W.Text(gate, 10, L.PIN_NOTE, W.GRAY, "CENTER")
  note:SetPoint("BOTTOM", 0, 10)
  note:SetWidth(500)

  ----------------------------------------------------------------------
  -- Dashboard
  ----------------------------------------------------------------------
  local dash = CreateFrame("Frame", nil, v)
  dash:SetPoint("TOPLEFT", 0, -30)
  dash:SetPoint("BOTTOMRIGHT", 0, 0)

  local statsBox = C.CreateFrame("Frame", nil, dash, nil, true)
  statsBox:SetPoint("TOPLEFT", 0, 0)
  statsBox:SetPoint("TOPRIGHT", 0, 0)
  statsBox:SetHeight(170)
  C.ApplyBackdrop(statsBox, 0.07, 0.05, 0.12, 0.9, 0.35, 0.28, 0.55)
  local statsTitle = W.Text(statsBox, 12, "", W.GOLD, "LEFT")
  statsTitle:SetPoint("TOPLEFT", 10, -8)
  -- Subject picker: cycles through every registered module.
  local subjectBtn = W.Button(statsBox, "", 190, 18, function()
    local list = ns.Modules.list
    local cur = v:SubjectId()
    local nextIdx = 1
    for i, m in ipairs(list) do if m.id == cur then nextIdx = i % #list + 1 end end
    v.moduleId = list[nextIdx].id
    v:Refresh()
  end, 10)
  subjectBtn:SetPoint("TOPRIGHT", -8, -5)
  local statsHead = W.Text(statsBox, 10, "", W.GRAY, "LEFT")
  statsHead:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -4)
  statsHead:SetText(L.PARENT_STATS_HEADER)
  local statRows = {}
  for i = 1, 5 do
    local row = {}
    local y = -42 - (i - 1) * 22
    row.name = W.Text(statsBox, 11, "", W.WHITE, "LEFT")
    row.name:SetPoint("TOPLEFT", 10, y)
    row.name:SetWidth(120)
    row.tiers = {}
    for t = 1, 3 do
      local fs = W.Text(statsBox, 10, "", W.WHITE, "LEFT")
      fs:SetPoint("TOPLEFT", 132 + (t - 1) * 100, y)
      fs:SetWidth(98)
      row.tiers[t] = fs
    end
    row.time = W.Text(statsBox, 10, "", W.GRAY, "LEFT")
    row.time:SetPoint("TOPLEFT", 432, y)
    -- Parent override of where this skill starts (cycles Spark -> Rune -> Glyph).
    row.start = W.Button(statsBox, "", 66, 18, function(self)
      if not self.nodeId then return end
      local nextTier = ns.Trial.StartTier(self.nodeId) % 3 + 1
      ns.Trial.SetOverride(self.nodeId, nextTier)
      v:Refresh()
    end, 10)
    row.start:SetPoint("TOPLEFT", 476, y + 3)
    statRows[i] = row
  end
  local totals = W.Text(statsBox, 10, "", W.GRAY, "LEFT")
  totals:SetPoint("BOTTOMLEFT", 10, 8)
  totals:SetWidth(530)

  -- Minute rules
  local minLabel = W.Text(dash, 11, L.PARENT_MIN_PER, W.WHITE, "LEFT")
  minLabel:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 4, -14)
  local minBox = W.EditBox(dash, 50, 24, 13)
  minBox:SetPoint("LEFT", minLabel, "LEFT", 170, 0)
  local capLabel = W.Text(dash, 11, L.PARENT_CAP, W.WHITE, "LEFT")
  capLabel:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", 0, -16)
  local capBox = W.EditBox(dash, 50, 24, 13)
  capBox:SetPoint("LEFT", capLabel, "LEFT", 170, 0)
  for _, e in ipairs({ minBox, capBox }) do
    if e.SetNumeric then e:SetNumeric(true) end
    e:SetMaxLetters(3)
  end
  local dashMsg = W.Text(dash, 11, "", W.GREEN, "LEFT")
  local saveRules = W.Button(dash, L.PARENT_SAVE, 70, 22, function()
    if ns.Progress.SetMinuteRules(minBox:GetText(), capBox:GetText()) then
      dashMsg:SetTextColor(W.GREEN[1], W.GREEN[2], W.GREEN[3])
      dashMsg:SetText(L.SAVED)
    else
      dashMsg:SetTextColor(W.AMBER[1], W.AMBER[2], W.AMBER[3])
      dashMsg:SetText(L.PARENT_SETTINGS_BAD)
    end
    minBox:ClearFocus(); capBox:ClearFocus()
  end)
  saveRules:SetPoint("LEFT", capBox, "RIGHT", 10, 0)

  -- Age band
  local bandLabel = W.Text(dash, 11, L.PARENT_BAND, W.WHITE, "LEFT")
  bandLabel:SetPoint("TOPLEFT", capLabel, "BOTTOMLEFT", 0, -18)
  local bandButtons = {}
  for i, band in ipairs(ns.Progress.BANDS) do
    local b = W.Button(dash, L[band.key], 90, 22, function()
      ns.Progress.SetBand(band.id)
      v:Refresh()
    end, 11)
    b:SetPoint("LEFT", bandLabel, "LEFT", 70 + (i - 1) * 96, 0)
    b.bandId = band.id
    bandButtons[i] = b
  end

  -- Toggles: a 2-column grid (learning, then sound / motion / cameos)
  local function settings() return ns.Progress.account.settings end
  local function sound() return settings().sound end
  local SE = ns.SoundEvents
  local toggles = {}
  local function toggle(col, row, fn)
    local b = W.Button(dash, "", 184, 22, function()
      fn()
      v:Refresh()
    end, 10)
    b:SetPoint("TOPLEFT", bandLabel, "BOTTOMLEFT", -4 + col * 190, -14 - row * 27)
    toggles[#toggles + 1] = b
    return b
  end
  local unlockBtn = toggle(0, 0, function() settings().unlockAllTiers = not settings().unlockAllTiers end)
  local reviewsBtn = toggle(1, 0, function() settings().reviews = not settings().reviews end)
  local soundBtn = toggle(0, 1, function()
    sound().enabled = not sound().enabled
    C.Sound("correct")
  end)
  local channelBtn = toggle(1, 1, function()
    sound().channel = SE.Cycle(SE.CHANNELS, SE.Channel(sound()))
    C.Sound("correct")
  end)
  local levelBtn = toggle(0, 2, function()
    sound().level = SE.Cycle(SE.LEVELS, sound().level)
    C.Sound("correct")
  end)
  local customBtn = toggle(1, 2, function()
    sound().custom = sound().custom == false
    C.missingSounds = {} -- re-check custom files
    C.Sound("correct")
  end)
  local motionBtn = toggle(0, 3, function() settings().reducedMotion = not settings().reducedMotion end)
  local cameoBtn = toggle(1, 3, function() settings().cameos = settings().cameos == false end)
  local minimapBtn = toggle(0, 4, function()
    if ns.MinimapButton then
      ns.MinimapButton.Create()
      ns.MinimapButton.Toggle()
    end
  end)
  v.minimapBtn = minimapBtn
  -- v0.7: In-Flight Lessons mode (Off -> Ask first -> Auto-open)
  local flightBtn = toggle(1, 4, function()
    if ns.FlightUI then ns.FlightUI.CycleMode() end
  end)
  v.flightBtn = flightBtn
  -- v0.8: Fizzwick's voice on/off
  local voiceBtn = toggle(0, 5, function()
    local st = settings()
    if type(st.voice) ~= "table" then st.voice = {} end
    st.voice.enabled = st.voice.enabled == false
  end)
  v.voiceBtn = voiceBtn
  -- v0.10: Duel of Wits safety settings live on their own overlay
  local duelBtn = toggle(1, 5, function() v:ShowDuelSettings() end)
  duelBtn:SetText(L.PP_DUEL_SETTINGS)
  v.duelBtn = duelBtn
  v.toggles = toggles

  dashMsg:SetPoint("TOPLEFT", bandLabel, "BOTTOMLEFT", 0, -14 - 6 * 27)
  dashMsg:SetWidth(380)

  -- Right column actions
  local exportBtn = W.Button(dash, L.PARENT_EXPORT, 150, 24, function() v:ShowExport() end)
  exportBtn:SetPoint("TOPRIGHT", statsBox, "BOTTOMRIGHT", 0, -10)
  local changePin = W.Button(dash, L.PARENT_CHANGE_PIN, 150, 24, function()
    v.changingPin = true
    v:Refresh()
  end)
  changePin:SetPoint("TOP", exportBtn, "BOTTOM", 0, -6)
  local resetBtn
  resetBtn = W.Button(dash, L.PARENT_RESET, 150, 24, function()
    if resetBtn.armed then
      resetBtn.armed = false
      ns.Progress.ResetProfile()
      ns.Lessons.session = nil
      C.Print(L.PARENT_RESET_DONE)
      v.unlocked = false
      H.ShowView("profile")
    else
      resetBtn.armed = true
      resetBtn:SetText("|cffff5555" .. L.PARENT_RESET_CONFIRM .. "|r")
      C.After(4, function()
        if resetBtn.armed then
          resetBtn.armed = false
          resetBtn:SetText(L.PARENT_RESET)
        end
      end)
    end
  end)
  resetBtn:SetPoint("TOP", changePin, "BOTTOM", 0, -6)
  local lockBtn = W.Button(dash, L.PARENT_LOCK, 150, 24, function()
    v.unlocked = false
    if v.duelPanel then v.duelPanel:Hide() end
    v:Refresh()
  end)
  local rerunBtn = W.Button(dash, L.PARENT_RERUN_TRIAL, 150, 24, function()
    local P = ns.Progress
    ns.Trial.ResetPlacement(v:SubjectId(), P.GetBand() or "initiate")
    dashMsg:SetTextColor(W.GREEN[1], W.GREEN[2], W.GREEN[3])
    dashMsg:SetText(L.PARENT_RERUN_DONE)
  end)
  rerunBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -6)
  lockBtn:SetPoint("TOP", rerunBtn, "BOTTOM", 0, -6)

  ----------------------------------------------------------------------
  -- v0.10 Duel of Wits settings overlay (behind the PIN like everything here)
  ----------------------------------------------------------------------
  local duel = C.CreateFrame("Frame", nil, v, nil, true)
  duel:SetAllPoints(v)
  duel:SetFrameLevel(v:GetFrameLevel() + 20)
  duel:EnableMouse(true)
  C.ApplyBackdrop(duel, 0.03, 0.02, 0.06, 0.98, 0.62, 0.48, 1)
  local dTitle = W.Text(duel, 15, L.PP_DUEL_SETTINGS, W.GOLD, "LEFT")
  dTitle:SetPoint("TOPLEFT", 14, -12)
  local dInfo = W.Text(duel, 11, L.PP_DUEL_INFO, W.WHITE, "LEFT")
  dInfo:SetPoint("TOPLEFT", dTitle, "BOTTOMLEFT", 0, -8)
  dInfo:SetWidth(520)
  local function dset() return ns.Progress.account.settings.duel end
  local function onoff(b) return b and L.PP_ON or L.PP_OFF end
  local dButtons = {}
  local function dtoggle(row, fn)
    local b = W.Button(duel, "", 300, 24, function()
      fn()
      C.Sound("click")
      v:RefreshDuel()
    end, 11)
    b:SetPoint("TOPLEFT", dInfo, "BOTTOMLEFT", 0, -16 - row * 32)
    dButtons[#dButtons + 1] = b
    return b
  end
  local dEnabled = dtoggle(0, function() dset().enabled = dset().enabled == false end)
  local dFriends = dtoggle(1, function() dset().friendsOnly = not dset().friendsOnly end)
  local dRandom = dtoggle(2, function()
    dset().random = not dset().random
    if not dset().random and ns.DuelUI then ns.DuelUI.StopQueue() end
  end)
  local dAlias = dtoggle(3, function()
    local al = dset().alias
    local n = ns.Duel.ALIAS_COUNT
    -- step through every adjective x creature pair
    al[2] = al[2] % n + 1
    if al[2] == 1 then al[1] = al[1] % n + 1 end
  end)
  local dClear = dtoggle(4, function() ns.Util.Wipe(ns.Progress.account.duel.blocked) end)
  local dNote = W.Text(duel, 10, L.PP_DUEL_RANDOM_NOTE, W.GRAY, "LEFT")
  dNote:SetPoint("TOPLEFT", dInfo, "BOTTOMLEFT", 0, -16 - 5 * 32)
  dNote:SetWidth(520)
  local dClose = W.Button(duel, L.CLOSE, 100, 24, function() duel:Hide() end)
  dClose:SetPoint("BOTTOMRIGHT", -12, 12)
  duel:Hide()
  v.duelPanel, v.duelButtons = duel, { enabled = dEnabled, friends = dFriends, random = dRandom, alias = dAlias, clear = dClear }

  function v:RefreshDuel()
    local st = dset()
    local blocked = 0
    for _ in pairs(ns.Progress.account.duel.blocked) do blocked = blocked + 1 end
    dEnabled:SetText(string.format(L.PP_DUEL_ENABLED, onoff(st.enabled ~= false)))
    dFriends:SetText(string.format(L.PP_DUEL_FRIENDS, onoff(st.friendsOnly)))
    dRandom:SetText(string.format(L.PP_DUEL_RANDOM, onoff(st.random)))
    dAlias:SetText(string.format(L.PP_DUEL_ALIAS, ns.Duel.AliasText(st.alias[1], st.alias[2])))
    dClear:SetText(string.format(L.PP_DUEL_CLEAR, blocked))
  end

  function v:ShowDuelSettings()
    if not self.unlocked then return end
    self:RefreshDuel()
    duel:Show()
  end

  ----------------------------------------------------------------------
  -- Export overlay (multi-line, select-all copy)
  ----------------------------------------------------------------------
  local export = C.CreateFrame("Frame", nil, v, nil, true)
  export:SetAllPoints(v)
  export:SetFrameLevel(v:GetFrameLevel() + 20)
  export:EnableMouse(true)
  C.ApplyBackdrop(export, 0.03, 0.02, 0.06, 0.98, 0.62, 0.48, 1)
  local exTitle = W.Text(export, 12, L.EXPORT_TITLE, W.GOLD, "LEFT")
  exTitle:SetPoint("TOPLEFT", 10, -10)
  local scroll = C.CreateFrame("ScrollFrame", nil, export, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -32)
  scroll:SetPoint("BOTTOMRIGHT", -30, 44)
  local exBox = CreateFrame("EditBox", nil, scroll)
  exBox:SetMultiLine(true)
  exBox:SetAutoFocus(false)
  pcall(exBox.SetFont, exBox, C.FONT, 11, "")
  exBox:SetWidth(500)
  exBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  exBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and export.text then self:SetText(export.text); self:HighlightText() end
  end)
  scroll:SetScrollChild(exBox)
  if scroll.EnableMouseWheel then
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local cur, maxv = self:GetVerticalScroll(), self:GetVerticalScrollRange()
      self:SetVerticalScroll(math.max(0, math.min(maxv, cur - delta * 30)))
    end)
  end
  -- Report scope: All subjects, or one subject.
  local scopeBtn = W.Button(export, "", 200, 24, function()
    local list = ns.Modules.list
    if export.scope == nil then export.scope = list[1].id
    else
      local nextId
      for i, m in ipairs(list) do if m.id == export.scope then nextId = list[i + 1] and list[i + 1].id end end
      export.scope = nextId -- after the last subject: back to All
    end
    v:ShowExport(true)
  end)
  scopeBtn:SetPoint("BOTTOM", 0, 10)
  local selectAll = W.Button(export, L.SELECT_ALL, 120, 24, function()
    exBox:SetFocus()
    exBox:HighlightText()
  end)
  selectAll:SetPoint("BOTTOMLEFT", 10, 10)
  local exClose = W.Button(export, L.CLOSE, 100, 24, function() export:Hide() end)
  exClose:SetPoint("BOTTOMRIGHT", -10, 10)
  export:Hide()

  function v:SubjectId()
    local id = self.moduleId
    if not (id and ns.Modules.Get(id)) then id = ns.Lessons.CurrentModule().id end
    return id
  end

  function v:ShowExport(keepScope)
    if not keepScope then export.scope = self:SubjectId() end
    local scopeName = export.scope and L[ns.Modules.Get(export.scope).nameKey] or L.ALL_SUBJECTS
    scopeBtn:SetText(string.format(L.REPORT_SCOPE, scopeName))
    export.text = ns.Report.Build({ player = C.PlayerName(), moduleId = export.scope })
    exBox:SetText(export.text)
    export:Show()
    exBox:SetFocus()
    exBox:HighlightText()
  end

  ----------------------------------------------------------------------
  local function pctText(rec)
    if rec.attempts == 0 then return "|cff777777" .. L.NONE .. "|r" end
    local rc, rt = ns.Mastery.RecentCorrect(rec)
    local acc = math.floor(rec.correct / rec.attempts * 100 + 0.5)
    local s = string.format("%d%% (%d) %d/%d", acc, rec.attempts, rc, rt)
    if rec.mastered then s = "|cffffd100" .. s .. " *|r" end
    return s
  end

  function v:Refresh()
    local P = ns.Progress
    export:Hide()
    if not self.unlocked or self.changingPin then
      dash:Hide()
      gate:Show()
      pin1:SetText(""); pin2:SetText(""); gateMsg:SetText("")
      local setting = (not P.HasPin()) or self.changingPin
      gate.mode = setting and "set" or "enter"
      gateTitle:SetText(setting and L.PIN_SET_TITLE or L.PIN_ENTER_TITLE)
      gateBtn:SetText(setting and L.PIN_SAVE or L.PIN_UNLOCK)
      if setting then pin2Label:Show(); pin2:Show() else pin2Label:Hide(); pin2:Hide() end
      pin1:SetFocus()
      return
    end
    gate:Hide()
    dash:Show()
    local bandId = P.GetBand() or "initiate"
    local band = P.BAND_BY_ID[bandId]
    local module = ns.Modules.Get(self:SubjectId())
    local bandText = L[band.key] .. " " .. string.format(L.BAND_AGES, band.ages)
    if module.unbanded then bandText = L.BAND_EVERYONE .. " " .. L.BAND_AGES_ALL end
    statsTitle:SetText(string.format(L.PARENT_STATS, L[module.nameKey], bandText))
    subjectBtn:SetText(string.format(L.PARENT_SUBJECT, L[module.nameKey]))
    local nodes = ns.Modules.Nodes(module.id, bandId)
    for i, row in ipairs(statRows) do
      local nodeId = nodes[i]
      if nodeId then
        local _, node = ns.Modules.FindNode(nodeId)
        local nr = P.GetNodeRec(nodeId)
        row.name:SetText(L[node.key])
        local time = 0
        for t = 1, 3 do
          local txt = pctText(nr.tiers[t])
          if nr.tiers[t].fading then txt = txt .. " |cffff8800!|r" end
          row.tiers[t]:SetText(txt)
          time = time + nr.tiers[t].time
        end
        row.time:SetText(ns.Util.FormatDuration(time))
        row.start.nodeId = nodeId
        row.start:SetText(L[ns.Mastery.TIERS[ns.Trial.StartTier(nodeId)].key])
        row.start:Show()
      else
        row.name:SetText("")
        for t = 1, 3 do row.tiers[t]:SetText("") end
        row.time:SetText("")
        row.start.nodeId = nil
        row.start:Hide()
      end
    end
    local st = P.char.stats
    local earned, cap = P.GetTodayMinutes()
    totals:SetText(string.format(L.PARENT_TOTALS, st.rounds, st.problems, st.firstCorrect, ns.Util.FormatDuration(st.time),
      earned, cap, P.char.shards, #ns.Review.Due(), #ns.Review.Fading()))
    minBox:SetText(tostring(P.account.settings.minutesPerMastery))
    capBox:SetText(tostring(P.account.settings.dailyCap))
    for _, b in ipairs(bandButtons) do
      if b.bandId == bandId then b:SetText("|cffffd100> " .. L[P.BAND_BY_ID[b.bandId].key] .. "|r") else b:SetText(L[P.BAND_BY_ID[b.bandId].key]) end
    end
    unlockBtn:SetText(string.format(L.PARENT_UNLOCK_ALL, P.account.settings.unlockAllTiers and L.ON or L.OFF))
    reviewsBtn:SetText(string.format(L.PARENT_REVIEWS, P.account.settings.reviews ~= false and L.ON or L.OFF))
    local snd = P.account.settings.sound
    soundBtn:SetText(string.format(L.PARENT_SOUND, snd.enabled ~= false and L.ON or L.OFF))
    channelBtn:SetText(string.format(L.PARENT_CHANNEL, L["CHANNEL_" .. SE.Channel(snd):upper()]))
    levelBtn:SetText(string.format(L.PARENT_SOUND_LEVEL, snd.level == "important" and L.SOUND_LEVEL_IMPORTANT or L.SOUND_LEVEL_ALL))
    customBtn:SetText(string.format(L.PARENT_CUSTOM_SOUNDS, snd.custom ~= false and L.ON or L.OFF))
    motionBtn:SetText(string.format(L.PARENT_MOTION, P.account.settings.reducedMotion and L.ON or L.OFF))
    cameoBtn:SetText(string.format(L.PARENT_CAMEOS, P.account.settings.cameos ~= false and L.ON or L.OFF))
    local mm = P.account.settings.minimap
    minimapBtn:SetText(string.format(L.PARENT_MINIMAP, not (type(mm) == "table" and mm.hide) and L.ON or L.OFF))
    if ns.FlightUI then flightBtn:SetText(string.format(L.PARENT_FLIGHT, ns.FlightUI.ModeName())) end
    voiceBtn:SetText(string.format(L.PARENT_VOICE, ns.Voice.Enabled({ voice = P.account.settings.voice }) and L.ON or L.OFF))
    duelBtn:SetText(L.PP_DUEL_SETTINGS)
  end

  local function submitGate()
    local P = ns.Progress
    local a, b = pin1:GetText() or "", pin2:GetText() or ""
    if gate.mode == "set" then
      if a ~= b or not P.SetPin(a) then
        gateMsg:SetText(L.PIN_INVALID)
        return
      end
      v.changingPin = false
      v.unlocked = true
      dashMsg:SetText(L.SAVED)
    else
      if not P.CheckPin(a) then
        gateMsg:SetText(L.PIN_BAD)
        pin1:SetText("")
        return
      end
      v.unlocked = true
      dashMsg:SetText("")
    end
    pin1:ClearFocus(); pin2:ClearFocus()
    v:Refresh()
  end
  gateBtn:SetScript("OnClick", function() C.Sound("click"); submitGate() end)
  pin1:SetScript("OnEnterPressed", function()
    if gate.mode == "set" then pin2:SetFocus() else submitGate() end
  end)
  pin2:SetScript("OnEnterPressed", submitGate)

  function v:OnShowView()
    self.changingPin = false
    duel:Hide()
    self:Refresh()
  end

  function v:OnHubHidden()
    -- Closing the window always re-locks the panel.
    self.unlocked = false
    self.changingPin = false
    duel:Hide()
    pin1:ClearFocus(); pin2:ClearFocus(); exBox:ClearFocus()
  end
  return v
end)

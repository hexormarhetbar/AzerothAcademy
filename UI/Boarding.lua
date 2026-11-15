-- Murloc Boarding Party (v0.6): the ship deck, live typing, broadside, result + voyage log.
-- Game rules live in Core/Boarding.lua. Murlocs are in-game icons; the Tidehunter is an
-- in-game murloc model (icon fallback). Nothing is shipped except Hex's Fizzwick art.
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

local BU = {}
ns.BoardingUI = BU

BU.MURLOC_ICON = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
BU.WHEEL_ICON = "Interface\\Icons\\INV_Misc_Gear_08"
BU.TIDEHUNTER = { nameKey = "BOARD_NAME", displays = { 1995 }, creatures = { 127 }, icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01" }
BU.TINTS = { { 0.7, 1, 0.7 }, { 0.7, 0.85, 1 }, { 1, 0.85, 0.7 } }
BU.DECK_W, BU.DECK_H = 548, 222
BU.RAIL_X, BU.WHEEL_X = 46, 470          -- murloc x at pos 0 and pos 100
BU.LANE_Y = { -64, -132, -200 }           -- icon centers (from the deck top)
BU.SPLASH_TIME = 0.6

local GREEN, DONE = "|cff33ff66", "|r"

local function say(event) if ns.GuideUI then return ns.GuideUI.Say(event) end end

-- Colored order text: typed part green, the rest white (gold for the current target).
function BU.Colored(m, progress, isTarget)
  local cut = ns.Boarding.Covered(m, progress or 0)
  local rest = m.text:sub(cut + 1)
  return (cut > 0 and (GREEN .. m.text:sub(1, cut) .. DONE) or "") .. (isTarget and "|cffffd100" or "|cffffffff") .. rest .. DONE
end

local function fmtTime(sec) return ns.Util.FormatDuration(math.floor(sec + 0.5)) end

function BU.Start(routeId)
  local band = ns.Progress.GetBand() or "initiate"
  routeId = routeId or ns.Boarding.BestRoute()
  if not ns.Boarding.Unlocked(routeId) then return nil end
  BU.game = ns.Boarding.New(band, routeId)
  H.ShowView("boarding", "play")
  return BU.game
end

------------------------------------------------------------------------
-- View
------------------------------------------------------------------------
H.RegisterView("boarding", function(parent)
  local v = CreateFrame("Frame", nil, parent)

  ---------------- setup panel ----------------
  local setup = CreateFrame("Frame", nil, v)
  setup:SetAllPoints(v)
  v.setup = setup
  local sTitle = W.Text(setup, 18, L.BOARD_NAME, W.GOLD, "LEFT")
  sTitle:SetPoint("TOPLEFT", 4, -2)
  local sBack = W.Button(setup, L.BACK, 90, 22, function()
    ns.Lessons.moduleId = "scribe"
    H.ShowView("forge")
  end)
  sBack:SetPoint("TOPRIGHT", 0, 0)
  local intro = W.Text(setup, 12, L.BOARD_INTRO, W.ARCANE, "LEFT")
  intro:SetPoint("TOPLEFT", sTitle, "BOTTOMLEFT", 0, -6)
  intro:SetWidth(540)
  local rules = W.Text(setup, 11, "", W.WHITE, "LEFT")
  rules:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -6)
  rules:SetWidth(540)
  v.selected = nil
  local routeBtns = {}
  for i, r in ipairs(ns.Boarding.ROUTES) do
    local b = C.CreateFrame("Button", nil, setup, nil, true)
    b:SetSize(174, 70)
    b:SetPoint("TOPLEFT", (i - 1) * 183, -118)
    local icon = W.FramedIcon(b, 30, r.icon)
    icon:SetPoint("TOPLEFT", 10, -8)
    b.icon = icon
    b.name = W.Text(b, 12, L[r.key], W.GOLD, "LEFT")
    b.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    b.name:SetWidth(118)
    b.state = W.Text(b, 10, "", W.GRAY, "LEFT")
    b.state:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)
    b.state:SetWidth(158)
    b.routeId = r.id
    b:SetScript("OnClick", function(self)
      if not ns.Boarding.Unlocked(self.routeId) then
        C.Sound("wrong")
        return
      end
      C.Sound("click")
      v.selected = self.routeId
      v:RefreshSetup()
    end)
    routeBtns[i] = b
  end
  v.routeBtns = routeBtns
  local sail = W.Button(setup, L.BOARD_SET_SAIL, 200, 34, function()
    BU.Start(v.selected) -- (W.Button ticks after the handler, v1.2.3)
  end, 15)
  sail:SetPoint("TOP", 0, -200)
  local logTitle = W.Text(setup, 13, L.BOARD_LOG, W.GOLD, "LEFT")
  logTitle:SetPoint("TOPLEFT", 4, -246)
  local best = W.Text(setup, 11, "", W.GREEN, "RIGHT")
  best:SetPoint("TOPRIGHT", -4, -248)
  local logLines = {}
  for i = 1, 5 do
    local fs = W.Text(setup, 11, "", W.WHITE, "LEFT")
    fs:SetPoint("TOPLEFT", 8, -266 - (i - 1) * 16)
    fs:SetWidth(530)
    logLines[i] = fs
  end
  v.logLines = logLines

  function v:RefreshSetup()
    local B = ns.Boarding
    local band = ns.Progress.GetBand() or "initiate"
    rules:SetText(L["BOARD_RULES_" .. band] or "")
    if not (self.selected and B.Unlocked(self.selected)) then self.selected = B.BestRoute() end
    local st = B.State()
    for i, b in ipairs(routeBtns) do
      local r = B.ROUTES[i]
      local open = B.Unlocked(r.id)
      local cleared = type(st.cleared[band]) == "table" and st.cleared[band][r.id]
      if open then
        b.state:SetText(cleared and ("|cff4dff66" .. L.BOARD_ROUTE_CLEARED .. "|r") or string.format(L.BOARD_ROUTE_WAVES, r.waves))
      else
        b.state:SetText(string.format(L.BOARD_ROUTE_LOCKED, L[B.ROUTE_BY_ID[r.unlock].key]))
      end
      if b.icon.SetDesaturated then b.icon:SetDesaturated(not open) end
      if self.selected == r.id then
        C.ApplyBackdrop(b, 0.18, 0.08, 0.32, 0.95, 1, 0.82, 0)
      else
        C.ApplyBackdrop(b, 0.08, 0.06, 0.14, 0.9, 0.35, 0.3, 0.5)
      end
    end
    local bb = type(st.best[band]) == "table" and st.best[band].wpm or 0
    best:SetText(bb > 0 and string.format(L.BOARD_BEST_LINE, bb) or "")
    for i, fs in ipairs(logLines) do
      local e = st.log[i]
      if e then
        local route = B.ROUTE_BY_ID[e.route]
        fs:SetText(string.format(L.BOARD_LOG_LINE, ns.Util.DateText(e.date), route and L[route.key] or e.route,
          e.won and ("|cff4dff66" .. L.BOARD_WON .. "|r") or ("|cffff8800" .. L.BOARD_LOST .. "|r"), e.wpm or 0, e.accuracy or 0))
      else
        fs:SetText(i == 1 and L.BOARD_LOG_EMPTY or "")
      end
    end
  end

  ---------------- play panel ----------------
  local play = CreateFrame("Frame", nil, v)
  play:SetAllPoints(v)
  v.play = play
  local routeText = W.Text(play, 13, "", W.GOLD, "LEFT")
  routeText:SetPoint("TOPLEFT", 4, -2)
  local waveText = W.Text(play, 12, "", W.WHITE, "CENTER")
  waveText:SetPoint("TOP", 0, -3)
  local quit = W.Button(play, L.BOARD_QUIT, 110, 20, function()
    if BU.game and not BU.game.done then BU.game.paused = true end
    v:ShowPanel("setup")
  end, 11)
  quit:SetPoint("TOPRIGHT", 0, 0)
  local wheelText = W.Text(play, 11, "", W.AMBER, "RIGHT")
  wheelText:SetPoint("RIGHT", quit, "LEFT", -8, 0)
  v.waveText, v.wheelText = waveText, wheelText

  local deck = C.CreateFrame("Frame", nil, play, nil, true)
  deck:SetSize(BU.DECK_W, BU.DECK_H)
  deck:SetPoint("TOPLEFT", 0, -24)
  C.ApplyBackdrop(deck, 0.30, 0.19, 0.09, 0.95, 0.55, 0.38, 0.18)
  v.deck = deck
  local sea = deck:CreateTexture(nil, "BACKGROUND", nil, 1)
  sea:SetPoint("TOPLEFT", 3, -3)
  sea:SetPoint("BOTTOMLEFT", 3, 3)
  sea:SetWidth(26)
  C.SetColor(sea, 0.1, 0.35, 0.7, 0.9)
  for i = 1, 3 do -- planks
    local p = deck:CreateTexture(nil, "BACKGROUND", nil, 2)
    p:SetPoint("TOPLEFT", 30, -i * BU.DECK_H / 4)
    p:SetPoint("TOPRIGHT", -3, -i * BU.DECK_H / 4)
    p:SetHeight(1)
    C.SetColor(p, 0.18, 0.11, 0.05, 0.8)
  end
  local wheel = W.FramedIcon(deck, 40, BU.WHEEL_ICON)
  wheel:SetPoint("RIGHT", -14, -18)
  v.wheel = wheel
  if ns.GuideUI then
    v.captain = ns.GuideUI.Hero(deck, 60) -- Fizzwick at the wheel (head crop, art only)
    v.captain:SetPoint("BOTTOM", wheel, "TOP", 0, 2)
  end

  -- murloc slots (pooled)
  local slots = {}
  local function newSlot()
    local s = CreateFrame("Frame", nil, deck)
    s:SetSize(36, 36)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints(s)
    s.icon:SetTexture(BU.MURLOC_ICON)
    s.ring = s:CreateTexture(nil, "OVERLAY")
    s.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    if s.ring.SetBlendMode then s.ring:SetBlendMode("ADD") end
    s.ring:SetSize(66, 66)
    s.ring:SetPoint("CENTER")
    s.ring:Hide()
    s.label = W.Text(deck, 12, "", W.WHITE, "CENTER", "OVERLAY")
    s:Hide()
    slots[#slots + 1] = s
    return s
  end
  for _ = 1, 6 do newSlot() end
  v.slots = slots
  -- the Tidehunter: an in-game murloc model (icon fallback)
  local boss = CreateFrame("Frame", nil, deck)
  boss:SetSize(76, 76)
  if ns.GuideUI then
    boss.portrait = ns.GuideUI.Portrait(boss, 76, 76)
    boss.portrait:SetAllPoints(boss)
  end
  boss.label = W.Text(deck, 13, "", W.WHITE, "CENTER", "OVERLAY")
  boss.label:SetWidth(330)
  boss:Hide()
  v.boss = boss

  local orderText = W.Text(play, 16, "", W.WHITE, "CENTER")
  orderText:SetPoint("TOP", deck, "BOTTOM", 0, -8)
  orderText:SetWidth(540)
  v.orderText = orderText
  local input = W.EditBox(play, 300, 28, 16)
  input:SetPoint("TOPLEFT", deck, "BOTTOMLEFT", 8, -44)
  v.input = input
  local typeHint = W.Text(play, 10, L.BOARD_TYPE_HERE, W.GRAY, "LEFT")
  typeHint:SetPoint("BOTTOMLEFT", input, "TOPLEFT", 2, 1)
  local meter = W.Bar(play, 130, 20, W.AMBER)
  meter:SetPoint("LEFT", input, "RIGHT", 12, 0)
  v.meter = meter
  local fire = W.Button(play, L.BOARD_FIRE, 92, 24, function() v:Fire() end, 10)
  fire:SetPoint("LEFT", meter, "RIGHT", 6, 0)
  v.fire = fire
  local stats = W.Text(play, 11, "", W.GRAY, "LEFT")
  stats:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -6)
  local timeText = W.Text(play, 11, "", W.GRAY, "RIGHT")
  timeText:SetPoint("TOPRIGHT", deck, "BOTTOMRIGHT", -4, -82)
  v.stats, v.timeText = stats, timeText

  -- pause overlay (combat, Escape, hub closed)
  local pause = C.CreateFrame("Frame", nil, play, nil, true)
  pause:SetSize(260, 110)
  pause:SetPoint("CENTER", deck, "CENTER")
  C.ApplyBackdrop(pause, 0.05, 0.04, 0.1, 0.96, 1, 0.82, 0)
  local pTitle = W.Text(pause, 18, L.BOARD_PAUSED, W.GOLD, "CENTER")
  pTitle:SetPoint("TOP", 0, -14)
  local resume = W.Button(pause, L.BOARD_RESUME, 140, 28, function() v:Resume() end, 13)
  resume:SetPoint("BOTTOM", 0, 16)
  pause:Hide()
  v.pause = pause

  ---------------- result panel ----------------
  local result = C.CreateFrame("Frame", nil, v, nil, true)
  result:SetAllPoints(v)
  C.ApplyBackdrop(result, 0.06, 0.05, 0.12, 0.97, 0.85, 0.65, 0.25)
  v.result = result
  local rTitle = W.Text(result, 22, "", W.GOLD, "CENTER")
  rTitle:SetPoint("TOP", 0, -18)
  local rLines = {}
  local prev = rTitle
  for i = 1, 7 do
    local fs = W.Text(result, 13, "", W.WHITE, "CENTER")
    fs:SetPoint("TOP", prev, "BOTTOM", 0, i == 1 and -14 or -6)
    fs:SetWidth(400)
    rLines[i] = fs
    prev = fs
  end
  v.rLines, v.rTitle = rLines, rTitle
  if ns.GuideUI then
    v.hero = ns.GuideUI.Hero(result, 140)
    v.hero:SetPoint("TOPLEFT", -4, -40)
  end
  local again = W.Button(result, L.BOARD_AGAIN, 140, 30, function()
    BU.Start(BU.lastResult and BU.lastResult.unlocked or (BU.game and BU.game.routeId))
  end, 13)
  again:SetPoint("BOTTOM", -150, 10)
  local toPort = W.Button(result, L.BOARD_QUIT, 140, 30, function() v:ShowPanel("setup") end, 13)
  toPort:SetPoint("BOTTOM", 0, 10)
  local hub = W.Button(result, L.HUB, 140, 30, function() H.ShowView("home") end, 13)
  hub:SetPoint("BOTTOM", 150, 10)

  ---------------- behaviour ----------------
  function v:ShowPanel(which)
    self.panel = which
    setup:SetShown(which == "setup")
    play:SetShown(which == "play" or which == "result")
    result:SetShown(which == "result")
    if which == "setup" then
      self:SetScript("OnUpdate", nil)
      self:RefreshSetup()
    end
  end

  function v:SlotFor(m)
    self.slotOf = self.slotOf or {}
    local s = self.slotOf[m.id]
    if s then return s end
    for _, x in ipairs(slots) do
      if not x.mid and not x.busy then s = x break end
    end
    s = s or newSlot()
    s.mid = m.id
    local tint = BU.TINTS[(m.id - 1) % #BU.TINTS + 1]
    s.icon:SetVertexColor(tint[1], tint[2], tint[3])
    s.icon:SetAlpha(1)
    s.label:SetWidth(self.game and self.game.band == "magister" and 250 or 190)
    self.slotOf[m.id] = s
    return s
  end

  local function xFor(pos) return BU.RAIL_X + (BU.WHEEL_X - BU.RAIL_X) * math.max(0, math.min(1, pos / ns.Boarding.DECK)) end

  function v:Place(m, s, bob)
    local x, y = xFor(m.pos), BU.LANE_Y[m.lane] + (bob or 0)
    s:ClearAllPoints()
    s:SetPoint("CENTER", deck, "TOPLEFT", x, y)
    local lw = s.label:GetWidth() or 190
    if lw == 0 then lw = 190 end
    local lx = math.max(lw / 2 + 4, math.min(BU.DECK_W - lw / 2 - 4, x))
    s.label:ClearAllPoints()
    s.label:SetPoint("BOTTOM", deck, "TOPLEFT", lx, y + (m.boss and 40 or 20))
  end

  function v:Render()
    local g = self.game
    if not g then return end
    local still = W.ReducedMotion()
    local live = {}
    for _, m in ipairs(g.murlocs) do
      live[m.id] = true
      local isTarget = g.target == m
      local progress = isTarget and #g.typed or 0
      if m.boss then
        boss:Show()
        boss.label:Show()
        self:Place(m, boss, 0)
        boss.label:SetText(BU.Colored(m, progress, isTarget))
        if boss.SetAlpha then boss:SetAlpha(m.stun > 0 and 0.6 or 1) end
      else
        local s = self:SlotFor(m)
        s:Show()
        s.label:Show()
        local bob = (still or m.waiting) and 0 or math.sin(g.time * 5 + m.id) * 3
        self:Place(m, s, bob)
        s.label:SetText(BU.Colored(m, progress, isTarget))
        s.ring:SetShown(isTarget)
      end
    end
    for id, s in pairs(self.slotOf or {}) do
      if not live[id] and not s.busy then
        s:Hide(); s.label:Hide(); s.mid = nil; self.slotOf[id] = nil
      end
    end
    if not g.bossSpawned or g.done then boss:Hide(); boss.label:Hide() end
    -- the order being typed, big
    if g.target then
      orderText:SetText(BU.Colored(g.target, #g.typed, true))
    else
      orderText:SetText("")
    end
    meter:SetProgress(g.meter / ns.Boarding.METER_MAX, g:BroadsideReady() and L.BOARD_FIRE or L.BOARD_METER)
    if g:BroadsideReady() then fire:Enable() else fire:Disable() end
    stats:SetText(string.format(L.BOARD_STATS, g.splashed, g.typos, g:WPM()))
    local par = g:Par()
    timeText:SetText(par and string.format(L.BOARD_TIME_PAR, fmtTime(g.time), fmtTime(par)) or string.format(L.BOARD_TIME, fmtTime(g.time)))
    if g.wheel then wheelText:SetText(string.format(L.BOARD_WHEEL, g.wheel)) else wheelText:SetText(L.BOARD_NO_FAIL) end
    waveText:SetText(g.bossSpawned and L.BOARD_BOSS or string.format(L.BOARD_WAVE, g.wave, g.route.waves))
  end

  function v:Captain(pose)
    if self.captain and ns.GuideUI then ns.GuideUI.ShowPose(self.captain, pose, true, false) end
    if self.captain then self.captain:SetShown(self.captain.mode == "art") end
  end

  function v:Splash(m, broadside)
    local s = self.slotOf and self.slotOf[m.id]
    if m.boss then s = boss end
    if not s then return end
    C.Sound("splash")
    local still = W.ReducedMotion()
    W.Float(deck, L.BOARD_SPLASH, { 0.4, 0.75, 1 }, xFor(m.pos) - BU.DECK_W / 2, BU.LANE_Y[m.lane] + BU.DECK_H / 2)
    s.label:Hide()
    if s.ring then s.ring:Hide() end
    if still or s == boss then
      s:Hide()
      if s ~= boss then s.mid = nil; self.slotOf[m.id] = nil end
      return
    end
    -- the crew flings it back over the rail into the sea
    s.busy = true
    self.slotOf[m.id] = nil
    s.mid = nil
    local x0, y0 = xFor(m.pos), BU.LANE_Y[m.lane]
    W.Animate(broadside and 0.45 or BU.SPLASH_TIME, function(p)
      s:ClearAllPoints()
      s:SetPoint("CENTER", deck, "TOPLEFT", x0 + (14 - x0) * p, y0 + math.sin(p * math.pi) * 40 - p * 20)
      s.icon:SetAlpha(1 - p * 0.8)
    end, function()
      s:Hide()
      s.busy = nil
      s.icon:SetAlpha(1)
    end)
    W.Sparks(deck, 6, { 0.4, 0.75, 1 })
  end

  function v:HandleEvents()
    local g = self.game
    for _, e in ipairs(g:PopEvents()) do
      local t = e.type
      if t == "spawn" then
        if math.random() < 0.5 then C.Sound("gurgle") end
      elseif t == "boss" then
        C.Sound("gurgle")
        if boss.portrait then boss.portrait:ShowCast(BU.TIDEHUNTER) end -- in-game model by design (no custom art)
        say("BOARDBOSS")
        self:Captain("surprised")
      elseif t == "wave" then
        if e.wave > 1 then say("BOARDWAVE"); self:Captain("talking") end
      elseif t == "splash" then
        self:Splash(e.murloc, e.broadside)
        if not e.broadside and e.streak and e.streak % 3 == 0 then
          say("BOARDSPLASH"); self:Captain("excited")
        end
      elseif t == "stumble" then
        C.Sound("wrong")
        W.Flash(input, W.AMBER, 0.3)
        self.stumbleText = L.BOARD_STUMBLE
      elseif t == "broadsideReady" then
        C.Sound("combo")
        W.Flash(fire, W.GOLD, 0.6)
      elseif t == "broadside" then
        C.Sound("cannon")
        W.Flash(deck, W.AMBER, 0.6)
        W.Sparks(deck, 16, W.GOLD)
        say("BOARDBROADSIDE"); self:Captain("excited")
      elseif t == "bossHit" then
        W.Float(deck, L.BOARD_SPLASH, W.GOLD, 0, 30)
      elseif t == "wheel" or t == "atWheel" then
        C.Sound("gurgle")
        W.Flash(deck, { 1, 0.3, 0.2 }, 0.4)
        say("BOARDWHEEL"); self:Captain("encouraging")
      elseif t == "win" or t == "lose" then
        self:Finish()
        return
      end
    end
  end

  function v:Fire()
    local g = self.game
    if not (g and g:Broadside()) then return false end
    input:SetText(g.typed)
    self:HandleEvents()
    self:Render()
    return true
  end

  -- Typing: every change is checked; typos are refused (the box goes back).
  input:SetScript("OnTextChanged", function(self)
    if v.settingText or not v.game then return end
    local text = self:GetText() or ""
    local shown, status = v.game:Input(text)
    if shown ~= text then
      v.settingText = true
      self:SetText(shown)
      v.settingText = false
    end
    v.lastStatus = status
    v:HandleEvents()
    v:Render()
  end)
  input:SetScript("OnEnterPressed", function(self)
    if v.game and v.game:BroadsideReady() then v:Fire() end
  end)
  input:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    v:Pause()
  end)

  function v:Pause()
    if not self.game or self.game.done then return end
    self.game.paused = true
    pause:Show()
  end

  function v:Resume()
    if not self.game or self.game.done then return end
    self.game.paused = false
    pause:Hide()
    input:SetFocus()
  end

  function v:OnTick(dt)
    local g = self.game
    if not g or g.done then return end
    g:Tick(dt)
    self:HandleEvents()
    if self.game and not self.game.done then self:Render() end
  end

  function v:Begin(g)
    self.game = g
    for id, s in pairs(self.slotOf or {}) do s:Hide(); s.label:Hide(); s.mid = nil; self.slotOf[id] = nil end
    boss:Hide(); boss.label:Hide()
    pause:Hide()
    self:ShowPanel("play")
    routeText:SetText(L[g.route.key])
    input:SetText("")
    input:SetFocus()
    C.Sound("gurgle")
    say("BOARDSTART")
    self:Captain("talking")
    self:SetScript("OnUpdate", function(self2, dt) self2:OnTick(dt) end)
    self:HandleEvents()
    self:Render()
  end

  function v:Finish()
    local g = self.game
    self:SetScript("OnUpdate", nil)
    input:ClearFocus()
    local r = ns.Boarding.Record(g)
    BU.lastResult = r
    self:Render()
    self:ShowPanel("result")
    rTitle:SetText(r.won and L.BOARD_WIN or L.BOARD_LOSE)
    local lines = {
      string.format(L.BOARD_RESULT_LINE, r.splashed, r.accuracy, r.bestStreak),
      string.format(L.BOARD_RESULT_WPM, r.wpm, fmtTime(r.time)),
    }
    if r.newBestWpm then lines[#lines + 1] = "|cffffd100" .. string.format(L.BOARD_RESULT_BEST, r.wpm) .. "|r" end
    if r.underPar then lines[#lines + 1] = "|cff4dff66" .. L.BOARD_RESULT_PAR .. "|r" end
    if r.firstClear then lines[#lines + 1] = "|cff4dff66" .. L.BOARD_RESULT_FIRST .. "|r" end
    if r.unlocked then lines[#lines + 1] = "|cff66ccff" .. string.format(L.BOARD_RESULT_UNLOCK, L[ns.Boarding.ROUTE_BY_ID[r.unlocked].key]) .. "|r" end
    for i, fs in ipairs(rLines) do fs:SetText(lines[i] or "") end
    W.CountUp(rLines[#lines + 1] or rLines[#rLines], r.shards, "|cffffd100" .. L.BOARD_RESULT_SHARDS .. "|r")
    local pose = r.won and "celebrating" or "encouraging"
    if r.newBestWpm then pose = "surprised" end
    self.heroPose = pose
    if self.hero then ns.GuideUI.ShowHero(self.hero, pose) end
    if r.won then
      C.Sound("reward")
      W.Sparks(result, 18, W.GOLD)
      say("BOARDWIN")
    else
      say("BOARDLOSE")
    end
    if r.newBestWpm and ns.GuideUI then ns.GuideUI.Pose("surprised") end
    if r.rankUp and ns.GuideUI then ns.GuideUI.Celebrate(ns.Progress.GetRankInfo().key) end
  end

  function v:OnShowView(mode)
    if mode == "play" and BU.game and BU.game ~= self.game then
      self:Begin(BU.game)
    elseif self.panel == "play" and self.game and not self.game.done then
      -- coming back (after combat or reopening): stay paused until Resume
      self:SetScript("OnUpdate", function(self2, dt) self2:OnTick(dt) end)
      self:Pause()
      self:Render()
    elseif self.panel == "result" and mode ~= "setup" then
      self:ShowPanel("result")
    else
      self:ShowPanel("setup")
    end
  end

  function v:OnHubHidden()
    if self.game and not self.game.done and self.panel == "play" then
      self.game.paused = true
      pause:Show()
    end
  end

  v:ShowPanel("setup")
  return v
end)

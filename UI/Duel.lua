-- Duel of Wits (v0.10): multiplayer learning races. The race logic lives in
-- Core/Duel.lua (pure); this file gives it a transport (addon messages through
-- Compat), a clock, and the screens: setup + waiting room, invite pop-up,
-- countdown + race, results. Nothing typed by a player is ever sent or shown:
-- only answers' scores and four preset emotes travel between clients.
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

local DU = {}
ns.DuelUI = DU

DU.TICK = 0.1
DU.sel = { subject = "runeforger", length = 5, scope = "PARTY", target = "" }

local function say(event) if ns.GuideUI and H.IsShown() then return ns.GuideUI.Say(event) end end
local function P() return ns.Progress end
local function D() return ns.Duel end
local function dset() return P().account.settings.duel end
local function reasonText(r) return L["DUEL_REASON_" .. tostring(r)] or tostring(r) end
local function errText(e) return L["DUEL_ERR_" .. tostring(e)] or tostring(e) end

function DU.MyName()
  local short = C.ShortName() or "Player"
  local realm = C.Realm()
  return realm ~= "" and (short .. "-" .. realm) or short
end

function DU.IsBlocked(name)
  local acct = P().account
  if not (acct and acct.duel) then return false end
  return acct.duel.blocked[D().Norm(name, C.Realm()):lower()] == true
end

function DU.Block(name, display)
  P().account.duel.blocked[D().Norm(name, C.Realm()):lower()] = true
  C.Print(string.format(L.DUEL_BLOCKED, display or D().Short(name)))
end

------------------------------------------------------------------------
-- Engine + transport
------------------------------------------------------------------------
function DU.Init()
  if DU.engine then return DU.engine end
  if not (P() and P().account) then return nil end
  local DP = ns.DuelProto
  C.RegisterAddonPrefix(DP.PREFIX)
  DU.engine = D().NewEngine({
    me = DU.MyName(), realm = C.Realm(), now = C.Now, addonVersion = ns.VERSION,
    send = function(msg, channel, target) C.SendAddonMessage(DP.PREFIX, msg, channel, target) end,
    band = function() return P().GetBand() end,
    course = function() return P().account.settings.tongues.course end,
    display = function() return C.ShortName() end,
    settings = dset,
    context = function() return { combat = C.InCombat(), instance = C.InInstance() } end,
    isFriend = C.IsFriend,
    isBlocked = DU.IsBlocked,
    groupChannel = C.GroupChannel,
    inGuild = C.InGuild,
    queueChannel = function() return DU.inQueueChannel and C.ChannelIndex(C.QUEUE_CHANNEL) or nil end,
    queueJoin = function() DU.inQueueChannel = true; C.JoinHiddenChannel(C.QUEUE_CHANNEL) end,
    queueLeave = function() DU.inQueueChannel = false; C.LeaveHiddenChannel(C.QUEUE_CHANNEL) end,
    notify = function(ev, ...) DU.OnEvent(ev, ...) end,
  })
  local ticker = CreateFrame("Frame", "AzerothAcademyDuelTicker")
  local acc = 0
  ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < DU.TICK then return end
    acc = 0
    DU.Tick()
  end)
  DU.ticker = ticker
  return DU.engine
end

function DU.Tick()
  local E = DU.engine
  if not E then return end
  local okt, err = pcall(E.Update, E)
  if not okt then DU.lastError = err end
  local v = DU.view
  if v and v:IsShown() and v.Tick then v:Tick() end
  if DU.popup and DU.popup:IsShown() then DU.popup:Tick() end
end

-- CHAT_MSG_ADDON (Main.lua filters the prefix)
function DU.Receive(msg, channel, sender)
  local E = DU.Init()
  if not E then return end
  local okr, err = pcall(E.Receive, E, msg, channel, sender)
  if not okr then DU.lastError = err end
end

function DU.OnCombat()
  if DU.popup then DU.popup:Hide() end
  if DU.engine then DU.engine:OnCombat() end
end

function DU.StopQueue()
  if DU.engine and DU.engine.queue then DU.engine:QueueLeave("left") end
end

------------------------------------------------------------------------
-- Opening / slash
------------------------------------------------------------------------
function DU.Open(target)
  if C.InCombat() then C.Print(L.NO_COMBAT) return end
  DU.Init()
  if target and target ~= "" then
    DU.sel.scope, DU.sel.target = "WHISPER", target
  end
  local E = DU.engine
  local mode = "setup"
  if E and E.duel then
    local s = E.duel.state
    if s == "countdown" or s == "race" then mode = "race" elseif s == "done" then mode = "result" end
  end
  H.Open("duel", mode)
end

-- /aa duel [name | queue | leave]
function DU.Slash(rest)
  rest = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local low = rest:lower()
  DU.Init()
  if low == "leave" or low == "stop" then
    DU.StopQueue()
    if DU.engine then DU.engine:Close() end
    return
  elseif low == "queue" or low == "random" then
    DU.sel.scope = "QUEUE"
    DU.Open()
    return
  end
  DU.Open(rest ~= "" and rest or nil)
end

------------------------------------------------------------------------
-- Engine events -> screens / chat
------------------------------------------------------------------------
local function showMode(mode)
  if not H.IsShown() then
    if C.InCombat() then return end
    H.Open("duel", mode)
  elseif H.current ~= "duel" then
    H.ShowView("duel", mode)
  elseif DU.view then
    DU.view:SetMode(mode)
  end
end

function DU.OnEvent(ev, a, b, c)
  local v = DU.view
  if ev == "invite" then
    DU.ShowInvite(a)
    say("DUELINVITE")
  elseif ev == "inviteGone" then
    if DU.popup then DU.popup:Hide() end
  elseif ev == "autoDecline" then
    if b ~= "busy" and b ~= "blocked" then C.Print(string.format(L.DUEL_AUTODECLINE, reasonText(b))) end
  elseif ev == "declined" then
    if b and b ~= "" then C.Print(string.format(L.DUEL_DEC, b, reasonText(c)))
    else C.Print(string.format(L.DUEL_DEC_ANON, reasonText(c))) end
    if v and v:IsShown() then v:Refresh() end
  elseif ev == "version" then
    C.Print(string.format(L.DUEL_VERSION, tostring(a), tonumber(b) or 0, tonumber(c) or 0))
  elseif ev == "lobby" then
    if v and v:IsShown() then v:Refresh() end
  elseif ev == "countdown" then
    if DU.popup then DU.popup:Hide() end
    DU.lastCount = nil
    showMode("race")
    say("DUELSTART")
  elseif ev == "race" or ev == "progress" or ev == "state" or ev == "racerLeft" or ev == "invalid" then
    if ev == "racerLeft" and b then
      local name = D().DisplayFor(b, a.scope)
      C.Print(string.format(L.DUEL_RACER_GONE, name))
    end
    if ev == "race" then C.Sound("forge") end
    if ev == "progress" and a.me and a.me.doneAt and a.state == "race" then say("DUELWAIT") end
    if v and v:IsShown() then v:Refresh() end
  elseif ev == "hostLost" then
    C.Print(L.DUEL_HOSTLOST)
  elseif ev == "result" then
    local rw = a.reward or {}
    if rw.win then C.Sound("duelwin"); say("DUELWIN") else C.Sound("reward"); say("DUELDONE") end
    showMode("result")
    if rw.rankUp and ns.GuideUI and ns.GuideUI.Celebrate then
      pcall(ns.GuideUI.Celebrate, P().GetRankInfo().key)
    end
  elseif ev == "cancel" then
    C.Print(b == "full" and L.DUEL_FULL or L.DUEL_CANCELLED)
    if v and v:IsShown() then v:SetMode("setup") end
  elseif ev == "left" then
    if b == "combat" then C.Print(L.DUEL_FORFEIT) end
    if v and v:IsShown() then v:SetMode("setup") end
  elseif ev == "emote" then
    local text = string.format(L.DUEL_EMOTE_SAYS, tostring(b), L[D().EMOTES[c]] or "")
    C.Print(text)
    if v and v:IsShown() then v:ShowEmote(text) end
  elseif ev == "queue" then
    if a == "timeout" then C.Print(L.DUEL_QUEUE_TIMEOUT) end
    if v and v:IsShown() then v:Refresh() end
  end
end

------------------------------------------------------------------------
-- Invite pop-up (works with the Academy window closed)
------------------------------------------------------------------------
function DU.ShowInvite(inv)
  local f = DU.popup
  if not f then
    f = C.CreateFrame("Frame", "AzerothAcademyDuelInvite", UIParent, nil, true)
    f:SetSize(360, 110)
    f:SetPoint("TOP", UIParent, "TOP", 0, -170)
    f:SetFrameStrata("HIGH")
    C.ApplyBackdrop(f, 0.06, 0.04, 0.14, 0.96, 0.62, 0.48, 1, 1)
    local icon = W.FramedIcon(f, 36, "Interface\\Icons\\INV_Misc_Book_09")
    icon:SetPoint("TOPLEFT", 12, -12)
    local msg = W.Text(f, 12, "", W.GOLD, "LEFT")
    msg:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    msg:SetWidth(290)
    f.msg = msg
    f.accept = W.Button(f, L.DUEL_ACCEPT, 130, 24, function()
      f:Hide()
      local E = DU.engine
      local okA, why = E:Accept()
      if okA then DU.Open() elseif why then C.Print(errText(why)) end
    end)
    f.accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 10)
    f.decline = W.Button(f, L.DUEL_DECLINE, 130, 24, function()
      f:Hide()
      if DU.engine then DU.engine:Decline("declined") end
    end)
    f.decline:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 10)
    function f:Tick()
      local i = DU.engine and DU.engine.invite
      if not i then self:Hide() return end
      local left = math.max(0, math.ceil(D().INVITE_TIMEOUT - (C.Now() - i.at)))
      self.decline:SetText(L.DUEL_DECLINE .. " (" .. left .. ")")
    end
    DU.popup = f
  end
  local subj = D().SubjectName(inv.subject)
  if inv.scope == "QUEUE" or inv.display == "" then
    f.msg:SetText(string.format(L.DUEL_POPUP_ANON, subj, inv.length))
  else
    f.msg:SetText(string.format(L.DUEL_POPUP, inv.display, subj, inv.length))
  end
  f.decline:SetText(L.DUEL_DECLINE)
  f:Show()
  C.Sound("chirp")
end

------------------------------------------------------------------------
-- The "duel" view: setup / race / result panels
------------------------------------------------------------------------
local SCOPES = { "PARTY", "GUILD", "WHISPER", "QUEUE" }
local SCOPE_KEY = { PARTY = "DUEL_SCOPE_PARTY", GUILD = "DUEL_SCOPE_GUILD", WHISPER = "DUEL_SCOPE_WHISPER", QUEUE = "DUEL_SCOPE_QUEUE" }
local STATUS_KEY = { joined = "DUEL_RACER_JOINED", left = "DUEL_RACER_LEFT", racing = "DUEL_RACER_RACING",
  finished = "DUEL_RACER_FINISHED", dnf = "DUEL_RACER_DNF" }

local function mark(text, on) return on and ("|cffffd100> " .. text .. " <|r") or text end

H.RegisterView("duel", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  DU.view = v

  local title = W.Text(v, 18, L.DUEL_TITLE, W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", 4, -2)
  local back = W.Button(v, L.BACK, 90, 22, function()
    local E = DU.engine
    if E and E:InRace() then return end
    H.ShowView("home")
  end)
  back:SetPoint("TOPRIGHT", 0, 0)
  v.back = back

  ----------------------------------------------------------------------
  -- Setup + waiting room
  ----------------------------------------------------------------------
  local setup = CreateFrame("Frame", nil, v)
  setup:SetPoint("TOPLEFT", 0, -26)
  setup:SetPoint("BOTTOMRIGHT", 0, 0)
  v.setup = setup
  local intro = W.Text(setup, 11, L.DUEL_INTRO, W.WHITE, "LEFT")
  intro:SetPoint("TOPLEFT", 4, 0)
  intro:SetWidth(540)

  local subjLabel = W.Text(setup, 12, L.DUEL_SUBJECT, W.GOLD, "LEFT")
  subjLabel:SetPoint("TOPLEFT", 4, -44)
  v.subjectButtons = {}
  -- v0.11: up to 4 subjects per row; everything below moves down with the rows
  local subjects = D().Subjects()
  local perRow = #subjects > 6 and 4 or 3
  local bw = perRow == 4 and 134 or 176
  local rows = math.ceil(#subjects / perRow)
  local shift = math.max(0, rows * 23 - 50)
  for i, s in ipairs(subjects) do
    local b = W.Button(setup, "", bw, 21, function()
      DU.sel.subject = s.id
      v:Refresh()
    end, perRow == 4 and 10 or 11)
    b:SetPoint("TOPLEFT", subjLabel, "BOTTOMLEFT", -2 + ((i - 1) % perRow) * (bw + 4), -4 - math.floor((i - 1) / perRow) * 23)
    b.subject = s.id
    v.subjectButtons[#v.subjectButtons + 1] = b
  end
  local lenLabel = W.Text(setup, 12, L.DUEL_WHO, W.GOLD, "LEFT")
  lenLabel:SetPoint("TOPLEFT", 4, -144 - shift)
  v.lengthButtons = {}
  for i, n in ipairs(D().LENGTHS) do
    local b = W.Button(setup, "", 120, 22, function()
      DU.sel.length = n
      v:Refresh()
    end, 11)
    b:SetPoint("TOPLEFT", setup, "TOPLEFT", 2 + (i - 1) * 126, -114 - shift)
    b.length = n
    v.lengthButtons[i] = b
  end
  v.scopeButtons = {}
  for i, sc in ipairs(SCOPES) do
    local b = W.Button(setup, "", 132, 22, function()
      DU.sel.scope = sc
      v:Refresh()
    end, 11)
    b:SetPoint("TOPLEFT", lenLabel, "BOTTOMLEFT", -2 + (i - 1) * 137, -4)
    b.scope = sc
    v.scopeButtons[i] = b
  end
  local target = W.EditBox(setup, 220, 24, 13)
  target:SetPoint("TOPLEFT", lenLabel, "BOTTOMLEFT", 4, -32)
  target:SetMaxLetters(48)
  target:SetScript("OnTextChanged", function(self) DU.sel.target = self:GetText() or "" end)
  target:SetScript("OnEnterPressed", function(self) self:ClearFocus(); v:DoInvite() end)
  v.target = target
  local targetHint = W.Text(setup, 10, L.DUEL_TARGET_HINT, W.GRAY, "LEFT")
  targetHint:SetPoint("LEFT", target, "RIGHT", 10, 0)
  targetHint:SetWidth(300)
  v.targetHint = targetHint

  local action = W.Button(setup, L.DUEL_INVITE, 200, 28, function() v:DoInvite() end, 13)
  action:SetPoint("TOPLEFT", lenLabel, "BOTTOMLEFT", -2, -64)
  v.action = action
  local status = W.Text(setup, 11, "", W.AMBER, "LEFT")
  status:SetPoint("LEFT", action, "RIGHT", 10, 0)
  status:SetWidth(330)
  v.status = status

  -- waiting room
  local lobbyTitle = W.Text(setup, 13, L.DUEL_LOBBY, W.GOLD, "LEFT")
  lobbyTitle:SetPoint("TOPLEFT", action, "BOTTOMLEFT", 2, -12)
  v.lobbyTitle = lobbyTitle
  v.lobbyRows = {}
  for i = 1, D().MAX_RACERS do
    local fs = W.Text(setup, 12, "", W.WHITE, "LEFT")
    fs:SetPoint("TOPLEFT", lobbyTitle, "BOTTOMLEFT", 8, -4 - (i - 1) * 16)
    fs:SetWidth(360)
    v.lobbyRows[i] = fs
  end
  local start = W.Button(setup, L.DUEL_START, 150, 26, function()
    local okS, why = DU.engine:Start()
    if not okS then v.status:SetText(errText(why)) end
  end, 13)
  start:SetPoint("TOPRIGHT", setup, "TOPRIGHT", 0, -252 - shift)
  v.start = start
  local cancel = W.Button(setup, L.DUEL_CANCEL, 150, 24, function()
    DU.engine:Close()
    v:Refresh()
  end)
  cancel:SetPoint("TOP", start, "BOTTOM", 0, -6)
  v.cancel = cancel
  local stats = W.Text(setup, 10, "", W.GRAY, "LEFT")
  stats:SetPoint("BOTTOMLEFT", 4, 2)
  stats:SetWidth(540)
  v.stats = stats

  function v:DoInvite()
    local E = DU.Init()
    if not E then return end
    local sel = DU.sel
    if sel.scope == "QUEUE" then
      if E.queue then E:QueueLeave("left"); self:Refresh(); return end
      if not C.HasModernComms() then self.status:SetText(L.DUEL_QUEUE_OFF); return end
      local okQ, why = E:QueueJoin(sel.subject, sel.length)
      if not okQ then self.status:SetText(why == "parent" and L.DUEL_QUEUE_OFF or errText(why)) end
      self:Refresh()
      return
    end
    local d, err = E:Host(sel.subject, sel.length, sel.scope, sel.scope == "WHISPER" and sel.target or nil)
    if not d then self.status:SetText(errText(err)) else self.status:SetText("") end
    self:Refresh()
  end

  function v:RefreshSetup()
    local E = DU.engine
    local sel = DU.sel
    for _, b in ipairs(self.subjectButtons) do b:SetText(mark(D().SubjectName(b.subject), sel.subject == b.subject)) end
    for _, b in ipairs(self.lengthButtons) do b:SetText(mark(string.format(L.DUEL_LENGTH, b.length), sel.length == b.length)) end
    for _, b in ipairs(self.scopeButtons) do b:SetText(mark(L[SCOPE_KEY[b.scope]], sel.scope == b.scope)) end
    if sel.scope == "WHISPER" then
      self.target:Show(); self.targetHint:Show()
      if (self.target:GetText() or "") ~= sel.target then self.target:SetText(sel.target or "") end
    else
      self.target:Hide(); self.targetHint:Hide()
    end
    local d = E and E.duel
    local inLobby = d and d.state == "lobby"
    if sel.scope == "QUEUE" then
      self.action:SetText(E and E.queue and L.DUEL_QUEUE_LEAVE or L.DUEL_QUEUE_JOIN)
      if E and E.queue then
        local secs = math.floor(C.Now() - E.queue.since)
        self.status:SetText(string.format(L.DUEL_QUEUE_SEARCH, ns.Util.FormatDuration(secs)))
      elseif not dset().random then
        self.status:SetText(L.DUEL_QUEUE_OFF)
      end
    else
      self.action:SetText(L.DUEL_INVITE)
    end
    if inLobby then self.action:Disable() else self.action:Enable() end
    -- waiting room
    for i, fs in ipairs(self.lobbyRows) do
      local k = inLobby and d.order[i]
      local r = k and d.racers[k]
      if r then
        local name = D().DisplayFor(r, d.scope)
        if k == E.meKey then name = string.format(L.DUEL_RACER_YOU, name) end
        fs:SetText(name .. "  |cff888888" .. (L[STATUS_KEY[r.status] or ""] or r.status) .. "|r")
        fs:Show()
      else
        fs:SetText("")
      end
    end
    if inLobby then
      self.lobbyTitle:Show()
      self.cancel:Show()
      self.cancel:SetText(d.isHost and L.DUEL_CANCEL or L.DUEL_LEAVE)
      if d.isHost then
        self.start:Show()
        if E:Joined() >= D().MIN_RACERS then self.start:Enable() else self.start:Disable() end
        if E:Joined() < D().MIN_RACERS then self.status:SetText(string.format(L.DUEL_LOBBY_WAIT_JOIN, E:Joined(), D().MAX_RACERS)) end
      else
        self.start:Hide()
        self.status:SetText(L.DUEL_LOBBY_WAIT_HOST)
      end
    else
      self.lobbyTitle:Hide(); self.start:Hide(); self.cancel:Hide()
    end
    local cs = P().char.duel
    local al = dset().alias
    self.stats:SetText(string.format(L.DUEL_STATS, cs.played, cs.wins) .. "   " ..
      string.format(L.DUEL_ALIAS_INFO, D().AliasText(al[1], al[2])))
  end

  ----------------------------------------------------------------------
  -- Countdown + race
  ----------------------------------------------------------------------
  local race = CreateFrame("Frame", nil, v)
  race:SetPoint("TOPLEFT", 0, -26)
  race:SetPoint("BOTTOMRIGHT", 0, 0)
  v.race = race
  v.bars = {}
  for i = 1, D().MAX_RACERS do
    local name = W.Text(race, 11, "", W.WHITE, "LEFT")
    name:SetPoint("TOPLEFT", 4, -(i - 1) * 19)
    name:SetWidth(150)
    local bar = W.Bar(race, 390, 17, W.ARCANE)
    bar:SetPoint("TOPLEFT", 158, -(i - 1) * 19 + 2)
    v.bars[i] = { name = name, bar = bar }
  end
  local card = C.CreateFrame("Frame", nil, race, nil, true)
  card:SetPoint("TOPLEFT", 0, -100)
  card:SetPoint("TOPRIGHT", 0, -100)
  card:SetHeight(140)
  C.ApplyBackdrop(card, 0.07, 0.05, 0.13, 0.95, 0.55, 0.42, 0.95)
  local qhead = W.Text(card, 11, "", W.GRAY, "LEFT")
  qhead:SetPoint("TOPLEFT", 10, -8)
  v.qhead = qhead
  local icons = {}
  for i = 1, 20 do
    local t = card:CreateTexture(nil, "ARTWORK")
    t:SetSize(22, 22)
    t:SetPoint("TOPLEFT", card, "TOP", -130 + ((i - 1) % 10) * 26, -24 - math.floor((i - 1) / 10) * 26)
    t:Hide()
    icons[i] = t
  end
  v.icons = icons
  local qtext = W.Text(card, 16, "", W.WHITE, "CENTER")
  qtext:SetWidth(520)
  v.qtext = qtext
  -- v1.2 World Tongues co-op: hear the partner's line (the line is also written on the card)
  local playBtn = W.Button(card, L.WT_REPLAY, 90, 22, function() v:PlayClip() end, 12)
  playBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -4)
  playBtn:Hide()
  v.playBtn = playBtn
  function v:PlayClip()
    local E = DU.engine
    local p = E and E:Current()
    local TA = ns.TonguesAudio
    local clip = p and p.audioFile and TA and TA.ByFile(p.audioFile)
    local played = clip and C.PlayTongue(clip) or false
    if not played and not (clip and TA.Available()) then playBtn:Hide() end
    return played
  end
  -- v0.11: Gnomish Engineering grid puzzles
  local grid = W.Grid(card, 6, 18)
  grid:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -24)
  v.grid = grid
  local big = W.Text(race, 48, "", W.GOLD, "CENTER")
  big:SetPoint("CENTER", card, "CENTER", 0, 0)
  v.big = big

  v.choices = {}
  for i = 1, 4 do
    local b = W.Button(race, "", 262, 34, function(self) v:Answer(self.value) end, 13)
    b:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 8 + ((i - 1) % 2) * 270, -8 - math.floor((i - 1) / 2) * 38)
    b:Hide()
    v.choices[i] = b
  end
  local typeBox = W.EditBox(race, 420, 28, 14)
  typeBox:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 10, -12)
  typeBox:SetMaxLetters(200)
  typeBox:SetScript("OnEnterPressed", function(self) v:Answer(self:GetText() or "") end)
  typeBox:Hide()
  v.typeBox = typeBox
  local typeGo = W.Button(race, L.DUEL_SUBMIT, 100, 28, function() v:Answer(typeBox:GetText() or "") end)
  typeGo:SetPoint("LEFT", typeBox, "RIGHT", 10, 0)
  typeGo:Hide()
  v.typeGo = typeGo
  local feedback = W.Text(race, 12, "", W.GREEN, "LEFT")
  feedback:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 6, -90)
  feedback:SetWidth(400)
  v.feedback = feedback
  local leave = W.Button(race, L.DUEL_LEAVE, 120, 22, function()
    DU.engine:Leave("left")
  end)
  leave:SetPoint("BOTTOMRIGHT", 0, 0)
  v.leave = leave

  function v:Answer(given)
    local E = DU.engine
    if not E or not E:Current() then return end
    local okA, info, p = E:Answer(given)
    if okA == nil then return end
    if p.mode == "typing" then
      self.typeBox:SetText("")
      local wpm, acc = info and info.wpm or 0, info and math.floor((info.accuracy or 0) * 100 + 0.5) or 0
      self.feedback:SetText((okA and L.DUEL_RIGHT or "") .. " " .. string.format(L.DUEL_TYPED, wpm, acc))
    elseif okA then
      self.feedback:SetText(L.DUEL_RIGHT)
    else
      self.feedback:SetText(string.format(L.DUEL_WRONG, tostring(ns.Modules.FormatAnswer(p))))
    end
    self.feedback:SetTextColor(unpack(okA and W.GREEN or W.AMBER))
    C.Sound(okA and "correct" or "wrong")
    self:Refresh()
  end

  function v:ShowQuestion()
    local E = DU.engine
    local p, idx = E:Current()
    local d = E.duel
    for _, b in ipairs(self.choices) do b:Hide() end
    self.typeBox:Hide(); self.typeGo:Hide()
    for _, t in ipairs(self.icons) do t:Hide() end
    self.grid:Hide()
    self.qtext:SetWidth(520)
    self.qtext:SetJustifyH("CENTER")
    if not p then
      self.qhead:SetText("")
      self.qtext:SetText(d and d.state == "race" and L.DUEL_WAITING or "")
      self.qtext:ClearAllPoints()
      self.qtext:SetPoint("CENTER", card, "CENTER", 0, 0)
      self.playBtn:Hide()
      return
    end
    if self.shownIdx ~= idx then
      self.shownIdx = idx
      if p.audioFile then self:PlayClip() end
    end
    local TA = ns.TonguesAudio
    if p.audioFile and TA and TA.Available() and TA.ByFile(p.audioFile) then self.playBtn:Show() else self.playBtn:Hide() end
    self.qhead:SetText(string.format(L.DUEL_QUESTION, idx, d.length))
    local count = p.icons and p.icons.count or 0
    for i, t in ipairs(self.icons) do
      if i <= count then t:SetTexture(p.icons.texture); t:Show() end
    end
    self.qtext:ClearAllPoints()
    if p.grid then
      self.grid:Draw(p.grid)
      local gw = self.grid:GetWidth()
      self.qtext:SetWidth(520 - gw - 10)
      self.qtext:SetPoint("TOPLEFT", card, "TOPLEFT", 10 + gw + 14, -28)
    else
      self.qtext:SetPoint("TOP", card, "TOP", 0, count > 0 and -(24 + (count > 10 and 52 or 26) + 4) or -28)
    end
    if p.code then self.qtext:SetJustifyH("LEFT") end
    if p.mode == "typing" then
      self.qtext:SetText(L.DUEL_TYPE_PROMPT .. "\n|cffffd100" .. tostring(p.typingTarget or p.answer) .. "|r")
      self.typeBox:Show(); self.typeGo:Show()
      self.typeBox:SetFocus()
    else
      self.qtext:SetText(p.text)
      local pm = ns.Modules.Get(p.moduleId or "")
      local font = pm and pm.courseFont and C.CourseFont() or C.FONT
      W.SetFontFace(self.qtext, font, 16)
      local longest = 0
      for _, val in ipairs(p.choices) do longest = math.max(longest, #tostring(val)) end
      for i, val in ipairs(p.choices) do
        local b = self.choices[i]
        if b then
          b.value = val
          b:SetText(type(val) == "number" and ns.Util.Commas(val) or tostring(val))
          W.SetButtonFontFace(b, font, longest > 44 and 10 or (longest > 30 and 11 or 13))
          W.ButtonWrap(b, longest > 30 and 250 or nil)
          b:Show()
        end
      end
    end
  end

  function v:RefreshRace()
    local E = DU.engine
    local d = E and E.duel
    if not d then return end
    for i, row in ipairs(self.bars) do
      local k = d.order[i]
      local r = k and d.racers[k]
      if r then
        local name = D().DisplayFor(r, d.scope)
        if k == E.meKey then name = "|cffffd100" .. string.format(L.DUEL_RACER_YOU, name) .. "|r" end
        row.name:SetText(name)
        local label = string.format("%d / %d", r.answered or 0, d.length)
        if r.status == "left" then label = L.DUEL_RACER_LEFT
        elseif r.valid == false then label = L.DUEL_RACER_INVALID
        elseif r.status == "finished" then label = label .. "  " .. L.DUEL_RACER_FINISHED end
        row.bar:SetProgress((r.answered or 0) / d.length, label)
        row.name:Show(); row.bar:Show()
      else
        row.name:Hide(); row.bar:Hide()
      end
    end
    if d.state == "countdown" then
      for _, b in ipairs(self.choices) do b:Hide() end
      self.typeBox:Hide(); self.typeGo:Hide()
      self.qtext:SetText(""); self.qhead:SetText("")
      self.feedback:SetText("")
    else
      self:ShowQuestion()
    end
  end

  ----------------------------------------------------------------------
  -- Results
  ----------------------------------------------------------------------
  local result = CreateFrame("Frame", nil, v)
  result:SetPoint("TOPLEFT", 0, -26)
  result:SetPoint("BOTTOMRIGHT", 0, 0)
  v.result = result
  local winner = W.Text(result, 16, "", W.GOLD, "LEFT")
  winner:SetPoint("TOPLEFT", 4, -2)
  winner:SetWidth(540)
  v.winner = winner
  v.rows, v.blockBtns = {}, {}
  for i = 1, D().MAX_RACERS do
    local fs = W.Text(result, 12, "", W.WHITE, "LEFT")
    fs:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 22)
    fs:SetWidth(460)
    v.rows[i] = fs
    local bb = W.Button(result, L.DUEL_BLOCK, 64, 18, function(self)
      if self.racerName then
        DU.Block(self.racerName, self.display)
        self:Hide()
      end
    end, 10)
    bb:SetPoint("TOPRIGHT", result, "TOPRIGHT", 0, -28 - (i - 1) * 22)
    bb:Hide()
    v.blockBtns[i] = bb
  end
  local reward = W.Text(result, 12, "", W.GREEN, "LEFT")
  reward:SetPoint("TOPLEFT", 8, -148)
  reward:SetWidth(540)
  v.reward = reward
  local partial = W.Text(result, 10, "", W.AMBER, "LEFT")
  partial:SetPoint("TOPLEFT", reward, "BOTTOMLEFT", 0, -4)
  partial:SetWidth(540)
  v.partial = partial
  v.emoteBtns = {}
  for i, key in ipairs(D().EMOTES) do
    local b = W.Button(result, L[key], 128, 24, function()
      if DU.engine and DU.engine:Emote(i) then
        v:ShowEmote(string.format(L.DUEL_EMOTE_SAYS, L.DUEL_YOU, L[key]))
      end
    end, 11)
    b:SetPoint("TOPLEFT", result, "TOPLEFT", 4 + (i - 1) * 136, -200)
    v.emoteBtns[i] = b
  end
  local emoteFeed = W.Text(result, 12, "", W.ARCANE, "LEFT")
  emoteFeed:SetPoint("TOPLEFT", 8, -232)
  emoteFeed:SetWidth(540)
  v.emoteFeed = emoteFeed
  local again = W.Button(result, L.DUEL_REMATCH, 140, 26, function()
    if DU.engine then DU.engine:Close() end
    v:SetMode("setup")
  end)
  again:SetPoint("BOTTOMLEFT", 0, 0)
  local done = W.Button(result, L.DUEL_BACK, 140, 26, function()
    if DU.engine then DU.engine:Close() end
    H.ShowView("home")
  end)
  done:SetPoint("BOTTOMRIGHT", 0, 0)

  function v:ShowEmote(text)
    self.emoteLines = self.emoteLines or {}
    table.insert(self.emoteLines, text)
    while #self.emoteLines > 3 do table.remove(self.emoteLines, 1) end
    self.emoteFeed:SetText(table.concat(self.emoteLines, "\n"))
  end

  function v:RefreshResult()
    local E = DU.engine
    local d = E and E.duel
    if not d or not d.ranked then return end
    local typing = D().SUBJECT_BY_ID[d.subject] and D().SUBJECT_BY_ID[d.subject].typing
    local top = d.ranked[1]
    local tie = d.ranked[2] and d.ranked[2].rank == 1
    self.winner:SetText(tie and L.DUEL_TIE or string.format(L.DUEL_WINNER, top and top.display or "?"))
    if d.team then self.winner:SetText(string.format(L.DUEL_PB_TEAM, d.team.correct, d.team.total)) end
    for i, fs in ipairs(self.rows) do
      local r = d.ranked[i]
      local bb = self.blockBtns[i]
      bb:Hide()
      if r then
        local name = r.isMe and string.format(L.DUEL_RACER_YOU, r.display) or r.display
        local tail
        if r.status == "left" then tail = L.DUEL_RACER_LEFT
        elseif r.valid == false then tail = L.DUEL_RACER_INVALID
        elseif r.status == "dnf" then tail = L.DUEL_RACER_DNF
        else tail = ns.Util.FormatDuration(math.floor((r.time or 0) + 0.5)) end
        if typing then
          fs:SetText(string.format(L.DUEL_ROW_TYPING, r.rank, name, r.correct or 0, d.length, tail, r.wpm or 0, r.acc or 0))
        else
          fs:SetText(string.format(L.DUEL_ROW, r.rank, name, r.correct or 0, d.length, tail))
        end
        if not r.isMe then
          bb.racerName, bb.display = r.name, r.display
          if not DU.IsBlocked(r.name) then bb:Show() end
        end
      else
        fs:SetText("")
      end
    end
    local rw = d.reward or {}
    if (rw.minutesGot or 0) > 0 then
      self.reward:SetText(string.format(L.DUEL_REWARD_MIN, rw.shardsGot or 0, rw.minutesGot))
    elseif (rw.shardsGot or 0) > 0 then
      self.reward:SetText(string.format(L.DUEL_REWARD, rw.shardsGot))
    else
      self.reward:SetText(L.DUEL_REWARD_NONE)
    end
    self.partial:SetText(d.partial and L.DUEL_PARTIAL or "")
  end

  ----------------------------------------------------------------------
  -- Mode switching
  ----------------------------------------------------------------------
  function v:SetMode(mode)
    local E = DU.engine
    local d = E and E.duel
    if mode == "race" and not (d and (d.state == "countdown" or d.state == "race")) then mode = "setup" end
    if mode == "result" and not (d and d.state == "done") then mode = "setup" end
    self.mode = mode
    self.setup:Hide(); self.race:Hide(); self.result:Hide()
    if mode == "race" then
      self.feedback:SetText("")
      self.race:Show()
    elseif mode == "result" then
      self.emoteLines = {}
      self.emoteFeed:SetText("")
      self.result:Show()
    else
      self.setup:Show()
    end
    self:Refresh()
  end

  function v:Refresh()
    if self.mode == "race" then self:RefreshRace()
    elseif self.mode == "result" then self:RefreshResult()
    else self:RefreshSetup() end
    local E = DU.engine
    if E and E:InRace() then self.back:Disable() else self.back:Enable() end
  end

  -- every DU.TICK: countdown numbers, queue timer
  function v:Tick()
    local E = DU.engine
    local d = E and E.duel
    if self.mode == "race" and d then
      if d.state == "countdown" then
        local n = math.max(1, math.ceil(d.startAt - C.Now()))
        if DU.lastCount ~= n then
          DU.lastCount = n
          self.big:SetText(tostring(n))
          C.Sound("countdown")
          self:RefreshRace()
        end
      elseif d.state == "race" then
        if DU.lastCount ~= 0 then
          DU.lastCount = 0
          self.big:SetText(L.DUEL_COUNT_GO)
          local goText = self.big
          C.After(0.6, function() goText:SetText("") end)
          self:RefreshRace()
        end
      elseif d.state == "done" then
        self:SetMode("result")
      end
    elseif self.mode == "setup" and E and E.queue then
      self:RefreshSetup()
    end
  end

  function v:OnShowView(mode)
    DU.Init()
    self:SetMode(mode or self.mode or "setup")
  end
  return v
end)

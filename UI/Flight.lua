-- In-Flight Lessons (v0.7): watches for flight paths and offers Fizzwick's quick round.
-- The rules (once per flight, combat, instances, cap, mode) live in Core/Flight.lua;
-- this file feeds it the taxi state and shows the toast / starts the round.
-- Source of truth is UnitOnTaxi (via Compat), polled twice a second. Control-lost /
-- control-gained style events only trigger an extra check sooner.
local _, ns = ...
local C, W, L = ns.Compat, ns.W, ns.L
local F = ns.Flight

local FU = {}
ns.FlightUI = FU

FU.tracker = F.NewTracker()
FU.SIM_SECONDS = 120 -- "/aa flight test" pretends to fly this long (or until "/aa flight land")
FU.lastSkip = nil     -- reason of the last silent skip (debug / tests)

local function settings() return ns.Progress and ns.Progress.account and ns.Progress.account.settings end

function FU.Mode() return F.Mode(settings()) end

function FU.SetMode(mode)
  local s = settings()
  if not (s and F.ValidMode(mode)) then return false end
  if type(s.flight) ~= "table" then s.flight = {} end
  s.flight.mode = mode
  return true
end

-- Cycle off -> toast -> auto -> off (Parent Panel button).
function FU.CycleMode()
  local cur, list = FU.Mode(), F.MODES
  for i, m in ipairs(list) do
    if m == cur then FU.SetMode(list[i % #list + 1]) return FU.Mode() end
  end
  FU.SetMode(F.DEFAULT_MODE)
  return FU.Mode()
end

function FU.ModeName(mode) return L["FLIGHT_MODE_" .. (mode or FU.Mode()):upper()] end

-- Real taxi, or the "/aa flight test" pretend flight.
function FU.OnTaxi()
  if FU.simUntil then
    if C.Now() < FU.simUntil then return true end
    FU.simUntil = nil
  end
  return C.OnTaxi()
end

function FU.CanOfferAnother() return F.CanOfferAnother(FU.tracker) end

function FU.Context()
  local P = ns.Progress
  local earned, cap = P.GetTodayMinutes()
  local H = ns.Hub
  return {
    mode = FU.Mode(),
    inCombat = C.InCombat(),
    inInstance = C.InInstance(),
    academyOpen = (H and (H.IsShown() or H.hiddenByCombat)) and true or false,
    hasBand = P.GetBand() ~= nil,
    capReached = F.CapReached(earned, cap),
    test = FU.testing,
  }
end

-- Toast ---------------------------------------------------------------------------
local function headIcon()
  if ns.MinimapButton and ns.MinimapButton.IconPath then return (ns.MinimapButton.IconPath()) end
  return ns.Guide.CAST.fizzwick.icon
end

function FU.BuildToast()
  if FU.toast then return FU.toast end
  local t = C.CreateFrame("Frame", "AzerothAcademyFlightToast", UIParent, nil, true)
  t:SetSize(380, 112)
  t:SetPoint("TOP", UIParent, "TOP", 0, -190)
  t:SetFrameStrata("HIGH")
  C.ApplyBackdrop(t, 0.06, 0.04, 0.14, 0.95, 0.62, 0.48, 1, 1)
  local icon = t:CreateTexture(nil, "ARTWORK")
  icon:SetSize(52, 52)
  icon:SetPoint("TOPLEFT", 12, -12)
  if icon:SetTexture(headIcon()) == false then icon:SetTexture(ns.Guide.CAST.fizzwick.icon) end
  t.icon = icon
  local title = W.Text(t, 14, L.FLIGHT_TITLE, W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
  t.title = title
  local msg = W.Text(t, 11, "", W.WHITE, "LEFT")
  msg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  msg:SetWidth(290)
  t.msg = msg
  local start = W.Button(t, L.FLIGHT_START, 96, 22, function() FU.StartQuickRound() end)
  start:SetPoint("BOTTOMLEFT", 12, 10)
  local later = W.Button(t, L.FLIGHT_NOTNOW, 96, 22, function() FU.HideToast() end)
  later:SetPoint("LEFT", start, "RIGHT", 6, 0)
  local mute = W.Button(t, L.FLIGHT_MUTE, 150, 22, function()
    F.Mute(FU.tracker)
    FU.HideToast()
    C.Print(L.FLIGHT_MUTED)
  end, 10)
  mute:SetPoint("LEFT", later, "RIGHT", 6, 0)
  t.start, t.later, t.mute = start, later, mute
  -- an ignored toast fades away by itself (OnUpdate, so it works with or without C_Timer)
  t:SetScript("OnUpdate", function(self, elapsed)
    self.left = (self.left or 0) - (elapsed or 0)
    if self.left <= 0 then FU.HideToast() end
  end)
  t:Hide()
  FU.toast = t
  return t
end

function FU.ShowToast()
  local t = FU.BuildToast()
  local text, key
  if ns.GuideUI then text, key = ns.GuideUI.PickLine("FLIGHTSTART") else text = ns.Guide.Line("FLIGHTSTART") end
  t.msg:SetText(text or L.FLIGHT_PROMPT)
  t.left = F.TOAST_SECONDS
  t:Show()
  C.Sound("flight")
  if ns.GuideUI and text then ns.GuideUI.Speak("FLIGHTSTART", key) end
end

function FU.HideToast()
  if FU.toast and FU.toast:IsShown() then FU.toast:Hide() end
end

-- The quick round: due reviews first, otherwise the recommended skill of the subject
-- opened last, 5 problems. Placement still comes first for a brand-new subject.
function FU.StartQuickRound()
  FU.HideToast()
  if C.InCombat() then C.Print(L.NO_COMBAT) return false end
  local H, RF, P = ns.Hub, ns.Lessons, ns.Progress
  H.Open("home")
  if not H.IsShown() then return false end
  local band = P.GetBand()
  if not band then return false end -- Open() showed the profile screen
  local s = settings()
  if s.reviews ~= false and #ns.Review.Due() > 0 then
    RF.StartReview({ flight = true })
  else
    local module = RF.CurrentModule()
    if ns.Trial.NeedsPlacement(module.id, band) then
      H.ShowView("trial", "placement")
      return true
    end
    local prefer = type(module.flightNodes) == "table" and module.flightNodes[band] or nil
    local nodeId, tier = ns.Mastery.Recommend(band, module.id, prefer)
    if not nodeId then return false end
    RF.StartRound(nodeId, tier, { size = F.ROUND_SIZE, flight = true })
  end
  if ns.GuideUI and RF.session then
    -- v0.9: a subject can bring its own sky line (Naturalist: "every zone below is a habitat")
    local m = RF.session.module
    ns.GuideUI.Say((m and m.flightEvent) or "FLIGHTSTART")
  end
  return RF.session ~= nil
end

function FU.AnotherRound()
  if not FU.CanOfferAnother() then return false end
  return FU.StartQuickRound()
end

-- Takeoff / landing ----------------------------------------------------------------
function FU.OnLanded()
  FU.HideToast()
  FU.simUntil = nil
  FU.testing = nil
  local H = ns.Hub
  if not (H and H.IsShown()) then return end -- hidden (or hidden for combat): never reopen anything
  if H.current == "reward" then
    local v = H.GetView("reward")
    if v and v.UpdateFlight then v:UpdateFlight() end
    if v and v.summary and v.summary.flight and ns.GuideUI then ns.GuideUI.Say("FLIGHTLAND") end
  elseif H.current == "problem" and ns.Lessons.session and ns.Lessons.session.flight then
    -- keep the round open: finish it on the ground, nothing lost
    if ns.GuideUI then ns.GuideUI.Say("FLIGHTLAND") end
  end
end

local function explainSkip(reason)
  local key = "FLIGHT_SKIP_" .. tostring(reason):upper()
  if L[key] then C.Print(L[key]) end
end

function FU.Check()
  if not ns.ready then return end
  local tr = FU.tracker
  local now = C.Now()
  local edge = F.Update(tr, FU.OnTaxi(), now)
  if edge == "landed" then FU.OnLanded() return end
  if not tr.onTaxi or tr.offered then return end
  local decision, reason = F.Decide(tr, now, FU.Context())
  if decision == "wait" then return end
  F.MarkOffered(tr)
  if decision == "skip" then
    FU.lastSkip = reason
    if FU.testing then explainSkip(reason) end
  elseif decision == "toast" then
    FU.ShowToast()
  elseif decision == "auto" then
    FU.StartQuickRound()
  end
end

-- "/aa flight test": pretend we just took off (no flying needed).
function FU.Test()
  local tr = FU.tracker
  tr.onTaxi = false -- next check sees a fresh takeoff, even on a real flight
  tr.muted = false
  FU.testing = true
  FU.simUntil = C.Now() + FU.SIM_SECONDS
  FU.Check()
end

-- "/aa flight land": end the pretend flight now.
function FU.Land()
  FU.simUntil = nil
  FU.Check()
  if FU.tracker.onTaxi then return false end
  return true
end

-- Watcher frame: poll + optional events.
local watcher = CreateFrame("Frame", "AzerothAcademyFlightWatch")
FU.watcher = watcher
FU.events = C.RegisterEvents(watcher, C.TAXI_EVENTS)
local elapsedSum = 0
watcher:SetScript("OnUpdate", function(_, elapsed)
  elapsedSum = elapsedSum + (elapsed or 0)
  if elapsedSum < (C.settings.flightPoll or 0.5) then return end
  elapsedSum = 0
  FU.Check()
end)
watcher:SetScript("OnEvent", function()
  FU.Check()
  -- UnitOnTaxi can lag the control event by a moment: look again shortly
  C.After(0.5, FU.Check)
end)

-- v1.1: language switch -> the flight toast is rebuilt in the new language on its next use
if ns.Hub and ns.Hub.OnRebuild then
  ns.Hub.OnRebuild(function()
    if FU.toast then FU.toast:Hide() end
    FU.toast = nil
  end)
end

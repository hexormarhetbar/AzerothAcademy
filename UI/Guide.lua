-- Professor Fizzwick's strip at the bottom of the Hub, Sprocket the parrot's hints,
-- the faction leader cameo card and the rank-up celebration.
-- Every character is shown with an in-game model loaded at runtime (PlayerModel +
-- creature display IDs) and falls back to an in-client icon.
-- v0.8: some lines are also spoken (Core/Voice.lua decides which and when).
local _, ns = ...
local C, W = ns.Compat, ns.W
local L = ns.L

local GU = {}
ns.GuideUI = GU

GU.STRIP_HEIGHT = 78
GU.missingArt = {} -- art files the client refused to load this session (v0.5)
GU.TALK_STEP = 0.12
GU.TALK_STEPS = 10
GU.voice = ns.Voice.NewState()

local function accountSettings() return ns.Progress and ns.Progress.account and ns.Progress.account.settings end

-- Play the recording for (event, key) if the rules allow it. Returns true if it started.
function GU.Speak(event, key)
  local V = ns.Voice
  local now = C.Now()
  local clip = V.Decide(GU.voice, event, key, now, accountSettings())
  if not clip then return false end
  if C.PlayVoice(V.Path(clip), clip.big) then
    V.Started(GU.voice, event, clip, now)
    GU.lastVoice = clip.file
    return true
  end
  GU.voice.missing[clip.file] = true -- file refused: don't try it again this session
  return false
end

-- A Fizzwick line for an event: the recorded line goes first once per session.
function GU.PickLine(event, ...)
  local key = ns.Voice.PreferKey(GU.voice, event, accountSettings(), C.Now())
  if key then
    local text, k = ns.Guide.LineKey(key, ...)
    if text then return text, k end
  end
  return ns.Guide.Line(event, ...)
end

-- Spoken goodbye when the kid closes the Academy (no bubble: the window is closing).
function GU.Goodbye()
  return GU.Speak("BYE", "FZ_BYE_1")
end

local function settings()
  local a = ns.Progress and ns.Progress.account
  return a and a.settings or {}
end

-- A portrait slot: a model when possible, otherwise the cast icon.
local function portrait(parent, w, h, zoom, noModel)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(w, h)
  local icon = holder:CreateTexture(nil, "ARTWORK")
  icon:SetSize(math.min(w, h) - 14, math.min(w, h) - 14)
  icon:SetPoint("CENTER")
  icon:Hide()
  holder.icon = icon
  -- v0.5: optional custom portrait (Media/Art, listed in Media/Art/Manifest.lua)
  local art = holder:CreateTexture(nil, "ARTWORK")
  art:SetSize(math.min(w, h), math.min(w, h))
  art:SetPoint("CENTER")
  art:Hide()
  holder.art = art
  holder.model = (not noModel) and C.CreateModel(holder, w, h) or nil
  if holder.model then holder.model:SetAllPoints(holder) end
  -- Show a texture from Media/Art. Returns false (and remembers it) if the client refuses it.
  function holder:ShowArt(path, name)
    if self.art:SetTexture(path) == false then
      GU.missingArt[name or path] = true
      return false
    end
    if self.art.SetTexCoord then self.art:SetTexCoord(0, 1, 0, 1) end
    if self.model then self.model:Hide() end
    self.icon:Hide()
    self.art:Show()
    self.mode, self.artName, self.cast = "art", name, nil
    return true
  end
  function holder:ShowCast(cast)
    self.cast = cast
    self.art:Hide()
    self.artName = nil
    local function useIcon()
      if self.cast ~= cast then return end
      if self.model then self.model:Hide() end
      self.icon:SetTexture(cast.icon)
      self.icon:Show()
      self.mode = "icon"
    end
    if self.model and (cast.displays or cast.creatures) then
      self.icon:Hide()
      self.model:Show()
      self.mode = "model"
      if C.SetModel(self.model, cast, useIcon) then
        C.PortraitCamera(self.model, zoom)
        return
      end
    end
    useIcon()
  end
  -- Some clients drop a model that was set while hidden; re-apply when shown.
  holder:SetScript("OnShow", function(self)
    if self.cast and self.mode == "model" then self:ShowCast(self.cast) end
  end)
  return holder
end
GU.Portrait = portrait

------------------------------------------------------------------------
-- Guide strip (lives on the Hub frame, under the content area)
------------------------------------------------------------------------
function GU.Attach(hubFrame)
  if GU.strip then return GU.strip end
  local s = C.CreateFrame("Frame", nil, hubFrame, nil, true)
  s:SetPoint("BOTTOMLEFT", 14, 12)
  s:SetPoint("BOTTOMRIGHT", -14, 12)
  s:SetHeight(GU.STRIP_HEIGHT)
  C.ApplyBackdrop(s, 0.10, 0.07, 0.03, 0.92, 0.85, 0.65, 0.25)

  s.face = portrait(s, 72, 72)
  s.face:SetPoint("LEFT", 4, 0)
  s.name = W.Text(s, 11, L.FZ_NAME, W.GOLD, "LEFT")
  s.name:SetPoint("TOPLEFT", s.face, "TOPRIGHT", 8, -6)
  s.text = W.Text(s, 13, "", W.WHITE, "LEFT")
  s.text:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -3)
  s.text:SetWidth(400)
  -- Sprocket, the mechanical parrot that delivers hints
  s.parrot = s:CreateTexture(nil, "ARTWORK")
  s.parrot:SetSize(30, 30)
  s.parrot:SetPoint("RIGHT", -12, 0)
  s.parrot:SetTexture(ns.Guide.CAST.parrot.icon)
  s.parrot:SetAlpha(0.45)
  GU.strip = s
  GU.ApplyParrotArt("curious")

  GU.ApplyFace("GREET")
  s.text:SetText(L.FZ_INTRO)
  return s
end

local function manifest() return ns.ArtManifest end

-- Put Fizzwick's art for a pose into any portrait slot. small = use the 256 head crops.
-- Falls back pose -> greet -> in-game model -> icon (allowModel = false hides instead).
function GU.ShowPose(holder, pose, small, allowModel)
  if not holder then return nil end
  for _ = 1, 4 do
    local path, name, used = ns.Art.Fizzwick(pose, manifest(), GU.missingArt, small)
    if not path then break end
    if holder.mode == "art" and holder.artName == name then holder.pose = used; return "art" end
    if holder:ShowArt(path, name) then holder.pose = used; return "art" end
  end
  holder.pose = nil
  if allowModel == false then
    holder.art:Hide()
    holder.mode, holder.artName = "none", nil
    return "none"
  end
  if (holder.mode ~= "model" and holder.mode ~= "icon") or holder.cast ~= ns.Guide.CAST.fizzwick then
    holder:ShowCast(ns.Guide.CAST.fizzwick)
  end
  return holder.mode
end

-- v1.0: a host portrait (Zixi, Quill). Art when shipped, else the placeholder.
function GU.ShowHost(holder, id, small)
  local host = holder and ns.Art.HOSTS[id or ""]
  if not host then return nil end
  for _ = 1, 3 do
    local path, name = ns.Art.Host(id, manifest(), GU.missingArt, small)
    if not path then break end
    if holder.mode == "art" and holder.artName == name then return "art" end
    if holder:ShowArt(path, name) then holder.host = id; return "art" end
  end
  holder.host = id
  if (holder.mode ~= "model" and holder.mode ~= "icon") or holder.cast ~= host.cast then holder:ShowCast(host.cast) end
  return holder.mode
end

-- A large full-figure Fizzwick (512 art) for reward / result / rank-up screens.
-- Art only: without art files it stays hidden so the v0.5 layouts are unchanged.
function GU.Hero(parent, size)
  local h = portrait(parent, size, size, nil, true)
  h:Hide()
  return h
end

function GU.ShowHero(holder, pose)
  if not holder then return nil end
  local mode = GU.ShowPose(holder, pose, false, false)
  if mode == "art" then
    holder:Show()
    if not W.ReducedMotion() then W.Reveal(holder.art, 0.5) end
  else
    holder:Hide()
  end
  return mode
end

-- Fizzwick's face in the strip for a guide event (or an explicit pose).
function GU.ApplyFace(event, pose)
  local s = GU.strip
  if not s then return end
  return GU.ShowPose(s.face, pose or ns.Art.PoseFor(event), true)
end

-- Switch the strip pose without a new line (worked example, personal best, idle...).
function GU.Pose(pose)
  GU.talkToken = nil
  GU.idleToken = nil
  return GU.ApplyFace(nil, pose)
end

-- Sprocket: "curious" while a hint is available, "squawk" while delivering one.
-- Without art he stays the gear icon.
function GU.ApplyParrotArt(state)
  local s = GU.strip
  if not s then return end
  for _ = 1, 4 do
    local path, name, used = ns.Art.Sprocket(state or "curious", manifest(), GU.missingArt, true)
    if not path then break end
    if s.parrot:SetTexture(path) ~= false then
      s.parrot:SetSize(56, 56)
      s.parrotArt, s.parrotState = true, used
      return true
    end
    GU.missingArt[name] = true
  end
  s.parrot:SetTexture(ns.Guide.CAST.parrot.icon)
  s.parrot:SetSize(30, 30)
  s.parrotArt, s.parrotState = false, nil
  return false
end

-- A problem is on screen. Sprocket looks curious when a hint can be asked for; after a
-- moment Fizzwick goes back to work on something that fits the subject (idle pose).
GU.IDLE_DELAY = 2.5
function GU.ProblemShown(moduleId, hintAvailable)
  local s = GU.strip
  if not s then return end
  GU.ApplyParrotArt("curious")
  s.parrot:SetAlpha(hintAvailable and 0.9 or 0.3)
  local token = {}
  GU.idleToken = token
  local pose = ns.Art.IdlePose(moduleId)
  C.After(GU.IDLE_DELAY, function()
    if GU.idleToken == token and not GU.talkToken then GU.ApplyFace(nil, pose) end
  end)
  return pose
end

-- Optional talk animation from fizzwick_strip (skipped with reduced motion).
function GU.Talk(event)
  local s = GU.strip
  local strip = ns.Art.Strip(manifest(), GU.missingArt)
  if not (s and strip) or W.ReducedMotion() then return false end
  if not s.face:ShowArt(strip.path, strip.name) then return false end
  local token = {}
  GU.talkToken = token
  local art = s.face.art
  for i = 1, GU.TALK_STEPS do
    C.After(GU.TALK_STEP * i, function()
      if GU.talkToken ~= token then return end
      if i == GU.TALK_STEPS then
        GU.talkToken = nil
        s.face.artName = nil
        GU.ApplyFace(event)
      elseif art.SetTexCoord then
        art:SetTexCoord(unpack(strip.coords[(i - 1) % strip.frames + 1]))
      end
    end)
  end
  if art.SetTexCoord then art:SetTexCoord(unpack(strip.coords[1])) end
  return true
end

-- Speak a line as Fizzwick (event from ns.Guide.EVENTS). Returns the text said.
function GU.Say(event, ...)
  local s = GU.strip
  local text, key = GU.PickLine(event, ...)
  if not (s and text) then return text end
  GU.Speak(event, key)
  s.name:SetText(L.FZ_NAME)
  s.name:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
  s.text:SetText(text)
  if s.parrotState == "squawk" then GU.ApplyParrotArt("curious") end
  s.parrot:SetAlpha(0.45)
  GU.talkToken = nil
  GU.idleToken = nil
  if not GU.Talk(event) then GU.ApplyFace(event) end
  GU.lastSpeaker, GU.lastText, GU.lastEvent = "fizzwick", text, event
  return text
end

-- Sprocket squawks a hint while Fizzwick points at the board (teaching pose).
function GU.Parrot(hint)
  local s = GU.strip
  local text = ns.Guide.Line("HINT", hint or "")
  if not (s and text) then return text end
  s.name:SetText(L.FZ_PARROT)
  s.name:SetTextColor(W.ARCANE[1], W.ARCANE[2], W.ARCANE[3])
  s.text:SetText(text)
  GU.ApplyParrotArt("squawk")
  s.parrot:SetAlpha(1)
  GU.Pose("teaching")
  if not W.ReducedMotion() then W.Sparks(s.parrot:GetParent(), 5, W.ARCANE) end
  C.Sound("hint")
  GU.Speak("HINT", nil)
  GU.lastSpeaker, GU.lastText, GU.lastEvent = "parrot", text, "HINT"
  return text
end

------------------------------------------------------------------------
-- Faction leader cameo card
------------------------------------------------------------------------
local function buildCameo()
  local hub = ns.Hub.frame
  local f = C.CreateFrame("Frame", "AzerothAcademyCameo", hub, nil, true)
  f:SetSize(400, 170)
  f:SetPoint("CENTER", hub, "CENTER", 0, 20)
  f:SetFrameStrata(C.settings.strata)
  if f.SetFrameLevel then f:SetFrameLevel((hub:GetFrameLevel() or 1) + 40) end
  f:EnableMouse(true)
  C.ApplyDialogFrame(f, 0.06, 0.04, 0.10, 0.98)
  f.face = portrait(f, 120, 140, 0.45)
  f.face:SetPoint("LEFT", 14, 0)
  f.name = W.Text(f, 14, "", W.GOLD, "LEFT")
  f.name:SetPoint("TOPLEFT", f.face, "TOPRIGHT", 10, -10)
  f.name:SetWidth(240)
  f.text = W.Text(f, 14, "", W.WHITE, "LEFT")
  f.text:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -8)
  f.text:SetWidth(240)
  f.ok = W.Button(f, L.CAMEO_THANKS, 110, 26, function() f:Hide() end, 12)
  f.ok:SetPoint("BOTTOMRIGHT", -16, 14)
  f:Hide()
  return f
end

-- kind: "RANKUP" | "EXAMPASS" | "MILESTONE". Returns the cameo table or nil
-- (neutral/unknown faction, turned off, too soon after the last one).
function GU.Cameo(kind)
  if not (ns.Hub.frame and ns.Hub.frame:IsShown()) then return nil end
  local cameo = ns.Guide.Cameo(kind, C.Faction(), ns.Util.Now(), settings())
  if not cameo then return nil end
  GU.cameo = GU.cameo or buildCameo()
  local f = GU.cameo
  f.name:SetText(cameo.name)
  f.text:SetText(cameo.text)
  f:Show()
  f.face:ShowCast(cameo.cast)
  C.Sound("cameo")
  local token = {}
  f.token = token
  C.After(10, function() if f.token == token and f:IsShown() then f:Hide() end end)
  GU.lastCameo = cameo
  return cameo
end

------------------------------------------------------------------------
-- Rank-up celebration
------------------------------------------------------------------------
local function buildCelebration()
  local hub = ns.Hub.frame
  local f = C.CreateFrame("Button", "AzerothAcademyRankUp", hub, nil, true)
  f:SetSize(380, 150)
  f:SetPoint("CENTER", hub, "CENTER", 0, 30)
  f:SetFrameStrata(C.settings.strata)
  if f.SetFrameLevel then f:SetFrameLevel((hub:GetFrameLevel() or 1) + 30) end
  C.ApplyDialogFrame(f, 0.10, 0.06, 0.02, 0.98)
  f.glow = f:CreateTexture(nil, "BACKGROUND")
  f.glow:SetPoint("TOPLEFT", 12, -12)
  f.glow:SetPoint("BOTTOMRIGHT", -12, 12)
  C.SetColor(f.glow, 1, 0.75, 0.2, 0.35)
  if f.glow.SetBlendMode then f.glow:SetBlendMode("ADD") end
  f.icon = W.FramedIcon(f, 44, "Interface\\Icons\\Spell_Holy_MagicalSentry")
  f.icon:SetPoint("TOP", 0, -18)
  f.title = W.Text(f, 26, L.RANKUP_TITLE, W.GOLD, "CENTER")
  f.title:SetPoint("TOP", f.icon, "BOTTOM", 0, -8)
  f.sub = W.Text(f, 15, "", W.WHITE, "CENTER")
  f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
  f.sub:SetWidth(340)
  f.hero = GU.Hero(f, 170) -- Fizzwick celebrating beside the card (art only)
  f.hero:SetPoint("RIGHT", f, "LEFT", 60, 0)
  f:SetScript("OnClick", function(self) self:Hide() end)
  f:SetScript("OnHide", function(self)
    W.Pulse(self.glow, false)
    local after = self.after
    self.after = nil
    if after then after() end
  end)
  f:Hide()
  return f
end

-- Big "RANK UP!" card; when it closes, the leader cameo (if any) appears.
function GU.Celebrate(rankKey)
  if not (ns.Hub.frame and ns.Hub.frame:IsShown()) then return end
  GU.celebration = GU.celebration or buildCelebration()
  local f = GU.celebration
  f.sub:SetText(string.format(L.RANKUP_SUB, L[rankKey or "RANK_INITIATE"]))
  f.after = nil
  f:Show()
  f.after = function() GU.Cameo("RANKUP") end
  GU.ShowHero(f.hero, "celebrating")
  W.Reveal(f.icon, 0.7)
  W.Pulse(f.glow, true, 0.45)
  W.Sparks(f, 18, W.GOLD)
  C.Sound("rankup")
  GU.Say("RANKUP")
  local token = {}
  f.token = token
  C.After(4, function() if f.token == token and f:IsShown() then f:Hide() end end)
end

function GU.HideOverlays()
  if GU.celebration then GU.celebration.after = nil; GU.celebration:Hide() end
  if GU.cameo then GU.cameo:Hide() end
end

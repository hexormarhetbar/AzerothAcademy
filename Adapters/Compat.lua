-- Client adapter. The ONLY file that cares which WoW client we are on.
-- Primary target: WoW Forever (game type "forever"/"camelot", 1.60.1, interface 16001),
-- which runs on the modern Mainline UI code. Secondary: Retail/Midnight (12.x).
-- Best effort: Classic Era (1.15.x). Every version-sensitive call is guarded.
local _, ns = ...

local C = {}
ns.Compat = C

-- Feed the core its clock/date (core never touches WoW globals itself).
ns.Env.time = time
ns.Env.date = date

local _, _, _, interface = GetBuildInfo()
interface = tonumber(interface) or 0
C.interface = interface

if WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
  C.flavor = "forever"
elseif interface > 16000 and interface < 20000 then
  C.flavor = "forever"
elseif interface >= 100000 then
  C.flavor = "mainline"
elseif interface < 20000 then
  C.flavor = "classic_era"
else
  C.flavor = "classic"
end
C.isForever = C.flavor == "forever"

-- v0.13 Mechanics Academy: which class and race lists to teach. WoW Forever and Classic Era
-- have the original nine classes and eight races; Retail adds Death Knight, Monk, Demon Hunter
-- and Evoker plus newer races. Progression Classic clients (Wrath and later) are asked whether a
-- class with id 6 (Death Knight) exists; that check is not trusted on Era/Forever, where the
-- class tables can list classes the game does not offer.
function C.HasModernClasses()
  if C.flavor == "mainline" then return true end
  if C.flavor ~= "classic" then return false end
  local ok, _, file = pcall(GetClassInfo or function() end, 6)
  return ok and file == "DEATHKNIGHT" or false
end
ns.Env.modernClasses = C.HasModernClasses()

C.FLAVOR_NAMES = {
  forever = "WoW Forever", mainline = "Retail", classic_era = "Classic Era", classic = "Classic",
}

-- Per-flavor tweaks live here so the UI never branches on version itself.
local FLAVOR_SETTINGS = {
  forever     = { strata = "DIALOG", taxiPoll = 1.0, flightPoll = 0.5 },
  mainline    = { strata = "DIALOG", taxiPoll = 1.0, flightPoll = 0.5 },
  classic_era = { strata = "DIALOG", taxiPoll = 1.0, flightPoll = 0.5 },
  classic     = { strata = "DIALOG", taxiPoll = 1.0, flightPoll = 0.5 },
}
C.settings = FLAVOR_SETTINGS[C.flavor] or FLAVOR_SETTINGS.mainline

C.BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
-- v1.0: always the client's default font. Localized clients set STANDARD_TEXT_FONT to a font
-- with the right glyphs; the table is only a fallback if that global is missing.
C.LOCALE_FONTS = {
  koKR = "Fonts\\2002.TTF",           -- Korean
  zhCN = "Fonts\\ARKai_T.ttf",        -- Simplified Chinese
  zhTW = "Fonts\\bLEI00D.ttf",        -- Traditional Chinese
  ruRU = "Fonts\\FRIZQT___CYR.TTF",   -- Cyrillic
}
C.CLIENT_LOCALE = (GetLocale and GetLocale()) or "enUS"
C.CLIENT_FONT = STANDARD_TEXT_FONT or C.LOCALE_FONTS[C.CLIENT_LOCALE] or "Fonts\\FRIZQT__.TTF"
C.FONT = C.CLIENT_FONT

-- v1.1 language picker + World Tongues: fonts for text the client's own font may not cover.
-- An enUS / EU client ships Latin (and usually Cyrillic) fonts only; the Korean and Chinese
-- fonts (2002.TTF, ARKai_T.ttf, bLEI00D.ttf ...) come with those clients. So when the picked
-- language uses a different script than the client, the Academy uses its OWN bundled fonts:
-- subsets of Noto Sans JP / KR / SC / TC (SIL Open Font License 1.1, see Media/Fonts/README.md),
-- cut by tools/build_fonts.py to exactly the characters the addon shows. Every bundled font
-- also carries the kana, kanji and accented letters of the World Tongues courses.
C.FONT_DIR = "Interface\\AddOns\\" .. (ns.ADDON or "AzerothAcademy") .. "\\Media\\Fonts\\"
C.BUNDLED_FONTS = {
  latin = C.FONT_DIR .. "AzAcadSans-JP.ttf",    -- Latin + Cyrillic + Japanese
  cyrillic = C.FONT_DIR .. "AzAcadSans-JP.ttf",
  ko = C.FONT_DIR .. "AzAcadSans-KR.ttf",       -- Hangul + kana/kanji
  sc = C.FONT_DIR .. "AzAcadSans-SC.ttf",       -- Simplified Chinese + kana/kanji
  tc = C.FONT_DIR .. "AzAcadSans-TC.ttf",       -- Traditional Chinese + kana/kanji
}
C.SCRIPT_OF = {
  enUS = "latin", enGB = "latin", deDE = "latin", frFR = "latin", esES = "latin", esMX = "latin",
  ptBR = "latin", itIT = "latin", ruRU = "cyrillic", koKR = "ko", zhCN = "sc", zhTW = "tc",
}

-- Font for UI text in `code`: the client's own font when it is the same script, otherwise ours.
function C.FontFor(code)
  local want = C.SCRIPT_OF[code or ""] or "latin"
  if want == (C.SCRIPT_OF[C.CLIENT_LOCALE] or "latin") then return C.CLIENT_FONT end
  return C.BUNDLED_FONTS[want]
end

-- True when text in `code` is drawn with a bundled font (shown in the picker).
function C.UsesBundledFont(code) return C.FontFor(code) ~= C.CLIENT_FONT end

-- World Tongues lesson text mixes the UI language with kana / kanji / accents, so it always
-- uses the bundled font that ALSO covers the current UI language.
function C.CourseFont()
  local s = C.SCRIPT_OF[ns.locale or C.CLIENT_LOCALE] or "latin"
  return C.BUNDLED_FONTS[s] or C.BUNDLED_FONTS.latin
end

-- Switch the default font for frames built from now on (W.Text / W.Button use C.FONT).
function C.SetUIFont(code)
  C.FONT = C.FontFor(code)
  return C.FONT
end

-- CreateFrame that optionally adds BackdropTemplate and never hard-fails on a template.
function C.CreateFrame(frameType, name, parent, template, wantBackdrop)
  local t = template
  if wantBackdrop and C.BACKDROP_TEMPLATE then
    t = t and (t .. "," .. C.BACKDROP_TEMPLATE) or C.BACKDROP_TEMPLATE
  end
  local ok, f = pcall(CreateFrame, frameType, name, parent, t)
  if ok and f then return f end
  ok, f = pcall(CreateFrame, frameType, name, parent, template)
  if ok and f then return f end
  return CreateFrame(frameType, name, parent)
end

function C.SetColor(tex, r, g, b, a)
  if tex.SetColorTexture then
    tex:SetColorTexture(r, g, b, a or 1)
  else
    tex:SetTexture(r, g, b, a or 1)
  end
end

C.DEFAULT_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function C.ApplyBackdrop(f, r, g, b, a, br, bg, bb, ba)
  if f.SetBackdrop then
    local ok = pcall(f.SetBackdrop, f, C.DEFAULT_BACKDROP)
    if ok then
      if f.SetBackdropColor then f:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.9) end
      if f.SetBackdropBorderColor then f:SetBackdropBorderColor(br or 0.6, bg or 0.6, bb or 0.6, ba or 1) end
      return
    end
  end
  -- Fallback: flat colored background + thin border lines.
  if not f.__aaBg then
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    f.__aaBg = t
  end
  C.SetColor(f.__aaBg, r or 0, g or 0, b or 0, a or 0.9)
end

-- Framed window: the classic dialog-box border/background that ships in every client.
C.DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function C.ApplyDialogFrame(f, r, g, b, a)
  if f.SetBackdrop and pcall(f.SetBackdrop, f, C.DIALOG_BACKDROP) then
    if f.SetBackdropColor then f:SetBackdropColor(1, 1, 1, 1) end
    return true
  end
  C.ApplyBackdrop(f, r, g, b, a, 0.62, 0.48, 1, 1)
  return false
end

-- Timers: C_Timer when present, OnUpdate fallback otherwise.
local pending, timerFrame = {}, nil
function C.After(seconds, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, fn)
    return
  end
  if not timerFrame then
    timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
      for i = #pending, 1, -1 do
        local t = pending[i]
        t.left = t.left - elapsed
        if t.left <= 0 then
          table.remove(pending, i)
          pcall(t.fn)
        end
      end
      if #pending == 0 then self:Hide() end
    end)
  end
  pending[#pending + 1] = { left = seconds, fn = fn }
  timerFrame:Show()
end

-- Sounds ------------------------------------------------------------------------
-- The registry (Core/SoundEvents.lua) decides WHAT to try; this plays it.
-- Order: custom file Media\Sounds\<event>.ogg (if the parent added one), then the
-- built-in SoundKits by SOUNDKIT name / numeric ID. Never errors, never touches the
-- player's volume CVars. A custom file that will not play is remembered as missing
-- for the rest of the session so we do not retry it on every click.
C.missingSounds = {}
C.lastSound = nil -- { event, how, value } for tests / debugging

local function soundSettings()
  local a = ns.Progress and ns.Progress.account
  return a and a.settings and a.settings.sound or nil
end

function C.Sound(event)
  local S = ns.SoundEvents
  if not S then return false end
  local settings = soundSettings()
  local plan = S.Plan(event, settings, C.missingSounds)
  if not plan then return false end
  local channel = S.Channel(settings)
  for _, step in ipairs(plan) do
    if step.file then
      if PlaySoundFile then
        local ok, willPlay = pcall(PlaySoundFile, step.file, channel)
        if ok and willPlay then
          C.lastSound = { event = event, how = "file", value = step.file }
          return true
        end
      end
      C.missingSounds[event] = true
    elseif PlaySound then
      local id = step.kit
      if type(id) == "string" then id = SOUNDKIT and SOUNDKIT[id] end
      if id then
        local ok, willPlay = pcall(PlaySound, id, channel)
        if ok and willPlay ~= false then
          C.lastSound = { event = event, how = "kit", value = id }
          return true
        end
      end
    end
  end
  return false
end

-- v0.8: Fizzwick's recorded voice. One clip at a time: `interrupt` stops the clip that is
-- still playing (StopSound with a short fade, where the client has it). Same channel as
-- the sound effects, so the player's volume slider for that channel applies.
C.voiceHandle, C.lastVoice = nil, nil
function C.PlayVoice(path, interrupt)
  if not PlaySoundFile then return false end
  local settings = soundSettings()
  if settings and settings.enabled == false then return false end
  if interrupt and C.voiceHandle and StopSound then pcall(StopSound, C.voiceHandle, 250) end
  local channel = ns.SoundEvents and ns.SoundEvents.Channel(settings) or "SFX"
  local ok, willPlay, handle = pcall(PlaySoundFile, path, channel)
  if ok and willPlay then
    C.voiceHandle, C.lastVoice = handle, path
    return true
  end
  return false
end

-- v1.2 World Tongues: play one language clip (`clip` from ns.TonguesAudio). Stops the clip
-- before it (a replay never overlaps itself), uses the same channel and the same sound
-- switch as everything else, and tells ns.TonguesAudio whether it played, so a missing
-- file is remembered and the UI can fall back to text. Returns true when it plays.
function C.PlayTongue(clip)
  local TA = ns.TonguesAudio
  if not (TA and clip) then return false end
  if not TA.Available() then return false end
  if not PlaySoundFile then return false end
  if C.tongueHandle and StopSound then pcall(StopSound, C.tongueHandle, 100) end
  C.tongueHandle = nil
  local channel = ns.SoundEvents and ns.SoundEvents.Channel(soundSettings()) or "SFX"
  local ok, willPlay, handle = pcall(PlaySoundFile, TA.Path(clip), channel)
  local played = ok and willPlay and true or false
  TA.Result(clip, played)
  if played then C.tongueHandle, C.lastTongue = handle, TA.Path(clip) end
  return played
end

function C.StopTongue()
  if C.tongueHandle and StopSound then pcall(StopSound, C.tongueHandle, 100) end
  C.tongueHandle = nil
end

-- Faction of the player: "Horde", "Alliance", "Neutral" or nil.
function C.Faction()
  if not UnitFactionGroup then return nil end
  local ok, f = pcall(UnitFactionGroup, "player")
  if ok and type(f) == "string" then return f end
  return nil
end

-- Model frames ----------------------------------------------------------------------
-- Create a PlayerModel and point it at a cast entry ({ displays = {...}, creatures = {...} }).
-- Returns the model or nil. Everything is pcall-guarded: a client without the
-- widget, or IDs it does not know, just means the caller shows an icon instead.
function C.CreateModel(parent, w, h)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
  if not ok or type(m) ~= "table" then return nil end
  if m.SetSize then m:SetSize(w, h) end
  return m
end

C.badModelIds = {} -- IDs that loaded nothing this session; skipped next time

local function candidates(cast)
  local list = {}
  for _, id in ipairs(cast.displays or {}) do list[#list + 1] = { "SetDisplayInfo", id, "display:" } end
  for _, id in ipairs(cast.creatures or {}) do list[#list + 1] = { "SetCreature", id, "creature:" } end
  return list
end

-- Point a model at a cast entry ({ displays = {...}, creatures = {...} }), trying
-- each ID in order. Models load asynchronously, so a moment later we ask the client
-- whether a model file really loaded (GetModelFileID on modern clients; 0 = unknown
-- ID) and move on to the next candidate. When none work, onFallback() is called and
-- the caller shows an icon instead. Older clients without GetModelFileID: a call
-- that did not error counts as success. Returns true if a candidate was applied.
function C.SetModel(model, cast, onFallback, startAt)
  if not (model and cast) then
    if onFallback then pcall(onFallback) end
    return false
  end
  local list = candidates(cast)
  for i = startAt or 1, #list do
    local c = list[i]
    local fn = model[c[1]]
    if fn and not C.badModelIds[c[3] .. c[2]] then
      if model.ClearModel then pcall(model.ClearModel, model) end
      if pcall(fn, model, c[2]) then
        model.aaModelId = c[3] .. c[2]
        local token = {}
        model.aaToken = token
        C.After(1.5, function()
          if model.aaToken ~= token or not model.GetModelFileID then return end
          local ok, fid = pcall(model.GetModelFileID, model)
          if ok and fid == 0 then
            C.badModelIds[c[3] .. c[2]] = true
            C.SetModel(model, cast, onFallback, i + 1)
          end
        end)
        return true
      end
    end
  end
  model.aaModelId = nil
  if onFallback then pcall(onFallback) end
  return false
end

-- Head-and-shoulders framing for a portrait model.
function C.PortraitCamera(model, zoom)
  if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, zoom or 0.85) end
  if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, 1.2) end
end

function C.InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then
    local ok, v = pcall(UnitAffectingCombat, "player")
    if ok and v then return true end
  end
  return false
end

function C.OnTaxi()
  if not UnitOnTaxi then return false end
  local ok, v = pcall(UnitOnTaxi, "player")
  return ok and v and true or false
end

-- v0.7: in a dungeon, raid, battleground or arena? (Flights can't start there, but be safe.)
function C.InInstance()
  if not IsInInstance then return false end
  local ok, inside, kind = pcall(IsInInstance)
  if not ok then return false end
  return (inside and kind ~= "none") and true or false
end

-- Seconds since some point (GetTime); 0 when the client has no clock (tests).
function C.Now()
  if not GetTime then return 0 end
  local ok, t = pcall(GetTime)
  return ok and tonumber(t) or 0
end

-- Register events that might not exist on every client (unknown names raise on modern clients).
-- Returns the list of names that registered.
function C.RegisterEvents(frame, names)
  local got = {}
  for _, e in ipairs(names) do
    if pcall(frame.RegisterEvent, frame, e) then got[#got + 1] = e end
  end
  return got
end

-- Events that hint a flight started or ended. Polling UnitOnTaxi is still the source of truth:
-- these only make the check happen sooner. Unverified on WoW Forever, so all are optional.
C.TAXI_EVENTS = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_CLOSED", "PLAYER_ENTERING_WORLD" }

function C.PlayerName()
  local ok, name, realm = pcall(UnitName, "player")
  if not ok or not name then return nil end
  if (not realm or realm == "") and GetRealmName then
    local ok2, r = pcall(GetRealmName)
    if ok2 then realm = r end
  end
  return realm and realm ~= "" and (name .. "-" .. realm) or name
end

function C.Print(msg)
  local line = "|cff9d7dffAzeroth Academy|r: " .. tostring(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(line)
  else
    print(line)
  end
end

------------------------------------------------------------------------
-- v0.10 Duel of Wits: addon messages, group/guild/friends, hidden queue channel
------------------------------------------------------------------------
-- Realm as it appears in CHAT_MSG_ADDON senders ("Name-RealmName", no spaces).
function C.Realm()
  if GetNormalizedRealmName then
    local ok, r = pcall(GetNormalizedRealmName)
    if ok and r and r ~= "" then return r end
  end
  if GetRealmName then
    local ok, r = pcall(GetRealmName)
    if ok and r then return (r:gsub("[%s%-]", "")) end
  end
  return ""
end

function C.ShortName()
  local ok, name = pcall(UnitName, "player")
  return ok and name or nil
end

-- true on clients with the modern C_ChatInfo API (needed for the random queue,
-- which talks on a custom channel; 3.3.5-era clients can't send addon messages there).
function C.HasModernComms()
  return (C_ChatInfo and C_ChatInfo.SendAddonMessage) and true or false
end

function C.RegisterAddonPrefix(prefix)
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    return pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
  end
  if RegisterAddonMessagePrefix then return pcall(RegisterAddonMessagePrefix, prefix) end
  return true -- very old clients deliver every prefix
end

C.lastAddonMessage = nil -- { prefix, msg, channel, target } for tests
function C.SendAddonMessage(prefix, msg, channel, target)
  local f = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if not f then return false end
  C.lastAddonMessage = { prefix, msg, channel, target }
  local ok, res = pcall(f, prefix, msg, channel, target)
  return ok and (res == nil or res == true or res == 0)
end

function C.GroupChannel()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  if GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0 then return "RAID" end
  if GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0 then return "PARTY" end
  return nil
end

function C.InGuild()
  return (IsInGuild and IsInGuild()) and true or false
end

-- Character friends list only (not Battle.net friends).
function C.IsFriend(name)
  name = tostring(name or "")
  local short = name:match("^([^%-]+)") or name
  if C_FriendList and C_FriendList.GetFriendInfo then
    for _, n in ipairs({ name, short }) do
      local ok, info = pcall(C_FriendList.GetFriendInfo, n)
      if ok and info then return true end
    end
    return false
  end
  if GetNumFriends and GetFriendInfo then
    local okn, count = pcall(GetNumFriends)
    for i = 1, (okn and count or 0) do
      local n = GetFriendInfo(i)
      if n and (n == short or n == name) then return true end
    end
  end
  return false
end

C.QUEUE_CHANNEL = "AzerothAcademyQ"

function C.ChannelIndex(name)
  if not GetChannelName then return nil end
  local ok, id = pcall(GetChannelName, name)
  if ok and type(id) == "number" and id > 0 then return id end
  return nil
end

-- Join quietly and keep the channel out of every chat window: kids never see it.
function C.JoinHiddenChannel(name)
  if not JoinTemporaryChannel then return nil end
  pcall(JoinTemporaryChannel, name)
  local remove = ChatFrame_RemoveChannel or (ChatFrameUtil and ChatFrameUtil.RemoveChannel)
  if remove then
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local cf = _G["ChatFrame" .. i]
      if cf then pcall(remove, cf, name) end
    end
  end
  return C.ChannelIndex(name)
end

function C.LeaveHiddenChannel(name)
  if LeaveChannelByName then pcall(LeaveChannelByName, name) end
end

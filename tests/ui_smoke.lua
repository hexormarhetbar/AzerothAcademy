-- UI smoke test: loads the WHOLE addon (every file in the .toc, in order) against a
-- permissive mock of the WoW widget API, then drives it like a player would:
-- login, /aa, pick a band, open the forge, play full rounds by "clicking" answers,
-- get hidden by combat and resume, use the parent panel (PIN, settings, export, reset).
-- This cannot prove pixels look right; it proves the Lua runs without errors.
-- Usage: lua tests/ui_smoke.lua [interface]   (16001 Forever, 120105 Retail, 11509 Classic Era)
local INTERFACE = tonumber(arg and arg[1]) or 16001
local LEGACY = arg and arg[2] == "legacy" -- strip C_Timer/BackdropTemplate to exercise fallbacks
math.randomseed(os.time())

local errors = 0
local function fail(msg) errors = errors + 1; io.write("FAIL: " .. msg .. "\n") end

-------------------------------------------------------------------------
-- Mock widget API
-------------------------------------------------------------------------
local allFrames, named = {}, {}
local Widget = {}
local function newWidget(kind, name, parent)
  local w = setmetatable({
    __kind = kind, __name = name, __parent = parent, __scripts = {}, __shown = true,
    __text = "", __w = 0, __h = 0, __points = {}, __enabled = true, __children = {},
  }, Widget)
  if parent and parent.__children then table.insert(parent.__children, w) end
  allFrames[#allFrames + 1] = w
  if name then named[name] = w; _G[name] = w end
  return w
end

local methods = {}
Widget.__index = function(t, k)
  if methods[k] then return methods[k] end
  -- WoW widget methods are CamelCase; plain fields (lowercase) must read as nil like the real client
  if type(k) ~= "string" or not k:match("^%u") then return nil end
  return function() return nil end -- permissive: unknown methods are no-ops
end
function methods:SetScript(ev, fn) self.__scripts[ev] = fn end
function methods:GetScript(ev) return self.__scripts[ev] end
function methods:HookScript(ev, fn) self.__scripts[ev] = fn end
function methods:Show()
  local was = self:IsVisible()
  self.__shown = true
  if not was and self:IsVisible() and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function methods:Hide()
  local was = self:IsVisible()
  self.__shown = false
  if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.__shown end
function methods:IsVisible()
  local p = self
  while p do
    if not p.__shown then return false end
    p = p.__parent
  end
  return true
end
function methods:SetText(t) self.__text = t == nil and "" or tostring(t) end
function methods:GetText() return self.__text end
function methods:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function methods:SetSize(w, h) self.__w, self.__h = w, h end
function methods:SetWidth(w) self.__w = w end
function methods:SetHeight(h) self.__h = h end
function methods:GetWidth() return self.__w end
function methods:GetHeight() return self.__h end
function methods:SetPoint(...) self.__points[#self.__points + 1] = { ... } end
function methods:ClearAllPoints() self.__points = {} end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetParent() return self.__parent end
function methods:SetParent(p) self.__parent = p end
function methods:Enable() self.__enabled = true end
function methods:Disable() self.__enabled = false end
function methods:IsEnabled() return self.__enabled end
function methods:GetFontString() return self.__fs end
function methods:SetFontString(fs) self.__fs = fs end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:SetFont() return true end
function methods:GetFontObject() return {} end
function methods:GetFrameLevel() return 1 end
function methods:GetVerticalScroll() return 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:CreateTexture(name) return newWidget("Texture", name, self) end
function methods:CreateFontString(name) return newWidget("FontString", name, self) end
function methods:RegisterEvent(e) self.__events = self.__events or {}; self.__events[e] = true end
function methods:UnregisterEvent(e) if self.__events then self.__events[e] = nil end end
function methods:Click() if self.__enabled and self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end end
function methods:SetBackdrop(bd) if not self.__backdrop then error("SetBackdrop without BackdropTemplate") end end

local decorateModel -- defined with the v0.4 mocks below
function CreateFrame(kind, name, parent, template)
  if kind == "PlayerModel" and LEGACY then error("PlayerModel not supported here") end
  local w = newWidget(kind, name, parent)
  if kind == "PlayerModel" then decorateModel(w) end
  if template and template:find("BackdropTemplate") then w.__backdrop = true end
  if INTERFACE < 20000 and INTERFACE ~= 16001 and template == "UIPanelScrollFrameTemplate" then
    -- pretend a template is missing on old clients to exercise fallbacks
  end
  if kind == "Button" and template and template:find("UIPanelButtonTemplate") then
    w.__fs = newWidget("FontString", nil, w)
  end
  if kind == "Button" and template == "UIPanelCloseButton" then w.__w = 24 end
  return w
end

-- Globals the addon uses
UIParent = newWidget("Frame", "UIParent")
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameFontHighlight = {}
BackdropTemplateMixin = {}
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_QUEST_LIST_COMPLETE = 878 }
local soundsPlayed = 0
local lastKit, lastChannel, fileTries = nil, nil, {}
function PlaySound(id, channel) soundsPlayed = soundsPlayed + 1; lastKit, lastChannel = id, channel; return true end
-- v0.4: custom sound files. Only correct.ogg "exists"; everything else must fall back to a kit.
local CUSTOM_FILES = { ["Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\correct.ogg"] = true }
-- v0.8: Fizzwick's voice clips (Media\Sounds\VO\) "exist" unless listed in voiceFail
local voicePlays, voiceStops, voiceFail, voiceHandle = {}, {}, {}, 100
function PlaySoundFile(path, channel)
  fileTries[path] = (fileTries[path] or 0) + 1
  if path:find("\\VO\\", 1, true) then
    if voiceFail[path:match("([%w_]+)%.ogg$")] then return false end
    voiceHandle = voiceHandle + 1
    voicePlays[#voicePlays + 1] = { path = path, channel = channel, handle = voiceHandle }
    return true, voiceHandle
  end
  if CUSTOM_FILES[path] then soundsPlayed = soundsPlayed + 1; lastChannel = channel; return true, 1 end
  return false
end
function StopSound(handle) voiceStops[#voiceStops + 1] = handle end
-- v0.4: faction per run (Horde on Forever, Alliance on Retail, none on Classic Era, Neutral in legacy)
local FACTION = ({ [16001] = "Horde", [120105] = "Alliance" })[INTERFACE]
if FACTION then function UnitFactionGroup() return FACTION, FACTION end end
-- v0.4: textures remember what they show; AnimationGroups exist (legacy strips them)
function methods:SetTexture(t) self.__tex = t; return true end
function methods:GetTexture() return self.__tex end
function methods:SetAlpha(a) self.__alpha = a end
function methods:GetAlpha() return self.__alpha or 1 end
function methods:CreateAnimationGroup()
  local g = newWidget("AnimationGroup", nil, nil)
  g.__anims = {}
  return g
end
function methods:CreateAnimation(kind) local a = newWidget("Animation"); a.__animKind = kind; return a end
function methods:Play() self.__playing = true end
function methods:Stop() self.__playing = false end
function methods:IsPlaying() return self.__playing == true end
-- v0.4: PlayerModel. Retail pretends display 7340 is unknown (GetModelFileID = 0 after
-- loading) so the async fallback to the next goblin is exercised. Legacy has no PlayerModel.
local modelSets = {}
function decorateModel(w)
  function w:SetDisplayInfo(id) self.__display = id; modelSets[#modelSets + 1] = "display:" .. id end
  function w:SetCreature(id) self.__creature = id; modelSets[#modelSets + 1] = "creature:" .. id end
  function w:GetModelFileID()
    if INTERFACE == 120105 and self.__display == 7340 then return 0 end
    return self.__display and 1000 + self.__display or nil
  end
end
local timers = {}
C_Timer = { After = function(sec, fn) timers[#timers + 1] = fn end }
local update
local function runTimers()
  local list = timers
  timers = {}
  for _, fn in ipairs(list) do fn() end
  if update then update(2.5) end
end
local clock = 1000
function GetTime() return clock end
local timeOffset = 0 -- lets the test jump days ahead for spaced review
time = function(t) if t then return os.time(t) end return os.time() + timeOffset end
date = os.date
function GetBuildInfo() return "1.60.1", "70790", "Nov 3 2026", INTERFACE end
function GetLocale() return "enUS" end
function GetRealmName() return "Testrealm" end
function UnitName() return "Hexkid", nil end
local inCombat, onTaxi = false, false
function InCombatLockdown() return inCombat end
function UnitAffectingCombat() return inCombat end
function UnitOnTaxi() return onTaxi end
local inInstance = false
function IsInInstance() return inInstance, inInstance and "party" or "none" end
WOW_PROJECT_ID = 1
SlashCmdList = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
local realPrint = io.write

if LEGACY then C_Timer = nil; BackdropTemplateMixin = nil; methods.CreateAnimationGroup = nil; FACTION = nil; UnitFactionGroup = function() return "Neutral" end end

-- v0.6.1 minimap mocks
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
local mmShape = "ROUND"
function GetMinimapShape() return mmShape end
function methods:GetCenter() return self.__cx or 500, self.__cy or 500 end
function methods:GetEffectiveScale() return 1 end
function methods:RegisterForClicks(...) self.__clicks = { ... } end
function methods:RegisterForDrag(...) self.__drag = { ... } end
function methods:SetHighlightTexture(t) self.__highlight = t end
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
Minimap.__cx, Minimap.__cy = 1000, 700
local tooltipLines = {}
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent)
function GameTooltip:SetOwner() tooltipLines = {} end
function GameTooltip:AddLine(t) tooltipLines[#tooltipLines + 1] = t end
if LEGACY then GetMinimapShape = nil end

-- v0.10 Duel of Wits comms mocks (modern C_ChatInfo, or the legacy globals)
local addonSent, prefixes, joinedChannels, leftChannels = {}, {}, {}, {}
local inGroup, friendNames, channelIds, shiftDown = false, {}, {}, false
local function recordAddon(p, m, ch, t)
  if #m > 255 then error("addon message longer than 255 bytes") end
  addonSent[#addonSent + 1] = { prefix = p, msg = m, channel = ch, target = t }
end
if not LEGACY then
  C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) prefixes[p] = true; return true end,
    SendAddonMessage = function(p, m, ch, t) recordAddon(p, m, ch, t); return 0 end,
  }
  function GetNormalizedRealmName() return "Testrealm" end
  C_FriendList = { GetFriendInfo = function(n) return friendNames[n] and { name = n } or nil end }
  function IsInGroup() return inGroup end
  function IsInRaid() return false end
else
  function SendAddonMessage(p, m, ch, t) recordAddon(p, m, ch, t) end
  function GetNumPartyMembers() return inGroup and 1 or 0 end
  function GetNumRaidMembers() return 0 end
  function GetNumFriends() return 0 end
end
function IsInGuild() return true end
function JoinTemporaryChannel(n) joinedChannels[#joinedChannels + 1] = n; channelIds[n] = 5 end
function GetChannelName(n) return channelIds[n] or 0 end
function LeaveChannelByName(n) leftChannels[#leftChannels + 1] = n; channelIds[n] = nil end
function IsShiftKeyDown() return shiftDown end

-------------------------------------------------------------------------
-- Load the addon exactly as the client would: files listed in the .toc
-------------------------------------------------------------------------
local ns = {}
local files = {}
for line in io.lines("AzerothAcademy.toc") do
  line = line:gsub("\r", "")
  if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(f)
  if not chunk then fail("load " .. f .. ": " .. err) else
    local ok, e = pcall(chunk, "AzerothAcademy", ns)
    if not ok then fail("run " .. f .. ": " .. tostring(e)) end
  end
end

local function fire(event, ...)
  for _, w in ipairs(allFrames) do
    if w.__events and w.__events[event] and w.__scripts.OnEvent then
      local ok, e = pcall(w.__scripts.OnEvent, w, event, ...)
      if not ok then fail("event " .. event .. ": " .. tostring(e)) end
    end
  end
end
function update(dt)
  for _, w in ipairs(allFrames) do
    if w.__scripts.OnUpdate and w:IsVisible() then
      local ok, e = pcall(w.__scripts.OnUpdate, w, dt)
      if not ok then fail("OnUpdate: " .. tostring(e)) end
    end
  end
end
local function slash(msg)
  local ok, e = pcall(SlashCmdList.AZEROTHACADEMY, msg)
  if not ok then fail("/aa " .. msg .. ": " .. tostring(e)) end
end
local function step(name, fn)
  local ok, e = pcall(fn)
  if not ok then fail(name .. ": " .. tostring(e)) end
end
-- Find a visible button whose text matches
local function findButton(pattern, root)
  for _, w in ipairs(allFrames) do
    if w.__kind == "Button" and w:IsVisible() and w.__enabled and w.__scripts.OnClick then
      local t = w.__text or ""
      if t:find(pattern) then return w end
      for _, c in ipairs(w.__children) do
        if c.__kind == "FontString" and (c.__text or ""):find(pattern) then return w end
      end
    end
  end
end
local function click(pattern)
  local b = findButton(pattern)
  if not b then fail("no visible button matching '" .. pattern .. "'") return false end
  local ok, e = pcall(b.Click, b)
  if not ok then fail("click '" .. pattern .. "': " .. tostring(e)) return false end
  return true
end

-------------------------------------------------------------------------
-- Drive it
-------------------------------------------------------------------------
step("ADDON_LOADED", function() fire("ADDON_LOADED", "AzerothAcademy") end)
step("PLAYER_LOGIN", function() fire("PLAYER_LOGIN") end)
if not ns.ready then fail("addon did not initialise") end
local hub
step("open hub", function() slash("") end)
hub = named.AzerothAcademyHub
if not (hub and hub:IsShown()) then fail("hub did not open") end
if ns.Hub.current ~= "profile" then fail("first run should show profile setup, got " .. tostring(ns.Hub.current)) end
local found = false
for _, n in ipairs(UISpecialFrames) do if n == "AzerothAcademyHub" then found = true end end
if not found then fail("hub not ESC-closable (UISpecialFrames)") end

local bandPattern = ({ "Initiate", "Adept", "Magister" })[math.random(1, 3)]
click("^" .. bandPattern)
if ns.Hub.current ~= "home" then fail("expected home view after band pick") end
if ns.Progress.GetBand() == nil then fail("band not saved") end

-- Coming-soon module + active module
click("^Mechanics Academy$") -- coming soon tile: prints, stays home
if ns.Hub.current ~= "home" then fail("coming-soon tile should not navigate") end
click("^Rune Forger$")
-- v0.2: first visit offers The Forgemaster's Trial
if ns.Hub.current ~= "trial" then fail("first forge visit should offer the placement trial, got " .. tostring(ns.Hub.current)) end
if not findButton("^Begin the Trial$") then fail("trial intro has no Begin button") end
click("^Skip for now$")
if ns.Hub.current ~= "forge" then fail("Rune Forger tile did not open the forge") end
if not ns.Progress.char.modules.runeforger.placement[ns.Progress.GetBand()] then fail("skip not recorded") end
click("^Spark$") -- start a Spark round from the node list
if ns.Hub.current ~= "problem" or not ns.RuneForger.session then fail("Spark button did not start a round") end
click("^Leave Forge$")
if ns.Hub.current ~= "forge" then fail("Leave Forge did not return to the node list") end

-- Play rounds through the UI for EVERY band and node, answering via the widgets
local view
local function playSession(correctness, expectView)
  view = ns.Hub.GetView("problem")
  local guard = 0
  while ns.RuneForger.session and guard < 40 do
    guard = guard + 1
    local s = ns.RuneForger.session
    local p = s.problem
    local right = math.random() < correctness
    local value
    if right then value = p.answer
    elseif p.mode == "choice" then
      for _, c in ipairs(p.choices) do if tostring(c) ~= tostring(p.answer) then value = c break end end
    else value = "987654" end
    clock = clock + 2
    step("answer", function() view:Answer(value) end)
    if s.problemDone then
      if right then runTimers() else
        if not s.problemDone then fail("problem should be done") end
        local nb = findButton("^Next$")
        if nb then nb:Click() else view:Advance() end
        runTimers()
      end
    end
    update(0.5)
  end
  if guard >= 40 then fail("session did not finish") end
  expectView = expectView or "reward"
  if ns.Hub.current ~= expectView then fail("expected " .. expectView .. " view after round, got " .. tostring(ns.Hub.current)) end
end
local function playUIRound(nodeId, tier, correctness)
  ns.RuneForger.StartRound(nodeId, tier)
  playSession(correctness)
end

for _, bandId in ipairs({ "initiate", "adept", "magister" }) do
  ns.Progress.SetBand(bandId)
  step("forge view " .. bandId, function() ns.Hub.ShowView("forge") end)
  if ns.Hub.current == "trial" then
    if bandId == "adept" then
      -- Full placement trial through the UI
      click("^Begin the Trial$")
      local ts = ns.RuneForger.session
      if not (ts and ts.isTrial and ns.Hub.current == "problem") then fail("Begin the Trial did not start the trial") end
      if findButton("^Hint$") then fail("trial must not offer hints") end
      if ts and ts.problem and ts.problem.mode ~= "input" then fail("Adept trial should use typed answers") end
      playSession(0.6, "trialResult")
      if ns.Progress.char.modules.runeforger.placement.adept.status ~= "done" then fail("UI placement not saved") end
      if not findButton("^Continue$") then fail("trial result has no Continue") end
      click("^Continue$")
    else
      click("^Skip for now$")
    end
  end
  if ns.Hub.current ~= "forge" then fail("expected forge for " .. bandId .. ", got " .. tostring(ns.Hub.current)) end
  for _, nodeId in ipairs(ns.MathGen.BANDS[bandId].nodes) do
    playUIRound(nodeId, 1, 0.7)
    playUIRound(nodeId, 1, 1.0)
    playUIRound(nodeId, 1, 1.0) -- likely mastered now
  end
end
ns.Progress.SetBand("adept")

-- v0.2 spaced review: jump a day ahead, the hub offers Review Time
timeOffset = 86400 + 60
local chatMark = #chat
fire("PLAYER_LOGIN")
local reviewChat = false
for i = chatMark + 1, #chat do if chat[i]:find("ready for review") then reviewChat = true end end
if not reviewChat then fail("no review reminder in chat at login") end
ns.Hub.ShowView("home")
if not findButton("Review Time %(%d+ due%)") then fail("hub does not show Review Time button") end
click("Review Time %(")
if not (ns.RuneForger.session and ns.RuneForger.session.mode == "review") then fail("Review Time did not start a review round") end
playSession(1.0)
local rewardView = ns.Hub.GetView("reward")
if not (rewardView.summary and rewardView.summary.mode == "review") then fail("review reward summary missing") end
-- fail a review -> fading -> Practice button
if #ns.Review.Due() > 0 then
  slash("review")
  playSession(0.0)
  local anyFading = #ns.Review.Fading() > 0
  if not anyFading then fail("failed review should mark a rune fading") end
  if not findButton("^Practice$") then fail("fading review should offer Practice") end
  click("^Practice$")
  if not (ns.RuneForger.session and ns.RuneForger.session.mode == "practice") then fail("Practice did not start a round") end
  playSession(1.0)
end

-- v0.2 Mastery Exam via the forge
ns.Progress.account.settings.unlockAllTiers = false
ns.Hub.ShowView("forge")
for i, nodeId in ipairs(ns.MathGen.BANDS.adept.nodes) do
  if i <= 4 then ns.Progress.GetTierRec(nodeId, 2).mastered = true end
end
ns.Hub.ShowView("forge")
if not findButton("Mastery Exam") then fail("exam button not enabled after 4 Rune masteries") end
click("Mastery Exam")
if ns.Hub.current ~= "trial" then fail("exam button did not open the exam intro") end
click("^Begin the Exam$")
playSession(1.0, "trialResult")
local ex = ns.Progress.char.modules.runeforger.exams.adept
if not (ex and ex.passed) then fail("perfect exam should pass") end
click("^Continue$")
if ns.Hub.current ~= "forge" then fail("Continue should return to the forge") end

-- v0.3 Scribe's Scrolls: tile -> Scribe's Trial -> result -> scroll list
ns.Hub.ShowView("home")
click("^Scribe's Scrolls$")
if ns.Hub.current ~= "trial" then fail("Scribe tile should open the Scribe's Trial, got " .. tostring(ns.Hub.current)) end
click("^Begin the Trial$")
if not (ns.RuneForger.session and ns.RuneForger.session.moduleId == "scribe") then fail("Scribe trial did not start") end
playSession(0.7, "trialResult")
if ns.Progress.char.modules.scribe.placement.adept.status ~= "done" then fail("Scribe placement not saved") end
click("^Continue$")
if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= "scribe" then fail("Continue should show the scroll list") end
if not findButton("^Spark$") then fail("scroll list has no tier buttons") end
-- every Scribe node plays through the UI in every band
for _, bandId in ipairs({ "initiate", "adept", "magister" }) do
  for _, nodeId in ipairs(ns.Scribe.BANDS[bandId].nodes) do
    ns.Progress.account.settings.unlockAllTiers = true
    playUIRound(nodeId, math.random(1, 3), 0.8)
  end
end
local function visibleEdit()
  for _, w in ipairs(allFrames) do
    if w.__kind == "EditBox" and w:IsVisible() and w.__scripts.OnEnterPressed then return w end
  end
end
local function visibleText(pattern)
  for _, w in ipairs(allFrames) do
    if w.__kind == "FontString" and w:IsVisible() and (w.__text or ""):find(pattern) then return w.__text end
  end
end
-- text answers: case and spaces forgiven, blank ignored
ns.RuneForger.StartRound("sc_spell_adept", 2)
local ts = ns.RuneForger.session
if ts.problem.mode ~= "text" then fail("Rune-tier spelling should be a text answer, got " .. tostring(ts.problem.mode)) end
local e = visibleEdit()
if not e then fail("no edit box for text answer") else
  e:SetText("   "); e.__scripts.OnEnterPressed(e)
  if ts.tries ~= 0 then fail("blank text answer should not use a try") end
  e:SetText("  " .. ts.problem.answer:upper() .. " "); e.__scripts.OnEnterPressed(e)
  if not (ts.problemDone and ts.firstCorrect == 1) then fail("upper-case spaced spelling should be accepted") end
end
click("^Leave Forge$")
-- typing: accuracy + WPM feedback from the GetTime clock
ns.RuneForger.StartRound("sc_type_phrases", 1)
ts = ns.RuneForger.session
if ts.problem.mode ~= "typing" then fail("typing node should use typing mode") end
e = visibleEdit()
if e then
  clock = clock + 6
  e:SetText(ts.problem.answer:lower()); e.__scripts.OnEnterPressed(e)
  if not ts.problemDone then fail("lower-case copy should pass at Spark") end
  if not visibleText("WPM") then fail("typing result (accuracy/WPM) not shown") end
  if (ns.Progress.GetTierRec("sc_type_phrases", 1).bestWpm or 0) <= 0 then fail("best WPM not saved") end
end
click("^Leave Forge$")
-- long definitions use the two-column button layout
ns.RuneForger.StartRound("sc_context", 1)
ts = ns.RuneForger.session
local shown = 0
for _, c in ipairs(ts.problem.choices) do
  for _, w in ipairs(allFrames) do
    if w.__kind == "Button" and w:IsVisible() and w.__text == c then shown = shown + 1 break end
  end
end
if shown ~= #ts.problem.choices then fail("not every definition choice is visible (" .. shown .. ")") end
click("^Leave Forge$")
slash("scribe")
if not (ns.Hub.current == "forge" and ns.Lessons.CurrentModule().id == "scribe") then fail("/aa scribe did not open the scroll list") end
slash("forge")
if ns.Lessons.CurrentModule().id ~= "runeforger" then fail("/aa forge did not switch back to Rune Forger") end
ns.Progress.account.settings.unlockAllTiers = false

-- Typed input path with Enter key on Rune tier
ns.Progress.account.settings.unlockAllTiers = true
ns.RuneForger.StartRound("times", 2)
view = ns.Hub.GetView("problem")
local s = ns.RuneForger.session
if s.problem.mode ~= "input" then fail("Rune tier should use typed input") end
-- find the visible edit box and press Enter with a wrong then right answer
local edit
for _, w in ipairs(allFrames) do
  if w.__kind == "EditBox" and w:IsVisible() and w.__scripts.OnEnterPressed then edit = w end
end
if not edit then fail("no visible answer EditBox") else
  edit:SetText("abc"); edit.__scripts.OnEnterPressed(edit)
  if s.tries ~= 0 then fail("garbage input should not count as a try") end
  edit:SetText(tostring(s.problem.answer + 1)); edit.__scripts.OnEnterPressed(edit)
  if s.tries ~= 1 then fail("wrong typed answer should use the first try") end
  edit:SetText(" " .. tostring(s.problem.answer) .. " "); edit.__scripts.OnEnterPressed(edit)
  if not s.problemDone then fail("right typed answer on retry should finish problem") end
end

-- Combat: hides, offers resume, resume restores the same problem
local idxBefore = s.index
inCombat = true
fire("PLAYER_REGEN_DISABLED")
if hub:IsShown() then fail("hub should hide in combat") end
slash("") -- attempt to open in combat
if hub:IsShown() then fail("hub opened during combat") end
inCombat = false
fire("PLAYER_REGEN_ENABLED")
local toast = named.AzerothAcademyResume
if not (toast and toast:IsShown()) then fail("resume prompt not shown after combat") end
click("^Resume$")
if not hub:IsShown() then fail("resume did not reopen hub") end
if ns.Hub.current ~= "problem" or not ns.RuneForger.session or ns.RuneForger.session.index ~= idxBefore then
  fail("resume did not return to the same problem")
end
click("^Leave Forge$")

-- In-Flight Lessons (v0.7): takeoff -> toast -> quick round -> landing
hub:Hide()
do
  local FU, Fl = ns.FlightUI, ns.Flight
  local en = ns.LocaleData.enUS
  local function fly(dt) clock = clock + dt; update(0.6) end
  local function isLine(prefix, text)
    for i = 1, 20 do if en[prefix .. "_" .. i] and en[prefix .. "_" .. i] == text then return true end end
    return false
  end
  if not (FU and FU.watcher and FU.watcher.__scripts.OnUpdate) then fail("flight watcher exists") end
  if FU.Mode() ~= "toast" then fail("default flight mode is toast, got " .. tostring(FU.Mode())) end
  for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do
    if not (FU.watcher.__events and FU.watcher.__events[e]) then fail("flight watcher listens to " .. e) end
  end
  -- takeoff: nothing for the first couple of seconds, then the toast (hub stays closed)
  onTaxi = true
  fly(0)
  if FU.toast and FU.toast:IsShown() then fail("flight toast should wait a moment after takeoff") end
  fly(3)
  local toast = FU.toast
  if not (toast and toast:IsShown()) then fail("flight toast shown after takeoff") end
  if hub:IsShown() then fail("toast mode must not open the hub by itself") end
  if not (toast and isLine("FZ_FLIGHTSTART", toast.msg:GetText())) then fail("toast shows a Fizzwick flight line") end
  if not (findButton("^Start$") and findButton("^Not now$") and findButton("^Not this session$")) then fail("toast buttons") end
  -- Not now, and at most once per flight
  click("^Not now$")
  if toast:IsShown() then fail("Not now hides the toast") end
  fly(5); fly(5)
  if toast:IsShown() then fail("only one offer per flight") end
  -- event path: control gained while still flying does not re-offer
  fire("PLAYER_CONTROL_GAINED"); runTimers()
  if toast:IsShown() then fail("events don't re-offer on the same flight") end
  -- landing, next flight, ignored toast fades away
  onTaxi = false; fly(1)
  onTaxi = true; fly(0); fly(3)
  if not toast:IsShown() then fail("the next flight offers again") end
  for _ = 1, 12 do update(2.5) end
  if toast:IsShown() then fail("an ignored toast fades away") end
  onTaxi = false; fly(1)
  -- combat: toast hidden, no offer while fighting, offered once combat ends (still flying)
  onTaxi = true; fly(0)
  inCombat = true
  fire("PLAYER_REGEN_DISABLED")
  fly(3); fly(3)
  if toast:IsShown() or hub:IsShown() then fail("no flight popup in combat") end
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  fly(1)
  if not toast:IsShown() then fail("offered after combat while still on the taxi") end
  -- combat while the toast is up hides it
  inCombat = true; fire("PLAYER_REGEN_DISABLED")
  if toast:IsShown() then fail("combat hides the flight toast") end
  inCombat = false; fire("PLAYER_REGEN_ENABLED")
  onTaxi = false; fly(1)
  -- instance: no popup
  inInstance = true
  onTaxi = true; fly(0); fly(3)
  if toast:IsShown() or FU.lastSkip ~= "instance" then fail("no flight popup in an instance") end
  inInstance = false
  onTaxi = false; fly(1)
  -- Academy already open: no popup
  ns.Hub.Open("home")
  onTaxi = true; fly(0); fly(3)
  if toast:IsShown() or FU.lastSkip ~= "open" then fail("no flight popup while the Academy is open") end
  hub:Hide()
  onTaxi = false; fly(1)
  -- mode off
  slash("flight off")
  if ns.Progress.account.settings.flight.mode ~= "off" then fail("/aa flight off saves the mode") end
  onTaxi = true; fly(0); fly(3)
  if toast:IsShown() or hub:IsShown() or FU.lastSkip ~= "off" then fail("mode off: no popup") end
  onTaxi = false; fly(1)
  -- daily cap reached
  slash("flight toast")
  local m = ns.Progress.account.minutes
  local savedEarned = m.earned
  ns.Progress.GetTodayMinutes()
  m.earned = ns.Progress.account.settings.dailyCap
  onTaxi = true; fly(0); fly(3)
  if toast:IsShown() or FU.lastSkip ~= "cap" then fail("no flight popup once the daily cap is reached") end
  m.earned = savedEarned
  onTaxi = false; fly(1)
  -- Start: a short flight round, reward, another round while flying, landing keeps things open
  onTaxi = true; fly(0); fly(3)
  click("^Start$")
  local fs = ns.RuneForger.session
  if not (hub:IsShown() and ns.Hub.current == "problem" and fs and fs.flight) then fail("Start opens a flight round") end
  if fs and fs.mode == "practice" and fs.total ~= Fl.ROUND_SIZE then fail("flight practice round is 5 problems, got " .. tostring(fs.total)) end
  if ns.GuideUI.lastEvent ~= "FLIGHTSTART" then fail("Fizzwick greets the flight round") end
  playSession(1)
  local rv = ns.Hub.GetView("reward")
  if not (rv.summary and rv.summary.flight and rv.another:IsVisible()) then fail("'another round' offered after a flight round while flying") end
  if ns.GuideUI.lastEvent ~= "FLIGHTDONE" then fail("Fizzwick's flight-done line, got " .. tostring(ns.GuideUI.lastEvent)) end
  click("^Another round")
  local fs2 = ns.RuneForger.session
  if not (fs2 and fs2.flight and ns.Hub.current == "problem") then fail("another round starts") end
  -- land mid-round: round stays open, no penalty
  local idx = fs2 and fs2.index
  onTaxi = false; fly(1)
  if not (hub:IsShown() and ns.Hub.current == "problem" and ns.RuneForger.session == fs2 and fs2.index == idx) then fail("landing keeps the round open") end
  if ns.GuideUI.lastEvent ~= "FLIGHTLAND" then fail("Fizzwick's landing line") end
  playSession(1)
  if rv.another:IsVisible() then fail("no 'another round' on the ground") end
  hub:Hide()
  -- auto mode opens straight into the round
  slash("flight auto")
  onTaxi = true; fly(0); fly(3)
  if not (hub:IsShown() and ns.RuneForger.session and ns.RuneForger.session.flight) or toast:IsShown() then fail("auto mode opens a quick round") end
  -- combat during the flight round still hides the Academy; landing never reopens it
  inCombat = true; fire("PLAYER_REGEN_DISABLED")
  if hub:IsShown() then fail("combat still hides the Academy during a flight round") end
  onTaxi = false; fly(1)
  if hub:IsShown() then fail("landing must not reopen the Academy during combat") end
  inCombat = false; fire("PLAYER_REGEN_ENABLED")
  if ns.Hub.resumeToast then ns.Hub.resumeToast:Hide() end
  ns.RuneForger.session = nil
  -- "Not this session"
  slash("flight toast")
  onTaxi = true; fly(0); fly(3)
  click("^Not this session$")
  onTaxi = false; fly(1)
  onTaxi = true; fly(0); fly(3)
  if toast:IsShown() or FU.lastSkip ~= "muted" then fail("'Not this session' stops later offers") end
  onTaxi = false; fly(1)
  -- dev command: pretend takeoff without flying (ignores the mute), then pretend landing
  slash("flight test")
  fly(3)
  if not toast:IsShown() then fail("/aa flight test shows the toast") end
  slash("flight land")
  if toast:IsShown() or FU.tracker.onTaxi then fail("/aa flight land ends the pretend flight") end
  local before = #chat
  ns.Hub.Open("home")
  slash("flight test"); fly(3)
  local explained = false
  for i = before + 1, #chat do if chat[i]:find("already open", 1, true) then explained = true end end
  if toast:IsShown() or not explained then fail("/aa flight test explains why nothing showed") end
  slash("flight land")
  hub:Hide()
  -- the pretend flight ends by itself
  slash("flight test"); fly(3)
  click("^Not now$")
  fly(FU.SIM_SECONDS)
  if FU.tracker.onTaxi then fail("pretend flight lands by itself") end
  before = #chat
  slash("flight")
  if not (chat[before + 1] or ""):find("Ask first", 1, true) then fail("/aa flight prints the mode") end
  slash("flight banana")
end

slash("drill")
if not (hub:IsShown() and ns.RuneForger.session) then fail("/aa drill did not start a round") end

-- Parent panel: set PIN, lock, wrong PIN, right PIN, settings, export, reset
slash("parent")
if ns.Hub.current ~= "parent" then fail("parent view not shown") end
local pv = ns.Hub.GetView("parent")
local pins = {}
for _, w in ipairs(allFrames) do
  if w.__kind == "EditBox" and w:IsVisible() and w.__parent and w.__parent.__parent == pv then pins[#pins + 1] = w end
end
if #pins < 2 then fail("expected 2 PIN boxes on first visit, got " .. #pins) else
  pins[1]:SetText("1234"); pins[2]:SetText("9999"); click("^Save PIN$")
  if ns.Progress.HasPin() then fail("mismatched PIN should not be saved") end
  pins[1]:SetText("1234"); pins[2]:SetText("1234"); click("^Save PIN$")
  if not ns.Progress.HasPin() then fail("PIN not saved") end
end
if not pv.unlocked then fail("panel should unlock after setting PIN") end
click("^Lock$")
if pv.unlocked then fail("lock failed") end
pins[1]:SetText("0000"); click("^Unlock$")
if pv.unlocked then fail("wrong PIN unlocked panel") end
pins[1]:SetText("1234"); click("^Unlock$")
if not pv.unlocked then fail("right PIN did not unlock") end
-- settings
local boxes = {}
for _, w in ipairs(allFrames) do
  if w.__kind == "EditBox" and w:IsVisible() and w.__parent and w.__parent.__parent == pv then boxes[#boxes + 1] = w end
end
if #boxes >= 2 then
  boxes[1]:SetText("15"); boxes[2]:SetText("90"); click("^Save$")
  if ns.Progress.account.settings.minutesPerMastery ~= 15 or ns.Progress.account.settings.dailyCap ~= 90 then
    fail("minute rules not saved")
  end
else
  fail("settings boxes not found")
end
click("Unlock all tiers")
-- v0.2: parent start-tier override and trial re-run
local firstNode = ns.MathGen.BANDS.adept.nodes[1]
local before = ns.Trial.StartTier(firstNode)
local startBtn
for _, w in ipairs(allFrames) do
  if w.__kind == "Button" and w:IsVisible() and rawget(w, "nodeId") == firstNode then startBtn = w end
end
if not startBtn then fail("no Start override button for " .. firstNode) else
  startBtn:Click()
  if ns.Trial.StartTier(firstNode) ~= before % 3 + 1 then fail("Start override did not cycle the tier") end
end
click("Spaced reviews")
if ns.Progress.account.settings.reviews ~= false then fail("reviews toggle did not switch off") end
click("Spaced reviews")
click("^Re%-run Trial$")
if not ns.Trial.NeedsPlacement("runeforger", "adept") then fail("Re-run Trial did not reset placement") end
-- v0.3 subject picker
click("^Subject: ")
if pv:SubjectId() ~= "scribe" then fail("subject picker did not switch to Scribe's Scrolls") end
if not visibleText("Scribe's Scrolls progress") then fail("stats title did not follow the subject picker") end
click("^Export Report$")
local function exportBox()
  for _, w in ipairs(allFrames) do
    if w.__kind == "EditBox" and w:IsVisible() and (w.__text or ""):find("Progress Report") then return w.__text end
  end
end
local exportText = exportBox()
if not exportText then fail("export text not shown") else
  if not (exportText:find("SCRIBE'S SCROLLS", 1, true) and not exportText:find("RUNE FORGER", 1, true)) then
    fail("export should follow the picked subject")
  end
end
local guardScope = 0
while not findButton("^Report: All subjects$") and guardScope < 12 do click("^Report: "); guardScope = guardScope + 1 end
local allText = exportBox() or ""
if not (allText:find("SCRIBE'S SCROLLS", 1, true) and allText:find("RUNE FORGER", 1, true)) then fail("All subjects export should include both") end
click("^Close$")
-- v0.5: the picker walks every module (Lore Chronicles and the Lore Quiz too) and wraps around
local visited = {}
for _ = 1, #ns.Modules.list - 1 do -- currently on Scribe (module #2)
  click("^Subject: ")
  visited[pv:SubjectId()] = true
  if pv:SubjectId() == "lorequiz" and not visibleText("Everyone all ages") then fail("quiz stats should say Everyone (all ages)") end
end
if not (visited.lore and visited.lorequiz) then fail("subject picker should include Lore Chronicles and the Lore Quiz") end
if pv:SubjectId() ~= "runeforger" then fail("subject picker should cycle back to Rune Forger") end
click("^Export Report$")
click("^Close$")
click("^Reset Profile$")
click("RESET")
if ns.Progress.GetBand() ~= nil then fail("reset did not clear band") end
if ns.Hub.current ~= "profile" then fail("reset should return to profile setup") end
-- ESC behaviour simulated: hide re-locks parent panel
hub:Hide()
if pv.unlocked then fail("closing the hub should re-lock the parent panel") end

-------------------------------------------------------------------------
-- v0.4: Fizzwick, parrot hints, cameos, celebrations, sounds, reduced motion, per-tile drill
-------------------------------------------------------------------------
local GU, Gd = ns.GuideUI, ns.Guide
ns.Progress.SetBand("adept")
slash("")
if not (hub:IsShown() and ns.Hub.current == "home") then fail("v0.4: hub should reopen on home, got " .. tostring(ns.Hub.current)) end
local strip = GU.strip
if not (strip and strip:IsVisible()) then fail("guide strip not visible on home") end
if GU.lastEvent ~= "GREET" or (strip.text.__text or "") == "" then fail("Fizzwick did not greet on hub open") end
-- v0.5.1: the shipped posed art shows first (greet head crop in the strip)
runTimers(); runTimers()
local face = strip.face
local SHIPPED_ART = ns.ArtManifest
if ns.Art.Count(SHIPPED_ART) ~= 26 then fail("v0.5.1 manifest should list 26 posed files, got " .. ns.Art.Count(SHIPPED_ART)) end
GU.Say("GREET")
if not (face.mode == "art" and face.art:GetTexture() == ns.Art.DIR .. "fizzwick_greet_head" and face.art:IsShown()) then
  fail("hub open should show the greet head crop, got " .. tostring(face.art:GetTexture()))
end
-- the v0.4/v0.5 portrait checks below run without art (model / icon fallbacks)
ns.ArtManifest = {}
face.artName = nil
GU.ApplyFace("GREET")
runTimers(); runTimers()
-- Fizzwick's face: model on Forever/Classic, async fallback on Retail, icon in legacy
if LEGACY then
  if face.mode ~= "icon" or face.icon.__tex ~= Gd.CAST.fizzwick.icon then fail("legacy: Fizzwick should fall back to the icon") end
elseif INTERFACE == 120105 then
  if face.model.aaModelId ~= "display:7217" then fail("retail: unknown display 7340 should fall back to 7217, got " .. tostring(face.model.aaModelId)) end
  face:ShowCast(Gd.CAST.fizzwick)
  if face.model.aaModelId ~= "display:7217" then fail("retail: a display that failed once should be skipped next time") end
else
  if face.mode ~= "model" or face.model.aaModelId ~= "display:7340" then fail("Fizzwick model should use display 7340, got " .. tostring(face.model and face.model.aaModelId)) end
end
-- model that fails every SetDisplayInfo/SetCreature -> icon
if not LEGACY then
  local badHolder = GU.Portrait(UIParent, 50, 50)
  badHolder.model.SetDisplayInfo = function() error("bad id") end
  badHolder.model.SetCreature = function() error("bad id") end
  badHolder:ShowCast(Gd.CAST.horde)
  if badHolder.mode ~= "icon" or badHolder.icon.__tex ~= Gd.CAST.horde.icon then fail("failing model should fall back to the banner icon") end
end
-- greeting only once per open
local greetText = strip.text.__text
ns.Hub.ShowView("forge"); ns.Hub.ShowView("home")
if GU.lastEvent ~= "GREET" or strip.text.__text ~= greetText then fail("greeting should not repeat within one hub visit") end
-- full-height parent panel hides the strip
ns.Hub.ShowView("parent")
if strip:IsVisible() then fail("guide strip should hide in the Parent Panel") end
ns.Hub.ShowView("home")
if not strip:IsVisible() then fail("guide strip should come back on home") end

-- per-tile Quick Drill
local scribeDrill
for _, w in ipairs(allFrames) do
  if w.__kind == "Button" and w:IsVisible() and rawget(w, "moduleId") == "scribe" and w.__text == "Drill" then scribeDrill = w end
end
if not scribeDrill then fail("Scribe tile has no Drill button") else
  scribeDrill:Click()
  if ns.Lessons.moduleId ~= "scribe" then fail("tile Drill should switch to Scribe") end
  if ns.Hub.current == "trial" then click("^Skip for now$"); scribeDrill = nil; ns.Hub.ShowView("home"); click("^Drill$") end
end
ns.Hub.ShowView("home")
local runeDrill
for _, w in ipairs(allFrames) do
  if w.__kind == "Button" and w:IsVisible() and rawget(w, "moduleId") == "runeforger" and w.__text == "Drill" then runeDrill = w end
end
if not runeDrill then fail("Rune Forger tile has no Drill button") else
  runeDrill:Click()
  if ns.Hub.current == "trial" then click("^Skip for now$"); ns.Hub.ShowView("home"); runeDrill:Click() end
  if not (ns.Lessons.session and ns.Lessons.moduleId == "runeforger" and ns.Hub.current == "problem") then fail("Rune Forger Drill did not start a round") end
end

-- round start line + start sound, parrot hint, answer lines, combo glow, custom sound file
if ns.Lessons.session then
  if GU.lastEvent ~= "ROUNDSTART" then fail("round start should get a Fizzwick line, got " .. tostring(GU.lastEvent)) end
  local pview = ns.Hub.GetView("problem")
  local hintText = ns.Lessons.session.problem.hint or ""
  click("^Hint$")
  if GU.lastSpeaker ~= "parrot" or not (strip.text.__text or ""):find(hintText, 1, true) then fail("hint should come from Sprocket the parrot") end
  if not (ns.Compat.lastSound and ns.Compat.lastSound.event == "hint") then fail("hint should play the parrot sound") end
  local s = ns.Lessons.session
  -- wrong first
  local p = s.problem
  local wrongVal
  if p.mode == "choice" then for _, c in ipairs(p.choices) do if tostring(c) ~= tostring(p.answer) then wrongVal = c break end end else wrongVal = "987654" end
  clock = clock + 2
  pview:Answer(wrongVal)
  if GU.lastEvent ~= "WRONG" then fail("wrong answer should get encouragement, got " .. tostring(GU.lastEvent)) end
  if s.problemDone then local nb = findButton("^Next$"); if nb then nb:Click() end end
  -- now a run of right answers
  local sawCombo = false
  for _ = 1, 4 do
    if not (ns.Lessons.session == s and s.problem and not s.problemDone) then break end
    clock = clock + 2
    pview:Answer(s.problem.answer)
    if not (GU.lastEvent == "CORRECT" or GU.lastEvent == "COMBO" or GU.lastEvent == "OVERCHARGE" or GU.lastEvent == "MASTERED") then
      fail("right answer should get a Fizzwick line, got " .. tostring(GU.lastEvent))
    end
    if s.streak >= ns.Session.COMBO_AT and pview.comboGlow:IsShown() then sawCombo = true end
    if ns.Compat.lastSound and ns.Compat.lastSound.event == "correct" and ns.Compat.lastSound.how ~= "file" then fail("correct.ogg exists and should be played as a file") end
    runTimers()
  end
  if s.streak >= ns.Session.COMBO_AT and not sawCombo then fail("combo glow should show on a streak") end
end
if (fileTries["Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\click.ogg"] or 0) ~= 1 then fail("missing click.ogg should be tried once, then skipped") end
if not ns.Compat.missingSounds.click then fail("missing custom file not remembered") end
ns.Compat.Sound("click")
if not (ns.Compat.lastSound.how == "kit" and ns.Compat.lastSound.value == 856) then fail("click should fall back to SoundKit 856") end

-- reward screen: subject icon, shard count-up, glyph reveal (AnimationGroup or fallback)
ns.Lessons.session = nil
local scribeNode = ns.ScribeGen and ns.ScribeGen.BANDS and ns.ScribeGen.BANDS.adept.nodes[1] or ns.Modules.Nodes("scribe", "adept")[1]
ns.Lessons.StartRound(scribeNode, 1)
playSession(1.0)
local rview = ns.Hub.GetView("reward")
if rview.glyph.__tex ~= ns.Modules.Get("scribe").icon then fail("reward icon should be the Scribe icon, got " .. tostring(rview.glyph.__tex)) end
if LEGACY then
  if rview.revealMode ~= "fallback" then fail("legacy: glyph reveal should use the OnUpdate fallback") end
elseif rview.revealMode ~= "anim" then fail("glyph reveal should use an AnimationGroup, got " .. tostring(rview.revealMode)) end
update(2); update(2)
if not visibleText("Knowledge shards earned: %+%d+") then fail("shard counter missing on reward screen") end
local nodeR = ns.Modules.Nodes("runeforger", "adept")[1]
ns.Lessons.StartRound(nodeR, 1)
playSession(1.0)
if rview.glyph.__tex ~= ns.Modules.Get("runeforger").icon then fail("reward icon should follow the subject (Rune Forger)") end

-- reduced motion: static reveal, no sparks
ns.Progress.account.settings.reducedMotion = true
ns.Lessons.StartRound(nodeR, 1)
playSession(1.0)
if rview.revealMode ~= "static" then fail("reduced motion should make the reveal static") end
if not visibleText("Knowledge shards earned: %+%d+") then fail("reduced motion: shard total should show at once") end
ns.Progress.account.settings.reducedMotion = false

-- rank-up celebration, then the faction cameo (Horde/Alliance) or nothing (neutral/unknown)
Gd.lastCameoAt = nil
GU.Celebrate("RANK_ADEPT")
if not (GU.celebration and GU.celebration:IsShown()) then fail("rank-up celebration not shown") end
if not visibleText("New rank: Adept") then fail("celebration text missing") end
GU.celebration:Click()
local cam = GU.lastCameo
if FACTION == "Horde" then
  if not (cam and cam.who == "horde" and GU.cameo:IsShown() and visibleText("Thrall, Warchief of the Horde")) then fail("Horde player should see Thrall") end
  if GU.cameo.face.model.aaModelId ~= "display:4527" then fail("Thrall model should use display 4527") end
elseif FACTION == "Alliance" then
  if not (cam and cam.who == "alliance" and GU.cameo:IsShown() and visibleText("King Magni Bronzebeard")) then fail("Alliance player should see Magni") end
  if GU.cameo.face.model.aaModelId ~= "display:3597" then fail("Magni model should use display 3597") end
else
  if cam ~= nil or (GU.cameo and GU.cameo:IsShown()) then fail("neutral/unknown faction must not get a leader cameo") end
end
if GU.cameo and GU.cameo:IsShown() then click("^Thank you!$") end
if GU.cameo and GU.cameo:IsShown() then fail("cameo Thank you button should close the card") end
if GU.cameo then
  -- legacy text-only fallback check: icon when the model is unavailable
  if LEGACY and GU.cameo.face.mode ~= "icon" then fail("legacy cameo should be text + icon") end
end
Gd.lastCameoAt = nil
local again = GU.Cameo("RANKUP")
if FACTION and not again then fail("cameo should show again after the gap was reset") end
if again and GU.Cameo("EXAMPASS") then fail("second cameo inside the gap should be suppressed") end
if GU.cameo then GU.cameo:Hide() end

-- Parent Panel: sound / motion / cameo toggles
ns.Hub.ShowView("parent")
local pv2 = ns.Hub.GetView("parent")
for _, w in ipairs(allFrames) do
  if w.__kind == "EditBox" and w:IsVisible() and w.__parent and w.__parent.__parent == pv2 then w:SetText("1234") break end
end
click("^Unlock$")
if not pv2.unlocked then fail("v0.4: could not unlock parent panel") end
local snd = ns.Progress.account.settings.sound
click("^Sound channel: Effects$")
if snd.channel ~= "Master" then fail("channel toggle should cycle SFX -> Master") end
if lastChannel ~= "Master" then fail("sounds should play on the chosen channel, got " .. tostring(lastChannel)) end
click("^Sounds: All$")
if snd.level ~= "important" then fail("sound level toggle") end
local before2 = soundsPlayed
ns.Compat.Sound("click")
if soundsPlayed ~= before2 then fail("important-only should skip click sounds") end
click("^Sounds: Important only$")
click("^Custom sound files: ON$")
if snd.custom ~= false then fail("custom files toggle") end
click("^Custom sound files: OFF$")
click("^Reduced motion: OFF$")
if ns.Progress.account.settings.reducedMotion ~= true then fail("reduced motion toggle") end
click("^Reduced motion: ON$")
click("^Leader cameos: ON$")
if ns.Progress.account.settings.cameos ~= false then fail("cameo toggle") end
Gd.lastCameoAt = nil
if GU.Cameo("RANKUP") then fail("cameos switched off must not show") end
click("^Leader cameos: OFF$")
click("^Sound: ON$")
if snd.enabled ~= false then fail("mute toggle") end
before2 = soundsPlayed
ns.Compat.Sound("correct"); ns.Compat.Sound("rankup")
if soundsPlayed ~= before2 then fail("muted addon should play nothing") end
click("^Sound: OFF$")
if snd.enabled ~= true then fail("unmute toggle") end
-- v0.5: Lore Chronicles (trial, every node, typed answers), Lore Quiz for Everyone, art slots
ns.Progress.SetBand("adept")
ns.Hub.Open("home")
if not findButton("^Lore Chronicles$") then fail("Lore Chronicles should be a real hub tile") end
if findButton("^Lore Quiz for Everyone$") then fail("the quiz must not have a hub tile") end
click("^Lore Chronicles$")
if ns.Hub.current ~= "trial" or not visibleText("^The Chronicler's Trial$") then fail("Lore tile should open The Chronicler's Trial") end
click("^Begin the Trial$")
local lts = ns.RuneForger.session
if not (lts and lts.isTrial and lts.moduleId == "lore") then fail("Lore trial did not start") end
playSession(0.7, "trialResult")
if not (ns.Progress.char.modules.lore and ns.Progress.char.modules.lore.placement.adept.status == "done") then fail("Lore placement not saved") end
click("^Continue$")
if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= "lore" then fail("Continue should show the story list") end
if not visibleText("^Lore Chronicles %- Adept") then fail("story list title") end
if not findButton("^Lore Quiz %(for everyone%)$") then fail("story list should link to the Lore Quiz") end
ns.Progress.account.settings.unlockAllTiers = true
for _, bandId in ipairs({ "initiate", "adept", "magister" }) do
  for _, nodeId in ipairs(ns.Lore.BANDS[bandId].nodes) do
    for _, tier in ipairs({ 1, math.random(2, 3) }) do playUIRound(nodeId, tier, 0.75) end
  end
end
-- typed sentence building: wide box, case and the final period forgiven
ns.RuneForger.StartRound("lc_build", 2)
local bs = ns.RuneForger.session
local bp = bs and bs.problem
local be = visibleEdit()
if not (bp and bp.mode == "text" and be and be.__w == 420) then fail("Rune-tier sentence builder should be a wide text box") else
  be:SetText(bp.answer:lower():gsub("%.$", "")); be.__scripts.OnEnterPressed(be)
  if not (bs.problemDone and bs.firstCorrect == 1) then fail("built sentence should be accepted") end
end
runTimers()
ns.RuneForger.session = nil
-- written answer: a miss shows how many key ideas were found and keeps the text
ns.RuneForger.StartRound("lc_written", 3)
local wsn = ns.RuneForger.session
local wpp = wsn and wsn.problem
local we = visibleEdit()
if not (wpp and wpp.mode == "text" and wpp.rubric and we and we.__w == 420) then fail("Glyph written answer should be a wide text box") else
  we:SetText("I do not know"); we.__scripts.OnEnterPressed(we)
  if not visibleText("Key ideas found: 0 of %d") then fail("rubric feedback should show key ideas found") end
  if visibleText("WPM") then fail("rubric feedback must not show typing speed") end
  if we:GetText() ~= "I do not know" then fail("a written answer should stay in the box after a miss") end
  we:SetText(wpp.answer); we.__scripts.OnEnterPressed(we)
  if not wsn.problemDone then fail("model written answer should be accepted") end
end
runTimers()
ns.RuneForger.session = nil
-- long passages use a smaller font
ns.RuneForger.StartRound("lc_compare", 1)
if not (ns.RuneForger.session and ns.RuneForger.session.problem.mode == "choice" and #ns.RuneForger.session.problem.choices == 4) then fail("compare uses 4 buttons") end
ns.RuneForger.session = nil
-- Lore Quiz via the link button: no trial, no exam, back link
ns.Hub.ShowView("forge")
click("^Lore Quiz %(for everyone%)$")
if ns.Lessons.CurrentModule().id ~= "lorequiz" or ns.Hub.current ~= "forge" then fail("quiz link should open the quiz list") end
if not visibleText("^Lore Quiz %- Everyone %(all ages%)$") then fail("quiz title should say Everyone (all ages)") end
if findButton("^|cffffd100Mastery Exam|r$") or findButton("^Exam: ") or findButton("^Mastery Exam$") then fail("quiz must not offer an exam") end
for _, nodeId in ipairs(ns.Lore.QUIZ_BANDS.everyone.nodes) do playUIRound(nodeId, 1, 0.9) end
ns.Hub.ShowView("forge")
click("^Story lessons$")
if ns.Lessons.CurrentModule().id ~= "lore" then fail("Story lessons should return to Lore Chronicles") end
slash("quiz")
if ns.Lessons.CurrentModule().id ~= "lorequiz" or ns.Hub.current ~= "forge" then fail("/aa quiz should open the quiz") end
slash("trial")
if ns.Hub.current ~= "forge" then fail("the quiz has no trial: /aa trial should land on the topic list") end
slash("lore")
if ns.Lessons.CurrentModule().id ~= "lore" or ns.Hub.current ~= "forge" then fail("/aa lore should open Lore Chronicles") end
if not findButton("Mastery Exam") and not findButton("^Exam: ") then fail("Lore Chronicles shows its exam button again") end

-- v0.5.1 posed art: event -> pose, head crops in the strip, Sprocket states, idle poses,
-- full-figure heroes, refused files falling back
local Art = ns.Art
local face = GU.strip.face
local D = Art.DIR
local function faceIs(name) return face.mode == "art" and face.art:GetTexture() == D .. name and face.art:IsShown() end
ns.ArtManifest = SHIPPED_ART
GU.missingArt = {}
face.artName = nil
ns.Progress.account.settings.reducedMotion = true
for ev, pose in pairs({ CORRECT = "talking", ROUNDSTART = "talking", COMBO = "excited", OVERCHARGE = "excited", WRONG = "encouraging",
    MASTERED = "proud", EXAMPASS = "celebrating", EXAMTRY = "encouraging", GREET = "greet" }) do
  GU.Say(ev)
  if not faceIs("fizzwick_" .. pose .. "_head") then fail("v0.5.1: " .. ev .. " should show " .. pose .. " (head crop), got " .. tostring(face.art:GetTexture())) end
end
-- Sprocket: curious normally, squawk (+ Fizzwick teaching) while delivering a hint
GU.ApplyParrotArt("curious")
if GU.strip.parrot:GetTexture() ~= D .. "sprocket_curious_head" then fail("Sprocket should rest as sprocket_curious_head") end
GU.Parrot("Count the tens first.")
if GU.strip.parrot:GetTexture() ~= D .. "sprocket_squawk_head" or GU.strip.parrot:GetAlpha() ~= 1 then fail("Sprocket should squawk the hint") end
if not faceIs("fizzwick_teaching_head") then fail("hint: Fizzwick should be teaching") end
if not (GU.strip.text.__text or ""):find("Count the tens first.", 1, true) then fail("Sprocket delivers the hint line") end
GU.Say("CORRECT")
if GU.strip.parrot:GetTexture() ~= D .. "sprocket_curious_head" then fail("after the hint Sprocket goes back to curious") end
-- idle poses per subject, and Sprocket brightness for "hint available"
for mod, pose in pairs({ lore = "researching", lorequiz = "researching", runeforger = "tinkering", scribe = "thinking" }) do
  GU.Say("ROUNDSTART")
  GU.ProblemShown(mod, mod ~= "scribe")
  if not faceIs("fizzwick_talking_head") then fail("idle pose must wait a moment (" .. mod .. ")") end
  runTimers()
  if not faceIs("fizzwick_" .. pose .. "_head") then fail("idle in " .. mod .. " should be " .. pose .. ", got " .. tostring(face.art:GetTexture())) end
  local a = GU.strip.parrot:GetAlpha()
  if (mod ~= "scribe" and a < 0.8) or (mod == "scribe" and a > 0.5) then fail("Sprocket brightness should show whether a hint is available (" .. mod .. ")") end
end
GU.ProblemShown("lore", true)
GU.Say("CORRECT")
runTimers()
if not faceIs("fizzwick_talking_head") then fail("a new line cancels the pending idle pose") end
GU.Pose("surprised")
if not faceIs("fizzwick_surprised_head") then fail("GU.Pose should switch the strip pose") end

-- a real Lore round: idle -> researching, retry -> encouraging, worked example -> teaching
ns.RuneForger.StartRound("lc_sentence", 1)
local pv = ns.Hub.GetView("problem")
runTimers()
if not faceIs("fizzwick_researching_head") then fail("Lore round idle pose should be researching, got " .. tostring(face.art:GetTexture())) end
local function wrongValue(p)
  if p.mode == "choice" then
    for _, c in ipairs(p.choices) do if tostring(c) ~= tostring(p.answer) then return c end end
  end
  return "zzqx"
end
local ls = ns.RuneForger.session
step("lore wrong 1", function() pv:Answer(wrongValue(ls.problem)) end)
if not ls.problemDone then
  if not faceIs("fizzwick_encouraging_head") then fail("first miss should show encouraging") end
  step("lore wrong 2", function() pv:Answer(wrongValue(ls.problem)) end)
end
if not faceIs("fizzwick_teaching_head") then fail("worked example after a miss should show teaching, got " .. tostring(face.art:GetTexture())) end
local nb = findButton("^Next$")
if nb then nb:Click() end
runTimers()
playSession(1.0)
local rv = ns.Hub.GetView("reward")
if not (rv.hero and rv.hero:IsShown() and rv.hero.mode == "art" and rv.hero.art:GetTexture() == D .. "fizzwick_" .. tostring(rv.heroPose)) then
  fail("reward screen should show the full-figure pose, got " .. tostring(rv.hero and rv.hero.art:GetTexture()))
end
-- typing: a new personal best WPM -> surprised
ns.RuneForger.StartRound("sc_type_words", 1)
runTimers()
local ts2 = ns.RuneForger.session
ns.Progress.GetTierRec("sc_type_words", ts2.tier).bestWpm = 0
clock = clock + 3
step("typing best", function() pv:Answer(ts2.problem.answer) end)
if not faceIs("fizzwick_surprised_head") then fail("new best WPM should show surprised, got " .. tostring(face.art:GetTexture())) end
runTimers()
playSession(1.0)
-- per-skill icons on the forge rows
ns.Hub.ShowView("forge")
local rowIcons = 0
local wanted = {}
for _, nodeId in ipairs(ns.Modules.Nodes(ns.Lessons.CurrentModule().id, ns.Progress.GetBand and ns.Progress.GetBand() or "adept")) do
  wanted[ns.SkillIcons[nodeId] or "?"] = true
end
for _, w in ipairs(allFrames) do if w.__kind == "Texture" and wanted[w.__tex] and w:IsVisible() then rowIcons = rowIcons + 1; wanted[w.__tex] = nil end end
if rowIcons < 3 then fail("forge rows should show per-skill icons, found " .. rowIcons) end
local tr = ns.Hub.GetView("trialResult")
if tr and tr.hero and tr.heroPose and tr.hero.art:GetTexture() ~= D .. "fizzwick_" .. tr.heroPose then fail("trial result hero should match its pose") end
if not (tr and tr.heroPose == "proud") then fail("placement trial result should have shown Fizzwick proud, got " .. tostring(tr and tr.heroPose)) end
GU.Celebrate("RANK_ADEPT")
local cel = GU.celebration
if not (cel and cel.hero:IsShown() and cel.hero.art:GetTexture() == D .. "fizzwick_celebrating") then fail("rank-up card should show Fizzwick celebrating") end
cel:Hide()
runTimers()

-- refused files: head crop -> full figure -> greet -> model; heroes hide; Sprocket -> gear
local realSetTexture = methods.SetTexture
methods.SetTexture = function(self, t)
  if type(t) == "string" and t:find("Media\\Art\\fizzwick_encouraging_head", 1, true) then return false end
  return realSetTexture(self, t)
end
GU.missingArt = {}
face.artName = nil
GU.Say("WRONG")
if not (GU.missingArt.fizzwick_encouraging_head and faceIs("fizzwick_encouraging")) then fail("refused head crop should fall back to the full figure") end
methods.SetTexture = function(self, t)
  if type(t) == "string" and t:find("Media\\Art\\fizzwick_encouraging", 1, true) then return false end
  return realSetTexture(self, t)
end
GU.missingArt = {}
face.artName = nil
GU.Say("WRONG")
if not faceIs("fizzwick_greet_head") then fail("refused pose should fall back to greet") end
methods.SetTexture = function(self, t)
  if type(t) == "string" and t:find("Media\\Art\\", 1, true) then return false end
  return realSetTexture(self, t)
end
GU.missingArt = {}
face.artName = nil
GU.Say("CORRECT")
if face.mode == "art" or face.art:IsShown() then fail("with every art file refused, the model (or icon) comes back") end
if GU.ApplyParrotArt("squawk") ~= false or GU.strip.parrot:GetTexture() ~= ns.Guide.CAST.parrot.icon then fail("refused Sprocket art falls back to the gear icon") end
local hero = GU.Hero(UIParent, 100)
if GU.ShowHero(hero, "proud") ~= "none" or hero:IsShown() then fail("a hero slot without loadable art stays hidden") end
methods.SetTexture = realSetTexture
-- reduced motion off: no strip shipped, poses still apply
GU.missingArt = {}
face.artName = nil
ns.Progress.account.settings.reducedMotion = false
GU.Say("COMBO")
if not faceIs("fizzwick_excited_head") then fail("with motion allowed (no strip shipped) poses still show") end
-- no manifest at all = v0.5 behaviour
ns.ArtManifest = {}
GU.missingArt = {}
GU.Say("GREET")
GU.ApplyParrotArt()
if face.mode == "art" then fail("empty manifest = model portrait") end
if GU.ShowHero(hero, "proud") ~= "none" then fail("empty manifest = no hero") end
runTimers()
ns.ArtManifest = SHIPPED_ART
GU.missingArt = {}

-- v0.6 Murloc Boarding Party: hub shortcut, skill-list link, setup, live typing, stumbles,
-- splash, broadside, pause/resume, combat, the Tidehunter model, result + log, routes
do
  local BU, B = ns.BoardingUI, ns.Boarding
  local function typeText(box, text) box:SetText(text); box.__scripts.OnTextChanged(box, true) end
  ns.Progress.SetBand("adept")
  ns.Progress.account.settings.reducedMotion = false
  ns.Progress.account.settings.unlockAllTiers = false
  ns.Hub.Open("home")
  if not findButton("^Murlocs$") then fail("v0.6: the Scribe's Scrolls tile should have a Murlocs shortcut") end
  click("^Murlocs$")
  local bv = ns.Hub.GetView("boarding")
  if ns.Hub.current ~= "boarding" or not bv.setup:IsVisible() then fail("Murlocs shortcut should open the boarding setup") end
  if not findButton("^Set sail!$") then fail("setup should offer Set sail!") end
  if not visibleText("No voyages yet") then fail("empty voyage log text") end
  local ratchetBtn = bv.routeBtns[2]
  ratchetBtn:Click()
  if bv.selected ~= "bootybay" then fail("a locked route can't be selected") end
  if not (ratchetBtn.state.__text or ""):find("Locked", 1, true) then fail("locked route says how to unlock it") end
  -- skill list link + slash
  ns.Lessons.moduleId = "scribe"
  ns.Hub.ShowView("forge")
  if not findButton("Murloc Boarding Party") then fail("Scribe's skill list should link to Murloc Boarding Party") end
  click("Murloc Boarding Party")
  if ns.Hub.current ~= "boarding" then fail("skill-list link should open the game") end
  ns.Lessons.moduleId = "runeforger"
  ns.Hub.ShowView("forge")
  if findButton("Murloc Boarding Party") then fail("Rune Forger must not show the murloc link") end
  slash("murloc")
  if ns.Hub.current ~= "boarding" or ns.Lessons.CurrentModule().id ~= "scribe" then fail("/aa murloc should open the game") end

  -- set sail
  click("^Set sail!$")
  local g = BU.game
  if not (g and bv.play:IsVisible() and not bv.setup:IsVisible() and bv.game == g) then fail("Set sail! should start a voyage") end
  if GU.lastEvent ~= "BOARDSTART" then fail("Fizzwick should speak from the wheel at the start") end
  if bv.captain and not (bv.captain:IsShown() and bv.captain.art:GetTexture() == ns.Art.DIR .. "fizzwick_talking_head") then
    fail("Fizzwick's head should show at the ship's wheel")
  end
  if not (bv.wheelText.__text or ""):find("Wheel: 3", 1, true) then fail("adept shows 3 wheel points") end
  update(0.6)
  local m = g.murlocs[1]
  if not m then fail("a murloc should climb aboard") else
    local s = bv.slotOf[m.id]
    if not (s and s:IsShown() and s.icon:GetTexture() == BU.MURLOC_ICON and (s.label.__text or ""):find(m.text, 1, true)) then
      fail("murloc slot shows the murloc icon with its order")
    end
    local input = bv.input
    typeText(input, m.need:sub(1, 1))
    if not ((bv.orderText.__text or ""):find("|cff33ff66", 1, true) and g.target == m and s.ring:IsShown()) then
      fail("live typing: the typed letter turns green and the murloc is targeted")
    end
    typeText(input, m.need:sub(1, 1) .. "#")
    if input:GetText() ~= m.need:sub(1, 1) or g.typos ~= 1 or bv.lastStatus ~= "stumble" then fail("a typo is refused (crew stumbles), progress kept") end
    typeText(input, m.need)
    if g.splashed ~= 1 or input:GetText() ~= "" or s.label:IsShown() then fail("finishing the order splashes the murloc") end
    if not s.busy then fail("the splash animation runs (motion allowed)") end
    runTimers()
  end
  -- broadside
  update(0.2); update(5); update(5)
  g.meter = B.METER_MAX
  bv:Render()
  if not bv.fire:IsEnabled() then fail("a full meter enables the broadside button") end
  local onDeck = #g.murlocs
  click("Fire broadside")
  if g.meter ~= 0 or #g.murlocs ~= 0 or GU.lastEvent ~= "BOARDBROADSIDE" then fail("broadside clears the deck (" .. onDeck .. " murlocs)") end
  -- Enter fires too
  g.meter = B.METER_MAX
  bv.input.__scripts.OnEnterPressed(bv.input)
  if g.meter ~= 0 then fail("Enter fires the broadside") end
  -- pause / resume / combat
  bv.input.__scripts.OnEscapePressed(bv.input)
  if not (g.paused and bv.pause:IsVisible()) then fail("Escape pauses the voyage") end
  local t0 = g.time
  update(1)
  if g.time ~= t0 then fail("paused voyage does not tick") end
  click("^Resume$")
  if g.paused or bv.pause:IsShown() then fail("Resume continues the voyage") end
  hub:Hide()
  if not g.paused then fail("closing the hub pauses the voyage") end
  slash("")
  if ns.Hub.current ~= "boarding" or not bv.pause:IsVisible() then fail("reopening shows the paused voyage") end
  click("^Resume$")
  -- reduced motion: splash hides at once
  ns.Progress.account.settings.reducedMotion = true
  for _ = 1, 20 do if #g.murlocs > 0 then break end update(0.5) end
  local m2 = g.murlocs[1]
  if m2 then
    local s2 = bv.slotOf[m2.id]
    typeText(bv.input, m2.need)
    if s2:IsShown() or s2.busy then fail("reduced motion: the splashed murloc disappears without the flight animation") end
  else
    fail("another murloc should be aboard")
  end
  ns.Progress.account.settings.reducedMotion = false
  -- play to the end like a steady typist; the Tidehunter appears as a model
  local sawBoss, guard = false, 0
  local shards0 = ns.Progress.char.shards
  while not g.done and guard < 6000 do
    guard = guard + 1
    update(0.25)
    if g.done then break end
    local t = g.target
    if not t then for _, x in ipairs(g.murlocs) do if not t or x.pos > t.pos then t = x end end end
    if t then typeText(bv.input, g.typed .. t.need:sub(#g.typed + 1, #g.typed + 1)) end
    if g.bossSpawned and not g.done and not sawBoss then
      sawBoss = true
      local p = bv.boss.portrait
      if not bv.boss:IsShown() then fail("the Tidehunter shows on deck") end
      if LEGACY then
        if p.mode ~= "icon" then fail("legacy: Tidehunter falls back to the murloc icon") end
      elseif not (p.model and p.model.aaModelId == "display:1995") then
        fail("Tidehunter should use the in-game murloc model 1995, got " .. tostring(p.model and p.model.aaModelId))
      end
      if GU.lastEvent ~= "BOARDBOSS" then fail("Fizzwick announces the Tidehunter") end
    end
  end
  if not (g.done and g.won) then fail("the voyage should be won by a steady typist (" .. guard .. " steps)") end
  if not sawBoss then fail("the Tidehunter never appeared") end
  if #bv.slots > 10 then fail("murloc slots are pooled, not leaked (" .. #bv.slots .. ")") end
  if not (bv.result:IsVisible() and (bv.rTitle.__text or "") == ns.L.BOARD_WIN) then fail("result panel shows Voyage complete!") end
  if ns.Progress.char.shards <= shards0 then fail("the voyage pays shards") end
  if bv.hero and not (bv.hero:IsShown() and bv.hero.art:GetTexture() == ns.Art.DIR .. "fizzwick_" .. bv.heroPose) then fail("result shows Fizzwick's pose") end
  if not visibleText("New route unlocked: Booty Bay to Ratchet") then fail("result announces the unlocked route") end
  click("^Back to port$")
  if not bv.setup:IsVisible() then fail("Back to port returns to the setup") end
  if not visibleText("won") then fail("the voyage log lists the voyage") end
  if not B.Unlocked("ratchet") or (ratchetBtn.state.__text or ""):find("Locked", 1, true) then fail("Ratchet route unlocked in the setup") end
  ratchetBtn:Click()
  if bv.selected ~= "ratchet" then fail("an unlocked route can be selected") end
  click("^Set sail!$")
  if not (BU.game and BU.game.routeId == "ratchet" and BU.game ~= g) then fail("Set sail! uses the selected route") end
  click("^Back to port$")
  -- magister: exact typing, par time, initiate: no fail
  ns.Progress.SetBand("magister")
  click("^Set sail!$")
  local gm = BU.game
  if not (gm.band == "magister" and (bv.timeText.__text or ""):find("par", 1, true)) then fail("magister voyage shows the par time") end
  update(0.6)
  local mm = gm.murlocs[1]
  if mm then
    typeText(bv.input, mm.need:sub(1, 1):lower())
    if gm.target then fail("magister: a lowercase first letter does not match a capital") end
  end
  click("^Back to port$")
  ns.Progress.SetBand("initiate")
  click("^Set sail!$")
  if not (bv.wheelText.__text or ""):find("No-fail", 1, true) then fail("initiate voyage says no-fail") end
  click("^Back to port$")
  ns.Progress.SetBand("adept")
  local rep = ns.Report.Build({ moduleId = "scribe" })
  if not rep:find("Murloc Boarding Party:", 1, true) then fail("the parent report includes the voyage log") end
  ns.Hub.ShowView("home")
end

-- v0.6.1 minimap button
do
  local MB = ns.MinimapButton
  local b = MB.button
  if not (b and b:IsShown() and b:GetParent() == Minimap and _G.AzerothAcademyMinimapButton == b) then fail("minimap button created at login on the minimap") end
  if not (b.ring:GetTexture():find("MiniMap%-TrackingBorder") and b.__highlight and b.__drag and b.__clicks) then fail("standard minimap button look (ring, highlight, drag, clicks)") end
  if b.icon:GetTexture() ~= ns.Art.DIR .. "fizzwick_greet_head" then fail("minimap icon should be Fizzwick's head crop, got " .. tostring(b.icon:GetTexture())) end
  local p = b.__points[#b.__points]
  local r = math.sqrt(p[4] ^ 2 + p[5] ^ 2)
  if not (p[2] == Minimap and math.abs(r - 75) < 0.01 and p[4] < 0 and p[5] < 0) then fail("default position: lower-left on the rim") end
  -- tooltip
  b.__scripts.OnEnter(b)
  local tt = table.concat(tooltipLines, "\n")
  if not (tt:find("Azeroth Academy", 1, true) and tt:find("Left-click: open", 1, true) and tt:find("Right-click: Parent Panel", 1, true)
    and tt:find("Drag: move", 1, true) and tt:find("Shards", 1, true) and tt:find("Reviews due:", 1, true)) then
    fail("tooltip text: " .. tt)
  end
  if not tt:find("minutes", 1, true) and not tt:find("Minutes", 1, true) then fail("tooltip shows minutes today") end
  b.__scripts.OnLeave(b)
  -- clicks
  hub:Hide()
  b.__scripts.OnClick(b, "LeftButton")
  if not hub:IsShown() then fail("left-click opens the hub") end
  b.__scripts.OnClick(b, "LeftButton")
  if hub:IsShown() then fail("left-click again closes the hub") end
  local pv = ns.Hub.GetView("parent")
  pv.unlocked = true
  b.__scripts.OnClick(b, "RightButton")
  if not (hub:IsShown() and ns.Hub.current == "parent" and not pv.unlocked) then fail("right-click opens the Parent Panel behind its PIN") end
  inCombat = true
  hub:Hide()
  b.__scripts.OnClick(b, "LeftButton")
  if hub:IsShown() then fail("no hub from the minimap in combat") end
  inCombat = false
  -- drag around the rim (cursor above the minimap center -> north)
  b.__scripts.OnDragStart(b)
  if b.__scripts.OnUpdate == nil then fail("drag starts following the cursor") end
  cursorX, cursorY = 1000, 900
  b.__scripts.OnUpdate(b, 0.02)
  b.__scripts.OnDragStop(b)
  local m = ns.Progress.account.settings.minimap
  p = b.__points[#b.__points]
  if not (math.abs(m.angle - 90) < 0.01 and math.abs(p[4]) < 0.01 and math.abs(p[5] - 75) < 0.01 and b.__scripts.OnUpdate == nil) then
    fail("dragging moves the button and saves the angle (" .. tostring(m.angle) .. ")")
  end
  -- square minimap
  if not LEGACY then
    mmShape = "SQUARE"
    cursorX, cursorY = 1100, 800
    MB.DragUpdate()
    p = b.__points[#b.__points]
    local d = (math.sqrt(2 * 75 * 75) - 10) * math.cos(math.rad(45))
    if not (math.abs(p[4] - d) < 0.01 and math.abs(p[5] - d) < 0.01) then fail("square minimap: button sits in the corner") end
    mmShape = "ROUND"
  end
  -- hide / show: slash and Parent Panel
  slash("minimap")
  if b:IsShown() or not m.hide then fail("/aa minimap hides the button") end
  slash("minimap")
  if not b:IsShown() or m.hide then fail("/aa minimap shows it again") end
  ns.Hub.Open("parent")
  pv.unlocked = true
  pv:Refresh()
  if not (pv.minimapBtn and pv.minimapBtn:IsVisible() and (pv.minimapBtn.__text or ""):find("Minimap button: ON", 1, true)) then fail("Parent Panel shows the minimap toggle " .. tostring(pv.minimapBtn and pv.minimapBtn.__text) .. " vis=" .. tostring(pv.minimapBtn and pv.minimapBtn:IsVisible()) .. " unl=" .. tostring(pv.unlocked) .. " hub=" .. tostring(hub:IsShown())) end
  pv.minimapBtn:Click()
  if b:IsShown() or not (pv.minimapBtn.__text or ""):find("OFF", 1, true) then fail("Parent Panel toggle hides the button") end
  pv.minimapBtn:Click()
  if not b:IsShown() then fail("Parent Panel toggle shows it again") end
  -- a second login does not make a second button
  fire("PLAYER_LOGIN")
  if MB.button ~= b then fail("only one minimap button") end
  -- optional LibDBIcon path (another addon loaded it): register there, no own button
  do
    local reg, shown = nil, nil
    local LDB = { NewDataObject = function(_, name, obj) obj.__name = name; return obj end }
    local Icon = {
      Register = function(_, name, obj, dbt) reg = { name = name, obj = obj, db = dbt } end,
      Show = function() shown = true end, Hide = function() shown = false end,
    }
    LibStub = function(name) if name == "LibDataBroker-1.1" then return LDB elseif name == "LibDBIcon-1.0" then return Icon end end
    MB.button = nil
    MB.Create()
    if not (reg and reg.name == "AzerothAcademy" and reg.db == ns.Progress.account.settings.minimap and reg.obj.type == "launcher" and MB.button == nil and shown == true) then
      fail("LibDBIcon registration path")
    end
    hub:Hide()
    reg.obj.OnClick(nil, "LeftButton")
    if not hub:IsShown() then fail("LibDBIcon launcher click opens the hub") end
    slash("minimap")
    if shown ~= false then fail("/aa minimap hides the LibDBIcon button") end
    slash("minimap")
    LibStub = nil
    MB.libIcon, MB.button = nil, b
    b:Show()
  end
  hub:Hide()
end

hub:Hide()

-- v0.8: Fizzwick's recorded voice
do
  local GU, V = ns.GuideUI, ns.Voice
  local st = ns.Progress.account.settings
  local function lastClip() local v = voicePlays[#voicePlays]; return v and v.path:match("([%w_]+)%.ogg$") end
  if not (st.voice and st.voice.enabled == true) then fail("voice is on by default") end
  GU.voice = V.NewState()
  ns.Guide.ResetBags()
  clock = clock + 100
  local n0 = #voicePlays
  GU.Say("CORRECT")
  if #voicePlays ~= n0 + 1 or lastClip() ~= "correct" then fail("first right answer speaks the recorded line (" .. tostring(lastClip()) .. ")") end
  if GU.lastText ~= ns.L.FZ_CORRECT_1 then fail("the voice plays with its own bubble text") end
  if voicePlays[#voicePlays].channel ~= ns.SoundEvents.Channel(st.sound) then fail("voice uses the sound-effects channel") end
  GU.Say("COMBO") -- straight after: still talking
  if #voicePlays ~= n0 + 1 then fail("voice clips never overlap") end
  clock = clock + 10
  GU.Say("COMBO")
  if lastClip() ~= "combo" or GU.lastText ~= ns.L.FZ_COMBO_1 then fail("combo line spoken once the first clip is done") end
  GU.Say("RANKUP") -- a big moment may cut in
  if lastClip() ~= "rankup" or #voiceStops == 0 or voiceStops[#voiceStops] ~= voicePlays[#voicePlays - 1].handle then fail("rank-up interrupts the clip that was playing") end
  clock = clock + 10
  local n1 = #voicePlays
  for _ = 1, 4 do GU.Say("CORRECT"); clock = clock + 1 end
  if #voicePlays > n1 then fail("the same clip is throttled") end
  -- /aa voice
  slash("voice off")
  if st.voice.enabled ~= false then fail("/aa voice off saves the setting") end
  clock = clock + 60
  n1 = #voicePlays
  GU.Say("MASTERED"); GU.Parrot("Count the tens first.")
  if #voicePlays ~= n1 then fail("/aa voice off silences Fizzwick") end
  slash("voice on")
  if st.voice.enabled ~= true then fail("/aa voice on saves the setting") end
  GU.Say("MASTERED")
  if lastClip() ~= "mastered" or GU.lastText ~= ns.L.FZ_MASTERED_1 then fail("voice back on after /aa voice on") end
  slash("voice bogus")
  if st.voice.enabled ~= true then fail("unknown /aa voice argument changes nothing") end
  -- parrot hint uses the event clip
  clock = clock + 60
  GU.Parrot("Count the tens first.")
  if lastClip() ~= "hint" then fail("Sprocket's hint has a voice clip") end
  -- Sound OFF mutes the voice too
  st.sound.enabled = false
  clock = clock + 60
  n1 = #voicePlays
  GU.Say("WRONG")
  if #voicePlays ~= n1 then fail("sound mute silences the voice") end
  st.sound.enabled = true
  -- Parent Panel toggle
  ns.Hub.Open("parent")
  local pvv = ns.Hub.GetView("parent")
  pvv.unlocked = true
  pvv:Refresh()
  if not (pvv.voiceBtn and pvv.voiceBtn:IsVisible() and (pvv.voiceBtn.__text or ""):find("Fizzwick's voice: ON", 1, true)) then fail("Parent Panel shows the voice toggle (" .. tostring(pvv.voiceBtn and pvv.voiceBtn.__text) .. ")") end
  pvv.voiceBtn:Click()
  if st.voice.enabled ~= false or not (pvv.voiceBtn.__text or ""):find("OFF", 1, true) then fail("Parent Panel toggle turns the voice off") end
  pvv.voiceBtn:Click()
  if st.voice.enabled ~= true then fail("Parent Panel toggle turns the voice on") end
  -- goodbye: only after a real visit, never for a quick peek or a combat hide
  hub:Hide()
  clock = clock + 60
  n1 = #voicePlays
  ns.Hub.Open(); clock = clock + 2; hub:Hide()
  if #voicePlays ~= n1 then fail("no goodbye after a quick peek") end
  clock = clock + 60
  ns.Hub.Open(); clock = clock + 30
  inCombat = true; fire("PLAYER_REGEN_DISABLED")
  if hub:IsShown() or #voicePlays ~= n1 then fail("no goodbye when combat hides the window") end
  inCombat = false; fire("PLAYER_REGEN_ENABLED")
  clock = clock + 60
  ns.Hub.Open(); clock = clock + 30; hub:Hide()
  if lastClip() ~= "bye" then fail("Fizzwick says goodbye when the Academy closes (" .. tostring(lastClip()) .. ")") end
  -- a clip the client refuses is not retried
  GU.voice = V.NewState()
  voiceFail.greet = true
  clock = clock + 100
  n1 = #voicePlays
  local tries0 = fileTries[V.DIR .. "greet.ogg"] or 0
  GU.Say("GREET")
  if #voicePlays ~= n1 or not GU.voice.missing.greet then fail("a missing clip is remembered") end
  GU.voice.heard.GREET = nil
  clock = clock + 100
  GU.Say("GREET")
  if (fileTries[V.DIR .. "greet.ogg"] or 0) ~= tries0 + 1 then fail("a missing clip is not tried again") end
  voiceFail.greet = nil
  hub:Hide()
end

-- v0.9 Azeroth Naturalist: hub tile -> survey -> skill list -> every skill -> specimen ->
-- Field Journal (tabs, pages, faded ink -> review) -> in-flight nature round -> slash commands
do
  local en = ns.LocaleData.enUS
  local GU = ns.GuideUI
  local function isLine(prefix, text)
    for i = 1, 20 do if en[prefix .. "_" .. i] and en[prefix .. "_" .. i] == text then return true end end
    return false
  end
  ns.Progress.SetBand("adept")
  ns.Progress.account.settings.unlockAllTiers = false
  ns.Hub.Open("home")
  if not findButton("^Azeroth Naturalist$") then fail("Azeroth Naturalist should be a real hub tile") end
  if findButton("^Mechanics Academy$") == nil and #ns.Hub.Tiles() < 6 then fail("coming-soon tiles still listed") end
  click("^Azeroth Naturalist$")
  if ns.Hub.current ~= "trial" or not visibleText("^The Field Warden's Survey$") then fail("Naturalist tile should open The Field Warden's Survey") end
  click("^Begin the Trial$")
  local nts = ns.RuneForger.session
  if not (nts and nts.isTrial and nts.moduleId == "naturalist") then fail("Naturalist trial did not start") end
  playSession(0.7, "trialResult")
  if not (ns.Progress.char.modules.naturalist and ns.Progress.char.modules.naturalist.placement.adept.status == "done") then fail("Naturalist placement not saved") end
  click("^Continue$")
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= "naturalist" then fail("Continue should show the Naturalist skill list") end
  if not visibleText("^Azeroth Naturalist %- Adept") then fail("naturalist skill list title") end
  if not findButton("ccffField Journal|r$") then fail("skill list links to the Field Journal") end
  -- every skill in every band plays through the UI (buttons and typed answers)
  ns.Progress.account.settings.unlockAllTiers = true
  for _, bandId in ipairs({ "initiate", "adept", "magister" }) do
    for _, nodeId in ipairs(ns.Naturalist.BANDS[bandId].nodes) do
      for _, tier in ipairs({ 1, math.random(2, 3) }) do playUIRound(nodeId, tier, 0.75) end
    end
  end
  -- round start uses the Naturalist line (every time) and the page sound
  GU.voice = ns.Voice.NewState()
  clock = clock + 100
  ns.RuneForger.StartRound("nat_matter", 2)
  if GU.lastEvent ~= "NATSTART" or not isLine("FZ_NATSTART", GU.lastText) then fail("Naturalist round opens with a field-journal line, got " .. tostring(GU.lastEvent)) end
  if voicePlays[#voicePlays] == nil or not voicePlays[#voicePlays].path:find("nat_start", 1, true) then fail("first Naturalist round start speaks nat_start") end
  local tp = ns.RuneForger.session.problem
  if tp.mode == "text" then
    local e = visibleEdit()
    if not e then fail("typed Naturalist problem shows an edit box") else
      e:SetText("  " .. tp.answer:lower() .. "  "); e.__scripts.OnEnterPressed(e)
      if not (ns.RuneForger.session.problemDone and ns.RuneForger.session.firstCorrect == 1) then fail("typed Naturalist answer accepted (case/space forgiven)") end
    end
  end
  runTimers()
  ns.RuneForger.session = nil
  -- master a fresh tier -> specimen banner, sound, Fizzwick, reward line, journal button
  local nodeId, tier = "nat_ecosystems", 3
  local spec = ns.Journal.Specimen(nodeId, tier)
  if ns.Journal.Has(nodeId, tier) then fail("specimen should not be collected yet") end
  local gotBanner, guard = false, 0
  local specSounds0 = soundsPlayed
  while not ns.Progress.GetTierRec(nodeId, tier).mastered and guard < 6 do
    guard = guard + 1
    ns.RuneForger.StartRound(nodeId, tier)
    view = ns.Hub.GetView("problem")
    while ns.RuneForger.session and ns.Hub.current == "problem" do
      local s = ns.RuneForger.session
      clock = clock + 2
      step("nat answer", function() view:Answer(s.problem.answer) end)
      if visibleText("New specimen for your Field Journal") then gotBanner = true end
      runTimers(); update(0.5)
    end
  end
  if not ns.Progress.GetTierRec(nodeId, tier).mastered then fail("tier mastered through the UI") end
  if not ns.Journal.Has(nodeId, tier) then fail("mastery collected the specimen") end
  if not gotBanner then fail("problem view shows the new-specimen banner") end
  if soundsPlayed <= specSounds0 then fail("sounds played while collecting") end
  local rv = ns.Hub.GetView("reward")
  if ns.Hub.current ~= "reward" or not (rv.summary and rv.summary.specimens and rv.summary.specimens[1] == spec) then fail("reward summary carries the specimen") end
  if not visibleText(spec.name) then fail("reward screen names the specimen") end
  if GU.lastEvent ~= "NATSPECIMEN" then fail("Fizzwick celebrates the specimen, got " .. tostring(GU.lastEvent)) end
  if not (rv.journalBtn and rv.journalBtn:IsVisible()) then fail("reward screen offers the Field Journal") end
  click("^Open Field Journal$")
  local jv = ns.Hub.GetView("journal")
  if ns.Hub.current ~= "journal" then fail("Open Field Journal opens the journal") end
  if not (jv.selNode == nodeId and jv.selTier == tier and jv.band == "magister") then fail("journal opens on the new page") end
  if not visibleText("^" .. spec.name .. "$") or not visibleText("^Found in: ") then fail("journal page shows name + zone") end
  if GU.lastEvent ~= "NATJOURNAL" then fail("Fizzwick welcomes you to the journal") end
  if not visibleText("^Specimens: %d+ / 45") then fail("journal counter") end
  -- tabs + grid + a missing page offers practice
  click("^Initiate$")
  if jv.band ~= "initiate" or jv.selNode then fail("Initiate tab switches band and clears the page") end
  local first = ns.Naturalist.BANDS.initiate.nodes[1]
  local cell = jv.cells[1][3]
  if cell.nodeId ~= first then fail("grid row 1 is the first skill") end
  if not ns.Journal.Has(first, 3) then
    cell:Click()
    if not visibleText("^Undiscovered specimen$") then fail("missing page is a mystery") end
    if not findButton("^Go collect it!$") then fail("missing page offers practice") end
  end
  -- a collected page whose tier is fading shows faded ink and a review button
  local cnode, ctier
  for _, it in ipairs(ns.Journal.All()) do
    if it.band == "initiate" and ns.Journal.Has(it.nodeId, it.tier) then cnode, ctier = it.nodeId, it.tier break end
  end
  if not cnode then
    ns.Journal.Collect(first, 1); cnode, ctier = first, 1
    ns.Progress.GetTierRec(first, 1).mastered = true
  end
  local tr = ns.Progress.GetTierRec(cnode, ctier)
  tr.fading = true
  jv:OnShowView({ nodeId = cnode, tier = ctier })
  if not visibleText("The ink is fading") then fail("fading tier shows faded ink") end
  if not visibleText("page%(s%) fading") then fail("journal counts faded pages") end
  click("^Review now$")
  if ns.Hub.current ~= "problem" or ns.RuneForger.session.nodeId ~= cnode then fail("Review now starts that skill") end
  playSession(1)
  if tr.fading then fail("a good round clears the fading ink") end
  -- slash commands
  slash("journal")
  if ns.Hub.current ~= "journal" then fail("/aa journal opens the Field Journal") end
  slash("nature")
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= "naturalist" then fail("/aa nature opens Azeroth Naturalist") end
  click("ccffField Journal|r$")
  if ns.Hub.current ~= "journal" then fail("skill-list link opens the journal") end
  click("^Back$")
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= "naturalist" then fail("journal Back returns to the skill list") end
  -- In-flight: the quick round prefers sky skills and Fizzwick's habitat line
  local st = ns.Progress.account.settings
  local savedReviews = st.reviews
  st.reviews = false
  ns.Progress.SetBand("initiate")
  ns.Progress.GetModuleState("naturalist").placement.initiate = { status = "skipped", date = 0 }
  ns.Lessons.moduleId = "naturalist"
  ns.RuneForger.session = nil
  local started = ns.FlightUI.StartQuickRound()
  local fsn = ns.RuneForger.session
  if not (started and fsn and fsn.flight and fsn.moduleId == "naturalist") then fail("in-flight round on Naturalist") end
  local sky = false
  for _, id in ipairs(ns.Naturalist.MODULE.flightNodes.initiate) do if fsn and fsn.nodeId == id then sky = true end end
  if not sky then fail("in-flight Naturalist round uses a sky skill, got " .. tostring(fsn and fsn.nodeId)) end
  if GU.lastEvent ~= "NATFLIGHT" or not isLine("FZ_NATFLIGHT", GU.lastText) then fail("in-flight Naturalist line, got " .. tostring(GU.lastEvent)) end
  playSession(1)
  st.reviews = savedReviews
  ns.Progress.SetBand("adept")
  ns.Progress.account.settings.unlockAllTiers = false
  -- report line
  if not ns.Report.Build({}):find("Field Journal: %d+ / 45") then fail("progress report shows the Field Journal") end
  hub:Hide()
end


-- v0.11+: a curated/generated subject with a collection book, end to end through the UI
local function subjectSmoke(cfg)
  local en = ns.LocaleData.enUS
  local GU = ns.GuideUI
  local function isLine(prefix, text)
    for i = 1, 20 do if en[prefix .. "_" .. i] and en[prefix .. "_" .. i] == text then return true end end
    return false
  end
  local mod = ns.Modules.Get(cfg.id)
  ns.Progress.SetBand("adept")
  ns.Progress.account.settings.unlockAllTiers = false
  ns.Hub.Open("home")
  if not findButton("^" .. cfg.tile .. "$") then fail(cfg.tile .. " should be a real hub tile") end
  click("^" .. cfg.tile .. "$")
  if ns.Hub.current ~= "trial" or not visibleText("^" .. en[mod.placementKey] .. "$") then fail(cfg.tile .. " tile should open its trial") end
  click("^Begin the Trial$")
  local ts = ns.RuneForger.session
  if not (ts and ts.isTrial and ts.moduleId == cfg.id) then fail(cfg.id .. " trial did not start") end
  playSession(0.7, "trialResult")
  if not (ns.Progress.char.modules[cfg.id] and ns.Progress.char.modules[cfg.id].placement.adept.status == "done") then fail(cfg.id .. " placement not saved") end
  click("^Continue$")
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= cfg.id then fail("Continue should show the " .. cfg.id .. " skill list") end
  if not findButton("ccff" .. en[mod.game.key] .. "|r$") then fail("skill list links to the book") end
  -- every skill in every band plays through the UI
  ns.Progress.account.settings.unlockAllTiers = true
  for _, bandId in ipairs({ "initiate", "adept", "magister" }) do
    for _, nodeId in ipairs(mod.bands[bandId].nodes) do
      for _, tier in ipairs({ 1, math.random(2, 3) }) do playUIRound(nodeId, tier, 0.75) end
    end
  end
  GU.voice = ns.Voice.NewState()
  clock = clock + 100
  local firstNode = mod.bands.adept.nodes[1]
  ns.RuneForger.StartRound(firstNode, 1)
  if GU.lastEvent ~= cfg.startEvent or not isLine("FZ_" .. cfg.startEvent, GU.lastText) then fail(cfg.id .. " round opens with its own line, got " .. tostring(GU.lastEvent)) end
  if cfg.startVoice and (voicePlays[#voicePlays] == nil or not voicePlays[#voicePlays].path:find(cfg.startVoice, 1, true)) then fail(cfg.id .. " round start speaks " .. cfg.startVoice) end
  runTimers()
  ns.RuneForger.session = nil
  if cfg.extra then cfg.extra() end
  -- master a fresh tier -> book banner, Fizzwick, reward line, book button
  local nodeId, tier = mod.bands.magister.nodes[5], 3
  local item = ns.Journal.Specimen(nodeId, tier)
  if ns.Journal.Has(nodeId, tier) then fail(cfg.id .. " item should not be collected yet") end
  local gotBanner, guard = false, 0
  local newText = en[cfg.prefix .. "_NEW"]:gsub("%%s.*$", "")
  while not ns.Progress.GetTierRec(nodeId, tier).mastered and guard < 6 do
    guard = guard + 1
    ns.RuneForger.StartRound(nodeId, tier)
    local view = ns.Hub.GetView("problem")
    while ns.RuneForger.session and ns.Hub.current == "problem" do
      local s = ns.RuneForger.session
      clock = clock + 2
      step(cfg.id .. " answer", function() view:Answer(s.problem.answer) end)
      if visibleText(newText) then gotBanner = true end
      runTimers(); update(0.5)
    end
  end
  if not ns.Progress.GetTierRec(nodeId, tier).mastered then fail(cfg.id .. " tier mastered through the UI") end
  if not ns.Journal.Has(nodeId, tier) then fail(cfg.id .. " mastery collected the item") end
  if not gotBanner then fail(cfg.id .. " problem view shows the new-item banner") end
  local rv = ns.Hub.GetView("reward")
  if ns.Hub.current ~= "reward" or not (rv.summary and rv.summary.specimens and rv.summary.specimens[1] == item) then fail(cfg.id .. " reward summary carries the item") end
  if GU.lastEvent ~= cfg.newEvent then fail("Fizzwick celebrates the " .. cfg.id .. " item, got " .. tostring(GU.lastEvent)) end
  local openText = en[cfg.prefix .. "_OPEN"]
  if not (rv.journalBtn and rv.journalBtn:IsVisible() and rv.journalBtn:GetText() == openText) then fail("reward screen offers " .. openText) end
  click("^" .. openText .. "$")
  local jv = ns.Hub.GetView("journal")
  if ns.Hub.current ~= "journal" or jv.moduleId ~= cfg.id then fail(openText .. " opens the right book") end
  if not (jv.selNode == nodeId and jv.selTier == tier) then fail(cfg.id .. " book opens on the new page") end
  if not visibleText("^" .. en[cfg.prefix .. "_TITLE"] .. "$") then fail(cfg.id .. " book title") end
  if not visibleText("^" .. item.name .. "$") then fail(cfg.id .. " page shows the item name") end
  if GU.lastEvent ~= cfg.openEvent then fail("Fizzwick opens the " .. cfg.id .. " book, got " .. tostring(GU.lastEvent)) end
  local countPat = "^" .. en[cfg.prefix .. "_COUNT"]:gsub("%%d", "%%d+"):gsub("%(", "%%("):gsub("%)", "%%)")
  if not visibleText(countPat) then fail(cfg.id .. " book counter") end
  if jv.cells[1][1].nodeId ~= mod.bands.magister.nodes[1] then fail(cfg.id .. " grid shows this subject's skills") end
  click("^Back$")
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= cfg.id then fail(cfg.id .. " book Back returns to its skill list") end
  -- slash commands + hub tile button
  slash(cfg.slashBook)
  if ns.Hub.current ~= "journal" or ns.Hub.GetView("journal").moduleId ~= cfg.id then fail("/aa " .. cfg.slashBook .. " opens the book") end
  slash("journal")
  if ns.Hub.GetView("journal").moduleId ~= "naturalist" then fail("/aa journal still opens the Field Journal") end
  slash(cfg.slashSubject)
  if ns.Hub.current ~= "forge" or ns.Lessons.CurrentModule().id ~= cfg.id then fail("/aa " .. cfg.slashSubject .. " opens the subject") end
  ns.Hub.Open("home")
  click("^" .. en[mod.game.tileKey] .. "$")
  if ns.Hub.current ~= "journal" then fail(cfg.id .. " tile book button opens a book") end
  ns.Progress.SetBand("adept")
  ns.Progress.account.settings.unlockAllTiers = false
  if not ns.Report.Build({}):find(en[cfg.prefix .. "_STATUS"]:gsub("%%d", "%%d+"), 1) then fail("progress report shows the " .. cfg.id .. " book") end
  hub:Hide()
end

step("v0.11 gnomish engineering", function()
  subjectSmoke({
    id = "gnomish", tile = "Gnomish Engineering", prefix = "BLUEPRINT",
    startEvent = "GESTART", newEvent = "GEBLUEPRINT", openEvent = "GEBINDER",
    slashBook = "blueprints", slashSubject = "gnomish", startVoice = "ge_start",
    extra = function()
      -- a grid puzzle draws Boltby, the gear or letters, and the question beside it
      local seen = 0
      for _ = 1, 6 do
        ns.RuneForger.StartRound("ge_program", 1)
        local view = ns.Hub.GetView("problem")
        local p = ns.RuneForger.session.problem
        if p.grid then
          seen = seen + 1
          if not view.grid:IsShown() then fail("grid shown for a grid puzzle") end
          local botCell = view.grid.cells[(p.grid.bot[2] - 1) * view.grid.maxSide + p.grid.bot[1]]
          if not (botCell.icon:IsShown() and botCell.icon.__tex == ns.W.GRID_ICONS.bot) then fail("Boltby drawn on the grid") end
          view:Answer(p.answer)
          if ns.RuneForger.session.firstCorrect ~= 1 then fail("program answer accepted") end
        end
        runTimers()
        ns.RuneForger.session = nil
      end
      if seen == 0 then fail("program puzzles carry a grid") end
      ns.RuneForger.StartRound("ge_directions", 1)
      local p = ns.RuneForger.session.problem
      local view = ns.Hub.GetView("problem")
      if p.grid and p.grid.marks then
        if not visibleText("^A$") then fail("letters drawn on the grid") end
      end
      runTimers()
      ns.RuneForger.session = nil
      ns.RuneForger.StartRound("ge_sequence", 1)
      if ns.Hub.GetView("problem").grid:IsShown() then fail("grid hidden for non-grid questions") end
      ns.RuneForger.session = nil
      local _ = view
      -- duel setup lists the new subject
      ns.Hub.Open("duel")
      if not findButton("Gnomish Engineering") then fail("duel setup lists Gnomish Engineering") end
    end,
  })
end)

step("v0.12 librarian quests", function()
  subjectSmoke({
    id = "librarian", tile = "Librarian Quests", prefix = "PASSPORT",
    startEvent = "LIBSTART", newEvent = "LIBSTAMP", openEvent = "LIBPASSPORT",
    slashBook = "passport", slashSubject = "library", startVoice = "lib_start",
    extra = function()
      -- tables and indexes are shown left-aligned like a page of a book
      ns.RuneForger.StartRound("lib_tables", 1)
      local p = ns.RuneForger.session.problem
      if not p.code then fail("data tables use the left-aligned page layout") end
      ns.Hub.GetView("problem"):Answer(p.answer)
      if ns.RuneForger.session.firstCorrect ~= 1 then fail("table answer accepted") end
      runTimers()
      ns.RuneForger.session = nil
      ns.RuneForger.StartRound("lib_factopinion", 1)
      if ns.Hub.GetView("problem").grid:IsShown() then fail("no grid on library questions") end
      ns.RuneForger.session = nil
      ns.Hub.Open("duel")
      if not findButton("Librarian Quests") then fail("duel setup lists Librarian Quests") end
      slash("research")
      if ns.Lessons.CurrentModule().id ~= "librarian" then fail("/aa research opens Librarian Quests") end
      slash("stamps")
      if ns.Hub.current ~= "journal" or ns.Hub.GetView("journal").moduleId ~= "librarian" then fail("/aa stamps opens the passport") end
    end,
  })
end)

-- v0.10 Duel of Wits: host a party race, join one by invite, auto-declines,
-- version mismatch, combat forfeit, parent settings, random queue, minimap entry
step("v0.10 duel of wits", function()
  local DP, DU, Duel = ns.DuelProto, ns.DuelUI, ns.Duel
  local GU = ns.GuideUI
  ns.Progress.SetBand("adept")
  if not LEGACY and not prefixes[DP.PREFIX] then fail("duel prefix registered at login") end
  if not DU.engine then fail("duel engine created at login") end
  local function decode(i) return DP.Decode(addonSent[i].msg) end
  local function lastSent(mtype)
    for i = #addonSent, 1, -1 do
      local _, t, f = decode(i)
      if t == mtype then return addonSent[i], f end
    end
  end
  local function peer(mtype, from, channel, ...)
    fire("CHAT_MSG_ADDON", DP.PREFIX, DP.Encode(mtype, ...), channel or "WHISPER", from)
  end
  local function tick(sec)
    for _ = 1, math.floor(sec / 0.25 + 0.5) do clock = clock + 0.25; update(0.25) end
  end
  local function chatHas(pat) for _, m in ipairs(chat) do if m:find(pat, 1, true) then return true end end end

  -- entry points: hub button, slash, minimap
  slash("")
  if ns.Hub.current ~= "home" then ns.Hub.ShowView("home") end
  click("Duel of Wits")
  if ns.Hub.current ~= "duel" then fail("hub button opens Duel of Wits") end
  local dv = ns.Hub.GetView("duel")
  if dv.mode ~= "setup" then fail("duel opens on setup") end
  hub:Hide()
  local mm = named.AzerothAcademyMinimapButton
  if mm then
    if not (mm.__clicks and table.concat(mm.__clicks, ","):find("MiddleButtonUp")) then fail("minimap registers middle-click") end
    mm.__scripts.OnClick(mm, "MiddleButton")
    if not (hub:IsShown() and ns.Hub.current == "duel") then fail("middle-click opens duels") end
    hub:Hide()
    shiftDown = true
    mm.__scripts.OnClick(mm, "LeftButton")
    shiftDown = false
    if not (hub:IsShown() and ns.Hub.current == "duel") then fail("shift-click opens duels") end
    local tl = table.concat(ns.MinimapButton.TooltipLines(), "\n")
    if not tl:find("Duel of Wits", 1, true) then fail("minimap tooltip mentions duels") end
  end

  -- (1) host a party race
  slash("duel")
  if ns.Hub.current ~= "duel" then fail("/aa duel opens the setup") end
  click("Rune Forger")
  click("Questions: 5")
  click("My group")
  click("^Send challenge$")
  if not visibleText("You are not in a group.") then fail("party duel without a group explains why") end
  inGroup = true
  click("> My group <")
  click("^Send challenge$")
  local inv, f = lastSent("INV")
  if not (inv and inv.channel == "PARTY" and f[2] == "runeforger" and f[3] == "5") then fail("INV broadcast to the party") end
  local id = f and f[1]
  if not visibleText("Waiting room") then fail("lobby shows the waiting room") end
  peer("ACC", "Pal-Testrealm", "WHISPER", id, "initiate", "Pal", 2, 3, "0.10.0")
  if not visibleText("^Pal") then fail("lobby lists the new racer") end
  click("^Start race!$")
  local sta, sf = lastSent("STA")
  if not (sta and sta.channel == "PARTY" and tonumber(sf[2])) then fail("STA with a seed goes to the party") end
  if dv.mode ~= "race" then fail("countdown switches to the race screen") end
  if GU.lastEvent ~= "DUELSTART" then fail("Fizzwick starts the duel, got " .. tostring(GU.lastEvent)) end
  tick(1)
  if not (dv.big.__text == "3" or dv.big.__text == "2") then fail("countdown digits, got " .. tostring(dv.big.__text)) end
  peer("ACK", "Pal-Testrealm", "WHISPER", id, "STA")
  tick(3)
  local E = DU.engine
  if E.duel.state ~= "race" then fail("race starts after 3-2-1") end
  -- the peer's set is reproducible from the seed + its band
  local peerSet = Duel.BuildSet("runeforger", "initiate", E.duel.seed, 5)
  if not (peerSet and #peerSet == 5) then fail("peer can rebuild its set") end
  for q = 1, 5 do
    local p = E:Current()
    if not p then fail("question " .. q .. " shown") break end
    local btn
    for _, b in ipairs(dv.choices) do if b:IsVisible() and tostring(b.value) == tostring(q == 2 and "__no__" or p.answer) then btn = b end end
    if q == 2 then
      for _, b in ipairs(dv.choices) do if b:IsVisible() and tostring(b.value) ~= tostring(p.answer) then btn = b end end
    end
    if not btn then fail("answer button for question " .. q) break end
    clock = clock + 2
    btn:Click()
    if q == 2 and not (dv.feedback.__text or ""):find("+3 seconds", 1, true) then fail("wrong answer shows the penalty") end
    if q == 2 then peer("PRG", "Pal-Testrealm", "WHISPER", id, 1, 2, 2, 4000, 0, 0) end
  end
  if not visibleText("Waiting for the other racers") then fail("finished host waits for the others") end
  if GU.lastEvent ~= "DUELWAIT" then fail("Fizzwick cheers while waiting, got " .. tostring(GU.lastEvent)) end
  peer("FIN", "Pal-Testrealm", "WHISPER", id, 2, 5, 3, 14000, 0, 0)
  tick(0.5)
  if dv.mode ~= "result" then fail("results screen after everyone finished, got " .. tostring(dv.mode)) end
  if not visibleText("Winner: ") then fail("results name a winner") end
  if not visibleText("You earned %d+ shards") then fail("results show the reward") end
  local res = lastSent("RES")
  if not (res and res.channel == "PARTY") then fail("host broadcasts RES") end
  if not (GU.lastEvent == "DUELWIN" or GU.lastEvent == "DUELDONE") then fail("Fizzwick reacts to the result") end
  if ns.Progress.char.duel.played ~= 1 then fail("duel stats recorded") end
  click("^Good game!$")
  local emo, ef = lastSent("EMO")
  if not (emo and emo.channel == "WHISPER" and ef[2] == "1") then fail("emote sends a preset id only") end
  peer("EMO", "Pal-Testrealm", "WHISPER", id, 2)
  if not chatHas("Pal: Well played!") then fail("incoming emote shown as preset text") end
  if not findButton("^Block$") then fail("results offer Block") else click("^Block$") end
  if not DU.IsBlocked("Pal-Testrealm") then fail("Block stores the player") end
  click("^New duel$")
  if dv.mode ~= "setup" or E.duel then fail("New duel returns to setup") end
  peer("INV", "Pal-Testrealm", "WHISPER", "77701", "scribe", 5, "WHISPER", "Pal", "initiate", 1, 1, "0.10.0")
  if E.invite then fail("blocked player's invite ignored") end
  local dec, df = lastSent("DEC")
  if not (dec and df[2] == "busy") then fail("blocked invite gets a neutral 'busy'") end
  ns.Util.Wipe(ns.Progress.account.duel.blocked)

  -- (2) accept an invite, then combat forfeits
  hub:Hide()
  peer("INV", "Rival-Testrealm", "WHISPER", "88801", "naturalist", 5, "WHISPER", "Rival", "magister", 4, 5, "0.10.0")
  local popup = named.AzerothAcademyDuelInvite
  if not (popup and popup:IsShown()) then fail("invite pop-up shows with the window closed") end
  if not visibleText("Rival challenges you") then fail("pop-up names the challenger") end
  click("^Accept$")
  local acc, af = lastSent("ACC")
  if not (acc and acc.target == "Rival-Testrealm" and af[1] == "88801") then fail("ACC whispered to the host") end
  if not (hub:IsShown() and ns.Hub.current == "duel") then fail("accepting opens the waiting room") end
  peer("LOB", "Rival-Testrealm", "WHISPER", "88801", "naturalist", 5, "WHISPER", 2,
    "Rival-Testrealm", "Rival", "magister", 4, 5, "joined", "Hexkid-Testrealm", "Hexkid", "adept", 1, 1, "joined")
  if not visibleText("Waiting for the challenger") then fail("racer waits for the host") end
  peer("STA", "Rival-Testrealm", "WHISPER", "88801", 4242, 3, "adept", "naturalist", 5, "WHISPER", 2,
    "Rival-Testrealm", "Rival", "magister", 4, 5, "Hexkid-Testrealm", "Hexkid", "adept", 1, 1)
  if not (lastSent("ACK") and E.duel and E.duel.state == "countdown") then fail("racer ACKs STA and counts down") end
  tick(3.5)
  if not E:Current() then fail("racer gets questions") end
  local mine = Duel.BuildSet("naturalist", "adept", 4242, 5)
  if not (mine and E.duel.set[1].text == mine[1].text) then fail("racer set comes from the shared seed + own band") end
  inCombat = true
  fire("PLAYER_REGEN_DISABLED")
  local lev, lf = lastSent("LEV")
  if not (lev and lf[2] == "combat") then fail("combat sends LEAVE(combat)") end
  if not chatHas("You left the race because combat started") then fail("combat forfeit explained") end
  if E.duel then fail("combat leaves the duel") end
  peer("INV", "Rival-Testrealm", "WHISPER", "88802", "lore", 5, "WHISPER", "Rival", "magister", 4, 5, "0.10.0")
  local dec2, d2 = lastSent("DEC")
  if not (dec2 and d2[1] == "88802" and d2[2] == "combat") then fail("invite in combat auto-declined") end
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  inInstance = true
  peer("INV", "Rival-Testrealm", "WHISPER", "88803", "lore", 5, "WHISPER", "Rival", "magister", 4, 5, "0.10.0")
  local _, d3 = lastSent("DEC")
  if not (d3 and d3[1] == "88803" and d3[2] == "instance") then fail("invite in an instance auto-declined") end
  if not chatHas("said no to a duel challenge") then fail("auto-decline mentioned in chat") end
  inInstance = false
  -- version mismatch
  fire("CHAT_MSG_ADDON", DP.PREFIX, (DP.Encode("INV", "99901", "runeforger", 5, "WHISPER", "Future", "adept", 1, 1, "9.0"):gsub("^AA%d+", "AA9")), "WHISPER", "Future-Testrealm")
  local ver, vf = lastSent("VER")
  if not (ver and vf[1] == "99901" and tonumber(vf[2]) == DP.VERSION) then fail("version mismatch answered with VER") end
  if not chatHas("different Azeroth Academy version") then fail("version mismatch explained") end
  if E.invite then fail("mismatched invite not shown") end
  -- invite timeout auto-declines
  peer("INV", "Slow-Testrealm", "WHISPER", "55501", "runeforger", 10, "WHISPER", "Slow", "adept", 1, 1, "0.10.0")
  if not E.invite then fail("normal invite shown") end
  tick(26)
  local _, d4 = lastSent("DEC")
  if E.invite or not (d4 and d4[1] == "55501" and d4[2] == "timeout") then fail("unanswered invite auto-declines") end
  if popup:IsShown() then fail("pop-up closes on timeout") end
  -- parent switch
  ns.Progress.account.settings.duel.enabled = false
  peer("INV", "Pal-Testrealm", "PARTY", "66601", "runeforger", 5, "PARTY", "Pal", "adept", 1, 1, "0.10.0")
  local _, d5 = lastSent("DEC")
  if E.invite or not (d5 and d5[2] == "parent") then fail("parent switch auto-declines") end
  ns.Progress.account.settings.duel.enabled = true

  -- (3) Parent Panel: duel settings overlay
  ns.Hub.Open("parent")
  local pv3 = ns.Hub.GetView("parent")
  pv3.unlocked = true
  pv3:Refresh()
  click("^Duel of Wits settings$")
  if not (pv3.duelPanel and pv3.duelPanel:IsShown()) then fail("duel settings overlay opens") end
  if not findButton("^Allow random challengers: Off$") then fail("random challengers default Off") end
  click("^Allow random challengers: Off$")
  if not ns.Progress.account.settings.duel.random then fail("random toggle saved") end
  click("^Friends only: Off$")
  if not ns.Progress.account.settings.duel.friendsOnly then fail("friends-only toggle saved") end
  click("^Friends only: On$")
  local before = ns.Duel.AliasText(ns.Progress.account.settings.duel.alias[1], ns.Progress.account.settings.duel.alias[2])
  click("^Duel name: ")
  local after = ns.Duel.AliasText(ns.Progress.account.settings.duel.alias[1], ns.Progress.account.settings.duel.alias[2])
  if before == after then fail("alias cycles") end
  click("^Close$")
  ns.Hub.ShowView("home")

  -- (4) random queue
  slash("duel queue")
  if DU.sel.scope ~= "QUEUE" then fail("/aa duel queue picks the random queue") end
  click("^Find a random challenger$")
  if LEGACY then
    if not visibleText("A parent can turn on random challengers") then fail("legacy client explains the queue is unavailable") end
  else
    if not (E.queue and joinedChannels[#joinedChannels] == "AzerothAcademyQ") then fail("queue joins the hidden channel") end
    tick(1)
    local q, qf = lastSent("Q")
    if not (q and q.channel == "CHANNEL" and q.target == 5 and #qf == 4) then fail("queue beacon on the hidden channel carries 4 fields") end
    if not visibleText("Looking for a challenger") then fail("queue status shown") end
    -- a matching beacon from another kid: lower nonce hosts. Force us to host.
    E.queue.nonce = "000000000"
    peer("Q", "Stranger-Otherrealm", "CHANNEL", "runeforger", 5, "adept", "999999999")
    local qi, qif = lastSent("INV")
    if not (qi and qi.target == "Stranger-Otherrealm" and qif[4] == "QUEUE" and qif[5] == "") then fail("queue match sends an anonymous invite") end
    peer("ACC", "Stranger-Otherrealm", "WHISPER", qif[1], "adept", "", 7, 8, "0.10.0")
    if not (E.duel and E.duel.state == "countdown") then fail("queue duel starts automatically") end
    if E.queue or leftChannels[#leftChannels] ~= "AzerothAcademyQ" then fail("matched: left the hidden channel") end
    tick(4)
    local anyName = false
    for _, b in ipairs(dv.bars) do if (b.name.__text or ""):find("Stranger", 1, true) then anyName = true end end
    if anyName then fail("random duel never shows the character name") end
    if not visibleText("Daring Mechastrider") and not visibleText(ns.Duel.AliasText(7, 8)) then fail("random opponent shown by alias") end
    click("^Leave race$")
    if E.duel then fail("leave race works") end
    -- stop searching
    slash("duel queue")
    click("^Find a random challenger$")
    click("^Stop searching$")
    if E.queue then fail("stop searching leaves the queue") end
  end
  ns.Progress.account.settings.duel.random = false
  inGroup = false
  hub:Hide()
end)

slash("status"); slash("help"); slash("nudge"); slash("nudge")
runTimers()
update(1)

io.write(string.format("UI smoke (interface %d" .. (LEGACY and ", legacy fallbacks" or "") .. ", flavor %s): %d frames created, %d sounds, %d voice clips, %d chat lines, %d errors\n",
  INTERFACE, tostring(ns.Compat.flavor), #allFrames, soundsPlayed, #voicePlays, #chat, errors))
if exportText then io.write("--- export sample ---\n" .. exportText:sub(1, 900) .. "\n") end
_ = realPrint
os.exit(errors == 0 and 0 or 1)

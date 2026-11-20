-- Bootstrap: saved variables, events, slash commands, combat + flight-path hooks.
local ADDON, ns = ...
local C, L = ns.Compat, ns.L

local events = CreateFrame("Frame", "AzerothAcademyEvents")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CHAT_MSG_ADDON") -- v0.10 Duel of Wits
events:RegisterEvent("CHAT_MSG_SYSTEM") -- v1.2.4 "No player named ..." after a duel whisper
-- v1.2.4: hide that system line when it answers one of our own duel whispers (it used to
-- repeat every 2 seconds); real whispers the player typed are never touched.
if ChatFrame_AddMessageEventFilter then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
    if ns.Compat and ns.Compat.WhisperFailName and ns.Compat.WhisperFailName(msg) then return true end
    return false
  end)
end

local function init()
  if ns.ready then return end
  if type(AzerothAcademyDB) ~= "table" then AzerothAcademyDB = {} end
  if type(AzerothAcademyCharDB) ~= "table" then AzerothAcademyCharDB = {} end
  ns.Progress.Bind(AzerothAcademyDB, AzerothAcademyCharDB)
  -- v1.1: Bind switched ns.L to the saved language; frames built from now on use its font
  C.SetUIFont(ns.locale)
  ns.ready = true
end

events:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      init()
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    init()
    if ns.MinimapButton then pcall(ns.MinimapButton.Create) end
    if ns.DuelUI then pcall(ns.DuelUI.Init) end
    C.Print(string.format(L.LOADED, ns.VERSION))
    if ns.Progress.GetBand() then
      local due = #ns.Review.Due()
      if due > 0 then C.Print(string.format(L.REVIEW_DUE_CHAT, due)) end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if ns.FlightUI then ns.FlightUI.HideToast() end
    if ns.DuelUI then ns.DuelUI.OnCombat() end
    if ns.Hub then ns.Hub.HideForCombat() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.Hub then ns.Hub.OfferResume() end
  elseif event == "CHAT_MSG_ADDON" then
    -- arg1 prefix, arg2 message, arg3 channel, arg4 sender
    if arg1 == ns.DuelProto.PREFIX and ns.ready and ns.DuelUI then ns.DuelUI.Receive(arg2, arg3, arg4) end
  elseif event == "CHAT_MSG_SYSTEM" then
    if ns.ready and ns.DuelUI and ns.DuelUI.OnSystem then pcall(ns.DuelUI.OnSystem, arg1) end
  end
end)

-- Flight paths: UI/Flight.lua watches UnitOnTaxi (v0.7 In-Flight Lessons; replaces the chat nudge).

-- Slash commands ---------------------------------------------------------------
SLASH_AZEROTHACADEMY1 = "/aa"
SLASH_AZEROTHACADEMY2 = "/academy"
-- /aa <word> -> open a subject's skill list / a collection book
local SUBJECT_SLASH = {
  forge = "runeforger", scribe = "scribe", lore = "lore", quiz = "lorequiz",
  nature = "naturalist", naturalist = "naturalist", science = "naturalist",
  gnomish = "gnomish", engineering = "gnomish", code = "gnomish", coding = "gnomish",
  library = "librarian", librarian = "librarian", research = "librarian",
  mechanics = "mechanics", tactics = "mechanics", training = "mechanics",
  -- v1.1 World Tongues
  tongues = "tongues_ja", languages = "tongues_ja", japanese = "tongues_ja", nihongo = "tongues_ja",
  spanish = "tongues_es", espanol = "tongues_es",
}
local BOOK_SLASH = {
  journal = "naturalist", bestiary = "naturalist",
  blueprints = "gnomish", binder = "gnomish",
  passport = "librarian", stamps = "librarian",
  deck = "mechanics", cards = "mechanics",
}

SlashCmdList.AZEROTHACADEMY = function(msg)
  init()
  local raw = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  msg = raw:lower()
  if msg == "duel" or msg:match("^duel%s") then
    -- v0.10: keep the original case of a character name
    if ns.DuelUI then ns.DuelUI.Slash(raw:match("^%S+%s+(.+)$") or "") end
    return
  end
  if msg == "" then
    ns.Hub.Toggle()
  elseif msg == "drill" then
    if C.InCombat() then C.Print(L.NO_COMBAT) return end
    ns.Lessons.QuickDrill()
  elseif msg == "review" then
    if C.InCombat() then C.Print(L.NO_COMBAT) return end
    ns.Hub.Open("home")
    if ns.Hub.IsShown() and ns.Progress.GetBand() then ns.Lessons.StartReview() end
  elseif msg == "trial" or msg == "exam" then
    ns.Hub.Open("trial", msg == "exam" and "exam" or "placement")
  elseif msg == "parent" or msg == "settings" or msg == "options" then
    ns.Hub.Open("parent")
  elseif msg == "lang" or msg == "language" or msg:match("^lang%s") or msg:match("^language%s") then
    -- v1.1 language picker: /aa lang (status) | /aa lang <code|auto>
    local arg = msg:match("^%S+%s+(.+)$")
    if arg then ns.LanguageUI.Slash(arg) else ns.LanguageUI.Slash(""); ns.Hub.Open("language", "home") end
  elseif SUBJECT_SLASH[msg] and not ns.Modules.IsShown(SUBJECT_SLASH[msg]) then
    C.Print(L.AREA_HIDDEN) -- v1.1: switched off in Settings > Areas to Show
  elseif SUBJECT_SLASH[msg] then
    ns.Lessons.moduleId = SUBJECT_SLASH[msg]
    ns.Hub.Open("forge")
  elseif msg == "murloc" or msg == "murlocs" or msg == "ship" or msg == "boarding" then
    if C.InCombat() then C.Print(L.NO_COMBAT) return end
    ns.Lessons.moduleId = "scribe"
    ns.Hub.Open("boarding", "setup")
  elseif BOOK_SLASH[msg] and ns.Modules.Get(BOOK_SLASH[msg]) then
    if C.InCombat() then C.Print(L.NO_COMBAT) return end
    ns.Lessons.moduleId = BOOK_SLASH[msg]
    ns.Hub.Open("journal", { moduleId = BOOK_SLASH[msg] })
  elseif msg == "minimap" then
    if ns.MinimapButton then
      ns.MinimapButton.Create()
      local hidden = ns.MinimapButton.Toggle()
      C.Print(string.format(L.MM_TOGGLED, hidden and L.OFF or L.ON))
    end
  elseif msg == "flight" or msg:match("^flight%s") or msg == "nudge" then
    local FU, F = ns.FlightUI, ns.Flight
    local action, value = F.ParseCommand(msg:match("^flight%s+(.*)$") or "")
    if msg == "nudge" then -- v0.6 command kept: flips In-Flight Lessons off / back on
      action, value = "set", FU.Mode() == "off" and F.DEFAULT_MODE or "off"
    end
    if action == "set" then
      FU.SetMode(value)
      C.Print(string.format(L.FLIGHT_STATUS, FU.ModeName()))
    elseif action == "test" then
      C.Print(string.format(L.FLIGHT_TEST, FU.ModeName()))
      FU.Test()
    elseif action == "land" then
      FU.Land()
      C.Print(L.FLIGHT_LANDED_TEST)
    elseif action == "status" then
      C.Print(string.format(L.FLIGHT_STATUS, FU.ModeName()))
      C.Print(L.FLIGHT_HELP)
    else
      C.Print(L.FLIGHT_HELP)
    end
  elseif msg == "voice" or msg:match("^voice%s") then
    local arg = msg:match("^voice%s+(%S+)") or ""
    local st = ns.Progress.account.settings
    if type(st.voice) ~= "table" then st.voice = {} end
    if arg == "on" then st.voice.enabled = true
    elseif arg == "off" then st.voice.enabled = false
    elseif arg == "" then st.voice.enabled = st.voice.enabled == false
    else C.Print(L.VOICE_HELP) return end
    C.Print(string.format(L.VOICE_TOGGLED, st.voice.enabled ~= false and L.ON or L.OFF))
  elseif msg == "status" then
    local info = ns.Progress.GetRankInfo()
    local earned, cap = ns.Progress.GetTodayMinutes()
    local art = ns.Art.Count(ns.ArtManifest)
    C.Print(string.format("%s | %s | %s | %s | client: %s (interface %d)",
      string.format(L.RANK_LINE, L[info.key]), string.format(L.SHARDS_LINE, ns.Progress.char.shards),
      string.format(L.MINUTES_LINE, earned, cap), string.format(L.ART_PARENT, art > 0 and tostring(art) or L.OFF),
      C.FLAVOR_NAMES[C.flavor] or C.flavor, C.interface))
  else
    C.Print(L.HELP)
  end
end

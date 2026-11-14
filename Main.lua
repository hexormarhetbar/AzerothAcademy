-- Bootstrap: saved variables, events, slash commands, combat + flight-path hooks.
local ADDON, ns = ...
local C, L = ns.Compat, ns.L

local events = CreateFrame("Frame", "AzerothAcademyEvents")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

local function init()
  if ns.ready then return end
  if type(AzerothAcademyDB) ~= "table" then AzerothAcademyDB = {} end
  if type(AzerothAcademyCharDB) ~= "table" then AzerothAcademyCharDB = {} end
  ns.Progress.Bind(AzerothAcademyDB, AzerothAcademyCharDB)
  ns.ready = true
end

events:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      init()
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    init()
    if ns.MinimapButton then pcall(ns.MinimapButton.Create) end
    C.Print(string.format(L.LOADED, ns.VERSION))
    if ns.Progress.GetBand() then
      local due = #ns.Review.Due()
      if due > 0 then C.Print(string.format(L.REVIEW_DUE_CHAT, due)) end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if ns.FlightUI then ns.FlightUI.HideToast() end
    if ns.Hub then ns.Hub.HideForCombat() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.Hub then ns.Hub.OfferResume() end
  end
end)

-- Flight paths: UI/Flight.lua watches UnitOnTaxi (v0.7 In-Flight Lessons; replaces the chat nudge).

-- Slash commands ---------------------------------------------------------------
SLASH_AZEROTHACADEMY1 = "/aa"
SLASH_AZEROTHACADEMY2 = "/academy"
SlashCmdList.AZEROTHACADEMY = function(msg)
  init()
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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
  elseif msg == "parent" then
    ns.Hub.Open("parent")
  elseif msg == "forge" or msg == "scribe" or msg == "lore" or msg == "quiz" then
    local ids = { forge = "runeforger", scribe = "scribe", lore = "lore", quiz = "lorequiz" }
    ns.Lessons.moduleId = ids[msg]
    ns.Hub.Open("forge")
  elseif msg == "murloc" or msg == "murlocs" or msg == "ship" or msg == "boarding" then
    if C.InCombat() then C.Print(L.NO_COMBAT) return end
    ns.Lessons.moduleId = "scribe"
    ns.Hub.Open("boarding", "setup")
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

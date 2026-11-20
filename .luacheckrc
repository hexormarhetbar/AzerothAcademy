std = "lua51"
max_line_length = false
codes = true
exclude_files = { "tests/**" }
ignore = {
  "212", -- unused argument (WoW handler signatures)
  "432", -- shadowing upvalue argument 'self'
}
globals = {
  "AzerothAcademyDB", "AzerothAcademyCharDB",
  "SLASH_AZEROTHACADEMY1", "SLASH_AZEROTHACADEMY2", "SlashCmdList",
  "UISpecialFrames",
}
read_globals = {
  "time", "date", "GetTime", "GetBuildInfo", "GetClassInfo", "GetLocale", "GetRealmName",
  "CreateFrame", "UIParent", "PlaySound", "SOUNDKIT", "C_Timer",
  "BackdropTemplateMixin", "STANDARD_TEXT_FONT", "GameFontHighlight",
  "InCombatLockdown", "UnitAffectingCombat", "UnitOnTaxi", "UnitName",
  "DEFAULT_CHAT_FRAME", "WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT",
  "PlaySoundFile", "StopSound", "UnitFactionGroup",
  "Minimap", "GameTooltip", "GetCursorPosition", "GetMinimapShape", "LibStub", "IsInInstance",
  -- v0.10 Duel of Wits comms
  "C_ChatInfo", "SendAddonMessage", "RegisterAddonMessagePrefix", "GetNormalizedRealmName", "Ambiguate", "ERR_CHAT_PLAYER_NOT_FOUND_S", "ChatFrame_AddMessageEventFilter",
  "IsInRaid", "IsInGroup", "GetNumRaidMembers", "GetNumPartyMembers", "IsInGuild",
  "C_FriendList", "GetNumFriends", "GetFriendInfo", "GetChannelName", "JoinTemporaryChannel",
  "LeaveChannelByName", "ChatFrame_RemoveChannel", "ChatFrameUtil", "NUM_CHAT_WINDOWS", "_G",
  "IsShiftKeyDown",
  -- v1.1 language picker
  "ReloadUI",
}

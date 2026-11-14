-- Sound registry (pure data + decision logic; Adapters/Compat.lua does the playing).
-- Every event maps to built-in client SoundKits (tried in order: SOUNDKIT name,
-- then numeric kit ID). A parent can drop a custom file at
--   Interface\AddOns\AzerothAcademy\Media\Sounds\<event>.ogg
-- and it is tried first. The addon ships NO audio files; see Media/Sounds/README.md.
local _, ns = ...

local S = {}
ns.SoundEvents = S

S.DIR = "Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\"
S.CHANNELS = { "SFX", "Master", "Dialog", "Ambience" }
S.LEVELS = { "all", "important" }

-- Older kits first in each list: they exist on every client (Forever, Retail, Classic Era).
S.EVENTS = {
  click      = { kits = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 } },
  open       = { kits = { "IG_SPELLBOOK_OPEN", 829 } },
  close      = { kits = { "IG_SPELLBOOK_CLOSE", 830 } },
  correct    = { kits = { "IG_QUEST_LIST_COMPLETE", 878 }, important = true },
  wrong      = { kits = { "IG_MAINMENU_OPTION_CHECKBOX_OFF", 857 }, important = true }, -- soft tick, never a buzzer
  combo      = { kits = { "LOOT_WINDOW_COIN_SOUND", 120 } },
  overcharge = { kits = { "UI_EPICLOOT_TOAST", 31578, "LEVELUPSOUND", 888 }, important = true },
  forge      = { kits = { "PUT_DOWN_GEMS", 1204, "IG_ABILITY_OPEN", 834 } },
  scroll     = { kits = { "IG_ABILITY_PAGE_TURN", 836 } },
  reward     = { kits = { "LEVELUPSOUND", 888, "IG_QUEST_LIST_COMPLETE", 878 }, important = true },
  rankup     = { kits = { "LEVELUPSOUND", 888, "UI_EPICLOOT_TOAST", 31578 }, important = true },
  exampass   = { kits = { "UI_WORLDQUEST_COMPLETE", 73277, "LEVELUPSOUND", 888 }, important = true },
  chirp      = { kits = { "TELL_MESSAGE", 3081 } },
  hint       = { kits = { "MAP_PING", 3175 } },
  cameo      = { kits = { "READY_CHECK", 8960 } },
  -- v0.6 Murloc Boarding Party (numeric kits from the game's own sound data)
  splash     = { kits = { 1097, 1096 } },               -- CharacterSplashSoundLarge, then Medium
  cannon     = { kits = { 1400, 3641 }, important = true }, -- Cannon01 blast, then CannonDeath
  gurgle     = { kits = { 416, 1109 } },                -- MurlocAggro ("mrglglgl"), then MurlocAlert
  -- v0.7/v0.8 In-Flight Lesson pop-up chime
  flight     = { kits = { "TELL_MESSAGE", 3081 } },
  -- v0.9 Azeroth Naturalist / Field Journal
  page       = { kits = { "IG_ABILITY_PAGE_TURN", 836 } },
  specimen   = { kits = { "IG_QUEST_LIST_COMPLETE", 878 }, important = true },
}
S.ORDER = { "click", "open", "close", "correct", "wrong", "combo", "overcharge", "forge",
  "scroll", "reward", "rankup", "exampass", "chirp", "hint", "cameo", "splash", "cannon", "gurgle", "flight",
  "page", "specimen" }

S.DEFAULTS = { enabled = true, channel = "SFX", level = "all", custom = true }

function S.FilePath(event) return S.DIR .. event .. ".ogg" end

local function valid(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

function S.Channel(settings)
  local ch = settings and settings.channel
  return valid(S.CHANNELS, ch) and ch or S.DEFAULTS.channel
end

-- Returns the ordered list of things to try for an event, or nil if nothing should
-- play (muted, filtered by "important only", unknown event).
--   { { file = path }, { kit = "NAME" }, { kit = 856 }, ... }
-- `missing` is a set of events whose custom file already failed this session.
function S.Plan(event, settings, missing)
  local def = S.EVENTS[event]
  if not def then return nil end
  settings = settings or S.DEFAULTS
  if settings.enabled == false then return nil end
  if settings.level == "important" and not def.important then return nil end
  local plan = {}
  if settings.custom ~= false and not (missing and missing[event]) then
    plan[#plan + 1] = { file = S.FilePath(event) }
  end
  for _, k in ipairs(def.kits) do plan[#plan + 1] = { kit = k } end
  return plan
end

function S.Cycle(list, cur)
  for i, v in ipairs(list) do
    if v == cur then return list[i % #list + 1] end
  end
  return list[1]
end

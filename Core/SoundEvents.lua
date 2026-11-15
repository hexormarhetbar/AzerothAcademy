-- Sound registry (pure data + decision logic; Adapters/Compat.lua does the playing).
-- Every event maps to built-in client SoundKits (tried in order: SOUNDKIT name,
-- then numeric kit ID). A parent can drop a custom file at
--   Interface\AddOns\AzerothAcademy\Media\Sounds\<event>.ogg
-- and it is tried first (the addon ships one per event); see Media/Sounds/README.md.
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
  -- v0.10 Duel of Wits
  countdown  = { kits = { "RAID_WARNING", 8959 } },
  duelwin    = { kits = { "UI_EPICLOOT_TOAST", 31578, "LEVELUPSOUND", 888 }, important = true },
  -- v0.11 Gnomish Engineering: workshop gears (round start + new blueprint)
  gears      = { kits = { "PUT_DOWN_GEMS", 1204, "IG_ABILITY_OPEN", 834 } },
  -- v0.12 Librarian Quests: passport stamp (new stamp)
  stamp      = { kits = { "IG_ABILITY_PAGE_TURN", 836, "IG_QUEST_LIST_COMPLETE", 878 } },
  -- v0.13 Mechanics Academy: training-yard horn (round start + new tactics card)
  drill      = { kits = { "READY_CHECK", 8960 } },
}
S.ORDER = { "click", "open", "close", "correct", "wrong", "combo", "overcharge", "forge",
  "scroll", "reward", "rankup", "exampass", "chirp", "hint", "cameo", "splash", "cannon", "gurgle", "flight",
  "page", "specimen", "countdown", "duelwin", "gears", "stamp", "drill" }

S.DEFAULTS = { enabled = true, channel = "SFX", level = "all", custom = true }

-- v1.2.3 speech channel rules (pure; Adapters/Compat.lua applies them). Speech = Fizzwick's
-- voice lines and the World Tongues clips: only one plays at a time, it starts a moment after
-- the press (and after a stinger that is still ringing), and sound effects get out of its way.
S.SPEECH_DELAY = 0.2     -- seconds from the press / event to the start of a speech clip
S.SPEECH_WAIT_MAX = 2.1  -- longest a speech clip waits for a stinger that is still playing (rankup 2.05 s)
S.SFX_WAIT_MAX = 0.8     -- an important effect waits for speech that ends within this long
-- Length in seconds of each effect (the shipped Media/Sounds/<event>.ogg; kits are similar).
S.LENGTH = {
  click = 0.35, open = 0.37, close = 0.12, correct = 0.68, wrong = 0.19, combo = 0.68, overcharge = 1.19,
  forge = 0.62, scroll = 0.65, reward = 1.21, rankup = 2.05, exampass = 1.9, chirp = 0.48, hint = 0.46,
  cameo = 1.06, splash = 0.51, cannon = 0.79, gurgle = 0.6, flight = 0.74, page = 0.56, specimen = 0.89,
  countdown = 0.66, duelwin = 1.58, gears = 0.94, stamp = 0.67, drill = 0.8,
}
-- UI ticks that are simply skipped while someone is speaking (they would only cover a word).
S.MINOR = { click = true, open = true, close = true, scroll = true, page = true, chirp = true }
-- Answer feedback and game hits: they belong to the click that caused them, so they wait only
-- for speech that is about to end (S.SFX_WAIT_MAX); under a long line they are skipped (the
-- card still flashes green / amber), never played over a word.
S.FEEDBACK = { correct = true, wrong = true, combo = true, overcharge = true, countdown = true,
  splash = true, cannon = true, gurgle = true }
S.SFX_WAIT_LONG = 6      -- other stingers (cameo, reward, flight chime ...) wait up to this long, else skipped

-- What to do with effect `event` when speech has `speechLeft` seconds to go (0 = silent):
-- "play" now, "drop" it, or "wait" (second value = seconds to wait).
function S.Duck(event, speechLeft)
  if not speechLeft or speechLeft <= 0 then return "play", 0 end
  if S.MINOR[event] then return "drop", 0 end
  if S.FEEDBACK[event] then
    if speechLeft <= S.SFX_WAIT_MAX then return "wait", speechLeft end
    return "drop", 0 -- feedback must not lag far behind the action or mask a word
  end
  if speechLeft <= S.SFX_WAIT_LONG then return "wait", speechLeft end
  return "drop", 0
end

-- Seconds to wait before a speech clip starts: the press delay, or until a stinger has rung out.
function S.SpeechStart(delay, sfxLeft)
  delay = delay or S.SPEECH_DELAY
  local wait = math.min(math.max(sfxLeft or 0, 0), S.SPEECH_WAIT_MAX)
  return math.max(delay, wait)
end

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

-- Fizzwick's recorded voice (v0.8). Pure Lua: WHICH line may speak and WHEN.
-- UI/Guide.lua asks V.Decide() whenever Fizzwick shows a text line, and plays the file.
--
-- Rules:
--   * A recording only plays with its exact text line (FZ_<EVENT>_<n> key), so what kids
--     hear always matches the bubble. Event-wide clips (V.EVENT_CLIPS) are short tags
--     like Sprocket's "Squawk! Hint, hint!" that fit every line of that event.
--   * Voiced lines are preferred the first time an event happens in a session
--     (V.PreferKey, once the clip has actually played), so a kid actually hears Fizzwick early; after that the normal
--     shuffle bag decides and the recording plays whenever its line comes up.
--   * One clip at a time: nothing starts while a clip is still playing, except a
--     "big" moment (rank up / mastery) which may cut in.
--   * Throttled: at least V.GAP seconds between clips and V.REPEAT_GAP before the same
--     clip again, so a run of right answers doesn't turn into a chatterbox.
local _, ns = ...

local V = {}
ns.Voice = V

V.DIR = "Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\VO\\"
V.VOICE_ID = "6cM4EfZ7l0vIR7bts4fm" -- ElevenLabs voice library: "Professor Fizzwick Coppercoil" (original, designed from text)
V.GAP = 6          -- seconds between any two clips
V.REPEAT_GAP = 45  -- seconds before the same clip may play again

-- key -> { file (without .ogg), dur (seconds, measured from the shipped file), big = may interrupt }
V.LINES = {
  FZ_GREET_1 = { file = "greet", dur = 5.2 },
  FZ_ROUNDSTART_2 = { file = "roundstart", dur = 2.2 },
  FZ_CORRECT_1 = { file = "correct", dur = 2.5 },
  FZ_WRONG_1 = { file = "wrong", dur = 4.1 },
  FZ_COMBO_1 = { file = "combo", dur = 3.1 },
  FZ_RANKUP_1 = { file = "rankup", dur = 4.0, big = true },
  FZ_MASTERED_1 = { file = "mastered", dur = 3.0, big = true },
  FZ_FLIGHTSTART_4 = { file = "flight", dur = 4.0 },
  FZ_FLIGHTLAND_1 = { file = "landing", dur = 3.5 },
  FZ_BOARDSTART_1 = { file = "murloc", dur = 4.4 },
  FZ_BYE_1 = { file = "bye", dur = 3.5 },
  -- v0.9 Azeroth Naturalist
  FZ_NATSTART_1 = { file = "nat_start", dur = 3.1 },
  FZ_NATCORRECT_1 = { file = "nat_correct", dur = 3.0 },
  FZ_NATSPECIMEN_1 = { file = "nat_specimen", dur = 4.3, big = true },
  FZ_NATJOURNAL_1 = { file = "nat_journal", dur = 3.8 },
  FZ_NATFLIGHT_1 = { file = "nat_flight", dur = 4.3 },
  -- v0.10 Duel of Wits
  FZ_DUELINVITE_1 = { file = "duel_invite", dur = 3.7 },
  FZ_DUELSTART_1 = { file = "duel_start", dur = 4.0 },
  FZ_DUELWIN_1 = { file = "duel_win", dur = 4.2, big = true },
  FZ_DUELDONE_1 = { file = "duel_done", dur = 3.9 },
  -- v0.11 Gnomish Engineering
  FZ_GESTART_1 = { file = "ge_start", dur = 4.4 },
  FZ_GEBLUEPRINT_1 = { file = "ge_blueprint", dur = 3.3, big = true },
}
-- event -> clip that fits every line of the event
V.EVENT_CLIPS = {
  HINT = { file = "hint", dur = 2.0 },
}

-- Settings: account.settings.voice = { enabled = true }. Volume and mute follow the sound settings.
function V.Enabled(settings)
  if type(settings) ~= "table" then return true end
  if type(settings.sound) == "table" and settings.sound.enabled == false then return false end
  local v = settings.voice
  return not (type(v) == "table" and v.enabled == false)
end

function V.Path(clip) return V.DIR .. clip.file .. ".ogg" end

-- The recorded key for an event (first one found, in a stable order), or nil.
function V.KeyFor(event)
  local prefix, best = "FZ_" .. tostring(event) .. "_", nil
  for key in pairs(V.LINES) do
    if key:sub(1, #prefix) == prefix and key:sub(#prefix + 1):match("^%d+$") and (not best or key < best) then best = key end
  end
  return best
end

function V.NewState() return { busyUntil = 0, lastAt = -1e9, lastByFile = {}, heard = {}, missing = {} } end

-- Which voiced line to force for this event, or nil. Only while that event hasn't been
-- heard yet this session AND the clip could actually play right now (so a forced line
-- never ends up silent because another clip was still talking).
function V.PreferKey(state, event, settings, now)
  if state.heard[event] then return nil end
  local key = V.KeyFor(event)
  if not key or not V.Decide(state, event, key, now, settings) then return nil end
  return key
end

-- Should the clip for (event, key) play now? Returns clip or nil, reason.
function V.Decide(state, event, key, now, settings)
  if not V.Enabled(settings) then return nil, "off" end
  local clip = (key and V.LINES[key]) or V.EVENT_CLIPS[event or ""]
  if not clip then return nil, "none" end
  if state.missing[clip.file] then return nil, "missing" end
  now = now or 0
  if now < state.busyUntil and not clip.big then return nil, "busy" end
  if now - state.lastAt < V.GAP and not clip.big then return nil, "gap" end
  local last = state.lastByFile[clip.file]
  if last and now - last < V.REPEAT_GAP then return nil, "repeat" end
  return clip
end

-- Record that a clip started (willPlay from PlaySoundFile).
function V.Started(state, event, clip, now)
  now = now or 0
  state.busyUntil = now + (clip.dur or 3) + 0.25
  state.lastAt = now
  state.lastByFile[clip.file] = now
  if event then state.heard[event] = true end
end

-- World Tongues audio (v1.2). Pure Lua: WHICH clip goes with an entry and WHETHER it may play.
-- The clips (Media\Sounds\Tongues\*.ogg) were generated with ElevenLabs from the kana /
-- Japanese script or the Spanish spelling, with two original designed voices (no cloning),
-- checked with speech-to-text and mastered like Fizzwick's lines (mono 44.1 kHz Ogg Vorbis).
-- Playing is the adapter's job (ns.Compat.PlayTongue); this file only decides.
--
-- Rules:
--   * Everything works without audio. No clip, sound switched off (Settings: sound off), or a
--     file the client will not play -> no Listen questions and no play buttons; nothing errors.
--   * A clip that fails to play is remembered as missing for the session. If the first
--     TA.MAX_FAILS tries all fail (nothing has played yet), audio is treated as unavailable
--     for the rest of the session (the files are probably not installed).
--   * Katakana use the hiragana clip of the same sound (ア = あ, ヂ = ぢ = じ): same sound,
--     no extra files. Homophones share a clip (じ/ぢ, ず/づ), and を is said like お,
--     so Listen questions never offer two buttons that sound the same (TA.SoundKey).
local _, ns = ...
local D = ns.TonguesData

local TA = {}
ns.TonguesAudio = TA

TA.DIR = "Interface\\AddOns\\AzerothAcademy\\Media\\Sounds\\Tongues\\"
TA.VOICES = { -- ElevenLabs voice library ids (original voices designed from a text description)
  ja = { id = "YoehWfvcIKadBIOJc73w", name = "AzAcad Tongues - Japanese Teacher" },
  es = { id = "xSdwcYyEmcoPXQWVelvl", name = "AzAcad Tongues - Spanish Teacher" },
}
TA.MAX_FAILS = 3
TA.ALIKE = { ja_k_wo = "ja_k_o" } -- を is said like お (ぢ/づ already share the じ/ず clip)

-- course -> native -> { file =, dur = }
TA.clips = { ja = {}, es = {} }
local data = ns.TonguesClipData or {}
for course, list in pairs(data) do
  TA.clips[course] = TA.clips[course] or {}
  for native, c in pairs(list) do TA.clips[course][native] = { file = c[1], dur = c[2] } end
end
do -- homophones and katakana share clips with the hiragana that sounds the same
  local ja = TA.clips.ja
  ja["ぢ"] = ja["ぢ"] or ja["じ"]
  ja["づ"] = ja["づ"] or ja["ず"]
  local function alias(kana, hira)
    for i, e in ipairs(kana or {}) do
      local h = hira[i]
      if h and h[2] == e[2] and ja[h[1]] and not ja[e[1]] then ja[e[1]] = ja[h[1]] end
    end
  end
  if D then alias(D.katakana, D.hiragana); alias(D.katakanaVoiced, D.hiraganaVoiced) end
end

function TA.NewState() return { missing = {}, fails = 0, broken = false, plays = 0 } end
TA.state = TA.NewState()

local function accountSettings()
  local P = ns.Progress
  local a = P and P.account
  return a and a.settings or nil
end

-- Sound on? (Settings: sound off silences World Tongues too; volume follows the sound channel.)
function TA.Enabled(settings)
  if settings == nil then settings = accountSettings() end
  if type(settings) ~= "table" then return true end
  if type(settings.sound) == "table" and settings.sound.enabled == false then return false end
  return true
end

-- May any clip play right now?
function TA.Available(settings, state)
  state = state or TA.state
  return TA.Enabled(settings) and not state.broken
end

-- The clip for a course entry (native text), or nil when there is none / it is missing.
function TA.Clip(course, native, state)
  state = state or TA.state
  local c = TA.clips[course or ""] and TA.clips[course][native or ""]
  if not c or state.missing[c.file] then return nil end
  return c
end

-- A clip to use for a question: only when audio is available at all.
function TA.ClipIfAvailable(course, native, settings, state)
  if not TA.Available(settings, state) then return nil end
  return TA.Clip(course, native, state)
end

function TA.Path(clip) return TA.DIR .. clip.file .. ".ogg" end

-- The clip behind a problem's `audioFile` (problems keep only the file name).
function TA.ByFile(file, state)
  state = state or TA.state
  if not file or state.missing[file] then return nil end
  for _, list in pairs(TA.clips) do
    for _, c in pairs(list) do if c.file == file then return c end end
  end
  return nil
end

-- Two entries that sound the same share a sound key (so they are never both offered).
function TA.SoundKey(course, native)
  local c = TA.clips[course or ""] and TA.clips[course][native or ""]
  if not c then return nil end
  return TA.ALIKE[c.file] or c.file
end

-- Count clips that exist per course (for the README / tests).
function TA.Count(course)
  local seen, n = {}, 0
  for _, c in pairs(TA.clips[course] or {}) do if not seen[c.file] then seen[c.file] = true; n = n + 1 end end
  return n
end

-- After the adapter tried to play `clip`: ok = PlaySoundFile said it will play.
function TA.Result(clip, ok, state)
  state = state or TA.state
  if not clip then return end
  if ok then
    state.fails, state.plays = 0, state.plays + 1
  else
    state.missing[clip.file] = true
    state.fails = state.fails + 1
    if state.plays == 0 and state.fails >= TA.MAX_FAILS then state.broken = true end
  end
end

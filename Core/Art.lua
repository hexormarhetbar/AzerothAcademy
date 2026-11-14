-- Fizzwick + Sprocket portraits (v0.5.1: posed art). Pure logic: which texture to show.
-- Hex's approved posed renders ship in Media/Art as 512x512 TGAs (full figure), plus
-- 256x256 head-and-chest crops (<name>_head) for small slots such as the guide strip:
--   fizzwick_<pose>  for the poses in A.POSES
--   sprocket_squawk (delivering a hint), sprocket_curious (a hint is available)
--   fizzwick_strip   optional talk animation (2/4/8 frames of 256x256), not shipped
-- Media/Art/Manifest.lua lists the files that exist (addons can't check the disk).
-- Fallback order: pose -> greet (the neutral-ish pose) -> in-game model -> icon.
local _, ns = ...

local A = {}
ns.Art = A

A.DIR = "Interface\\AddOns\\AzerothAcademy\\Media\\Art\\"
A.POSES = { "greet", "talking", "thinking", "researching", "teaching", "excited",
  "celebrating", "proud", "encouraging", "tinkering", "surprised" }
A.SPROCKET = { "squawk", "curious" }
A.DEFAULT_POSE = "greet"
A.SIZE, A.HEAD_SIZE, A.FRAME = 512, 256, 256
A.STRIP_FRAMES = { [2] = true, [4] = true, [8] = true }

-- Guide events -> pose. Subject context (idle) is A.IdlePose(moduleId).
A.EVENT_POSE = {
  GREET = "greet",
  ROUNDSTART = "talking", EXAMSTART = "talking", TRIALSTART = "talking", REVIEW = "talking",
  TRIALDONE = "talking", CORRECT = "talking",
  IDLE = "thinking",
  HINT = "teaching", EXPLAIN = "teaching",
  COMBO = "excited", OVERCHARGE = "excited",
  RANKUP = "celebrating", EXAMPASS = "celebrating",
  MASTERED = "proud",
  WRONG = "encouraging", EXAMTRY = "encouraging", FADING = "encouraging",
  BEST = "surprised",
  -- v0.6 Murloc Boarding Party
  BOARDSTART = "talking", BOARDWAVE = "talking", BOARDBOSS = "surprised", BOARDSPLASH = "excited",
  BOARDBROADSIDE = "excited", BOARDWHEEL = "encouraging", BOARDWIN = "celebrating", BOARDLOSE = "encouraging",
  -- v0.7 In-Flight Lessons
  FLIGHTSTART = "excited", FLIGHTDONE = "proud", FLIGHTLAND = "talking",
  -- v0.9 Azeroth Naturalist
  NATSTART = "talking", NATCORRECT = "talking", NATWRONG = "encouraging", NATSPECIMEN = "excited",
  NATJOURNAL = "researching", NATFLIGHT = "excited",
  -- v0.10 Duel of Wits
  DUELINVITE = "surprised", DUELSTART = "excited", DUELWIN = "celebrating", DUELDONE = "encouraging",
  DUELWAIT = "thinking",
  -- v0.11 Gnomish Engineering
  GESTART = "tinkering", GECORRECT = "excited", GEWRONG = "encouraging", GEBLUEPRINT = "excited", GEBINDER = "proud",
}

-- While a problem waits for an answer, Fizzwick works on something that fits the subject.
A.SUBJECT_POSE = {
  lore = "researching", lorequiz = "researching", librarian = "researching",
  runeforger = "tinkering", gnomish = "tinkering",
  boarding = "talking", -- at the ship's wheel
  naturalist = "researching",
}

local function has(manifest, name, missing)
  return type(manifest) == "table" and manifest[name] and not (missing and missing[name]) and true or false
end

function A.PoseFor(event) return A.EVENT_POSE[event or ""] or A.DEFAULT_POSE end
function A.IdlePose(moduleId) return A.SUBJECT_POSE[moduleId or ""] or A.EVENT_POSE.IDLE end

-- Candidate file names for a pose, best first. small = prefer the 256 head crop.
function A.Candidates(pose, small)
  local out, seen = {}, {}
  local function add(n) if not seen[n] then seen[n] = true; out[#out + 1] = n end end
  for _, p in ipairs({ pose, A.DEFAULT_POSE }) do
    local base = "fizzwick_" .. p
    if small then add(base .. "_head") end
    add(base)
  end
  return out
end

-- path, name, pose (the pose actually used) or nil -> use the model.
function A.Fizzwick(pose, manifest, missing, small)
  for _, name in ipairs(A.Candidates(pose or A.DEFAULT_POSE, small)) do
    if has(manifest, name, missing) then
      return A.DIR .. name, name, (name:match("^fizzwick_(%a+)"))
    end
  end
  return nil
end

function A.FizzwickFor(event, manifest, missing, small)
  return A.Fizzwick(A.PoseFor(event), manifest, missing, small)
end

-- Sprocket: wanted state first, then the other state; head crop first when small.
function A.Sprocket(state, manifest, missing, small)
  local order = { state or "curious" }
  for _, s in ipairs(A.SPROCKET) do if s ~= order[1] then order[#order + 1] = s end end
  for _, s in ipairs(order) do
    local base = "sprocket_" .. s
    if small and has(manifest, base .. "_head", missing) then return A.DIR .. base .. "_head", base .. "_head", s end
    if has(manifest, base, missing) then return A.DIR .. base, base, s end
  end
  return nil
end

-- Talk strip: { path, frames, coords } or nil.
function A.Strip(manifest, missing)
  local e = type(manifest) == "table" and manifest.fizzwick_strip
  if not e or (missing and missing.fizzwick_strip) then return nil end
  local frames = type(e) == "table" and tonumber(e.frames) or nil
  if not frames or not A.STRIP_FRAMES[frames] then return nil end
  local coords = {}
  for i = 1, frames do coords[i] = { (i - 1) / frames, i / frames, 0, 1 } end
  return { path = A.DIR .. "fizzwick_strip", name = "fizzwick_strip", frames = frames, coords = coords }
end

-- Every file the art set can contain (for tests, the script and the README).
function A.AllNames()
  local out = {}
  for _, p in ipairs(A.POSES) do out[#out + 1] = "fizzwick_" .. p; out[#out + 1] = "fizzwick_" .. p .. "_head" end
  for _, s in ipairs(A.SPROCKET) do out[#out + 1] = "sprocket_" .. s; out[#out + 1] = "sprocket_" .. s .. "_head" end
  return out
end

-- Number of art files listed in the manifest.
function A.Count(manifest)
  if type(manifest) ~= "table" then return 0 end
  local n = 0
  for _, name in ipairs(A.AllNames()) do if manifest[name] then n = n + 1 end end
  if manifest.fizzwick_strip then n = n + 1 end
  return n
end

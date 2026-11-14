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
  -- v0.12 Librarian Quests
  LIBSTART = "researching", LIBCORRECT = "excited", LIBWRONG = "encouraging", LIBSTAMP = "celebrating",
  LIBPASSPORT = "proud",
  -- v0.13 Mechanics Academy
  LORECAMEO = "researching", -- v0.14
  MECHSTART = "excited", MECHCORRECT = "excited", MECHWRONG = "encouraging", MECHCARD = "celebrating", MECHDECK = "proud",
}

-- While a problem waits for an answer, Fizzwick works on something that fits the subject.
A.SUBJECT_POSE = {
  lore = "researching", lorequiz = "researching", librarian = "researching",
  runeforger = "tinkering", gnomish = "tinkering",
  boarding = "talking", -- at the ship's wheel
  naturalist = "researching",
  mechanics = "teaching", -- drawing tactics on the Training Ring chalkboard
}

-- Host portraits (slots v0.15, Hex's approved art since v1.0.0-rc): Chronicler Zixi (Lore
-- Chronicles, Lore Quiz) and Archivist Quill (Scribe's Scrolls). Same two sizes as Fizzwick:
--   <id>_<pose>.tga (512x512 full figure) and <id>_<pose>_head.tga (256x256 head crop).
-- Each host has five shared poses plus a signature one (Zixi storytelling, Quill writing).
-- Missing files fall back pose -> greet -> a placeholder from the game (the subject icon).
-- The Murloc Tidehunter has no art slot by Hex's decision: it always uses the in-game
-- murloc model (UI/Boarding.lua).
A.HOST_ORDER = { "zixi", "quill" }
A.HOST_POSES = { "greet", "talking", "thinking", "encouraging", "proud" }
A.HOSTS = {
  zixi = { nameKey = "HOST_ZIXI", modules = { lore = true, lorequiz = true }, signature = "storytelling",
    cast = { nameKey = "HOST_ZIXI", icon = "Interface\\Icons\\INV_Misc_Book_09" } },
  quill = { nameKey = "HOST_QUILL", modules = { scribe = true }, signature = "writing",
    cast = { nameKey = "HOST_QUILL", icon = "Interface\\Icons\\INV_Scroll_03" } },
}
-- Moments where a host appears -> pose ("signature" = the host's own pose).
A.HOST_MOMENT = {
  skilllist = "signature",   -- the small slot on the skill list: at work in the Story Vault / Archive
  placement = "greet",       -- placement trial intro: meeting the host
  exam = "talking",          -- Mastery Exam intro: explaining the exam
  placed = "proud",          -- placement trial finished: the right shelf is found
  passed = "proud",          -- Mastery Exam passed
  tryagain = "encouraging",  -- Mastery Exam not passed yet
  unfinished = "thinking",   -- a trial left before the end
}
function A.HostPoses(id)
  local h = A.HOSTS[id or ""]
  if not h then return {} end
  local out = {}
  for _, p in ipairs(A.HOST_POSES) do out[#out + 1] = p end
  out[#out + 1] = h.signature
  return out
end
function A.HostPose(id, moment)
  local h = A.HOSTS[id or ""]
  local p = A.HOST_MOMENT[moment or ""] or moment or "greet"
  if p == "signature" then p = h and h.signature or "greet" end
  return p
end

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

-- Host whose portrait belongs on a module's skill list (or nil).
function A.HostFor(moduleId)
  for _, id in ipairs(A.HOST_ORDER) do
    if A.HOSTS[id].modules[moduleId or ""] then return id end
  end
  return nil
end

-- Host portrait for a moment or pose: path, name, pose or nil (= the placeholder cast).
-- Order: pose (head crop first when small) -> greet -> the other size.
function A.Host(id, moment, manifest, missing, small)
  if not A.HOSTS[id or ""] then return nil end
  local pose = A.HostPose(id, moment)
  local tries = {}
  for _, p in ipairs({ pose, "greet" }) do
    local base = id .. "_" .. p
    if small then tries[#tries + 1] = { base .. "_head", p } end
    tries[#tries + 1] = { base, p }
    if not small then tries[#tries + 1] = { base .. "_head", p } end
  end
  for _, t in ipairs(tries) do
    if has(manifest, t[1], missing) then return A.DIR .. t[1], t[1], t[2] end
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
  for _, h in ipairs(A.HOST_ORDER) do
    for _, p in ipairs(A.HostPoses(h)) do out[#out + 1] = h .. "_" .. p; out[#out + 1] = h .. "_" .. p .. "_head" end
  end
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

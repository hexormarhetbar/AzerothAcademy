-- In-Flight Lessons (v0.7): decides WHEN Fizzwick offers a quick round on a flight path.
-- Pure Lua: the caller feeds it "am I on a taxi?" plus a clock value and a context
-- table, so every rule here is tested headlessly. Main.lua does the polling/events,
-- UI/Flight.lua shows the toast or opens the round.
--
--   tracker = F.NewTracker()
--   F.Update(tracker, onTaxi, now)      -> "takeoff" | "landed" | nil
--   F.Decide(tracker, now, ctx)         -> "toast" | "auto" | "wait" | "skip", reason
--   F.MarkOffered(tracker)              (at most one offer per flight)
local _, ns = ...

local F = {}
ns.Flight = F

F.MODES = { "off", "toast", "auto" }
F.DEFAULT_MODE = "toast"
F.TAKEOFF_DELAY = 2.5   -- seconds after takeoff before Fizzwick speaks up
F.ROUND_SIZE = 5        -- flights vary a lot, so rounds are short; "another round" while still flying
F.TOAST_SECONDS = 25    -- an ignored toast just fades away

local VALID = { off = true, toast = true, auto = true }

function F.ValidMode(mode) return VALID[mode] == true end

-- Mode from the account settings (anything odd counts as the default).
function F.Mode(settings)
  local fl = type(settings) == "table" and settings.flight
  local m = type(fl) == "table" and fl.mode
  if VALID[m] then return m end
  return F.DEFAULT_MODE
end

-- Daily cap reached? A cap of 0 means "no bonus minutes", not "no learning", so it never blocks.
function F.CapReached(earned, cap)
  earned, cap = tonumber(earned) or 0, tonumber(cap) or 0
  return cap > 0 and earned >= cap
end

function F.NewTracker()
  return { onTaxi = false, flight = 0, offered = false, takeoffAt = nil, muted = false, landedAt = nil }
end

-- Feed the latest taxi state. Edges only: polling and events can both call this freely.
function F.Update(tr, onTaxi, now)
  onTaxi = onTaxi and true or false
  if onTaxi == tr.onTaxi then return nil end
  tr.onTaxi = onTaxi
  if onTaxi then
    tr.flight = tr.flight + 1
    tr.takeoffAt = now or 0
    tr.offered = false
    tr.landedAt = nil
    return "takeoff"
  end
  tr.landedAt = now or 0
  return "landed"
end

-- ctx = { mode, inCombat, inInstance, academyOpen, hasBand, capReached, test }
-- "wait" = try again on the next check this flight (combat, too early);
-- "skip" = nothing this flight (and the caller marks it offered so we stay quiet).
function F.Decide(tr, now, ctx)
  ctx = ctx or {}
  if not tr.onTaxi then return "skip", "grounded" end
  if tr.offered then return "skip", "already" end
  local mode = VALID[ctx.mode] and ctx.mode or F.DEFAULT_MODE
  if mode == "off" then return "skip", "off" end
  if tr.muted and not ctx.test then return "skip", "muted" end
  if ctx.inInstance then return "skip", "instance" end
  if ctx.academyOpen then return "skip", "open" end
  if not ctx.hasBand then return "skip", "noband" end
  if ctx.capReached then return "skip", "cap" end
  if ctx.inCombat then return "wait", "combat" end
  if (now or 0) - (tr.takeoffAt or 0) < F.TAKEOFF_DELAY then return "wait", "early" end
  return mode, nil
end

function F.MarkOffered(tr) tr.offered = true end

-- "Don't ask again this session" (cleared by /reload or logout, or by /aa flight test).
function F.Mute(tr) tr.muted = true end

-- Offer "another round" after a flight round only while still in the air.
function F.CanOfferAnother(tr) return tr.onTaxi and true or false end

-- Parse "/aa flight ..." arguments: returns action, value.
function F.ParseCommand(arg)
  arg = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if arg == "" then return "status" end
  if VALID[arg] then return "set", arg end
  if arg == "on" then return "set", F.DEFAULT_MODE end
  if arg == "test" or arg == "sim" or arg == "simulate" then return "test" end
  if arg == "land" then return "land" end
  return "help"
end

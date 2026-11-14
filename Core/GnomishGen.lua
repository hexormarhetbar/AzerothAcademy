-- Gnomish Engineering (module #5, programming, v0.11), hosted by Tinker Nixa Sprocketwhirl
-- in the Knowledge Exchange's workshop in Gadgetzan. Kids program Boltby, a clockwork
-- critter, on a command grid. Generators + registry + the Blueprint Binder book.
-- Pure Lua (no WoW API).
--
-- Grid puzzles carry p.grid = { w, h, bot = {x, y, dir}, goal = {x, y}, walls, marks }
-- (y = 1 is the top row); UI/Widgets.lua W.Grid draws it with in-game icons. Every grid
-- answer is computed by GE.Run, so the harness can replay each puzzle.
local _, ns = ...
local Util = ns.Util
local D = ns.GnomishData
local NA = ns.Naturalist
local random, abs, floor = Util.Random, math.abs, math.floor

local GE = {}
ns.Gnomish = GE

GE.MODULE_ID = "gnomish"
GE.MAX_TEXT = 480
GE.MAX_CHOICE = 80

local function L() return ns.L end
local function fmt(key, ...) return string.format(ns.L[key], ...) end
local function pick(t) return t[random(1, #t)] end
local function choices(answer, distractors, n) return ns.Modules.TextChoices(answer, distractors, n) end
local LevelFor = NA.LevelFor

------------------------------------------------------------------------
-- Grid engine (pure, unit-tested)
------------------------------------------------------------------------
GE.DIRS = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }
GE.ABS = { U = "N", D = "S", L = "W", R = "E" }        -- absolute moves (Initiate)
GE.LEFT_OF = { N = "W", W = "S", S = "E", E = "N" }
GE.RIGHT_OF = { N = "E", E = "S", S = "W", W = "N" }
GE.OPPOSITE = { U = "D", D = "U", L = "R", R = "L" }
GE.MOVES = { "U", "D", "L", "R" }
GE.DIR_ORDER = { "N", "E", "S", "W" }

local function wallSet(grid)
  local s = {}
  for _, c in ipairs(grid.walls or {}) do s[c[2] * 100 + c[1]] = true end
  return s
end

function GE.Free(grid, x, y, walls)
  if x < 1 or y < 1 or x > grid.w or y > grid.h then return false end
  return not (walls or wallSet(grid))[y * 100 + x]
end

-- one command: U/D/L/R (move that way), F (forward), TL/TR (turn). Blocked moves stay put.
function GE.Step(grid, x, y, dir, cmd, walls)
  local move
  if GE.ABS[cmd] then move = GE.ABS[cmd]
  elseif cmd == "F" then move = dir
  elseif cmd == "TL" then return x, y, GE.LEFT_OF[dir], false
  elseif cmd == "TR" then return x, y, GE.RIGHT_OF[dir], false
  else return x, y, dir, true end
  local d = GE.DIRS[move]
  local nx, ny = x + d[1], y + d[2]
  if not GE.Free(grid, nx, ny, walls) then return x, y, dir, true end
  return nx, ny, dir, false
end

-- program = list of commands and loops { rep = n, body = {...} }
function GE.Flatten(prog, out)
  out = out or {}
  for _, c in ipairs(prog) do
    if type(c) == "table" then
      for _ = 1, c.rep do GE.Flatten(c.body, out) end
    else
      out[#out + 1] = c
    end
  end
  return out
end

-- -> { x, y, dir, crashed, steps }
function GE.Run(grid, prog)
  local walls = wallSet(grid)
  local x, y, dir = grid.bot[1], grid.bot[2], grid.bot[3] or "E"
  local crashed, steps = false, 0
  for _, c in ipairs(GE.Flatten(prog)) do
    local blocked
    x, y, dir, blocked = GE.Step(grid, x, y, dir, c, walls)
    if blocked then crashed = true end
    steps = steps + 1
  end
  return { x = x, y = y, dir = dir, crashed = crashed, steps = steps }
end

function GE.Reaches(grid, prog, cx, cy)
  local r = GE.Run(grid, prog)
  return not r.crashed and r.x == cx and r.y == cy
end

-- shortest absolute path (BFS) from the bot to (tx, ty), or nil
function GE.Shortest(grid, tx, ty)
  local walls = wallSet(grid)
  local sx, sy = grid.bot[1], grid.bot[2]
  local prev, queue, head = { [sy * 100 + sx] = false }, { { sx, sy } }, 1
  while queue[head] do
    local cx, cy = queue[head][1], queue[head][2]
    head = head + 1
    if cx == tx and cy == ty then
      local path, k = {}, cy * 100 + cx
      while prev[k] do
        table.insert(path, 1, prev[k].cmd)
        k = prev[k].from
      end
      return path
    end
    for _, m in ipairs(Util.Shuffle({ "U", "D", "L", "R" })) do
      local d = GE.DIRS[GE.ABS[m]]
      local nx, ny = cx + d[1], cy + d[2]
      local k = ny * 100 + nx
      if prev[k] == nil and GE.Free(grid, nx, ny, walls) then
        prev[k] = { from = cy * 100 + cx, cmd = m }
        queue[#queue + 1] = { nx, ny }
      end
    end
  end
  return nil
end

function GE.CmdName(c) return L()["GE_CMD_" .. c] end
function GE.DirName(d) return L()["GE_DIR_" .. d] end

function GE.ProgText(prog, sep)
  local out = {}
  for _, c in ipairs(prog) do
    if type(c) == "table" then
      out[#out + 1] = fmt("GE_REPEAT", c.rep, GE.ProgText(c.body))
    else
      out[#out + 1] = GE.CmdName(c)
    end
  end
  return table.concat(out, sep or ", ")
end

-- numbered program lines ("1. Right")
function GE.Numbered(prog)
  local out = {}
  for i, c in ipairs(prog) do out[i] = i .. ". " .. GE.CmdName(c) end
  return table.concat(out, "   ")
end

local function cellKey(x, y) return y * 100 + x end

-- Letter the answer cell and decoys (A, B, C...) in reading order; returns the answer letter.
-- decoys: candidate cells (already checked), padded with free cells near the answer.
function GE.Mark(grid, ax, ay, decoys, n)
  local walls = wallSet(grid)
  local used = { [cellKey(ax, ay)] = true, [cellKey(grid.bot[1], grid.bot[2])] = true }
  if grid.goal then used[cellKey(grid.goal[1], grid.goal[2])] = true end
  local cells = { { ax, ay, ans = true } }
  local function add(x, y)
    if #cells < n and GE.Free(grid, x, y, walls) and not used[cellKey(x, y)] then
      used[cellKey(x, y)] = true
      cells[#cells + 1] = { x, y }
    end
  end
  for _, c in ipairs(decoys or {}) do add(c[1], c[2]) end
  for r = 1, 3 do
    local ring = {}
    for dx = -r, r do
      for dy = -r, r do
        if abs(dx) + abs(dy) == r then ring[#ring + 1] = { ax + dx, ay + dy } end
      end
    end
    for _, c in ipairs(Util.Shuffle(ring)) do add(c[1], c[2]) end
  end
  table.sort(cells, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  local marks, answer, letters = {}, nil, {}
  for i, c in ipairs(cells) do
    local letter = string.char(64 + i)
    marks[i] = { c[1], c[2], letter }
    letters[i] = letter
    if c.ans then answer = letter end
  end
  grid.marks = marks
  return answer, letters
end

local function randomCell(grid)
  return random(1, grid.w), random(1, grid.h)
end

-- a random program of n absolute moves that never steps straight back
local function randomMoves(n)
  local prog, last = {}, nil
  for i = 1, n do
    local m
    repeat m = pick(GE.MOVES) until not last or m ~= GE.OPPOSITE[last]
    prog[i] = m
    last = m
  end
  return prog
end

-- programs one mistake away (for decoy cells and wrong answers)
function GE.Mutations(prog, relative)
  local out = {}
  local alphabet = relative and { "F", "TL", "TR" } or GE.MOVES
  for i = 1, #prog do
    local dropped = {}
    for j, c in ipairs(prog) do if j ~= i then dropped[#dropped + 1] = c end end
    if #dropped > 0 then out[#out + 1] = dropped end
    for _, a in ipairs(alphabet) do
      if a ~= prog[i] then
        local swapped = { unpack(prog) }
        swapped[i] = a
        out[#out + 1] = swapped
      end
    end
  end
  local extra = { unpack(prog) }
  extra[#extra + 1] = prog[#prog]
  out[#out + 1] = extra
  return Util.Shuffle(out)
end

local function newGrid(w, h, dir) return { w = w, h = h, bot = { 1, 1, dir or "E" }, walls = {} } end

local function addWalls(grid, n)
  local taken = { [cellKey(grid.bot[1], grid.bot[2])] = true }
  if grid.goal then taken[cellKey(grid.goal[1], grid.goal[2])] = true end
  local guard = 0
  while #grid.walls < n and guard < 100 do
    guard = guard + 1
    local x, y = randomCell(grid)
    if not taken[cellKey(x, y)] then
      taken[cellKey(x, y)] = true
      grid.walls[#grid.walls + 1] = { x, y }
    end
  end
end

------------------------------------------------------------------------
-- Generators
------------------------------------------------------------------------
local gen = {}

local function curated(bagKey, list, band, hintKey)
  return function(level)
    return NA.FromEntry(NA.Draw("ge_" .. bagKey, list, level), band, hintKey)
  end
end

-- letters as answer buttons (kept in A, B, C order)
local function markProblem(grid, ax, ay, decoys, n, text, hintKey, explain, prog)
  local answer, letters = GE.Mark(grid, ax, ay, decoys, n)
  explain = explain and (explain:gsub("%%s", answer)) or nil
  return { text = text, grid = grid, answer = answer, choices = letters, hint = L()[hintKey], explain = explain,
    target = { ax, ay }, prog = prog }
end

-- INITIATE (ages 5-7): always 3 big buttons --------------------------------
gen.ge_sequence = curated("sequence", D.SEQUENCE, "initiate", "GE_H_SEQUENCE")

-- repeating patterns of parts (and, later, number patterns)
GE.UNITS = {
  { 1, 2 }, { 1, 1, 2 }, { 1, 2, 2 }, { 1, 2, 3 }, { 1, 1, 2, 2 }, { 1, 2, 3, 3 }, { 1, 2, 1, 3 },
}
function GE.PartName(i) return L()["GE_PART_" .. i] end
GE.PARTS = 8
function gen.ge_patterns(level)
  local lv = LevelFor(level)
  if lv == 3 and random() < 0.4 then
    -- counting patterns: +k steps
    local k, a0 = random(2, 5), random(1, 6)
    local len = random(4, 5)
    local seq = {}
    for i = 1, len do seq[i] = a0 + (i - 1) * k end
    local ans = a0 + len * k
    return { text = fmt("GE_Q_NUMPATTERN", table.concat(seq, ", ")), answer = ans,
      choices = Util.MakeChoices(ans, 3, k, 0, { ans + 1, ans - 1, ans + k }),
      hint = L().GE_H_PATTERNS, explain = fmt("GE_E_NUMPATTERN", k, ans) }
  end
  local units = lv == 1 and { GE.UNITS[1], GE.UNITS[2], GE.UNITS[3] }
    or (lv == 2 and { GE.UNITS[2], GE.UNITS[3], GE.UNITS[4], GE.UNITS[5] } or GE.UNITS)
  local unit = pick(units)
  local parts = Util.Shuffle({ 1, 2, 3, 4, 5, 6, 7, 8 })
  local names = {}
  for i, u in ipairs(unit) do names[i] = GE.PartName(parts[u]) end
  local reps = (#unit <= 2) and 3 or 2
  local seq = {}
  for _ = 1, reps do for i = 1, #unit do seq[#seq + 1] = names[i] end end
  local nextName = names[1]
  local missing = lv >= 2 and random() < 0.35
  local ans, shown
  if missing then
    local idx = random(2, #seq - 1)
    ans = seq[idx]
    local copy = { unpack(seq) }
    copy[idx] = "?"
    shown = fmt("GE_Q_PATTERN_GAP", table.concat(copy, ", "))
  else
    ans = nextName
    shown = fmt("GE_Q_PATTERN", table.concat(seq, ", "))
  end
  local ds = {}
  for i = 1, #unit do if names[i] ~= ans then ds[#ds + 1] = names[i] end end
  ds[#ds + 1] = GE.PartName(parts[8])
  ds[#ds + 1] = GE.PartName(parts[7])
  local unitNames = {}
  for i = 1, #unit do unitNames[i] = names[i] end
  return { text = shown, answer = ans, choices = choices(ans, ds, 3), hint = L().GE_H_PATTERNS,
    explain = fmt("GE_E_PATTERN", table.concat(unitNames, ", "), ans) }
end

-- absolute moves on a grid: where does Boltby stop? / which way to the gear?
function gen.ge_directions(level)
  local lv = LevelFor(level)
  local size = lv == 1 and 4 or 5
  if lv == 1 and random() < 0.35 then
    local grid = newGrid(size, size)
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local options = {}
    for _, m in ipairs(GE.MOVES) do
      local d = GE.DIRS[GE.ABS[m]]
      if GE.Free(grid, grid.bot[1] + d[1], grid.bot[2] + d[2]) then options[#options + 1] = m end
    end
    local m = pick(options)
    local d = GE.DIRS[GE.ABS[m]]
    grid.goal = { grid.bot[1] + d[1], grid.bot[2] + d[2] }
    local ds = {}
    for _, o in ipairs(GE.MOVES) do if o ~= m then ds[#ds + 1] = GE.CmdName(o) end end
    local a = GE.CmdName(m)
    return { text = L().GE_Q_WHICHWAY, grid = grid, answer = a, choices = choices(a, ds, 3),
      hint = L().GE_H_DIRECTIONS, explain = fmt("GE_E_WHICHWAY", a) }
  end
  local n = lv + 1
  for _ = 1, 60 do
    local grid = newGrid(size, size)
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local prog = randomMoves(n)
    local r = GE.Run(grid, prog)
    if not r.crashed and not (r.x == grid.bot[1] and r.y == grid.bot[2]) then
      local decoys = {}
      for _, mprog in ipairs(GE.Mutations(prog)) do
        local mr = GE.Run(grid, mprog)
        if not mr.crashed then decoys[#decoys + 1] = { mr.x, mr.y } end
      end
      local text = fmt("GE_Q_STOP", GE.ProgText(prog))
      return markProblem(grid, r.x, r.y, decoys, 3, text, "GE_H_DIRECTIONS",
        fmt("GE_E_STOP", GE.ProgText(prog), "%s"), prog)
    end
  end
  return gen.ge_patterns(level)
end

-- which program reaches the gear?
local function programPuzzle(level, n, bandHint)
  local lv = LevelFor(level)
  local size = lv == 1 and 4 or 5
  for _ = 1, 80 do
    local grid = newGrid(size, size)
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local gx, gy = randomCell(grid)
    local dist = abs(gx - grid.bot[1]) + abs(gy - grid.bot[2])
    if dist >= 2 and dist <= lv + 2 then
      grid.goal = { gx, gy }
      if lv == 3 then addWalls(grid, random(2, 4)) end
      local path = GE.Shortest(grid, gx, gy)
      if path and #path >= 2 and #path <= 6 then
        local a = GE.ProgText(path)
        local wrong, seen, programs = {}, { [a] = true }, { [a] = path }
        for _, m in ipairs(GE.Mutations(path)) do
          local t = GE.ProgText(m)
          if #m > 0 and not seen[t] and not GE.Reaches(grid, m, gx, gy) then
            seen[t] = true
            wrong[#wrong + 1] = t
            programs[t] = m
          end
        end
        if #wrong >= n - 1 then
          return { text = L().GE_Q_PROGRAM, grid = grid, answer = a, choices = choices(a, wrong, n),
            hint = L()[bandHint], explain = fmt("GE_E_PROGRAM", a), programs = programs }
        end
      end
    end
  end
  return nil
end

function gen.ge_program(level)
  return programPuzzle(level, 3, "GE_H_PROGRAM") or gen.ge_patterns(level)
end

-- turning: facing words, then Forward/Turn programs on a grid
function gen.ge_turns(level)
  local lv = LevelFor(level)
  if lv == 1 or random() < 0.4 then
    local start = pick(GE.DIR_ORDER)
    local turns = {}
    for i = 1, (lv == 1 and 1 or (lv == 2 and 2 or 3)) do turns[i] = random() < 0.5 and "TL" or "TR" end
    local d = start
    for _, t in ipairs(turns) do d = (t == "TL") and GE.LEFT_OF[d] or GE.RIGHT_OF[d] end
    local ds = {}
    for _, o in ipairs(GE.DIR_ORDER) do if o ~= d then ds[#ds + 1] = GE.DirName(o) end end
    local a = GE.DirName(d)
    return { text = fmt("GE_Q_FACE", GE.DirName(start), GE.ProgText(turns)), answer = a, choices = choices(a, ds, 3),
      hint = L().GE_H_TURNS, explain = fmt("GE_E_FACE", GE.DirName(start), GE.ProgText(turns), a) }
  end
  for _ = 1, 80 do
    local grid = newGrid(5, 5, pick(GE.DIR_ORDER))
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local prog, nF = {}, 0
    for i = 1, lv + 2 do
      local c = (i == 1 or random() < 0.55) and "F" or (random() < 0.5 and "TL" or "TR")
      if c == "F" then nF = nF + 1 end
      prog[i] = c
    end
    local r = GE.Run(grid, prog)
    if nF >= 2 and not r.crashed and not (r.x == grid.bot[1] and r.y == grid.bot[2]) then
      local decoys = {}
      local swapped = {}
      for i, c in ipairs(prog) do swapped[i] = (c == "TL" and "TR") or (c == "TR" and "TL") or c end
      for _, mprog in ipairs({ swapped, unpack(GE.Mutations(prog, true)) }) do
        local mr = GE.Run(grid, mprog)
        if not mr.crashed then decoys[#decoys + 1] = { mr.x, mr.y } end
      end
      return markProblem(grid, r.x, r.y, decoys, 3,
        fmt("GE_Q_TURNGRID", GE.DirName(grid.bot[3]), GE.ProgText(prog)), "GE_H_TURNS",
        fmt("GE_E_STOP", GE.ProgText(prog), "%s"), prog)
    end
  end
  return gen.ge_directions(level)
end

-- ADEPT (ages 8-10) --------------------------------------------------------
-- loops: count what a loop does, spot the loop that matches, add up in a loop
function gen.ge_loops(level)
  local lv = LevelFor(level)
  local kind = random(1, lv == 1 and 2 or 4)
  if kind == 1 then
    if lv == 3 and random() < 0.5 then
      local a, b, c = random(2, 4), random(2, 3), random(1, 3)
      local ans = a * b * c
      return { text = fmt("GE_Q_NESTED", a, b, c), answer = ans, distractors = { a * b, a + b + c, a * c + b },
        hint = L().GE_H_LOOPS, explain = fmt("GE_E_NESTED", a, b, c, ans), code = true }
    end
    local reps, steps = random(2, lv == 1 and 4 or 6), random(1, lv == 1 and 3 or 5)
    local ans = reps * steps
    return { text = fmt("GE_Q_LOOPSTEPS", reps, steps), answer = ans, distractors = { reps + steps, ans + steps, ans - steps },
      hint = L().GE_H_LOOPS, explain = fmt("GE_E_LOOPSTEPS", reps, steps, ans) }
  elseif kind == 2 then
    local body = randomMoves(random(1, 2))
    if #body == 2 and body[1] == body[2] then body = { body[1] } end
    local reps = random(3, 4)
    local flat = GE.Flatten({ { rep = reps, body = body } })
    local a = GE.ProgText({ { rep = reps, body = body } })
    local wrong = {
      GE.ProgText({ { rep = reps - 1, body = body } }),
      GE.ProgText({ { rep = reps + 1, body = body } }),
    }
    local other = {}
    for i, c in ipairs(body) do other[i] = GE.OPPOSITE[c] end
    wrong[#wrong + 1] = GE.ProgText({ { rep = reps, body = other } })
    return { text = fmt("GE_Q_WHICHLOOP", GE.ProgText(flat)), answer = a, choices = choices(a, wrong, 4),
      hint = L().GE_H_LOOPS, explain = fmt("GE_E_WHICHLOOP", a) }
  elseif kind == 3 then
    local start, reps, add = random(0, 10), random(3, 6), random(2, lv == 3 and 9 or 5)
    local ans = start + reps * add
    return { text = fmt("GE_Q_LOOPADD", start, reps, add), answer = ans, distractors = { start + add, reps * add, ans + add },
      hint = L().GE_H_LOOPS, explain = fmt("GE_E_LOOPADD", start, reps, add, ans), code = true }
  end
  -- a loop that counts down
  local start, step = random(10, 30), random(2, 4)
  local reps = random(2, floor(start / step))
  local ans = start - reps * step
  return { text = fmt("GE_Q_LOOPSUB", start, reps, step), answer = ans, distractors = { start - step, ans - step, ans + step },
    hint = L().GE_H_LOOPS, explain = fmt("GE_E_LOOPSUB", start, reps, step, ans), code = true }
end

-- loops on the grid: where does it stop / which loop reaches the gear?
function gen.ge_loopgrid(level)
  local lv = LevelFor(level)
  for _ = 1, 80 do
    local grid = newGrid(6, 6)
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local body = randomMoves(lv == 1 and 2 or random(2, 3))
    local reps = random(2, 3)
    local prog = { { rep = reps, body = body } }
    if lv == 3 and random() < 0.6 then prog[2] = pick(GE.MOVES) end
    local r = GE.Run(grid, prog)
    if not r.crashed and (abs(r.x - grid.bot[1]) + abs(r.y - grid.bot[2])) >= 2 then
      if random() < 0.5 then
        local decoys = {}
        for _, alt in ipairs({ { { rep = reps - 1, body = body } }, { { rep = reps + 1, body = body } }, { { rep = reps, body = { body[1] } } } }) do
          local mr = GE.Run(grid, alt)
          if not mr.crashed then decoys[#decoys + 1] = { mr.x, mr.y } end
        end
        return markProblem(grid, r.x, r.y, decoys, 4, fmt("GE_Q_STOP", GE.ProgText(prog)), "GE_H_LOOPGRID",
          fmt("GE_E_LOOPSTOP", GE.ProgText(GE.Flatten(prog)), "%s"), prog)
      end
      grid.goal = { r.x, r.y }
      local a = GE.ProgText(prog)
      local wrong, seen, programs = {}, { [a] = true }, { [a] = prog }
      local cands = { { { rep = reps + 1, body = body } }, { { rep = reps - 1, body = body } } }
      local rev = {}
      for i, c in ipairs(body) do rev[i] = GE.OPPOSITE[c] end
      cands[#cands + 1] = { { rep = reps, body = rev } }
      for i = 1, #body do
        local b2 = { unpack(body) }
        b2[i] = pick(GE.MOVES)
        cands[#cands + 1] = { { rep = reps, body = b2 } }
      end
      for _, c in ipairs(cands) do
        if prog[2] then c[2] = prog[2] end
        local t = GE.ProgText(c)
        if c[1].rep >= 1 and not seen[t] and not GE.Reaches(grid, c, r.x, r.y) then
          seen[t] = true
          wrong[#wrong + 1] = t
          programs[t] = c
        end
      end
      if #wrong >= 3 then
        return { text = L().GE_Q_LOOPGOAL, grid = grid, answer = a, choices = choices(a, wrong, 4),
          hint = L().GE_H_LOOPGRID, explain = fmt("GE_E_PROGRAM", a), programs = programs }
      end
    end
  end
  return gen.ge_loops(level)
end

-- IF / ELSE
GE.SAYS = 6 -- GE_SAY_1a/1b ... pairs of outcomes
GE.THINGS = 6 -- GE_THING_1..6 (gears, sparks, ...)
function gen.ge_conditionals(level)
  local lv = LevelFor(level)
  if random() < 0.3 then return NA.FromEntry(NA.Draw("ge_cond", D.COND, level), "adept", "GE_H_CONDITIONALS") end
  local thing = L()["GE_THING_" .. random(1, GE.THINGS)]
  local s = random(1, GE.SAYS)
  local yes, no = L()["GE_SAY_" .. s .. "A"], L()["GE_SAY_" .. s .. "B"]
  local limit = random(3, 12)
  local kind = random(1, lv == 1 and 2 or 3)
  if kind == 3 then
    -- numeric: the branch changes a value
    local v = random(limit - 4, limit + 4)
    local down, up = random(2, 5), random(2, 6)
    local ans = (v > limit) and (v - down) or (v + up)
    return { text = fmt("GE_Q_IFNUM", thing, v, thing, limit, thing, thing, down, thing, thing, up, thing),
      answer = ans, distractors = { v - down, v + up, v }, hint = L().GE_H_CONDITIONALS,
      explain = fmt("GE_E_IFNUM", v, limit, ans), code = true }
  end
  local op = (lv >= 2 and random() < 0.5) and ">=" or (random() < 0.5 and ">" or "<")
  local v
  if lv >= 2 and random() < 0.4 then v = limit else v = random(math.max(0, limit - 5), limit + 5) end
  local test = (op == ">" and v > limit) or (op == "<" and v < limit) or (op == ">=" and v >= limit)
  local a = test and yes or no
  local other = test and no or yes
  return { text = fmt("GE_Q_IF", thing, op, limit, yes, no, thing, v), answer = a,
    choices = choices(a, { other, L().GE_SAY_BOTH, L().GE_SAY_NOTHING }, 4), hint = L().GE_H_CONDITIONALS,
    explain = fmt(test and "GE_E_IF_TRUE" or "GE_E_IF_FALSE", v, op, limit, a), code = true }
end

-- debugging: one step of the program is wrong
function GE.BugPuzzle(lv)
  for _ = 1, 120 do
    local grid = newGrid(5, 5)
    grid.bot[1], grid.bot[2] = randomCell(grid)
    local gx, gy = randomCell(grid)
    local dist = abs(gx - grid.bot[1]) + abs(gy - grid.bot[2])
    if dist >= 3 and dist <= lv + 3 then
      grid.goal = { gx, gy }
      if lv == 3 then addWalls(grid, random(1, 3)) end
      local path = GE.Shortest(grid, gx, gy)
      if path and #path >= 3 and #path <= 6 then
        local bugAt = random(1, #path)
        local buggy = { unpack(path) }
        local alts = {}
        for _, m in ipairs(GE.MOVES) do if m ~= path[bugAt] then alts[#alts + 1] = m end end
        buggy[bugAt] = pick(alts)
        if not GE.Reaches(grid, buggy, gx, gy) then
          -- exactly one step can be fixed by changing it
          local fixable = 0
          for i = 1, #buggy do
            for _, m in ipairs(GE.MOVES) do
              if m ~= buggy[i] then
                local t = { unpack(buggy) }
                t[i] = m
                if GE.Reaches(grid, t, gx, gy) then fixable = fixable + (i == bugAt and 0 or 1) end
              end
            end
          end
          if fixable == 0 then return grid, buggy, bugAt, path end
        end
      end
    end
  end
  return nil
end

function gen.ge_debug(level)
  local lv = LevelFor(level)
  if random() < 0.25 then return NA.FromEntry(NA.Draw("ge_debug", D.DEBUG, level), "adept", "GE_H_DEBUG") end
  local grid, buggy, bugAt, path = GE.BugPuzzle(lv)
  if not grid then return gen.ge_loops(level) end
  if lv >= 2 and random() < 0.4 then
    local a = GE.CmdName(path[bugAt])
    local ds = {}
    for _, m in ipairs(GE.MOVES) do if m ~= path[bugAt] then ds[#ds + 1] = GE.CmdName(m) end end
    return { text = fmt("GE_Q_FIX", GE.Numbered(buggy), bugAt), grid = grid, answer = a, buggy = buggy, bugAt = bugAt,
      distractors = ds, typed = true, alts = { a }, hint = L().GE_H_DEBUG, explain = fmt("GE_E_FIX", bugAt, a) }
  end
  return { text = fmt("GE_Q_BUG", GE.Numbered(buggy)), grid = grid, answer = bugAt, buggy = buggy, bugAt = bugAt, minChoice = 1, maxChoice = #buggy,
    distractors = {}, hint = L().GE_H_DEBUG, explain = fmt("GE_E_BUG", bugAt, GE.CmdName(path[bugAt])) }
end

gen.ge_events = curated("events", D.EVENTS, "adept", "GE_H_EVENTS")

-- MAGISTER (ages 11-13) ----------------------------------------------------
GE.VARS = { "gears", "power", "speed", "sparks", "bolts", "fuel" }
local function twoVars()
  local v = Util.Shuffle({ unpack(GE.VARS) })
  return v[1], v[2]
end

-- trace assignments; returns lines, final values
function GE.Trace(lv)
  local a, b = twoVars()
  local val = {}
  local lines = {}
  local function set(name, expr, value)
    lines[#lines + 1] = name .. " = " .. expr
    val[name] = value
  end
  set(a, tostring(random(2, 9)), nil)
  val[a] = tonumber(lines[1]:match("(%d+)$"))
  if lv == 1 then
    for _ = 1, random(1, 2) do
      local k = random(1, 6)
      if random() < 0.6 or val[a] - k < 0 then set(a, a .. " + " .. k, val[a] + k)
      else set(a, a .. " - " .. k, val[a] - k) end
    end
    return lines, val, a
  end
  local k = random(1, 5)
  set(b, a .. " + " .. k, val[a] + k)
  if lv == 2 then
    local m = random(2, 3)
    set(a, a .. " * " .. m, val[a] * m)
    local ask = random() < 0.5 and a or b
    if ask == b then set(b, b .. " + " .. a, val[b] + val[a]) end
    return lines, val, ask
  end
  -- lv 3: a swap through a temp, or a multiply that uses both
  if random() < 0.5 then
    lines[#lines + 1] = "temp = " .. a
    lines[#lines + 1] = a .. " = " .. b
    lines[#lines + 1] = b .. " = temp"
    val[a], val[b] = val[b], val[a]
    local ask = random() < 0.5 and a or b
    return lines, val, ask
  end
  set(a, a .. " * " .. b, val[a] * val[b])
  set(b, a .. " - " .. b, val[a] - val[b])
  return lines, val, random() < 0.5 and a or b
end

function gen.ge_variables(level)
  local lv = LevelFor(level)
  if random() < 0.2 then return NA.FromEntry(NA.Draw("ge_vars", D.VARS, level), "magister", "GE_H_VARIABLES") end
  local lines, val, ask = GE.Trace(lv)
  local ans = val[ask]
  local ds = {}
  for _, v in pairs(val) do if v ~= ans then ds[#ds + 1] = v end end
  ds[#ds + 1] = ans + 1
  return { text = fmt("GE_Q_VARS", table.concat(lines, "\n"), ask), answer = ans, distractors = ds,
    allowNegative = ans < 0, hint = L().GE_H_VARIABLES, explain = fmt("GE_E_VARS", ask, ans), code = true }
end

GE.FUNCS = { "boost", "spin", "tune", "charge", "grind", "zap" }
function gen.ge_functions(level)
  local lv = LevelFor(level)
  if random() < 0.2 then return NA.FromEntry(NA.Draw("ge_funcs", D.FUNCS, level), "magister", "GE_H_FUNCTIONS") end
  local name = pick(GE.FUNCS)
  local m, k = random(2, 4), random(1, 6)
  local x = random(1, 6)
  local function f(n) return n * m + k end
  if lv == 1 then
    local add = random() < 0.5
    local function g(n) return add and n + k or n * m end
    local body = add and ("n + " .. k) or ("n * " .. m)
    local ans = g(x)
    return { text = fmt("GE_Q_FUNC", name, body, name .. "(" .. x .. ")"), answer = ans,
      distractors = { x, ans + 1, add and x * k or x + m }, hint = L().GE_H_FUNCTIONS,
      explain = fmt("GE_E_FUNC", name .. "(" .. x .. ")", ans), code = true }
  end
  local body = "n * " .. m .. " + " .. k
  if lv == 2 then
    local y = random(1, 6)
    if random() < 0.5 then
      local ans = f(x) + f(y)
      return { text = fmt("GE_Q_FUNC", name, body, name .. "(" .. x .. ") + " .. name .. "(" .. y .. ")"), answer = ans,
        distractors = { f(x + y), f(x) + y, ans + k }, hint = L().GE_H_FUNCTIONS,
        explain = fmt("GE_E_FUNC2", name, x, f(x), name, y, f(y), ans), code = true }
    end
    local ans = f(x)
    return { text = fmt("GE_Q_FUNC", name, body, name .. "(" .. x .. ")"), answer = ans,
      distractors = { x * (m + k), ans + m, ans - k }, hint = L().GE_H_FUNCTIONS,
      explain = fmt("GE_E_FUNC", name .. "(" .. x .. ")", ans), code = true }
  end
  if random() < 0.5 then
    x = random(1, 3)
    local ans = f(f(x))
    return { text = fmt("GE_Q_FUNC", name, body, name .. "(" .. name .. "(" .. x .. "))"), answer = ans,
      distractors = { f(x), f(x) * 2, ans + k }, hint = L().GE_H_FUNCTIONS,
      explain = fmt("GE_E_NESTFUNC", name, x, f(x), name, f(x), ans), code = true }
  end
  -- a function with an IF inside
  local cut = random(4, 8)
  local function h(n) if n > cut then return n - cut else return n * 2 end end
  local y = random(1, 12)
  local ans = h(y)
  return { text = fmt("GE_Q_FUNCIF", name, cut, cut, name, y), answer = ans,
    distractors = { y * 2, y + cut, abs(y - cut) + 1 }, hint = L().GE_H_FUNCTIONS,
    explain = fmt("GE_E_FUNC", name .. "(" .. y .. ")", ans), code = true }
end

-- boolean logic: and / or / not on a robot's sensors
function GE.Bool(lv)
  local hp, mana, hasKey = random(10, 99), random(10, 99), random() < 0.5
  local facts = string.format("hp = %d, mana = %d, hasKey = %s", hp, mana, tostring(hasKey))
  local function cmp(name, value)
    local lim = random(2, 9) * 10
    if random() < 0.5 then return name .. " < " .. lim, value < lim end
    return name .. " > " .. lim, value > lim
  end
  local e1, v1 = cmp("hp", hp)
  local e2, v2 = cmp("mana", mana)
  if lv == 1 then
    local k = random(1, 3)
    if k == 1 then return facts, e1, v1 end
    if k == 2 then return facts, "not hasKey", not hasKey end
    return facts, e2, v2
  end
  if lv == 2 then
    if random() < 0.5 then return facts, e1 .. " and " .. e2, v1 and v2 end
    return facts, e1 .. " or hasKey", v1 or hasKey
  end
  local k = random(1, 3)
  if k == 1 then return facts, "(" .. e1 .. " or " .. e2 .. ") and not hasKey", (v1 or v2) and not hasKey end
  if k == 2 then return facts, "not (" .. e1 .. " and hasKey)", not (v1 and hasKey) end
  return facts, e1 .. " and (" .. e2 .. " or hasKey)", v1 and (v2 or hasKey)
end

function gen.ge_boolean(level)
  local lv = LevelFor(level)
  if random() < 0.2 then return NA.FromEntry(NA.Draw("ge_bool", D.BOOL, level), "magister", "GE_H_BOOLEAN") end
  local facts, expr, v = GE.Bool(lv)
  local a = v and L().GE_TRUE or L().GE_FALSE
  return { text = fmt("GE_Q_BOOL", facts, expr), answer = a, distractors = { v and L().GE_FALSE or L().GE_TRUE },
    typed = true, alts = v and { "true", "t", "yes" } or { "false", "f", "no" }, hint = L().GE_H_BOOLEAN,
    explain = fmt("GE_E_BOOL", expr, a), code = true }
end

-- algorithms: trace sums, counts, a maximum, a search, one bubble-sort pass
function GE.BubblePass(list)
  local t = { unpack(list) }
  for i = 1, #t - 1 do
    if t[i] > t[i + 1] then t[i], t[i + 1] = t[i + 1], t[i] end
  end
  return t
end

local function listText(t) return "[" .. table.concat(t, ", ") .. "]" end

function gen.ge_algorithms(level)
  local lv = LevelFor(level)
  local kind = random(1, lv == 1 and 3 or 6)
  if kind == 6 then return NA.FromEntry(NA.Draw("ge_algo", D.ALGO, level), "magister", "GE_H_ALGORITHMS") end
  local list = {}
  for i = 1, (lv == 1 and 4 or 5) do list[i] = random(1, 20) end
  if kind == 1 then
    local n = random(3, lv == 1 and 5 or 8)
    local ans = n * (n + 1) / 2
    return { text = fmt("GE_Q_SUMLOOP", n), answer = ans, distractors = { ans - n, ans + n + 1, n * n },
      hint = L().GE_H_ALGORITHMS, explain = fmt("GE_E_SUMLOOP", n, ans), code = true }
  elseif kind == 2 then
    local cut = random(6, 14)
    local ans = 0
    for _, v in ipairs(list) do if v > cut then ans = ans + 1 end end
    return { text = fmt("GE_Q_COUNTIF", listText(list), cut), answer = ans, distractors = { #list - ans, ans + 1 },
      minChoice = 0, maxChoice = #list, hint = L().GE_H_ALGORITHMS, explain = fmt("GE_E_COUNTIF", cut, ans), code = true }
  elseif kind == 3 then
    local best = list[1]
    for _, v in ipairs(list) do if v > best then best = v end end
    return { text = fmt("GE_Q_MAX", listText(list)), answer = best, distractors = { list[1], list[#list] },
      hint = L().GE_H_ALGORITHMS, explain = fmt("GE_E_MAX", best), code = true }
  elseif kind == 4 then
    -- linear search: how many checks?
    local uniq, seen = {}, {}
    for _, v in ipairs(Util.Shuffle({ 2, 3, 5, 7, 8, 11, 12, 14, 16, 19 })) do
      if #uniq < 6 and not seen[v] then uniq[#uniq + 1] = v; seen[v] = true end
    end
    local idx = random(2, #uniq)
    return { text = fmt("GE_Q_SEARCH", listText(uniq), uniq[idx]), answer = idx, distractors = { idx - 1, idx + 1, #uniq },
      minChoice = 1, maxChoice = #uniq, hint = L().GE_H_ALGORITHMS, explain = fmt("GE_E_SEARCH", uniq[idx], idx, idx), code = true }
  end
  -- one bubble-sort pass (choice)
  local uniq, seen = {}, {}
  while #uniq < 4 do
    local v = random(1, 9)
    if not seen[v] then uniq[#uniq + 1] = v; seen[v] = true end
  end
  local after = GE.BubblePass(uniq)
  if listText(after) == listText(uniq) then uniq[1], uniq[4] = uniq[4], uniq[1]; after = GE.BubblePass(uniq) end
  local sorted = { unpack(uniq) }
  table.sort(sorted)
  local a = listText(after)
  local rev = { unpack(uniq) }
  for i = 1, #rev do rev[i] = uniq[#uniq - i + 1] end
  local swapFirst = { unpack(uniq) }
  swapFirst[1], swapFirst[2] = swapFirst[2], swapFirst[1]
  return { text = fmt("GE_Q_BUBBLE", listText(uniq)), answer = a,
    choices = choices(a, { listText(sorted), listText(rev), listText(swapFirst), listText(uniq) }, 4),
    hint = L().GE_H_ALGORITHMS, explain = fmt("GE_E_BUBBLE", a), code = true }
end

-- pseudocode reading: while loops, filters, what a program is for
GE.WORDS = { "gear", "spring", "rocket", "lamp", "cog", "piston", "wrench", "fuse", "bolt", "sprocket" }
function gen.ge_pseudocode(level)
  local lv = LevelFor(level)
  local kind = random(1, 3)
  if kind == 3 then return NA.FromEntry(NA.Draw("ge_pseudo", D.PSEUDO, level), "magister", "GE_H_PSEUDOCODE") end
  if kind == 1 then
    local double = lv >= 2 and random() < 0.6
    local x, limit = random(1, 3), double and random(20, 90) or random(15, lv == 1 and 25 or 40)
    local step = random(3, 7)
    local v, loops = x, 0
    while v < limit do
      if double then v = v * 2 else v = v + step end
      loops = loops + 1
    end
    local body = double and "x = x * 2" or ("x = x + " .. step)
    if lv == 3 and random() < 0.5 then
      return { text = fmt("GE_Q_WHILECOUNT", x, limit, body), answer = loops, distractors = { loops + 1, loops - 1 },
        minChoice = 0, hint = L().GE_H_PSEUDOCODE, explain = fmt("GE_E_WHILECOUNT", loops, v), code = true }
    end
    return { text = fmt("GE_Q_WHILE", x, limit, body), answer = v, distractors = { limit, double and v / 2 or v - step },
      hint = L().GE_H_PSEUDOCODE, explain = fmt("GE_E_WHILE", limit, v), code = true }
  end
  -- filter: which words get printed?
  local words = {}
  for i, w in ipairs(Util.Shuffle({ unpack(GE.WORDS) })) do if i <= 4 then words[i] = w end end
  local n = random(4, 5)
  local out, rest = {}, {}
  for _, w in ipairs(words) do if #w > n then out[#out + 1] = w else rest[#rest + 1] = w end end
  if #out == 0 or #rest == 0 then return gen.ge_algorithms(level) end
  local a = table.concat(out, ", ")
  local wrong = { table.concat(rest, ", "), table.concat(words, ", ") }
  if #out > 1 then wrong[#wrong + 1] = out[1] end
  if #rest > 0 then wrong[#wrong + 1] = out[1] .. ", " .. rest[1] end
  return { text = fmt("GE_Q_FILTER", listText(words), n), answer = a, choices = choices(a, wrong, 4),
    hint = L().GE_H_PSEUDOCODE, explain = fmt("GE_E_FILTER", n, a), code = true }
end

------------------------------------------------------------------------
-- Answer check: numbers typed or picked, typed words with spellings, buttons
------------------------------------------------------------------------
function GE.Check(p, given)
  if type(p.answer) == "number" then
    if p.mode == "choice" then return tostring(given) == tostring(p.answer) end
    local n = Util.ParseNumber(given)
    return n ~= nil and abs(n - p.answer) < 1e-9
  end
  return NA.Check(p, given)
end

------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------
GE.BANDS = {
  initiate = { id = "initiate", nodes = { "ge_sequence", "ge_patterns", "ge_directions", "ge_program", "ge_turns" } },
  adept    = { id = "adept",    nodes = { "ge_loops", "ge_loopgrid", "ge_conditionals", "ge_debug", "ge_events" } },
  magister = { id = "magister", nodes = { "ge_variables", "ge_functions", "ge_boolean", "ge_algorithms", "ge_pseudocode" } },
}
GE.NODES = {}
for id, fn in pairs(gen) do GE.NODES[id] = { key = "GE_NODE_" .. id:sub(4):upper(), gen = fn } end
GE.GEN = gen
GE.GRID_NODES = { ge_directions = true, ge_program = true, ge_turns = true, ge_loopgrid = true, ge_debug = true }

-- Curated lists per node (for tests and question counts)
GE.LISTS = {
  ge_sequence = { D.SEQUENCE }, ge_conditionals = { D.COND }, ge_debug = { D.DEBUG }, ge_events = { D.EVENTS },
  ge_variables = { D.VARS }, ge_functions = { D.FUNCS }, ge_boolean = { D.BOOL }, ge_algorithms = { D.ALGO },
  ge_pseudocode = { D.PSEUDO },
}

GE.MODULE = ns.Modules.Register({
  id = GE.MODULE_ID,
  nameKey = "MOD_GNOMISH", descKey = "MOD_GNOMISH_DESC",
  icon = "Interface\\Icons\\Trade_Engineering",
  startSound = "gears",
  loreKey = "GE_LORE", titleKey = "GE_TITLE",
  placementKey = "GE_TRIAL", examKey = "GE_EXAM",
  placementLoreKey = "GE_TRIAL_LORE", examLoreKey = "GE_EXAM_LORE",
  placementResultKey = "GE_TRIAL_RESULT", examPassKey = "GE_EXAM_PASS",
  trialRightKey = "GE_TRIAL_RIGHT", trialWrongKey = "GE_TRIAL_WRONG",
  bands = GE.BANDS, nodes = GE.NODES,
  choiceOnlyBands = { initiate = true },
  check = GE.Check,
  textAnswers = true,
  game = { key = "GE_BINDER_LINK", tileKey = "GE_BINDER_TILE", tipKey = "GE_BINDER_TIP", view = "journal" },
  guideEvents = { ROUNDSTART = { "GESTART", every = 1 }, CORRECT = { "GECORRECT", every = 3 }, WRONG = { "GEWRONG", every = 3 } },
})

-- Blueprint Binder: one blueprint page per mastered tier (shared collection system)
ns.Journal.RegisterBook({
  moduleId = GE.MODULE_ID, items = D.BLUEPRINTS, prefix = "BLUEPRINT",
  openEvent = "GEBINDER", newEvent = "GEBLUEPRINT", sound = "gears",
})

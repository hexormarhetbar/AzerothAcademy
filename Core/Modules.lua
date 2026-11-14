-- Module registry + the module-agnostic problem pipeline.
-- A module (subject) registers its skills ("nodes") per age band and a generator per
-- node. The round engine (Session), trials (Trial), reviews (Review) and mastery
-- (Mastery) only ever talk to this registry, never to a specific subject.
--
-- Module definition:
--   id, nameKey, descKey, icon             identity + hub tile
--   loreKey, titleKey                      skill-list screen text (titleKey gets %s = band)
--   placementKey, examKey, reviewKey       names of the trial / exam / review for this subject
--   bands = { [bandId] = { nodes = { nodeId, ... } } }
--   nodes = { [nodeId] = { key, descKey, gen = function(level) -> problem } }
--   choiceOnlyBands = { initiate = true }  bands that only ever get big buttons
--   youngChoices (3), choices (4)          number of buttons
--   inputMode = function(node, tier, purpose) -> "choice", n | "input" | nil (optional override)
--   check = function(problem, given) -> boolean (optional custom answer checker, e.g. spelling)
--   startSound = "forge" | "scroll" ...     sound event played when a round starts (v0.4, optional)
--   unbanded = true                        one "everyone" band shown whatever the kid's path is (v0.5)
--   noTrials = true                        no placement trial / mastery exam (v0.5)
--   hidden = true                          no hub tile (reached through linkModule / slash command)
--   linkModule, linkKey                    a button on the skill list that opens another module
--   area = "lore"                          v1.1 area this module belongs to (default: its own id).
--                                          Settings can hide a whole area (Progress.IsAreaShown).
-- Node ids must be unique across ALL modules (prefix them, e.g. "scribe_spelling").
local _, ns = ...
local Util = ns.Util
local floor, abs, max = math.floor, math.abs, math.max

local Mods = { list = {}, byId = {}, nodeIndex = {} }
ns.Modules = Mods

Mods.BAND_ORDER = { "initiate", "adept", "magister" }
Mods.EVERYONE = { id = "everyone", key = "BAND_EVERYONE", ages = "all ages" }
Mods.UNBANDED_ORDER = { "everyone" }

function Mods.Register(def)
  assert(type(def) == "table" and type(def.id) == "string", "module needs an id")
  assert(type(def.bands) == "table" and type(def.nodes) == "table", "module needs bands and nodes")
  assert(not def.unbanded or type(def.bands.everyone) == "table", "unbanded modules need bands.everyone")
  assert(not Mods.byId[def.id], "duplicate module id: " .. def.id)
  def.icon = def.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  -- validate everything first so a bad definition leaves the registry untouched
  local seen = {}
  for bandId, band in pairs(def.bands) do
    assert(type(band.nodes) == "table" and #band.nodes > 0, "band " .. bandId .. " has no nodes")
    for _, nodeId in ipairs(band.nodes) do
      local node = def.nodes[nodeId]
      assert(type(node) == "table" and type(node.gen) == "function", "node " .. tostring(nodeId) .. " needs gen()")
      assert(not Mods.nodeIndex[nodeId] and not seen[nodeId], "node id must be unique across modules: " .. nodeId)
      seen[nodeId] = true
    end
  end
  for bandId, band in pairs(def.bands) do
    for _, nodeId in ipairs(band.nodes) do
      local node = def.nodes[nodeId]
      node.id, node.band, node.module = nodeId, bandId, def.id
      node.key = node.key or nodeId
      node.descKey = node.descKey or (node.key .. "_DESC")
      node.icon = node.icon or (ns.SkillIcons and ns.SkillIcons[nodeId]) or def.icon -- v0.5.1 per-skill icons
      Mods.nodeIndex[nodeId] = def
    end
  end
  def.area = def.area or def.id
  def.nameKey = def.nameKey or def.id
  def.descKey = def.descKey or (def.nameKey .. "_DESC")
  def.choiceOnlyBands = def.choiceOnlyBands or {}
  def.youngChoices = def.youngChoices or 3
  def.choices = def.choices or 4
  Mods.list[#Mods.list + 1] = def
  Mods.byId[def.id] = def
  return def
end

function Mods.Get(id) return Mods.byId[id] end

function Mods.FindNode(nodeId)
  local m = Mods.nodeIndex[nodeId]
  if not m then return nil, nil end
  return m, m.nodes[nodeId]
end

function Mods.Nodes(moduleId, bandId)
  local m = Mods.byId[moduleId]
  if m and m.unbanded then bandId = "everyone" end
  local band = m and m.bands[bandId]
  return band and band.nodes or {}
end

-- Band ids a module really has, in display order.
function Mods.BandIds(module)
  if module.unbanded then return Mods.UNBANDED_ORDER end
  return Mods.BAND_ORDER
end

-- v1.1: is this module's area switched on in Settings? (always true before Progress is bound)
function Mods.IsShown(module)
  if type(module) == "string" then module = Mods.byId[module] end
  if not module then return false end
  local P = ns.Progress
  if not (P and P.account and P.IsAreaShown) then return true end
  return P.IsAreaShown(module.area or module.id)
end

-- Modules that get a hub tile (and whose area is shown).
function Mods.Visible(includeHidden)
  local out = {}
  for _, m in ipairs(Mods.list) do
    if not m.hidden and (includeHidden or Mods.IsShown(m)) then out[#out + 1] = m end
  end
  return out
end

-- v1.1: one entry per area, in hub order: { id, nameKey, icon, modules = { ids } }
function Mods.Areas()
  local out, byId = {}, {}
  for _, m in ipairs(Mods.list) do
    local a = byId[m.area]
    if not a then
      a = { id = m.area, modules = {} }
      byId[m.area] = a
      out[#out + 1] = a
    end
    a.modules[#a.modules + 1] = m.id
    if not m.hidden or not a.nameKey then a.nameKey, a.icon = m.nameKey, m.icon end
    if m.areaKey then a.nameKey = m.areaKey end
  end
  return out
end

-- Decide how the kid answers. purpose: "practice" | "review" | "trial"
function Mods.InputMode(module, node, tier, purpose)
  if module.inputMode then
    local mode, n = module.inputMode(node, tier, purpose)
    if mode then return mode, n end
  end
  if module.choiceOnlyBands[node.band] then return "choice", module.youngChoices end
  if purpose == "trial" then return "input" end -- no guessing on trials
  if (tier or 1) == 1 then return "choice", module.choices end
  return "input"
end

function Mods.Generate(nodeId, level, tier, purpose)
  local module, node = Mods.FindNode(nodeId)
  if not node then return nil end
  level = Util.Clamp(floor(level or 1), 1, 5)
  local p = node.gen(level)
  p.nodeId, p.moduleId, p.level, p.tier = nodeId, module.id, level, tier or 1
  if p.forceMode == "typing" then
    p.mode = "typing" -- typing practice is always typed, even for the youngest band
  elseif p.choices then
    p.mode = "choice"
    p.choiceOnly = true -- the generator picked the buttons itself (e.g. reading questions)
  else
    local mode, n = Mods.InputMode(module, node, tier, purpose)
    if p.choiceOnly and mode ~= "choice" then
      mode, n = "choice", (module.choiceOnlyBands[node.band] and module.youngChoices or module.choices)
    end
    if mode == "choice" and type(p.answer) == "number" then
      local minChoice = p.minChoice or ((not p.allowNegative) and 0 or nil)
      local spread
      if n <= 3 then spread = p.spread or 2 else spread = p.spread or max(3, floor(abs(p.answer) * 0.2)) end
      p.mode = "choice"
      p.choices = Util.MakeChoices(p.answer, n, spread, minChoice, p.distractors, p.maxChoice)
    elseif mode == "choice" then
      p.mode = "choice"
      p.choices = Mods.TextChoices(p.answer, p.distractors, math.min(n or 4, p.maxChoices or 99))
      if p.chooseText then p.text = p.chooseText end
    elseif type(p.answer) == "string" then
      p.mode = "text"
    else
      p.mode = "input"
    end
  end
  return p
end

-- Text choices: the answer plus up to n-1 distinct distractors (case-insensitive), shuffled.
function Mods.TextChoices(answer, distractors, n)
  local out, seen = { answer }, { [string.lower(answer)] = true }
  for _, d in ipairs(distractors or {}) do
    if #out >= n then break end
    local k = string.lower(tostring(d))
    if not seen[k] then out[#out + 1] = d; seen[k] = true end
  end
  return Util.Shuffle(out)
end

-- ctx = { elapsed = seconds on this try, tier = tier } (typing modules use it)
-- returns correct(bool), info(table|nil)
function Mods.Check(p, given, ctx)
  if not p then return false end
  local module = p.moduleId and Mods.byId[p.moduleId]
  if module and module.check then
    local okv, info = module.check(p, given, ctx)
    return okv and true or false, info
  end
  if p.mode == "choice" or type(p.answer) == "string" then
    return tostring(given) == tostring(p.answer)
  end
  local n = Util.ParseNumber(given)
  return n ~= nil and abs(n - p.answer) < 1e-9
end

function Mods.FormatAnswer(p)
  if type(p.answer) == "number" then return Util.Commas(p.answer) end
  return tostring(p.answer)
end

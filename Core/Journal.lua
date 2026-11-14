-- Collection books (v0.9 Field Journal, generalized in v0.11). Pure Lua (no WoW API).
--
-- A module with collectibles registers a book: one item per skill tier (nodeId -> {tier1,
-- tier2, tier3}), e.g. Naturalist specimens or Gnomish Engineering blueprint pages. Mastering
-- a tier collects its item. Entries live account-wide in AzerothAcademyDB.journal.entries
-- keyed "nodeId:tier" (node ids are unique across modules, so books share one table and a
-- family shares every book). Sync() re-collects anything the current character has mastered.
--
-- Book strings come from L[prefix .. "_TITLE"] etc. and fall back to the JOURNAL_* keys.
local _, ns = ...
local Util = ns.Util

local J = {}
ns.Journal = J

J.DEFAULT = "naturalist"
J.books, J.order = {}, {}

-- def = { moduleId, items, prefix, openEvent, newEvent, sound }
function J.RegisterBook(def)
  assert(type(def) == "table" and def.moduleId and type(def.items) == "table", "bad book")
  def.prefix = def.prefix or "JOURNAL"
  if not J.books[def.moduleId] then J.order[#J.order + 1] = def.moduleId end
  J.books[def.moduleId] = def
  for nodeId, list in pairs(def.items) do
    for t, item in ipairs(list) do item.nodeId, item.tier, item.moduleId = nodeId, t, def.moduleId end
  end
  return def
end

function J.Book(moduleId) return J.books[moduleId or J.DEFAULT] end

function J.Books()
  local out = {}
  for _, id in ipairs(J.order) do
    if ns.Modules.Get(id) then out[#out + 1] = J.books[id] end
  end
  return out
end

-- the book a node belongs to
function J.BookFor(nodeId)
  local m = ns.Modules.FindNode(nodeId or "")
  return m and J.books[m.id] or nil
end

-- localized book string: L[prefix_SUFFIX] or the Field Journal default
function J.Str(moduleId, suffix)
  local L = ns.L
  local b = J.Book(moduleId)
  local key = (b and b.prefix or "JOURNAL") .. "_" .. suffix
  local v = L[key]
  if v == key then v = L["JOURNAL_" .. suffix] end
  return v
end

local function entries()
  local P = ns.Progress
  if not (P and P.account) then return nil end
  if type(P.account.journal) ~= "table" then P.account.journal = {} end
  if type(P.account.journal.entries) ~= "table" then P.account.journal.entries = {} end
  return P.account.journal.entries
end

function J.Key(nodeId, tier) return tostring(nodeId) .. ":" .. tostring(tier) end

function J.Specimen(nodeId, tier)
  local b = J.BookFor(nodeId)
  local list = b and b.items[nodeId]
  return list and list[tier] or nil
end
J.Item = J.Specimen

-- Every item of one book in display order: { nodeId, tier, band, spec }
function J.All(moduleId)
  moduleId = moduleId or J.DEFAULT
  local b = J.books[moduleId]
  local out = {}
  if not b then return out end
  for _, band in ipairs(ns.Modules.BAND_ORDER) do
    for _, nodeId in ipairs(ns.Modules.Nodes(moduleId, band)) do
      for t = 1, 3 do
        local spec = b.items[nodeId] and b.items[nodeId][t]
        if spec then out[#out + 1] = { nodeId = nodeId, tier = t, band = band, spec = spec } end
      end
    end
  end
  return out
end

function J.Has(nodeId, tier)
  local e = entries()
  return e ~= nil and e[J.Key(nodeId, tier)] ~= nil
end

function J.Entry(nodeId, tier)
  local e = entries()
  return e and e[J.Key(nodeId, tier)]
end

-- Called when a tier is newly mastered. Returns the item if it is new to its book.
function J.Collect(nodeId, tier, now)
  local spec = J.Specimen(nodeId, tier)
  local e = entries()
  if not spec or not e then return nil end
  local k = J.Key(nodeId, tier)
  if e[k] then return nil end
  e[k] = { at = now or Util.Now() }
  return spec
end

-- Collect every item (all books) whose tier the current character has mastered.
function J.Sync(now)
  local P = ns.Progress
  local out = {}
  if not (P and P.char and type(P.char.modules) == "table") then return out end
  for _, b in ipairs(J.Books()) do
    local st = P.char.modules[b.moduleId]
    if type(st) == "table" and type(st.nodes) == "table" then
      for _, it in ipairs(J.All(b.moduleId)) do
        local nr = st.nodes[it.nodeId]
        local tr = type(nr) == "table" and type(nr.tiers) == "table" and nr.tiers[it.tier]
        if type(tr) == "table" and tr.mastered then
          local spec = J.Collect(it.nodeId, it.tier, tr.masteredAt or now)
          if spec then out[#out + 1] = spec end
        end
      end
    end
  end
  return out
end

-- have, total (optionally for one band) for one book
function J.Count(band, moduleId)
  local have, total = 0, 0
  for _, it in ipairs(J.All(moduleId)) do
    if not band or it.band == band then
      total = total + 1
      if J.Has(it.nodeId, it.tier) then have = have + 1 end
    end
  end
  return have, total
end

-- "missing" | "collected" | "faded" (collected, but this character's tier is fading or due a review)
function J.Status(nodeId, tier, now)
  if not J.Has(nodeId, tier) then return "missing" end
  local P = ns.Progress
  local m = ns.Modules.FindNode(nodeId or "")
  local st = m and P and P.char and type(P.char.modules) == "table" and P.char.modules[m.id]
  local nr = type(st) == "table" and type(st.nodes) == "table" and st.nodes[nodeId]
  local tr = type(nr) == "table" and type(nr.tiers) == "table" and nr.tiers[tier]
  if type(tr) == "table" and (tr.fading or (ns.Review and ns.Review.IsDue(tr, now or Util.Now()))) then return "faded" end
  return "collected"
end

function J.FadedCount(now, moduleId)
  local n = 0
  for _, it in ipairs(J.All(moduleId)) do
    if J.Status(it.nodeId, it.tier, now) == "faded" then n = n + 1 end
  end
  return n
end

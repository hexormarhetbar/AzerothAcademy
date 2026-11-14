-- Field Journal (v0.9): the Azeroth Naturalist bestiary. One page per mastered
-- Naturalist tier (5 skills x Spark/Rune/Glyph per band). Pages are account-wide
-- (ns.Journal in Core/NaturalistGen.lua); faded ink means this character's tier is
-- fading or due a review, and the page offers that review right here.
-- Specimen pictures are in-game icons loaded at runtime; nothing is shipped.
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

local JU = {}
ns.JournalUI = JU

JU.CELL, JU.GAP = 40, 46
JU.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function say(event) if ns.GuideUI then return ns.GuideUI.Say(event) end end
local function tierName(t) return L[ns.Mastery.TIERS[t].key] end

function JU.Open(target)
  if not H.IsShown() then H.Open("home") end
  if not H.IsShown() then return end
  H.ShowView("journal", target or "open")
end

-- Text + action for one page (pure enough for the smoke test).
function JU.PageInfo(nodeId, tier)
  local J = ns.Journal
  local spec = J.Specimen(nodeId, tier)
  local _, node = ns.Modules.FindNode(nodeId)
  local status = J.Status(nodeId, tier)
  local skill = string.format(L.JOURNAL_SKILL, node and L[node.key] or nodeId, tierName(tier))
  if status == "missing" then
    return { status = status, name = L.JOURNAL_UNKNOWN, icon = JU.UNKNOWN_ICON, zone = "", skill = skill,
      note = string.format(L.JOURNAL_HOWTO, node and L[node.key] or nodeId, tierName(tier)), action = "practice" }
  end
  local e = J.Entry(nodeId, tier)
  local info = { status = status, name = spec.name, icon = spec.icon, skill = skill, note = spec.note,
    zone = string.format(L.JOURNAL_ZONE, spec.zone) }
  if status == "faded" then
    info.state = "|cffff8800" .. string.format(L.JOURNAL_FADING, node and L[node.key] or nodeId) .. "|r"
    info.action = "review"
  else
    info.state = "|cff4dff66" .. string.format(L.JOURNAL_FOUND, date and e and e.at and date("%Y-%m-%d", e.at) or "") .. "|r"
  end
  return info
end

-- Practice for a missing page, or the review that restores a faded one.
function JU.DoAction(nodeId, tier)
  local RF = ns.Lessons
  local status = ns.Journal.Status(nodeId, tier)
  if status == "missing" then
    RF.StartRound(nodeId, ns.Mastery.CurrentTier(nodeId))
  elseif status == "faded" then
    local tr = ns.Progress.GetTierRec(nodeId, tier)
    if tr.fading or #ns.Review.Due() == 0 then RF.StartRound(nodeId, tier) else RF.StartReview() end
  end
end

H.RegisterView("journal", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local J = ns.Journal

  local title = W.Text(v, 18, L.JOURNAL_TITLE, W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", 4, -2)
  local back = W.Button(v, L.BACK, 90, 22, function()
    ns.Lessons.moduleId = "naturalist"
    H.ShowView("forge")
  end)
  back:SetPoint("TOPRIGHT", 0, 0)
  local count = W.Text(v, 12, "", W.ARCANE, "LEFT")
  count:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  count:SetWidth(540)
  v.count = count

  -- band tabs
  local tabs = {}
  for i, b in ipairs(ns.Progress.BANDS) do
    local t = W.Button(v, L[b.key], 150, 22, function()
      C.Sound("page")
      v.band = b.id
      v.selNode, v.selTier = nil, nil
      v:Refresh()
    end, 11)
    t:SetPoint("TOPLEFT", (i - 1) * 158, -46)
    t.band = b.id
    tabs[i] = t
  end
  v.tabs = tabs

  -- tier headers + grid (rows = skills, columns = Spark/Rune/Glyph)
  local x0, y0 = 130, -96
  for t = 1, 3 do
    local h = W.Text(v, 10, tierName(t), W.GRAY, "CENTER")
    h:SetPoint("TOP", v, "TOPLEFT", x0 + (t - 1) * JU.GAP + JU.CELL / 2, y0 + 16)
  end
  local rows, cells = {}, {}
  for r = 1, 5 do
    local lab = W.Text(v, 11, "", W.WHITE, "LEFT")
    lab:SetPoint("TOPLEFT", 4, y0 - (r - 1) * JU.GAP - 12)
    lab:SetWidth(122)
    rows[r] = lab
    cells[r] = {}
    for t = 1, 3 do
      local b = C.CreateFrame("Button", nil, v, nil, true)
      b:SetSize(JU.CELL, JU.CELL)
      b:SetPoint("TOPLEFT", x0 + (t - 1) * JU.GAP, y0 - (r - 1) * JU.GAP)
      local icon = b:CreateTexture(nil, "ARTWORK")
      icon:SetSize(JU.CELL - 8, JU.CELL - 8)
      icon:SetPoint("CENTER")
      b.icon = icon
      b.tier = t
      b:SetScript("OnClick", function(self)
        if not self.nodeId then return end
        C.Sound("click")
        v.selNode, v.selTier = self.nodeId, self.tier
        v:Refresh()
      end)
      cells[r][t] = b
    end
  end
  v.cells, v.rows = cells, rows

  -- detail page
  local px = 290
  local dIcon = W.FramedIcon(v, 44, JU.UNKNOWN_ICON)
  dIcon:SetPoint("TOPLEFT", px + 8, y0 - 6)
  local dName = W.Text(v, 14, "", W.GOLD, "LEFT")
  dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 14, 2)
  dName:SetWidth(190)
  local dZone = W.Text(v, 11, "", W.ARCANE, "LEFT")
  dZone:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4)
  dZone:SetWidth(190)
  local dSkill = W.Text(v, 10, "", W.GRAY, "LEFT")
  dSkill:SetPoint("TOPLEFT", px, y0 - 62)
  dSkill:SetWidth(256)
  local dNote = W.Text(v, 12, L.JOURNAL_PICK, W.WHITE, "LEFT")
  dNote:SetPoint("TOPLEFT", dSkill, "BOTTOMLEFT", 0, -8)
  dNote:SetWidth(256)
  local dState = W.Text(v, 11, "", W.GREEN, "LEFT")
  dState:SetPoint("TOPLEFT", dNote, "BOTTOMLEFT", 0, -8)
  dState:SetWidth(256)
  local action = W.Button(v, L.JOURNAL_REVIEW, 150, 26, function()
    if v.selNode then JU.DoAction(v.selNode, v.selTier) end
  end, 12)
  action:SetPoint("TOPLEFT", px, y0 - 200)
  action:Hide()
  v.detail = { icon = dIcon, name = dName, zone = dZone, skill = dSkill, note = dNote, state = dState, action = action }

  local faded = W.Text(v, 11, "", W.AMBER, "LEFT")
  faded:SetPoint("TOPLEFT", 4, y0 - 5 * JU.GAP - 6)
  faded:SetWidth(540)
  v.faded = faded

  function v:Refresh()
    local band = self.band or ns.Progress.GetBand() or "initiate"
    self.band = band
    local have, total = J.Count()
    local bh, bt = J.Count(band)
    count:SetText(string.format(L.JOURNAL_COUNT, have, total) .. "    " ..
      string.format(L.JOURNAL_BAND_COUNT, L[ns.Progress.BAND_BY_ID[band].key], bh, bt))
    for _, t in ipairs(tabs) do
      if t.LockHighlight then if t.band == band then t:LockHighlight() else t:UnlockHighlight() end end
    end
    local nodes = ns.Modules.Nodes("naturalist", band)
    for r = 1, 5 do
      local nodeId = nodes[r]
      local _, node = ns.Modules.FindNode(nodeId or "")
      rows[r]:SetText(node and L[node.key] or "")
      for t = 1, 3 do
        local b = cells[r][t]
        b.nodeId = nodeId
        local status = nodeId and J.Status(nodeId, t) or "missing"
        local spec = nodeId and J.Specimen(nodeId, t)
        b.status = status
        if status == "missing" or not spec then
          b.icon:SetTexture(JU.UNKNOWN_ICON)
          b.icon:SetAlpha(0.35)
          if b.icon.SetDesaturated then b.icon:SetDesaturated(true) end
        else
          b.icon:SetTexture(spec.icon)
          b.icon:SetAlpha(status == "faded" and 0.55 or 1)
          if b.icon.SetDesaturated then b.icon:SetDesaturated(status == "faded") end
        end
        if self.selNode == nodeId and self.selTier == t then
          C.ApplyBackdrop(b, 0.18, 0.08, 0.32, 0.95, 1, 0.82, 0)
        elseif status == "faded" then
          C.ApplyBackdrop(b, 0.12, 0.07, 0.03, 0.9, 1, 0.55, 0.1)
        elseif status == "collected" then
          C.ApplyBackdrop(b, 0.05, 0.14, 0.08, 0.9, 0.3, 0.8, 0.45)
        else
          C.ApplyBackdrop(b, 0.08, 0.06, 0.14, 0.9, 0.35, 0.3, 0.5)
        end
      end
    end
    local d = self.detail
    if self.selNode then
      local info = JU.PageInfo(self.selNode, self.selTier)
      d.icon:SetTexture(info.icon)
      if d.icon.SetDesaturated then d.icon:SetDesaturated(info.status ~= "collected") end
      d.name:SetText(info.name)
      d.zone:SetText(info.zone or "")
      d.skill:SetText(info.skill or "")
      d.note:SetText(info.note or "")
      d.state:SetText(info.state or "")
      if info.action == "review" then
        d.action:SetText(L.JOURNAL_REVIEW); d.action:Show()
      elseif info.action == "practice" then
        d.action:SetText(L.JOURNAL_PRACTICE); d.action:Show()
      else
        d.action:Hide()
      end
      self.info = info
    else
      d.icon:SetTexture(JU.UNKNOWN_ICON)
      d.name:SetText(""); d.zone:SetText(""); d.skill:SetText(""); d.state:SetText("")
      d.note:SetText(L.JOURNAL_PICK)
      d.action:Hide()
      self.info = nil
    end
    local nf = J.FadedCount()
    faded:SetText(nf > 0 and string.format(L.JOURNAL_FADED, nf) or "")
  end

  -- arg: nil (refresh), "open"/"setup" (fresh open), or { nodeId=, tier= } to open a page
  function v:OnShowView(arg)
    if arg ~= nil then
      J.Sync()
      if type(arg) == "table" and arg.nodeId then
        local _, node = ns.Modules.FindNode(arg.nodeId)
        self.band = node and node.band or self.band
        self.selNode, self.selTier = arg.nodeId, arg.tier or 1
      else
        self.band = ns.Progress.GetBand() or self.band
        self.selNode, self.selTier = nil, nil
      end
      C.Sound("page")
      say("NATJOURNAL")
    end
    self:Refresh()
  end
  return v
end)

-- Main Hub window: one movable, ESC-closable frame that hosts every screen ("view").
local _, ns = ...
local C, W = ns.Compat, ns.W
local L = ns.L

local H = {}
ns.Hub = H

H.WIDTH, H.HEIGHT = 580, 544
local views, builders = {}, {}

H.BYE_AFTER = 20 -- seconds the window must have been open before Fizzwick says goodbye

function H.RegisterView(name, builder) builders[name] = builder end

local function savePosition(f)
  local db = ns.Progress.account
  if not db then return end
  local point, _, relPoint, x, y = f:GetPoint(1)
  db.ui.point, db.ui.relPoint, db.ui.x, db.ui.y = point, relPoint, x, y
end

local function restorePosition(f)
  f:ClearAllPoints()
  local ui = ns.Progress.account and ns.Progress.account.ui
  if ui and ui.point then
    f:SetPoint(ui.point, UIParent, ui.relPoint or ui.point, ui.x or 0, ui.y or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end

function H.Create()
  if H.frame then return H.frame end
  local f = C.CreateFrame("Frame", "AzerothAcademyHub", UIParent, nil, true)
  f:SetSize(H.WIDTH, H.HEIGHT)
  f:SetFrameStrata(C.settings.strata)
  if f.SetToplevel then f:SetToplevel(true) end
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self)
  end)
  C.ApplyDialogFrame(f, 0.04, 0.03, 0.10, 0.96)
  restorePosition(f)

  -- ESC closes the window (Blizzard closes frames listed in UISpecialFrames).
  if UISpecialFrames then table.insert(UISpecialFrames, "AzerothAcademyHub") end

  -- Title: the classic dialog header plate (in-client art) with the name on it
  local header = f:CreateTexture(nil, "ARTWORK")
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetSize(300, 64)
  header:SetPoint("TOP", 0, 12)
  f.header = header
  local title = W.Text(f, 15, L.ADDON_TITLE, W.GOLD, "CENTER")
  title:SetPoint("TOP", header, "TOP", 0, -14)
  f.title = title
  local sub = W.Text(f, 10, "", W.GRAY, "RIGHT")
  sub:SetPoint("TOPRIGHT", -40, -18)
  sub:SetText("v" .. ns.VERSION .. " - " .. (C.FLAVOR_NAMES[C.flavor] or C.flavor))

  local close = C.CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  if close:GetWidth() == 0 then
    close:SetSize(24, 24)
    close:SetText("X")
  end
  close:SetScript("OnClick", function() f:Hide() end)

  local content = CreateFrame("Frame", nil, f)
  f.content = content
  if ns.GuideUI then ns.GuideUI.Attach(f) end
  H.SetGuideVisible(true, f)

  f:SetScript("OnShow", function()
    C.Sound("open")
    H.openedAt = C.Now()
  end)
  f:SetScript("OnHide", function()
    if H.rebuilding then -- v1.1: language switch, the window is rebuilt right away
      for _, v in pairs(views) do if v.OnHubHidden then pcall(v.OnHubHidden, v) end end
      return
    end
    C.Sound("close")
    -- v0.8: Fizzwick says goodbye when the kid closes the window after a real visit (not for combat)
    if ns.GuideUI and not H.hiddenByCombat and C.Now() - (H.openedAt or 0) >= H.BYE_AFTER then ns.GuideUI.Goodbye() end
    H.greeted = false
    if ns.GuideUI then ns.GuideUI.HideOverlays() end
    for _, v in pairs(views) do
      if v.OnHubHidden then pcall(v.OnHubHidden, v) end
    end
  end)
  f:Hide()
  H.frame = f
  return f
end

-- The guide strip sits under the content area; full-height views (the Parent
-- Panel) hide it and get the space back.
function H.SetGuideVisible(show, frame)
  local f = frame or H.frame
  if not f then return end
  local content, strip = f.content, ns.GuideUI and ns.GuideUI.strip
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", 16, -40)
  if show and strip then
    content:SetPoint("BOTTOMRIGHT", -16, 14 + ns.GuideUI.STRIP_HEIGHT + 6)
    strip:Show()
  else
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    if strip then strip:Hide() end
  end
end

function H.HasView(name) return builders[name] ~= nil end

function H.GetView(name)
  if not views[name] and builders[name] then
    local v = builders[name](H.frame.content)
    v:SetAllPoints(H.frame.content)
    v:Hide()
    views[name] = v
  end
  return views[name]
end

function H.ShowView(name, ...)
  H.Create()
  local target = H.GetView(name)
  if not target then return end
  for n, v in pairs(views) do
    if n ~= name then v:Hide() end
  end
  H.current = name
  H.SetGuideVisible(not target.hideGuide)
  target:Show()
  if target.OnShowView then target:OnShowView(...) end
end

function H.RefreshCurrent()
  local v = H.current and views[H.current]
  if v and v:IsShown() and v.OnShowView then v:OnShowView() end
end

function H.IsShown() return H.frame and H.frame:IsShown() end

-- v1.1 language picker: every screen is built once with the labels of the language in use.
-- After a switch the window, its views, Fizzwick's strip and the small toasts are thrown away
-- (hidden; WoW cannot delete frames) and rebuilt with the new strings and font. Lesson and
-- duel state live in the core, so nothing in progress is lost.
H.rebuildHooks = {}
function H.OnRebuild(fn) H.rebuildHooks[#H.rebuildHooks + 1] = fn end

function H.RebuildForLocale(reopenView, ...)
  local settingsUnlocked = views.parent and views.parent.unlocked
  C.SetUIFont(ns.locale)
  local wasShown = H.IsShown()
  if H.frame then
    H.rebuilding = true
    H.frame:Hide()
    H.rebuilding = false
    H.frame = nil
  end
  for k in pairs(views) do views[k] = nil end
  H.current = nil
  if H.resumeToast then H.resumeToast:Hide(); H.resumeToast = nil end
  for _, fn in ipairs(H.rebuildHooks) do pcall(fn) end
  H.Create()
  if settingsUnlocked then H.GetView("parent").unlocked = true end
  if wasShown or reopenView then H.Open(reopenView, ...) end
  return true
end
H.Rebuild = H.RebuildForLocale -- v1.1 area selection rebuilds the hub tiles the same way

function H.Open(viewName, ...)
  if C.InCombat() then
    C.Print(L.NO_COMBAT)
    return
  end
  H.Create()
  if H.resumeToast then H.resumeToast:Hide() end
  H.frame:Show()
  if not ns.Progress.GetBand() then
    H.ShowView("profile")
  elseif viewName then
    H.ShowView(viewName, ...)
  elseif H.current and H.current ~= "profile" then
    H.ShowView(H.current)
  else
    H.ShowView("home")
  end
end

function H.Toggle()
  if H.IsShown() then H.frame:Hide() else H.Open() end
end

-- Combat handling ---------------------------------------------------------
function H.HideForCombat()
  if H.IsShown() then
    H.hiddenByCombat = true
    H.frame:Hide()
    C.Print(L.COMBAT_HIDDEN)
  end
end

function H.OfferResume()
  if not H.hiddenByCombat then return end
  H.hiddenByCombat = false
  if not H.resumeToast then
    local t = C.CreateFrame("Frame", "AzerothAcademyResume", UIParent, nil, true)
    t:SetSize(330, 74)
    t:SetPoint("TOP", UIParent, "TOP", 0, -140)
    t:SetFrameStrata("HIGH")
    C.ApplyBackdrop(t, 0.06, 0.04, 0.14, 0.95, 0.62, 0.48, 1, 1)
    local msg = W.Text(t, 12, L.RESUME_PROMPT, W.GOLD, "CENTER")
    msg:SetPoint("TOP", 0, -12)
    msg:SetWidth(310)
    local yes = W.Button(t, L.RESUME, 110, 24, function() t:Hide(); H.Open() end)
    yes:SetPoint("BOTTOMRIGHT", t, "BOTTOM", -6, 10)
    local no = W.Button(t, L.LATER, 110, 24, function() t:Hide() end)
    no:SetPoint("BOTTOMLEFT", t, "BOTTOM", 6, 10)
    H.resumeToast = t
  end
  H.resumeToast:Show()
  local toast = H.resumeToast
  C.After(25, function() if toast:IsShown() then toast:Hide() end end)
end

------------------------------------------------------------------------
-- View: first-run profile (age band) setup
------------------------------------------------------------------------
H.RegisterView("profile", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  local title = W.Text(v, 20, L.PROFILE_TITLE, W.GOLD, "CENTER")
  title:SetPoint("TOP", 0, -20)
  title:SetWidth(540)
  local text = W.Text(v, 13, L.PROFILE_TEXT, W.WHITE, "CENTER")
  text:SetPoint("TOP", title, "BOTTOM", 0, -12)
  text:SetWidth(500)
  local flavor = { initiate = L.PROFILE_FLAVOR_INITIATE, adept = L.PROFILE_FLAVOR_ADEPT, magister = L.PROFILE_FLAVOR_MAGISTER }
  local y = -120
  for _, band in ipairs(ns.Progress.BANDS) do
    local b = W.Button(v, L[band.key] .. "  (" .. string.format(L.BAND_AGES, band.ages) .. ")", 300, 44, function()
      ns.Progress.SetBand(band.id)
      H.ShowView("home")
    end, 16)
    b:SetPoint("TOP", 0, y)
    local d = W.Text(v, 11, flavor[band.id], W.GRAY, "CENTER")
    d:SetPoint("TOP", b, "BOTTOM", 0, -4)
    d:SetWidth(460)
    y = y - 84
  end
  return v
end)

------------------------------------------------------------------------
-- View: home (rank, shards, minutes, module buttons)
------------------------------------------------------------------------
-- Playable subjects come from the module registry (ns.Modules); these are the
-- placeholders for subjects that are not built yet.
H.COMING_SOON = {
  { id = "scribe",     key = "MOD_SCRIBE",     icon = "Interface\\Icons\\INV_Inscription_Scroll" },
  { id = "gnomish",    key = "MOD_GNOMISH",    icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

function H.Tiles()
  local tiles, seen = {}, {}
  for _, m in ipairs(ns.Modules.Visible()) do
    tiles[#tiles + 1] = { id = m.id, key = m.nameKey, descKey = m.descKey, icon = m.icon, active = true }
    seen[m.nameKey or m.id] = true
  end
  for _, m in ipairs(H.COMING_SOON) do
    if not seen[m.key] and #tiles < 8 then tiles[#tiles + 1] = m end
  end
  return tiles
end

H.RegisterView("home", function(parent)
  local v = CreateFrame("Frame", nil, parent)

  -- Left column: the apprentice's stats
  local stats = C.CreateFrame("Frame", nil, v, nil, true)
  stats:SetPoint("TOPLEFT", 0, 0)
  stats:SetSize(200, 396)
  C.ApplyBackdrop(stats, 0.08, 0.06, 0.16, 0.9, 0.4, 0.3, 0.6)

  local crest = W.FramedIcon(stats, 48, "Interface\\Icons\\Spell_Holy_MagicalSentry")
  crest:SetPoint("TOP", 0, -18)
  local rank = W.Text(stats, 15, "", W.GOLD, "CENTER")
  rank:SetPoint("TOP", crest, "BOTTOM", 0, -8)
  rank:SetWidth(186)
  local bar = W.Bar(stats, 180, 20, W.ARCANE)
  bar:SetPoint("TOP", rank, "BOTTOM", 0, -6)
  local barNote = W.Text(stats, 10, "", W.GRAY, "CENTER")
  barNote:SetPoint("TOP", bar, "BOTTOM", 0, -3)
  barNote:SetWidth(186)
  local shards = W.Text(stats, 13, "", W.WHITE, "CENTER")
  shards:SetPoint("TOP", barNote, "BOTTOM", 0, -14)
  local minutes = W.Text(stats, 13, "", W.GREEN, "CENTER")
  minutes:SetPoint("TOP", shards, "BOTTOM", 0, -8)
  minutes:SetWidth(186)
  local band = W.Text(stats, 11, "", W.GRAY, "CENTER")
  band:SetPoint("TOP", minutes, "BOTTOM", 0, -12)
  band:SetWidth(186)

  local review = W.Button(stats, L.REVIEW_RUNES, 170, 26, function() ns.Lessons.StartReview() end)
  review:SetPoint("BOTTOM", 0, 82)
  local drill = W.Button(stats, L.QUICK_DRILL, 170, 26, function() ns.Lessons.QuickDrill() end)
  drill:SetPoint("BOTTOM", 0, 48)
  -- v1.1: the Parent Panel is now Settings (the PIN is optional)
  local parentBtn = W.Button(stats, L.SETTINGS_BTN, 170, 26, function() H.ShowView("parent") end)
  parentBtn:SetPoint("BOTTOM", 0, 14)
  -- v0.10: Duel of Wits (multiplayer learning races)
  local duelBtn = W.Button(stats, "|cffffd100" .. L.DUEL_BTN .. "|r", 170, 26, function()
    if ns.DuelUI then ns.DuelUI.Open() end
  end)
  duelBtn:SetPoint("BOTTOM", 0, 116)
  v.duelBtn = duelBtn

  -- v1.1: language picker (small globe in the stats corner)
  local langBtn = C.CreateFrame("Button", nil, stats)
  langBtn:SetSize(24, 24)
  langBtn:SetPoint("TOPRIGHT", -6, -6)
  langBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
  if langBtn.SetHighlightTexture then pcall(langBtn.SetHighlightTexture, langBtn, "Interface\\Buttons\\ButtonHilight-Square", "ADD") end
  langBtn:SetScript("OnClick", function() C.Sound("click"); H.ShowView("language") end)
  langBtn:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.LANG_TITLE)
    GameTooltip:AddLine(L.LANG_TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  langBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  v.langBtn = langBtn
  v.langBtn = langBtn

  -- Right side: module grid
  local header = W.Header(v, L.CHOOSE_LESSON, 15, 330)
  header:SetPoint("TOPLEFT", stats, "TOPRIGHT", 14, -6)
  local col, row = 0, 0
  for _, m in ipairs(H.Tiles()) do
    local b = C.CreateFrame("Button", nil, v, nil, true)
    b:SetSize(160, 78)
    b:SetPoint("TOPLEFT", stats, "TOPRIGHT", 14 + col * 168, -30 - row * 88)
    if m.active then
      C.ApplyBackdrop(b, 0.18, 0.08, 0.32, 0.95, 1, 0.82, 0)
    else
      C.ApplyBackdrop(b, 0.08, 0.08, 0.1, 0.85, 0.3, 0.3, 0.3)
    end
    local icon = W.FramedIcon(b, 34, m.icon)
    icon:SetPoint("LEFT", 12, 8)
    if not m.active and icon.SetDesaturated then icon:SetDesaturated(true) end
    local name = W.Text(b, 12, L[m.key], m.active and W.GOLD or W.GRAY, "LEFT")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
    name:SetWidth(100)
    local desc = W.Text(b, 10, m.active and L[m.descKey or (m.key .. "_DESC")] or L.COMING_SOON, m.active and W.WHITE or W.GRAY, "LEFT")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    desc:SetWidth(100)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 4, -4)
    hl:SetPoint("BOTTOMRIGHT", -4, 4)
    C.SetColor(hl, 1, 1, 1, 0.08)
    if m.active then
      b:SetScript("OnClick", function()
        C.Sound("click")
        ns.Lessons.OpenModule(m.id)
      end)
      -- Quick Drill for this subject: straight into its best next lesson
      local drillBtn = W.Button(b, L.TILE_DRILL, 56, 18, function()
        ns.Lessons.moduleId = m.id
        ns.Lessons.QuickDrill()
      end, 10)
      drillBtn:SetPoint("BOTTOMRIGHT", -6, 6)
      drillBtn.tooltip = L.TILE_DRILL_TIP
      drillBtn.moduleId = m.id
      b.drill = drillBtn
      -- v0.6: mini-game shortcut (Scribe's Scrolls -> Murloc Boarding Party)
      local def = ns.Modules.Get(m.id)
      if def and def.game then
        local gameBtn = W.Button(b, L[def.game.tileKey], 60, 18, function()
          ns.Lessons.moduleId = m.id
          H.ShowView(def.game.view, "setup")
        end, 10)
        gameBtn:SetPoint("RIGHT", drillBtn, "LEFT", -4, 0)
        gameBtn.tooltip = L[def.game.tipKey]
        b.game = gameBtn
      end
    else
      b:SetScript("OnClick", function()
        C.Print(L[m.key] .. ": " .. L.COMING_SOON)
      end)
    end
    col = col + 1
    if col > 1 then col, row = 0, row + 1 end
  end

  function v:OnShowView()
    local P = ns.Progress
    local info = P.GetRankInfo()
    rank:SetText(string.format(L.RANK_LINE, L[info.key]))
    if info.nextKey then
      bar:SetProgress(info.pct, string.format("%d / %d", info.shards, info.nextMin))
      barNote:SetText(string.format(L.RANK_PROGRESS, info.shards, info.nextMin, L[info.nextKey]))
    else
      bar:SetProgress(1, tostring(info.shards))
      barNote:SetText(L.RANK_MAX)
    end
    shards:SetText(string.format(L.SHARDS_LINE, P.char.shards))
    local earned, cap = P.GetTodayMinutes()
    minutes:SetText(string.format(L.MINUTES_LINE, earned, cap))
    local b = P.BAND_BY_ID[P.GetBand() or ""]
    band:SetText(b and string.format(L.BAND_LINE, L[b.key], string.format(L.BAND_AGES, b.ages)) or "")
    local due = #ns.Review.Due()
    if due > 0 then
      review:SetText("|cff66ccff" .. string.format(L.REVIEW_BUTTON, due) .. "|r")
      review:Show()
      W.Flash(review, W.ARCANE, 0.8)
    else
      review:Hide()
    end
    if not H.greeted and ns.GuideUI then
      H.greeted = true
      ns.GuideUI.Say("GREET")
      C.Sound("chirp")
    end
  end
  return v
end)

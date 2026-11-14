-- Minimap button (v0.6.1): left-click toggles the hub, right-click opens the Parent Panel
-- (the PIN still applies), drag moves it around the rim. No libraries are bundled; if
-- another addon already loaded LibDataBroker + LibDBIcon, we register with those instead
-- so minimap-button collectors see one button. The angle is saved per account.
local _, ns = ...
local C, L = ns.Compat, ns.L

local MB = {}
ns.MinimapButton = MB

MB.FALLBACK_ICON = "Interface\\Icons\\Trade_Engineering"

local function db()
  local s = ns.Progress.account.settings
  if type(s.minimap) ~= "table" then s.minimap = {} end
  local m = s.minimap
  if m.hide == nil then m.hide = false end
  m.angle = ns.MinimapMath.Normalize(m.angle or m.minimapPos)
  return m
end
MB.DB = db

-- Icon: Fizzwick's head crop when the art is present, else the engineering icon.
function MB.IconPath()
  local A, man = ns.Art, ns.ArtManifest
  local miss = ns.GuideUI and ns.GuideUI.missingArt
  if type(man) == "table" and man.fizzwick_greet_head and not (miss and miss.fizzwick_greet_head) then
    return A.DIR .. "fizzwick_greet_head", true
  end
  return MB.FALLBACK_ICON, false
end

-- Tooltip lines (also used by the LibDataBroker path).
function MB.TooltipLines()
  local P = ns.Progress
  local lines = { L.MM_TITLE, L.MM_HELP_LEFT, L.MM_HELP_RIGHT, L.MM_HELP_DRAG }
  if P.char then
    local info = P.GetRankInfo()
    local earned, cap = P.GetTodayMinutes()
    lines[#lines + 1] = " "
    lines[#lines + 1] = string.format(L.RANK_LINE, L[info.key]) .. "  |  " .. string.format(L.SHARDS_LINE, P.char.shards)
    lines[#lines + 1] = string.format(L.MINUTES_LINE, earned, cap)
    lines[#lines + 1] = string.format(L.MM_REVIEWS, ns.Review and #ns.Review.Due() or 0)
  end
  return lines
end

local function fillTooltip(tt)
  for i, line in ipairs(MB.TooltipLines()) do
    if i == 1 then tt:AddLine(line, 1, 0.82, 0) else tt:AddLine(line, 1, 1, 1) end
  end
end

function MB.LeftClick()
  if C.InCombat() then C.Print(L.NO_COMBAT) return end
  ns.Hub.Toggle()
end

function MB.RightClick()
  if C.InCombat() then C.Print(L.NO_COMBAT) return end
  if not (ns.Hub.IsShown() and ns.Hub.current == "parent") then
    local pv = ns.Hub.frame and ns.Hub.GetView("parent")
    if pv then pv.unlocked = false end -- the PIN is asked every time it opens from here
  end
  ns.Hub.Open("parent")
end

function MB.OnClick(button)
  if button == "RightButton" then MB.RightClick() else MB.LeftClick() end
end

local function minimapShape()
  if GetMinimapShape then
    local ok, s = pcall(GetMinimapShape)
    if ok and type(s) == "string" then return s end
  end
  return "ROUND"
end

function MB.UpdatePosition()
  local b = MB.button
  if not b or not Minimap then return end
  local x, y = ns.MinimapMath.Position(db().angle, minimapShape(), Minimap:GetWidth())
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function dragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale() or 1
  if not (mx and px) then return end
  db().angle = ns.MinimapMath.AngleFrom(px / scale - mx, py / scale - my)
  MB.UpdatePosition()
end
MB.DragUpdate = dragUpdate

-- Optional: someone else's LibDBIcon. Returns true when it took over.
local function tryLibDBIcon()
  if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return false end
  local ok, LDB = pcall(LibStub, "LibDataBroker-1.1", true)
  local ok2, Icon = pcall(LibStub, "LibDBIcon-1.0", true)
  if not (ok and ok2 and LDB and Icon) then return false end
  local done = pcall(function()
    local obj = LDB:NewDataObject("AzerothAcademy", {
      type = "launcher", text = L.MM_TITLE, icon = (MB.IconPath()),
      OnClick = function(_, button) MB.OnClick(button) end,
      OnTooltipShow = function(tt) fillTooltip(tt) end,
    })
    local m = db()
    m.minimapPos = m.minimapPos or m.angle
    Icon:Register("AzerothAcademy", obj, m)
    MB.libIcon = Icon
  end)
  return done and MB.libIcon ~= nil
end

function MB.Create()
  if MB.button or MB.libIcon then return MB.button end
  if not Minimap then return nil end
  if tryLibDBIcon() then MB.Apply() return nil end
  local b = CreateFrame("Button", "AzerothAcademyMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  if b.SetFrameLevel and Minimap.GetFrameLevel then b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8) end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(19, 19)
  icon:SetPoint("TOPLEFT", 6, -6)
  local path, isArt = MB.IconPath()
  if icon:SetTexture(path) == false then
    if ns.GuideUI then ns.GuideUI.missingArt.fizzwick_greet_head = true end
    path, isArt = MB.FALLBACK_ICON, false
    icon:SetTexture(path)
  end
  if isArt then
    -- round mask on clients that have it; the plain square crop is fine elsewhere
    if not (icon.SetMask and pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask")) and icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
  elseif icon.SetTexCoord then
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
  b.icon = icon
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")
  b.ring = ring

  b:SetScript("OnClick", function(_, button) MB.OnClick(button) end)
  b:SetScript("OnDragStart", function(self)
    if self.LockHighlight then self:LockHighlight() end
    self.dragging = true
    self:SetScript("OnUpdate", dragUpdate)
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self.dragging = false
    if self.UnlockHighlight then self:UnlockHighlight() end
  end)
  b:SetScript("OnEnter", function(self)
    if self.dragging or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  MB.button = b
  MB.Apply()
  return b
end

-- Show or hide per the saved setting, and place it.
function MB.Apply()
  local hide = db().hide
  if MB.libIcon then
    pcall(hide and MB.libIcon.Hide or MB.libIcon.Show, MB.libIcon, "AzerothAcademy")
    return
  end
  local b = MB.button
  if not b then return end
  MB.UpdatePosition()
  if hide then b:Hide() else b:Show() end
end

function MB.SetHidden(hide)
  db().hide = hide and true or false
  MB.Apply()
  return db().hide
end

function MB.Toggle() return MB.SetHidden(not db().hide) end

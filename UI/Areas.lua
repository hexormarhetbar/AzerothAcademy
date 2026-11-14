-- v1.1: select which subjects/areas to show. Hiding never deletes learning progress.
local _, ns = ...
local W, H, L = ns.W, ns.Hub, ns.L
H.RegisterView("areas", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  v.hideGuide = true
  local title = W.Text(v, 17, L.AREAS_TITLE, W.GOLD)
  title:SetPoint("TOPLEFT", 4, -2)
  local back = W.Button(v, L.BACK, 90, 22, function() H.ShowView("parent") end)
  back:SetPoint("TOPRIGHT", 0, 0)
  local info = W.Text(v, 12, L.AREAS_INFO, W.WHITE)
  info:SetPoint("TOPLEFT", 4, -40); info:SetWidth(530)
  local msg = W.Text(v, 11, "", W.AMBER)
  msg:SetPoint("BOTTOMLEFT", 4, 4); msg:SetWidth(530)
  local buttons = {}
  for i, area in ipairs(ns.Modules.Areas()) do
    local b = W.Button(v, "", 264, 30, function()
      local P = ns.Progress
      if not P.SetAreaShown(area.id, not P.IsAreaShown(area.id)) then msg:SetText(L.AREAS_LAST); return end
      H.Rebuild("areas")
    end, 12)
    b:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * 274, -100 - math.floor((i - 1) / 2) * 38)
    buttons[#buttons + 1] = { b = b, area = area }
  end
  function v:OnShowView()
    -- Same optional PIN gate as other Settings controls; no bypass via the view API.
    local settings = H.GetView("parent")
    if ns.Progress.HasPin() and not (settings and settings.unlocked) then H.ShowView("parent"); return end
    for _, entry in ipairs(buttons) do
      entry.b:SetText((ns.Progress.IsAreaShown(entry.area.id) and "|cff66ff88[x] " or "|cffaaaaaa[ ] ") .. L[entry.area.nameKey] .. "|r")
    end
  end
  return v
end)

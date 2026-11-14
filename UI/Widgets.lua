-- Small defensive widget helpers shared by every Academy screen.
local _, ns = ...
local C = ns.Compat

local W = {}
ns.W = W

W.GOLD = { 1, 0.82, 0 }
W.WHITE = { 1, 1, 1 }
W.GRAY = { 0.55, 0.55, 0.55 }
W.ARCANE = { 0.72, 0.55, 1 }
W.GREEN = { 0.3, 1, 0.4 }
W.AMBER = { 1, 0.65, 0.2 }

-- Parent Panel "Reduced motion": no flashing, flying sparks or count-ups.
function W.ReducedMotion()
  local a = ns.Progress and ns.Progress.account
  return a and a.settings and a.settings.reducedMotion == true or false
end

function W.SetFontSize(fs, size, flags)
  local ok = pcall(fs.SetFont, fs, C.FONT, size or 12, flags or "")
  if not ok or not fs:GetFont() then
    if GameFontHighlight then fs:SetFontObject(GameFontHighlight) end
  end
end

function W.SetButtonFontSize(b, size)
  local fs = b.GetFontString and b:GetFontString()
  if fs then W.SetFontSize(fs, size) end
end

-- Let a button's label wrap inside the given width (nil = back to one line).
function W.ButtonWrap(b, width)
  local fs = b.GetFontString and b:GetFontString()
  if not fs then return end
  if width then
    fs:SetWidth(width)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
  else
    fs:SetWidth(0)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
  end
end

function W.Text(parent, size, text, color, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  W.SetFontSize(fs, size or 12)
  local c = color or W.WHITE
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetJustifyH(justify or "LEFT")
  if fs.SetWordWrap then fs:SetWordWrap(true) end
  fs:SetText(text or "")
  return fs
end

function W.Button(parent, text, width, height, onClick, fontSize)
  local b = C.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 120, height or 24)
  if not b:GetFontString() then
    -- template missing: build a minimal look-alike
    C.ApplyBackdrop(b, 0.25, 0.1, 0.1, 1, 0.8, 0.6, 0.2)
    local fs = W.Text(b, fontSize or 12, "", W.GOLD, "CENTER")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    if b.SetHighlightTexture then pcall(b.SetHighlightTexture, b, "Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD") end
  end
  b:SetText(text or "")
  if fontSize and b:GetFontString() then W.SetFontSize(b:GetFontString(), fontSize) end
  if onClick then
    b:SetScript("OnClick", function(self, ...)
      C.Sound("click")
      onClick(self, ...)
    end)
  end
  return b
end

function W.EditBox(parent, width, height, fontSize)
  local e = C.CreateFrame("EditBox", nil, parent, "InputBoxTemplate", false)
  e:SetSize(width or 120, height or 24)
  e:SetAutoFocus(false)
  if not e:GetFontObject() and not e:GetFont() then
    C.ApplyBackdrop(e, 0, 0, 0, 0.8)
  end
  pcall(e.SetFont, e, C.FONT, fontSize or 14, "")
  if e.SetTextInsets then e:SetTextInsets(6, 6, 0, 0) end
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return e
end

function W.Bar(parent, width, height, color)
  local holder = C.CreateFrame("Frame", nil, parent, nil, true)
  holder:SetSize(width, height)
  C.ApplyBackdrop(holder, 0, 0, 0, 0.7, 0.4, 0.4, 0.5)
  local bar = CreateFrame("StatusBar", nil, holder)
  bar:SetPoint("TOPLEFT", 4, -4)
  bar:SetPoint("BOTTOMRIGHT", -4, 4)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  local c = color or W.ARCANE
  bar:SetStatusBarColor(c[1], c[2], c[3])
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  local text = W.Text(bar, math.max(10, height - 8), "", W.WHITE, "CENTER") -- on the bar so it draws above the fill
  text:SetPoint("CENTER", holder, "CENTER", 0, 0)
  if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
  holder.bar, holder.text = bar, text
  function holder:SetProgress(v, label)
    self.bar:SetValue(math.max(0, math.min(1, v or 0)))
    self.text:SetText(label or "")
  end
  return holder
end

-- Lightweight animation runner (OnUpdate based, works on every client).
local anims = {}
local animFrame = CreateFrame("Frame")
animFrame:Hide()
animFrame:SetScript("OnUpdate", function(self, elapsed)
  for i = #anims, 1, -1 do
    local a = anims[i]
    a.t = a.t + elapsed
    local p = math.min(1, a.t / a.dur)
    local ok = pcall(a.step, p)
    if p >= 1 or not ok then
      table.remove(anims, i)
      if a.done then pcall(a.done) end
    end
  end
  if #anims == 0 then self:Hide() end
end)

function W.Animate(duration, step, done)
  anims[#anims + 1] = { t = 0, dur = duration, step = step, done = done }
  animFrame:Show()
end

-- Full-frame colored flash (the "glow" when a rune charges).
function W.Flash(frame, color, duration)
  if W.ReducedMotion() then return end
  if not frame.__aaFlash then
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    frame.__aaFlash = t
  end
  local t = frame.__aaFlash
  local c = color or W.GREEN
  C.SetColor(t, c[1], c[2], c[3], 1)
  t:SetAlpha(0.45)
  t:Show()
  W.Animate(duration or 0.6, function(p) t:SetAlpha(0.45 * (1 - p)) end, function() t:Hide() end)
end

-- Floating "+10 shards" text that drifts up and fades.
local floatPool = {}
function W.Float(parent, text, color, x, y)
  local fs = table.remove(floatPool) or W.Text(parent, 18, "", W.GOLD, "CENTER")
  if fs:GetParent() ~= parent then fs:SetParent(parent) end
  local c = color or W.GOLD
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetText(text)
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", parent, "CENTER", x or 0, y or 0)
  fs:SetAlpha(1)
  fs:Show()
  local still = W.ReducedMotion()
  W.Animate(1.2, function(p)
    if still then return end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", parent, "CENTER", x or 0, (y or 0) + 40 * p)
    fs:SetAlpha(1 - p * p)
  end, function()
    fs:Hide()
    floatPool[#floatPool + 1] = fs
  end)
end

-- Little "sparks": a burst of tiny star icons that fly outward.
function W.Sparks(parent, count, color)
  if W.ReducedMotion() then return end
  parent.__aaSparks = parent.__aaSparks or {}
  local pool = parent.__aaSparks
  for i = 1, count or 8 do
    local t = pool[i]
    if not t then
      t = parent:CreateTexture(nil, "OVERLAY")
      t:SetSize(14, 14)
      t:SetTexture("Interface\\Cooldown\\star4")
      if t.SetBlendMode then t:SetBlendMode("ADD") end
      pool[i] = t
    end
    local c = color or W.GOLD
    t:SetVertexColor(c[1], c[2], c[3])
    local angle = (i / (count or 8)) * 2 * math.pi
    local dx, dy = math.cos(angle), math.sin(angle)
    t:Show()
    W.Animate(0.7, function(p)
      t:ClearAllPoints()
      t:SetPoint("CENTER", parent, "CENTER", dx * 90 * p, dy * 50 * p)
      t:SetAlpha(1 - p)
    end, function() t:Hide() end)
  end
end

-- Count a number up from 0 (the reward screen's shard counter).
function W.CountUp(fs, target, fmt, duration)
  target = math.floor(target or 0)
  if W.ReducedMotion() or target <= 0 then
    fs:SetText(string.format(fmt, target))
    return
  end
  fs:SetText(string.format(fmt, 0))
  W.Animate(duration or 0.9, function(p)
    fs:SetText(string.format(fmt, math.floor(target * p + 0.5)))
  end, function() fs:SetText(string.format(fmt, target)) end)
end

-- Build an AnimationGroup safely. Returns the group or nil (old client / mock).
-- `build(ag)` adds the animations; any error means "no AnimationGroup here".
local function animGroup(region, field, build)
  if region[field] then return region[field] end
  if not region.CreateAnimationGroup then return nil end
  local ok, ag = pcall(function()
    local g = region:CreateAnimationGroup()
    build(g)
    return g
  end)
  if ok and ag then
    region[field] = ag
    return ag
  end
  return nil
end

local function setScaleAnim(s, from, to)
  if s.SetScaleFrom then s:SetScaleFrom(from, from); s:SetScaleTo(to, to)
  elseif s.SetFromScale then s:SetFromScale(from, from); s:SetToScale(to, to)
  else s:SetScale(to / from, to / from) end
end

-- Glyph reveal: fade + grow in. AnimationGroup when available, OnUpdate otherwise.
-- Returns "static" | "anim" | "fallback" (used by tests).
function W.Reveal(region, duration)
  duration = duration or 0.6
  region:SetAlpha(1)
  region:Show()
  if W.ReducedMotion() then return "static" end
  local ag = animGroup(region, "__aaReveal", function(g)
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(duration)
    local sc = g:CreateAnimation("Scale")
    setScaleAnim(sc, 0.4, 1)
    sc:SetDuration(duration)
    if sc.SetSmoothing then sc:SetSmoothing("OUT") end
  end)
  if ag and pcall(function() ag:Stop(); ag:Play() end) then return "anim" end
  region:SetAlpha(0)
  W.Animate(duration, function(p) region:SetAlpha(p) end, function() region:SetAlpha(1) end)
  return "fallback"
end

-- Soft looping glow (combo meter). on=false stops it. Without AnimationGroups (or
-- with reduced motion) the glow is simply shown steady.
function W.Pulse(region, on, alpha)
  alpha = alpha or 0.6
  local ag = region.__aaPulse
  if not on then
    if ag then pcall(ag.Stop, ag) end
    region:Hide()
    return
  end
  region:Show()
  region:SetAlpha(alpha)
  if W.ReducedMotion() then
    if ag then pcall(ag.Stop, ag) end
    return "static"
  end
  ag = animGroup(region, "__aaPulse", function(g)
    if g.SetLooping then g:SetLooping("BOUNCE") end
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(alpha * 0.35); a:SetToAlpha(alpha); a:SetDuration(0.55)
  end)
  if ag and pcall(function() if not ag:IsPlaying() then ag:Play() end end) then return "anim" end
  return "static"
end

-- Section header: gold text with the in-client divider underneath.
function W.Header(parent, text, size, width)
  local fs = W.Text(parent, size or 15, text, W.GOLD, "LEFT")
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
  line:SetSize(width or 256, 16)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", -8, 4)
  fs.divider = line
  return fs
end

-- Square icon with the action-button slot frame around it (in-client art).
function W.FramedIcon(parent, size, texture)
  local icon = parent:CreateTexture(nil, "ARTWORK")
  icon:SetSize(size, size)
  icon:SetTexture(texture)
  local border = parent:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(size * 1.7, size * 1.7)
  border:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.border = border
  return icon
end

-- v0.11: command grid for Gnomish Engineering puzzles (also drawn in duels).
-- spec = { w, h, bot = {x, y, dir}, goal = {x, y}, walls = {{x, y}}, coins = {{x, y}},
--          marks = {{x, y, label}} } with x/y 1-based and y = 1 the top row.
-- Pictures are in-game icons loaded at runtime.
W.GRID_ICONS = {
  bot = "Interface\\Icons\\Ability_Mount_MechaStrider",
  goal = "Interface\\Icons\\INV_Misc_Gear_01",
  wall = "Interface\\Icons\\INV_Stone_01",
  coin = "Interface\\Icons\\INV_Misc_Coin_01",
}
W.GRID_ARROWS = { N = "^", E = ">", S = "v", W = "<" }
function W.Grid(parent, maxSide, cell)
  maxSide, cell = maxSide or 6, cell or 22
  local g = CreateFrame("Frame", nil, parent)
  g:SetSize(maxSide * cell, maxSide * cell)
  g.cells, g.cell, g.maxSide = {}, cell, maxSide
  for y = 1, maxSide do
    for x = 1, maxSide do
      local bg = g:CreateTexture(nil, "BACKGROUND")
      bg:SetSize(cell - 2, cell - 2)
      bg:SetPoint("TOPLEFT", (x - 1) * cell + 1, -((y - 1) * cell + 1))
      local icon = g:CreateTexture(nil, "ARTWORK")
      icon:SetSize(cell - 4, cell - 4)
      icon:SetPoint("CENTER", bg, "CENTER", 0, 0)
      local label = W.Text(g, math.floor(cell * 0.6), "", W.GOLD, "CENTER", "OVERLAY")
      label:SetPoint("CENTER", bg, "CENTER", 0, 0)
      g.cells[(y - 1) * maxSide + x] = { bg = bg, icon = icon, label = label }
    end
  end
  function g:Draw(spec)
    if type(spec) ~= "table" then self:Hide() return end
    local w, h = math.min(spec.w or 5, self.maxSide), math.min(spec.h or 5, self.maxSide)
    local kind = {}
    local function put(list, k)
      for _, c in ipairs(list or {}) do kind[c[2] * 100 + c[1]] = { k = k, label = c[3] } end
    end
    put(spec.walls, "wall"); put(spec.coins, "coin")
    if spec.goal then put({ spec.goal }, "goal") end
    put(spec.marks, "mark")
    if spec.bot then put({ { spec.bot[1], spec.bot[2], W.GRID_ARROWS[spec.bot[3] or "E"] } }, "bot") end
    for y = 1, self.maxSide do
      for x = 1, self.maxSide do
        local c = self.cells[(y - 1) * self.maxSide + x]
        if x <= w and y <= h then
          local k = kind[y * 100 + x]
          C.SetColor(c.bg, 0.16, 0.13, 0.24, 0.95)
          c.bg:Show()
          c.label:SetText(k and k.label or "")
          c.label:Show()
          if k and k.k ~= "mark" then
            c.icon:SetTexture(W.GRID_ICONS[k.k])
            c.icon:SetAlpha(k.k == "bot" and 1 or 0.9)
            c.icon:Show()
          else
            c.icon:Hide()
          end
          if k and k.k == "mark" then C.SetColor(c.bg, 0.3, 0.22, 0.05, 0.95) end
        else
          c.bg:Hide(); c.icon:Hide(); c.label:Hide()
        end
      end
    end
    self.spec = spec
    self:SetSize(w * self.cell, h * self.cell)
    self:Show()
  end
  g:Hide()
  return g
end

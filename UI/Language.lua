-- v1.1 Language picker: "Auto (game language)" or any shipped translation, switched live.
-- Reached from the globe on the home screen, from Settings and with /aa lang <code|auto>.
-- Not behind the PIN: reading in your own language is never a parent-only choice.
local _, ns = ...
local C, W, H = ns.Compat, ns.W, ns.Hub
local L = ns.L

local LU = {}
ns.LanguageUI = LU

-- Apply a choice ("auto" or a locale code). Returns the code in use, or nil if unknown.
-- The window (if open) is rebuilt in the new language and reopens on `reopen`.
function LU.Apply(choice, reopen)
  local P = ns.Progress
  if not P.account then return nil end
  local before = ns.locale
  local code = P.SetLanguage(choice)
  if not code then return nil end
  if code ~= before or C.FONT ~= C.FontFor(code) then
    H.RebuildForLocale(H.IsShown() and reopen or nil)
  end
  return code
end

-- Label for the choice in use: "Auto (game language): English" or the native name.
function LU.CurrentLabel()
  local choice = ns.localeChoice or "auto"
  local cur = ns.LANGUAGE_BY_CODE[ns.locale or "enUS"]
  if choice == "auto" then return string.format(L.LANG_AUTO_IS, cur and cur.name or ns.locale) end
  return cur and cur.name or choice
end

-- /aa lang [code|auto]  (case-insensitive: "kokr", "koKR", "ko" all work)
function LU.Slash(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if arg == "" then
    C.Print(string.format(L.LANG_STATUS, LU.CurrentLabel()))
    local codes = {}
    for _, c in ipairs(ns.LANGUAGE_CHOICES) do codes[#codes + 1] = c.code end
    C.Print(string.format(L.LANG_HELP, table.concat(codes, ", ")))
    return
  end
  local want = arg:lower()
  local pick
  if want == "auto" or want == "game" then pick = "auto" end
  for _, c in ipairs(ns.LANGUAGE_CHOICES) do
    if want == c.code:lower() or want == c.code:sub(1, 2):lower() then pick = pick or c.code end
  end
  if want == "esmx" then pick = "esES" end
  if not pick or not LU.Apply(pick, "language") then
    C.Print(string.format(L.LANG_UNKNOWN, arg))
    return
  end
  C.Print(string.format(L.LANG_STATUS, LU.CurrentLabel()))
  if C.UsesBundledFont(ns.locale) then C.Print(L.LANG_CHAT_NOTE) end
end

H.RegisterView("language", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  v.hideGuide = true
  local title = W.Text(v, 17, L.LANG_TITLE, W.GOLD, "LEFT")
  title:SetPoint("TOPLEFT", 4, -2)
  local back = W.Button(v, L.BACK, 90, 22, function() H.ShowView(v.backTo or "home") end)
  back:SetPoint("TOPRIGHT", 0, 0)
  local info = W.Text(v, 11, L.LANG_INFO, W.WHITE, "LEFT")
  info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  info:SetWidth(540)
  local cur = W.Text(v, 12, "", W.GREEN, "LEFT")
  cur:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -8)
  cur:SetWidth(540)

  local buttons = {}
  local auto = W.Button(v, "", 540, 28, function() LU.Apply("auto", "language") end, 13)
  auto:SetPoint("TOPLEFT", cur, "BOTTOMLEFT", 0, -10)
  auto.code = "auto"
  buttons[1] = auto
  for i, c in ipairs(ns.LANGUAGE_CHOICES) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local b = W.Button(v, "", 266, 28, function() LU.Apply(c.code, "language") end, 13)
    b:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", col * 274, -8 - row * 32)
    b.code = c.code
    -- each language is written in its own script, so it gets the font that has its letters
    W.SetButtonFontFace(b, C.FontFor(c.code), 13)
    buttons[#buttons + 1] = b
  end
  local note = W.Text(v, 10, "", W.GRAY, "LEFT")
  note:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -8 - 5 * 32 - 6)
  note:SetWidth(540)
  local reload = W.Button(v, L.LANG_RELOAD, 150, 24, function()
    if ReloadUI and not C.InCombat() then ReloadUI() end
  end, 11)
  reload:SetPoint("BOTTOMRIGHT", 0, 0)
  local reloadNote = W.Text(v, 10, L.LANG_RELOAD_NOTE, W.GRAY, "LEFT")
  reloadNote:SetPoint("BOTTOMLEFT", 0, 4)
  reloadNote:SetWidth(380)
  v.buttons = buttons

  function v:OnShowView(backTo)
    if backTo == "parent" or backTo == "home" then self.backTo = backTo end
    local choice = ns.localeChoice or "auto"
    cur:SetText(string.format(L.LANG_CURRENT, LU.CurrentLabel()))
    local client = ns.LANGUAGE_BY_CODE[ns.ClientLocale()]
    local autoText = string.format(L.LANG_AUTO, client and client.name or ns.ClientLocale())
    auto:SetText(choice == "auto" and ("|cffffd100> " .. autoText .. " <|r") or autoText)
    W.SetButtonFontFace(auto, C.FontFor(ns.ClientLocale()), 13)
    local anyBundled = false
    for i = 2, #buttons do
      local b = buttons[i]
      local c = ns.LANGUAGE_BY_CODE[b.code]
      local label = c.name
      if C.UsesBundledFont(b.code) then label = label .. " *"; anyBundled = true end
      if choice == b.code then label = "|cffffd100> " .. label .. " <|r" end
      b:SetText(label)
    end
    note:SetText((anyBundled and (L.LANG_FONT_NOTE .. " ") or "") .. L.LANG_MACHINE_NOTE)
  end
  return v
end)

-- Build ns.L: active locale -> enUS -> the key itself.
-- v1.1: the active locale can be changed at runtime (in-game language picker,
-- account setting `settings.language`, "auto" = the client's language). ns.L is ONE table
-- for the whole session; switching only swaps the table it reads from, so every file that
-- did `local L = ns.L` sees the new language on its next lookup. Labels that were already
-- drawn are rebuilt by the UI (ns.Hub.RebuildForLocale), not here.
local _, ns = ...
local data = ns.LocaleData or {}
local enUS = data.enUS or {}
local cur = {}

-- Picker order and native names (each shown in its own script).
ns.LANGUAGE_CHOICES = {
  { code = "enUS", name = "English" },
  { code = "deDE", name = "Deutsch" },
  { code = "frFR", name = "Fran\195\167ais" },
  { code = "esES", name = "Espa\195\177ol" },
  { code = "ptBR", name = "Portugu\195\170s (Brasil)" },
  { code = "itIT", name = "Italiano" },
  { code = "ruRU", name = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185" },
  { code = "koKR", name = "\237\149\156\234\181\173\236\150\180" },
  { code = "zhCN", name = "\231\174\128\228\189\147\228\184\173\230\150\135" },
  { code = "zhTW", name = "\231\185\129\233\171\148\228\184\173\230\150\135" },
}
ns.LANGUAGE_BY_CODE = {}
for _, c in ipairs(ns.LANGUAGE_CHOICES) do ns.LANGUAGE_BY_CODE[c.code] = c end
ns.LANGUAGE_BY_CODE.esMX = ns.LANGUAGE_BY_CODE.esES

-- "auto" / nil / unknown -> the client's own language
function ns.ResolveLocale(choice)
  if type(choice) == "string" and choice ~= "auto" then
    if choice == "enGB" then choice = "enUS" end
    if choice == "enUS" or data[choice] then return choice end
  end
  local l = ns.ClientLocale()
  if l ~= "enUS" and not data[l] then l = "enUS" end
  return l
end

function ns.SetLocale(choice)
  local code = ns.ResolveLocale(choice)
  cur = (code ~= "enUS" and data[code]) or {}
  ns.locale = code
  ns.localeChoice = (type(choice) == "string" and choice ~= "" and ns.LANGUAGE_BY_CODE[choice] and choice) or "auto"
  return code
end

ns.L = setmetatable({}, {
  __index = function(_, key)
    local v = cur[key]
    if v == nil then v = enUS[key] end
    if v == nil then v = key end
    return v
  end,
})
ns.SetLocale("auto")

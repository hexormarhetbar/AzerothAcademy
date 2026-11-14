-- Build ns.L: current locale -> enUS -> the key itself.
local _, ns = ...
local data = ns.LocaleData or {}
local enUS = data.enUS or {}

local locale = ns.ClientLocale()
ns.locale = locale
local cur = data[locale] or {}

ns.L = setmetatable({}, {
  __index = function(_, key)
    local v = cur[key]
    if v == nil then v = enUS[key] end
    if v == nil then v = key end
    return v
  end,
})

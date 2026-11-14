-- Dev helper: prints the README language table rows from the shipped locale files.
-- Usage: lua tools/locale_table.lua
local ns = { Env = { locale = "enUS", allLocales = true } }
for line in io.lines("AzerothAcademy.toc") do
  line = line:gsub("\r", "")
  if line:match("^Core\\Namespace") or line:match("^Locales\\") then assert(loadfile((line:gsub("\\", "/"))))("AzerothAcademy", ns) end
end
local EN, total = ns.LocaleData.enUS, 0
for _, v in pairs(EN) do
  if v:gsub("%%[-+ #0]*%d*%.?%d*[dsfixX%%]", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):find("%a%a") then total = total + 1 end
end
local names = { deDE = "German", frFR = "French", esES = "Spanish (Spain)", esMX = "Spanish (Latin America, same table as esES)",
  ptBR = "Portuguese (Brazil)", itIT = "Italian", ruRU = "Russian", koKR = "Korean", zhCN = "Simplified Chinese", zhTW = "Traditional Chinese" }
local engine = { deDE = "Argos", esES = "Argos", esMX = "Argos", itIT = "Argos", ruRU = "Argos", frFR = "NLLB-200", ptBR = "NLLB-200",
  koKR = "NLLB-200", zhCN = "NLLB-200", zhTW = "NLLB-200 + OpenCC" }
local sum = 0
for _, loc in ipairs(ns.LOCALES) do
  local n = 0
  for _ in pairs(ns.LocaleData[loc]) do n = n + 1 end
  if loc ~= "esMX" then sum = sum + n end
  print(string.format("| %s | %s | Machine translation (%s), %d of %d strings (%d%%). **Needs native-speaker review** |",
    loc, names[loc], engine[loc], n, total, math.floor(n / total * 100 + 0.5)))
end
io.stderr:write("TOTAL " .. sum .. "\n")

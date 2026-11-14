#!/bin/sh
# Runs every check. Needs lua5.1 + luac + luacheck on PATH.
set -e
cd "$(dirname "$0")/.."
echo "== luac -p (syntax) =="
for f in $(find . -name '*.lua' | sort); do luac -p "$f"; done
echo "all files parse"
echo "== luacheck (whole addon, WoW globals whitelisted) =="
luacheck . -q
echo "== core purity (Core/ + Locales/ may only use time/date/GetLocale) =="
luacheck Core Locales -q --no-config --std lua51 --no-max-line-length --ignore 212 432 --read-globals time date GetLocale
echo "== headless core harness =="
lua tests/harness.lua "${ITER:-400}"
echo "== UI smoke tests (mock WoW API) =="
lua tests/ui_smoke.lua 16001
lua tests/ui_smoke.lua 120105
lua tests/ui_smoke.lua 11509
lua tests/ui_smoke.lua 16001 legacy
echo "== UI smoke on translated clients (v1.0: Lua errors + raw-text scan; English text checks skipped) =="
AA_LOCALE=deDE lua tests/ui_smoke.lua 16001
AA_LOCALE=ruRU lua tests/ui_smoke.lua 11509
AA_LOCALE=koKR lua tests/ui_smoke.lua 120105
AA_LOCALE=zhCN lua tests/ui_smoke.lua 16001 legacy
echo "ALL CHECKS PASSED"

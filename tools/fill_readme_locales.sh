#!/bin/sh
# Dev helper: refresh the README language table between the locale markers.
cd "$(dirname "$0")/.." && lua tools/locale_table.lua > /tmp/aa_rows.txt 2> /tmp/aa_total.txt && python3 - <<'PY'
import re
s = open("README.md", encoding="utf-8").read()
rows = open("/tmp/aa_rows.txt", encoding="utf-8").read().rstrip("\n")
total = open("/tmp/aa_total.txt").read().split()[1]
s = s.replace("{{LOCALE_ROWS}}", "<!-- locales:start -->\n" + rows + "\n<!-- locales:end -->")
s = re.sub(r"<!-- locales:start -->.*?<!-- locales:end -->", lambda m: "<!-- locales:start -->\n" + rows + "\n<!-- locales:end -->", s, flags=re.S)
s = s.replace("{{TRANSLATED_TOTAL}}", "<!-- total -->" + total + "<!-- /total -->")
s = re.sub(r"<!-- total -->\d+<!-- /total -->", "<!-- total -->" + total + "<!-- /total -->", s)
open("README.md", "w", encoding="utf-8").write(s)
PY

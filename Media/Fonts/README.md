# Bundled fonts (v1.1.0)

WoW clients only ship fonts for their own region: English and European clients have no Korean, Chinese or Japanese
glyphs, and no client has a Japanese font. These four fonts let the addon draw World Tongues (kana and kanji) and the
Korean/Chinese interface on any client.

| File | Family name | Source | Weight | Characters |
|---|---|---|---|---|
| `AzAcadSans-JP.ttf` | AzAcad Sans JP | Noto Sans JP (Google Fonts, variable, version 2.004) | 500 | Latin, Cyrillic, kana, the 60 World Tongues kanji, picker names |
| `AzAcadSans-KR.ttf` | AzAcad Sans KR | Noto Sans KR | 500 | the koKR table + World Tongues |
| `AzAcadSans-SC.ttf` | AzAcad Sans SC | Noto Sans SC | 500 | the zhCN table + World Tongues |
| `AzAcadSans-TC.ttf` | AzAcad Sans TC | Noto Sans TC | 500 | the zhTW table + World Tongues |

`coverage.txt` lists every character in each subset; the test harness checks that every character the addon can draw
with a font is in it.

**License.** These are Modified Versions of Noto Sans JP/KR/SC/TC, (c) 2014-2021 Adobe (http://www.adobe.com/), with
Reserved Font Name 'Source', licensed under the SIL Open Font License, Version 1.1 (`OFL.txt` in this folder; also at
https://scripts.sil.org/OFL). They were instanced at one weight, subset, and renamed "AzAcad Sans" (no Reserved Font
Name is used). They are not covered by the addon's MIT license and may not be sold by themselves.

**Rebuild** after changing any text: download the four `NotoSans*[wght].ttf` files and `OFL.txt` from
https://github.com/google/fonts/tree/main/ofl into `/workspace/fonts` (renamed `NotoSansJP.ttf` and so on), then
run `python3 tools/build_fonts.py` (needs `fontTools`).

# World Tongues voice clips (v1.2.2)

121 clips, mono 44.1 kHz Ogg Vorbis (`tools/master_audio.py`), about 1.1 MB in all. Listed in `tools/tongues_clips.tsv`;
`python3 tools/gen_tongues_clips.py` turns that list into `Core/TonguesClips.lua`. Shared clips: katakana use the
hiragana clip of the same sound, ぢ uses じ, づ uses ず (so 123 entries, 121 files).

## Voices (generated with ElevenLabs)

Both voices are **original voices designed from a text description** with ElevenLabs Voice Design for this addon.
**No voice cloning, no samples or recordings of any real person, and nothing from the game.**

| Course | Voice name | Voice id | Brief |
|---|---|---|---|
| Japanese | AzAcad Tongues - Japanese Teacher | `YoehWfvcIKadBIOJc73w` | adult female teacher, native-sounding Tokyo-standard Japanese |
| Spanish | AzAcad Tongues - Spanish Teacher | `xSdwcYyEmcoPXQWVelvl` | adult male teacher, native-sounding neutral Latin American Spanish |

Model: `eleven_multilingual_v2`.

## v1.2.2: one consistent voice

In v1.2.1 some Japanese clips sounded like a different speaker. Measured, the single kana spread over a wide pitch
range (standard deviation 5.1 semitones around the median, up to 13 semitones off; 17 of 68 kana more than 6 semitones
off), and the Spanish clips spread even more (7.5 st). v1.2.2 regenerates the Japanese set and the Spanish outliers:

- **Same settings for every clip:** stability 0.75, similarity boost 0.9, style 0, speaker boost on, language code
  `ja` / `es`, speed 0.85 (kana) / 0.95 (phrases). The ElevenLabs tool used has **no seed** and no
  previous/next-text conditioning, so neither was used; consistency comes from the higher stability, one prompt format,
  and the selection below.
- **One prompt format for all kana:** the kana followed by `。` (`か。`). Row batches (`か。 き。 く。 け。 こ。`, split on
  silence) were tried first; only the あ, や and ば rows came out with clean pauses, so 5 clips are row cuts and the
  rest are single prompts.
- **Objective check, then retakes.** `tools/voice_check/` measures every clip against its group median (kana /
  Japanese phrases / Spanish): Praat pitch (`pitch_summary.py`), Resemblyzer speaker-embedding distance and spectral
  stats (`consistency.py`). Outliers were regenerated (up to 3 retake rounds) and the take closest to the median kept.
- **Small pitch nudge.** 37 clips that were still well off the median were moved toward it
  with Praat PSOLA (`pitchnorm.py`; formants and timing unchanged, at most a few semitones). The shift per clip is in
  the table and in `tools/voice_check/v122_takes.tsv` (which also records the ElevenLabs generation id).
- **Kept from v1.2.0:** い (new takes were read "ai"), う (new takes were unclear), いいえ (new takes dropped the え) and
  おなまえは (new takes sounded like "onamee"); all four are already inside the pitch band. 9 Spanish clips were
  already consistent and were kept; 2 more were kept with a pitch nudge, 9 were regenerated.
- **Pronunciation check:** done locally with faster-whisper (free): all 32 Japanese phrase clips and all 20 Spanish clips
  matched their text. Whisper cannot judge a single kana, so the kana have no automated pronunciation check in v1.2.2;
  **a native speaker should listen to them.** ElevenLabs speech-to-text was not used in v1.2.2.
- Mastered with `tools/master_audio.py`: trimmed, ~-16 LUFS, mono 44.1 kHz, Ogg Vorbis q4.

| Group (Praat pitch, semitones from median) | v1.2.1 | v1.2.2 |
|---|---|---|
| Japanese kana (68 voiced; つ is unvoiced) | SD 5.09, max 13.3, 28 over 4, 17 over 6 | SD 2.48, max 4.0, 0 over 4 |
| Japanese phrases (32) | SD 2.81, max 6.1, 5 over 4, 1 over 6 | SD 2.32, max 4.4, 5 over 4 (just), 0 over 6 |
| Spanish (20) | SD 7.46, max 14.8, 12 over 4, 9 over 6 | SD 3.25, max 6.4, 5 over 4, 1 over 6 |

Re-run with `tools/voice_check/pitch_summary.py OLD_DIR Media/Sounds/Tongues`. The speaker-embedding distances barely
moved (kana median 0.31 → 0.29; Resemblyzer is not reliable on clips this short), so pitch is the main measure.

## Earlier versions (v1.2.0)

- The text sent is the **kana / Japanese script** (or the Spanish spelling with accents), never romaji.
- v1.2.0 was verified with ElevenLabs speech-to-text (Scribe v1): the clips were joined into long files, transcribed
  and matched back in order (Japanese 66 of 69 kana and all 32 lines on the first pass, the 3 misses regenerated;
  Spanish 20 of 20).

## Clips

Source: `v1.2.2` first take, `v1.2.2 retake`, `v1.2.2 row` (cut from a row prompt), `v1.2.0` (kept). Shift: PSOLA pitch
change in semitones.

| File | Course | Text | Prompt sent | Source | Shift | Seconds |
|---|---|---|---|---|---|---|
| `ja_k_a.ogg` | ja | あ | あ。 い。 う。 え。 お。 (cut 1 of 5) | v1.2.2 row |  | 0.21 |
| `ja_k_i.ogg` | ja | い | 「い」 | v1.2.0 |  | 0.16 |
| `ja_k_u.ogg` | ja | う | う、う。 (second token) | v1.2.0 |  | 0.19 |
| `ja_k_e.ogg` | ja | え | え。 | v1.2.2 retake |  | 0.28 |
| `ja_k_o.ogg` | ja | お | お。 | v1.2.2 retake | -0.6 | 0.28 |
| `ja_k_ka.ogg` | ja | か | か。 | v1.2.2 | -2.4 | 0.29 |
| `ja_k_ki.ogg` | ja | き | き。 | v1.2.2 retake | -6.1 | 0.35 |
| `ja_k_ku.ogg` | ja | く | く。 | v1.2.2 retake | -2.1 | 0.7 |
| `ja_k_ke.ogg` | ja | け | け。 | v1.2.2 retake | -5.2 | 0.39 |
| `ja_k_ko.ogg` | ja | こ | こ。 | v1.2.2 |  | 0.32 |
| `ja_k_sa.ogg` | ja | さ | さ。 | v1.2.2 |  | 0.48 |
| `ja_k_shi.ogg` | ja | し | し。 | v1.2.2 |  | 0.4 |
| `ja_k_su.ogg` | ja | す | す。 | v1.2.2 retake |  | 0.79 |
| `ja_k_se.ogg` | ja | せ | せ。 | v1.2.2 retake | +0.9 | 0.42 |
| `ja_k_so.ogg` | ja | そ | そ。 | v1.2.2 retake | -2.7 | 0.36 |
| `ja_k_ta.ogg` | ja | た | た。 | v1.2.2 |  | 0.29 |
| `ja_k_chi.ogg` | ja | ち | ち。 | v1.2.2 |  | 0.44 |
| `ja_k_tsu.ogg` | ja | つ | つ。 | v1.2.2 retake | +0.8 | 0.59 |
| `ja_k_te.ogg` | ja | て | て。 | v1.2.2 retake | -1.6 | 0.33 |
| `ja_k_to.ogg` | ja | と | と。 | v1.2.2 retake | -1.7 | 0.48 |
| `ja_k_na.ogg` | ja | な | な。 | v1.2.2 retake |  | 0.38 |
| `ja_k_ni.ogg` | ja | に | に。 | v1.2.2 |  | 0.45 |
| `ja_k_nu.ogg` | ja | ぬ | ぬ。 | v1.2.2 |  | 0.44 |
| `ja_k_ne.ogg` | ja | ね | ね。 | v1.2.2 |  | 0.36 |
| `ja_k_no.ogg` | ja | の | の。 | v1.2.2 |  | 0.39 |
| `ja_k_ha.ogg` | ja | は | は。 | v1.2.2 retake |  | 0.22 |
| `ja_k_hi.ogg` | ja | ひ | ひ。 | v1.2.2 retake | -3.4 | 0.33 |
| `ja_k_fu.ogg` | ja | ふ | ふ。 | v1.2.2 |  | 0.34 |
| `ja_k_he.ogg` | ja | へ | へ。 | v1.2.2 | -1.6 | 0.32 |
| `ja_k_ho.ogg` | ja | ほ | ほ。 | v1.2.2 | -2.2 | 0.31 |
| `ja_k_ma.ogg` | ja | ま | ま。 | v1.2.2 retake | +0.8 | 0.43 |
| `ja_k_mi.ogg` | ja | み | み。 | v1.2.2 | +0.3 | 0.39 |
| `ja_k_mu.ogg` | ja | む | む。 | v1.2.2 |  | 0.41 |
| `ja_k_me.ogg` | ja | め | め。 | v1.2.2 |  | 0.36 |
| `ja_k_mo.ogg` | ja | も | も。 | v1.2.2 |  | 0.43 |
| `ja_k_ya.ogg` | ja | や | や。 ゆ。 よ。 (cut 1 of 3) | v1.2.2 row |  | 0.35 |
| `ja_k_yu.ogg` | ja | ゆ | や。 ゆ。 よ。 (cut 2 of 3) | v1.2.2 row |  | 0.25 |
| `ja_k_yo.ogg` | ja | よ | や。 ゆ。 よ。 (cut 3 of 3) | v1.2.2 row |  | 0.24 |
| `ja_k_ra.ogg` | ja | ら | ら。 | v1.2.2 retake |  | 0.41 |
| `ja_k_ri.ogg` | ja | り | り。 | v1.2.2 retake | +0.9 | 0.64 |
| `ja_k_ru.ogg` | ja | る | る。 | v1.2.2 retake |  | 0.58 |
| `ja_k_re.ogg` | ja | れ | れ。 | v1.2.2 |  | 0.36 |
| `ja_k_ro.ogg` | ja | ろ | ろ。 | v1.2.2 | +0.4 | 0.33 |
| `ja_k_wa.ogg` | ja | わ | わ。 | v1.2.2 |  | 0.34 |
| `ja_k_wo.ogg` | ja | を | を。 | v1.2.2 | +3.0 | 0.46 |
| `ja_k_n.ogg` | ja | ん | ん。 | v1.2.2 |  | 0.42 |
| `ja_k_ga.ogg` | ja | が | が。 | v1.2.2 |  | 0.35 |
| `ja_k_gi.ogg` | ja | ぎ | ぎ。 | v1.2.2 |  | 0.44 |
| `ja_k_gu.ogg` | ja | ぐ | ぐ。 | v1.2.2 retake | -5.3 | 0.32 |
| `ja_k_ge.ogg` | ja | げ | げ。 | v1.2.2 retake | -1.4 | 0.34 |
| `ja_k_go.ogg` | ja | ご | ご。 | v1.2.2 |  | 0.38 |
| `ja_k_za.ogg` | ja | ざ | ざ。 | v1.2.2 |  | 0.38 |
| `ja_k_ji.ogg` | ja | じ | じ。 | v1.2.2 |  | 0.45 |
| `ja_k_zu.ogg` | ja | ず | ず。 | v1.2.2 retake |  | 0.67 |
| `ja_k_ze.ogg` | ja | ぜ | ぜ。 | v1.2.2 retake |  | 0.37 |
| `ja_k_zo.ogg` | ja | ぞ | ぞ。 | v1.2.2 retake | -2.8 | 0.49 |
| `ja_k_da.ogg` | ja | だ | だ。 | v1.2.2 retake | +0.6 | 0.38 |
| `ja_k_de.ogg` | ja | で | で。 | v1.2.2 |  | 0.33 |
| `ja_k_do.ogg` | ja | ど | ど。 | v1.2.2 |  | 0.45 |
| `ja_k_ba.ogg` | ja | ば | ば。 | v1.2.2 retake | -2.1 | 0.29 |
| `ja_k_bi.ogg` | ja | び | び。 | v1.2.2 retake |  | 0.31 |
| `ja_k_bu.ogg` | ja | ぶ | ぶ。 | v1.2.2 retake |  | 0.43 |
| `ja_k_be.ogg` | ja | べ | ば。 び。 ぶ。 べ。 ぼ。 (cut 4 of 5) | v1.2.2 row | -3.5 | 0.17 |
| `ja_k_bo.ogg` | ja | ぼ | ぼ。 | v1.2.2 retake | +2.6 | 0.48 |
| `ja_k_pa.ogg` | ja | ぱ | ぱ。 | v1.2.2 retake | -2.2 | 0.33 |
| `ja_k_pi.ogg` | ja | ぴ | ぴ。 | v1.2.2 |  | 0.61 |
| `ja_k_pu.ogg` | ja | ぷ | ぷ。 | v1.2.2 | -5.5 | 0.36 |
| `ja_k_pe.ogg` | ja | ぺ | ぺ。 | v1.2.2 retake |  | 0.32 |
| `ja_k_po.ogg` | ja | ぽ | ぽ。 | v1.2.2 retake | -2.7 | 0.34 |
| `ja_w_konnichiwa.ogg` | ja | こんにちは | こんにちは。 | v1.2.2 |  | 0.67 |
| `ja_w_ohayou_gozaimasu.ogg` | ja | おはようございます | おはようございます。 | v1.2.2 |  | 0.98 |
| `ja_w_konbanwa.ogg` | ja | こんばんは | こんばんは。 | v1.2.2 |  | 0.7 |
| `ja_w_arigatou_gozaimasu.ogg` | ja | ありがとうございます | ありがとうございます。 | v1.2.2 |  | 1.05 |
| `ja_w_sumimasen.ogg` | ja | すみません | すみません。 | v1.2.2 |  | 0.63 |
| `ja_w_hai.ogg` | ja | はい | はい。 | v1.2.2 retake |  | 0.4 |
| `ja_w_iie.ogg` | ja | いいえ | いいえ。 | v1.2.0 |  | 0.45 |
| `ja_w_sayounara.ogg` | ja | さようなら | さようなら。 | v1.2.2 |  | 0.7 |
| `ja_w_oyasuminasai.ogg` | ja | おやすみなさい | おやすみなさい。 | v1.2.2 |  | 0.72 |
| `ja_w_hajimemashite.ogg` | ja | はじめまして | はじめまして。 | v1.2.2 |  | 0.86 |
| `ja_w_douzo_yoroshiku.ogg` | ja | どうぞよろしく | どうぞよろしく。 | v1.2.2 |  | 0.8 |
| `ja_w_onegaishimasu.ogg` | ja | お願いします | お願いします。 | v1.2.2 |  | 0.8 |
| `ja_w_onamae_wa.ogg` | ja | おなまえは | おなまえは？ | v1.2.0 |  | 0.57 |
| `ja_w_wakarimasen.ogg` | ja | わかりません | わかりません。 | v1.2.2 |  | 0.64 |
| `ja_w_mou_ichido_onegaishimasu.ogg` | ja | もういちどお願いします | もういちどお願いします。 | v1.2.2 |  | 1.15 |
| `ja_w_yukkuri_onegaishimasu.ogg` | ja | ゆっくりお願いします | ゆっくりお願いします。 | v1.2.2 |  | 1.07 |
| `ja_w_kore_wa_nan_desu_ka.ogg` | ja | これはなんですか | これはなんですか？ | v1.2.2 |  | 1.0 |
| `ja_w_ikura_desu_ka.ogg` | ja | いくらですか | いくらですか？ | v1.2.2 |  | 0.77 |
| `ja_w_daijoubu_desu.ogg` | ja | だいじょうぶです | だいじょうぶです。 | v1.2.2 retake |  | 0.97 |
| `ja_w_dou_itashimashite.ogg` | ja | どういたしまして | どういたしまして。 | v1.2.2 |  | 0.84 |
| `ja_w_itadakimasu.ogg` | ja | いただきます | いただきます。 | v1.2.2 |  | 0.8 |
| `ja_w_gochisousama_deshita.ogg` | ja | ごちそうさまでした | ごちそうさまでした。 | v1.2.2 |  | 1.1 |
| `ja_d_konnichiwa_hajimemashite.ogg` | ja | こんにちは。はじめまして | こんにちは。はじめまして。 | v1.2.2 |  | 1.4 |
| `ja_d_watashi_wa_fizuwikku_desu.ogg` | ja | わたしはフィズウィックです | わたしはフィズウィックです。 | v1.2.2 |  | 1.24 |
| `ja_d_sore_wa_ringo_desu.ogg` | ja | それはりんごです | それはりんごです。 | v1.2.2 |  | 0.94 |
| `ja_d_irasshaimase.ogg` | ja | いらっしゃいませ | いらっしゃいませ。 | v1.2.2 |  | 0.88 |
| `ja_d_kore_wa_ikura_desu_ka.ogg` | ja | これはいくらですか | これはいくらですか？ | v1.2.2 |  | 0.96 |
| `ja_d_hyaku_en_desu.ogg` | ja | ひゃくえんです | ひゃくえんです。 | v1.2.2 |  | 0.77 |
| `ja_d_kore_o_kudasai.ogg` | ja | これをください | これをください。 | v1.2.2 |  | 0.84 |
| `ja_d_oishii_desu.ogg` | ja | おいしいです | おいしいです。 | v1.2.2 |  | 0.71 |
| `ja_d_ocha_wa_dou_desu_ka.ogg` | ja | おちゃはどうですか | おちゃはどうですか？ | v1.2.2 retake | -1.3 | 1.01 |
| `ja_d_hai_onegaishimasu.ogg` | ja | はい、お願いします | はい、お願いします。 | v1.2.2 |  | 0.94 |
| `es_hola.ogg` | es | hola | Hola. | v1.2.2 retake | -3.6 | 0.32 |
| `es_adios.ogg` | es | adiós | Adiós. | v1.2.0 |  | 0.48 |
| `es_gracias.ogg` | es | gracias | Gracias. | v1.2.0 |  | 0.48 |
| `es_por_favor.ogg` | es | por favor | Por favor. | v1.2.0 | +1.2 | 0.55 |
| `es_si.ogg` | es | sí | Sí. | v1.2.2 retake | +3.9 | 0.44 |
| `es_no.ogg` | es | no | No. | v1.2.0 |  | 0.3 |
| `es_buenos_dias.ogg` | es | buenos días | Buenos días. | v1.2.2 retake |  | 0.71 |
| `es_buenas_noches.ogg` | es | buenas noches | Buenas noches. | v1.2.2 retake |  | 0.77 |
| `es_rojo.ogg` | es | rojo | Rojo. | v1.2.0 |  | 0.37 |
| `es_azul.ogg` | es | azul | Azul. | v1.2.2 retake |  | 0.52 |
| `es_verde.ogg` | es | verde | Verde. | v1.2.0 |  | 0.54 |
| `es_amarillo.ogg` | es | amarillo | Amarillo. | v1.2.0 |  | 0.55 |
| `es_blanco.ogg` | es | blanco | Blanco. | v1.2.0 |  | 0.54 |
| `es_negro.ogg` | es | negro | Negro. | v1.2.0 |  | 0.47 |
| `es_como_estas.ogg` | es | ¿Cómo estás? | ¿Cómo estás? | v1.2.2 retake | -6.8 | 0.61 |
| `es_estoy_bien.ogg` | es | Estoy bien | Estoy bien. | v1.2.0 |  | 0.64 |
| `es_no_entiendo.ogg` | es | No entiendo | No entiendo. | v1.2.2 retake |  | 0.71 |
| `es_cuanto_cuesta.ogg` | es | ¿Cuánto cuesta? | ¿Cuánto cuesta? | v1.2.2 retake | -1.0 | 0.89 |
| `es_me_llamo.ogg` | es | Me llamo... | Me llamo... | v1.2.0 | +3.6 | 0.58 |
| `es_mucho_gusto.ogg` | es | Mucho gusto | Mucho gusto. | v1.2.2 retake | -1.7 | 0.65 |

Credits used (from the connector's per-generation prices): v1.2.0 text-to-speech about 760, speech-to-text about
1,630; v1.2.2 text-to-speech about 954 (205 generations including retakes and row tests), speech-to-text 0.
Voice Design cost was not reported by the connector.

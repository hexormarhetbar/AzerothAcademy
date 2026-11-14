# World Tongues voice clips (v1.2.0)

121 clips, mono 44.1 kHz Ogg Vorbis (`tools/master_audio.py`), 1.3 MB in all. Listed in `tools/tongues_clips.tsv`;
`python3 tools/gen_tongues_clips.py` turns that list into `Core/TonguesClips.lua`. Shared clips: katakana use the
hiragana clip of the same sound, ぢ uses じ, づ uses ず (so 123 entries, 121 files).

## Voices (generated with ElevenLabs)

Both voices are **original voices designed from a text description** with ElevenLabs Voice Design for this addon.
**No voice cloning, no samples or recordings of any real person, and nothing from the game.**

| Course | Voice name | Voice id | Brief |
|---|---|---|---|
| Japanese | AzAcad Tongues - Japanese Teacher | `YoehWfvcIKadBIOJc73w` | adult female teacher, native-sounding Tokyo-standard Japanese |
| Spanish | AzAcad Tongues - Spanish Teacher | `xSdwcYyEmcoPXQWVelvl` | adult male teacher, native-sounding neutral Latin American Spanish |

Model: `eleven_multilingual_v2`, one generation per clip (batching clips in one request runs them together).

## How each clip was made

- The text sent is the **kana / Japanese script** (or the Spanish spelling with accents), never romaji, ending in `。`
  (Japanese) so a single kana is said as a full syllable. Three vowels needed a different prompt:
  い was read "ai" from `い。`, so it uses `「い」`; え was heard as い, so it uses the katakana `エ。`; う was heard as い
  or "yu", so `う、う。` was generated and the second, clean token was cut out.
- **Verified with ElevenLabs speech-to-text (Scribe v1).** The clips were joined with gaps into long files (Japanese
  217 s, Spanish 46 s), transcribed, and each word matched back to its clip in order. Japanese: 66 of 69 kana and all
  32 greeting / phrase / dialogue lines matched on the first pass (ひゃくえんです was transcribed as "100円です",
  accepted); the 3 misses (い, う, え) were regenerated and re-checked (heard as あ、い、う、え、お / romaji A I U E O).
  Spanish: 20 of 20. The local tests also check every file is mono 44.1 kHz Ogg Vorbis.
- Mastered with `tools/master_audio.py`: trimmed, ~-16 LUFS, mono 44.1 kHz, Ogg Vorbis q4.

## Clips

| File | Course | Text | Prompt sent | Seconds |
|---|---|---|---|---|
| `ja_k_a.ogg` | ja | あ | あ。 | 0.26 |
| `ja_k_i.ogg` | ja | い | 「い」 | 0.16 |
| `ja_k_u.ogg` | ja | う | う、う。 (second token) | 0.19 |
| `ja_k_e.ogg` | ja | え | エ。 | 0.29 |
| `ja_k_o.ogg` | ja | お | お。 | 0.23 |
| `ja_k_ka.ogg` | ja | か | か。 | 0.25 |
| `ja_k_ki.ogg` | ja | き | き。 | 0.32 |
| `ja_k_ku.ogg` | ja | く | く。 | 0.41 |
| `ja_k_ke.ogg` | ja | け | け。 | 0.43 |
| `ja_k_ko.ogg` | ja | こ | こ。 | 0.3 |
| `ja_k_sa.ogg` | ja | さ | さ。 | 0.41 |
| `ja_k_shi.ogg` | ja | し | し。 | 0.32 |
| `ja_k_su.ogg` | ja | す | す。 | 0.55 |
| `ja_k_se.ogg` | ja | せ | せ。 | 0.58 |
| `ja_k_so.ogg` | ja | そ | そ。 | 0.23 |
| `ja_k_ta.ogg` | ja | た | た。 | 0.28 |
| `ja_k_chi.ogg` | ja | ち | ち。 | 0.33 |
| `ja_k_tsu.ogg` | ja | つ | つ。 | 0.64 |
| `ja_k_te.ogg` | ja | て | て。 | 0.53 |
| `ja_k_to.ogg` | ja | と | と。 | 0.41 |
| `ja_k_na.ogg` | ja | な | な。 | 0.3 |
| `ja_k_ni.ogg` | ja | に | に。 | 0.33 |
| `ja_k_nu.ogg` | ja | ぬ | ぬ。 | 0.46 |
| `ja_k_ne.ogg` | ja | ね | ね。 | 0.24 |
| `ja_k_no.ogg` | ja | の | の。 | 0.31 |
| `ja_k_ha.ogg` | ja | は | は。 | 0.26 |
| `ja_k_hi.ogg` | ja | ひ | ひ。 | 0.25 |
| `ja_k_fu.ogg` | ja | ふ | ふ。 | 0.23 |
| `ja_k_he.ogg` | ja | へ | へ。 | 0.33 |
| `ja_k_ho.ogg` | ja | ほ | ほ。 | 0.31 |
| `ja_k_ma.ogg` | ja | ま | ま。 | 0.18 |
| `ja_k_mi.ogg` | ja | み | み。 | 0.39 |
| `ja_k_mu.ogg` | ja | む | む。 | 0.37 |
| `ja_k_me.ogg` | ja | め | め。 | 0.36 |
| `ja_k_mo.ogg` | ja | も | も。 | 0.38 |
| `ja_k_ya.ogg` | ja | や | や。 | 0.32 |
| `ja_k_yu.ogg` | ja | ゆ | ゆ。 | 0.58 |
| `ja_k_yo.ogg` | ja | よ | よ。 | 0.33 |
| `ja_k_ra.ogg` | ja | ら | ら。 | 0.28 |
| `ja_k_ri.ogg` | ja | り | り。 | 0.54 |
| `ja_k_ru.ogg` | ja | る | る。 | 0.34 |
| `ja_k_re.ogg` | ja | れ | れ。 | 0.37 |
| `ja_k_ro.ogg` | ja | ろ | ろ。 | 0.28 |
| `ja_k_wa.ogg` | ja | わ | わ。 | 0.24 |
| `ja_k_wo.ogg` | ja | を | を。 | 0.3 |
| `ja_k_n.ogg` | ja | ん | ん。 | 0.22 |
| `ja_k_ga.ogg` | ja | が | が。 | 0.3 |
| `ja_k_gi.ogg` | ja | ぎ | ぎ。 | 0.27 |
| `ja_k_gu.ogg` | ja | ぐ | ぐ。 | 0.11 |
| `ja_k_ge.ogg` | ja | げ | げ。 | 0.43 |
| `ja_k_go.ogg` | ja | ご | ご。 | 0.33 |
| `ja_k_za.ogg` | ja | ざ | ざ。 | 0.35 |
| `ja_k_ji.ogg` | ja | じ | じ。 | 0.33 |
| `ja_k_zu.ogg` | ja | ず | ず。 | 0.35 |
| `ja_k_ze.ogg` | ja | ぜ | ぜ。 | 0.27 |
| `ja_k_zo.ogg` | ja | ぞ | ぞ。 | 0.4 |
| `ja_k_da.ogg` | ja | だ | だ。 | 0.3 |
| `ja_k_de.ogg` | ja | で | で。 | 0.3 |
| `ja_k_do.ogg` | ja | ど | ど。 | 0.43 |
| `ja_k_ba.ogg` | ja | ば | ば。 | 0.33 |
| `ja_k_bi.ogg` | ja | び | び。 | 0.5 |
| `ja_k_bu.ogg` | ja | ぶ | ぶ。 | 0.25 |
| `ja_k_be.ogg` | ja | べ | べ。 | 0.19 |
| `ja_k_bo.ogg` | ja | ぼ | ぼ。 | 0.6 |
| `ja_k_pa.ogg` | ja | ぱ | ぱ。 | 0.25 |
| `ja_k_pi.ogg` | ja | ぴ | ぴ。 | 0.23 |
| `ja_k_pu.ogg` | ja | ぷ | ぷ。 | 0.38 |
| `ja_k_pe.ogg` | ja | ぺ | ぺ。 | 0.36 |
| `ja_k_po.ogg` | ja | ぽ | ぽ。 | 0.27 |
| `ja_w_konnichiwa.ogg` | ja | こんにちは | こんにちは。 | 0.62 |
| `ja_w_ohayou_gozaimasu.ogg` | ja | おはようございます | おはようございます。 | 0.89 |
| `ja_w_konbanwa.ogg` | ja | こんばんは | こんばんは。 | 0.56 |
| `ja_w_arigatou_gozaimasu.ogg` | ja | ありがとうございます | ありがとうございます。 | 0.94 |
| `ja_w_sumimasen.ogg` | ja | すみません | すみません。 | 0.63 |
| `ja_w_hai.ogg` | ja | はい | はい。 | 0.31 |
| `ja_w_iie.ogg` | ja | いいえ | いいえ。 | 0.45 |
| `ja_w_sayounara.ogg` | ja | さようなら | さようなら。 | 0.69 |
| `ja_w_oyasuminasai.ogg` | ja | おやすみなさい | おやすみなさい。 | 0.81 |
| `ja_w_hajimemashite.ogg` | ja | はじめまして | はじめまして。 | 0.8 |
| `ja_w_douzo_yoroshiku.ogg` | ja | どうぞよろしく | どうぞよろしく。 | 0.79 |
| `ja_w_onegaishimasu.ogg` | ja | お願いします | お願いします。 | 0.84 |
| `ja_w_onamae_wa.ogg` | ja | おなまえは | おなまえは？ | 0.57 |
| `ja_w_wakarimasen.ogg` | ja | わかりません | わかりません。 | 0.66 |
| `ja_w_mou_ichido_onegaishimasu.ogg` | ja | もういちどお願いします | もういちどお願いします。 | 1.08 |
| `ja_w_yukkuri_onegaishimasu.ogg` | ja | ゆっくりお願いします | ゆっくりお願いします。 | 1.09 |
| `ja_w_kore_wa_nan_desu_ka.ogg` | ja | これはなんですか | これはなんですか？ | 0.87 |
| `ja_w_ikura_desu_ka.ogg` | ja | いくらですか | いくらですか？ | 0.76 |
| `ja_w_daijoubu_desu.ogg` | ja | だいじょうぶです | だいじょうぶです。 | 0.81 |
| `ja_w_dou_itashimashite.ogg` | ja | どういたしまして | どういたしまして。 | 0.92 |
| `ja_w_itadakimasu.ogg` | ja | いただきます | いただきます。 | 0.72 |
| `ja_w_gochisousama_deshita.ogg` | ja | ごちそうさまでした | ごちそうさまでした。 | 1.09 |
| `ja_d_konnichiwa_hajimemashite.ogg` | ja | こんにちは。はじめまして | こんにちは。はじめまして。 | 1.41 |
| `ja_d_watashi_wa_fizuwikku_desu.ogg` | ja | わたしはフィズウィックです | わたしはフィズウィックです。 | 1.28 |
| `ja_d_sore_wa_ringo_desu.ogg` | ja | それはりんごです | それはりんごです。 | 0.97 |
| `ja_d_irasshaimase.ogg` | ja | いらっしゃいませ | いらっしゃいませ。 | 0.86 |
| `ja_d_kore_wa_ikura_desu_ka.ogg` | ja | これはいくらですか | これはいくらですか？ | 0.97 |
| `ja_d_hyaku_en_desu.ogg` | ja | ひゃくえんです | ひゃくえんです。 | 0.82 |
| `ja_d_kore_o_kudasai.ogg` | ja | これをください | これをください。 | 0.92 |
| `ja_d_oishii_desu.ogg` | ja | おいしいです | おいしいです。 | 0.66 |
| `ja_d_ocha_wa_dou_desu_ka.ogg` | ja | おちゃはどうですか | おちゃはどうですか？ | 1.02 |
| `ja_d_hai_onegaishimasu.ogg` | ja | はい、お願いします | はい、お願いします。 | 0.98 |
| `es_hola.ogg` | es | hola | Hola. | 0.62 |
| `es_adios.ogg` | es | adiós | Adiós. | 0.48 |
| `es_gracias.ogg` | es | gracias | Gracias. | 0.48 |
| `es_por_favor.ogg` | es | por favor | Por favor. | 0.55 |
| `es_si.ogg` | es | sí | Sí. | 0.33 |
| `es_no.ogg` | es | no | No. | 0.3 |
| `es_buenos_dias.ogg` | es | buenos días | Buenos días. | 0.83 |
| `es_buenas_noches.ogg` | es | buenas noches | Buenas noches. | 0.63 |
| `es_rojo.ogg` | es | rojo | Rojo. | 0.37 |
| `es_azul.ogg` | es | azul | Azul. | 0.61 |
| `es_verde.ogg` | es | verde | Verde. | 0.54 |
| `es_amarillo.ogg` | es | amarillo | Amarillo. | 0.55 |
| `es_blanco.ogg` | es | blanco | Blanco. | 0.54 |
| `es_negro.ogg` | es | negro | Negro. | 0.47 |
| `es_como_estas.ogg` | es | ¿Cómo estás? | ¿Cómo estás? | 0.88 |
| `es_estoy_bien.ogg` | es | Estoy bien | Estoy bien. | 0.64 |
| `es_no_entiendo.ogg` | es | No entiendo | No entiendo. | 0.57 |
| `es_cuanto_cuesta.ogg` | es | ¿Cuánto cuesta? | ¿Cuánto cuesta? | 0.77 |
| `es_me_llamo.ogg` | es | Me llamo... | Me llamo... | 0.58 |
| `es_mucho_gusto.ogg` | es | Mucho gusto | Mucho gusto. | 0.67 |

Credits used (from the connector's per-generation prices): text-to-speech about 760 credits in all (596 for the
129 clip generations including retakes, 166 for early tests), speech-to-text about 1,630 credits. Voice Design
cost was not reported by the connector.

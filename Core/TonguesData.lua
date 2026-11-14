-- World Tongues: curated, real-world language courses. Pure data, no audio or game APIs.
-- Japanese uses modified Hepburn with ASCII long vowels (ou / uu) for keyboard answers.
-- The course teaches modern kana only: obsolete wi/we are deliberately not among the 46.
-- A course adds lessons { id, band, title, desc, kind, entries }. Entries: { native, reading,
-- meaning, note? }. Stable course/lesson ids are saved with mastery; never recycle an id.
local _, ns = ...
local D = { courses = {}, order = { "ja", "es" } }
ns.TonguesData = D

local hira = {
 {"あ","a"},{"い","i"},{"う","u"},{"え","e"},{"お","o"},
 {"か","ka"},{"き","ki"},{"く","ku"},{"け","ke"},{"こ","ko"},
 {"さ","sa"},{"し","shi"},{"す","su"},{"せ","se"},{"そ","so"},
 {"た","ta"},{"ち","chi"},{"つ","tsu"},{"て","te"},{"と","to"},
 {"な","na"},{"に","ni"},{"ぬ","nu"},{"ね","ne"},{"の","no"},
 {"は","ha"},{"ひ","hi"},{"ふ","fu"},{"へ","he"},{"ほ","ho"},
 {"ま","ma"},{"み","mi"},{"む","mu"},{"め","me"},{"も","mo"},
 {"や","ya"},{"ゆ","yu"},{"よ","yo"},
 {"ら","ra"},{"り","ri"},{"る","ru"},{"れ","re"},{"ろ","ro"},
 {"わ","wa"},{"を","wo"},{"ん","n"},
}
local voiced = {
 {"が","ga"},{"ぎ","gi"},{"ぐ","gu"},{"げ","ge"},{"ご","go"},
 {"ざ","za"},{"じ","ji"},{"ず","zu"},{"ぜ","ze"},{"ぞ","zo"},
 {"だ","da"},{"ぢ","ji"},{"づ","zu"},{"で","de"},{"ど","do"},
 {"ば","ba"},{"び","bi"},{"ぶ","bu"},{"べ","be"},{"ぼ","bo"},
 {"ぱ","pa"},{"ぴ","pi"},{"ぷ","pu"},{"ぺ","pe"},{"ぽ","po"},
}
local kata = {
 {"ア","a"},{"イ","i"},{"ウ","u"},{"エ","e"},{"オ","o"},
 {"カ","ka"},{"キ","ki"},{"ク","ku"},{"ケ","ke"},{"コ","ko"},
 {"サ","sa"},{"シ","shi"},{"ス","su"},{"セ","se"},{"ソ","so"},
 {"タ","ta"},{"チ","chi"},{"ツ","tsu"},{"テ","te"},{"ト","to"},
 {"ナ","na"},{"ニ","ni"},{"ヌ","nu"},{"ネ","ne"},{"ノ","no"},
 {"ハ","ha"},{"ヒ","hi"},{"フ","fu"},{"ヘ","he"},{"ホ","ho"},
 {"マ","ma"},{"ミ","mi"},{"ム","mu"},{"メ","me"},{"モ","mo"},
 {"ヤ","ya"},{"ユ","yu"},{"ヨ","yo"},
 {"ラ","ra"},{"リ","ri"},{"ル","ru"},{"レ","re"},{"ロ","ro"},
 {"ワ","wa"},{"ヲ","wo"},{"ン","n"},
}
local katavoiced = {
 {"ガ","ga"},{"ギ","gi"},{"グ","gu"},{"ゲ","ge"},{"ゴ","go"},
 {"ザ","za"},{"ジ","ji"},{"ズ","zu"},{"ゼ","ze"},{"ゾ","zo"},
 {"ダ","da"},{"ヂ","ji"},{"ヅ","zu"},{"デ","de"},{"ド","do"},
 {"バ","ba"},{"ビ","bi"},{"ブ","bu"},{"ベ","be"},{"ボ","bo"},
 {"パ","pa"},{"ピ","pi"},{"プ","pu"},{"ペ","pe"},{"ポ","po"},
}
D.hiragana, D.hiraganaVoiced, D.katakana, D.katakanaVoiced = hira, voiced, kata, katavoiced

local greetings = {
 {"こんにちは","konnichiwa","hello (daytime)"},
 {"おはようございます","ohayou gozaimasu","good morning (polite)"},
 {"こんばんは","konbanwa","good evening"},
 {"ありがとうございます","arigatou gozaimasu","thank you (polite)"},
 {"すみません","sumimasen","excuse me / sorry"},
 {"はい","hai","yes"},{"いいえ","iie","no"},
 {"さようなら","sayounara","goodbye"},
 {"おやすみなさい","oyasuminasai","good night"},
 {"はじめまして","hajimemashite","nice to meet you (first meeting)"},
 {"どうぞよろしく","douzo yoroshiku","pleased to meet you / please be kind to me"},
 {"お願いします","onegaishimasu","please (a request)"},
}
local colors = {
 {"あか","aka","red"},{"あお","ao","blue"},{"きいろ","kiiro","yellow"},
 {"みどり","midori","green"},{"しろ","shiro","white"},{"くろ","kuro","black"},
 {"むらさき","murasaki","purple"},{"ちゃいろ","chairo","brown"},
 {"ピンク","pinku","pink"},{"オレンジ","orenji","orange (color)"},
}
local family = {
 {"はは","haha","my mother (speaking to others)"},
 {"ちち","chichi","my father (speaking to others)"},
 {"あに","ani","my older brother (speaking to others)"},
 {"あね","ane","my older sister (speaking to others)"},
 {"おとうと","otouto","younger brother"},{"いもうと","imouto","younger sister"},
 {"そふ","sofu","my grandfather (speaking to others)"},
 {"そぼ","sobo","my grandmother (speaking to others)"},
 {"かぞく","kazoku","family"},{"きょうだい","kyoudai","siblings"},
}
local food = {
 {"みず","mizu","water"},{"おちゃ","ocha","tea"},{"ごはん","gohan","cooked rice / meal"},
 {"パン","pan","bread"},{"さかな","sakana","fish"},{"にく","niku","meat"},
 {"やさい","yasai","vegetables"},{"くだもの","kudamono","fruit"},
 {"りんご","ringo","apple"},{"たまご","tamago","egg"},
 {"ぎゅうにゅう","gyuunyuu","milk"},{"おにぎり","onigiri","rice ball"},
}
local phrases = {
 {"おなまえは","onamae wa","what is your name? (short polite form)"},
 {"わかりません","wakarimasen","I do not understand"},
 {"もういちどお願いします","mou ichido onegaishimasu","one more time, please"},
 {"ゆっくりお願いします","yukkuri onegaishimasu","slowly, please"},
 {"これはなんですか","kore wa nan desu ka","what is this?"},
 {"いくらですか","ikura desu ka","how much is it?"},
 {"だいじょうぶです","daijoubu desu","it is all right / I am all right"},
 {"どういたしまして","dou itashimashite","you are welcome"},
 {"いただきます","itadakimasu","said before eating (gratitude for the meal)"},
 {"ごちそうさまでした","gochisousama deshita","said after eating (thanks for the meal)"},
}
local sentences = {
 {"わたしはがくせいです","watashi wa gakusei desu","I am a student"},
 {"これはほんです","kore wa hon desu","this is a book"},
 {"それはみずです","sore wa mizu desu","that is water (near you)"},
 {"あれはやまです","are wa yama desu","that is a mountain (over there)"},
 {"わたしはせんせいです","watashi wa sensei desu","I am a teacher"},
 {"これはりんごです","kore wa ringo desu","this is an apple"},
 {"それはねこです","sore wa neko desu","that is a cat (near you)"},
 {"これはパンです","kore wa pan desu","this is bread"},
}

-- One taught reading per kanji, not all possible readings. A kanji's reading depends on the
-- word it is in; these are citation readings for beginners, not a kanji dictionary.
local kanji = {
 {"一","ichi","one"},{"二","ni","two"},{"三","san","three"},{"四","yon","four"},
 {"五","go","five"},{"六","roku","six"},{"七","nana","seven"},{"八","hachi","eight"},
 {"九","kyuu","nine"},{"十","juu","ten"},{"百","hyaku","hundred"},{"千","sen","thousand"},
 {"日","hi","sun / day"},{"月","tsuki","moon / month"},{"火","hi","fire"},
 {"水","mizu","water"},{"木","ki","tree / wood"},{"金","kane","money / metal"},
 {"土","tsuchi","soil / earth"},{"曜","you","weekday (as in youbi)"},
 {"年","toshi","year"},{"時","toki","time"},
 {"山","yama","mountain"},{"川","kawa","river"},{"田","ta","rice field"},
 {"石","ishi","stone"},{"雨","ame","rain"},{"空","sora","sky"},
 {"花","hana","flower"},{"草","kusa","grass"},{"森","mori","forest"},
 {"林","hayashi","grove"},{"海","umi","sea"},{"天","ten","heaven / sky"},
 {"人","hito","person"},{"口","kuchi","mouth"},{"目","me","eye"},
 {"耳","mimi","ear"},{"手","te","hand"},{"足","ashi","foot / leg"},
 {"子","ko","child"},{"女","onna","woman"},{"男","otoko","man"},
 {"父","chichi","father"},{"母","haha","mother"},
 {"大","dai","large (as in daigaku)"},{"小","shou","small (as in shougaku)"},
 {"中","naka","inside / middle"},{"上","ue","above / up"},{"下","shita","below / down"},
 {"左","hidari","left"},{"右","migi","right"},
 {"本","hon","book"},{"学","gaku","learning (as in gakusei)"},
 {"校","kou","school (as in gakkou)"},{"生","sei","life (as in gakusei)"},
 {"先","saki","ahead / previous"},{"名","na","name"},{"円","en","yen / circle"},{"白","shiro","white"},
}
D.kanji = kanji
local function slice(t, a, b)
  local out = {}; for i = a, b do out[#out + 1] = t[i] end; return out
end

-- Count numbers with the neutral/common readings yon / nana / kyuu (not shi / shichi / ku).
local digits = {"いち","に","さん","よん","ご","ろく","なな","はち","きゅう"}
local reads = {"ichi","ni","san","yon","go","roku","nana","hachi","kyuu"}
function D.Number(n)
  if n == 100 then return { "ひゃく", "hyaku", "100" } end
  local t, u = math.floor(n / 10), n % 10
  local native, reading = "", ""
  if t > 0 then
    native = (t == 1 and "" or digits[t]) .. "じゅう"
    reading = (t == 1 and "" or reads[t]) .. "juu"
  end
  if u > 0 then native = native .. digits[u]; reading = reading .. reads[u] end
  return { native, reading, tostring(n) }
end
local numbers = {}; for i = 1, 100 do numbers[i] = D.Number(i) end
D.numbers = numbers
local days = {
 {"にちようび","nichiyoubi","Sunday"},{"げつようび","getsuyoubi","Monday"},
 {"かようび","kayoubi","Tuesday"},{"すいようび","suiyoubi","Wednesday"},
 {"もくようび","mokuyoubi","Thursday"},{"きんようび","kinyoubi","Friday"},
 {"どようび","doyoubi","Saturday"},
}
local function join(a,b) local t={};for _,e in ipairs(a) do t[#t+1]=e end;for _,e in ipairs(b) do t[#t+1]=e end;return t end
D.courses.ja = {
  id = "ja", name = "Japanese / 日本語", title = "WORLD_JA", lessons = {
    { id="hira", band="initiate", title="Hiragana: 46 sounds", kind="kana", entries=hira },
    { id="hira_marks", band="initiate", title="Hiragana: sound marks", kind="kana", entries=voiced },
    { id="kata", band="initiate", title="Katakana: 46 sounds", kind="kana", entries=kata },
    { id="greetings", band="initiate", title="Greetings", kind="words", entries=greetings },
    { id="numbers", band="initiate", title="Numbers 1-100", kind="numbers", entries=numbers },
    { id="kata_marks", band="adept", title="Katakana: sound marks", kind="kana", entries=katavoiced },
    { id="colors", band="adept", title="Colors", kind="words", entries=colors },
    { id="family", band="adept", title="Family", kind="words", entries=family },
    { id="food", band="adept", title="Food and drink", kind="words", entries=food },
    { id="sentences", band="adept", title="X wa Y desu", kind="sentences", entries=sentences },
    { id="kanji_numbers", band="magister", title="Kanji: numbers", kind="kanji", entries=slice(kanji,1,12) },
    { id="kanji_time", band="magister", title="Kanji and weekdays", kind="kanji", entries=join(slice(kanji,13,22),days) },
    { id="kanji_nature", band="magister", title="Kanji: nature", kind="kanji", entries=slice(kanji,23,34) },
    { id="kanji_people", band="magister", title="Kanji: people and daily life", kind="kanji", entries=slice(kanji,35,60) },
    { id="phrases", band="magister", title="A trader's phrasebook", kind="words", entries=phrases },
  },
}
-- Duel of Wits co-op "phrasebook": two traders take turns. Lines alternate A, B, A, B ...
D.dialogues = {
  { -- meeting at the Gadgetzan gate
    {"こんにちは","konnichiwa","hello"},
    {"こんにちは。はじめまして","konnichiwa. hajimemashite","hello. Nice to meet you"},
    {"わたしはフィズウィックです","watashi wa Fizuwikku desu","I am Fizzwick"},
    {"どうぞよろしく","douzo yoroshiku","pleased to meet you"},
    {"これはなんですか","kore wa nan desu ka","what is this?"},
    {"それはりんごです","sore wa ringo desu","that is an apple"},
  },
  { -- at a market stall
    {"いらっしゃいませ","irasshaimase","welcome (to the shop)"},
    {"これはいくらですか","kore wa ikura desu ka","how much is this?"},
    {"ひゃくえんです","hyaku en desu","it is 100 yen"},
    {"これをください","kore o kudasai","this one, please"},
    {"ありがとうございます","arigatou gozaimasu","thank you very much"},
    {"さようなら","sayounara","goodbye"},
  },
  { -- dinner at the inn
    {"いただきます","itadakimasu","(said before eating)"},
    {"おいしいです","oishii desu","it is delicious"},
    {"おちゃはどうですか","ocha wa dou desu ka","how about some tea?"},
    {"はい、お願いします","hai, onegaishimasu","yes, please"},
    {"ごちそうさまでした","gochisousama deshita","thank you for the meal"},
    {"どういたしまして","dou itashimashite","you are welcome"},
  },
}

D.courses.es = { id="es", name="Spanish / Español", title="WORLD_ES", lessons={
 { id="greetings", band="initiate", title="Spanish greetings", kind="words", entries={
  {"hola","hola","hello"},{"adiós","adios","goodbye"},{"gracias","gracias","thank you"},
  {"por favor","por favor","please"},{"sí","si","yes"},{"no","no","no"},
  {"buenos días","buenos dias","good morning"},{"buenas noches","buenas noches","good evening / good night"},
 }},
 { id="colors", band="adept", title="Spanish colors", kind="words", entries={
  {"rojo","rojo","red"},{"azul","azul","blue"},{"verde","verde","green"},
  {"amarillo","amarillo","yellow"},{"blanco","blanco","white"},{"negro","negro","black"},
 }},
 { id="phrases", band="magister", title="Spanish travel phrases", kind="words", entries={
  {"¿Cómo estás?","como estas","how are you? (informal)"},{"Estoy bien","estoy bien","I am well"},
  {"No entiendo","no entiendo","I do not understand"},{"¿Cuánto cuesta?","cuanto cuesta","how much does it cost?"},
  {"Me llamo...","me llamo","my name is..."},{"Mucho gusto","mucho gusto","nice to meet you"},
 }},
}}

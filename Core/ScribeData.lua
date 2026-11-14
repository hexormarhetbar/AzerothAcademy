-- Scribe's Scrolls word data (English). Pure data, no logic.
-- Every list is validated by tests/harness.lua: unique ids/words, non-empty
-- definitions, misspellings that differ from the real word, sentences that
-- contain their word or blank, and plain ASCII typing lines.
-- "lv" is a difficulty level 1-5 (generators pick entries near the asked level).
local _, ns = ...

local D = {}
ns.ScribeData = D

------------------------------------------------------------------------
-- INITIATE (ages 5-7)
------------------------------------------------------------------------
-- Consonant-vowel-consonant words with a simple picture-free clue.
D.CVC = {
  { w = "cat", def = "a small furry pet that says meow" },
  { w = "dog", def = "a pet that barks and wags its tail" },
  { w = "pig", def = "a pink farm animal that says oink" },
  { w = "hat", def = "something you wear on your head" },
  { w = "map", def = "a drawing that shows where places are" },
  { w = "bag", def = "you carry things in it" },
  { w = "sun", def = "it shines in the sky in the daytime" },
  { w = "bug", def = "a tiny crawling creature" },
  { w = "cup", def = "you drink from it" },
  { w = "box", def = "a container with flat sides and corners" },
  { w = "fox", def = "a wild animal with a bushy red tail" },
  { w = "bed", def = "you sleep in it at night" },
  { w = "hen", def = "a mother chicken" },
  { w = "web", def = "a spider spins it to catch flies" },
  { w = "net", def = "you can catch fish with it" },
  { w = "pot", def = "you cook soup in it" },
  { w = "log", def = "a big round piece of a fallen tree" },
  { w = "fin", def = "a fish uses it to swim" },
  { w = "bat", def = "a flying animal that sleeps upside down" },
  { w = "mud", def = "wet, sticky dirt" },
  { w = "gem", def = "a shiny jewel" },
  { w = "rug", def = "a soft mat that covers the floor" },
  { w = "jam", def = "a sweet fruit spread for bread" },
  { w = "pen", def = "you write with it" },
  { w = "cub", def = "a baby bear" },
  { w = "tub", def = "you take a bath in it" },
}

-- Words for "first letter / last letter" questions. Only words whose first
-- letter is also the first sound (no silent letters like gnome or knight).
D.LETTER_WORDS = {
  "murloc", "dragon", "troll", "wolf", "bear", "kobold", "fish", "sword", "ring", "lion",
  "horse", "panda", "nest", "egg", "apple", "owl", "zebra", "volcano", "goblin", "boat",
  "tower", "lamp", "moon", "candle", "rabbit",
}

-- Sight words with curated misspellings and a lore sentence ("___" = the word).
D.SIGHT = {
  { w = "the", lv = 1, bad = { "teh", "hte" }, s = "Jaina looked at ___ big map." },
  { w = "and", lv = 1, bad = { "adn", "nad" }, s = "Thrall ___ Jaina are friends." },
  { w = "you", lv = 1, bad = { "yu", "yoo" }, s = "Can ___ see the gryphon?" },
  { w = "was", lv = 1, bad = { "wuz", "waz" }, s = "The dragon ___ very sleepy." },
  { w = "are", lv = 2, bad = { "ar", "arr" }, s = "The murlocs ___ singing by the lake." },
  { w = "said", lv = 2, bad = { "sed", "siad" }, s = "The innkeeper ___ hello to the heroes." },
  { w = "they", lv = 2, bad = { "thay", "tehy" }, s = "The gnomes said ___ would fix the robot." },
  { w = "have", lv = 2, bad = { "hav", "haev" }, s = "I ___ a pet wolf." },
  { w = "come", lv = 3, bad = { "kome", "comme" }, s = "Please ___ to Gadgetzan with me." },
  { w = "what", lv = 3, bad = { "wut", "whut" }, s = "Guess ___ is in the treasure chest!" },
  { w = "where", lv = 3, bad = { "whare", "wher" }, s = "Do you know ___ the kobold put the candle?" },
  { w = "of", lv = 1, bad = { "uv", "ov" }, s = "The goblin has a bag ___ gold coins." },
  { w = "were", lv = 3, bad = { "wer", "wur" }, s = "The trolls ___ dancing around the fire." },
  { w = "there", lv = 4, bad = { "thare", "ther" }, s = "Look over ___, a dragon!" },
  { w = "here", lv = 3, bad = { "heer", "heere" }, s = "Come ___, little murloc!" },
  { w = "some", lv = 3, bad = { "somm", "sume" }, s = "Can I have ___ bread?" },
  { w = "one", lv = 4, bad = { "wun", "onne" }, s = "I see ___ owl in the tree." },
  { w = "two", lv = 4, bad = { "tu", "twoo" }, s = "The ogre has ___ heads." },
  { w = "look", lv = 2, bad = { "luk", "lok" }, s = "Come and ___ at the shiny gem!" },
  { w = "little", lv = 5, bad = { "littel", "litle" }, s = "The ___ gnome fixed the gears." },
  { w = "friend", lv = 5, bad = { "frend", "freind" }, s = "The gryphon is my best ___." },
  { w = "because", lv = 5, bad = { "becuz", "becaus" }, s = "The murloc ran away ___ it was scared." },
}

-- Simple word meanings. "grp" marks words close enough in meaning that they
-- must never be offered as distractors for each other.
D.MEANINGS = {
  { w = "big", lv = 1, def = "very large", grp = "large" },
  { w = "tiny", lv = 2, def = "very, very small", grp = "small" },
  { w = "happy", lv = 1, def = "feeling glad", grp = "glad" },
  { w = "sad", lv = 1, def = "feeling unhappy", grp = "sad" },
  { w = "fast", lv = 1, def = "moving quickly", grp = "fast" },
  { w = "slow", lv = 2, def = "taking a long time to move", grp = "slow" },
  { w = "loud", lv = 2, def = "making a lot of noise", grp = "loud" },
  { w = "quiet", lv = 3, def = "making little or no noise", grp = "quiet" },
  { w = "hungry", lv = 2, def = "wanting to eat", grp = "hungry" },
  { w = "sleepy", lv = 2, def = "wanting to sleep", grp = "tired" },
  { w = "brave", lv = 3, def = "not afraid to do hard things", grp = "brave" },
  { w = "cold", lv = 1, def = "not warm at all", grp = "cold" },
  { w = "wet", lv = 1, def = "covered with water", grp = "wet" },
  { w = "soft", lv = 3, def = "not hard; nice to touch", grp = "soft" },
  { w = "tall", lv = 3, def = "high from bottom to top", grp = "large" },
  { w = "shiny", lv = 4, def = "bright and sparkly", grp = "shiny" },
  { w = "angry", lv = 4, def = "feeling mad", grp = "mad" },
  { w = "kind", lv = 4, def = "nice and caring to others", grp = "kind" },
  { w = "sticky", lv = 5, def = "able to stick to things, like honey", grp = "sticky" },
  { w = "empty", lv = 5, def = "with nothing inside", grp = "empty" },
  { w = "giggle", lv = 5, def = "to laugh in a silly way", grp = "laugh" },
}

-- Words to type, by level.
D.TYPE_WORDS = {
  [1] = { "cat", "dog", "sun", "hat", "map", "cup", "box", "pig" },
  [2] = { "orc", "elf", "owl", "axe", "gem", "imp", "cub", "fin" },
  [3] = { "wolf", "bear", "fish", "ship", "king", "boat", "lamp", "nest" },
  [4] = { "troll", "sword", "horse", "magic", "tower", "candy", "flame", "storm" },
  [5] = { "murloc", "dragon", "castle", "potion", "gryphon", "goblin", "forest", "shield" },
}

------------------------------------------------------------------------
-- ADEPT (ages 8-10)
------------------------------------------------------------------------
-- Spelling patterns.
D.SILENT_E = {
  { base = "cap", w = "cape", def = "a cloak that heroes wear" },
  { base = "hop", w = "hope", def = "to wish that something will happen" },
  { base = "kit", w = "kite", def = "a toy that flies in the wind on a string" },
  { base = "tub", w = "tube", def = "a long, hollow pipe" },
  { base = "pin", w = "pine", def = "a tall tree with needles instead of leaves" },
  { base = "rob", w = "robe", def = "a long, loose gown that mages wear" },
  { base = "not", w = "note", def = "a short written message" },
  { base = "can", w = "cane", def = "a stick that helps someone walk" },
  { base = "cub", w = "cube", def = "a shape with six square sides" },
  { base = "bit", w = "bite", def = "to cut into something with your teeth" },
  { base = "plan", w = "plane", def = "a flying machine with wings" },
  { base = "glob", w = "globe", def = "a round model of a world" },
}

-- Digraph words: "dg" is the digraph the blank hides, "wrong" are plausible swaps.
D.DIGRAPH = {
  { w = "ship", dg = "sh", wrong = { "chip", "sip", "schip" }, def = "a big boat that sails the sea" },
  { w = "shell", dg = "sh", wrong = { "chell", "sell", "schell" }, def = "the hard outside of a turtle or a snail" },
  { w = "fish", dg = "sh", wrong = { "fich", "fis", "fisch" }, def = "an animal that swims and breathes underwater" },
  { w = "chest", dg = "ch", wrong = { "shest", "cest", "tchest" }, def = "a big box for keeping treasure" },
  { w = "cheese", dg = "ch", wrong = { "sheese", "ceese", "tcheese" }, def = "a food made from milk; mice love it" },
  { w = "lunch", dg = "ch", wrong = { "lunsh", "lunc", "luntch" }, def = "the meal you eat in the middle of the day" },
  { w = "thorn", dg = "th", wrong = { "forn", "torn", "vorn" }, def = "a sharp point on a rose stem" },
  { w = "path", dg = "th", wrong = { "paf", "pat", "pav" }, def = "a trail you walk along" },
  { w = "whale", dg = "wh", wrong = { "wale", "hale", "wjale" }, def = "a huge animal that lives in the ocean" },
  { w = "wheel", dg = "wh", wrong = { "weel", "heel", "wjeel" }, def = "a round thing that turns so a cart can roll" },
  { w = "duck", dg = "ck", wrong = { "duk", "duc", "dukc" }, def = "a bird that swims and says quack" },
  { w = "clock", dg = "ck", wrong = { "clok", "cloc", "clokc" }, def = "it tells you the time" },
  { w = "brick", dg = "ck", wrong = { "brik", "bric", "brikc" }, def = "a hard block used to build walls" },
  { w = "moth", dg = "th", wrong = { "mof", "mot", "mov" }, def = "an insect like a butterfly that flies at night" },
}

-- Plurals. kind: s, es, ies, ves, irregular. "wrong" are common mistakes.
D.PLURALS = {
  { one = "murloc", w = "murlocs", kind = "s", wrong = { "murloces", "murloc's", "murlocz" } },
  { one = "sword", w = "swords", kind = "s", wrong = { "swordes", "sword's", "swordz" } },
  { one = "dragon", w = "dragons", kind = "s", wrong = { "dragones", "dragon's", "dragonz" } },
  { one = "box", w = "boxes", kind = "es", wrong = { "boxs", "boxxes", "box's" } },
  { one = "fox", w = "foxes", kind = "es", wrong = { "foxs", "foxxes", "foxen" } },
  { one = "torch", w = "torches", kind = "es", wrong = { "torchs", "torchis", "torch's" } },
  { one = "dish", w = "dishes", kind = "es", wrong = { "dishs", "dishis", "dish's" } },
  { one = "glass", w = "glasses", kind = "es", wrong = { "glasss", "glases", "glass's" } },
  { one = "berry", w = "berries", kind = "ies", wrong = { "berrys", "berryes", "berrise" } },
  { one = "pony", w = "ponies", kind = "ies", wrong = { "ponys", "ponyes", "ponise" } },
  { one = "puppy", w = "puppies", kind = "ies", wrong = { "puppys", "puppyes", "pupies" } },
  { one = "story", w = "stories", kind = "ies", wrong = { "storys", "storyes", "storise" } },
  { one = "city", w = "cities", kind = "ies", wrong = { "citys", "cityes", "citise" } },
  { one = "wolf", w = "wolves", kind = "ves", wrong = { "wolfs", "wolfes", "wolvs" } },
  { one = "elf", w = "elves", kind = "ves", wrong = { "elfs", "elfes", "elvs" } },
  { one = "leaf", w = "leaves", kind = "ves", wrong = { "leafs", "leafes", "leavs" } },
  { one = "loaf", w = "loaves", kind = "ves", wrong = { "loafs", "loafes", "loavs" } },
  { one = "shelf", w = "shelves", kind = "ves", wrong = { "shelfs", "shelfes", "shelvs" } },
  { one = "mouse", w = "mice", kind = "irregular", wrong = { "mouses", "mices", "meese" } },
  { one = "child", w = "children", kind = "irregular", wrong = { "childs", "childrens", "childes" } },
  { one = "foot", w = "feet", kind = "irregular", wrong = { "foots", "feets", "footes" } },
  { one = "tooth", w = "teeth", kind = "irregular", wrong = { "tooths", "teeths", "toothes" } },
  { one = "goose", w = "geese", kind = "irregular", wrong = { "gooses", "geeses", "goosen" } },
}

-- Vocabulary from context (lore sentences contain the word).
D.CONTEXT_A = {
  { w = "curious", lv = 1, def = "wanting to know or learn about something",
    s = "The curious gnome opened every box in the workshop to see what was inside." },
  { w = "enormous", grp = "large", lv = 1, def = "very, very big",
    s = "The enormous dragon's wings covered the whole sky over the valley." },
  { w = "ancient", lv = 2, def = "very, very old",
    s = "The night elves guard an ancient tree that has stood for thousands of years." },
  { w = "fierce", grp = "strong", lv = 2, def = "wild and strong in a scary way",
    s = "The fierce wolf growled and showed its sharp teeth." },
  { w = "gloomy", lv = 2, def = "dark and sad-feeling",
    s = "Duskwood is a gloomy forest where the sun hardly ever shines." },
  { w = "timid", grp = "fear", lv = 3, def = "shy and easily scared",
    s = "The timid murloc hid behind a rock when the heroes walked by." },
  { w = "loyal", lv = 3, def = "always staying true to a friend",
    s = "The loyal gryphon waited by the tower every day for its rider to return." },
  { w = "weary", lv = 3, def = "very tired",
    s = "After the long walk across the Barrens, the weary traveler sat down to rest." },
  { w = "glimmer", lv = 4, def = "a faint, flickering light",
    s = "A glimmer of candlelight shone from the end of the kobold's tunnel." },
  { w = "cautious", grp = "fear", lv = 4, def = "careful to stay away from danger",
    s = "The cautious adventurer tested the old rope bridge before crossing it." },
  { w = "generous", lv = 4, def = "happy to give and share",
    s = "The generous innkeeper gave the hungry children free bread and soup." },
  { w = "grumble", lv = 4, def = "to complain in a low, unhappy voice",
    s = "The dwarf began to grumble when the tavern ran out of cheese." },
  { w = "journey", lv = 3, def = "a long trip from one place to another",
    s = "Their journey on foot from Ratchet to Gadgetzan took many days." },
  { w = "victory", lv = 3, def = "the win in a battle or contest",
    s = "The crowd cheered when the champions won a great victory in the arena." },
  { w = "peculiar", lv = 5, def = "strange or unusual",
    s = "The goblin built a peculiar machine that hopped around like a frog." },
  { w = "swift", grp = "fast", lv = 5, def = "very fast",
    s = "The swift hippogryph flew across the sea in a single night." },
  { w = "nimble", grp = "fast", lv = 5, def = "quick and light in moving",
    s = "The nimble rogue climbed the castle wall without making a sound." },
}

-- Synonyms / antonyms. "g" = meaning cluster; distractors never share the
-- cluster of the prompt word or of the answer.
D.WORD_CLUSTER = {
  big = "large", huge = "large", enormous = "large", small = "small", little = "small", tiny = "small",
  happy = "glad", glad = "glad", angry = "mad", mad = "mad", fast = "fast", quick = "fast",
  swift = "fast", slow = "slow", begin = "start", start = "start", finish = "end", ["end"] = "end",
  shout = "yell", yell = "yell", smart = "clever", clever = "clever", scared = "afraid",
  afraid = "afraid", cowardly = "afraid", brave = "brave", bold = "brave", pretty = "pretty",
  beautiful = "pretty", rich = "rich", wealthy = "rich", jump = "leap", leap = "leap",
  sleepy = "tired", tired = "tired", gift = "gift", present = "gift", simple = "easy", easy = "easy",
  hot = "hot", cold = "cold", up = "up", down = "down", open = "open", closed = "shut", shut = "shut",
  light = "light", dark = "dark", full = "full", empty = "empty", early = "early", late = "late",
  win = "win", lose = "lose", friend = "friend", enemy = "enemy", strong = "strong", weak = "weak",
  noisy = "loud", quiet = "quiet", wide = "wide", narrow = "narrow", rough = "rough", smooth = "smooth",
  give = "give", take = "take", push = "push", pull = "pull", float = "float", sink = "sink",
  remember = "remember", forget = "forget", ["true"] = "true", ["false"] = "false",
}
D.SYNONYMS = {
  { a = "big", b = "huge", lv = 1 }, { a = "small", b = "little", lv = 1 }, { a = "happy", b = "glad", lv = 1 },
  { a = "angry", b = "mad", lv = 1 }, { a = "fast", b = "quick", lv = 2 }, { a = "begin", b = "start", lv = 2 },
  { a = "shout", b = "yell", lv = 2 }, { a = "smart", b = "clever", lv = 3 }, { a = "scared", b = "afraid", lv = 2 },
  { a = "finish", b = "end", lv = 3 }, { a = "brave", b = "bold", lv = 4 }, { a = "pretty", b = "beautiful", lv = 3 },
  { a = "rich", b = "wealthy", lv = 5 }, { a = "jump", b = "leap", lv = 4 }, { a = "sleepy", b = "tired", lv = 2 },
  { a = "gift", b = "present", lv = 4 }, { a = "simple", b = "easy", lv = 5 }, { a = "enormous", b = "huge", lv = 5 },
  { a = "tiny", b = "little", lv = 3 }, { a = "swift", b = "fast", lv = 5 },
}
D.ANTONYMS = {
  { a = "hot", b = "cold", lv = 1 }, { a = "up", b = "down", lv = 1 }, { a = "open", b = "closed", lv = 1 },
  { a = "light", b = "dark", lv = 2 }, { a = "full", b = "empty", lv = 2 }, { a = "early", b = "late", lv = 2 },
  { a = "win", b = "lose", lv = 2 }, { a = "friend", b = "enemy", lv = 3 }, { a = "strong", b = "weak", lv = 3 },
  { a = "noisy", b = "quiet", lv = 3 }, { a = "wide", b = "narrow", lv = 4 }, { a = "rough", b = "smooth", lv = 4 },
  { a = "give", b = "take", lv = 3 }, { a = "push", b = "pull", lv = 3 }, { a = "float", b = "sink", lv = 4 },
  { a = "remember", b = "forget", lv = 5 }, { a = "true", b = "false", lv = 4 }, { a = "brave", b = "cowardly", lv = 5 },
}

-- Spelling words (Adept). "bad" = common misspellings.
D.SPELL_A = {
  { w = "friend", lv = 1, def = "a person you like and trust", bad = { "frend", "freind" } },
  { w = "dragon", lv = 1, def = "a huge flying lizard that can breathe fire", bad = { "dragun", "dragen" } },
  { w = "potion", lv = 1, def = "a magic drink", bad = { "poshun", "potian" } },
  { w = "wizard", lv = 2, def = "a person who uses magic", bad = { "wizzard", "wizerd" } },
  { w = "castle", lv = 2, def = "a big stone building with towers where a king may live", bad = { "castel", "cassle" } },
  { w = "shield", lv = 2, def = "armor you hold up to block attacks", bad = { "sheild", "sheeld" } },
  { w = "guard", lv = 2, def = "a person whose job is to protect a place", bad = { "gaurd", "gard" } },
  { w = "people", lv = 3, def = "men, women and children", bad = { "peeple", "poeple" } },
  { w = "knight", lv = 3, def = "a soldier in armor who serves a king or queen", bad = { "nite", "knite" } },
  { w = "island", lv = 3, def = "land with water all around it", bad = { "iland", "ilend" } },
  { w = "answer", lv = 3, def = "a reply to a question", bad = { "anser", "awnser" } },
  { w = "because", lv = 3, def = "for the reason that", bad = { "becuase", "becos" } },
  { w = "treasure", lv = 4, def = "gold, jewels and other riches", bad = { "tresure", "treasur" } },
  { w = "weather", lv = 4, def = "rain, sun, wind or snow outside", bad = { "wether", "wheather" } },
  { w = "believe", lv = 4, def = "to think that something is true", bad = { "beleive", "belive" } },
  { w = "library", lv = 4, def = "a place full of books to read or borrow", bad = { "libary", "liberry" } },
  { w = "mountain", lv = 4, def = "a very high, steep hill", bad = { "mountin", "mountian" } },
  { w = "journey", lv = 5, def = "a long trip", bad = { "jurney", "journy" } },
  { w = "beautiful", lv = 5, def = "very pretty", bad = { "beutiful", "beautifull" } },
  { w = "different", lv = 5, def = "not the same", bad = { "diffrent", "diferent" } },
}

-- Short phrases to type (Adept).
D.TYPE_PHRASES = {
  [1] = { "For the Alliance!", "For the Horde!", "Light the forge.", "Feed the wolf.", "Hello, friend!" },
  [2] = { "Gnomes love gears.", "The gryphon flies fast.", "Murlocs say mrrgl.", "Open the treasure chest." },
  [3] = { "Stay away from the murlocs!", "The tauren waved hello.", "Ironforge is inside a mountain." },
  [4] = { "The goblin sold me a shiny rocket.", "Pandas love to eat bamboo and dumplings." },
  [5] = { "The dwarf hammered the hot iron on the anvil.", "A baby dragon slept on a pile of gold coins." },
}

------------------------------------------------------------------------
-- MAGISTER (ages 11-13)
------------------------------------------------------------------------
-- Prefixes / suffixes / roots: meaning questions ("m" must be unique within a list).
D.PREFIXES = {
  { p = "un-", ex = "unhappy", m = "not" },
  { p = "re-", ex = "rebuild", m = "again" },
  { p = "pre-", ex = "preview", m = "before" },
  { p = "mis-", ex = "misspell", m = "wrongly" },
  { p = "sub-", ex = "submarine", m = "under or below" },
  { p = "inter-", ex = "international", m = "between" },
  { p = "trans-", ex = "transport", m = "across" },
  { p = "anti-", ex = "antifreeze", m = "against" },
  { p = "over-", ex = "overcharge", m = "too much" },
  { p = "bi-", ex = "bicycle", m = "two" },
  { p = "tri-", ex = "triangle", m = "three" },
}
D.SUFFIXES = {
  { p = "-less", ex = "fearless", m = "without" },
  { p = "-ful", ex = "careful", m = "full of" },
  { p = "-able", ex = "breakable", m = "able to be" },
  { p = "-ness", ex = "kindness", m = "the state of being" },
  { p = "-er", ex = "teacher", m = "a person who does something" },
  { p = "-ology", ex = "geology", m = "the study of" },
}
D.ROOTS = {
  { p = "port", ex = "portal, transport", m = "carry" },
  { p = "scrib / script", ex = "scribe, describe", m = "write" },
  { p = "dict", ex = "predict, dictionary", m = "say or speak" },
  { p = "vis / vid", ex = "vision, invisible", m = "see" },
  { p = "aqua", ex = "aquarium", m = "water" },
  { p = "geo", ex = "geology, geography", m = "earth" },
  { p = "bio", ex = "biology", m = "life" },
  { p = "tele", ex = "telescope", m = "far away" },
  { p = "phon", ex = "telephone, phonics", m = "sound" },
  { p = "chron", ex = "chronicle", m = "time" },
  { p = "struct", ex = "construct, structure", m = "build" },
}
-- Build a word from a base + affix. lv 5 entries change spelling (y -> i).
D.AFFIX_BUILD = {
  { base = "visible", w = "invisible", how = "prefix", def = "not able to be seen", lv = 3, bad = { "unvisible", "invisable" } },
  { base = "fear", w = "fearless", how = "suffix", def = "without fear", lv = 3, bad = { "fearles", "fearlest" } },
  { base = "care", w = "careful", how = "suffix", def = "full of care", lv = 3, bad = { "carefull", "carful" } },
  { base = "build", w = "rebuild", how = "prefix", def = "to build again", lv = 3, bad = { "unbuild", "rebild" } },
  { base = "agree", w = "disagree", how = "prefix", def = "to not agree", lv = 3, bad = { "unagree", "disagre" } },
  { base = "honest", w = "dishonest", how = "prefix", def = "not honest", lv = 4, bad = { "unhonest", "dishonnest" } },
  { base = "possible", w = "impossible", how = "prefix", def = "not possible", lv = 4, bad = { "unpossible", "impossable" } },
  { base = "view", w = "preview", how = "prefix", def = "to see something before others do", lv = 4, bad = { "priview", "preveiw" } },
  { base = "spell", w = "misspell", how = "prefix", def = "to spell wrongly", lv = 4, bad = { "mispell", "misspel" } },
  { base = "break", w = "breakable", how = "suffix", def = "able to be broken", lv = 4, bad = { "breakible", "brakeable" } },
  { base = "use", w = "useless", how = "suffix", def = "without use; not helpful", lv = 3, bad = { "useles", "usless" } },
  { base = "kind", w = "kindness", how = "suffix", def = "the state of being kind", lv = 3, bad = { "kindnes", "kindniss" } },
  { base = "happy", w = "happiness", how = "suffix", def = "the state of being happy", lv = 5, bad = { "happyness", "happines" } },
  { base = "beauty", w = "beautiful", how = "suffix", def = "full of beauty", lv = 5, bad = { "beautyful", "beautifull" } },
  { base = "pity", w = "pitiful", how = "suffix", def = "full of pity; sad to see", lv = 5, bad = { "pityful", "pitifull" } },
}

-- Commonly confused words: "___" is the blank, a = right answer, c = choices.
D.CONFUSED = {
  { s = "The night elves rode ___ nightsabers through the forest.", a = "their", c = { "their", "there", "they're" },
    why = "Their means belonging to them." },
  { s = "Put the shield over ___, next to the anvil.", a = "there", c = { "their", "there", "they're" },
    why = "There means in that place." },
  { s = "___ going to the Darkmoon Faire tonight!", a = "They're", c = { "Their", "There", "They're" },
    why = "They're is short for they are." },
  { s = "Is this ___ mount?", a = "your", c = { "your", "you're" }, why = "Your means belonging to you." },
  { s = "___ the bravest adventurer in Goldshire.", a = "You're", c = { "Your", "You're" },
    why = "You're is short for you are." },
  { s = "The dragon flapped ___ huge wings.", a = "its", c = { "its", "it's" },
    why = "Its means belonging to it. It's always means it is or it has." },
  { s = "___ raining in Stranglethorn again.", a = "It's", c = { "Its", "It's" }, why = "It's is short for it is." },
  { s = "The gnome carries ___ wrenches in her belt.", a = "two", c = { "to", "too", "two" },
    why = "Two is the number 2." },
  { s = "This armor is ___ heavy to lift.", a = "too", c = { "to", "too", "two" },
    why = "Too means more than enough (or also)." },
  { s = "We are flying ___ Orgrimmar tomorrow.", a = "to", c = { "to", "too", "two" },
    why = "To shows direction: going to a place." },
  { s = "A dragon is bigger ___ a murloc.", a = "than", c = { "then", "than" },
    why = "Than is used to compare two things." },
  { s = "First feed your pet, ___ train your skills.", a = "then", c = { "then", "than" },
    why = "Then tells what happens next." },
  { s = "Don't ___ your hearthstone!", a = "lose", c = { "lose", "loose" },
    why = "Lose means to misplace something. Loose means not tight." },
  { s = "The ogre's tooth was ___ and wobbly.", a = "loose", c = { "lose", "loose" },
    why = "Loose means not tight or not firmly attached." },
  { s = "Everyone came to the feast ___ the grumpy troll.", a = "except", c = { "accept", "except" },
    why = "Except means but not; leaving out." },
  { s = "Will you ___ this quest, hero?", a = "accept", c = { "accept", "except" },
    why = "Accept means to say yes to or receive." },
  { s = "The potion had a strange ___ on the gnome: he turned green!", a = "effect", c = { "affect", "effect" },
    why = "Effect is a noun: the result of something." },
  { s = "Cold weather can ___ how well the crops in Westfall grow.", a = "affect", c = { "affect", "effect" },
    why = "Affect is a verb: to change or influence something." },
  { s = "___ helmet is this?", a = "Whose", c = { "Whose", "Who's" }, why = "Whose asks who something belongs to." },
  { s = "___ ready for the dungeon?", a = "Who's", c = { "Whose", "Who's" }, why = "Who's is short for who is." },
  { s = "The ___ in Winterspring is almost always snowy.", a = "weather", c = { "weather", "whether" },
    why = "Weather is rain, snow, sun and wind." },
  { s = "Decide ___ you want to fly or ride.", a = "whether", c = { "weather", "whether" },
    why = "Whether introduces a choice between options." },
  { s = "Be ___ so the dragon stays asleep.", a = "quiet", c = { "quiet", "quite" },
    why = "Quiet means making little noise. Quite means very or completely." },
  { s = "The climb up the mountain was ___ long.", a = "quite", c = { "quiet", "quite" },
    why = "Quite means very or fairly." },
  { s = "Take a deep ___ before you dive into the lake.", a = "breath", c = { "breath", "breathe" },
    why = "Breath (no e) is the noun: the air you take in." },
  { s = "Murlocs can ___ underwater.", a = "breathe", c = { "breath", "breathe" },
    why = "Breathe (with e) is the verb: to take air in and out." },
}

-- Advanced vocabulary in lore passages.
D.CONTEXT_M = {
  { w = "resilient", grp = "persist", lv = 3, def = "able to recover quickly from hard times",
    s = "Even after they lost their city, the resilient gnomes built a new home and kept inventing." },
  { w = "benevolent", lv = 4, def = "kind and wanting to help others",
    s = "The benevolent druid healed every injured animal she found in the forest." },
  { w = "ominous", lv = 3, def = "giving a feeling that something bad will happen",
    s = "Dark clouds gathered over Karazhan, and an ominous silence filled the air." },
  { w = "formidable", grp = "strong", lv = 4, def = "very strong and hard to defeat",
    s = "The formidable ogre lord was twice the size of any warrior in the camp." },
  { w = "meticulous", grp = "careful", lv = 5, def = "very careful about every small detail",
    s = "The meticulous scribe checked every letter of the scroll three times." },
  { w = "reluctant", lv = 2, def = "not wanting to do something",
    s = "The reluctant apprentice walked slowly to his first lesson, wishing he could stay in bed." },
  { w = "vigilant", lv = 3, def = "watchful and alert for danger",
    s = "The vigilant guards on the walls of Stormwind watched the road all night." },
  { w = "tranquil", lv = 2, def = "calm and peaceful",
    s = "The tranquil pools of the Jade Forest reflected the misty mountains." },
  { w = "treacherous", lv = 4, def = "dangerous, with hidden risks",
    s = "The treacherous mountain path was covered in loose rocks and ice." },
  { w = "ingenious", grp = "clever", lv = 4, def = "very clever and inventive",
    s = "The goblin's ingenious rocket boots let her leap right over the canyon." },
  { w = "diligent", grp = "careful", lv = 3, def = "hard-working and careful",
    s = "The diligent blacksmith worked at her anvil from sunrise to sunset." },
  { w = "desolate", lv = 2, def = "empty, lonely and lifeless",
    s = "Nothing grew in the desolate wasteland of the Blasted Lands." },
  { w = "jubilant", lv = 5, def = "full of great joy",
    s = "The jubilant crowd in Orgrimmar cheered as the heroes returned home." },
  { w = "cunning", grp = "clever", lv = 1, def = "clever at tricking others",
    s = "The cunning goblin sold the same treasure map to three different explorers." },
  { w = "colossal", grp = "large", lv = 1, def = "extremely large",
    s = "A colossal titan statue towered over the ancient city of Ulduar." },
  { w = "persevere", grp = "persist", lv = 5, def = "to keep trying even when it is hard",
    s = "The young paladin failed her test twice but chose to persevere until she passed." },
}

-- Spelling words (Magister).
D.SPELL_M = {
  { w = "necessary", lv = 2, def = "needed; something that must be done", bad = { "neccessary", "necesary" } },
  { w = "separate", lv = 1, def = "to split apart", bad = { "seperate", "separete" } },
  { w = "definitely", lv = 2, def = "for sure; without any doubt", bad = { "definately", "definitly" } },
  { w = "rhythm", lv = 3, def = "a steady pattern of beats in music", bad = { "rythm", "rhythem" } },
  { w = "conscience", lv = 5, def = "the inner sense of right and wrong", bad = { "conscence", "consience" } },
  { w = "occasion", lv = 3, def = "a special event or time", bad = { "ocassion", "occassion" } },
  { w = "embarrass", lv = 4, def = "to make someone feel awkward or ashamed", bad = { "embarass", "embarras" } },
  { w = "privilege", lv = 4, def = "a special right or advantage", bad = { "priviledge", "privilage" } },
  { w = "environment", lv = 3, def = "the natural world around us", bad = { "enviroment", "envirnment" } },
  { w = "government", lv = 2, def = "the group of people that runs a country", bad = { "goverment", "govermint" } },
  { w = "calendar", lv = 1, def = "a chart that shows the days and months", bad = { "calender", "calandar" } },
  { w = "accommodate", lv = 5, def = "to have room for; to give someone a place to stay", bad = { "accomodate", "acommodate" } },
  { w = "recommend", lv = 3, def = "to suggest something as good", bad = { "reccomend", "recomend" } },
  { w = "guarantee", lv = 4, def = "a promise that something will happen", bad = { "garantee", "guarentee" } },
  { w = "mischievous", lv = 5, def = "playfully naughty", bad = { "mischievious", "mischevous" } },
  { w = "knowledge", lv = 1, def = "facts and understanding you have learned", bad = { "knowlege", "knoledge" } },
}

-- Sentences to type (Magister).
D.TYPE_SENTENCES = {
  [1] = { "Murlocs gather near lakes and rivers.", "The gnome tightened every bolt." },
  [2] = { "Stormwind has tall white walls and blue roofs.", "The Darkmoon Faire visits a new place each month." },
  [3] = { "The night elves watch over the ancient forests of Ashenvale.",
    "Gnomish engineers built a tram that runs under the sea." },
  [4] = { "Thrall led the orcs across the sea to a new land called Kalimdor.",
    "A careful scribe checks every word before the ink dries." },
  [5] = { "The gryphon rider soared above the snowy peaks of Dun Morogh, scanning the valleys below.",
    "Brave adventurers from every corner of Azeroth gathered to defend the city." },
}

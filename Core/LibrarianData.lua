-- Librarian Quests curated questions + generator data (v0.12). Original writing.
-- Head Librarian Tamsin Quillfeather (original, neutral) runs the library of the Knowledge
-- Exchange in Gadgetzan and sends researchers to libraries of every faction. Pure data.
-- Entry: { lv = 1..3, q, a, d = { wrong answers }, why, t = { typed spellings } (optional) }
local _, ns = ...
local D = {}
ns.LibrarianData = D

-- Book topics used by the shelf, ABC, contents and index generators (kid-friendly, neutral)
D.TOPICS = { "Bats", "Bears", "Clouds", "Dragons", "Eagles", "Frogs", "Gryphons", "Herbs", "Islands",
  "Kodos", "Lanterns", "Maps", "Mushrooms", "Murlocs", "Owls", "Potions", "Raptors", "Rivers", "Stars",
  "Turtles", "Volcanoes", "Wisps", "Wolves", "Yetis" }
-- animals for keyword questions (plural)
D.ANIMALS = { "owls", "kodos", "murlocs", "raptors", "turtles", "wolves", "bats", "frogs", "gryphons", "yetis", "bears", "eagles" }
-- keyword templates: question, best keywords, worse keyword choices (%s = animal)
D.KEYWORD_TEMPLATES = {
  { q = "What do %s eat?", a = "%s food", d = { "what do", "eat what", "%s colors" } },
  { q = "Where do %s live?", a = "%s habitat", d = { "where do", "live where", "%s food" } },
  { q = "How big do %s grow?", a = "%s size", d = { "how big", "grow do", "%s habitat" } },
  { q = "How long do %s live?", a = "%s lifespan", d = { "how long", "do live", "%s size" } },
  { q = "How do baby %s grow up?", a = "%s life cycle", d = { "how do", "baby grow up", "%s food" } },
}

-- made-up books for citing (titles, authors and years are invented for the Academy library)
D.BOOKS = {
  { title = "Rivers of Kalimdor", first = "Mira", last = "Stonebrook", year = 2019 },
  { title = "A Guide to Gnome Gadgets", first = "Pell", last = "Copperfield", year = 2016 },
  { title = "Night Owls of the Forest", first = "Juno", last = "Ashgrove", year = 2021 },
  { title = "The Kodo Herds", first = "Tibbs", last = "Wrenwhistle", year = 2014 },
  { title = "Murloc Songs and Sounds", first = "Orla", last = "Brightwater", year = 2018 },
  { title = "Maps for Young Explorers", first = "Dax", last = "Hollowmere", year = 2020 },
  { title = "Mushrooms of the Marsh", first = "Nim", last = "Saltreed", year = 2015 },
  { title = "Stars over the Desert", first = "Bree", last = "Kettlewick", year = 2022 },
  { title = "Turtles of the Shore", first = "Hal", last = "Mossberry", year = 2017 },
  { title = "How Potions Work", first = "Ivy", last = "Cindervale", year = 2023 },
}

-- two-source comparisons: same event told by a careful source (A) and a weaker one (B).
-- %d slots: A count, B count. agree = what both say; differ = what they disagree on.
D.COMPARE = {
  { thing = "wolves", a = "Ranger's logbook, written the same evening: \"We counted %d wolves by the river at dawn.\"",
    b = "A traveler's tale, told a year later: \"There must have been %d wolves by the river that night!\"",
    agree = "Wolves were seen by the river", differ = "How many wolves, and what time it was",
    reliable = "The logbook: written the same day by someone who counted" },
  { thing = "ships", a = "Harbor record, written by the dockmaster that day: \"%d ships arrived in the morning.\"",
    b = "A sailor's song from much later: \"%d ships sailed in beneath the moon!\"",
    agree = "Ships arrived at the harbor", differ = "How many ships, and the time of day",
    reliable = "The harbor record: written that day by the dockmaster" },
  { thing = "eggs", a = "Naturalist's notebook, with a sketch: \"The nest held %d eggs on the first day of spring.\"",
    b = "A rumor in the tavern: \"I heard that nest has %d eggs, maybe in summer.\"",
    agree = "There was a nest with eggs", differ = "How many eggs, and the season",
    reliable = "The notebook: someone saw the nest and wrote it down" },
  { thing = "lanterns", a = "Festival list, kept by the organizer: \"We lit %d lanterns at sunset.\"",
    b = "A child's postcard home: \"I think there were %d lanterns, after midnight!\"",
    agree = "Lanterns were lit at the festival", differ = "How many lanterns, and when",
    reliable = "The festival list: kept by the person in charge" },
  { thing = "kodos", a = "Herder's tally sheet, filled in at the watering hole: \"%d kodos drank at noon.\"",
    b = "A merchant passing by, months later: \"Oh, about %d kodos, in the evening.\"",
    agree = "Kodos came to the watering hole", differ = "How many kodos, and the time",
    reliable = "The tally sheet: counted on the spot" },
}

-- data tables (title, row label, unit, rows)
D.TABLES = {
  { title = "Herbs picked this week", col = "Herbs", rows = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" } },
  { title = "Books borrowed by class", col = "Books", rows = { "Owl class", "Fox class", "Bear class", "Hawk class" } },
  { title = "Fish caught at the pier", col = "Fish", rows = { "Ratchet", "Booty Bay", "Gadgetzan", "Everlook" } },
  { title = "Stars counted each night", col = "Stars", rows = { "Night 1", "Night 2", "Night 3", "Night 4", "Night 5" } },
  { title = "Gears sorted by helpers", col = "Gears", rows = { "Nixa", "Boltby", "Quill", "Bramble" } },
}

-- INITIATE: true or silly (simple real-world facts) ---------------------------
D.TRUESILLY = {
  { lv = 1, q = "Which sentence about fish is TRUE?", a = "Fish live in water", d = { "Fish fly to the moon", "Fish wear hats to school" }, why = "Real fish live in water. The others are silly." },
  { lv = 1, q = "Which sentence about snow is TRUE?", a = "Snow is cold", d = { "Snow is hot like soup", "Snow is made of cheese" }, why = "Snow is frozen water, so it is cold." },
  { lv = 1, q = "Which sentence about cats is SILLY?", a = "Cats can drive wagons", d = { "Cats have whiskers", "Cats can purr" }, why = "Cats have whiskers and purr, but they cannot drive!" },
  { lv = 1, q = "Which sentence about birds is TRUE?", a = "Birds have feathers", d = { "Birds have wheels", "Birds are made of stone" }, why = "All birds have feathers." },
  { lv = 1, q = "Which sentence about the sun is SILLY?", a = "The sun comes out at midnight", d = { "The sun is bright", "The sun gives us light" }, why = "Midnight is in the night, when the sun is down." },
  { lv = 1, q = "Which sentence about plants is TRUE?", a = "Plants need water to grow", d = { "Plants grow best in a dark box with no water", "Plants eat candy" }, why = "Plants need water, light and air." },
  { lv = 2, q = "Which one could you check in a book about animals?", a = "How many legs a spider has", d = { "What your friend ate today", "Your favorite color" }, why = "Books hold facts that are the same for everyone, like a spider's 8 legs." },
  { lv = 2, q = "Which sentence about turtles is SILLY?", a = "Turtles run faster than horses", d = { "Turtles have shells", "Some turtles swim in the sea" }, why = "Turtles are slow on land. Horses are much faster." },
  { lv = 2, q = "Which sentence about ice is TRUE?", a = "Ice melts when it gets warm", d = { "Ice gets colder in the sun", "Ice turns into sand" }, why = "Warmth melts ice into water." },
  { lv = 2, q = "Where can you find out if a sentence is true?", a = "A good book or a teacher", d = { "A guess", "A silly song" }, why = "Check facts in a trusted book or with someone who knows." },
  { lv = 3, q = "Which sentence about the moon is TRUE?", a = "The moon goes around the earth", d = { "The moon is a big lamp on a string", "The moon is made of cheese" }, why = "The moon travels around our planet." },
  { lv = 3, q = "A story says a dragon talks. Is that true in our real world?", a = "No, it is make-believe", d = { "Yes, dragons talk at the zoo", "Yes, every book is true" }, why = "Stories can be make-believe. Fact books tell what is real." },
  { lv = 3, q = "Which book would tell you TRUE facts about bears?", a = "A fact book about bears", d = { "A fairy tale with a talking bear", "A joke book" }, why = "Fact books (nonfiction) are written to tell what is true." },
  { lv = 3, q = "Books with true facts are called...", a = "Nonfiction", d = { "Make-believe", "Comics" }, why = "Nonfiction books are about real things. Fiction is made up." },
}

-- INITIATE: keywords (also generated) -----------------------------------------
D.KEYWORDS_YOUNG = {
  { lv = 1, q = "You want to learn about frogs. Which word do you look for on the shelf?", a = "Frogs", d = { "Want", "Learn" }, why = "The topic word, frogs, is the key word." },
  { lv = 1, q = "You want a book about the stars. Which word matters most?", a = "Stars", d = { "Book", "About" }, why = "Stars is what the book should be about." },
  { lv = 2, q = "Which question is about volcanoes?", a = "Why do volcanoes erupt?", d = { "Why do frogs jump?", "Where do owls sleep?" }, why = "Look for the key word: volcanoes." },
  { lv = 2, q = "\"How tall do giraffes grow?\" What is the key word?", a = "Giraffes", d = { "How", "Do" }, why = "Small words like how and do don't tell the topic." },
  { lv = 3, q = "\"What do baby owls eat?\" Which TWO words are the most important?", a = "Owls, eat", d = { "What, do", "Baby, what" }, why = "Owls (the topic) and eat (what you want to know)." },
  { lv = 3, q = "A key word is...", a = "The most important word for your question", d = { "The longest word", "The first word" }, why = "Key words point to what you want to find." },
}

-- ADEPT: fact or opinion -------------------------------------------------------
D.FACTOPINION = {
  { lv = 1, q = "\"Gadgetzan is in a desert.\" Fact or opinion?", a = "Fact", d = { "Opinion", "A question", "A rhyme" }, why = "You can check it on a map. That makes it a fact.", t = { "fact" } },
  { lv = 1, q = "\"Owls are the coolest birds.\" Fact or opinion?", a = "Opinion", d = { "Fact", "A question", "A list" }, why = "'Coolest' is a feeling. Someone else may disagree.", t = { "opinion" } },
  { lv = 1, q = "\"Spiders have eight legs.\" Fact or opinion?", a = "Fact", d = { "Opinion", "A guess", "A joke" }, why = "You can count them. It is true for every spider.", t = { "fact" } },
  { lv = 1, q = "\"Pumpkin pie is the best dessert.\" Fact or opinion?", a = "Opinion", d = { "Fact", "A rule", "A question" }, why = "'Best' depends on who you ask.", t = { "opinion" } },
  { lv = 2, q = "Which sentence is an OPINION?", a = "Murlocs sing the most beautiful songs", d = { "Murlocs live near water", "Murlocs make gurgling sounds", "Murlocs can swim" }, why = "'Most beautiful' is a feeling, not something you can prove." },
  { lv = 2, q = "Which sentence is a FACT?", a = "Water freezes when it is very cold", d = { "Winter is the nicest season", "Snowmen are fun to build", "Cold days are boring" }, why = "Freezing can be tested. The others are feelings." },
  { lv = 2, q = "Which word often signals an opinion?", a = "Best", d = { "Seven", "Under", "Blue" }, why = "Words like best, worst, prettiest and boring show feelings." },
  { lv = 2, q = "\"I think kodos are adorable.\" Why is this an opinion?", a = "It tells a feeling", d = { "It has a number", "It can be measured", "It is very short" }, why = "'I think' and 'adorable' show a personal feeling." },
  { lv = 3, q = "\"The bridge is 40 steps long and it is the scariest bridge ever.\" What is this?", a = "A fact and an opinion", d = { "Only a fact", "Only an opinion", "A question" }, why = "40 steps can be counted (fact); scariest is a feeling (opinion)." },
  { lv = 3, q = "How can you check if a sentence is a fact?", a = "Look it up or test it", d = { "Ask if people like it", "See if it is long", "Check if it rhymes" }, why = "Facts can be proven by checking sources or testing." },
  { lv = 3, q = "A guidebook says: \"This is the most beautiful lake in Azeroth.\" Fact or opinion?", a = "Opinion", d = { "Fact", "A measurement", "A date" }, why = "Even in a book, 'most beautiful' is someone's opinion.", t = { "opinion" } },
  { lv = 3, q = "Which sentence mixes in an opinion?", a = "The tower is 12 floors tall and looks silly", d = { "The tower is 12 floors tall", "The tower was built of stone", "The tower has a bell" }, why = "'Looks silly' is a feeling added to the facts." },
}

-- ADEPT: note-taking -------------------------------------------------------------
D.NOTES = {
  { lv = 1, q = "Text: \"Kodos are huge, gentle animals that walk in herds across the plains.\" Best short note?", a = "Kodos: huge, gentle, herds", d = { "Kodos are huge, gentle animals that walk", "Walk across", "Plains are big" }, why = "Good notes keep only the key words." },
  { lv = 1, q = "Text: \"Owls hunt at night and sleep during the day.\" Best short note?", a = "Owls: hunt night, sleep day", d = { "Owls hunt at night and sleep during", "Day and night", "Sleep is good" }, why = "Short notes: topic plus key facts." },
  { lv = 1, q = "Why do we take short notes instead of copying everything?", a = "To keep just the important ideas", d = { "To make our hand tired", "To use more paper", "Because copying is faster" }, why = "Notes help you remember the main points quickly." },
  { lv = 2, q = "Text: \"Turtles lay their eggs in warm sand. The baby turtles hatch and crawl to the sea.\" Best note?", a = "Turtles: eggs in sand, babies crawl to sea", d = { "Turtles lay their eggs", "Warm sand is warm", "The sea is big and blue" }, why = "It keeps both key facts in a few words." },
  { lv = 2, q = "Which is the best heading for notes about where bats live, what they eat and how they fly?", a = "Bats", d = { "Flying", "Food", "Caves" }, why = "The heading should cover everything in the notes." },
  { lv = 2, q = "When you take notes, you should write...", a = "Key words in your own words", d = { "Every word exactly", "Only the title", "Only your opinion" }, why = "Your own short words help you understand and avoid copying." },
  { lv = 2, q = "Text: \"Wisps glow softly and drift through ancient forests.\" Which word is NOT needed in a note?", a = "Softly", d = { "Wisps", "Glow", "Forests" }, why = "Notes drop describing words that aren't key facts." },
  { lv = 3, q = "You found 3 facts about yetis in 2 books. What should your notes include?", a = "The facts and which book each came from", d = { "Only the facts you like", "Only the book titles", "A copy of both books" }, why = "Writing the source next to each fact lets you cite it later." },
  { lv = 3, q = "Which note uses a good shortcut?", a = "Yetis: live in snow, eat roots & fish", d = { "Yetis are creatures that live in the snow and they eat roots and fish", "Snow", "Yetis are cool" }, why = "Symbols like & and short phrases make quick, clear notes." },
  { lv = 3, q = "After reading, what is a good way to check your notes?", a = "Tell the main ideas from your notes alone", d = { "Throw them away", "Count the words", "Copy them again" }, why = "If your notes let you explain the topic, they work." },
}

-- MAGISTER: reliable sources -----------------------------------------------------
D.SOURCES = {
  { lv = 1, q = "Who is the most reliable source about healing herbs?", a = "An experienced herbalist", d = { "A random stranger", "A talking parrot", "A joke book" }, why = "Experts who study a topic know it best." },
  { lv = 1, q = "Which source is most reliable about yesterday's storm?", a = "Someone who saw it and wrote it down that day", d = { "A rumor from a friend's cousin", "A story made up for fun", "A guess" }, why = "Eyewitnesses who record things right away are more reliable." },
  { lv = 1, q = "A source you can trust is called...", a = "Reliable", d = { "Rumor", "Fiction", "Opinion" }, why = "Reliable means you can count on it to be accurate.", t = { "reliable" } },
  { lv = 1, q = "Why is a rumor not a good source?", a = "Nobody knows where it came from", d = { "It is too short", "It is spoken out loud", "It is always about food" }, why = "You can't check who said it or whether they knew." },
  { lv = 2, q = "Two maps of the same zone disagree. Which is probably better?", a = "The newer map made by a mapmaker", d = { "The older map with a coffee stain", "A map a child drew for fun", "The prettier map" }, why = "Recent work by an expert is usually more accurate." },
  { lv = 2, q = "A potion seller says his potion is the best. Why be careful?", a = "He wants you to buy it", d = { "He talks too fast", "Potions are always bad", "He has a hat" }, why = "People who gain from you believing them may be biased." },
  { lv = 2, q = "What should you check about any source?", a = "Who wrote it, when, and why", d = { "Only its color", "How many pages it has", "If it has pictures" }, why = "Author, date and purpose tell you how much to trust it." },
  { lv = 2, q = "An old book about dragons is from 100 years ago. What should you do?", a = "Check a newer source too", d = { "Trust it completely", "Throw it away", "Copy all of it" }, why = "Old sources can be out of date. Compare with newer ones." },
  { lv = 3, q = "A diary written during an event is a...", a = "Primary source", d = { "Secondary source", "Rumor", "Fiction" }, why = "Primary sources come from the time and the people involved.", t = { "primary source", "primary" } },
  { lv = 3, q = "A history book written long after an event, using many records, is a...", a = "Secondary source", d = { "Primary source", "Diary", "Rumor" }, why = "Secondary sources explain events using other sources.", t = { "secondary source", "secondary" } },
  { lv = 3, q = "Three reliable sources agree; one unknown source disagrees. What is wisest?", a = "Go with the agreeing reliable sources", d = { "Believe the odd one out", "Give up researching", "Pick the shortest one" }, why = "When trustworthy sources agree, that's strong evidence." },
  { lv = 3, q = "Which source is biased?", a = "A guild poster saying its guild is the best", d = { "A map of the Barrens", "A dictionary", "A weather record" }, why = "The poster wants you to join, so it only shows one side." },
}

-- MAGISTER: citing ---------------------------------------------------------------
D.CITE = {
  { lv = 1, q = "Why do researchers cite their sources?", a = "To show where their facts came from", d = { "To make the page longer", "To hide the facts", "Because it rhymes" }, why = "Citing gives credit and lets others check your facts." },
  { lv = 1, q = "Copying someone's words and pretending they are yours is called...", a = "Plagiarism", d = { "Citing", "Research", "Note-taking" }, why = "Plagiarism is not allowed. Always give credit.", t = { "plagiarism" } },
  { lv = 2, q = "If you use someone's exact words, you must...", a = "Put them in quotation marks and cite them", d = { "Change one word", "Write them in capitals", "Hide them in the middle" }, why = "Quotation marks show the exact words belong to someone else." },
  { lv = 2, q = "Saying an idea in your own words is called...", a = "Paraphrasing", d = { "Plagiarism", "Copying", "Guessing" }, why = "Paraphrasing still needs a citation, because the idea isn't yours.", t = { "paraphrasing", "paraphrase" } },
  { lv = 3, q = "Do you need to cite an idea you paraphrased?", a = "Yes, the idea came from someone else", d = { "No, it's in my words now", "Only if it is long", "Only on weekends" }, why = "Credit the idea's owner even when the words are yours." },
  { lv = 3, q = "Which fact usually does NOT need a citation?", a = "There are seven days in a week", d = { "A scholar's new theory", "A quote from a book", "Numbers from a survey" }, why = "Common knowledge everyone knows doesn't need a source." },
}

-- MAGISTER: the research process ------------------------------------------------------
D.SKIM = {
  { lv = 1, q = "What is the FIRST step of a research quest?", a = "Decide what question you want to answer", d = { "Write the final report", "Make a poster", "Pick a font" }, why = "A clear question guides everything else." },
  { lv = 1, q = "Reading quickly to get the main idea is called...", a = "Skimming", d = { "Scanning", "Plagiarism", "Citing" }, why = "Skim to get the gist; scan to find one detail.", t = { "skimming", "skim" } },
  { lv = 1, q = "Looking quickly for one name or number is called...", a = "Scanning", d = { "Skimming", "Copying", "Sorting" }, why = "Scanning hunts for a specific detail.", t = { "scanning", "scan" } },
  { lv = 2, q = "Which part of a book helps you skim fast?", a = "Headings and bold words", d = { "The page numbers only", "The back cover price", "The blank pages" }, why = "Headings and bold words show the main ideas." },
  { lv = 2, q = "Put the research steps in order: find sources, ask a question, share results.", a = "Ask, find, share", d = { "Share, ask, find", "Find, share, ask", "Ask, share, find" }, why = "Question first, then sources, then share what you learned." },
  { lv = 2, q = "Your search found nothing useful. What should you try?", a = "Different keywords", d = { "Give up", "Copy any page", "Use longer sentences" }, why = "New or more specific keywords often find better results." },
  { lv = 3, q = "A glossary in a book is...", a = "A list of hard words and their meanings", d = { "The list of chapters", "The author's photo", "The cover" }, why = "Glossaries explain special words, usually at the back." },
  { lv = 3, q = "You have one question and three sources. What should you do before writing?", a = "Compare what the sources say", d = { "Use only the first one", "Write before reading", "Pick the longest one" }, why = "Comparing sources helps you find what is true." },
  { lv = 3, q = "Where in a nonfiction book do you find which page talks about a topic?", a = "The index", d = { "The title page", "The dedication", "The front cover" }, why = "The index at the back lists topics with page numbers.", t = { "index", "the index" } },
}

-- Library Passport: one stamp per skill tier. Libraries from every faction and the
-- neutral lands, with Alliance and Horde places in equal numbers. Icons are in-game icons.
local I = "Interface\\Icons\\"
local function st(name, zone, icon, note) return { name = name, zone = zone, icon = I .. icon, note = note } end
D.STAMPS = {
  lib_shelves = {
    st("Shelf-Finder Stamp", "Knowledge Exchange, Gadgetzan", "INV_Misc_Book_09", "Every book has a home on a shelf. Labels tell you where to look."),
    st("Ladder Stamp", "Royal Library, Stormwind", "INV_Misc_Book_01", "Tall shelves need ladders, and smart readers read the labels first."),
    st("Return Cart Stamp", "Valley of Wisdom, Orgrimmar", "INV_Misc_Book_10", "Putting books back on the right shelf helps the next reader."),
  },
  lib_abc = {
    st("Alphabet Stamp", "Knowledge Exchange, Gadgetzan", "INV_Scroll_01", "A, B, C... libraries line books up in ABC order so you can find them fast."),
    st("Card Drawer Stamp", "Hall of Explorers, Ironforge", "INV_Scroll_03", "Old card drawers are sorted by letter, one tiny card per book."),
    st("Second-Letter Stamp", "Elder Rise, Thunder Bluff", "INV_Scroll_04", "When first letters match, look at the second letter."),
  },
  lib_toc_simple = {
    st("Contents Stamp", "Cenarion Hold, Silithus", "INV_Misc_Book_10", "The contents page is a map of the book."),
    st("Page Turner Stamp", "Royal Library, Stormwind", "INV_Misc_Note_01", "Find the topic, read the page number, turn straight there."),
    st("Chapter Peek Stamp", "Valley of Wisdom, Orgrimmar", "INV_Misc_Note_02", "Each part starts on its page and runs until the next part begins."),
  },
  lib_keywords_young = {
    st("Key Word Stamp", "Booty Bay Harbor Office", "INV_Misc_Key_02", "The key word is the word that tells what you want to know."),
    st("Little-Words Stamp", "Hall of Explorers, Ironforge", "INV_Misc_Key_03", "Skip little words like 'the' and 'what'. Keep the topic word."),
    st("Two-Key Stamp", "Elder Rise, Thunder Bluff", "INV_Misc_Key_04", "Two key words, like 'owls' and 'eat', find better answers."),
  },
  lib_truesilly = {
    st("True-or-Silly Stamp", "Ratchet Docks Notice Board", "Spell_Holy_HolyBolt", "Readers ask: could this really be true?"),
    st("Fact Book Stamp", "Royal Library, Stormwind", "INV_Misc_Book_09", "Nonfiction books are written to tell what is real."),
    st("Story Shelf Stamp", "Valley of Wisdom, Orgrimmar", "INV_Misc_Book_01", "Stories can be make-believe, and that's part of the fun."),
  },
  lib_index = {
    st("Index Stamp", "Violet Citadel, Dalaran", "INV_Scroll_03", "The index at the back lists topics in ABC order with page numbers."),
    st("Many-Pages Stamp", "Hall of Explorers, Ironforge", "INV_Scroll_06", "A topic in the index can point to more than one page."),
    st("Back-of-Book Stamp", "Elder Rise, Thunder Bluff", "INV_Misc_Book_10", "Contents at the front, index at the back."),
  },
  lib_toc = {
    st("Chapter Map Stamp", "Knowledge Exchange, Gadgetzan", "INV_Misc_Book_01", "Chapters start on a page and end just before the next one starts."),
    st("Page Range Stamp", "Royal Library, Stormwind", "INV_Misc_Note_01", "Subtract the start pages to know how long a chapter is."),
    st("Big Book Stamp", "Valley of Wisdom, Orgrimmar", "INV_Misc_Book_09", "Even the thickest book is easy with a good contents page."),
  },
  lib_keywords = {
    st("Search Stamp", "Violet Citadel, Dalaran", "INV_Misc_Key_04", "Turn a question into strong search words: topic plus what you need."),
    st("Better Words Stamp", "Hall of Explorers, Ironforge", "INV_Misc_Key_02", "Habitat, lifespan, diet: precise words find precise answers."),
    st("Refine Stamp", "Elder Rise, Thunder Bluff", "INV_Misc_Key_03", "No luck? Try different keywords. Researchers never give up."),
  },
  lib_factopinion = {
    st("Fact Stamp", "Cenarion Hold, Silithus", "Spell_Holy_Restoration", "Facts can be checked. Opinions tell how someone feels."),
    st("Signal Word Stamp", "Royal Library, Stormwind", "INV_Scroll_01", "Best, worst, prettiest: these words often mean an opinion."),
    st("Mixed Sentence Stamp", "Valley of Wisdom, Orgrimmar", "INV_Scroll_04", "One sentence can hold a fact and an opinion together."),
  },
  lib_notes = {
    st("Notebook Stamp", "Booty Bay Harbor Office", "INV_Scroll_04", "Notes keep key words, not every word."),
    st("Heading Stamp", "Hall of Explorers, Ironforge", "INV_Misc_Note_02", "A good heading covers everything in the notes below it."),
    st("Source Tag Stamp", "Elder Rise, Thunder Bluff", "INV_Misc_Note_01", "Write where each fact came from, so you can cite it later."),
  },
  lib_sources = {
    st("Trusted Source Stamp", "Violet Citadel, Dalaran", "Spell_Holy_MindSooth", "Ask: who wrote it, when, and why?"),
    st("Eyewitness Stamp", "Royal Library, Stormwind", "INV_Misc_Eye_01", "Someone who saw it and wrote it down that day beats a rumor."),
    st("Primary Source Stamp", "Valley of Wisdom, Orgrimmar", "INV_Scroll_06", "Diaries and logbooks from the time are primary sources."),
  },
  lib_citing = {
    st("Citation Stamp", "Knowledge Exchange, Gadgetzan", "INV_Scroll_06", "Author, title, year: give credit where it's due."),
    st("Quotation Stamp", "Hall of Explorers, Ironforge", "INV_Scroll_01", "Exact words go in quotation marks, with the source."),
    st("Paraphrase Stamp", "Elder Rise, Thunder Bluff", "INV_Scroll_03", "Your own words, someone else's idea: still cite it."),
  },
  lib_compare = {
    st("Two Sources Stamp", "Cenarion Hold, Silithus", "Ability_Hunter_SniperShot", "When two sources agree, you can trust that part more."),
    st("Spot the Difference Stamp", "Royal Library, Stormwind", "INV_Misc_Spyglass_02", "Where sources disagree, look for the more careful one."),
    st("Judge's Stamp", "Valley of Wisdom, Orgrimmar", "INV_Misc_Book_10", "Written the same day by someone who counted beats a tale told later."),
  },
  lib_tables = {
    st("Table Reader Stamp", "Ratchet Docks Notice Board", "INV_Misc_Coin_05", "Find the row, read across: tables hold facts in neat boxes."),
    st("Biggest Number Stamp", "Hall of Explorers, Ironforge", "INV_Misc_Coin_04", "Compare every row to find the most or the least."),
    st("Total Stamp", "Elder Rise, Thunder Bluff", "INV_Misc_Coin_02", "Add the rows for a total, subtract for a difference."),
  },
  lib_skim = {
    st("Skim Stamp", "Violet Citadel, Dalaran", "INV_Misc_Eye_01", "Skim for the main idea, scan for one detail."),
    st("Research Quest Stamp", "Knowledge Exchange, Gadgetzan", "INV_Misc_Book_11", "Ask, find, check, share: every research quest has these steps."),
    st("Master Researcher Stamp", "Booty Bay Harbor Office", "INV_Misc_Book_09", "Compare sources, take notes, cite them, and share what you learned."),
  },
}

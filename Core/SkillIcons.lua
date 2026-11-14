-- Per-skill icons (v0.5.1): every skill row gets its own in-game icon instead of the
-- subject icon. All are standard client icon files (Interface\Icons), loaded at runtime;
-- names were checked against the icon database. A skill without an entry falls back to
-- its module's icon (Modules.Register fills node.icon).
local _, ns = ...
local P = "Interface\\Icons\\"
local I = {
  -- Rune Forger
  counting = "INV_Misc_Coin_01", add10 = "INV_Misc_Bag_10", add20 = "INV_Misc_Bag_08",
  sub20 = "INV_Misc_Ammo_Arrow_01", compare = "INV_Misc_Orb_01",
  times = "Spell_Nature_Lightning", division = "INV_Misc_Food_11", placevalue = "INV_Misc_Coin_04",
  fractions = "INV_Misc_Food_25", word = "INV_Misc_Note_01",
  percent = "INV_Misc_Coin_02", negatives = "Spell_Frost_FrostBolt02", order = "INV_Misc_Gear_02",
  equations = "Spell_Holy_SealOfWisdom", area = "INV_Misc_Map_01",
  -- Scribe's Scrolls
  sc_letters = "INV_Misc_Note_02", sc_cvc = "INV_Misc_Note_03", sc_sight = "INV_Misc_Spyglass_01",
  sc_meaning = "INV_Misc_Book_02", sc_type_words = "INV_Feather_01",
  sc_patterns = "INV_Misc_Rune_02", sc_context = "INV_Misc_Book_04", sc_synonyms = "Spell_Nature_MirrorImage",
  sc_spell_adept = "INV_Scroll_02", sc_type_phrases = "INV_Feather_02",
  sc_affixes = "Trade_Engraving", sc_confused = "Spell_Shadow_Charm", sc_vocab = "INV_Misc_Book_08",
  sc_spell_magister = "INV_Scroll_05", sc_type_sentences = "INV_Feather_03",
  -- Lore Chronicles
  lc_sentence = "INV_Misc_Note_04", lc_sequence = "INV_Misc_PocketWatch_02", lc_who = "INV_Misc_Head_Human_01",
  lc_what = "INV_Box_01", lc_where = "INV_Misc_Spyglass_02",
  lc_main_idea = "INV_Misc_Book_06", lc_feelings = "Spell_Holy_Heal", lc_cause = "Spell_Nature_Earthquake",
  lc_vocab = "INV_Misc_Book_05", lc_build = "INV_Stone_01",
  lc_inference = "Spell_Holy_MindVision", lc_compare = "INV_BannerPVP_03", lc_bigpicture = "INV_Misc_Book_07",
  lc_grammar = "INV_Misc_Bandage_15", lc_written = "INV_Feather_05",
  -- Lore Quiz for Everyone
  lq_horde = "INV_BannerPVP_01", lq_alliance = "INV_BannerPVP_02", lq_neutral = "INV_Misc_Coin_03",
  lq_places = "INV_Misc_Spyglass_03", lq_legends = "INV_Misc_Head_Dragon_01",
  -- Azeroth Naturalist (v0.9)
  nat_habitats = "Ability_Hunter_Pet_Tallstrider", nat_needs = "INV_Drink_07", nat_living = "INV_Misc_Herb_10",
  nat_daynight = "Spell_Nature_StarFall", nat_seasons = "Spell_Nature_ResistNature",
  nat_foodchains = "Ability_Hunter_Pet_Wolf", nat_watercycle = "Spell_Frost_IceStorm", nat_matter = "INV_Potion_15",
  nat_adapt = "Ability_Hunter_Pet_Turtle", nat_lifecycle = "INV_Misc_Herb_02",
  nat_fairtest = "Trade_Alchemy", nat_explain = "INV_Misc_Book_03", nat_ecosystems = "Spell_Nature_Regeneration",
  nat_forces = "Ability_Warrior_Charge", nat_energy = "Spell_Fire_Fire",
  -- Gnomish Engineering (v0.11)
  ge_sequence = "INV_Misc_Gear_03", ge_patterns = "INV_Misc_Gear_04", ge_directions = "Ability_Mount_MechaStrider",
  ge_program = "INV_Misc_Gear_05", ge_turns = "INV_Misc_Gear_06",
  ge_loops = "INV_Misc_Gear_07", ge_loopgrid = "INV_Misc_Gear_08", ge_conditionals = "INV_Misc_Lantern_01",
  ge_debug = "INV_Misc_Wrench_01", ge_events = "INV_Misc_PocketWatch_01",
  ge_variables = "INV_Battery_01", ge_functions = "INV_Gizmo_01", ge_boolean = "INV_Misc_Key_01",
  ge_algorithms = "INV_Misc_Rune_01", ge_pseudocode = "INV_Misc_Note_05",
  -- Librarian Quests (v0.12)
  lib_shelves = "INV_Misc_Key_03", lib_abc = "INV_Scroll_01", lib_toc_simple = "INV_Misc_Book_10",
  lib_keywords_young = "INV_Misc_Key_02", lib_truesilly = "Spell_Holy_HolyBolt",
  lib_index = "INV_Scroll_08", lib_toc = "INV_Scroll_07", lib_keywords = "INV_Misc_Key_04",
  lib_factopinion = "Spell_Holy_Restoration", lib_notes = "INV_Scroll_04",
  lib_sources = "Spell_Holy_MindSooth", lib_citing = "INV_Scroll_06", lib_compare = "Ability_Hunter_SniperShot",
  lib_tables = "INV_Misc_Coin_05", lib_skim = "INV_Misc_Eye_01",
  -- Mechanics Academy (v0.13)
  mech_roles = "Ability_Warrior_ShieldWall", mech_fire = "Spell_Fire_Fireball02", mech_count = "Ability_Hunter_Pet_Raptor",
  mech_health = "Spell_Holy_Heal02", mech_teamwork = "Spell_Holy_PrayerOfFortitude",
  mech_threat = "Ability_Warrior_Taunt", mech_positioning = "Ability_Rogue_Sprint", mech_interrupts = "Ability_Kick",
  mech_cooldowns = "Spell_Nature_TimeStop", mech_classes = "INV_Helmet_08",
  mech_dps = "Ability_DualWield", mech_mana = "INV_Potion_76", mech_rotation = "Ability_Rogue_SliceDice",
  mech_bossmech = "INV_Misc_Head_Dragon_Black", mech_races = "Spell_Nature_Polymorph",
  -- World Tongues (v1.1)
  wt_ja_hira = "INV_Misc_Book_01", wt_ja_hira_marks = "INV_Scroll_03", wt_ja_kata = "INV_Letter_01",
  wt_ja_greetings = "INV_Misc_Gift_01", wt_ja_numbers = "INV_Misc_Bag_07", wt_ja_kata_marks = "INV_Letter_02",
  wt_ja_colors = "INV_Potion_51", wt_ja_family = "Spell_Holy_PrayerOfHealing", wt_ja_food = "INV_Misc_Food_15",
  wt_ja_sentences = "INV_Letter_03", wt_ja_kanji_numbers = "INV_Misc_Rune_04", wt_ja_kanji_time = "Spell_Nature_Sleep",
  wt_ja_kanji_nature = "INV_Misc_Flower_02", wt_ja_kanji_people = "INV_Misc_Head_Gnome_01", wt_ja_phrases = "INV_Misc_Coin_06",
  wt_es_greetings = "INV_Letter_04", wt_es_colors = "INV_Potion_52", wt_es_phrases = "INV_Letter_05",
}
ns.SkillIcons = {}
for id, name in pairs(I) do ns.SkillIcons[id] = P .. name end

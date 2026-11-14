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
}
ns.SkillIcons = {}
for id, name in pairs(I) do ns.SkillIcons[id] = P .. name end

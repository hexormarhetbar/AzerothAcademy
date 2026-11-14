-- Mechanics Academy curated questions + generator data (v0.13). Original writing.
-- Coach Brakka Steelwhistle (original goblin, neutral) runs the Training Ring behind the
-- Knowledge Exchange in Gadgetzan. Game facts (roles, classes, racial traits) are described in
-- our own words; nothing is copied from game text. Pure data.
-- Entry: { lv = 1..3, q, a, d = { wrong answers }, why, t = { typed spellings } (optional) }
local _, ns = ...
local D = {}
ns.MechanicsData = D

-- names used in drills (Academy characters, all original)
D.NAMES = { "Nixa", "Bramble", "Quill", "Tamsin", "Pip", "Rook", "Juno", "Dax", "Ivy", "Tibbs", "Orla", "Hal" }
D.ENEMIES = { "wolves", "raptors", "murlocs", "kobolds", "spiders", "boars", "harpies", "gnolls" }
D.BOSSES = { "the Clockwork Golem", "the Sand Wyrm", "the Bog Beast", "the Crystal Spider", "the Storm Elemental",
  "the Mossy Giant" }

-- Classes. modern = only on clients that have the class (Retail); see Compat (ns.Env.modernClasses).
-- roles: which roles the class can fill in a group.
D.CLASSES = {
  { id = "WARRIOR", name = "Warrior", tank = true, dps = true, power = "rage", armor = "plate",
    hint = "fights up close in heavy armor and builds rage by hitting and being hit" },
  { id = "PALADIN", name = "Paladin", tank = true, heal = true, dps = true, power = "mana", armor = "plate",
    hint = "a holy knight in plate who can protect, heal or fight" },
  { id = "HUNTER", name = "Hunter", dps = true, power = "focus or mana", armor = "mail", pet = true,
    hint = "shoots from far away and fights beside an animal companion" },
  { id = "ROGUE", name = "Rogue", dps = true, power = "energy", armor = "leather", stealth = true,
    hint = "sneaks in stealth and builds combo points for finishing moves" },
  { id = "PRIEST", name = "Priest", heal = true, dps = true, power = "mana", armor = "cloth",
    hint = "wears cloth robes and uses holy or shadow magic, often to heal" },
  { id = "SHAMAN", name = "Shaman", heal = true, dps = true, power = "mana", armor = "mail", totems = true,
    hint = "calls on the elements and places totems on the ground" },
  { id = "MAGE", name = "Mage", dps = true, power = "mana", armor = "cloth",
    hint = "casts fire, frost and arcane spells and can conjure food and water" },
  { id = "WARLOCK", name = "Warlock", dps = true, power = "mana", armor = "cloth", pet = true,
    hint = "commands a summoned minion and uses spells that hurt over time" },
  { id = "DRUID", name = "Druid", tank = true, heal = true, dps = true, power = "mana", armor = "leather",
    hint = "changes shape into animals like a bear or a cat" },
  { id = "DEATHKNIGHT", name = "Death Knight", modern = true, tank = true, dps = true, power = "runic power", armor = "plate",
    hint = "a plate fighter with frost and shadow powers who uses runes" },
  { id = "MONK", name = "Monk", modern = true, tank = true, heal = true, dps = true, power = "energy or mana", armor = "leather",
    hint = "a martial artist who can tank, heal or fight with fists and kicks" },
  { id = "DEMONHUNTER", name = "Demon Hunter", modern = true, tank = true, dps = true, power = "fury", armor = "leather",
    hint = "a fast fighter with glaives who can glide and double jump" },
  { id = "EVOKER", name = "Evoker", modern = true, heal = true, dps = true, power = "essence and mana", armor = "mail",
    hint = "a dragon-kin caster who breathes magic and can heal" },
}

-- Racial traits, described in our own words. modern = only on clients with these races.
D.RACES = {
  { name = "Human", trait = "Diplomacy", does = "earns reputation a little faster" },
  { name = "Dwarf", trait = "Stoneform", does = "turns their skin to stone to shrug off poisons and bleeding" },
  { name = "Night Elf", trait = "Shadowmeld", does = "fades into the shadows while standing still" },
  { name = "Gnome", trait = "Escape Artist", does = "wriggles free when something holds them in place" },
  { name = "Orc", trait = "Blood Fury", does = "gets a short burst of extra attack power" },
  { name = "Undead", trait = "Will of the Forsaken", does = "breaks free of fear, charm and sleep" },
  { name = "Tauren", trait = "War Stomp", does = "stomps the ground to stun enemies close by" },
  { name = "Troll", trait = "Berserking", does = "attacks and casts faster for a short time" },
  { name = "Draenei", trait = "Gift of the Naaru", does = "heals a friend over a few seconds", modern = true },
  { name = "Worgen", trait = "Darkflight", does = "runs much faster for a few seconds", modern = true },
  { name = "Blood Elf", trait = "Arcane Torrent", does = "silences enemies nearby and restores some power", modern = true },
  { name = "Goblin", trait = "Rocket Jump", does = "blasts forward with a rocket belt", modern = true },
}

-- role descriptions for the generated "what is my role?" questions
D.ROLE_CLUES = {
  tank = { "wears heavy armor and keeps the monster looking at them", "stands in front so the monster hits them, not the others",
    "goes in first and holds the boss in one place" },
  heal = { "watches everyone's health bars and fixes the hurt ones", "keeps the group alive with healing spells",
    "brings friends back up when their health gets low" },
  dps = { "does as much damage as possible to defeat the monster", "attacks the boss while staying out of the bad stuff",
    "brings the monster's health down fast" },
}

-- rotation abilities (made-up names, generic so they fit any class)
D.ABILITIES = { "Power Strike", "Quick Jab", "Big Finisher", "Shield Bash", "Flame Bolt", "Frost Shard", "Healing Light",
  "Rally Cry" }

-- INITIATE: roles -------------------------------------------------------------
D.ROLES = {
  { lv = 1, q = "Who stands in front and gets hit by the monster?", a = "The tank", d = { "The healer", "The damage dealer" }, why = "The tank protects the group by taking the hits." },
  { lv = 1, q = "Who keeps everyone's health up?", a = "The healer", d = { "The tank", "The damage dealer" }, why = "Healers fix health bars so nobody falls." },
  { lv = 1, q = "Whose job is to bring the monster's health down?", a = "The damage dealer", d = { "The healer", "The map reader" }, why = "Damage dealers (DPS) defeat the monster." },
  { lv = 2, q = "A normal dungeon group has how many tanks?", a = "1", d = { "3", "5" }, why = "Usually 1 tank, 1 healer and 3 damage dealers." },
  { lv = 2, q = "DPS means damage per...", a = "Second", d = { "Sandwich", "Song" }, why = "DPS is damage per second: how much damage you do each second." },
  { lv = 2, q = "The healer runs out of mana. What should the group do?", a = "Wait so the healer can drink", d = { "Run into more monsters", "Leave the healer behind" }, why = "Good groups wait until the healer is ready." },
  { lv = 3, q = "Why does the tank go in first?", a = "So monsters attack the tank", d = { "Because tanks are slow", "To pick up all the loot" }, why = "The tank grabs the monsters' attention to protect the others." },
  { lv = 3, q = "Which role needs to watch the whole group most?", a = "The healer", d = { "The damage dealer", "Nobody" }, why = "Healers check everyone's health all the time." },
  { lv = 3, q = "A dungeon group has 1 tank, 1 healer and 3 DPS. How many players?", a = "5", d = { "3", "4" }, why = "1 + 1 + 3 = 5 players." },
}

-- INITIATE: teamwork ---------------------------------------------------------
D.TEAMWORK = {
  { lv = 1, q = "A new player in your group makes a mistake. What do you do?", a = "Help them kindly", d = { "Laugh at them", "Leave the group" }, why = "Everyone learns. Kind words help the whole team." },
  { lv = 1, q = "The tank says \"Wait here.\" What should you do?", a = "Wait with the group", d = { "Run ahead alone", "Go to sleep" }, why = "Listening to the plan keeps everyone safe." },
  { lv = 1, q = "Your friend found a sword they need. What do you say?", a = "Nice find, enjoy it!", d = { "Give it to me!", "That's not fair!" }, why = "Being happy for friends makes groups fun." },
  { lv = 2, q = "Before a big fight, what is a good idea?", a = "Make sure everyone is ready", d = { "Start before others arrive", "Hide from the group" }, why = "A ready check means nobody is surprised." },
  { lv = 2, q = "The group lost a fight. What helps most?", a = "Talk about what to try next", d = { "Blame one player", "Give up forever" }, why = "Teams get better by planning together." },
  { lv = 2, q = "Why should you stay close to your group?", a = "So the healer can reach you", d = { "So you can take all the loot", "So you can push others" }, why = "Healers can only help players who are close." },
  { lv = 3, q = "Someone types a rude word in chat. What is best?", a = "Don't answer and tell a grown-up", d = { "Be rude back", "Copy them" }, why = "Ignore rude players and tell a parent or guardian." },
  { lv = 3, q = "Your group says thank you after a run. What do you say?", a = "Thanks, that was fun!", d = { "Nothing at all", "You were all bad" }, why = "Good manners make players want to play with you again." },
  { lv = 3, q = "What does \"follow the leader\" mean in a group?", a = "Go where the leader goes", d = { "Go the other way", "Stand still forever" }, why = "Moving together keeps the group safe." },
}

-- ADEPT: positioning ---------------------------------------------------------
D.POSITIONING = {
  { lv = 1, q = "The boss breathes fire in front of it. Where should damage dealers stand?", a = "Behind or beside the boss", d = { "Right in front of it", "On top of the fire", "Far away doing nothing" }, why = "Frontal attacks only hit what is in front." },
  { lv = 1, q = "Fire appears under your feet. What do you do?", a = "Move out right away", d = { "Stay and keep attacking", "Wait for it to grow", "Sit down" }, why = "Rule one of every fight: don't stand in the fire!" },
  { lv = 1, q = "Where does the tank usually point the boss?", a = "Away from the group", d = { "At the healer", "At the damage dealers", "At the door" }, why = "Pointing the boss away keeps its attacks on the tank only." },
  { lv = 2, q = "The boss tail-swipes anything behind it. Where is safest for melee?", a = "At its side", d = { "Directly behind it", "In front of it", "Under its tail" }, why = "Front and back are dangerous, so the sides are safe." },
  { lv = 2, q = "Why do healers often stand a little back?", a = "To see and reach the whole group", d = { "To take a nap", "To hide from the tank", "To pick flowers" }, why = "From the back, healers can see everyone." },
  { lv = 2, q = "Ranged players stand far away. Why?", a = "Their attacks work from far away", d = { "They are afraid of the tank", "Melee is not allowed", "To get lost" }, why = "Ranged attacks reach the boss from a distance, away from melee danger." },
  { lv = 3, q = "\"Spread out!\" means...", a = "Stand apart so splash damage hits only one", d = { "Stand all together", "Run out of the room", "Stand behind the healer" }, why = "Some attacks splash onto anyone nearby. Spreading keeps damage small." },
  { lv = 3, q = "\"Stack up!\" means...", a = "Stand close together to share the damage", d = { "Spread far apart", "Jump up and down", "Stack your loot" }, why = "Some attacks split their damage between everyone close by." },
  { lv = 3, q = "The boss pulls everyone to the middle, then a ring of fire appears there. What next?", a = "Run out of the middle", d = { "Stay in the middle", "Attack harder", "Drink a potion and stay" }, why = "Watch for the pattern: pull in, then run out." },
  { lv = 3, q = "Line of sight means...", a = "The caster can see you", d = { "You can see the loot", "A line on the floor", "You are in a queue" }, why = "Hiding behind a pillar breaks line of sight so a spell can't reach you." },
}

-- MAGISTER: boss mechanics ----------------------------------------------------
D.BOSSMECH = {
  { lv = 1, q = "A boss gets much stronger after a time limit. This is called...", a = "An enrage timer", d = { "A loot timer", "A cooldown", "A buff" }, why = "Beat the boss before it enrages!", t = { "enrage timer", "enrage" } },
  { lv = 1, q = "A boss changes how it fights at half health. This is a new...", a = "Phase", d = { "Class", "Zone", "Mount" }, why = "Fights often have phases with new mechanics.", t = { "phase" } },
  { lv = 1, q = "Small extra monsters that join a boss fight are called...", a = "Adds", d = { "Pets", "Mounts", "Quests" }, why = "Adds are 'added' monsters. Often they must be defeated first.", t = { "adds" } },
  { lv = 2, q = "The boss casts a big heal on itself. Who should stop it?", a = "A player with an interrupt", d = { "The healer, by healing more", "Nobody", "The player with the most gold" }, why = "Interrupts stop spells while they are being cast." },
  { lv = 2, q = "\"Soak\" a puddle means...", a = "Some players stand in it to share its damage", d = { "Avoid it completely", "Drink from it", "Clean it up" }, why = "Soaking splits damage so nobody takes too much." },
  { lv = 2, q = "Two tanks swap the boss when it stacks a weakness on one. This is a...", a = "Tank swap", d = { "Tank race", "Healer swap", "Loot swap" }, why = "Swapping lets the stacks fall off the first tank." },
  { lv = 2, q = "Which should you usually defeat first: a healer add or the boss?", a = "The healer add", d = { "The boss", "Neither", "The tank" }, why = "An add that heals the boss undoes your damage." },
  { lv = 3, q = "The boss marks you with a bomb that explodes in 5 seconds. What do you do?", a = "Move away from the group", d = { "Run into the group", "Stand next to the healer", "Ignore it" }, why = "Carry the danger away so only you are hit." },
  { lv = 3, q = "Why do groups learn a fight step by step?", a = "Each phase has different rules", d = { "To make it slower", "Bosses never change", "Learning is not needed" }, why = "Knowing what comes next lets you react in time." },
  { lv = 3, q = "A wipe means...", a = "The whole group was defeated", d = { "The floor was cleaned", "A boss was defeated", "Someone left" }, why = "After a wipe, talk about what to change and try again." },
}

-- Tactics Deck: one card per skill tier. Neutral places only. Icons are in-game icons.
local I = "Interface\\Icons\\"
local function card(name, zone, icon, note) return { name = name, zone = zone, icon = I .. icon, note = note } end

D.CARDS = {
  mech_roles = {
    card("Shield Wall Card", "Training Ring, Gadgetzan", "INV_Shield_05", "Tanks hold attention, healers keep health up, damage dealers finish the job."),
    card("Healing Hands Card", "Training Ring, Gadgetzan", "Spell_Holy_FlashHeal", "A healer watches every health bar, not just their own."),
    card("Team of Five Card", "Wailing Caverns", "INV_Banner_01", "One tank, one healer and three damage dealers make a classic group."),
  },
  mech_fire = {
    card("Hot Feet Card", "Searing Gorge", "Spell_Fire_Fire", "If the floor glows, your feet go. Step out first, then keep fighting."),
    card("Safe Square Card", "Burning Steppes", "Spell_Fire_FlameShock", "Look for the square with no fire and nothing spreading toward it."),
    card("Firewalker Card", "Blackrock Mountain", "Spell_Fire_SelfDestruct", "Fire spreads. Plan one step ahead, not just this second."),
  },
  mech_count = {
    card("Head Count Card", "Training Ring, Gadgetzan", "INV_Misc_Head_Human_01", "Count the monsters before you pull. More than expected? Wait for the tank."),
    card("Add Watcher Card", "Razorfen Kraul", "Ability_Hunter_Pet_Boar", "Extra monsters joining a fight are adds. Keeping count keeps you calm."),
    card("Pack Planner Card", "Shadowfang Keep", "Ability_Hunter_Pet_Wolf", "Group size plus adds tells the healer how busy the fight will be."),
  },
  mech_health = {
    card("Health Bar Card", "Training Ring, Gadgetzan", "INV_Potion_51", "The emptiest health bar is the one that needs help first."),
    card("Triage Card", "Stranglethorn Vale", "Spell_Holy_Renew", "Compare health by what is missing, not just by the number left."),
    card("Quick Mender Card", "Tanaris", "INV_Potion_54", "Half of 100 is 50. Knowing halves and quarters makes healing quick."),
  },
  mech_teamwork = {
    card("Kind Words Card", "Training Ring, Gadgetzan", "Spell_Holy_PowerWordShield", "Everyone was new once. A kind word is the best buff in the game."),
    card("Ready Check Card", "Gadgetzan Bank", "INV_Misc_Bell_01", "Ask \"Is everyone ready?\" before every big pull."),
    card("Good Sport Card", "Booty Bay", "INV_Misc_Ticket_Tarot_Blessings", "Win or wipe, say thanks. Good manners make good friends."),
  },
  mech_threat = {
    card("Aggro Card", "Training Ring, Gadgetzan", "Ability_Warrior_Taunt", "Monsters attack whoever has the most threat. Let the tank stay on top."),
    card("Threat Meter Card", "Scarlet Monastery", "Ability_Warrior_PunishingBlow", "Watch the gap between you and the tank, and slow down when it gets small."),
    card("Taunt Card", "Uldaman", "Ability_Warrior_Sunder", "A taunt pulls a monster's attention back to the tank in an instant."),
  },
  mech_positioning = {
    card("Behind the Boss Card", "Training Ring, Gadgetzan", "Ability_BackStab", "Frontal attacks miss you if you stand behind or beside the boss."),
    card("Spread Out Card", "Zul'Farrak", "Spell_Nature_Lightning", "Splash attacks hit everyone nearby, so spread out when you hear it."),
    card("Stack Up Card", "Maraudon", "Spell_Holy_PrayerOfHealing", "Shared damage gets smaller with more friends standing close."),
  },
  mech_interrupts = {
    card("Kick Card", "Training Ring, Gadgetzan", "Ability_Kick", "Watch the cast bar. Interrupt before it fills."),
    card("Cast Bar Card", "Sunken Temple", "Spell_Frost_IceShock", "Casts come on a rhythm. Count the seconds and be ready."),
    card("Interrupt Order Card", "Blackrock Depths", "Spell_Holy_Silence", "Take turns: when one interrupt is cooling down, the next player is ready."),
  },
  mech_cooldowns = {
    card("Cooldown Clock Card", "Training Ring, Gadgetzan", "INV_Misc_PocketWatch_02", "A 30-second cooldown used at 10 seconds is ready again at 40."),
    card("Save It Card", "Dire Maul", "Spell_Holy_DivineIntervention", "Big cooldowns are best saved for the dangerous moment."),
    card("Timeline Card", "Stratholme", "INV_Misc_Note_06", "Write the fight as a timeline to see when each cooldown is back."),
  },
  mech_classes = {
    card("Class Guide Card", "Training Ring, Gadgetzan", "INV_Misc_Book_08", "Every class has a style. Some can fill more than one role."),
    card("Hybrid Card", "Feralas", "Ability_Druid_CatForm", "Hybrid classes can switch roles: tank one day, heal the next."),
    card("Armor Types Card", "Winterspring", "INV_Chest_Plate06", "Cloth, leather, mail and plate: heavier armor, more protection."),
  },
  mech_dps = {
    card("Damage Meter Card", "Training Ring, Gadgetzan", "Ability_DualWield", "DPS times seconds equals total damage."),
    card("Boss Timer Card", "Onyxia's Lair", "INV_Misc_Head_Dragon_01", "Boss health divided by group DPS tells you how long the fight lasts."),
    card("Team Damage Card", "Molten Core", "Spell_Fire_Incinerate", "Add every player's DPS to get the group's total damage per second."),
  },
  mech_mana = {
    card("Mana Budget Card", "Training Ring, Gadgetzan", "INV_Potion_76", "Mana divided by spell cost tells you how many casts you have left."),
    card("Drink Break Card", "Thousand Needles", "INV_Drink_07", "Regaining mana each second stretches a long fight."),
    card("Efficient Caster Card", "Moonglade", "Spell_Nature_Lightning", "A cheaper spell that heals less can still win the long fight."),
  },
  mech_rotation = {
    card("Priority List Card", "Training Ring, Gadgetzan", "INV_Misc_Note_04", "Check the list from the top. Use the first ability whose rule is true."),
    card("Combo Card", "Silithus", "Ability_Rogue_Eviscerate", "Build up, then spend. Finishers hit hardest at full combo."),
    card("Execute Card", "Ahn'Qiraj Gates", "INV_Sword_48", "Some abilities only work when the enemy is low. Watch for that rule."),
  },
  mech_bossmech = {
    card("Enrage Timer Card", "Training Ring, Gadgetzan", "Spell_Shadow_UnholyFrenzy", "Beat the boss before the timer runs out or it gets much stronger."),
    card("Phase Shift Card", "Blackwing Lair", "INV_Misc_Head_Dragon_Black", "New phase, new rules. Listen for the boss to change."),
    card("Wipe Recovery Card", "Naxxramas", "Spell_Holy_Resurrection", "After a wipe, change one thing and try again."),
  },
  mech_races = {
    card("Racial Trait Card", "Training Ring, Gadgetzan", "Spell_Shadow_Teleport", "Every race brings a special trait. Knowing them helps you plan."),
    card("Stoneskin Card", "Dun Morogh", "Spell_Shadow_UnholyStrength", "A trait that shrugs off poison and bleeding can save a run."),
    card("War Drum Card", "Mulgore", "Ability_WarStomp", "A short stun on nearby enemies buys the healer a breath."),
  },
}

-- Murloc Boarding Party (v0.6): crew orders the murlocs carry. Original writing.
-- Initiate (5-7): single letters and short words. Adept (8-10): short crew orders.
-- Magister (11-13): full sentences. Each band also has Tidehunter boss sentences.
local _, ns = ...

local D = {}
ns.BoardingData = D

D.LETTERS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
  "n", "o", "p", "r", "s", "t", "u", "w", "y" }

D.WORDS = {
  "mop", "sail", "rope", "fish", "map", "hat", "oar", "net", "sea", "ship", "crab", "gold",
  "deck", "wave", "boat", "flag", "hook", "sun", "bell", "cup", "fin", "wet", "run", "hop",
  "dig", "sit", "pot", "bag", "red", "big", "box", "jam", "cat", "pig", "log", "mud",
}

D.PHRASES = {
  "Fire the cannon!", "Raise the sail!", "Drop the anchor!", "Swab the deck!", "Tie the rope!",
  "Turn the wheel!", "Load the cannon!", "Hoist the flag!", "Mind the barrels!", "Grab a mop!",
  "Check the map!", "Coil the rope!", "Ring the bell!", "Trim the sails!", "Pump the water out!",
  "Patch the hull!", "Roll the barrel!", "Light the lantern!", "Lower the boat!", "Sound the horn!",
  "Polish the brass!", "Feed the parrot!", "Count the crates!", "Close the hatch!", "Steady the mast!",
  "Watch the waves!", "Stack the cannonballs!", "Wake the cook!", "Fetch the spyglass!", "Oil the gears!",
}

D.SENTENCES = {
  "Load the port cannons and wait for my signal.",
  "Keep the rigging tight because the wind is turning.",
  "Bring two buckets of water to the lower deck.",
  "The cook says lunch is ready, so wash your hands.",
  "Check the cargo list before we reach the harbor.",
  "Tie every barrel down before the storm arrives.",
  "Signal the lighthouse that we are coming home.",
  "Turn the ship south and follow the warm current.",
  "Count the cannonballs and write the number down.",
  "Raise the green flag so the harbor knows we are friends.",
  "Pull in the fishing nets and sort out the crabs.",
  "Clean the spyglass lens so we can see the coast.",
  "Wind the gear crank until the paddle starts to turn.",
  "Patch the small leak near the front of the ship.",
  "Light the lanterns because the sun is going down.",
  "Ask the navigator how far we are from Ratchet.",
  "Stack the crates neatly so nothing slides around.",
  "Ring the bell twice when you spot the next island.",
  "Keep calm and keep typing; the crew believes in you.",
  "Hold the wheel steady while I check the compass.",
}

-- The Murloc Tidehunter carries a full sentence. Short and simple for the youngest band.
D.BOSS = {
  initiate = {
    "I see a big fish.", "Go back to the sea.", "The ship is ours.", "We can do it.",
    "Get off the deck.", "The sun is up.",
  },
  adept = {
    "All hands, push the big murloc back into the sea!",
    "Ready the long rope and pull the anchor up fast!",
    "Everyone grab a mop and slide that murloc overboard!",
    "Turn the ship hard and send that murloc splashing!",
    "Ring the bell, crew, the big murloc is going for a swim!",
    "Load the soft cannon and give that murloc a splash!",
  },
  magister = {
    "Fire every cannon at once and send the Tidehunter tumbling back into the waves!",
    "Hold the line, crew, because this ship sails for Ratchet and no murloc will stop it!",
    "Steady the wheel, ready the broadside, and show that Tidehunter the way to the water!",
    "The Steamwheedle crew never gives up a ship, so push that murloc back where it belongs!",
    "Raise every sail, ring the bell, and wave goodbye as the Tidehunter splashes down!",
    "Our cargo is going to Ratchet on time, so the Tidehunter will have to find another ride!",
  },
}

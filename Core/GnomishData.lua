-- Gnomish Engineering curated questions (v0.11). Original writing; Boltby is an original
-- clockwork critter and Tinker Nixa Sprocketwhirl an original host. Pure data.
-- Entry: { lv = 1..3, q = question, a = answer, d = { wrong answers }, why = explanation,
--          t = { typed spellings } (optional: Adept/Magister may type it on Rune/Glyph) }
local _, ns = ...
local D = {}
ns.GnomishData = D

-- INITIATE: steps in order (first / next / last) ------------------------------
D.SEQUENCE = {
  { lv = 1, q = "Boltby wants to plant a seed. What does it do FIRST?", a = "Dig a hole", d = { "Water the flower", "Pick the flower" }, why = "First dig a hole, then drop the seed in, then water it." },
  { lv = 1, q = "Boltby is putting on boots. What comes FIRST?", a = "Put on socks", d = { "Tie the laces", "Go outside" }, why = "Socks go on before the boots, and laces get tied last." },
  { lv = 1, q = "To brush its gears, Boltby gets the brush. What comes NEXT?", a = "Add the polish", d = { "Put the brush away", "Go to sleep" }, why = "Get the brush, add polish, scrub, then put it away." },
  { lv = 1, q = "Boltby makes a sandwich: bread, then cheese. What comes LAST?", a = "Put bread on top", d = { "Get the bread", "Open the cheese" }, why = "The top slice of bread is the last step." },
  { lv = 1, q = "Boltby wants to read a book. What does it do FIRST?", a = "Open the book", d = { "Turn to the last page", "Close the book" }, why = "You have to open the book before you can read it." },
  { lv = 1, q = "Boltby is mailing a letter. What comes LAST?", a = "Drop it in the mailbox", d = { "Write the letter", "Fold the paper" }, why = "Write it, fold it, then drop it in the mailbox." },
  { lv = 1, q = "Boltby wants a drink of water. What does it do FIRST?", a = "Get a cup", d = { "Drink the water", "Wash the cup" }, why = "Get a cup, fill it, then drink." },
  { lv = 1, q = "To wake up, Boltby opens its eyes. What comes NEXT?", a = "Get out of bed", d = { "Go to sleep", "Eat dinner" }, why = "Eyes open, then out of bed to start the day." },
  { lv = 2, q = "Boltby builds a tower: big block, middle block, small block. Which goes on the BOTTOM?", a = "Big block", d = { "Small block", "Middle block" }, why = "The big block goes first, on the bottom, so the tower stands." },
  { lv = 2, q = "Boltby washes its hands. Wet hands, add soap... what comes NEXT?", a = "Scrub", d = { "Dry hands", "Turn on the water" }, why = "Wet, soap, scrub, rinse, dry." },
  { lv = 2, q = "Boltby feeds a pet. What comes FIRST?", a = "Get the food bag", d = { "Wash the empty bowl after", "Watch the pet eat" }, why = "Get the food, fill the bowl, then the pet eats." },
  { lv = 2, q = "Boltby crosses a road. What does it do FIRST?", a = "Stop and look both ways", d = { "Run across", "Wave from the other side" }, why = "Always stop and look before you cross." },
  { lv = 2, q = "Boltby fixes a squeaky wheel. Find the squeak, add oil... what comes NEXT?", a = "Spin it to test", d = { "Find the squeak", "Buy a wheel" }, why = "After a fix, test it. Engineers always check their work." },
  { lv = 2, q = "A robot recipe says: 1. Fill pot. 2. Heat water. 3. ??? 4. Stir.  What is step 3?", a = "Add the noodles", d = { "Eat the noodles", "Wash the pot" }, why = "Noodles go into the hot water before you stir them." },
  { lv = 2, q = "Boltby paints a picture. What comes LAST?", a = "Let the paint dry", d = { "Dip the brush", "Pick colors" }, why = "Pick colors, paint, then let it dry." },
  { lv = 2, q = "Boltby wants to go outside. Shoes on, coat on... what comes NEXT?", a = "Open the door", d = { "Take off the shoes", "Go to bed" }, why = "Get ready first, then open the door." },
  { lv = 3, q = "Which list is in the RIGHT order to plant a tree?", a = "Dig, plant, water", d = { "Water, dig, plant", "Plant, water, dig" }, why = "A program only works when the steps are in the right order." },
  { lv = 3, q = "Which list is in the RIGHT order to send a message?", a = "Write, fold, send", d = { "Send, write, fold", "Fold, send, write" }, why = "You can't send a message you haven't written yet!" },
  { lv = 3, q = "Boltby's steps were mixed up: dry, wash, soap. Which step should be FIRST?", a = "Wash", d = { "Dry", "Soap" }, why = "Wash first. Drying first would not make sense." },
  { lv = 3, q = "Why must a robot's steps be in order?", a = "Robots do steps exactly as told", d = { "Robots like surprises", "Order does not matter" }, why = "A robot can't guess. It follows each step exactly, in order." },
  { lv = 3, q = "Boltby wants to build a toy cart. What does it do FIRST?", a = "Make a plan", d = { "Paint the cart", "Ride the cart" }, why = "Engineers plan first, then build, then test." },
  { lv = 3, q = "An instruction list is called a...", a = "Program", d = { "Puddle", "Pillow" }, why = "A program is a list of steps a computer or robot follows." },
}

-- ADEPT: IF / ELSE thinking --------------------------------------------------
D.COND = {
  { lv = 1, q = "IF it is raining THEN take an umbrella. It is raining. What happens?", a = "Take an umbrella", d = { "Nothing happens", "Wear sunglasses", "Go swimming" }, why = "The condition is true, so the THEN part happens." },
  { lv = 1, q = "IF the lamp is green THEN go ELSE wait. The lamp is red. What does Boltby do?", a = "Wait", d = { "Go", "Go and wait", "Turn green" }, why = "Red is not green, so the ELSE part runs.", t = { "wait" } },
  { lv = 1, q = "IF Boltby is hungry THEN it eats oil. Boltby is NOT hungry. What happens?", a = "Nothing happens", d = { "It eats oil", "It eats two oils", "It explodes" }, why = "The condition is false and there is no ELSE, so nothing happens." },
  { lv = 1, q = "Which of these is a condition?", a = "IF the door is open", d = { "Walk forward", "Repeat 3 times", "Say hello" }, why = "A condition is a yes-or-no check that decides what happens." },
  { lv = 2, q = "IF it is dark THEN turn on the lamp ELSE turn it off. It is daytime. What happens?", a = "Turn the lamp off", d = { "Turn the lamp on", "Nothing", "Flash the lamp" }, why = "Daytime is not dark, so the ELSE part runs." },
  { lv = 2, q = "A condition can only be...", a = "True or false", d = { "Big or small", "Red or blue", "Fast or slow" }, why = "Every IF checks something that is either true or false." },
  { lv = 2, q = "IF a wall is ahead THEN turn right ELSE go forward. There is no wall. What does Boltby do?", a = "Go forward", d = { "Turn right", "Turn left", "Stop forever" }, why = "No wall means the condition is false: go forward." },
  { lv = 2, q = "What word starts the 'otherwise' part of an IF?", a = "ELSE", d = { "THEN", "REPEAT", "END" }, why = "ELSE is what happens when the condition is false.", t = { "else" } },
  { lv = 3, q = "IF score >= 10 THEN 'Gold' ELSE IF score >= 5 THEN 'Silver' ELSE 'Bronze'. Score is 7. Result?", a = "Silver", d = { "Gold", "Bronze", "Gold and Silver" }, why = "7 is not 10 or more, but it is 5 or more, so Silver.", t = { "silver" } },
  { lv = 3, q = "IF score >= 10 THEN 'Gold' ELSE IF score >= 5 THEN 'Silver' ELSE 'Bronze'. Score is 10. Result?", a = "Gold", d = { "Silver", "Bronze", "Nothing" }, why = "10 >= 10 is true, so the first branch wins.", t = { "gold" } },
  { lv = 3, q = "A guard robot checks: IF badge = yes AND time = day THEN open. Badge yes, time night. Open?", a = "No, stay shut", d = { "Yes, open", "Open halfway", "Open twice" }, why = "AND needs both parts true. Night makes it false." },
  { lv = 3, q = "IF the battery < 20 THEN go recharge. Battery is 20. What happens?", a = "Keep working", d = { "Go recharge", "Shut down", "Recharge twice" }, why = "20 is not less than 20, so the condition is false." },
}

-- ADEPT: bugs in instructions ------------------------------------------------
D.DEBUG = {
  { lv = 1, q = "Steps: 1. Put on shoes  2. Put on socks  3. Walk. What is the bug?", a = "Socks must go before shoes", d = { "Walking is wrong", "There is no bug", "Shoes are not needed" }, why = "Two steps are swapped. Swapped steps are a very common bug." },
  { lv = 1, q = "Boltby should go to the gear 2 steps to the right, but the program says 'Right'. What is missing?", a = "One more Right", d = { "One Left", "One Up", "Nothing" }, why = "A missing step is a bug. Add one more Right." },
  { lv = 1, q = "What is a bug in a program?", a = "A mistake that makes it go wrong", d = { "A beetle in the robot", "A very fast program", "A finished program" }, why = "A bug is a mistake. Finding and fixing it is called debugging." },
  { lv = 1, q = "What is the BEST first step when a program does not work?", a = "Test it step by step", d = { "Throw it away", "Run it faster", "Hide it" }, why = "Walk through each step to see where it goes wrong." },
  { lv = 2, q = "A loop should beep 5 times but beeps 4 times. What should change?", a = "Repeat 5 instead of 4", d = { "Beep louder", "Remove the loop", "Repeat 3 times" }, why = "The repeat count was off by one, a classic bug." },
  { lv = 2, q = "Recipe: 1. Bake the cake  2. Mix the flour  3. Eat. Which step should be first?", a = "Mix the flour", d = { "Bake the cake", "Eat", "Wash the bowl" }, why = "You must mix before you bake. The steps are out of order." },
  { lv = 2, q = "Boltby turns left when it should turn right. What kind of bug is this?", a = "A wrong step", d = { "A missing step", "An extra step", "No bug" }, why = "The step is there, but it is the wrong one." },
  { lv = 2, q = "Fixing mistakes in a program is called...", a = "Debugging", d = { "Looping", "Painting", "Sleeping" }, why = "Debugging means finding and removing bugs.", t = { "debugging", "debug" } },
  { lv = 3, q = "A program adds 2 to gears each loop. After 3 loops, gears should be 6 (start 0) but is 8. Likely bug?", a = "It looped 4 times", d = { "It added 1 each time", "It started at -2", "It looped 2 times" }, why = "4 loops of +2 gives 8. The loop ran one time too many." },
  { lv = 3, q = "Why do engineers test after every small change?", a = "So a new bug is easy to find", d = { "Tests are fun to skip", "To make code longer", "So bugs hide better" }, why = "Small steps make it easy to see which change caused a bug." },
  { lv = 3, q = "IF age > 10 THEN 'big' should say 'big' for age 10 too. What is the fix?", a = "Change > to >= (at least)", d = { "Change > to < (less than)", "Change 10 to 11", "Remove the IF" }, why = ">= means 'greater than or equal', so 10 counts too." },
  { lv = 3, q = "A robot repeats 'Forward' forever and never stops. This bug is called...", a = "An endless loop", d = { "A missing turn", "A short loop", "A condition" }, why = "A loop with no way to stop runs forever: an endless (infinite) loop." },
}

-- ADEPT: events and breaking a job into parts ------------------------------
D.EVENTS = {
  { lv = 1, q = "WHEN the lever is pulled, the gate opens. What is the event?", a = "Pulling the lever", d = { "The gate", "Opening slowly", "The wall" }, why = "An event is something that happens and starts the program." },
  { lv = 1, q = "WHEN you click the button, Boltby jumps. What makes Boltby jump?", a = "Clicking the button", d = { "Waiting", "The sky", "Boltby's name" }, why = "The click is the event. The jump is what the program does." },
  { lv = 1, q = "WHEN the alarm rings, Boltby wakes up. What is the event?", a = "The alarm ringing", d = { "Waking up", "Sleeping", "Eating" }, why = "The ringing happens first and starts the action." },
  { lv = 1, q = "Breaking a big job into small steps is called...", a = "Decomposition", d = { "Explosion", "Painting", "Repeating" }, why = "Decomposing means splitting a big problem into small parts.", t = { "decomposition", "decomposing" } },
  { lv = 2, q = "Building a cart: which small job goes with it?", a = "Make the wheels", d = { "Sing a song", "Paint the sky", "Read a map of the moon" }, why = "Big jobs split into parts: wheels, frame, seat." },
  { lv = 2, q = "WHEN Boltby touches a coin THEN add 1 to score. Boltby touches 3 coins. Score goes up by?", a = "3", d = { "1", "0", "6" }, why = "The event happens 3 times, so the action runs 3 times.", t = { "3", "three" } },
  { lv = 2, q = "In a game, what usually starts a jump?", a = "A key being pressed", d = { "The music", "The title screen", "The score" }, why = "Pressing a key is an event the game listens for." },
  { lv = 2, q = "A mailbox robot: WHEN a letter drops in, the flag goes up. A letter drops in. What happens?", a = "The flag goes up", d = { "The flag goes down", "Nothing", "The mailbox walks away" }, why = "The event happened, so the action runs." },
  { lv = 2, q = "Which is an event?", a = "The timer reaches zero", d = { "Move forward", "Turn left", "Say hello" }, why = "Events are things that happen. The others are actions." },
  { lv = 3, q = "Planning a party robot: which is the BEST first part to split off?", a = "Make a guest list", d = { "Clean up after", "Eat the cake", "Wave goodbye" }, why = "Decompose the job and start with what everything else needs." },
  { lv = 3, q = "Two events: WHEN red button THEN beep. WHEN blue button THEN flash. Blue is pressed. What happens?", a = "Flash", d = { "Beep", "Beep and flash", "Nothing" }, why = "Only the blue event happened.", t = { "flash" } },
  { lv = 3, q = "Why split a big program into parts?", a = "Each part is easier to build and test", d = { "Parts make it slower", "To hide the bugs", "Big programs never work" }, why = "Small parts are easier to understand, test and fix." },
  { lv = 3, q = "A program waits and does something each time a thing happens. This is called...", a = "Event-driven", d = { "Upside-down", "Read-only", "Out of order" }, why = "Event-driven programs react to events like clicks and timers." },
}

-- MAGISTER: variables ---------------------------------------------------------
D.VARS = {
  { lv = 1, q = "A variable is like...", a = "A labeled box that holds a value", d = { "A broken robot", "A loop that never ends", "A kind of bug" }, why = "A variable has a name and stores a value that can change." },
  { lv = 1, q = "In 'gears = 5', what is the variable's name?", a = "gears", d = { "5", "=", "gears = 5" }, why = "The name is on the left. The value 5 is stored inside it.", t = { "gears" } },
  { lv = 2, q = "gears = 3, then gears = 8. What is gears now?", a = "8", d = { "3", "11", "38" }, why = "Setting a variable again replaces the old value.", t = { "8", "eight" } },
  { lv = 2, q = "Why use a variable for a score?", a = "The score can change as you play", d = { "Scores never change", "To make the game slower", "Variables are only for names" }, why = "Variables store values that change over time." },
  { lv = 2, q = "name = 'Boltby'. What kind of value is 'Boltby'?", a = "Text (a string)", d = { "A number", "True or false", "A loop" }, why = "Values in quotes are text, called strings." },
  { lv = 3, q = "x = 4, then x = x + x. What is x?", a = "8", d = { "4", "16", "44" }, why = "The right side is worked out first: 4 + 4 = 8.", t = { "8", "eight" } },
  { lv = 3, q = "To swap a and b, why do we need a temp variable?", a = "Otherwise one value is lost", d = { "Temp makes it faster", "Swapping needs three robots", "It is not needed" }, why = "Setting a = b first would erase a's old value, so we save it in temp." },
  { lv = 3, q = "Which name is clearest for a robot's battery level?", a = "battery", d = { "x", "thing", "zzz" }, why = "Good variable names say what they hold.", t = { "battery" } },
}

-- MAGISTER: functions -----------------------------------------------------------
D.FUNCS = {
  { lv = 1, q = "A function is...", a = "A named set of steps you can use again", d = { "A broken step", "A number", "The end of a program" }, why = "Functions bundle steps under a name so you can reuse them." },
  { lv = 1, q = "In 'function boost(n)', what is n?", a = "A parameter (an input)", d = { "The output", "A loop", "A bug" }, why = "Parameters are the inputs a function gets when it is called." },
  { lv = 2, q = "What does 'return' do in a function?", a = "Sends a value back", d = { "Starts the program again", "Deletes the function", "Repeats forever" }, why = "return hands the answer back to whoever called the function." },
  { lv = 2, q = "Why write a function instead of copying the same steps 5 times?", a = "Write once, use many times", d = { "Copies run faster", "Functions are longer", "It hides mistakes" }, why = "Functions avoid repeats and make fixes happen in one place." },
  { lv = 2, q = "Running a function by its name is called...", a = "Calling it", d = { "Hiding it", "Looping it", "Erasing it" }, why = "We call a function to make its steps run." },
  { lv = 3, q = "function add(a, b) return a + b end. What is add(7, 5)?", a = "12", d = { "75", "2", "35" }, why = "a gets 7, b gets 5, and 7 + 5 = 12.", t = { "12", "twelve" } },
  { lv = 3, q = "A function with no return value is often used to...", a = "Do an action, like move or beep", d = { "Hold a number", "Stop all programs", "Make a variable" }, why = "Some functions just do something instead of giving a value back." },
  { lv = 3, q = "function sq(n) return n * n end. What is sq(sq(2))?", a = "16", d = { "4", "8", "6" }, why = "sq(2) = 4, then sq(4) = 16. The inside runs first.", t = { "16", "sixteen" } },
}

-- MAGISTER: boolean logic ---------------------------------------------------------
D.BOOL = {
  { lv = 1, q = "A boolean can only be...", a = "True or false", d = { "Any number", "A word", "Up or down" }, why = "Booleans have just two values: true and false." },
  { lv = 1, q = "What is 'not true'?", a = "False", d = { "True", "Maybe", "Zero" }, why = "not flips a boolean.", t = { "false" } },
  { lv = 2, q = "true and false = ?", a = "False", d = { "True", "Both", "Maybe" }, why = "and is only true when BOTH sides are true.", t = { "false" } },
  { lv = 2, q = "true or false = ?", a = "True", d = { "False", "Neither", "Maybe" }, why = "or is true when AT LEAST ONE side is true.", t = { "true" } },
  { lv = 2, q = "A door opens if you have a key OR know the password. You know the password only. Open?", a = "Yes", d = { "No", "Only halfway", "Only with a key" }, why = "With or, one true side is enough.", t = { "yes" } },
  { lv = 3, q = "not (true and false) = ?", a = "True", d = { "False", "Error", "Maybe" }, why = "Inside first: true and false = false. not false = true.", t = { "true" } },
  { lv = 3, q = "(false or false) and true = ?", a = "False", d = { "True", "Both", "Error" }, why = "false or false = false, and false and true = false.", t = { "false" } },
  { lv = 3, q = "Which is true when x = 5?", a = "x > 3 and x < 9", d = { "x > 6", "x < 2 or x > 8", "not (x = 5)" }, why = "5 is greater than 3 and less than 9, so both sides are true." },
}

-- MAGISTER: algorithms --------------------------------------------------------------
D.ALGO = {
  { lv = 1, q = "An algorithm is...", a = "Clear steps that solve a problem", d = { "A type of robot", "A random guess", "A drawing" }, why = "Algorithms are step-by-step recipes for solving problems." },
  { lv = 1, q = "To find the tallest kid in a line, a good algorithm is...", a = "Compare each kid with the tallest so far", d = { "Pick the first kid", "Pick a random kid", "Ask the shortest kid" }, why = "Keep the best so far and check everyone once." },
  { lv = 2, q = "Guess my number from 1 to 100. Best first guess?", a = "50", d = { "1", "99", "7" }, why = "Guessing the middle cuts the choices in half each time.", t = { "50", "fifty" } },
  { lv = 2, q = "Sorting means...", a = "Putting things in order", d = { "Throwing things away", "Counting things", "Painting things" }, why = "A sorted list goes in order, like smallest to biggest." },
  { lv = 2, q = "A list is sorted. Halving to find a number is called...", a = "Binary search", d = { "Bubble sort", "Endless loop", "Guess and pray" }, why = "Binary search checks the middle and throws away half each time." },
  { lv = 3, q = "With halving, how many guesses at most to find a number from 1 to 16?", a = "5", d = { "16", "8", "2" }, why = "16, 8, 4, 2, 1: at most 5 guesses.", t = { "5", "five" } },
  { lv = 3, q = "Checking items one by one from the start is called...", a = "Linear search", d = { "Binary search", "Recursion", "Sorting" }, why = "Linear search walks the list in a straight line.", t = { "linear search", "linear" } },
  { lv = 3, q = "Why is binary search faster than linear search on a big sorted list?", a = "It skips half the list each check", d = { "It checks every item twice", "It only works on 3 items", "It is not faster" }, why = "Halving each time needs far fewer checks." },
}

-- MAGISTER: reading pseudocode --------------------------------------------------------
D.PSEUDO = {
  { lv = 1, q = "total = 0\nFOR each coin in purse:\n  total = total + coin\nWhat does this find?", a = "The total of all coins", d = { "The biggest coin", "How many purses", "The first coin" }, why = "It adds every coin into total." },
  { lv = 1, q = "count = 0\nFOR each gear in box:\n  count = count + 1\nWhat does this find?", a = "How many gears there are", d = { "The heaviest gear", "The last gear", "Nothing" }, why = "It adds 1 for every gear, so it counts them." },
  { lv = 2, q = "best = list[1]\nFOR each n in list:\n  IF n > best THEN best = n\nWhat is best at the end?", a = "The biggest number", d = { "The smallest number", "The first number", "The sum" }, why = "best only changes when a bigger number shows up." },
  { lv = 2, q = "FOR i = 1 TO 3:\n  PRINT 'tick'\nHow many ticks print?", a = "3", d = { "1", "2", "4" }, why = "i goes 1, 2, 3: three times.", t = { "3", "three" } },
  { lv = 2, q = "IF fuel = 0 THEN PRINT 'empty'\nfuel is 4. What prints?", a = "Nothing", d = { "empty", "4", "0" }, why = "4 is not 0, so PRINT is skipped." },
  { lv = 3, q = "n = 10\nWHILE n > 0:\n  n = n - 3\nWhat is n at the end?", a = "-2", d = { "0", "1", "-3" }, why = "10, 7, 4, 1, -2. The loop stops once n is not above 0.", t = { "-2" } },
  { lv = 3, q = "out = ''\nFOR each letter in 'cog':\n  out = letter + out\nWhat is out?", a = "goc", d = { "cog", "ccc", "gco" }, why = "Each new letter goes in front, so the word comes out backwards.", t = { "goc" } },
  { lv = 3, q = "found = false\nFOR each n in [4, 9, 2]:\n  IF n = 9 THEN found = true\nWhat is found?", a = "True", d = { "False", "9", "2" }, why = "9 is in the list, so found becomes true.", t = { "true" } },
}

-- Blueprint Binder: one page per skill tier (Spark/Rune/Glyph). Icons are in-game icons.
local I = "Interface\\Icons\\"
local function bp(name, zone, icon, note) return { name = name, zone = zone, icon = I .. icon, note = note } end
D.BLUEPRINTS = {
  ge_sequence = {
    bp("Step-by-Step Toaster", "Breakfast in the right order", "INV_Misc_Gear_03", "Bread in, lever down, wait, pop! Swap any two steps and breakfast is ruined."),
    bp("Morning Routine Clock", "Waking up on time", "INV_Misc_PocketWatch_01", "It chimes each step of the morning in order, so nothing gets skipped."),
    bp("Recipe Reader Mk II", "Cooking without mistakes", "INV_Misc_Note_01", "Reads one step at a time and refuses to bake before you mix."),
  },
  ge_patterns = {
    bp("Pattern Loom", "Weaving striped scarves", "INV_Misc_Gear_04", "Gear, bolt, gear, bolt: it spots a pattern and keeps it going."),
    bp("Chime Organ", "Music that repeats", "INV_Misc_Gear_05", "Songs are patterns too. Find the part that repeats and you can play it forever."),
    bp("Tile Layer 3000", "Floors with neat designs", "INV_Misc_Gear_06", "It lays tiles in repeating units, never missing a beat."),
  },
  ge_directions = {
    bp("Compass Cart", "Rolling where you point", "Ability_Mount_MechaStrider", "Up, down, left, right: four simple moves can reach any square."),
    bp("Grid Walker", "Mapping the workshop floor", "INV_Misc_Map_01", "Counts each square it rolls over and always knows where it is."),
    bp("Delivery Strider", "Bringing gears to the right desk", "INV_Misc_Bag_10", "Follows a route of arrows to drop parts off exactly on target."),
  },
  ge_program = {
    bp("Punch-Card Reader", "Running programs from cards", "INV_Misc_Note_02", "Each hole is a command. Line them up and Boltby follows them."),
    bp("Route Planner", "Finding the way around walls", "INV_Misc_Map_01", "It tries routes in its head before Boltby takes a single step."),
    bp("Autopilot Wheel", "Steering without hands", "INV_Misc_Gear_07", "Load a program, press go, and the wheel does the rest."),
  },
  ge_turns = {
    bp("Spinning Turret", "Facing the right way", "INV_Misc_Gear_08", "Turn left, turn right: turning changes which way forward goes."),
    bp("Weathervane Bot", "Always knowing north", "INV_Misc_Spyglass_03", "It remembers its facing after every turn, no matter how many."),
    bp("Maze Runner", "Escaping twisty tunnels", "INV_Misc_Spyglass_01", "Forward, turn, forward: it walks mazes using only three commands."),
  },
  ge_loops = {
    bp("Repeat-O-Matic", "Doing a job many times", "INV_Misc_Gear_02", "Why write Forward ten times? Write Repeat 10 once."),
    bp("Drum Machine", "Beats that loop", "INV_Misc_Bag_10", "A loop of four beats, played again and again, makes a song."),
    bp("Gear Counter", "Adding up in a loop", "INV_Misc_Coin_01", "Each loop adds a few gears to the pile. Count the loops, know the pile."),
  },
  ge_loopgrid = {
    bp("Staircase Climber", "Climbing step after step", "INV_Misc_Gear_01", "Repeat: right, up. Two moves in a loop climb any staircase."),
    bp("Lawn Mower Bot", "Neat stripes on the grass", "INV_Misc_Herb_10", "It loops the same row pattern until the whole lawn is done."),
    bp("Spiral Sweeper", "Cleaning in circles", "INV_Misc_Orb_01", "Loops inside loops sweep a room in a perfect spiral."),
  },
  ge_conditionals = {
    bp("Smart Lamp", "Light only when dark", "INV_Misc_Lantern_01", "IF dark THEN light on ELSE light off. One check, every second."),
    bp("Gate Keeper", "Opening for friends", "INV_Misc_Key_03", "It checks a condition and only then decides what to do."),
    bp("Rain Detector", "Umbrella reminders", "Spell_Frost_IceStorm", "IF raining THEN beep. Conditions let machines react."),
  },
  ge_debug = {
    bp("Bug Magnifier", "Spotting mistakes", "INV_Misc_Spyglass_02", "Walk the program one step at a time and the bug has nowhere to hide."),
    bp("Wrench of Fixing", "Repairing programs", "INV_Misc_Wrench_01", "Find the wrong step, change it, test again. That's debugging."),
    bp("Test Bench", "Checking every change", "INV_Misc_Gear_04", "Test small, test often, and every bug is easy to catch."),
  },
  ge_events = {
    bp("Doorbell Chimer", "Ringing when pressed", "INV_Misc_Gear_01", "WHEN pressed THEN ring. Events wake programs up."),
    bp("Alarm Trap", "Waking sleepy tinkers", "INV_Misc_PocketWatch_02", "It waits for the timer event, then makes a big racket."),
    bp("Workshop Planner", "Big jobs in small parts", "INV_Misc_Note_03", "Split one huge job into small ones. Each part is easy to build."),
  },
  ge_variables = {
    bp("Labeled Parts Bin", "Storing values", "INV_Box_01", "Each drawer has a name and holds one value. That is a variable."),
    bp("Fuel Gauge", "Values that change", "INV_Potion_15", "fuel = fuel - 1 every mile. The name stays, the value changes."),
    bp("Swap Station", "Trading two values", "INV_Misc_Bag_08", "Save one value in temp first, or it gets lost in the swap."),
  },
  ge_functions = {
    bp("Gear Press", "One job, used many times", "INV_Misc_Gear_05", "Put a number in, get a number back: a function you can call anytime."),
    bp("Spring Winder", "Reusable steps", "INV_Misc_Gear_06", "Wrap steps in a function and call it by name instead of copying."),
    bp("Nested Gearbox", "Functions inside functions", "INV_Misc_Gear_07", "Call one inside another. The inside one always runs first."),
  },
  ge_boolean = {
    bp("Logic Lock", "Two keys at once", "INV_Misc_Key_01", "AND opens only when both keys turn. OR opens with either one."),
    bp("Flip Switch", "Turning true to false", "INV_Misc_Rune_01", "not flips the switch: true becomes false, false becomes true."),
    bp("Sensor Panel", "Combining checks", "INV_Misc_Orb_01", "Brackets first, then not, then and, then or."),
  },
  ge_algorithms = {
    bp("Sorting Conveyor", "Lining parts up by size", "INV_Misc_Gear_08", "Swap neighbors that are out of order, pass after pass."),
    bp("Finder Goggles", "Searching fast", "INV_Misc_Spyglass_03", "Check the middle, throw away half. Big lists shrink fast."),
    bp("Tallest-Tower Meter", "Keeping the best so far", "INV_Misc_Gear_03", "Look at each one once and remember the best so far."),
  },
  ge_pseudocode = {
    bp("Plain-Words Compiler", "Reading code like a story", "INV_Misc_Note_04", "Pseudocode is code in plain words. Read it line by line."),
    bp("While Engine", "Running until done", "INV_Misc_PocketWatch_02", "WHILE keeps going until the check turns false."),
    bp("Master Schematic", "Planning a whole machine", "INV_Misc_Book_08", "Every great machine starts as clear steps on paper."),
  },
}

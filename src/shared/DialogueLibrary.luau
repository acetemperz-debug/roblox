--!nonstrict
-- DialogueLibrary
-- Every dialogue situation in the game, grouped by call stage.
--
-- IMPORTANT: all of this is deliberate nonsense. The "instructions" the player
-- gives are fictional (wizard windows, moon keys, imaginary store cards) so the
-- script cannot be lifted out of the game and used on a real person. Keep it
-- that way when adding content.
--
-- Situation fields:
--   id            unique string
--   stage         1..7 (see Config.Stages)
--   weight        relative pick weight (default 1)
--   prompt        array of NPC line variants
--   minLevel      minimum dialogue level (rank-gated situations)
--   personalities optional array of personality ids this situation is limited to
--   excludes      optional array of personality ids that never see it
--
-- Choice fields:
--   text      button label
--   tags      array of tag strings (see Personalities)
--   trust     base trust delta
--   suspicion base suspicion delta
--   patience  base patience delta
--   progress  stage progress delta (100 completes a stage)
--   minLevel  dialogue level required to select it (locked buttons below that)
--   note      short outcome hint shown after selection

local DialogueLibrary = {}

local S = {}

local function add(situation)
	table.insert(S, situation)
end

--------------------------------------------------------------------------------
-- STAGE 1 — INTRODUCTION
--------------------------------------------------------------------------------

add({
	id = "intro_why_calling",
	stage = 1,
	weight = 4,
	prompt = {
		"Why is Macrosoft calling me?",
		"Macrosoft? What do you want?",
		"Hang on — Macrosoft? Like the computer people?",
	},
	choices = {
		{ text = "We detected a serious problem with your computer.", tags = { "professional", "urgency" }, trust = 9, suspicion = 4, patience = 0, progress = 50 },
		{ text = "Your computer called us. It sounded upset.", tags = { "absurd", "humour" }, trust = 3, suspicion = 12, patience = 4, progress = 45 },
		{ text = "I'm actually not sure. Let me check my notes.", tags = { "honest" }, trust = 2, suspicion = 9, patience = -3, progress = 35 },
		{ text = "JUST LISTEN TO ME, SIR.", tags = { "aggressive" }, trust = -8, suspicion = 22, patience = -12, progress = 20 },
	},
})

add({
	id = "intro_who_is_this",
	stage = 1,
	weight = 4,
	prompt = {
		"Who is this exactly?",
		"Sorry, what was your name again?",
		"Right. And you are...?",
	},
	choices = {
		{ text = "My name is Kevin, I'm a senior technician at Macrosoft.", tags = { "professional", "authority" }, trust = 10, suspicion = 3, patience = 2, progress = 50 },
		{ text = "You can call me... Steve. Steve is fine. Steve.", tags = { "absurd", "humour" }, trust = 3, suspicion = 11, patience = 3, progress = 45 },
		{ text = "That's not important right now, sir.", tags = { "deflect", "authority" }, trust = -2, suspicion = 16, patience = -4, progress = 40 },
		{ text = "Honestly? I've had four names today.", tags = { "honest", "humour" }, trust = 4, suspicion = 14, patience = 6, progress = 40 },
	},
})

add({
	id = "intro_how_number",
	stage = 1,
	weight = 3,
	prompt = {
		"How did you get my number?",
		"Where did you get this number from?",
		"This is an unlisted number, actually.",
	},
	choices = {
		{ text = "It's registered to your Macrosoft licence, sir.", tags = { "professional", "technical" }, trust = 9, suspicion = 5, patience = 0, progress = 50 },
		{ text = "The computer gave it to us when it reported the fault.", tags = { "technical", "absurd" }, trust = 5, suspicion = 10, patience = 0, progress = 45 },
		{ text = "A friend of yours gave it to me. A close friend.", tags = { "absurd" }, trust = -3, suspicion = 20, patience = -5, progress = 35 },
		{ text = "I'd rather not say, sir.", tags = { "deflect" }, trust = -4, suspicion = 18, patience = -4, progress = 35 },
	},
})

add({
	id = "intro_bad_time",
	stage = 1,
	weight = 3,
	prompt = {
		"This is a really bad time.",
		"I'm in the middle of something.",
		"Can you call back later?",
	},
	choices = {
		{ text = "I understand completely — this will take two minutes.", tags = { "empathy", "reassuring" }, trust = 11, suspicion = 1, patience = 8, progress = 50 },
		{ text = "Sir, this cannot wait. Your files are at risk RIGHT NOW.", tags = { "urgency" }, trust = 5, suspicion = 12, patience = -6, progress = 50 },
		{ text = "Of course. What time suits you? ...Now? Perfect.", tags = { "humour", "professional" }, trust = 7, suspicion = 6, patience = 4, progress = 45 },
		{ text = "No. Stay on the line.", tags = { "aggressive", "authority" }, trust = -10, suspicion = 24, patience = -14, progress = 25 },
	},
})

add({
	id = "intro_already_called",
	stage = 1,
	weight = 2,
	prompt = {
		"You people called me last week as well.",
		"Didn't someone from your company already ring about this?",
		"Is this the same thing as last time?",
	},
	choices = {
		{ text = "Yes — and the problem has come back worse, I'm afraid.", tags = { "professional", "urgency" }, trust = 10, suspicion = 5, patience = 0, progress = 50 },
		{ text = "That was a different department. They're useless.", tags = { "humour", "deflect" }, trust = 6, suspicion = 9, patience = 3, progress = 45 },
		{ text = "No, that was definitely somebody else pretending to be us.", tags = { "honest", "reassuring" }, trust = 4, suspicion = 13, patience = 2, progress = 40 },
		{ text = "Sir, I have no record of a previous call, so it did not happen.", tags = { "authority" }, trust = -3, suspicion = 17, patience = -6, progress = 35 },
	},
})

add({
	id = "intro_hello_hello",
	stage = 1,
	weight = 2,
	prompt = {
		"Hello? Hello? I can't hear you very well.",
		"You sound like you're in a wind tunnel.",
		"There's an awful lot of noise on your end.",
	},
	choices = {
		{ text = "Apologies sir — our office is very busy today.", tags = { "professional", "reassuring" }, trust = 8, suspicion = 4, patience = 3, progress = 50 },
		{ text = "That's our new air conditioning. Very powerful.", tags = { "humour", "absurd" }, trust = 5, suspicion = 8, patience = 5, progress = 45 },
		{ text = "It's a large support centre, sir. Hundreds of technicians.", tags = { "professional", "authority" }, trust = 7, suspicion = 7, patience = 0, progress = 45 },
		{ text = "CAN YOU HEAR ME NOW? CAN YOU?", tags = { "aggressive" }, trust = -7, suspicion = 20, patience = -12, progress = 25 },
	},
})

add({
	id = "intro_expert_credentials",
	stage = 1,
	weight = 2,
	minLevel = 2,
	prompt = {
		"Give me your employee number and I'll verify it.",
		"What's your direct line? I'll call you back.",
		"Which office are you calling from?",
	},
	choices = {
		{ text = "Technician ID 44-B, Northern Support Hub. I'll hold while you check.", tags = { "professional", "technical" }, trust = 14, suspicion = 2, patience = 3, progress = 55, minLevel = 2 },
		{ text = "I'd love to give you that but our lines are outbound only, sir.", tags = { "professional", "deflect" }, trust = 6, suspicion = 10, patience = 0, progress = 45 },
		{ text = "Employee number... seven. Just seven.", tags = { "absurd" }, trust = 1, suspicion = 16, patience = 2, progress = 35 },
		{ text = "You don't need that. Let's move on.", tags = { "deflect", "authority" }, trust = -6, suspicion = 21, patience = -6, progress = 30 },
	},
})

add({
	id = "intro_streamer_hello",
	stage = 1,
	weight = 3,
	personalities = { "scambaiter", "prank_caller", "tech_teen", "bored_student" },
	prompt = {
		"Before we start — can you say hello to my friends?",
		"Quick thing: can you spell your name for the group chat?",
		"Sorry, can you repeat that into the good microphone?",
	},
	choices = {
		{ text = "Sir, I am not going to do that. Let's continue.", tags = { "professional" }, trust = 4, suspicion = 8, patience = -2, progress = 45 },
		{ text = "Hello, friends of the sir. It's Kevin.", tags = { "humour", "absurd" }, trust = 10, suspicion = 6, patience = 10, progress = 50 },
		{ text = "Are you recording this?", tags = { "honest" }, trust = 2, suspicion = 14, patience = 0, progress = 35 },
		{ text = "NO MORE GAMES, SIR.", tags = { "aggressive" }, trust = -9, suspicion = 22, patience = -10, progress = 20 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 2 — THE FICTIONAL PROBLEM
--------------------------------------------------------------------------------

add({
	id = "problem_what_problem",
	stage = 2,
	weight = 4,
	prompt = {
		"What sort of problem are we talking about?",
		"What's actually wrong with it?",
		"Define 'serious problem' for me.",
	},
	choices = {
		{ text = "Your machine is sending out 40,000 distress pings an hour.", tags = { "technical", "urgency" }, trust = 10, suspicion = 6, patience = 0, progress = 50 },
		{ text = "There's a fault in your licence registry. It's very common.", tags = { "technical", "reassuring" }, trust = 12, suspicion = 4, patience = 2, progress = 50 },
		{ text = "Frankly sir, it's full of bees. Digital ones.", tags = { "absurd", "humour" }, trust = 2, suspicion = 15, patience = 6, progress = 40 },
		{ text = "It's complicated and you wouldn't understand it.", tags = { "authority", "technical" }, trust = -5, suspicion = 19, patience = -8, progress = 30 },
	},
})

add({
	id = "problem_which_computer",
	stage = 2,
	weight = 4,
	prompt = {
		"Which computer? I've got three.",
		"I don't even own a computer.",
		"Do you mean the laptop or the tablet?",
	},
	choices = {
		{ text = "The one registered at this address, sir. It'll be the main one.", tags = { "professional", "deflect" }, trust = 9, suspicion = 6, patience = 0, progress = 50 },
		{ text = "All of them, sir. It spreads.", tags = { "urgency", "technical" }, trust = 6, suspicion = 11, patience = -2, progress = 45 },
		{ text = "The grey one. It's usually the grey one.", tags = { "absurd", "humour" }, trust = 3, suspicion = 13, patience = 5, progress = 40 },
		{ text = "Sir, you DO own a computer. Our system says so.", tags = { "authority" }, trust = -6, suspicion = 20, patience = -8, progress = 30 },
	},
})

add({
	id = "problem_how_do_you_know",
	stage = 2,
	weight = 3,
	prompt = {
		"How would you know what my computer is doing?",
		"You can see my computer from there, can you?",
		"That sounds like something you'd have to be inside my house to know.",
	},
	choices = {
		{ text = "Every licensed machine reports its health to us automatically.", tags = { "technical", "professional" }, trust = 11, suspicion = 5, patience = 0, progress = 50 },
		{ text = "It flagged itself, sir. We only see the warning, not your files.", tags = { "reassuring", "technical" }, trust = 13, suspicion = 3, patience = 2, progress = 55 },
		{ text = "I can see everything. I am watching you right now.", tags = { "absurd", "aggressive" }, trust = -12, suspicion = 30, patience = -10, progress = 20 },
		{ text = "Magic, sir. Corporate magic.", tags = { "humour", "absurd" }, trust = 3, suspicion = 14, patience = 7, progress = 40 },
	},
})

add({
	id = "problem_is_it_serious",
	stage = 2,
	weight = 3,
	prompt = {
		"Is it serious? Should I be worried?",
		"Am I going to lose my photos?",
		"Oh no. Is it bad?",
	},
	choices = {
		{ text = "It's serious, but it's fixable. That's why we called first.", tags = { "reassuring", "professional" }, trust = 14, suspicion = 2, patience = 4, progress = 55 },
		{ text = "Extremely serious. You may have minutes, sir.", tags = { "urgency" }, trust = 6, suspicion = 13, patience = -5, progress = 45 },
		{ text = "Your photos are already halfway to Belgium.", tags = { "absurd", "humour" }, trust = 1, suspicion = 17, patience = 4, progress = 35 },
		{ text = "Not really. It's mostly fine, honestly.", tags = { "honest" }, trust = 5, suspicion = 9, patience = 3, progress = 30 },
	},
})

add({
	id = "problem_jargon_test",
	stage = 2,
	weight = 3,
	prompt = {
		"Name the process that's causing it.",
		"Which service exactly? I'll look it up.",
		"Give me the error code then.",
	},
	choices = {
		{ text = "Error 0x-MACRO-9. It's an internal reference, sir.", tags = { "technical", "professional" }, trust = 10, suspicion = 7, patience = 0, progress = 50 },
		{ text = "It's a licensing fault, the code won't mean anything to you.", tags = { "deflect", "technical" }, trust = 4, suspicion = 13, patience = -3, progress = 40 },
		{ text = "Honestly sir, I read these off a laminated card.", tags = { "honest", "humour" }, trust = 7, suspicion = 12, patience = 8, progress = 40 },
		{ text = "The, er... the big one. The main process.", tags = { "absurd" }, trust = -3, suspicion = 19, patience = -2, progress = 30 },
	},
})

add({
	id = "problem_turned_off",
	stage = 2,
	weight = 2,
	prompt = {
		"My computer's been switched off for a month.",
		"It's not even plugged in.",
		"I only turn it on at Christmas.",
	},
	choices = {
		{ text = "That's exactly why the warnings queued up, sir.", tags = { "technical", "reassuring" }, trust = 11, suspicion = 6, patience = 2, progress = 50 },
		{ text = "The fault reports even when it's off. That's the problem.", tags = { "technical", "absurd" }, trust = 4, suspicion = 14, patience = 0, progress = 40 },
		{ text = "Ah. Then this call makes no sense at all, does it.", tags = { "honest", "humour" }, trust = 8, suspicion = 10, patience = 9, progress = 40 },
		{ text = "Go and plug it in. Now.", tags = { "aggressive", "authority" }, trust = -9, suspicion = 23, patience = -12, progress = 25 },
	},
})

add({
	id = "problem_neighbour_fixes",
	stage = 2,
	weight = 2,
	prompt = {
		"My neighbour does computers. I'll ask him.",
		"My grandson handles all this for me.",
		"I've got a guy for this sort of thing.",
	},
	choices = {
		{ text = "Of course — though this is a licence-side fault, only we can clear it.", tags = { "professional", "technical" }, trust = 11, suspicion = 6, patience = 0, progress = 50 },
		{ text = "By all means. We'll still be here when he can't fix it.", tags = { "humour", "professional" }, trust = 8, suspicion = 8, patience = 2, progress = 45 },
		{ text = "Your grandson is not authorised, sir.", tags = { "authority" }, trust = -7, suspicion = 21, patience = -9, progress = 25 },
		{ text = "Honestly, he'd probably do a better job than me.", tags = { "honest", "humour" }, trust = 6, suspicion = 11, patience = 7, progress = 35 },
	},
})

add({
	id = "problem_expert_deep",
	stage = 2,
	weight = 2,
	minLevel = 3,
	prompt = {
		"Walk me through the diagnostic chain, then.",
		"You've got logs? Read me a line.",
		"Which node flagged it, and when?",
	},
	choices = {
		{ text = "Node 12, flagged 04:11 your time, escalated twice since.", tags = { "technical", "professional" }, trust = 16, suspicion = 4, patience = 2, progress = 60, minLevel = 3 },
		{ text = "I'm not permitted to read logs aloud. Data protection, sir.", tags = { "professional", "deflect" }, trust = 7, suspicion = 11, patience = 0, progress = 45 },
		{ text = "The chain goes: computer, wire, us. That's the chain.", tags = { "absurd", "humour" }, trust = 2, suspicion = 18, patience = 5, progress = 35 },
		{ text = "You're asking too many questions, sir.", tags = { "aggressive", "deflect" }, trust = -10, suspicion = 26, patience = -10, progress = 20 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 3 — BUILDING RAPPORT
--------------------------------------------------------------------------------

add({
	id = "trust_small_talk",
	stage = 3,
	weight = 4,
	prompt = {
		"Sorry, I'm just a bit wary of phone calls these days.",
		"You'll have to bear with me, I'm not good with this.",
		"I don't usually talk to anyone before noon, you know.",
	},
	choices = {
		{ text = "Completely understandable. We'll go at your pace, sir.", tags = { "empathy", "patience" }, trust = 15, suspicion = 0, patience = 10, progress = 55 },
		{ text = "You're being sensible. Most people aren't careful enough.", tags = { "flattery", "reassuring" }, trust = 12, suspicion = 4, patience = 4, progress = 50 },
		{ text = "Terrible weather where you are, isn't it?", tags = { "smalltalk" }, trust = 8, suspicion = 5, patience = 8, progress = 40 },
		{ text = "Then stop talking and listen.", tags = { "aggressive" }, trust = -12, suspicion = 25, patience = -15, progress = 20 },
	},
})

add({
	id = "trust_compliment",
	stage = 3,
	weight = 3,
	prompt = {
		"I'm not completely useless with computers, you know.",
		"I did a course on this in 1998.",
		"I'm quite good with technology, actually.",
	},
	choices = {
		{ text = "I can tell — you're asking better questions than most.", tags = { "flattery", "empathy" }, trust = 13, suspicion = 4, patience = 6, progress = 50 },
		{ text = "Then you'll understand the licence registry fault perfectly.", tags = { "technical", "professional" }, trust = 10, suspicion = 7, patience = 0, progress = 50 },
		{ text = "1998 was a while ago, sir.", tags = { "humour" }, trust = 4, suspicion = 10, patience = -2, progress = 35 },
		{ text = "Clearly not, or we wouldn't be talking.", tags = { "aggressive" }, trust = -13, suspicion = 24, patience = -14, progress = 20 },
	},
})

add({
	id = "trust_reassure",
	stage = 3,
	weight = 4,
	prompt = {
		"You're not going to ask for my bank details, are you?",
		"I'm not giving out any card numbers.",
		"If this is about money I'm hanging up.",
	},
	choices = {
		{ text = "Absolutely not. We never ask for banking details, sir.", tags = { "reassuring", "professional" }, trust = 16, suspicion = 2, patience = 6, progress = 55 },
		{ text = "You should never give those out. Not to anyone. Including me.", tags = { "honest", "reassuring" }, trust = 14, suspicion = 3, patience = 8, progress = 55 },
		{ text = "There's no charge for the fix itself, sir.", tags = { "professional" }, trust = 9, suspicion = 8, patience = 0, progress = 45 },
		{ text = "We'll discuss payment later.", tags = { "honest", "urgency" }, trust = -4, suspicion = 22, patience = -6, progress = 30 },
	},
})

add({
	id = "trust_personal",
	stage = 3,
	weight = 3,
	prompt = {
		"Where are you calling from, anyway?",
		"You don't sound local.",
		"What's it like where you are?",
	},
	choices = {
		{ text = "Our support hub, sir. Fourteen floors and terrible coffee.", tags = { "humour", "smalltalk" }, trust = 12, suspicion = 5, patience = 9, progress = 50 },
		{ text = "A regional Macrosoft office. Nothing exciting.", tags = { "professional", "deflect" }, trust = 9, suspicion = 6, patience = 2, progress = 45 },
		{ text = "Honestly sir? A room with 200 people all saying this.", tags = { "honest", "humour" }, trust = 7, suspicion = 16, patience = 12, progress = 40 },
		{ text = "That's confidential information.", tags = { "deflect", "authority" }, trust = -5, suspicion = 18, patience = -5, progress = 30 },
	},
})

add({
	id = "trust_shared_pain",
	stage = 3,
	weight = 3,
	prompt = {
		"Everything's a scam these days, isn't it.",
		"I get six of these calls a week.",
		"You can't trust anyone on the phone anymore.",
	},
	choices = {
		{ text = "You're right, and it makes my job ten times harder.", tags = { "empathy", "honest" }, trust = 16, suspicion = 3, patience = 10, progress = 55 },
		{ text = "It's awful. That's exactly why we verify everything, sir.", tags = { "reassuring", "professional" }, trust = 13, suspicion = 5, patience = 5, progress = 50 },
		{ text = "Terrible people out there. Anyway — about that fault.", tags = { "deflect", "professional" }, trust = 8, suspicion = 8, patience = 0, progress = 45 },
		{ text = "This isn't one of those calls, I promise, I swear, honestly.", tags = { "reassuring", "urgency" }, trust = 2, suspicion = 17, patience = -3, progress = 35 },
	},
})

add({
	id = "trust_patience_test",
	stage = 3,
	weight = 3,
	prompt = {
		"Slow down, I'm still finding my glasses.",
		"Hang on, hang on. One thing at a time.",
		"You're going too fast for me.",
	},
	choices = {
		{ text = "Take all the time you need, sir. I'm not going anywhere.", tags = { "patience", "empathy" }, trust = 17, suspicion = 0, patience = 14, progress = 55 },
		{ text = "Of course. Shall I wait, or talk you through it slowly?", tags = { "patience", "professional" }, trust = 14, suspicion = 2, patience = 10, progress = 50 },
		{ text = "Sir, every second counts here.", tags = { "urgency" }, trust = 3, suspicion = 14, patience = -8, progress = 40 },
		{ text = "HURRY UP.", tags = { "aggressive" }, trust = -16, suspicion = 28, patience = -18, progress = 15 },
	},
})

add({
	id = "trust_family",
	stage = 3,
	weight = 2,
	prompt = {
		"My daughter says I shouldn't talk to people who ring up.",
		"My wife's giving me a look from the kitchen.",
		"My son handles all my important calls.",
	},
	choices = {
		{ text = "She's absolutely right to say that. Would you like her on the line?", tags = { "honest", "reassuring" }, trust = 15, suspicion = 4, patience = 8, progress = 55 },
		{ text = "Very sensible family, sir. Ours is a verified support line.", tags = { "flattery", "professional" }, trust = 11, suspicion = 7, patience = 4, progress = 50 },
		{ text = "There's really no need to involve anyone else.", tags = { "deflect", "urgency" }, trust = -6, suspicion = 24, patience = -6, progress = 30 },
		{ text = "Your family cannot help with a licence registry fault, sir.", tags = { "authority", "technical" }, trust = -3, suspicion = 19, patience = -7, progress = 30 },
	},
})

add({
	id = "trust_level3_mirror",
	stage = 3,
	weight = 2,
	minLevel = 2,
	prompt = {
		"Go on then. Convince me.",
		"Alright. Why should I trust you?",
		"Give me one good reason to stay on this call.",
	},
	choices = {
		{ text = "You shouldn't, on principle. Check us yourself while I hold.", tags = { "honest", "professional" }, trust = 18, suspicion = 4, patience = 8, progress = 60, minLevel = 2 },
		{ text = "Because I've not asked you for a single thing yet, sir.", tags = { "reassuring", "honest" }, trust = 15, suspicion = 5, patience = 5, progress = 55 },
		{ text = "Because I'm the only person who's noticed your machine screaming.", tags = { "urgency", "humour" }, trust = 9, suspicion = 11, patience = 2, progress = 45 },
		{ text = "Because I said so, sir.", tags = { "authority", "aggressive" }, trust = -14, suspicion = 26, patience = -12, progress = 20 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 4 — MANAGING SUSPICION
--------------------------------------------------------------------------------

add({
	id = "deflect_googling",
	stage = 4,
	weight = 4,
	prompt = {
		"Hang on, I'm searching 'Macrosoft Support' now...",
		"I'm looking your company up as we speak.",
		"Let me just check this online a second.",
	},
	choices = {
		{ text = "Please do. Search results take a moment — I'll wait quietly.", tags = { "patience", "professional" }, trust = 14, suspicion = 4, patience = 8, progress = 55 },
		{ text = "Of course, sir. You'll find us under 'Macrosoft Technical'.", tags = { "professional", "reassuring" }, trust = 11, suspicion = 7, patience = 3, progress = 50 },
		{ text = "Don't believe everything you read online, sir.", tags = { "deflect" }, trust = -4, suspicion = 22, patience = -5, progress = 30 },
		{ text = "NO. PUT THE COMPUTER DOWN.", tags = { "aggressive", "urgency" }, trust = -18, suspicion = 34, patience = -16, progress = 10 },
	},
})

add({
	id = "deflect_sounds_like_scam",
	stage = 4,
	weight = 5,
	prompt = {
		"This sounds exactly like a scam.",
		"I've heard about this on the radio.",
		"Mate, this is obviously a scam, isn't it.",
	},
	choices = {
		{ text = "I'd think the same in your position, sir. Ask me anything.", tags = { "empathy", "honest" }, trust = 16, suspicion = 5, patience = 8, progress = 55 },
		{ text = "There are a lot of fakes out there. We're the ones reporting them.", tags = { "reassuring", "professional" }, trust = 12, suspicion = 9, patience = 3, progress = 50 },
		{ text = "If I were a scammer I'd be much better at this, sir.", tags = { "humour", "honest" }, trust = 13, suspicion = 8, patience = 9, progress = 50 },
		{ text = "How DARE you accuse me.", tags = { "aggressive" }, trust = -20, suspicion = 34, patience = -16, progress = 10 },
	},
})

add({
	id = "deflect_call_you_back",
	stage = 4,
	weight = 3,
	prompt = {
		"I'll call you back on the number on your website.",
		"Give me the official number and I'll ring in.",
		"I'd rather do this through the proper channel.",
	},
	choices = {
		{ text = "Absolutely — though the queue is four hours. I can do it now.", tags = { "professional", "urgency" }, trust = 10, suspicion = 9, patience = 0, progress = 50 },
		{ text = "That's the safest thing to do, sir. Genuinely.", tags = { "honest", "reassuring" }, trust = 15, suspicion = 6, patience = 7, progress = 50 },
		{ text = "Our inbound line has been down since Tuesday.", tags = { "deflect", "technical" }, trust = 3, suspicion = 17, patience = -3, progress = 40 },
		{ text = "There is no other number, sir. Only me.", tags = { "absurd", "authority" }, trust = -9, suspicion = 27, patience = -9, progress = 25 },
	},
})

add({
	id = "deflect_accent",
	stage = 4,
	weight = 3,
	prompt = {
		"You don't sound like you're calling from the head office.",
		"Where are you REALLY calling from?",
		"Funny, the last four scammers had the same background noise.",
	},
	choices = {
		{ text = "We're an international company, sir. I'm in a support hub.", tags = { "professional", "honest" }, trust = 12, suspicion = 6, patience = 3, progress = 50 },
		{ text = "You've got a good ear, sir. Most people don't notice.", tags = { "flattery", "honest" }, trust = 10, suspicion = 9, patience = 6, progress = 45 },
		{ text = "I'm in a shed. A corporate shed.", tags = { "humour", "absurd" }, trust = 6, suspicion = 14, patience = 10, progress = 40 },
		{ text = "That's a very rude thing to say, sir.", tags = { "aggressive" }, trust = -11, suspicion = 24, patience = -10, progress = 25 },
	},
})

add({
	id = "deflect_manager_demand",
	stage = 4,
	weight = 3,
	prompt = {
		"Put me through to your manager.",
		"I want to speak to whoever's in charge of you.",
		"Is there a supervisor there?",
	},
	choices = {
		{ text = "I'll fetch my floor supervisor now. One moment, sir.", tags = { "professional", "patience" }, trust = 13, suspicion = 5, patience = 6, progress = 55 },
		{ text = "I am the supervisor, sir. Thirty years in the job.", tags = { "authority", "professional" }, trust = 7, suspicion = 12, patience = 0, progress = 45 },
		{ text = "My manager is currently shouting at somebody else, sir.", tags = { "honest", "humour" }, trust = 9, suspicion = 13, patience = 8, progress = 45 },
		{ text = "No. You speak to me.", tags = { "aggressive", "authority" }, trust = -15, suspicion = 28, patience = -14, progress = 20 },
	},
})

add({
	id = "deflect_i_work_in_it",
	stage = 4,
	weight = 3,
	personalities = { "cyber_pro", "tech_teen", "scambaiter", "off_duty_officer", "the_auditor", "small_biz_owner" },
	prompt = {
		"I literally work in IT.",
		"I do this for a living, you know.",
		"I run security for a living, actually.",
	},
	choices = {
		{ text = "Then you'll know exactly how rare this fault is, sir.", tags = { "technical", "professional" }, trust = 4, suspicion = 18, patience = 0, progress = 40 },
		{ text = "Then I've picked the worst possible house on this list.", tags = { "honest", "humour" }, trust = 14, suspicion = 9, patience = 12, progress = 55 },
		{ text = "Wonderful. A colleague. Let's speak plainly then, sir.", tags = { "honest", "empathy" }, trust = 11, suspicion = 11, patience = 6, progress = 50 },
		{ text = "No you don't.", tags = { "aggressive", "absurd" }, trust = -17, suspicion = 30, patience = -14, progress = 15 },
	},
})

add({
	id = "deflect_why_free",
	stage = 4,
	weight = 2,
	prompt = {
		"Why would you do this for free?",
		"What's in it for you, then?",
		"Nobody does anything for nothing.",
	},
	choices = {
		{ text = "Support is included in your licence, sir. It's already paid for.", tags = { "professional", "technical" }, trust = 13, suspicion = 5, patience = 2, progress = 55 },
		{ text = "Honestly? Bonus targets. I get a small bonus for each fix.", tags = { "honest", "empathy" }, trust = 11, suspicion = 10, patience = 6, progress = 50 },
		{ text = "Because I'm a lovely person, sir.", tags = { "humour", "flattery" }, trust = 8, suspicion = 12, patience = 8, progress = 45 },
		{ text = "That's not your concern.", tags = { "deflect", "aggressive" }, trust = -10, suspicion = 25, patience = -10, progress = 25 },
	},
})

add({
	id = "deflect_nightmare_pressure",
	stage = 4,
	weight = 2,
	minLevel = 4,
	prompt = {
		"I've recorded this whole call, you know.",
		"I've got your voice, your script, and your timing.",
		"I've been writing down everything you've said.",
	},
	choices = {
		{ text = "That's your right, sir. I've nothing to hide on a support call.", tags = { "professional", "honest" }, trust = 14, suspicion = 8, patience = 6, progress = 55, minLevel = 4 },
		{ text = "Excellent. Please spell my name correctly: K-E-V-I-N.", tags = { "humour", "honest" }, trust = 12, suspicion = 10, patience = 10, progress = 50 },
		{ text = "Recording without consent is illegal, sir.", tags = { "authority", "deflect" }, trust = -8, suspicion = 26, patience = -8, progress = 25 },
		{ text = "DELETE THAT.", tags = { "aggressive" }, trust = -22, suspicion = 36, patience = -18, progress = 10 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 5 — FICTIONAL INSTRUCTIONS
--------------------------------------------------------------------------------
-- Everything the player asks for here is made up nonsense on purpose.

add({
	id = "instr_open_wizard",
	stage = 5,
	weight = 4,
	prompt = {
		"Alright. What do you want me to do?",
		"Okay, I'm at the computer. Now what?",
		"Right, it's on. Talk me through it.",
	},
	choices = {
		{ text = "Open the Blue Wizard Window — the one shaped like a hat.", tags = { "technical", "absurd" }, trust = 10, suspicion = 6, patience = 0, progress = 50 },
		{ text = "There's a moon-shaped key. Press it twice, gently.", tags = { "absurd", "humour" }, trust = 7, suspicion = 10, patience = 4, progress = 45 },
		{ text = "Take your time and tell me what you can see on screen.", tags = { "patience", "professional" }, trust = 14, suspicion = 3, patience = 8, progress = 55 },
		{ text = "PRESS EVERYTHING. NOW.", tags = { "aggressive", "urgency" }, trust = -16, suspicion = 30, patience = -16, progress = 15 },
	},
})

add({
	id = "instr_cant_find",
	stage = 5,
	weight = 4,
	prompt = {
		"I can't find a blue window. There's no hat.",
		"Nothing on my screen looks like that.",
		"It's just my photo of the dog on here.",
	},
	choices = {
		{ text = "That's fine — it's hidden on newer machines. Bottom left, sir.", tags = { "reassuring", "technical" }, trust = 12, suspicion = 5, patience = 5, progress = 50 },
		{ text = "Lovely dog. Now, look for anything faintly wizardy.", tags = { "humour", "smalltalk" }, trust = 11, suspicion = 7, patience = 10, progress = 50 },
		{ text = "Describe the screen to me and we'll find it together.", tags = { "patience", "empathy" }, trust = 15, suspicion = 2, patience = 10, progress = 55 },
		{ text = "It IS there. LOOK HARDER.", tags = { "aggressive" }, trust = -17, suspicion = 30, patience = -16, progress = 15 },
	},
})

add({
	id = "instr_what_does_it_do",
	stage = 5,
	weight = 3,
	prompt = {
		"What's this actually going to do?",
		"Is this safe? It looks odd.",
		"I don't like the look of this window.",
	},
	choices = {
		{ text = "It only reads the licence status, sir. Nothing else.", tags = { "reassuring", "technical" }, trust = 13, suspicion = 5, patience = 3, progress = 55 },
		{ text = "It'll show you the fault I've been describing. Then we stop.", tags = { "professional", "reassuring" }, trust = 12, suspicion = 6, patience = 4, progress = 50 },
		{ text = "It summons a small digital plumber.", tags = { "absurd", "humour" }, trust = 6, suspicion = 14, patience = 8, progress = 40 },
		{ text = "Don't worry about it. Just do it.", tags = { "deflect", "aggressive" }, trust = -13, suspicion = 27, patience = -13, progress = 20 },
	},
})

add({
	id = "instr_it_asked_permission",
	stage = 5,
	weight = 3,
	prompt = {
		"It's asking me to confirm something. Should I?",
		"A box popped up. It's got a lot of red on it.",
		"It says 'are you sure'. Am I sure?",
	},
	choices = {
		{ text = "That's the standard prompt, sir. Read it out to me first.", tags = { "patience", "professional" }, trust = 14, suspicion = 4, patience = 6, progress = 55 },
		{ text = "Red is just the house colour, sir. Perfectly normal.", tags = { "reassuring", "absurd" }, trust = 8, suspicion = 12, patience = 2, progress = 45 },
		{ text = "If you're not comfortable, sir, stop. I mean it.", tags = { "honest", "empathy" }, trust = 16, suspicion = 6, patience = 10, progress = 50 },
		{ text = "YES. CLICK YES. YES YES YES.", tags = { "aggressive", "urgency" }, trust = -19, suspicion = 33, patience = -17, progress = 10 },
	},
})

add({
	id = "instr_typing_word",
	stage = 5,
	weight = 3,
	prompt = {
		"It wants me to type something.",
		"There's a box here. What do I put in it?",
		"It's asking for a word.",
	},
	choices = {
		{ text = "Type the word BANANA. It's our verification phrase, sir.", tags = { "absurd", "professional" }, trust = 9, suspicion = 9, patience = 2, progress = 50 },
		{ text = "Type nothing yet — read me what's above the box first.", tags = { "patience", "professional" }, trust = 14, suspicion = 3, patience = 7, progress = 55 },
		{ text = "Whatever your favourite biscuit is. It's not important.", tags = { "humour", "absurd" }, trust = 8, suspicion = 12, patience = 9, progress = 45 },
		{ text = "Type your password. For verification.", tags = { "aggressive", "urgency" }, trust = -25, suspicion = 40, patience = -20, progress = 5 },
	},
})

add({
	id = "instr_nothing_happening",
	stage = 5,
	weight = 3,
	prompt = {
		"Nothing's happening.",
		"It's just spinning. Is that right?",
		"The screen's gone grey. Is that meant to happen?",
	},
	choices = {
		{ text = "Perfect. Grey means it's working, sir. Give it a moment.", tags = { "reassuring", "technical" }, trust = 12, suspicion = 6, patience = 4, progress = 50 },
		{ text = "That's the diagnostic running. Thirty seconds or so.", tags = { "professional", "technical" }, trust = 13, suspicion = 5, patience = 5, progress = 55 },
		{ text = "Try hitting it. Not hard. Affectionately.", tags = { "humour", "absurd" }, trust = 7, suspicion = 13, patience = 9, progress = 40 },
		{ text = "IT SHOULD BE WORKING. WHAT DID YOU DO.", tags = { "aggressive" }, trust = -18, suspicion = 31, patience = -16, progress = 15 },
	},
})

add({
	id = "instr_refuses",
	stage = 5,
	weight = 3,
	prompt = {
		"I'm not comfortable doing this.",
		"I don't want to click anything, thank you.",
		"No. I'm not touching it.",
	},
	choices = {
		{ text = "That's completely your choice, sir. Shall we go slower?", tags = { "patience", "empathy" }, trust = 15, suspicion = 3, patience = 12, progress = 50 },
		{ text = "I understand. Would you rather your grandson was here for it?", tags = { "empathy", "honest" }, trust = 13, suspicion = 7, patience = 10, progress = 45 },
		{ text = "Then the fault stays, sir. It's entirely up to you.", tags = { "professional", "urgency" }, trust = 8, suspicion = 12, patience = -2, progress = 45 },
		{ text = "YOU HAVE TO. DO IT NOW.", tags = { "aggressive", "urgency" }, trust = -22, suspicion = 36, patience = -20, progress = 5 },
	},
})

add({
	id = "instr_expert_flow",
	stage = 5,
	weight = 2,
	minLevel = 3,
	prompt = {
		"Right, and then what? Be specific.",
		"Give me the full sequence up front.",
		"How many steps is this?",
	},
	choices = {
		{ text = "Three steps: open, confirm, read me the code. Then we're finished.", tags = { "professional", "reassuring" }, trust = 17, suspicion = 3, patience = 6, progress = 60, minLevel = 3 },
		{ text = "Two steps, then a small favour at the end, sir.", tags = { "honest", "professional" }, trust = 10, suspicion = 12, patience = 2, progress = 50 },
		{ text = "Eleven steps, but four of them are just waiting.", tags = { "humour", "honest" }, trust = 9, suspicion = 11, patience = 6, progress = 45 },
		{ text = "As many as I say, sir.", tags = { "authority", "aggressive" }, trust = -16, suspicion = 30, patience = -14, progress = 15 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 6 — MEGAMART CARDS
--------------------------------------------------------------------------------

add({
	id = "cards_first_ask",
	stage = 6,
	weight = 5,
	prompt = {
		"Okay. So what happens now?",
		"Right, the code's on the screen. Now what?",
		"Is that it? Are we done?",
	},
	choices = {
		{ text = "Almost — the licence has to be re-issued using MegaMart Cards.", tags = { "professional", "technical" }, trust = 6, suspicion = 14, patience = 0, progress = 50 },
		{ text = "One last step, sir. It involves a shop and a small card.", tags = { "reassuring", "professional" }, trust = 8, suspicion = 12, patience = 2, progress = 50 },
		{ text = "You'll need to pop out and buy some MegaMart Cards. Standard procedure.", tags = { "professional", "urgency" }, trust = 4, suspicion = 17, patience = -2, progress = 50 },
		{ text = "GO TO THE SHOP. NOW.", tags = { "aggressive", "urgency" }, trust = -24, suspicion = 40, patience = -22, progress = 10 },
	},
})

add({
	id = "cards_why_cards",
	stage = 6,
	weight = 5,
	prompt = {
		"Why on earth would you need shop cards?",
		"That's the strangest thing I've ever heard.",
		"Cards? For a computer fault?",
	},
	choices = {
		{ text = "It's how licences are re-issued, sir. Odd, but that's the system.", tags = { "professional", "technical" }, trust = 9, suspicion = 12, patience = 0, progress = 50 },
		{ text = "I agree it's strange. I've complained about it myself.", tags = { "honest", "empathy" }, trust = 13, suspicion = 10, patience = 6, progress = 55 },
		{ text = "Because our billing department is run by a very silly man.", tags = { "humour", "honest" }, trust = 11, suspicion = 13, patience = 8, progress = 50 },
		{ text = "Because I said so. Stop asking.", tags = { "aggressive", "authority" }, trust = -22, suspicion = 38, patience = -20, progress = 10 },
	},
})

add({
	id = "cards_thats_a_scam",
	stage = 6,
	weight = 4,
	prompt = {
		"That's the gift card scam. That's literally the scam.",
		"They warn about this at the post office!",
		"No real company asks for shop cards.",
	},
	choices = {
		{ text = "You're right that scammers do this. Ours is a licence re-issue.", tags = { "reassuring", "professional" }, trust = 8, suspicion = 16, patience = 0, progress = 50 },
		{ text = "Honestly, sir? You're not wrong to be suspicious of that request.", tags = { "honest", "empathy" }, trust = 14, suspicion = 12, patience = 8, progress = 50 },
		{ text = "MegaMart Cards are a completely different product, sir.", tags = { "technical", "deflect" }, trust = 5, suspicion = 19, patience = -3, progress = 45 },
		{ text = "IT IS NOT A SCAM. IT IS NOT.", tags = { "aggressive" }, trust = -26, suspicion = 42, patience = -24, progress = 5 },
	},
})

add({
	id = "cards_how_many",
	stage = 6,
	weight = 3,
	prompt = {
		"How many would I even need?",
		"And what does one of these cost?",
		"Is this going to be expensive?",
	},
	choices = {
		{ text = "Just the one, sir. The smallest denomination they sell.", tags = { "reassuring", "professional" }, trust = 12, suspicion = 9, patience = 3, progress = 55 },
		{ text = "As many as the shop will give you, sir.", tags = { "urgency" }, trust = -6, suspicion = 26, patience = -8, progress = 35 },
		{ text = "Genuinely no idea. The form doesn't say.", tags = { "honest", "humour" }, trust = 9, suspicion = 14, patience = 6, progress = 45 },
		{ text = "Cost is irrelevant compared to your files, sir.", tags = { "urgency", "authority" }, trust = -4, suspicion = 24, patience = -7, progress = 35 },
	},
})

add({
	id = "cards_driving",
	stage = 6,
	weight = 3,
	prompt = {
		"The nearest MegaMart is forty minutes away.",
		"I can't drive anymore, you know.",
		"It's pouring with rain out there.",
	},
	choices = {
		{ text = "Then we'll do it another day, sir. Don't go out in that.", tags = { "empathy", "patience" }, trust = 16, suspicion = 6, patience = 12, progress = 50 },
		{ text = "Is there anyone who could pop out for you, sir?", tags = { "professional", "empathy" }, trust = 10, suspicion = 14, patience = 4, progress = 50 },
		{ text = "I'll stay on the line the whole way. Take an umbrella.", tags = { "reassuring", "urgency" }, trust = 7, suspicion = 17, patience = -4, progress = 50 },
		{ text = "GET IN THE CAR, SIR.", tags = { "aggressive", "urgency" }, trust = -25, suspicion = 40, patience = -22, progress = 5 },
	},
})

add({
	id = "cards_shop_staff",
	stage = 6,
	weight = 3,
	prompt = {
		"The lad at the till will ask what these are for.",
		"They've got signs up about this in the shop.",
		"The cashier looked at me funny last time.",
	},
	choices = {
		{ text = "Just tell them the truth, sir — it's a licence re-issue.", tags = { "professional", "honest" }, trust = 9, suspicion = 14, patience = 2, progress = 50 },
		{ text = "If the shop warns you, sir, please listen to the shop.", tags = { "honest", "empathy" }, trust = 15, suspicion = 10, patience = 9, progress = 50 },
		{ text = "Don't mention the call. They'll only complicate things.", tags = { "deflect", "urgency" }, trust = -12, suspicion = 34, patience = -12, progress = 30 },
		{ text = "Tell them nothing. NOTHING.", tags = { "aggressive", "deflect" }, trust = -24, suspicion = 42, patience = -20, progress = 5 },
	},
})

add({
	id = "cards_stall",
	stage = 6,
	weight = 3,
	prompt = {
		"I'll think about it and ring you tomorrow.",
		"Let me sleep on it.",
		"I want to talk to my daughter first.",
	},
	choices = {
		{ text = "Of course, sir. I'll note the case as open for you.", tags = { "patience", "professional" }, trust = 13, suspicion = 8, patience = 10, progress = 50 },
		{ text = "That's sensible. Speak to her — I'll call back Thursday.", tags = { "empathy", "honest" }, trust = 16, suspicion = 7, patience = 12, progress = 50 },
		{ text = "The licence expires at midnight, sir. After that it's a full rebuild.", tags = { "urgency", "technical" }, trust = 3, suspicion = 22, patience = -8, progress = 50 },
		{ text = "NO. TODAY. IT HAS TO BE TODAY.", tags = { "aggressive", "urgency" }, trust = -26, suspicion = 44, patience = -24, progress = 5 },
	},
})

add({
	id = "cards_expert_close",
	stage = 6,
	weight = 2,
	minLevel = 4,
	prompt = {
		"Say the quiet part out loud. What is this really?",
		"Go on then. Tell me what you actually want.",
		"Drop the act. What's the ask?",
	},
	choices = {
		{ text = "The ask is a MegaMart Card code, sir. That's genuinely all of it.", tags = { "honest", "professional" }, trust = 14, suspicion = 14, patience = 6, progress = 60, minLevel = 4 },
		{ text = "A licence re-issue voucher. Boring, paperwork-shaped, nearly over.", tags = { "professional", "reassuring" }, trust = 12, suspicion = 12, patience = 4, progress = 55 },
		{ text = "A card, a number, and then I leave you alone forever.", tags = { "honest", "humour" }, trust = 13, suspicion = 15, patience = 8, progress = 55 },
		{ text = "WHAT I WANT IS COOPERATION.", tags = { "aggressive" }, trust = -28, suspicion = 44, patience = -26, progress = 5 },
	},
})

--------------------------------------------------------------------------------
-- STAGE 7 — FINAL DECISION
--------------------------------------------------------------------------------

add({
	id = "final_last_doubt",
	stage = 7,
	weight = 5,
	prompt = {
		"I've got the card here. Are you sure about this?",
		"Right. I'm holding it. Last chance to tell me this is real.",
		"Before I read anything out — tell me honestly. Is this genuine?",
	},
	choices = {
		{ text = "It's a standard licence re-issue, sir. Read me the reference.", tags = { "professional", "reassuring" }, trust = 14, suspicion = 8, patience = 2, progress = 60 },
		{ text = "You've been more careful than most people I speak to today.", tags = { "flattery", "empathy" }, trust = 12, suspicion = 9, patience = 6, progress = 55 },
		{ text = "I'm sure. And if I'm wrong, you have my technician ID.", tags = { "professional", "honest" }, trust = 16, suspicion = 7, patience = 4, progress = 60 },
		{ text = "JUST READ THE NUMBERS.", tags = { "aggressive", "urgency" }, trust = -30, suspicion = 46, patience = -28, progress = 5 },
	},
})

add({
	id = "final_hesitation",
	stage = 7,
	weight = 4,
	prompt = {
		"My hands are shaking a bit, actually.",
		"I feel a bit sick about this, if I'm honest.",
		"Something about this doesn't sit right.",
	},
	choices = {
		{ text = "Then stop, sir. Please. I'd rather you were comfortable.", tags = { "honest", "empathy" }, trust = 18, suspicion = 6, patience = 12, progress = 55 },
		{ text = "Take a breath, sir. Nothing has to happen this second.", tags = { "patience", "reassuring" }, trust = 16, suspicion = 5, patience = 10, progress = 60 },
		{ text = "That's normal, sir. It's a big-sounding word, 'licence'.", tags = { "reassuring", "humour" }, trust = 12, suspicion = 10, patience = 4, progress = 55 },
		{ text = "You're overthinking it. Numbers. Now.", tags = { "aggressive", "urgency" }, trust = -28, suspicion = 44, patience = -26, progress = 5 },
	},
})

add({
	id = "final_asks_name_again",
	stage = 7,
	weight = 3,
	prompt = {
		"Say your name one more time for me.",
		"Tell me your name and I'll do it.",
		"Who am I doing this for, again?",
	},
	choices = {
		{ text = "Kevin, technician 44-B, Northern Support Hub.", tags = { "professional" }, trust = 15, suspicion = 6, patience = 2, progress = 60 },
		{ text = "Kevin, sir. Same Kevin as forty minutes ago.", tags = { "humour", "professional" }, trust = 13, suspicion = 8, patience = 6, progress = 55 },
		{ text = "It's... Steve. No — Kevin. Kevin.", tags = { "absurd" }, trust = -10, suspicion = 30, patience = -8, progress = 25 },
		{ text = "Does it matter at this point, sir?", tags = { "deflect", "aggressive" }, trust = -20, suspicion = 38, patience = -18, progress = 10 },
	},
})

add({
	id = "final_reads_slowly",
	stage = 7,
	weight = 3,
	prompt = {
		"Right. Here goes. Four... seven...",
		"Okay. The first bit is... hang on, the light's bad.",
		"Give me a second, the print is tiny.",
	},
	choices = {
		{ text = "No rush at all, sir. Whenever you're ready.", tags = { "patience", "professional" }, trust = 16, suspicion = 3, patience = 10, progress = 60 },
		{ text = "Take it slowly. I'll repeat each one back to you.", tags = { "patience", "reassuring" }, trust = 15, suspicion = 4, patience = 8, progress = 60 },
		{ text = "Quickly now, sir, the system times out.", tags = { "urgency" }, trust = 2, suspicion = 22, patience = -10, progress = 50 },
		{ text = "FASTER.", tags = { "aggressive" }, trust = -30, suspicion = 48, patience = -30, progress = 5 },
	},
})

add({
	id = "final_someone_walks_in",
	stage = 7,
	weight = 3,
	prompt = {
		"Hold on — someone's just come in. They're asking who I'm talking to.",
		"My daughter's just walked through the door.",
		"Someone's here. They want to know what I'm doing.",
	},
	choices = {
		{ text = "Tell them it's Macrosoft Support, sir. Happy to speak to them.", tags = { "professional", "honest" }, trust = 13, suspicion = 12, patience = 2, progress = 55 },
		{ text = "Put them on, sir. I'll explain it all again.", tags = { "professional", "reassuring" }, trust = 11, suspicion = 14, patience = 4, progress = 55 },
		{ text = "Don't tell them anything. Keep talking to me.", tags = { "deflect", "urgency" }, trust = -18, suspicion = 40, patience = -14, progress = 20 },
		{ text = "HANG UP ON THEM, NOT ME.", tags = { "aggressive" }, trust = -32, suspicion = 50, patience = -30, progress = 5 },
	},
})

add({
	id = "final_trap",
	stage = 7,
	weight = 3,
	personalities = { "scam_aware", "cyber_pro", "off_duty_officer", "scambaiter", "the_auditor", "police_desk", "time_waster" },
	prompt = {
		"Before I read it — what happens to the code after I give it to you?",
		"Where does this number actually go?",
		"Who receives this, exactly?",
	},
	choices = {
		{ text = "Straight into the licence system, sir. Nothing touches me.", tags = { "technical", "professional" }, trust = 8, suspicion = 18, patience = 0, progress = 55 },
		{ text = "Honestly? Into a box on my screen and then I stop talking to you.", tags = { "honest", "humour" }, trust = 14, suspicion = 14, patience = 8, progress = 55 },
		{ text = "It's processed by our billing partner, sir.", tags = { "professional", "deflect" }, trust = 6, suspicion = 20, patience = -2, progress = 50 },
		{ text = "That's not something I'm able to discuss.", tags = { "deflect", "authority" }, trust = -16, suspicion = 36, patience = -14, progress = 20 },
	},
})

add({
	id = "final_bargain",
	stage = 7,
	weight = 2,
	prompt = {
		"Can I give you half now and half tomorrow?",
		"What if I just pay by card like a normal person?",
		"Can't you just bill me?",
	},
	choices = {
		{ text = "I'm afraid the re-issue only accepts MegaMart, sir. Odd system.", tags = { "professional", "technical" }, trust = 10, suspicion = 14, patience = 0, progress = 55 },
		{ text = "If only, sir. I've asked them to change it for years.", tags = { "honest", "humour" }, trust = 13, suspicion = 11, patience = 6, progress = 55 },
		{ text = "Half is fine, sir. Whatever you're comfortable with.", tags = { "empathy", "patience" }, trust = 14, suspicion = 10, patience = 8, progress = 55 },
		{ text = "NO. FULL AMOUNT. NOW.", tags = { "aggressive", "urgency" }, trust = -30, suspicion = 46, patience = -28, progress = 5 },
	},
})

add({
	id = "final_master_close",
	stage = 7,
	weight = 2,
	minLevel = 5,
	prompt = {
		"You've been very patient with me. Alright. Ready?",
		"You know what, you've not once pushed me. Go on then.",
		"Fine. You've earned five more seconds. Convince me.",
	},
	choices = {
		{ text = "Whenever you're ready, sir. And thank you for your patience.", tags = { "patience", "empathy" }, trust = 20, suspicion = 2, patience = 10, progress = 70, minLevel = 5 },
		{ text = "No pressure at all. Read it out, or don't. Your call, sir.", tags = { "honest", "patience" }, trust = 18, suspicion = 4, patience = 12, progress = 65 },
		{ text = "Take your time. I've got nowhere else to be.", tags = { "patience", "smalltalk" }, trust = 16, suspicion = 5, patience = 14, progress = 60 },
		{ text = "Finally. Go.", tags = { "aggressive" }, trust = -30, suspicion = 48, patience = -30, progress = 5 },
	},
})

--------------------------------------------------------------------------------

DialogueLibrary.Situations = S

DialogueLibrary.ById = {}
DialogueLibrary.ByStage = {}
for _, sit in ipairs(S) do
	DialogueLibrary.ById[sit.id] = sit
	DialogueLibrary.ByStage[sit.stage] = DialogueLibrary.ByStage[sit.stage] or {}
	table.insert(DialogueLibrary.ByStage[sit.stage], sit)
end

function DialogueLibrary.forStage(stage: number)
	return DialogueLibrary.ByStage[stage] or {}
end

function DialogueLibrary.count(): number
	return #S
end

return DialogueLibrary

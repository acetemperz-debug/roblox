--!nonstrict
-- RandomEvents
-- Interruptions that replace a normal dialogue situation. Each one forces the
-- player to pick a response, exactly like a situation, but with its own effects.
--
-- Fields:
--   id, title      display name shown on the event banner
--   weight         relative pick weight
--   minStage/maxStage  stage window where the event can fire
--   personalities  optional whitelist of personality ids
--   excludes       optional blacklist
--   prompt         array of NPC line variants
--   choices        same shape as DialogueLibrary choices
--   onHold         true if this event puts the player on hold (tracked for an achievement)
--   fatal          true if failing it ends the call immediately

local RandomEvents = {}

RandomEvents.List = {
	{
		id = "grandson_arrives",
		title = "The Grandson Arrives",
		weight = 4,
		minStage = 2,
		maxStage = 7,
		prompt = {
			"Hold on — my grandson's just walked in. He says to put it on speaker.",
			"My nephew's here. He does computers. He's taking the phone.",
			"One second. My granddaughter's pulling a face at me.",
		},
		choices = {
			{ text = "Put him on, sir. I'll happily explain it to him.", tags = { "professional", "honest" }, trust = 10, suspicion = 8, patience = 4, progress = 40 },
			{ text = "Hello young man. I'm Kevin from Macrosoft Technical.", tags = { "professional", "reassuring" }, trust = 8, suspicion = 12, patience = 2, progress = 40 },
			{ text = "Perhaps we should do this when you're alone, sir.", tags = { "deflect", "urgency" }, trust = -14, suspicion = 32, patience = -10, progress = 20 },
			{ text = "TELL HIM TO GO AWAY.", tags = { "aggressive" }, trust = -22, suspicion = 42, patience = -20, progress = 5 },
		},
	},
	{
		id = "searches_online",
		title = "They're Searching Online",
		weight = 4,
		minStage = 1,
		maxStage = 6,
		prompt = {
			"Hang on. I'm typing 'Macrosoft Support' into the search bar...",
			"Right, first result says... hm. That's interesting.",
			"I'm reading a page about companies that call people. Hmm.",
		},
		choices = {
			{ text = "Go ahead and read it, sir. I'll wait.", tags = { "patience", "honest" }, trust = 14, suspicion = 6, patience = 8, progress = 45 },
			{ text = "You'll see a lot of fake versions of us on there.", tags = { "reassuring", "deflect" }, trust = 6, suspicion = 16, patience = 0, progress = 40 },
			{ text = "Search results are sponsored, sir. Not reliable.", tags = { "technical", "deflect" }, trust = 2, suspicion = 22, patience = -4, progress = 35 },
			{ text = "CLOSE THAT PAGE.", tags = { "aggressive", "urgency" }, trust = -24, suspicion = 44, patience = -20, progress = 5 },
		},
	},
	{
		id = "internet_drops",
		title = "Their Internet Drops",
		weight = 3,
		minStage = 3,
		maxStage = 7,
		prompt = {
			"Oh, the wifi's gone off. The little light's orange.",
			"Everything's frozen. The internet's dropped out.",
			"Hang on, the router's making a noise at me.",
		},
		choices = {
			{ text = "No problem at all, sir. I'll hold while it comes back.", tags = { "patience", "professional" }, trust = 12, suspicion = 2, patience = 10, progress = 45 },
			{ text = "That'll be the fault spreading, sir. Exactly as I warned.", tags = { "technical", "urgency" }, trust = 8, suspicion = 14, patience = -4, progress = 45 },
			{ text = "Turn it off and on again. The classic.", tags = { "humour", "technical" }, trust = 10, suspicion = 8, patience = 4, progress = 40 },
			{ text = "THE INTERNET IS FINE. IT'S YOUR COMPUTER.", tags = { "aggressive" }, trust = -20, suspicion = 36, patience = -18, progress = 10 },
		},
	},
	{
		id = "manager_shouting",
		title = "Your Manager Is Shouting",
		weight = 3,
		minStage = 1,
		maxStage = 7,
		prompt = {
			"What's all that shouting on your end?",
			"Is someone yelling at you? I can hear it clearly.",
			"Is that your boss? He sounds furious.",
		},
		choices = {
			{ text = "Busy office, sir. Apologies for the noise.", tags = { "professional", "deflect" }, trust = 9, suspicion = 7, patience = 2, progress = 45 },
			{ text = "That's Steve. He shouts at everyone. Ignore him.", tags = { "humour", "honest" }, trust = 12, suspicion = 10, patience = 8, progress = 45 },
			{ text = "I didn't hear anything, sir.", tags = { "deflect" }, trust = -6, suspicion = 24, patience = -6, progress = 30 },
			{ text = "SORRY, ONE MOMENT — NO, I'M ON A CALL!", tags = { "absurd", "humour" }, trust = 7, suspicion = 14, patience = 6, progress = 40 },
		},
	},
	{
		id = "celebration",
		title = "Someone Celebrates Loudly",
		weight = 3,
		minStage = 2,
		maxStage = 7,
		prompt = {
			"What was that cheering? Did someone score?",
			"Why is everyone in your office clapping?",
			"Somebody just shouted 'YES' very loudly there.",
		},
		choices = {
			{ text = "Someone resolved a difficult case, sir. It's a supportive office.", tags = { "professional", "humour" }, trust = 11, suspicion = 8, patience = 4, progress = 45 },
			{ text = "Birthday. There's cake. I'm not getting any.", tags = { "humour", "smalltalk" }, trust = 13, suspicion = 7, patience = 10, progress = 45 },
			{ text = "Sales floor, sir. Ignore them.", tags = { "honest", "deflect" }, trust = 5, suspicion = 16, patience = 0, progress = 40 },
			{ text = "That was nothing. Focus, sir.", tags = { "aggressive", "deflect" }, trust = -12, suspicion = 28, patience = -12, progress = 20 },
		},
	},
	{
		id = "fire_alarm",
		title = "The Fire Alarm Goes Off",
		weight = 2,
		minStage = 2,
		maxStage = 7,
		prompt = {
			"Is that an alarm going off where you are?",
			"There's a siren on your end. Should you be leaving?",
			"That sounds like a fire alarm, mate.",
		},
		choices = {
			{ text = "Routine test, sir. Every Wednesday at this time.", tags = { "professional", "reassuring" }, trust = 11, suspicion = 8, patience = 2, progress = 45 },
			{ text = "It is. I'm staying on the line for you anyway, sir.", tags = { "empathy", "absurd" }, trust = 14, suspicion = 10, patience = 8, progress = 45 },
			{ text = "That's the kettle. Very loud kettle.", tags = { "absurd", "humour" }, trust = 7, suspicion = 16, patience = 6, progress = 40 },
			{ text = "IGNORE IT. WHERE WERE WE.", tags = { "aggressive" }, trust = -16, suspicion = 32, patience = -14, progress = 15 },
		},
	},
	{
		id = "on_hold",
		title = "You've Been Put On Hold",
		weight = 3,
		minStage = 2,
		maxStage = 7,
		onHold = true,
		prompt = {
			"Hold on, someone's at the door. Don't go anywhere.",
			"One second, the other phone's ringing. Hold please.",
			"Hang on. Kettle. Two minutes.",
		},
		choices = {
			{ text = "Of course, sir. I'll wait right here.", tags = { "patience", "professional" }, trust = 12, suspicion = 2, patience = 10, progress = 45 },
			{ text = "Take your time. I'll enjoy the silence.", tags = { "patience", "humour" }, trust = 13, suspicion = 4, patience = 12, progress = 45 },
			{ text = "Sir, please don't — the diagnostic will time out.", tags = { "urgency", "technical" }, trust = 2, suspicion = 20, patience = -8, progress = 40 },
			{ text = "DO NOT PUT ME ON HOLD.", tags = { "aggressive" }, trust = -20, suspicion = 38, patience = -18, progress = 10 },
		},
	},
	{
		id = "ask_for_manager",
		title = "They Want Your Manager",
		weight = 3,
		minStage = 3,
		maxStage = 7,
		prompt = {
			"Right. I want your supervisor on this call.",
			"Get me whoever's above you.",
			"Is there an adult there I can speak to?",
		},
		choices = {
			{ text = "One moment, sir — I'll transfer you to my floor lead.", tags = { "professional", "patience" }, trust = 13, suspicion = 6, patience = 6, progress = 45 },
			{ text = "I'm the senior on shift, sir. Everything goes through me.", tags = { "authority", "professional" }, trust = 6, suspicion = 14, patience = 0, progress = 45 },
			{ text = "He's currently shouting at someone else. Shall I wait for a gap?", tags = { "humour", "honest" }, trust = 11, suspicion = 12, patience = 8, progress = 45 },
			{ text = "THERE IS NO MANAGER. THERE IS ONLY ME.", tags = { "aggressive", "absurd" }, trust = -22, suspicion = 40, patience = -20, progress = 5 },
		},
	},
	{
		id = "cybersecurity_claim",
		title = "\"I Work In Cybersecurity\"",
		weight = 3,
		minStage = 1,
		maxStage = 6,
		prompt = {
			"Just so you know — I work in cybersecurity.",
			"Fun fact: this is literally my job. Carry on though.",
			"I train people to spot calls like this. Professionally.",
		},
		choices = {
			{ text = "Then I've had the worst luck of anyone on this floor today.", tags = { "honest", "humour" }, trust = 15, suspicion = 10, patience = 12, progress = 50 },
			{ text = "Then you'll know a licence registry fault when you see one, sir.", tags = { "technical", "professional" }, trust = 3, suspicion = 24, patience = -2, progress = 40 },
			{ text = "Wonderful. A professional. Let's speak plainly.", tags = { "honest", "empathy" }, trust = 12, suspicion = 12, patience = 8, progress = 45 },
			{ text = "Sure you do, sir.", tags = { "aggressive", "humour" }, trust = -16, suspicion = 34, patience = -14, progress = 15 },
		},
	},
	{
		id = "loud_music",
		title = "Loud Music Down The Phone",
		weight = 2,
		minStage = 3,
		maxStage = 7,
		prompt = {
			"Hang on, let me put some music on for you.",
			"You like trumpets? I hope you like trumpets.",
			"I'm going to hold the phone up to the speaker now.",
		},
		choices = {
			{ text = "That's a lovely bit of brass, sir. Now, about the licence.", tags = { "humour", "patience" }, trust = 12, suspicion = 8, patience = 10, progress = 45 },
			{ text = "I'll wait until the song finishes, sir.", tags = { "patience", "humour" }, trust = 14, suspicion = 6, patience = 12, progress = 45 },
			{ text = "Sir, please, this is a technical support call.", tags = { "professional", "urgency" }, trust = 4, suspicion = 16, patience = -6, progress = 40 },
			{ text = "TURN THAT OFF.", tags = { "aggressive" }, trust = -20, suspicion = 36, patience = -18, progress = 10 },
		},
	},
	{
		id = "deliberate_stalling",
		title = "Deliberate Stalling",
		weight = 3,
		minStage = 2,
		maxStage = 7,
		prompt = {
			"Sorry, could you start from the very beginning again?",
			"What was the company name? And spell it. Slowly. Letter by letter.",
			"Sorry, I've dropped my pen. Hold on. Hold on.",
		},
		choices = {
			{ text = "Of course, sir. M-A-C-R-O-S-O-F-T. Take your time.", tags = { "patience", "professional" }, trust = 11, suspicion = 4, patience = 8, progress = 45 },
			{ text = "You're doing this on purpose, aren't you, sir?", tags = { "honest", "humour" }, trust = 13, suspicion = 12, patience = 6, progress = 45 },
			{ text = "We've been over this twice already, sir.", tags = { "urgency" }, trust = 2, suspicion = 18, patience = -8, progress = 40 },
			{ text = "STOP WASTING MY TIME.", tags = { "aggressive" }, trust = -22, suspicion = 38, patience = -20, progress = 10 },
		},
	},
	{
		id = "wrong_name",
		title = "You Used The Wrong Name",
		weight = 2,
		minStage = 2,
		maxStage = 7,
		prompt = {
			"Why did you just call me Margaret? That's not my name.",
			"You've got the wrong person's file up there, haven't you.",
			"That's the third name you've used for me.",
		},
		choices = {
			{ text = "Apologies sir — two windows open. Entirely my fault.", tags = { "honest", "professional" }, trust = 11, suspicion = 10, patience = 4, progress = 45 },
			{ text = "Margaret is the account holder, sir. Isn't she?", tags = { "professional", "deflect" }, trust = 4, suspicion = 20, patience = -2, progress = 40 },
			{ text = "I have four hundred of these open. You're all Margaret to me.", tags = { "honest", "humour" }, trust = 9, suspicion = 18, patience = 8, progress = 40 },
			{ text = "Your name is whatever the system says it is, sir.", tags = { "authority", "absurd" }, trust = -16, suspicion = 34, patience = -14, progress = 15 },
		},
	},
	{
		id = "dog_barking",
		title = "The Dog Has Opinions",
		weight = 2,
		minStage = 1,
		maxStage = 7,
		prompt = {
			"BISCUIT. BISCUIT, NO. Sorry. Sorry, go on.",
			"The dog's got the phone cable. One second.",
			"He always barks at cold callers. Funny that.",
		},
		choices = {
			{ text = "Lovely dog, sir. What breed?", tags = { "smalltalk", "empathy" }, trust = 14, suspicion = 4, patience = 12, progress = 45 },
			{ text = "No trouble at all, sir. I'll wait for Biscuit.", tags = { "patience", "humour" }, trust = 13, suspicion = 3, patience = 10, progress = 45 },
			{ text = "Sir, if we could focus on the fault.", tags = { "professional", "urgency" }, trust = 5, suspicion = 12, patience = -4, progress = 40 },
			{ text = "PUT THE DOG OUTSIDE.", tags = { "aggressive" }, trust = -18, suspicion = 34, patience = -16, progress = 10 },
		},
	},
	{
		id = "reads_out_your_script",
		title = "They Read Your Next Line",
		weight = 2,
		minStage = 3,
		maxStage = 7,
		personalities = { "scam_aware", "cyber_pro", "scambaiter", "tech_teen", "the_auditor", "rival_centre" },
		prompt = {
			"Next you're going to tell me my licence has expired. Go on. Say it.",
			"Let me guess — MegaMart Cards?",
			"I'll say your next line for you, shall I?",
		},
		choices = {
			{ text = "You're two lines ahead of me, sir. Impressive.", tags = { "honest", "humour" }, trust = 13, suspicion = 14, patience = 10, progress = 45 },
			{ text = "That's a coincidence, sir. Licences do expire.", tags = { "professional", "deflect" }, trust = 3, suspicion = 24, patience = -2, progress = 40 },
			{ text = "Fine. You've got me. Want to hear how the rest goes?", tags = { "honest", "absurd" }, trust = 15, suspicion = 16, patience = 12, progress = 45 },
			{ text = "YOU DON'T KNOW WHAT I WAS GOING TO SAY.", tags = { "aggressive" }, trust = -24, suspicion = 42, patience = -22, progress = 5 },
		},
	},
	{
		id = "supervisor_listening",
		title = "Your Supervisor Is Listening",
		weight = 2,
		minStage = 4,
		maxStage = 7,
		prompt = {
			"Is that someone breathing on the line with us?",
			"There's a click every time you speak. Is this recorded?",
			"Is somebody else listening to this call?",
		},
		choices = {
			{ text = "Calls are monitored for quality, sir. Standard practice.", tags = { "professional", "honest" }, trust = 12, suspicion = 8, patience = 4, progress = 45 },
			{ text = "That's my supervisor. He's judging both of us.", tags = { "humour", "honest" }, trust = 13, suspicion = 12, patience = 8, progress = 45 },
			{ text = "No, sir. Nobody else is on this line.", tags = { "deflect" }, trust = -4, suspicion = 22, patience = -4, progress = 35 },
			{ text = "That's the fault in your line, sir. Told you.", tags = { "technical", "absurd" }, trust = 5, suspicion = 18, patience = 0, progress = 40 },
		},
	},
	{
		id = "phone_battery",
		title = "Their Phone Is Dying",
		weight = 2,
		minStage = 4,
		maxStage = 7,
		prompt = {
			"My phone's on four percent, just so you know.",
			"Battery's about to go. Better be quick.",
			"I'm going to have to find the charger in a minute.",
		},
		choices = {
			{ text = "Then let's pause here, sir. I'll call back once you're charged.", tags = { "patience", "empathy" }, trust = 15, suspicion = 4, patience = 10, progress = 45 },
			{ text = "Plug it in and I'll hold, sir. No rush.", tags = { "patience", "professional" }, trust = 14, suspicion = 3, patience = 10, progress = 45 },
			{ text = "Then we must finish now, sir. Quickly.", tags = { "urgency" }, trust = 3, suspicion = 18, patience = -6, progress = 45 },
			{ text = "DON'T YOU DARE HANG UP.", tags = { "aggressive" }, trust = -22, suspicion = 40, patience = -20, progress = 5 },
		},
	},
	{
		id = "rival_confusion",
		title = "Wait, Are They Also Scamming You?",
		weight = 3,
		minStage = 1,
		maxStage = 7,
		personalities = { "rival_centre" },
		prompt = {
			"Sir, I am calling about YOUR computer. Please open the blue window.",
			"Sir, please stop reading my script back to me.",
			"Sir, my supervisor says you must buy the cards.",
		},
		choices = {
			{ text = "Sir, I called YOU. Please open YOUR blue window.", tags = { "absurd", "humour" }, trust = 14, suspicion = 6, patience = 12, progress = 50 },
			{ text = "Are we... are we both doing this right now?", tags = { "honest", "humour" }, trust = 16, suspicion = 4, patience = 14, progress = 50 },
			{ text = "Let's both hang up at the same time. Three, two...", tags = { "humour", "honest" }, trust = 12, suspicion = 8, patience = 10, progress = 45 },
			{ text = "NO, SIR. YOU BUY THE CARDS.", tags = { "aggressive", "absurd" }, trust = -10, suspicion = 26, patience = -10, progress = 25 },
		},
	},
}

RandomEvents.ById = {}
for _, ev in ipairs(RandomEvents.List) do
	RandomEvents.ById[ev.id] = ev
end

function RandomEvents.count(): number
	return #RandomEvents.List
end

return RandomEvents

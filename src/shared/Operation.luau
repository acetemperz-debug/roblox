--!nonstrict
-- Operation
-- The tycoon layer: how big the fictional call centre is, who works there, what
-- "method" it runs on, how much heat that draws from the police, and how much
-- security is holding it together.
--
-- Everything here is abstract game economy. A "method" is a name, an income
-- multiplier and a heat number -- none of them describe how anything is
-- actually done, and none of them ever will. Keep it that way when adding
-- tiers: a joke and two numbers, never an explanation.
--
-- The numbers are tuned so that, at every method tier, the matching security
-- and tradecraft make the operation sustainable (net heat <= 0) while running
-- the same method bare gets you raided. tests/simulate.luau asserts exactly
-- that, so if you retune, run it.

local Operation = {}

--------------------------------------------------------------------------------
-- Heat constants
--------------------------------------------------------------------------------

Operation.Heat = {
	Max = 100,
	-- Heat bleeds off on its own. Security adds to this.
	BaseDecayPerSecond = 0.12,
	-- Laying low halts income but multiplies decay.
	LayLowDecayMultiplier = 8,
	LayLowSeconds = 180,
	-- Warning thresholds, shown to the player before anything happens.
	Warnings = {
		{ at = 45, title = "Unmarked Car", body = "There is a very ordinary car parked across the road that has not moved all day." },
		{ at = 70, title = "Someone Is Taking Photos", body = "A person in a high-vis jacket has photographed your door three times." },
		{ at = 88, title = "Final Warning", body = "Two people in matching coats just asked the caretaker what floor you are on." },
	},
	-- The police do not care about one person and a phone. Heat scales in with
	-- the size of the operation, which is the whole point of the system: net
	-- income at which you draw full attention.
	NoticeIncome = 40,
	-- Once you move off cold calling you are committed, and never fully
	-- invisible again.
	MinNoticeAboveTier1 = 0.35,
	-- Suspicion added by things that happen during calls.
	PerSuccessfulCall = 1.5,
	PerPoliceCall = 25,
	PerExposedCall = 0.5,
}

--------------------------------------------------------------------------------
-- Methods: the ladder of how the fictional operation makes its money.
--------------------------------------------------------------------------------

Operation.Methods = {
	{
		id = "cold_calling",
		index = 1,
		name = "Cold Calling",
		blurb = "A phone, a list, and no plan. Where everybody starts.",
		cost = 0,
		incomeMul = 1.0,
		heatPerSecond = 0.06,
		requiresRank = 1,
	},
	{
		id = "warm_lists",
		index = 2,
		name = "Warm Lead Sheets",
		blurb = "Somebody sold you a spreadsheet. It is 40% deceased.",
		cost = 25000,
		incomeMul = 1.7,
		heatPerSecond = 0.14,
		requiresRank = 3,
	},
	{
		id = "dodgy_links",
		index = 3,
		name = "Dodgy Links",
		blurb = "Now the callers arrive pre-annoyed. Revenue up, patience down.",
		cost = 120000,
		incomeMul = 2.8,
		heatPerSecond = 0.26,
		requiresRank = 4,
	},
	{
		id = "popup_farm",
		index = 4,
		name = "Popup Farm",
		blurb = "Seventeen flashing windows and a siren noise. Extremely effective, extremely loud.",
		cost = 450000,
		incomeMul = 4.5,
		heatPerSecond = 0.42,
		requiresRank = 5,
	},
	{
		id = "refund_portal",
		index = 5,
		name = "Fake Refund Portal",
		blurb = "A website with one button on it. The button says REFUND. It does not refund.",
		cost = 1800000,
		incomeMul = 7.0,
		heatPerSecond = 0.62,
		requiresRank = 6,
	},
	{
		id = "impersonation_desk",
		index = 6,
		name = "Corporate Impersonation Desk",
		blurb = "Letterheads, hold music, a fake org chart. Somebody printed lanyards.",
		cost = 6500000,
		incomeMul = 11.0,
		heatPerSecond = 0.9,
		requiresRank = 7,
	},
	{
		id = "franchise",
		index = 7,
		name = "The Franchise",
		blurb = "You now license the whole operation to other people. Deeply illegal. Beautifully organised.",
		cost = 25000000,
		incomeMul = 18.0,
		heatPerSecond = 1.3,
		requiresRank = 8,
	},
}

Operation.MethodById = {}
for _, method in ipairs(Operation.Methods) do
	Operation.MethodById[method.id] = method
end

Operation.StartingMethod = "cold_calling"

--------------------------------------------------------------------------------
-- Tradecraft: the "make the same method look less dodgy" upgrades.
--------------------------------------------------------------------------------
-- heatMul multiplies heat generation, incomeMul adds to the income multiplier.

Operation.Tradecraft = {
	{
		id = "voice_modulator",
		name = "Voice Modulator",
		blurb = "Makes everyone on the floor sound like a man who owns a filing cabinet.",
		cost = 12000,
		order = 1,
		requiresMethod = 1,
		heatMul = 0.92,
		incomeMul = 0.05,
	},
	{
		id = "charisma_training",
		name = "Charisma Training",
		blurb = "A two-hour seminar. Nobody can remember any of it but morale is up.",
		cost = 45000,
		order = 2,
		requiresMethod = 1,
		heatMul = 0.94,
		incomeMul = 0.12,
	},
	{
		id = "hold_music",
		name = "Licensed Hold Music",
		blurb = "Legitimate companies have terrible hold music. Now so do you.",
		cost = 110000,
		order = 3,
		requiresMethod = 2,
		heatMul = 0.9,
		incomeMul = 0.08,
	},
	{
		id = "script_polish",
		name = "Script Localisation",
		blurb = "Someone finally proofread the laminated binder.",
		cost = 320000,
		order = 4,
		requiresMethod = 3,
		heatMul = 0.9,
		incomeMul = 0.15,
	},
	{
		id = "call_qa",
		name = "Quality Assurance Team",
		blurb = "Two people whose entire job is telling the others they sound suspicious.",
		cost = 900000,
		order = 5,
		requiresMethod = 3,
		heatMul = 0.86,
		incomeMul = 0.1,
	},
	{
		id = "brand_identity",
		name = "Corporate Brand Identity",
		blurb = "A logo, a font and a slogan: 'Macrosoft - Probably Fine'.",
		cost = 2800000,
		order = 6,
		requiresMethod = 4,
		heatMul = 0.85,
		incomeMul = 0.2,
	},
	{
		id = "compliance_theatre",
		name = "Compliance Theatre",
		blurb = "Posters about data protection. Nobody reads them. They work anyway.",
		cost = 9000000,
		order = 7,
		requiresMethod = 5,
		heatMul = 0.8,
		incomeMul = 0.25,
	},
}

Operation.TradecraftById = {}
for _, item in ipairs(Operation.Tradecraft) do
	Operation.TradecraftById[item.id] = item
end

--------------------------------------------------------------------------------
-- Facilities: how big the place is. Sets the headcount cap.
--------------------------------------------------------------------------------

Operation.Facilities = {
	{
		id = "back_room",
		index = 1,
		name = "The Back Room",
		blurb = "One desk, one chair, one extension lead doing far too much.",
		cost = 0,
		desks = 3,
		incomeMul = 1.0,
	},
	{
		id = "small_office",
		index = 2,
		name = "Small Office",
		blurb = "Above a chip shop. Permanently smells of vinegar.",
		cost = 15000,
		desks = 6,
		incomeMul = 1.1,
	},
	{
		id = "open_floor",
		index = 3,
		name = "Open Plan Floor",
		blurb = "Rows of desks and a plant that nobody has watered since March.",
		cost = 90000,
		desks = 12,
		incomeMul = 1.25,
	},
	{
		id = "two_floors",
		index = 4,
		name = "Two Floors",
		blurb = "You now have stairs and, regrettably, a stairs-related incident log.",
		cost = 500000,
		desks = 22,
		incomeMul = 1.45,
	},
	{
		id = "whole_building",
		index = 5,
		name = "The Whole Building",
		blurb = "You bought the chip shop too. It is now a break room.",
		cost = 2500000,
		desks = 36,
		incomeMul = 1.7,
	},
	{
		id = "business_park",
		index = 6,
		name = "Business Park Unit",
		blurb = "Beige. Enormous. Indistinguishable from a real company.",
		cost = 12000000,
		desks = 56,
		incomeMul = 2.0,
	},
	{
		id = "offshore_campus",
		index = 7,
		name = "Offshore Campus",
		blurb = "It has a lake. Nobody knows why it has a lake.",
		cost = 60000000,
		desks = 90,
		incomeMul = 2.5,
	},
}

Operation.FacilityById = {}
for _, facility in ipairs(Operation.Facilities) do
	Operation.FacilityById[facility.id] = facility
end

Operation.StartingFacility = "back_room"

--------------------------------------------------------------------------------
-- Security: slows heat, speeds decay, and decides how a raid goes.
--------------------------------------------------------------------------------

Operation.Security = {
	{
		id = "door_buzzer",
		name = "Door Buzzer",
		blurb = "Now people have to be let in, which buys you about nine seconds.",
		cost = 8000,
		order = 1,
		heatMul = 0.94,
		decayBonus = 0.02,
		rating = 1,
	},
	{
		id = "shredder",
		name = "Industrial Paper Shredder",
		blurb = "Eats a binder in four seconds. Has eaten one tie.",
		cost = 35000,
		order = 2,
		heatMul = 0.92,
		decayBonus = 0.04,
		rating = 1,
	},
	{
		id = "cctv",
		name = "CCTV (Facing Outwards)",
		blurb = "You see them coming. That is the entire feature.",
		cost = 130000,
		order = 3,
		heatMul = 0.92,
		decayBonus = 0.05,
		rating = 2,
	},
	{
		id = "fire_exit",
		name = "Generous Fire Exit Programme",
		blurb = "Seven fire exits for a room of twelve people. Safety first.",
		cost = 420000,
		order = 4,
		heatMul = 0.96,
		decayBonus = 0.06,
		rating = 3,
	},
	{
		id = "lawyer",
		name = "Suspiciously Friendly Lawyer",
		blurb = "Answers the phone with 'what have you done now'.",
		cost = 1600000,
		order = 5,
		heatMul = 0.86,
		decayBonus = 0.09,
		rating = 3,
	},
	{
		id = "decoy_office",
		name = "Decoy Office",
		blurb = "An identical empty office two doors down with a nicer sign.",
		cost = 5500000,
		order = 6,
		heatMul = 0.82,
		decayBonus = 0.12,
		rating = 4,
	},
	{
		id = "shell_paperwork",
		name = "Shell Company Paperwork",
		blurb = "On paper you are a garden furniture wholesaler in a country you cannot spell.",
		cost = 22000000,
		order = 7,
		heatMul = 0.78,
		decayBonus = 0.16,
		rating = 5,
	},
}

Operation.SecurityById = {}
for _, item in ipairs(Operation.Security) do
	Operation.SecurityById[item.id] = item
end

--------------------------------------------------------------------------------
-- Employees: passive income, wages, and how much attention they draw.
--------------------------------------------------------------------------------
-- `suspicious` staff are cheap but noisy: more heat each, and they are the ones
-- a raid takes first.

Operation.Employees = {
	{
		id = "work_experience",
		tier = 1,
		name = "Work Experience Kid",
		blurb = "Fifteen. Enthusiastic. Has already told one caller the truth.",
		cost = 750,
		costGrowth = 1.09,
		incomePerSecond = 1.5,
		wagePerSecond = 0,
		heatPerSecond = 0.05,
		suspicious = true,
	},
	{
		id = "junior_caller",
		tier = 2,
		name = "Junior Caller",
		blurb = "Reads the script word for word, including the stage directions.",
		cost = 4000,
		costGrowth = 1.08,
		incomePerSecond = 5,
		wagePerSecond = 0.8,
		heatPerSecond = 0.03,
		suspicious = true,
	},
	{
		id = "caller",
		tier = 3,
		name = "Caller",
		blurb = "Competent. Bored. Applying for other jobs on the second monitor.",
		cost = 20000,
		costGrowth = 1.075,
		incomePerSecond = 18,
		wagePerSecond = 3,
		heatPerSecond = 0.025,
	},
	{
		id = "smooth_talker",
		tier = 4,
		name = "Smooth Talker",
		blurb = "Could sell you your own coat. Insists on a window seat.",
		cost = 90000,
		costGrowth = 1.07,
		incomePerSecond = 60,
		wagePerSecond = 11,
		heatPerSecond = 0.02,
	},
	{
		id = "veteran_closer",
		tier = 5,
		name = "Veteran Closer",
		blurb = "Has never once raised their voice and has never once failed.",
		cost = 400000,
		costGrowth = 1.065,
		incomePerSecond = 220,
		wagePerSecond = 45,
		heatPerSecond = 0.015,
	},
	{
		id = "ex_industry",
		tier = 6,
		name = "Ex-Industry Manager",
		blurb = "Ran a real call centre for nine years. Says this one is better managed.",
		cost = 1800000,
		costGrowth = 1.06,
		incomePerSecond = 800,
		wagePerSecond = 170,
		heatPerSecond = 0.01,
	},
	{
		id = "the_legend",
		tier = 7,
		name = "The Legend",
		blurb = "Nobody knows their real name. Nobody has seen them use a phone.",
		cost = 8000000,
		costGrowth = 1.055,
		incomePerSecond = 3000,
		wagePerSecond = 650,
		heatPerSecond = 0.006,
	},
}

Operation.EmployeeById = {}
for _, employee in ipairs(Operation.Employees) do
	Operation.EmployeeById[employee.id] = employee
end

--------------------------------------------------------------------------------
-- Offline earnings
--------------------------------------------------------------------------------

Operation.Offline = {
	-- How much of your live rate keeps running while you are away.
	Efficiency = 0.5,
	-- Default cap. The Night Shift Licence game pass raises it.
	CapSeconds = 4 * 3600,
	PassCapSeconds = 24 * 3600,
	-- Heat bleeds off while you are away, at the normal decay rate.
	DecayWhileAway = true,
}

--------------------------------------------------------------------------------
-- Raids
--------------------------------------------------------------------------------

Operation.Raid = {
	BaseEscapeChance = 0.20,
	EscapePerSecurityRating = 0.05,
	EscapePenaltyPerMethodTier = 0.04,
	MinEscapeChance = 0.05,
	MaxEscapeChance = 0.85,
	-- What a failed raid costs.
	CreditLossFraction = 0.2,
	StaffLossFraction = 0.25,
	-- Where heat lands afterwards.
	HeatAfterEscape = 25,
	HeatAfterRaid = 15,
	-- Operation is shut down for this long after a failed raid.
	ShutdownSeconds = 60,
}

--------------------------------------------------------------------------------
-- Derived numbers. One function so the server, the UI and the tests agree.
--------------------------------------------------------------------------------

-- operation: the profile's operation table
-- options: { offlineCapSeconds: number? }
function Operation.summarise(operation, options)
	options = options or {}
	local method = Operation.MethodById[operation.method] or Operation.MethodById[Operation.StartingMethod]
	local facility = Operation.FacilityById[operation.facility] or Operation.FacilityById[Operation.StartingFacility]

	local incomeMul = method.incomeMul * facility.incomeMul
	local heatMul = 1
	local decay = Operation.Heat.BaseDecayPerSecond
	local securityRating = 0

	for _, item in ipairs(Operation.Tradecraft) do
		if operation.tradecraft[item.id] then
			heatMul *= item.heatMul
			incomeMul += item.incomeMul
		end
	end
	for _, item in ipairs(Operation.Security) do
		if operation.security[item.id] then
			heatMul *= item.heatMul
			decay += item.decayBonus
			securityRating += item.rating
		end
	end

	local grossIncome = 0
	local wages = 0
	local staffHeat = 0
	local headcount = 0
	local suspiciousCount = 0

	for _, employee in ipairs(Operation.Employees) do
		local count = operation.staff[employee.id] or 0
		if count > 0 then
			headcount += count
			grossIncome += employee.incomePerSecond * count
			wages += employee.wagePerSecond * count
			staffHeat += employee.heatPerSecond * count
			if employee.suspicious then
				suspiciousCount += count
			end
		end
	end

	local income = grossIncome * incomeMul
	local netIncome = income - wages

	-- A tiny operation generates almost no attention no matter what it is doing.
	local notoriety = math.clamp(netIncome / Operation.Heat.NoticeIncome, 0, 1)
	if method.index > 1 then
		notoriety = math.max(notoriety, Operation.Heat.MinNoticeAboveTier1)
	end

	local heatGain = (method.heatPerSecond + staffHeat) * heatMul * notoriety
	local heatRate = heatGain - decay

	local escapeChance = math.clamp(
		Operation.Raid.BaseEscapeChance
			+ securityRating * Operation.Raid.EscapePerSecurityRating
			- (method.index - 1) * Operation.Raid.EscapePenaltyPerMethodTier,
		Operation.Raid.MinEscapeChance,
		Operation.Raid.MaxEscapeChance
	)

	return {
		method = method,
		facility = facility,
		headcount = headcount,
		deskCap = facility.desks,
		suspiciousCount = suspiciousCount,
		grossIncome = grossIncome,
		income = income,
		wages = wages,
		netIncome = netIncome,
		incomeMul = incomeMul,
		heatMul = heatMul,
		notoriety = notoriety,
		heatGain = heatGain,
		heatDecay = decay,
		heatRate = heatRate,
		securityRating = securityRating,
		escapeChance = escapeChance,
		offlineCapSeconds = options.offlineCapSeconds or Operation.Offline.CapSeconds,
	}
end

-- Hiring the same tier repeatedly gets more expensive.
function Operation.hireCost(employee, alreadyHired: number): number
	return math.floor(employee.cost * (employee.costGrowth ^ alreadyHired))
end

-- Firing refunds a fraction of what the last hire cost.
function Operation.severance(employee, alreadyHired: number): number
	if alreadyHired <= 0 then
		return 0
	end
	return math.floor(Operation.hireCost(employee, alreadyHired - 1) * 0.35)
end

function Operation.defaultState()
	return {
		method = Operation.StartingMethod,
		facility = Operation.StartingFacility,
		unlockedMethods = { [Operation.StartingMethod] = true },
		staff = {},
		security = {},
		tradecraft = {},
		heat = 0,
		layLowUntil = 0,
		shutdownUntil = 0,
		raidsSurvived = 0,
		raidsLost = 0,
		passiveEarned = 0,
		lastTick = 0,
	}
end

return Operation

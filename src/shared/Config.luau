--!nonstrict
-- Config
-- Central tuning module for Macrosoft Support (satirical call-centre game).
-- Everything here is fictional. No real company, product or process is referenced.

local Config = {}

Config.Version = "1.3.2"
Config.GameName = "Macrosoft Support: Call Centre Simulator"

Config.Currency = {
	Name = "Call Centre Credits",
	Short = "Credits",
	Symbol = "\u{20A1}", -- fictional credit symbol
}

Config.Call = {
	MaxTrust = 100,
	MaxSuspicion = 100,
	MaxPatience = 100,
	StartProgress = 0,
	-- Trust required at the final stage for the fictional call to succeed.
	TrustToSucceed = 65,
	-- Suspicion at which the NPC always hangs up.
	HangUpSuspicion = 100,
	-- Patience drains over time; at 0 the NPC gets bored and leaves.
	PatienceTickSeconds = 4,
	-- Hard ceiling so a call cannot run forever.
	MaxCallSeconds = 900,
	-- Fast-completion bonus window.
	FastCallSeconds = 120,
	-- How many situations the player must clear per stage before advancing.
	ProgressPerStage = 100,
	-- Maximum number of dialogue choices shown at once.
	MaxChoices = 4,

	-- Global balance knobs applied by NPCPersonalitySystem after personality and
	-- difficulty multipliers. Suspicion is scaled because a full call runs for
	-- roughly 14-18 exchanges and raw per-choice values would always reach 100.
	SuspicionScale = 0.45,
	-- Personality and difficulty suspicion multipliers are combined with a
	-- softening exponent so the hardest callers stay hard without becoming
	-- arithmetically unwinnable (0.7 => a raw 2.1x lands as 1.67x).
	SuspicionMultiplierSoftening = 0.7,
	TrustScale = 1.0,
	-- A line that lands really well calms the caller down a little.
	ReassureTrust = 9,
	ReassureAmount = 3.5,
}

Config.Stages = {
	{ id = 1, key = "Introduction", label = "Introduction" },
	{ id = 2, key = "Problem", label = "The Fictional Problem" },
	{ id = 3, key = "Trust", label = "Building Rapport" },
	{ id = 4, key = "Deflect", label = "Managing Suspicion" },
	{ id = 5, key = "Instructions", label = "Fictional Instructions" },
	{ id = 6, key = "Cards", label = "MegaMart Cards" },
	{ id = 7, key = "Final", label = "Final Decision" },
	{ id = 8, key = "Resolution", label = "Resolution" },
}

Config.StageCount = 7 -- stage 8 is the resolution screen, not playable

Config.DataStore = {
	Key = "MacrosoftCallCentre_PlayerData_v1",
	LeaderboardKey = "MacrosoftCallCentre_Leaderboard_v1",
	AutosaveSeconds = 120,
	MaxRetries = 4,
	RetryBaseDelay = 2,
	-- Set true in Studio if you have not enabled API services yet.
	StudioFallbackToMemory = true,
}

Config.Rewards = {
	TierBase = {
		Easy = { min = 50, max = 100 },
		Normal = { min = 100, max = 250 },
		Hard = { min = 250, max = 500 },
		Expert = { min = 500, max = 800 },
		Nightmare = { min = 1000, max = 1000 },
	},
	Bonuses = {
		LowSuspicion = { threshold = 20, mult = 0.30, label = "Cool Under Pressure" },
		HighTrust = { threshold = 85, mult = 0.25, label = "Trusted Advisor" },
		FastCall = { mult = 0.20, label = "Quick Talker" },
		PerfectRun = { mult = 0.50, label = "Flawless Script" },
		HardNPC = { mult = 0.15, label = "Tough Customer" },
		-- Consecutive wins. Capped so a streak is a reason to keep playing
		-- rather than the only thing that matters.
		Streak = { perCall = 0.08, max = 0.6, label = "Streak" },
	},
	-- Consolation credits for a failed call so progression never fully stalls.
	FailureConsolation = { min = 5, max = 20 },
}

Config.Events = {
	-- Base chance per situation that a random event fires instead of normal dialogue.
	BaseChance = 0.12,
	-- Minimum situations between two random events.
	Cooldown = 2,
}

Config.UI = {
	Theme = {
		Background = Color3.fromRGB(18, 20, 28),
		Panel = Color3.fromRGB(28, 31, 42),
		PanelLight = Color3.fromRGB(38, 42, 56),
		Accent = Color3.fromRGB(86, 140, 255),
		AccentDark = Color3.fromRGB(52, 96, 190),
		Trust = Color3.fromRGB(88, 214, 141),
		Suspicion = Color3.fromRGB(231, 91, 91),
		Patience = Color3.fromRGB(240, 189, 87),
		Text = Color3.fromRGB(238, 241, 248),
		SubText = Color3.fromRGB(158, 166, 184),
		Success = Color3.fromRGB(88, 214, 141),
		Danger = Color3.fromRGB(231, 91, 91),
		Gold = Color3.fromRGB(244, 203, 96),
	},
	TypewriterSpeed = 0.018, -- seconds per character
	TweenTime = 0.25,
}

-- Lighting and post-processing. Pulled out here because getting an indoor
-- Roblox room to read well is pure trial and error, and you should be able to
-- tune it in one file (or live -- see docs/TESTING.md) rather than hunting
-- through EnvironmentBuilder.
--
-- Two rules learned the hard way:
--   * Ambient does the work indoors. PointLights are accent only; a grid of
--     them at high brightness just washes everything to white.
--   * A Neon part renders at its own colour with full emission, so a near-white
--     Neon screen blooms into a shapeless blob. Neon wants a MID colour.
Config.Environment = {
	Ambient = Color3.fromRGB(104, 108, 126),
	OutdoorAmbient = Color3.fromRGB(94, 98, 116),
	Brightness = 2,
	ClockTime = 15,
	FogEnd = 500,

	-- Ceiling fixtures: all of them glow, a sparse grid actually casts light.
	CeilingLightColour = Color3.fromRGB(198, 216, 240),
	CeilingLightBrightness = 0.5,
	CeilingLightRange = 26,

	-- Monitors. Mid-blue, not white: this is what stops the blobbing.
	ScreenColour = Color3.fromRGB(58, 112, 178),
	-- Wall trim strips, dimmed so they read as trim and not as lasers.
	StripColourA = Color3.fromRGB(52, 96, 178),
	StripColourB = Color3.fromRGB(150, 64, 118),

	Bloom = { Intensity = 0.22, Size = 10, Threshold = 2 },
	Colour = { Saturation = 0.12, Contrast = 0.04, Brightness = 0.015 },
}

Config.Workstation = {
	-- Where the player's desk sits in the world (EnvironmentBuilder uses this).
	Origin = CFrame.new(0, 0, 0),
}

return Config

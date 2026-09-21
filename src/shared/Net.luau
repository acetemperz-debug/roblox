--!nonstrict
-- Net
-- Creates (server) or waits for (client) every RemoteEvent / RemoteFunction the
-- game uses. Nothing has to be created by hand in Studio -- require this module
-- and the objects appear under ReplicatedStorage/MacrosoftRemotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "MacrosoftRemotes"

local EVENTS = {
	-- Client -> Server
	"StartCall", -- (difficultyKey: string)
	"ChooseOption", -- (choiceIndex: number)
	"HangUp", -- ()
	"PurchaseUpgrade", -- (upgradeId: string)
	"RequestData", -- ()
	"SetDifficulty", -- (difficultyKey: string)
	"PromptPurchase", -- (kind: "pass"|"product", itemId: string)
	"UseItem", -- (productId: string)
	"SetAlias", -- (alias: string)
	"OperationAction", -- (action: string, a: any?, b: any?)
	"CloseTerminal",

	-- Server -> Client
	"CallStarted", -- (callView)
	"CallUpdated", -- (callView)
	"CallEnded", -- (resultView)
	"DataUpdated", -- (publicData)
	"Notify", -- ({title, body, kind})
	"AchievementUnlocked", -- (achievementView)
	"RankChanged", -- ({from, to})
	"OperationUpdated", -- (operationView)
	"HeatWarning", -- ({title, body, at})
	"RaidAlert", -- (outcome)
	"OfflineEarnings", -- ({amount, seconds, capped})
	"Broadcast", -- ({text, kind}) to everyone, for the live ticker
	"TerminalOpened", -- server-authorised physical terminal session
	"TerminalClosed",
	"LeaderboardRank", -- personal row on the physical board
}

local FUNCTIONS = {
	"GetData", -- () -> publicData
	"GetCatalog", -- () -> {upgrades, ranks, achievements, difficulties}
	"GetStore", -- () -> {passes, products}
	"GetOperation", -- () -> operationView
}

local Net = {}

local folder: Folder

local function ensureFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
end

local function ensureChild(parent: Instance, name: string, className: string): Instance
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
		return inst
	end
	return parent:WaitForChild(name, 30)
end

-- Call once on the server (Bootstrap does this) before anything else uses Net.
function Net.init()
	folder = ensureFolder()
	for _, name in ipairs(EVENTS) do
		ensureChild(folder, name, "RemoteEvent")
	end
	for _, name in ipairs(FUNCTIONS) do
		ensureChild(folder, name, "RemoteFunction")
	end
end

function Net.event(name: string): RemoteEvent
	if not folder then
		folder = ensureFolder()
	end
	return ensureChild(folder, name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	if not folder then
		folder = ensureFolder()
	end
	return ensureChild(folder, name, "RemoteFunction") :: RemoteFunction
end

Net.EventNames = EVENTS
Net.FunctionNames = FUNCTIONS

return Net

--!nonstrict
-- MonetisationManager
-- Everything Robux touches. Owns game-pass ownership caching, the
-- ProcessReceipt callback for Developer Products, and the grants those
-- purchases hand out.
--
-- Two rules this module exists to enforce:
--   1. A Developer Product grant is written to the profile and SAVED before
--      PurchaseGranted is returned. Returning granted on an unsaved grant is how
--      players lose purchases when a server dies.
--   2. Grants are idempotent on PurchaseId, because Roblox will replay
--      ProcessReceipt until it gets an answer it likes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Products = require(Shared.Products)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local OperationManager = require(script.Parent.OperationManager)

local MonetisationManager = {}

MonetisationManager.Granted = Instance.new("BindableEvent")
MonetisationManager.PassChanged = Instance.new("BindableEvent")

-- Cached so a call never blocks on a web request.
local passCache: { [number]: { [string]: boolean } } = {}

-- Product information comes from Roblox so Managed Pricing changes are shown
-- without a code release. Cache successful lookups briefly to avoid spending a
-- web request every time somebody opens the kiosk. Failures use the catalogue's
-- suggested price for a much shorter window before trying Roblox again.
local LIVE_PRICE_TTL = 300
local FALLBACK_PRICE_TTL = 30
local priceCache = {}

local function currentPrice(def, infoType): (number, boolean)
	if not Products.isConfigured(def) then
		return def.suggestedRobux, false
	end

	local cacheKey = tostring(def.assetId)
	local cached = priceCache[cacheKey]
	if cached and cached.expiresAt > os.clock() then
		return cached.robux, cached.isLive
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(def.assetId, infoType)
	end)
	local livePrice = ok and type(info) == "table" and tonumber(info.PriceInRobux) or nil
	local isLive = livePrice ~= nil and livePrice >= 0
	local robux = isLive and math.floor(livePrice) or def.suggestedRobux
	priceCache[cacheKey] = {
		robux = robux,
		isLive = isLive,
		expiresAt = os.clock() + (isLive and LIVE_PRICE_TTL or FALLBACK_PRICE_TTL),
	}
	if not ok then
		warn("[MonetisationManager] price lookup failed for " .. def.id .. ": " .. tostring(info))
	end
	return robux, isLive
end

--------------------------------------------------------------------------------
-- Game passes
--------------------------------------------------------------------------------

function MonetisationManager.refreshPasses(player: Player)
	local owned = {}
	for _, pass in ipairs(Products.GamePasses) do
		if Products.isConfigured(pass) then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
			end)
			if ok then
				owned[pass.id] = result == true
			else
				-- Keep whatever we already believed rather than revoking a pass
				-- because one web request failed.
				owned[pass.id] = passCache[player.UserId] and passCache[player.UserId][pass.id] or PlayerDataManager.ownsPass(player, pass.id)
				warn("[MonetisationManager] pass check failed for " .. pass.id .. ": " .. tostring(result))
			end
		end
	end
	passCache[player.UserId] = owned

	for passId, isOwned in pairs(owned) do
		local had = PlayerDataManager.ownsPass(player, passId)
		PlayerDataManager.setPassOwned(player, passId, isOwned)
		if isOwned and not had then
			MonetisationManager.PassChanged:Fire(player, Products.PassById[passId])
		end
	end
	return owned
end

function MonetisationManager.owns(player: Player, passId: string): boolean
	return PlayerDataManager.ownsPass(player, passId)
end

function MonetisationManager.promptPass(player: Player, passId: string): (boolean, string)
	local pass = Products.PassById[passId]
	if not pass then
		return false, "Unknown item."
	end
	if not Products.isConfigured(pass) then
		return false, pass.name .. " has not been set up yet (no asset id)."
	end
	if PlayerDataManager.ownsPass(player, passId) then
		return false, "You already own that."
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.assetId)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, ""
end

function MonetisationManager.promptProduct(player: Player, productId: string): (boolean, string)
	local product = Products.ProductById[productId]
	if not product then
		return false, "Unknown item."
	end
	if not Products.isConfigured(product) then
		return false, product.name .. " has not been set up yet (no asset id)."
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.assetId)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, ""
end

--------------------------------------------------------------------------------
-- Developer products
--------------------------------------------------------------------------------

local function grant(player: Player, product): (boolean, string)
	local kind = product.grant.kind

	if kind == "credits" then
		PlayerDataManager.addCredits(player, product.grant.amount, false)
		return true, string.format("%d Credits added.", product.grant.amount)
	elseif kind == "boost" then
		PlayerDataManager.addBoost(player, product.grant.seconds, product.grant.multiplier)
		return true, string.format("Double Credits for %d minutes.", math.floor(product.grant.seconds / 60))
	elseif kind == "payslip" then
		local summary = OperationManager.summary(player)
		local seconds = product.grant.hours * 3600
		local amount = math.floor((summary and summary.netIncome or 0) * seconds)
		if amount <= 0 then
			-- Nothing to pay out yet; bank it as a consumable so the purchase is
			-- never simply eaten.
			PlayerDataManager.addItem(player, product.id, 1)
			return true, "You have no staff yet, so this is saved in your drawer for later."
		end
		OperationManager.creditPassive(player, amount)
		return true, string.format("%d hours of passive income collected.", product.grant.hours)
	elseif kind == "consumable" then
		PlayerDataManager.addItem(player, product.id, product.grant.amount or 1)
		return true, product.name .. " added to your desk drawer."
	end

	return false, "Unknown grant type."
end

-- Wired up by MacrosoftServer. Returns a ProductPurchaseDecision.
function MonetisationManager.processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- They left mid-purchase. Do not consume it; Roblox retries when they
		-- next join a server.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = PlayerDataManager.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if profile.loadFailed then
		-- Saving is disabled this session, so a grant would silently vanish.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = Products.productByAssetId(receiptInfo.ProductId)
	if not product then
		warn("[MonetisationManager] receipt for unknown product " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	if not PlayerDataManager.claimReceipt(player, receiptId) then
		-- Already granted in an earlier attempt.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, message = grant(player, product)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Persist before confirming. If the save fails we hand the receipt back so
	-- Roblox retries rather than charging for something we did not keep.
	if not PlayerDataManager.save(player, false) then
		warn("[MonetisationManager] could not save grant for " .. player.Name .. "; asking Roblox to retry.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MonetisationManager.Granted:Fire(player, product, message)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- Catalogue view for the store UI
--------------------------------------------------------------------------------

function MonetisationManager.catalog(player: Player)
	local data = PlayerDataManager.get(player)
	local passes = {}
	for _, pass in ipairs(Products.GamePasses) do
		local robux, priceIsLive = currentPrice(pass, Enum.InfoType.GamePass)
		table.insert(passes, {
			id = pass.id,
			assetId = pass.assetId,
			name = pass.name,
			blurb = pass.blurb,
			order = pass.order,
			robux = robux,
			priceIsLive = priceIsLive,
			configured = Products.isConfigured(pass),
			owned = data ~= nil and data.premium.passes[pass.id] == true,
			cosmetic = pass.cosmetic == true,
		})
	end
	table.sort(passes, function(a, b)
		return a.order < b.order
	end)

	local products = {}
	for _, product in ipairs(Products.DeveloperProducts) do
		local robux, priceIsLive = currentPrice(product, Enum.InfoType.Product)
		table.insert(products, {
			id = product.id,
			assetId = product.assetId,
			name = product.name,
			blurb = product.blurb,
			order = product.order,
			robux = robux,
			priceIsLive = priceIsLive,
			configured = Products.isConfigured(product),
			owned = data ~= nil and (data.premium.inventory[product.id] or 0) or 0,
			usableInCall = product.usableInCall == true,
			usableInOperation = product.usableInOperation == true,
			useLabel = product.useLabel,
		})
	end
	table.sort(products, function(a, b)
		return a.order < b.order
	end)

	return { passes = passes, products = products }
end

function MonetisationManager.start()
	MarketplaceService.ProcessReceipt = MonetisationManager.processReceipt

	-- Warm the cache in parallel. The kiosk still resolves a missing entry on
	-- demand, so an early interaction remains correct.
	for _, pass in ipairs(Products.GamePasses) do
		task.spawn(currentPrice, pass, Enum.InfoType.GamePass)
	end
	for _, product in ipairs(Products.DeveloperProducts) do
		task.spawn(currentPrice, product, Enum.InfoType.Product)
	end

	local function onJoin(player: Player)
		task.spawn(function()
			-- Wait for the profile so ownership has somewhere to land.
			local deadline = os.clock() + 20
			while not PlayerDataManager.get(player) and os.clock() < deadline do
				task.wait(0.25)
			end
			if PlayerDataManager.get(player) then
				MonetisationManager.refreshPasses(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		onJoin(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		passCache[player.UserId] = nil
	end)

	-- Re-check ownership right after a prompt closes, so a pass bought in-game
	-- takes effect without rejoining.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _assetId, wasPurchased)
		if wasPurchased then
			task.spawn(MonetisationManager.refreshPasses, player)
		end
	end)
end

return MonetisationManager

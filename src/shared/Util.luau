--!nonstrict
-- Util
-- Small shared helpers. No game logic lives here.

local Util = {}

local rng = Random.new(os.clock() * 1e6 % 2 ^ 31)

-- Reseeds the shared generator. Used by the headless simulator so a test run is
-- reproducible; never called by the game itself.
function Util.setSeed(seed: number)
	rng = Random.new(seed)
end

function Util.newRandom(seed: number?): Random
	if seed then
		return Random.new(seed)
	end
	return Random.new(rng:NextInteger(1, 2 ^ 30))
end

function Util.clamp(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function Util.round(v: number, places: number?): number
	local m = 10 ^ (places or 0)
	return math.floor(v * m + 0.5) / m
end

-- Pick a uniformly random element from an array.
function Util.pick(list, random: Random?)
	if #list == 0 then
		return nil
	end
	local r = random or rng
	return list[r:NextInteger(1, #list)]
end

-- Pick n distinct elements (returns fewer if the list is short).
function Util.pickMany(list, n: number, random: Random?)
	local r = random or rng
	local copy = table.clone(list)
	local out = {}
	for _ = 1, math.min(n, #copy) do
		local i = r:NextInteger(1, #copy)
		table.insert(out, copy[i])
		table.remove(copy, i)
	end
	return out
end

-- Weighted pick. `list` entries must expose a numeric `weight` (default 1).
function Util.weightedPick(list, random: Random?)
	local r = random or rng
	local total = 0
	for _, entry in ipairs(list) do
		total += entry.weight or 1
	end
	if total <= 0 then
		return nil
	end
	local roll = r:NextNumber() * total
	local acc = 0
	for _, entry in ipairs(list) do
		acc += entry.weight or 1
		if roll <= acc then
			return entry
		end
	end
	return list[#list]
end

function Util.shuffle(list, random: Random?)
	local r = random or rng
	for i = #list, 2, -1 do
		local j = r:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function Util.deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Util.deepCopy(v)
	end
	return out
end

function Util.contains(list, value): boolean
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

function Util.count(dict): number
	local n = 0
	for _ in pairs(dict) do
		n += 1
	end
	return n
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Util.formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

-- Replace {tokens} in a string using a table of values.
function Util.interpolate(template: string, values): string
	return (string.gsub(template, "{(%w+)}", function(token)
		local v = values[token]
		if v == nil then
			return "{" .. token .. "}"
		end
		return tostring(v)
	end))
end

-- Merge `extra` into `base` (shallow), returning a new table.
function Util.merge(base, extra)
	local out = table.clone(base)
	for k, v in pairs(extra or {}) do
		out[k] = v
	end
	return out
end

return Util

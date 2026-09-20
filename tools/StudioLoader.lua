--[[ Macrosoft Support installer.
     Paste the whole thing into the Roblox Studio command bar and press Enter.
     It downloads every script from GitHub and puts it in the right service.
     Re-run it any time to update to the latest push.
     Deliberately free of -- line comments so it still works if the command bar
     flattens it onto one line. ]]
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
local BASE = "https://raw.githubusercontent.com/acetemperz-debug/roblox/refs/heads/claude/roblox-scam-call-centre-yx6beg/"
local okHttp = pcall(function()
	Http.HttpEnabled = true
end)
if not okHttp and not Http.HttpEnabled then
	warn("[Macrosoft] Turn on Game Settings > Security > Allow HTTP Requests, then run this again.")
	return
end
if not SPS then
	warn("[Macrosoft] No StarterPlayerScripts found.")
	return
end
local function fetch(path)
	local ok, body = pcall(function()
		return Http:GetAsync(BASE .. path, true)
	end)
	if not ok then
		return nil, tostring(body)
	end
	return body
end
local raw, err = fetch("build/manifest.json")
if not raw then
	warn("[Macrosoft] Could not reach GitHub: " .. tostring(err))
	return
end
local manifest = Http:JSONDecode(raw)
local old = RS:FindFirstChild("MacrosoftShared")
if old then
	old:Destroy()
end
old = SSS:FindFirstChild("MacrosoftServer")
if old then
	old:Destroy()
end
local shared = Instance.new("Folder")
shared.Name = "MacrosoftShared"
shared.Parent = RS
local server = Instance.new("Folder")
server.Name = "MacrosoftServer"
server.Parent = SSS
local homes = { shared = shared, server = server, client = SPS }
local done, failed = 0, {}
for _, entry in ipairs(manifest.files) do
	local source, why = fetch(entry.path)
	if source then
		local home = homes[entry.target]
		local existing = home:FindFirstChild(entry.name)
		if existing then
			existing:Destroy()
		end
		local inst = Instance.new(entry.class)
		inst.Name = entry.name
		inst.Source = source
		inst.Parent = home
		done += 1
	else
		table.insert(failed, entry.name .. " (" .. tostring(why) .. ")")
	end
end
print(string.format("[Macrosoft] Installed %d/%d scripts.", done, #manifest.files))
if #failed > 0 then
	warn("[Macrosoft] Failed: " .. table.concat(failed, ", "))
else
	print("[Macrosoft] Done. Turn on Studio Access to API Services, then press Play.")
end

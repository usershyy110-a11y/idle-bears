-- ================================================
-- AdminCommands — /coins add/remove/set <player> <amount>
-- Only ADMIN_ID can use these commands (via Player.Chatted)
-- Calls BearManager.ForceSetCoins to keep all state in sync
-- ================================================
local Players    = game:GetService("Players")
local ADMIN_ID   = 5647716264

-- Lazy-load BearManager to avoid circular require
local BearManager = nil
task.defer(function()
	BearManager = require(game:GetService("ServerScriptService"):WaitForChild("BearManager"))
end)

local function findPlayer(text)
	text = text:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower():sub(1,#text) == text then return plr end
		if plr.DisplayName:lower():sub(1,#text) == text then return plr end
	end
	return nil
end

local function notify(plr, ok, msg)
	local re = game.ReplicatedStorage:FindFirstChild("RemoteEvents")
	local resp = re and re:FindFirstChild("ShopResponse")
	if resp then resp:FireClient(plr, ok, msg) end
end

Players.PlayerAdded:Connect(function(plr)
	if plr.UserId ~= ADMIN_ID then return end

	plr.Chatted:Connect(function(msg)
		-- Format: /coins add|remove|set <player> <amount>
		local parts = msg:split(" ")
		if #parts < 4 then return end
		if parts[1]:lower() ~= "/coins" then return end

		local action = parts[2]:lower()
		if action ~= "add" and action ~= "remove" and action ~= "set" then return end

		local targetText = parts[3]
		local amount     = math.floor(tonumber(parts[4]) or 0)
		if amount < 0 then
			notify(plr, false, "Amount must be positive"); return
		end

		local target = findPlayer(targetText)
		if not target then
			notify(plr, false, "Player not found: " .. targetText); return
		end

		if not BearManager or not BearManager.ForceSetCoins then
			notify(plr, false, "BearManager not ready"); return
		end

		local pd = BearManager.GetPlayerData(target.UserId)
		if not pd then
			notify(plr, false, target.Name .. " has no data yet"); return
		end

		local current = pd.coins
		local newCoins
		if action == "add" then
			newCoins = current + amount
		elseif action == "remove" then
			newCoins = math.max(0, current - amount)
		elseif action == "set" then
			newCoins = amount
		end

		BearManager.ForceSetCoins(target, newCoins)
		notify(plr, true, ("Admin: %s %s coins → %d"):format(action, target.Name, newCoins))
		notify(target, true, ("💰 An admin adjusted your coins to %d"):format(newCoins))
	end)
end)

print("[AdminCommands] loaded ✓")

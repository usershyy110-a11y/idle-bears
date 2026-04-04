-- ================================================
-- Idle Bears | Shop Server Script
-- ================================================
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local DS                = DataStoreService:GetDataStore("BearData_v1")

local RS      = game.ReplicatedStorage
local remotes = RS:WaitForChild("RemoteEvents")
local SellRE  = remotes:WaitForChild("SellBear")
local BuyRE   = remotes:WaitForChild("BuyFood")
local RespRE  = remotes:WaitForChild("ShopResponse")
local tiers   = require(RS:WaitForChild("BearTiers"))

local SELL_COOLDOWN = 3
local BUY_COOLDOWN  = 1
local lastSell = {}
local lastBuy  = {}

local function getAge(plr)
    local stats = plr:FindFirstChild("BearStats")
    return stats and stats:FindFirstChild("Age")
end

local function getCoins(plr)
    local stats = plr:FindFirstChild("BearStats")
    return stats and stats:FindFirstChild("Coins")
end

local function getTierForAge(age)
    local best = tiers[1]
    for _, t in ipairs(tiers) do
        if age >= t.minAge then best = t end
    end
    return best
end

local function respond(plr, ok, msg)
    RespRE:FireClient(plr, ok, msg)
end

local function saveCoins(plr, coins)
    local key = "bear:" .. plr.UserId
    pcall(function()
        local ok, data = pcall(function() return DS:GetAsync(key) end)
        if ok and data then
            data.coins = coins
            DS:SetAsync(key, data)
        end
    end)
end

-- Leaderstats
Players.PlayerAdded:Connect(function(plr)
    local stats = plr:WaitForChild("BearStats", 10)
    if not stats then return end

    local key = "bear:" .. plr.UserId
    local savedCoins = 0
    pcall(function()
        local ok, data = pcall(function() return DS:GetAsync(key) end)
        if ok and data and data.coins then
            savedCoins = tonumber(data.coins) or 0
        end
    end)

    local coins = Instance.new("IntValue")
    coins.Name  = "Coins"
    coins.Value = savedCoins
    coins.Parent = stats

    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = plr

    local lsCoins = Instance.new("IntValue")
    lsCoins.Name  = "Coins"
    lsCoins.Value = savedCoins
    lsCoins.Parent = ls

    local lsAge = Instance.new("IntValue")
    lsAge.Name  = "Bear Age"
    lsAge.Parent = ls

    local age = stats:WaitForChild("Age", 5)
    if age then
        lsAge.Value = age.Value
        age:GetPropertyChangedSignal("Value"):Connect(function()
            lsAge.Value = age.Value
        end)
    end

    coins:GetPropertyChangedSignal("Value"):Connect(function()
        lsCoins.Value = coins.Value
    end)
end)

-- Sell Bear
SellRE.OnServerEvent:Connect(function(plr)
    local uid = plr.UserId
    local now = os.clock()
    if lastSell[uid] and (now - lastSell[uid]) < SELL_COOLDOWN then
        respond(plr, false, "Wait before selling again!")
        return
    end
    lastSell[uid] = now

    local ageVal  = getAge(plr)
    local coinVal = getCoins(plr)
    if not ageVal or not coinVal then
        respond(plr, false, "Bear not ready yet.")
        return
    end

    local tier   = getTierForAge(ageVal.Value)
    local earned = tier.sellPrice
    coinVal.Value += earned
    ageVal.Value  = 0
    saveCoins(plr, coinVal.Value)

    respond(plr, true, ("Sold %s %s for 💰 %d coins! Bear resets to Baby Cub."):format(
        tier.emoji, tier.name, earned))
end)

-- Buy Food
BuyRE.OnServerEvent:Connect(function(plr, foodName, foodCost, ageBonus)
    if type(foodName) ~= "string" then return end
    foodCost = tonumber(foodCost) or 0
    ageBonus = tonumber(ageBonus) or 0
    if foodCost <= 0 or ageBonus <= 0 or foodCost > 200 or ageBonus > 200 then return end

    local uid = plr.UserId
    local now = os.clock()
    if lastBuy[uid] and (now - lastBuy[uid]) < BUY_COOLDOWN then
        respond(plr, false, "Slow down!")
        return
    end
    lastBuy[uid] = now

    local ageVal  = getAge(plr)
    local coinVal = getCoins(plr)
    if not ageVal or not coinVal then return end

    if coinVal.Value < foodCost then
        respond(plr, false, ("Not enough coins! Need 💰 %d"):format(foodCost))
        return
    end

    coinVal.Value -= foodCost
    ageVal.Value  += ageBonus
    saveCoins(plr, coinVal.Value)

    respond(plr, true, ("Bought %s! Bear grew +%d age. 💰 -%d"):format(foodName, ageBonus, foodCost))
end)

print("[IdleBears] ShopServer loaded ✓")

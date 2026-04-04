-- ================================================
-- BearManager: owns bear slots, buying, upgrading, follow
-- ================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BearData_v2")

local RS       = game.ReplicatedStorage
local remotes  = RS:WaitForChild("RemoteEvents")
local tiers    = require(RS:WaitForChild("BearTiers"))
local SS       = game.ServerStorage
local models   = SS:WaitForChild("BearModels")

local BuyBearRE     = remotes:WaitForChild("BuyBear")
local UpgradeRE     = remotes:WaitForChild("UpgradeBear")
local ToggleFollowRE= remotes:WaitForChild("ToggleFollow")
local SlotUpdateRE  = remotes:WaitForChild("BearSlotUpdate")
local RespRE        = remotes:WaitForChild("ShopResponse")

local MAX_SLOTS    = 5
local STARTING_COINS = 30
local FOLLOW_SPEED = 14
local FOLLOW_GAP   = 5   -- studs between bears in line

local function getBuyPrice(tierIdx)
    return math.floor(tiers[tierIdx].sellPrice * 0.8)
end

local function getUpgradePrice(fromIdx, toIdx)
    if toIdx > #tiers then return math.huge end
    return math.floor((tiers[toIdx].sellPrice - tiers[fromIdx].sellPrice) * 0.7)
end

local function getTierById(id)
    for i, t in ipairs(tiers) do
        if t.id == id then return t, i end
    end
    return tiers[1], 1
end

-- ------------------------------------------------
-- Player state (server-side cache)
-- ------------------------------------------------
local playerData = {}   -- [userId] = { coins, slots={}, followEnabled }
-- slot = { tierId="t1", age=0, model=Model|nil }

local function getPlayerData(plr)
    return playerData[plr.UserId]
end

local function respond(plr, ok, msg)
    RespRE:FireClient(plr, ok, msg)
end

local function broadcastSlots(plr)
    local pd = getPlayerData(plr)
    if not pd then return end
    local info = {}
    for i, slot in ipairs(pd.slots) do
        local tier, tierIdx = getTierById(slot.tierId)
        info[i] = { tierId=slot.tierId, name=tier.name, emoji=tier.emoji, age=slot.age, tierIdx=tierIdx }
    end
    SlotUpdateRE:FireClient(plr, pd.coins, info, pd.followEnabled)
end

-- ------------------------------------------------
-- Bear model management
-- ------------------------------------------------
local function spawnBearModel(plr, slotIdx, tierId)
    local pd = getPlayerData(plr)
    if not pd then return end
    local slot = pd.slots[slotIdx]
    if not slot then return end

    if slot.model and slot.model.Parent then
        slot.model:Destroy()
    end

    local src = models:FindFirstChild("Bear_" .. tierId)
    if not src then return end

    local clone = src:Clone()
    clone.Name  = ("PlayerBear_%d_%d"):format(plr.UserId, slotIdx)
    clone.Parent = workspace

    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local basePos = root and root.Position or Vector3.new(0,5,0)
    local offset  = Vector3.new((slotIdx-1)*FOLLOW_GAP, 0, 6)

    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CFrame = part.CFrame + basePos + offset
            part.Anchored = true
            part.CanCollide = false
        end
    end

    slot.model = clone
    return clone
end

local function despawnBearModel(plr, slotIdx)
    local pd = getPlayerData(plr)
    if not pd then return end
    local slot = pd.slots[slotIdx]
    if slot and slot.model and slot.model.Parent then
        slot.model:Destroy()
        slot.model = nil
    end
end

-- ------------------------------------------------
-- Follow logic (runs every heartbeat)
-- ------------------------------------------------
local followConnections = {}

local function startFollow(plr)
    local uid = plr.UserId
    if followConnections[uid] then
        followConnections[uid]:Disconnect()
    end

    followConnections[uid] = RunService.Heartbeat:Connect(function(dt)
        local pd = playerData[uid]
        if not pd or not pd.followEnabled then return end
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local forward = root.CFrame.LookVector
        local right   = root.CFrame.RightVector

        for i, slot in ipairs(pd.slots) do
            if slot.model and slot.model.Parent then
                local row   = math.ceil(i / 3)
                local col   = ((i-1) % 3) - 1   -- -1, 0, 1
                local target = root.Position
                    - forward * (FOLLOW_GAP * row + FOLLOW_GAP)
                    + right   * (col * (FOLLOW_GAP * 0.8))

                local body = slot.model:FindFirstChild("Body")
                if not body then continue end
                local current = body.Position
                local newPos  = current:Lerp(target, math.min(dt * FOLLOW_SPEED, 1))
                local delta   = newPos - current

                for _, part in ipairs(slot.model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CFrame = part.CFrame + delta
                    end
                end
            end
        end
    end)
end

local function stopFollow(plr)
    local uid = plr.UserId
    if followConnections[uid] then
        followConnections[uid]:Disconnect()
        followConnections[uid] = nil
    end
end

-- ------------------------------------------------
-- Data persistence
-- ------------------------------------------------
local function saveData(plr)
    local pd = getPlayerData(plr)
    if not pd then return end
    local saved = { coins=pd.coins, slots={}, followEnabled=pd.followEnabled }
    for i, slot in ipairs(pd.slots) do
        saved.slots[i] = { tierId=slot.tierId, age=slot.age }
    end
    local key = "bearv2:" .. plr.UserId
    pcall(function() DS:SetAsync(key, saved) end)
end

local function loadData(plr)
    local key = "bearv2:" .. plr.UserId
    local ok, data = pcall(function() return DS:GetAsync(key) end)
    if ok and data then return data end
    return nil
end

-- ------------------------------------------------
-- Player Added
-- ------------------------------------------------
local function onPlayerAdded(plr)
    local saved = loadData(plr)

    local pd = {
        coins         = saved and saved.coins or STARTING_COINS,
        followEnabled = saved and saved.followEnabled ~= false or true,
        slots         = {},
    }
    playerData[plr.UserId] = pd

    if saved and saved.slots and #saved.slots > 0 then
        for _, s in ipairs(saved.slots) do
            table.insert(pd.slots, { tierId=s.tierId or "t1", age=s.age or 0, model=nil })
        end
    else
        -- New player: 1 free Baby Cub
        table.insert(pd.slots, { tierId="t1", age=0, model=nil })
    end

    local function onCharSpawned()
        task.wait(1)
        for i, slot in ipairs(pd.slots) do
            spawnBearModel(plr, i, slot.tierId)
        end
        if pd.followEnabled then startFollow(plr) end
        broadcastSlots(plr)
    end

    if plr.Character then onCharSpawned() end
    plr.CharacterAdded:Connect(onCharSpawned)

    -- Leaderstats
    local ls = Instance.new("Folder"); ls.Name="leaderstats"; ls.Parent=plr
    local lsCoins = Instance.new("IntValue"); lsCoins.Name="Coins"; lsCoins.Value=pd.coins; lsCoins.Parent=ls
    local lsBears = Instance.new("IntValue"); lsBears.Name="Bears"; lsBears.Value=#pd.slots; lsBears.Parent=ls

    -- BearStats folder (for UI compat)
    local stats = Instance.new("Folder"); stats.Name="BearStats"; stats.Parent=plr
    local coinsVal = Instance.new("IntValue"); coinsVal.Name="Coins"; coinsVal.Value=pd.coins; coinsVal.Parent=stats

    task.spawn(function()
        while plr.Parent do
            task.wait(2)
            local curr = playerData[plr.UserId]
            if curr then
                lsCoins.Value  = curr.coins
                coinsVal.Value = curr.coins
                lsBears.Value  = #curr.slots
            end
        end
    end)

    task.spawn(function()
        while plr.Parent do
            task.wait(60)
            saveData(plr)
        end
    end)
end

-- ------------------------------------------------
-- Player Removing
-- ------------------------------------------------
local function onPlayerRemoving(plr)
    stopFollow(plr)
    saveData(plr)
    local pd = getPlayerData(plr)
    if pd then
        for i in ipairs(pd.slots) do
            despawnBearModel(plr, i)
        end
    end
    playerData[plr.UserId] = nil
end

-- ------------------------------------------------
-- Buy Bear
-- ------------------------------------------------
BuyBearRE.OnServerEvent:Connect(function(plr, tierIdx)
    tierIdx = tonumber(tierIdx)
    if not tierIdx or tierIdx < 1 or tierIdx > #tiers then return end

    local pd = getPlayerData(plr)
    if not pd then return end

    if #pd.slots >= MAX_SLOTS then
        respond(plr, false, "You already have the maximum of " .. MAX_SLOTS .. " bears!")
        return
    end

    local price = getBuyPrice(tierIdx)
    if pd.coins < price then
        respond(plr, false, ("Not enough coins! Need 💰 %d"):format(price))
        return
    end

    pd.coins -= price
    local newSlot = { tierId=tiers[tierIdx].id, age=tiers[tierIdx].minAge, model=nil }
    table.insert(pd.slots, newSlot)
    local slotIdx = #pd.slots
    spawnBearModel(plr, slotIdx, newSlot.tierId)

    respond(plr, true, ("Bought %s %s! 💰 -%d"):format(tiers[tierIdx].emoji, tiers[tierIdx].name, price))
    broadcastSlots(plr)
    saveData(plr)
end)

-- ------------------------------------------------
-- Upgrade Bear
-- ------------------------------------------------
UpgradeRE.OnServerEvent:Connect(function(plr, slotIdx)
    slotIdx = tonumber(slotIdx)
    if not slotIdx then return end

    local pd = getPlayerData(plr)
    if not pd then return end

    local slot = pd.slots[slotIdx]
    if not slot then respond(plr, false, "Invalid bear slot."); return end

    local _, currIdx = getTierById(slot.tierId)
    local nextIdx    = currIdx + 1
    if nextIdx > #tiers then
        respond(plr, false, "This bear is already at max tier! 👑")
        return
    end

    local price = getUpgradePrice(currIdx, nextIdx)
    if pd.coins < price then
        respond(plr, false, ("Need 💰 %d to upgrade to %s"):format(price, tiers[nextIdx].name))
        return
    end

    pd.coins   -= price
    slot.tierId = tiers[nextIdx].id
    slot.age    = tiers[nextIdx].minAge

    spawnBearModel(plr, slotIdx, slot.tierId)

    respond(plr, true, ("Upgraded to %s %s! 💰 -%d"):format(tiers[nextIdx].emoji, tiers[nextIdx].name, price))
    broadcastSlots(plr)
    saveData(plr)
end)

-- ------------------------------------------------
-- Toggle Follow
-- ------------------------------------------------
ToggleFollowRE.OnServerEvent:Connect(function(plr)
    local pd = getPlayerData(plr)
    if not pd then return end
    pd.followEnabled = not pd.followEnabled
    if pd.followEnabled then
        startFollow(plr)
        respond(plr, true, "Bears are now following you! 🐻")
    else
        stopFollow(plr)
        respond(plr, true, "Bears stopped following.")
    end
    broadcastSlots(plr)
end)

-- ------------------------------------------------
-- Sell Bear
-- ------------------------------------------------
local SellRE = remotes:WaitForChild("SellBear")
SellRE.OnServerEvent:Connect(function(plr, slotIdx)
    slotIdx = tonumber(slotIdx) or 1
    local pd = getPlayerData(plr)
    if not pd then return end

    local slot = pd.slots[slotIdx]
    if not slot then respond(plr, false, "Invalid slot."); return end

    local tier, _ = getTierById(slot.tierId)
    local earned = tier.sellPrice
    pd.coins += earned

    despawnBearModel(plr, slotIdx)
    table.remove(pd.slots, slotIdx)

    for i, s in ipairs(pd.slots) do
        if s.model then s.model:Destroy(); s.model = nil end
        spawnBearModel(plr, i, s.tierId)
    end

    respond(plr, true, ("Sold %s %s for 💰 %d!"):format(tier.emoji, tier.name, earned))
    broadcastSlots(plr)
    saveData(plr)
end)

-- ------------------------------------------------
-- Idle growth loop
-- ------------------------------------------------
task.spawn(function()
    while true do
        task.wait(30)
        for uid, pd in pairs(playerData) do
            for _, slot in ipairs(pd.slots) do
                slot.age += 1
                local _, currIdx = getTierById(slot.tierId)
                if currIdx < #tiers and slot.age >= tiers[currIdx+1].minAge then
                    slot.tierId = tiers[currIdx+1].id
                    local plr = Players:GetPlayerByUserId(uid)
                    if plr then
                        for i, s in ipairs(pd.slots) do
                            if s == slot then
                                spawnBearModel(plr, i, slot.tierId)
                                broadcastSlots(plr)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ------------------------------------------------
-- Init
-- ------------------------------------------------
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, plr in ipairs(Players:GetPlayers()) do
    onPlayerAdded(plr)
end

print("[BearManager] loaded ✓")
return {}

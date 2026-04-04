-- ================================================
-- Idle Bears | Main Server Script
-- ================================================
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DS = DataStoreService:GetDataStore("BearData_v1")
local template = game.ServerStorage:WaitForChild("BearTemplate")

-- קבועים
local GROW_INTERVAL   = 30   -- שניות בין טיקים (production)
local AGE_PER_TICK    = 1
local MAX_AGE_COLOR   = 100  -- גיל מקסימלי לצבע מלא
local FEED_BONUS      = 3
local WATER_BONUS     = 2
local ACTION_COOLDOWN = 2    -- שניות מינימום בין פעולות שחקן
local SAVE_INTERVAL   = 60   -- שמירה כל 60 שניות

local white  = Color3.fromRGB(255, 255, 255)
local yellow = Color3.fromRGB(255, 255, 180)

-- RemoteEvents
local remotes = game.ReplicatedStorage:WaitForChild("RemoteEvents")
local FeedRE  = remotes:WaitForChild("FeedBear")
local WaterRE = remotes:WaitForChild("WaterBear")

-- Rate-limit per player
local lastAction = {}  -- [userId] = os.clock()

-- ------------------------------------------------
-- פונקציות עזר
-- ------------------------------------------------
local function applyColor(bearModel, age)
	if not bearModel then return end
	local body = bearModel:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then return end
	local t = math.clamp(age / MAX_AGE_COLOR, 0, 1)
	body.Color = white:Lerp(yellow, t)
end

local function saveData(plr, age)
	local key = "bear:" .. plr.UserId
	pcall(function()
		DS:SetAsync(key, { age = age, savedAt = os.time() })
	end)
end

local function loadData(plr)
	local key = "bear:" .. plr.UserId
	local ok, data = pcall(function() return DS:GetAsync(key) end)
	if ok and data then
		return tonumber(data.age) or 0, tonumber(data.savedAt) or os.time()
	end
	return 0, os.time()
end

-- ------------------------------------------------
-- שחקן נכנס
-- ------------------------------------------------
Players.PlayerAdded:Connect(function(plr)
	local savedAge, savedAt = loadData(plr)

	-- offline growth: כמה טיקים עברו כשהשחקן לא היה
	local elapsed      = os.time() - savedAt
	local offlineTicks = math.floor(elapsed / GROW_INTERVAL)
	local startAge     = savedAge + (offlineTicks * AGE_PER_TICK)

	-- סטטוס
	local stats = Instance.new("Folder")
	stats.Name  = "BearStats"
	stats.Parent = plr

	local Age = Instance.new("IntValue")
	Age.Name  = "Age"
	Age.Value = startAge
	Age.Parent = stats

	-- דובון אישי
	local clone = template:Clone()
	clone.Name  = ("Bear_%d"):format(plr.UserId)
	clone:SetAttribute("OwnerUserId", plr.UserId)
	clone.Parent = workspace
	applyColor(clone, Age.Value)

	Age.Changed:Connect(function()
		applyColor(clone, Age.Value)
	end)

	-- שמירה תקופתית
	task.spawn(function()
		while plr.Parent do
			task.wait(SAVE_INTERVAL)
			saveData(plr, Age.Value)
		end
	end)

	print(("[IdleBears] %s נכנס | גיל: %d (offline growth: %d)"):format(plr.Name, startAge, offlineTicks))
end)

-- ------------------------------------------------
-- שחקן יוצא
-- ------------------------------------------------
Players.PlayerRemoving:Connect(function(plr)
	local stats = plr:FindFirstChild("BearStats")
	local age   = stats and stats:FindFirstChild("Age")
	if age then saveData(plr, age.Value) end

	local bear = workspace:FindFirstChild(("Bear_%d"):format(plr.UserId))
	if bear then bear:Destroy() end
	lastAction[plr.UserId] = nil
end)

-- ------------------------------------------------
-- לולאת גדילה Idle (task.spawn — לא חוסמת)
-- ------------------------------------------------
task.spawn(function()
	while true do
		task.wait(GROW_INTERVAL)
		for _, plr in ipairs(Players:GetPlayers()) do
			local stats = plr:FindFirstChild("BearStats")
			local Age   = stats and stats:FindFirstChild("Age")
			if Age then
				Age.Value += AGE_PER_TICK
			end
		end
	end
end)

-- ------------------------------------------------
-- פעולות האכלה / השקיה (עם rate-limit)
-- ------------------------------------------------
local function handleAction(plr, bonus)
	local uid = plr.UserId
	local now = os.clock()
	if lastAction[uid] and (now - lastAction[uid]) < ACTION_COOLDOWN then
		return  -- מהיר מדי, התעלם
	end
	lastAction[uid] = now

	local stats = plr:FindFirstChild("BearStats")
	local Age   = stats and stats:FindFirstChild("Age")
	if Age then Age.Value += bonus end
end

FeedRE.OnServerEvent:Connect(function(plr)  handleAction(plr, FEED_BONUS)  end)
WaterRE.OnServerEvent:Connect(function(plr) handleAction(plr, WATER_BONUS) end)

print("[IdleBears] Main Server Script טעון ✓")

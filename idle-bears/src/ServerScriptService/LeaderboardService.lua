-- ================================================
-- LeaderboardService — ODS-based leaderboards
-- Boards: Top Richest Players, Top Oldest Brainrots, Newest Brainrots
-- ================================================
local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local CoinsODS   = DataStoreService:GetOrderedDataStore("CoinsLeaderboard_v1")
local OldestODS  = DataStoreService:GetOrderedDataStore("OldestBrainrots_v1")
local NewestODS  = DataStoreService:GetOrderedDataStore("NewestBrainrots_v1")
local PetMetaDS  = DataStoreService:GetDataStore("BrainrotMeta_v1")

local REFRESH_RATE = 60  -- seconds

-- ---- Public: Update coins for a player ----
function LeaderboardService.UpdateCoins(userId, coins)
	task.spawn(function()
		pcall(function()
			CoinsODS:SetAsync(tostring(userId), math.max(0, math.floor(coins)))
		end)
	end)
end

-- ---- Public: Update pet leaderboards ----
function LeaderboardService.UpdatePet(userId, userName, slot)
	if not slot or not slot.petId then return end
	task.spawn(function()
		pcall(function()
			PetMetaDS:SetAsync(slot.petId, {
				ownerUserId = userId,
				ownerName   = userName,
				tierId      = slot.tierId,
				age         = slot.age,
				createdAt   = slot.createdAt or 0,
			})
			OldestODS:SetAsync(slot.petId, math.floor(slot.age))
			NewestODS:SetAsync(slot.petId, math.floor(slot.createdAt or 0))
		end)
	end)
end

-- ---- UI helpers ----
local function getOrMakeGui(part)
	local sg = part:FindFirstChildOfClass("SurfaceGui")
	if not sg then
		sg = Instance.new("SurfaceGui")
		sg.Face    = Enum.NormalId.Front
		sg.Name    = "SurfaceGui"
		sg.Parent  = part
	end
	local frame = sg:FindFirstChild("Container")
	if not frame then
		frame          = Instance.new("ScrollingFrame")
		frame.Name     = "Container"
		frame.Size     = UDim2.new(1,0,1,0)
		frame.BackgroundColor3 = Color3.fromRGB(15,15,25)
		frame.ScrollBarThickness = 0
		frame.CanvasSize = UDim2.new(0,0,0,0)
		frame.Parent   = sg

		local layout = Instance.new("UIListLayout")
		layout.Padding         = UDim.new(0,4)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent          = frame
	end
	return frame
end

local function makeRow(text, rankColor)
	local f = Instance.new("Frame")
	f.Size  = UDim2.new(0.95,0,0,42)
	f.BackgroundColor3 = Color3.fromRGB(25,25,40)
	f.BorderSizePixel  = 0
	Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1,-12,1,0)
	lbl.Position           = UDim2.new(0,6,0,0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = rankColor or Color3.fromRGB(230,230,230)
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Text               = text
	lbl.Parent             = f
	return f
end

local function makeTitle(container, text, color)
	-- remove existing title
	local old = container:FindFirstChild("__Title")
	if old then old:Destroy() end

	local f = Instance.new("Frame")
	f.Name = "__Title"
	f.Size = UDim2.new(1,0,0,54)
	f.BackgroundColor3 = color
	f.BorderSizePixel  = 0
	Instance.new("UICorner",f).CornerRadius = UDim.new(0,10)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = Color3.fromRGB(255,255,255)
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.Text               = text
	lbl.Parent             = f
	f.Parent               = container
	return f
end

local rankColors = {
	Color3.fromRGB(255,210,0),   -- gold
	Color3.fromRGB(200,200,210), -- silver
	Color3.fromRGB(205,127,50),  -- bronze
}
local function rankColor(i)
	return rankColors[i] or Color3.fromRGB(180,180,200)
end

-- ---- Refresh: Coins board ----
local function refreshCoinsBoard(container)
	-- clear old rows
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "__Title" then c:Destroy() end
	end
	makeTitle(container, "💰 Top Richest Players", Color3.fromRGB(180,120,0))

	local ok, pages = pcall(function()
		return CoinsODS:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then return end

	for rank, data in ipairs(pages:GetCurrentPage()) do
		local userId  = tonumber(data.key)
		local coins   = data.value
		local name    = "Player"
		pcall(function()
			name = Players:GetNameFromUserIdAsync(userId)
		end)
		local row = makeRow(
			("%d.  %s  —  💰 %s"):format(rank, name, tostring(coins)),
			rankColor(rank)
		)
		row.Name   = "Row"..rank
		row.Parent = container
	end
end

-- ---- Refresh: Oldest board ----
local function refreshOldestBoard(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "__Title" then c:Destroy() end
	end
	makeTitle(container, "⏳ Top Oldest Brainrots", Color3.fromRGB(60,120,200))

	local ok, pages = pcall(function()
		return OldestODS:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then return end

	for rank, data in ipairs(pages:GetCurrentPage()) do
		local petId = data.key
		local age   = data.value
		local meta  = {ownerName="?", tierId="t1"}
		pcall(function()
			local m = PetMetaDS:GetAsync(petId)
			if m then meta = m end
		end)
		local row = makeRow(
			("%d.  %s  — Age %d  (%s)"):format(rank, meta.tierId, age, meta.ownerName),
			rankColor(rank)
		)
		row.Name   = "Row"..rank
		row.Parent = container
	end
end

-- ---- Refresh: Newest board ----
local function refreshNewestBoard(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "__Title" then c:Destroy() end
	end
	makeTitle(container, "🆕 Newest Brainrots", Color3.fromRGB(40,160,80))

	local ok, pages = pcall(function()
		return NewestODS:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then return end

	for rank, data in ipairs(pages:GetCurrentPage()) do
		local petId = data.key
		local meta  = {ownerName="?", tierId="t1"}
		pcall(function()
			local m = PetMetaDS:GetAsync(petId)
			if m then meta = m end
		end)
		local row = makeRow(
			("%d.  %s  (%s)"):format(rank, meta.tierId, meta.ownerName),
			rankColor(rank)
		)
		row.Name   = "Row"..rank
		row.Parent = container
	end
end

-- ---- Public: Start refresh loop ----
function LeaderboardService.Start()
	task.spawn(function()
		while true do
			local boards = workspace:FindFirstChild("Leaderboards")
			if boards then
				local cb = boards:FindFirstChild("CoinsBoard")
				local ob = boards:FindFirstChild("OldestBoard")
				local nb = boards:FindFirstChild("NewestBoard")
				if cb then pcall(refreshCoinsBoard,  getOrMakeGui(cb)) end
				if ob then pcall(refreshOldestBoard, getOrMakeGui(ob)) end
				if nb then pcall(refreshNewestBoard, getOrMakeGui(nb)) end
			end
			task.wait(REFRESH_RATE)
		end
	end)
end

return LeaderboardService

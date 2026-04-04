-- ================================================
-- Idle Bears | UI Client Script
-- ================================================
local Players    = game:GetService("Players")
local plr        = Players.LocalPlayer
local remotes    = game.ReplicatedStorage:WaitForChild("RemoteEvents")
local FeedRE     = remotes:WaitForChild("FeedBear")
local WaterRE    = remotes:WaitForChild("WaterBear")

-- ------------------------------------------------
-- בניית GUI
-- ------------------------------------------------
local gui           = Instance.new("ScreenGui")
gui.Name            = "BearUI"
gui.ResetOnSpawn    = false
gui.Parent          = plr:WaitForChild("PlayerGui")

local function makeButton(text, posX, color)
	local frame = Instance.new("Frame")
	frame.Size            = UDim2.new(0, 130, 0, 50)
	frame.Position        = UDim2.new(0, posX, 1, -80)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent          = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Size                = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                = text
	btn.TextColor3          = Color3.fromRGB(255, 255, 255)
	btn.TextScaled          = true
	btn.Font                = Enum.Font.GothamBold
	btn.Parent              = frame

	return btn, frame
end

local feedBtn,  feedFrame  = makeButton("🥕 Feed",  20,  Color3.fromRGB(220, 130, 50))
local waterBtn, waterFrame = makeButton("💧 Water", 165, Color3.fromRGB(70, 140, 220))

-- תצוגת גיל
local ageLabel = Instance.new("TextLabel")
ageLabel.Size               = UDim2.new(0, 200, 0, 36)
ageLabel.Position           = UDim2.new(0, 20, 1, -125)
ageLabel.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
ageLabel.BackgroundTransparency = 0.35
ageLabel.TextColor3         = Color3.fromRGB(255, 255, 220)
ageLabel.TextScaled         = true
ageLabel.Font               = Enum.Font.GothamBold
ageLabel.Text               = "🐻 Bear Age: ..."
ageLabel.Parent             = gui

local agecorner = Instance.new("UICorner")
agecorner.CornerRadius = UDim.new(0, 8)
agecorner.Parent = ageLabel

-- ------------------------------------------------
-- חיבור לנתוני השחקן
-- ------------------------------------------------
local stats = plr:WaitForChild("BearStats")
local Age   = stats:WaitForChild("Age")

local function refreshAge()
	ageLabel.Text = ("🐻 Bear Age: %d"):format(Age.Value)
end
refreshAge()
Age:GetPropertyChangedSignal("Value"):Connect(refreshAge)

-- ------------------------------------------------
-- לחיצות כפתורים עם cooldown ויזואלי
-- ------------------------------------------------
local COOLDOWN = 0.5
local busy = false

local function clickAction(btn, frame, remote, origColor)
	if busy then return end
	busy = true
	frame.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	remote:FireServer()
	task.delay(COOLDOWN, function()
		frame.BackgroundColor3 = origColor
		busy = false
	end)
end

feedBtn.MouseButton1Click:Connect(function()
	clickAction(feedBtn, feedFrame, FeedRE, Color3.fromRGB(220, 130, 50))
end)

waterBtn.MouseButton1Click:Connect(function()
	clickAction(waterBtn, waterFrame, WaterRE, Color3.fromRGB(70, 140, 220))
end)

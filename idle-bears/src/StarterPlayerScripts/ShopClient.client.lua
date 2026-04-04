-- ================================================
-- Idle Bears | Shop Client Script
-- ================================================
local Players  = game:GetService("Players")
local plr      = Players.LocalPlayer
local RS       = game.ReplicatedStorage
local remotes  = RS:WaitForChild("RemoteEvents")
local SellRE   = remotes:WaitForChild("SellBear")
local BuyRE    = remotes:WaitForChild("BuyFood")
local RespRE   = remotes:WaitForChild("ShopResponse")
local tiers    = require(RS:WaitForChild("BearTiers"))

-- Notification
local pg = plr:WaitForChild("PlayerGui")
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "NotifGui"; notifGui.ResetOnSpawn = false; notifGui.Parent = pg

local notifFrame = Instance.new("Frame")
notifFrame.Size = UDim2.new(0,320,0,60)
notifFrame.Position = UDim2.new(0.5,-160,0,20)
notifFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
notifFrame.BackgroundTransparency = 0.2
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
notifFrame.Parent = notifGui
Instance.new("UICorner", notifFrame).CornerRadius = UDim.new(0,12)

local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(1,-16,1,0); notifLabel.Position = UDim2.new(0,8,0,0)
notifLabel.BackgroundTransparency = 1; notifLabel.TextColor3 = Color3.fromRGB(255,255,255)
notifLabel.TextScaled = true; notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextWrapped = true; notifLabel.Parent = notifFrame

local notifTask = nil
local function showNotif(ok, msg)
    notifFrame.BackgroundColor3 = ok and Color3.fromRGB(30,120,50) or Color3.fromRGB(140,30,30)
    notifLabel.Text = msg; notifFrame.Visible = true
    if notifTask then task.cancel(notifTask) end
    notifTask = task.delay(3, function() notifFrame.Visible = false end)
end

RespRE.OnClientEvent:Connect(showNotif)

-- Food definitions (must match ShopServer)
local foodDefs = {
    {name="Honey Jar",   cost=5,  bonus=5,  color=Color3.fromRGB(200,150,0)},
    {name="Berries",     cost=10, bonus=12, color=Color3.fromRGB(160,30,100)},
    {name="Fish",        cost=20, bonus=28, color=Color3.fromRGB(60,150,200)},
    {name="Magic Fruit", cost=40, bonus=60, color=Color3.fromRGB(140,0,220)},
}

local function getTierForAge(age)
    local best = tiers[1]
    for _, t in ipairs(tiers) do if age >= t.minAge then best = t end end
    return best
end

-- Shop Panel
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "ShopGui"; shopGui.ResetOnSpawn = false; shopGui.Enabled = false; shopGui.Parent = pg

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,340,0,420); panel.Position = UDim2.new(0.5,-170,0.5,-210)
panel.BackgroundColor3 = Color3.fromRGB(35,20,10); panel.BorderSizePixel = 0; panel.Parent = shopGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,50); title.BackgroundColor3 = Color3.fromRGB(180,60,60)
title.BorderSizePixel = 0; title.TextColor3 = Color3.fromRGB(255,240,180)
title.TextScaled = true; title.Font = Enum.Font.GothamBold; title.Text = "🐻 Bear Shop"; title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0,16)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,36,0,36); closeBtn.Position = UDim2.new(1,-42,0,7)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50); closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Text = "✕"; closeBtn.TextScaled = true; closeBtn.Font = Enum.Font.GothamBold; closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function() shopGui.Enabled = false end)

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Size = UDim2.new(1,-16,0,32); coinsLbl.Position = UDim2.new(0,8,0,56)
coinsLbl.BackgroundTransparency = 1; coinsLbl.TextColor3 = Color3.fromRGB(255,220,50)
coinsLbl.TextScaled = true; coinsLbl.Font = Enum.Font.GothamBold; coinsLbl.Text = "💰 Coins: ..."; coinsLbl.Parent = panel

local bearInfoLbl = Instance.new("TextLabel")
bearInfoLbl.Size = UDim2.new(1,-16,0,28); bearInfoLbl.Position = UDim2.new(0,8,0,90)
bearInfoLbl.BackgroundTransparency = 1; bearInfoLbl.TextColor3 = Color3.fromRGB(200,180,150)
bearInfoLbl.TextScaled = true; bearInfoLbl.Font = Enum.Font.Gotham; bearInfoLbl.Text = "Bear: ..."; bearInfoLbl.Parent = panel

local sellBtn = Instance.new("TextButton")
sellBtn.Size = UDim2.new(1,-16,0,56); sellBtn.Position = UDim2.new(0,8,0,126)
sellBtn.BackgroundColor3 = Color3.fromRGB(200,140,30); sellBtn.TextColor3 = Color3.fromRGB(255,255,255)
sellBtn.TextScaled = true; sellBtn.Font = Enum.Font.GothamBold; sellBtn.Text = "🐻 Sell Bear"; sellBtn.Parent = panel
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0,12)

local foodTitle = Instance.new("TextLabel")
foodTitle.Size = UDim2.new(1,-16,0,28); foodTitle.Position = UDim2.new(0,8,0,200)
foodTitle.BackgroundTransparency = 1; foodTitle.TextColor3 = Color3.fromRGB(180,230,140)
foodTitle.TextScaled = true; foodTitle.Font = Enum.Font.GothamBold; foodTitle.Text = "🥕 Buy Food"; foodTitle.Parent = panel

local foodBtns = {}
for i, fd in ipairs(foodDefs) do
    local fb = Instance.new("TextButton")
    fb.Size = UDim2.new(0.46,0,0,44)
    fb.Position = UDim2.new(((i-1)%2)*0.5+0.02,0,0,232+math.floor((i-1)/2)*52)
    fb.BackgroundColor3 = fd.color; fb.TextColor3 = Color3.fromRGB(255,255,255)
    fb.TextScaled = true; fb.Font = Enum.Font.GothamBold; fb.TextWrapped = true
    fb.Text = fd.name.."\n💰"..fd.cost.." (+"..fd.bonus..")"; fb.Parent = panel
    Instance.new("UICorner", fb).CornerRadius = UDim.new(0,10)
    fb.MouseButton1Click:Connect(function()
        BuyRE:FireServer(fd.name, fd.cost, fd.bonus)
        shopGui.Enabled = false
    end)
    table.insert(foodBtns, fb)
end

local function refreshPanel()
    local stats = plr:FindFirstChild("BearStats"); if not stats then return end
    local age   = stats:FindFirstChild("Age")
    local coins = stats:FindFirstChild("Coins")
    if not age or not coins then return end
    coinsLbl.Text = "💰 Coins: " .. coins.Value
    local tier = getTierForAge(age.Value)
    bearInfoLbl.Text = tier.emoji.." "..tier.name.."  (Age "..age.Value..")"
    sellBtn.Text = "🐻 Sell "..tier.name.." — 💰 "..tier.sellPrice
end

task.spawn(function()
    local farm = workspace:WaitForChild("BearFarm",10); if not farm then return end
    local shop = farm:WaitForChild("Shop",10); if not shop then return end
    local function hookPrompt(partName, mode)
        local trigger = shop:WaitForChild(partName,10); if not trigger then return end
        local pp = trigger:FindFirstChildOfClass("ProximityPrompt"); if not pp then return end
        pp.Triggered:Connect(function()
            refreshPanel()
            title.Text = mode=="sell" and "🐻 Sell Bear" or "🥕 Buy Food"
            sellBtn.Visible = mode=="sell"
            foodTitle.Visible = mode=="buy"
            for _, fb in ipairs(foodBtns) do fb.Visible = mode=="buy" end
            shopGui.Enabled = true
        end)
    end
    hookPrompt("Sell Bear","sell")
    hookPrompt("Buy Bear Food","buy")
end)

task.spawn(function()
    local stats = plr:WaitForChild("BearStats",10); if not stats then return end
    local coins = stats:WaitForChild("Coins",10); if not coins then return end
    coins:GetPropertyChangedSignal("Value"):Connect(function()
        if shopGui.Enabled then refreshPanel() end
    end)
end)

sellBtn.MouseButton1Click:Connect(function()
    SellRE:FireServer(); shopGui.Enabled = false
end)

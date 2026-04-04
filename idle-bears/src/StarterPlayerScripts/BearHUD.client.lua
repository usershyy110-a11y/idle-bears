-- ================================================
-- Idle Bears | Bear HUD + Shop Client
-- ================================================
local Players    = game:GetService("Players")
local plr        = Players.LocalPlayer
local RS         = game.ReplicatedStorage
local remotes    = RS:WaitForChild("RemoteEvents")
local tiers      = require(RS:WaitForChild("BearTiers"))

local BuyBearRE      = remotes:WaitForChild("BuyBear")
local UpgradeRE      = remotes:WaitForChild("UpgradeBear")
local ToggleFollowRE = remotes:WaitForChild("ToggleFollow")
local SellRE         = remotes:WaitForChild("SellBear")
local SlotUpdateRE   = remotes:WaitForChild("BearSlotUpdate")
local RespRE         = remotes:WaitForChild("ShopResponse")

local MAX_SLOTS = 5
local pg = plr:WaitForChild("PlayerGui")

-- ================================================
-- NOTIFICATION
-- ================================================
local notifSG = Instance.new("ScreenGui")
notifSG.Name="NotifGui"; notifSG.ResetOnSpawn=false; notifSG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; notifSG.Parent=pg

local notifFrame = Instance.new("Frame")
notifFrame.Size=UDim2.new(0,340,0,58); notifFrame.Position=UDim2.new(0.5,-170,0,18)
notifFrame.BackgroundColor3=Color3.fromRGB(20,20,20); notifFrame.BackgroundTransparency=0.15
notifFrame.BorderSizePixel=0; notifFrame.Visible=false; notifFrame.Parent=notifSG
Instance.new("UICorner",notifFrame).CornerRadius=UDim.new(0,12)

local notifLbl = Instance.new("TextLabel")
notifLbl.Size=UDim2.new(1,-16,1,0); notifLbl.Position=UDim2.new(0,8,0,0)
notifLbl.BackgroundTransparency=1; notifLbl.TextColor3=Color3.fromRGB(255,255,255)
notifLbl.TextScaled=true; notifLbl.Font=Enum.Font.GothamBold; notifLbl.TextWrapped=true
notifLbl.Parent=notifFrame
local _nt=nil
local function notify(ok,msg)
    notifFrame.BackgroundColor3 = ok and Color3.fromRGB(25,110,45) or Color3.fromRGB(130,25,25)
    notifLbl.Text=msg; notifFrame.Visible=true
    if _nt then task.cancel(_nt) end
    _nt=task.delay(3.5,function() notifFrame.Visible=false end)
end
RespRE.OnClientEvent:Connect(notify)

-- ================================================
-- COINS BAR (top-left)
-- ================================================
local coinsSG = Instance.new("ScreenGui")
coinsSG.Name="CoinsGui"; coinsSG.ResetOnSpawn=false; coinsSG.Parent=pg

local coinsFrame = Instance.new("Frame")
coinsFrame.Size=UDim2.new(0,180,0,40); coinsFrame.Position=UDim2.new(0,14,0,14)
coinsFrame.BackgroundColor3=Color3.fromRGB(25,18,8); coinsFrame.BackgroundTransparency=0.15
coinsFrame.BorderSizePixel=0; coinsFrame.Parent=coinsSG
Instance.new("UICorner",coinsFrame).CornerRadius=UDim.new(0,10)

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Size=UDim2.new(1,0,1,0); coinsLbl.BackgroundTransparency=1
coinsLbl.TextColor3=Color3.fromRGB(255,220,50); coinsLbl.TextScaled=true
coinsLbl.Font=Enum.Font.GothamBold; coinsLbl.Text="💰 0"; coinsLbl.Parent=coinsFrame

-- ================================================
-- FOLLOW TOGGLE BUTTON (bottom-right)
-- ================================================
local followSG = Instance.new("ScreenGui")
followSG.Name="FollowGui"; followSG.ResetOnSpawn=false; followSG.Parent=pg

local followBtn = Instance.new("TextButton")
followBtn.Size=UDim2.new(0,170,0,46); followBtn.Position=UDim2.new(1,-184,1,-70)
followBtn.BackgroundColor3=Color3.fromRGB(40,140,60); followBtn.BorderSizePixel=0
followBtn.TextColor3=Color3.fromRGB(255,255,255); followBtn.TextScaled=true
followBtn.Font=Enum.Font.GothamBold; followBtn.Text="🐻 Following"; followBtn.Parent=followSG
Instance.new("UICorner",followBtn).CornerRadius=UDim.new(0,12)

local followEnabled = true
followBtn.MouseButton1Click:Connect(function()
    ToggleFollowRE:FireServer()
end)

-- ================================================
-- BEAR SLOTS HUD (bottom-center)
-- ================================================
local slotsSG = Instance.new("ScreenGui")
slotsSG.Name="SlotsGui"; slotsSG.ResetOnSpawn=false; slotsSG.Parent=pg

local slotsFrame = Instance.new("Frame")
slotsFrame.Size=UDim2.new(0,360,0,80); slotsFrame.Position=UDim2.new(0.5,-180,1,-100)
slotsFrame.BackgroundColor3=Color3.fromRGB(20,12,5); slotsFrame.BackgroundTransparency=0.2
slotsFrame.BorderSizePixel=0; slotsFrame.Parent=slotsSG
Instance.new("UICorner",slotsFrame).CornerRadius=UDim.new(0,14)

local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection=Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
slotsLayout.VerticalAlignment=Enum.VerticalAlignment.Center
slotsLayout.Padding=UDim.new(0,6); slotsLayout.Parent=slotsFrame

-- 5 slot buttons
local slotBtns = {}
for i=1,MAX_SLOTS do
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(0,62,0,64); btn.BackgroundColor3=Color3.fromRGB(45,30,15)
    btn.BorderSizePixel=0; btn.TextColor3=Color3.fromRGB(255,255,255)
    btn.TextScaled=true; btn.Font=Enum.Font.GothamBold; btn.TextWrapped=true
    btn.Text="＋"; btn.Parent=slotsFrame
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,10)
    slotBtns[i] = btn
end

-- ================================================
-- MAIN SHOP PANEL
-- ================================================
local shopSG = Instance.new("ScreenGui")
shopSG.Name="ShopPanel"; shopSG.ResetOnSpawn=false; shopSG.Enabled=false; shopSG.Parent=pg

local panel = Instance.new("ScrollingFrame")
panel.Size=UDim2.new(0,380,0,520); panel.Position=UDim2.new(0.5,-190,0.5,-260)
panel.BackgroundColor3=Color3.fromRGB(22,12,5); panel.BorderSizePixel=0
panel.ScrollBarThickness=6; panel.CanvasSize=UDim2.new(0,0,0,0)
panel.AutomaticCanvasSize=Enum.AutomaticSize.Y; panel.Parent=shopSG
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
Instance.new("UIPadding",panel).PaddingTop=UDim.new(0,8)

local pLayout = Instance.new("UIListLayout")
pLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
pLayout.Padding=UDim.new(0,6); pLayout.Parent=panel

local function makeRow(text, bgColor, h)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(0.95,0,0,h or 40); f.BackgroundColor3=bgColor or Color3.fromRGB(40,25,10)
    f.BorderSizePixel=0; f.Parent=panel
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
    if text then
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0)
        l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(255,235,170)
        l.TextScaled=true; l.Font=Enum.Font.GothamBold; l.Text=text; l.Parent=f
    end
    return f
end

-- Title
local titleRow = makeRow("🐻 Bear Shop", Color3.fromRGB(160,50,50), 50)

-- Close
local closeBtn2 = Instance.new("TextButton")
closeBtn2.Size=UDim2.new(0,34,0,34); closeBtn2.Position=UDim2.new(1,-40,0.5,-17)
closeBtn2.BackgroundColor3=Color3.fromRGB(200,40,40); closeBtn2.Text="✕"
closeBtn2.TextColor3=Color3.fromRGB(255,255,255); closeBtn2.TextScaled=true
closeBtn2.Font=Enum.Font.GothamBold; closeBtn2.Parent=titleRow
Instance.new("UICorner",closeBtn2).CornerRadius=UDim.new(0,8)
closeBtn2.MouseButton1Click:Connect(function() shopSG.Enabled=false end)

-- Coins in panel
local panelCoins = makeRow("💰 0", Color3.fromRGB(30,20,8), 34)
local pcLbl = panelCoins:FindFirstChildOfClass("TextLabel")

-- Tabs: BUY | MY BEARS
local tabFrame = Instance.new("Frame")
tabFrame.Size=UDim2.new(0.95,0,0,38); tabFrame.BackgroundTransparency=1; tabFrame.Parent=panel
Instance.new("UICorner",tabFrame).CornerRadius=UDim.new(0,8)
local tLayout=Instance.new("UIListLayout"); tLayout.FillDirection=Enum.FillDirection.Horizontal
tLayout.Padding=UDim.new(0,6); tLayout.Parent=tabFrame

local tabBuy = Instance.new("TextButton")
tabBuy.Size=UDim2.new(0.48,0,1,0); tabBuy.BackgroundColor3=Color3.fromRGB(60,140,60)
tabBuy.BorderSizePixel=0; tabBuy.TextColor3=Color3.fromRGB(255,255,255)
tabBuy.TextScaled=true; tabBuy.Font=Enum.Font.GothamBold; tabBuy.Text="🛒 Buy Bears"; tabBuy.Parent=tabFrame
Instance.new("UICorner",tabBuy).CornerRadius=UDim.new(0,8)

local tabMine = Instance.new("TextButton")
tabMine.Size=UDim2.new(0.48,0,1,0); tabMine.BackgroundColor3=Color3.fromRGB(50,50,120)
tabMine.BorderSizePixel=0; tabMine.TextColor3=Color3.fromRGB(255,255,255)
tabMine.TextScaled=true; tabMine.Font=Enum.Font.GothamBold; tabMine.Text="🐻 My Bears"; tabMine.Parent=tabFrame
Instance.new("UICorner",tabMine).CornerRadius=UDim.new(0,8)

-- Container for buy list
local buyContainer = Instance.new("Frame")
buyContainer.Size=UDim2.new(0.95,0,0,1); buyContainer.AutomaticSize=Enum.AutomaticSize.Y
buyContainer.BackgroundTransparency=1; buyContainer.Parent=panel
local bcLayout=Instance.new("UIListLayout"); bcLayout.Padding=UDim.new(0,5); bcLayout.Parent=buyContainer

-- Container for my bears
local mineContainer = Instance.new("Frame")
mineContainer.Size=UDim2.new(0.95,0,0,1); mineContainer.AutomaticSize=Enum.AutomaticSize.Y
mineContainer.BackgroundTransparency=1; mineContainer.Visible=false; mineContainer.Parent=panel
local mcLayout=Instance.new("UIListLayout"); mcLayout.Padding=UDim.new(0,5); mcLayout.Parent=mineContainer

-- Tab switching
tabBuy.MouseButton1Click:Connect(function()
    buyContainer.Visible=true; mineContainer.Visible=false
    tabBuy.BackgroundColor3=Color3.fromRGB(60,140,60)
    tabMine.BackgroundColor3=Color3.fromRGB(50,50,120)
end)
tabMine.MouseButton1Click:Connect(function()
    buyContainer.Visible=false; mineContainer.Visible=true
    tabMine.BackgroundColor3=Color3.fromRGB(80,80,180)
    tabBuy.BackgroundColor3=Color3.fromRGB(35,80,35)
end)

-- Build buy list (all 15 tiers)
for i, tier in ipairs(tiers) do
    local buyPrice = math.floor(tier.sellPrice * 0.8)
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,52); row.BackgroundColor3=Color3.fromRGB(35,22,10)
    row.BorderSizePixel=0; row.Parent=buyContainer
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(0.62,0,1,0); lbl.BackgroundTransparency=1
    lbl.TextColor3=Color3.fromRGB(255,235,180); lbl.TextScaled=true
    lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Position=UDim2.new(0,10,0,0)
    lbl.Text=tier.emoji.." "..tier.name.."\n(Age "..tier.minAge..")"; lbl.Parent=row

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size=UDim2.new(0.34,0,0.7,0); buyBtn.Position=UDim2.new(0.64,0,0.15,0)
    buyBtn.BackgroundColor3=Color3.fromRGB(40,160,70); buyBtn.BorderSizePixel=0
    buyBtn.TextColor3=Color3.fromRGB(255,255,255); buyBtn.TextScaled=true
    buyBtn.Font=Enum.Font.GothamBold; buyBtn.Text="💰 "..buyPrice; buyBtn.Parent=row
    Instance.new("UICorner",buyBtn).CornerRadius=UDim.new(0,8)

    local capturedI = i
    buyBtn.MouseButton1Click:Connect(function()
        BuyBearRE:FireServer(capturedI)
        shopSG.Enabled=false
    end)
end

-- My Bears tab — rebuilt on each open
local myBearRows = {}
local currentSlots = {}

local function rebuildMyBears(slots)
    for _, r in ipairs(myBearRows) do r:Destroy() end
    myBearRows = {}
    currentSlots = slots or {}

    if #currentSlots == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size=UDim2.new(1,0,0,50); empty.BackgroundTransparency=1
        empty.TextColor3=Color3.fromRGB(180,150,100); empty.TextScaled=true
        empty.Font=Enum.Font.Gotham; empty.Text="No bears yet!"; empty.Parent=mineContainer
        table.insert(myBearRows, empty)
        return
    end

    for _, slot in ipairs(currentSlots) do
        local row = Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,64); row.BackgroundColor3=Color3.fromRGB(30,18,8)
        row.BorderSizePixel=0; row.Parent=mineContainer
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
        table.insert(myBearRows, row)

        local info = Instance.new("TextLabel")
        info.Size=UDim2.new(0.5,0,1,0); info.BackgroundTransparency=1
        info.TextColor3=Color3.fromRGB(255,235,180); info.TextScaled=true
        info.Font=Enum.Font.GothamBold; info.TextXAlignment=Enum.TextXAlignment.Left
        info.Position=UDim2.new(0,10,0,0)
        info.Text=slot.emoji.." "..slot.name.."\nAge: "..slot.age; info.Parent=row

        -- Upgrade button
        local nextTierIdx = slot.tierIdx + 1
        if nextTierIdx <= #tiers then
            local upPrice = math.floor((tiers[nextTierIdx].sellPrice - tiers[slot.tierIdx].sellPrice)*0.7)
            local upBtn = Instance.new("TextButton")
            upBtn.Size=UDim2.new(0.22,0,0.6,0); upBtn.Position=UDim2.new(0.5,0,0.2,0)
            upBtn.BackgroundColor3=Color3.fromRGB(60,80,180); upBtn.BorderSizePixel=0
            upBtn.TextColor3=Color3.fromRGB(255,255,255); upBtn.TextScaled=true
            upBtn.Font=Enum.Font.GothamBold; upBtn.Text="⬆️\n💰"..upPrice; upBtn.Parent=row
            Instance.new("UICorner",upBtn).CornerRadius=UDim.new(0,8)
            local captIdx=slot.slotIdx
            upBtn.MouseButton1Click:Connect(function()
                UpgradeRE:FireServer(captIdx)
                shopSG.Enabled=false
            end)
        end

        -- Sell button
        local sellBtn2 = Instance.new("TextButton")
        sellBtn2.Size=UDim2.new(0.22,0,0.6,0); sellBtn2.Position=UDim2.new(0.75,0,0.2,0)
        sellBtn2.BackgroundColor3=Color3.fromRGB(180,50,50); sellBtn2.BorderSizePixel=0
        sellBtn2.TextColor3=Color3.fromRGB(255,255,255); sellBtn2.TextScaled=true
        sellBtn2.Font=Enum.Font.GothamBold; sellBtn2.Text="💰\nSell"; sellBtn2.Parent=row
        Instance.new("UICorner",sellBtn2).CornerRadius=UDim.new(0,8)
        local captIdx=slot.slotIdx
        sellBtn2.MouseButton1Click:Connect(function()
            SellRE:FireServer(captIdx)
            shopSG.Enabled=false
        end)
    end
end

-- ================================================
-- Slot update handler
-- ================================================
local latestCoins = 0
local latestSlots = {}

SlotUpdateRE.OnClientEvent:Connect(function(coins, slots, followState)
    latestCoins = coins
    latestSlots = slots
    followEnabled = followState

    coinsLbl.Text  = "💰 " .. coins
    pcLbl.Text     = "💰 " .. coins
    followBtn.Text = followEnabled and "🐻 Following" or "⏸ Stopped"
    followBtn.BackgroundColor3 = followEnabled
        and Color3.fromRGB(40,140,60)
        or  Color3.fromRGB(100,60,20)

    for i=1,MAX_SLOTS do
        local btn = slotBtns[i]
        local slot = slots[i]
        if slot then
            btn.BackgroundColor3 = Color3.fromRGB(60,38,18)
            btn.Text = slot.emoji.."\n"..slot.name:split(" ")[1]
        else
            btn.BackgroundColor3 = Color3.fromRGB(35,22,10)
            btn.Text = "＋"
        end
    end
end)

-- ================================================
-- Slot button clicks
-- ================================================
for i=1,MAX_SLOTS do
    slotBtns[i].MouseButton1Click:Connect(function()
        local slot = latestSlots[i]
        if slot then
            local withIdx = {}
            for j, s in ipairs(latestSlots) do
                local copy = {}
                for k,v in pairs(s) do copy[k]=v end
                copy.slotIdx = j
                table.insert(withIdx, copy)
            end
            rebuildMyBears(withIdx)
            buyContainer.Visible=false; mineContainer.Visible=true
            tabMine.BackgroundColor3=Color3.fromRGB(80,80,180)
            tabBuy.BackgroundColor3=Color3.fromRGB(35,80,35)
        else
            buyContainer.Visible=true; mineContainer.Visible=false
            tabBuy.BackgroundColor3=Color3.fromRGB(60,140,60)
            tabMine.BackgroundColor3=Color3.fromRGB(50,50,120)
        end
        pcLbl.Text = "💰 " .. latestCoins
        shopSG.Enabled = true
    end)
end

-- ProximityPrompts from farm shop
task.spawn(function()
    local farm = workspace:WaitForChild("BearFarm",15)
    if not farm then return end
    local shop = farm:WaitForChild("Shop",10)
    if not shop then return end

    local function hookPrompt(partName, openTab)
        local trigger = shop:WaitForChild(partName,10)
        if not trigger then return end
        local pp = trigger:FindFirstChildOfClass("ProximityPrompt")
        if not pp then return end
        pp.Triggered:Connect(function()
            pcLbl.Text = "💰 " .. latestCoins
            if openTab == "sell" then
                local withIdx = {}
                for j, s in ipairs(latestSlots) do
                    local copy={}; for k,v in pairs(s) do copy[k]=v end
                    copy.slotIdx=j; table.insert(withIdx,copy)
                end
                rebuildMyBears(withIdx)
                buyContainer.Visible=false; mineContainer.Visible=true
            else
                buyContainer.Visible=true; mineContainer.Visible=false
            end
            shopSG.Enabled=true
        end)
    end
    hookPrompt("Sell Bear","sell")
    hookPrompt("Buy Bear Food","buy")
end)

-- ================================================
-- Idle Bears | Bear HUD + Shop Client v2
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
local FeedRE         = remotes:WaitForChild("FeedBear")
local WaterRE        = remotes:WaitForChild("WaterBear")
local BuyFoodRE      = remotes:WaitForChild("BuyFood")
local BuyDrinkRE     = remotes:WaitForChild("BuyDrink")

local MAX_SLOTS = 5
local pg = plr:WaitForChild("PlayerGui")

-- Food definitions (5 levels)
local foodDefs = {
	{name="Honey",        cost=5,   ageBonus=3,   color=Color3.fromRGB(220,160,0),   emoji="🍯"},
	{name="Berries",      cost=15,  ageBonus=8,   color=Color3.fromRGB(160,30,100),  emoji="🍓"},
	{name="Salmon",       cost=35,  ageBonus=20,  color=Color3.fromRGB(60,150,200),  emoji="🐟"},
	{name="Magic Fruit",  cost=80,  ageBonus=50,  color=Color3.fromRGB(140,0,220),   emoji="🍎"},
	{name="Golden Apple", cost=200, ageBonus=120, color=Color3.fromRGB(220,180,0),   emoji="🍏"},
}

-- Drink definitions (5 levels)
local drinkDefs = {
	{name="Fresh Water",   cost=8,   multiplier=1.5, duration=120, color=Color3.fromRGB(80,180,255),  emoji="💧"},
	{name="River Water",   cost=20,  multiplier=2,   duration=180, color=Color3.fromRGB(40,140,220),  emoji="🌊"},
	{name="Spring Water",  cost=50,  multiplier=3,   duration=240, color=Color3.fromRGB(0,200,180),   emoji="🫧"},
	{name="Mystic Water",  cost=120, multiplier=5,   duration=300, color=Color3.fromRGB(120,0,220),   emoji="🔮"},
	{name="Celestial Dew", cost=300, multiplier=10,  duration=420, color=Color3.fromRGB(255,200,50),  emoji="✨"},
}

-- ================================================
-- NOTIFICATION
-- ================================================
local notifSG = Instance.new("ScreenGui")
notifSG.Name="NotifGui"; notifSG.ResetOnSpawn=false
notifSG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; notifSG.Parent=pg

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
-- FEED / WATER BUTTONS (bottom-left)
-- ================================================
local actionSG = Instance.new("ScreenGui")
actionSG.Name="ActionGui"; actionSG.ResetOnSpawn=false; actionSG.Parent=pg

local function makeActionBtn(text, posX, color)
	local frame = Instance.new("Frame")
	frame.Size=UDim2.new(0,120,0,48); frame.Position=UDim2.new(0,posX,1,-70)
	frame.BackgroundColor3=color; frame.BorderSizePixel=0; frame.Parent=actionSG
	Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
	local btn = Instance.new("TextButton")
	btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
	btn.Text=text; btn.TextColor3=Color3.fromRGB(255,255,255)
	btn.TextScaled=true; btn.Font=Enum.Font.GothamBold; btn.Parent=frame
	return btn, frame
end

local feedBtn,  feedFrame  = makeActionBtn("🥕 Feed",  14,  Color3.fromRGB(210,120,40))
local waterBtn, waterFrame = makeActionBtn("💧 Water", 144, Color3.fromRGB(50,130,210))

local COOLDOWN = 0.5
local busy = false
local function doAction(btn, frame, remote, origColor)
	if busy then return end
	busy = true
	frame.BackgroundColor3 = Color3.fromRGB(160,160,160)
	remote:FireServer()
	task.delay(COOLDOWN, function()
		frame.BackgroundColor3 = origColor; busy = false
	end)
end
feedBtn.MouseButton1Click:Connect(function()
	doAction(feedBtn, feedFrame, FeedRE, Color3.fromRGB(210,120,40))
end)
waterBtn.MouseButton1Click:Connect(function()
	doAction(waterBtn, waterFrame, WaterRE, Color3.fromRGB(50,130,210))
end)

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
followBtn.MouseButton1Click:Connect(function() ToggleFollowRE:FireServer() end)

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
panel.Size=UDim2.new(0,400,0,540); panel.Position=UDim2.new(0.5,-200,0.5,-270)
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

-- 3 Tabs: BEARS | FOOD | DRINK
local tabFrame = Instance.new("Frame")
tabFrame.Size=UDim2.new(0.95,0,0,38); tabFrame.BackgroundTransparency=1; tabFrame.Parent=panel
local tLayout=Instance.new("UIListLayout"); tLayout.FillDirection=Enum.FillDirection.Horizontal
tLayout.Padding=UDim.new(0,4); tLayout.Parent=tabFrame

local function makeTab(text, color)
	local t = Instance.new("TextButton")
	t.Size=UDim2.new(0.32,0,1,0); t.BackgroundColor3=color
	t.BorderSizePixel=0; t.TextColor3=Color3.fromRGB(255,255,255)
	t.TextScaled=true; t.Font=Enum.Font.GothamBold; t.Text=text; t.Parent=tabFrame
	Instance.new("UICorner",t).CornerRadius=UDim.new(0,8)
	return t
end
local tabBears = makeTab("🐻 Bears", Color3.fromRGB(60,140,60))
local tabFood  = makeTab("🥕 Food",  Color3.fromRGB(140,80,20))
local tabDrink = makeTab("💧 Drink", Color3.fromRGB(30,100,180))

-- Containers
local function makeContainer()
	local f = Instance.new("Frame")
	f.Size=UDim2.new(0.95,0,0,1); f.AutomaticSize=Enum.AutomaticSize.Y
	f.BackgroundTransparency=1; f.Parent=panel
	Instance.new("UIListLayout",f).Padding=UDim.new(0,5)
	return f
end
local bearBuyC  = makeContainer()
local mineBearC = makeContainer(); mineBearC.Visible=false
local foodC     = makeContainer(); foodC.Visible=false
local drinkC    = makeContainer(); drinkC.Visible=false

local currentTab = "buyBears"
local function setTab(t)
	currentTab = t
	bearBuyC.Visible  = (t=="buyBears")
	mineBearC.Visible = (t=="myBears")
	foodC.Visible     = (t=="food")
	drinkC.Visible    = (t=="drink")
	tabBears.BackgroundColor3 = (t=="buyBears" or t=="myBears") and Color3.fromRGB(80,160,80) or Color3.fromRGB(35,80,35)
	tabFood.BackgroundColor3  = (t=="food")  and Color3.fromRGB(200,120,30) or Color3.fromRGB(90,50,10)
	tabDrink.BackgroundColor3 = (t=="drink") and Color3.fromRGB(50,140,220) or Color3.fromRGB(20,65,120)
end
tabBears.MouseButton1Click:Connect(function() setTab("buyBears") end)
tabFood.MouseButton1Click:Connect(function()  setTab("food") end)
tabDrink.MouseButton1Click:Connect(function() setTab("drink") end)

-- Bears inner tabs (Buy / Mine)
local bearTabRow = Instance.new("Frame")
bearTabRow.Size=UDim2.new(1,0,0,34); bearTabRow.BackgroundTransparency=1; bearTabRow.Parent=bearBuyC
local btl=Instance.new("UIListLayout"); btl.FillDirection=Enum.FillDirection.Horizontal; btl.Padding=UDim.new(0,4); btl.Parent=bearTabRow
local btBuy  = Instance.new("TextButton"); btBuy.Size=UDim2.new(0.49,0,1,0); btBuy.BackgroundColor3=Color3.fromRGB(50,140,60)
btBuy.BorderSizePixel=0; btBuy.TextColor3=Color3.fromRGB(255,255,255); btBuy.TextScaled=true
btBuy.Font=Enum.Font.GothamBold; btBuy.Text="🛒 Buy"; btBuy.Parent=bearTabRow
Instance.new("UICorner",btBuy).CornerRadius=UDim.new(0,6)
local btMine = Instance.new("TextButton"); btMine.Size=UDim2.new(0.49,0,1,0); btMine.BackgroundColor3=Color3.fromRGB(40,40,100)
btMine.BorderSizePixel=0; btMine.TextColor3=Color3.fromRGB(255,255,255); btMine.TextScaled=true
btMine.Font=Enum.Font.GothamBold; btMine.Text="🐻 Mine"; btMine.Parent=bearTabRow
Instance.new("UICorner",btMine).CornerRadius=UDim.new(0,6)

local buyInner = Instance.new("Frame"); buyInner.Size=UDim2.new(1,0,0,1)
buyInner.AutomaticSize=Enum.AutomaticSize.Y; buyInner.BackgroundTransparency=1; buyInner.Parent=bearBuyC
Instance.new("UIListLayout",buyInner).Padding=UDim.new(0,5)
mineBearC.Parent = panel

local function setBearTab(mode)
	buyInner.Visible  = (mode=="buy")
	mineBearC.Visible = (mode=="mine")
	bearBuyC.Visible  = true
	btBuy.BackgroundColor3  = mode=="buy"  and Color3.fromRGB(50,160,70) or Color3.fromRGB(30,70,35)
	btMine.BackgroundColor3 = mode=="mine" and Color3.fromRGB(70,70,180) or Color3.fromRGB(30,30,80)
end
btBuy.MouseButton1Click:Connect(function()  setBearTab("buy") end)
btMine.MouseButton1Click:Connect(function() setBearTab("mine") end)

-- Build buy list (all 15 tiers)
for i, tier in ipairs(tiers) do
	local buyPrice = math.floor(tier.sellPrice * 0.8)
	local row = Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,52); row.BackgroundColor3=Color3.fromRGB(35,22,10)
	row.BorderSizePixel=0; row.Parent=buyInner
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
	local ci=i
	buyBtn.MouseButton1Click:Connect(function() BuyBearRE:FireServer(ci); shopSG.Enabled=false end)
end

-- Food shop
local foodHdr = Instance.new("Frame"); foodHdr.Size=UDim2.new(1,0,0,36)
foodHdr.BackgroundTransparency=1; foodHdr.Parent=foodC
local fhl=Instance.new("TextLabel"); fhl.Size=UDim2.new(1,0,1,0); fhl.BackgroundTransparency=1
fhl.TextColor3=Color3.fromRGB(255,210,100); fhl.TextScaled=true; fhl.Font=Enum.Font.GothamBold
fhl.Text="🥕 Buy Food — feeds your bear (+Age instantly)"; fhl.Parent=foodHdr

for _, fd in ipairs(foodDefs) do
	local row = Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=Color3.fromRGB(40,22,8)
	row.BorderSizePixel=0; row.Parent=foodC
	Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
	local lbl = Instance.new("TextLabel")
	lbl.Size=UDim2.new(0.6,0,1,0); lbl.BackgroundTransparency=1
	lbl.TextColor3=Color3.fromRGB(255,235,180); lbl.TextScaled=true
	lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Position=UDim2.new(0,10,0,0)
	lbl.Text=fd.emoji.." "..fd.name.."\n+Age "..fd.ageBonus; lbl.Parent=row
	local fb = Instance.new("TextButton")
	fb.Size=UDim2.new(0.35,0,0.65,0); fb.Position=UDim2.new(0.63,0,0.17,0)
	fb.BackgroundColor3=fd.color; fb.BorderSizePixel=0
	fb.TextColor3=Color3.fromRGB(255,255,255); fb.TextScaled=true
	fb.Font=Enum.Font.GothamBold; fb.Text="💰 "..fd.cost; fb.Parent=row
	Instance.new("UICorner",fb).CornerRadius=UDim.new(0,8)
	local cfd=fd
	fb.MouseButton1Click:Connect(function()
		BuyFoodRE:FireServer(cfd.name, cfd.cost, cfd.ageBonus)
		shopSG.Enabled=false
	end)
end

-- Drink shop
local drinkHdr = Instance.new("Frame"); drinkHdr.Size=UDim2.new(1,0,0,36)
drinkHdr.BackgroundTransparency=1; drinkHdr.Parent=drinkC
local dhl=Instance.new("TextLabel"); dhl.Size=UDim2.new(1,0,1,0); dhl.BackgroundTransparency=1
dhl.TextColor3=Color3.fromRGB(140,210,255); dhl.TextScaled=true; dhl.Font=Enum.Font.GothamBold
dhl.Text="💧 Buy Drink — boosts idle growth speed"; dhl.Parent=drinkHdr

for _, dd in ipairs(drinkDefs) do
	local row = Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,58); row.BackgroundColor3=Color3.fromRGB(8,20,40)
	row.BorderSizePixel=0; row.Parent=drinkC
	Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
	local lbl = Instance.new("TextLabel")
	lbl.Size=UDim2.new(0.6,0,1,0); lbl.BackgroundTransparency=1
	lbl.TextColor3=Color3.fromRGB(200,235,255); lbl.TextScaled=true
	lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Position=UDim2.new(0,10,0,0)
	lbl.Text=dd.emoji.." "..dd.name.."\nx"..dd.multiplier.." / "..dd.duration.."s"; lbl.Parent=row
	local db = Instance.new("TextButton")
	db.Size=UDim2.new(0.35,0,0.65,0); db.Position=UDim2.new(0.63,0,0.17,0)
	db.BackgroundColor3=dd.color; db.BorderSizePixel=0
	db.TextColor3=Color3.fromRGB(255,255,255); db.TextScaled=true
	db.Font=Enum.Font.GothamBold; db.Text="💰 "..dd.cost; db.Parent=row
	Instance.new("UICorner",db).CornerRadius=UDim.new(0,8)
	local cdd=dd
	db.MouseButton1Click:Connect(function()
		BuyDrinkRE:FireServer(cdd.name, cdd.cost, cdd.multiplier, cdd.duration)
		shopSG.Enabled=false
	end)
end

-- ================================================
-- My Bears tab
-- ================================================
local myBearRows = {}
local function rebuildMyBears(slots)
	for _, r in ipairs(myBearRows) do r:Destroy() end
	myBearRows = {}
	if #slots==0 then
		local e=Instance.new("TextLabel"); e.Size=UDim2.new(1,0,0,50); e.BackgroundTransparency=1
		e.TextColor3=Color3.fromRGB(180,150,100); e.TextScaled=true
		e.Font=Enum.Font.Gotham; e.Text="No bears yet!"; e.Parent=mineBearC
		table.insert(myBearRows,e); return
	end
	for _, slot in ipairs(slots) do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,64); row.BackgroundColor3=Color3.fromRGB(30,18,8)
		row.BorderSizePixel=0; row.Parent=mineBearC
		Instance.new("UICorner",row).CornerRadius=UDim.new(0,8); table.insert(myBearRows,row)
		local info=Instance.new("TextLabel"); info.Size=UDim2.new(0.5,0,1,0); info.BackgroundTransparency=1
		info.TextColor3=Color3.fromRGB(255,235,180); info.TextScaled=true
		info.Font=Enum.Font.GothamBold; info.TextXAlignment=Enum.TextXAlignment.Left
		info.Position=UDim2.new(0,8,0,0)
		info.Text=slot.emoji.." "..slot.name.."\nAge: "..slot.age; info.Parent=row
		if slot.tierIdx < #tiers then
			local upPrice=math.floor((tiers[slot.tierIdx+1].sellPrice-tiers[slot.tierIdx].sellPrice)*0.7)
			local ub=Instance.new("TextButton"); ub.Size=UDim2.new(0.22,0,0.6,0); ub.Position=UDim2.new(0.5,2,0.2,0)
			ub.BackgroundColor3=Color3.fromRGB(60,80,180); ub.BorderSizePixel=0
			ub.TextColor3=Color3.fromRGB(255,255,255); ub.TextScaled=true; ub.Font=Enum.Font.GothamBold
			ub.Text="⬆️\n💰"..upPrice; ub.Parent=row
			Instance.new("UICorner",ub).CornerRadius=UDim.new(0,8)
			local ci=slot.slotIdx; ub.MouseButton1Click:Connect(function() UpgradeRE:FireServer(ci); shopSG.Enabled=false end)
		end
		local sb=Instance.new("TextButton"); sb.Size=UDim2.new(0.22,0,0.6,0); sb.Position=UDim2.new(0.74,2,0.2,0)
		sb.BackgroundColor3=Color3.fromRGB(180,40,40); sb.BorderSizePixel=0
		sb.TextColor3=Color3.fromRGB(255,255,255); sb.TextScaled=true; sb.Font=Enum.Font.GothamBold
		sb.Text="💰\nSell"; sb.Parent=row
		Instance.new("UICorner",sb).CornerRadius=UDim.new(0,8)
		local ci=slot.slotIdx; sb.MouseButton1Click:Connect(function() SellRE:FireServer(ci); shopSG.Enabled=false end)
	end
end

-- ================================================
-- Slot update handler
-- ================================================
local latestCoins = 0
local latestSlots = {}

SlotUpdateRE.OnClientEvent:Connect(function(coins, slots, followState)
	latestCoins=coins; latestSlots=slots; followEnabled=followState
	coinsLbl.Text="💰 "..coins
	pcLbl.Text="💰 "..coins
	followBtn.Text = followEnabled and "🐻 Following" or "⏸ Stopped"
	followBtn.BackgroundColor3 = followEnabled and Color3.fromRGB(40,140,60) or Color3.fromRGB(100,60,20)
	for i=1,MAX_SLOTS do
		local btn=slotBtns[i]; local slot=slots[i]
		if slot then
			btn.BackgroundColor3=Color3.fromRGB(60,38,18)
			btn.Text=slot.emoji.."\n"..slot.name:split(" ")[1]
		else
			btn.BackgroundColor3=Color3.fromRGB(35,22,10); btn.Text="＋"
		end
	end
end)

-- ================================================
-- Slot button clicks
-- ================================================
for i=1,MAX_SLOTS do
	slotBtns[i].MouseButton1Click:Connect(function()
		local slot=latestSlots[i]
		pcLbl.Text="💰 "..latestCoins
		if slot then
			local wi={}
			for j,s in ipairs(latestSlots) do
				local cp={}; for k,v in pairs(s) do cp[k]=v end; cp.slotIdx=j; table.insert(wi,cp)
			end
			rebuildMyBears(wi)
			setTab("myBears"); setBearTab("mine")
		else
			setTab("buyBears"); setBearTab("buy")
		end
		shopSG.Enabled=true
	end)
end

-- ================================================
-- ProximityPrompts
-- ================================================
task.spawn(function()
	local farm=workspace:WaitForChild("BearFarm",15); if not farm then return end
	local shop=farm:WaitForChild("Shop",10); if not shop then return end
	local function hook(partName, tab)
		local t=shop:WaitForChild(partName,10); if not t then return end
		local pp=t:FindFirstChildOfClass("ProximityPrompt"); if not pp then return end
		pp.Triggered:Connect(function()
			pcLbl.Text="💰 "..latestCoins
			if tab=="myBears" then
				local wi={}
				for j,s in ipairs(latestSlots) do
					local cp={}; for k,v in pairs(s) do cp[k]=v end; cp.slotIdx=j; table.insert(wi,cp)
				end
				rebuildMyBears(wi); setTab("myBears"); setBearTab("mine")
			elseif tab=="food" then
				setTab("food")
			else
				setTab("buyBears"); setBearTab("buy")
			end
			shopSG.Enabled=true
		end)
	end
	hook("Sell Bear","myBears")
	hook("Buy Bear Food","food")
end)

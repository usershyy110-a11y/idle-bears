-- ================================================
-- BearManager v2: slots, buy, upgrade, follow, food, drink, admin
-- ================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BearData_v2")
local Chat             = game:GetService("Chat")

local RS      = game.ReplicatedStorage
local remotes = RS:WaitForChild("RemoteEvents")
local tiers   = require(RS:WaitForChild("BearTiers"))
local SS      = game.ServerStorage
local models  = SS:WaitForChild("BearModels")

local BuyBearRE      = remotes:WaitForChild("BuyBear")
local UpgradeRE      = remotes:WaitForChild("UpgradeBear")
local ToggleFollowRE = remotes:WaitForChild("ToggleFollow")
local SlotUpdateRE   = remotes:WaitForChild("BearSlotUpdate")
local RespRE         = remotes:WaitForChild("ShopResponse")
local SellRE         = remotes:WaitForChild("SellBear")
local FeedRE         = remotes:WaitForChild("FeedBear")
local WaterRE        = remotes:WaitForChild("WaterBear")
local BuyFoodRE      = remotes:WaitForChild("BuyFood")
local BuyDrinkRE     = remotes:WaitForChild("BuyDrink")

-- ---- Config ----
local MAX_SLOTS      = 5
local STARTING_COINS = 30
local FOLLOW_SPEED   = 14
local FOLLOW_GAP     = 5
local IDLE_INTERVAL  = 30   -- seconds per idle age tick
local FEED_AGE       = 2    -- age bonus per manual feed
local WATER_AGE      = 1    -- age bonus per manual water

local ADMIN_ID = 5647716264  -- DY110TD

-- Valid food/drink definitions (server-side validation)
local FOOD_DEFS = {
	["Honey"]        = {cost=5,   ageBonus=3},
	["Berries"]      = {cost=15,  ageBonus=8},
	["Salmon"]       = {cost=35,  ageBonus=20},
	["Magic Fruit"]  = {cost=80,  ageBonus=50},
	["Golden Apple"] = {cost=200, ageBonus=120},
}
local DRINK_DEFS = {
	["Fresh Water"]   = {cost=8,   multiplier=1.5, duration=120},
	["River Water"]   = {cost=20,  multiplier=2,   duration=180},
	["Spring Water"]  = {cost=50,  multiplier=3,   duration=240},
	["Mystic Water"]  = {cost=120, multiplier=5,   duration=300},
	["Celestial Dew"] = {cost=300, multiplier=10,  duration=420},
}

-- ---- State ----
local playerData        = {}  -- [uid] = {coins, slots, followEnabled, drinkBoost, drinkExpiry}
local followConnections = {}

-- ---- Helpers ----
local function getTierById(id)
	for i,t in ipairs(tiers) do if t.id==id then return t,i end end
	return tiers[1],1
end
local function getBuyPrice(idx)    return math.floor(tiers[idx].sellPrice*0.8) end
local function getUpgradePrice(fi,ti) if ti>#tiers then return math.huge end return math.floor((tiers[ti].sellPrice-tiers[fi].sellPrice)*0.7) end
local function respond(plr,ok,msg) RespRE:FireClient(plr,ok,msg) end

local function broadcastSlots(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	local info={}
	for i,slot in ipairs(pd.slots) do
		local tier,idx=getTierById(slot.tierId)
		info[i]={tierId=slot.tierId,name=tier.name,emoji=tier.emoji,age=slot.age,tierIdx=idx}
	end
	SlotUpdateRE:FireClient(plr,pd.coins,info,pd.followEnabled)
end

-- ---- Bear models ----
local function spawnBearModel(plr,slotIdx,tierId)
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then return end
	if slot.model and slot.model.Parent then slot.model:Destroy() end
	local src=models:FindFirstChild("Bear_"..tierId); if not src then return end
	local clone=src:Clone()
	clone.Name=("PlayerBear_%d_%d"):format(plr.UserId,slotIdx)
	clone.Parent=workspace
	local char=plr.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local basePos=root and root.Position or Vector3.new(0,5,0)
	local offset=Vector3.new((slotIdx-1)*FOLLOW_GAP,0,6)
	for _,p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame=p.CFrame+basePos+offset; p.Anchored=true; p.CanCollide=false
		end
	end
	slot.model=clone; return clone
end

local function despawnBearModel(plr,slotIdx)
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]
	if slot and slot.model and slot.model.Parent then slot.model:Destroy(); slot.model=nil end
end

-- ---- Follow ----
local function startFollow(plr)
	local uid=plr.UserId
	if followConnections[uid] then followConnections[uid]:Disconnect() end
	followConnections[uid]=RunService.Heartbeat:Connect(function(dt)
		local pd=playerData[uid]; if not pd or not pd.followEnabled then return end
		local char=plr.Character
		local root=char and char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local fwd=root.CFrame.LookVector; local right=root.CFrame.RightVector
		for i,slot in ipairs(pd.slots) do
			if slot.model and slot.model.Parent then
				local row=math.ceil(i/3); local col=((i-1)%3)-1
				local target=root.Position-fwd*(FOLLOW_GAP*row+FOLLOW_GAP)+right*(col*FOLLOW_GAP*0.8)
				local body=slot.model:FindFirstChild("Body"); if not body then continue end
				local newPos=body.Position:Lerp(target,math.min(dt*FOLLOW_SPEED,1))
				local delta=newPos-body.Position
				for _,p in ipairs(slot.model:GetDescendants()) do
					if p:IsA("BasePart") then p.CFrame=p.CFrame+delta end
				end
			end
		end
	end)
end

local function stopFollow(plr)
	local uid=plr.UserId
	if followConnections[uid] then followConnections[uid]:Disconnect(); followConnections[uid]=nil end
end

-- ---- Data ----
local function saveData(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	local saved={coins=pd.coins,followEnabled=pd.followEnabled,slots={}}
	for i,s in ipairs(pd.slots) do saved.slots[i]={tierId=s.tierId,age=s.age} end
	pcall(function() DS:SetAsync("bearv2:"..plr.UserId,saved) end)
end
local function loadData(plr)
	local ok,data=pcall(function() return DS:GetAsync("bearv2:"..plr.UserId) end)
	if ok and data then return data end; return nil
end

-- ---- Age helper: apply age to all bears and auto-upgrade ----
local function applyAge(plr,amount)
	local pd=playerData[plr.UserId]; if not pd then return end
	for i,slot in ipairs(pd.slots) do
		slot.age+=amount
		local _,ci=getTierById(slot.tierId)
		if ci<#tiers and slot.age>=tiers[ci+1].minAge then
			slot.tierId=tiers[ci+1].id
			spawnBearModel(plr,i,slot.tierId)
		end
	end
	broadcastSlots(plr)
end

-- ---- Player Added ----
local function onPlayerAdded(plr)
	local saved=loadData(plr)
	local pd={
		coins=saved and saved.coins or STARTING_COINS,
		followEnabled=saved and saved.followEnabled~=false or true,
		slots={},
		drinkMultiplier=1,
		drinkExpiry=0,
	}
	playerData[plr.UserId]=pd

	if saved and saved.slots and #saved.slots>0 then
		for _,s in ipairs(saved.slots) do
			table.insert(pd.slots,{tierId=s.tierId or "t1",age=s.age or 0,model=nil})
		end
	else
		table.insert(pd.slots,{tierId="t1",age=0,model=nil})
	end

	local ls=Instance.new("Folder"); ls.Name="leaderstats"; ls.Parent=plr
	local lsC=Instance.new("IntValue"); lsC.Name="Coins"; lsC.Value=pd.coins; lsC.Parent=ls
	local lsB=Instance.new("IntValue"); lsB.Name="Bears"; lsB.Value=#pd.slots; lsB.Parent=ls
	local stats=Instance.new("Folder"); stats.Name="BearStats"; stats.Parent=plr
	local cv=Instance.new("IntValue"); cv.Name="Coins"; cv.Value=pd.coins; cv.Parent=stats

	local function onChar()
		task.wait(1)
		for i,slot in ipairs(pd.slots) do spawnBearModel(plr,i,slot.tierId) end
		if pd.followEnabled then startFollow(plr) end
		broadcastSlots(plr)
	end
	if plr.Character then task.spawn(onChar) end
	plr.CharacterAdded:Connect(function() task.spawn(onChar) end)

	task.spawn(function()
		while plr.Parent do
			task.wait(2)
			local curr=playerData[plr.UserId]
			if curr then lsC.Value=curr.coins; cv.Value=curr.coins; lsB.Value=#curr.slots end
		end
	end)
	task.spawn(function()
		while plr.Parent do task.wait(60); saveData(plr) end
	end)
end

local function onPlayerRemoving(plr)
	stopFollow(plr); saveData(plr)
	local pd=playerData[plr.UserId]
	if pd then for i in ipairs(pd.slots) do despawnBearModel(plr,i) end end
	playerData[plr.UserId]=nil
end

-- ================================================
-- EVENTS
-- ================================================

-- Feed Bear (manual +2 age)
FeedRE.OnServerEvent:Connect(function(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	applyAge(plr,FEED_AGE)
	respond(plr,true,"🥕 Bear fed! +2 age")
end)

-- Water Bear (manual +1 age)
WaterRE.OnServerEvent:Connect(function(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	applyAge(plr,WATER_AGE)
	respond(plr,true,"💧 Bear watered! +1 age")
end)

-- Buy Food
BuyFoodRE.OnServerEvent:Connect(function(plr,foodName,foodCost,ageBonus)
	if type(foodName)~="string" then return end
	local def=FOOD_DEFS[foodName]; if not def then return end
	local cost=def.cost; local bonus=def.ageBonus
	local pd=playerData[plr.UserId]; if not pd then return end
	if pd.coins<cost then respond(plr,false,"Not enough coins! Need 💰 "..cost); return end
	pd.coins-=cost
	applyAge(plr,bonus)
	respond(plr,true,("Fed %s! Bear grew +%d age. 💰 -%d"):format(foodName,bonus,cost))
	broadcastSlots(plr); saveData(plr)
end)

-- Buy Drink (boosts idle growth rate)
BuyDrinkRE.OnServerEvent:Connect(function(plr,drinkName,drinkCost,multiplier,duration)
	if type(drinkName)~="string" then return end
	local def=DRINK_DEFS[drinkName]; if not def then return end
	local cost=def.cost; local mult=def.multiplier; local dur=def.duration
	local pd=playerData[plr.UserId]; if not pd then return end
	if pd.coins<cost then respond(plr,false,"Not enough coins! Need 💰 "..cost); return end
	pd.coins-=cost
	pd.drinkMultiplier=mult
	pd.drinkExpiry=os.clock()+dur
	respond(plr,true,("Drank %s! Idle growth x%.1f for %ds 💰 -%d"):format(drinkName,mult,dur,cost))
	broadcastSlots(plr); saveData(plr)
end)

-- Buy Bear
BuyBearRE.OnServerEvent:Connect(function(plr,tierIdx)
	tierIdx=tonumber(tierIdx)
	if not tierIdx or tierIdx<1 or tierIdx>#tiers then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	if #pd.slots>=MAX_SLOTS then respond(plr,false,"Max "..MAX_SLOTS.." bears!"); return end
	local price=getBuyPrice(tierIdx)
	if pd.coins<price then respond(plr,false,"Need 💰 "..price); return end
	pd.coins-=price
	local ns={tierId=tiers[tierIdx].id,age=tiers[tierIdx].minAge,model=nil}
	table.insert(pd.slots,ns)
	spawnBearModel(plr,#pd.slots,ns.tierId)
	respond(plr,true,("Bought %s %s! 💰 -%d"):format(tiers[tierIdx].emoji,tiers[tierIdx].name,price))
	broadcastSlots(plr); saveData(plr)
end)

-- Upgrade Bear
UpgradeRE.OnServerEvent:Connect(function(plr,slotIdx)
	slotIdx=tonumber(slotIdx); if not slotIdx then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then respond(plr,false,"Invalid slot"); return end
	local _,ci=getTierById(slot.tierId)
	local ni=ci+1
	if ni>#tiers then respond(plr,false,"Max tier! 👑"); return end
	local price=getUpgradePrice(ci,ni)
	if pd.coins<price then respond(plr,false,"Need 💰 "..price.." for "..tiers[ni].name); return end
	pd.coins-=price; slot.tierId=tiers[ni].id; slot.age=tiers[ni].minAge
	spawnBearModel(plr,slotIdx,slot.tierId)
	respond(plr,true,("Upgraded to %s %s! 💰 -%d"):format(tiers[ni].emoji,tiers[ni].name,price))
	broadcastSlots(plr); saveData(plr)
end)

-- Toggle Follow
ToggleFollowRE.OnServerEvent:Connect(function(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	pd.followEnabled=not pd.followEnabled
	if pd.followEnabled then startFollow(plr); respond(plr,true,"Bears following! 🐻")
	else stopFollow(plr); respond(plr,true,"Bears stopped.") end
	broadcastSlots(plr)
end)

-- Sell Bear
SellRE.OnServerEvent:Connect(function(plr,slotIdx)
	slotIdx=tonumber(slotIdx) or 1
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then respond(plr,false,"Invalid slot"); return end
	local tier=getTierById(slot.tierId)
	pd.coins+=tier.sellPrice
	despawnBearModel(plr,slotIdx)
	table.remove(pd.slots,slotIdx)
	for i,s in ipairs(pd.slots) do
		if s.model then s.model:Destroy(); s.model=nil end
		spawnBearModel(plr,i,s.tierId)
	end
	respond(plr,true,("Sold %s %s for 💰 %d!"):format(tier.emoji,tier.name,tier.sellPrice))
	broadcastSlots(plr); saveData(plr)
end)

-- ================================================
-- ADMIN COMMANDS (chat: /coins 5000 | /addbear t5)
-- ================================================
Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg)
		if plr.UserId~=ADMIN_ID then return end
		local cmd,arg=msg:match("^(/[%a]+)%s*(.*)")
		if not cmd then return end
		cmd=cmd:lower()

		if cmd=="/coins" then
			local amount=tonumber(arg)
			if not amount then respond(plr,false,"Usage: /coins <amount>"); return end
			local pd=playerData[plr.UserId]; if not pd then return end
			pd.coins+=amount
			respond(plr,true,("Admin: +💰 %d (total: %d)"):format(amount,pd.coins))
			broadcastSlots(plr); saveData(plr)

		elseif cmd=="/addbear" then
			local tierId=arg:match("^%s*(%S+)%s*$") or "t1"
			local pd=playerData[plr.UserId]; if not pd then return end
			if #pd.slots>=MAX_SLOTS then respond(plr,false,"Max slots reached!"); return end
			local foundTier=nil
			for _,t in ipairs(tiers) do if t.id==tierId then foundTier=t; break end end
			if not foundTier then respond(plr,false,"Unknown tier: "..tierId); return end
			local ns={tierId=foundTier.id,age=foundTier.minAge,model=nil}
			table.insert(pd.slots,ns)
			spawnBearModel(plr,#pd.slots,foundTier.id)
			respond(plr,true,("Admin: Added %s %s (slot %d)"):format(foundTier.emoji,foundTier.name,#pd.slots))
			broadcastSlots(plr); saveData(plr)
		end
	end)
end)

-- ================================================
-- IDLE GROWTH LOOP (respects drink boost)
-- ================================================
task.spawn(function()
	while true do
		task.wait(IDLE_INTERVAL)
		for uid,pd in pairs(playerData) do
			local plr=Players:GetPlayerByUserId(uid)
			local mult=1
			if pd.drinkExpiry and os.clock()<pd.drinkExpiry then
				mult=pd.drinkMultiplier or 1
			else
				pd.drinkMultiplier=1; pd.drinkExpiry=0
			end
			local growth=math.floor(1*mult)
			for i,slot in ipairs(pd.slots) do
				slot.age+=growth
				local _,ci=getTierById(slot.tierId)
				if ci<#tiers and slot.age>=tiers[ci+1].minAge then
					slot.tierId=tiers[ci+1].id
					if plr then spawnBearModel(plr,i,slot.tierId) end
				end
			end
			if plr then broadcastSlots(plr) end
		end
	end
end)

-- ================================================
-- INIT
-- ================================================
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _,plr in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded,plr) end

print("[BearManager v2] loaded OK")
return {}

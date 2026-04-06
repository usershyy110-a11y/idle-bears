-- ================================================
-- BearManager v4 — Phase 2 UI-Ready
-- Public API: GetPlayerData, ForceSetCoins
-- Remotes: InventorySync (push), ConsumeRequest/ConsumeResponse (Zero Trust)
-- Admin: /boards, /coins, /addbear
-- ================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")
local DS               = DataStoreService:GetDataStore("BearData_v4")

local RS       = game.ReplicatedStorage
local remotes  = RS:WaitForChild("RemoteEvents")
local tiers    = require(RS:WaitForChild("BearTiers"))
local VF       = require(RS:WaitForChild("BrainrotVisualFactory"))
local LB       = require(game:GetService("ServerScriptService"):WaitForChild("LeaderboardService"))
local Registry = require(RS:WaitForChild("ItemRegistry"))
local EC       = Registry.ErrorCodes

local SS           = game.ServerStorage
local prefabFolder = SS:FindFirstChild("BrainrotModels")

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
local UseFoodRE      = remotes:WaitForChild("UseFood")
local UseDrinkRE     = remotes:WaitForChild("UseDrink")
-- New Phase 2 UI remotes
local InvSyncRE      = remotes:WaitForChild("InventorySync")
local ConsumeReqRE   = remotes:WaitForChild("ConsumeRequest")
local ConsumeRespRE  = remotes:WaitForChild("ConsumeResponse")

local MAX_SLOTS        = 5
local STARTING_COINS   = 30
local AGE_MULTIPLIER   = 1.5
local FOLLOW_SPEED     = 12
local FOLLOW_GAP       = 5
local IDLE_INTERVAL    = 30
local FEED_AGE         = 2
local WATER_AGE        = 1
local ADMIN_ID         = 5647716264
local CONSUME_COOLDOWN = 0.5  -- seconds between ConsumeRequests per player

-- Foods: buy adds to inventory; use spends inventory + adds age per slot
local FOOD_DEFS = {
	["Honey"]           = {cost=5,    ageBonus=3},
	["Berries"]         = {cost=15,   ageBonus=8},
	["Salmon"]          = {cost=35,   ageBonus=20},
	["Magic Fruit"]     = {cost=80,   ageBonus=50},
	["Golden Apple"]    = {cost=200,  ageBonus=120},
	-- New high-tier foods (x30 scaling)
	["Dragon Fruit"]    = {cost=6000,  ageBonus=3600},
	["Phoenix Berry"]   = {cost=18000, ageBonus=9600},
	["Void Salmon"]     = {cost=42000, ageBonus=24000},
	["Astral Melon"]    = {cost=96000, ageBonus=60000},
	["Celestial Core"]  = {cost=240000,ageBonus=144000},
}
-- Drinks: buy adds to inventory; use activates multiplier
local DRINK_DEFS = {
	["Fresh Water"]     = {cost=8,     multiplier=1.5, duration=120},
	["River Water"]     = {cost=20,    multiplier=2,   duration=180},
	["Spring Water"]    = {cost=50,    multiplier=3,   duration=240},
	["Mystic Water"]    = {cost=120,   multiplier=5,   duration=300},
	["Celestial Dew"]   = {cost=300,   multiplier=10,  duration=420},
	-- New high-tier drinks (x30 scaling)
	["Void Essence"]    = {cost=9000,  multiplier=15,  duration=600},
	["Nebula Sap"]      = {cost=22500, multiplier=20,  duration=720},
	["Star Bloom"]      = {cost=56250, multiplier=30,  duration=900},
	["Aurora Elixir"]   = {cost=135000,multiplier=50,  duration=1200},
	["Eternal Spring"]  = {cost=337500,multiplier=100, duration=1800},
}

-- Inventory default (used for new players and migration)
local function defaultInventory()
	return {foods={}, drinks={}}
end

local playerData        = {}
local followConnections = {}
local M                 = {}

-- ---- Helpers ----
local function newPetId(uid, i)
	return ("%d_%d_%s"):format(uid, i, HttpService:GenerateGUID(false):sub(1,8))
end
local function getTierById(id)
	for i,t in ipairs(tiers) do if t.id==id then return t,i end end
	return tiers[1],1
end
local function getBuyPrice(idx)    return math.floor(tiers[idx].sellPrice*0.8) end
local function getUpgradePrice(fi,ti)
	if ti>#tiers then return math.huge end
	return math.floor((tiers[ti].sellPrice-tiers[fi].sellPrice)*0.7)
end
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

-- ---- Spawn ----
local function targetCF(plr,slotIdx)
	local char=plr.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local base=root and root.Position or Vector3.new(0,5,0)
	return CFrame.new(base+Vector3.new((slotIdx-1)*FOLLOW_GAP,2.5,6))
end
local function spawnBrainrot(plr,slotIdx)
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then return end
	VF.despawnModel(slot.model)
	local tier=getTierById(slot.tierId)
	slot.model=VF.spawnModel(tier,prefabFolder,targetCF(plr,slotIdx),
		("PlayerBrainrot_%d_%d"):format(plr.UserId,slotIdx))
end
local function despawnBrainrot(plr,slotIdx)
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]
	if slot then VF.despawnModel(slot.model); slot.model=nil end
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
			if slot.model and slot.model.Parent and slot.model.PrimaryPart then
				local row=math.ceil(i/3); local col=((i-1)%3)-1
				local target=root.Position
					-fwd*(FOLLOW_GAP*row+FOLLOW_GAP)
					+right*(col*FOLLOW_GAP*0.8)
					+Vector3.new(0,2.5,0)
				local cur=slot.model.PrimaryPart.Position
				VF.moveModel(slot.model,CFrame.new(cur:Lerp(target,math.min(dt*FOLLOW_SPEED,1))))
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
	local saved={coins=pd.coins,followEnabled=pd.followEnabled,slots={},inventory=pd.inventory}
	for i,s in ipairs(pd.slots) do
		saved.slots[i]={tierId=s.tierId,age=s.age,petId=s.petId,createdAt=s.createdAt}
	end
	pcall(function() DS:SetAsync("bearv4:"..plr.UserId,saved) end)
	LB.UpdateCoins(plr.UserId,pd.coins)
	for _,slot in ipairs(pd.slots) do LB.UpdatePet(plr.UserId,plr.Name,slot) end
end
local function loadData(plr)
	local ok,data=pcall(function() return DS:GetAsync("bearv4:"..plr.UserId) end)
	if ok and data then return data end
	return nil
end

-- ---- Age ----
local function applyAge(plr,amount)
	local pd=playerData[plr.UserId]; if not pd then return end
	for i,slot in ipairs(pd.slots) do
		slot.age+=amount
		local _,ci=getTierById(slot.tierId)
		if ci<#tiers and slot.age>=tiers[ci+1].minAge then
			slot.tierId=tiers[ci+1].id; spawnBrainrot(plr,i)
		end
	end
	broadcastSlots(plr)
end

-- ---- petId targeting (Section 4) ----
local function getPetSlotByPetId(uid, petId)
	local pd = playerData[uid]; if not pd then return nil end
	for i, slot in ipairs(pd.slots) do
		if slot.petId == petId then return i, slot end
	end
	return nil
end

-- ---- InventorySync push (Section 2 + 5) ----
local function pushInventorySync(plr)
	local pd = playerData[plr.UserId]; if not pd then return end
	InvSyncRE:FireClient(plr, {
		version     = Registry.SNAPSHOT_VERSION,
		foods       = pd.inventory.foods,
		drinks      = pd.inventory.drinks,
		selectedPetId = pd.slots[1] and pd.slots[1].petId or nil,
		serverTime  = os.time(),
	})
end

-- ---- ConsumeResponse helper ----
local function consumeResp(plr, success, code, message)
	ConsumeRespRE:FireClient(plr, {
		success = success,
		code    = code or (success and "OK" or EC.INTERNAL_ERROR),
		message = message,
	})
end

-- ---- Public API ----
function M.GetPlayerData(uid) return playerData[uid] end

function M.ForceSetCoins(plr, newAmount)
	local pd=playerData[plr.UserId]; if not pd then return end
	pd.coins=math.max(0,math.floor(newAmount))
	local ls=plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Coins") then ls.Coins.Value=pd.coins end
	local stats=plr:FindFirstChild("BearStats")
	if stats and stats:FindFirstChild("Coins") then stats.Coins.Value=pd.coins end
	broadcastSlots(plr); saveData(plr)
end

-- ---- Player lifecycle ----
local function onPlayerAdded(plr)
	local saved=loadData(plr)
	local pd={
		coins=saved and saved.coins or STARTING_COINS,
		followEnabled=saved and saved.followEnabled~=false or true,
		slots={},drinkMultiplier=1,drinkExpiry=0,
		inventory=saved and saved.inventory or defaultInventory(),
	}
	-- Migration: old saves without inventory
	if not pd.inventory then pd.inventory=defaultInventory() end
	if not pd.inventory.foods then pd.inventory.foods={} end
	if not pd.inventory.drinks then pd.inventory.drinks={} end
	playerData[plr.UserId]=pd
	if saved and saved.slots and #saved.slots>0 then
		for i,s in ipairs(saved.slots) do
			table.insert(pd.slots,{
				tierId=s.tierId or "t1",age=s.age or 0,
				petId=s.petId or newPetId(plr.UserId,i),
				createdAt=s.createdAt or os.time(),model=nil,
			})
		end
	else
		table.insert(pd.slots,{
			tierId="t1",age=0,
			petId=newPetId(plr.UserId,1),createdAt=os.time(),model=nil,
		})
	end
	local ls=Instance.new("Folder"); ls.Name="leaderstats"; ls.Parent=plr
	local lsC=Instance.new("IntValue"); lsC.Name="Coins";     lsC.Value=pd.coins; lsC.Parent=ls
	local lsB=Instance.new("IntValue"); lsB.Name="Brainrots"; lsB.Value=#pd.slots; lsB.Parent=ls
	local stats=Instance.new("Folder"); stats.Name="BearStats"; stats.Parent=plr
	local cv=Instance.new("IntValue"); cv.Name="Coins"; cv.Value=pd.coins; cv.Parent=stats
	local function onChar()
		task.wait(1)
		for i in ipairs(pd.slots) do spawnBrainrot(plr,i) end
		if pd.followEnabled then startFollow(plr) end
		broadcastSlots(plr)
		pushInventorySync(plr)  -- full snapshot on join
	end
	if plr.Character then task.spawn(onChar) end
	plr.CharacterAdded:Connect(function() task.spawn(onChar) end)
	task.spawn(function()
		while plr.Parent do task.wait(2)
			local c=playerData[plr.UserId]
			if c then lsC.Value=c.coins; cv.Value=c.coins; lsB.Value=#c.slots end
		end
	end)
	task.spawn(function() while plr.Parent do task.wait(60); saveData(plr) end end)
	LB.UpdateCoins(plr.UserId,pd.coins)
	for _,slot in ipairs(pd.slots) do LB.UpdatePet(plr.UserId,plr.Name,slot) end
end

local function onPlayerRemoving(plr)
	stopFollow(plr); saveData(plr)
	local pd=playerData[plr.UserId]
	if pd then for i in ipairs(pd.slots) do despawnBrainrot(plr,i) end end
	playerData[plr.UserId]=nil
end

-- ---- Remote Events ----
FeedRE.OnServerEvent:Connect(function(plr)
	if not playerData[plr.UserId] then return end
	applyAge(plr,FEED_AGE); respond(plr,true,"🥕 Fed! +"..FEED_AGE.." age")
end)
WaterRE.OnServerEvent:Connect(function(plr)
	if not playerData[plr.UserId] then return end
	applyAge(plr,WATER_AGE); respond(plr,true,"💧 Watered! +"..WATER_AGE.." age")
end)
-- Buy food → add to inventory (no immediate effect)
BuyFoodRE.OnServerEvent:Connect(function(plr,foodName,qty)
	if type(foodName)~="string" then return end
	local def=FOOD_DEFS[foodName]; if not def then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	qty=math.max(1,math.floor(tonumber(qty) or 1))
	local total=def.cost*qty
	if pd.coins<total then respond(plr,false,"Need 💰 "..total.." for "..qty.."x "..foodName); return end
	pd.coins-=total
	pd.inventory.foods[foodName]=(pd.inventory.foods[foodName] or 0)+qty
	respond(plr,true,("Bought %dx %s! 💰 -%d"):format(qty,foodName,total))
	broadcastSlots(plr); saveData(plr)
end)

-- Buy drink → add to inventory
BuyDrinkRE.OnServerEvent:Connect(function(plr,drinkName,qty)
	if type(drinkName)~="string" then return end
	local def=DRINK_DEFS[drinkName]; if not def then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	qty=math.max(1,math.floor(tonumber(qty) or 1))
	local total=def.cost*qty
	if pd.coins<total then respond(plr,false,"Need 💰 "..total.." for "..qty.."x "..drinkName); return end
	pd.coins-=total
	pd.inventory.drinks[drinkName]=(pd.inventory.drinks[drinkName] or 0)+qty
	respond(plr,true,("Bought %dx %s! 💰 -%d"):format(qty,drinkName,total))
	broadcastSlots(plr); saveData(plr)
end)

-- Use food from inventory → apply age to all slots (bulk)
UseFoodRE.OnServerEvent:Connect(function(plr,foodName,qty)
	if type(foodName)~="string" then return end
	local def=FOOD_DEFS[foodName]; if not def then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	qty=math.max(1,math.floor(tonumber(qty) or 1))
	local have=pd.inventory.foods[foodName] or 0
	if have<qty then respond(plr,false,("Only have %d %s"):format(have,foodName)); return end
	pd.inventory.foods[foodName]=have-qty
	applyAge(plr,def.ageBonus*qty)
	respond(plr,true,("Used %dx %s! +%d age 🥕"):format(qty,foodName,def.ageBonus*qty))
	broadcastSlots(plr); saveData(plr)
end)

-- Use drink from inventory → activate multiplier
UseDrinkRE.OnServerEvent:Connect(function(plr,drinkName,qty)
	if type(drinkName)~="string" then return end
	local def=DRINK_DEFS[drinkName]; if not def then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	qty=math.max(1,math.floor(tonumber(qty) or 1))
	local have=pd.inventory.drinks[drinkName] or 0
	if have<qty then respond(plr,false,("Only have %d %s"):format(have,drinkName)); return end
	pd.inventory.drinks[drinkName]=have-qty
	-- Stacks duration, caps multiplier at highest used
	local newMult=math.max(pd.drinkMultiplier,def.multiplier)
	local addedDuration=def.duration*qty
	pd.drinkMultiplier=newMult
	pd.drinkExpiry=math.max(pd.drinkExpiry,os.clock())+addedDuration
	respond(plr,true,("Drank %dx %s! x%.0f for +%ds 💧"):format(qty,drinkName,newMult,addedDuration))
	broadcastSlots(plr); saveData(plr)
end)
BuyBearRE.OnServerEvent:Connect(function(plr,tierIdx)
	tierIdx=tonumber(tierIdx)
	if not tierIdx or tierIdx<1 or tierIdx>#tiers then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	if #pd.slots>=MAX_SLOTS then respond(plr,false,"Max "..MAX_SLOTS.." brainrots!"); return end
	local price=getBuyPrice(tierIdx)
	if pd.coins<price then respond(plr,false,"Need 💰 "..price); return end
	pd.coins-=price
	local ns={tierId=tiers[tierIdx].id,age=tiers[tierIdx].minAge,
		petId=newPetId(plr.UserId,#pd.slots+1),createdAt=os.time(),model=nil}
	table.insert(pd.slots,ns); spawnBrainrot(plr,#pd.slots)
	respond(plr,true,("Bought %s %s! 💰 -%d"):format(tiers[tierIdx].emoji,tiers[tierIdx].name,price))
	LB.UpdatePet(plr.UserId,plr.Name,ns); broadcastSlots(plr); saveData(plr)
end)
UpgradeRE.OnServerEvent:Connect(function(plr,slotIdx)
	slotIdx=tonumber(slotIdx); if not slotIdx then return end
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then respond(plr,false,"Invalid slot"); return end
	local _,ci=getTierById(slot.tierId); local ni=ci+1
	if ni>#tiers then respond(plr,false,"Max tier! 👑"); return end
	local price=getUpgradePrice(ci,ni)
	if pd.coins<price then respond(plr,false,"Need 💰 "..price.." for "..tiers[ni].name); return end
	pd.coins-=price; slot.tierId=tiers[ni].id; slot.age=tiers[ni].minAge
	spawnBrainrot(plr,slotIdx)
	respond(plr,true,("Upgraded to %s %s! 💰 -%d"):format(tiers[ni].emoji,tiers[ni].name,price))
	LB.UpdatePet(plr.UserId,plr.Name,slot); broadcastSlots(plr); saveData(plr)
end)
ToggleFollowRE.OnServerEvent:Connect(function(plr)
	local pd=playerData[plr.UserId]; if not pd then return end
	pd.followEnabled=not pd.followEnabled
	if pd.followEnabled then startFollow(plr); respond(plr,true,"Following! 🧠")
	else stopFollow(plr); respond(plr,true,"Stopped.") end
	broadcastSlots(plr)
end)
SellRE.OnServerEvent:Connect(function(plr,slotIdx)
	slotIdx=tonumber(slotIdx) or 1
	local pd=playerData[plr.UserId]; if not pd then return end
	local slot=pd.slots[slotIdx]; if not slot then respond(plr,false,"Invalid slot"); return end
	local tier=getTierById(slot.tierId)
	local finalPrice=math.floor(tier.sellPrice + slot.age * AGE_MULTIPLIER)
	pd.coins+=finalPrice; despawnBrainrot(plr,slotIdx); table.remove(pd.slots,slotIdx)
	for i,s in ipairs(pd.slots) do VF.despawnModel(s.model); s.model=nil; spawnBrainrot(plr,i) end
	respond(plr,true,("Sold %s %s for 💰 %d! (age bonus: +%d)"):format(tier.emoji,tier.name,finalPrice,math.floor(slot.age*AGE_MULTIPLIER)))
	broadcastSlots(plr); saveData(plr)
end)

-- ---- Admin Chat Commands ----
local function findPlayer(text)
	text=text:lower()
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1,#text)==text then return p end
		if p.DisplayName:lower():sub(1,#text)==text then return p end
	end
	return nil
end

Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg)
		if plr.UserId~=ADMIN_ID then return end
		local parts=msg:split(" ")
		local cmd=parts[1] and parts[1]:lower()

		if cmd=="/boards" then
			local action=parts[2] and parts[2]:lower()
			if action=="refresh" then
				LB.ForceRefresh()
				respond(plr,true,"Boards refreshed ✓")
			elseif action=="remove" and parts[3] then
				local sub=parts[3]:lower()
				if sub=="coins" and parts[4] then
					local target=findPlayer(parts[4])
					if not target then respond(plr,false,"Player not found: "..parts[4]); return end
					LB.RemoveFromCoins(target.UserId)
					respond(plr,true,"Removed "..target.Name.." from Coins board")
				elseif sub=="pet" and parts[4] then
					LB.RemoveFromPetBoards(parts[4])
					respond(plr,true,"Removed pet "..parts[4].." from pet boards")
				else
					respond(plr,false,"Usage: /boards remove coins <player> | /boards remove pet <petId>")
				end
			else
				respond(plr,false,"Usage: /boards refresh | /boards remove coins <player> | /boards remove pet <petId>")
			end

		elseif cmd=="/coins" and #parts>=4 then
			local action=parts[2]:lower()
			if action~="add" and action~="remove" and action~="set" then return end
			local amount=math.max(0,math.floor(tonumber(parts[4]) or 0))
			local target=findPlayer(parts[3])
			if not target then respond(plr,false,"Player not found: "..parts[3]); return end
			local pd=playerData[target.UserId]
			if not pd then respond(plr,false,"No data for "..target.Name); return end
			local new
			if action=="add" then new=pd.coins+amount
			elseif action=="remove" then new=math.max(0,pd.coins-amount)
			else new=amount end
			M.ForceSetCoins(target,new)
			respond(plr,true,("Admin: %s %s → 💰%d"):format(action,target.Name,new))
			respond(target,true,("💰 Admin adjusted your coins to %d"):format(new))

		elseif cmd=="/addbear" then
			local tierId=parts[2] or "t1"
			local pd=playerData[plr.UserId]; if not pd then return end
			if #pd.slots>=MAX_SLOTS then respond(plr,false,"Max slots!"); return end
			local ft
			for _,t in ipairs(tiers) do if t.id==tierId then ft=t; break end end
			if not ft then respond(plr,false,"Unknown tier: "..tierId); return end
			local ns={tierId=ft.id,age=ft.minAge,petId=newPetId(plr.UserId,#pd.slots+1),createdAt=os.time(),model=nil}
			table.insert(pd.slots,ns); spawnBrainrot(plr,#pd.slots)
			respond(plr,true,("Admin: Added %s %s"):format(ft.emoji,ft.name))
			LB.UpdatePet(plr.UserId,plr.Name,ns); broadcastSlots(plr); saveData(plr)
		end
	end)
end)

-- ---- ConsumeRequest — Zero Trust handler (Sections 2, 3, 4) ----
local consumeCooldowns = {}  -- [userId] = last os.clock()

ConsumeReqRE.OnServerEvent:Connect(function(plr, petId, itemId, amount)
	local uid = plr.UserId
	local pd  = playerData[uid]

	-- Section 3: rate limit
	local now = os.clock()
	if (consumeCooldowns[uid] or 0) + CONSUME_COOLDOWN > now then
		consumeResp(plr, false, EC.RATE_LIMITED, "Too fast — wait a moment")
		return
	end
	consumeCooldowns[uid] = now

	if not pd then
		consumeResp(plr, false, EC.INTERNAL_ERROR, "Player data not loaded"); return
	end

	-- Section 3: validate amount
	amount = math.floor(tonumber(amount) or 0)
	if amount < 1 then
		consumeResp(plr, false, EC.INVALID_AMOUNT, "Amount must be a positive integer"); return
	end

	-- Section 3: validate item exists in Registry
	local item = Registry.Get(itemId)
	if not item then
		consumeResp(plr, false, EC.ITEM_NOT_FOUND, "Unknown item: " .. tostring(itemId)); return
	end

	-- Section 4: validate petId ownership
	local slotIdx, slot = getPetSlotByPetId(uid, petId)
	if not slotIdx then
		consumeResp(plr, false, EC.PET_NOT_FOUND, "Pet not found: " .. tostring(petId)); return
	end

	-- Section 3: validate inventory stock
	local inv   = item.category == "Food" and pd.inventory.foods or pd.inventory.drinks
	local have  = inv[itemId] or 0
	if have < amount then
		consumeResp(plr, false, EC.INSUFFICIENT_STOCK,
			("Have %d, need %d %s"):format(have, amount, itemId)); return
	end

	-- Commit — server mutates state first, then notifies client
	inv[itemId] = have - amount

	if item.category == "Food" then
		slot.age += item.effectValue * amount
		-- Check tier upgrade
		local _, ci = getTierById(slot.tierId)
		if ci < #tiers and slot.age >= tiers[ci+1].minAge then
			slot.tierId = tiers[ci+1].id
			spawnBrainrot(plr, slotIdx)
		end
	else -- Drink
		local newMult = math.max(pd.drinkMultiplier, item.effectValue)
		pd.drinkMultiplier = newMult
		pd.drinkExpiry = math.max(pd.drinkExpiry, os.clock()) + (item.duration * amount)
	end

	-- Push updated state to client
	pushInventorySync(plr)
	broadcastSlots(plr)
	saveData(plr)

	consumeResp(plr, true, "OK",
		("Used %dx %s on %s"):format(amount, item.displayName, slot.tierId))
end)

-- ---- Idle Growth Loop ----
task.spawn(function()
	while true do task.wait(IDLE_INTERVAL)
		for uid,pd in pairs(playerData) do
			local plr=Players:GetPlayerByUserId(uid)
			local mult=1
			if pd.drinkExpiry and os.clock()<pd.drinkExpiry then mult=pd.drinkMultiplier or 1
			else pd.drinkMultiplier=1; pd.drinkExpiry=0 end
			local growth=math.max(1,math.floor(mult))
			for i,slot in ipairs(pd.slots) do
				slot.age+=growth
				local _,ci=getTierById(slot.tierId)
				if ci<#tiers and slot.age>=tiers[ci+1].minAge then
					slot.tierId=tiers[ci+1].id
					if plr then spawnBrainrot(plr,i) end
				end
			end
			if plr then broadcastSlots(plr) end
		end
	end
end)

-- ---- Init ----
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _,plr in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded,plr) end
LB.Start()
print("[BrainrotManager v4] loaded OK")
return M

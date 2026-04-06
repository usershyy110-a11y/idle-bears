-- ================================================
-- BrainrotVisualFactory
-- Responsible ONLY for building and placing visual models.
-- BearManager calls spawnModel() / despawnModel() / moveModel().
--
-- Visual strategy (per tier):
--   All tiers: humanoid-style SpecialMesh parts (Torso, Head, Arms, Legs)
--   Rare+    : colored accent ears
--   Epic+    : spike crown on head
--   Legendary+: halo ring
--   Mythic+  : gold crown
--   Secret+  : orbiting accent balls
--   OG Secret: wings + point light glow
--
-- PREFAB HOOK: If ServerStorage.BrainrotModels contains a Model named
-- "Bear_<tierId>", that prefab is cloned instead of building from parts.
-- This allows per-tier custom models without changing any other code.
-- ================================================

local M = {}

-- Roblox SpecialMesh mesh types
local MT = Enum.MeshType

local rarityColor = {
	["Common"]       = Color3.fromRGB(171,171,171),
	["Rare"]         = Color3.fromRGB(79,163,255),
	["Epic"]         = Color3.fromRGB(160,80,255),
	["Legendary"]    = Color3.fromRGB(255,180,0),
	["Mythic"]       = Color3.fromRGB(0,255,200),
	["Brainrot God"] = Color3.fromRGB(255,80,255),
	["Secret"]       = Color3.fromRGB(255,60,60),
	["OG Secret"]    = Color3.fromRGB(255,224,50),
}

-- ---- Part builder helpers ----

local function part(name, size, color, shape)
	local p = Instance.new("Part")
	p.Name        = name
	p.Size        = size
	p.Color       = color
	p.Anchored    = false
	p.CanCollide  = false
	p.CastShadow  = false
	p.TopSurface  = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	return p
end

local function mesh(parent, meshType, scale)
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType
	m.Scale    = scale or Vector3.new(1,1,1)
	m.Parent   = parent
	return m
end

local function weld(root, child, offsetCF)
	local w  = Instance.new("Weld")
	w.Part0  = root
	w.Part1  = child
	w.C0     = offsetCF
	w.C1     = CFrame.new()
	w.Parent = root
	child.Parent = root.Parent
	return w
end

local function billboard(body, tier, rarCol)
	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(0,240,0,60)
	bb.StudsOffset  = Vector3.new(0,7,0)
	bb.AlwaysOnTop  = false
	bb.Parent       = body

	local name = Instance.new("TextLabel")
	name.Size               = UDim2.new(1,0,0.6,0)
	name.BackgroundTransparency = 1
	name.TextColor3         = rarCol
	name.TextScaled         = true
	name.Font               = Enum.Font.GothamBold
	name.Text               = tier.emoji .. " " .. tier.name
	name.Parent             = bb

	local rar = Instance.new("TextLabel")
	rar.Size                = UDim2.new(1,0,0.4,0)
	rar.Position            = UDim2.new(0,0,0.6,0)
	rar.BackgroundTransparency = 1
	rar.TextColor3          = Color3.fromRGB(210,210,210)
	rar.TextScaled          = true
	rar.Font                = Enum.Font.Gotham
	rar.Text                = "[" .. tier.rarity .. "]"
	rar.Parent              = bb
end

-- ---- Build humanoid-style model from parts ----

local function buildFromParts(tier, rarCol)
	local model = Instance.new("Model")
	model.Name  = "Bear_" .. tier.id

	-- Torso (root)
	local torso = part("Torso", Vector3.new(2,2,1), tier.bodyColor)
	mesh(torso, MT.Brick, Vector3.new(1,1,1))
	torso.Anchored = true
	torso.Parent   = model
	model.PrimaryPart = torso

	-- Head
	local head = part("Head", Vector3.new(1.5,1.5,1.5), tier.headColor)
	mesh(head, MT.Head, Vector3.new(1.25,1.25,1.25))
	weld(torso, head, CFrame.new(0, 1.75, 0))

	-- Eyes
	local eyeL = part("EyeL", Vector3.new(0.35,0.35,0.2), tier.eyeColor, Enum.PartType.Ball)
	weld(torso, eyeL, CFrame.new(-0.4, 2.0, 0.72))
	local eyeR = part("EyeR", Vector3.new(0.35,0.35,0.2), tier.eyeColor, Enum.PartType.Ball)
	weld(torso, eyeR, CFrame.new(0.4, 2.0, 0.72))

	-- Mouth
	local mouth = part("Mouth", Vector3.new(0.6,0.18,0.18), tier.accentColor)
	mesh(mouth, MT.Cylinder, Vector3.new(0.3,1,1))
	weld(torso, mouth, CFrame.new(0, 1.55, 0.74))

	-- Arms
	local armL = part("ArmL", Vector3.new(0.6,1.6,0.6), tier.bodyColor)
	mesh(armL, MT.Brick, Vector3.new(1,1,1))
	weld(torso, armL, CFrame.new(-1.3, 0.2, 0))

	local armR = part("ArmR", Vector3.new(0.6,1.6,0.6), tier.bodyColor)
	mesh(armR, MT.Brick, Vector3.new(1,1,1))
	weld(torso, armR, CFrame.new(1.3, 0.2, 0))

	-- Legs
	local legL = part("LegL", Vector3.new(0.6,1.6,0.6), tier.bodyColor)
	mesh(legL, MT.Brick, Vector3.new(1,1,1))
	weld(torso, legL, CFrame.new(-0.5, -1.8, 0))

	local legR = part("LegR", Vector3.new(0.6,1.6,0.6), tier.bodyColor)
	mesh(legR, MT.Brick, Vector3.new(1,1,1))
	weld(torso, legR, CFrame.new(0.5, -1.8, 0))

	local idx = tonumber(tier.id:sub(2)) or 1

	-- Rare+: accent ears
	if idx >= 4 then
		local earL = part("EarL", Vector3.new(0.5,0.5,0.3), tier.accentColor)
		mesh(earL, MT.Head, Vector3.new(0.4,0.4,0.4))
		weld(torso, earL, CFrame.new(-0.85, 2.7, 0))
		local earR = part("EarR", Vector3.new(0.5,0.5,0.3), tier.accentColor)
		mesh(earR, MT.Head, Vector3.new(0.4,0.4,0.4))
		weld(torso, earR, CFrame.new(0.85, 2.7, 0))
	end

	-- Epic+: spikes on head
	if idx >= 7 then
		for i = 1, 3 do
			local spike = part("Spike"..i, Vector3.new(0.3,0.7,0.3), tier.accentColor)
			mesh(spike, MT.FileMesh) -- cone-ish via Wedge fallback
			local sm = spike:FindFirstChildOfClass("SpecialMesh")
			if sm then sm:Destroy() end
			-- use wedge shape for spike
			spike:Destroy()
			local wedge = Instance.new("WedgePart")
			wedge.Name       = "Spike"..i
			wedge.Size       = Vector3.new(0.3,0.8,0.35)
			wedge.Color      = tier.accentColor
			wedge.Anchored   = false
			wedge.CanCollide = false
			wedge.CastShadow = false
			weld(torso, wedge, CFrame.new((i-2)*0.55, 3.1, 0) * CFrame.Angles(0,0,0))
		end
	end

	-- Legendary+: halo
	if idx >= 9 then
		local halo = part("Halo", Vector3.new(2.4,0.2,2.4), Color3.fromRGB(255,220,0))
		mesh(halo, MT.FileMesh)
		local sm = halo:FindFirstChildOfClass("SpecialMesh")
		if sm then sm:Destroy() end
		-- cylinder ring approximation
		local haloP = part("Halo", Vector3.new(2.4,0.18,2.4), Color3.fromRGB(255,220,50))
		mesh(haloP, MT.Cylinder, Vector3.new(1,0.12,1))
		weld(torso, haloP, CFrame.new(0, 3.4, 0) * CFrame.Angles(0,0,math.pi/2))
	end

	-- Mythic+: crown
	if idx >= 11 then
		local crown = part("Crown", Vector3.new(1.8,0.7,1.8), Color3.fromRGB(255,200,0))
		mesh(crown, MT.Head, Vector3.new(1.5,0.6,1.5))
		weld(torso, crown, CFrame.new(0, 3.15, 0))
	end

	-- Secret+: orbiting balls
	if idx >= 13 then
		for i = 1, 3 do
			local angle = (i-1)*(math.pi*2/3)
			local orb = part("Orb"..i, Vector3.new(0.5,0.5,0.5), tier.accentColor, Enum.PartType.Ball)
			weld(torso, orb, CFrame.new(math.cos(angle)*1.8, 0.5, math.sin(angle)*1.8))
		end
	end

	-- OG Secret: wings + glow
	if idx >= 15 then
		local wingL = part("WingL", Vector3.new(0.2,1.8,2.8), tier.accentColor)
		mesh(wingL, MT.Brick, Vector3.new(1,1,1))
		weld(torso, wingL, CFrame.new(-2.2, 0.4, 0) * CFrame.Angles(0,0,math.rad(20)))

		local wingR = part("WingR", Vector3.new(0.2,1.8,2.8), tier.accentColor)
		mesh(wingR, MT.Brick, Vector3.new(1,1,1))
		weld(torso, wingR, CFrame.new(2.2, 0.4, 0) * CFrame.Angles(0,0,math.rad(-20)))

		local glow = Instance.new("PointLight")
		glow.Brightness = 3
		glow.Range      = 12
		glow.Color      = tier.accentColor
		glow.Parent     = torso
	end

	billboard(torso, tier, rarCol)
	return model
end

-- ---- Public API ----

-- prefabFolder: SS:FindFirstChild("BrainrotModels") — passed in from BearManager
function M.spawnModel(tier, prefabFolder, targetCFrame, modelName)
	local rarCol = rarityColor[tier.rarity] or Color3.new(1,1,1)
	local model

	-- PREFAB HOOK: use pre-built model if available
	if prefabFolder then
		local src = prefabFolder:FindFirstChild("Bear_" .. tier.id)
		if src then
			model = src:Clone()
			model.Name = modelName
		end
	end

	-- Fallback: build from SpecialMesh parts
	if not model then
		model = buildFromParts(tier, rarCol)
		model.Name = modelName
	end

	model.Parent = workspace

	-- Place via PivotTo (respects PrimaryPart + all welds)
	if model.PrimaryPart then
		model:PivotTo(targetCFrame)
	end

	return model
end

function M.despawnModel(model)
	if model and model.Parent then
		model:Destroy()
	end
end

-- Move the whole model — only touches PrimaryPart
function M.moveModel(model, targetCFrame)
	if model and model.Parent and model.PrimaryPart then
		model:PivotTo(targetCFrame)
	end
end

return M

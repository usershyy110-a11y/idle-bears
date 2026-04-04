-- ================================================
-- Idle Bears | Farm Map Builder
-- Run once in Studio Command Bar to build the map
-- ================================================

-- Helper functions
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.Size = props.Size or Vector3.new(4,1,4)
	p.CFrame = CFrame.new(props.Pos or Vector3.new(0,0,0))
	p.Color = props.Color or Color3.fromRGB(106,127,63)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Name then p.Name = props.Name end
	p.Parent = props.Parent or workspace
	return p
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or workspace
	return m
end

local function addLabel(p, text, face)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.Parent = p
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,0,1,0)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.fromRGB(255,255,255)
	tl.Text = text
	tl.Parent = sg
end

-- ===== ROOT =====
local MAP = model("BearFarm", workspace)

-- GROUND
part({Name="Ground",Parent=MAP,Size=Vector3.new(200,1,200),Pos=Vector3.new(0,0,0),
	Color=Color3.fromRGB(106,127,63),Material=Enum.Material.Grass})

-- PATH
part({Name="Path",Parent=MAP,Size=Vector3.new(8,0.6,160),Pos=Vector3.new(0,0.3,0),
	Color=Color3.fromRGB(151,107,74),Material=Enum.Material.Ground})

-- SPAWN PAD
part({Name="SpawnPad",Parent=MAP,Size=Vector3.new(12,0.8,12),Pos=Vector3.new(0,0.4,60),
	Color=Color3.fromRGB(163,162,165),Material=Enum.Material.Cobblestone})

-- ===== FARM AREA =====
local farm = model("FarmArea", MAP)
part({Name="FarmGround",Parent=farm,Size=Vector3.new(80,0.7,60),Pos=Vector3.new(-44,0.35,-30),
	Color=Color3.fromRGB(115,85,55),Material=Enum.Material.Ground})

for row = 0, 1 do
	for col = 0, 2 do
		local px = -70 + col * 22
		local pz = -15 - row * 28
		local plot = model("BearPlot_" .. (row*3+col+1), farm)
		part({Name="Soil",Parent=plot,Size=Vector3.new(16,0.8,16),Pos=Vector3.new(px,0.4,pz),
			Color=Color3.fromRGB(89,67,40),Material=Enum.Material.Ground})
		local fc = Color3.fromRGB(160,120,80)
		for _, fz in ipairs({pz-8.5, pz+8.5}) do
			part({Name="FenceFB",Parent=plot,Size=Vector3.new(17,2,0.5),Pos=Vector3.new(px,1.5,fz),Color=fc,Material=Enum.Material.Wood})
		end
		for _, fx in ipairs({px-8.5, px+8.5}) do
			part({Name="FenceLR",Parent=plot,Size=Vector3.new(0.5,2,17),Pos=Vector3.new(fx,1.5,pz),Color=fc,Material=Enum.Material.Wood})
		end
		local sign = part({Name="PlotSign",Parent=plot,Size=Vector3.new(3,1.5,0.3),Pos=Vector3.new(px,2.5,pz-9),Color=Color3.fromRGB(222,188,140),Material=Enum.Material.Wood})
		addLabel(sign, "Plot " .. (row*3+col+1))
		part({Name="BearSpawn",Parent=plot,Size=Vector3.new(5,0.2,5),Pos=Vector3.new(px,0.85,pz),
			Color=Color3.fromRGB(255,220,100),Material=Enum.Material.Neon,CanCollide=false})
	end
end

-- ===== SHOP =====
local shop = model("Shop", MAP)
part({Name="ShopFloor",Parent=shop,Size=Vector3.new(30,0.8,24),Pos=Vector3.new(50,0.4,-20),Color=Color3.fromRGB(180,150,110),Material=Enum.Material.Wood})
local wc = Color3.fromRGB(210,175,130)
part({Name="WallBack",Parent=shop,Size=Vector3.new(30,10,0.6),Pos=Vector3.new(50,5.4,-32),Color=wc,Material=Enum.Material.Wood})
part({Name="WallLeft",Parent=shop,Size=Vector3.new(0.6,10,24),Pos=Vector3.new(35,5.4,-20),Color=wc,Material=Enum.Material.Wood})
part({Name="WallRight",Parent=shop,Size=Vector3.new(0.6,10,24),Pos=Vector3.new(65,5.4,-20),Color=wc,Material=Enum.Material.Wood})
part({Name="WallFrontL",Parent=shop,Size=Vector3.new(10,10,0.6),Pos=Vector3.new(40,5.4,-8),Color=wc,Material=Enum.Material.Wood})
part({Name="WallFrontR",Parent=shop,Size=Vector3.new(10,10,0.6),Pos=Vector3.new(60,5.4,-8),Color=wc,Material=Enum.Material.Wood})
part({Name="DoorTop",Parent=shop,Size=Vector3.new(10,3,0.6),Pos=Vector3.new(50,9,-8),Color=wc,Material=Enum.Material.Wood})
part({Name="Roof",Parent=shop,Size=Vector3.new(34,1,28),Pos=Vector3.new(50,10.5,-20),Color=Color3.fromRGB(180,60,60),Material=Enum.Material.Brick})
local shopSign = part({Name="ShopSign",Parent=shop,Size=Vector3.new(12,3,0.5),Pos=Vector3.new(50,13,-8),Color=Color3.fromRGB(80,40,10),Material=Enum.Material.Wood})
addLabel(shopSign, "🐻 Bear Shop")

-- Counters
local bc = part({Name="BearCounter",Parent=shop,Size=Vector3.new(10,3,2),Pos=Vector3.new(40,2,-25),Color=Color3.fromRGB(140,100,60),Material=Enum.Material.Wood})
addLabel(bc, "🐻 Sell Bears")
part({Name="BearCounterTop",Parent=shop,Size=Vector3.new(10,0.4,2.5),Pos=Vector3.new(40,3.5,-24.8),Color=Color3.fromRGB(200,170,120),Material=Enum.Material.Wood})

local fc2 = part({Name="FoodCounter",Parent=shop,Size=Vector3.new(10,3,2),Pos=Vector3.new(60,2,-25),Color=Color3.fromRGB(60,130,80),Material=Enum.Material.Wood})
addLabel(fc2, "🥕 Bear Food")
part({Name="FoodCounterTop",Parent=shop,Size=Vector3.new(10,0.4,2.5),Pos=Vector3.new(60,3.5,-24.8),Color=Color3.fromRGB(120,200,120),Material=Enum.Material.Wood})

-- Proximity Prompts
for _, info in ipairs({{name="Sell Bear",pos=Vector3.new(40,2,-18)},{name="Buy Bear Food",pos=Vector3.new(60,2,-18)}}) do
	local t = Instance.new("Part")
	t.Name = info.name .. "Trigger"
	t.Size = Vector3.new(6,4,6)
	t.CFrame = CFrame.new(info.pos)
	t.Anchored = true; t.CanCollide = false; t.Transparency = 0.85
	t.Color = Color3.fromRGB(255,255,0); t.Parent = shop
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = info.name; pp.ObjectText = "Bear Shop"
	pp.MaxActivationDistance = 8; pp.Parent = t
end

-- ===== TREES =====
local trees = model("Trees", MAP)
for i, tp in ipairs({
	Vector3.new(-85,0,40),Vector3.new(-85,0,20),Vector3.new(-85,0,0),Vector3.new(-85,0,-40),
	Vector3.new(85,0,40),Vector3.new(85,0,15),Vector3.new(85,0,-10),Vector3.new(85,0,-50),
	Vector3.new(-30,0,75),Vector3.new(0,0,85),Vector3.new(30,0,75),
}) do
	part({Name="Trunk"..i,Parent=trees,Size=Vector3.new(2,8,2),Pos=Vector3.new(tp.X,4,tp.Z),Color=Color3.fromRGB(106,74,40),Material=Enum.Material.Wood})
	part({Name="Leaves"..i,Parent=trees,Size=Vector3.new(8,7,8),Pos=Vector3.new(tp.X,11,tp.Z),Color=Color3.fromRGB(75,151,75),Material=Enum.Material.Grass})
end

-- ===== OUTER FENCE =====
local fence = model("OuterFence", MAP)
local fenceC = Color3.fromRGB(185,145,95)
for x = -90,90,10 do
	part({Name="FN",Parent=fence,Size=Vector3.new(10,3,0.8),Pos=Vector3.new(x,1.5,-95),Color=fenceC,Material=Enum.Material.Wood})
	part({Name="FS",Parent=fence,Size=Vector3.new(10,3,0.8),Pos=Vector3.new(x,1.5,95),Color=fenceC,Material=Enum.Material.Wood})
end
for z = -90,90,10 do
	part({Name="FW",Parent=fence,Size=Vector3.new(0.8,3,10),Pos=Vector3.new(-95,1.5,z),Color=fenceC,Material=Enum.Material.Wood})
	part({Name="FE",Parent=fence,Size=Vector3.new(0.8,3,10),Pos=Vector3.new(95,1.5,z),Color=fenceC,Material=Enum.Material.Wood})
end

-- Welcome sign
local ws = part({Name="WelcomeSign",Parent=MAP,Size=Vector3.new(14,4,0.5),Pos=Vector3.new(0,5,68),Color=Color3.fromRGB(80,40,10),Material=Enum.Material.Wood})
addLabel(ws, "🐻 Welcome to Bear Farm!")

print("[IdleBears] Map built successfully!")

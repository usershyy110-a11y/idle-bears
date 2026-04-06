-- ================================================
-- ItemRegistry — Single Source of Truth for all consumable items
-- Used by both Server (BearManager) and Client (HUD/Shop UI)
-- ================================================
local ItemRegistry = {}

-- Error codes for ConsumeResponse
ItemRegistry.ErrorCodes = {
	INVALID_AMOUNT      = "INVALID_AMOUNT",
	ITEM_NOT_FOUND      = "ITEM_NOT_FOUND",
	INSUFFICIENT_STOCK  = "INSUFFICIENT_STOCK",
	PET_NOT_FOUND       = "PET_NOT_FOUND",
	PET_NOT_OWNED       = "PET_NOT_OWNED",
	RATE_LIMITED        = "RATE_LIMITED",
	INTERNAL_ERROR      = "INTERNAL_ERROR",
}

-- Item schema:
--   itemId       string  — unique key, matches FOOD_DEFS/DRINK_DEFS keys in BearManager
--   displayName  string  — shown in UI
--   assetId      string  — Roblox image asset id ("rbxassetid://...")
--   category     string  — "Food" | "Drink"
--   cost         number  — coin cost per unit
--   effectValue  number  — age bonus per unit (Food) OR multiplier (Drink)
--   duration     number? — seconds active (Drink only)
--   maxStack     number  — max units in inventory (0 = unlimited)
--   sortOrder    number  — display order in UI (lower = first)
--   isEnabled    boolean — false hides item from shop without removing from code

local items = {
	-- ---- Foods ----
	{
		itemId="Honey",          displayName="Honey",
		assetId="rbxassetid://0", category="Food",
		cost=5,    effectValue=3,      maxStack=0, sortOrder=1,  isEnabled=true,
	},
	{
		itemId="Berries",        displayName="Berries",
		assetId="rbxassetid://0", category="Food",
		cost=15,   effectValue=8,      maxStack=0, sortOrder=2,  isEnabled=true,
	},
	{
		itemId="Salmon",         displayName="Salmon",
		assetId="rbxassetid://0", category="Food",
		cost=35,   effectValue=20,     maxStack=0, sortOrder=3,  isEnabled=true,
	},
	{
		itemId="Magic Fruit",    displayName="Magic Fruit",
		assetId="rbxassetid://0", category="Food",
		cost=80,   effectValue=50,     maxStack=0, sortOrder=4,  isEnabled=true,
	},
	{
		itemId="Golden Apple",   displayName="Golden Apple",
		assetId="rbxassetid://0", category="Food",
		cost=200,  effectValue=120,    maxStack=0, sortOrder=5,  isEnabled=true,
	},
	{
		itemId="Dragon Fruit",   displayName="Dragon Fruit",
		assetId="rbxassetid://0", category="Food",
		cost=6000,   effectValue=3600,   maxStack=0, sortOrder=6,  isEnabled=true,
	},
	{
		itemId="Phoenix Berry",  displayName="Phoenix Berry",
		assetId="rbxassetid://0", category="Food",
		cost=18000,  effectValue=9600,   maxStack=0, sortOrder=7,  isEnabled=true,
	},
	{
		itemId="Void Salmon",    displayName="Void Salmon",
		assetId="rbxassetid://0", category="Food",
		cost=42000,  effectValue=24000,  maxStack=0, sortOrder=8,  isEnabled=true,
	},
	{
		itemId="Astral Melon",   displayName="Astral Melon",
		assetId="rbxassetid://0", category="Food",
		cost=96000,  effectValue=60000,  maxStack=0, sortOrder=9,  isEnabled=true,
	},
	{
		itemId="Celestial Core", displayName="Celestial Core",
		assetId="rbxassetid://0", category="Food",
		cost=240000, effectValue=144000, maxStack=0, sortOrder=10, isEnabled=true,
	},

	-- ---- Drinks ----
	{
		itemId="Fresh Water",    displayName="Fresh Water",
		assetId="rbxassetid://0", category="Drink",
		cost=8,      effectValue=1.5,  duration=120,  maxStack=0, sortOrder=1,  isEnabled=true,
	},
	{
		itemId="River Water",    displayName="River Water",
		assetId="rbxassetid://0", category="Drink",
		cost=20,     effectValue=2,    duration=180,  maxStack=0, sortOrder=2,  isEnabled=true,
	},
	{
		itemId="Spring Water",   displayName="Spring Water",
		assetId="rbxassetid://0", category="Drink",
		cost=50,     effectValue=3,    duration=240,  maxStack=0, sortOrder=3,  isEnabled=true,
	},
	{
		itemId="Mystic Water",   displayName="Mystic Water",
		assetId="rbxassetid://0", category="Drink",
		cost=120,    effectValue=5,    duration=300,  maxStack=0, sortOrder=4,  isEnabled=true,
	},
	{
		itemId="Celestial Dew",  displayName="Celestial Dew",
		assetId="rbxassetid://0", category="Drink",
		cost=300,    effectValue=10,   duration=420,  maxStack=0, sortOrder=5,  isEnabled=true,
	},
	{
		itemId="Void Essence",   displayName="Void Essence",
		assetId="rbxassetid://0", category="Drink",
		cost=9000,   effectValue=15,   duration=600,  maxStack=0, sortOrder=6,  isEnabled=true,
	},
	{
		itemId="Nebula Sap",     displayName="Nebula Sap",
		assetId="rbxassetid://0", category="Drink",
		cost=22500,  effectValue=20,   duration=720,  maxStack=0, sortOrder=7,  isEnabled=true,
	},
	{
		itemId="Star Bloom",     displayName="Star Bloom",
		assetId="rbxassetid://0", category="Drink",
		cost=56250,  effectValue=30,   duration=900,  maxStack=0, sortOrder=8,  isEnabled=true,
	},
	{
		itemId="Aurora Elixir",  displayName="Aurora Elixir",
		assetId="rbxassetid://0", category="Drink",
		cost=135000, effectValue=50,   duration=1200, maxStack=0, sortOrder=9,  isEnabled=true,
	},
	{
		itemId="Eternal Spring", displayName="Eternal Spring",
		assetId="rbxassetid://0", category="Drink",
		cost=337500, effectValue=100,  duration=1800, maxStack=0, sortOrder=10, isEnabled=true,
	},
}

-- ---- Internal lookup tables (built once at require-time) ----
local byId       = {}  -- itemId -> item
local byCategory = {Food={}, Drink={}}

for _, item in ipairs(items) do
	byId[item.itemId] = item
	if byCategory[item.category] then
		table.insert(byCategory[item.category], item)
	end
end

-- Sort each category by sortOrder
for _, list in pairs(byCategory) do
	table.sort(list, function(a, b) return a.sortOrder < b.sortOrder end)
end

-- ---- Public API ----

-- Returns item definition or nil
function ItemRegistry.Get(itemId)
	return byId[itemId]
end

-- Returns ordered list for a category ("Food" or "Drink"), enabled only by default
function ItemRegistry.GetByCategory(category, includeDisabled)
	local list = byCategory[category] or {}
	if includeDisabled then return list end
	local out = {}
	for _, item in ipairs(list) do
		if item.isEnabled then table.insert(out, item) end
	end
	return out
end

-- Returns all enabled items (both categories)
function ItemRegistry.GetAll(includeDisabled)
	local out = {}
	for _, item in ipairs(items) do
		if includeDisabled or item.isEnabled then
			table.insert(out, item)
		end
	end
	return out
end

-- Snapshot format for InventorySync payload versioning
ItemRegistry.SNAPSHOT_VERSION = 1

return ItemRegistry

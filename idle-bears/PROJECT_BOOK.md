# Idle Bears → Brainrot Game — Project Book

> **Last updated:** 2026-04-06  
> **Platform:** Roblox Studio (Luau)  
> **Repo:** `usershyy110-a11y/shyy_AI` → `roblox/idle-bears/`

---

## Overview

An idle Roblox game where players receive a Brainrot character, feed/water it to grow its age, and sell it for coins. Characters progress through 15 tiers from Common to OG Secret. The game features a shop, leaderboards, admin commands, and follow mechanics.

---

## Architecture

```
ReplicatedStorage/
  BearTiers.lua            ← Data-only: 15 Brainrot tier definitions
  BrainrotVisualFactory.lua ← Visual layer: spawn/despawn/move models

ServerScriptService/
  BearManager.lua          ← Core server logic + admin commands (Script)
  LeaderboardService.lua   ← ODS leaderboards + board UI (ModuleScript)

StarterPlayerScripts/
  BearHUD.client.lua       ← Player HUD (coins, slots, feed/water/sell)

RemoteEvents (ReplicatedStorage/RemoteEvents/):
  BuyBear, UpgradeBear, ToggleFollow, BearSlotUpdate,
  ShopResponse, SellBear, FeedBear, WaterBear, BuyFood, BuyDrink
```

### Module Responsibilities

| Module | Role |
|---|---|
| `BearTiers` | Static data: id, name, rarity, colors, sellPrice, minAge, emoji |
| `BrainrotVisualFactory` | Builds humanoid SpecialMesh models; prefab hook; spawn/despawn/move |
| `BearManager` | Player data lifecycle, idle growth loop, remote event handlers, admin chat |
| `LeaderboardService` | ODS rankings, DS metadata, 60s refresh loop, SurfaceGui boards |

---

## The 15 Brainrot Tiers

| # | ID | Name | Rarity | Emoji | Sell Price |
|---|---|---|---|---|---|
| 1 | t1 | Noobini Pizzanini | Common | 🍕 | 10 |
| 2 | t2 | Pipi Corni | Common | 🌽 | 30 |
| 3 | t3 | Chimpanzini Banani | Common | 🍌 | 90 |
| 4 | t4 | Tong Tong Sahur | Rare | 🪘 | 270 |
| 5 | t5 | Ballerina Cappuccino | Rare | ☕ | 810 |
| 6 | t6 | Los Tralaleritos | Rare | 🎵 | 2,430 |
| 7 | t7 | Frigo Camelo | Epic | 🐪 | 7,290 |
| 8 | t8 | Matio | Epic | 🍄 | 21,870 |
| 9 | t9 | Bombadero Crocodile | Legendary | 🐊 | 65,610 |
| 10 | t10 | Giraffe Celestea | Legendary | 🦒 | 196,830 |
| 11 | t11 | Crocila | Mythic | 👑 | 590,490 |
| 12 | t12 | Cocofanto Elefanto | Brainrot God | 🐘 | 1,771,470 |
| 13 | t13 | Dragon Cannelloni | Secret | 🐉 | 8,857,350 |
| 14 | t14 | Strawberry Elephant | Secret | 🍓 | 44,286,750 |
| 15 | t15 | Garra | OG Secret | ⚡ | 221,433,750 |

Sell prices scale x3 per tier (t13+ scale x5).

---

## Visual System (BrainrotVisualFactory)

### Humanoid SpecialMesh Model

Each Brainrot is built from welded parts:

| Part | Mesh | Notes |
|---|---|---|
| Torso | Brick | PrimaryPart, Anchored=true |
| Head | Head | Rounded, 1.9Y above torso |
| EyeL/EyeR | Ball | With white shine dots |
| Mouth | Cylinder | Accent color bar |
| ArmL/ArmR | Brick | 88% body color (shade) |
| LegL/LegR | Brick | 85% limb color (shade) |

### Rarity Visual Upgrades

| Rarity | Extra Parts |
|---|---|
| Rare+ (t4+) | Accent-colored ears |
| Epic+ (t7+) | 3 WedgePart spikes on head |
| Legendary+ (t9+) | Gold halo cylinder ring |
| Mythic+ (t11+) | Gold crown |
| Secret+ (t13+) | 3 orbiting accent balls |
| OG Secret (t15+) | Wings + PointLight glow |

### Prefab Hook

If `ServerStorage.BrainrotModels` contains a Model named `Bear_<tierId>`, it is cloned instead of building procedurally. This allows custom meshes per tier without changing any other code.

### Color Helpers

```lua
safeColor(v, fallback)  -- nil-safe Color3 access
shade(c, factor)        -- darken/lighten a Color3
```

---

## Game Mechanics

### Coins
- Start: 30 coins
- Earn: sell Brainrots
- Spend: buy food, drinks, new Brainrots, upgrades

### Age & Tier Progression
- Each Brainrot has an `age` value
- Age auto-increases every 30s (idle growth)
- Feeding/watering gives instant age bonuses
- When age reaches `tiers[nextTier].minAge`, tier upgrades automatically and model respawns

### Food Shop (instant age bonus)
| Item | Cost | Age Bonus |
|---|---|---|
| Honey | 5 | +3 |
| Berries | 15 | +8 |
| Salmon | 35 | +20 |
| Magic Fruit | 80 | +50 |
| Golden Apple | 200 | +120 |

### Drink Shop (idle growth multiplier)
| Item | Cost | Multiplier | Duration |
|---|---|---|---|
| Fresh Water | 8 | x1.5 | 2 min |
| River Water | 20 | x2 | 3 min |
| Spring Water | 50 | x3 | 4 min |
| Mystic Water | 120 | x5 | 5 min |
| Celestial Dew | 300 | x10 | 7 min |

### Slots
- Max 5 Brainrot slots per player
- Each slot tracks: `tierId`, `age`, `petId` (GUID), `createdAt` (os.time)

### Follow
- Brainrots follow the player's character (Heartbeat lerp)
- Toggled via HUD button
- Formation: 3 per row, offset behind player

---

## Leaderboards

Three in-world SurfaceGui boards inside `workspace.Leaderboards`:

| Board | ODS Key | Ranks By | Location |
|---|---|---|---|
| CoinsBoard | `CoinsLeaderboard_v1` | Coins (desc) | X=50, Z=31 |
| OldestBoard | `OldestBrainrots_v1` | Pet age (desc) | X=50, Z=56 |
| NewestBoard | `NewestBrainrots_v1` | createdAt (desc) | X=50, Z=81 |

- Metadata stored in `BrainrotMeta_v1` DataStore (petId → ownerName, tierId, age, createdAt)
- Boards refresh every 60 seconds
- Top 10 shown, gold/silver/bronze colors for rank 1/2/3

---

## Admin Commands (chat only, UserId 5647716264)

| Command | Effect |
|---|---|
| `/coins add <player> <n>` | Add n coins to player |
| `/coins remove <player> <n>` | Remove n coins from player (min 0) |
| `/coins set <player> <n>` | Set player coins to exact value |
| `/addbear <tierId>` | Add a Brainrot of given tier to admin's slots |

Player matching is case-insensitive prefix search (Name or DisplayName).

---

## DataStore

| Key | Store | Content |
|---|---|---|
| `bearv4:<userId>` | `BearData_v4` | `{coins, followEnabled, slots[]}` |
| `<userId>` | `CoinsLeaderboard_v1` (ODS) | coins integer |
| `<petId>` | `OldestBrainrots_v1` (ODS) | age integer |
| `<petId>` | `NewestBrainrots_v1` (ODS) | createdAt integer |
| `<petId>` | `BrainrotMeta_v1` | `{ownerUserId, ownerName, tierId, age, createdAt}` |

> Enable in Studio: **Game Settings → Security → Enable Studio Access to API Services**

---

## Key Technical Notes

### Weld vs WeldConstraint
Use `Weld` with explicit `C0` offsets. `WeldConstraint` captures the current physical distance between parts — unreliable when all parts start at origin (0,0,0).

### Module vs Script
`BearManager` is a `Script` (not ModuleScript). `require()` only works on ModuleScripts. Admin logic is merged directly into BearManager to avoid cross-script require.

### require() Cache
Luau caches module results after first require. If a ModuleScript's data needs updating, the Source must be edited directly in Studio (not hot-reloaded).

### Model Positioning
`model:PivotTo(CFrame)` moves the entire model via PrimaryPart + all welds. Never move individual parts directly after welding.

---

## Map Layout

```
North (Z+)
  Pond @ (-96, Z=81)
  Barn @ (-96, Z=-34)
  Shop @ (X=9, Z=21)
  BearFarm (6 plots, 2 rows)
    Row 1: plots @ X=-111,-89,-67  Z=26
    Row 2: plots @ X=-111,-89,-67  Z=-2
  Leaderboards (east fence, X=50)
    CoinsBoard  @ Z=31
    OldestBoard @ Z=56
    NewestBoard @ Z=81
  Trees (east side, X=44): Z=81,56,31,-9
  OuterFence: W=-136, E=54, N=136, S=-54
  SpawnPad @ (-41, Z=101)
```

---

## Changelog

### Session 1 — Foundation
- 15-tier BearTiers data module
- BearManager with slots, idle growth, sell/feed/water
- BearHUD LocalScript with feed/water/sell buttons
- Food shop (5 levels), drink shop (5 levels)

### Session 2 — Brainrot Theme
- Replaced all 15 bear tiers with Brainrot characters
- BrainrotVisualFactory: humanoid SpecialMesh models
- Per-rarity visual upgrades (ears, spikes, halo, crown, orbs, wings)
- `safeColor()` + `shade()` color helpers
- Prefab hook for custom ServerStorage models

### Session 3 — Leaderboards & Admin
- LeaderboardService: 3 ODS boards + metadata DS
- In-world SurfaceGui boards (CoinsBoard, OldestBoard, NewestBoard)
- Admin `/coins add|remove|set <player> <n>` with prefix player search
- Admin `/addbear <tierId>` for instant tier injection
- BearManager v4: clean rewrite with petId (GUID), createdAt, LB integration
- Boards repositioned to east fence (X=50) alongside right-side trees

---

## Future Ideas

### Gameplay
- [ ] Walking path / roaming behavior for Brainrots
- [ ] Mini-game on feeding (timed key press)
- [ ] Egg hatching gacha system
- [ ] Breeding: two Brainrots → new one
- [ ] Daily quests / challenges
- [ ] Player-to-player trading

### Visuals
- [ ] Particle effects by rarity (sparks for Legendary, fire for Secret)
- [ ] Unique animations per rarity
- [ ] Sound effects per tier
- [ ] Larger map with rarity-gated zones
- [ ] Real mesh models (uploaded assets)

### Systems
- [ ] Rebirth system (reset + permanent bonus)
- [ ] Game Pass: x2 growth, extra slot, free food
- [ ] Expanded inventory (more than 5 slots)
- [ ] Global event challenges

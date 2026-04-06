# Idle Bears — Implementation Roadmap

> **Last updated:** 2026-04-06  
> **Status:** Phase 1 ready to build

---

## Phase 1 — Admin Commands + Dynamic Pricing + Stable Boards

### 1A. Expanded Admin Commands

**New commands to add (merged into BearManager chat handler):**

| Command | Effect |
|---|---|
| `/boards refresh` | Force-refresh all 3 leaderboard boards immediately |
| `/boards remove coins <player>` | Remove player from CoinsLeaderboard ODS |
| `/boards remove pet <petId>` | Remove a pet from OldestBrainrots + NewestBrainrots ODS |

**Changes required:**
- `LeaderboardService.lua` — expose `ForceRefresh()` and `RemoveFromCoins(userId)` and `RemoveFromPetBoards(petId)` as public functions
- `BearManager.lua` — add `/boards` branch to the admin chat parser

---

### 1B. Dynamic Sell Price

Replace fixed `tier.sellPrice` with age-based formula:

```lua
local AGE_MULTIPLIER = 1.5

-- In SellRE handler:
local finalSellPrice = math.floor(tier.sellPrice + slot.age * AGE_MULTIPLIER)
```

**Changes required:**
- `BearManager.lua` — update `SellRE.OnServerEvent` handler
- `BearHUD.client.lua` — display the calculated price in the sell button tooltip (send via `BearSlotUpdate` payload)

**Test cases:**
- Sell t1 at age 0 → 10 coins
- Sell t1 at age 20 → 10 + 30 = 40 coins
- Sell t9 at age 100 → 65,610 + 150 = 65,760 coins

---

### 1C. Board Stability

- Verify boards refresh correctly after `/boards refresh`
- Verify `RemoveAsync` on ODS clears entry from board on next refresh
- Enable **Game Settings → Security → Enable Studio Access to API Services** for DataStore to work in Studio

---

## Phase 2 — Food & Drink Inventory + Bulk Feed

### 2A. playerData Schema Change

Add `inventory` table to player data:

```lua
-- Default player data
{
    coins = 30,
    followEnabled = true,
    slots = {},
    drinkMultiplier = 1,
    drinkExpiry = 0,
    inventory = {
        -- food items
        Honey = 0,
        Berries = 0,
        Salmon = 0,
        ["Magic Fruit"] = 0,
        ["Golden Apple"] = 0,
        -- drink items
        ["Fresh Water"] = 0,
        ["River Water"] = 0,
        ["Spring Water"] = 0,
        ["Mystic Water"] = 0,
        ["Celestial Dew"] = 0,
    }
}
```

### 2B. Buy = Stock, Use = Consume

Split current buy-and-use into two separate flows:

**BuyFood** → adds to `inventory[foodName]` (no immediate age bonus)  
**UseFood(slotIdx, foodName, quantity)** → deducts inventory, applies age × quantity

```lua
-- New RemoteEvent: UseFood
UseFoodRE.OnServerEvent:Connect(function(plr, slotIdx, foodName, quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    local def = FOOD_DEFS[foodName]
    local pd = playerData[plr.UserId]
    if not def or not pd then return end
    if (pd.inventory[foodName] or 0) < quantity then
        respond(plr, false, "Not enough " .. foodName); return
    end
    pd.inventory[foodName] -= quantity
    applyAge(plr, def.ageBonus * quantity)
    respond(plr, true, ("Used %dx %s! +%d age"):format(quantity, foodName, def.ageBonus * quantity))
    saveData(plr)
end)
```

**Same pattern for drinks** — stock in inventory, apply multiplier on use.

### 2C. HUD Changes

- Add inventory panel (counts per item)
- Quantity selector (slider or +/- buttons) before using food/drink
- Show total age gain preview before confirming

### 2D. DataStore Migration

`inventory` must be included in `saveData` / `loadData`.  
Old saves (no `inventory` key) default all counts to 0 — safe migration, no wipe needed.

---

## Phase 3 — Local Server Trade

> **Do NOT start until Phase 1 + 2 are stable and tested.**

### Architecture: TradeService.lua (separate ModuleScript)

Reason: keeps BearManager focused on player data. TradeService manages trade state machine; calls `BearManager.SwapAssets(p1, p2, offer1, offer2)` only on confirmed commit.

### Trade State Machine

```
Idle → [RequestTrade] → Pending
Pending → [Accept/Decline] → Accepted / Cancelled
Accepted → [3s countdown] → Committed / Cancelled
Committed → [SwapAssets] → Idle
```

### API Surface (TradeService.lua)

```lua
TradeService.RequestTrade(player1, player2)
-- Validates: both online, no active trade, not same player

TradeService.UpdateOffer(player, { coins=n, petSlots={1,2} })
-- Locks offer during confirmation window

TradeService.AcceptTrade(player)
-- Both must accept → starts 3s countdown (anti-scam)

TradeService.CancelTrade(player)
-- Either player can cancel before commit

-- Internal only:
local function CommitTrade(tradeData)
    BearManager.SwapAssets(p1, p2, offer1, offer2)
end
```

### BearManager addition needed

```lua
function M.SwapAssets(p1, p2, offer1, offer2)
    -- Lock both players' slots during swap
    -- Transfer coins + pets atomically
    -- Respawn models for both players
    -- Broadcast updated slots to both players
    -- Save both players' data
end
```

### Anti-exploit Rules

- Server validates all offer contents (no negative coins, no invalid slots)
- Pets offered are locked (cannot be sold/fed) during trade window
- If either player leaves during trade → auto-cancel, no data change
- No cross-server trade (MemoryStoreService complexity not worth it yet)

---

## Deferred (not in any phase yet)

| Feature | Notes |
|---|---|
| Expand to 30+ tiers | Do as one coordinated update to BearTiers.lua + shop prices |
| Private servers | No code needed — enable in Creator Dashboard |
| Cross-server trade | Requires MemoryStoreService + MessagingService, high complexity |
| Egg hatching gacha | New RemoteEvent + probability table |
| Rebirth system | Reset slots/age, keep bonus multiplier |
| Game Pass | x2 growth, extra slot — BillingService integration |

---

## Work Order Summary

```
Phase 1
  ├── LeaderboardService: expose ForceRefresh + RemoveFromCoins + RemoveFromPetBoards
  ├── BearManager: add /boards admin command branch
  ├── BearManager: dynamic sell price (basePrice + age × 1.5)
  └── BearHUD: show calculated sell price per slot

Phase 2
  ├── playerData: add inventory{} table
  ├── BearManager: split BuyFood → stock only
  ├── BearManager: new UseFood RemoteEvent with quantity
  ├── Same for drinks
  ├── saveData/loadData: include inventory
  └── BearHUD: inventory panel + quantity selector

Phase 3
  ├── TradeService.lua: state machine (RequestTrade, UpdateOffer, Accept, Cancel, Commit)
  ├── BearManager: add SwapAssets API
  ├── New RemoteEvents: TradeRequest, TradeOffer, TradeAccept, TradeCancel, TradeUpdate
  └── BearHUD: trade UI panel
```

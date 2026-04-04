# Idle Bears — Game Design Document

## Concept
Idle farming game inspired by "Grow a Garden". Each player owns a bear that grows older over time.
Color shifts from white → yellow as the bear ages. Players interact via Feed/Water buttons.

## Core Loop
1. Player joins → bear spawns with saved age (+ offline growth)
2. Bear ages every 30 seconds automatically (idle)
3. Player feeds (+3 age) or waters (+2 age) to speed growth
4. Color interpolates white→yellow as age approaches 100
5. Age saved to DataStore on interval + on player leave

## Architecture

```
ReplicatedStorage/
  RemoteEvents/
    FeedBear    (RemoteEvent)
    WaterBear   (RemoteEvent)

ServerStorage/
  BearTemplate/
    Body        (Part, Anchored, 4x4x4, white)

ServerScriptService/
  Main          (Script) — all server logic

StarterPlayer/
  StarterPlayerScripts/
    Ui.client   (LocalScript) — HUD buttons + age display
```

## Constants (Main.server.lua)
| Name | Value | Description |
|---|---|---|
| GROW_INTERVAL | 30s | Seconds between idle ticks |
| AGE_PER_TICK | 1 | Age added per tick |
| MAX_AGE_COLOR | 100 | Age at which color is fully yellow |
| FEED_BONUS | 3 | Age bonus from feeding |
| WATER_BONUS | 2 | Age bonus from watering |
| ACTION_COOLDOWN | 2s | Minimum time between player actions (anti-spam) |
| SAVE_INTERVAL | 60s | Periodic DataStore save interval |

## DataStore
- Key: `bear:<UserId>`
- Value: `{ age: number, savedAt: unix_timestamp }`
- Offline growth calculated on login: `floor((now - savedAt) / GROW_INTERVAL)`

## Security
- Server validates all RemoteEvent calls
- Rate-limit: 2s cooldown per player per action
- No client-side authority over Age value

## Roadmap
- [ ] Stage 3: Rare bear variants (color/shape)
- [ ] Stage 4: Leaderboard (leaderstats)
- [ ] Stage 5: Mini-games for bonus age
- [ ] Stage 6: Seasonal events
- [ ] Stage 7: Mobile UI polish

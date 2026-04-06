# Idle Bears → Brainrot Game — DevLog

## המטרה המקורית
משחק Roblox idle בסגנון "גדל הדובון שלך" — שחקן מקבל דובון, מאכיל אותו, הוא גדל ועולה ברמה, ואפשר למכור אותו תמורת מטבעות.

---

## מה שנבנה (סדר כרונולוגי)

### שלב 1 — תשתית בסיסית
- `BearTiers` ModuleScript — 15 רמות דובון
- `BearManager` ModuleScript — לוגיקת שרת (גידול, מכירה, slots)
- `BearManagerLoader` Script — טוען את BearManager
- `BearHUD` LocalScript — ממשק שחקן
- `ShopServer` / `Main` — סקריפטים ישנים (הושבתו)
- RemoteEvents: SellBear, BuyFood, ShopResponse, FeedBear, WaterBear

### שלב 2 — הרחבות (לפי בקשה)
| תכונה | פרטים |
|---|---|
| כפתורי Feed/Water | 🥕 Feed ו-💧 Water בHUD, cooldown 0.5s |
| חנות אוכל (5 רמות) | Honey(+3)/Berries(+8)/Salmon(+20)/Magic Fruit(+50)/Golden Apple(+120) |
| חנות שתיה (5 רמות) | Fresh Water(x1.5/120s) → Celestial Dew(x10/420s) — מכפיל גידול idle |
| Admin Commands | `/coins <n>` ו-`/addbrain <tierId>` — רק ל-UserId 5647716264 |

### שלב 3 — החלפת דובונים בברינרוטים
הוחלפו כל 15 הדמויות לדמויות מהמשחק "a Brainrot":

| Tier | שם | Rarity | Emoji |
|---|---|---|---|
| t1 | Noobini Pizzanini | Common | 🍕 |
| t2 | Pipi Corni | Common | 🌽 |
| t3 | Chimpanzini Banani | Common | 🍌 |
| t4 | Tong Tong Sahur | Rare | 🪘 |
| t5 | Ballerina Cappuccino | Rare | ☕ |
| t6 | Los Tralaleritos | Rare | 🎵 |
| t7 | Frigo Camelo | Epic | 🐪 |
| t8 | Matio | Epic | 🍄 |
| t9 | Bombadero Crocodile | Legendary | 🐊 |
| t10 | Giraffe Celestea | Legendary | 🦒 |
| t11 | Crocila | Mythic | 👑 |
| t12 | Cocofanto Elefanto | Brainrot God | 🐘 |
| t13 | Dragon Cannelloni | Secret | 🐉 |
| t14 | Strawberry Elephant | Secret | 🍓 |
| t15 | Garra | OG Secret | ⚡ |

**מחירי מכירה:** x3 כל שלב, t14/t15 x5 (10 → 132,860,250)

**עיצוב מודלים לפי Rarity:**
- Common: גוף+ראש+עיניים+פה+רגליים
- Rare+: אוזניים
- Epic+: קוצים
- Legendary+: הילה
- Mythic+: כתר
- Secret+: כדורי אורה סביב הגוף
- OG Secret: כנפיים + אאורה

---

## תקלות ופתרונות

| תקלה | סיבה | פתרון |
|---|---|---|
| מודלים נעלמו אחרי עצירת Play | נבנו ב-Play Mode — כל שינוי runtime נמחק | בניה מחדש ב-Edit Mode |
| `Color3.fromHex` — שגיאה | לא קיים ב-Roblox Luau | הוחלף ב-`Color3.fromRGB()` ישירות |
| `require()` מחזיר cache ישן | Luau מאחסן module בזיכרון לאחר טעינה ראשונה | בניית מודלים עם data hardcoded, לא require |
| BearManager כפול (13k תווים) | multi_edit כתב פעמיים | נחתך לאחר הסוף הראשון |
| BearHUD כפול (23k תווים) | אותה בעיה | נחתך לאחר הסוף הראשון |
| DataStore שגיאות בStudio | Studio API access לא מופעל | להפעיל: Game Settings → Security → Enable Studio Access to API Services |
| SSS ריק ב-Play Mode | בעיה עם MCP execute_luau בPlay | script רץ כ-ModuleScript — נפתר |
| `BrainrotModels` לא קיים ב-ServerStorage בPlay | SS לא מועתק ל-Play | BearManager בונה מודלים דינמית בזמן ריצה |

---

## מצב נוכחי (עובד ✅)
- **BrainrotManager v1** — loaded OK בPlay
- **שחקן מקבל Brainrot** — מופיע ב-Workspace עם מודל מלא
- **BillboardGui** — שם + rarity מוצגים מעל הדמות
- **Leaderstats** — Coins + Brainrots
- **Admin ID** 5647716264 — `/coins` ו-`/addbrain` עובדים

---

## אפשרויות פיתוח עתידיות

### גיימפליי
- [ ] מסלול ריצה/הליכה לברינרוט (follow path)
- [ ] מיני-גיים להאכלה (לחיצת מקש בזמן)
- [ ] Egg hatching — קנה ביצה וגלה איזה ברינרוט יצא (גאצ'ה)
- [ ] Breeding — שני ברינרוטים → ברינרוט חדש
- [ ] Quests / Daily Challenges
- [ ] Trading בין שחקנים

### עיצוב
- [ ] Particle effects לפי Rarity (ניצוצות לLegendary, אש לSecret וכו')
- [ ] אנימציות ייחודיות לכל Rarity
- [ ] Sound effects — צלילים שונים לכל רמה
- [ ] מפה גדולה יותר עם אזורים לפי Rarity
- [ ] מודלים מפורטים יותר (meshes אמיתיים)

### מערכות
- [ ] Leaderboard גלובלי
- [ ] Rebirth system — אפס והתחל מחדש עם bonus
- [ ] Pet inventory עם יותר מ-slot אחד גלוי
- [ ] Game Pass — x2 גידול, slot נוסף, אוכל חינם

---

## קבצים מרכזיים
| קובץ | תפקיד |
|---|---|
| `src/ReplicatedStorage/BearTiers.lua` | 15 רמות ברינרוט |
| `src/ServerScriptService/BearManager.lua` | כל לוגיקת השרת |
| `src/StarterPlayerScripts/BearHUD.client.lua` | ממשק שחקן |
| `src/StarterPlayerScripts/ShopClient.client.lua` | חנות (ישנה, לא בשימוש) |
| `src/ServerScriptService/ShopServer.server.lua` | חנות שרת (ישנה, מושבתת) |

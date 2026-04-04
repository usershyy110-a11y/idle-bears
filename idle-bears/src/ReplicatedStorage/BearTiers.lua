-- ================================================
-- BearTiers: 15 bear tiers
-- Pricing: x3 each tier, last 2 tiers x5
-- Base: 10 → 30 → 90 → 270 → 810 → 2430 → 7290 → 21870 → 65610 → 196830
--       → 590490 → 1771470 → 5314410 → x5→26572050 → x5→132860250
-- ================================================
return {
    {id="t1",  name="Tiny Cub",       minAge=0,   sellPrice=10,        emoji="🐻",
     bodyColor=Color3.fromRGB(255,230,180), headColor=Color3.fromRGB(245,215,160), eyeColor=Color3.fromRGB(40,20,10),    desc="A newborn cub."},
    {id="t2",  name="Fluffy Cub",     minAge=10,  sellPrice=30,        emoji="🐻",
     bodyColor=Color3.fromRGB(240,200,130), headColor=Color3.fromRGB(225,185,110), eyeColor=Color3.fromRGB(50,25,10),    desc="Getting fluffier!"},
    {id="t3",  name="Young Bear",     minAge=20,  sellPrice=90,        emoji="🐻",
     bodyColor=Color3.fromRGB(210,160,80),  headColor=Color3.fromRGB(195,145,65),  eyeColor=Color3.fromRGB(60,30,10),    desc="Growing up fast."},
    {id="t4",  name="Brown Bear",     minAge=30,  sellPrice=270,       emoji="🐻",
     bodyColor=Color3.fromRGB(165,100,40),  headColor=Color3.fromRGB(145,85,30),   eyeColor=Color3.fromRGB(30,15,5),     desc="A solid brown bear."},
    {id="t5",  name="Forest Bear",    minAge=40,  sellPrice=810,       emoji="🌿🐻",
     bodyColor=Color3.fromRGB(100,65,25),   headColor=Color3.fromRGB(85,50,18),    eyeColor=Color3.fromRGB(180,120,40),  desc="One with the forest."},
    {id="t6",  name="Shadow Bear",    minAge=50,  sellPrice=2430,      emoji="🌑🐻",
     bodyColor=Color3.fromRGB(55,40,30),    headColor=Color3.fromRGB(45,30,20),    eyeColor=Color3.fromRGB(180,60,60),   desc="Dark and mysterious."},
    {id="t7",  name="Snow Bear",      minAge=60,  sellPrice=7290,      emoji="❄️🐻",
     bodyColor=Color3.fromRGB(220,235,255), headColor=Color3.fromRGB(200,220,255), eyeColor=Color3.fromRGB(80,160,255),  desc="Pure as snow."},
    {id="t8",  name="Ember Bear",     minAge=70,  sellPrice=21870,     emoji="🔥🐻",
     bodyColor=Color3.fromRGB(220,80,30),   headColor=Color3.fromRGB(200,60,20),   eyeColor=Color3.fromRGB(255,200,0),   desc="Burns with inner fire."},
    {id="t9",  name="Ocean Bear",     minAge=80,  sellPrice=65610,     emoji="🌊🐻",
     bodyColor=Color3.fromRGB(30,100,200),  headColor=Color3.fromRGB(20,80,180),   eyeColor=Color3.fromRGB(0,220,220),   desc="Deep as the ocean."},
    {id="t10", name="Thunder Bear",   minAge=90,  sellPrice=196830,    emoji="⚡🐻",
     bodyColor=Color3.fromRGB(80,50,180),   headColor=Color3.fromRGB(60,35,160),   eyeColor=Color3.fromRGB(200,100,255), desc="Crackling with lightning."},
    {id="t11", name="Crystal Bear",   minAge=100, sellPrice=590490,    emoji="💎🐻",
     bodyColor=Color3.fromRGB(180,240,255), headColor=Color3.fromRGB(160,225,255), eyeColor=Color3.fromRGB(0,255,200),   desc="Shimmers like crystal."},
    {id="t12", name="Inferno Bear",   minAge=115, sellPrice=1771470,   emoji="🌋🐻",
     bodyColor=Color3.fromRGB(255,50,0),    headColor=Color3.fromRGB(220,30,0),    eyeColor=Color3.fromRGB(255,255,0),   desc="Born in volcanic flame."},
    {id="t13", name="Void Bear",      minAge=130, sellPrice=5314410,   emoji="🌌🐻",
     bodyColor=Color3.fromRGB(15,5,30),     headColor=Color3.fromRGB(10,0,20),     eyeColor=Color3.fromRGB(180,0,255),   desc="From the void between stars."},
    {id="t14", name="Celestial Bear", minAge=150, sellPrice=26572050,  emoji="🌟🐻",
     bodyColor=Color3.fromRGB(255,220,100), headColor=Color3.fromRGB(255,200,50),  eyeColor=Color3.fromRGB(255,255,255), desc="Blessed by the stars."},
    {id="t15", name="Eternal Bear",   minAge=180, sellPrice=132860250, emoji="👑🐻",
     bodyColor=Color3.fromRGB(255,255,255), headColor=Color3.fromRGB(240,240,255), eyeColor=Color3.fromRGB(255,180,0),   desc="The ultimate bear. Eternal glory."},
}

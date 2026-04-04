-- ================================================
-- BearTiers: all bear types, requirements & shop prices
-- ================================================
return {
    { id="cub",    name="Baby Cub",    minAge=0,   sellPrice=10,   foodCost=5,  emoji="🐻",
      bodyColor=Color3.fromRGB(255,220,150), headColor=Color3.fromRGB(255,210,130), eyeColor=Color3.fromRGB(40,25,10),
      desc="A tiny newborn cub." },
    { id="young",  name="Young Bear",  minAge=20,  sellPrice=35,   foodCost=10, emoji="🐻",
      bodyColor=Color3.fromRGB(200,140,70),  headColor=Color3.fromRGB(190,130,60),  eyeColor=Color3.fromRGB(30,18,8),
      desc="Growing fast!" },
    { id="adult",  name="Adult Bear",  minAge=50,  sellPrice=100,  foodCost=20, emoji="🐻",
      bodyColor=Color3.fromRGB(140,85,35),   headColor=Color3.fromRGB(120,70,25),   eyeColor=Color3.fromRGB(20,10,4),
      desc="A strong adult bear." },
    { id="elder",  name="Elder Bear",  minAge=80,  sellPrice=250,  foodCost=40, emoji="✨🐻",
      bodyColor=Color3.fromRGB(80,50,20),    headColor=Color3.fromRGB(65,40,15),    eyeColor=Color3.fromRGB(200,180,120),
      desc="Ancient and wise. Very valuable!" },
    { id="golden", name="Golden Bear", minAge=100, sellPrice=1000, foodCost=0,  emoji="🌟🐻",
      bodyColor=Color3.fromRGB(255,200,0),   headColor=Color3.fromRGB(255,180,0),   eyeColor=Color3.fromRGB(255,100,0),
      desc="Legendary. Worth a fortune!" },
}

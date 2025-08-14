Config = {}

Config.RequiredJob = "miner"
Config.RequiredItem = "pickaxe"

Config.MiningCooldown = 5000 
Config.PickaxeDurability = 20 
Config.PickaxeBreakChance = 0.05 

Config.MiningTime = {
    min = 8000,
    max = 15000
}

Config.MiningZones = {
    {
        name = "Quarry Mining Site",
        coords = vector3(2944.91, 2746.21, 43.5),
        radius = 100.0,
        blip = {
            sprite = 618,
            color = 5,
            scale = 0.8,
            label = "Mining Site"
        }
    },
    {
        name = "Desert Mining Area",
        coords = vector3(2580.0, 2722.0, 42.0),
        radius = 80.0,
        blip = {
            sprite = 618,
            color = 5,
            scale = 0.8,
            label = "Mining Site"
        }
    }
}

Config.RockLocations = {
    -- Quarry rocks
    {coords = vector3(2951.2, 2749.8, 43.7-1.5), heading = 45.0, model = "prop_rock_4_big2"},
    {coords = vector3(2938.5, 2751.2, 44.1), heading = 120.0, model = "prop_rock_4_big"},
    {coords = vector3(2955.8, 2735.6, 42.9), heading = 200.0, model = "prop_rock_4_big2"},
    {coords = vector3(2943.1, 2742.3, 43.2), heading = 315.0, model = "prop_rock_4_big"},
    {coords = vector3(2960.2, 2758.4, 44.5), heading = 90.0, model = "prop_rock_4_big2"},
    
    -- Desert rocks
    {coords = vector3(2575.3, 2718.9, 42.1), heading = 60.0, model = "prop_rock_4_big"},
    {coords = vector3(2582.7, 2725.4, 42.3), heading = 180.0, model = "prop_rock_4_big2"},
    {coords = vector3(2587.1, 2712.8, 41.8), heading = 270.0, model = "prop_rock_4_big"},
    {coords = vector3(2571.9, 2728.2, 42.5), heading = 30.0, model = "prop_rock_4_big2"}
}

Config.MiningRewards = {
    {item = "stone", chance = 40, min = 1, max = 3},
    {item = "iron_ore", chance = 25, min = 1, max = 2},
    {item = "copper_ore", chance = 20, min = 1, max = 2},
    {item = "coal", chance = 30, min = 2, max = 4},
    {item = "gold_ore", chance = 8, min = 1, max = 1},
    {item = "diamond", chance = 2, min = 1, max = 1}
}

Config.SellLocation = {
    coords = vector3(2947.52, 2749.93, 43.58-0.20),
    heading = 180.0,
    blip = {
        sprite = 605,
        color = 2,
        scale = 0.8,
        label = "Mining Buyer"
    },
    ped = {
        model = "s_m_y_construct_01",
        scenario = "WORLD_HUMAN_CLIPBOARD"
    }
}

Config.SellPrices = {
    ["stone"] = {min = 5, max = 8},
    ["iron_ore"] = {min = 12, max = 18},
    ["copper_ore"] = {min = 10, max = 15},
    ["coal"] = {min = 3, max = 6},
    ["gold_ore"] = {min = 25, max = 35},
    ["diamond"] = {min = 50, max = 75}
}
Config = {}

Config.Framework = "qbcore" -- qbcore/qbox
Config.Notify = 'ox' -- ox/qbcore

Config.DefaultGroupLimit = 4

Config.LocalStates = { -- nghe states for each job type that is currently set up
    ngheTaco = "taco",
    ngheHouserobbery = "houserobbery",
    ngheSanitation = "sani",
    ngheFishing = "fishing",
    nghePostop = "postop",
    ngheLumberjack = "lumberjack",
    ngheRecycle = "recycle",
    ngheGoldpan = "goldpan",
    ngheCokeruns = "cokeruns",
    ngheChickens = "chickens",
    ngheDiving = "diving",
    ngheHunting = "hunting",
    ngheOxyruns = "oxyruns",
}

Config.JobPlayerLimits = { -- Max players per job
    taco = 6,
    houserobbery = 12,
    sani = 16,
    fishing = 16,
    postop = 16,
    lumberjack = 16,
    recycle = 16,
    goldpan = 16,
    cokeruns = 16,
    chickens = 16,
    diving = 16,
    hunting = 16,
    oxyruns = 16,
}

Config.GroupPlayerLimits = { -- Max amount of player per group
    taco = 2,
    houserobbery = 2,
    sani = 4,
    fishing = 4,
    postop = 4,
    lumberjack = 4,
    recycle = 4,
    goldpan = 4,
    cokeruns = 4,
    chickens = 4,
    diving = 4,
    hunting = 4,
    oxyruns = 4,
}

Config.JobCooldowns = { -- Cooldowns between finishing a job and getting put back in the queue for a new one
    cokeruns = 7200, -- 120 mins
    taco = 1800, -- 30 min
    houserobbery = 900, -- 15 min
    oxyruns = 600, -- 10 mins
    diving = 600, -- 10 mins

    sani = 600, -- 10 mins
    fishing = 600, -- 10 mins
    postop = 600, -- 10 mins
    hunting = 600, -- 10 mins
    lumberjack = 600, -- 10 mins

    recycle = 300, -- 5 mins
    goldpan = 300, -- 5 mins
    chickens = 300, -- 5 mins
}
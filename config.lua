Config = {}

Config.DefaultGroupLimit = 4

Config.LocalStates = { -- nghe states for each job type that is currently set up
    ngheTaco = "taco",
    ngheHouserobbery = "houserobbery",
    ngheSanitation = "sani",
    ngheFishing = "fishing",
    nghePostop = "postop",
}

Config.JobPlayerLimits = { -- Max players per job
    taco = 6,
    houserobbery = 12,
    sanitation = 16,
    fishing = 16,
    postop = 16,
}

Config.GroupPlayerLimits = { -- Max amount of player per group
    taco = 2,
    houserobbery = 2,
    sanitation = 4,
    fishing = 4,
    postop = 4,
}

Config.JobCooldowns = { -- Cooldowns between finishing a job and getting put back in the queue for a new one
    taco = 1800, -- 30 min
    houserobbery = 900, -- 15 min
    sanitation = 600, -- 10 mins
    fishing = 600, -- 10 mins
    postop = 600, -- 10 mins
}
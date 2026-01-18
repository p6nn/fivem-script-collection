Config = {}

Config.MethTable = {
    item = 'meth_table',
    model = `bkr_prop_meth_table01a`,
    label = 'Meth Cooking Table',
    weight = 5000
}

Config.CookingSteps = {
    {
        id = 'step1',
        label = 'Add Pseudoephedrine',
        description = 'Add pseudoephedrine to start the cooking process',
        requiredItem = 'pseudoephedrine',
        requiredAmount = 2,
        duration = 5000,
        waitAfter = 1000,
        progressLabel = 'Adding Pseudoephedrine...',
        animation = {
            dict = 'mini@repair',
            anim = 'fixing_a_ped'
        }
    },
    {
        id = 'step2',
        label = 'Add Lithium',
        description = 'Add lithium to continue the process',
        requiredItem = 'lithium',
        requiredAmount = 1,
        duration = 8000,
        waitAfter = 1000,
        progressLabel = 'Adding Lithium...',
        animation = {
            dict = 'mini@repair',
            anim = 'fixing_a_ped'
        }
    },
    {
        id = 'step3',
        label = 'Add Muriatic Acid',
        description = 'Add muriatic acid to complete the cook',
        requiredItem = 'muriatic_acid',
        requiredAmount = 1,
        duration = 10000,
        waitAfter = 1000,
        progressLabel = 'Adding Muriatic Acid...',
        animation = {
            dict = 'mini@repair',
            anim = 'fixing_a_ped'
        }
    },
    {
        id = 'step4',
        label = 'Collect Product',
        description = 'Collect the finished meth',
        requiredItem = nil,
        requiredAmount = 0,
        duration = 3000,
        waitAfter = 0,
        progressLabel = 'Collecting Product...',
        reward = {
            item = 'meth',
            minAmount = 3,
            maxAmount = 6
        },
        animation = {
            dict = 'mp_common',
            anim = 'givetake1_a'
        }
    }
}

Config.Debug = false

Config.Refund = {
    enabled = true,
    percentage = 0.5
}

Config.StepWait = {
    enabled = true,
    useIndividualTimes = true,
    defaultDuration = 30000
}

Config.MethQuality = {
    enabled = true,
    qualities = {
        {name = "Poor", chance = 25, multiplier = 0.8, purity = 60, color = "red"},
        {name = "Average", chance = 40, multiplier = 1.0, purity = 75, color = "yellow"},
        {name = "Good", chance = 25, multiplier = 1.2, purity = 85, color = "green"},
        {name = "Excellent", chance = 8, multiplier = 1.5, purity = 95, color = "blue"},
        {name = "Pure", chance = 2, multiplier = 2.0, purity = 99, color = "purple"}
    }
}
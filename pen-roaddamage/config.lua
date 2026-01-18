return {
    sampleIntervalMs = 1250,
    reportIntervalMs = 6000,
    syncIntervalMs = 5000,

    minSpeedToCount = 6.0,

    damagePerMeter = 0.00045,
    damageDecayPerMinute = 0.18,

    saveIntervalMs = 60000,

    limits = {
        maxMetersPerReport = 1200.0,
        maxStreetKey = 2147483647,
    },

    tirePop = {
        enabled = true,
        minDamage = 35,
        maxDamage = 100,
        baseChancePerSampleAtMax = 0.015,
        burstDamage = 1000.0,
        onlyDriver = true,
        disableIfBulletproof = true,
    }
}

-- Copyright (c) 2026 Karl Schmidt
--[[
    MobHealthCache

    Since UnitHealthMax is secret, we cannot access fresh mob health in combat.
    This cache estimates and stores mob health for use by EstimateTargetMaxHealth().
    Estimates are derived from damage meter segments matched to recently targeted mobs.

    Health estimates are cached by creature level and creature ID, with per-level averages for each classification.
    We write to the cache after a combat session ends, using the damage meter output to estimate max health. Each cache
    entry stores a decaying average of recent samples.

    This is of debatable precision but it's the best I can do with what the secretvalue API allows.
--]]

local addon = LibStub("AceAddon-3.0"):GetAddon("Sundered")
local mobHealthCache = addon:NewModule("MobHealthCache", "AceEvent-3.0")
SunderedMobHealthCache = SunderedMobHealthCache or {}
local targetSnapshots = {}

-- Restore the cache branch if saved data is incomplete or was created by an older addon version.
local function ensureHealthCache()
    SunderedMobHealthCache.byLevelCreatureID = SunderedMobHealthCache.byLevelCreatureID or {}
end

-- Approximate maximum health for normal creatures by level.
local approximateMaxHealthByLevel = {
      44,   53,   64,   76,   89,  103,  119,  137,  156,  176,
     197,  219,  241,  264,  288,  290,  312,  338,  366,  397,
     430,  464,  501,  540,  581,  624,  669,  716,  765,  815,
     827,  830,  868,  915,  968, 1025, 1085, 1148, 1216, 1288,
    1363, 1444, 1529, 1619, 1714, 1835, 1962, 2095, 2234, 2367,
    2507, 2654, 2808, 2971, 3141, 3321, 3510, 3709, 3918, 4137,
    4367, 4609, 4863,
}

-- Health scaling estimate for elites, rares, etc. Not very accurate.
local approximateHealthMultiplierByClassification = {
    normal = 1,
    trivial = 1,
    minus = 0.5,
    rare = 1.5,
    elite = 2,
    rareelite = 3,
    worldboss = 1000,
}

-- Update a cached health value with a new health sample.
local function updateAverage(cache, key, sample)
    -- Blend repeated estimates to smooth out overkill and damage-meter variation.
    local average = cache[key]
    if average then
        -- The smaller the value, the less the new sample will affect the average.
        local healthEstimateSmoothing = 0.05
        average = average * (1 - healthEstimateSmoothing) + sample * healthEstimateSmoothing
    else
        average = sample
    end
    cache[key] = average
end

-- Make a nested cache branch available.
local function getCacheTable(cache, key)
    local value = cache[key]
    if not value then
        value = {}
        cache[key] = value
    end
    return value
end

local function updateHealthCache(cache, level, creatureID, classification, sample)
    local levelCache = getCacheTable(
        getCacheTable(cache, "byLevelCreatureID"),
        level
    )
    updateAverage(levelCache, creatureID, sample)
    updateAverage(levelCache, classification, sample)
end

ensureHealthCache()

-- Rough overkill estimates for a level-appropriate green 1H weapon.
local overkillDamageByLevel = {
     5,   7,   8,   9,  11,  12,  14,  16,  17,  20,
    22,  24,  27,  29,  32,  35,  37,  40,  43,  46,
    50,  53,  56,  60,  65,  68,  72,  76,  81,  85,
    90,  96, 101, 106, 111, 118, 123, 130, 135, 141,
   146, 151, 156, 161, 166, 171, 176, 181, 186, 190,
   196, 200, 205, 210, 215, 220, 225, 230, 234, 240,
}

local function estimateOverkillDamage(level)
    return overkillDamageByLevel[level] or 0
end

-- Called on player target changing. Attempt to snapshot any target data that will be secret in combat for later use.
local function captureTargetSnapshot()
    -- Don't bother if the target isn't a mob.
    if UnitAffectingCombat("player") or not UnitExists("target")
        or UnitIsPlayer("target") or UnitPlayerControlled("target")
    then
        return
    end

    local creatureID = scrubsecretvalues(UnitCreatureID("target"))
    local level = UnitLevel("target")
    if not creatureID or creatureID <= 0 or level <= 0 then
        return
    end

    local levels = getCacheTable(targetSnapshots, creatureID)
    levels[level] = true
end

-- Estimate mob health from a completed Damage Meter session and update the cache.
local function cacheCombatSession(combatSession)
    if not combatSession then
        return
    end

    local combatSources = scrubsecretvalues(combatSession.combatSources)
    if not combatSources then
        return
    end

    -- There were multiple mob types involved. We cannot get a reliable damage estimate for a single mob, so abort.
    if #combatSources ~= 1 then
        targetSnapshots = {}
        return
    end

    -- Get the data for the one type we killed. If it's not secret then combat is over and we can continue.
    local source = combatSources[1]
    local creatureID = scrubsecretvalues(source.sourceCreatureID)
    local classification = scrubsecretvalues(source.classification)
    if not creatureID or not classification then
        return
    end

    -- Matching snapshots at multiple levels make the damage-meter estimate ambiguous.
    local levels = targetSnapshots[creatureID]
    local level
    local ambiguous = false
    if levels then
        for snapshotLevel in pairs(levels) do
            if level then
                ambiguous = true
                break
            end
            level = snapshotLevel
        end
    end

    local estimate = scrubsecretvalues(combatSession.totalAmount)

    if estimate and estimate > 0 then
        -- Reduce the health estimate by an estimate of our overkill damage to reflect expected max health.
        estimate = estimate - estimateOverkillDamage(UnitLevel("Player"))

        -- Update the matching level/creature entry when the sample can be attributed unambiguously.
        if level and not ambiguous and estimate > 0 then
            updateHealthCache(
                SunderedMobHealthCache, level, creatureID, classification, estimate
            )
        end
    end

    -- Discard target snapshots for this mob type for future use.
    targetSnapshots[creatureID] = nil
end

-- Grab the damage taken session from the in-game damage meter and send it to the cache update function.
local function readCombatSession(sessionID)
    local isAvailable = C_DamageMeter.IsDamageMeterAvailable()
    if not isAvailable then
        return
    end

    local damageMeterType = Enum.DamageMeterType.EnemyDamageTaken
    local combatSession
    if sessionID then
        combatSession = C_DamageMeter.GetCombatSessionFromID(sessionID, damageMeterType)
    else
        local currentSession = Enum.DamageMeterSessionType.Current
        combatSession = C_DamageMeter.GetCombatSessionFromType(currentSession, damageMeterType)
    end

    cacheCombatSession(combatSession)
end

-- Handler for the PLAYER_TARGET_CHANGED and PLAYER_ENTERING_WORLD event
function mobHealthCache:OnPlayerTargetChanged()
    captureTargetSnapshot()
end

-- Handler for the DAMAGE_METER_COMBAT_SESSION_UPDATED event.
-- I am unsure if this is actually needed, since we read the data on combat end.
function mobHealthCache:OnDamageMeterCombatSessionUpdated(event, damageMeterType, sessionID)
    if damageMeterType ~= Enum.DamageMeterType.EnemyDamageTaken or sessionID == 0 then
        return
    end

    readCombatSession(sessionID)
end

-- Handler for the PLAYER_REGEN_ENABLED. This indicates combat has ended.
function mobHealthCache:OnPlayerRegenEnabled()
    readCombatSession()
end

-- Starts listening for combat meter updates and combat end.
function mobHealthCache:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnPlayerTargetChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerTargetChanged")
    self:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", "OnDamageMeterCombatSessionUpdated")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
    captureTargetSnapshot()
end

-- Stops listening for combat meter updates and combat end.
function mobHealthCache:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

-- Estimates target maximum health from its level and creature ID.
function mobHealthCache:EstimateTargetMaxHealth()
    local level = UnitLevel("target")
    local classification = UnitClassification("target")
    local creatureID = scrubsecretvalues(UnitCreatureID("target"))

    -- Try the most accurate cache: creatureID and level.
    local cachedHP
    if creatureID then
        local levelCache = SunderedMobHealthCache.byLevelCreatureID[level]
        cachedHP = levelCache and levelCache[creatureID]
    end
    if cachedHP then
        return cachedHP
    end

    -- Fall back to the level and classification cache.
    level = math.max(1, math.min(level, 63))
    local levelCache = SunderedMobHealthCache.byLevelCreatureID[level]
    cachedHP = levelCache and levelCache[classification]
    if cachedHP then
        return cachedHP
    end

    -- Fall back to the level cache. For non-normal creatures, try scaling up the normal level cache.
    cachedHP = levelCache and levelCache.normal
    if not cachedHP then
        cachedHP = approximateMaxHealthByLevel[level]
    end
    local multiplier = approximateHealthMultiplierByClassification[classification]
    return cachedHP * multiplier
end

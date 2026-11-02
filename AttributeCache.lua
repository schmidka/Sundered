-- Copyright (c) 2026 Karl Schmidt
--[[
    AttributeCache

    Samples player combat attributes at the end of combat and caches them. This allows them to be retreived in combat,
    when they will be stale but not secret. The cache uses an exponential decaying average of the last few samples of
    each attribute. The hope is that this will be a reasonable estimator for the average in-combat attribute.

    Currently this never returns the exact, current values even when they are not secret. This is by design:
    representing the expected average is preferable.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local AttributeCache = Addon:NewModule("AttributeCache", "AceEvent-3.0")

-- Exponential decay smoothing. The higher the smoothing the faster the decay. No, I don't know why ol' Slopsy did it
-- that way either.
local smoothing = 0.2

-- Outlier threshold. If the current value and cache value differs by this ratio then the cache will be overwritten.
local outlierThreshold = 0.5

-- Accepts both the current numeric cache format and an older average wrapper.
local function normalizeSavedAverage(value)
    if type(value) == "table" then
        return value.average
    end

    return value
end

-- Incorporates a public sample into its saved moving average.
local function updateAverage(stats, key, sample)
    if not sample then
        return
    end

    local average = stats[key]
    if not average then
        stats[key] = sample
        return
    end

    -- Replace large changes directly, to avoid stale outliers living on.
    if sample < average / (1 + outlierThreshold) or
       sample > average * (1 + outlierThreshold)
    then
        stats[key] = sample
        return
    end

    stats[key] = average * (1 - smoothing) + sample * smoothing
end

-- Reads player attributes from Blizzard APIs. Returns nil if the results are secret.
local function currentAttackPower()
    local base, positiveBuffs, negativeBuffs = scrubsecretvalues(UnitAttackPower("player"))
    if not base or not positiveBuffs or not negativeBuffs then
        return nil
    end

    return base + positiveBuffs + negativeBuffs
end

local function currentWeaponDamage()
    local minDamage, maxDamage, minOffHandDamage, maxOffHandDamage = scrubsecretvalues(UnitDamage("player"))
    if not minDamage or not maxDamage or not minOffHandDamage or not maxOffHandDamage
    then
        return nil, nil
    end

    return (minDamage + maxDamage) / 2, (minOffHandDamage + maxOffHandDamage) / 2
end

local function currentCritChance()
    return scrubsecretvalues(GetCritChance())
end

-- Reads the player's melee hit bonus for the attack estimates.
local function currentHitChance()
    local hitRatingBonus, hitModifier = scrubsecretvalues(
        GetCombatRatingBonus(CR_HIT_MELEE), GetHitModifier()
    )
    if not hitRatingBonus or not hitModifier then
        return nil
    end

    return hitRatingBonus + hitModifier
end

-- Reads the main-hand speed used by the white-swing Rage estimate.
local function currentMainHandSpeed()
    return scrubsecretvalues(UnitAttackSpeed("player"))
end

local function currentShieldBlock()
    return scrubsecretvalues(GetShieldBlock())
end

-- Initializes the saved cache and starts listening for stat sampling events.
function AttributeCache:OnEnable()
    SundererAbilityCache = SundererAbilityCache or {}
    self.database = SundererAbilityCache
    self.loadedCharacters = {}

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Capture")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Capture")
end

-- Stops listening for stat sampling events.
function AttributeCache:OnDisable()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

-- Returns the saved stat cache for the current character.
function AttributeCache:GetCharacterStats()
    -- Key each character independently so its samples are reused on later logins.
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then
        return nil
    end

    local characterKey = realm .. "-" .. name
    local characterStats = self.database[characterKey] or {}
    self.database[characterKey] = characterStats

    if not self.loadedCharacters[characterKey] then
        -- Normalize saved values once when this character's cache is first opened.
        characterStats.attackPower = normalizeSavedAverage(characterStats.attackPower)
        characterStats.averageMainHandDamage = normalizeSavedAverage(characterStats.averageMainHandDamage)
        characterStats.averageOffHandDamage = normalizeSavedAverage(characterStats.averageOffHandDamage)
        characterStats.critChance = normalizeSavedAverage(characterStats.critChance)
        characterStats.hitChance = normalizeSavedAverage(characterStats.hitChance)
        characterStats.mainHandSpeed = normalizeSavedAverage(characterStats.mainHandSpeed)
        characterStats.shieldBlock = normalizeSavedAverage(characterStats.shieldBlock)
        self.loadedCharacters[characterKey] = true
    end

    return characterStats
end

-- Samples current player stats and updates their cached averages.
function AttributeCache:Capture()
    local stats = self:GetCharacterStats()
    if not stats then
        return
    end

    -- Capture each attribute separately so a secret result leaves its existing sample untouched.
    updateAverage(stats, "attackPower", currentAttackPower())
    local mainHandDamage, offHandDamage = currentWeaponDamage()
    updateAverage(stats, "averageMainHandDamage", mainHandDamage)
    updateAverage(stats, "averageOffHandDamage", offHandDamage)
    updateAverage(stats, "critChance", currentCritChance())
    updateAverage(stats, "hitChance", currentHitChance())
    updateAverage(stats, "mainHandSpeed", currentMainHandSpeed())
    updateAverage(stats, "shieldBlock", currentShieldBlock())
end

-- Returns the cached average Attack Power, or zero when it is unavailable.
function AttributeCache:GetAttackPower()
    return self:GetCharacterStats().attackPower or 0
end

-- Returns the cached average main-hand damage, or zero when unavailable.
function AttributeCache:GetAverageMainHandDamage()
    return self:GetCharacterStats().averageMainHandDamage or 0
end

-- Returns the cached average off-hand damage, or zero when unavailable.
function AttributeCache:GetAverageOffHandDamage()
    return self:GetCharacterStats().averageOffHandDamage or 0
end

-- Returns the cached average Crit Chance, or zero when it is unavailable.
function AttributeCache:GetCritChance()
    return self:GetCharacterStats().critChance or 0
end

-- Returns the cached average melee hit bonus, or zero when unavailable.
function AttributeCache:GetHitChance()
    return self:GetCharacterStats().hitChance or 0
end

-- Provides the assumed Classic weapon skill for attack estimates.
function AttributeCache:GetWeaponSkill()
    return UnitLevel("player") * 5
end

-- Returns the cached average main-hand weapon speed, or zero when unavailable.
function AttributeCache:GetMainHandSpeed()
    return self:GetCharacterStats().mainHandSpeed or 0
end

-- Returns the cached average Shield Block value, or zero when unavailable.
function AttributeCache:GetShieldBlock()
    return self:GetCharacterStats().shieldBlock or 0
end

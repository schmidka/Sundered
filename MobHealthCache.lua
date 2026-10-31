--[[ 
    MobHealthCache

    Since UnitHealthMax is secret if called in combat we may not always be able to access fresh data for mob health.
    The objective of this cache is to store the observed max health values of targeted mobs for nonsecret access in
    combat. The primary function is EstimateTargetMaxHealth, which is how other parts of the addon are expected to get
    health values for targets.
    
    Cached health values are indexed by the tuple (zone, level, classification). For example, the health of a Mo'grosh
    Ogre may be stored under the tuple ("Dun Morogh", 18, elite). We do not use UnitName, as it is secret in combat.
    
    It may be possible to refine the cache by using subzones and other identifying information like UnitPowerType.
--]]

local addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local mobHealthCache = addon:NewModule("MobHealthCache", "AceEvent-3.0")

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

-- Scales the level estimate for each UnitClassification result.
local approximateHealthMultiplierByClassification = {
    normal = 1,
    trivial = 1,
    minus = 0.5,
    rare = 1.3,
    elite = 1.3,
    rareelite = 3,
    worldboss = 1000,
}

-- Stores observed health by zone, level, and classification.
SundererMobHealthCache = SundererMobHealthCache or {}

-- Saves public health observations for eligible targets.
local function captureTargetHealth()
    -- Exclude players and player-controlled units from creature observations.
    if not UnitExists("target") or UnitIsPlayer("target") or UnitPlayerControlled("target") then
        return
    end

    -- Secret health cannot be persisted; public health is stored under its target tuple.
    local maxHealth = UnitHealthMax("target")
    if issecretvalue(maxHealth) then
        return
    end

    local zone = GetRealZoneText()
    local level = UnitLevel("target")
    local classification = UnitClassification("target")
    local zoneCache = SundererMobHealthCache[zone]
    if not zoneCache then
        zoneCache = {}
        SundererMobHealthCache[zone] = zoneCache
    end

    local levelCache = zoneCache[level]
    if not levelCache then
        levelCache = {}
        zoneCache[level] = levelCache
    end

    levelCache[classification] = maxHealth
end

-- Starts collecting health observations when targets change and combat ends.
function mobHealthCache:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", captureTargetHealth)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", captureTargetHealth)
end

-- Stops collecting health observations while the module is disabled.
function mobHealthCache:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

-- Estimates target maximum health
function mobHealthCache:EstimateTargetMaxHealth()
    -- Prefer the exact current value whenever it isn't secret.
    local maxHealth = UnitHealthMax("target")
    if not issecretvalue(maxHealth) then
        return maxHealth
    end

    -- Reuse the cached value, if it exists
    local zoneCache = SundererMobHealthCache[GetRealZoneText()]
    local levelCache = zoneCache and zoneCache[UnitLevel("target")]
    local cachedHealth = levelCache and levelCache[UnitClassification("target")]
    if cachedHealth then
        return cachedHealth
    end

    -- No hit in the cache. Use a rough estimate based on a table of typical mob health values, with a multiplier for
    -- elites and bosses.
    local level = math.max(1, math.min(UnitLevel("target"), 63))
    local classification = UnitClassification("target")
    local baseHealth = approximateMaxHealthByLevel[level]
    local multiplier = approximateHealthMultiplierByClassification[classification]
    return baseHealth * multiplier
end

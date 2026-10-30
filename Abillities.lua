-- Helper functions for classic combat ability math. Handles estimations for mob HP and armor, as
-- well math for specific abilities (such as, unsurprisingly, Sunder Armor).

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Abilities = Addon:NewModule("Abilities")
local AttributeCache = Addon:GetModule("AttributeCache")

local function GetOption(key)
    return Addon:GetModule("Options"):GetOption(key)
end

--[[
    A brief overview of mob classes and armor in classic:

    There are generally 4 classes for mobs: warrior, rogue, paladin and mage.

    Warriors and Rogues have the same armor and the highest values.
    Paladins are the most common and have middle values.
    Mages have the lowest armor.
    
    Armor is provided in exact lookups, and should be accurate ... if we know
    the type. Unfortunately, we don't. Functions will simply guess paladin for
    now.

    Some bosses have armor values that break this, but Sunderer primarily
    cares about leveling and normal mobs, not instanced content. The Sunder
    yes/no decision is always going to be yes against Sulfuron, so I am not
    worried about handling them.
    
    Health is definitely not exact. Secrecy prevents us from using
    UnitHealthMax. We have to hardcode some guesses. This is a sloppily
    generated table of approximate base health for a typical mob at each
    level. I have done some manual verification and the AI seems to have done
    a reasonable job, but by its nature these are rough numbers. Mage mobs
    will have 30% less, high HP mobs like bears will have 20% more, give or
    take.

    Finally, I believe Forever increases these values much like SoD did, since damage is higher.

    In conclusion:
    - All these tables are wrong.
    - Expect all these tables to be updated.
    - We need to make guesses for Sunderer to work.
--]]


local mageArmorByLevel = {
      10,   11,   24,   42,   65,   93,  126,  166,  212,  267,
     286,  305,  325,  344,  363,  385,  404,  423,  442,  461,
     480,  499,  518,  537,  556,  575,  594,  613,  632,  658,
     676,  694,  712,  730,  748,  802,  858,  915,  974, 1036,
    1100, 1167, 1235, 1305, 1378, 1406, 1434, 1462, 1490, 1518,
    1546, 1574, 1602, 1630, 1658, 1686, 1714, 1742, 1770, 1798,
    1826, 1854, 1882,
}

local paladinArmorByLevel = {
      17,   18,   38,   68,  105,  150,  205,  268,  342,  426,
     450,  479,  508,  537,  566,  596,  625,  653,  684,  712,
     741,  771,  800,  829,  858,  887,  917,  946,  975, 1004,
    1033, 1063, 1092, 1121, 1151, 1234, 1325, 1418, 1517, 1619,
    1728, 1841, 1958, 2082, 2211, 2255, 2300, 2344, 2388, 2433,
    2477, 2522, 2566, 2610, 2654, 2699, 2743, 2788, 2832, 2876,
    2921, 2965, 3009,
}

local warriorArmorByLevel = {
      20,   21,   46,   82,  126,  180,  245,  322,  412,  518,
     545,  580,  615,  650,  685,  721,  756,  791,  826,  861,
     897,  932,  967, 1002, 1037, 1072, 1108, 1142, 1172, 1212,
    1247, 1283, 1317, 1353, 1387, 1494, 1607, 1724, 1849, 1980,
    2117, 2262, 2414, 2574, 2742, 2798, 2853, 2907, 2963, 3018,
    3072, 3128, 3183, 3237, 3292, 3348, 3402, 3457, 3512, 3566,
    3622, 3677, 3731,
}

-- As mentioned, these values are definitely not great but they're probably better than nothing.
local baseHealthByLevel = {
      44,   53,   64,   76,   89,  103,  119,  137,  156,  176,
     197,  219,  241,  264,  288,  290,  312,  338,  366,  397,
     430,  464,  501,  540,  581,  624,  669,  716,  765,  815,
     827,  830,  868,  915,  968, 1025, 1085, 1148, 1216, 1288,
    1363, 1444, 1529, 1619, 1714, 1835, 1962, 2095, 2234, 2367,
    2507, 2654, 2808, 2971, 3141, 3321, 3510, 3709, 3918, 4137,
    4367, 4609, 4863,
}

local sunderArmorByRank = {
    90, 180, 270, 360, 450,
}

local mortalStrikeBonusByRank = {
    85, 110, 135, 160,
}

local slamBonusByRank = {
    32, 43, 68, 87,
}

local shieldSlamBonusByRank = {
    225, 264, 303, 342,
}

local thunderClapDamageByRank = {
    10, 23, 37, 55, 82, 103,
}

local improvedThunderClapDamageByRank = {
    [0] = 0,
    0.4, 0.7, 1,
}

local improvedThunderClapRageReductionByRank = {
    0, 1, 2, 4,
}

local rageCosts = {
    SUNDER_ARMOR = 15,
    BLOODTHIRST = 30,
    MORTAL_STRIKE = 30,
    SLAM = 15,
    SHIELD_SLAM = 20,
    WHIRLWIND = 25,
    THUNDER_CLAP = 20,
}

function round(value) 
    return math.floor(value + 0.5)
end

function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- Assumes a successful hit and averages normal damage with double-damage crits.
local function applyExpectedCrit(damage)
    return damage * (1 + AttributeCache:GetCritChance() / 100)
end

-- Returns the estimated armor for a mob at the given level.
function Abilities:GetArmor(mobName, level)
    level = clamp(level, 1, 63)
    return paladinArmorByLevel[level]
end

-- Returns the estimated maximum health for a mob at the given level.
function Abilities:GetApproximateMaxHealth(mobName, level)
    level = clamp(level, 1, 63)
    return baseHealthByLevel[level]
end

-- Returns the armor reduction for a Sunder Armor rank.
function Abilities:GetSunderArmorValue(rank)
    rank = clamp(rank, 1, 5)
    return sunderArmorByRank[rank]
end

-- Estimates Bloodthirst damage from current attack power and critical strike chance.
function Abilities:ComputeExpectedBloodthirstEHPDamage()
    local attackPower = AttributeCache:GetAttackPower()
    return applyExpectedCrit(attackPower * 0.45)
end

-- Estimates Mortal Strike damage using the selected rank and current main-hand damage.
function Abilities:ComputeExpectedMortalStrikeEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return applyExpectedCrit(
        weaponDamage + mortalStrikeBonusByRank[rank]
    )
end

-- Estimates Slam damage using the selected rank and current main-hand damage.
function Abilities:ComputeExpectedSlamEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return applyExpectedCrit(weaponDamage + slamBonusByRank[rank])
end

-- Estimates Shield Slam damage using the selected rank and current shield block value.
function Abilities:ComputeExpectedShieldSlamEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    return applyExpectedCrit(GetShieldBlock() + shieldSlamBonusByRank[rank])
end

-- Estimates Whirlwind damage using cached main- and off-hand damage.
function Abilities:ComputeExpectedWhirlwindEHPDamage()
    local mainHandDamage = AttributeCache:GetAverageMainHandDamage()
    local offHandDamage = AttributeCache:GetAverageOffHandDamage()
    return applyExpectedCrit(mainHandDamage + offHandDamage)
end

-- Estimates Thunder Clap damage using its rank and Improved Thunder Clap talent.
function Abilities:ComputeExpectedThunderClapEHPDamage(rank, talentRank)
    rank = clamp(rank, 1, 6)
    talentRank = clamp(talentRank, 0, 3)
    local damage = thunderClapDamageByRank[rank]
        * (1 + improvedThunderClapDamageByRank[talentRank])
    return applyExpectedCrit(damage)
end

-- Estimates the selected comparison ability's EHP damage using its configured rank.
function Abilities:ComputeExpectedAbilityEHPDamage(ability)
    if ability == "BLOODTHIRST" then
        return self:ComputeExpectedBloodthirstEHPDamage()
    elseif ability == "MORTAL_STRIKE" then
        return self:ComputeExpectedMortalStrikeEHPDamage(
            GetOption("mortalStrikeRank")
        )
    elseif ability == "SLAM" then
        return self:ComputeExpectedSlamEHPDamage(GetOption("slamRank"))
    elseif ability == "SHIELD_SLAM" then
        return self:ComputeExpectedShieldSlamEHPDamage(
            GetOption("shieldSlamRank")
        )
    elseif ability == "WHIRLWIND" then
        return self:ComputeExpectedWhirlwindEHPDamage()
    elseif ability == "THUNDER_CLAP" then
        return self:ComputeExpectedThunderClapEHPDamage(
            GetOption("thunderClapRank"),
            GetOption("improvedThunderClapRank")
        )
    end
end

-- Returns an ability's base rage cost after configured talent reductions.
function Abilities:GetAbilityRageCost(ability)
    local rageCost = rageCosts[ability]
    if not rageCost then
        return nil
    end

    rageCost = rageCost - GetOption("focusedRageRank")
    if ability == "SUNDER_ARMOR" then
        rageCost = rageCost - GetOption("improvedSunderArmorRank")
    elseif ability == "THUNDER_CLAP" then
        rageCost = rageCost
            - improvedThunderClapRageReductionByRank[
                GetOption("improvedThunderClapRank") + 1
            ]
    end

    return math.max(0, rageCost)
end

-- Returns estimated EHP damage per rage for Sunder Armor or a direct ability.
function Abilities:ComputeExpectedAbilityEHPDamagePerRage(
    ability,
    attackerLevel,
    targetHitPoints,
    targetLevel
)
    local damage
    if ability == "SUNDER_ARMOR" then
        damage = self:ComputeSunderArmorEHPDamage(
            GetOption("sunderArmorRank"),
            attackerLevel,
            targetHitPoints,
            targetLevel
        )
    else
        damage = self:ComputeExpectedAbilityEHPDamage(ability)
    end

    return damage / self:GetAbilityRageCost(ability)
end

-- Calculates the fraction of damage prevented by armor.
function Abilities:ComputeMitigation(armor, attackerLevel)
    return armor / (85 * attackerLevel + 400 + armor)
end

-- Calculates effective HP for a given target and attacker.
function Abilities:ComputeEHP(hitPoints, armor, attackerLevel)
    return hitPoints + hitPoints * armor / (85 * attackerLevel + 400)
end

-- Calculates the effective HP damage from applying Sunder Armor.
function Abilities:ComputeSunderArmorEHPDamage(rank, attackerLevel, targetHitPoints, targetLevel)
    local armor = self:GetArmor(nil, targetLevel)
    local sunderArmor = self:GetSunderArmorValue(rank)
    local remainingArmor = math.max(0, armor - sunderArmor)

    return self:ComputeEHP(targetHitPoints, armor, attackerLevel)
        - self:ComputeEHP(targetHitPoints, remainingArmor, attackerLevel)
end

-- Calculates Sunder Armor's effective health damage per hit point of target health.
function Abilities:ComputeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
    local armor = self:GetArmor(nil, targetLevel)
    local reducedArmor = math.min(armor, self:GetSunderArmorValue(rank))
    return reducedArmor / (85 * attackerLevel + 400)
end

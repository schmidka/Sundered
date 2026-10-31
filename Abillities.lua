--[[
    Abilities

    Functions to estimate the effective health damage of various Warrior abilities, notably including Sunder Armor. This
    allows users to compare Sunder and potentially other armor reduction abilities directly to direct damage abilities,
    which is kind of the point of this entire addon.

    Because several values required to compute these things accurately are secret while in combat in the Forever API,
    we must rely on estimates for a number of critical values. Most notably, we do not generally know exact max health,
    which is required to compute the EHP damage of a Sunder Armor, or the current player attributes such as crit chance,
    attack power, etc, all which are required to compute the EHP damage of any direct damage ability.

    The armor tables distinguish rough mob archetypes, but GetArmor currently uses the paladin table as a general
    guess. We could try to use UnitPowerType to differentiate these better but it's hard to be exact about this thing
    in anyhting vanilla-ish. Target health is handled separately by MobHealthCache. Values here are Classic estimates
    and will need revision for Forever.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Abilities = Addon:NewModule("Abilities")
local AttributeCache = Addon:GetModule("AttributeCache")

local supportedAbilities = {
    "Sunder Armor",
    "Bloodthirst",
    "Mortal Strike",
    "Slam",
    "Shield Slam",
    "Whirlwind",
    "Thunder Clap",
}

-- This would be better accessed through the API but since I'm testing in Midnight it's easier to hardcore.
local abilityTextures = {
    ["Sunder Armor"] = "Interface\\Icons\\Ability_Warrior_Sunder",
    ["Bloodthirst"] = "Interface\\Icons\\Spell_Nature_BloodLust",
    ["Mortal Strike"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    ["Slam"] = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    ["Shield Slam"] = "Interface\\Icons\\INV_Shield_05",
    ["Whirlwind"] = "Interface\\Icons\\Ability_Whirlwind",
    ["Thunder Clap"] = "Interface\\Icons\\Spell_Nature_ThunderClap",
}

local function GetOption(key)
    return Addon:GetModule("Options"):GetOption(key)
end

-- Approximate armor values indexed by mob level for the three Classic archetypes.
local mageArmorByLevel = {
      10,   11,   24,   42,   65,   93,  126,  166,  212,  267,
     286,  305,  325,  344,  363,  385,  404,  423,  442,  461,
     480,  499,  518,  537,  556,  575,  594,  613,  632,  658,
     676,  694,  712,  730,  748,  802,  858,  915,  974, 1036,
    1100, 1167, 1235, 1305, 1378, 1406, 1434, 1462, 1490, 1518,
    1546, 1574, 1602, 1630, 1658, 1686, 1714, 1742, 1770, 1798,
    1826, 1854, 1882,
}

-- Paladin armor is the current default because target archetype is not identified.
local paladinArmorByLevel = {
      17,   18,   38,   68,  105,  150,  205,  268,  342,  426,
     450,  479,  508,  537,  566,  596,  625,  653,  684,  712,
     741,  771,  800,  829,  858,  887,  917,  946,  975, 1004,
    1033, 1063, 1092, 1121, 1151, 1234, 1325, 1418, 1517, 1619,
    1728, 1841, 1958, 2082, 2211, 2255, 2300, 2344, 2388, 2433,
    2477, 2522, 2566, 2610, 2654, 2699, 2743, 2788, 2832, 2876,
    2921, 2965, 3009,
}

-- Warrior and rogue armor values, included for future archetype-specific estimates.
local warriorArmorByLevel = {
      20,   21,   46,   82,  126,  180,  245,  322,  412,  518,
     545,  580,  615,  650,  685,  721,  756,  791,  826,  861,
     897,  932,  967, 1002, 1037, 1072, 1108, 1142, 1172, 1212,
    1247, 1283, 1317, 1353, 1387, 1494, 1607, 1724, 1849, 1980,
    2117, 2262, 2414, 2574, 2742, 2798, 2853, 2907, 2963, 3018,
    3072, 3128, 3183, 3237, 3292, 3348, 3402, 3457, 3512, 3566,
    3622, 3677, 3731,
}

-- Armor removed by each Sunder Armor rank.
local sunderArmorByRank = {
    90, 180, 270, 360, 450,
}

-- Bonus damage by rank for Mortal Strike.
local mortalStrikeBonusByRank = {
    85, 110, 135, 160,
}

-- Bonus damage by rank for Slam.
local slamBonusByRank = {
    32, 43, 68, 87,
}

-- Bonus damage by rank for Shield Slam.
local shieldSlamBonusByRank = {
    225, 264, 303, 342,
}

-- Base damage by rank for Thunder Clap.
local thunderClapDamageByRank = {
    10, 23, 37, 55, 82, 103,
}

-- Improved Thunder Clap's damage bonus by talent rank.
local improvedThunderClapDamageByRank = {
    [0] = 0,
    0.4, 0.7, 1,
}

-- Rage reduction for the same talent ranks.
local improvedThunderClapRageReductionByRank = {
    0, 1, 2, 4,
}

-- Base Rage costs before the configured talent reductions are applied.
local rageCosts = {
    ["Sunder Armor"] = 15,
    ["Bloodthirst"] = 30,
    ["Mortal Strike"] = 30,
    ["Slam"] = 15,
    ["Shield Slam"] = 20,
    ["Whirlwind"] = 25,
    ["Thunder Clap"] = 20,
}

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- Assumes a successful hit and averages normal damage with double-damage crits.
local function applyExpectedCrit(damage)
    return damage * (1 + AttributeCache:GetCritChance() / 100)
end

-- Returns a level-based armor estimate using the current default mob archetype.
local function getArmor(level)
    level = clamp(level, 1, 63)
    return paladinArmorByLevel[level]
end

-- Returns the armor reduction for a Sunder Armor rank.
local function getSunderArmorValue(rank)
    rank = clamp(rank, 1, 5)
    return sunderArmorByRank[rank]
end

-- Estimates Bloodthirst EHP damage.
local function computeBloodthirstEHPDamage()
    local attackPower = AttributeCache:GetAttackPower()
    return applyExpectedCrit(attackPower * 0.45)
end

-- Estimates Mortal Strike EHP damage.
local function computeMortalStrikeEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return applyExpectedCrit(weaponDamage + mortalStrikeBonusByRank[rank])
end

-- Estimates Slam EHP damage.
local function computeSlamEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return applyExpectedCrit(weaponDamage + slamBonusByRank[rank])
end

-- Estimates Shield Slam EHP damage.
local function computeShieldSlamEHPDamage(rank)
    rank = clamp(rank, 1, 4)
    local shieldBlock = AttributeCache:GetShieldBlock()
    local damage = shieldBlock + shieldSlamBonusByRank[rank]
    return applyExpectedCrit(damage)
end

-- Estimates Whirlwind EHP damage.
local function computeWhirlwindEHPDamage()
    local mainHandDamage = AttributeCache:GetAverageMainHandDamage()
    local offHandDamage = AttributeCache:GetAverageOffHandDamage()
    return applyExpectedCrit(mainHandDamage + offHandDamage)
end

-- Estimates Thunder Clap EHP damage.
local function computeThunderClapEHPDamage(rank, talentRank)
    rank = clamp(rank, 1, 6)
    talentRank = clamp(talentRank, 0, 3)
    local improvedDamage = improvedThunderClapDamageByRank[talentRank]
    local damage = thunderClapDamageByRank[rank] * (1 + improvedDamage)
    return applyExpectedCrit(damage)
end

local function computeEHP(hitPoints, armor, attackerLevel)
    return hitPoints + hitPoints * armor / (85 * attackerLevel + 400)
end

-- Estimates Sunder Armor's EHP damage against the target's current estimated health.
local function computeSunderArmorEHPDamage(rank, attackerLevel, targetHitPoints, targetLevel)
    local armor = getArmor(targetLevel)
    local sunderArmor = getSunderArmorValue(rank)
    local remainingArmor = math.max(0, armor - sunderArmor)

    return computeEHP(targetHitPoints, armor, attackerLevel)
        - computeEHP(targetHitPoints, remainingArmor, attackerLevel)
end

local function computeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
    local armor = getArmor(targetLevel)
    local reducedArmor = math.min(armor, getSunderArmorValue(rank))
    return reducedArmor / (85 * attackerLevel + 400)
end

-- Keeps direct-ability formulas separate because each uses different ranks and player attributes.
local function computeDirectAbilityEHPDamage(spellName)
    if spellName == "Bloodthirst" then
        return computeBloodthirstEHPDamage()
    elseif spellName == "Mortal Strike" then
        return computeMortalStrikeEHPDamage(GetOption("mortalStrikeRank"))
    elseif spellName == "Slam" then
        return computeSlamEHPDamage(GetOption("slamRank"))
    elseif spellName == "Shield Slam" then
        return computeShieldSlamEHPDamage(GetOption("shieldSlamRank"))
    elseif spellName == "Whirlwind" then
        return computeWhirlwindEHPDamage()
    elseif spellName == "Thunder Clap" then
        return computeThunderClapEHPDamage(
            GetOption("thunderClapRank"), GetOption("improvedThunderClapRank")
        )
    end
end

-- Returns the spell names supported by the damage estimates.
function Abilities:GetSupportedAbilities()
    local abilities = {}
    for index, spellName in ipairs(supportedAbilities) do
        abilities[index] = spellName
    end
    return abilities
end

-- Returns the icon asset associated with a supported ability.
function Abilities:GetAbilityTexture(spellName)
    return abilityTextures[spellName]
end

-- Estimates EHP damage for a spell name, using Blizzard's canonical English name.
function Abilities:ComputeExpectedAbilityEHPDamage(spellName, attackerLevel, targetHitPoints, targetLevel)
    if spellName == "Sunder Armor" then
        return computeSunderArmorEHPDamage(
            GetOption("sunderArmorRank"), attackerLevel, targetHitPoints, targetLevel
        )
    end

    return computeDirectAbilityEHPDamage(spellName)
end

-- Returns an ability's base rage cost after configured talent reductions.
function Abilities:GetAbilityRageCost(spellName)
    local rageCost = rageCosts[spellName]
    if not rageCost then
        return nil
    end

    -- Apply general talent reductions, then the ability-specific reduction.
    rageCost = rageCost - GetOption("focusedRageRank")
    if spellName == "Sunder Armor" then
        rageCost = rageCost - GetOption("improvedSunderArmorRank")
    elseif spellName == "Thunder Clap" then
        local talentRank = GetOption("improvedThunderClapRank")
        local rageReduction = improvedThunderClapRageReductionByRank[talentRank + 1]
        rageCost = rageCost - rageReduction
    end

    return math.max(0, rageCost)
end

-- Returns estimated EHP damage per rage for Sunder Armor or a direct ability.
function Abilities:ComputeExpectedAbilityEHPDamagePerRage(spellName, attackerLevel, targetHitPoints, targetLevel)
    local damage = self:ComputeExpectedAbilityEHPDamage(spellName, attackerLevel, targetHitPoints, targetLevel)
    return damage / self:GetAbilityRageCost(spellName)
end

-- Returns target-health scaling for spells whose impact depends on remaining target health.
function Abilities:ComputeExpectedAbilityEHPDamageScaling(spellName, attackerLevel, targetLevel)
    if spellName == "Sunder Armor" then
        return computeSunderArmorEHPDamageScaling(
            GetOption("sunderArmorRank"), attackerLevel, targetLevel
        )
    end
end

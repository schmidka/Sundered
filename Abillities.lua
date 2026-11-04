-- Copyright (c) 2026 Karl Schmidt
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
    in anyhting vanilla-ish. Target health is handled separately by MobHealthCache. Armor estimates remain
    Classic-based; ability ranks and damage values are updated for Forever where known.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sundered")
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
    "Heroic Strike",
    "Cleave",
    "Rend",
    "Revenge",
}

-- Static assets keep the icons available while testing in Midnight.
local abilityTextures = {
    ["Sunder Armor"] = "Interface\\Icons\\Ability_Warrior_Sunder",
    ["Bloodthirst"] = "Interface\\Icons\\Spell_Nature_BloodLust",
    ["Mortal Strike"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    ["Slam"] = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    ["Shield Slam"] = "Interface\\Icons\\INV_Shield_05",
    ["Whirlwind"] = "Interface\\Icons\\Ability_Whirlwind",
    ["Thunder Clap"] = "Interface\\Icons\\Spell_Nature_ThunderClap",
    ["Heroic Strike"] = "Interface\\Icons\\Ability_Rogue_Ambush",
    ["Cleave"] = "Interface\\Icons\\Ability_Warrior_Cleave",
    ["Rend"] = "Interface\\Icons\\Ability_Gouge",
    ["Revenge"] = "Interface\\Icons\\Ability_Warrior_Revenge",
}

local function GetOption(key)
    return Addon:GetModule("Options"):GetOption(key)
end

-- Approximate armor values indexed by mob level for the mage archetype.
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

-- Approximate armor values indexed by mob level for the warrior archetype.
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

-- Base damage by rank for Mortal Strike.
local mortalStrikeBonusByRank = {
    85, 110, 135, 160,
}

-- Base damage by rank for Slam.
local slamBonusByRank = {
    16, 32, 43, 68, 87,
}

-- Base damage by rank for Shield Slam.
local shieldSlamBonusByRank = {
    430, 505, 580, 655,
}

-- Base damage by rank for Bloodthirst.
local bloodthirstBonusByRank = {
    30, 37, 43, 48,
}

-- Base damage by rank for Heroic Strike.
local heroicStrikeBonusByRank = {
    11, 21, 32, 54, 78, 100, 128, 157, 196,
}

-- Base damage by rank for Cleave.
local cleaveBonusByRank = {
    5, 10, 18, 32, 50,
}

-- Base damage by rank for Rend.
local rendDamageByRank = {
    15, 30, 45, 75, 105, 150, 210,
}

-- Damage ticks by rank for Rend.
local rendTicksByRank = {
    3, 4, 5, 5, 5, 5, 5,
}

-- Damage increase by Improved Rend talent rank.
local improvedRendDamageByRank = {
    0, 0.12, 0.23, 0.35,
}

-- Base damage by rank for Revenge.
local revengeDamageByRank = {
    22, 34, 48, 82, 121, 153,
}

-- Base damage by rank for Thunder Clap.
local thunderClapDamageByRank = {
    10, 23, 37, 55, 82, 103,
}

-- Rage reduction by Improved Thunder Clap talent rank.
local improvedThunderClapRageReductionByRank = {
    0, 2, 4, 6,
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
    ["Heroic Strike"] = 15,
    ["Cleave"] = 20,
    ["Rend"] = 10,
    ["Revenge"] = 5,
}

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- Estimates the target's defensive skill gap for Classic attack calculations.
local function getSkillDifference(targetLevel)
    local defenseSkill = clamp(targetLevel, 1, 63) * 5
    return defenseSkill - AttributeCache:GetWeaponSkill()
end

-- Estimates the chance that an attack misses its target.
local function computeMissChance(skillDifference, isDualWielding)
    local missChance
    if skillDifference <= 10 then
        missChance = 5 + skillDifference * 0.1
    else
        missChance = 6 + (skillDifference - 10) * 0.4
    end

    if isDualWielding then
        missChance = missChance + 19
    end

    return clamp(missChance - AttributeCache:GetHitChance(), 0, 100)
end

-- Estimates the chance that the target dodges a frontal melee attack.
local function computeDodgeChance(skillDifference)
    return clamp(5 + skillDifference * 0.1, 0, 100)
end

-- Estimates the chance that the target parries a frontal melee attack.
local function computeParryChance(skillDifference)
    return clamp(5 + skillDifference * 0.1, 0, 100)
end

-- Combines attack outcomes to estimate the chance that an attack lands.
local function computeAttackTable(targetLevel, isDualWielding)
    local skillDifference = getSkillDifference(targetLevel)
    local missChance = computeMissChance(skillDifference, isDualWielding)
    local dodgeChance = computeDodgeChance(skillDifference)
    local parryChance = computeParryChance(skillDifference)
    local landedChance = math.max(0, 100 - missChance - dodgeChance - parryChance)
    return skillDifference, landedChance
end

-- Estimates the chance that an attack critically strikes its target.
local function computeCritChance(targetLevel)
    local skillDifference = getSkillDifference(targetLevel)
    local chance = AttributeCache:GetCritChance() - skillDifference * 0.04
    return clamp(chance, 0, 100)
end

-- Estimates the chance that a white swing glances off the target.
local function computeGlancingChance(skillDifference)
    return clamp(10 + skillDifference * 2, 0, 100)
end

-- Estimates the damage retained when a white swing glances.
local function computeGlancingDamageMultiplier(skillDifference)
    local minimum = math.max(0.01, math.min(0.91, 1.3 - skillDifference * 0.05))
    local maximum = clamp(1.2 - skillDifference * 0.03, 0.2, 0.99)
    return (minimum + maximum) / 2
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

local function computeMitigation(armor, attackerLevel)
    return 1 + armor / (85 * attackerLevel + 400)
end

-- Estimates average damage for an ability that uses the yellow attack table.
-- Currently missing: combat table prioririty, +%damage talents and stances, expertise.
local function computeExpectedYellowEHPDamage(damage, targetLevel, canCrit)
    local _, landedChance = computeAttackTable(targetLevel, false)
    local critChance = 0
    if canCrit then
        critChance = math.min(computeCritChance(targetLevel), landedChance)
    end

    local critDamageBonus = GetOption("impaleRank") * 0.1
    return damage * (landedChance + critChance * (1 + critDamageBonus)) / 100
end

-- Estimates average damage for a white swing, including glancing blows.
-- Currently missing: combat table prioririty, +%damage talents and stances, expertise.
local function computeExpectedWhiteSwingEHPDamage(damage, targetLevel)
    local isDualWielding = AttributeCache:GetAverageOffHandDamage() > 0
    local skillDifference, landedChance = computeAttackTable(targetLevel, isDualWielding)
    local glancingChance = math.min(computeGlancingChance(skillDifference), landedChance)
    local remainingChance = landedChance - glancingChance
    local critChance = math.min(computeCritChance(targetLevel), remainingChance)
    local normalChance = remainingChance - critChance
    local critDamageBonus = GetOption("impaleRank") * 0.1
    local expectedDamage = normalChance + critChance * (2 + critDamageBonus)
    expectedDamage = expectedDamage + glancingChance * computeGlancingDamageMultiplier(skillDifference)
    return damage * expectedDamage / 100
end

-- Estimates the Rage generated by the white swing that Heroic Strike replaces.
-- Currently missing: combat table prioririty, +%damage talents and stances, expertise.
local function computeExpectedWhiteSwingRage(attackerLevel, targetLevel)
    local isDualWielding = AttributeCache:GetAverageOffHandDamage() > 0
    local _, landedChance = computeAttackTable(targetLevel, isDualWielding)
    local damage = computeExpectedWhiteSwingEHPDamage(
        AttributeCache:GetAverageMainHandDamage(), targetLevel
    )
    local armor = getArmor(targetLevel)
    local actualDamage = damage / computeMitigation(armor, attackerLevel)
    local damageRage = actualDamage / (0.5 * attackerLevel + 0.5)
    local swingRage = landedChance / 100 * AttributeCache:GetMainHandSpeed() * 3.5
    return (damageRage + swingRage) / 2
end

-- Estimates Bloodthirst damage from attack power and its selected rank.
local function computeBloodthirstEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 4)
    local attackPower = AttributeCache:GetAttackPower()
    return computeExpectedYellowEHPDamage(attackPower * 0.45 + bloodthirstBonusByRank[rank], targetLevel, true)
end

-- Estimates Mortal Strike damage from main-hand weapon damage and its selected rank.
local function computeMortalStrikeEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 4)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return computeExpectedYellowEHPDamage(weaponDamage + mortalStrikeBonusByRank[rank], targetLevel, true)
end

-- Estimates Slam damage from main-hand weapon damage and its selected rank.
local function computeSlamEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 5)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    return computeExpectedYellowEHPDamage(weaponDamage + slamBonusByRank[rank], targetLevel, true)
end

-- Estimates Shield Slam damage from shield block value and its selected rank.
local function computeShieldSlamEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 4)
    local shieldBlock = AttributeCache:GetShieldBlock()
    local damage = shieldBlock + shieldSlamBonusByRank[rank]
    return computeExpectedYellowEHPDamage(damage, targetLevel, true)
end

-- Estimates Whirlwind damage from both weapon hands.
local function computeWhirlwindEHPDamage(targetLevel)
    local mainHandDamage = AttributeCache:GetAverageMainHandDamage()
    local offHandDamage = AttributeCache:GetAverageOffHandDamage()
    return computeExpectedYellowEHPDamage(mainHandDamage + offHandDamage, targetLevel, true)
end

-- Estimates Thunder Clap damage using its selected rank.
local function computeThunderClapEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 6)
    return computeExpectedYellowEHPDamage(thunderClapDamageByRank[rank], targetLevel, true)
end

-- Estimates Heroic Strike's damage gain over the white swing it replaces.
local function computeHeroicStrikeEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 9)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    local heroicStrikeDamage = computeExpectedYellowEHPDamage(
        weaponDamage + heroicStrikeBonusByRank[rank], targetLevel, true
    )
    return heroicStrikeDamage - computeExpectedWhiteSwingEHPDamage(weaponDamage, targetLevel)
end

-- Estimates Cleave's total damage to two same-level targets, net of its replaced white swing.
local function computeCleaveEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 5)
    local weaponDamage = AttributeCache:GetAverageMainHandDamage()
    local damagePerTarget = computeExpectedYellowEHPDamage(
        weaponDamage + cleaveBonusByRank[rank], targetLevel, true
    )
    return damagePerTarget * 2 - computeExpectedWhiteSwingEHPDamage(weaponDamage, targetLevel)
end

-- Rend cannot crit; estimate its bleed damage in armor-mitigated EHP terms.
local function computeRendEHPDamage(rank, attackerLevel, targetLevel)
    rank = clamp(rank, 1, 7)
    local talentRank = clamp(GetOption("improvedRendRank"), 0, 3)
    local attackPower = AttributeCache:GetAttackPower()
    local ticks = rendTicksByRank[rank]
    local damage = rendDamageByRank[rank] + ticks * attackPower * 0.02
    local armor = getArmor(targetLevel)
    damage = damage * (1 + improvedRendDamageByRank[talentRank + 1])
    damage = damage * computeMitigation(armor, attackerLevel)
    return computeExpectedYellowEHPDamage(damage, targetLevel, false)
end

-- Estimates Revenge assuming its block, dodge, or parry condition was met.
local function computeRevengeEHPDamage(rank, targetLevel)
    rank = clamp(rank, 1, 6)
    local attackPower = AttributeCache:GetAttackPower()
    local damage = revengeDamageByRank[rank] + attackPower * 0.25
    local talentRank = clamp(GetOption("improvedRevengeRank"), 0, 3)
    damage = damage * (1 + talentRank * 0.2)
    return computeExpectedYellowEHPDamage(damage, targetLevel, true)
end

-- Converts health and armor into effective health for a given attacker level.
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

-- Returns the target-health scaling for one Sunder Armor application.
local function computeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
    local armor = getArmor(targetLevel)
    local reducedArmor = math.min(armor, getSunderArmorValue(rank))
    return reducedArmor / (85 * attackerLevel + 400)
end

-- Keeps direct-ability formulas separate because each uses different ranks and player attributes.
local function computeDirectAbilityEHPDamage(spellName, attackerLevel, targetLevel)
    if spellName == "Bloodthirst" then
        return computeBloodthirstEHPDamage(GetOption("bloodthirstRank"), targetLevel)
    elseif spellName == "Mortal Strike" then
        return computeMortalStrikeEHPDamage(GetOption("mortalStrikeRank"), targetLevel)
    elseif spellName == "Slam" then
        return computeSlamEHPDamage(GetOption("slamRank"), targetLevel)
    elseif spellName == "Shield Slam" then
        return computeShieldSlamEHPDamage(GetOption("shieldSlamRank"), targetLevel)
    elseif spellName == "Whirlwind" then
        return computeWhirlwindEHPDamage(targetLevel)
    elseif spellName == "Thunder Clap" then
        return computeThunderClapEHPDamage(GetOption("thunderClapRank"), targetLevel)
    elseif spellName == "Heroic Strike" then
        return computeHeroicStrikeEHPDamage(GetOption("heroicStrikeRank"), targetLevel)
    elseif spellName == "Cleave" then
        return computeCleaveEHPDamage(GetOption("cleaveRank"), targetLevel)
    elseif spellName == "Rend" then
        return computeRendEHPDamage(GetOption("rendRank"), attackerLevel, targetLevel)
    elseif spellName == "Revenge" then
        return computeRevengeEHPDamage(GetOption("revengeRank"), targetLevel)
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
        local rank = GetOption("sunderArmorRank")
        local damage = computeSunderArmorEHPDamage(rank, attackerLevel, targetHitPoints, targetLevel)
        local _, landedChance = computeAttackTable(targetLevel, false)
        return damage * landedChance / 100
    end

    return computeDirectAbilityEHPDamage(spellName, attackerLevel, targetLevel)
end

-- Returns estimated Rage cost after talents and the Rage lost from a replaced white swing.
function Abilities:GetAbilityRageCost(spellName, attackerLevel, targetLevel)
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
    elseif spellName == "Heroic Strike" then
        rageCost = rageCost - GetOption("improvedHeroicStrikeRank")
    end

    if spellName ~= "Rend" and spellName ~= "Sunder Armor" then
        rageCost = rageCost - GetOption("unbridledWrathRank") * 0.12
    end

    if spellName == "Heroic Strike" or spellName == "Cleave" then
        attackerLevel = attackerLevel or AttributeCache:GetWeaponSkill() / 5
        targetLevel = targetLevel or attackerLevel
        rageCost = rageCost + computeExpectedWhiteSwingRage(attackerLevel, targetLevel)
    end

    return math.max(0, rageCost)
end

-- Returns estimated EHP damage per rage for Sunder Armor or a direct ability.
function Abilities:ComputeExpectedAbilityEHPDamagePerRage(spellName, attackerLevel, targetHitPoints, targetLevel)
    local damage = self:ComputeExpectedAbilityEHPDamage(spellName, attackerLevel, targetHitPoints, targetLevel)
    return damage / self:GetAbilityRageCost(spellName, attackerLevel, targetLevel)
end

-- Returns target-health scaling for spells whose impact depends on remaining target health.
function Abilities:ComputeExpectedAbilityEHPDamageScaling(spellName, attackerLevel, targetLevel)
    if spellName == "Sunder Armor" then
        local rank = GetOption("sunderArmorRank")
        local scaling = computeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
        local _, landedChance = computeAttackTable(targetLevel, false)
        return scaling * landedChance / 100
    end
end

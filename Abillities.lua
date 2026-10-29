local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Abilities = Addon:NewModule("Abilities")

--[[
    A brief overview of mob classes and armor in classic:

    There are generally 4 classes for mobs: warrior, rogue, paladin and mage.

    Warriors and Rogues have the same armor and the highest values.
    Paladins are the most common and have middle values.
    Mages have the lowest armor.
    
    Armor is provided in exact lookups, and should be accurate ... if we know the type. Unfortunately, we don't. Functions will simply guess paladin for now.

    Some bosses have armor values that break this, but since Sunderer primarily cares about leveling and normal mobs and not instanced content -- the Sunder yes/no decision is always going to be yes against Sulfuron -- I am not worried about handling them.
    
    Health is definitely not exact. Secrecy prevents us from using UnitHealthMax. We have to hardcode some guesses. This is a sloppily generated table of approximate base health for a typical mob at each level. I have done some manual verification and the AI seems to have done a reasonable job, but by its nature these are rough numbers. Mage mobs will have 30% less, high HP mobs like bears will have 20% more, give or take.

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

function round(value) 
    return math.floor(value + 0.5)
end

function clamp(value, min, max)
    return math.max(min, math.min(value, max))
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

-- Creates a CuverObject that maps percent HP to estimated Sunder Armor EHP damage.
function Abilities:CreateEHPDamageCurve(rank)
    -- Get current character and target data. We have to approximate health.
    local attackerLevel = UnitLevel("player")
    local targetLevel = UnitLevel("target")
    local targetMaxHP  = Abilities:GetApproximateMaxHealth("", targetLevel)

    -- Scale estimated max HP bty estimated sunder damage/HP. Note, lots of estimating.
    local scale = self:ComputeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, 0)
    curve:AddPoint(1, scale * targetMaxHP)
    return curve
end

-- Creates the damage curve for the current target, or returns nil if there is none.
function Abilities:CreateCurrentSunderArmorEHPDamageCurve(rank)
    if not UnitExists("target") then
        return nil
    end
    return self:CreateEHPDamageCurve(rank)
end

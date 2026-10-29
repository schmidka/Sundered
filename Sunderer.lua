Sunderer = Sunderer or {}

local armorByType = {
    MAGE = {
        10, 11, 24, 42, 65, 93, 126, 166, 212, 267, 286, 305, 325, 344, 363, 385, 404, 423, 442, 461, 480,
        499, 518, 537, 556, 575, 594, 613, 632, 658, 676, 694, 712, 730, 748, 802, 858, 915, 974, 1036, 1100,
        1167, 1235, 1305, 1378, 1406, 1434, 1462, 1490, 1518, 1546, 1574, 1602, 1630, 1658, 1686, 1714, 1742,
        1770, 1798, 1826, 1854, 1882,
    },
    PALADIN = {
        17, 18, 38, 68, 105, 150, 205, 268, 342, 426, 450, 479, 508, 537, 566, 596, 625, 653, 684, 712, 741,
        771, 800, 829, 858, 887, 917, 946, 975, 1004, 1033, 1063, 1092, 1121, 1151, 1234, 1325, 1418, 1517,
        1619, 1728, 1841, 1958, 2082, 2211, 2255, 2300, 2344, 2388, 2433, 2477, 2522, 2566, 2610, 2654, 2699,
        2743, 2788, 2832, 2876, 2921, 2965, 3009,
    },
    WARRIOR = {
        20, 21, 46, 82, 126, 180, 245, 322, 412, 518, 545, 580, 615, 650, 685, 721, 756, 791, 826, 861, 897,
        932, 967, 1002, 1037, 1072, 1108, 1142, 1172, 1212, 1247, 1283, 1317, 1353, 1387, 1494, 1607, 1724,
        1849, 1980, 2117, 2262, 2414, 2574, 2742, 2798, 2853, 2907, 2963, 3018, 3072, 3128, 3183, 3237, 3292,
        3348, 3402, 3457, 3512, 3566, 3622, 3677, 3731,
    },
}

local armorValues = armorByType.PALADIN

local icon = CreateFrame("Button", "SundererIcon", UIParent)
icon:SetSize(32, 32)
icon:SetPoint("CENTER")
icon:SetMovable(true)
icon:EnableMouse(true)
icon:RegisterForDrag("LeftButton")
icon:SetScript("OnDragStart", icon.StartMoving)
icon:SetScript("OnDragStop", icon.StopMovingOrSizing)

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetAllPoints()
texture:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

local armorText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local fontPath, _, fontFlags = armorText:GetFont()
local validTextPositions = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
    BELOW = true,
}

function Sunderer.ApplyOptions(options)
    icon:SetSize(options.iconSize, options.iconSize)
    armorText:SetFont(fontPath, options.textSize, fontFlags)
    armorText:ClearAllPoints()

    local position = options.textPosition
    if not validTextPositions[position] then
        position = "CENTER"
    end
    if position == "BELOW" then
        armorText:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        armorText:SetWidth(icon:GetWidth())
        armorText:SetJustifyH("CENTER")
        armorText:SetJustifyV("TOP")
        return
    end

    local horizontal = position:match("LEFT$") and "LEFT"
        or position:match("RIGHT$") and "RIGHT"
        or "CENTER"
    local vertical = position:match("^TOP") and "TOP"
        or position:match("^BOTTOM") and "BOTTOM"
        or "MIDDLE"

    armorText:SetPoint(position, icon, position)
    armorText:SetWidth(icon:GetWidth())
    armorText:SetHeight(icon:GetHeight())
    armorText:SetJustifyH(horizontal)
    armorText:SetJustifyV(vertical)
end

local function UpdateArmor()
    if not UnitExists("target") then
        armorText:SetText("")
        return
    end

    local level = UnitLevel("target")
    if not level or level < 1 then
        armorText:SetText("")
        return
    end

    level = math.min(level, #armorValues)
    armorText:SetText(armorValues[level] or "")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", UpdateArmor)

UpdateArmor()

-- Addon 
Sunderer = LibStub("AceAddon-3.0"):NewAddon("Sunderer", "AceEvent-3.0", "AceConsole-3.0")
Sunderer.callbacks = LibStub("CallbackHandler-1.0"):New(Sunderer)

-- Modules
local Options           = nil

-- Armor values in classic wow. Mobs are divided into 3 armor types. Mage is light, Paladin is medium, Warrior is heavy. The majority of mobs are Paladins. The armor values are indexed by mob level. Some raid bosses have higher values, but frankly this addon isn't about them.
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

-- Ideally we'd look up mobs by name, but for now assume medium armor.
local armorValues = armorByType.PALADIN

-- Display state
local icon      = nil
local armorText = nil

-- Initialization. Called once on UI load.
function Sunderer:OnInitialize()
	-- Get modules
	Options = self:GetModule("Options")

    -- Register option command, if ever we use it
	self:RegisterChatCommand("sunderer", "ChatCommand")

    -- Init the icon with some defaults
    self.icon = CreateFrame("Button", "SundererIcon", UIParent)

    local texture = self.icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.icon:SetSize(32, 32)
    self.icon:SetPoint("CENTER")
    self.icon:SetMovable(true)
    self.icon:EnableMouse(true)
    self.icon:RegisterForDrag("LeftButton")
    self.icon:SetScript("OnDragStart", self.icon.StartMoving)
    self.icon:SetScript("OnDragStop", self.icon.StopMovingOrSizing)

    self.armorText = self.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

function Sunderer:UpdateSetting(event, key, value)
    -- ignore exactly what setting was changed and just apply everything
    self:ApplyOptions()
end

function Sunderer:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateArmor")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArmor")
	Options.RegisterCallback(self, "Sunderer_SETTING_CHANGED", "UpdateSetting")

    -- Initialize our icon and text
    self:ApplyOptions()
    self:UpdateArmor()
    self.icon:Show()
end

function Sunderer:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	Options.UnregisterCallback(self, "Sunderer_SETTING_CHANGED")
    self.icon:Hide()
end

function Sunderer:ApplyOptions()
    -- Try to load the current profile. If the options aren't initalized then this may return nil.
    local profile = Options:GetCurrentProfile()
    if not profile then
        return
    end

    -- Set icon and text according to the profile's settings
    self.icon:SetSize(profile.iconSize, profile.iconSize)

    local fontPath, _, fontFlags = self.armorText:GetFont()
    self.armorText:SetFont(fontPath, profile.textSize, fontFlags)
    self.armorText:ClearAllPoints()

    local position = profile.textPosition
    if position == "BELOW" then
        self.armorText:SetPoint("TOP", self.icon, "BOTTOM", 0, -2)
        self.armorText:SetWidth(self.icon:GetWidth())
        self.armorText:SetJustifyH("CENTER")
        self.armorText:SetJustifyV("TOP")
        return
    end
    local horizontal = position:match("LEFT$") and "LEFT"
        or position:match("RIGHT$") and "RIGHT"
        or "CENTER"
    local vertical = position:match("^TOP") and "TOP"
        or position:match("^BOTTOM") and "BOTTOM"
        or "MIDDLE"

    self.armorText:SetPoint(position, self.icon, position)
    self.armorText:SetWidth(self.icon:GetWidth())
    self.armorText:SetHeight(self.icon:GetHeight())
    self.armorText:SetJustifyH(horizontal)
    self.armorText:SetJustifyV(vertical)
end

function Sunderer:UpdateArmor()
    if not self.armorText then
        return
    end

    if not UnitExists("target") then
        self.armorText:SetText("")
        return
    end

    local level = UnitLevel("target")
    if not level or level < 1 then
        self.armorText:SetText("")
        return
    end

    -- Clamp level to [1,63]
    level = math.max(1, math.min(level, 63))
    self.armorText:SetText(armorValues[level] or "")
end

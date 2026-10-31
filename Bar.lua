-- Module to display estimated Sunder Armor damage as a bar

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Bar = Addon:NewModule("Bar")
local LSM = LibStub("LibSharedMedia-3.0")

local compareAbilityOrder = {
    "BLOODTHIRST",
    "MORTAL_STRIKE",
    "SLAM",
    "SHIELD_SLAM",
    "WHIRLWIND",
    "THUNDER_CLAP",
}

local compareAbilities = {
    BLOODTHIRST = {
        optionKey = "compareBloodthirst",
        spellID = 23881,
    },
    MORTAL_STRIKE = {
        optionKey = "compareMortalStrike",
        spellID = 12294,
    },
    SLAM = {
        optionKey = "compareSlam",
        spellID = 1464,
    },
    SHIELD_SLAM = {
        optionKey = "compareShieldSlam",
        spellID = 23922,
    },
    WHIRLWIND = {
        optionKey = "compareWhirlwind",
        spellID = 1680,
    },
    THUNDER_CLAP = {
        optionKey = "compareThunderClap",
        spellID = 6343,
    },
}

local function createSunderDamageCurve(abilities, mobHealthCache, rank, targetLevel, attackerLevel)
    local maxHealth = mobHealthCache:EstimateTargetMaxHealth()
    local scale = abilities:ComputeSunderArmorEHPDamageScaling(rank, attackerLevel, targetLevel)
    local maxValue = scale * maxHealth
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, 0)
    curve:AddPoint(1, maxValue)
    return curve, maxValue
end

local function createComparisonColorCurve(compareValue, maxValue, aboveColor, belowColor)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Cubic)

    if not compareValue or compareValue <= 0 or maxValue <= 0 then
        curve:AddPoint(0, aboveColor)
        curve:AddPoint(1, aboveColor)
        return curve
    end

    local transitionStart = compareValue * 0.7 / maxValue
    local transitionEnd = compareValue * 1.3 / maxValue
    if transitionStart >= 1 then
        curve:AddPoint(0, belowColor)
        curve:AddPoint(1, belowColor)
        return curve
    end

    curve:AddPoint(0, belowColor)
    if transitionStart > 0 then
        curve:AddPoint(transitionStart, belowColor)
    end
    if transitionEnd >= 1 then
        local transition = (1 - transitionStart) / (transitionEnd - transitionStart)
        local belowRed, belowGreen, belowBlue = belowColor:GetRGB()
        local aboveRed, aboveGreen, aboveBlue = aboveColor:GetRGB()
        local red = belowRed + (aboveRed - belowRed) * transition
        local green = belowGreen + (aboveGreen - belowGreen) * transition
        local blue = belowBlue + (aboveBlue - belowBlue) * transition
        curve:AddPoint(1, CreateColor(red, green, blue, 1))
    else
        curve:AddPoint(transitionEnd, aboveColor)
        curve:AddPoint(1, aboveColor)
    end
    return curve
end

-- Creates the draggable status bar, optional icon, and text.
function Bar:Initialize(parent)
    self.parent = parent
    self.options = Addon:GetModule("Options")
    self.abilities = Addon:GetModule("Abilities")
    self.mobHealthCache = Addon:GetModule("MobHealthCache")
    self.frame = CreateFrame("StatusBar", nil, parent)
    self.frame:SetStatusBarColor(0.75, 0.25, 0.25)
    self.frame:SetMinMaxValues(0, 1)
    self.frame:SetValue(0)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
    end)

    local background = self.frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    self.icon = self.frame:CreateTexture(nil, "OVERLAY")
    self.icon:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.text:SetPoint("CENTER")

    self.compareIndicators = {}
    for index, abilityKey in ipairs(compareAbilityOrder) do
        local indicator = CreateFrame("Frame", nil, self.frame)
        indicator:SetFrameLevel(self.frame:GetFrameLevel() + index)
        indicator:SetSize(2, 20)

        local line = indicator:CreateTexture(nil, "OVERLAY")
        line:SetAllPoints()
        line:SetColorTexture(1, 1, 1, 0.9)

        local icon = indicator:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("BOTTOM", indicator, "TOP", 0, 2)

        indicator:Hide()
        self.compareIndicators[abilityKey] = {
            frame = indicator,
            icon = icon,
        }
    end
end

-- Shows or hides the bar display.
function Bar:SetShown(shown)
    self.frame:SetShown(shown)
end

-- Sets the bar width.
function Bar:SetWidth(width)
    self.width = width
    self:ApplySize()
end

-- Sets the bar height.
function Bar:SetHeight(height)
    self.height = height
    self:ApplySize()
end

-- Applies the bar and optional icon dimensions and layout.
function Bar:ApplySize()
    if not self.width or not self.height then
        return
    end

    local hasIcon = self.iconPosition ~= "NONE"
    self.frame:SetSize(self.width, self.height)
    for _, indicator in pairs(self.compareIndicators) do
        indicator.frame:SetHeight(self.height)
    end
    self.frame:ClearAllPoints()
    if self.iconPosition == "LEFT" then
        self.frame:SetPoint("CENTER", self.parent, "CENTER", self.height / 2, 0)
    elseif self.iconPosition == "RIGHT" then
        self.frame:SetPoint("CENTER", self.parent, "CENTER", -self.height / 2, 0)
    else
        self.frame:SetPoint("CENTER", self.parent, "CENTER")
    end
    self.parent:SetSize(self.width + (hasIcon and self.height or 0), self.height)

    self.icon:SetSize(self.height, self.height)
    self.icon:ClearAllPoints()
    if self.iconPosition == "LEFT" then
        self.icon:SetPoint("RIGHT", self.frame, "LEFT")
    elseif self.iconPosition == "RIGHT" then
        self.icon:SetPoint("LEFT", self.frame, "RIGHT")
    end
end

-- Sets the displayed text size.
function Bar:SetTextSize(size)
    local fontPath, _, fontFlags = self.text:GetFont()
    self.text:SetFont(fontPath, size, fontFlags)
end

-- Sets the displayed text font from LibSharedMedia.
function Bar:SetFont(font)
    local _, size, fontFlags = self.text:GetFont()
    self.text:SetFont(LSM:Fetch("font", font), size, fontFlags)
end

-- Sets the bar texture from LibSharedMedia.
function Bar:SetTexture(texture)
    self.frame:SetStatusBarTexture(LSM:Fetch("statusbar", texture))
end

-- Sets the colors used by the comparison gradient and solid bar.
function Bar:SetColors(aboveThreshold, belowThreshold, solid)
    self.aboveThresholdColor = CreateColor(unpack(aboveThreshold))
    self.belowThresholdColor = CreateColor(unpack(belowThreshold))
    self.solidColor = CreateColor(unpack(solid))
end

-- Enables or disables comparison-based bar color shifting.
function Bar:SetColorShiftEnabled(enabled)
    self.colorShiftEnabled = enabled
end

-- Sets whether the icon is hidden or attached to either side of the bar.
function Bar:SetIconPosition(position)
    self.iconPosition = position
    self:ApplySize()
    if position == "NONE" then
        self.icon:Hide()
    else
        self.icon:Show()
    end
end

-- Updates the bar range, displayed text, and optional ability comparison marker.
function Bar:Update()
    local rank = self.options:GetOption("sunderArmorRank")
    local targetLevel = UnitLevel("target")
    local attackerLevel = UnitLevel("player")
    local curve, maxValue = createSunderDamageCurve(
        self.abilities, self.mobHealthCache, rank, targetLevel, attackerLevel
    )
    local value = UnitHealthPercent("target", true, curve)
    local text = Addon:AbbreviateDamage(value)
    local sunderRageCost = self.abilities:GetAbilityRageCost("SUNDER_ARMOR")
    local comparisons = {}
    local highestCompareValue = 0
    for _, abilityKey in ipairs(compareAbilityOrder) do
        local ability = compareAbilities[abilityKey]
        if self.options:GetOption(ability.optionKey) then
            local damagePerRage = self.abilities:ComputeExpectedAbilityEHPDamagePerRage(abilityKey)
            local compareValue = damagePerRage * sunderRageCost
            comparisons[#comparisons + 1] = { key = abilityKey, value = compareValue }
            highestCompareValue = math.max(highestCompareValue, compareValue)
        else
            self.compareIndicators[abilityKey].frame:Hide()
        end
    end

    if self.colorShiftEnabled and #comparisons > 0 then
        local colorCurve = createComparisonColorCurve(
            highestCompareValue,
            maxValue,
            self.aboveThresholdColor,
            self.belowThresholdColor
        )
        local color = UnitHealthPercent("target", true, colorCurve)
        self.frame:GetStatusBarTexture():SetVertexColor(color:GetRGB())
    else
        self.frame:SetStatusBarColor(self.solidColor:GetRGB())
    end

    local rangeMax = maxValue
    if #comparisons > 0 then
        local comparisonRangeMax = math.min(maxValue, highestCompareValue * 1.66)
        rangeMax = math.max(highestCompareValue, comparisonRangeMax)
    end
    self.text:SetText(text)
    self.frame:SetMinMaxValues(0, rangeMax)
    self.frame:SetValue(value)

    for _, comparison in ipairs(comparisons) do
        local indicator = self.compareIndicators[comparison.key]
        local position = math.max(
            1,
            math.min(self.width - 1, comparison.value / rangeMax * self.width)
        )
        indicator.frame:ClearAllPoints()
        indicator.frame:SetPoint("CENTER", self.frame, "LEFT", position, 0)
        indicator.icon:ClearAllPoints()
        indicator.icon:SetPoint("BOTTOM", indicator.frame, "TOP", 0, 2)
        local spellID = compareAbilities[comparison.key].spellID
        indicator.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
        indicator.frame:Show()
    end
end

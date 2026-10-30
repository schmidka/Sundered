Sunderer = LibStub("AceAddon-3.0"):NewAddon("Sunderer", "AceEvent-3.0", "AceConsole-3.0")
Sunderer.callbacks = LibStub("CallbackHandler-1.0"):New(Sunderer)

local Options   = nil
local Abilities = nil
local Icon      = nil
local Bar       = nil

-- Configure Blizzard's localized number abbreviations for values up to 100K.
-- The 10K breakpoint keeps about three significant digits; the zero
-- breakpoint avoids showing fractional values below one.
local numberAbbreviationOptions = {
    breakpointData = {},
}
for _, data in ipairs(C_StringUtil.GetDefaultAbbreviationBreakpoints()) do
    if data.breakpoint >= 1000 and data.breakpoint <= 100000 then
        local breakpoint = {
            breakpoint = data.breakpoint,
            abbreviation = data.abbreviation,
            significandDivisor = data.significandDivisor,
            fractionDivisor = data.fractionDivisor,
            abbreviationIsGlobal = data.abbreviationIsGlobal,
        }
        if data.breakpoint == 10000 then
            breakpoint.significandDivisor = 100
            breakpoint.fractionDivisor = 10
        end
        table.insert(numberAbbreviationOptions.breakpointData, breakpoint)
    end
end
table.insert(numberAbbreviationOptions.breakpointData, {
    breakpoint = 0,
    abbreviation = "",
    significandDivisor = 1,
    fractionDivisor = 1,
    abbreviationIsGlobal = false,
})

function Sunderer:OnInitialize()
    Options = self:GetModule("Options")
    Abilities = self:GetModule("Abilities")
    Icon = self:GetModule("Icon")
    Bar = self:GetModule("Bar")

    self:RegisterChatCommand("sunderer", "ChatCommand")

    self.displayFrame = CreateFrame("Frame", "SundererDisplay", UIParent)
    self.displayFrame:SetSize(32, 32)
    self.displayFrame:SetPoint("CENTER")
    self.displayFrame:SetMovable(true)
    self.displayFrame:SetClampedToScreen(true)

    Icon:Initialize(self.displayFrame)
    Bar:Initialize(self.displayFrame)
end

function Sunderer:UpdateSetting(event, key, value)
    -- Ignore parameters, just apply all the settings
    self:ApplyOptions()
    self:Update()
end

function Sunderer:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("UNIT_HEALTH", "Update")
    Options.RegisterCallback(self, "Sunderer_SETTING_CHANGED", "UpdateSetting")

    self:ApplyOptions()
    self:Update()
end

function Sunderer:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UNIT_HEALTH")
    Options.UnregisterCallback(self, "Sunderer_SETTING_CHANGED")
    self.displayFrame:Hide()
end

function Sunderer:ApplyOptions()
    local profile = Options:GetCurrentProfile()
    if not profile then
        return
    end

    local isBar = profile.displayMode == "BAR"
    Icon:SetShown(not isBar)
    Bar:SetShown(isBar)

    Icon:SetIconSize(profile.iconSize)
    Icon:SetTextSize(profile.textSize)
    Icon:SetFont(profile.font)
    Icon:SetTextPosition(profile.textPosition)

    Bar:SetWidth(profile.barWidth)
    Bar:SetHeight(profile.barHeight)
    Bar:SetTextSize(profile.textSize)
    Bar:SetFont(profile.font)
    Bar:SetTexture(profile.barTexture)
    Bar:SetIconPosition(profile.barIconPosition)

    if isBar then
        local iconWidth = profile.barIconPosition == "NONE" and 0 or profile.barHeight
        self.displayFrame:SetSize(profile.barWidth + iconWidth, profile.barHeight)
    else
        self.displayFrame:SetSize(profile.iconSize, profile.iconSize)
    end
end

function Sunderer:Update()
    if not self.displayFrame then
        return
    end

    if not UnitExists("target") then
        self.displayFrame:Hide()
        return
    end
    self.displayFrame:Show()

    local rank = Options:GetOption("sunderArmorRank")
    local curve = Abilities:CreateCurrentSunderArmorEHPDamageCurve(rank)
    if not curve then
        -- This shouldn't happen...
        Icon:Update("Poop")
        Bar:Update(0, "Poop", 1)
        return
    end

    local sunderEHPDamage = UnitHealthPercent("target", true, curve)
    local displayText = AbbreviateNumbers(sunderEHPDamage, numberAbbreviationOptions)
    local targetLevel = UnitLevel("target")
    local maxHealth = Abilities:GetApproximateMaxHealth("", targetLevel)
    local scale = Abilities:ComputeSunderArmorEHPDamageScaling(
        rank,
        UnitLevel("player"),
        targetLevel
    )

    Icon:Update(displayText)
    Bar:Update(sunderEHPDamage, displayText, scale * maxHealth)
end

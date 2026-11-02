-- Copyright (c) 2026 Karl Schmidt
--[[
    Sunderer

    This is the entry point and primary event handler for the addon. It owns the main addon frame and acts as to
    control and coordinate the other aspects.

    Currently it also houses some common uility functions. These may be moved in the future.
]]
Sunderer = LibStub("AceAddon-3.0"):NewAddon("Sunderer", "AceEvent-3.0", "AceConsole-3.0")
Sunderer.callbacks = LibStub("CallbackHandler-1.0"):New(Sunderer)

-- Module references initialized after AceAddon loads the addon.
local Options   = nil
local Icon      = nil
local Bar       = nil

-- Keep Blizzard's localized abbreviations while tuning the displayed precision below 100K. The 10K breakpoint keeps
-- about three significant digits; the zero breakpoint avoids showing fractional values below one.
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

-- Formats an EHP damage value using Blizzard's localized abbreviation rules.
function Sunderer:AbbreviateDamage(value)
    return AbbreviateNumbers(value, numberAbbreviationOptions)
end

-- Creates the shared display frame and initializes the icon and bar modules.
function Sunderer:OnInitialize()
    Options = self:GetModule("Options")
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

-- Reapplies display options and refreshes the current estimate after a setting changes.
function Sunderer:UpdateSetting(event, key, value)
    -- Ignore parameters, just apply all the settings
    self:ApplyOptions()
    self:Update()
end

-- Starts display updates for target, health, world, combat, and profile-setting changes.
function Sunderer:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Update")
    self:RegisterEvent("UNIT_HEALTH", "Update")
    Options.RegisterCallback(self, "Sunderer_SETTING_CHANGED", "UpdateSetting")

    self:ApplyOptions()
    self:Update()
end

-- Unregisters display events and hides the shared frame.
function Sunderer:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("UNIT_HEALTH")
    Options.UnregisterCallback(self, "Sunderer_SETTING_CHANGED")
    self.displayFrame:Hide()
end

-- Applies the active profile to both display modules and sizes their shared frame.
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
    Bar:SetColors(
        profile.barAboveThresholdColor,
        profile.barBelowThresholdColor,
        profile.barSolidColor
    )
    Bar:SetColorShiftEnabled(profile.barColorShiftEnabled)

    if isBar then
        local iconWidth = profile.barIconPosition == "NONE" and 0 or profile.barHeight
        self.displayFrame:SetSize(profile.barWidth + iconWidth, profile.barHeight)
    else
        self.displayFrame:SetSize(profile.iconSize, profile.iconSize)
    end
end

-- Returns the movable display frame to the center of the screen.
function Sunderer:ResetDisplayPosition()
    if not self.displayFrame then
        return
    end

    self.displayFrame:StopMovingOrSizing()
    self.displayFrame:ClearAllPoints()
    self.displayFrame:SetPoint("CENTER")
end

-- Hides the display without a target or refreshes both views for the current target.
function Sunderer:Update()
    if not self.displayFrame then
        return
    end

    if not UnitExists("target") then
        self.displayFrame:Hide()
        return
    end
    self.displayFrame:Show()

    Icon:Update()
    Bar:Update()
end

-- Copyright (c) 2026 Karl Schmidt
--[[
    Sundered

    This is the entry point and primary event handler for the addon. It owns the main addon frame and acts as to
    control and coordinate the other aspects.

    Currently it also houses some common uility functions. These may be moved in the future.
]]
Sundered = LibStub("AceAddon-3.0"):NewAddon("Sundered", "AceEvent-3.0", "AceConsole-3.0")
Sundered.callbacks = LibStub("CallbackHandler-1.0"):New(Sundered)

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
function Sundered:AbbreviateDamage(value)
    return AbbreviateNumbers(value, numberAbbreviationOptions)
end

-- Opens the addon options panel from the slash command.
function Sundered:ChatCommand()
    Options:Open()
end

-- Creates the shared display frame and initializes the icon and bar modules.
function Sundered:OnInitialize()
    Options = self:GetModule("Options")
    Icon = self:GetModule("Icon")
    Bar = self:GetModule("Bar")

    self:RegisterChatCommand("sundered", "ChatCommand")

    self.displayFrame = CreateFrame("Frame", "SunderedDisplay", UIParent)
    self.displayFrame:SetSize(32, 32)
    self.displayFrame:SetPoint("CENTER")
    self.displayFrame:SetMovable(true)
    self.displayFrame:SetClampedToScreen(true)

    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    Bar:Initialize(self.displayFrame)
end

-- Reapplies display options and refreshes the current estimate after a setting changes.
function Sundered:UpdateSetting(event, key, value)
    -- Ignore parameters, just apply all the settings
    self:ApplyOptions()
    self:Update()
end

-- Starts display updates for target, health, world, combat, and profile-setting changes.
function Sundered:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Update")
    self:RegisterEvent("UNIT_HEALTH", "Update")
    Options.RegisterCallback(self, "Sundered_SETTING_CHANGED", "UpdateSetting")

    self:ApplyOptions()
    self:Update()
end

-- Reapply a saved anchor when its target frame's addon becomes available.
function Sundered:OnAddonLoaded(event, addonName)
    self:ApplyDisplayPosition()
end

-- Unregisters display events and hides the shared frame.
function Sundered:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("UNIT_HEALTH")
    self:UnregisterEvent("ADDON_LOADED")
    Options.UnregisterCallback(self, "Sundered_SETTING_CHANGED")
    self.displayFrame:Hide()
end

-- Applies the active profile to the bar and icon modules and sizes their shared frame.
function Sundered:ApplyOptions()
    local profile = Options:GetCurrentProfile()
    if not profile then
        return
    end

    Bar:SetShown(true)

    Icon:SetFont(profile.font)
    Icon:SetCooldownEnabled(profile.cooldownDisplayEnabled)
    Icon:SetWarningGlowEnabled(profile.warningGlowEnabled)
    Icon:SetWarningGlowTexture(profile.warningGlowTexture)
    Icon:SetWarningGlowThreshold(profile.warningGlowThreshold)

    Bar:SetIconSize(profile.iconSize)
    Bar:SetWidth(profile.barWidth)
    Bar:SetHeight(profile.barHeight)
    Bar:SetFont(profile.font)
    Bar:SetTexture(profile.barTexture)
    Bar:SetIconPosition(profile.iconPosition)
    Bar:SetColors(
        profile.barAboveThresholdColor,
        profile.barBelowThresholdColor,
        profile.barSolidColor
    )
    Bar:SetColorShiftEnabled(profile.barColorShiftEnabled)

    local iconWidth = profile.iconPosition == "NONE" and 0 or profile.iconSize
    self.displayFrame:SetSize(profile.barWidth + iconWidth, profile.barHeight)
    self.displayFrame:SetMovable(not profile.locked)
    self:ApplyDisplayPosition()
    Icon:Update()
end

-- Resolves a named anchor point to its screen coordinates for saving drag offsets.
local function getPointCoordinates(frame, point)
    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom or not width or not height then
        return nil
    end

    local x = left + (point:find("LEFT") and 0 or point:find("RIGHT") and width or width / 2)
    local y = bottom + (point:find("BOTTOM") and 0 or point:find("TOP") and height or height / 2)
    return x, y
end

-- Applies the profile's anchor, falling back visibly if a saved target is unavailable.
function Sundered:ApplyDisplayPosition()
    local profile = Options:GetCurrentProfile()
    if not profile or not self.displayFrame then
        return
    end

    local frameName = profile.anchorFrame or "UIParent"
    local relativeFrame = _G[frameName]
    if not relativeFrame then
        if self.missingAnchorFrame ~= frameName then
            self:Print("Anchor frame " .. frameName .. " is not loaded; using UIParent until it is available.")
            self.missingAnchorFrame = frameName
        end
        relativeFrame = UIParent
    else
        self.missingAnchorFrame = nil
    end

    self.displayFrame:ClearAllPoints()
    self.displayFrame:SetPoint(
        profile.framePoint or "CENTER",
        relativeFrame,
        profile.relativePoint or "CENTER",
        profile.xOffset or 0,
        profile.yOffset or 0
    )
end

-- Saves the moved frame's current offsets relative to the configured anchor.
function Sundered:SaveDisplayPosition()
    local profile = Options:GetCurrentProfile()
    local relativeFrame = profile and _G[profile.anchorFrame or "UIParent"]
    if not relativeFrame then
        self:Print("Could not save position because the selected anchor frame is unavailable.")
        return
    end

    local displayX, displayY = getPointCoordinates(self.displayFrame, profile.framePoint)
    local anchorX, anchorY = getPointCoordinates(relativeFrame, profile.relativePoint)
    if not displayX or not displayY or not anchorX or not anchorY then
        self:Print("Could not save position because Sundered or its anchor has no valid geometry.")
        return
    end

    Options:SetAnchor(
        profile.anchorFrame,
        profile.framePoint,
        profile.relativePoint,
        math.floor(displayX - anchorX + 0.5),
        math.floor(displayY - anchorY + 0.5)
    )
end

-- Returns the display to the center of UIParent.
function Sundered:ResetDisplayPosition()
    if not self.displayFrame then
        return
    end

    self.displayFrame:StopMovingOrSizing()
    Options:SetAnchor("UIParent", "CENTER", "CENTER", 0, 0)
end

-- Hides the display without a target or refreshes both views for the current target.
function Sundered:Update()
    if not self.displayFrame then
        return
    end

    if not UnitExists("target") then
        self.displayFrame:Hide()
        return
    end
    self.displayFrame:Show()

    Bar:Update()
end

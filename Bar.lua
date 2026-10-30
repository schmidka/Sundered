-- Module to display estimated Sunder Armor damage as a bar

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Bar = Addon:NewModule("Bar")
local LSM = LibStub("LibSharedMedia-3.0")

-- Creates the draggable status bar, optional icon, and text.
function Bar:Initialize(parent)
    self.parent = parent
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

-- Updates the bar range, value, and displayed text.
function Bar:Update(value, text, maxValue)
    self.text:SetText(text)
    self.frame:SetMinMaxValues(0, maxValue)
    self.frame:SetValue(value)
end

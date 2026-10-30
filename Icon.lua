-- Module to display estimated Sunder Armor damage as an icon

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")
local Icon = Addon:NewModule("Icon")
local LSM = LibStub("LibSharedMedia-3.0")

-- Creates the draggable icon and its text.
function Icon:Initialize(parent)
    self.parent = parent
    self.frame = CreateFrame("Button", "SundererIcon", parent)

    local texture = self.frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.frame:SetPoint("CENTER", parent, "CENTER")
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
    end)

    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

-- Shows or hides the icon display.
function Icon:SetShown(shown)
    self.frame:SetShown(shown)
end

-- Sets the icon's width and height.
function Icon:SetIconSize(size)
    self.frame:SetSize(size, size)
end

-- Sets the displayed text size.
function Icon:SetTextSize(size)
    local fontPath, _, fontFlags = self.text:GetFont()
    self.text:SetFont(fontPath, size, fontFlags)
end

-- Sets the displayed text font from LibSharedMedia.
function Icon:SetFont(font)
    local _, size, fontFlags = self.text:GetFont()
    self.text:SetFont(LSM:Fetch("font", font), size, fontFlags)
end

-- Positions and aligns the text relative to the icon.
function Icon:SetTextPosition(position)
    self.text:ClearAllPoints()

    if position == "BELOW" then
        self.text:SetPoint("TOP", self.frame, "BOTTOM", 0, -2)
        self.text:SetJustifyH("CENTER")
        self.text:SetJustifyV("TOP")
        return
    end

    local horizontal = position:match("LEFT$") and "LEFT"
        or position:match("RIGHT$") and "RIGHT"
        or "CENTER"
    local vertical = position:match("^TOP") and "TOP"
        or position:match("^BOTTOM") and "BOTTOM"
        or "MIDDLE"

    self.text:SetPoint(position, self.frame, position)
    self.text:SetJustifyH(horizontal)
    self.text:SetJustifyV(vertical)
end

-- Updates the displayed text.
function Icon:Update(text)
    self.text:SetText(text)
end

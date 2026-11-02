-- Copyright (c) 2026 Karl Schmidt
--[[
    Icon

    Displays estimated Sunder Armor effective-health damage as text over a draggable Sunder Armor icon.
    
    This is currently not a very useful display mode. The longer term intent is to add more text-based indicators to the icon to
    make it a denser alternative to the bar mode, but for now it's a secondary concern.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sundered")
local Icon = Addon:NewModule("Icon")
local LSM = LibStub("LibSharedMedia-3.0")
local sunderArmorSpellName = "Sunder Armor"

-- Curvie mapping target health percentage to the estimated Sunder EHP damage at that health.
local function createSunderDamageCurve(abilities, mobHealthCache, targetLevel, attackerLevel)
    local maxHealth = mobHealthCache:EstimateTargetMaxHealth()
    local scale = abilities:ComputeExpectedAbilityEHPDamageScaling(
        sunderArmorSpellName, attackerLevel, targetLevel
    )
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, 0)
    curve:AddPoint(1, scale * maxHealth)
    return curve
end

-- Creates the draggable icon and its text.
function Icon:Initialize(parent)
    self.parent = parent
    self.abilities = Addon:GetModule("Abilities")
    self.mobHealthCache = Addon:GetModule("MobHealthCache")
    self.frame = CreateFrame("Button", "SunderedIcon", parent)

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

    -- "Below" is outside the icon; all other choices use matching frame anchors.
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
function Icon:Update()
    -- Rebuild the target-specific curve whenever target stats or settings change.
    local targetLevel = UnitLevel("target")
    local attackerLevel = UnitLevel("player")
    local curve = createSunderDamageCurve(
        self.abilities, self.mobHealthCache, targetLevel, attackerLevel
    )
    local value = UnitHealthPercent("target", true, curve)
    self.text:SetText(Addon:AbbreviateDamage(value))
end

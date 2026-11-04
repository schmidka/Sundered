-- Copyright (c) 2026 Karl Schmidt
--[[
    Icon

    Displays the target's Sunder Armor stack count and duration.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sundered")
local Icon = Addon:NewModule("Icon", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local sunderArmorSpellName = "Sunder Armor"
local textHeightRatio = 0.85
local warningBorderTextures = {
    IconAlert = {
        path = "Interface\\SpellActivationOverlay\\IconAlert",
        coordinates = { 0.0078125, 0.5078125, 0.27734375, 0.52734375 },
        padding = 0.3125,
    },
    IconAlertAnts = {
        path = "Interface\\SpellActivationOverlay\\IconAlertAnts",
        padding = 0.125,
    },
}

local function applyWarningBorderSize(self)
    local padding = self.frame:GetWidth() * (self.warningBorderPadding or 0.125)
    self.warningBorder:ClearAllPoints()
    self.warningBorder:SetPoint("TOPLEFT", self.frame, -padding, padding)
    self.warningBorder:SetPoint("BOTTOMRIGHT", self.frame, padding, -padding)
end

local function createWarningAlphaCurve(threshold)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, 1)
    curve:AddPoint(threshold - 0.01, 1)
    curve:AddPoint(threshold, 0)
    return curve
end

local function createStackColorCurve()
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, CreateColor(1, 1, 1, 1))
    curve:AddPoint(4, CreateColor(1, 1, 1, 1))
    curve:AddPoint(5, CreateColor(1, 0, 0, 1))
    return curve
end

-- Creates the icon and its stack-count label.
function Icon:Initialize(parent)
    self.frame = CreateFrame("Button", nil, parent)
    self.frame:SetSize(20, 20)
    self.frame:Hide()

    self.icon = self.frame:CreateTexture(nil, "ARTWORK")
    self.icon:SetAllPoints()
    self.icon:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.cooldown = CreateFrame("Cooldown", nil, self.frame, "CooldownFrameTemplate")
    self.cooldown:SetAllPoints()
    self.cooldown:SetDrawSwipe(true)
    self.cooldown:SetDrawEdge(false)
    self.cooldown:SetDrawBling(false)
    self.cooldown:SetHideCountdownNumbers(true)

    self.warningBorder = self.frame:CreateTexture(nil, "OVERLAY")
    self.warningBorder:SetAllPoints()
    self.warningBorder:SetBlendMode("ADD")
    self.warningBorder:Hide()

    self.textFrame = CreateFrame("Frame", nil, self.frame)
    self.textFrame:SetAllPoints()
    self.textFrame:SetFrameLevel(self.frame:GetFrameLevel() + 2)
    self.text = self.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.text:SetPoint("CENTER")
    self.stackColorCurve = createStackColorCurve()

    local masque = LibStub("Masque", true)
    if masque then
        self.masqueGroup = masque:Group("Sundered", "Sunder Icon")
        self.masqueGroup:AddButton(self.frame, {
            Icon = self.icon,
            Cooldown = self.cooldown,
            Count = self.text,
        }, "Debuff")
    end
end

-- Sets the icon's size.
function Icon:SetIconSize(size)
    self.frame:SetSize(size, size)
    if self.masqueGroup then
        self.masqueGroup:SetFrameSize(size, size, self.frame, true)
    end
    applyWarningBorderSize(self)
    self:ApplyTextFont()
end

function Icon:SetCooldownEnabled(enabled)
    self.cooldownEnabled = enabled
    self:ApplyAuraVisuals()
end

function Icon:SetWarningGlowEnabled(enabled)
    self.warningGlowEnabled = enabled
    self:ApplyAuraVisuals()
end

function Icon:SetWarningGlowTexture(textureName)
    local texture = warningBorderTextures[textureName] or warningBorderTextures.IconAlertAnts
    self.warningBorderPadding = texture.padding
    self.warningBorder:SetTexture(texture.path)
    if texture.coordinates then
        self.warningBorder:SetTexCoord(unpack(texture.coordinates))
    else
        self.warningBorder:SetTexCoord(0, 1, 0, 1)
    end
    applyWarningBorderSize(self)
end

function Icon:SetWarningGlowThreshold(threshold)
    self.warningAlphaCurve = createWarningAlphaCurve(threshold)
    self:UpdateWarningGlow()
end

function Icon:SetShown(shown)
    self.frame:SetShown(shown)
end

function Icon:ApplyTextFont()
    if not self.fontPath then
        return
    end

    local _, _, fontFlags = self.text:GetFont()
    local fontSize = math.floor(self.frame:GetHeight() * textHeightRatio + 0.5)
    self.text:SetFont(self.fontPath, fontSize, fontFlags)
end

-- Sets the stack-count font from LibSharedMedia.
function Icon:SetFont(font)
    self.fontPath = LSM:Fetch("font", font)
    self:ApplyTextFont()
end

-- Positions the icon beside its bar.
function Icon:SetBarAnchor(position, bar)
    self.frame:ClearAllPoints()
    if position == "LEFT" then
        self.frame:SetPoint("RIGHT", bar, "LEFT")
    elseif position == "RIGHT" then
        self.frame:SetPoint("LEFT", bar, "RIGHT")
    end
end

function Icon:ClearAuraDuration()
    self.auraDuration = nil
    self.frame:SetScript("OnUpdate", nil)
    self.cooldown:Hide()
    self.warningBorder:Hide()
end

function Icon:UpdateWarningGlow()
    if not self.auraDuration or not self.warningGlowEnabled then
        return
    end

    -- Evaluate secret remaining duration through a curve instead of branching on it.
    local alpha = self.auraDuration:EvaluateRemainingDuration(self.warningAlphaCurve)
    self.warningBorder:SetAlpha(alpha)
end

-- Updates the cooldown swipe and secret-safe warning alpha for the current aura.
function Icon:ApplyAuraVisuals()
    if not self.auraDuration then
        self.cooldown:Hide()
        self.warningBorder:Hide()
        self.frame:SetScript("OnUpdate", nil)
        return
    end

    if self.cooldownEnabled then
        self.cooldown:SetCooldownFromDurationObject(self.auraDuration)
        self.cooldown:Show()
    else
        self.cooldown:Hide()
    end

    if self.warningGlowEnabled then
        self.warningBorder:Show()
        self:UpdateWarningGlow()
        self.frame:SetScript("OnUpdate", function(_, elapsed)
            self.warningUpdateElapsed = (self.warningUpdateElapsed or 0) + elapsed
            if self.warningUpdateElapsed >= 0.1 then
                self.warningUpdateElapsed = 0
                self:UpdateWarningGlow()
            end
        end)
    else
        self.warningBorder:Hide()
        self.frame:SetScript("OnUpdate", nil)
    end
end

-- Displays the stack count using Blizzard's secret-safe aura display APIs.
function Icon:Update()
    local aura
    if UnitExists("target") then
        aura = C_UnitAuras.GetAuraDataBySpellName("target", sunderArmorSpellName, "HARMFUL")
    end
    if not aura then
        self:ClearAuraDuration()
        self.text:SetText("")
        return
    end

    if self.cooldownEnabled or self.warningGlowEnabled then
        self.auraDuration = C_UnitAuras.GetAuraDuration("target", aura.auraInstanceID)
    else
        self.auraDuration = nil
    end
    self:ApplyAuraVisuals()

    self.text:SetText(C_UnitAuras.GetAuraApplicationDisplayCount("target", aura.auraInstanceID, 1))
    local color = self.stackColorCurve:Evaluate(aura.applications)
    self.text:SetTextColor(color:GetRGB())
end

function Icon:OnUnitAura(event, unit)
    if unit == "target" then
        self:Update()
    end
end

-- Keeps stack information current as the target or its auras change.
function Icon:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:Update()
end

function Icon:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UNIT_AURA")
    self:ClearAuraDuration()
end

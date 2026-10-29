-- Addon 
Sunderer = LibStub("AceAddon-3.0"):NewAddon("Sunderer", "AceEvent-3.0", "AceConsole-3.0")
Sunderer.callbacks = LibStub("CallbackHandler-1.0"):New(Sunderer)

-- Modules
local Options           = nil
local Abilities         = nil
local LSM               = LibStub("LibSharedMedia-3.0")

-- Display state
local icon      = nil
local iconText = nil
local bar       = nil
local barText   = nil

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

-- Initialization. Called once on UI load.
function Sunderer:OnInitialize()
	-- Get modules
	Options = self:GetModule("Options")
    Abilities = self:GetModule("Abilities")

    -- Register option command, if ever we use it
	self:RegisterChatCommand("sunderer", "ChatCommand")

    -- Create a shared container so either display can be moved.
    self.displayFrame = CreateFrame("Frame", "SundererDisplay", UIParent)
    self.displayFrame:SetPoint("CENTER")
    self.displayFrame:SetMovable(true)
    self.displayFrame:SetClampedToScreen(true)

    -- Init the icon display.
    self.icon = CreateFrame("Button", "SundererIcon", self.displayFrame)

    local texture = self.icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.icon:SetSize(32, 32)
    self.icon:SetPoint("CENTER", self.displayFrame, "CENTER")
    self.icon:EnableMouse(true)
    self.icon:RegisterForDrag("LeftButton")
    self.icon:SetScript("OnDragStart", function()
        self.displayFrame:StartMoving()
    end)
    self.icon:SetScript("OnDragStop", function()
        self.displayFrame:StopMovingOrSizing()
    end)

    self.iconText = self.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    -- Init the bar display.
    self.bar = CreateFrame("StatusBar", nil, self.displayFrame)
    self.bar:SetStatusBarTexture(LSM:Fetch("statusbar", "Blizzard"))
    self.bar:SetStatusBarColor(0.75, 0.25, 0.25)
    self.bar:SetMinMaxValues(0, 1)
    self.bar:SetValue(0)
    self.bar:EnableMouse(true)
    self.bar:RegisterForDrag("LeftButton")
    self.bar:SetScript("OnDragStart", function()
        self.displayFrame:StartMoving()
    end)
    self.bar:SetScript("OnDragStop", function()
        self.displayFrame:StopMovingOrSizing()
    end)

    local barBackground = self.bar:CreateTexture(nil, "BACKGROUND")
    barBackground:SetAllPoints()
    barBackground:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    self.barIcon = self.bar:CreateTexture(nil, "OVERLAY")
    self.barIcon:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")

    self.barText = self.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.barText:SetPoint("CENTER")

    self.icon:Hide()
    self.bar:Hide()
end

function Sunderer:UpdateSetting(event, key, value)
    -- ignore exactly what setting was changed and just apply everything
    self:ApplyOptions()
    self:UpdateArmor()
end

function Sunderer:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateArmor")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArmor")
    self:RegisterEvent("UNIT_HEALTH", "UpdateArmor")
	Options.RegisterCallback(self, "Sunderer_SETTING_CHANGED", "UpdateSetting")

    -- Initialize the selected display and its text.
    self:ApplyOptions()
    self:UpdateArmor()
    self.displayFrame:Show()
end

function Sunderer:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UNIT_HEALTH")
	Options.UnregisterCallback(self, "Sunderer_SETTING_CHANGED")
    self.displayFrame:Hide()
end

function Sunderer:ApplyOptions()
    -- Try to load the current profile. If the options aren't initalized then this may return nil.
    local profile = Options:GetCurrentProfile()
    if not profile then
        return
    end

    -- Set the selected display's size and layout.
    local isBar = profile.displayMode == "BAR"
    self.icon:SetShown(not isBar)
    self.bar:SetShown(isBar)

    local _, _, fontFlags = self.iconText:GetFont()
    local fontPath = LSM:Fetch("font", profile.font)
    self.iconText:SetFont(fontPath, profile.textSize, fontFlags)
    self.barText:SetFont(fontPath, profile.textSize, fontFlags)
    self.iconText:ClearAllPoints()

    if isBar then
        local width = profile.barWidth
        local height = profile.barHeight
        local iconPosition = profile.barIconPosition
        local hasIcon = iconPosition ~= "NONE"

        self.bar:SetStatusBarTexture(LSM:Fetch("statusbar", profile.barTexture))
        self.bar:SetSize(width, height)
        self.bar:ClearAllPoints()
        if iconPosition == "LEFT" then
            self.bar:SetPoint("CENTER", self.displayFrame, "CENTER", height / 2, 0)
            self.barIcon:ClearAllPoints()
            self.barIcon:SetPoint("RIGHT", self.bar, "LEFT")
        elseif iconPosition == "RIGHT" then
            self.bar:SetPoint("CENTER", self.displayFrame, "CENTER", -height / 2, 0)
            self.barIcon:ClearAllPoints()
            self.barIcon:SetPoint("LEFT", self.bar, "RIGHT")
        else
            self.bar:SetPoint("CENTER", self.displayFrame, "CENTER")
        end
        self.barIcon:SetSize(height, height)
        if hasIcon then
            self.barIcon:Show()
        else
            self.barIcon:Hide()
        end
        self.displayFrame:SetSize(width + (hasIcon and height or 0), height)
        return
    end

    self.icon:SetSize(profile.iconSize, profile.iconSize)
    self.displayFrame:SetSize(profile.iconSize, profile.iconSize)

    local position = profile.textPosition
    if position == "BELOW" then
        self.iconText:SetPoint("TOP", self.icon, "BOTTOM", 0, -2)
        self.iconText:SetJustifyH("CENTER")
        self.iconText:SetJustifyV("TOP")
        return
    end
    local horizontal = position:match("LEFT$") and "LEFT"
        or position:match("RIGHT$") and "RIGHT"
        or "CENTER"
    local vertical = position:match("^TOP") and "TOP"
        or position:match("^BOTTOM") and "BOTTOM"
        or "MIDDLE"

    self.iconText:SetPoint(position, self.icon, position)
    self.iconText:SetJustifyH(horizontal)
    self.iconText:SetJustifyV(vertical)
end

function Sunderer:UpdateArmor()
    if not self.iconText then
        return
    end

    local curve = Abilities:CreateCurrentSunderArmorEHPDamageCurve(Options:GetOption("sunderArmorRank"))
    if not curve then
        self.iconText:SetText("Poop")
        self.barText:SetText("Poop")
        self.bar:SetValue(0)
        return
    end

    local rank = Options:GetOption("sunderArmorRank")
    local sunderEHPDamage = UnitHealthPercent("target", true, curve)
    local displayText = AbbreviateNumbers(sunderEHPDamage, numberAbbreviationOptions)
    self.iconText:SetText(displayText)
    self.barText:SetText(displayText)

    local targetLevel = UnitLevel("target")
    local maxHealth = Abilities:GetApproximateMaxHealth("", targetLevel)
    local scale = Abilities:ComputeSunderArmorEHPDamageScaling(
        rank,
        UnitLevel("player"),
        targetLevel
    )
    self.bar:SetMinMaxValues(0, scale * maxHealth)
    self.bar:SetValue(sunderEHPDamage)
end

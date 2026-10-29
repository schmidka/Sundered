-- Addon 
Sunderer = LibStub("AceAddon-3.0"):NewAddon("Sunderer", "AceEvent-3.0", "AceConsole-3.0")
Sunderer.callbacks = LibStub("CallbackHandler-1.0"):New(Sunderer)

-- Modules
local Options           = nil
local Abilities         = nil

-- Display state
local icon      = nil
local armorText = nil

-- Initialization. Called once on UI load.
function Sunderer:OnInitialize()
	-- Get modules
	Options = self:GetModule("Options")
    Abilities = self:GetModule("Abilities")

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
    self:UpdateArmor()
end

function Sunderer:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateArmor")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArmor")
    self:RegisterEvent("UNIT_HEALTH", "UpdateArmor")
	Options.RegisterCallback(self, "Sunderer_SETTING_CHANGED", "UpdateSetting")

    -- Initialize our icon and text
    self:ApplyOptions()
    self:UpdateArmor()
    self.icon:Show()
end

function Sunderer:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UNIT_HEALTH")
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
    self.armorText:SetJustifyH(horizontal)
    self.armorText:SetJustifyV(vertical)
end

function Sunderer:UpdateArmor()
    if not self.armorText then
        return
    end

    local curve = Abilities:CreateCurrentSunderArmorEHPDamageCurve(Options:GetOption("sunderArmorRank"))
    if not curve then
        self.armorText:SetText("Poop")
        return
    end

    local sunderEHPDamage = UnitHealthPercent("target", true, curve)
    self.armorText:SetText(sunderEHPDamage)
end

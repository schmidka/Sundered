Sunderer = {
    -- Saved icon position: { point, relativePoint, x, y } (relative to UIParent)
    iconPoint = nil,
}

local ICON_TEXTURE = "Interface\\Icons\\Ability_warrior_sunderarmor"
local SPELL_ID     = 1464 -- Sunder Armor
local ICON_SIZE    = 32

local function RestorePosition(frame)
    local saved = Sunderer.iconPoint
    if saved and saved[1] then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3] or 0, saved[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function CreateIcon()
    local icon = CreateFrame("Frame", "SundererIcon", UIParent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:EnableMouse(true)

    -- Dark backing plate so the icon reads against any background
    local backdrop = icon:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints(true)
    backdrop:SetTexture(0, 0, 0, 0.6)

    local art = icon:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints(true)
    art:SetTexture(ICON_TEXTURE)

    RestorePosition(icon)

    -- Draggable
    icon:SetMovable(true)
    icon:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        Sunderer.iconPoint = { point, relativePoint, x, y }
    end)

    -- Tooltip
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink("spell:" .. SPELL_ID)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return icon
end

Sunderer.icon = CreateIcon()
print("Sunderer: icon ready.")

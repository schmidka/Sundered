local settingsVersion = 1
local defaults = {
    iconSize = 32,
    textSize = 12,
    textPosition = "CENTER",
}

if type(SundererDB) ~= "table" then
    SundererDB = {}
end

local previousVersion = tonumber(SundererDB.settingsVersion) or 0
if previousVersion < settingsVersion then
    if SundererDB.textPosition == nil and SundererDB.textAlignment ~= nil then
        SundererDB.textPosition = "BELOW"
    end
    SundererDB.settingsVersion = settingsVersion
    SundererDB.textAlignment = nil
end

local function NormalizeNumber(value, default, minimum, maximum, step)
    value = tonumber(value)
    if not value or value ~= value then
        value = default
    end

    value = math.max(minimum, math.min(maximum, value))
    return minimum + math.floor((value - minimum) / step + 0.5) * step
end

SundererDB.iconSize = NormalizeNumber(SundererDB.iconSize, defaults.iconSize, 16, 64, 2)
SundererDB.textSize = NormalizeNumber(SundererDB.textSize, defaults.textSize, 8, 24, 1)

local validPositions = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
    BELOW = true,
}

if not validPositions[SundererDB.textPosition] then
    SundererDB.textPosition = defaults.textPosition
end

local panel = CreateFrame("Frame")
panel:SetSize(600, 400)

local function CreateSlider(labelText, option, minimum, maximum, step, y)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    label:SetText(labelText)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetSize(260, 18)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    -- slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
    track:SetPoint("CENTER")
    track:SetSize(260, 4)

    local valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value)
        SundererDB[option] = value
        Sunderer.ApplyOptions(SundererDB)
    end)
    slider:SetValue(SundererDB[option])
end

CreateSlider("Icon size", "iconSize", 16, 64, 2, -32)
CreateSlider("Text size", "textSize", 8, 24, 1, -112)

local positionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -192)
positionLabel:SetText("Text position")

local positionButtons = {}
local positions = {
    { value = "TOPLEFT", label = "Top left", column = 1, row = 1 },
    { value = "TOP", label = "Top", column = 2, row = 1 },
    { value = "TOPRIGHT", label = "Top right", column = 3, row = 1 },
    { value = "LEFT", label = "Left", column = 1, row = 2 },
    { value = "CENTER", label = "Center", column = 2, row = 2 },
    { value = "RIGHT", label = "Right", column = 3, row = 2 },
    { value = "BOTTOMLEFT", label = "Bottom left", column = 1, row = 3 },
    { value = "BOTTOM", label = "Bottom", column = 2, row = 3 },
    { value = "BOTTOMRIGHT", label = "Bottom right", column = 3, row = 3 },
    { value = "BELOW", label = "Below", column = 1, row = 4 },
}

local function UpdatePositionButtons()
    for _, button in ipairs(positionButtons) do
        button:SetChecked(button.position == SundererDB.textPosition)
    end
end

for _, position in ipairs(positions) do
    local button = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    button:SetPoint(
        "TOPLEFT",
        positionLabel,
        "BOTTOMLEFT",
        (position.column - 1) * 145,
        -12 - (position.row - 1) * 34
    )
    button.position = position.value
    button:SetScript("OnClick", function(self)
        SundererDB.textPosition = self.position
        Sunderer.ApplyOptions(SundererDB)
        UpdatePositionButtons()
    end)

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    label:SetText(position.label)

    table.insert(positionButtons, button)
end

UpdatePositionButtons()
Sunderer.ApplyOptions(SundererDB)

local category = Settings.RegisterCanvasLayoutCategory(panel, "Sunderer")
Settings.RegisterAddOnCategory(category)

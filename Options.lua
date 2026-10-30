-- this addon
local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")

-- this module
local Options = Addon:NewModule("Options")
Options.callbacks = LibStub("CallbackHandler-1.0"):New(Options)

-- Ace libraries used by this module
local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceDB             = LibStub("AceDB-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")
local LSM               = LibStub("LibSharedMedia-3.0")

-- dummy value
local _

-- Default values for our options
local defaults = {
    profile = {
        displayMode = "BAR",
        iconSize = 32,
        textSize = 12,
        textPosition = "CENTER",
        font = "Friz Quadrata TT",
        barWidth = 200,
        barHeight = 20,
        barTexture = "Blizzard",
        barIconPosition = "NONE",
        barColorShiftEnabled = true,
        barAboveThresholdColor = { 0, 0.62, 0.45 },
        barBelowThresholdColor = { 0.8, 0.47, 0.65 },
        barSolidColor = { 0.75, 0.25, 0.25 },
        compareTo = "NONE",
        sunderArmorRank = 5,
        mortalStrikeRank = 4,
        slamRank = 4,
        shieldSlamRank = 4,
    },
}

-- Get the current options profile block
function Options:GetCurrentProfile()
    if self.db and self.db.profile then
	    return self.db.profile
    else 
        return nil
    end
end

local textPositions = {
    TOPLEFT = "Top left",
    TOP = "Top",
    TOPRIGHT = "Top right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom right",
    BELOW = "Below",
}

local displayModes = {
    ICON = "Icon",
    BAR = "Bar",
}

local barIconPositions = {
    NONE = "None",
    LEFT = "Left",
    RIGHT = "Right",
}

local compareToAbilities = {
    NONE = "None",
    BLOODTHIRST = "Bloodthirst",
    MORTAL_STRIKE = "Mortal Strike",
    SLAM = "Slam",
    SHIELD_SLAM = "Shield Slam",
}

local function getMediaValues(mediaType)
    local values = {}
    for _, name in ipairs(LSM:List(mediaType)) do
        values[name] = name
    end
    return values
end

local function makeBarColorOption(options, name, optionKey, order, colorShifted)
    return {
        type = "color",
        name = name,
        hasAlpha = false,
        order = order,
        disabled = function()
            return options.db.profile.displayMode ~= "BAR"
                or options.db.profile.barColorShiftEnabled ~= colorShifted
        end,
        get = function()
            return unpack(options.db.profile[optionKey])
        end,
        set = function(_, red, green, blue)
            options:SetOption(optionKey, { red, green, blue })
        end,
    }
end

function Options:SetOption(key, value)
    self.db.profile[key] = value
	self.callbacks:Fire("Sunderer" .. "_SETTING_CHANGED", key, value)
end

function Options:GetOption(key)
	return self.db.profile[key]
end

function Options:OnInitialize()
	-- init database
	self.db = AceDB:New("SundererDB", defaults, "Default")

    -- init options table
    self.options = {
        type = "group",
        name = "Sunderer",
        args = {
            display = {
                type = "group",
                name = "Display",
                order = 1,
                args = {
                    generalHeader = {
                        type = "header",
                        name = "General",
                        order = 1,
                    },
                    displayMode = {
                        type = "select",
                        name = "Display mode",
                        desc = "Choose whether to show the estimate as an icon or a bar.",
                        values = displayModes,
                        order = 2,
                        get = function()
                            return self.db.profile.displayMode
                        end,
                        set = function(_, value)
                            self:SetOption("displayMode", value)
                        end,
                    },
                    compareTo = {
                        type = "select",
                        name = "Compare To",
                        desc = "Choose an ability to compare with the Sunder Armor estimate.",
                        values = compareToAbilities,
                        order = 3,
                        get = function()
                            return self.db.profile.compareTo
                        end,
                        set = function(_, value)
                            self:SetOption("compareTo", value)
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text size",
                        desc = "Set the size of the displayed estimate.",
                        min = 8,
                        max = 24,
                        step = 1,
                        order = 4,
                        get = function()
                            return self.db.profile.textSize
                        end,
                        set = function(_, value)
                            self:SetOption("textSize", value)
                        end,
                    },
                    font = {
                        type = "select",
                        name = "Font",
                        desc = "Choose the font for the displayed estimate.",
                        values = function()
                            return getMediaValues("font")
                        end,
                        order = 5,
                        get = function()
                            return self.db.profile.font
                        end,
                        set = function(_, value)
                            self:SetOption("font", value)
                        end,
                    },
                    resetPosition = {
                        type = "execute",
                        name = "Reset display position",
                        desc = "Move the display back to the center of the screen.",
                        order = 6,
                        func = function()
                            Addon:ResetDisplayPosition()
                        end,
                    },
                    barHeader = {
                        type = "header",
                        name = "Bar",
                        order = 7,
                    },
                    barWidth = {
                        type = "range",
                        name = "Bar width",
                        desc = "Set the width of the display bar, excluding its optional icon.",
                        min = 80,
                        max = 400,
                        step = 10,
                        order = 8,
                        disabled = function()
                            return self.db.profile.displayMode ~= "BAR"
                        end,
                        get = function()
                            return self.db.profile.barWidth
                        end,
                        set = function(_, value)
                            self:SetOption("barWidth", value)
                        end,
                    },
                    barHeight = {
                        type = "range",
                        name = "Bar height",
                        desc = "Set the height of the display bar and its optional icon.",
                        min = 8,
                        max = 48,
                        step = 2,
                        order = 9,
                        disabled = function()
                            return self.db.profile.displayMode ~= "BAR"
                        end,
                        get = function()
                            return self.db.profile.barHeight
                        end,
                        set = function(_, value)
                            self:SetOption("barHeight", value)
                        end,
                    },
                    barTexture = {
                        type = "select",
                        name = "Bar texture",
                        desc = "Choose the texture used to fill the display bar.",
                        values = function()
                            return getMediaValues("statusbar")
                        end,
                        order = 10,
                        disabled = function()
                            return self.db.profile.displayMode ~= "BAR"
                        end,
                        get = function()
                            return self.db.profile.barTexture
                        end,
                        set = function(_, value)
                            self:SetOption("barTexture", value)
                        end,
                    },
                    barIconPosition = {
                        type = "select",
                        name = "Bar icon",
                        desc = "Optionally attach the Sunder Armor icon to either end of the bar.",
                        values = barIconPositions,
                        order = 11,
                        disabled = function()
                            return self.db.profile.displayMode ~= "BAR"
                        end,
                        get = function()
                            return self.db.profile.barIconPosition
                        end,
                        set = function(_, value)
                            self:SetOption("barIconPosition", value)
                        end,
                    },
                    barColorShiftEnabled = {
                        type = "toggle",
                        name = "Color shift",
                        desc = "Shift the bar color based on its value relative to Compare To.",
                        order = 12,
                        disabled = function()
                            return self.db.profile.displayMode ~= "BAR"
                        end,
                        get = function()
                            return self.db.profile.barColorShiftEnabled
                        end,
                        set = function(_, value)
                            self:SetOption("barColorShiftEnabled", value)
                        end,
                    },
                    barAboveThresholdColor = makeBarColorOption(
                        self,
                        "Above-threshold color",
                        "barAboveThresholdColor",
                        13,
                        true
                    ),
                    barBelowThresholdColor = makeBarColorOption(
                        self,
                        "Below-threshold color",
                        "barBelowThresholdColor",
                        14,
                        true
                    ),
                    barSolidColor = makeBarColorOption(
                        self,
                        "Solid bar color",
                        "barSolidColor",
                        15,
                        false
                    ),
                    iconHeader = {
                        type = "header",
                        name = "Icon",
                        order = 16,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon size",
                        desc = "Set the icon width and height.",
                        min = 16,
                        max = 64,
                        step = 2,
                        order = 17,
                        disabled = function()
                            return self.db.profile.displayMode ~= "ICON"
                        end,
                        get = function()
                            return self.db.profile.iconSize
                        end,
                        set = function(_, value)
                            self:SetOption("iconSize", value)
                        end,
                    },
                    textPosition = {
                        type = "select",
                        name = "Text position",
                        desc = "Choose an attachment point on the icon or center the text below it.",
                        values = textPositions,
                        order = 18,
                        disabled = function()
                            return self.db.profile.displayMode ~= "ICON"
                        end,
                        get = function()
                            return self.db.profile.textPosition
                        end,
                        set = function(_, value)
                            self:SetOption("textPosition", value)
                        end,
                    },
                },
            },
            abilities = {
                type = "group",
                name = "Abilities",
                order = 2,
                args = {
                    sunderArmorRank = {
                        type = "range",
                        name = "Sunder Armor rank",
                        desc = "Set the highest rank of Sunder Armor available to your character.",
                        min = 1,
                        max = 5,
                        step = 1,
                        order = 1,
                        get = function()
                            return self.db.profile.sunderArmorRank
                        end,
                        set = function(_, value)
                            self:SetOption("sunderArmorRank", value)
                        end,
                    },
                    mortalStrikeRank = {
                        type = "range",
                        name = "Mortal Strike rank",
                        desc = "Set the highest rank of Mortal Strike available to your character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = 2,
                        get = function()
                            return self.db.profile.mortalStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("mortalStrikeRank", value)
                        end,
                    },
                    slamRank = {
                        type = "range",
                        name = "Slam rank",
                        desc = "Set the highest rank of Slam available to your character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = 3,
                        get = function()
                            return self.db.profile.slamRank
                        end,
                        set = function(_, value)
                            self:SetOption("slamRank", value)
                        end,
                    },
                    shieldSlamRank = {
                        type = "range",
                        name = "Shield Slam rank",
                        desc = "Set the highest rank of Shield Slam available to your character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = 4,
                        get = function()
                            return self.db.profile.shieldSlamRank
                        end,
                        set = function(_, value)
                            self:SetOption("shieldSlamRank", value)
                        end,
                    },
                },
            },
        },
    }

	-- profile support
	self.options.args.profile = LibStub:GetLibrary("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.options.args.profile.order = 3
    self.db.RegisterCallback(self, "OnProfileChanged", self.OnProfileChanged)
    self.db.RegisterCallback(self, "OnProfileCopied", self.OnProfileChanged)
    self.db.RegisterCallback(self, "OnProfileReset", self.OnProfileChanged)

    -- add options to ace config and the game ui
	AceConfig:RegisterOptionsTable("Sunderer", self.options)
	AceConfigDialog:AddToBlizOptions("Sunderer")
end

function Options:OnEnable()
end

function Options:OnDisable()
end

function Options:OnProfileChanged(event, database, newProfileKey)
	self.db.profile = database.profile
	Addon:ApplyOptions()
end

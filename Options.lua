-- this addon
local Addon = LibStub("AceAddon-3.0"):GetAddon("Sunderer")

-- this module
local Options = Addon:NewModule("Options")
Options.callbacks = LibStub("CallbackHandler-1.0"):New(Options)

-- Ace libraries used by this module
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceDB             = LibStub("AceDB-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")

-- dummy value
local _

-- Default values for our options
local defaults = {
    profile = {
        iconSize = 32,
        textSize = 12,
        textPosition = "CENTER",
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
                    iconSize = {
                        type = "range",
                        name = "Icon size",
                        desc = "Set the icon width and height.",
                        min = 16,
                        max = 64,
                        step = 2,
                        order = 1,
                        get = function()
                            return self.db.profile.iconSize
                        end,
                        set = function(_, value)
                            self:SetOption("iconSize", value)
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text size",
                        desc = "Set the size of the armor text.",
                        min = 8,
                        max = 24,
                        step = 1,
                        order = 2,
                        get = function()
                            return self.db.profile.textSize
                        end,
                        set = function(_, value)
                            self:SetOption("textSize", value)
                        end,
                    },
                    textPosition = {
                        type = "select",
                        name = "Text position",
                        desc = "Choose an attachment point on the icon or center the text below it.",
                        values = textPositions,
                        order = 3,
                        get = function()
                            return self.db.profile.textPosition
                        end,
                        set = function(_, value)
                            self:SetOption("textPosition", value)
                        end,
                    },
                },
            },
        },
    }

	-- profile support
	self.options.args.profile = LibStub:GetLibrary("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.options.args.profile.order = 2
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

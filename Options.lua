-- Copyright (c) 2026 Karl Schmidt
--[[
    Options

    AceConfig interface. Handles the ace options UI set up through the options table, plus the logic around user 
    profiles and SavedVariables store/load of the assorted options.

    Much of this project is written with the help of ol' Slopsy, although I like to think my masters in CS and 15
    years as a software engineer has made me a competent meatspace assistant to my AI overlord. However, this part is
    especially AI-generated. No one should manually write AceConfig options tables, that's just cruel punishment.
]]

local Addon = LibStub("AceAddon-3.0"):GetAddon("Sundered")

local Options = Addon:NewModule("Options")
Options.callbacks = LibStub("CallbackHandler-1.0"):New(Options)

-- Ace libraries for configuration UI, profile persistence, and shared media.
local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceDB             = LibStub("AceDB-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")
local LSM               = LibStub("LibSharedMedia-3.0")

local _

-- Defaults for the display and Forever ability settings in each profile.
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
        sunderArmorRank = 5,
        improvedSunderArmorRank = 0,
        improvedThunderClapRank = 0,
        improvedHeroicStrikeRank = 0,
        improvedRevengeRank = 0,
        improvedRendRank = 0,
        impaleRank = 0,
        focusedRageRank = 0,
        unbridledWrathRank = 0,
        bloodthirstRank = 4,
        mortalStrikeRank = 4,
        slamRank = 5,
        shieldSlamRank = 4,
        thunderClapRank = 6,
        heroicStrikeRank = 9,
        rendRank = 7,
        revengeRank = 6,
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

-- Text anchors presented by the icon text-position selector.
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

-- Display modes presented by the display selector.
local displayModes = {
    ICON = "Icon",
    BAR = "Bar",
}

-- Optional positions presented by the bar-icon selector.
local barIconPositions = {
    NONE = "None",
    LEFT = "Left",
    RIGHT = "Right",
}

local function getMediaValues(mediaType)
    -- Convert the media library's list into the key/value map AceConfig expects.
    local values = {}
    for _, name in ipairs(LSM:List(mediaType)) do
        values[name] = name
    end
    return values
end

local function makeBarColorOption(options, name, optionKey, order, colorShifted)
    -- Reuse one option definition for the two gradient colors and the solid color.
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

local function makeCompareAbilityOption(options, abilities, spellName, optionKey, order)
    -- Each comparison has its own profile-backed toggle and spell icon label.
    return {
        type = "toggle",
        name = function()
            local icon = abilities:GetAbilityTexture(spellName)
            if icon then
                return ("|T%s:16|t %s"):format(icon, spellName)
            end

            return spellName
        end,
        desc = "Show a bar marker for " .. spellName .. ".",
        order = order,
        get = function()
            return options.db.profile[optionKey]
        end,
        set = function(_, value)
            options:SetOption(optionKey, value)
        end,
    }
end

-- Saves a profile setting and notifies the addon so dependent displays can refresh.
function Options:SetOption(key, value)
    self.db.profile[key] = value
	self.callbacks:Fire("Sundered_SETTING_CHANGED", key, value)
end

-- Returns a setting from the active profile.
function Options:GetOption(key)
	return self.db.profile[key]
end

-- Initializes the profile database and registers all addon settings with AceConfig.
function Options:OnInitialize()
    local abilities = Addon:GetModule("Abilities")
    local supportedAbilities = abilities:GetSupportedAbilities()
    local comparisonCount = 0
    for _, spellName in ipairs(supportedAbilities) do
        if spellName ~= "Sunder Armor" then
            local optionKey = "compare_" .. spellName:lower():gsub("%s+", "_")
            defaults.profile[optionKey] = false
            comparisonCount = comparisonCount + 1
        end
    end

    -- Open the saved profile database before building controls that read its values.
	self.db = AceDB:New("SunderedDB", defaults, "Default")

    -- Options table describing the Options UI layout for AceConfig and AceConfigDialog.
    self.options = {
        type = "group",
        name = "Sundered",
        args = {
            -- Display options configure presentation and comparison markers.
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
                    compareHeader = {
                        type = "header",
                        name = "Compare To",
                        order = 3,
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
            -- Ability ranks and talent ranks feed the damage and Rage estimates.
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
                        order = 3,
                        get = function()
                            return self.db.profile.mortalStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("mortalStrikeRank", value)
                        end,
                    },
                    bloodthirstRank = {
                        type = "range",
                        name = "Bloodthirst rank",
                        desc = "Set the highest rank of Bloodthirst available to your character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = 2,
                        get = function()
                            return self.db.profile.bloodthirstRank
                        end,
                        set = function(_, value)
                            self:SetOption("bloodthirstRank", value)
                        end,
                    },
                    slamRank = {
                        type = "range",
                        name = "Slam rank",
                        desc = "Set the highest rank of Slam available to your character.",
                        min = 1,
                        max = 5,
                        step = 1,
                        order = 4,
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
                        order = 5,
                        get = function()
                            return self.db.profile.shieldSlamRank
                        end,
                        set = function(_, value)
                            self:SetOption("shieldSlamRank", value)
                        end,
                    },
                    thunderClapRank = {
                        type = "range",
                        name = "Thunder Clap rank",
                        desc = "Set the highest rank of Thunder Clap available to your character.",
                        min = 1,
                        max = 6,
                        step = 1,
                        order = 6,
                        get = function()
                            return self.db.profile.thunderClapRank
                        end,
                        set = function(_, value)
                            self:SetOption("thunderClapRank", value)
                        end,
                    },
                    improvedSunderArmorRank = {
                        type = "range",
                        name = "Improved Sunder Armor rank",
                        desc = "Set the rank of the talent that reduces Sunder Armor's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 7,
                        get = function()
                            return self.db.profile.improvedSunderArmorRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedSunderArmorRank", value)
                        end,
                    },
                    focusedRageRank = {
                        type = "range",
                        name = "Focused Rage rank",
                        desc = "Set the rank of the talent that reduces offensive abilities' Rage costs.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 8,
                        get = function()
                            return self.db.profile.focusedRageRank
                        end,
                        set = function(_, value)
                            self:SetOption("focusedRageRank", value)
                        end,
                    },
                    unbridledWrathRank = {
                        type = "range",
                        name = "Unbridled Wrath rank",
                        desc = "Set the rank of the talent that can reduce direct-damage abilities' Rage costs.",
                        min = 0,
                        max = 5,
                        step = 1,
                        order = 9,
                        get = function()
                            return self.db.profile.unbridledWrathRank
                        end,
                        set = function(_, value)
                            self:SetOption("unbridledWrathRank", value)
                        end,
                    },
                    improvedThunderClapRank = {
                        type = "range",
                        name = "Improved Thunder Clap rank",
                        desc = "Set the talent rank that reduces Thunder Clap's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 10,
                        get = function()
                            return self.db.profile.improvedThunderClapRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedThunderClapRank", value)
                        end,
                    },
                    improvedHeroicStrikeRank = {
                        type = "range",
                        name = "Improved Heroic Strike rank",
                        desc = "Set the talent rank that reduces Heroic Strike's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 11,
                        get = function()
                            return self.db.profile.improvedHeroicStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedHeroicStrikeRank", value)
                        end,
                    },
                    improvedRendRank = {
                        type = "range",
                        name = "Improved Rend rank",
                        desc = "Set the talent rank that increases Rend damage.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 12,
                        get = function()
                            return self.db.profile.improvedRendRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedRendRank", value)
                        end,
                    },
                    impaleRank = {
                        type = "range",
                        name = "Impale rank",
                        desc = "Set the talent rank that increases critical strike damage.",
                        min = 0,
                        max = 2,
                        step = 1,
                        order = 13,
                        get = function()
                            return self.db.profile.impaleRank
                        end,
                        set = function(_, value)
                            self:SetOption("impaleRank", value)
                        end,
                    },
                    improvedRevengeRank = {
                        type = "range",
                        name = "Improved Revenge rank",
                        desc = "Set the talent rank that increases Revenge damage.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = 14,
                        get = function()
                            return self.db.profile.improvedRevengeRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedRevengeRank", value)
                        end,
                    },
                    heroicStrikeRank = {
                        type = "range",
                        name = "Heroic Strike rank",
                        desc = "Set the highest rank of Heroic Strike available to your character.",
                        min = 1,
                        max = 9,
                        step = 1,
                        order = 15,
                        get = function()
                            return self.db.profile.heroicStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("heroicStrikeRank", value)
                        end,
                    },
                    rendRank = {
                        type = "range",
                        name = "Rend rank",
                        desc = "Set the highest rank of Rend available to your character.",
                        min = 1,
                        max = 7,
                        step = 1,
                        order = 16,
                        get = function()
                            return self.db.profile.rendRank
                        end,
                        set = function(_, value)
                            self:SetOption("rendRank", value)
                        end,
                    },
                    revengeRank = {
                        type = "range",
                        name = "Revenge rank",
                        desc = "Set the highest rank of Revenge available to your character.",
                        min = 1,
                        max = 6,
                        step = 1,
                        order = 17,
                        get = function()
                            return self.db.profile.revengeRank
                        end,
                        set = function(_, value)
                            self:SetOption("revengeRank", value)
                        end,
                    },
                },
            },
        },
    }

    local displayArgs = self.options.args.display.args
    for _, option in pairs(displayArgs) do
        if option.order and option.order >= 4 then
            option.order = option.order + comparisonCount
        end
    end

    local comparisonOrder = 4
    for _, spellName in ipairs(supportedAbilities) do
        if spellName ~= "Sunder Armor" then
            local optionKey = "compare_" .. spellName:lower():gsub("%s+", "_")
            displayArgs[optionKey] = makeCompareAbilityOption(
                self, abilities, spellName, optionKey, comparisonOrder
            )
            comparisonOrder = comparisonOrder + 1
        end
    end

    -- Add AceDB's profile controls and refresh the addon when the active profile changes.
	self.options.args.profile = LibStub:GetLibrary("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.options.args.profile.order = 3
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- add options to ace config and the game ui
	AceConfig:RegisterOptionsTable("Sundered", self.options)
	AceConfigDialog:AddToBlizOptions("Sundered")
end

function Options:OnEnable()
end

function Options:OnDisable()
end

-- Applies the profile selected or restored by AceDB.
function Options:OnProfileChanged(event, database, newProfileKey)
	self.db.profile = database.profile
	Addon:ApplyOptions()
end

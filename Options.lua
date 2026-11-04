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
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceDB             = LibStub("AceDB-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")
local LSM               = LibStub("LibSharedMedia-3.0")

local _

-- Defaults for display and ability settings in each profile.
local defaults = {
    profile = {
        locked = false,
        iconPosition = "LEFT",
        iconSize = 32,
        cooldownDisplayEnabled = true,
        warningGlowEnabled = true,
        warningGlowTexture = "IconAlertAnts",
        warningGlowThreshold = 5,
        font = "Friz Quadrata TT",
        anchorFrame = "UIParent",
        framePoint = "CENTER",
        relativePoint = "CENTER",
        xOffset = 0,
        yOffset = 0,
        barWidth = 200,
        barHeight = 20,
        barTexture = "Blizzard",
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
        cleaveRank = 5,
        rendRank = 7,
        revengeRank = 6,
    },
}

-- Get the current options profile block
function Options:GetCurrentProfile()
    return self.db and self.db.profile
end

-- Optional positions presented by the icon-position selector.
local iconPositions = {
    NONE = "None",
    LEFT = "Left",
    RIGHT = "Right",
}

local anchorPoints = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local warningGlowTextures = {
    IconAlert = "Spell Activation Glow",
    IconAlertAnts = "Marching Ants",
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
            return options.db.profile.barColorShiftEnabled ~= colorShifted
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
        desc = "Bar marker for " .. spellName .. ".",
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

function Options:SetAnchor(frameName, framePoint, relativePoint, xOffset, yOffset)
    local profile = self.db.profile
    profile.anchorFrame = frameName
    profile.framePoint = framePoint
    profile.relativePoint = relativePoint
    profile.xOffset = xOffset
    profile.yOffset = yOffset
    self.callbacks:Fire("Sundered_SETTING_CHANGED", "anchor", nil)
    AceConfigRegistry:NotifyChange("Sundered")
end

-- Returns a setting from the active profile.
function Options:GetOption(key)
	return self.db.profile[key]
end

local function isWithinFrame(frame, ancestor)
    while frame do
        if frame == ancestor then
            return true
        end
        frame = frame:GetParent()
    end
    return false
end

function Options:BeginAnchorFrameSelection()
    self.anchorPicker:RegisterEvent("GLOBAL_MOUSE_DOWN")
    Addon:Print("Click a visible named frame to anchor to it. Right-click to cancel.")
end

function Options:OnAnchorPickerMouseDown(event, button)
    if button == "RightButton" then
        self.anchorPicker:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        Addon:Print("Anchor selection cancelled.")
        return
    end
    if button ~= "LeftButton" then
        return
    end

    -- Walk each focused frame's parents to find the nearest named frame usable as an anchor.
    for _, focus in ipairs(GetMouseFoci()) do
        local frame = focus
        while frame do
            local name = frame:GetName()
            if name and _G[name] == frame and frame:IsVisible()
                and not isWithinFrame(frame, Addon.displayFrame)
            then
                self.anchorPicker:UnregisterEvent("GLOBAL_MOUSE_DOWN")
                self:SetOption("anchorFrame", name)
                Addon:Print("Anchor frame set to " .. name .. ".")
                return
            end
            if frame == UIParent then
                break
            end
            frame = frame:GetParent()
        end
    end

    Addon:Print("No visible named frame found. Try another frame, or right-click to cancel.")
end

-- Initializes the profile database and registers all addon settings with AceConfig.
function Options:OnInitialize()
    self.anchorPicker = CreateFrame("Frame")
    self.anchorPicker:SetScript("OnEvent", function(_, event, button)
        self:OnAnchorPickerMouseDown(event, button)
    end)

    local abilities = Addon:GetModule("Abilities")
    local supportedAbilities = abilities:GetSupportedAbilities()
    local comparisonCount = 0
    -- Add a saved toggle for every supported comparison ability.
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
            -- Display options configure presentation and layout.
            display = {
                type = "group",
                name = "Display",
                order = 1,
                childGroups = "tree",
                args = {
                    -- Keep the common placement and font controls directly under Display.
                    iconPosition = {
                        type = "select",
                        name = "Icon Position",
                        desc = "Position of the status icon relative to the status bar.",
                        values = iconPositions,
                        order = 1,
                        get = function()
                            return self.db.profile.iconPosition
                        end,
                        set = function(_, value)
                            self:SetOption("iconPosition", value)
                        end,
                    },
                    font = {
                        type = "select",
                        name = "Font",
                        desc = "Font used for text in Sundered.",
                        values = function()
                            return getMediaValues("font")
                        end,
                        order = 2,
                        get = function()
                            return self.db.profile.font
                        end,
                        set = function(_, value)
                            self:SetOption("font", value)
                        end,
                    },
                    position = {
                        type = "group",
                        name = "Position",
                        order = 3,
                        args = {
                            -- Group anchor and offset controls on their own page.
                            positioning = {
                                type = "group",
                                name = "Positioning",
                                inline = true,
                                order = 4,
                                args = {
                                    resetPosition = {
                                        type = "execute",
                                        name = "Reset Position",
                                        desc = "Sundered position at screen center, anchored to UIParent.",
                                        order = 1,
                                        func = function()
                                            Addon:ResetDisplayPosition()
                                        end,
                                    },
                                    locked = {
                                        type = "toggle",
                                        name = "Lock",
                                        desc = "Whether Sundered can be dragged.",
                                        order = 2,
                                        get = function()
                                            return self.db.profile.locked
                                        end,
                                        set = function(_, value)
                                            self:SetOption("locked", value)
                                        end,
                                    },
                                    currentAnchorFrame = {
                                        type = "description",
                                        name = function()
                                            return "Current Target Frame: " .. self.db.profile.anchorFrame
                                        end,
                                        order = 3,
                                    },
                                    selectAnchorFrame = {
                                        type = "execute",
                                        name = "Select Target Frame",
                                        desc = "Visible named frame used as Sundered's anchor.",
                                        order = 4,
                                        func = function()
                                            self:BeginAnchorFrameSelection()
                                        end,
                                    },
                                    framePoint = {
                                        type = "select",
                                        name = "Anchor From",
                                        desc = "Anchor point on Sundered.",
                                        values = anchorPoints,
                                        order = 5,
                                        get = function()
                                            return self.db.profile.framePoint
                                        end,
                                        set = function(_, value)
                                            self:SetOption("framePoint", value)
                                        end,
                                    },
                                    relativePoint = {
                                        type = "select",
                                        name = "Anchor To",
                                        desc = "Anchor point on the selected target frame.",
                                        values = anchorPoints,
                                        order = 6,
                                        get = function()
                                            return self.db.profile.relativePoint
                                        end,
                                        set = function(_, value)
                                            self:SetOption("relativePoint", value)
                                        end,
                                    },
                                    xOffset = {
                                        type = "input",
                                        name = "Horizontal Offset",
                                        desc = "Horizontal offset from the selected anchor point.",
                                        pattern = "^%-?%d+$",
                                        width = "half",
                                        order = 7,
                                        get = function()
                                            return tostring(self.db.profile.xOffset)
                                        end,
                                        set = function(_, value)
                                            self:SetOption("xOffset", tonumber(value))
                                        end,
                                    },
                                    yOffset = {
                                        type = "input",
                                        name = "Vertical Offset",
                                        desc = "Vertical offset from the selected anchor point.",
                                        pattern = "^%-?%d+$",
                                        width = "half",
                                        order = 8,
                                        get = function()
                                            return tostring(self.db.profile.yOffset)
                                        end,
                                        set = function(_, value)
                                            self:SetOption("yOffset", tonumber(value))
                                        end,
                                    },
                                },
                            },
                        },
                    },
                    bar = {
                        type = "group",
                        name = "Bar",
                        order = 4,
                        args = {
                            -- Bar dimensions, texture, and color behavior.
                            barWidth = {
                                type = "range",
                                name = "Bar Width",
                                desc = "Width of the status bar.",
                                min = 80,
                                max = 800,
                                step = 10,
                                order = 1,
                                get = function()
                                    return self.db.profile.barWidth
                                end,
                                set = function(_, value)
                                    self:SetOption("barWidth", value)
                                end,
                            },
                            barHeight = {
                                type = "range",
                                name = "Bar Height",
                                desc = "Height of the status bar.",
                                min = 8,
                                max = 48,
                                step = 2,
                                order = 2,
                                get = function()
                                    return self.db.profile.barHeight
                                end,
                                set = function(_, value)
                                    self:SetOption("barHeight", value)
                                end,
                            },
                            barTexture = {
                                type = "select",
                                name = "Bar Texture",
                                desc = "Texture used to fill the status bar.",
                                values = function()
                                    return getMediaValues("statusbar")
                                end,
                                order = 3,
                                get = function()
                                    return self.db.profile.barTexture
                                end,
                                set = function(_, value)
                                    self:SetOption("barTexture", value)
                                end,
                            },
                            barColorShiftEnabled = {
                                type = "toggle",
                                name = "Solid Color",
                                desc = "Solid bar color instead of threshold-based colors.",
                                order = 4,
                                get = function()
                                    return not self.db.profile.barColorShiftEnabled
                                end,
                                set = function(_, value)
                                    self:SetOption("barColorShiftEnabled", not value)
                                end,
                            },
                            barAboveThresholdColor = makeBarColorOption(
                                self,
                                "Above-Threshold Color",
                                "barAboveThresholdColor",
                                5,
                                true
                            ),
                            barBelowThresholdColor = makeBarColorOption(
                                self,
                                "Below-Threshold Color",
                                "barBelowThresholdColor",
                                6,
                                true
                            ),
                            barSolidColor = makeBarColorOption(
                                self,
                                "Solid Bar Color",
                                "barSolidColor",
                                7,
                                false
                            ),
                        },
                    },
                    icon = {
                        type = "group",
                        name = "Icon",
                        order = 5,
                        args = {
                            -- Icon size and aura-duration warning visuals.
                            iconSize = {
                                type = "range",
                                name = "Icon Size",
                                desc = "Width and height of the status icon.",
                                min = 16,
                                max = 128,
                                step = 2,
                                order = 1,
                                disabled = function()
                                    return self.db.profile.iconPosition == "NONE"
                                end,
                                get = function()
                                    return self.db.profile.iconSize
                                end,
                                set = function(_, value)
                                    self:SetOption("iconSize", value)
                                end,
                            },
                            cooldownDisplayEnabled = {
                                type = "toggle",
                                name = "Show Swipe",
                                desc = "Remaining Sunder Armor duration shown as an icon swipe.",
                                order = 2,
                                disabled = function()
                                    return self.db.profile.iconPosition == "NONE"
                                end,
                                get = function()
                                    return self.db.profile.cooldownDisplayEnabled
                                end,
                                set = function(_, value)
                                    self:SetOption("cooldownDisplayEnabled", value)
                                end,
                            },
                            warningGlowEnabled = {
                                type = "toggle",
                                name = "Enable Glow",
                                desc = "Glow shown when Sunder Armor is about to expire.",
                                order = 3,
                                disabled = function()
                                    return self.db.profile.iconPosition == "NONE"
                                end,
                                get = function()
                                    return self.db.profile.warningGlowEnabled
                                end,
                                set = function(_, value)
                                    self:SetOption("warningGlowEnabled", value)
                                end,
                            },
                            warningGlowTexture = {
                                type = "select",
                                name = "Glow Texture",
                                desc = "Overlay texture used for the low duration warning glow.",
                                values = warningGlowTextures,
                                order = 4,
                                disabled = function()
                                    return self.db.profile.iconPosition == "NONE"
                                        or not self.db.profile.warningGlowEnabled
                                end,
                                get = function()
                                    return self.db.profile.warningGlowTexture
                                end,
                                set = function(_, value)
                                    self:SetOption("warningGlowTexture", value)
                                end,
                            },
                            warningGlowThreshold = {
                                type = "input",
                                name = "Glow Threshold",
                                desc = "Remaining duration threshold for the warning glow, in seconds, with hundredths precision.",
                                pattern = "^%d+%.?%d?%d?$",
                                order = 5,
                                disabled = function()
                                    return self.db.profile.iconPosition == "NONE"
                                        or not self.db.profile.warningGlowEnabled
                                end,
                                validate = function(_, value)
                                    local threshold = tonumber(value)
                                    if not threshold or threshold < 1 or threshold > 30 then
                                        return "Glow Threshold must be between 1 and 30 seconds."
                                    end
                                    return true
                                end,
                                get = function()
                                    return tostring(self.db.profile.warningGlowThreshold)
                                end,
                                set = function(_, value)
                                    self:SetOption("warningGlowThreshold", tonumber(value))
                                end,
                            },
                        },
                    },
                },
            },
            -- Comparisons and ranks feed the damage and Rage estimates.
            abilities = {
                type = "group",
                name = "Abilities",
                order = 2,
                args = {
                    compareHeader = {
                        type = "header",
                        name = "Compare To",
                        order = 1,
                    },
                    rankHeader = {
                        type = "header",
                        name = "Rank Selectors (Temporary)",
                        order = comparisonCount + 2,
                    },
                    sunderArmorRank = {
                        type = "range",
                        name = "Sunder Armor Rank",
                        desc = "Highest Sunder Armor rank available to the character.",
                        min = 1,
                        max = 5,
                        step = 1,
                        order = comparisonCount + 3,
                        get = function()
                            return self.db.profile.sunderArmorRank
                        end,
                        set = function(_, value)
                            self:SetOption("sunderArmorRank", value)
                        end,
                    },
                    mortalStrikeRank = {
                        type = "range",
                        name = "Mortal Strike Rank",
                        desc = "Highest Mortal Strike rank available to the character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = comparisonCount + 5,
                        get = function()
                            return self.db.profile.mortalStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("mortalStrikeRank", value)
                        end,
                    },
                    bloodthirstRank = {
                        type = "range",
                        name = "Bloodthirst Rank",
                        desc = "Highest Bloodthirst rank available to the character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = comparisonCount + 4,
                        get = function()
                            return self.db.profile.bloodthirstRank
                        end,
                        set = function(_, value)
                            self:SetOption("bloodthirstRank", value)
                        end,
                    },
                    slamRank = {
                        type = "range",
                        name = "Slam Rank",
                        desc = "Highest Slam rank available to the character.",
                        min = 1,
                        max = 5,
                        step = 1,
                        order = comparisonCount + 6,
                        get = function()
                            return self.db.profile.slamRank
                        end,
                        set = function(_, value)
                            self:SetOption("slamRank", value)
                        end,
                    },
                    shieldSlamRank = {
                        type = "range",
                        name = "Shield Slam Rank",
                        desc = "Highest Shield Slam rank available to the character.",
                        min = 1,
                        max = 4,
                        step = 1,
                        order = comparisonCount + 7,
                        get = function()
                            return self.db.profile.shieldSlamRank
                        end,
                        set = function(_, value)
                            self:SetOption("shieldSlamRank", value)
                        end,
                    },
                    thunderClapRank = {
                        type = "range",
                        name = "Thunder Clap Rank",
                        desc = "Highest Thunder Clap rank available to the character.",
                        min = 1,
                        max = 6,
                        step = 1,
                        order = comparisonCount + 8,
                        get = function()
                            return self.db.profile.thunderClapRank
                        end,
                        set = function(_, value)
                            self:SetOption("thunderClapRank", value)
                        end,
                    },
                    improvedSunderArmorRank = {
                        type = "range",
                        name = "Improved Sunder Armor Rank",
                        desc = "Rank of the talent that reduces Sunder Armor's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 9,
                        get = function()
                            return self.db.profile.improvedSunderArmorRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedSunderArmorRank", value)
                        end,
                    },
                    focusedRageRank = {
                        type = "range",
                        name = "Focused Rage Rank",
                        desc = "Rank of the talent that reduces offensive abilities' Rage costs.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 10,
                        get = function()
                            return self.db.profile.focusedRageRank
                        end,
                        set = function(_, value)
                            self:SetOption("focusedRageRank", value)
                        end,
                    },
                    unbridledWrathRank = {
                        type = "range",
                        name = "Unbridled Wrath Rank",
                        desc = "Rank of the talent that can reduce direct-damage abilities' Rage costs.",
                        min = 0,
                        max = 5,
                        step = 1,
                        order = comparisonCount + 11,
                        get = function()
                            return self.db.profile.unbridledWrathRank
                        end,
                        set = function(_, value)
                            self:SetOption("unbridledWrathRank", value)
                        end,
                    },
                    improvedThunderClapRank = {
                        type = "range",
                        name = "Improved Thunder Clap Rank",
                        desc = "Talent rank that reduces Thunder Clap's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 12,
                        get = function()
                            return self.db.profile.improvedThunderClapRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedThunderClapRank", value)
                        end,
                    },
                    improvedHeroicStrikeRank = {
                        type = "range",
                        name = "Improved Heroic Strike Rank",
                        desc = "Talent rank that reduces Heroic Strike's Rage cost.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 13,
                        get = function()
                            return self.db.profile.improvedHeroicStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedHeroicStrikeRank", value)
                        end,
                    },
                    improvedRendRank = {
                        type = "range",
                        name = "Improved Rend Rank",
                        desc = "Talent rank that increases Rend damage.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 14,
                        get = function()
                            return self.db.profile.improvedRendRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedRendRank", value)
                        end,
                    },
                    impaleRank = {
                        type = "range",
                        name = "Impale Rank",
                        desc = "Talent rank that increases critical strike damage.",
                        min = 0,
                        max = 2,
                        step = 1,
                        order = comparisonCount + 15,
                        get = function()
                            return self.db.profile.impaleRank
                        end,
                        set = function(_, value)
                            self:SetOption("impaleRank", value)
                        end,
                    },
                    improvedRevengeRank = {
                        type = "range",
                        name = "Improved Revenge Rank",
                        desc = "Talent rank that increases Revenge damage.",
                        min = 0,
                        max = 3,
                        step = 1,
                        order = comparisonCount + 16,
                        get = function()
                            return self.db.profile.improvedRevengeRank
                        end,
                        set = function(_, value)
                            self:SetOption("improvedRevengeRank", value)
                        end,
                    },
                    heroicStrikeRank = {
                        type = "range",
                        name = "Heroic Strike Rank",
                        desc = "Highest Heroic Strike rank available to the character.",
                        min = 1,
                        max = 9,
                        step = 1,
                        order = comparisonCount + 17,
                        get = function()
                            return self.db.profile.heroicStrikeRank
                        end,
                        set = function(_, value)
                            self:SetOption("heroicStrikeRank", value)
                        end,
                    },
                    rendRank = {
                        type = "range",
                        name = "Rend Rank",
                        desc = "Highest Rend rank available to the character.",
                        min = 1,
                        max = 7,
                        step = 1,
                        order = comparisonCount + 18,
                        get = function()
                            return self.db.profile.rendRank
                        end,
                        set = function(_, value)
                            self:SetOption("rendRank", value)
                        end,
                    },
                    revengeRank = {
                        type = "range",
                        name = "Revenge Rank",
                        desc = "Highest Revenge rank available to the character.",
                        min = 1,
                        max = 6,
                        step = 1,
                        order = comparisonCount + 19,
                        get = function()
                            return self.db.profile.revengeRank
                        end,
                        set = function(_, value)
                            self:SetOption("revengeRank", value)
                        end,
                    },
                    cleaveRank = {
                        type = "range",
                        name = "Cleave Rank",
                        desc = "Highest Cleave rank available to the character.",
                        min = 1,
                        max = 5,
                        step = 1,
                        order = comparisonCount + 20,
                        get = function()
                            return self.db.profile.cleaveRank
                        end,
                        set = function(_, value)
                            self:SetOption("cleaveRank", value)
                        end,
                    },
                },
            },
        },
    }

    local abilityArgs = self.options.args.abilities.args
    local comparisonOrder = 2
    -- Keep comparison toggles ahead of the temporary rank selectors.
    for _, spellName in ipairs(supportedAbilities) do
        if spellName ~= "Sunder Armor" then
            local optionKey = "compare_" .. spellName:lower():gsub("%s+", "_")
            abilityArgs[optionKey] = makeCompareAbilityOption(
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

function Options:Open()
    AceConfigDialog:Open("Sundered")
end

function Options:OnDisable()
    self.anchorPicker:UnregisterEvent("GLOBAL_MOUSE_DOWN")
end

-- Applies the profile selected or restored by AceDB.
function Options:OnProfileChanged(event, database, newProfileKey)
	self.db.profile = database.profile
	Addon:ApplyOptions()
end

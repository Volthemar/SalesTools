--[[
    Project: SalesTools
    Desc: An addon with several useful Quality of Life features for the advertisement & administration of in-game gold sales
    Repo: https://github.com/Adalyia/SalesTools
    Author(s): 
    - Emily Cohen / Emilýp-Illidan / adalyiawra@gmail.com
    - Honorax-Illidan - https://worldofwarcraft.com/en-us/character/us/illidan/honorax (Original author, this addon is largely based on his idea/work)
--]]

-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
SalesTools = LibStub("AceAddon-3.0"):NewAddon("SalesTools", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local StdUi = LibStub('StdUi')
local LibDBIcon = LibStub("LibDBIcon-1.0")

-- Global for our addon object
_G["SalesTools"] = SalesTools

-- Debugging mode
local DEBUG_MODE = false

-- Addon constants
local ADDON_CHAT_PREFIX = "|cffFFE400[|r|cff3AFF00" .. L["Addon_Name"] .. "|r|cffFFE400]|r"
local ADDON_COMMAND1,ADDON_COMMAND2,ADDON_COMMAND3,ADDON_COMMAND4 = "sales","sale","st","ad"
local ADDON_ICON = [=[Interface\Addons\SalesTools\media\i32.tga]=]
local MINIMAP_DEFAULTS = {
    { text = L["Addon_Name"], notCheckable = true, isTitle = true },
    { text = L["SalesTools_Minimap_HideMinimap"], notCheckable = true, func = function()
        SalesTools.db.global.minimap.hide = true;
        LibDBIcon:Refresh("SalesToolsMinimapButton", SalesTools.db.global.minimap)
    end }
}
local ADDON_OPTION_DEFAULTS = {
    desc = {
        type = "description",
        name = L["Description"],
        fontSize = "medium",
        order = 1
    },
    author = {
        type = "description",
        name = "\n|cffffd100" .. L["Author"] .. ": |r " .. GetAddOnMetadata("SalesTools", "Author"),
        order = 2
    },
    version = {
        type = "description",
        name = "|cffffd100" .. L["Version"] .. ": |r" .. GetAddOnMetadata("SalesTools", "Version") .. "\n",
        order = 3
    },
    hide_minimap = {
        name = L["SalesTools_Minimap_Option_Label"],
        desc = "|cffaaaaaa".. L["SalesTools_Minimap_Option_Desc"] .. "|r",
        descStyle = "inline",
        width = "full",
        type = "toggle",
        order = 4,
        set = function(_, val)
            SalesTools.db.global.minimap.hide = not val
            LibDBIcon:Refresh("SalesToolsMinimapButton", SalesTools.db.global.minimap)
        end,
        get = function(_)
            return not SalesTools.db.global.minimap.hide
        end
    },
}
local ADDON_COMMAND_DEFAULTS = {
    version = {
        desc = L["SalesTools_Version_Command_Desc"],
        action = function()
            SalesTools:Print(string.format(L["SalesTools_Version_Command_Msg"], GetAddOnMetadata("SalesTools", "Version")))
            SalesTools:AddonInfoPanel()
        end,
    },
    minimap = {
        desc = L["SalesTools_Minimap_Command_Desc"],
        action = function()
            SalesTools.db.global.minimap.hide = not SalesTools.db.global.minimap.hide
            LibDBIcon:Refresh("SalesToolsMinimapButton", SalesTools.db.global.minimap)
        end,
    }
}

-- Replacements for the default print function to addon name localization
function SalesTools:Print(...)
    local str = ADDON_CHAT_PREFIX .. "|cff00F7FF "
    local count = select("#", ...)
	for i = 1, count do
		str = str .. tostring(select(i, ...))
		if i < count then
			str = str .. " "
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(str .. "|r")
end

function SalesTools:Debug(...)
    if DEBUG_MODE then
        local str = ADDON_CHAT_PREFIX .. "|cffFF0000 "
        local count = select("#", ...)
        for i = 1, count do
            str = str .. tostring(select(i, ...))
            if i < count then
                str = str .. " "
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(str .. "|r")
    end
end

-- Core functions
function SalesTools:OnInitialize()
    -- Called when the addon is loaded
    self:Debug("OnInitialize")

    -- Set a starting Z value for our frames/windows
    self.FRAME_LEVEL = 0

    -- Instanced copy of the addon icon
    self.AddonIcon = ADDON_ICON

    -- Create our local options table / flatfile
    self.db = LibStub("AceDB-3.0"):New("SalesToolsDB", defaults)

    -- Create a list of minimap options from our defaults
    self.MinimapMenu = MINIMAP_DEFAULTS

    -- Create a list of buttons to attach to the mailbox frame, this can be filled/added to by modules
    self.MailboxButtons = {}
    
    -- Create our addon options dictionary, this determines options in the interface menu
    self.AddonOptions = ADDON_OPTION_DEFAULTS

    -- Create a list of addon commands/subcommands, this can be filled/added to by modules
    self.AddonCommands = ADDON_COMMAND_DEFAULTS

    -- Enumerate the modules we want to load
    self.MailLog = SalesTools:GetModule("MailLog")
    self.MailSender = SalesTools:GetModule("MailSender")
    self.MailGrabber = SalesTools:GetModule("MailGrabber")
    self.TradeLog = SalesTools:GetModule("TradeLog")
    self.BalanceList = SalesTools:GetModule("BalanceList")
    self.AutoInvite = SalesTools:GetModule("AutoInvite")
    self.HelperDisplay = SalesTools:GetModule("HelperDisplay")
    self.MassInvite = SalesTools:GetModule("MassInvite")
    self.MassWhisper = SalesTools:GetModule("MassWhisper")
    self.CollectorMenu = SalesTools:GetModule("CollectorMenu")

    -- Modules to load at runtime
    for name, module in self:IterateModules() do
        module:SetEnabledState(true)
    end
    
    -- Draw minimap button
    SalesTools:DrawMinimapButton()

    -- Populate our addon options panel
    SalesTools:SetupOptions()
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SalesTools", "SalesTools")

    -- Command handler
    local function OnCommand(msg)
        -- Called when the addon is given a command
        self:Debug("OnCommand", msg)
    
        -- To make our command arguments non case sensitive convert the input string to lower case before comparison
        msg = string.lower(msg)
    
        -- Var that tells us if we executed a command or not
        local found = false
    
        -- Iterate through the registered commands, if we find a match execute the corresponding action
        for key, value in pairs(SalesTools.AddonCommands) do
            if (key == msg) then
                found = true
                value.action()
            end
            
        end
    
        -- If we find no valid commands, output the commands list
        if (not found) then
            self:Print("Commands:")
            for key, value in pairs(SalesTools.AddonCommands) do
                DEFAULT_CHAT_FRAME:AddMessage("   /" .. "|cffd4af37" .. ADDON_COMMAND1 .. "|r" .. " |cff00FF17" .. key .. " |r- |cff00F7FF" .. value.desc)
            end
        
        end
    end

    -- Register commands
    self:RegisterChatCommand(ADDON_COMMAND1, OnCommand)
    self:RegisterChatCommand(ADDON_COMMAND2, OnCommand)
    self:RegisterChatCommand(ADDON_COMMAND3, OnCommand)
    self:RegisterChatCommand(ADDON_COMMAND4, OnCommand)

    -- Print version information
    self:Print(string.format(L["Version_Message"], GetAddOnMetadata("SalesTools", "Version"),GetAddOnMetadata("SalesTools", "Author")))
end

function SalesTools:OnEnable()
    -- Called when the addon is enabled
    self:Debug("OnEnable")

    -- Disable tutorials KEKW
    SetCVar("showTutorials", 0)

    -- Register our event handlers
    self:RegisterEvent("MAIL_SHOW", "OnEvent")
    self:RegisterEvent("MAIL_CLOSED", "OnEvent")
end

function SalesTools:OnDisable()
    -- Called when the addon is disabled
    self:Debug("OnDisable")

end

-- Setup/basic UI functions

function SalesTools:DrawMinimapButton()
    -- Called to draw/display the minimap button
    self:Debug("DrawMinimapButton")

    if (self.db.global.minimap == nil) then
        self.db.global.minimap = { ["hide"] = false }
    end

    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("SalesToolsMinimapButton", {
        type = "launcher",
        icon = self.AddonIcon,
        OnClick = function(self)
            if (not self.menuFrame) then
                local MenuFrame = CreateFrame("Frame", "MinimapMenuFrame", UIParent, "UIDropDownMenuTemplate")
                self.MinimapMenuFrame = MenuFrame
            end
            
            EasyMenu(SalesTools.MinimapMenu, self.MinimapMenuFrame, "cursor", 0, 0, "MENU");
        end,
    })

    LibDBIcon:Register("SalesToolsMinimapButton", ldb, self.db.global.minimap)
    LibDBIcon:Refresh("SalesToolsMinimapButton", self.db.global.minimap)
end

function SalesTools:SetupOptions()
    -- Called to create a menu for our addon's options in the Blizzard UI
    self:Debug("SetupOptions")

    local options = {
        name = L["Addon_Name"],
        descStyle = "inline",
        type = "group",
        childGroups = "tree",
        args = self.AddonOptions,
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("SalesTools", options)
end

-- Event Handlers
function SalesTools:OnEvent(event, ...)
    -- Called when an event is triggered
    self:Debug("OnEvent", event, ...)

    -- Check if the event is one of the registered events
    if (event == "MAIL_SHOW") then
        -- When the mail frame opens draw our buttons
        SalesTools:DrawMailboxButtons()
    elseif (event == "MAIL_CLOSED") then
        -- When the mail frame closes hide any created buttons
        if (self.SendMailButton) then
            self.SendMailButton:Hide()
        end
        if (self.MailLogButton) then
            self.MailLogButton:Hide()
        end
        if (self.MailPickupButton) then
            self.MailPickupButton:Hide()
        end
        if (self.AddonIconFrame) then
            self.AddonIconFrame:Hide()
        end
        if (self.MailPickupButton) then
            self.MailPickupButton:Hide()
        end
	end
end

-- GUI Elements

function SalesTools:AddonInfoPanel()
    -- Called to draw/display the addon's information panel
    self:Debug("AddonInfoPanel")

    if (self.InfoPanel) then
        self.InfoPanel:Show()
    else
        local window = StdUi:Window(UIParent, 360, 200, L["Addon_Name"])
        window:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        window:SetMovable(false);
        window:EnableMouse(false);

        local addonVersion = StdUi:Label(window, '|cffFFE400' .. GetAddOnMetadata("SalesTools", "Version") .. '|r', 17, nil, 160);
        addonVersion:SetJustifyH('MIDDLE');
        StdUi:GlueTop(addonVersion, window, 0, -40);

        local addonAuthor = StdUi:Label(window, '|cff00FF17' .. GetAddOnMetadata("SalesTools", "Author"):gsub(" / ", string.char(10)) .. '|r', 13, nil, 200);
        addonAuthor:SetJustifyH('MIDDLE');
        StdUi:GlueBelow(addonAuthor, addonVersion, 0, -10);

        local addonNotes = StdUi:Label(window, '|cff00F7FF' .. GetAddOnMetadata("SalesTools", "Notes") .. '|r', 13, nil, 300);
        addonNotes:SetJustifyH('MIDDLE');
        StdUi:GlueBelow(addonNotes, addonAuthor, 0, -15);

        self.InfoPanel = window

    end
end

-- Draw our mail frame buttons
function SalesTools:DrawMailboxButtons()
    if (self.AddonIconFrame == nil and self.SendMailButton == nil and self.MailLogButton == nil and self.MailSender ~= nil and self.MailLog ~= nil) then
        local AddonIconFrame = StdUi:Frame(MailFrame, 32, 32)
        local icon_texture = StdUi:Texture(AddonIconFrame, 32, 32, SalesTools.AddonIcon)
        StdUi:GlueTop(icon_texture, AddonIconFrame, 0, 0)

        local MailLogButton = StdUi:Button(MailFrame, 150, 22, "Mail Log")
        MailLogButton:SetScript("OnClick", function()
            if (SalesTools.MailLog) then
                SalesTools.MailLog:Toggle()
            end
        end)

        StdUi:GlueBottom(MailLogButton, MailFrame, 20, -22, "RIGHT")
        StdUi:GlueLeft(AddonIconFrame, MailLogButton, 0, -11)

        local SendMailButton = StdUi:Button(MailFrame, 150, 22, "Mail Gold")
        SendMailButton:SetScript("OnClick", function()
            if (SalesTools.MailSender) then
                SalesTools.MailSender:Toggle()
            end
        end)

        StdUi:GlueBottom(SendMailButton, MailLogButton, 0, -22)

        self.SendMailButton = SendMailButton
        self.MailLogButton = MailLogButton
        self.AddonIconFrame = AddonIconFrame
        
        
        if (self.MailPickupButton == nil and self.MailGrabber ~= nil) then
            local MailPickupButton = StdUi:Button(MailFrame, 150, 22, "Mail Pickup")
            MailPickupButton:SetScript("OnClick", function()
                if (SalesTools.MailGrabber) then
                    SalesTools.MailGrabber:Toggle()
                end
            end)

            StdUi:GlueBottom(MailPickupButton, SendMailButton, 0, -22)

            self.MailPickupButton = MailPickupButton
        
        end
    else
        if (self.MailSender ~= nil and self.MailLog ~= nil) then
        self.AddonIconFrame:Show()
        self.SendMailButton:Show()
        self.MailLogButton:Show()
            if (self.MailGrabber ~= nil) then
                self.MailPickupButton:Show()
            end
        end
    end
    
end

-- Reused functions
function SalesTools:HasValue(tab, val)
    -- Check if a table has a value
    self:Debug("HasValue")
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function SalesTools:CommaValue(amount)
    -- Comma delimit an integer
    self:Debug("CommaValue")

    local formatted = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end


function SalesTools:FormatRawCurrency(currency)
    -- Convert a value in copper to a rounded value in gold
    self:Debug("FormatRawCurrency")

    return math.floor(currency / COPPER_PER_GOLD)
end

function SalesTools:GetPlayerFullName()
    -- Get the player's name in Name-Realm format
    self:Debug("GetPlayerFullName")

    local name, realm = UnitFullName("player")

    if realm ~= nil then
        return name .. "-" .. realm
    else
        return name
    end
end

function SalesTools:GetNextFrameLevel()
    -- Get the next frame level
    self:Debug("GetNextFrameLevel")

    SalesTools.FRAME_LEVEL = SalesTools.FRAME_LEVEL + 10
    return math.min(SalesTools.FRAME_LEVEL, 10000)
end

function SalesTools:ShowPopup(text)
    -- Show a popup that the user can copy text from
    self:Debug("ShowPopup")

    local DialogBox = StaticPopup_Show("ADToolsPopup")
    DialogBox.EditBox:SetScript("OnEscapePressed", function()
        DialogBox:Hide()
    end)
    DialogBox.EditBox:SetScript("OnEnterPressed", function()
        DialogBox:Hide()
    end)
    DialogBox.EditBox:SetScript("OnTabPressed", function()
        DialogBox:Hide()
    end)
    DialogBox.EditBox:SetScript("OnSpacePressed", function()
        DialogBox:Hide()
    end)
    DialogBox.EditBox:SetText(text)
    DialogBox.EditBox:SetFocus()
    DialogBox.EditBox:HighlightText()
end

-- Our popup settings
StaticPopupDialogs["SalesToolsPopup"] = {
    text = "Copy",
    button2 = OKAY,
    timeout = 10,
    whileDead = true,
    hideOnEscape = true,
    exclusive = true,
    enterClicksFirstButton = true,
    preferredIndex = 3,
    hasEditBox = true
}
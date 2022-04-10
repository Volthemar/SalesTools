-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local MassWhisper = SalesTools:NewModule("MassWhisper", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
local StdUi = LibStub('StdUi')

function MassWhisper:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("MassWhisper:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Register the module's minimap button
    table.insert(SalesTools.MinimapMenu, { text = L["MassWhisper_Toggle"], notCheckable = true, func = function()
        if (SalesTools.MassWhisper) then
            SalesTools.MassWhisper:Toggle()
        end
    end })

    -- Write our defaults to the DB if they don't exist
    if (self.GlobalSettings.massWhisperMessage == nil) then
        self.GlobalSettings.massWhisperMessage = "Hey {player}! Your funnelers/traders are: {custom}"
    end

    -- Register the options relevant to this module
    SalesTools.AddonOptions.MassWhisper = {
        name = L["MassWhisper"],
        type = "group",
        args= {
            massWhisperMessage = {
                name = L["MassWhisper_Message_Option_Name"],
                desc = "|cffaaaaaa" .. L["MassWhisper_Message_Option_Desc"] .. "|r",
                width = "full",
                type = "input",
                set = function(info, val)
                    if val ~= "" then
                        SalesTools.db.global.massWhisperMessage = val
        
                    else
                        SalesTools:Print(L["MassWhisper_Options_No_Empty"])
                    end
                end,
                get = function(info)
                    return SalesTools.db.global.massWhisperMessage
                end
            },
        },
    }

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.whisper = {
        desc = L["MassWhisper_Command_Desc"],
        action = function()
            if (SalesTools.MassWhisper) then
                SalesTools.MassWhisper:Toggle()
            end
        end,
    }
end

function MassWhisper:Toggle()
    -- Toggle visibility of the Mass Whisper window
    SalesTools:Debug("MassWhisper:Toggle")

    if (self.WhisperWindowFrame == nil) then
        self:DrawWindow()
        self:DrawInfoIcon()
    elseif self.WhisperWindowFrame:IsVisible() then
        self.WhisperWindowFrame:Hide()
    else
        self.WhisperWindowFrame:Show()
    end
end

function MassWhisper:DrawWindow()
    -- Draw our Mass Whisper window
    SalesTools:Debug("MassWhisper:DrawWindow")

    local WhisperWindowFrame
    if (self.CharacterSettings.WhisperWindowFrame ~= nil) then
        WhisperWindowFrame = StdUi:Window(UIParent, self.CharacterSettings.WhisperWindowSize.width, self.CharacterSettings.WhisperWindowSize.height, L["MassWhisper_Window_Title"])
    else
        WhisperWindowFrame = StdUi:Window(UIParent, 450, 400, L["MassWhisper_Window_Title"])
    end

    if (self.CharacterSettings.WhisperWindowPosition ~= nil) then
        WhisperWindowFrame:SetPoint(self.CharacterSettings.WhisperWindowPosition.point or "CENTER",
                self.CharacterSettings.WhisperWindowPosition.UIParent,
                self.CharacterSettings.WhisperWindowPosition.relPoint or "CENTER",
                self.CharacterSettings.WhisperWindowPosition.relX or 0,
                self.CharacterSettings.WhisperWindowPosition.relY or 0)
    else
        WhisperWindowFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end

    StdUi:MakeResizable(WhisperWindowFrame, "BOTTOMRIGHT")
    WhisperWindowFrame:SetMinResize(450, 400)
    WhisperWindowFrame:SetMaxResize(580, 664)
    WhisperWindowFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    WhisperWindowFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    WhisperWindowFrame:SetScript("OnSizeChanged", function(self)
        MassWhisper.CharacterSettings.WhisperWindowSize = { width = self:GetWidth(), height = self:GetHeight() }
    end)

    WhisperWindowFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        MassWhisper.CharacterSettings.WhisperWindowPosition = { point = point, relPoint = relPoint, relX = xOfs, relY = yOfs }
    end)

    local EditBox = StdUi:MultiLineBox(WhisperWindowFrame, 440, 300, nil)
    StdUi:GlueAcross(EditBox, WhisperWindowFrame, 10, -50, -10, 70)
    EditBox:SetFocus()

    local SendButton = StdUi:Button(WhisperWindowFrame, 160, 30, 'Send Whispers')
    StdUi:GlueBottom(SendButton, WhisperWindowFrame, 0, 10, 'CENTER')
    SendButton:SetScript('OnClick', function()
        MassWhisper:Start()
    end)

    local IconFrame = StdUi:Frame(WhisperWindowFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)

    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, WhisperWindowFrame, -10, 10, "RIGHT")

    local function customValidator(self)
        local text = self:GetText();
        if text then
            self.value = text;
            MassWhisper.GlobalSettings.massWhisperMessage = text
            StdUi:MarkAsValid(self, true);
            return true;
        end
    end

    local MassWhisperTargetsBox = StdUi:EditBox(WhisperWindowFrame, 430, 20, self.GlobalSettings.massWhisperMessage, customValidator)
    StdUi:GlueBelow(MassWhisperTargetsBox, EditBox, 0, -3, "LEFT")
    MassWhisperTargetsBox:SetPoint("TOPRIGHT", EditBox, "BOTTOMRIGHT", 0, -3)

    self.WhisperWindowFrame = WhisperWindowFrame
    self.WhisperWindowFrame.SendButton = SendButton
    self.WhisperWindowFrame.MassWhisperTargetsBox = MassWhisperTargetsBox
    self.WhisperWindowFrame.EditBox = EditBox
end

function MassWhisper:DrawInfoIcon()
    -- Draw our info tooltip icon
    SalesTools:Debug("MassWhisper:DrawInfoIcon")

    local WhisperWindowFrame = self.WhisperWindowFrame
    local InfoIconFrame = StdUi:Frame(WhisperWindowFrame, 16, 16, nil);
    StdUi:GlueRight(InfoIconFrame, self.WhisperWindowFrame.SendButton, 20, 0, 'RIGHT')
    local InfoIconTexture = StdUi:Texture(WhisperWindowFrame, 16, 16, [=[Interface\FriendsFrame\InformationIcon]=])
    StdUi:GlueTop(InfoIconTexture, InfoIconFrame, 0, 0, "CENTER")
    local tooltip = StdUi:FrameTooltip(InfoIconFrame, "Examples:|nplayer1-server:custom_message|n{custom} - Your custom message|n{player} - The target player's name", "tooltip", "TOP", true)
end

function MassWhisper:Start()
    -- Start the mass whisper loop
    SalesTools:Debug("MassWhisper:Start")

    if (self.WhisperWindowFrame.EditBox ~= nil and self.WhisperWindowFrame.EditBox:GetText() ~= nil) then
        local input = self.WhisperWindowFrame.EditBox:GetText()
        local parsedInput = string.gmatch(input, "[^\r\n]+")
        for entry in parsedInput do
            local subEntries = {}
            for subEntry in (entry):gmatch("[^:]+") do
                table.insert(subEntries, subEntry)
            end
            if (subEntries[1] and subEntries[2]) then
                local player = MassWhisper:EnsureFullName(subEntries[1])
                local formattedMessage = self.GlobalSettings.massWhisperMessage:gsub("{custom}", subEntries[2]):gsub("{player}", player)
                SendChatMessage(formattedMessage, "WHISPER", "COMMON", player)
            end
        end
    end

    self.WhisperWindowFrame:Hide()
end

function MassWhisper:EnsureFullName(name)
    -- Force full name(s) for any players
    SalesTools:Debug("MassWhisper:EnsureFullName")

    if (not name:find("-")) then
        name = name .. "-" .. select(2, UnitFullName("player"))
    end

    return name
end

function MassWhisper:Finish()
    -- When mass whispers have been sent hide the window
    SalesTools:Debug("MassWhisper:Finish")
    
    self.WhisperWindowFrame:Hide()
end
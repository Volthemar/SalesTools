-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local NameGrabber = SalesTools:NewModule("NameGrabber", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local StdUi = LibStub('StdUi')

function NameGrabber:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("NameGrabber:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.gnames = {
        desc = L["NameGrabber_Command_Desc"],
        action = function()
            if (SalesTools.NameGrabber) then
                SalesTools.NameGrabber:Toggle()
            end
        end,
    }
end

function NameGrabber:Toggle()
    -- Toggle visibility of the Mass Inviter window
    SalesTools:Debug("NameGrabber:Toggle")

    if (self.NameGrabberFrame == nil) then
        self:DrawNamesWindow()
        self:GetNames()
    elseif self.NameGrabberFrame:IsVisible() then
        self.NameGrabberFrame:Hide()
    else
        self.NameGrabberFrame:Show()
        self:GetNames()
    end
end

function NameGrabber:DrawNamesWindow()
    -- Draw the mass invite window
    SalesTools:Debug("NameGrabber:DrawNamesWindow")

    local NameGrabberFrame = StdUi:Window(UIParent, 300, 400, L["NameGrabber_Window_Title"])
    NameGrabberFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    NameGrabberFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())
    NameGrabberFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    StdUi:MakeResizable(NameGrabberFrame, "BOTTOMRIGHT")
    NameGrabberFrame:SetResizeBounds(250, 332, 500, 664)
    NameGrabberFrame:IsUserPlaced(true);

    local EditBox = StdUi:MultiLineBox(NameGrabberFrame, 280, 300, nil)
    EditBox:SetAlpha(0.75)
    StdUi:GlueAcross(EditBox, NameGrabberFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local IconFrame = StdUi:Frame(NameGrabberFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, NameGrabberFrame, -10, 10, "RIGHT")

    local getNamesButton = StdUi:Button(NameGrabberFrame, 120, 30, L["NameGrabber_GetNames_Button"])
    StdUi:GlueBottom(getNamesButton, NameGrabberFrame, 0, 10, 'CENTER')
    getNamesButton:SetScript('OnClick', function()
        self:GetNames()
    end)

    self.NameGrabberFrame = NameGrabberFrame
    self.NameGrabberFrame.EditBox = EditBox
end

function NameGrabber:EnsureFullName(name)
    -- Force full name(s) for any players
    SalesTools:Debug("NameGrabber:EnsureFullName", name)

    if (not name:find("-")) then
        name = name .. "-" .. GetNormalizedRealmName()
    end

    return name
end

function NameGrabber:GetNames()
    -- Grab names
    SalesTools:Debug("NameGrabber:GetNames")

    local InRaid = IsInRaid()
    local InParty = IsInGroup()

    if (not InRaid and not InParty) then
        local Name = select(1, UnitName("player")) .. "-" .. GetNormalizedRealmName()
        if (self.NameGrabberFrame ~= nil) then
            self.NameGrabberFrame.EditBox:SetText(Name)
        end
        return Name
    end

    local Names = {}

    -- This is sloppy but hey it works and im lazy XD
    if (InRaid) then
        for i = 1, GetNumGroupMembers() do
            local Name, Realm = UnitName("raid" .. i)
            if (Name ~= nil) then
                if (Realm ~= nil) then
                    Name = Name .. "-" .. Realm:gsub("-", ""):gsub(" ", "")
                end
                table.insert(Names, NameGrabber:EnsureFullName(Name))
            end
        end
    elseif (InParty) then
        table.insert(Names, NameGrabber:EnsureFullName(select(1, UnitName("player")) .. "-" .. GetNormalizedRealmName()))
        for i = 1, GetNumGroupMembers() do
            local Name, Realm = UnitName("party" .. i)
            if (Name ~= nil) then
                if (Realm ~= nil) then
                    Name = Name .. "-" .. Realm:gsub("-", ""):gsub(" ", "")
                end
                table.insert(Names, NameGrabber:EnsureFullName(Name))
            end
        end
    end
    if (self.NameGrabberFrame ~= nil) then
        self.NameGrabberFrame.EditBox:SetText(table.concat(Names, "\n"))
    end
    return table.concat(Names, "\n")
end
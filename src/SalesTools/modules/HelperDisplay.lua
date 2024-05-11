-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local HelperDisplay = SalesTools:NewModule("HelperDisplay", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")

function HelperDisplay:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("HelperDisplay:OnEnable")

    -- Our databases/user settings
    self.GlobalSettings = SalesTools.db.global
    self.CharacterSettings = SalesTools.db.char

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.help = {
        desc = L["HelpDisplay_Toggle_Command_Desc"],
        action = function()
            if (SalesTools.HelperDisplay) then
                SalesTools.HelperDisplay:Toggle()
            end
        end,
    }
    SalesTools.AddonCommands.name = {
        desc = L["HelpDisplay_Toggle_NameDisplay_Command_Desc"],
        action = function()
            if (SalesTools.HelperDisplay) then
                SalesTools.HelperDisplay:ToggleName()
            end
        end,
    }
    SalesTools.AddonCommands.gold = {
        desc = L["HelpDisplay_Toggle_GoldDisplay_Command_Desc"],
        action = function()
            if (SalesTools.HelperDisplay) then
                SalesTools.HelperDisplay:ToggleGold()
            end
        end,
    }
    SalesTools.AddonCommands.realm = {
        desc = L["HelpDisplay_Toggle_RealmDisplay_Command_Desc"],
        action = function()
            if (SalesTools.HelperDisplay) then
                SalesTools.HelperDisplay:ToggleRealm()
            end
        end,
    }
    
    -- Hide the helper windows by default if the player level is 49 or lower
    if self.CharacterSettings.ShowHelperDisplays == nil then
        if (UnitLevel("player") <= 49) then
            self.CharacterSettings.ShowHelperDisplays = true
        else
            self.CharacterSettings.ShowHelperDisplays = false
        end
    end

    if self.CharacterSettings.ShowNameDisplay == nil then
        if (UnitLevel("player") <= 49) then
            self.CharacterSettings.ShowNameDisplay = true
        else
            self.CharacterSettings.ShowNameDisplay = false
        end
    end

    if self.CharacterSettings.ShowRealmDisplay == nil then
        if (UnitLevel("player") <= 49) then
            self.CharacterSettings.ShowRealmDisplay = true
        else
            self.CharacterSettings.ShowRealmDisplay = false
        end
    end

    if self.CharacterSettings.ShowGoldDisplay == nil then
        if (UnitLevel("player") <= 49) then
            self.CharacterSettings.ShowGoldDisplay = true
        else
            self.CharacterSettings.ShowGoldDisplay = false
        end
    end

    -- If enabled, show/draw our helper windows
    if self.CharacterSettings.ShowHelperDisplays then
        if self.HelperFrame == nil then
            HelperDisplay:DrawHelpWindow()
        else
            self.HelperFrame:Show()
        end
    end

    -- Register our events
    HelperDisplay:RegisterEvent("PLAYER_MONEY", "UpdateGold")

end

function HelperDisplay:UpdateGold(event, ...)
    -- Handler for PLAYER_MONEY events
    SalesTools:Debug("HelperDisplay:UpdateGold")

    if (self.HelperFrame ~= nil) then
        local gold = math.floor(GetMoney() / 100 / 100)
        self.HelperFrame.GoldDisplay:SetText(SalesTools:CommaValue(gold) .. " Gold")
    end
end

function HelperDisplay:DrawHelpWindow()
    -- Draw our helper frame
    SalesTools:Debug("HelperDisplay:DrawHelpWindow")

    local frame = CreateFrame("FRAME", nil)
    local name, realm = UnitFullName("player")

    -- Label displaying the current realm
    frame.RealmDisplay = frame:CreateFontString("realmDisplay")
    frame.RealmDisplay:SetFontObject("GameFontNormalMed3")
    frame.RealmDisplay:SetTextColor(1, 1, 1, 1)
    frame.RealmDisplay:SetJustifyH("CENTER")
    frame.RealmDisplay:SetJustifyV("MIDDLE")
    frame.RealmDisplay:SetText(realm)
    frame.RealmDisplay:ClearAllPoints()
    frame.RealmDisplay:SetPoint("TOP", UIParent, "TOP", 0, 0)


    frame.RealmDisplay:SetScale(3)

    -- Label displaying the current character's name
    frame.NameDisplay = frame:CreateFontString("nameDisplay")
    frame.NameDisplay:SetFontObject("GameFontNormalMed3")
    frame.NameDisplay:SetTextColor(1, 1, 1, 1)
    frame.NameDisplay:SetJustifyH("CENTER")
    frame.NameDisplay:SetJustifyV("MIDDLE")
    frame.NameDisplay:SetText(name)
    frame.NameDisplay:ClearAllPoints()
    frame.NameDisplay:SetPoint("TOP", frame.RealmDisplay, "BOTTOM", 0, 0)

    frame.NameDisplay:SetScale(2)

    -- Button showing the current character's gold
    frame.GoldDisplay = CreateFrame("Button", "GoldCopyButton", frame, "GameMenuButtonTemplate")
    frame.GoldDisplay:SetSize(180, 22) -- width, height
    local gold = math.floor(GetMoney() / 100 / 100)
    frame.GoldDisplay:SetPoint("TOP", frame.NameDisplay, "LEFT", -75, -20)

    frame.GoldDisplay:SetText(SalesTools:CommaValue(gold) .. " " .. L["HelpDisplay_GoldDisplay_Gold"])
    frame.GoldDisplay:SetScript("OnClick", function()
        local gold = math.floor(GetMoney() / 100 / 100)
        SalesTools:ShowPopup(gold)
    end)

    -- Button showing the current character's name
    frame.NameCopyButton = CreateFrame("Button", "NameCopyButton", frame, "GameMenuButtonTemplate")
    frame.NameCopyButton:SetSize(180, 22) -- width, height
    frame.NameCopyButton:SetPoint("TOP", frame.NameDisplay, "RIGHT", 75, -20)
    frame.NameCopyButton:SetText(name .. "-" .. realm)
    frame.NameCopyButton:SetScript("OnClick", function()
        SalesTools:ShowPopup(name .. "-" .. realm)
    end)

    self.HelperFrame = frame

    if self.CharacterSettings.ShowNameDisplay == false then
        self.HelperFrame.NameDisplay:Hide()
        self.HelperFrame.NameCopyButton:Hide()
    end
    if self.CharacterSettings.ShowRealmDisplay == false then
        self.HelperFrame.RealmDisplay:Hide()
    end
    if self.CharacterSettings.ShowGoldDisplay == false then
        self.HelperFrame.GoldDisplay:Hide()
    end

end

function HelperDisplay:Toggle()
    -- Toggle visibility of the helper frame
    SalesTools:Debug("HelperDisplay:Toggle")
    
    if self.CharacterSettings.ShowHelperDisplays then
        self.CharacterSettings.ShowHelperDisplays = false
        if self.HelperFrame ~= nil then
            self.HelperFrame:Hide()
        end
    else
        self.CharacterSettings.ShowHelperDisplays = true
        if self.HelperFrame == nil then
            HelperDisplay:DrawHelpWindow()
        else
            self.HelperFrame:Show()
        end
    end
end

function HelperDisplay:ToggleName()
    -- Toggle visibility of the name display
    SalesTools:Debug("HelperDisplay:ToggleName")

    if self.CharacterSettings.ShowNameDisplay then
        self.CharacterSettings.ShowNameDisplay = false
        if self.HelperFrame ~= nil then
            self.HelperFrame.NameDisplay:Hide()
            self.HelperFrame.NameCopyButton:Hide()
        end
    else
        self.CharacterSettings.ShowNameDisplay = true
        if self.HelperFrame == nil then
            HelperDisplay:DrawHelpWindow()
        else
            self.HelperFrame:Show()
            self.HelperFrame.NameDisplay:Show()
            self.HelperFrame.NameCopyButton:Show()
        end
    end
end

function HelperDisplay:ToggleRealm()
    -- Toggle visibility of the realm display
    SalesTools:Debug("HelperDisplay:ToggleRealm")

    if self.CharacterSettings.ShowRealmDisplay then
        self.CharacterSettings.ShowRealmDisplay = false
        if self.HelperFrame ~= nil then
            self.HelperFrame.RealmDisplay:Hide()
        end
    else
        self.CharacterSettings.ShowRealmDisplay = true
        if self.HelperFrame == nil then
            HelperDisplay:DrawHelpWindow()
        else
            self.HelperFrame:Show()
            self.HelperFrame.RealmDisplay:Show()
        end
    end
end

function HelperDisplay:ToggleGold()
    -- Toggle visibility of the gold display
    SalesTools:Debug("HelperDisplay:ToggleGold")

    if self.CharacterSettings.ShowGoldDisplay then
        self.CharacterSettings.ShowGoldDisplay = false
        if self.HelperFrame ~= nil then
            self.HelperFrame.GoldDisplay:Hide()
        end
    else
        self.CharacterSettings.ShowGoldDisplay = true
        if self.HelperFrame == nil then
            HelperDisplay:DrawHelpWindow()
        else
            self.HelperFrame:Show()
            self.HelperFrame.GoldDisplay:Show()
        end
    end
end

-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local CollectorMenu = SalesTools:NewModule("CollectorMenu", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local StdUi = LibStub("StdUi")

function CollectorMenu:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("CollectorMenu:OnEnable")

    -- Our databases/user settings
    self.GlobalSettings = SalesTools.db.global
    self.CharacterSettings = SalesTools.db.char

    -- Write our defaults to the DB if they don't exist
    if (self.GlobalSettings.PrimaryCollectorChar == nil) then
        self.GlobalSettings.PrimaryCollectorChar = "ExampleChar-Illidan"
    end

    if (self.GlobalSettings.RequestInviteMessage == nil) then
        self.GlobalSettings.RequestInviteMessage = "inv"
    end

    -- Register the options relevant to this module
    SalesTools.AddonOptions.CollectorMenu = {
        name = L["CollectorMenu"],
        type = "group",
        args= {
            PrimaryCollectorChar = {
                name = L["CollectorMenu_Primary_Char_Option_Name"],
                desc = "|cffaaaaaa" .. L["CollectorMenu_Primary_Char_Option_Desc"] .. "|r",
                width = "full",
                type = "input",
                set = function(info, val)
                    if val ~= "" then
                        SalesTools.db.global.PrimaryCollectorChar = val
        
                    else
                        SalesTools:Print(L["CollectorMenu_Options_No_Empty"])
                    end
                end,
                get = function(info)
                    return SalesTools.db.global.PrimaryCollectorChar
                end
            },
            RequestInviteMessage = {
                name = L["CollectorMenu_Invite_Request_Option_Name"],
                desc = "|cffaaaaaa" .. L["CollectorMenu_Invite_Request_Option_Desc"] .. "|r",
                width = "full",
                type = "input",
                set = function(info, val)
                    if val ~= "" then
                        SalesTools.db.global.RequestInviteMessage = val
        
                    else
                        SalesTools:Print(L["CollectorMenu_Options_No_Empty"])
                    end
                end,
                get = function(info)
                    return SalesTools.db.global.RequestInviteMessage
                end
            },
        },
    }

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.collect = {
        desc = L["CollectorMenu_Toggle_Command_Desc"],
        action = function()
            if (SalesTools.CollectorMenu) then
                SalesTools.CollectorMenu:Toggle()
            end
        end,
    }

    -- Register our events
    CollectorMenu:RegisterEvent("PLAYER_MONEY", "UpdateGold")
    CollectorMenu:RegisterEvent("TRADE_MONEY_CHANGED", "AcceptTrade")

    -- Default the panel to invisible if the player level is below or equal to 49
    if self.CharacterSettings.CollectorMenuEnabled == nil then
        if (UnitLevel("player") <= 49) then
            self.CharacterSettings.CollectorMenuEnabled = true
        else
            self.CharacterSettings.CollectorMenuEnabled = false
        end

    end

    -- If the panel is enabled, draw it
    if (self.CollectorMenuFrame == nil and self.CharacterSettings.CollectorMenuEnabled == true) then
        CollectorMenu:DrawCollectorWindow()
    end

end

function CollectorMenu:UpdateGold(event, ...)
    -- Event for PLAYER_MONEY
    -- Update the gold display
    SalesTools:Debug("CollectorMenu:UpdateGold")

    -- If our menu exists update the relevant texts
    if (self.CollectorMenuFrame ~= nil) then
        self.CollectorMenuFrame.GoldLabel:SetText('Gold: ' .. SalesTools:CommaValue(math.floor(GetMoney() / 100 / 100)) .. 'g')
        self.CollectorMenuFrame.GoldCapLabel:SetText('Cap Req: ' .. SalesTools:CommaValue(9999999 - math.floor(GetMoney() / 100 / 100)) .. 'g')
    end
end

function CollectorMenu:AcceptTrade(event, ...)
    -- Auto accept trade
    SalesTools:Debug("CollectorMenu:AcceptTrade")

    AcceptTrade()
end

function CollectorMenu:DrawCollectorWindow()
    -- Draw our GC Menu/Collectors Window
    SalesTools:Debug("CollectorMenu:DrawCollectorWindow")

    if self.CollectorMenuFrame == nil then
        local frame = StdUi:Window(UIParent, 260, 250, L["CollectorMenu"])
        frame:SetPoint('TOP', UIParent, 'TOP', 500, 0)

        frame.closeBtn:Hide()
        frame:SetMovable(true);
        frame:EnableMouse(true);

        -- Invite Current Target Button
        if frame.InviteTargetButton == nil then
            local InviteTargetButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_Invite_Target_Button"])
            StdUi:GlueTop(InviteTargetButton, frame, -64, -30, 'CENTER')
            frame.InviteTargetButton = InviteTargetButton
            frame.InviteTargetButton:SetScript("OnClick", function()
                if GetUnitName("target") ~= nil then
                    C_PartyInfo.InviteUnit(GetUnitName("target", true))
                end
            end)
        end
    
        -- Target Trade Button
        if frame.TradeTargetButton == nil then
            local TradeTargetButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_Trade_Target_Button"])
            StdUi:GlueTop(TradeTargetButton, frame.InviteTargetButton, 126, 0, 'CENTER')
            frame.TradeTargetButton = TradeTargetButton
            frame.TradeTargetButton:SetScript("OnClick", function()
                if GetUnitName("target") ~= nil then
                    InitiateTrade("target")
                end
            end)
        end
    
        -- Invite Request Button
        if frame.RequestInviteButton == nil then
            local RequestInviteButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_Invite_Request_Button"])
            StdUi:GlueTop(RequestInviteButton, frame.InviteTargetButton, 0, -30, 'CENTER')
            frame.RequestInviteButton = RequestInviteButton
            frame.RequestInviteButton:SetScript("OnClick", function()
                if (self.GlobalSettings.PrimaryCollectorChar == "" or self.GlobalSettings.RequestInviteMessage == "") then
                    SalesTools:Print(L["CollectorMenu_Invite_Request_No_Primary"])
                else
                    SendChatMessage(self.GlobalSettings.RequestInviteMessage, "WHISPER", nil, self.GlobalSettings.PrimaryCollectorChar)
                end
            end)
        end

        -- Mail Log Button
        if frame.MailLog == nil then
            local MailLogButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_MailLog_Button"])
            StdUi:GlueTop(MailLogButton, frame.TradeTargetButton, 0, -30, 'CENTER')
            frame.MailLog = MailLogButton
            frame.MailLog:SetScript("OnClick", function()
                if (SalesTools.MailLog) then
                    SalesTools.MailLog:Toggle()
                end
            end)
        end
    
        -- Trade Log Button
        if frame.TradeLog == nil then
            local tradelogButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_TradeLog_Button"])
            StdUi:GlueTop(tradelogButton, frame.RequestInviteButton, 0, -30, 'CENTER')
            frame.TradeLog = tradelogButton
            frame.TradeLog:SetScript("OnClick", function()
                if (SalesTools.TradeLog) then
                    SalesTools.TradeLog:Toggle()
                end
            end)
        end
    
        -- Gold Log Button
        if frame.GoldLabelLog == nil then
            local goldLogButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_BalanceList_Button"])
            StdUi:GlueTop(goldLogButton, frame.MailLog, 0, -30, 'CENTER')
            frame.GoldLabelLog = goldLogButton
            frame.GoldLabelLog:SetScript("OnClick", function()
                if (SalesTools.BalanceList) then
                    SalesTools.BalanceList:Toggle()
                end
            end)
        end

        -- Mass Whisper Button
        if frame.MassWhisperButton == nil then
            local MassWhisperButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_MassWhisper_Button"])
            StdUi:GlueTop(MassWhisperButton, frame.TradeLog, 0, -30, 'CENTER')
            frame.MassWhisperButton = MassWhisperButton
            frame.MassWhisperButton:SetScript("OnClick", function()
                if (SalesTools.MassWhisper) then
                    SalesTools.MassWhisper:Toggle()
                end
            end)
        end
    
        -- Mass Inviter Button
        if frame.MassInvite == nil then
            local MassInviteButton = StdUi:Button(frame, 124, 30, L["CollectorMenu_MassInvite_Button"])
            StdUi:GlueTop(MassInviteButton, frame.GoldLabelLog, 0, -30, 'CENTER')
            frame.MassInvite = MassInviteButton
            frame.MassInvite:SetScript("OnClick", function()
                if (SalesTools.MassInvite) then
                    SalesTools.MassInvite:Toggle()
                end
            end)
        end
    
    
        -- Gold Section
        local goldText = StdUi:Label(frame, "Gold Info", 16)
        StdUi:GlueTop(goldText, frame.MassInvite, -63, -40, 'CENTER')
    
        -- Label for how much gold the player has
        if frame.GoldLabel == nil then
            local gold = math.floor(GetMoney() / 100 / 100)
            local GoldCopyButton = StdUi:Button(frame, 250, 30, 'Gold: ' .. SalesTools:CommaValue(gold) .. 'g')
            StdUi:GlueTop(GoldCopyButton, goldText, 0, -20, 'CENTER')
            frame.GoldLabel = GoldCopyButton
            frame.GoldLabel:SetScript("OnClick", function()
                local gold = math.floor(GetMoney() / 100 / 100)
                SalesTools:ShowPopup(gold)
            end)
        end
    
        -- Label for the amount of gold needed to cap a character at 9,999,999
        if frame.GoldCapLabel == nil then
            local gold = 9999999 - math.floor(GetMoney() / 100 / 100)
            local goldCapButton = StdUi:Button(frame, 250, 30, 'Cap Req: ' .. SalesTools:CommaValue(gold) .. 'g')
            StdUi:GlueTop(goldCapButton, frame.GoldLabel, 0, -30, 'CENTER')
            frame.GoldCapLabel = goldCapButton
            frame.GoldCapLabel:SetScript("OnClick", function()
                local gold = 9999999 - math.floor(GetMoney() / 100 / 100)
                SalesTools:ShowPopup(gold)
            end)
        end

        self.CollectorMenuFrame = frame

    end


end

function CollectorMenu:Toggle()
    -- Toggle Visibility of the collector window
    SalesTools:Debug("CollectorMenu:Toggle")

    if self.CharacterSettings.CollectorMenuEnabled == true then
        self.CharacterSettings.CollectorMenuEnabled = false
        if (self.CollectorMenuFrame ~= nil) then
            self.CollectorMenuFrame:Hide()
        end

    else
        self.CharacterSettings.CollectorMenuEnabled = true
        if (self.CollectorMenuFrame == nil) then
            CollectorMenu:DrawCollectorWindow()
        else
            self.CollectorMenuFrame:Show()
        end
        

    end

end
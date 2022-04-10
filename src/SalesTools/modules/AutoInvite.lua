-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local AutoInvite = SalesTools:NewModule("AutoInvite", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")

function AutoInvite:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("AutoInvite:OnEnable")

    -- Our databases/user settings
    self.GlobalSettings = SalesTools.db.global
    self.CharacterSettings = SalesTools.db.char

    -- Write our defaults to the DB if they don't exist
    if (self.CharacterSettings.AutoInviteKeys == nil) then
        self.CharacterSettings.AutoInviteKeys = "invite,inv"
    end
    
    if (self.CharacterSettings.AutoInviteEnabled == nil) then
        self.CharacterSettings.AutoInviteEnabled = true
    end

    if (self.CharacterSettings.AutoAcceptInvites == nil) then
        self.CharacterSettings.AutoAcceptInvites = true
    end

    if (self.CharacterSettings.AutoAcceptInvitesGC == nil) then
        self.CharacterSettings.AutoAcceptInvitesGC = true
    end
    
    -- Register the options relevant to this module
    SalesTools.AddonOptions.AutoInvite = {
        name = L["AutoInv"],
        type = "group",
        args= {
            autoinv = {
                name = L["AutoInv_Enabled_Option_Name"],
                desc = "|cffaaaaaa" .. L["AutoInv_Enabled_Option_Desc"] .. "|r",
                descStyle = "inline",
                width = "full",
                type = "toggle",
                order = 8,
                set = function(info, val)
                    SalesTools.AutoInvite:ToggleInvite(val)
                end,
                get = function(info)
                    return SalesTools.db.char.AutoInviteEnabled
                end
            },
            autoinvwords = {
                name = L["AutoInv_Keywords_Option_Name"],
                desc = "|cffaaaaaa" .. L["AutoInv_Keywords_Option_Desc"] .. "|r",
                width = "full",
                type = "input",
                order = 9,
                set = function(info, val)
                    if val ~= "" then
                        SalesTools.db.char.AutoInviteKeys = val
        
                    else
                        SalesTools:Print(L["AutoInv_Options_No_Empty"])
                    end
                end,
                get = function(info)
                    return SalesTools.db.char.AutoInviteKeys
                end
            },
            autoacceptinv = {
                name = L["AutoInv_Auto_Accept_Option_Name"],
                desc = "|cffaaaaaa" .. L["AutoInv_Auto_Accept_Option_Desc"] .. "|r",
                descStyle = "inline",
                width = "full",
                type = "toggle",
                order = 10,
                set = function(info, val)
                    SalesTools.AutoInvite:ToggleAccepts(val)
                end,
                get = function(info)
                    return SalesTools.db.char.AutoAcceptInvites
                end
            },
            autoacceptinvgconly = {
                name = L["AutoInv_Auto_Accept_Collector_Option_Name"],
                desc = "|cffaaaaaa" .. L["AutoInv_Auto_Accept_Collector_Option_Desc"] .. "|r",
                descStyle = "inline",
                width = "full",
                type = "toggle",
                order = 11,
                set = function(info, val)
                    SalesTools.db.char.AutoAcceptInvitesGC = val
                end,
                get = function(info)
                    return SalesTools.db.char.AutoAcceptInvitesGC
                end
            },
        },
    }

    -- Register our events
    if (self.CharacterSettings.AutoInviteEnabled) then
        AutoInvite:RegisterEvent('CHAT_MSG_WHISPER', 'CHAT_MSG_WHISPER')
        AutoInvite:RegisterEvent('CHAT_MSG_BN_WHISPER', 'CHAT_MSG_BN_WHISPER')

    end
    if (self.CharacterSettings.AutoAcceptInvites) then
        AutoInvite:RegisterEvent('PARTY_INVITE_REQUEST', 'PARTY_INVITE_REQUEST')

    end
end

function AutoInvite:ToggleInvite(state)
    -- Toggle auto inviting on or off
    SalesTools:Debug("AutoInvite:ToggleInvite")

    self.CharacterSettings.AutoInviteEnabled = state

    if (state) then
        AutoInvite:RegisterEvent('CHAT_MSG_WHISPER', 'CHAT_MSG_WHISPER')
        AutoInvite:RegisterEvent('CHAT_MSG_BN_WHISPER', 'CHAT_MSG_BN_WHISPER')
    else
        AutoInvite:UnregisterEvent('CHAT_MSG_WHISPER', 'CHAT_MSG_WHISPER')
        AutoInvite:UnregisterEvent('CHAT_MSG_BN_WHISPER', 'CHAT_MSG_BN_WHISPER')
    end
end

function AutoInvite:ToggleAccepts(state)
    -- Toggle auto accepting of invites on or off
    SalesTools:Debug("AutoInvite:ToggleAccepts")

    self.CharacterSettings.AutoAcceptInvites = state

    if (state) then
        AutoInvite:RegisterEvent('PARTY_INVITE_REQUEST', 'PARTY_INVITE_REQUEST')
    else
        AutoInvite:UnregisterEvent('PARTY_INVITE_REQUEST', 'PARTY_INVITE_REQUEST')
    end
end

function AutoInvite:PARTY_INVITE_REQUEST(event, ...)
    -- Handler for PART_INVITE_REQUEST events
    SalesTools:Debug("AutoInvite:PARTY_INVITE_REQUEST")

    local name, isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles, inviterGUID, questSessionActive = ...

    if self.CharacterSettings.AutoAcceptInvites then
        if (self.CharacterSettings.AutoAcceptInvitesGC) then
            if (not isNativeRealm and name == self.GlobalSettings.PrimaryCollectorChar) then
                AcceptGroup()
                StaticPopup_Hide("PARTY_INVITE")
                SalesTools:Print(string.format(L["AutoInv_Accepted_Invite"], name))
            else
                local _, realm = UnitFullName("player")
                i, j = string.find(self.GlobalSettings.PrimaryCollectorChar, "-")
                if (self.GlobalSettings.PrimaryCollectorChar == name .. "-" .. realm) then
                    AcceptGroup()
                    StaticPopup_Hide("PARTY_INVITE")
                    SalesTools:Print(string.format(L["AutoInv_Accepted_Invite"], name))
                end


            end

        else
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
            SalesTools:Print(string.format(L["AutoInv_Accepted_Invite"], name))
        end


    end
end

function AutoInvite:CHAT_MSG_WHISPER(event, ...)
    -- Handler for CHAT_MSG_WHISPER events
    SalesTools:Debug("AutoInvite:CHAT_MSG_WHISPER")

    local msg, user, special = ...
    msg = string.lower(msg)
    if not (self:IsKeyword(msg)) then
        return
    end

    if not IsInRaid() and GetNumGroupMembers() == 5 and UnitLevel("player") >= 10 and UnitIsGroupLeader("player") then
        C_PartyInfo.ConvertToRaid()
    end
    SalesTools:Print(string.format(L["AutoInv_Attempt_Invite"],user))
    C_PartyInfo.InviteUnit(user)


end

function AutoInvite:CHAT_MSG_BN_WHISPER(event, ...)
    -- Handler for CHAT_MSG_BN_WHISPER events
    SalesTools:Debug("AutoInvite:CHAT_MSG_BN_WHISPER")

    local msg, playerName, _, _, _, _, _, _, _, _, _, _, bnSenderID = ...
    msg = string.lower(msg)
    if not (self:IsKeyword(msg)) then
        return
    end
    if not IsInRaid() and GetNumGroupMembers() == 5 and UnitLevel("player") >= 10 and UnitIsGroupLeader("player") then
        C_PartyInfo.ConvertToRaid()
    end

    if (not BNIsSelf(bnSenderID)) then
        local index = BNGetFriendIndex(bnSenderID)
        local gameAccs = C_BattleNet.GetFriendNumGameAccounts(index)
        for i = 1, gameAccs do
            local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
            local player = gameAccountInfo.characterName
            local realmName = gameAccountInfo.realmName
            local realmDisplayName = gameAccountInfo.realmDisplayName
            local faction = gameAccountInfo.factionName
            if gameAccountInfo.clientProgram == "WoW" and gameAccountInfo.wowProjectID == 1 and realmName and realmDisplayName and player and UnitFactionGroup('player') == faction then
                if realmDisplayName ~= GetRealmName() then
                    player = player .. "-" .. realmName
                end
                SalesTools:Print(string.format(L["AutoInv_Attempt_Invite"],player ))
                C_PartyInfo.InviteUnit(player)
            end
        end
    end

end

function AutoInvite:IsKeyword(val)
    -- Check if a string is one of the auto invite keywords
    SalesTools:Debug("AutoInvite:IsKeyword")
    
    local keywordsList = {};
    for match in (self.CharacterSettings.AutoInviteKeys .. ","):gmatch("(.-)" .. ",") do
        table.insert(keywordsList, match:lower());
    end

    for index, value in ipairs(keywordsList) do
        if value == val:lower() then
            return true
        end
    end

    return false
end
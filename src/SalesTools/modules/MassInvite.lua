-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local MassInvite = SalesTools:NewModule("MassInvite", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local StdUi = LibStub('StdUi')

function MassInvite:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("MassInvite:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Mass Inviter Variables
    self.WAITING_STRING = L["MassInvite_Pending"]
    self.DECLINED_STRING = L["MassInvite_Declined"]
    self.IN_RAID_STRING = L["MassInvite_In_Raid"]
    self.NOEXIST_STRING = L["MassInvite_Offline"]
    self.BUSY_STRING = L["MassInvite_Busy"]
    self.PendingInvites = {}
    self.ExpectingEvent = false

    -- Register the module's minimap button
    table.insert(SalesTools.MinimapMenu, { text = L["MassInvite_Toggle"], notCheckable = true, func = function()
        if (SalesTools.MassInvite) then
            SalesTools.MassInvite:Toggle()
        end
    end })

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.invite = {
        desc = L["MassInvite_Command_Desc"],
        action = function()
            if (SalesTools.MassInvite) then
                SalesTools.MassInvite:Toggle()
            end
        end,
    }
end

function MassInvite:Toggle()
    -- Toggle visibility of the Mass Inviter window
    SalesTools:Debug("MassInvite:Toggle")

    if (self.MassInviteFrame == nil) then
        self:DrawInviteWindow()
    elseif self.MassInviteFrame:IsVisible() then
        self.MassInviteFrame:Hide()
    else
        self.MassInviteFrame:Show()
    end
end

function MassInvite:DrawInviteWindow()
    -- Draw the mass invite window
    SalesTools:Debug("MassInvite:DrawInviteWindow")

    local MassInviteFrame = StdUi:Window(UIParent, 300, 400, L["MassInvite_Window_Title"])
    MassInviteFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    MassInviteFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())
    MassInviteFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    StdUi:MakeResizable(MassInviteFrame, "BOTTOMRIGHT")
    MassInviteFrame:SetMinResize(250, 332)
    MassInviteFrame:SetMaxResize(500, 664)
    MassInviteFrame:IsUserPlaced(true);

    local EditBox = StdUi:MultiLineBox(MassInviteFrame, 280, 300, nil)
    EditBox:SetAlpha(0.75)
    StdUi:GlueAcross(EditBox, MassInviteFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local IconFrame = StdUi:Frame(MassInviteFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, MassInviteFrame, -10, 10, "RIGHT")

    local inviteButton = StdUi:Button(MassInviteFrame, 80, 30, L["MassInvite_Invite_Button"])
    StdUi:GlueBottom(inviteButton, MassInviteFrame, 0, 10, 'CENTER')
    inviteButton:SetScript('OnClick', function()
        MassInvite:ParseInviteInput()
        MassInvite:InvitePlayers()
        self.MassInviteFrame:Hide()
    end)

    self.MassInviteFrame = MassInviteFrame
    self.MassInviteFrame.EditBox = EditBox
end

function MassInvite:ParseInviteInput()
    -- Parse the invite panel's editbox; split on newline, ignore whitespace, append realm if missing
    SalesTools:Debug("MassInvite:ParseInviteInput")

    wipe(self.PendingInvites)
    local input = self.MassInviteFrame.EditBox:GetText()
    local parsedInput = string.gmatch(input, "[^\r\n]+")
    for entry in parsedInput do
        local subEntries = {}
        for subEntry in (entry):gmatch("[^:]+") do
            table.insert(subEntries, subEntry)
        end
        local player = subEntries[1] or ""
        local balance = subEntries[2] or 0
        if (player and not player:find("-")) then
            player = player .. "-" .. select(2, UnitFullName("player"))
        end
        self.PendingInvites[#self.PendingInvites + 1] = { name = player, balance = balance * 10000, timer = nil, status = MassInvite.WAITING_STRING, hasSentMessage = false } -- timer will be populated later
    end
end

function MassInvite:InvitePlayers()
    -- Draw the progress window, then invite all players we tracked in ParseInviteInput.
    SalesTools:Debug("MassInvite:InvitePlayers")

    if (self.PendingInvites) then
        if (self.InviteProgressWindow) then
            self.MassInviteFrame:Hide()
            self.InviteProgressWindow:Show()
        else
            MassInvite:DrawProgressWindow()
        end

        for _, player in pairs(self.PendingInvites) do
            C_PartyInfo.InviteUnit(player.name)
        end
    end
end

function MassInvite:DrawProgressWindow()
    -- Draw our data table showing the status/progress of each invite
    SalesTools:Debug("MassInvite:DrawProgressWindow")

    local InviteProgressWindow = StdUi:Window(UIParent, 575, 330, L["MassInvite_Progress_Window_Title"])
    InviteProgressWindow:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    InviteProgressWindow:SetFrameLevel(SalesTools:GetNextFrameLevel())
    InviteProgressWindow:SetResizable(false)
    InviteProgressWindow:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    InviteProgressWindow:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    local cols = {
        {
            name = "",
            width = 32,
            align = "LEFT",
            index = "icon",
            format = "icon",
            defaultSort = "asc"
        },
        {
            name = L["MassInvite_Viewer_Name"],
            width = 200,
            align = "LEFT",
            index = "name",
            format = "string",
        },
        {
            name = L["MassInvite_Viewer_Status"],
            width = 125,
            align = "CENTER",
            index = "status",
            format = "string"
        },
        {
            name = L["MassInvite_Viewer_Time"],
            width = 50,
            align = "CENTER",
            index = "timeLeft",
            format = "string"
        },
        {
            name = "",
            width = 32,
            align = "CENTER",
            index = "inviteTexture",
            format = "icon",
            texture = true,
            events = {
                OnClick = function(rowFrame, cellFrame, data, cols, row, realRow, column, table, button, ...)
                    C_PartyInfo.InviteUnit(cols.name)
                end,
            },
        },

    }

    local tbl = StdUi:ScrollTable(InviteProgressWindow, cols, 15, 16);
    StdUi:GlueTop(tbl, InviteProgressWindow, 0, -50)--, -10, 50)

    self.InviteProgressWindow = InviteProgressWindow
    self.InviteProgressWindow.table = tbl

    local IconFrame = StdUi:Frame(InviteProgressWindow, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)

    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, InviteProgressWindow, -10, 10, "RIGHT")

    self.InviteProgressWindow:SetResizable(false)

    MassInvite:UpdateProgressWindow()
end

function MassInvite:UpdateProgressWindow()
    -- Update our progress/status window
    SalesTools:Debug("MassInvite:UpdateProgressWindow")

    if (not MassInvite.InviteProgressWindow) then
        MassInvite:DrawProgressWindow()
    end
    
    local data = {}
    local currentMembers = {}
    local playersMissing = false
    local ongoingTimers = false

    -- Track all of the players in our group.
    for i = 1, MAX_RAID_MEMBERS do
        local name = GetRaidRosterInfo(i)
        if (name ~= nil) then
            if (not name:find("-")) then
                name = name .. "-" .. select(2, UnitFullName("player"))
            end
            currentMembers[name:lower()] = true
        end
    end

    if (MassInvite.PendingInvites) then
        for _, player in pairs(MassInvite.PendingInvites) do
            local icon
            local timeLeft
            -- For each player we've invited, check to see if they're in the group.
            local inRaid = currentMembers[player.name:lower()] ~= nil
            if (inRaid) then
                -- If they are, we're happy. Cancel their timer and mark them as in the raid.
                player.status = MassInvite.IN_RAID_STRING
                icon = 237554 -- happy
                MassInvite:CancelTimer(player.timer)
                timeLeft = "N/A"
            else
                -- If they're not, but we still have a timer running, we're just waiting.
                playersMissing = true
                local remaining = MassInvite:TimeLeft(player.timer)
                if (remaining > 0) then
                    ongoingTimers = true
                    icon = 237555 -- sad
                    timeLeft = math.ceil(remaining)
                else
                    -- If there's no timer running, but we don't have a more specific status, it must have expired.
                    icon = 237553 -- mad
                    timeLeft = "N/A"
                    if (player.status == MassInvite.WAITING_STRING) then
                        player.status = "Expired"
                    end
                end
            end
            balanceTexture = (not player.hasSentMessage and [=[Interface\Buttons\UI-GuildButton-MOTD-Up]=]) or [=[Interface\Buttons\UI-GuildButton-MOTD-Disabled]=]
            table.insert(data, { icon = icon, name = player.name, balance = player.balance, status = player.status, timeLeft = timeLeft, inviteTexture = [=[Interface\Buttons\UI-RefreshButton]=], balanceTexture = balanceTexture })
        end
    end

    MassInvite.InviteProgressWindow.table:SetData(data, true)
    -- Keep refreshing while we're missing players and we have ongoing timers.
    local continueUpdating = playersMissing and ongoingTimers
    if (continueUpdating) then
        if (not MassInvite.progressTimer) then
            -- Refresh the progress window every second, but make sure we don't spawn a billion timers.
            MassInvite.progressTimer = MassInvite:ScheduleRepeatingTimer(function()
                MassInvite.UpdateProgressWindow()
            end, 1)
        end
    else
        -- If we feel we have everyone we invited, shut down everything.
        MassInvite:CancelTimer(MassInvite.progressTimer)
        MassInvite.progressTimer = nil
        MassInvite:UnregisterEvent("GROUP_ROSTER_UPDATE", "OnEvent")
        MassInvite:UnregisterEvent("CHAT_MSG_SYSTEM", "OnEvent")
        if (MassInvite.PendingInvites) then
            local anyBalanceLeft = false
            for _, player in pairs(MassInvite.PendingInvites) do
                if (player.balance > 0) then
                    anyBalanceLeft = true
                end
            end

            if (not anyBalanceLeft) then
                MassInvite:UnregisterEvent("TRADE_ACCEPT_UPDATE", "OnEvent")
            end
        end
    end
end

function MassInvite:OnEvent(event, ...)
    -- Events handler
    SalesTools:Debug("MassInvite:OnEvent", event)

    if (event == "GROUP_ROSTER_UPDATE") then
        if (not self.InviteProgressWindow) then
            MassInvite:DrawProgressWindow()
            MassInvite:UpdateProgressWindow()
        elseif (self.InviteProgressWindow:IsVisible()) then
            MassInvite:UpdateProgressWindow()
        end
    elseif (event == "TRADE_ACCEPT_UPDATE") then
        local fullName = MassInvite:EnsureFullName(GetUnitName("NPC")):lower()
        local trackedPlayer = MassInvite:GetTrackedPlayer(fullName)
        local playerAccept, targetAccept = ...
        if (playerAccept == 1 and targetAccept == 1 and trackedPlayer) then
            trackedPlayer.balance = trackedPlayer.balance - GetTargetTradeMoney()
            MassInvite.PendingInvites[trackedPlayer.index] = trackedPlayer
            MassInvite:UpdateProgressWindow()
        end
    elseif (event == "CHAT_MSG_SYSTEM") then
        -- No good way of handling failed group invites, unfortunately. Parse system messages to try to glean failure reasons.
        if (MassInvite.InviteProgressWindow and MassInvite.InviteProgressWindow:IsVisible()) then
            local message = select(1, ...)
            -- Player declines your group invitation
            if (message:find("declines your group invitation.", 1, true)) then
                local player = string.sub(message, 1, message:find(" ") - 1)
                local fullName = MassInvite:EnsureFullName(player):lower()
                local trackedPlayer = MassInvite:GetTrackedPlayer(fullName)
                if (trackedPlayer) then
                    MassInvite:CancelTimer(trackedPlayer.timer)
                    trackedPlayer.status = MassInvite.DECLINED_STRING
                end
                MassInvite:UpdateProgressWindow()
                -- Cannot find player 'Player'
            elseif (message:find("Cannot find player")) then
                local player = string.match(message, "%b''")
                player = string.gsub(player, "'", '')
                local fullName = MassInvite:EnsureFullName(player):lower()
                local trackedPlayer = MassInvite:GetTrackedPlayer(fullName)
                if (trackedPlayer) then
                    MassInvite:CancelTimer(trackedPlayer.timer)
                    trackedPlayer.status = MassInvite.NOEXIST_STRING
                end
                MassInvite:UpdateProgressWindow()
                -- Player is already in a group
            elseif message:find("is already in a group", 1, true) then
                local player = string.sub(message, 1, message:find(" ") - 1)
                local fullName = MassInvite:EnsureFullName(player):lower()
                local trackedPlayer = MassInvite:GetTrackedPlayer(fullName)
                if (trackedPlayer) then
                    local timeRemaining = MassInvite:TimeLeft(trackedPlayer.timer)
                    -- kinda jank, but this should help differentiate busy in other group vs. busy accepting our inv
                    if (trackedPlayer and not MassInvite:IsPlayerInRaid(player) and timeRemaining > 58) then
                        MassInvite:CancelTimer(trackedPlayer.timer)
                        trackedPlayer.status = MassInvite.DECLINED_STRING
                        MassInvite:UpdateProgressWindow()
                    end
                end
            end
        end
    end
end

function MassInvite:EnsureFullName(name)
    -- Force full name(s) for any players
    SalesTools:Debug("MassInvite:EnsureFullName", name)

    if (not name:find("-")) then
        name = name .. "-" .. select(2, UnitFullName("player"))
    end

    return name
end

function MassInvite:IsPlayerInRaid(player)
    -- Check if a player is in the group by name
    SalesTools:Debug("MassInvite:IsPlayerInRaid", player)

    for i = 1, MAX_RAID_MEMBERS do
        local name = GetRaidRosterInfo(i)
        if (player == name) then
            return true
        end
    end

    return false
end

function MassInvite:GetTrackedPlayer(fullName)
    -- If the player is in our players to invite, get them and their index.
    SalesTools:Debug("MassInvite:GetTrackedPlayer", fullName)

    if (self.PendingInvites) then
        for i, player in pairs(self.PendingInvites) do
            if (player.name:lower() == fullName:lower()) then
                player.index = i
                return player
            end
        end
    end
end

hooksecurefunc(C_PartyInfo, "InviteUnit", function(player)
    -- Intercept invites; if the progress window is open, track them.
    SalesTools:Debug("C_PartyInfo.InviteUnit", player)

    if (MassInvite.InviteProgressWindow and MassInvite.InviteProgressWindow:IsVisible()) then
        MassInvite:RegisterEvent("GROUP_ROSTER_UPDATE", "OnEvent")
        MassInvite:RegisterEvent("CHAT_MSG_SYSTEM", "OnEvent")
        MassInvite:RegisterEvent("TRADE_ACCEPT_UPDATE", "OnEvent")
        local fullName = MassInvite:EnsureFullName(player):lower()
        local trackedPlayer = MassInvite:GetTrackedPlayer(fullName)
        if (trackedPlayer) then
            if (MassInvite:TimeLeft(trackedPlayer.timer) == 0) then
                local timer = MassInvite:ScheduleTimer(function()
                end, 60)
                trackedPlayer.timer = timer
                trackedPlayer.status = MassInvite.WAITING_STRING
                MassInvite.PendingInvites[trackedPlayer.index] = trackedPlayer
                MassInvite:UpdateProgressWindow()
            end
        else
            local timer = MassInvite:ScheduleTimer(function()
            end, 60)
            MassInvite.PendingInvites[#MassInvite.PendingInvites + 1] = { name = fullName, timer = timer, balance = trackedPlayer.balance, status = MassInvite.WAITING_STRING, hasSentMessage = false }
            MassInvite:UpdateProgressWindow()
        end
    end
end)


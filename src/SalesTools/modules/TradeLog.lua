-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local TradeLog = SalesTools:NewModule("TradeLog", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local StdUi = LibStub("StdUi")

function TradeLog:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("TradeLog:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Trade variables
    self.PendingTradeContents = {}
    self.TradeTargetName = ""

    -- Register the module's minimap button
    table.insert(SalesTools.MinimapMenu, { text = L["TradeLog_Toggle"], notCheckable = true, func = function()
        if (SalesTools.TradeLog) then
            SalesTools.TradeLog:Toggle()
        end
    end })

    -- Write our defaults to the DB if they don't exist
    if (self.GlobalSettings.TradeLog == nil) then
        self.GlobalSettings.TradeLog = {}
    end

    if (self.GlobalSettings.WhisperAfterTrade == nil) then
        self.GlobalSettings.WhisperAfterTrade = true
    end

    if (self.GlobalSettings.TradeWhisperSuffix == nil) then
        self.GlobalSettings.TradeWhisperSuffix = ""
    end

    -- Register the options relevant to this module
    SalesTools.AddonOptions.TradeLog = {
        name = L["TradeLog"],
        type = "group",
        args={
            WhisperAfterTrade = {
                name = L["TradeLog_WhisperOptionName"],
                desc = "|cffaaaaaa" .. L["TradeLog_WhisperOptionDesc"] .. "|r",
                descStyle = "inline",
                width = "full",
                type = "toggle",
                set = function(info, val)
                    SalesTools.db.global.WhisperAfterTrade = val
                end,
                get = function(info)
                    return SalesTools.db.global.WhisperAfterTrade
                end
            },
            TradeWhisperSuffix = {
                name = L["TradeLog_WhisperSuffixName"],
                desc = "|cffaaaaaa" .. L["TradeLog_WhisperSuffixDesc"] .. "|r",
                width = "full",
                type = "input",
                set = function(info, val)
                    SalesTools.db.global.TradeWhisperSuffix = val
                end,
                get = function(info)
                    return SalesTools.db.global.TradeWhisperSuffix
                end
            },
        }
    }

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.tradelog = {
        desc = L["TradeLog_Command_Desc"],
        action = function()
            if (SalesTools.TradeLog) then
                SalesTools.TradeLog:Toggle()
            end
        end,
    }

    -- Register our events
    self:RegisterEvent("TRADE_ACCEPT_UPDATE", "OnEvent")
    self:RegisterEvent("UI_INFO_MESSAGE", "OnEvent")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
    self:RegisterEvent("TRADE_SHOW", "OnEvent")
end

function TradeLog:OnEvent(event, arg1, arg2, ...)
    -- Events handler
    SalesTools:Debug("TradeLog:OnEvent",event)

    if (event == "UI_ERROR_MESSAGE") then
        -- Special error cases
        if (arg2 == ERR_TRADE_BAG_FULL or arg2 == ERR_TRADE_MAX_COUNT_EXCEEDED or arg2 == ERR_TRADE_TARGET_BAG_FULL or arg2 == ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED) then
            SalesTools:Print(string.format(L["TradeLog_Trade_Cancelled"], TradeLog.TradeTargetName))
            TradeLog:Finish()
        end
    elseif (event == "UI_INFO_MESSAGE" and (arg2 == ERR_TRADE_CANCELLED or arg2 == ERR_TRADE_COMPLETE)) then
        -- Cancelled or success
        if (arg2 == ERR_TRADE_CANCELLED and self.TradeTargetName) then
            SalesTools:Print(string.format(L["TradeLog_Trade_Cancelled"], TradeLog.TradeTargetName))
            TradeLog:Finish()
        else
            SalesTools:Print(string.format(L["TradeLog_Trade_Completed"], TradeLog.TradeTargetName))
            self.GlobalSettings.TradeLog[#self.GlobalSettings.TradeLog + 1] = self.PendingTradeContents
            if self.GlobalSettings.WhisperAfterTrade then
                if (self.PendingTradeContents.playerGold > 0) then
                    SendChatMessage(string.format(L["TradeLog_Trade_Gave"], SalesTools:FormatRawCurrency(self.PendingTradeContents.playerGold),self.PendingTradeContents.target,self.GlobalSettings.TradeWhisperSuffix), "WHISPER", "COMMON", self.PendingTradeContents.target)
                elseif (self.PendingTradeContents.targetGold > 0) then
                    SendChatMessage(string.format(L["TradeLog_Trade_Received"], SalesTools:FormatRawCurrency(self.PendingTradeContents.targetGold),self.PendingTradeContents.target,self.GlobalSettings.TradeWhisperSuffix), "WHISPER", "COMMON", self.PendingTradeContents.target)
                end
            end
            TradeLog:PrintTradeContents()
            if (self.LogFrame) then
                C_Timer.After(1, function()
                    TradeLog:SearchTrades(self.LogFrame.SearchBox:GetText())
                end)
            end
            TradeLog:Finish()
        end
    elseif (event == "TRADE_SHOW") then
        local name, realm = UnitName("NPC")
        if realm ~= nil then
            self.TradeTargetName = name .. "-" .. realm:gsub(' ','')
        else
            self.TradeTargetName = name
        end
    elseif (event == "TRADE_ACCEPT_UPDATE") then
        local playerGoldOffer = GetPlayerTradeMoney()
        local targetGoldOffer = GetTargetTradeMoney()
        local playerItemOffers = ""
        local targetItemOffers = ""

        for i = 1, 6 do
            local name, _, numItems, quality = GetTradePlayerItemInfo(i)
            if (name) then
                playerItemOffers = playerItemOffers .. ITEM_QUALITY_COLORS[quality].hex .. name .. "|r x " .. numItems .. "|n"
            end
        end

        for i = 1, 6 do
            local name, _, numItems, quality = GetTradeTargetItemInfo(i)
            if (name) then
                targetItemOffers = targetItemOffers .. ITEM_QUALITY_COLORS[quality].hex .. name .. "|r x " .. numItems .. "|n"
            end
        end

        self.PendingTradeContents = { date = date("%Y-%m-%d %X (%A)"), player = TradeLog:EnsureFullName(UnitName("player")), target = TradeLog:EnsureFullName(self.TradeTargetName), playerGold = playerGoldOffer, targetGold = targetGoldOffer, playerItems = playerItemOffers, targetItems = targetItemOffers }
    end
end

function TradeLog:PrintTradeContents()
    -- Write the trade contents on success
    SalesTools:Debug("TradeLog:PrintTradeContents")

    if (self.PendingTradeContents) then
        if (self.PendingTradeContents.playerGold or self.PendingTradeContents.playerItems) then
            print("|CFFFFFF00 Gave:")
            if (self.PendingTradeContents.playerGold and self.PendingTradeContents.playerGold > 0) then
                print("    |CFFFFFF00" .. SalesTools:FormatRawCurrency(self.PendingTradeContents.playerGold) .. "g")
            end

            if (self.PendingTradeContents.playerItems and self.PendingTradeContents.playerItems ~= "") then
                print("    " .. self.PendingTradeContents.playerItems)
            end
        end

        if (self.PendingTradeContents.targetGold or self.PendingTradeContents.targetItems) then
            print("|CFFFFFF00 Received:")
            if (self.PendingTradeContents.targetGold and self.PendingTradeContents.targetGold > 0) then
                print("    |CFFFFFF00" .. SalesTools:FormatRawCurrency(self.PendingTradeContents.targetGold) .. "g")
            end

            if (self.PendingTradeContents.targetItems and self.PendingTradeContents.targetItems ~= "") then
                print("    " .. self.PendingTradeContents.targetItems)
            end
        end
    end
end

function TradeLog:Toggle()
    -- Toggle the visibility of the Trade Logs window
    SalesTools:Debug("TradeLog:Toggle")

    if (self.LogFrame == nil) then
        self:DrawWindow()
        self:DrawSearchPane()
        self:DrawSearchResultsTable()
        self:SearchTrades("")
    elseif self.LogFrame:IsVisible() then
        self.LogFrame:Hide()
    else
        self.LogFrame:Show()
        self:SearchTrades("")
    end
end

function TradeLog:SearchTrades(filter)
    -- Very rough search, returns any row with any field containing the user input text
    SalesTools:Debug("TradeLog:SearchTrades")

    local LogFrame = self.LogFrame
    local SearchFilter = filter:lower()
    local allResults = self.GlobalSettings.TradeLog
    local FilteredResults = {}
    local player = SalesTools:GetPlayerFullName()
    local AllCharactersOptiond = LogFrame.AllCharactersOption:GetChecked()
    local TodayFilterOptiond = LogFrame.TodayFilterOption:GetChecked()
    local date = date("%Y-%m-%d")
    for _, trade in pairs(allResults) do
        if (AllCharactersOptiond or ((trade.player and trade.player:lower():find(player:lower(), 1, true))) ~= nil)
                and (trade.date and (not TodayFilterOptiond or (string.sub(trade.date, 1, 10) == date)))
                and ((trade.playerGold and tostring(SalesTools:FormatRawCurrency(trade.playerGold)):find(SearchFilter, 1, true))
                or (trade.targetGold and tostring(SalesTools:FormatRawCurrency(trade.targetGold)):find(SearchFilter, 1, true))
                or (trade.target and trade.target:lower():find(SearchFilter, 1, true))
                or (trade.playerItems and trade.playerItems:lower():find(SearchFilter, 1, true))
                or (trade.targetItems and trade.targetItems:lower():find(SearchFilter, 1, true))) then
            table.insert(FilteredResults, trade)
        end
    end

    TradeLog:ApplyDefaultSort(FilteredResults)

    self.CurrentView = FilteredResults
    self.LogFrame.SearchResults:SetData(self.CurrentView, true)
    TradeLog:UpdateStateText()
    TradeLog:UpdateResultsText()
end

function TradeLog:DrawWindow()
    -- Draw our Trade Logs Window
    SalesTools:Debug("TradeLog:DrawWindow")

    local LogFrame
    if (self.CharacterSettings.LogFrameSize ~= nil) then
        LogFrame = StdUi:Window(UIParent, self.CharacterSettings.LogFrameSize.width, self.CharacterSettings.LogFrameSize.height, "Trade Log Viewer")
    else
        LogFrame = StdUi:Window(UIParent, 1100, 700, "Trade Log Viewer")
    end

    if (self.CharacterSettings.LogFramePosition ~= nil) then
        LogFrame:SetPoint(self.CharacterSettings.LogFramePosition.point or "CENTER",
                self.CharacterSettings.LogFramePosition.UIParent,
                self.CharacterSettings.LogFramePosition.relPoint or "CENTER",
                self.CharacterSettings.LogFramePosition.relX or 0,
                self.CharacterSettings.LogFramePosition.relY or 0)
    else
        LogFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end

    LogFrame:SetScript("OnSizeChanged", function(self)
        TradeLog.CharacterSettings.LogFrameSize = { width = self:GetWidth(), height = self:GetHeight() }
    end)

    LogFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    LogFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        TradeLog.CharacterSettings.LogFramePosition = { point = point, relPoint = relPoint, relX = xOfs, relY = yOfs }
    end)

    StdUi:MakeResizable(LogFrame, "BOTTOMRIGHT")
    StdUi:MakeResizable(LogFrame, "TOPLEFT")
    LogFrame:SetResizeBounds(850, 250, 1280, 720)
    LogFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    local IconFrame = StdUi:Frame(LogFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)

    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, LogFrame, -10, 10, "RIGHT")

    LogFrame.ResultsLabel = StdUi:Label(LogFrame, nil, 16)
    StdUi:GlueBottom(LogFrame.ResultsLabel, LogFrame, 10, 5, "LEFT")

    local clearButton = StdUi:Button(LogFrame, 128, 16, L["TradeLog_Clear_Button"])
    StdUi:GlueBottom(clearButton, LogFrame, 0, 10, "CENTER")

    clearButton:SetScript("OnClick", function()
        TradeLog:DrawClearWarningWindow()
    end)

    self.LogFrame = LogFrame
end

function TradeLog:DrawClearWarningWindow()
    -- Draw a warning window for deleting all table entries
    SalesTools:Debug("TradeLog:DrawClearWarningWindow")

    local buttons = {
        character = {
            text = "This Character",
            onClick = function(b)
                TradeLog:ClearTradesForCharacter()
                b.window:Hide()
            end
        },
        all = {
            text = "All Trades",
            onClick = function(b)
                TradeLog:ClearAllTrades()
                b.window:Hide()
            end
        },
    }

    StdUi:Confirm("Clear Log", L["TradeLog_Clear_Warning"], buttons, 1)
end

function TradeLog:ClearTradesForCharacter()
    -- Remove all DB entries relating to the current character
    SalesTools:Debug("TradeLog:ClearTradesForCharacter")

    local player = SalesTools:GetPlayerFullName()
    for index, trade in pairs(self.GlobalSettings.TradeLog) do
        if trade.source == player or trade.destination == player then
            self.GlobalSettings.TradeLog[index] = nil
        end
    end

    if (self.LogFrame) then
        TradeLog:SearchTrades(self.LogFrame.SearchBox:GetText())
    end
end

function TradeLog:ClearAllTrades()
    -- Remove all DB entries
    SalesTools:Debug("TradeLog:ClearAllTrades")

    for index, trade in pairs(self.GlobalSettings.TradeLog) do
        self.GlobalSettings.TradeLog[index] = nil
    end
    if (self.LogFrame) then
        TradeLog:SearchTrades(self.LogFrame.SearchBox:GetText())
    end
end

function TradeLog:DrawSearchPane()
    -- Draw the search box
    SalesTools:Debug("TradeLog:DrawSearchPane")

    local LogFrame = self.LogFrame
    local SearchBox = StdUi:Autocomplete(LogFrame, 400, 30, "", nil, nil, nil)
    StdUi:ApplyPlaceholder(SearchBox, L["TradeLog_Search_Button"], [=[Interface\Common\UI-Searchbox-Icon]=])
    SearchBox:SetFontSize(16)

    local Search_Button = StdUi:Button(LogFrame, 80, 30, L["TradeLog_Search_Button"])

    StdUi:GlueTop(SearchBox, LogFrame, 10, -40, "LEFT")
    StdUi:GlueTop(Search_Button, LogFrame, 420, -40, "LEFT")

    SearchBox:SetScript("OnEnterPressed", function()
        TradeLog:SearchTrades(SearchBox:GetText())
    end)
    Search_Button:SetScript("OnClick", function()
        TradeLog:SearchTrades(SearchBox:GetText())
    end)

    local AllCharactersOption = StdUi:Checkbox(LogFrame, L["TradeLog_AllChars_Option_Label"])
    StdUi:GlueRight(AllCharactersOption, Search_Button, 10, 0)
    AllCharactersOption.OnValueChanged = function(self, state)
        TradeLog:SearchTrades(SearchBox:GetText())
    end
    local AllCharactersOptionTooltip = StdUi:FrameTooltip(AllCharactersOption, L["TradeLog_AllChars_Option"], "tooltip", "RIGHT", true)

    local TodayFilterOption = StdUi:Checkbox(LogFrame, L["TradeLog_TodayFilter_Option_Label"])
    StdUi:GlueRight(TodayFilterOption, AllCharactersOption, 10, 0)
    TodayFilterOption.OnValueChanged = function(self, state)
        TradeLog:SearchTrades(SearchBox:GetText())
    end
    local TodayFilterOptionTooltip = StdUi:FrameTooltip(TodayFilterOption, L["TradeLog_TodayFilter_Option"], "tooltip", "RIGHT", true)

    LogFrame.AllCharactersOption = AllCharactersOption
    LogFrame.TodayFilterOption = TodayFilterOption
    LogFrame.SearchBox = SearchBox
    LogFrame.Search_Button = Search_Button
end

function TradeLog:DrawSearchResultsTable()
    -- Draw our results table
    SalesTools:Debug("TradeLog:DrawSearchResultsTable")

    local LogFrame = self.LogFrame

    local function showTooltip(frame, show, text)
        if show and text ~= nil then
            GameTooltip:SetOwner(frame);
            GameTooltip:SetText(text)
        else
            GameTooltip:Hide();
        end
    end

    local cols = {
        {
            name = L["TradeLog_Viewer_Date"],
            width = 215,
            align = "MIDDLE",
            index = "date",
            format = "string",
            defaultSort = "asc"
        },
        {
            name = L["TradeLog_Viewer_You"],
            width = 100,
            align = "MIDDLE",
            index = "player",
            format = "string",
        },
        {
            name = L["TradeLog_Viewer_Your_Gold"],
            width = 100,
            align = "MIDDLE",
            index = "playerGold",
            format = "money",
        },
        {
            name = L["TradeLog_Viewer_Your_Items"],
            width = 150,
            align = "LEFT",
            index = "playerItems",
            format = "string",
            events = {
                OnEnter = function(table, cellFrame, rowFrame, rowData, columnData, rowIndex)
                    local cellData = rowData[columnData.index];
                    if (rowData.playerItems) then
                        showTooltip(cellFrame, true, rowData.playerItems);
                    end
                    return true;
                end,
                OnLeave = function(rowFrame, cellFrame)
                    showTooltip(cellFrame, false);
                    return true;
                end
            },
        },
        {
            name = L["TradeLog_Viewer_Target"],
            width = 100,
            align = "LEFT",
            index = "target",
            format = "string",
        },
        {
            name = L["TradeLog_Viewer_Their_Gold"],
            width = 100,
            align = "MIDDLE",
            index = "targetGold",
            format = "money",
        },
        {
            name = L["TradeLog_Viewer_Their_Items"],
            width = 150,
            align = "LEFT",
            index = "targetItems",
            format = "string",
            events = {
                OnEnter = function(table, cellFrame, rowFrame, rowData, columnData, rowIndex)
                    local cellData = rowData[columnData.index];
                    if (rowData.targetItems) then
                        showTooltip(cellFrame, true, rowData.targetItems);
                    end
                    return true;
                end,
                OnLeave = function(rowFrame, cellFrame)
                    showTooltip(cellFrame, false);
                    return true;
                end
            },
        },

    }

    LogFrame.SearchResults = StdUi:ScrollTable(LogFrame, cols, 18, 29)
    LogFrame.SearchResults:SetDisplayRows(math.floor(LogFrame.SearchResults:GetWidth() / LogFrame.SearchResults:GetHeight()), LogFrame.SearchResults.rowHeight)
    LogFrame.SearchResults:EnableSelection(true)

    LogFrame.SearchResults:SetScript("OnSizeChanged", function(self)
        local tableWidth = self:GetWidth();
        local tableHeight = self:GetHeight();

        -- Determine total width of columns
        local total = 0;
        for i = 1, #self.columns do
            total = total + self.columns[i].width;
        end

        -- Adjust all column widths proportionally
        for i = 1, #self.columns do
            self.columns[i]:SetWidth((self.columns[i].width / total) * (tableWidth - 30));
        end

        -- Set the number of displayed rows according to the new height
        self:SetDisplayRows(math.floor(tableHeight / self.rowHeight), self.rowHeight);
    end)

    StdUi:GlueAcross(LogFrame.SearchResults, LogFrame, 10, -110, -10, 50)

    LogFrame.stateLabel = StdUi:Label(LogFrame.SearchResults, L["TradeLog_NoResults"])
    StdUi:GlueTop(LogFrame.stateLabel, LogFrame.SearchResults, 0, -40, "CENTER")
end

function TradeLog:ApplyDefaultSort(tableToSort)
    -- Apply our default sort settings
    SalesTools:Debug("TradeLog:ApplyDefaultSort")

    if (self.LogFrame.SearchResults.head.columns) then
        local isSorted = false

        for k, v in pairs(self.LogFrame.SearchResults.head.columns) do
            if (v.arrow:IsVisible()) then
                isSorted = true
            end
        end

        if (not isSorted) then
            return table.sort(tableToSort, function(a, b)
                return a["date"] > b["date"]
            end)
        end
    end

    return tableToSort
end

function TradeLog:UpdateStateText()
    -- Show a warning if no results were found
    SalesTools:Debug("TradeLog:UpdateStateText")

    if (#self.CurrentView > 0) then
        self.LogFrame.stateLabel:Hide()
    else
        self.LogFrame.stateLabel:SetText(L["TradeLog_NoResults"])
    end
end

function TradeLog:UpdateResultsText()
    -- Show the number of results in the current query
    SalesTools:Debug("TradeLog:UpdateResultsText")

    if (#self.CurrentView > 0) then
        self.LogFrame.ResultsLabel:SetText(string.format(L["TradeLog_CurrentResults"],tostring(#self.CurrentView)))
        self.LogFrame.ResultsLabel:Show()
    else
        self.LogFrame.ResultsLabel:Hide()
    end
end

function TradeLog:EnsureFullName(name)
    -- Require full player-realm format
    SalesTools:Debug("TradeLog:EnsureFullName")

    if (not name:find("-")) then
        name = name .. "-" .. select(2, UnitFullName("player"))
    end

    return name
end

function TradeLog:Finish()
    -- Run on trade completion
    SalesTools:Debug("TradeLog:Finish")

    self.PendingTradeContents = {}
    self.TradeTargetName = ""
end
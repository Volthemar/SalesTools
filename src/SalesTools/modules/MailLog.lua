-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local MailLog = SalesTools:NewModule("MailLog", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local StdUi = LibStub("StdUi")


function MailLog:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("MailLog:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Register the module's minimap button
    table.insert(SalesTools.MinimapMenu, { text = L["MailLog_Minimap_Desc"], notCheckable = true, func = function()
        if (SalesTools.MailLog) then
            SalesTools.MailLog:Toggle()
        end
    end })

    -- Write our defaults to the DB if they don't exist
    if (self.GlobalSettings.MailLog == nil) then
        self.GlobalSettings.MailLog = {}
    end

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.maillog = {
        desc = L["MailLog_Command_Desc"],
        action = function()
            if (SalesTools.MailLog) then
                SalesTools.MailLog:Toggle()
            end
        end,
    }

    -- Register our events
    self:RegisterEvent("MAIL_SUCCESS", "OnEvent")
    self:RegisterEvent("MAIL_INBOX_UPDATE", "OnEvent")
end

function MailLog:Toggle()
    -- Toggle visibility of the Mail Log Window
    SalesTools:Debug("MailLog:Toggle")

    if (self.LogFrame == nil) then
        self:DrawWindow()
        self:DrawSearchPane()
        self:DrawSearchResultsTable()
        self:SearchMail("")
    elseif self.LogFrame:IsVisible() then
        self.LogFrame:Hide()
    else
        self.LogFrame:Show()
        self:SearchMail("")
    end
end


function MailLog:SearchMail(filter)
    -- Very rough search, returns any row with any field containing the user input text
    SalesTools:Debug("MailLog:SearchMail")

    local LogFrame = self.LogFrame
    local SearchFilter = filter:lower()
    local allResults = self.GlobalSettings.MailLog
    local FilteredResults = {}
    local name, realm = UnitFullName("player")
    local player = name .. "-" .. realm
    local AllCharactersOptiond = LogFrame.AllCharactersOption:GetChecked()
    local TodayFilterOptiond = LogFrame.TodayFilterOption:GetChecked()
    local date = date("%Y-%m-%d")
    for _, mail in pairs(allResults) do
        if ((AllCharactersOptiond or ((mail.source and mail.source:lower():find(player:lower(), 1, true)) or (mail.destination and mail.destination:lower():find(player:lower(), 1, true))) ~= nil)
                and (mail.date and (not TodayFilterOptiond or (string.sub(mail.date, 1, 10) == date)))
                and (mail.subject and (mail.subject:lower():find(SearchFilter, 1, true))
                or (mail.body and mail.body:lower():find(SearchFilter, 1, true))
                or (mail.gold and tostring(floor(mail.gold / COPPER_PER_GOLD)):find(SearchFilter, 1, true))
                or (mail.source and mail.source:lower():find(SearchFilter, 1, true))
                or (mail.destination and mail.destination:lower():find(SearchFilter, 1, true))
                or (mail.date and mail.date:lower():find(SearchFilter, 1, true))
                or SearchFilter == "sent" and mail.sent
                or SearchFilter == "received" and not mail.sent)) then
            table.insert(FilteredResults, mail)
        end
    end

    MailLog:ApplyDefaultSort(FilteredResults)

    self.CurrentView = FilteredResults
    self.LogFrame.SearchResults:SetData(self.CurrentView, true)
    MailLog:UpdateStateText()
    MailLog:UpdateResultsText()
end


function MailLog:DrawWindow()
    -- Draw our Mail Logs Window
    SalesTools:Debug("MailLog:DrawWindow")

    local LogFrame
    if (self.CharacterSettings.LogFrameSize ~= nil) then
        LogFrame = StdUi:Window(UIParent, self.CharacterSettings.LogFrameSize.width, self.CharacterSettings.LogFrameSize.height, L["MailLog_Window_Title"])
    else
        LogFrame = StdUi:Window(UIParent, 1100, 700, L["MailLog_Window_Title"])
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
        MailLog.CharacterSettings.LogFrameSize = { width = self:GetWidth(), height = self:GetHeight() }
    end)

    LogFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        MailLog.CharacterSettings.LogFramePosition = { point = point, relPoint = relPoint, relX = xOfs, relY = yOfs }
    end)

    StdUi:MakeResizable(LogFrame, "BOTTOMRIGHT")
    StdUi:MakeResizable(LogFrame, "TOPLEFT")
    LogFrame:SetResizeBounds(850, 250,1280, 720)
    LogFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    LogFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    local IconFrame = StdUi:Frame(LogFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)

    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, LogFrame, -10, 10, "RIGHT")

    LogFrame.ResultsLabel = StdUi:Label(LogFrame, nil, 16)
    StdUi:GlueBottom(LogFrame.ResultsLabel, LogFrame, 10, 5, "LEFT")

    local clearButton = StdUi:Button(LogFrame, 128, 16, L["MailLog_Clear_Button"])
    StdUi:GlueBottom(clearButton, LogFrame, 0, 10, "CENTER")

    clearButton:SetScript("OnClick", function()
        MailLog:DrawClearWarningWindow()
    end)

    self.LogFrame = LogFrame
end

function MailLog:DrawClearWarningWindow()
    -- Draw a warning window for deleting all table entries
    SalesTools:Debug("MailLog:DrawClearWarningWindow")

    local buttons = {
        character = {
            text = "This Character",
            onClick = function(b)
                MailLog:ClearMailForCharacter()
                b.window:Hide()
            end
        },
        all = {
            text = "All Mail",
            onClick = function(b)
                MailLog:ClearAllMail()
                b.window:Hide()
            end
        },
    }

    StdUi:Confirm(L["MailLog_Clear_Button"], L["MailLog_Clear_Warning"], buttons, 1)
end

function MailLog:ClearMailForCharacter()
    -- Remove all DB entries relating to the current character
    SalesTools:Debug("MailLog:ClearMailForCharacter")

    local name, realm = UnitFullName("player")
    local player = name .. "-" .. realm
    for index, mail in pairs(self.GlobalSettings.MailLog) do
        if mail.source == player or mail.destination == player then
            self.GlobalSettings.MailLog[index] = nil
        end
    end

    if (self.LogFrame) then
        MailLog:SearchMail(self.LogFrame.SearchBox:GetText())
    end
end

function MailLog:ClearAllMail()
    -- Remove all DB entries
    SalesTools:Debug("MailLog:ClearAllMail")

    for index, mail in pairs(self.GlobalSettings.MailLog) do
        self.GlobalSettings.MailLog[index] = nil
    end
    if (self.LogFrame) then
        MailLog:SearchMail(self.LogFrame.SearchBox:GetText())
    end
end

function MailLog:DrawSearchPane()
    -- Draw the search box
    SalesTools:Debug("MailLog:DrawSearchPane")

    local LogFrame = self.LogFrame
    local SearchBox = StdUi:Autocomplete(LogFrame, 400, 30, "", nil, nil, nil)
    StdUi:ApplyPlaceholder(SearchBox, L["MailLog_Search_Button"], [=[Interface\Common\UI-Searchbox-Icon]=])
    SearchBox:SetFontSize(16)

    local Search_Button = StdUi:Button(LogFrame, 80, 30, L["MailLog_Search_Button"])

    StdUi:GlueTop(SearchBox, LogFrame, 10, -40, "LEFT")
    StdUi:GlueTop(Search_Button, LogFrame, 420, -40, "LEFT")

    SearchBox:SetScript("OnEnterPressed", function()
        MailLog:SearchMail(SearchBox:GetText())
    end)
    Search_Button:SetScript("OnClick", function()
        MailLog:SearchMail(SearchBox:GetText())
    end)

    local AllCharactersOption = StdUi:Checkbox(LogFrame, L["MailLog_AllChars_Option_Label"])
    StdUi:GlueRight(AllCharactersOption, Search_Button, 10, 0)
    AllCharactersOption.OnValueChanged = function(self, state)
        MailLog:SearchMail(SearchBox:GetText())
    end

    local AllCharactersOptionTooltip = StdUi:FrameTooltip(AllCharactersOption, L["MailLog_AllChars_Option"], "tooltip", "RIGHT", true)

    local TodayFilterOption = StdUi:Checkbox(LogFrame, L["MailLog_TodayFilter_Option_Label"])
    StdUi:GlueRight(TodayFilterOption, AllCharactersOption, 10, 0)
    TodayFilterOption.OnValueChanged = function(self, state)
        MailLog:SearchMail(SearchBox:GetText())
    end
    local TodayFilterOptionTooltip = StdUi:FrameTooltip(TodayFilterOption, L["MailLog_TodayFilter_Option"], "tooltip", "RIGHT", true)

    LogFrame.AllCharactersOption = AllCharactersOption
    LogFrame.TodayFilterOption = TodayFilterOption
    LogFrame.SearchBox = SearchBox
    LogFrame.Search_Button = Search_Button
end

function MailLog:DrawSearchResultsTable()
    -- Draw our results table
    SalesTools:Debug("MailLog:DrawSearchResultsTable")

    local LogFrame = self.LogFrame

    local function showTooltip(frame, show, text)
        if show then
            GameTooltip:SetOwner(frame);
            GameTooltip:SetText(text)
        else
            GameTooltip:Hide();
        end
    end

    local cols = {
        {
            name = L["MailLog_Viewer_DateSent"],
            width = 225,
            align = "MIDDLE",
            index = "date",
            format = "string",
            defaultSort = "asc"
        },
        {
            name = L["MailLog_Viewer_Sender"],
            width = 150,
            align = "MIDDLE",
            index = "source",
            format = "string",
        },
        {
            name = L["MailLog_Viewer_Recipient"],
            width = 150,
            align = "MIDDLE",
            index = "destination",
            format = "string",
        },
        {
            name = L["MailLog_Viewer_Gold"],
            width = 100,
            align = "LEFT",
            index = "gold",
            format = "money",
        },
        {
            name = L["MailLog_Viewer_Subject"],
            width = 150,
            align = "LEFT",
            index = "subject",
            format = "string",
        },
        {
            name = L["MailLog_Viewer_DateLooted"],
            width = 150,
            align = "MIDDLE",
            index = "openedDate",
            format = "string",
            compareSort = function(self, rowA, rowB, sortBy)
                local a = self:GetRow(rowA);
                local b = self:GetRow(rowB);
                local column = self.columns[sortBy];
                local idx = column.index;

                local direction = column.sort or column.defaultSort or 'asc';
                if direction:lower() == 'asc' then
                    return (a[idx] or "") > (b[idx] or "");
                else
                    return (a[idx] or "") < (b[idx] or "");
                end
            end
        },
        {
            name = L["MailLog_Viewer_Body"],
            width = 150,
            align = "LEFT",
            index = "body",
            format = "string",
            events = {
                OnEnter = function(table, cellFrame, rowFrame, rowData, columnData, rowIndex)
                    local cellData = rowData[columnData.index];
                    if (rowData.body) then
                        showTooltip(cellFrame, true, rowData.body);
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
    LogFrame.SearchResults:EnableSelection(true)
    LogFrame.SearchResults:SetDisplayRows(math.floor(LogFrame.SearchResults:GetWidth() / LogFrame.SearchResults:GetHeight()), LogFrame.SearchResults.rowHeight)

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

    LogFrame.stateLabel = StdUi:Label(LogFrame.SearchResults, L["MailLog_NoResults"])
    StdUi:GlueTop(LogFrame.stateLabel, LogFrame.SearchResults, 0, -40, "CENTER")
end

function MailLog:ApplyDefaultSort(tableToSort)
    -- Apply our default sort settings
    SalesTools:Debug("MailLog:ApplyDefaultSort")

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

function MailLog:UpdateStateText()
    -- Show a warning if no results were found
    SalesTools:Debug("MailLog:UpdateStateText")

    if (#self.CurrentView > 0) then
        self.LogFrame.stateLabel:Hide()
    else
        self.LogFrame.stateLabel:SetText(L["MailLog_NoResults"])
    end
end

function MailLog:UpdateResultsText()
    -- Show the number of results in the current query
    SalesTools:Debug("MailLog:UpdateResultsText")

    if (#self.CurrentView > 0) then
        self.LogFrame.ResultsLabel:SetText(string.format(L["MailLog_CurrentResults"], tostring(#self.CurrentView)))
        self.LogFrame.ResultsLabel:Show()
    else
        self.LogFrame.ResultsLabel:Hide()
    end
end

function MailLog:OnEvent(event)
    -- Bit lazy, but it allows the mail log to update in "real time"
    SalesTools:Debug("MailLog:OnEvent", event)

    if (self.LogFrame) then
        C_Timer.After(1, function()
            MailLog:SearchMail(self.LogFrame.SearchBox:GetText())
        end)
    end
end
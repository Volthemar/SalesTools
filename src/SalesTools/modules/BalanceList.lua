-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local BalanceList = SalesTools:NewModule("BalanceList", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local StdUi = LibStub('StdUi')
local LGBC = LibStub("LibGuildBankComm-1.0")



function BalanceList:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("BalanceList:OnEnable")

    -- Our databases/user settings
    self.CharacterSettings = SalesTools.db.char
    self.GlobalSettings = SalesTools.db.global

    -- Register the module's minimap button
    table.insert(SalesTools.MinimapMenu, { text = L["BalanceList_Toggle"], notCheckable = true, func = function()
        if (SalesTools.BalanceList) then
            SalesTools.BalanceList:Toggle()
        end
    end })

    -- Write our defaults to the DB if they don't exist
    if (self.GlobalSettings.BalanceList == nil) then
        self.GlobalSettings.BalanceList = {}
    end

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.balances = {
        desc = L["BalanceList_Command_Desc"],
        action = function()
            if (SalesTools.BalanceList) then
                SalesTools.BalanceList:Toggle()
            end
        end,
    }

    -- Register our events
    BalanceList:RegisterEvent("PLAYER_MONEY", "UpdateGold")
    BalanceList:RegisterEvent("GUILDBANKFRAME_CLOSED", "UpdateGold")
    BalanceList:RegisterEvent("GUILDBANKFRAME_OPENED", "UpdateGold")
    BalanceList:RegisterEvent("GUILDBANK_UPDATE_MONEY", "UpdateGold")
    self:UpdateGold()

end

function BalanceList:Toggle()
    -- Toggle the visibility of the Balance List Window
    SalesTools:Debug("BalanceList:Toggle")

    if (self.BalanceFrame == nil) then
        self:DrawWindow()
        self:DrawSearchPane()
        self:DrawSearchResultsTable()
        self:SearchEntries("")
    elseif self.BalanceFrame:IsVisible() then
        self.BalanceFrame:Hide()
    else
        self.BalanceFrame:Show()
        self:SearchEntries("")
    end
end

function BalanceList:SearchEntries(filter)
    -- Very rough search, returns any row with any field containing the user input text
    SalesTools:Debug("BalanceList:SearchEntries")

    local SearchFilter = filter:lower()
    local FilteredResults = {}

    for _, CharBalanceInfo in pairs(self.GlobalSettings.BalanceList) do
        if (_ and _:lower():find(SearchFilter, 1, true)) then
            --if (SalesTools:FormatRawCurrency(CharBalanceInfo["Personal"]) >= 1 or SalesTools:FormatRawCurrency(CharBalanceInfo["Guild"]) >= 1) then
                table.insert(FilteredResults, { name = _, realm = string.match(_, "-(.*)"), balance = CharBalanceInfo["Personal"], guildname = CharBalanceInfo["GuildName"], guildmoney = CharBalanceInfo["Guild"], deleteTexture = [=[Interface\Buttons\UI-GroupLoot-Pass-Down]=] })

            --end

        end

    end

    BalanceList:ApplyDefaultSort(FilteredResults)

    self.CurrentView = FilteredResults
    self.BalanceFrame.SearchResults:SetData(self.CurrentView, true)

    BalanceList:UpdateStateText()
    BalanceList:UpdateResultsText()
end

function BalanceList:DrawWindow()
    -- Draw our Trade Logs Window
    SalesTools:Debug("BalanceList:DrawWindow")

    local BalanceFrame

    if (self.CharacterSettings.BalanceFrameSize ~= nil) then
        BalanceFrame = StdUi:Window(UIParent, self.CharacterSettings.BalanceFrameSize.width, self.CharacterSettings.BalanceFrameSize.height, L["BalanceList_Window_Title"])
    else
        BalanceFrame = StdUi:Window(UIParent, 850, 650, L["BalanceList_Window_Title"])
    end

    if (self.CharacterSettings.BalanceFramePosition ~= nil) then
        BalanceFrame:SetPoint(self.CharacterSettings.BalanceFramePosition.point or "CENTER",
                self.CharacterSettings.BalanceFramePosition.UIParent,
                self.CharacterSettings.BalanceFramePosition.relPoint or "CENTER",
                self.CharacterSettings.BalanceFramePosition.relX or 0,
                self.CharacterSettings.BalanceFramePosition.relY or 0)
    else
        BalanceFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end

    BalanceFrame:SetScript("OnSizeChanged", function(self)
        BalanceList.CharacterSettings.BalanceFrameSize = { width = self:GetWidth(), height = self:GetHeight() } -- Save width/height to config db
    end)

    BalanceFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    BalanceFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()

        local point, _, relPoint, xOfs, yOfs = self:GetPoint() -- Get positional info

        BalanceList.CharacterSettings.BalanceFramePosition = { point = point, relPoint = relPoint, relX = xOfs, relY = yOfs } -- Save position to config db
    end)

    StdUi:MakeResizable(BalanceFrame, "BOTTOMRIGHT")
    StdUi:MakeResizable(BalanceFrame, "TOPLEFT")

    BalanceFrame:SetResizeBounds(850, 250, 1280, 720)
    BalanceFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    local IconFrame = StdUi:Frame(BalanceFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, BalanceFrame, -10, 10, "RIGHT")

    BalanceFrame.ResultsLabel = StdUi:Label(BalanceFrame, nil, 16)
    StdUi:GlueBottom(BalanceFrame.ResultsLabel, BalanceFrame, 10, 5, "LEFT")

    local BalanceAuditButton = StdUi:Button(BalanceFrame, 128, 20, L["BalanceList_AuditButton"])
    StdUi:GlueBottom(BalanceAuditButton, BalanceFrame, 0, 10, "CENTER")

    BalanceAuditButton:SetScript("OnClick", function()
        if (BalanceList.BalanceAuditFrame == nil) then
            BalanceList:DrawReportWindow()
        else
            BalanceList.BalanceAuditFrame:Show()
        end
        local BalanceAuditString = ""
        local AccountBalance = 0

        for _, CharBalanceInfo in pairs(self.GlobalSettings.BalanceList) do
            --if (SalesTools:FormatRawCurrency(CharBalanceInfo["Personal"]) >= 1 or SalesTools:FormatRawCurrency(CharBalanceInfo["Guild"]) >= 1) then

                BalanceAuditString = BalanceAuditString .. _ .. string.char(9) .. CharBalanceInfo["Realm"] .. string.char(9) .. CharBalanceInfo["Faction"] .. string.char(9) .. SalesTools:FormatRawCurrency(CharBalanceInfo["Personal"])  .. string.char(9) .. CharBalanceInfo["GuildName"] .. string.char(9) .. SalesTools:FormatRawCurrency(CharBalanceInfo["Guild"]).. string.char(10)
    
            --end
    
            
    
        end
        BalanceList.BalanceAuditFrame.EditBox:SetText(BalanceAuditString)

    end)

    self.BalanceFrame = BalanceFrame
end

function BalanceList:DrawReportWindow()
    -- Draw a window with an edit box for our gold audit
    SalesTools:Debug("BalanceList:DrawReportWindow")



    local BalanceAuditFrame = StdUi:Window(UIParent, 720, 960, L["BalanceList_Audit_Window_Title"])
    BalanceAuditFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)

    StdUi:MakeResizable(BalanceAuditFrame, "BOTTOMRIGHT")

    BalanceAuditFrame:SetResizeBounds(600, 800, 960, 1280)
    BalanceAuditFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    BalanceAuditFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    local EditBox = StdUi:MultiLineBox(BalanceAuditFrame, 550, 550, nil)
    StdUi:GlueAcross(EditBox, BalanceAuditFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local CloseAuditFrameButton = StdUi:Button(BalanceAuditFrame, 80, 30, L["BalanceList_Audit_Window_Close_Button"])
    StdUi:GlueBottom(CloseAuditFrameButton, BalanceAuditFrame, 0, 10, 'CENTER')
    CloseAuditFrameButton:SetScript('OnClick', function()
        BalanceList.BalanceAuditFrame:Hide()
    end)

    local IconFrame = StdUi:Frame(BalanceAuditFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, BalanceAuditFrame, -10, 10, "RIGHT")

    self.BalanceAuditFrame = BalanceAuditFrame
    self.BalanceAuditFrame.CloseAuditFrameButton = CloseAuditFrameButton
    self.BalanceAuditFrame.EditBox = EditBox
end

function BalanceList:DrawSearchPane()
    -- Draw the search box
    SalesTools:Debug("BalanceList:DrawSearchPane")

    local BalanceFrame = self.BalanceFrame

    local SearchBox = StdUi:Autocomplete(BalanceFrame, 400, 30, "", nil, nil, nil)
    StdUi:ApplyPlaceholder(SearchBox, L["BalanceList_Search_Button"], [=[Interface\Common\UI-Searchbox-Icon]=])
    SearchBox:SetFontSize(16)

    local Search_Button = StdUi:Button(BalanceFrame, 80, 30, L["BalanceList_Search_Button"] )

    local AccountBalance = 0
    for _, CharBalanceInfo in pairs(self.GlobalSettings.BalanceList) do
        --if (SalesTools:FormatRawCurrency(CharBalanceInfo["Personal"]) >= 1) then
            AccountBalance = AccountBalance + CharBalanceInfo["Personal"]

        --end


    end

    AccountBalance = BalanceList:MoneyFormat(AccountBalance)

    local GoldLabel = StdUi:Label(BalanceFrame, string.format(L["BalanceList_AccountBalance"],string.char(10),AccountBalance), 14, nil, 200, 30)

    StdUi:GlueTop(SearchBox, BalanceFrame, 10, -40, "LEFT")
    StdUi:GlueTop(Search_Button, BalanceFrame, 420, -40, "LEFT")
    StdUi:GlueTop(GoldLabel, BalanceFrame, -20, -40, "RIGHT")

    SearchBox:SetScript("OnEnterPressed", function()
        BalanceList:SearchEntries(SearchBox:GetText())
    end)
    Search_Button:SetScript("OnClick", function()
        BalanceList:SearchEntries(SearchBox:GetText())
    end)

    BalanceFrame.GoldLabel = GoldLabel
    BalanceFrame.SearchBox = SearchBox
    BalanceFrame.Search_Button = Search_Button


end

function BalanceList:DrawSearchResultsTable()
    -- Draw the search results table
    SalesTools:Debug("BalanceList:DrawSearchResultsTable")

    local BalanceFrame = self.BalanceFrame

    local cols = {
        {
            name = L["BalanceList_Viewer_Character"],
            width = 150,
            align = "CENTER",
            index = "name",
            format = "string",
            defaultSort = "asc"
        },
        {
            name = L["BalanceList_Viewer_Realm"],
            width = 100,
            align = "CENTER",
            index = "realm",
            format = "string",
            defaultSort = "asc"
        },
        {
            name = L["BalanceList_Viewer_Balance"],
            width = 125,
            align = "CENTER",
            index = "balance",
            format = "money",
        },
        {
            name = L["BalanceList_Viewer_Guild"],
            width = 100,
            align = "CENTER",
            index = "guildname",
            format = "string",
            defaultSort = "asc"
        },
        {
            name = L["BalanceList_Viewer_Guild_Balance"],
            width = 125,
            align = "CENTER",
            index = "guildmoney",
            format = "money",
        },
        {
            name = "",
            width = 16,
            align = "CENTER",
            index = "deleteTexture",
            format = "icon",
            texture = true,
            events = {
                OnClick = function(rowFrame, cellFrame, data, cols, row, realRow, column, table, button, ...)
                    self.GlobalSettings.BalanceList[cols.name] = nil
                    BalanceList:RefreshData()

                end,
            },
        },

    }

    BalanceFrame.SearchResults = StdUi:ScrollTable(BalanceFrame, cols, 18, 29)
    BalanceFrame.SearchResults:SetDisplayRows(math.floor(BalanceFrame.SearchResults:GetWidth() / BalanceFrame.SearchResults:GetHeight()), BalanceFrame.SearchResults.rowHeight)
    BalanceFrame.SearchResults:EnableSelection(true)

    BalanceFrame.SearchResults:SetScript("OnSizeChanged", function(self)
        local tableWidth = self:GetWidth();
        local tableHeight = self:GetHeight();

        local total = 0;
        for i = 1, #self.columns do
            total = total + self.columns[i].width;
        end

        for i = 1, #self.columns do
            self.columns[i]:SetWidth((self.columns[i].width / total) * (tableWidth - 30));
        end

        self:SetDisplayRows(math.floor(tableHeight / self.rowHeight), self.rowHeight);
    end)

    StdUi:GlueAcross(BalanceFrame.SearchResults, BalanceFrame, 10, -110, -10, 50)
    BalanceFrame.stateLabel = StdUi:Label(BalanceFrame.SearchResults, L["BalanceList_NoResults"])
    StdUi:GlueTop(BalanceFrame.stateLabel, BalanceFrame.SearchResults, 0, -40, "CENTER")
end

function BalanceList:ApplyDefaultSort(tableToSort)
    -- Apply our default sort settings
    SalesTools:Debug("BalanceList:ApplyDefaultSort")

    if (self.BalanceFrame.SearchResults.head.columns) then
        local isSorted = false

        for k, v in pairs(self.BalanceFrame.SearchResults.head.columns) do
            if (v.arrow:IsVisible()) then
                isSorted = true
            end
        end

        if (not isSorted) then
            return table.sort(tableToSort, function(a, b)
                return a["balance"] > b["balance"]
            end)
        end
    end

    return tableToSort
end

function BalanceList:UpdateStateText()
    -- Show a warning if no results were found
    SalesTools:Debug("BalanceList:UpdateStateText")

    if (#self.CurrentView > 0) then
        self.BalanceFrame.stateLabel:Hide()
    else
        self.BalanceFrame.stateLabel:SetText(L["BalanceList_NoResults"])
    end
end

function BalanceList:UpdateResultsText()
    -- Show the number of results in the current query
    SalesTools:Debug("BalanceList:UpdateResultsText")

    if (#self.CurrentView > 0) then
        self.BalanceFrame.ResultsLabel:SetText(string.format(L["BalanceList_CurrentResults"], tostring(#self.CurrentView)))
        self.BalanceFrame.ResultsLabel:Show()
    else
        self.BalanceFrame.ResultsLabel:Hide()
    end
end

function BalanceList:RefreshData()
    -- Refresh the results of the current query
    SalesTools:Debug("BalanceList:RefreshData")

    if (self.BalanceFrame ~= nil) then
        BalanceList:SearchEntries(self.BalanceFrame.SearchBox:GetText())
        local AccountBalance = 0
        for _, CharBalanceInfo in pairs(self.GlobalSettings.BalanceList) do
            --if (SalesTools:FormatRawCurrency(CharBalanceInfo["Personal"]) >= 1) then
                AccountBalance = AccountBalance + CharBalanceInfo["Personal"]

            --end


        end
        AccountBalance = BalanceList:MoneyFormat(AccountBalance)
        self.BalanceFrame.GoldLabel:SetText(string.format(L["BalanceList_AccountBalance"],string.char(10),AccountBalance))

    end
end

function BalanceList:UpdateGold()
    -- Handler for PLAYER_MONEY events
    SalesTools:Debug("BalanceList:UpdateGold")

    if (UnitFullName("player") ~= nil) then
        local faction, _ = UnitFactionGroup("player")
        local player = SalesTools:GetPlayerFullName()
        local pgold = GetMoney()
        local realm = GetRealmName()
        
        local ggold = 0
        local gname = "No Guild"
        
        if (IsInGuild() and (C_GuildInfo.IsGuildOfficer() or IsGuildLeader())) then
            local GuildName, _, _, _ = GetGuildInfo("player")

            if LGBC:GetGuildFunds() ~= nil then
                ggold = LGBC:GetGuildFunds()
            end
            
            if GuildName ~= nil then
                gname = GuildName
            end
        end

        self.GlobalSettings.BalanceList[player] = {
            ["Personal"] = pgold,
            ["Faction"] = faction,
            ["Guild"] = ggold,
            ["GuildName"] = "<" .. gname .. ">",
            ["Realm"] = realm:gsub(' ','')
        }

        BalanceList:RefreshData()

    end

end

function BalanceList:MoneyFormat(money, excludeCopper)
    -- Format gold nicely with colours and commas
    SalesTools:Debug("BalanceList:MoneyFormat")
    
    if type(money) ~= 'number' then
        return money;
    end

    money = tonumber(money);
    local goldColor = '|cfffff209';
    local silverColor = '|cff7b7b7a';
    local copperColor = '|cffac7248';

    local gold = SalesTools:FormatRawCurrency(money);
    local silver = floor((money - (gold * COPPER_PER_GOLD)) / COPPER_PER_SILVER);
    local copper = floor(money % COPPER_PER_SILVER);

    local output = '';

    if gold > 0 then
        output = format('%s%s%s ', goldColor, SalesTools:CommaValue(gold), '|rg');
    end

    if gold > 0 or silver > 0 then
        output = format('%s%s%02i%s ', output, silverColor, silver, '|rs');
    end

    if not excludeCopper then
        output = format('%s%s%02i%s ', output, copperColor, copper, '|rc');
    end

    return output:trim();
end

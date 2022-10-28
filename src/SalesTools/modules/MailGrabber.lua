-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local MailGrabber = SalesTools:NewModule("MailGrabber", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local StdUi = LibStub("StdUi")

-- Instance variables for our mail grabber
MailGrabber.DELAY_PER_LETTER = 0.5
MailGrabber.PendingImports = {}
MailGrabber.PendingExports = {}
MailGrabber.PendingMailContent = {}
MailGrabber.indexToDelete = nil


function MailGrabber:OnEnable()
    -- Run when the module is enabled
    SalesTools:Debug("MailGrabber:OnEnable")

    -- Register our events
    self:RegisterEvent("PLAYER_MONEY", "OnEvent")
    self:RegisterEvent("MAIL_FAILED", "OnEvent")
end

function MailGrabber:Toggle()
    -- Toggle visibility of the Mail Grabber Window
    SalesTools:Debug("MailGrabber:Toggle")

    if ((self.ExportFrame and self.ExportFrame:IsVisible())  or  (self.ImportFrame and self.ImportFrame:IsVisible())) then
        if (self.ExportFrame) then
             self.ExportFrame:Hide()
        end

        if (self.ImportFrame) then
            self.ImportFrame:Hide()
        else
            self.ImportFrame:Show()
        end
        
        if (self.ImportFrame == nil) then
            MailGrabber:DrawImportWindow()
        else
            self.ImportFrame:Show()
        end
    else
        if (self.ImportFrame == nil) then
            MailGrabber:DrawImportWindow()
        else
            self.ImportFrame:Show()
        end
    end
end

function MailGrabber:GrabNextMail()
    -- Try to retrieve the next mail
    SalesTools:Debug("MailGrabber:GrabNextMail")
    
    for i=1, GetInboxNumItems() do
        local subject, money = select(4, GetInboxHeaderInfo(i))
        local body = GetInboxText(i)


        for code, gold in pairs(self.PendingImports) do
                local goldWithinRange = money >= (gold - 10) * COPPER_PER_GOLD
                -- If the subject or body contains our code and it's roughly what we expect, loot it and save it for later.
                if (subject and subject == code) then
                    if (goldWithinRange) then
                        if (MailGrabber:WithinGoldCap(money)) then
                            AutoLootMailItem(i)
                            self.PendingMailContent = {code=code, gold=SalesTools:FormatRawCurrency(money),  subject=subject or "", body=body}
                            self.MailExpected = true
                            if (body ~= nil and body ~= "") then
                                self.indexToDelete = i
                            end
                            return
                        else
                            SalesTools:Print(string.format(L["MailGrabber_Skip_GoldCap"],code))
                            self.PendingImports[code] = nil
                        end
                    else
                        SalesTools:Print(string.format(L["MailGrabber_Skip_Mismatch"],code))
                        self.PendingImports[code] = nil
                    end
                end
        end
        

    end

    C_Timer.After(0.5, function()
        if (not MailGrabber.ExportFrame) then
            if (MailGrabber.ImportFrame) then
                MailGrabber.ImportFrame:Hide()
            end
            MailGrabber:DrawExportWindow()
        else
            if (MailGrabber.ImportFrame) then
                MailGrabber.ImportFrame:Hide()
            end
            MailGrabber.ExportFrame:Show()
            MailGrabber.ExportFrame.EditBox:SetText(MailGrabber:GenerateExportText())
        end
    end)
end

function MailGrabber:WithinGoldCap(money)
    -- Make sure that we won't exceed gold cap
    SalesTools:Debug("MailGrabber:WithinGoldCap")

    if ((GetMoney() + money) < 99999999999 --[[ gold cap ]]) then
        return true
    else
        return false
    end
end

function MailGrabber:OnEvent(event, ...)
    -- Events handler
    SalesTools:Debug("MailGrabber:OnEvent",event)

    if (event == "PLAYER_MONEY" and self.MailExpected) then
        self.PendingExports[#self.PendingExports + 1] = self.PendingMailContent
        if (self.PendingMailContent.code and self.PendingMailContent.gold) then
            SalesTools:Print(string.format(L["MailGrabber_Collected_Mail"], self.PendingMailContent.code, self.PendingMailContent.gold))
            self.PendingImports[self.PendingMailContent.code] = nil
        end
        self.MailExpected = false
        if (self.indexToDelete ~= nil) then
            DeleteInboxItem(self.indexToDelete)
            self.indexToDelete = nil
        end
        C_Timer.After(self.DELAY_PER_LETTER, function() MailGrabber:GrabNextMail() end)
    elseif (event == "MAIL_FAILED" and self.MailExpected) then
        wipe(self.PendingMailContent)
        self.MailExpected = false
    end
end

function MailGrabber:DrawImportWindow()
    -- Draw our mail import window
    SalesTools:Debug("MailGrabber:DrawImportWindow")
    
    local IconFrame = StdUi:Frame(MailFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0)

    ImportFrame = StdUi:Window(UIParent, 300, 400, L["MailGrabber_Import_Window_Title"])
    ImportFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    ImportFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    StdUi:MakeResizable(ImportFrame, "BOTTOMRIGHT")
    ImportFrame:SetResizeBounds(250, 332)

    ImportFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    local EditBox = StdUi:MultiLineBox(ImportFrame, 280, 300, nil)
    StdUi:GlueAcross(EditBox, ImportFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local IconFrame = StdUi:Frame(ImportFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, ImportFrame, -10, 10, "RIGHT")

    local GrabButton = StdUi:Button(ImportFrame, 80, 30, 'Pick Up')
    StdUi:GlueBottom(GrabButton, ImportFrame, 0, 10, 'CENTER')

    GrabButton:SetScript('OnClick', function()
        MailGrabber:ParseImportInput()
        MailGrabber:GrabNextMail()
    end)

    self.ImportFrame = ImportFrame
    self.ImportFrame.EditBox = EditBox
end


function MailGrabber:DrawExportWindow()
    -- Draw our mail export window
    SalesTools:Debug("MailGrabber:DrawExportWindow")

    local IconFrame = StdUi:Frame(MailFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0)

    ExportFrame = StdUi:Window(UIParent, 300, 400, L["MailGrabber_Export_Window_Title"])
    ExportFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    ExportFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    StdUi:MakeResizable(ExportFrame, "BOTTOMRIGHT")
    ExportFrame:SetResizeBounds(250, 332)

    local EditBox = StdUi:MultiLineBox(ExportFrame, 280, 300, MailGrabber:GenerateExportText())
    StdUi:GlueAcross(EditBox, ExportFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local IconFrame = StdUi:Frame(ExportFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)
    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, ExportFrame, -10, 10, "RIGHT")

    self.ExportFrame = ExportFrame
    self.ExportFrame.EditBox = EditBox
end

function MailGrabber:ParseImportInput()
    -- Parse the user input for mails to be imported
    SalesTools:Debug("MailGrabber:ParseImportInput")

    local input = self.ImportFrame.EditBox:GetText()
    local parsedInput = string.gmatch(input, "[^\r\n]+")
    for entry in parsedInput do
        local subEntries = {}
        for subEntry in (entry):gmatch("[^:]+") do
            table.insert(subEntries, subEntry)
        end
        local code = subEntries[1]
        local gold = subEntries[2]
        self.PendingImports[code] = gold
    end
end

function MailGrabber:GenerateExportText()
    -- Output the mails we successfully found
    SalesTools:Debug("MailGrabber:GenerateExportText")

    local exportString = ""
    local _,realm = UnitFullName("player")
    for _, mail in pairs(self.PendingExports) do
        if (mail.code and mail.subject) then
            exportString = exportString .. mail.code
            exportString = exportString .. "|n"
        elseif (mail.body and mail.gold) then
            exportString = exportString .. mail.body .. "\t"..realm.."\t" .. date() .."\t" .. mail.gold .. "|n"
        end
    end

    self.PendingImports = {}
    self.PendingExports = {}

    return exportString
end
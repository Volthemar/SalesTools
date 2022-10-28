-- Basic imports(s)/setup
local L = LibStub("AceLocale-3.0"):GetLocale("SalesTools") -- Localization support
local SalesTools = LibStub("AceAddon-3.0"):GetAddon("SalesTools")
local MailSender = SalesTools:NewModule("MailSender", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
local StdUi = LibStub('StdUi')

-- Instance variables for handling our bulk mail sending
MailSender.MailCache = {}
MailSender.MailExpected = false
MailSender.OutgoingMailContents = {}

function MailSender:OnEnable()
    -- Called when the module is enabled
    SalesTools:Debug("MailSender:OnEnable")

    -- Our databases/user settings
    self.GlobalSettings = SalesTools.db.global
    self.CharacterSettings = SalesTools.db.char

    -- Register any command(s) this module uses
    SalesTools.AddonCommands.sendmail = {
        desc = L["MailSender_Command_Desc"],
        action = function()
            if (SalesTools.MailSender) then
                SalesTools.MailSender:Toggle()
            end
        end,
    }

    -- Register our events
    self:RegisterEvent("PLAYER_MONEY", "OnEvent")
    self:RegisterEvent("MAIL_FAILED", "OnEvent")
    self:RegisterEvent("MAIL_SUCCESS", "OnEvent")
    self:RegisterEvent("MAIL_CLOSED", "OnEvent")
end

function MailSender:Toggle()
    -- Toggle the visibility of the Mail Sender Window
    SalesTools:Debug("MailSender:Toggle")

    if (self.MailSenderFrame == nil) then
        self:DrawWindow()
        self:DrawInfoIcon()
    elseif self.MailSenderFrame:IsVisible() then
        self.MailSenderFrame:Hide()
    else
        self.MailSenderFrame:Show()
    end
end


function MailSender:DrawWindow()
    -- Draw our Mail Sender Window
    SalesTools:Debug("MailSender:DrawWindow")

    local MailSenderFrame

    if (self.CharacterSettings.MailSenderFrameSize ~= nil) then
        MailSenderFrame = StdUi:Window(UIParent, self.CharacterSettings.MailSenderFrameSize.width, self.CharacterSettings.MailSenderFrameSize.height, L["MailSender_Window_Title"])
    else
        MailSenderFrame = StdUi:Window(UIParent, 300, 400, L["MailSender_Window_Title"])
    end

    if (self.CharacterSettings.MailSenderFramePosition ~= nil) then
        MailSenderFrame:SetPoint(self.CharacterSettings.MailSenderFramePosition.point or "CENTER",
                self.CharacterSettings.MailSenderFramePosition.UIParent,
                self.CharacterSettings.MailSenderFramePosition.relPoint or "CENTER",
                self.CharacterSettings.MailSenderFramePosition.relX or 0,
                self.CharacterSettings.MailSenderFramePosition.relY or 0)
    else
        MailSenderFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end

    StdUi:MakeResizable(MailSenderFrame, "BOTTOMRIGHT")
    MailSenderFrame:SetResizeBounds(250, 332, 500, 664)
    MailSenderFrame:SetFrameLevel(SalesTools:GetNextFrameLevel())

    MailSenderFrame:SetScript("OnMouseDown", function(self)
        self:SetFrameLevel(SalesTools:GetNextFrameLevel())
    end)

    MailSenderFrame:SetScript("OnSizeChanged", function(self)
        MailSender.CharacterSettings.MailSenderFrameSize = { width = self:GetWidth(), height = self:GetHeight() }
    end)

    MailSenderFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        MailSender.CharacterSettings.MailSenderFramePosition = { point = point, relPoint = relPoint, relX = xOfs, relY = yOfs }
    end)

    local EditBox = StdUi:MultiLineBox(MailSenderFrame, 280, 300, nil)
    StdUi:GlueAcross(EditBox, MailSenderFrame, 10, -50, -10, 50)
    EditBox:SetFocus()

    local SendButton = StdUi:Button(MailSenderFrame, 80, 30, 'Send')
    StdUi:GlueBottom(SendButton, MailSenderFrame, 0, 10, 'CENTER')
    SendButton:SetScript('OnClick', function()
        MailSender:Start()
    end)

    local IconFrame = StdUi:Frame(MailSenderFrame, 32, 32)
    local IconTexture = StdUi:Texture(IconFrame, 32, 32, SalesTools.AddonIcon)

    StdUi:GlueTop(IconTexture, IconFrame, 0, 0, "CENTER")
    StdUi:GlueBottom(IconFrame, MailSenderFrame, -10, 10, "RIGHT")

    self.MailSenderFrame = MailSenderFrame
    self.MailSenderFrame.SendButton = SendButton
    self.MailSenderFrame.EditBox = EditBox
end

function MailSender:DrawInfoIcon()
    -- Draw our Info Icon
    SalesTools:Debug("MailSender:DrawInfoIcon")

    local MailSenderFrame = self.MailSenderFrame
    local InfoIconFrame = StdUi:Frame(MailSenderFrame, 16, 16, nil);
    StdUi:GlueRight(InfoIconFrame, self.MailSenderFrame.SendButton, 20, 0, 'RIGHT')
    local InfoIconTexture = StdUi:Texture(MailSenderFrame, 16, 16, [=[Interface\FriendsFrame\InformationIcon]=])
    StdUi:GlueTop(InfoIconTexture, InfoIconFrame, 0, 0, "CENTER")
    local tooltip = StdUi:FrameTooltip(InfoIconFrame, "Examples:|player1-server:100:subject1:body1|player2-server:200:subject2:body2|player3-server:199:subject3:body3", "tooltip", "TOP", true)
end

function MailSender:Start()
    -- Start sending our bulk mail
    SalesTools:Debug("MailSender:Start")

    wipe(self.MailCache)
    self.MailExpected = false
    self.MailSent = 1
    if (self.MailSenderFrame.EditBox ~= nil and self.MailSenderFrame.EditBox:GetText() ~= nil and self.MailSenderFrame.EditBox:GetText() ~= "") then
        MailSender:ParseInput()
        if (not MailSender:HasEnoughGold()) then
            MailSender:LogNotEnoughGold()
            MailSender:Finish()
            return
        end
        MailSender:AttemptSendMail(self.MailSent)
    end
end

function MailSender:AttemptSendMail(index)
    -- Attempt to send a single mail
    SalesTools:Debug("MailSender:AttemptSendMail")

    local gold = (self.MailCache[index].gold or 0)
    local player = self.MailCache[index].player
    local subject = self.MailCache[index].subject or ""
    local body = self.MailCache[index].body or ""

    SetSendMailMoney(gold)

    SendMail(player, subject, body:gsub("\\n", string.char(10)))
    
end

-- Events Handler
-- We must rate-limit based on events, or else the Blizzard API will simply swallow mail requests.
function MailSender:OnEvent(event, ...)
    -- Handle events
    SalesTools:Debug("MailSender:OnEvent", event)

    -- We rate limit on PLAYER_MONEY rather than MAIL_SUCCESS because it allows us to more reliably check if we have enough gold to send the next message.
    if (#self.MailCache > 0) then
        if (event == "PLAYER_MONEY" or event == "MAIL_FAILED" or event == "MAIL_CLOSED") then
            -- We're in the middle of sending out messages, so assume the event was for us; print out the message for the previous player.
            if (event == "MAIL_CLOSED") then
                MailSender:Finish()
                return
            elseif (event == "PLAYER_MONEY") then
                SalesTools:Print(string.format(L["MailSender_Mail_Sent"],SalesTools:FormatRawCurrency(self.MailCache[self.MailSent].gold),self.MailCache[self.MailSent].player))
                self.GlobalSettings.MailLog[#self.GlobalSettings.MailLog + 1] = self.OutgoingMailContents
            elseif (event == "MAIL_FAILED") then
                SalesTools:Print(string.format(L["MailSender_Mail_Failed"],SalesTools:FormatRawCurrency(self.MailCache[self.MailSent].gold),self.MailCache[self.MailSent].player))
                MailSender:Finish()
                return
            end
            self.MailSent = self.MailSent + 1
            if (self.MailSent > #self.MailCache) then
                MailSender:Finish()
                return
            elseif (not MailSender:HasEnoughGold()) then
                -- Before we continue, check to see whether we have enough gold. If we don't, short-circuit.
                MailSender:LogNotEnoughGold()
                MailSender:Finish()
                return
            else
                MailSender:AttemptSendMail(self.MailSent)
            end
        end
    else
        if (event == "MAIL_SUCCESS" and self.MailExpected) then
            self.GlobalSettings.MailLog[#self.GlobalSettings.MailLog + 1] = self.OutgoingMailContents
            self.MailExpected = false
        elseif (event == "MAIL_FAILED" and self.MailExpected) then
            wipe(self.OutgoingMailContents)
            self.MailExpected = false
        end
    end
end

hooksecurefunc("SendMail", function(name, subject, body)
    -- Hook SendMail so we can save all the mail information and await a MAIL_SUCCESS/MAIL_FAILED event.
    SalesTools:Debug("SendMail")

    local money = GetSendMailMoney()
    if (money > 0) then
        MailSender.MailExpected = true
        MailSender.OutgoingMailContents = { source = SalesTools:GetPlayerFullName(), destination = name, gold = money, subject = subject, body = body, sent = true, date = date("%Y-%m-%d %X (%A)") }
    end
end)

hooksecurefunc("TakeInboxMoney", function(index)
    -- Hook a few other functions to allow for auto looting of mail
    SalesTools:Debug("TakeInboxMoney")

    local sender, subject, money, _, daysLeft = select(3, GetInboxHeaderInfo(index))
    local body = GetInboxText(index)
    if (sender and not sender:find("-")) then
        sender = sender .. "-" .. select(2, UnitFullName("player"))
    end
    if (money > 0) then
        MailSender.MailExpected = true
        local sentDate = date("%Y-%m-%d %X (%A)", (time() - (31 - daysLeft) * 24 * 60 * 60))
        MailSender.OutgoingMailContents = { source = sender, destination = SalesTools:GetPlayerFullName(), gold = money, subject = subject, body = body, sent = false, date = sentDate, openedDate = date("%Y-%m-%d %X (%A)") }
    end
end)

hooksecurefunc("AutoLootMailItem", function(index)
    -- Hook AutoLootMailItem so we can save all the mail information and await a MAIL_SUCCESS/MAIL_FAILED event.
    SalesTools:Debug("AutoLootMailItem")

    local sender, subject, money, _, daysLeft = select(3, GetInboxHeaderInfo(index))
    local body = GetInboxText(index)
    if (sender and not sender:find("-")) then
        sender = sender .. "-" .. select(2, UnitFullName("player"))
    end
    if (money > 0) then
        MailSender.MailExpected = true
        local sentDate = date("%Y-%m-%d %X (%A)", (time() - (31 - daysLeft) * 24 * 60 * 60))
        MailSender.OutgoingMailContents = { source = sender, destination = SalesTools:GetPlayerFullName(), gold = money, subject = subject, body = body, sent = false, date = sentDate, openedDate = date("%Y-%m-%d %X (%A)") }
    end
end)

function MailSender:ParseInput()
    -- Split user input on newlines, then split on colons to get player:gold:subject:body parts.
    SalesTools:Debug("MailSender:ParseInput")

    local input = self.MailSenderFrame.EditBox:GetText()
    local parsedInput = string.gmatch(input, "[^\r\n]+")
    for entry in parsedInput do
        local subEntries = {}
        for subEntry in (entry):gmatch("[^:]+") do
            table.insert(subEntries, subEntry)
        end
        local player = subEntries[1] or ""
        local gold = subEntries[2] or 0
        local subject = subEntries[3] or "Mail!"
        local body = subEntries[4] or ""
        self.MailCache[#self.MailCache + 1] = { player = player, gold = gold * COPPER_PER_GOLD, subject = subject, body = body }
    end
end

function MailSender:HasEnoughGold()
    -- Check whether there's enough gold to actually send a mail
    SalesTools:Debug("MailSender:HasEnoughGold")
    if self.MailSent ~= nil then
        return (GetMoney() > tonumber(self.MailCache[self.MailSent].gold or 0))
    end
    return 0
end

function MailSender:LogNotEnoughGold()
    -- Log that we don't have enough gold to send a mail
    SalesTools:Debug("MailSender:LogNotEnoughGold")

    SalesTools:Print(L["MailSender_Not_Enough_Gold"])
    SalesTools:Print(string.format(L["MailSender_Not_Enough_GoldPlayer"],self.MailCache[self.MailSent].player,SalesTools:FormatRawCurrency(self.MailCache[self.MailSent].gold)))
end


function MailSender:Finish()
    -- Cleanup once we've finished sending mails
    SalesTools:Debug("MailSender:Finish")

    SalesTools:Print(L["MailSender_Done"])

    wipe(self.MailCache)
    self.OutgoingMailContents = {}
    self.MailExpected = false
    self.MailSenderFrame:Hide()
end
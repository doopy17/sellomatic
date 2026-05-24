-- File: SellOMatic.lua
-- Sell-O-Matic modified for Ebonhold 200 ilvl BoE farming

local CreateSellButtons, DoAutoSell, InitializeCheckboxes, PrintSellSummary, SellItems, DeleteNextItem

keepList = keepList or {}
local function NormalizeKeepList()
    if type(keepList) ~= "table" then
        keepList = {}
        return
    end

    for key, value in pairs(keepList) do
        if type(key) == "string" then
            local numericKey = tonumber(key)
            if numericKey then
                keepList[numericKey] = value
                keepList[key] = nil
            end
        end
    end
end
NormalizeKeepList()

deleteList = deleteList or {}
local function NormalizeDeleteList()
    if type(deleteList) ~= "table" then
        deleteList = {}
        return
    end

    for key, value in pairs(deleteList) do
        if type(key) == "string" then
            local numericKey = tonumber(key)
            if numericKey then
                deleteList[numericKey] = value
                deleteList[key] = nil
            end
        end
    end
end
NormalizeDeleteList()

SellOMatic_Settings = SellOMatic_Settings or {}
-- Initialize settings with defaults on first load
if SellOMatic_Settings.autoSellEnabled == nil then
    SellOMatic_Settings.autoSellEnabled = false
end
if SellOMatic_Settings.sellWhite == nil then
    SellOMatic_Settings.sellWhite = false
end
if SellOMatic_Settings.sellGreen == nil then
    SellOMatic_Settings.sellGreen = false
end
if SellOMatic_Settings.sellBlue == nil then
    SellOMatic_Settings.sellBlue = false
end
if SellOMatic_Settings.sellEpic == nil then
    SellOMatic_Settings.sellEpic = false
end
if SellOMatic_Settings.sellScrolls == nil then
    SellOMatic_Settings.sellScrolls = false
end
if SellOMatic_Settings.sellDarkmoonCards == nil then
    SellOMatic_Settings.sellDarkmoonCards = false
end
if SellOMatic_Settings.keepAffixes == nil then
    SellOMatic_Settings.keepAffixes = false
end
if SellOMatic_Settings.deleteList == nil then
    SellOMatic_Settings.deleteList = false
end

-- confirmation popup frame for clearing lists, since StaticPopupDialogs can taint the Blizzard UI and cause issues with secure actions like learning bind on use recipes, we create our own simple confirmation frame instead of using StaticPopupDialogs for the "clear" commands in the keep and delete list management
SellOMaticCustomConfirmFrame = CreateFrame("Frame", "SellOMaticCustomConfirmFrame", UIParent)

local ConfirmFrame = SellOMaticCustomConfirmFrame
ConfirmFrame:SetSize(320, 75)
ConfirmFrame:SetPoint("TOP", UIParent, "TOP", 0, -135)
ConfirmFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
ConfirmFrame:SetFrameStrata("DIALOG")
ConfirmFrame:EnableMouse(true)
ConfirmFrame:Hide()
tinsert(UISpecialFrames, "SellOMaticCustomConfirmFrame")

ConfirmFrame:SetScript("OnShow", function()
    PlaySound("igMainMenuOpen")
end)

ConfirmFrame:SetScript("OnHide", function()
    PlaySound("igMainMenuClose")
end)

-- Text label
ConfirmFrame.text = ConfirmFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
ConfirmFrame.text:SetPoint("TOP", ConfirmFrame, "TOP", 0, -18)
ConfirmFrame.text:SetWidth(290)

-- Accept Button
ConfirmFrame.accept = CreateFrame("Button", "SellOMaticConfirmAcceptButton", ConfirmFrame, "StaticPopupButtonTemplate")
ConfirmFrame.accept:SetSize(120, 20)
ConfirmFrame.accept:SetPoint("BOTTOMLEFT", ConfirmFrame, "BOTTOMLEFT", 32, 16)
ConfirmFrame.accept:SetText("Clear")

-- Cancel Button
ConfirmFrame.cancel = CreateFrame("Button", "SellOMaticConfirmCancelButton", ConfirmFrame, "StaticPopupButtonTemplate")
ConfirmFrame.cancel:SetSize(120, 20)
ConfirmFrame.cancel:SetPoint("BOTTOMRIGHT", ConfirmFrame, "BOTTOMRIGHT", -32, 16)
ConfirmFrame.cancel:SetText("Cancel")
ConfirmFrame.cancel:SetScript("OnClick", function() ConfirmFrame:Hide() end)

-- Helper function to trigger our custom popup box safely
local function ShowCustomConfirm(message, onAcceptFunc)
    ConfirmFrame.text:SetText(message)
    ConfirmFrame.accept:SetScript("OnClick", function()
        onAcceptFunc()
        ConfirmFrame:Hide()
    end)
    ConfirmFrame:Show()
end

function DeleteNextItem()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(string.match(link, "item:(%d+)"))
                if deleteList[itemId] then
                    PickupContainerItem(bag, slot)
                    DeleteCursorItem()
                    return
                end
            end
        end
    end
end

local forcePrint = true
function PrintSellSummary(totalItemsSold, totalGoldGained, forcePrint)
    if not totalItemsSold or totalItemsSold <= 0 then return end

    local iconSize = select(2, GetChatWindowInfo(1)) - 2
    local itemsStr = (totalItemsSold == 1) and 'item' or 'items'
    local newMessage = format("Sell-O-Matic: Automatically sold %d %s for %s.", totalItemsSold, itemsStr, GetCoinTextureString(totalGoldGained, iconSize))
    
    local totalMessages = DEFAULT_CHAT_FRAME:GetNumMessages() or 0
    local lastMessageText = ""
    if totalMessages > 0 then
        lastMessageText = DEFAULT_CHAT_FRAME:GetMessageInfo(totalMessages) or ""
    end
    
    if forcePrint or newMessage ~= lastMessageText then
        print(newMessage)
        forcePrint = false
    end
end

function SellItems(quality, sellOnlyType)
    if not MerchantFrame or not MerchantFrame:IsVisible() then
        return 0, 0 -- Return values so buttons can harvest metrics if called directly
    end

    local totalGoldGained = 0
    local totalItemsSold = 0

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, _, itemSellPrice = GetItemInfo(link)
                local itemId = tonumber(string.match(link, "item:(%d+)"))
                local itemString = string.match(link, "item:[%d:-]+")
                local rawSuffix = select(8, string.split(":", itemString))
                local suffixId = math.abs(tonumber(rawSuffix) or 0)

                local shouldSell = not keepList[itemId]
                local isGear = (itemType == "Armor" or itemType == "Weapon") and (itemEquipLoc ~= "")

                local itemCount = select(2, GetContainerItemInfo(bag, slot))
                itemCount = tonumber(itemCount) or 1
                local totalSlotValue = (itemSellPrice or 0) * itemCount

                if shouldSell and itemQuality == quality and itemSellPrice > 0 then
                    local itemWasSold = false

                    if sellOnlyType == "Scroll" then
                        if itemType == "Consumable" and itemSubType == "Scroll" then
                            UseContainerItem(bag, slot)
                            itemWasSold = true
                        end
                    elseif sellOnlyType == "DarkmoonCard" then
                        if itemType == "Quest" and itemName then
                            if string.find(itemName, "of ") then
                                if string.find(itemName, "^Ace") or
                                    string.find(itemName, "^Two") or
                                    string.find(itemName, "^Three") or
                                    string.find(itemName, "^Four") or
                                    string.find(itemName, "^Five") or
                                    string.find(itemName, "^Six") or
                                    string.find(itemName, "^Seven") or
                                    string.find(itemName, "^Eight") then
                                    UseContainerItem(bag, slot)
                                    itemWasSold = true
                                end
                            end
                        end
                    elseif sellOnlyType == "KnownRecipes" then
                        if itemType == "Recipe" and not (itemName and string.find(itemName, "Tome of Echo")) then
                        local function IsRecipeAlreadyKnown(bag, slot)
                            local ScanTooltip = CreateFrame("GameTooltip", "SellOMaticScanTooltip", nil, "GameTooltipTemplate")
                            ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                            ScanTooltip:ClearLines()
                            ScanTooltip:SetBagItem(bag, slot)
                            
                            -- Loop through all lines of text currently visible on the item tooltip
                            for i = 1, ScanTooltip:NumLines() do
                                local leftLine = _G["SellOMaticScanTooltipTextLeft" .. i]
                                if leftLine then
                                    local text = leftLine:GetText()
                                    -- Check for the English string or the game's localized default global string
                                    if text and (string.find(text, "Already Known") or text == ITEM_SPELL_KNOWN) then
                                        return true
                                    end
                                end
                            end
                            return false
                        end
                            if IsRecipeAlreadyKnown(bag, slot) then
                                UseContainerItem(bag, slot)
                                itemWasSold = true
                            end
                        end
                    else
                        if itemLevel < 201 and isGear then
                            if SellOMatic_Settings.keepAffixes == nil then
                                UseContainerItem(bag, slot)
                                itemWasSold = true
                            elseif SellOMatic_Settings.keepAffixes == 1 then
                                if suffixId < 8950 then
                                    UseContainerItem(bag, slot)
                                    itemWasSold = true
                                end
                            end
                        end
                    end
                    if itemWasSold then
                        totalGoldGained = totalGoldGained + totalSlotValue
                        totalItemsSold = totalItemsSold + itemCount
                    end
                end
            end
        end
    end
    return totalItemsSold, totalGoldGained
end
MerchantFrame:HookScript("OnHide", function()
    forcePrint = true
end)

local function CreateSellButtons() -- merchant frame buttons
    if SellomaticSellWhiteItemsButton and SellomaticSellGreenItemsButton and SellomaticSellBlueItemsButton and SellomaticSellEpicItemsButton and SellomaticSettingsButton then
        return
    end

    local buttonWidth = 100
    local buttonHeight = 15
    local spacing = 4
    local merchantFrameLevel = MerchantFrame:GetFrameLevel()

    SellomaticSellWhiteItemsButton = SellomaticSellWhiteItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellWhiteItemsButton:SetText("Sell Whites")
    SellomaticSellWhiteItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellWhiteItemsButton:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 80, -37.5)
    SellomaticSellWhiteItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellWhiteItemsButton:SetScript("OnClick", function() 
        local items, gold = SellItems(1)
        PrintSellSummary(items, gold, true)
    end)

    SellomaticSellGreenItemsButton = SellomaticSellGreenItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellGreenItemsButton:SetText("Sell Greens")
    SellomaticSellGreenItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellGreenItemsButton:SetPoint("LEFT", SellomaticSellWhiteItemsButton, "RIGHT", spacing, 0)
    SellomaticSellGreenItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellGreenItemsButton:SetScript("OnClick", function() 
        local items, gold = SellItems(2)
        PrintSellSummary(items, gold, true)
    end)

    SellomaticSellBlueItemsButton = SellomaticSellBlueItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellBlueItemsButton:SetText("Sell Blues")
    SellomaticSellBlueItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellBlueItemsButton:SetPoint("TOPLEFT", SellomaticSellWhiteItemsButton, "BOTTOMLEFT", 0, -spacing)
    SellomaticSellBlueItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellBlueItemsButton:SetScript("OnClick", function()
        local items, gold = SellItems(3)
        PrintSellSummary(items, gold, true)
    end)

    SellomaticSellEpicItemsButton = SellomaticSellEpicItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellEpicItemsButton:SetText("Sell Epics")
    SellomaticSellEpicItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellEpicItemsButton:SetPoint("LEFT", SellomaticSellBlueItemsButton, "RIGHT", spacing, 0)
    SellomaticSellEpicItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellEpicItemsButton:SetScript("OnClick", function() 
        local items, gold = SellItems(4)
        PrintSellSummary(items, gold, true)
    end)

    SellomaticSettingsButton = SellomaticSettingsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSettingsButton:SetText("S")
    SellomaticSettingsButton:SetSize(20, 15)
    SellomaticSettingsButton:SetPoint("LEFT", SellomaticSellGreenItemsButton, "RIGHT", spacing, 0)
    SellomaticSettingsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSettingsButton:SetScript("OnClick", function() 
        InterfaceOptionsFrame_OpenToCategory(SellOMatic_InterfacePanel)
    end)
    SellomaticSettingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sell-O-Matic Settings")
        GameTooltip:Show()
    end)
    SellomaticSettingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function DoAutoSell()
    if not SellOMatic_Settings.autoSellEnabled then
        return
    end
    
    local totalGoldGained = 0
    local totalItemsSold = 0
    
    if SellOMatic_Settings.sellWhite then 
        local items, gold = SellItems(1)
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
    end
    if SellOMatic_Settings.sellGreen then 
        local items, gold = SellItems(2)
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
    end
    if SellOMatic_Settings.sellBlue then 
        local items, gold = SellItems(3)
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
    end
    if SellOMatic_Settings.sellEpic then 
        local items, gold = SellItems(4)
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
    end
    if SellOMatic_Settings.sellScrolls then 
        local items, gold = SellItems(1, "Scroll")
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
    end
    if SellOMatic_Settings.sellDarkmoonCards then
        local items, gold = SellItems(1, "DarkmoonCard")
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items
        
        local items2, gold2 = SellItems(3, "DarkmoonCard")
        totalGoldGained = totalGoldGained + gold2
        totalItemsSold = totalItemsSold + items2
    end
    if SellOMatic_Settings.sellKnownRecipes then
        local items, gold = SellItems(1, "KnownRecipes")
        totalGoldGained = totalGoldGained + gold
        totalItemsSold = totalItemsSold + items

        local items2, gold2 = SellItems(2, "KnownRecipes")
        totalGoldGained = totalGoldGained + gold2
        totalItemsSold = totalItemsSold + items2

        local items3, gold3 = SellItems(3, "KnownRecipes")
        totalGoldGained = totalGoldGained + gold3
        totalItemsSold = totalItemsSold + items3

        local items4, gold4 = SellItems(4, "KnownRecipes")
        totalGoldGained = totalGoldGained + gold4
        totalItemsSold = totalItemsSold + items4
    end
    
    -- Print once with all accumulated totals
    PrintSellSummary(totalItemsSold, totalGoldGained)
end

local isInitializing = false

local function CreateOptionCheckbox(name, parent, text, point, relativeTo, relativePoint, x, y, onClick)
    local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint(point, relativeTo, relativePoint, x, y)
    local textObject = _G[name .. "Text"]
    if textObject then
        textObject:SetText(text)
    end
    check:SetScript("OnClick", onClick)
    return check
end

local addonLoaded = false

local function InitializeCheckboxes() -- addon options checkboxes
    if addonLoaded then return end
    addonLoaded = true
    
    -- Create interface panel if needed
    if not SellOMatic_InterfacePanel then
        SellOMatic_InterfacePanel = CreateFrame("Frame", "SellOMatic_InterfacePanel", InterfaceOptionsFramePanelContainer)
        SellOMatic_InterfacePanel.name = "Sell-O-Matic"
        InterfaceOptions_AddCategory(SellOMatic_InterfacePanel)
        
        SellOMatic_InterfacePanel.title = SellOMatic_InterfacePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        SellOMatic_InterfacePanel.title:SetPoint("TOPLEFT", 16, -16)
        SellOMatic_InterfacePanel.title:SetText("Sell-O-Matic Options")

        SellOMatic_InterfacePanel.description = SellOMatic_InterfacePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        SellOMatic_InterfacePanel.description:SetPoint("TOPLEFT", SellOMatic_InterfacePanel.title, "BOTTOMLEFT", 0, -8)
        SellOMatic_InterfacePanel.description:SetText("Configure auto-sell and auto-delete behavior.")
    end
    
    isInitializing = true
    
    SellOMaticOptionKeepAffixes = CreateOptionCheckbox("SellOMaticOptionKeepAffixes", SellOMatic_InterfacePanel,
        "Keep Ebonhold affixes", "TOPLEFT", SellOMatic_InterfacePanel.description, "BOTTOMLEFT", 0, -16,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.keepAffixes = isChecked
            SellOMaticOptionKeepAffixes:SetChecked(isChecked)
        end)
    SellOMaticOptionKeepAffixes:SetChecked(SellOMatic_Settings.keepAffixes or false)

    SellOMaticOptionAutoSell = CreateOptionCheckbox("SellOMaticOptionAutoSell", SellOMatic_InterfacePanel,
        "Enable auto sell on merchant open", "TOPLEFT", SellOMaticOptionKeepAffixes, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.autoSellEnabled = isChecked
            SellOMaticOptionAutoSell:SetChecked(isChecked)
        end)
    SellOMaticOptionAutoSell:SetChecked(SellOMatic_Settings.autoSellEnabled or false)

    SellOMaticOptionSellWhite = CreateOptionCheckbox("SellOMaticOptionSellWhite", SellOMatic_InterfacePanel,
        "Sell whites", "TOPLEFT", SellOMaticOptionAutoSell, "BOTTOMLEFT", 16, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellWhite = isChecked
            SellOMaticOptionSellWhite:SetChecked(isChecked)
        end)
    SellOMaticOptionSellWhite:SetChecked(SellOMatic_Settings.sellWhite or false)

    SellOMaticOptionSellGreen = CreateOptionCheckbox("SellOMaticOptionSellGreen", SellOMatic_InterfacePanel,
        "Sell greens", "TOPLEFT", SellOMaticOptionSellWhite, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellGreen = isChecked
            SellOMaticOptionSellGreen:SetChecked(isChecked)
        end)
    SellOMaticOptionSellGreen:SetChecked(SellOMatic_Settings.sellGreen or false)

    SellOMaticOptionSellBlue = CreateOptionCheckbox("SellOMaticOptionSellBlue", SellOMatic_InterfacePanel,
        "Sell blues", "TOPLEFT", SellOMaticOptionSellGreen, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellBlue = isChecked
            SellOMaticOptionSellBlue:SetChecked(isChecked)
        end)
    SellOMaticOptionSellBlue:SetChecked(SellOMatic_Settings.sellBlue)

    SellOMaticOptionSellEpic = CreateOptionCheckbox("SellOMaticOptionSellEpic", SellOMatic_InterfacePanel,
        "Sell epics", "TOPLEFT", SellOMaticOptionSellBlue, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellEpic = isChecked
            SellOMaticOptionSellEpic:SetChecked(isChecked)
        end)
    SellOMaticOptionSellEpic:SetChecked(SellOMatic_Settings.sellEpic or false)

    SellOMaticOptionSellScrolls = CreateOptionCheckbox("SellOMaticOptionSellScrolls", SellOMatic_InterfacePanel,
        "Sell scrolls", "TOPLEFT", SellOMaticOptionSellEpic, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellScrolls = isChecked
            SellOMaticOptionSellScrolls:SetChecked(isChecked)
        end)
    SellOMaticOptionSellScrolls:SetChecked(SellOMatic_Settings.sellScrolls or false)

    SellOMaticOptionSellDarkmoonCards = CreateOptionCheckbox("SellOMaticOptionSellDarkmoonCards", SellOMatic_InterfacePanel,
        "Sell Darkmoon Cards", "TOPLEFT", SellOMaticOptionSellScrolls, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellDarkmoonCards = isChecked
            SellOMaticOptionSellDarkmoonCards:SetChecked(isChecked)
        end)
    SellOMaticOptionSellDarkmoonCards:SetChecked(SellOMatic_Settings.sellDarkmoonCards or false)

    SellOMaticOptionSellKnownRecipes = CreateOptionCheckbox("SellOMaticOptionSellKnownRecipes", SellOMatic_InterfacePanel,
        "Sell known profession recipes", "TOPLEFT", SellOMaticOptionSellDarkmoonCards, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellKnownRecipes = isChecked
            SellOMaticOptionSellKnownRecipes:SetChecked(isChecked)
        end)
    SellOMaticOptionSellKnownRecipes:SetChecked(SellOMatic_Settings.sellKnownRecipes or false)

    SellOMaticOptionDeleteList = CreateOptionCheckbox("SellOMaticOptionDeleteList", SellOMatic_InterfacePanel,
        "Delete list - WIP", "TOPLEFT", SellOMaticOptionSellKnownRecipes, "BOTTOMLEFT", -16, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.deleteList = isChecked
            SellOMaticOptionDeleteList:SetChecked(isChecked)
        end)
    SellOMaticOptionDeleteList:SetChecked(SellOMatic_Settings.deleteList or false)

    isInitializing = false
end

-- Register for addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SellOMatic" then
        InitializeCheckboxes()
    elseif event == "MERCHANT_SHOW" then
        CreateSellButtons()
        DoAutoSell()
    end
end)

SLASH_SELLOMATIC1 = "/sellomatic"
SlashCmdList["SELLOMATIC"] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(SellOMatic_InterfacePanel)
end

--testing
SLASH_FIND1 = "/find"
SlashCmdList["FIND"] = function(msg)
    local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
    local _, itemLink = GetItemInfo(itemId)
    local spellId = tonumber(string.match(msg, "spell:(%d+)")) or 0
    local spellName, spellLink = GetSpellInfo(spellId)
    if itemId ~= 0 then
        print(GetItemInfo(itemId))
        local l = msg
        if l then 
            --print(l:gsub("\124", "\124\124")) -- for seeing suffixId for affix data
        end
    elseif spellId ~= 0 then
        --print(spellLink, spellName, spellId)
        print(GetSpellInfo(spellId))
    else
        print("Usage: /find item:[itemID]")
    end
end
--testing

SLASH_DELETE1 = "/delete"
SlashCmdList["DELETE"] = function(msg)
    --list command
    if msg == "list" then
        print("== Delete List ==")
        if next(deleteList) == nil then
            print("(empty)")
        else
            for itemId in pairs(deleteList) do
                local _, link = GetItemInfo(itemId)
                print("  - " .. (link or "item=" .. itemId .. " (item link not cached)"))
            end
        end
    --add command
    elseif string.match(msg, "item:(%d+)") and string.sub(msg, 1, 6) ~= "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and deleteList[itemId] == nil then
            deleteList[itemId] = true
            print("Added to delete list: " .. (link or "Unknown"))
        elseif itemId ~= 0 and deleteList[itemId] == true then
            print((link or "Unknown") .. " is already being deleted")
        end
    --remove command
    elseif string.sub(msg, 1, 6) == "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and deleteList[itemId] == true then
            deleteList[itemId] = nil
            print("Removed from delete list: " .. (link or "Unknown"))
        elseif itemId ~= 0 and deleteList[itemId] == nil then
            print((link or "Unknown") .. " is not being deleted")
        end
    elseif string.sub(msg, 1, 5) == "clear" then
        ShowCustomConfirm("Clear the delete list?  This cannot be undone.", function()
            if wipe then wipe(deleteList) else for itemId in pairs(deleteList) do deleteList[itemId] = nil end end
            print("Delete list cleared.")
        end)
    --help prints
    else
        print("/delete [item]")
        print("/delete remove [item]")
        print("/delete list")
        print("/delete clear")
    end
end

SLASH_KEEP1 = "/keep"
SlashCmdList["KEEP"] = function(msg)
    -- list command
    if msg == "list" then
        print("== Keep List ==")
        if next(keepList) == nil then
            print("(empty)")
        else
            for itemId in pairs(keepList) do
                local _, link = GetItemInfo(itemId)
                print("  - " .. (link or "item=" .. itemId .. " (item link not cached)"))
            end
        end
    -- add command
    elseif string.match(msg, "item:(%d+)") and string.sub(msg, 1, 6) ~= "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and keepList[itemId] == nil then
            keepList[itemId] = true
            print("Added to keep list: " .. (link or "Unknown"))
        elseif itemId ~= 0 and keepList[itemId] == true then
            print((link or "Unknown") .. " is already being kept")
        end
    -- remove command
    elseif string.sub(msg, 1, 6) == "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and keepList[itemId] == true then
            keepList[itemId] = nil
            print("Removed from keep list: " .. (link or "Unknown"))
        elseif itemId ~= 0 and keepList[itemId] == nil then
            print((link or "Unknown") .. " is not being kept")
        end
    -- clear command
    elseif string.sub(msg, 1, 5) == "clear" then
        ShowCustomConfirm("Clear the keep list?  This cannot be undone.", function()
            if wipe then wipe(keepList) else for itemId in pairs(keepList) do keepList[itemId] = nil end end
            print("Keep list cleared.")
        end)
    -- help prints
    else
        print("/keep [item]")
        print("/keep remove [item]")
        print("/keep list")
        print("/keep clear")
    end
end
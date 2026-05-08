-- File: SellOMatic.lua
-- Sell-O-Matic modified for Ebonhold 200 ilvl BoE farming

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

SellOMatic_Settings = SellOMatic_Settings or {}
-- Initialize settings with defaults on first load
if not SellOMatic_Settings.autoSellEnabled then
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

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["SELL_OMATIC_CLEAR_KEEP"] = {
    text = "Clear the keep list? This cannot be undone.",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function()
        if wipe then
            wipe(keepList)
        else
            for itemId in pairs(keepList) do
                keepList[itemId] = nil
            end
        end
        print("Keep list cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function SellItems(quality)
    if not MerchantFrame or not MerchantFrame:IsVisible() then
        return
    end

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc = GetItemInfo(link)
                local itemId = tonumber(string.match(link, "item:(%d+)"))
                local shouldSell = not keepList[itemId]
                local isGear = (itemType == "Armor" or itemType == "Weapon") and (itemEquipLoc ~= "")
                if shouldSell and itemQuality == quality then
                    if isGear then
                        if (quality == 3 or quality == 4) and itemLevel and itemLevel >= 200 then
                            local isBoE = false
                            local tooltip = CreateFrame("GameTooltip", "SellOMaticScanTooltip", nil, "GameTooltipTemplate")
                            tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                            tooltip:SetBagItem(bag, slot)
                            for i = 1, tooltip:NumLines() do
                                local text = _G["SellOMaticScanTooltipTextLeft" .. i]:GetText()
                                if text == ITEM_BIND_ON_EQUIP then
                                    isBoE = true
                                    break
                                end
                            end
                            if not isBoE then
                                UseContainerItem(bag, slot)
                            end
                        else
                            UseContainerItem(bag, slot)
                        end
                    end
                end
            end
        end
    end
end

local function CreateSellButtons()
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
    SellomaticSellWhiteItemsButton:SetScript("OnClick", function() SellItems(1) end)

    SellomaticSellGreenItemsButton = SellomaticSellGreenItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellGreenItemsButton:SetText("Sell Greens")
    SellomaticSellGreenItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellGreenItemsButton:SetPoint("LEFT", SellomaticSellWhiteItemsButton, "RIGHT", spacing, 0)
    SellomaticSellGreenItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellGreenItemsButton:SetScript("OnClick", function() SellItems(2) end)

    SellomaticSellBlueItemsButton = SellomaticSellBlueItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellBlueItemsButton:SetText("Sell Blues")
    SellomaticSellBlueItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellBlueItemsButton:SetPoint("TOPLEFT", SellomaticSellWhiteItemsButton, "BOTTOMLEFT", 0, -spacing)
    SellomaticSellBlueItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellBlueItemsButton:SetScript("OnClick", function() SellItems(3) end)

    SellomaticSellEpicItemsButton = SellomaticSellEpicItemsButton or CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellEpicItemsButton:SetText("Sell Epics")
    SellomaticSellEpicItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellEpicItemsButton:SetPoint("LEFT", SellomaticSellBlueItemsButton, "RIGHT", spacing, 0)
    SellomaticSellEpicItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellEpicItemsButton:SetScript("OnClick", function() SellItems(4) end)

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

    if SellOMatic_Settings.sellWhite then
        SellItems(1)
    end
    if SellOMatic_Settings.sellGreen then
        SellItems(2)
    end
    if SellOMatic_Settings.sellBlue then
        SellItems(3)
    end
    if SellOMatic_Settings.sellEpic then
        SellItems(4)
    end
end

if not SellOMatic_InterfacePanel then
    SellOMatic_InterfacePanel = CreateFrame("Frame", "SellOMatic_InterfacePanel", InterfaceOptionsFramePanelContainer)
    SellOMatic_InterfacePanel.name = "Sell-O-Matic"
    InterfaceOptions_AddCategory(SellOMatic_InterfacePanel)
end

SellOMatic_InterfacePanel.title = SellOMatic_InterfacePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
SellOMatic_InterfacePanel.title:SetPoint("TOPLEFT", 16, -16)
SellOMatic_InterfacePanel.title:SetText("Sell-O-Matic Options")

SellOMatic_InterfacePanel.description = SellOMatic_InterfacePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
SellOMatic_InterfacePanel.description:SetPoint("TOPLEFT", SellOMatic_InterfacePanel.title, "BOTTOMLEFT", 0, -8)
SellOMatic_InterfacePanel.description:SetText("Configure auto-sell and auto-delete behavior.")

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

local function InitializeCheckboxes()
    if addonLoaded then return end
    addonLoaded = true
    
    -- Create checkboxes NOW after SavedVariables are loaded
    isInitializing = true
    
    SellOMaticOptionAutoSell = CreateOptionCheckbox("SellOMaticOptionAutoSell", SellOMatic_InterfacePanel,
        "Enable auto sell on merchant open", "TOPLEFT", SellOMatic_InterfacePanel.description, "BOTTOMLEFT", 0, -16,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.autoSellEnabled = isChecked
            SellOMaticOptionAutoSell:SetChecked(isChecked)
            UpdateAutoSellCheckboxes()
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



        -- testing block
    SellOMaticOptionSellBlue = CreateOptionCheckbox("SellOMaticOptionSellBlue", SellOMatic_InterfacePanel,
        "Sell blues", "TOPLEFT", SellOMaticOptionSellGreen, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellBlue = isChecked
            SellOMaticOptionSellBlue:SetChecked(isChecked)
        end)
    SellOMaticOptionSellBlue:SetChecked(SellOMatic_Settings.sellBlue)
        -- testing block



    SellOMaticOptionSellEpic = CreateOptionCheckbox("SellOMaticOptionSellEpic", SellOMatic_InterfacePanel,
        "Sell epics", "TOPLEFT", SellOMaticOptionSellBlue, "BOTTOMLEFT", 0, -6,
        function(self)
            if isInitializing then return end
            local isChecked = self:GetChecked()
            SellOMatic_Settings.sellEpic = isChecked
            SellOMaticOptionSellEpic:SetChecked(isChecked)
        end)
    SellOMaticOptionSellEpic:SetChecked(SellOMatic_Settings.sellEpic or false)

    isInitializing = false
    UpdateAutoSellCheckboxes()
end

-- Register for addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SellOMatic" then
        InitializeCheckboxes()
    elseif event == "MERCHANT_SHOW" then
        CreateSellButtons()
        DoAutoSell()
    end
end)
frame:RegisterEvent("MERCHANT_SHOW")

SLASH_SELLOMATIC1 = "/sellomatic"
SlashCmdList["SELLOMATIC"] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(SellOMatic_InterfacePanel)
end

SLASH_KEEP1 = "/keep"
SlashCmdList["KEEP"] = function(msg)
    -- keep command
    if msg == "list" then
        print("== Keep List ==")
        if next(keepList) == nil then
            print("(empty)")
        else
            for itemId in pairs(keepList) do
                local _, link = GetItemInfo(itemId)
                print("  - " .. (link or "Unknown (" .. itemId .. ")"))
            end
        end
    -- remove command
    elseif string.sub(msg, 1, 6) == "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and keepList[itemId] == true then
            keepList[itemId] = nil
            print("Removed from keep list: " .. (link or "Unknown"))
        elseif keepList[itemId] == nil then
            print((link or "Unknown") .. " is not being kept")
        end
    -- clear command
    elseif string.sub(msg, 1, 5) == "clear" then
        StaticPopup_Show("SELL_OMATIC_CLEAR_KEEP")
    -- add command
    elseif string.match(msg, "item:(%d+)") then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        local _, link = GetItemInfo(itemId)
        if itemId ~= 0 and keepList[itemId] == nil then
            keepList[itemId] = true
            print("Added to keep list: " .. (link or "Unknown"))
        elseif keepList[itemId] == true then
            print((link or "Unknown") .. " is already being kept")
        end
    else
        print("/keep [item]")
        print("/keep remove [item]")
        print("/keep list")
        print("/keep clear")
    end
end
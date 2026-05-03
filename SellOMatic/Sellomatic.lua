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

SellOMatic_Settings = SellOMatic_Settings or {
    autoSellEnabled = false,
    sellWhite = false,
    sellGreen = false,
    sellBlue = false,
    sellEpic = false,
}

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
    if SellomaticSellWhiteItemsButton and SellomaticSellGreenItemsButton and SellomaticSellBlueItemsButton and SellomaticSellEpicItemsButton then
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        CreateSellButtons()
        DoAutoSell()
    end
end)

SLASH_SELLOMATIC1 = "/sellomatic"
SlashCmdList["SELLOMATIC"] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(SellOMatic_InterfacePanel)
end

SLASH_KEEP1 = "/keep"
SlashCmdList["KEEP"] = function(msg)
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
    elseif string.sub(msg, 1, 3) == "add" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        if itemId ~= 0 then
            keepList[itemId] = true
            local _, link = GetItemInfo(itemId)
            print("Added to keep list:(" .. (link or "Unknown") .. ")")
        end
    elseif string.sub(msg, 1, 6) == "remove" then
        local itemId = tonumber(string.match(msg, "item:(%d+)")) or 0
        if itemId ~= 0 then
            keepList[itemId] = nil
            local _, link = GetItemInfo(itemId)
            print("Removed from keep list:(" .. (link or "Unknown") .. ")")
        end
    elseif string.sub(msg, 1, 5) == "clear" then
        StaticPopup_Show("SELL_OMATIC_CLEAR_KEEP")
    else
        print("/keep add [item]")
        print("/keep remove [item]")
        print("/keep list")
        print("/keep clear")
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
SellOMatic_InterfacePanel.description:SetText("Configure auto-sell and keep list behavior.")

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

local function UpdateAutoSellCheckboxes()
    -- Keep child quality options editable so the player can configure them at any time.
    -- Their values are only used when auto-sell is enabled.
end

SellOMaticOptionAutoSell = CreateOptionCheckbox("SellOMaticOptionAutoSell", SellOMatic_InterfacePanel,
    "Enable auto sell on merchant open", "TOPLEFT", SellOMatic_InterfacePanel.description, "BOTTOMLEFT", 0, -16,
    function(self)
        SellOMatic_Settings.autoSellEnabled = self:GetChecked()
        UpdateAutoSellCheckboxes()
    end)
SellOMaticOptionAutoSell:SetChecked(SellOMatic_Settings.autoSellEnabled)

SellOMaticOptionSellWhite = CreateOptionCheckbox("SellOMaticOptionSellWhite", SellOMatic_InterfacePanel,
    "Sell whites", "TOPLEFT", SellOMaticOptionAutoSell, "BOTTOMLEFT", 16, -6,
    function(self)
        SellOMatic_Settings.sellWhite = self:GetChecked()
    end)
SellOMaticOptionSellWhite:SetChecked(SellOMatic_Settings.sellWhite)

SellOMaticOptionSellGreen = CreateOptionCheckbox("SellOMaticOptionSellGreen", SellOMatic_InterfacePanel,
    "Sell greens", "TOPLEFT", SellOMaticOptionSellWhite, "BOTTOMLEFT", 0, -6,
    function(self)
        SellOMatic_Settings.sellGreen = self:GetChecked()
    end)
SellOMaticOptionSellGreen:SetChecked(SellOMatic_Settings.sellGreen)

SellOMaticOptionSellBlue = CreateOptionCheckbox("SellOMaticOptionSellBlue", SellOMatic_InterfacePanel,
    "Sell blues", "TOPLEFT", SellOMaticOptionSellGreen, "BOTTOMLEFT", 0, -6,
    function(self)
        SellOMatic_Settings.sellBlue = self:GetChecked()
    end)
SellOMaticOptionSellBlue:SetChecked(SellOMatic_Settings.sellBlue)

SellOMaticOptionSellEpic = CreateOptionCheckbox("SellOMaticOptionSellEpic", SellOMatic_InterfacePanel,
    "Sell epics", "TOPLEFT", SellOMaticOptionSellBlue, "BOTTOMLEFT", 0, -6,
    function(self)
        SellOMatic_Settings.sellEpic = self:GetChecked()
    end)
SellOMaticOptionSellEpic:SetChecked(SellOMatic_Settings.sellEpic)

UpdateAutoSellCheckboxes()
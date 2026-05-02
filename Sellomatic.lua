-- File: SellOMatic.lua
-- Sell-O-Matic modified for Ebonhold 200 ilvl BoE farming

keepList = keepList or {}

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
    local buttonHeight = 16
    local spacing = 3
    local merchantFrameLevel = MerchantFrame:GetFrameLevel()

    local SellomaticSellWhiteItemsButton = CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellWhiteItemsButton:SetText("Sell Whites")
    SellomaticSellWhiteItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellWhiteItemsButton:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 80, -37.5)
    SellomaticSellWhiteItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellWhiteItemsButton:SetScript("OnClick", function() SellItems(1) end)

    local SellomaticSellGreenItemsButton = CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellGreenItemsButton:SetText("Sell Greens")
    SellomaticSellGreenItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellGreenItemsButton:SetPoint("LEFT", SellomaticSellWhiteItemsButton, "RIGHT", spacing, 0)
    SellomaticSellGreenItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellGreenItemsButton:SetScript("OnClick", function() SellItems(2) end)

    local SellomaticSellBlueItemsButton = CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellBlueItemsButton:SetText("Sell Blues")
    SellomaticSellBlueItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellBlueItemsButton:SetPoint("TOPLEFT", SellomaticSellWhiteItemsButton, "BOTTOMLEFT", 0, -spacing)
    SellomaticSellBlueItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellBlueItemsButton:SetScript("OnClick", function() SellItems(3) end)

    local SellomaticSellEpicItemsButton = CreateFrame("Button", nil, MerchantFrame, "OptionsButtonTemplate")
    SellomaticSellEpicItemsButton:SetText("Sell Epics")
    SellomaticSellEpicItemsButton:SetSize(buttonWidth, buttonHeight)
    SellomaticSellEpicItemsButton:SetPoint("LEFT", SellomaticSellBlueItemsButton, "RIGHT", spacing, 0)
    SellomaticSellEpicItemsButton:SetFrameLevel(merchantFrameLevel + 1)
    SellomaticSellEpicItemsButton:SetScript("OnClick", function() SellItems(4) end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        CreateSellButtons()
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
    else
        print("/keep add <item>")
        print("/keep remove <item>")
        print("/keep list")
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
SellOMatic_InterfacePanel.description:SetText("No blacklist settings are available.")
-- Initialize addon
local addonName = "Farming_Tracker"
local addon = {}
local pendingItems = {} -- Items waiting for server response

-- Create main frame but don't show it yet
local mainFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "BasicFrameTemplateWithInset")

mainFrame:SetSize(250, 400)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame.TitleBg:SetHeight(30)
mainFrame:Hide()  -- Hide initially until addon loads
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("TOPLEFT", mainFrame.TitleBg, "TOPLEFT", 5, -4)
mainFrame.title:SetText("Farming Tracker")

-- Create scrollable content area
local scrollFrame = CreateFrame("ScrollFrame", "FarmingTrackerScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -35)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 45)

local contentFrame = CreateFrame("Frame", "FarmingTrackerContentFrame", scrollFrame)
contentFrame:SetSize(200, 1) -- Height will be adjusted dynamically
scrollFrame:SetScrollChild(contentFrame)

-- Input box and button
local inputBox = CreateFrame("EditBox", "MaterialTrackerInputBox", mainFrame, "InputBoxTemplate")
inputBox:SetSize(150, 30)
inputBox:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, 10)
inputBox:SetAutoFocus(false)
inputBox:SetMaxLetters(10)

-- Add button
local addButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
addButton:SetSize(60, 30)
addButton:SetPoint("LEFT", inputBox, "RIGHT", 10, 0)
addButton:SetText("Add")

mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self)
	self:StartMoving()
end)
mainFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
end)

SLASH_FARMINGTRACKER1 = "/farmingtracker"
SLASH_FARMINGTRACKER2 = "/ft"
SlashCmdList["FARMINGTRACKER"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        FTDB.visible = false
    else
        mainFrame:Show()
        FTDB.visible = true
    end
end

-- Addon loading and event handling
function addon:OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end
    
    -- Initialize saved variables after addon loads
    if not FTDB then
        FTDB = {
            visible = false,
            trackedItems = {}
        }
    end
    
    -- Ensure trackedItems table exists (for upgrades)
    if not FTDB.trackedItems then
        FTDB.trackedItems = {}
    end
    
    -- Set initial frame visibility based on saved setting
    if FTDB.visible then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end
    
    -- Update display
    addon:UpdateItemDisplay()
end

-- Item tracking functions
function addon:AddItem(itemID)
    local itemName, itemLink = GetItemInfo(itemID)
    
    if itemName then
        -- Item is cached, add immediately
        return self:AddItemImmediate(itemID, itemName, itemLink)
    else
        -- Item not cached, request from server
        pendingItems[itemID] = true
        print("Looking up item ID " .. itemID .. "... please wait.")
        return true -- Don't show error yet
    end
end

function addon:AddItemImmediate(itemID, itemName, itemLink)
    -- Check if already tracked
    if FTDB.trackedItems[itemID] then
        print("Item '" .. itemName .. "' is already being tracked.")
        return false
    end
    
    -- Add to tracked items
    FTDB.trackedItems[itemID] = {
        name = itemName,
        link = itemLink
    }
    
    print("Added '" .. itemName .. "' to tracking list.")
    self:UpdateItemDisplay()
    return true
end

function addon:HandleItemInfoReceived(itemID)
    if pendingItems[itemID] then
        pendingItems[itemID] = nil -- Remove from pending
        
        local itemName, itemLink = GetItemInfo(itemID)
        if itemName then
            self:AddItemImmediate(itemID, itemName, itemLink)
        else
            print("Item ID " .. itemID .. " not found. Make sure it's a valid item ID.")
        end
    end
end

function addon:UpdateItemDisplay()
    -- Clear existing display
    for i, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local yOffset = 0
    local lineHeight = 20
    
    for itemID, itemData in pairs(FTDB.trackedItems) do
        local itemCount = GetItemCount(tonumber(itemID))
        
        -- Create item display frame
        local itemFrame = CreateFrame("Frame", nil, contentFrame)
        itemFrame:SetSize(200, lineHeight)
        itemFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        
        -- Item name and count text
        local itemText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemText:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
        itemText:SetText(itemData.name .. ": " .. itemCount)
        
        -- Remove button
        local removeBtn = CreateFrame("Button", nil, itemFrame, "UIPanelButtonTemplate")
        removeBtn:SetSize(20, 18)
        removeBtn:SetPoint("RIGHT", itemFrame, "RIGHT", 0, 0)
        removeBtn:SetText("X")
        removeBtn:SetScript("OnClick", function()
            addon:RemoveItem(itemID)
        end)
        
        yOffset = yOffset + lineHeight + 2
    end
    
    -- Update content frame height
    contentFrame:SetHeight(math.max(yOffset, 1))
end

function addon:RemoveItem(itemID)
    if FTDB.trackedItems[itemID] then
        local itemName = FTDB.trackedItems[itemID].name
        FTDB.trackedItems[itemID] = nil
        print("Removed '" .. itemName .. "' from tracking list.")
        self:UpdateItemDisplay()
    end
end

function addon:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        self:OnAddonLoaded(...)
    elseif event == "ITEM_COUNT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
        self:UpdateItemDisplay()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if itemID then
            self:HandleItemInfoReceived(itemID)
        end
    end
end

local eventListenerFrame = CreateFrame("Frame", "MyAddonEventListenerFrame", UIParent)
eventListenerFrame:SetScript("OnEvent", function(self, event, ...) addon:OnEvent(event, ...) end)
eventListenerFrame:RegisterEvent("ADDON_LOADED")
eventListenerFrame:RegisterEvent("ITEM_COUNT_CHANGED")
eventListenerFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventListenerFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")



-- Input box functionality
addButton:SetScript("OnClick", function()
    local itemID = inputBox:GetText()
    if itemID and itemID ~= "" then
        local numericID = tonumber(itemID)
        if numericID then
            addon:AddItem(numericID)
            inputBox:SetText("") -- Clear input
        else
            print("Please enter a valid numeric item ID.")
        end
    end
end)

-- Allow Enter key to submit
inputBox:SetScript("OnEnterPressed", function(self)
    addButton:GetScript("OnClick")(addButton)
    self:ClearFocus()
end)

-- Clear focus when escape is pressed
inputBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

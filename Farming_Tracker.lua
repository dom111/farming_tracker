-- Initialize addon
local addonName = "Farming_Tracker"
local addon = {}
local pendingItems = {} -- Items waiting for server response

-- Create main frame but don't show it yet
local mainFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(220, 300)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:Hide()  -- Hide initially until addon loads

-- Set up backdrop with transparency
mainFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
mainFrame:SetBackdropColor(0, 0, 0, 0.85)
mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

-- Create content area (no scroll frame)
local contentFrame = CreateFrame("Frame", "FarmingTrackerContentFrame", mainFrame)
contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -10)
contentFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -10)
contentFrame:SetSize(200, 300) -- Set initial size

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
SlashCmdList["FARMINGTRACKER"] = function(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()
    
    if command == "add" then
        local itemID = tonumber(arg)
        if itemID then
            addon:AddItem(itemID)
        else
            print("Usage: /ft add <itemID>")
        end
    else
        -- Toggle window visibility
        if mainFrame:IsShown() then
            mainFrame:Hide()
            FTDB.visible = false
        else
            mainFrame:Show()
            FTDB.visible = true
        end
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
    local lineHeight = 18
    local itemCount = 0
    
    -- Count items first
    for _ in pairs(FTDB.trackedItems) do
        itemCount = itemCount + 1
    end
    
    if itemCount == 0 then
        -- Show empty state message
        local emptyText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyText:SetPoint("CENTER", contentFrame, "TOP", 0, -20)
        emptyText:SetText("|cff999999Alt-click items to track|r")
        emptyText:SetFontObject("GameFontNormalSmall")
        local font, size, flags = emptyText:GetFont()
        emptyText:SetFont(font, size, "ITALIC")
        
        -- Set minimum size for empty state
        mainFrame:SetSize(220, 50)
    else
        -- Display tracked items
        for itemID, itemData in pairs(FTDB.trackedItems) do
            local itemCount = GetItemCount(tonumber(itemID))
            
            -- Create item display frame
            local itemFrame = CreateFrame("Frame", nil, contentFrame)
            itemFrame:SetSize(200, lineHeight)
            itemFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            
            -- Item name and count text
            local itemText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemText:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
            itemText:SetText(itemData.name .. ": |cffffffff" .. itemCount .. "|r")
            itemText:SetJustifyH("LEFT")
            itemText:SetWidth(165)
            
            -- Remove button (smaller, simpler)
            local removeBtn = CreateFrame("Button", nil, itemFrame)
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("RIGHT", itemFrame, "RIGHT", 0, 0)
            
            local removeBtnText = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            removeBtnText:SetPoint("CENTER")
            removeBtnText:SetText("|cffff4444×|r")
            
            removeBtn:SetScript("OnEnter", function(self)
                removeBtnText:SetText("|cffff0000×|r")
            end)
            removeBtn:SetScript("OnLeave", function(self)
                removeBtnText:SetText("|cffff4444×|r")
            end)
            removeBtn:SetScript("OnClick", function()
                addon:RemoveItem(itemID)
            end)
            
            yOffset = yOffset + lineHeight + 1
        end
        
        -- Resize main frame based on content (padding top and bottom)
        local frameHeight = yOffset + 20
        mainFrame:SetSize(220, frameHeight)
    end
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





-- Inventory click integration
-- Hook into the modified item click handler
local originalHandleModifiedItemClick = HandleModifiedItemClick
function HandleModifiedItemClick(link)
    if IsAltKeyDown() and link then
        -- Extract item ID from the link
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
            addon:AddItem(itemID)
            return -- Don't pass to original handler
        end
    end
    
    -- Call original function for other cases
    return originalHandleModifiedItemClick(link)
end

print("|cff00ff00Farming Tracker loaded!|r Alt-click items to track them, or use /ft to toggle the window.")

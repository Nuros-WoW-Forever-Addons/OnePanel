--[[
    OnePanel - OnePanel.lua
    Master host frame shell, container canvas, plugin registration API, and slash commands.
--]]

local addonName, addonTable = ...
_G.OnePanel = _G.OnePanel or addonTable
local OnePanel = _G.OnePanel

OnePanel.name = addonName
OnePanel.version = "0.0.1"
OnePanel.plugins = {}
OnePanel.pluginOrder = {}
OnePanel.activePluginId = nil

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Host Canvas Frame Initialization
-------------------------------------------------------------------------------

local function CreateMasterFrame()
    if OnePanel.frame then return OnePanel.frame end
    
    -- Main Window Container
    local frame = CreateFrame("Frame", "OnePanelFrame", UIParent)
    frame:SetSize(832, 580)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown or not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:Hide()
    
    -- Apply standard Blizzard backdrop & title bar via FrameHelper
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:ApplyBackdrop(frame,
            "Interface\\DialogFrame\\UI-DialogBox-Background",
            "Interface\\DialogFrame\\UI-DialogBox-Border",
            32, 32, { left = 11, right = 12, top = 12, bottom = 11 }
        )
        Utils.FrameHelper:AttachTitleBar(frame, "OnePanel Suite")
        Utils.FrameHelper:RegisterEscClose("OnePanelFrame")
    end
    
    -- Header / Title Bar Decoration
    local headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -18)
    headerText:SetText("|cff00ccffOnePanel|r")
    frame.Title = headerText
    
    -- Close Button
    local closeBtn = CreateFrame("Button", "OnePanelFrameCloseButton", frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
        OnePanel:Hide()
    end)
    frame.CloseButton = closeBtn
    
    -- Inner Content Display Area (Container for Plugin Views)
    local contentArea = CreateFrame("Frame", "OnePanelContentArea", frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -45)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:ApplyBackdrop(contentArea,
            "Interface\\FrameGeneral\\UI-Background-Marble",
            "Interface\\Tooltips\\UI-Tooltip-Border",
            16, 16, { left = 4, right = 4, top = 4, bottom = 4 }
        )
    end
    frame.ContentArea = contentArea
    
    OnePanel.frame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Plugin Registration API
-------------------------------------------------------------------------------

--- Register a plugin module with OnePanel master host
-- @param config table: Plugin configuration schema
function OnePanel:RegisterPlugin(config)
    if not config or type(config) ~= "table" then
        if Utils and Utils.Logger then
            Utils.Logger:Log("OnePanel", "ERROR", "RegisterPlugin failed: Invalid config table")
        end
        return false
    end
    
    local id = config.id or config.title
    if not id or type(id) ~= "string" then
        if Utils and Utils.Logger then
            Utils.Logger:Log("OnePanel", "ERROR", "RegisterPlugin failed: Plugin missing 'id'")
        end
        return false
    end
    
    if type(config.CreateView) ~= "function" then
        if Utils and Utils.Logger then
            Utils.Logger:Log("OnePanel", "ERROR", "RegisterPlugin failed: Plugin '" .. id .. "' missing 'CreateView' callback")
        end
        return false
    end
    
    config.order = config.order or 100
    OnePanel.plugins[id] = config
    
    -- Maintain ordered list of plugin IDs
    local exists = false
    for _, existingId in ipairs(OnePanel.pluginOrder) do
        if existingId == id then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(OnePanel.pluginOrder, id)
    end
    
    -- Sort plugins by order field
    table.sort(OnePanel.pluginOrder, function(a, b)
        local pA = OnePanel.plugins[a]
        local pB = OnePanel.plugins[b]
        return (pA and pA.order or 100) < (pB and pB.order or 100)
    end)
    
    if Utils and Utils.Logger then
        Utils.Logger:Log("OnePanel", "INFO", "Plugin registered: " .. id .. " (" .. (config.title or id) .. ")")
    end
    
    -- Refresh tab strip if TabManager is active
    if OnePanel.TabManager and OnePanel.TabManager.RefreshTabs then
        OnePanel.TabManager:RefreshTabs()
    end
    
    if Utils and Utils.EventBus then
        Utils.EventBus:Trigger("ONEPANEL_PLUGIN_REGISTERED", id, config)
    end
    
    return true
end

-------------------------------------------------------------------------------
-- Phase 2 Default Test Plugins
-------------------------------------------------------------------------------

local function RegisterTestPlugins()
    -- 1. Test Character Sheet Plugin
    OnePanel:RegisterPlugin({
        id = "Character",
        title = "Character",
        order = 10,
        icon = "Interface\\Icons\\INV_Chest_Chain_05",
        CreateView = function(parentFrame)
            local container = CreateFrame("Frame", "OnePanel_TestCharacterView", parentFrame)
            container:SetAllPoints(parentFrame)
            
            -- Title text
            local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            title:SetPoint("TOP", container, "TOP", 0, -60)
            title:SetText("|cff00ccffCharacter Sheet|r")
            
            -- Placeholder Notice
            local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            desc:SetPoint("TOP", title, "BOTTOM", 0, -20)
            desc:SetText("[Phase 2 Test View]\nPlaceholder View for Character Equipment & Stats.")
            
            -- Icon display
            local icon = container:CreateTexture(nil, "ARTWORK")
            icon:SetSize(64, 64)
            icon:SetPoint("CENTER", container, "CENTER", 0, 10)
            icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
            
            return container
        end,
        OnShow = function(container)
            if Utils and Utils.Logger then
                Utils.Logger:Log("CharacterView", "DEBUG", "Test Character view shown")
            end
        end,
        OnHide = function(container)
            if Utils and Utils.Logger then
                Utils.Logger:Log("CharacterView", "DEBUG", "Test Character view hidden")
            end
        end
    })
    
    -- 2. Test Professions Plugin
    OnePanel:RegisterPlugin({
        id = "Professions",
        title = "Professions",
        order = 20,
        icon = "Interface\\Icons\\Trade_Tailoring",
        CreateView = function(parentFrame)
            local container = CreateFrame("Frame", "OnePanel_TestProfessionsView", parentFrame)
            container:SetAllPoints(parentFrame)
            
            -- Title text
            local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            title:SetPoint("TOP", container, "TOP", 0, -60)
            title:SetText("|cffffcc00Professions|r")
            
            -- Placeholder Notice
            local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            desc:SetPoint("TOP", title, "BOTTOM", 0, -20)
            desc:SetText("[Phase 2 Test View]\nPlaceholder View for Crafting & Gathering Interfaces.")
            
            -- Icon display
            local icon = container:CreateTexture(nil, "ARTWORK")
            icon:SetSize(64, 64)
            icon:SetPoint("CENTER", container, "CENTER", 0, 10)
            icon:SetTexture("Interface\\Icons\\Trade_Tailoring")
            
            return container
        end,
        OnShow = function(container)
            if Utils and Utils.Logger then
                Utils.Logger:Log("ProfessionsView", "DEBUG", "Test Professions view shown")
            end
        end,
        OnHide = function(container)
            if Utils and Utils.Logger then
                Utils.Logger:Log("ProfessionsView", "DEBUG", "Test Professions view hidden")
            end
        end
    })
end

-------------------------------------------------------------------------------
-- Window Visibility & Toggle API
-------------------------------------------------------------------------------

function OnePanel:Show()
    local frame = CreateMasterFrame()
    frame:Show()
    
    -- Select first tab if none is active
    if not OnePanel.activePluginId and #OnePanel.pluginOrder > 0 then
        if OnePanel.TabManager then
            OnePanel.TabManager:SelectTab(OnePanel.pluginOrder[1])
        end
    end
end

function OnePanel:Hide()
    if OnePanel.frame then
        OnePanel.frame:Hide()
    end
end

function OnePanel:Toggle()
    local frame = CreateMasterFrame()
    if frame:IsShown() then
        OnePanel:Hide()
    else
        OnePanel:Show()
    end
end

-------------------------------------------------------------------------------
-- Event Handling & Slash Commands
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OnePanel_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        _G.OnePanelDB = _G.OnePanelDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        CreateMasterFrame()
        RegisterTestPlugins()
        
        if Utils and Utils.Logger then
            Utils.Logger:Log("OnePanel", "INFO", "OnePanel Host Shell v" .. OnePanel.version .. " loaded.")
        end
        
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Slash Commands: /onepanel or /op
SLASH_ONEPANEL1 = "/onepanel"
SLASH_ONEPANEL2 = "/op"
SlashCmdList["ONEPANEL"] = function(msg)
    OnePanel:Toggle()
end

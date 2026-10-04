--[[
    OnePanel - TabManager.lua
    Dynamic master tab controller, view container swapper, and tab button rendering.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel or addonTable
local TabManager = {}
OnePanel.TabManager = TabManager

TabManager.tabButtons = {}

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- View Container Switching Engine
-------------------------------------------------------------------------------

--- Select and display a target plugin tab
-- @param pluginId string: Unique identifier of plugin to activate
function TabManager:SelectTab(pluginId)
    local plugin = OnePanel.plugins[pluginId]
    if not plugin then
        if Utils and Utils.Logger then
            Utils.Logger:Log("TabManager", "WARN", "SelectTab failed: Plugin '" .. tostring(pluginId) .. "' not found")
        end
        return false
    end
    
    local contentArea = OnePanel.frame and OnePanel.frame.ContentArea
    if not contentArea then
        if Utils and Utils.Logger then
            Utils.Logger:Log("TabManager", "ERROR", "SelectTab failed: Host contentArea not created")
        end
        return false
    end
    
    -- Hide currently active plugin view
    if OnePanel.activePluginId and OnePanel.activePluginId ~= pluginId then
        local prevPlugin = OnePanel.plugins[OnePanel.activePluginId]
        if prevPlugin and prevPlugin.viewContainer then
            prevPlugin.viewContainer:Hide()
            if type(prevPlugin.OnHide) == "function" then
                if Utils and Utils.Logger then
                    Utils.Logger:SafeCall("Plugin:" .. prevPlugin.id, prevPlugin.OnHide, prevPlugin.viewContainer)
                else
                    pcall(prevPlugin.OnHide, prevPlugin.viewContainer)
                end
            end
        end
    end
    
    -- Lazily create view container if not yet instantiated
    if not plugin.viewContainer then
        if type(plugin.CreateView) == "function" then
            local success, container = false, nil
            if Utils and Utils.Logger then
                success, container = Utils.Logger:SafeCall("CreateView:" .. pluginId, plugin.CreateView, contentArea)
            else
                success, container = pcall(plugin.CreateView, contentArea)
            end
            
            if success and container then
                plugin.viewContainer = container
                if Utils and Utils.FrameHelper then
                    Utils.FrameHelper:ReparentFrame(container, contentArea)
                else
                    container:SetParent(contentArea)
                    container:SetAllPoints(contentArea)
                end
            else
                if Utils and Utils.Logger then
                    Utils.Logger:Log("TabManager", "ERROR", "CreateView failed for plugin: " .. pluginId)
                end
                return false
            end
        end
    end
    
    -- Show target plugin view container
    if plugin.viewContainer then
        plugin.viewContainer:Show()
        if type(plugin.OnShow) == "function" then
            if Utils and Utils.Logger then
                Utils.Logger:SafeCall("Plugin:" .. pluginId, plugin.OnShow, plugin.viewContainer)
            else
                pcall(plugin.OnShow, plugin.viewContainer)
            end
        end
    end
    
    OnePanel.activePluginId = pluginId
    self:UpdateTabHighlights()
    
    if Utils and Utils.EventBus then
        Utils.EventBus:Trigger("ONEPANEL_TAB_CHANGED", pluginId, plugin)
    end
    
    return true
end

-------------------------------------------------------------------------------
-- Dynamic Tab Rail Rendering & Positioning
-------------------------------------------------------------------------------

--- Create a styled master tab button
-- @param index number: Tab index position
-- @param pluginId string: Plugin ID
-- @return Button: Tab button frame
local function CreateTabButton(index, pluginId)
    local parentFrame = OnePanel.frame
    local buttonName = "OnePanelMasterTab" .. index
    
    local tab = CreateFrame("Button", buttonName, parentFrame, "CharacterFrameTabButtonTemplate")
    tab:SetID(index)
    tab.pluginId = pluginId
    
    tab:SetScript("OnClick", function(self)
        TabManager:SelectTab(self.pluginId)
    end)
    
    return tab
end

--- Refresh and align all master tab buttons along the frame bottom rail
function TabManager:RefreshTabs()
    local frame = OnePanel.frame
    if not frame then return end
    
    local plugins = OnePanel.plugins
    local order = OnePanel.pluginOrder
    
    for i, pluginId in ipairs(order) do
        local plugin = plugins[pluginId]
        if plugin then
            local btn = self.tabButtons[i]
            if not btn then
                btn = CreateTabButton(i, pluginId)
                self.tabButtons[i] = btn
            end
            
            btn.pluginId = pluginId
            btn:SetText(plugin.title or pluginId)
            btn:Show()
            
            -- Position tabs horizontally along bottom rail
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 19, 11)
            else
                btn:SetPoint("LEFT", self.tabButtons[i - 1], "RIGHT", -15, 0)
            end
            
            -- Apply tab width calculation via standard WoW PanelTemplates API if available
            if PanelTemplates_TabResize then
                PanelTemplates_TabResize(btn, 0)
            end
        end
    end
    
    -- Hide unused extra tab buttons
    for i = #order + 1, #self.tabButtons do
        if self.tabButtons[i] then
            self.tabButtons[i]:Hide()
        end
    end
    
    self:UpdateTabHighlights()
end

--- Update active vs inactive visual highlights on tab buttons
function TabManager:UpdateTabHighlights()
    local activeId = OnePanel.activePluginId
    for i, btn in ipairs(self.tabButtons) do
        if btn:IsShown() then
            if btn.pluginId == activeId then
                if PanelTemplates_SelectTab then
                    PanelTemplates_SelectTab(btn)
                else
                    btn:Disable()
                end
            else
                if PanelTemplates_DeselectTab then
                    PanelTemplates_DeselectTab(btn)
                else
                    btn:Enable()
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Module Event Registration
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OnePanel_TabManager_EventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if OnePanel.frame then
        TabManager:RefreshTabs()
    end
end)

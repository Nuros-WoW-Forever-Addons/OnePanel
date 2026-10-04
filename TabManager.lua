--[[
    OnePanel - TabManager.lua
    Right-side vertical tab controller, icon tab styling, and view container swapper.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel or addonTable
local TabManager = {}
OnePanel.TabManager = TabManager

TabManager.tabButtons = {}

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Right-Side Vertical Tab Button Construction
-------------------------------------------------------------------------------

--- Programmatically build a vertical right-side tab button
-- @param index number: Tab index position
-- @param pluginId string: Unique plugin identifier
-- @return Button: Created side tab button
local function CreateSideTabButton(index, pluginId)
    local parentFrame = OnePanel.frame
    local buttonName = "OnePanelSideTab" .. index
    
    local tab = CreateFrame("Button", buttonName, parentFrame)
    tab:SetSize(36, 36)
    tab:SetID(index)
    tab.pluginId = pluginId
    
    -- Outer Border Texture (SpellBook-SkillLineTab style)
    local border = tab:CreateTexture(buttonName .. "Border", "BACKGROUND")
    border:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    tab.Border = border
    
    -- Main Icon Texture
    local icon = tab:CreateTexture(buttonName .. "Icon", "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.Icon = icon
    
    -- Highlight Texture (Square hover glow)
    local highlight = tab:CreateTexture(buttonName .. "Highlight", "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(icon)
    tab.Highlight = highlight
    
    -- Active / Checked Glow Texture
    local activeGlow = tab:CreateTexture(buttonName .. "ActiveGlow", "OVERLAY")
    activeGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    activeGlow:SetBlendMode("ADD")
    activeGlow:SetAllPoints(icon)
    activeGlow:Hide()
    tab.ActiveGlow = activeGlow
    
    -- Tooltip Handlers
    tab:SetScript("OnEnter", function(self)
        local plugin = OnePanel.plugins[self.pluginId]
        if plugin then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(plugin.title or self.pluginId, 1, 1, 1)
            if plugin.tooltipDesc then
                GameTooltip:AddLine(plugin.tooltipDesc, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end
    end)
    
    tab:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)
    
    tab:SetScript("OnClick", function(self)
        TabManager:SelectTab(self.pluginId)
    end)
    
    return tab
end

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
    if not contentArea then return false end
    
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
-- Dynamic Right-Side Tab Positioning & Highlight Management
-------------------------------------------------------------------------------

--- Refresh and align all side tab buttons vertically along the right edge
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
                btn = CreateSideTabButton(i, pluginId)
                self.tabButtons[i] = btn
            end
            
            btn.pluginId = pluginId
            if plugin.icon then
                btn.Icon:SetTexture(plugin.icon)
            end
            btn:Show()
            
            -- Position side tabs vertically stacked along the right frame edge
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -36)
            else
                btn:SetPoint("TOPLEFT", self.tabButtons[i - 1], "BOTTOMLEFT", 0, -12)
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

--- Update active vs inactive visual highlights on right-side tabs
function TabManager:UpdateTabHighlights()
    local activeId = OnePanel.activePluginId
    local frame = OnePanel.frame
    
    for i, btn in ipairs(self.tabButtons) do
        if btn and btn:IsShown() then
            local isSelected = (btn.pluginId == activeId)
            
            -- Re-calculate horizontal offset: active tab shifts slightly right to pop out
            btn:ClearAllPoints()
            local xOffset = isSelected and 2 or -2
            
            if i == 1 then
                btn:SetPoint("TOPLEFT", frame, "TOPRIGHT", xOffset, -36)
            else
                btn:SetPoint("TOPLEFT", self.tabButtons[i - 1], "BOTTOMLEFT", (isSelected and 4 or 0), -12)
            end
            
            if isSelected then
                btn.Icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                if btn.ActiveGlow then btn.ActiveGlow:Show() end
            else
                btn.Icon:SetVertexColor(0.7, 0.7, 0.7, 1.0)
                if btn.ActiveGlow then btn.ActiveGlow:Hide() end
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

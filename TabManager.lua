--[[
    OnePanel - TabManager.lua
    Right-side vertical tab controller, 3D tab portraits, dynamic titles, and view swapper.
    Styling matches native Blizzard CharacterFrameModeTab buttons.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel or addonTable
local TabManager = {}
OnePanel.TabManager = TabManager

TabManager.tabButtons = {}

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Atlas / Texture Helper
-------------------------------------------------------------------------------

local function ApplyTabAtlasOrTexture(texObj, atlasName, fallbackPath)
    if not texObj then return end
    local set = false
    if texObj.SetAtlas then
        set = pcall(function() texObj:SetAtlas(atlasName, true) end)
    end
    if not set or not texObj:GetTexture() then
        texObj:SetTexture(fallbackPath)
    end
end

-------------------------------------------------------------------------------
-- Right-Side Vertical Tab Button Construction
-------------------------------------------------------------------------------

--- Programmatically build a vertical right-side tab button (Matches CharacterFrameModeTab 55x55)
-- @param index number: Tab index position
-- @param pluginId string: Unique plugin identifier
-- @return Button: Created side tab button
local function CreateSideTabButton(index, pluginId)
    local modeTabsFrame = TabManager.modeTabsFrame
    if not modeTabsFrame then
        modeTabsFrame = CreateFrame("Frame", "OnePanel_ModeTabs", OnePanel.frame)
        modeTabsFrame:SetSize(64, 384)
        modeTabsFrame:SetPoint("TOPLEFT", OnePanel.frame, "TOPRIGHT", 0, -30)
        modeTabsFrame:SetFrameLevel(OnePanel.frame:GetFrameLevel() + 2)
        TabManager.modeTabsFrame = modeTabsFrame
    end
    
    local buttonName = "OnePanelSideTab" .. index
    local tab = CreateFrame("Button", buttonName, modeTabsFrame)
    tab:SetSize(55, 55)
    tab:SetID(index)
    tab.pluginId = pluginId
    
    -- Background Texture (common-sidetab atlas)
    local bg = tab:CreateTexture(buttonName .. "Background", "BACKGROUND")
    ApplyTabAtlasOrTexture(bg, "common-sidetab", "Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetAllPoints(tab)
    tab.Background = bg
    
    -- Main Icon Texture
    local icon = tab:CreateTexture(buttonName .. "Icon", "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.Icon = icon
    
    -- Highlight Texture (common-sidetab-hover atlas)
    local highlight = tab:CreateTexture(buttonName .. "Highlight", "HIGHLIGHT")
    ApplyTabAtlasOrTexture(highlight, "common-sidetab-hover", "Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(tab)
    tab.Highlight = highlight
    
    -- Active / Selected Overlay (common-sidetab-selected atlas)
    local activeGlow = tab:CreateTexture(buttonName .. "ActiveGlow", "OVERLAY")
    ApplyTabAtlasOrTexture(activeGlow, "common-sidetab-selected", "Interface\\Buttons\\CheckButtonHilight")
    activeGlow:SetBlendMode("ADD")
    activeGlow:SetAllPoints(tab)
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
    
    -- Update dynamic title bar
    if OnePanel.SetTitleText then
        OnePanel:SetTitleText(plugin.title or pluginId)
    end
    
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
            
            -- Check for 3D portrait tab requirement
            if plugin.use3DPortrait or pluginId == "Character" then
                if not btn.PlayerModel then
                    local model = CreateFrame("PlayerModel", btn:GetName() .. "3DPortrait", btn)
                    model:SetSize(30, 30)
                    model:SetPoint("CENTER", btn, "CENTER", 0, 0)
                    model:SetFrameLevel(btn:GetFrameLevel() + 2)
                    model:SetUnit("player")
                    if model.SetPortraitZoom then model:SetPortraitZoom(1) end
                    btn.PlayerModel = model
                else
                    btn.PlayerModel:SetSize(30, 30)
                    btn.PlayerModel:SetPoint("CENTER", btn, "CENTER", 0, 0)
                    btn.PlayerModel:SetUnit("player")
                    if btn.PlayerModel.SetPortraitZoom then btn.PlayerModel:SetPortraitZoom(1) end
                    btn.PlayerModel:Show()
                end
                btn.Icon:Hide()
            else
                if btn.PlayerModel then btn.PlayerModel:Hide() end
                btn.Icon:Show()
                if plugin.icon then
                    btn.Icon:SetTexture(plugin.icon)
                end
            end
            
            btn:Show()
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
    local modeTabsFrame = TabManager.modeTabsFrame
    if not modeTabsFrame then return end
    
    for i, btn in ipairs(self.tabButtons) do
        if btn and btn:IsShown() then
            local isSelected = (btn.pluginId == activeId)
            
            btn:ClearAllPoints()
            local xOffset = isSelected and 0 or -2
            
            if i == 1 then
                btn:SetPoint("TOPLEFT", modeTabsFrame, "TOPLEFT", xOffset, 0)
            else
                btn:SetPoint("TOPLEFT", self.tabButtons[i - 1], "BOTTOMLEFT", 0, -6)
            end
            
            if isSelected then
                if btn.Icon then btn.Icon:SetVertexColor(1.0, 1.0, 1.0, 1.0) end
                if btn.ActiveGlow then btn.ActiveGlow:Show() end
            else
                if btn.Icon then btn.Icon:SetVertexColor(0.7, 0.7, 0.7, 1.0) end
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
eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_MODEL_CHANGED" and unit ~= "player" then return end
    if OnePanel.frame then
        TabManager:RefreshTabs()
    end
end)

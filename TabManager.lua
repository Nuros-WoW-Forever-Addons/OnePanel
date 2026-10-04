--[[
    OnePanel - TabManager.lua
    Dynamic master tab controller, view container swapper, and fallback tab button rendering.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel or addonTable
local TabManager = {}
OnePanel.TabManager = TabManager

TabManager.tabButtons = {}

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Fallback Custom Tab Construction
-------------------------------------------------------------------------------

--- Programmatically build a tab button if native XML template is missing
-- @param button Button: The target button frame
local function BuildCustomTabTextures(button)
    if button.isCustomTabBuilt then return end
    button.isCustomTabBuilt = true
    
    -- Inactive Background Textures
    local left = button:CreateTexture(button:GetName() .. "Left", "BACKGROUND")
    left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    left:SetSize(20, 32)
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
    left:SetTexCoord(0, 0.15625, 0, 1.0)
    button.Left = left
    
    local right = button:CreateTexture(button:GetName() .. "Right", "BACKGROUND")
    right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    right:SetSize(20, 32)
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -1)
    right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    button.Right = right
    
    local middle = button:CreateTexture(button:GetName() .. "Middle", "BACKGROUND")
    middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    middle:SetHeight(32)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    button.Middle = middle
    
    -- Active / Disabled Textures
    local leftDisabled = button:CreateTexture(button:GetName() .. "LeftDisabled", "BACKGROUND")
    leftDisabled:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    leftDisabled:SetSize(20, 35)
    leftDisabled:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    leftDisabled:SetTexCoord(0, 0.15625, 0, 0.546875)
    leftDisabled:Hide()
    button.LeftDisabled = leftDisabled
    
    local rightDisabled = button:CreateTexture(button:GetName() .. "RightDisabled", "BACKGROUND")
    rightDisabled:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    rightDisabled:SetSize(20, 35)
    rightDisabled:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    rightDisabled:SetTexCoord(0.84375, 1.0, 0, 0.546875)
    rightDisabled:Hide()
    button.RightDisabled = rightDisabled
    
    local middleDisabled = button:CreateTexture(button:GetName() .. "MiddleDisabled", "BACKGROUND")
    middleDisabled:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    middleDisabled:SetHeight(35)
    middleDisabled:SetPoint("LEFT", leftDisabled, "RIGHT", 0, 0)
    middleDisabled:SetPoint("RIGHT", rightDisabled, "LEFT", 0, 0)
    middleDisabled:SetTexCoord(0.15625, 0.84375, 0, 0.546875)
    middleDisabled:Hide()
    button.MiddleDisabled = middleDisabled
    
    -- Text Label
    local text = button:CreateFontString(button:GetName() .. "Text", "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 2)
    button.Text = text
    button:SetFontString(text)
    
    -- Highlight Texture
    local highlight = button:CreateTexture(button:GetName() .. "HighlightTexture", "HIGHLIGHT")
    highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, 5)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 0)
    button.HighlightTexture = highlight
end

-------------------------------------------------------------------------------
-- Dynamic Tab Rail Rendering & Positioning
-------------------------------------------------------------------------------

--- Create a styled master tab button with template fallback safety
-- @param index number: Tab index position
-- @param pluginId string: Plugin ID
-- @return Button: Tab button frame
local function CreateTabButton(index, pluginId)
    local parentFrame = OnePanel.frame
    local buttonName = "OnePanelMasterTab" .. index
    
    local tab = nil
    -- Try native templates first
    local templatesToTry = {
        "CharacterFrameTabButtonTemplate",
        "PanelTabButtonTemplate",
        "TabButtonTemplate"
    }
    
    for _, templateName in ipairs(templatesToTry) do
        local ok, btn = pcall(CreateFrame, "Button", buttonName, parentFrame, templateName)
        if ok and btn then
            tab = btn
            break
        end
    end
    
    -- Fallback: Create un-templated button and programmatically construct graphics
    if not tab then
        tab = CreateFrame("Button", buttonName, parentFrame)
        BuildCustomTabTextures(tab)
    end
    
    tab:SetID(index)
    tab:SetHeight(32)
    tab.pluginId = pluginId
    
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
            local text = plugin.title or pluginId
            btn:SetText(text)
            btn:Show()
            
            -- Calculate button width based on text
            local textFontString = btn.Text or _G[btn:GetName() .. "Text"]
            local textWidth = textFontString and textFontString:GetStringWidth() or 60
            local btnWidth = math.max(80, textWidth + 30)
            btn:SetWidth(btnWidth)
            
            -- Position tabs horizontally along bottom rail
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 19, 11)
            else
                btn:SetPoint("LEFT", self.tabButtons[i - 1], "RIGHT", -5, 0)
            end
            
            if PanelTemplates_TabResize then
                pcall(PanelTemplates_TabResize, btn, 0)
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
        if btn and btn:IsShown() then
            local isSelected = (btn.pluginId == activeId)
            
            if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
                if isSelected then
                    pcall(PanelTemplates_SelectTab, btn)
                else
                    pcall(PanelTemplates_DeselectTab, btn)
                end
            else
                -- Fallback custom tab highlighting
                if isSelected then
                    if btn.LeftDisabled then btn.LeftDisabled:Show() end
                    if btn.MiddleDisabled then btn.MiddleDisabled:Show() end
                    if btn.RightDisabled then btn.RightDisabled:Show() end
                    if btn.Left then btn.Left:Hide() end
                    if btn.Middle then btn.Middle:Hide() end
                    if btn.Right then btn.Right:Hide() end
                    if btn.Text then btn.Text:SetTextColor(1, 0.82, 0) end
                else
                    if btn.LeftDisabled then btn.LeftDisabled:Hide() end
                    if btn.MiddleDisabled then btn.MiddleDisabled:Hide() end
                    if btn.RightDisabled then btn.RightDisabled:Hide() end
                    if btn.Left then btn.Left:Show() end
                    if btn.Middle then btn.Middle:Show() end
                    if btn.Right then btn.Right:Show() end
                    if btn.Text then btn.Text:SetTextColor(0.5, 0.5, 0.5) end
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

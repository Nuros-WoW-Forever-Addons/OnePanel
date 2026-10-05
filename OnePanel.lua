--[[
    OnePanel - OnePanel.lua
    Master host frame shell, centered character title, top-left scaled circular portrait,
    subdued background art, and collapsible side panel window sizing.
--]]

local addonName, addonTable = ...
_G.OnePanel = _G.OnePanel or addonTable
local OnePanel = _G.OnePanel

OnePanel.name = addonName
OnePanel.version = "0.0.1"
OnePanel.plugins = {}
OnePanel.pluginOrder = {}
OnePanel.activePluginId = nil
OnePanel.isExpanded = true

local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Dynamic Title Bar & Window Width API
-------------------------------------------------------------------------------

--- Dynamically set the main window title header (centered First & Last name)
-- @param titleText string: Optional custom title override
function OnePanel:SetTitleText(titleText)
    if self.frame and self.frame.Title then
        local name = UnitName("player") or "Player"
        local displayTitle = titleText or name
        self.frame.Title:SetText("|cffffffff" .. displayTitle .. "|r")
    end
end

--- Collapse or Expand the master window frame width
-- @param expanded boolean: True to expand (832px), False to collapse (520px)
function OnePanel:SetPanelExpanded(expanded)
    self.isExpanded = (expanded ~= false)
    if self.frame then
        local targetWidth = self.isExpanded and 832 or 520
        self.frame:SetWidth(targetWidth)
        
        if Utils and Utils.EventBus then
            Utils.EventBus:Trigger("ONEPANEL_EXPAND_STATE_CHANGED", self.isExpanded)
        end
    end
end

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
        Utils.FrameHelper:RegisterEscClose("OnePanelFrame")
    end
    
    -- Centered Title Header FontString (First & Last Name)
    local headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
    headerText:SetPoint("TOP", frame, "TOP", 0, -12)
    headerText:SetText("|cffffffff" .. (UnitName("player") or "Player") .. "|r")
    frame.Title = headerText
    
    -- Top-Left Scaled Circular Class/Player Portrait Icon (Positioned cleanly on top-left corner)
    local classIcon = frame:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(46, 46)
    classIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:SetClassIcon(classIcon)
    end
    frame.ClassIcon = classIcon
    
    local classRing = frame:CreateTexture(nil, "OVERLAY")
    classRing:SetSize(62, 62)
    classRing:SetPoint("CENTER", classIcon, "CENTER", 0, 0)
    classRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    classRing:SetDesaturated(true)
    classRing:SetVertexColor(0.85, 0.85, 0.85)
    frame.ClassRing = classRing
    
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
            nil,
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
    if not config or type(config) ~= "table" then return false end
    
    local id = config.id or config.title
    if not id or type(id) ~= "string" then return false end
    if type(config.CreateView) ~= "function" then return false end
    
    config.order = config.order or 100
    OnePanel.plugins[id] = config
    
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
    
    table.sort(OnePanel.pluginOrder, function(a, b)
        local pA = OnePanel.plugins[a]
        local pB = OnePanel.plugins[b]
        return (pA and pA.order or 100) < (pB and pB.order or 100)
    end)
    
    if OnePanel.TabManager and OnePanel.TabManager.RefreshTabs then
        OnePanel.TabManager:RefreshTabs()
    end
    
    if Utils and Utils.EventBus then
        Utils.EventBus:Trigger("ONEPANEL_PLUGIN_REGISTERED", id, config)
    end
    
    return true
end

-------------------------------------------------------------------------------
-- Window Visibility & Toggle API
-------------------------------------------------------------------------------

function OnePanel:Show()
    local frame = CreateMasterFrame()
    frame:Show()
    
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

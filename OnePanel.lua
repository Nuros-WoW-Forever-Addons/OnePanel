--[[
    OnePanel - OnePanel.lua
    Master host frame shell utilizing Blizzard's native PortraitFrameTemplate
    for 1:1 visual parity with native frames, centered title, top-left portrait ring,
    and collapsible side panel window sizing.
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
    if not self.frame then return end
    local name = UnitName("player") or "Player"
    local displayTitle = titleText or name
    
    if self.frame.SetTitle then
        self.frame:SetTitle(displayTitle)
    elseif self.frame.TitleContainer and self.frame.TitleContainer.TitleText then
        self.frame.TitleContainer.TitleText:SetText(displayTitle)
    elseif self.frame.Title then
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
        
        if self.frame.RightSideToggleButton then
            self.frame.RightSideToggleButton:UpdateIcon()
        end
        
        if Utils and Utils.EventBus then
            Utils.EventBus:Trigger("ONEPANEL_EXPAND_STATE_CHANGED", self.isExpanded)
        end
    end
end

--- Set or update the header portrait icon inside OnePanel's master frame ring
-- @param texturePath string|nil: Icon texture path
-- @param texCoords table|nil: Optional {left, right, top, bottom} coords
-- @param usePlayerPortrait boolean|nil: If true, calls SetPortraitTexture for player
function OnePanel:SetHeaderPortrait(texturePath, texCoords, usePlayerPortrait)
    if not self.frame then return end
    
    local portraitTex = (self.frame.PortraitContainer and self.frame.PortraitContainer.portrait)
        or self.frame.portrait
        or self.frame.PortraitIcon
        
    if not portraitTex then return end
    
    portraitTex:Show()
    
    if usePlayerPortrait then
        SetPortraitTexture(portraitTex, "player")
        portraitTex:SetTexCoord(0, 1, 0, 1)
    elseif texturePath then
        portraitTex:SetTexture(texturePath)
        if texCoords and type(texCoords) == "table" and #texCoords == 4 then
            portraitTex:SetTexCoord(unpack(texCoords))
        else
            portraitTex:SetTexCoord(0, 1, 0, 1)
        end
    else
        if Utils and Utils.FrameHelper then
            Utils.FrameHelper:SetClassIcon(portraitTex)
        else
            SetPortraitTexture(portraitTex, "player")
            portraitTex:SetTexCoord(0, 1, 0, 1)
        end
    end
end

-------------------------------------------------------------------------------
-- Host Canvas Frame Initialization
-------------------------------------------------------------------------------

local function CreateMasterFrame()
    if OnePanel.frame then return OnePanel.frame end
    
    -- Main Window Container using native Blizzard PortraitFrameTemplate
    local frame = CreateFrame("Frame", "OnePanelFrame", UIParent, "PortraitFrameTemplate")
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
    
    -- Register Esc key close
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:RegisterEscClose("OnePanelFrame")
    end
    
    -- Store frame reference
    OnePanel.frame = frame
    
    -- Set Initial Title & Portrait
    OnePanel:SetTitleText()
    OnePanel:SetHeaderPortrait()
    
    -- Inner Content Display Area (Container for Plugin Views)
    local contentArea = CreateFrame("Frame", "OnePanelContentArea", frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:ApplyBackdrop(contentArea,
            nil,
            "Interface\\Tooltips\\UI-Tooltip-Border",
            16, 16, { left = 4, right = 4, top = 4, bottom = 4 }
        )
    end
    frame.ContentArea = contentArea
    -- Native Right-Side Collapse / Expand Toggle Button (Matches CharacterFrameRightPaneToggleButton)
    local toggleBtn = CreateFrame("Button", "OnePanel_RightSideToggleButton", frame)
    toggleBtn:SetSize(28, 28)
    toggleBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    toggleBtn:SetFrameLevel(510)
    
    local toggleIcon = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints(toggleBtn)
    local setNorm = pcall(function() toggleIcon:SetTexture(130869) end)
    if not setNorm or not toggleIcon:GetTexture() then
        toggleIcon:SetTexture("Interface\\Buttons\\UI-SpellbookSearch-DrillDown")
    end
    toggleBtn.Icon = toggleIcon
    
    local toggleHilight = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
    local setHilight = pcall(function() toggleHilight:SetTexture(130757) end)
    if not setHilight or not toggleHilight:GetTexture() then
        toggleHilight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    end
    toggleHilight:SetBlendMode("ADD")
    toggleHilight:SetAllPoints(toggleBtn)
    
    local function UpdateToggleIcon()
        if OnePanel.isExpanded then
            toggleIcon:SetTexCoord(0, 1, 0, 1)
        else
            toggleIcon:SetTexCoord(1, 0, 0, 1)
        end
    end
    toggleBtn.UpdateIcon = UpdateToggleIcon
    UpdateToggleIcon()
    
    toggleBtn:SetScript("OnClick", function()
        OnePanel:SetPanelExpanded(not OnePanel.isExpanded)
    end)
    
    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(OnePanel.isExpanded and "Collapse Side Panel" or "Expand Side Panel", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function() GameTooltip_Hide() end)
    
    frame.RightSideToggleButton = toggleBtn

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

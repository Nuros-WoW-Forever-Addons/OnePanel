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

--- Set or update the header portrait icon inside OnePanel's master frame ring
-- @param texturePath string|nil: Icon texture path
-- @param texCoords table|nil: Optional {left, right, top, bottom} coords
-- @param usePlayerPortrait boolean|nil: If true, calls SetPortraitTexture for player
function OnePanel:SetHeaderPortrait(texturePath, texCoords, usePlayerPortrait)
    if not self.frame or not self.frame.PortraitIcon then return end
    
    if usePlayerPortrait then
        SetPortraitTexture(self.frame.PortraitIcon, "player")
    elseif texturePath then
        self.frame.PortraitIcon:SetTexture(texturePath)
        if texCoords and type(texCoords) == "table" and #texCoords == 4 then
            self.frame.PortraitIcon:SetTexCoord(unpack(texCoords))
        else
            self.frame.PortraitIcon:SetTexCoord(0, 1, 0, 1)
        end
    else
        if Utils and Utils.FrameHelper then
            Utils.FrameHelper:SetClassIcon(self.frame.PortraitIcon)
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
    
    -- Top-Left Circular Portrait Ring & Icon (Master Host Base Shell Feature)
    local portraitRing = frame:CreateTexture("OnePanelFramePortraitRing", "OVERLAY")
    portraitRing:SetSize(96, 96)
    portraitRing:SetPoint("CENTER", frame, "TOPLEFT", 0, 0)
    portraitRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    portraitRing:SetDesaturated(true)
    portraitRing:SetVertexColor(0.85, 0.85, 0.85)
    frame.PortraitRing = portraitRing
    
    local portraitIcon = frame:CreateTexture("OnePanelFramePortraitIcon", "ARTWORK")
    portraitIcon:SetSize(60, 60)
    portraitIcon:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:SetClassIcon(portraitIcon)
    end
    frame.PortraitIcon = portraitIcon
    
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
-- 1px Precision Nudger Tool for Portrait & Ring Positioning/Scaling
-------------------------------------------------------------------------------

--- Toggle or enable the in-game 1px Nudger tool for pixel-perfect adjustments
-- @param enable boolean|nil: True to enable, False to disable, nil to toggle
function OnePanel:EnableGUIBuilder(enable)
    local frame = CreateMasterFrame()
    if not frame then return end
    
    if enable == nil then
        self.guiBuilderEnabled = not self.guiBuilderEnabled
    else
        self.guiBuilderEnabled = enable
    end
    
    if not self.nudgerWindow then
        local nudger = CreateFrame("Frame", "OnePanel_NudgerWindow", frame)
        nudger:SetSize(340, 180)
        nudger:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 10)
        nudger:SetFrameStrata("TOOLTIP")
        nudger:EnableMouse(true)
        nudger:SetMovable(true)
        nudger:RegisterForDrag("LeftButton")
        nudger:SetScript("OnDragStart", function(self) self:StartMoving() end)
        nudger:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        if Utils and Utils.FrameHelper then
            Utils.FrameHelper:ApplyBackdrop(nudger,
                "Interface\\DialogFrame\\UI-DialogBox-Background",
                "Interface\\DialogFrame\\UI-DialogBox-Border",
                16, 16, { left = 4, right = 4, top = 4, bottom = 4 }
            )
        end
        
        -- State variables
        nudger.ringX = 0
        nudger.ringY = 0
        nudger.ringSize = 96
        nudger.iconSize = 60
        nudger.iconOffsetX = 0
        nudger.iconOffsetY = 0
        
        -- Display FontStrings
        local title = nudger:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", nudger, "TOP", 0, -8)
        title:SetText("|cffffd1001px Precision Nudger Tool|r")
        
        local infoText = nudger:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoText:SetPoint("TOPLEFT", nudger, "TOPLEFT", 12, -28)
        infoText:SetPoint("TOPRIGHT", nudger, "TOPRIGHT", -12, -28)
        infoText:SetJustifyH("LEFT")
        nudger.InfoText = infoText
        
        local function UpdateLayout()
            frame.PortraitRing:SetSize(nudger.ringSize, nudger.ringSize)
            frame.PortraitRing:ClearAllPoints()
            frame.PortraitRing:SetPoint("CENTER", frame, "TOPLEFT", nudger.ringX, nudger.ringY)
            
            frame.PortraitIcon:SetSize(nudger.iconSize, nudger.iconSize)
            frame.PortraitIcon:ClearAllPoints()
            frame.PortraitIcon:SetPoint("CENTER", frame.PortraitRing, "CENTER", nudger.iconOffsetX, nudger.iconOffsetY)
            
            local line1 = string.format("Ring Size: |cffffffff%d x %d|r  |  Ring Offset: |cffffffffX=%d, Y=%d|r",
                nudger.ringSize, nudger.ringSize, nudger.ringX, nudger.ringY)
            local line2 = string.format("Icon Size: |cffffffff%d x %d|r  |  Icon Offset: |cffffffffX=%d, Y=%d|r",
                nudger.iconSize, nudger.iconSize, nudger.iconOffsetX, nudger.iconOffsetY)
            nudger.InfoText:SetText(line1 .. "\n" .. line2)
            
            if Utils and Utils.Logger then
                Utils.Logger:Log("NUDGER", "INFO", line1 .. " | " .. line2)
            end
        end
        nudger.UpdateLayout = UpdateLayout
        
        -- Helper to create 1px Nudge buttons
        local function CreateNudgeBtn(name, label, width, x, y, onClick)
            local btn = CreateFrame("Button", name, nudger, "UIPanelButtonTemplate")
            btn:SetSize(width, 22)
            btn:SetPoint("TOPLEFT", nudger, "TOPLEFT", x, y)
            btn:SetText(label)
            btn:SetScript("OnClick", function()
                onClick()
                nudger:UpdateLayout()
            end)
            return btn
        end
        
        -- Row 1: Ring Position 1px Directional Nudgers
        CreateNudgeBtn("OP_NudgeUp", "▲ Up (+1)", 74, 12, -62, function() nudger.ringY = nudger.ringY + 1 end)
        CreateNudgeBtn("OP_NudgeDown", "▼ Down (-1)", 74, 90, -62, function() nudger.ringY = nudger.ringY - 1 end)
        CreateNudgeBtn("OP_NudgeLeft", "◄ Left (-1)", 74, 168, -62, function() nudger.ringX = nudger.ringX - 1 end)
        CreateNudgeBtn("OP_NudgeRight", "Right ► (+1)", 82, 246, -62, function() nudger.ringX = nudger.ringX + 1 end)
        
        -- Row 2: Ring Size & Icon Size 1px Controls
        CreateNudgeBtn("OP_RingPlus", "Ring +1", 74, 12, -90, function() nudger.ringSize = nudger.ringSize + 1 end)
        CreateNudgeBtn("OP_RingMinus", "Ring -1", 74, 90, -90, function() nudger.ringSize = math.max(10, nudger.ringSize - 1) end)
        CreateNudgeBtn("OP_IconPlus", "Icon +1", 74, 168, -90, function() nudger.iconSize = nudger.iconSize + 1 end)
        CreateNudgeBtn("OP_IconMinus", "Icon -1", 82, 246, -90, function() nudger.iconSize = math.max(10, nudger.iconSize - 1) end)
        
        -- Row 3: Icon Offset Nudgers
        CreateNudgeBtn("OP_IconOffsetXMinus", "Icon X-1", 74, 12, -118, function() nudger.iconOffsetX = nudger.iconOffsetX - 1 end)
        CreateNudgeBtn("OP_IconOffsetXPlus", "Icon X+1", 74, 90, -118, function() nudger.iconOffsetX = nudger.iconOffsetX + 1 end)
        CreateNudgeBtn("OP_IconOffsetYMinus", "Icon Y-1", 74, 168, -118, function() nudger.iconOffsetY = nudger.iconOffsetY - 1 end)
        CreateNudgeBtn("OP_IconOffsetYPlus", "Icon Y+1", 82, 246, -118, function() nudger.iconOffsetY = nudger.iconOffsetY + 1 end)
        
        -- Row 4: Copy / Print Coordinates Button
        local printBtn = CreateFrame("Button", "OP_PrintCoordsBtn", nudger, "UIPanelButtonTemplate")
        printBtn:SetSize(316, 22)
        printBtn:SetPoint("TOPLEFT", nudger, "TOPLEFT", 12, -146)
        printBtn:SetText("Log / Print Coordinates to Chat & Swatter")
        printBtn:SetScript("OnClick", function()
            local code1 = string.format("portraitRing:SetSize(%d, %d)", nudger.ringSize, nudger.ringSize)
            local code2 = string.format("portraitRing:SetPoint('CENTER', frame, 'TOPLEFT', %d, %d)", nudger.ringX, nudger.ringY)
            local code3 = string.format("portraitIcon:SetSize(%d, %d)", nudger.iconSize, nudger.iconSize)
            local code4 = string.format("portraitIcon:SetPoint('CENTER', portraitRing, 'CENTER', %d, %d)", nudger.iconOffsetX, nudger.iconOffsetY)
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[OnePanel Nudger Final Coordinates]|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. code1 .. "|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. code2 .. "|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. code3 .. "|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. code4 .. "|r")
            end
            if Utils and Utils.Logger then
                Utils.Logger:Log("NUDGER_SAVE", "INFO", code1 .. " | " .. code2 .. " | " .. code3 .. " | " .. code4)
            end
        end)
        
        self.nudgerWindow = nudger
    end
    
    if self.guiBuilderEnabled then
        frame:Show()
        self.nudgerWindow:Show()
        self.nudgerWindow:UpdateLayout()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OnePanel 1px Nudger ENABLED]|r Use on-screen buttons to adjust position by 1px steps.")
            DEFAULT_CHAT_FRAME:AddMessage("|cffffffffType /opgui or /onepanelgui again to hide.|r")
        end
    else
        if self.nudgerWindow then
            self.nudgerWindow:Hide()
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OnePanel 1px Nudger DISABLED]|r")
        end
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

-- GUI Builder Command: /opgui or /onepanelgui
SLASH_ONEPANELGUI1 = "/opgui"
SLASH_ONEPANELGUI2 = "/onepanelgui"
SlashCmdList["ONEPANELGUI"] = function(msg)
    OnePanel:EnableGUIBuilder()
end

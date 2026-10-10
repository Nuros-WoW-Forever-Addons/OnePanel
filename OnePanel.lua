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

--- Return the player's full name (supporting TRP3/MRP RP names, PvP title, or UnitName)
function OnePanel:GetPlayerFullName()
    -- 1. Total RP 3
    if _G.TRP3_API and _G.TRP3_API.register and _G.TRP3_API.register.getPlayerCompleteName then
        local ok, trpName = pcall(_G.TRP3_API.register.getPlayerCompleteName, true)
        if ok and trpName and trpName ~= "" then return trpName end
    end
    -- 2. MyRolePlay
    if _G.mrp and _G.mrp.GetPlayerFullName then
        local ok, mrpName = pcall(function() return _G.mrp:GetPlayerFullName() end)
        if ok and mrpName and mrpName ~= "" then return mrpName end
    end
    -- 3. UnitPVPName (returns "Saulest Nurotic" or title rank)
    if UnitPVPName then
        local ok, pvpName = pcall(UnitPVPName, "player")
        if ok and pvpName and pvpName ~= "" then return pvpName end
    end
    -- 4. Native UnitName fallback
    return UnitName("player") or "Player"
end

--- Dynamically set the main window title header (centered First & Last name)
-- @param titleText string: Optional custom title override
function OnePanel:SetTitleText(titleText)
    if not self.frame then return end
    local displayTitle = titleText or self:GetPlayerFullName()
    
    if self.frame.SetTitle then
        self.frame:SetTitle(displayTitle)
    elseif self.frame.TitleContainer and self.frame.TitleContainer.TitleText then
        self.frame.TitleContainer.TitleText:SetText(displayTitle)
    elseif self.frame.Title then
        self.frame.Title:SetText("|cffffffff" .. displayTitle .. "|r")
    end
end

--- Collapse or Expand the master window frame width
-- @param expanded boolean: True to expand (580px), False to collapse (370px)
function OnePanel:SetPanelExpanded(expanded)
    self.isExpanded = (expanded ~= false)
    if self.frame then
        local targetWidth = self.isExpanded and 580 or 370
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

local function SaveMasterFramePosition(frame)
    if not frame then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point and xOfs and yOfs then
        _G.OnePanelDB = _G.OnePanelDB or {}
        _G.OnePanelDB.position = {
            point = point,
            relativePoint = relativePoint or point,
            x = math.floor(xOfs + 0.5),
            y = math.floor(yOfs + 0.5),
        }
    end
end

local function RestoreMasterFramePosition(frame)
    if not frame then return end
    if _G.OnePanelDB and _G.OnePanelDB.position then
        local pos = _G.OnePanelDB.position
        if pos.point and pos.x and pos.y then
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
            return
        end
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function CreateMasterFrame()
    if OnePanel.frame then return OnePanel.frame end
    
    -- Main Window Container using native Blizzard PortraitFrameTemplate
    local frame = CreateFrame("Frame", "OnePanelFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(580, 475)
    RestoreMasterFramePosition(frame)
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
        SaveMasterFramePosition(self)
    end)
    frame:Hide()
    
    -- Register Esc key close
    if Utils and Utils.FrameHelper then
        Utils.FrameHelper:RegisterEscClose("OnePanelFrame")
    end
    
    -- Sound effects on Open / Close (Native Character Info sounds)
    local function PlayOpenSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN) or 839
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igCharacterInfoOpen")
        end
    end

    local function PlayCloseSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE) or 840
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igCharacterInfoClose")
        end
    end

    if frame.HookScript then
        frame:HookScript("OnShow", PlayOpenSound)
        frame:HookScript("OnHide", PlayCloseSound)
    else
        frame:SetScript("OnShow", PlayOpenSound)
        frame:SetScript("OnHide", PlayCloseSound)
    end
    
    -- Store frame reference
    OnePanel.frame = frame
    
    -- Apply HiRes Frame Artwork Theme (UIFrameHiRes)
    if Utils and Utils.FrameHelper and Utils.FrameHelper.ApplyHiResFrame then
        Utils.FrameHelper:ApplyHiResFrame(frame)
    end
    
    -- Set Initial Title & Portrait
    OnePanel:SetTitleText()
    OnePanel:SetHeaderPortrait()
    
    -- Inner Content Display Area (Container for Plugin Views)
    local contentArea = CreateFrame("Frame", "OnePanelContentArea", frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    contentArea:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.ContentArea = contentArea

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
        if OnePanel.frame then
            RestoreMasterFramePosition(OnePanel.frame)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        local frame = CreateMasterFrame()
        RestoreMasterFramePosition(frame)
        
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

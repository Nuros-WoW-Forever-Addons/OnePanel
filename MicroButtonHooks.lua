--[[
    OnePanel - MicroButtonHooks.lua
    Secure, taint-free hooks for native WoW toggle routines using hooksecurefunc.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel or addonTable
local MicroButtonHooks = {}
OnePanel.MicroButtonHooks = MicroButtonHooks

local Utils = _G.OnePanelUtils

-- Map of native Blizzard toggle function names to OnePanel plugin IDs
local ToggleMapping = {
    ["ToggleCharacter"]   = "Character",
    ["ToggleProfessions"] = "Professions",
    ["ToggleSpellBook"]   = "SpellBook",
    ["ToggleTalentFrame"] = "Talents",
}

-------------------------------------------------------------------------------
-- Secure Hook Engine (Zero Taint)
-------------------------------------------------------------------------------

--- Install taint-free secure hooks on native Blizzard toggle routines
function MicroButtonHooks:Initialize()
    for globalFuncName, pluginId in pairs(ToggleMapping) do
        if type(_G[globalFuncName]) == "function" then
            hooksecurefunc(globalFuncName, function(subFrame, ...)
                local targetPluginId = pluginId
                if globalFuncName == "ToggleCharacter" then
                    if subFrame == "ReputationFrame" and OnePanel.plugins and OnePanel.plugins["Reputation"] then
                        targetPluginId = "Reputation"
                    elseif subFrame == "TokenFrame" and OnePanel.plugins and OnePanel.plugins["Tokens"] then
                        targetPluginId = "Tokens"
                    end
                end
                
                local plugin = OnePanel.plugins and OnePanel.plugins[targetPluginId]
                local globalEnable = (OnePanelDB and OnePanelDB.interceptNativeKeys)
                local pluginEnable = (plugin and plugin.interceptNativeToggle)
                
                -- Only react if explicitly requested by active plugin or global setting
                if plugin and (globalEnable or pluginEnable) then
                    if OnePanel.frame and OnePanel.frame:IsShown() and OnePanel.activePluginId == targetPluginId then
                        OnePanel:Hide()
                    else
                        OnePanel:Show()
                        if OnePanel.TabManager then
                            OnePanel.TabManager:SelectTab(targetPluginId)
                        end
                    end
                    
                    if CharacterFrame and CharacterFrame:IsShown() then
                        CharacterFrame:Hide()
                    end
                end
            end)
            
            if Utils and Utils.Logger then
                Utils.Logger:Log("MicroButtonHooks", "DEBUG", "Securely hooked toggle routine: " .. globalFuncName .. " -> " .. pluginId)
            end
        end
    end
    
    -- Suppress native CharacterFrame if OnePanel is active
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function(self)
            if OnePanel and OnePanel.frame and OnePanel.frame:IsShown() then
                self:Hide()
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- Initialization Listener
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OnePanel_MicroButtonHooks_EventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    MicroButtonHooks:Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

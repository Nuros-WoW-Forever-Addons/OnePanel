--[[
    OnePanel - MicroButtonHooks.lua
    Micro-button & keybind toggle intercepts for seamless native UI redirection.
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
-- Toggle Intercept Engine
-------------------------------------------------------------------------------

--- Install hooks on native Blizzard toggle routines
function MicroButtonHooks:Initialize()
    for globalFuncName, pluginId in pairs(ToggleMapping) do
        local origFunc = _G[globalFuncName]
        if type(origFunc) == "function" then
            _G[globalFuncName] = function(...)
                -- Check if plugin is registered with OnePanel
                if OnePanel.plugins and OnePanel.plugins[pluginId] then
                    if OnePanel.frame and OnePanel.frame:IsShown() and OnePanel.activePluginId == pluginId then
                        OnePanel:Hide()
                    else
                        OnePanel:Show()
                        if OnePanel.TabManager then
                            OnePanel.TabManager:SelectTab(pluginId)
                        end
                    end
                else
                    -- Fallback to native Blizzard UI execution
                    return origFunc(...)
                end
            end
            
            if Utils and Utils.Logger then
                Utils.Logger:Log("MicroButtonHooks", "DEBUG", "Hooked native toggle routine: " .. globalFuncName .. " -> " .. pluginId)
            end
        end
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

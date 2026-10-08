--[[
    OnePanel - HiResNudger.lua
    Interactive on-screen alignment and tuning panel for UIFrameHiRes metal border.
    Allows live pixel-level adjustments of all frame corners, edges, portrait, and close button,
    with an export dialog for easy copy/pasting.
--]]

local OnePanel = _G.OnePanel
local Utils = _G.OnePanelUtils

local defaultState = {
    -- Top-Left Corner (Portrait Ring)
    tlX = -14,
    tlY = 18,
    tlW = 118.5,
    tlH = 121.5,
    
    -- Top-Right Corner (Close Box)
    trX = 4,
    trY = 18,
    trW = 76.5,
    trH = 67.5,
    
    -- Bottom-Left Corner
    blX = -11,
    blY = -8,
    blW = 23,
    blH = 25,
    
    -- Bottom-Right Corner
    brX = 4,
    brY = -8,
    brW = 24,
    brH = 25,
    
    -- Top Edge
    teY = 3,
    teH = 9,
    
    -- Bottom Edge
    beY = 0,
    beH = 9,
    
    -- Left Edge
    leX = 12,
    leW = 9,
    
    -- Right Edge
    reX = 0,
    reW = 9,
    
    -- Portrait
    portraitX = 1,
    portraitY = -7,
    portraitSize = 60,
    
    -- Close Button
    closeX = -15,
    closeY = -15,
}

local nudgerState = {}
for k, v in pairs(defaultState) do nudgerState[k] = v end

local function ApplyState(frame, s)
    if not frame then
        frame = _G["OnePanelFrame"]
    end
    if not frame or not frame.HiResBorder then return end
    local b = frame.HiResBorder
    
    -- Top-Left Corner (Portrait Ring)
    if b.TopLeft then
        b.TopLeft:ClearAllPoints()
        b.TopLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", s.tlX, s.tlY)
        b.TopLeft:SetSize(s.tlW, s.tlH)
    end
    
    -- Top-Right Corner (Close Box)
    if b.TopRight then
        b.TopRight:ClearAllPoints()
        b.TopRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", s.trX, s.trY)
        b.TopRight:SetSize(s.trW, s.trH)
    end
    
    -- Bottom-Left Corner
    if b.BottomLeft then
        b.BottomLeft:ClearAllPoints()
        b.BottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", s.blX, s.blY)
        b.BottomLeft:SetSize(s.blW, s.blH)
    end
    
    -- Bottom-Right Corner
    if b.BottomRight then
        b.BottomRight:ClearAllPoints()
        b.BottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", s.brX, s.brY)
        b.BottomRight:SetSize(s.brW, s.brH)
    end
    
    -- Top Edge
    if b.TopEdge and b.TopLeft and b.TopRight then
        b.TopEdge:ClearAllPoints()
        b.TopEdge:SetPoint("TOPLEFT", b.TopLeft, "TOPRIGHT", -8, s.teY)
        b.TopEdge:SetPoint("TOPRIGHT", b.TopRight, "TOPLEFT", 8, s.teY)
        b.TopEdge:SetHeight(s.teH)
    end
    
    -- Bottom Edge
    if b.BottomEdge and b.BottomLeft and b.BottomRight then
        b.BottomEdge:ClearAllPoints()
        b.BottomEdge:SetPoint("BOTTOMLEFT", b.BottomLeft, "BOTTOMRIGHT", 0, s.beY)
        b.BottomEdge:SetPoint("BOTTOMRIGHT", b.BottomRight, "BOTTOMLEFT", 0, s.beY)
        b.BottomEdge:SetHeight(s.beH)
    end
    
    -- Left Edge
    if b.LeftEdge and b.TopLeft and b.BottomLeft then
        b.LeftEdge:ClearAllPoints()
        b.LeftEdge:SetPoint("TOPLEFT", b.TopLeft, "BOTTOMLEFT", s.leX, 0)
        b.LeftEdge:SetPoint("BOTTOMLEFT", b.BottomLeft, "TOPLEFT", 0, 0)
        b.LeftEdge:SetWidth(s.leW)
    end
    
    -- Right Edge
    if b.RightEdge and b.TopRight and b.BottomRight then
        b.RightEdge:ClearAllPoints()
        b.RightEdge:SetPoint("TOPRIGHT", b.TopRight, "BOTTOMRIGHT", s.reX, 0)
        b.RightEdge:SetPoint("BOTTOMRIGHT", b.BottomRight, "TOPRIGHT", 0, 0)
        b.RightEdge:SetWidth(s.reW)
    end
    
    -- Portrait Container
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", s.portraitX, s.portraitY)
        frame.PortraitContainer:SetSize(s.portraitSize, s.portraitSize)
        if frame.PortraitContainer.portrait then
            frame.PortraitContainer.portrait:ClearAllPoints()
            frame.PortraitContainer.portrait:SetAllPoints(frame.PortraitContainer)
            frame.PortraitContainer.portrait:Show()
        end
    elseif frame.portrait then
        frame.portrait:ClearAllPoints()
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", s.portraitX, s.portraitY)
        frame.portrait:SetSize(s.portraitSize, s.portraitSize)
        frame.portrait:Show()
    end
    
    -- Close Button
    if frame.CloseButton and b.TopRight then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", b.TopRight, "TOPRIGHT", s.closeX, s.closeY)
    end
end

local function GetFormattedCode(s)
    return string.format(
        "HiResOffsets = {\n" ..
        "    tlX = %d, tlY = %d, tlW = %.1f, tlH = %.1f,\n" ..
        "    trX = %d, trY = %d, trW = %.1f, trH = %.1f,\n" ..
        "    blX = %d, blY = %d, blW = %d, blH = %d,\n" ..
        "    brX = %d, brY = %d, brW = %d, brH = %d,\n" ..
        "    teY = %d, teH = %d,\n" ..
        "    beY = %d, beH = %d,\n" ..
        "    leX = %d, leW = %d,\n" ..
        "    reX = %d, reW = %d,\n" ..
        "    portraitX = %d, portraitY = %d, portraitSize = %d,\n" ..
        "    closeX = %d, closeY = %d,\n" ..
        "}",
        s.tlX, s.tlY, s.tlW, s.tlH,
        s.trX, s.trY, s.trW, s.trH,
        s.blX, s.blY, s.blW, s.blH,
        s.brX, s.brY, s.brW, s.brH,
        s.teY, s.teH,
        s.beY, s.beH,
        s.leX, s.leW,
        s.reX, s.reW,
        s.portraitX, s.portraitY, s.portraitSize,
        s.closeX, s.closeY
    )
end

local currentTarget = "TopLeft"

local TARGETS = {
    { id = "TopLeft",  label = "Portrait Ring", keys = { "tlX", "tlY", "tlW", "tlH" }, names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "TopRight", label = "Close Box",     keys = { "trX", "trY", "trW", "trH" }, names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "BotLeft",  label = "Bottom-Left",   keys = { "blX", "blY", "blW", "blH" }, names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "BotRight", label = "Bottom-Right",  keys = { "brX", "brY", "brW", "brH" }, names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "TopEdge",  label = "Top Edge",      keys = { "teY", "teH" },               names = { "Y Offset", "Height" } },
    { id = "BotEdge",  label = "Bottom Edge",   keys = { "beY", "beH" },               names = { "Y Offset", "Height" } },
    { id = "LeftEdge", label = "Left Edge",     keys = { "leX", "leW" },               names = { "X Offset", "Width" } },
    { id = "RightEdge",label = "Right Edge",    keys = { "reX", "reW" },               names = { "X Offset", "Width" } },
    { id = "Portrait", label = "Portrait Icon", keys = { "portraitX", "portraitY", "portraitSize" }, names = { "X Offset", "Y Offset", "Size" } },
    { id = "CloseBtn", label = "Close Button",  keys = { "closeX", "closeY" },          names = { "X Offset", "Y Offset" } },
}

local function CreateNudgerFrame()
    if _G["OnePanel_HiResNudgerFrame"] then return _G["OnePanel_HiResNudgerFrame"] end
    
    local nudger = CreateFrame("Frame", "OnePanel_HiResNudgerFrame", UIParent, "DialogBoxFrame")
    nudger:SetSize(460, 520)
    nudger:SetPoint("CENTER", UIParent, "CENTER", 340, 20)
    nudger:SetFrameStrata("TOOLTIP")
    nudger:SetMovable(true)
    nudger:EnableMouse(true)
    nudger:RegisterForDrag("LeftButton")
    nudger:SetScript("OnDragStart", nudger.StartMoving)
    nudger:SetScript("OnDragStop", nudger.StopMovingOrSizing)
    
    local title = nudger:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", nudger, "TOP", 0, -12)
    title:SetText("HiRes Frame Nudger (/opnudge)")
    
    -- Target selector buttons (2 rows of 5 buttons)
    local targetButtons = {}
    local btnW, btnH = 82, 22
    for idx, t in ipairs(TARGETS) do
        local btn = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
        btn:SetSize(btnW, btnH)
        local row = math.floor((idx - 1) / 5)
        local col = (idx - 1) % 5
        btn:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18 + col * (btnW + 4), -40 - row * (btnH + 4))
        btn:SetText(t.label)
        btn:SetScript("OnClick", function()
            currentTarget = t.id
            nudger:RefreshControls()
        end)
        targetButtons[t.id] = btn
    end
    
    -- Rows container
    local rows = {}
    local rowY = -104
    for i = 1, 4 do
        local rowFrame = CreateFrame("Frame", nil, nudger)
        rowFrame:SetSize(424, 26)
        rowFrame:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18, rowY)
        
        local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        lbl:SetWidth(110)
        lbl:SetJustifyH("LEFT")
        rowFrame.Label = lbl
        
        local btnM10 = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        btnM10:SetSize(40, 22)
        btnM10:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        btnM10:SetText("-10")
        rowFrame.BtnM10 = btnM10
        
        local btnM1 = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        btnM1:SetSize(36, 22)
        btnM1:SetPoint("LEFT", btnM10, "RIGHT", 2, 0)
        btnM1:SetText("-1")
        rowFrame.BtnM1 = btnM1
        
        local btnP1 = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        btnP1:SetSize(36, 22)
        btnP1:SetPoint("LEFT", btnM1, "RIGHT", 2, 0)
        btnP1:SetText("+1")
        rowFrame.BtnP1 = btnP1
        
        local btnP10 = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        btnP10:SetSize(40, 22)
        btnP10:SetPoint("LEFT", btnP1, "RIGHT", 2, 0)
        btnP10:SetText("+10")
        rowFrame.BtnP10 = btnP10
        
        local valText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valText:SetPoint("LEFT", btnP10, "RIGHT", 10, 0)
        rowFrame.ValText = valText
        
        rows[i] = rowFrame
        rowY = rowY - 30
    end
    
    -- Code export scroll & edit box
    local exportBox = CreateFrame("EditBox", "OnePanel_HiResExportBox", nudger)
    exportBox:SetMultiLine(true)
    exportBox:SetFontObject("GameFontHighlightSmall")
    exportBox:SetWidth(410)
    exportBox:SetAutoFocus(false)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    local exportScroll = CreateFrame("ScrollFrame", nil, nudger, "UIPanelScrollFrameTemplate")
    exportScroll:SetSize(410, 150)
    exportScroll:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18, -235)
    exportScroll:SetScrollChild(exportBox)
    
    -- Action buttons at bottom
    local btnCopy = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnCopy:SetSize(130, 24)
    btnCopy:SetPoint("BOTTOMLEFT", nudger, "BOTTOMLEFT", 18, 16)
    btnCopy:SetText("Select All Code")
    btnCopy:SetScript("OnClick", function()
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)
    
    local btnReset = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnReset:SetSize(110, 24)
    btnReset:SetPoint("LEFT", btnCopy, "RIGHT", 6, 0)
    btnReset:SetText("Reset Defaults")
    btnReset:SetScript("OnClick", function()
        for k, v in pairs(defaultState) do nudgerState[k] = v end
        nudger:RefreshControls()
    end)
    
    local btnClose = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnClose:SetSize(90, 24)
    btnClose:SetPoint("BOTTOMRIGHT", nudger, "BOTTOMRIGHT", -18, 16)
    btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function() nudger:Hide() end)
    
    function nudger:RefreshControls()
        -- Highlight active target button
        for tid, btn in pairs(targetButtons) do
            if tid == currentTarget then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
        
        -- Find target definition
        local targetDef = nil
        for _, t in ipairs(TARGETS) do
            if t.id == currentTarget then targetDef = t; break end
        end
        if not targetDef then return end
        
        for i = 1, 4 do
            local row = rows[i]
            local key = targetDef.keys[i]
            local name = targetDef.names[i]
            if key then
                row:Show()
                row.Label:SetText(name)
                row.ValText:SetText(string.format("%.1f", nudgerState[key]))
                
                local function onStep(delta)
                    nudgerState[key] = nudgerState[key] + delta
                    row.ValText:SetText(string.format("%.1f", nudgerState[key]))
                    ApplyState(_G["OnePanelFrame"], nudgerState)
                    exportBox:SetText(GetFormattedCode(nudgerState))
                end
                
                row.BtnM10:SetScript("OnClick", function() onStep(-10) end)
                row.BtnM1:SetScript("OnClick", function() onStep(-1) end)
                row.BtnP1:SetScript("OnClick", function() onStep(1) end)
                row.BtnP10:SetScript("OnClick", function() onStep(10) end)
            else
                row:Hide()
            end
        end
        
        ApplyState(_G["OnePanelFrame"], nudgerState)
        exportBox:SetText(GetFormattedCode(nudgerState))
    end
    
    nudger:SetScript("OnShow", function()
        nudger:RefreshControls()
    end)
    
    nudger:RefreshControls()
    return nudger
end

SLASH_OPNUDGE1 = "/opnudge"
SLASH_OPNUDGE2 = "/opalign"
SLASH_OPNUDGE3 = "/opborder"
SlashCmdList["OPNUDGE"] = function()
    local f = CreateNudgerFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

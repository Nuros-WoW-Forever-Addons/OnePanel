--[[
    OnePanel - HiResNudger.lua
    Interactive on-screen alignment and tuning panel for UIFrameMetal / UIFrameHiRes borders.
    Allows live pixel-level adjustments of all frame corners, edges, crops (UVs), portrait, and close button,
    with an export dialog for copying tuned Lua tables directly to the clipboard.
--]]

local OnePanel = _G.OnePanel
local Utils = _G.OnePanelUtils

-- Theme presets
local THEME_PRESETS = {
    ["Metal"] = {
        name        = "Metal (1x Standard)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameMetal",
        horizFile   = "Interface\\FrameGeneral\\UIFrameMetalHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameMetalVertical",
        
        -- TopLeft (Portrait Ring)
        tlL = 136, tlR = 267, tlT = 136, tlB = 267,
        tlW = 132.0, tlH = 132.0, tlX = -13, tlY = 14,
        
        -- TopRight (Close Box)
        trL = 0, trR = 131, trT = 148, trB = 267,
        trW = 132.0, trH = 120.0, trX = 0, trY = 2,
        
        -- BottomLeft Corner
        blL = 10, blR = 50, blT = 80, blB = 132,
        blW = 40, blH = 52, blX = -5, blY = -4,
        
        -- BottomRight Corner
        brL = 220, brR = 266, brT = 80, brB = 132,
        brW = 46, brH = 52, brX = 1, brY = -4,
        
        -- TopEdge
        teT = 124, teB = 133,
        teH = 10, teY = -13, teLeftX = 0, teRightX = 0,
        
        -- Header Divider (Bottom of double top header)
        hdT = 149, hdB = 157,
        hdH = 8, hdY = -32, hdLeftX = 0, hdRightX = 0,
        
        -- Vertical Divider (between main panel and side panel)
        vdL = 258, vdR = 265,
        vdW = 7, vdX = 1, vdTopY = 11, vdBotY = -9,
        
        -- BottomEdge
        beT = 167, beB = 178,
        beH = 10, beY = -1, beLeftX = 0, beRightX = 0,
        
        -- LeftEdge
        leL = 11, leR = 18,
        leW = 7, leX = 9, leTopY = 0, leBotY = 0,
        
        -- RightEdge
        reL = 258, reR = 265,
        reW = 7, reX = 0, reTopY = 0, reBotY = 0,
        
        -- Portrait Center & Size
        portraitX = -7, portraitY = 7, portraitSize = 60,
        
        -- Close Button Center
        closeX = -13.5, closeY = -14.5,
        
        -- Title Centering
        titleX = 0, titleY = -13,
        
        -- Background Insets (contained within metal borders)
        bgLeft = 0, bgRight = -3, bgTop = -3, bgBottom = 0,
    },
    ["HiRes"] = {
        name        = "HiRes (2x Scaled)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameHiRes",
        horizFile   = "Interface\\FrameGeneral\\UIFrameHiResHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameHiResVertical",
        
        -- TopLeft (Portrait Ring)
        tlL = 0, tlR = 237, tlT = 0, tlB = 243,
        tlW = 118.5, tlH = 121.5, tlX = -14, tlY = 18,
        
        -- TopRight (Close Box)
        trL = 237, trR = 390, trT = 4, trB = 139,
        trW = 76.5, trH = 67.5, trX = 4, trY = 18,
        
        -- BottomLeft Corner
        blL = 446, blR = 492, blT = 0, blB = 50,
        blW = 23, blH = 25, blX = -11, blY = -8,
        
        -- BottomRight Corner
        brL = 394, brR = 442, brT = 0, brB = 50,
        brW = 24, brH = 25, brX = 4, brY = -8,
        
        -- TopEdge
        teT = 0, teB = 18,
        teH = 9, teY = 3, teLeftX = -8, teRightX = 8,
        
        -- Header Divider (Bottom of double top header)
        hdT = 58, hdB = 70,
        hdH = 12, hdY = -23, hdLeftX = -8, hdRightX = 8,
        
        -- Vertical Divider (between main panel and side panel)
        vdL = 19, vdR = 37,
        vdW = 9, vdX = 1, vdTopY = 10, vdBotY = -14,
        
        -- BottomEdge
        beT = 71, beB = 89,
        beH = 9, beY = 0, beLeftX = 0, beRightX = 0,
        
        -- LeftEdge
        leL = 0, leR = 18,
        leW = 9, leX = 12, leTopY = 0, leBotY = 0,
        
        -- RightEdge
        reL = 19, reR = 37,
        reW = 9, reX = 0, reTopY = 0, reBotY = 0,
        
        -- Portrait
        portraitX = 1, portraitY = -7, portraitSize = 60,
        
        -- Close Button
        closeX = -15, closeY = -15,
        
        -- Title Centering
        titleX = 0, titleY = -14,
        
        -- Background Insets
        bgLeft = 0, bgRight = -3, bgTop = -3, bgBottom = 0,
    }
}

local activeTheme = "Metal"
local activeMode = "Geometry" -- "Geometry" or "TexCoords"
local currentTarget = "TopLeft"

-- Working state per theme
local states = {}
for themeKey, preset in pairs(THEME_PRESETS) do
    states[themeKey] = {}
    for k, v in pairs(preset) do
        states[themeKey][k] = v
    end
end

local function CloneTable(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function ApplyState(frame, s)
    if not frame then
        frame = _G["OnePanelFrame"]
    end
    if not frame then return end
    
    -- Ensure HiResBorder exists with active theme files
    if not frame.HiResBorder then
        if Utils and Utils.FrameHelper then
            Utils.FrameHelper:ApplyHiResFrame(frame, { theme = activeTheme })
        end
    end
    
    local b = frame.HiResBorder
    if not b then return end
    
    -- Ensure HeaderDivider exists on border frame
    if not b.HeaderDivider then
        local hd = b:CreateTexture(nil, "OVERLAY", nil, 1)
        hd:SetHorizTile(true)
        b.HeaderDivider = hd
    end
    
    if frame.Bg then
        frame.Bg:ClearAllPoints()
        frame.Bg:SetPoint("TOPLEFT", frame, "TOPLEFT", s.bgLeft or 0, s.bgTop or -3)
        frame.Bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", s.bgRight or -3, s.bgBottom or 0)
        frame.Bg:SetHorizTile(false)
        frame.Bg:SetVertTile(false)
        frame.Bg:SetTexCoord(0, 1, 0, 1)
        frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
        frame.Bg:SetVertexColor(0.2, 0.2, 0.2, 1.0)
        frame.Bg:Show()
    end
    if b.TitleBg then
        b.TitleBg:Hide()
    end
    
    -- Update textures for theme
    local preset = THEME_PRESETS[activeTheme]
    if preset then
        if b.TopLeft then b.TopLeft:SetTexture(preset.cornersFile) end
        if b.TopRight then b.TopRight:SetTexture(preset.cornersFile) end
        if b.BottomLeft then b.BottomLeft:SetTexture(preset.cornersFile) end
        if b.BottomRight then b.BottomRight:SetTexture(preset.cornersFile) end
        if b.TopEdge then b.TopEdge:SetTexture(preset.horizFile) end
        if b.HeaderDivider then b.HeaderDivider:SetTexture(preset.horizFile) end
        if b.BottomEdge then b.BottomEdge:SetTexture(preset.horizFile) end
        if b.LeftEdge then b.LeftEdge:SetTexture(preset.vertFile) end
        if b.RightEdge then b.RightEdge:SetTexture(preset.vertFile) end
    end
    
    local cWDim = 512
    local cHDim = (activeTheme == "HiRes") and 256 or 512
    local hDim = (activeTheme == "HiRes") and 128 or 512
    local vDim = (activeTheme == "HiRes") and 64 or 512
    
    -- Ensure border is at frame level + 10
    b:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    -- 1. Top-Left Corner (Portrait Ring)
    if b.TopLeft then
        b.TopLeft:SetTexCoord((s.tlL or 0)/cWDim, (s.tlR or 0)/cWDim, (s.tlT or 0)/cHDim, (s.tlB or 0)/cHDim)
        b.TopLeft:ClearAllPoints()
        b.TopLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", s.tlX or 0, s.tlY or 0)
        b.TopLeft:SetSize(s.tlW or 100, s.tlH or 100)
    end
    
    -- 2. Top-Right Corner (Close Box)
    if b.TopRight then
        b.TopRight:SetTexCoord((s.trL or 0)/cWDim, (s.trR or 0)/cWDim, (s.trT or 0)/cHDim, (s.trB or 0)/cHDim)
        b.TopRight:ClearAllPoints()
        b.TopRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", s.trX or 0, s.trY or 0)
        b.TopRight:SetSize(s.trW or 100, s.trH or 100)
    end
    
    -- 3. Bottom-Left Corner
    if b.BottomLeft then
        b.BottomLeft:SetTexCoord((s.blL or 0)/cWDim, (s.blR or 0)/cWDim, (s.blT or 0)/cHDim, (s.blB or 0)/cHDim)
        b.BottomLeft:ClearAllPoints()
        b.BottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", s.blX or 0, s.blY or 0)
        b.BottomLeft:SetSize(s.blW or 20, s.blH or 20)
    end
    
    -- 4. Bottom-Right Corner
    if b.BottomRight then
        b.BottomRight:SetTexCoord((s.brL or 0)/cWDim, (s.brR or 0)/cWDim, (s.brT or 0)/cHDim, (s.brB or 0)/cHDim)
        b.BottomRight:ClearAllPoints()
        b.BottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", s.brX or 0, s.brY or 0)
        b.BottomRight:SetSize(s.brW or 20, s.brH or 20)
    end
    
    -- 5. Top Edge
    if b.TopEdge and b.TopLeft and b.TopRight then
        b.TopEdge:SetTexCoord(0, 1, (s.teT or 0)/hDim, (s.teB or 0)/hDim)
        b.TopEdge:ClearAllPoints()
        b.TopEdge:SetPoint("TOPLEFT", b.TopLeft, "TOPRIGHT", s.teLeftX or 0, s.teY or 0)
        b.TopEdge:SetPoint("TOPRIGHT", b.TopRight, "TOPLEFT", s.teRightX or 0, s.teY or 0)
        b.TopEdge:SetHeight(s.teH or 10)
    end
    
    -- 6. Header Divider (Bottom bar of double top header)
    if b.HeaderDivider and b.TopLeft and b.TopRight then
        b.HeaderDivider:SetTexCoord(0, 1, (s.hdT or 0)/hDim, (s.hdB or 0)/hDim)
        b.HeaderDivider:ClearAllPoints()
        b.HeaderDivider:SetPoint("TOPLEFT", b.TopLeft, "TOPRIGHT", s.hdLeftX or 0, s.hdY or -32)
        b.HeaderDivider:SetPoint("TOPRIGHT", b.TopRight, "TOPLEFT", s.hdRightX or 0, s.hdY or -32)
        b.HeaderDivider:SetHeight(s.hdH or 9)
    end
    
    -- 6b. Hide TitleBg if present (master frame.Bg seamlessly covers title bar and main panel)
    if b.TitleBg then
        b.TitleBg:Hide()
    end
    
    -- 7. Bottom Edge
    if b.BottomEdge and b.BottomLeft and b.BottomRight then
        b.BottomEdge:SetTexCoord(0, 1, (s.beT or 0)/hDim, (s.beB or 0)/hDim)
        b.BottomEdge:ClearAllPoints()
        b.BottomEdge:SetPoint("BOTTOMLEFT", b.BottomLeft, "BOTTOMRIGHT", s.beLeftX or 0, s.beY or 0)
        b.BottomEdge:SetPoint("BOTTOMRIGHT", b.BottomRight, "BOTTOMLEFT", s.beRightX or 0, s.beY or 0)
        b.BottomEdge:SetHeight(s.beH or 10)
    end
    
    -- 8. Left Edge
    if b.LeftEdge and b.TopLeft and b.BottomLeft then
        b.LeftEdge:SetTexCoord((s.leL or 0)/vDim, (s.leR or 0)/vDim, 0, 1)
        b.LeftEdge:ClearAllPoints()
        b.LeftEdge:SetPoint("TOPLEFT", b.TopLeft, "BOTTOMLEFT", s.leX or 0, s.leTopY or 0)
        b.LeftEdge:SetPoint("BOTTOMLEFT", b.BottomLeft, "TOPLEFT", 0, s.leBotY or 0)
        b.LeftEdge:SetWidth(s.leW or 10)
    end
    
    -- 9. Right Edge
    if b.RightEdge and b.TopRight and b.BottomRight then
        b.RightEdge:SetTexCoord((s.reL or 0)/vDim, (s.reR or 0)/vDim, 0, 1)
        b.RightEdge:ClearAllPoints()
        b.RightEdge:SetPoint("TOPRIGHT", b.TopRight, "BOTTOMRIGHT", s.reX or 0, s.reTopY or 0)
        b.RightEdge:SetPoint("BOTTOMRIGHT", b.BottomRight, "TOPRIGHT", 0, s.reBotY or 0)
        b.RightEdge:SetWidth(s.reW or 10)
    end
    
    -- 10. Portrait Container
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", s.portraitX or 0, s.portraitY or 0)
        frame.PortraitContainer:SetSize(s.portraitSize or 60, s.portraitSize or 60)
        frame.PortraitContainer:SetFrameLevel(b:GetFrameLevel() + 1)
        if frame.PortraitContainer.portrait then
            frame.PortraitContainer.portrait:ClearAllPoints()
            frame.PortraitContainer.portrait:SetAllPoints(frame.PortraitContainer)
            frame.PortraitContainer.portrait:Show()
        end
    elseif frame.portrait then
        frame.portrait:ClearAllPoints()
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", s.portraitX or 0, s.portraitY or 0)
        frame.portrait:SetSize(s.portraitSize or 60, s.portraitSize or 60)
        frame.portrait:Show()
    end
    
    -- 11. Close Button
    if frame.CloseButton and b.TopRight then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", b.TopRight, "TOPRIGHT", s.closeX or -14, s.closeY or -14)
        frame.CloseButton:SetFrameLevel(b:GetFrameLevel() + 5)
    end
    
    -- 12. Vertical Divider (between main panel and side panel)
    local vDivider = _G["OnePanel_CharacterVerticalDivider"] or (frame and frame.CharacterVerticalDivider)
    local leftArea = _G["OnePanel_CharacterLeftArea"]
    if vDivider and leftArea then
        vDivider:SetTexture(preset.vertFile)
        vDivider:SetTexCoord((s.vdL or 258)/vDim, (s.vdR or 265)/vDim, 0, 1)
        vDivider:SetWidth(s.vdW or 7)
        vDivider:ClearAllPoints()
        vDivider:SetPoint("TOP", leftArea, "TOPRIGHT", s.vdX or 1, s.vdTopY or 11)
        vDivider:SetPoint("BOTTOM", leftArea, "BOTTOMRIGHT", s.vdX or 1, s.vdBotY or -9)
    end
    
    -- 13. Title Text Centering
    local titleTarget = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText or frame.Title
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("CENTER", frame, "TOP", s.titleX or 0, s.titleY or -13)
        frame.TitleContainer:SetSize(400, 24)
        frame.TitleContainer:SetFrameLevel(b:GetFrameLevel() + 2)
        frame.TitleContainer:Show()
    end
    if titleTarget then
        titleTarget:ClearAllPoints()
        if frame.TitleContainer and titleTarget:GetParent() == frame.TitleContainer then
            titleTarget:SetPoint("CENTER", frame.TitleContainer, "CENTER", 0, 0)
        else
            titleTarget:SetPoint("CENTER", frame, "TOP", s.titleX or 0, s.titleY or -13)
        end
        titleTarget:SetDrawLayer("OVERLAY", 3)
        if titleTarget.SetJustifyH then titleTarget:SetJustifyH("CENTER") end
        if titleTarget.SetJustifyV then titleTarget:SetJustifyV("MIDDLE") end
        titleTarget:Show()
    end
end

local function GetFormattedCode(theme, s)
    local cWDim = 512
    local cHDim = (theme == "HiRes") and 256 or 512
    local hDim = (theme == "HiRes") and 128 or 512
    local vDim = (theme == "HiRes") and 64 or 512
    
    return string.format(
        '["%s"] = {\n' ..
        '    name        = "%s",\n' ..
        '    cornersFile = "%s",\n' ..
        '    horizFile   = "%s",\n' ..
        '    vertFile    = "%s",\n\n' ..
        '    -- TopLeft (Portrait Ring)\n' ..
        '    tlCoords = { %d/%d, %d/%d, %d/%d, %d/%d },\n' ..
        '    tlW = %.1f, tlH = %.1f, tlX = %d, tlY = %d,\n\n' ..
        '    -- TopRight (Close Box)\n' ..
        '    trCoords = { %d/%d, %d/%d, %d/%d, %d/%d },\n' ..
        '    trW = %.1f, trH = %.1f, trX = %d, trY = %d,\n\n' ..
        '    -- BottomLeft\n' ..
        '    blCoords = { %d/%d, %d/%d, %d/%d, %d/%d },\n' ..
        '    blW = %d, blH = %d, blX = %d, blY = %d,\n\n' ..
        '    -- BottomRight\n' ..
        '    brCoords = { %d/%d, %d/%d, %d/%d, %d/%d },\n' ..
        '    brW = %d, brH = %d, brX = %d, brY = %d,\n\n' ..
        '    -- TopEdge\n' ..
        '    teCoords = { 0, 1, %d/%d, %d/%d },\n' ..
        '    teH = %d, teY = %d, teLeftX = %d, teRightX = %d,\n\n' ..
        '    -- Header Divider (Bottom of double top header)\n' ..
        '    hdCoords = { 0, 1, %d/%d, %d/%d },\n' ..
        '    hdH = %d, hdY = %d, hdLeftX = %d, hdRightX = %d,\n\n' ..
        '    -- Vertical Divider (between main panel and side panel)\n' ..
        '    vdCoords = { %d/%d, %d/%d, 0, 1 },\n' ..
        '    vdW = %d, vdX = %d, vdTopY = %d, vdBotY = %d,\n\n' ..
        '    -- BottomEdge\n' ..
        '    beCoords = { 0, 1, %d/%d, %d/%d },\n' ..
        '    beH = %d, beY = %d, beLeftX = %d, beRightX = %d,\n\n' ..
        '    -- LeftEdge\n' ..
        '    leCoords = { %d/%d, %d/%d, 0, 1 },\n' ..
        '    leW = %d, leX = %d, leTopY = %d, leBotY = %d,\n\n' ..
        '    -- RightEdge\n' ..
        '    reCoords = { %d/%d, %d/%d, 0, 1 },\n' ..
        '    reW = %d, reX = %d, reTopY = %d, reBotY = %d,\n\n' ..
        '    -- Portrait Center & Size\n' ..
        '    portraitX = %d, portraitY = %d, portraitSize = %d,\n\n' ..
        '    -- Close Button Center\n' ..
        '    closeX = %.1f, closeY = %.1f,\n\n' ..
        '    -- Title Position\n' ..
        '    titleX = %d, titleY = %d,\n\n' ..
        '    -- Background Insets (contained within metal borders)\n' ..
        '    bgLeft = %d, bgRight = %d, bgTop = %d, bgBottom = %d,\n' ..
        '}',
        theme, s.name or theme, s.cornersFile or "", s.horizFile or "", s.vertFile or "",
        s.tlL or 0, cWDim, s.tlR or 0, cWDim, s.tlT or 0, cHDim, s.tlB or 0, cHDim, s.tlW or 0, s.tlH or 0, s.tlX or 0, s.tlY or 0,
        s.trL or 0, cWDim, s.trR or 0, cWDim, s.trT or 0, cHDim, s.trB or 0, cHDim, s.trW or 0, s.trH or 0, s.trX or 0, s.trY or 0,
        s.blL or 0, cWDim, s.blR or 0, cWDim, s.blT or 0, cHDim, s.blB or 0, cHDim, s.blW or 0, s.blH or 0, s.blX or 0, s.blY or 0,
        s.brL or 0, cWDim, s.brR or 0, cWDim, s.brT or 0, cHDim, s.brB or 0, cHDim, s.brW or 0, s.brH or 0, s.brX or 0, s.brY or 0,
        s.teT or 0, hDim, s.teB or 0, hDim, s.teH or 0, s.teY or 0, s.teLeftX or 0, s.teRightX or 0,
        s.hdT or 0, hDim, s.hdB or 0, hDim, s.hdH or 0, s.hdY or 0, s.hdLeftX or 0, s.hdRightX or 0,
        s.vdL or 258, vDim, s.vdR or 265, vDim, s.vdW or 7, s.vdX or 1, s.vdTopY or 11, s.vdBotY or -9,
        s.beT or 0, hDim, s.beB or 0, hDim, s.beH or 0, s.beY or 0, s.beLeftX or 0, s.beRightX or 0,
        s.leL or 0, vDim, s.leR or 0, vDim, s.leW or 0, s.leX or 0, s.leTopY or 0, s.leBotY or 0,
        s.reL or 0, vDim, s.reR or 0, vDim, s.reW or 0, s.reX or 0, s.reTopY or 0, s.reBotY or 0,
        s.portraitX or 0, s.portraitY or 0, s.portraitSize or 0,
        s.closeX or 0, s.closeY or 0,
        s.titleX or 0, s.titleY or (theme == "HiRes" and -14 or -13),
        s.bgLeft or 0, s.bgRight or -3, s.bgTop or -3, s.bgBottom or 0
    )
end

-- TARGET DEFINITIONS FOR GEOMETRY MODE
local GEOM_TARGETS = {
    { id = "TopLeft",    label = "Portrait Ring", keys = { "tlX", "tlY", "tlW", "tlH" },             names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "TopRight",   label = "Close Box",     keys = { "trX", "trY", "trW", "trH" },             names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "BotLeft",    label = "Bottom-Left",   keys = { "blX", "blY", "blW", "blH" },             names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "BotRight",   label = "Bottom-Right",  keys = { "brX", "brY", "brW", "brH" },             names = { "X Offset", "Y Offset", "Width", "Height" } },
    { id = "TopEdge",    label = "Top Edge",      keys = { "teY", "teH", "teLeftX", "teRightX" },   names = { "Y Offset", "Height", "Left X", "Right X" } },
    { id = "HeaderDiv",  label = "Header Div",    keys = { "hdY", "hdH", "hdLeftX", "hdRightX" },   names = { "Y Offset", "Height", "Left X", "Right X" } },
    { id = "VertDiv",    label = "Vert Divider",  keys = { "vdX", "vdW", "vdTopY", "vdBotY" },     names = { "X Offset", "Width", "Top Y", "Bottom Y" } },
    { id = "BotEdge",    label = "Bottom Edge",   keys = { "beY", "beH", "beLeftX", "beRightX" },   names = { "Y Offset", "Height", "Left X", "Right X" } },
    { id = "LeftEdge",   label = "Left Edge",     keys = { "leX", "leW", "leTopY", "leBotY" },     names = { "X Offset", "Width", "Top Y", "Bottom Y" } },
    { id = "RightEdge",  label = "Right Edge",    keys = { "reX", "reW", "reTopY", "reBotY" },     names = { "X Offset", "Width", "Top Y", "Bottom Y" } },
    { id = "Portrait",   label = "Portrait",      keys = { "portraitX", "portraitY", "portraitSize" }, names = { "X Offset", "Y Offset", "Icon Size" } },
    { id = "CloseBtn",   label = "Close Button",  keys = { "closeX", "closeY" },                      names = { "X Offset", "Y Offset" } },
    { id = "Title",      label = "Title Text",    keys = { "titleX", "titleY" },                      names = { "X Offset", "Y Offset" } },
    { id = "Background", label = "Background",    keys = { "bgLeft", "bgRight", "bgTop", "bgBottom" }, names = { "Left Inset", "Right Inset", "Top Inset", "Bottom Inset" } },
}

-- TARGET DEFINITIONS FOR TEXCOORD (UV CROP) MODE
local UV_TARGETS = {
    { id = "TopLeft",   label = "TL UV",         keys = { "tlL", "tlR", "tlT", "tlB" }, names = { "Left (px)", "Right (px)", "Top (px)", "Bottom (px)" } },
    { id = "TopRight",  label = "TR UV",         keys = { "trL", "trR", "trT", "trB" }, names = { "Left (px)", "Right (px)", "Top (px)", "Bottom (px)" } },
    { id = "BotLeft",   label = "BL UV",         keys = { "blL", "blR", "blT", "blB" }, names = { "Left (px)", "Right (px)", "Top (px)", "Bottom (px)" } },
    { id = "BotRight",  label = "BR UV",         keys = { "brL", "brR", "brT", "brB" }, names = { "Left (px)", "Right (px)", "Top (px)", "Bottom (px)" } },
    { id = "TopEdge",   label = "Top Edge UV",   keys = { "teT", "teB" },               names = { "Top (px)", "Bottom (px)" } },
    { id = "HeaderDiv", label = "Header Div UV", keys = { "hdT", "hdB" },               names = { "Top (px)", "Bottom (px)" } },
    { id = "VertDiv",   label = "Vert Div UV",   keys = { "vdL", "vdR" },               names = { "Left (px)", "Right (px)" } },
    { id = "BotEdge",   label = "Bot Edge UV",   keys = { "beT", "beB" },               names = { "Top (px)", "Bottom (px)" } },
    { id = "LeftEdge",  label = "Left Edge UV",  keys = { "leL", "leR" },               names = { "Left (px)", "Right (px)" } },
    { id = "RightEdge", label = "Right Edge UV", keys = { "reL", "reR" },               names = { "Left (px)", "Right (px)" } },
}

local function CreateNudgerFrame()
    if _G["OnePanel_HiResNudgerFrame"] then return _G["OnePanel_HiResNudgerFrame"] end
    
    local nudger = CreateFrame("Frame", "OnePanel_HiResNudgerFrame", UIParent, "DialogBoxFrame")
    nudger:SetSize(490, 580)
    nudger:SetPoint("CENTER", UIParent, "CENTER", 340, 20)
    nudger:SetFrameStrata("TOOLTIP")
    nudger:SetMovable(true)
    nudger:SetClampedToScreen(true)
    nudger:EnableMouse(true)
    nudger:RegisterForDrag("LeftButton")
    nudger:SetScript("OnDragStart", nudger.StartMoving)
    nudger:SetScript("OnDragStop", nudger.StopMovingOrSizing)
    
    -- Suppress Blizzard's default DialogBoxFrame Okay button
    local okayBtn = _G[nudger:GetName() .. "Okay"] or nudger.Okay
    if okayBtn then okayBtn:Hide() end
    
    -- Title
    local title = nudger:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", nudger, "TOP", 0, -12)
    title:SetText("OnePanel Metal Border Nudger")
    
    -- Theme Switcher Button
    local btnTheme = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnTheme:SetSize(220, 22)
    btnTheme:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18, -36)
    
    local function UpdateThemeButtonText()
        btnTheme:SetText("Theme: " .. activeTheme .. " (Click to toggle)")
    end
    UpdateThemeButtonText()
    
    btnTheme:SetScript("OnClick", function()
        if activeTheme == "Metal" then
            activeTheme = "HiRes"
        else
            activeTheme = "Metal"
        end
        UpdateThemeButtonText()
        if Utils and Utils.FrameHelper then
            Utils.FrameHelper:ApplyHiResFrame(_G["OnePanelFrame"], { theme = activeTheme })
        end
        nudger:RefreshControls()
    end)
    
    -- Mode Switcher (Geometry vs TexCoords)
    local btnModeGeom = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnModeGeom:SetSize(110, 22)
    btnModeGeom:SetPoint("TOPRIGHT", nudger, "TOPRIGHT", -134, -36)
    btnModeGeom:SetText("Geometry")
    
    local btnModeUV = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnModeUV:SetSize(110, 22)
    btnModeUV:SetPoint("LEFT", btnModeGeom, "RIGHT", 4, 0)
    btnModeUV:SetText("TexCoords (UV)")
    
    btnModeGeom:SetScript("OnClick", function()
        activeMode = "Geometry"
        nudger:RefreshTargetButtons()
        nudger:RefreshControls()
    end)
    btnModeUV:SetScript("OnClick", function()
        activeMode = "TexCoords"
        nudger:RefreshTargetButtons()
        nudger:RefreshControls()
    end)
    
    -- Target selector buttons container (4 columns x 3 rows = up to 12 buttons)
    local targetButtonContainer = CreateFrame("Frame", nil, nudger)
    targetButtonContainer:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18, -64)
    targetButtonContainer:SetSize(454, 76)
    
    local targetButtons = {}
    
    function nudger:RefreshTargetButtons()
        -- Clear old buttons
        for _, btn in pairs(targetButtons) do
            btn:Hide()
        end
        wipe(targetButtons)
        
        local targets = (activeMode == "Geometry") and GEOM_TARGETS or UV_TARGETS
        local cols = 5
        local btnW = 86
        local btnH = 22
        local gapX = 5
        local gapY = 4
        
        -- Check if currentTarget is valid in this mode
        local found = false
        for _, t in ipairs(targets) do
            if t.id == currentTarget then found = true; break end
        end
        if not found then
            currentTarget = targets[1].id
        end
        
        for idx, t in ipairs(targets) do
            local btn = CreateFrame("Button", nil, targetButtonContainer, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            local fs = btn:GetFontString()
            if fs then fs:SetFontObject("GameFontNormalSmall") end
            local row = math.floor((idx - 1) / cols)
            local col = (idx - 1) % cols
            btn:SetPoint("TOPLEFT", targetButtonContainer, "TOPLEFT", col * (btnW + gapX), -row * (btnH + gapY))
            btn:SetText(t.label)
            btn:SetScript("OnClick", function()
                currentTarget = t.id
                nudger:RefreshControls()
            end)
            targetButtons[t.id] = btn
        end
        
        if activeMode == "Geometry" then
            btnModeGeom:LockHighlight()
            btnModeUV:UnlockHighlight()
        else
            btnModeGeom:UnlockHighlight()
            btnModeUV:LockHighlight()
        end
    end
    
    -- 4 Adjustment Rows (Moved down to -148 to clear 3 rows of target buttons)
    local rows = {}
    local rowY = -148
    for i = 1, 4 do
        local rowFrame = CreateFrame("Frame", nil, nudger)
        rowFrame:SetSize(454, 26)
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
        rowY = rowY - 28
    end
    
    -- Code Export EditBox
    local exportBox = CreateFrame("EditBox", "OnePanel_HiResExportBox", nudger)
    exportBox:SetMultiLine(true)
    exportBox:SetFontObject("GameFontHighlightSmall")
    exportBox:SetWidth(434)
    exportBox:SetAutoFocus(false)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    local exportScroll = CreateFrame("ScrollFrame", nil, nudger, "UIPanelScrollFrameTemplate")
    exportScroll:SetSize(434, 196)
    exportScroll:SetPoint("TOPLEFT", nudger, "TOPLEFT", 18, -268)
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
    btnReset:SetSize(120, 24)
    btnReset:SetPoint("LEFT", btnCopy, "RIGHT", 8, 0)
    btnReset:SetText("Reset Defaults")
    btnReset:SetScript("OnClick", function()
        local preset = THEME_PRESETS[activeTheme]
        states[activeTheme] = CloneTable(preset)
        nudger:RefreshControls()
    end)
    
    local btnClose = CreateFrame("Button", nil, nudger, "UIPanelButtonTemplate")
    btnClose:SetSize(90, 24)
    btnClose:SetPoint("BOTTOMRIGHT", nudger, "BOTTOMRIGHT", -18, 16)
    btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function() nudger:Hide() end)
    
    function nudger:RefreshControls()
        local s = states[activeTheme]
        local targets = (activeMode == "Geometry") and GEOM_TARGETS or UV_TARGETS
        
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
        for _, t in ipairs(targets) do
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
                row.ValText:SetText(string.format("%.1f", s[key] or 0))
                
                local function onStep(delta)
                    s[key] = (s[key] or 0) + delta
                    row.ValText:SetText(string.format("%.1f", s[key]))
                    ApplyState(_G["OnePanelFrame"], s)
                    exportBox:SetText(GetFormattedCode(activeTheme, s))
                end
                
                row.BtnM10:SetScript("OnClick", function() onStep(-10) end)
                row.BtnM1:SetScript("OnClick", function() onStep(-1) end)
                row.BtnP1:SetScript("OnClick", function() onStep(1) end)
                row.BtnP10:SetScript("OnClick", function() onStep(10) end)
            else
                row:Hide()
            end
        end
        
        ApplyState(_G["OnePanelFrame"], s)
        exportBox:SetText(GetFormattedCode(activeTheme, s))
    end
    
    nudger:SetScript("OnShow", function()
        if _G["OnePanelFrame"] and not _G["OnePanelFrame"]:IsShown() then
            _G["OnePanelFrame"]:Show()
        end
        nudger:RefreshTargetButtons()
        nudger:RefreshControls()
    end)
    
    nudger:RefreshTargetButtons()
    nudger:RefreshControls()
    return nudger
end

SLASH_OPNUDGE1 = "/opnudge"
SLASH_OPNUDGE2 = "/opalign"
SLASH_OPNUDGE3 = "/opborder"
SlashCmdList["OPNUDGE"] = function()
    -- Ensure OnePanel master frame is created
    if OnePanel and OnePanel.CreateMasterFrame and not _G["OnePanelFrame"] then
        OnePanel:CreateMasterFrame()
    end
    if _G["OnePanelFrame"] and not _G["OnePanelFrame"]:IsShown() then
        _G["OnePanelFrame"]:Show()
    end
    
    local f = CreateNudgerFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

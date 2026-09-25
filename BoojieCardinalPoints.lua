local ADDON_NAME = ...

local TITLE = "Boojie Cardinal Points"
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "1.1.0"
local ICON = "Interface\\AddOns\\BoojieCardinalPoints\\BoojieCardinalPointsBCPIcon.png"
local LDB_NAME = "BoojieCardinalPoints"
local PINK_HEX = "FFFF8DA1"
local PINK_R, PINK_G, PINK_B = 1, 0.553, 0.631
local MIN_SIZE, MAX_SIZE = 8, 40
local MIN_OFFSET, MAX_OFFSET = -50, 50

local DEFAULTS = {
    size = 18,
    outline = false,
    offsets = { N = 0, E = 0, S = 0, W = 0 },
    color = { r = 1, g = 1, b = 1 },
    showMinimapButton = true,
    minimap = { minimapPos = 225 },
    windowPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
}

local OFFSET_LABELS = {
    N = "North Y (+ up / - down)",
    E = "East X (+ right / - left)",
    S = "South Y (+ up / - down)",
    W = "West X (+ right / - left)",
}

local BACKDROP = {
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local db
local letterLayer
local letters = {}
local window
local ldbIcon
local sizeSlider
local sizeLabel
local colorSwatch
local outlineCheck
local offsetLabels = {}
local offsetSliders = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function ApplyBackdrop(frame, alpha)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0, 0, 0, alpha or 1)
    frame:SetBackdropBorderColor(PINK_R, PINK_G, PINK_B, 1)
end

local function SkinButton(button)
    ApplyBackdrop(button, 1)
    button:SetNormalFontObject("GameFontHighlight")
    button:SetHighlightTexture("Interface/Buttons/WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(PINK_R, PINK_G, PINK_B, 0.22)
    button:SetPushedTexture("Interface/Buttons/WHITE8X8")
    button:GetPushedTexture():SetVertexColor(PINK_R, PINK_G, PINK_B, 0.35)
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    SkinButton(button)
    return button
end

local function InitializeDatabase()
    BoojieCardinalPointsDB = type(BoojieCardinalPointsDB) == "table" and BoojieCardinalPointsDB or {}
    db = BoojieCardinalPointsDB
    db.size = Clamp(tonumber(db.size) or DEFAULTS.size, MIN_SIZE, MAX_SIZE)
    db.outline = db.outline == true
    db.offsets = type(db.offsets) == "table" and db.offsets or {
        N = tonumber(db.yOffset) or 0,
        E = tonumber(db.xOffset) or 0,
        S = -(tonumber(db.yOffset) or 0),
        W = -(tonumber(db.xOffset) or 0),
    }
    for direction, defaultValue in pairs(DEFAULTS.offsets) do
        db.offsets[direction] = Clamp(tonumber(db.offsets[direction]) or defaultValue, MIN_OFFSET, MAX_OFFSET)
    end
    db.xOffset = nil
    db.yOffset = nil

    db.color = type(db.color) == "table" and db.color or {}
    db.color.r = Clamp(tonumber(db.color.r) or DEFAULTS.color.r, 0, 1)
    db.color.g = Clamp(tonumber(db.color.g) or DEFAULTS.color.g, 0, 1)
    db.color.b = Clamp(tonumber(db.color.b) or DEFAULTS.color.b, 0, 1)
    db.showMinimapButton = db.showMinimapButton ~= false
    db.minimap = type(db.minimap) == "table" and db.minimap or { minimapPos = DEFAULTS.minimap.minimapPos }
    db.minimap.minimapPos = tonumber(db.minimap.minimapPos) or DEFAULTS.minimap.minimapPos
    db.windowPosition = type(db.windowPosition) == "table" and db.windowPosition or {}
    for key, value in pairs(DEFAULTS.windowPosition) do
        if type(db.windowPosition[key]) ~= type(value) then
            db.windowPosition[key] = value
        end
    end
end

local function ApplyAppearance()
    local fontFile = GameFontNormal:GetFont()
    local flags = db.outline and "OUTLINE" or ""
    for _, fontString in pairs(letters) do
        fontString:SetFontObject(nil)
        fontString:SetFont(fontFile, db.size, flags)
        fontString:SetTextColor(db.color.r, db.color.g, db.color.b)
    end
end

local function CreateLetters()
    letterLayer = CreateFrame("Frame", nil, Minimap)
    letterLayer:SetAllPoints(Minimap)
    letterLayer:SetFrameLevel(Minimap:GetFrameLevel() + 100)
    letterLayer:EnableMouse(false)

    for _, direction in ipairs({ "N", "E", "S", "W" }) do
        letters[direction] = letterLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        letters[direction]:SetText(direction)
    end
    ApplyAppearance()
end

local function PositionLetters()
    if not letterLayer then
        return
    end

    letterLayer:SetFrameLevel(Minimap:GetFrameLevel() + 100)
    local halfSize = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
    local edgeInset = math.max(8, db.size * 0.65)
    local radius = math.max(0, halfSize - edgeInset)

    local function Place(fontString, x, y)
        fontString:ClearAllPoints()
        fontString:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    Place(letters.N, 0, radius + db.offsets.N)
    Place(letters.E, radius + db.offsets.E, 0)
    Place(letters.S, 0, -radius + db.offsets.S)
    Place(letters.W, -radius + db.offsets.W, 0)
end

local function SetSize(value)
    db.size = Clamp(math.floor(value + 0.5), MIN_SIZE, MAX_SIZE)
    if sizeLabel then
        sizeLabel:SetText("Letter size: " .. db.size)
    end
    ApplyAppearance()
    PositionLetters()
end

local function SetOffset(direction, value)
    db.offsets[direction] = Clamp(math.floor(value + 0.5), MIN_OFFSET, MAX_OFFSET)
    if offsetLabels[direction] then
        offsetLabels[direction]:SetText(OFFSET_LABELS[direction] .. " offset: " .. db.offsets[direction])
    end
    PositionLetters()
end

local function SetColor(r, g, b)
    db.color.r = r
    db.color.g = g
    db.color.b = b
    if colorSwatch then
        colorSwatch:SetColorTexture(r, g, b, 1)
    end
    ApplyAppearance()
end

local function SetOutline(enabled)
    db.outline = enabled and true or false
    if outlineCheck then
        outlineCheck:SetChecked(db.outline)
    end
    ApplyAppearance()
end

local function OpenColorPicker()
    local oldR, oldG, oldB = db.color.r, db.color.g, db.color.b
    ColorPickerFrame:SetupColorPickerAndShow({
        r = oldR,
        g = oldG,
        b = oldB,
        hasOpacity = false,
        swatchFunc = function()
            SetColor(ColorPickerFrame:GetColorRGB())
        end,
        cancelFunc = function()
            SetColor(oldR, oldG, oldB)
        end,
    })
end

local function SaveWindowPosition()
    if not window then
        return
    end
    local point, _, relativePoint, x, y = window:GetPoint(1)
    if point then
        db.windowPosition.point = point
        db.windowPosition.relativePoint = relativePoint or point
        db.windowPosition.x = math.floor((x or 0) + 0.5)
        db.windowPosition.y = math.floor((y or 0) + 0.5)
    end
end

local function UpdateMinimapButtonVisibility()
    if not ldbIcon then
        return
    end
    db.minimap.hide = not db.showMinimapButton
    if db.showMinimapButton then
        ldbIcon:Show(LDB_NAME)
    else
        ldbIcon:Hide(LDB_NAME)
    end
end

local function CreateSlider(parent, name, labelText, x, y, minimum, maximum, value, callback)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetTextColor(PINK_R, PINK_G, PINK_B)
    label:SetText(labelText)

    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -10)
    slider:SetWidth(260)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText(minimum)
    _G[name .. "High"]:SetText(maximum)
    _G[name .. "Text"]:SetText("")
    slider:SetScript("OnValueChanged", function(_, newValue)
        callback(newValue)
    end)
    slider:SetValue(value)
    return slider, label
end

local function ResetDefaults()
    SetColor(DEFAULTS.color.r, DEFAULTS.color.g, DEFAULTS.color.b)
    SetOutline(DEFAULTS.outline)
    sizeSlider:SetValue(DEFAULTS.size)
    for direction, slider in pairs(offsetSliders) do
        slider:SetValue(DEFAULTS.offsets[direction])
    end
end

local function CreateWindow()
    window = CreateFrame("Frame", "BoojieCardinalPointsWindow", UIParent, "BackdropTemplate")
    window:SetSize(640, 500)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)
    window:SetPoint(
        db.windowPosition.point,
        UIParent,
        db.windowPosition.relativePoint,
        db.windowPosition.x,
        db.windowPosition.y
    )
    ApplyBackdrop(window, 0.98)
    window:Hide()

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -17)
    title:SetText("|c" .. PINK_HEX .. TITLE .. "|r  |cffaaaaaav" .. VERSION .. "|r")

    local closeButton = CreateButton(window, "X", 24, 24)
    closeButton:SetPoint("TOPRIGHT", -10, -10)
    closeButton:SetScript("OnClick", function()
        window:Hide()
    end)

    local command = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    command:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    command:SetText("Open this window: |c" .. PINK_HEX .. "/bcp|r")

    local minimapCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 14, -68)
    minimapCheck:SetChecked(db.showMinimapButton)
    minimapCheck:SetScript("OnClick", function(self)
        db.showMinimapButton = self:GetChecked() and true or false
        UpdateMinimapButtonVisibility()
    end)

    local minimapLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
    minimapLabel:SetText("Show minimap button")

    local separator = window:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(PINK_R, PINK_G, PINK_B, 0.65)
    separator:SetPoint("TOPLEFT", 18, -105)
    separator:SetPoint("TOPRIGHT", -18, -105)
    separator:SetHeight(1)

    sizeSlider, sizeLabel = CreateSlider(
        window,
        "BoojieCardinalPointsSizeSlider",
        "Letter size: " .. db.size,
        22,
        -130,
        MIN_SIZE,
        MAX_SIZE,
        db.size,
        SetSize
    )

    local directions = {
        { direction = "N", x = 22, y = -220 },
        { direction = "E", x = 330, y = -220 },
        { direction = "S", x = 22, y = -305 },
        { direction = "W", x = 330, y = -305 },
    }
    for _, control in ipairs(directions) do
        local direction = control.direction
        local capturedDirection = direction
        local slider, label = CreateSlider(
            window,
            "BoojieCardinalPoints" .. direction .. "OffsetSlider",
            OFFSET_LABELS[direction] .. " offset: " .. db.offsets[direction],
            control.x,
            control.y,
            MIN_OFFSET,
            MAX_OFFSET,
            db.offsets[direction],
            function(value)
                SetOffset(capturedDirection, value)
            end
        )
        offsetSliders[direction] = slider
        offsetLabels[direction] = label
    end

    local colorButton = CreateButton(window, "Choose Letter Color", 150, 28)
    colorButton:SetPoint("TOPLEFT", 22, -405)
    colorButton:SetScript("OnClick", OpenColorPicker)

    colorSwatch = window:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetSize(24, 24)
    colorSwatch:SetPoint("LEFT", colorButton, "RIGHT", 10, 0)
    colorSwatch:SetColorTexture(db.color.r, db.color.g, db.color.b, 1)

    outlineCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    outlineCheck:SetPoint("LEFT", colorSwatch, "RIGHT", 35, 0)
    outlineCheck:SetChecked(db.outline)
    outlineCheck:SetScript("OnClick", function(self)
        SetOutline(self:GetChecked())
    end)

    local outlineLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    outlineLabel:SetPoint("LEFT", outlineCheck, "RIGHT", 3, 0)
    outlineLabel:SetText("Outline letters")

    local resetButton = CreateButton(window, "Reset Defaults", 130, 28)
    resetButton:SetPoint("TOPRIGHT", -22, -405)
    resetButton:SetScript("OnClick", ResetDefaults)

    table.insert(UISpecialFrames, window:GetName())
end

local function ToggleWindow()
    window:SetShown(not window:IsShown())
end

local function CreateMinimapButton()
    ldbIcon = LibStub("LibDBIcon-1.0")
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(LDB_NAME, {
        type = "launcher",
        label = TITLE,
        text = TITLE,
        icon = ICON,
        OnClick = ToggleWindow,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(TITLE, PINK_R, PINK_G, PINK_B)
            tooltip:AddLine("Click to open or close.", 1, 1, 1)
        end,
    })
    db.minimap.hide = not db.showMinimapButton
    ldbIcon:Register(LDB_NAME, launcher, db.minimap)
end

local function RegisterBlizzardSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return
    end

    local panel = CreateFrame("Frame")

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(128, 128)
    icon:SetPoint("TOP", 0, -28)
    icon:SetTexture(ICON)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", icon, "BOTTOM", 0, -12)
    title:SetText("|c" .. PINK_HEX .. TITLE .. "|r  |cffaaaaaav" .. VERSION .. "|r")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOP", title, "BOTTOM", 0, -10)
    description:SetText("Customize the stationary cardinal points around your minimap.")

    local openButton = CreateButton(panel, "Open Boojie Cardinal Points", 220, 28)
    openButton:SetPoint("TOP", description, "BOTTOM", 0, -18)
    openButton:SetScript("OnClick", function()
        window:Show()
    end)

    local command = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    command:SetPoint("TOP", openButton, "BOTTOM", 0, -12)
    command:SetText("You can also open it with |c" .. PINK_HEX .. "/bcp|r")

    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
end

SLASH_BOOJIECARDINALPOINTS1 = "/boojiecardinalpoints"
SLASH_BOOJIECARDINALPOINTS2 = "/bcp"
SlashCmdList.BOOJIECARDINALPOINTS = function()
    if window then
        ToggleWindow()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if not Minimap then
        return
    end

    InitializeDatabase()
    CreateLetters()
    PositionLetters()
    Minimap:HookScript("OnSizeChanged", PositionLetters)
    CreateWindow()
    CreateMinimapButton()
    RegisterBlizzardSettings()
end)

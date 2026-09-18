local f = CreateFrame("Frame")

local DEFAULTS = {
    size = 18,
    outline = false,
    offsets = { N = 0, E = 0, S = 0, W = 0 },
    color = { r = 1, g = 1, b = 1 },
}
local MIN_SIZE, MAX_SIZE = 8, 40
local MIN_OFFSET, MAX_OFFSET = -50, 50
local OFFSET_LABELS = {
    N = "North Y (+ up / - down)",
    E = "East X (+ right / - left)",
    S = "South Y (+ up / - down)",
    W = "West X (+ right / - left)",
}
local letters, db = {}, nil
local letterLayer
local sizeSlider, sizeLabel, colorSwatch, outlineCheck
local offsetLabels = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
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
    db.xOffset, db.yOffset = nil, nil
    db.color = type(db.color) == "table" and db.color or {}
    db.color.r = Clamp(tonumber(db.color.r) or DEFAULTS.color.r, 0, 1)
    db.color.g = Clamp(tonumber(db.color.g) or DEFAULTS.color.g, 0, 1)
    db.color.b = Clamp(tonumber(db.color.b) or DEFAULTS.color.b, 0, 1)
end

local function ApplyAppearance()
    local fontFile = GameFontNormal:GetFont()
    local flags = db.outline and "OUTLINE" or ""
    for _, fs in pairs(letters) do
        fs:SetFontObject(nil)
        fs:SetFont(fontFile, db.size, flags)
        fs:SetTextColor(db.color.r, db.color.g, db.color.b)
    end
end

local function CreateLetters()
    letterLayer = CreateFrame("Frame", nil, Minimap)
    letterLayer:SetAllPoints(Minimap)
    letterLayer:SetFrameLevel(Minimap:GetFrameLevel() + 100)
    letterLayer:EnableMouse(false)

    letters.N = letterLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letters.E = letterLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letters.S = letterLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letters.W = letterLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    for direction, fs in pairs(letters) do fs:SetText(direction) end
    ApplyAppearance()
end

local function PositionLetters()
    letterLayer:SetFrameLevel(Minimap:GetFrameLevel() + 100)
    local halfSize = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
    local edgeInset = math.max(8, db.size * 0.65)
    local radius = math.max(0, halfSize - edgeInset)
    local function Place(fs, x, y)
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    Place(letters.N, 0, radius + db.offsets.N)
    Place(letters.E, radius + db.offsets.E, 0)
    Place(letters.S, 0, -radius + db.offsets.S)
    Place(letters.W, -radius + db.offsets.W, 0)
end

local function SetSize(value)
    db.size = Clamp(math.floor(value + 0.5), MIN_SIZE, MAX_SIZE)
    if sizeLabel then sizeLabel:SetText("Letter size: " .. db.size) end
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
    db.color.r, db.color.g, db.color.b = r, g, b
    if colorSwatch then colorSwatch:SetColorTexture(r, g, b, 1) end
    ApplyAppearance()
end

local function SetOutline(enabled)
    db.outline = enabled and true or false
    if outlineCheck then outlineCheck:SetChecked(db.outline) end
    ApplyAppearance()
end

local function OpenColorPicker()
    local oldR, oldG, oldB = db.color.r, db.color.g, db.color.b
    ColorPickerFrame:SetupColorPickerAndShow({
        r = oldR, g = oldG, b = oldB, hasOpacity = false,
        swatchFunc = function() SetColor(ColorPickerFrame:GetColorRGB()) end,
        cancelFunc = function() SetColor(oldR, oldG, oldB) end,
    })
end

local function CreateSettingsPanel()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end

    local panel = CreateFrame("Frame")
    panel.name = "Boojie Cardinal Points"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(panel.name)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Customize the stationary cardinal points around the minimap.")

    sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -30)
    sizeLabel:SetText("Letter size: " .. db.size)

    sizeSlider = CreateFrame("Slider", "BoojieCardinalPointsSizeSlider", panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 4, -12)
    sizeSlider:SetWidth(260)
    sizeSlider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    _G[sizeSlider:GetName() .. "Low"]:SetText(MIN_SIZE)
    _G[sizeSlider:GetName() .. "High"]:SetText(MAX_SIZE)
    _G[sizeSlider:GetName() .. "Text"]:SetText("")
    sizeSlider:SetScript("OnValueChanged", function(_, value) SetSize(value) end)
    sizeSlider:SetValue(db.size)

    local offsetSliders = {}
    local function CreateOffsetControl(direction, text, anchor, x, y)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        label:SetText(text .. " offset: " .. db.offsets[direction])
        offsetLabels[direction] = label

        local slider = CreateFrame("Slider", "BoojieCardinalPoints" .. direction .. "OffsetSlider", panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -12)
        slider:SetWidth(220)
        slider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        _G[slider:GetName() .. "Low"]:SetText(MIN_OFFSET)
        _G[slider:GetName() .. "High"]:SetText(MAX_OFFSET)
        _G[slider:GetName() .. "Text"]:SetText("")
        slider:SetScript("OnValueChanged", function(_, value) SetOffset(direction, value) end)
        slider:SetValue(db.offsets[direction])
        offsetSliders[direction] = slider
        return slider
    end

    local northSlider = CreateOffsetControl("N", OFFSET_LABELS.N, sizeSlider, -4, -30)
    local eastSlider = CreateOffsetControl("E", OFFSET_LABELS.E, sizeSlider, 286, -30)
    local southSlider = CreateOffsetControl("S", OFFSET_LABELS.S, northSlider, -4, -30)
    CreateOffsetControl("W", OFFSET_LABELS.W, eastSlider, -4, -30)

    local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", southSlider, "BOTTOMLEFT", -4, -34)
    colorLabel:SetText("Letter color")

    local colorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    colorButton:SetSize(130, 26)
    colorButton:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -10)
    colorButton:SetText("Choose Color")
    colorButton:SetScript("OnClick", OpenColorPicker)

    colorSwatch = panel:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetSize(22, 22)
    colorSwatch:SetPoint("LEFT", colorButton, "RIGHT", 10, 0)
    colorSwatch:SetColorTexture(db.color.r, db.color.g, db.color.b, 1)

    outlineCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    outlineCheck:SetPoint("LEFT", colorSwatch, "RIGHT", 42, 0)
    outlineCheck:SetChecked(db.outline)
    local outlineLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    outlineLabel:SetPoint("LEFT", outlineCheck, "RIGHT", 3, 0)
    outlineLabel:SetText("Outline letters")
    outlineCheck:SetScript("OnClick", function(self) SetOutline(self:GetChecked()) end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(130, 26)
    resetButton:SetPoint("TOPLEFT", colorButton, "BOTTOMLEFT", 0, -24)
    resetButton:SetText("Reset Defaults")
    resetButton:SetScript("OnClick", function()
        SetColor(DEFAULTS.color.r, DEFAULTS.color.g, DEFAULTS.color.b)
        SetOutline(DEFAULTS.outline)
        sizeSlider:SetValue(DEFAULTS.size)
        for direction, slider in pairs(offsetSliders) do
            slider:SetValue(DEFAULTS.offsets[direction])
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not Minimap then return end
    InitializeDatabase()
    CreateLetters()
    PositionLetters()
    Minimap:HookScript("OnSizeChanged", PositionLetters)
    CreateSettingsPanel()
end)

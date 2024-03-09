local lib = require "../../../extension/lua/joypad-assist/Advanced Gamepad Assist/AGALib"
local _json = require "json"

local uiData = ac.connect{
    ac.StructItem.key("AGAData"),
    _appCanRun               = ac.StructItem.boolean(),
    _rAxleHVelAngle          = ac.StructItem.double(),
    _selfSteerStrength       = ac.StructItem.double(),
    _frontNdSlip             = ac.StructItem.double(),
    _rearNdSlip              = ac.StructItem.double(),
    _limitReduction          = ac.StructItem.double(),
    _gameGamma               = ac.StructItem.double(),
    _gameDeadzone            = ac.StructItem.double(),
    _gameRumble              = ac.StructItem.double(),
    assistEnabled            = ac.StructItem.boolean(),
    graphSelection           = ac.StructItem.int32(), -- 1 = none, 2 = static, 3 = live
    keyboardMode             = ac.StructItem.int32(), -- 0 = disabled, 1 = enabled, 2 = enabled + brake assist, 3 = enabled + throttle and brake assist
    autoClutch               = ac.StructItem.boolean(),
    autoShiftingMode         = ac.StructItem.int32(), -- 0 = default, 1 = manual, 2 = automatic
    autoShiftingCruise       = ac.StructItem.boolean(),
    autoShiftingDownBias     = ac.StructItem.double(),
    triggerFeedbackL         = ac.StructItem.double(),
    triggerFeedbackR         = ac.StructItem.double(),
    triggerFeedbackAlwaysOn  = ac.StructItem.boolean(),
    useFilter                = ac.StructItem.boolean(),
    filterSetting            = ac.StructItem.double(),
    steeringRate             = ac.StructItem.double(),
    targetSlip               = ac.StructItem.double(),
    rateIncreaseWithSpeed    = ac.StructItem.double(),
    selfSteerResponse        = ac.StructItem.double(),
    dampingStrength          = ac.StructItem.double(),
    maxSelfSteerAngle        = ac.StructItem.double(),
    countersteerResponse     = ac.StructItem.double(),
    maxDynamicLimitReduction = ac.StructItem.double()
}

-- Keys that are stored in a preset
local presetKeys = {
    "useFilter",
    "filterSetting",
    "steeringRate",
    "rateIncreaseWithSpeed",
    "targetSlip",
    "selfSteerResponse",
    "dampingStrength",
    "maxSelfSteerAngle",
    "countersteerResponse",
    "maxDynamicLimitReduction",
}

local _factoryPresetsStr = '{"Loose":{"dampingStrength":0.3,"filterSetting":0.5,"useFilter":false,"selfSteerResponse":0.3,"maxSelfSteerAngle":8,"targetSlip":1,"countersteerResponse":0.4,"rateIncreaseWithSpeed":0.1,"maxDynamicLimitReduction":4.5,"steeringRate":0.5},"Default":{"dampingStrength":0.37,"filterSetting":0.5,"useFilter":true,"selfSteerResponse":0.37,"maxSelfSteerAngle":14,"targetSlip":0.95,"countersteerResponse":0.2,"rateIncreaseWithSpeed":0.1,"maxDynamicLimitReduction":5,"steeringRate":0.5},"Stable":{"dampingStrength":0.75,"filterSetting":0.5,"useFilter":false,"selfSteerResponse":0.65,"maxSelfSteerAngle":90,"targetSlip":0.94,"countersteerResponse":0.1,"rateIncreaseWithSpeed":0.1,"maxDynamicLimitReduction":6,"steeringRate":0.3},"Drift":{"dampingStrength":0.5,"filterSetting":0.5,"useFilter":false,"selfSteerResponse":0.35,"maxSelfSteerAngle":90,"targetSlip":1,"countersteerResponse":0.5,"rateIncreaseWithSpeed":0.1,"maxDynamicLimitReduction":4,"steeringRate":0.4},"Author\'s preference":{"dampingStrength":0.4,"filterSetting":0.5,"useFilter":false,"selfSteerResponse":0.4,"maxSelfSteerAngle":90,"targetSlip":0.95,"countersteerResponse":0.2,"rateIncreaseWithSpeed":0,"maxDynamicLimitReduction":5,"steeringRate":0.5}}'
local factoryPresets     = _json.decode(_factoryPresetsStr)

local savedPresets = ac.storage({presets = "{}"}, "AGA_PRESETS_")

local presets = _json.decode(savedPresets.presets)

-- Removing presets saved by previous versions that have the same names as the factory presets
for k, _ in pairs(presets) do
    if factoryPresets[k] ~= nil then
        presets[k] = nil
    end
end
savedPresets.presets = _json.encode(presets)

local tooltips = {
    factoryReset             = "RESETS EVERY SETTING TO ITS DEFAULT VALUE AND DELETES ALL PRESETS!\nClick twice to confirm!",
    lockedNote               = "Locked. Uncheck 'Simplified settings' to adjust manually!",
    presets                  = "This is where you can save or load presets!",
    calibration              = "Performs a quick steering calibration, just in case the assist isn't working correctly.\nYou must stop the car before doing this!",
    graphs                   = "Shows graphs to visualize what the steering assist is doing.\nThey can either be static or updated with live values.",
    assistEnabled            = "Enables or disables the entire assist.\nIf unchecked, AC's built-in input processing is used without alterations.",
    useFilter                = "Provides a single slider that will adjust most settings automatically for you.",
    autoClutch               = "Automatically controls the clutch if the engine would otherwise stall, or when setting off from a standstill.",
    autoShiftingMode         = "Default = AC's own gear shifting, no change.\n\nManual = custom rev-matching and clutch logic, but manual shifting only.\n\nAutomatic = custom rev-matching and clutch logic, but with automatic gear shifts. You can still shift manually to override a gear for a short time though.\n\nIMPORTANT: Options other than 'Default' only work properly if 'Automatic shifting' is DISABLED in AC's assist settings!",
    autoShiftingCruise       = "Allows the automatic shifting to go between cruise mode and performance mode depending on your throttle input.\nUseful if you want to do both performance driving and casual cruising, but you can disable it for racing (especially for rolling starts).",
    autoShiftingDownBias     = "Higher = more aggressive downshifting when using automatic mode.\nFor example at 90% the car will downshift almost immediately when you brake for a turn, however, this might leave you very close to the top of a gear when going back on the throttle again.",
    triggerFeedbackL         = "Vibration feedback on the left trigger when braking.\nOnly works with compatible Xbox controllers!",
    triggerFeedbackR         = "Vibration feedback on the right trigger when accelerating.\nOnly works with compatible Xbox controllers!",
    triggerFeedbackAlwaysOn  = "Allows trigger vibrations even when TCS or ABS are enabled.",
    keyboardMode             = "Enables gas, brake and steering input on keyboard.\nYou can also choose to have brake or gas assistance when ABS or TCS are off. These aren't as good as ABS or TCS, they just try to compensate for not having analog input.\nFor every vehicle control to work (like shifting or handbrake), you also have to enable the 'Combine with keyboard' option in the control settings in Content Manager!",
    filterSetting            = "How much steering assistance you want in general.\nNote that 0% does not mean the assist is off, it's just a lower level of assistance.",
    steeringRate             = "How fast the steering is in general.",
    rateIncreaseWithSpeed    = "How much slower or faster the steering gets as you speed up.",
    selfSteerResponse        = "How aggressive the self-steer force will fight to keep the car straight.\nLow = looser feel and easier to oversteer, high = more assistance to prevent oversteer and keep the car stable.",
    dampingStrength          = "This is an advanced setting, and in most cases it's best to leave it at a similar value to 'Response'.\n\nDamping adds some additional self-steer that counteracts the car's yaw rotation which results in more stability.\nHigher 'Response' and 'Max angle' settings require more damping to stop the car from wobbling, especially at high speed.\nThe damping force is not limited by the 'Max angle' setting.",
    maxSelfSteerAngle        = "Caps the self-steer force to a certain steering angle.\nBasically this limits how big of a slide the self-steer can help to recover from.",
    targetSlip               = "Changes the slip angle that the front wheels will target.\nHigher = more steering, lower = less steering.\nMost cars feel best around 90-95%, but you can set it higher if you want to force the car to go over the limit, or to generate more heat in the front tires.\nBeware that the slip angle achieved in reality might be slightly different from the intended amount on some cars.",
    countersteerResponse     = "High = more effective manual countersteering, but also easier to overcorrect a slide.",
    maxDynamicLimitReduction = "How much the steering angle is allowed to reduce when the car oversteers while you turn inward, in order to maintain front grip.\nLow = more raw and more prone to front wheel slippage.\nHigh = more assistance to keep front grip in a turn.\nFor the best grip it should be at least as high as the travel angle when cornering, but high values can feel restricting.\nIf you like to throw the car into a turn more aggressively with less assistance, set it lower.\nYou might want to use a higher setting for loose-handling cars.",
    builtInSettings          = "These directly adjust AC's own settings (just like the Controller Tweaks app), they are just here for convenience.",
    _gameGamma               = "Controls AC's own \"Steering gamma\" setting.\n\nHigher gamma will make your analog stick less sensitive near the center.",
    _gameDeadzone            = "Controls AC's own \"Steering deadzone\" setting.\n\nDeadzone is used to avoid unintended inputs caused by stick-drift when you're not touching the analog stick.",
    _gameRumble              = "Controls AC's own \"Rumble effects\" setting."
}

local sectionPadding = 10

local black              = rgbm(0.0, 0.0, 0.0, 1.0)
local white              = rgbm(1.0, 1.0, 1.0, 1.0)
local controlHoverColor  = rgbm(0.5, 0.5, 0.5, 1.0)
local controlAccentColor = rgbm(59/255, 159/255, 255/255, 1)
local controlActiveColor = rgbm(59/255, 159/255, 255/255, 0.4)
local lockIconColor      = controlAccentColor
local lockedSliderColor  = rgbm(0.0, 0.2, 0.5, 0.5)
local buttonColor        = rgbm(0.4, 0.4, 0.4, 0.75)
local childBgColor       = rgbm(0.0, 0.0, 0.0, 0.2)

local graphPadding       = 50
local graphDivColor      = rgbm(1.0, 1.0, 1.0, 0.1)
local graphPathColor     = controlAccentColor
local graphBgColor       = rgbm(0.0, 0.0, 0.0, 0.5)
local graphLiveColor     = rgbm(1.0, 1.0, 1.0, 0.5)
local graphBorderColor   = black

local barBgColor         = graphBgColor
local barPadding         = 25
local barLiveColor       = controlAccentColor
local barBorderColor     = black
local barCenterColor     = graphLiveColor
local barHighColor       = rgbm(1.0, 0.0, 0.0, 1.0)
local barLowColor        = rgbm(140/255, 156/255, 171/255, 1)

local zeroVec = vec2() -- Do not modify
local tmpVec1 = vec2()
local tmpVec2 = vec2()
local tmpVec3 = vec2()

local presetsWindowEnabled = false

local enableClicked = 0

local function getPresetList()
    local keys = {}
    for k, _ in pairs(factoryPresets) do
        keys[#keys + 1] = "*" .. k
    end
    for k, _ in pairs(presets) do
        if factoryPresets[k] == nil then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

local function addTooltipToLastItem(tooltipKey)
    if ui.itemHovered() and tooltipKey and tooltips[tooltipKey] then
        ui.setTooltip(tooltips[tooltipKey])
    end
end

local function showCheckbox(cfgKey, name, inverted, disabled, indent)
    indent = indent or sectionPadding
    local val = not uiData[cfgKey]
    if not inverted then val = not val end
    ui.offsetCursorX(indent)
    if disabled then ui.pushDisabled() end
    if ui.checkbox(name, val) and not disabled then
        uiData[cfgKey] = not uiData[cfgKey]
    end
    if disabled then ui.popDisabled() end
    addTooltipToLastItem(cfgKey)
end

local function showConfigSlider(cfgKey, name, format, minVal, maxVal, valueMult, locked, width, indent, disabled, onHover, hoverOnInteract)
    indent = indent or sectionPadding
    width = width or ui.availableSpaceX()
    local displayVal = uiData[cfgKey] * valueMult
    if locked then
        ui.offsetCursorX(indent)
        local cursorOld = ui.getCursor()
        ui.drawRectFilled(cursorOld, tmpVec1:set(cursorOld.x + width - indent, cursorOld.y + ui.frameHeight()), lockedSliderColor)
        ui.setCursorX(cursorOld.x)
        ui.textAligned(string.format(name .. ": " .. format, displayVal), tmpVec1:set(0.5, 0.5), tmpVec2:set(width - indent, ui.frameHeight()))
        ui.setCursor(cursorOld)
        ui.setItemAllowOverlap()
        ui.invisibleButton("##" .. cfgKey, tmpVec1:set(width - indent, ui.frameHeight()))
        addTooltipToLastItem(cfgKey)
        if onHover and ui.itemHovered() then onHover() end
        local preImageCursor = ui.getCursor()
        ui.setCursor(cursorOld)
        ui.offsetCursorX(-ui.frameHeight())
        ui.image("img/lock.png", tmpVec1:set(ui.frameHeight(), ui.frameHeight()), lockIconColor, true)
        addTooltipToLastItem("lockedNote")
        ui.setCursor(preImageCursor)
        local newValue = math.clamp(displayVal, minVal, maxVal) / valueMult
        if math.abs(newValue - displayVal) > (1e-5 * (maxVal - minVal)) then uiData[cfgKey] = newValue end
        return newValue
    else
        ui.offsetCursorX(indent)
        ui.setNextItemWidth(width - indent)
        if disabled then ui.pushDisabled() end
        local value, changed = ui.slider("##" .. cfgKey, displayVal, minVal, maxVal, name .. ": " .. format)
        if disabled then ui.popDisabled() end
        value = math.clamp(value, minVal, maxVal) / valueMult
        local changedFr = math.abs(value - displayVal) > (1e-5 * (maxVal - minVal))
        addTooltipToLastItem(cfgKey)
        if onHover and (ui.itemHovered() or (hoverOnInteract and ui.itemActive())) then onHover() end
        local newValue = changedFr and value or (math.clamp(displayVal, minVal, maxVal) / valueMult)
        if changedFr then uiData[cfgKey] = newValue end
        return newValue
    end
end

local function showDummyLine(lineHeightMult)
    lineHeightMult = lineHeightMult or 1.0
    ui.dummy(tmpVec1:set(ui.availableSpaceX(), ui.frameHeight() * lineHeightMult))
end

local function showHeader(text)
    showDummyLine(0.25)
    ui.alignTextToFramePadding()
    ui.header(text)
end

local function showButton(text, tooltipKey, callback, indent)
    indent = indent or sectionPadding
    ui.offsetCursorX(indent)
    local clicked = ui.button(text, tmpVec1:set(ui.availableSpaceX() - indent, ui.frameHeight()))
    addTooltipToLastItem(tooltipKey)
    if clicked and callback then callback() end
    return clicked
end

local function showCompactDropdown(label, tooltipKey, values, selectedIndex, indent)
    indent = indent or sectionPadding
    ui.offsetCursorX(indent)
    ui.pushItemWidth(ui.availableSpaceX() * 0.5)
    local selection = ui.combo(string.format("%s - %s", label, values[selectedIndex]), selectedIndex, ui.ComboFlags.NoPreview, values)
    addTooltipToLastItem(tooltipKey)
    ui.popItemWidth()
    return selection + 0
end

local function sendRecalibrationEvent()
    ac.broadcastSharedEvent("AGA_calibrateSteering")
end

local function showBar(title, upperLeft, size, xMin, xMax, xDiv, lowColor, highColor, xHighlight, liveXValue)
    ui.toolWindow(title, upperLeft, size, true, function ()
        ui.pushFont(ui.Font.Small)

        ui.drawRectFilled(zeroVec, size, barBgColor)
        ui.drawRect(zeroVec, size, barBorderColor)
        ui.offsetCursorY(7)
        ui.textAligned(title, tmpVec1:set(0.5, 0.0), tmpVec2:set(size.x, 0.0))

        local xRange   = xMax - xMin
        local barWidth = size.x - 2 * barPadding
        local xPPU     = barWidth / xRange -- Pixels per unit

        ui.setCursorX(0)
        ui.setCursorY(0)

        for x = xMin, xMax, xDiv do
            ui.drawLine(tmpVec1:set(math.round(barPadding + xPPU * (x - xMin)) or 0, barPadding), tmpVec2:set(tmpVec1.x, size.y - barPadding), graphDivColor)
            ui.textAligned(
                string.format("%.f", x),
                tmpVec1:set(((x - xMin) / xRange) * ((size.x - 2 * barPadding + (barWidth * 0.018)) / size.x) + ((barPadding - (barWidth * 0.0053333)) / size.x), (size.y - barPadding + 15) / size.y),
                size
            )
            ui.setCursor(zeroVec)
        end

        if xHighlight then ui.drawLine(tmpVec1:set(math.round(barPadding + xPPU * (xHighlight - xMin)) or 0, barPadding), tmpVec2:set(tmpVec1.x, size.y - barPadding), barCenterColor) end

        if liveXValue then
            local liveLineXPos = math.round(barPadding + (liveXValue - xMin) / xRange * barWidth) or 0
            local tooLow = liveLineXPos < barPadding + 2
            local tooHigh = liveLineXPos > (size.x - barPadding - 3)
            local barColor = barLiveColor
            if tooHigh and highColor then
                liveLineXPos = size.x - barPadding - 3
                barColor = highColor
            end
            if tooLow and lowColor then
                liveLineXPos = barPadding + 2
                barColor = lowColor
            end
            if (tooLow or lowColor) and (tooHigh or highColor) then ui.drawLine(tmpVec1:set(liveLineXPos, barPadding + 1), tmpVec2:set(liveLineXPos, size.y - barPadding - 1), barColor, 3) end
        end

        ui.drawRect(tmpVec1:set(barPadding, barPadding), tmpVec2:set(size.x - barPadding, size.y - barPadding), white)

        ui.popFont()
        return 0
    end)
    ui.popStyleVar()
end

local function showGraph(title, upperLeft, size, xTitle, yTitle, xMin, xMax, yMin, yMax, xDiv, yDiv, graphCallback, liveXValue, screenSampleSize)
    ui.toolWindow(title, upperLeft, size, true, function ()
        ui.pushFont(ui.Font.Small)

        ui.drawRectFilled(zeroVec, size, graphBgColor)
        ui.drawRect(zeroVec, size, graphBorderColor)

        ui.offsetCursorY(10)
        ui.textAligned(title, tmpVec1:set(0.5, 0.0), tmpVec2:set(size.x, 0.0))

        ui.drawLine(tmpVec1:set(graphPadding, graphPadding), tmpVec2:set(graphPadding, size.y - graphPadding), white)
        ui.drawLine(tmpVec1:set(graphPadding, size.y - graphPadding), tmpVec2:set(size.x - graphPadding, size.y - graphPadding), white)

        local xRange = xMax - xMin
        local yRange = yMax - yMin

        local xPPU = (size.x - 2 * graphPadding) / xRange -- Pixels per unit
        local yPPU = (size.y - 2 * graphPadding) / yRange -- Pixels per unit

        ui.setCursorX(0)
        ui.setCursorY(0)

        local graphWidth  = size.x - graphPadding * 2.0
        local graphHeight = size.y - graphPadding * 2.0

        if graphCallback then
            for cx = graphPadding, size.x - graphPadding, screenSampleSize do
                local relativeX = math.clamp(cx - graphPadding, 0.0, graphWidth) / graphWidth
                ui.pathLineTo(tmpVec1:set(
                    graphPadding + relativeX * graphWidth,
                    ((1.0 - (graphCallback(xMin + relativeX * xRange) - yMin) / yRange)) * graphHeight + graphPadding
                ))
            end
            ui.pathStroke(graphPathColor, false, 2)
        end

        for x = xMin, xMax, xDiv do
            ui.drawLine(tmpVec1:set(math.round(graphPadding + xPPU * (x - xMin)) or 0, graphPadding), tmpVec2:set(tmpVec1.x, size.y - graphPadding), graphDivColor)
            ui.textAligned(
                string.format("%.f", x),
                tmpVec1:set(((x - xMin) / xRange) * ((size.x - 2 * graphPadding + (graphWidth * 0.018)) / size.x) + ((graphPadding - (graphWidth * 0.0053333)) / size.x), (size.y - graphPadding + 15) / size.y),
                size
            )
            ui.setCursor(zeroVec)
        end

        for y = yMin, yMax, yDiv do
            ui.drawLine(tmpVec1:set(graphPadding, math.round(graphPadding + yPPU * (y - yMin))), tmpVec2:set(size.x - graphPadding, math.round(graphPadding + yPPU * (y - xMin))), graphDivColor)
            ui.textAligned(
                string.format("%.f", y),
                tmpVec1:set((graphPadding - 15) / size.x, 1.0 - (((y - yMin) / yRange) * ((size.y - 2 * graphPadding + (graphHeight * 0.018)) / size.y) + ((graphPadding - (graphHeight * 0.0053333)) / size.y))),
                size
            )
            ui.setCursor(zeroVec)
        end

        if liveXValue and graphCallback then
            local liveLineXPos = math.round(graphPadding + (liveXValue - xMin) / xRange * graphWidth) or 0
            local liveLineYPos = math.round(graphPadding + (1.0 - (graphCallback(liveXValue) - yMin) / yRange) * graphHeight) or 0
            local xPosTooHigh = not (liveLineXPos < size.x - graphPadding)
            local yPosTooHigh = not (liveLineYPos > graphPadding)
            if liveLineXPos > graphPadding and not xPosTooHigh then
                ui.drawLine(tmpVec1:set(liveLineXPos, graphPadding), tmpVec2:set(liveLineXPos, size.y - graphPadding), graphLiveColor)
            end
            if liveLineYPos < size.y - graphPadding and not yPosTooHigh then
                ui.drawLine(tmpVec1:set(graphPadding, liveLineYPos), tmpVec2:set(size.x - graphPadding, liveLineYPos), graphLiveColor)
            end
            if not (xPosTooHigh or yPosTooHigh) then
                ui.drawCircleFilled(tmpVec1:set(liveLineXPos, liveLineYPos), 3, graphPathColor)
            end
        end

        ui.offsetCursorY(size.y - graphPadding + 30)
        ui.textAligned(xTitle, tmpVec1:set(0.5, 0.0), tmpVec2:set(size.x, 0.0))
        ui.setCursor(zeroVec)

        ui.beginRotation()
        ui.offsetCursorY(size.y * 0.5)
        ui.setCursorX(graphPadding)
        ui.textAligned(yTitle, tmpVec1:set(0.5, 0.0), tmpVec2:set(size.x - graphPadding * 2, 0.0))
        ui.endRotation(180.0, tmpVec1:set(-size.x * 0.5 + graphPadding - 30, 0.0))

        ui.popFont()
        return 0
    end)
    ui.popStyleVar()
end

local function selfSteerCurveCallback(x)
    local correctionExponent = 1.0 + (1.0 - math.log10(10.0 * (uiData.selfSteerResponse * 0.9 + 0.1)))
    local correctionBase     = lib.signedPow(math.clamp(x / 72.0, -1, 1), correctionExponent) * 72.0
    local selfSteerCapT      = math.min(1.0, 4.0 / (2 * uiData.maxSelfSteerAngle))
    return lib.clampEased(correctionBase, -uiData.maxSelfSteerAngle, uiData.maxSelfSteerAngle, selfSteerCapT) * ((uiData.graphSelection == 3) and uiData._selfSteerStrength or 1.0)
end

local function drawSelfSteerCurve()
    local liveAngle = (uiData.graphSelection == 3) and math.abs(uiData._rAxleHVelAngle) or nil
    showGraph("Self-steer force\n(damping force not included)", vec2(ui.windowPos().x + ui.windowWidth(), ui.windowPos().y), vec2(300, 300), "Rear axle travel angle (degrees)", "Self-steer (degrees)", 0.0, 60.0, 0.0, 60.0, 10.0, 10.0, uiData.assistEnabled and selfSteerCurveCallback or nil, uiData.assistEnabled and liveAngle or nil, 3)
end

local function drawLimitReductionBar()
    showBar("Dynamic limit reduction (deg)", vec2(ui.windowPos().x + ui.windowWidth(), ui.windowPos().y + 299), vec2(300, 75), -10.0, 0.0, 1.0, barLiveColor, barLiveColor, -uiData.maxDynamicLimitReduction, uiData.assistEnabled and (-uiData._limitReduction) or nil)
end

local function drawFrontSlipBar()
    showBar("Relative front slip (%)", vec2(ui.windowPos().x + ui.windowWidth(), ui.windowPos().y + 373), vec2(300, 75), 50.0, 150.0, 10.0, barLowColor, barHighColor, 100.0, uiData._frontNdSlip * 100.0)
end

local function drawRearSlipBar()
    showBar("Relative rear slip (%)", vec2(ui.windowPos().x + ui.windowWidth(), ui.windowPos().y + 447), vec2(300, 75), 50.0, 150.0, 10.0, barLowColor, barHighColor, 100.0, uiData._rearNdSlip * 100.0)
end

local function enableScript()
    local iniFile     = "\\joypad_assist.ini"
    local sectionName = "BASIC"

    if ac.getPatchVersionCode() >= 2260 then
        iniFile     = "\\gamepad_fx.ini"
        sectionName = "JOYPAD_ASSIST"
    end

    local gamepadIni = ac.INIConfig.load(ac.getFolder(ac.FolderID.ExtCfgUser) .. iniFile)
    gamepadIni:set(sectionName, "ENABLED", 1)
    gamepadIni:set(sectionName, "IMPLEMENTATION", "Advanced Gamepad Assist")
    gamepadIni:save(ac.getFolder(ac.FolderID.ExtCfgUser) .. iniFile)

    enableClicked = os.clock()
end

local function togglePresetsWindow()
    presetsWindowEnabled = not presetsWindowEnabled
end

local function savePreset(name)
    if factoryPresets[name] ~= nil then return false end

    presets[name] = {}
    for _, pKey in ipairs(presetKeys) do
        if uiData[pKey] ~= nil then presets[name][pKey] = uiData[pKey] end
    end
    savedPresets.presets = _json.encode(presets)

    return true
end

local function loadPreset(name)
    if factoryPresets[name] ~= nil then
        for _, pKey in ipairs(presetKeys) do
            if uiData[pKey] ~= nil and factoryPresets[name][pKey] ~= nil then uiData[pKey] = factoryPresets[name][pKey] end
        end
        return true
    end

    if presets[name] ~= nil then
        for _, pKey in ipairs(presetKeys) do
            if uiData[pKey] ~= nil and presets[name][pKey] ~= nil then uiData[pKey] = presets[name][pKey] end
        end
        return true
    end

    return false
end

local function deletePreset(name)
    if presets[name] == nil then return false end
    presets[name] = nil
    savedPresets.presets = _json.encode(presets)
    return true
end

local function factoryReset()
    presets = _json.decode(_factoryPresetsStr)
    savedPresets.presets = _factoryPresetsStr

    -- // TODO use the event instead of setting these by hand here
    uiData.assistEnabled           = true
    uiData.autoClutch              = false
    uiData.autoShiftingMode        = 0
    uiData.autoShiftingCruise      = true
    uiData.autoShiftingDownBias    = 0.7
    uiData.triggerFeedbackL        = 0.0
    uiData.triggerFeedbackR        = 0.0
    uiData.triggerFeedbackAlwaysOn = false
    uiData.graphSelection          = 1
    uiData.keyboardMode            = 0

    loadPreset("Default")

    presetsWindowEnabled = false

    ac.broadcastSharedEvent("AGA_factoryReset")
end

local function pushStyle()
    ui.pushFont(ui.Font.Small)
    ui.pushStyleColor(ui.StyleColor.Button, buttonColor)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, controlHoverColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgHovered, controlHoverColor)
    ui.pushStyleColor(ui.StyleColor.CheckMark, controlAccentColor)
    ui.pushStyleColor(ui.StyleColor.ButtonActive, controlActiveColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgActive, controlActiveColor)
    ui.pushStyleColor(ui.StyleColor.SliderGrab, buttonColor)
    ui.pushStyleColor(ui.StyleColor.SliderGrabActive, controlAccentColor)
    ui.pushStyleColor(ui.StyleColor.HeaderHovered, controlHoverColor)
    ui.pushStyleColor(ui.StyleColor.HeaderActive, controlActiveColor)
    ui.pushStyleColor(ui.StyleColor.TextSelectedBg, controlAccentColor)
    ui.pushStyleColor(ui.StyleColor.ChildBg, childBgColor)
end

local function popStyle()
    ui.popStyleColor(12)
    ui.popFont()
end

local currentPresetName   = ""
local saveFeedbackStart   = -1
local loadFeedbackStart   = -1
local deleteFeedbackStart = -1
local function drawPresetsWindow()
    ui.beginToolWindow("AGA_presets", tmpVec1:set(ui.windowPos()):add(tmpVec2:set(0, -270)), tmpVec3:set(270, 270), false, true)

    ui.text("Preset name:")

    ui.setNextItemWidth(ui.availableSpaceX())
    currentPresetName = ui.inputText("", currentPresetName, ui.InputTextFlags.RetainSelection):gsub("%*", "")

    local loadText = "⤴️ Load"
    local loadFlags = ui.ButtonFlags.None
    if loadFeedbackStart ~= -1 then
        if ui.time() - loadFeedbackStart > 1.0 then
            loadFeedbackStart = -1
        else
            ui.setNextTextBold()
            loadText = "Loaded!"
            loadFlags = ui.ButtonFlags.Disabled
        end
    end
    local loadClicked = ui.button(loadText, tmpVec1:set(ui.availableSpaceX() / 3.0, ui.frameHeight()), loadFlags)

    ui.sameLine()
    local saveText = "💾 Save"
    local saveFlags = ui.ButtonFlags.None
    if saveFeedbackStart ~= -1 then
        if ui.time() - saveFeedbackStart > 1.0 then
            saveFeedbackStart = -1
        else
            ui.setNextTextBold()
            saveText = "Saved!"
            saveFlags = ui.ButtonFlags.Disabled
        end
    end
    local saveClicked = ui.button(saveText, tmpVec1:set(ui.availableSpaceX() / 2.0, ui.frameHeight()), saveFlags)

    ui.sameLine()
    local deleteText = "❌ Delete"
    local deleteFlags = ui.ButtonFlags.None
    if deleteFeedbackStart ~= -1 then
        if ui.time() - deleteFeedbackStart > 1.0 then
            deleteFeedbackStart = -1
        else
            ui.setNextTextBold()
            deleteText = "Deleted!"
            deleteFlags = ui.ButtonFlags.Disabled
        end
    end
    local deleteClicked = ui.button(deleteText, tmpVec1:set(ui.availableSpaceX(), ui.frameHeight()), deleteFlags)

    if saveClicked and currentPresetName:len() > 0   then if savePreset(currentPresetName)   then saveFeedbackStart = ui.time() end end
    if loadClicked and currentPresetName:len() > 0   then if loadPreset(currentPresetName)   then loadFeedbackStart = ui.time() end end
    if deleteClicked and currentPresetName:len() > 0 then if deletePreset(currentPresetName) then deleteFeedbackStart = ui.time() end end

    ui.text("Saved presets:")

    local presetNames = getPresetList()

    ui.childWindow("presetList", tmpVec1:set(ui.availableSpaceX(), ui.windowHeight() - ui.getCursorY() - ui.StyleVar.WindowPadding), false, ui.WindowFlags.NoTitleBar + ui.WindowFlags.NoMove + ui.WindowFlags.NoResize, function ()
        -- ui.alignTextToFramePadding()
        showDummyLine(0.0)
        for _, preset in ipairs(presetNames) do
            local isSelected = (preset == currentPresetName or (string.startsWith(preset, "*") and string.sub(preset, 2) == currentPresetName))
            if isSelected then ui.setNextTextBold() end
            if ui.selectable(preset, isSelected) then
                currentPresetName = preset:gsub("%*", "")
            end
        end
        return 0
    end)

    popStyle()
    ui.setCursor(tmpVec1:set(270 - 20, 0))
    if ui.button("x", tmpVec1:set(20, 20)) then
        togglePresetsWindow()
    end
    pushStyle()

    ui.endToolWindow()
end

function script.windowMain(dt)
    if not uiData._appCanRun then
        if ac.getPatchVersionCode() < 2651 then
            ui.pushStyleColor(ui.StyleColor.Text, rgbm(1.0, 0.0, 0.0, 1.0))
            ui.textWrapped("Update CSP to 0.2.0 or newer!\nOlder versions are not supported anymore.")
            ui.popStyleColor(1)
        elseif not lib.clampEased then
            ui.textWrapped("Advanced Gamepad Assist is not installed!")
        else
            ui.textWrapped("Advanced Gamepad Assist is currently not enabled!")
            local currentClock = os.clock()
            if (currentClock - enableClicked) >= 3.0 then
                showDummyLine()
                showButton("Enable", nil, enableScript)
            end
        end

        return
    end

    pushStyle()
    -- ui.pushStyleColor(ui.StyleColor.Border, black)
    -- ui.pushStyleVar(ui.StyleVar.WindowBorderSize, 1)

    showHeader("General:")

    showCheckbox("assistEnabled", "Enable Advanced Gamepad Assist")
    showButton("Re-calibrate steering", "calibration", sendRecalibrationEvent)
    showButton(presetsWindowEnabled and "Hide presets" or "Show presets", "presets", togglePresetsWindow)
    showCheckbox("useFilter", "Simplified settings", false)

    if uiData.useFilter then
        showConfigSlider("filterSetting", "Steering assistance", "%.f%%", 0.0, 100.0, 100.0)
    else
        showDummyLine()
    end

    showHeader("Steering input:")

    showConfigSlider("steeringRate",             "Steering rate",               "%.f%%",    0.0, 100.0, 100.0)
    showConfigSlider("rateIncreaseWithSpeed",    "Steering rate at speed",      "%+.f%%", -50.0,  50.0, 100.0, uiData.useFilter)
    showConfigSlider("targetSlip",               "Target slip angle",           "%.1f%%",  90.0, 110.0, 100.0, uiData.useFilter)
    showConfigSlider("countersteerResponse",     "Countersteer response",       "%.f%%",    0.0, 100.0, 100.0, uiData.useFilter)
    showConfigSlider("maxDynamicLimitReduction", "Max dynamic limit reduction", "%.1f°",    0.0,  10.0,   1.0, uiData.useFilter)

    showHeader("Self-steer force:")

    showConfigSlider("selfSteerResponse", "Response",  "%.f%%", 0.0, 100.0, 100.0, uiData.useFilter)
    showConfigSlider("maxSelfSteerAngle", "Max angle", "%.1f°", 0.0,  90.0,   1.0, uiData.useFilter)
    showConfigSlider("dampingStrength",   "Damping",   "%.f%%", 0.0, 100.0, 100.0, uiData.useFilter)

    showDummyLine(1.0)
    ui.alignTextToFramePadding()
    ui.textWrapped("Tip: hold SHIFT to fine-tune sliders, or CTRL-click them to edit the values!")

    -- ui.pushFont(ui.Font.Tiny)
    -- showDummyLine(0.5)
    -- ui.alignTextToFramePadding()
    -- ui.textAligned("v0.6b", tmpVec1:set(0.5 - (29 / ui.windowWidth()), 0), tmpVec2:set(ui.windowWidth(), 0))
    -- ui.popFont()

    if uiData.graphSelection > 1 then
        drawSelfSteerCurve()
        if uiData.graphSelection == 3 then
            drawLimitReductionBar()
            drawFrontSlipBar()
            drawRearSlipBar()
        end
    end

    if presetsWindowEnabled then drawPresetsWindow() end

    popStyle()
end

local resetClicked = 0
function script.windowSettings(dt)
    if not uiData._appCanRun then return end

    pushStyle()

    uiData.graphSelection = showCompactDropdown("Graphs", "graphs", {"None", "Static", "Live"}, uiData.graphSelection, 0)
    uiData.keyboardMode = showCompactDropdown("Keyboard", "keyboardMode", {"Off", "On", "On (brake help)", "On (gas + brake help)"}, uiData.keyboardMode + 1, 0) - 1

    showDummyLine(0.25)

    showCheckbox("autoClutch", "Automatic clutch", false, false, 0)

    showDummyLine(0.25)

    uiData.autoShiftingMode = showCompactDropdown("Shifting mode", "autoShiftingMode", {"Default", "Manual", "Automatic"}, uiData.autoShiftingMode + 1, 0) - 1;
    showCheckbox("autoShiftingCruise", "Auto-switch into cruise mode", false, uiData.autoShiftingMode < 2, 20)
    showConfigSlider("autoShiftingDownBias", "Downshift bias", "%.f%%", 0.0, 90.0, 100.0, false, 200.0, 20, uiData.autoShiftingMode < 2)

    showDummyLine(0.25)

    showConfigSlider("triggerFeedbackL", "Left trigger feedback", "%.f%%", 0.0, 100.0, 100.0, false, 200.0, 0)
    showConfigSlider("triggerFeedbackR", "Right trigger feedback", "%.f%%", 0.0, 100.0, 100.0, false, 200.0, 0)
    showCheckbox("triggerFeedbackAlwaysOn", "Trigger feedback with ABS/TCS", false, false, 0)

    showDummyLine(0.25)

    local reset = showButton(resetClicked > 0 and "⚠️ Confirm?" or "⚠️ Factory reset", "factoryReset", nil, 0)

    if reset then
        if resetClicked > 0.2 then
            factoryReset()
            resetClicked = 0
        elseif resetClicked == 0 then
            resetClicked = resetClicked + dt
        end
    end

    if resetClicked > 3.0 then
        resetClicked = 0
    end

    if resetClicked > 0 then
        resetClicked = resetClicked + dt
    end

    showHeader("Built-in setting shortcuts:")
    addTooltipToLastItem("builtInSettings")

    showConfigSlider("_gameGamma",    "Gamma", "   %.f%%", 100.0, 300.0, 100.0, false, 200.0, 0)
    showConfigSlider("_gameDeadzone", "Deadzone", "%.f%%",   0.0, 100.0, 100.0, false, 200.0, 0)
    showConfigSlider("_gameRumble",   "Rumble",   "%.f%%",   0.0, 100.0, 100.0, false, 200.0, 0)

    popStyle()
end

ac.onSharedEvent("AGA_reloadControlSettings", function ()
    ac.reloadControlSettings()
end)
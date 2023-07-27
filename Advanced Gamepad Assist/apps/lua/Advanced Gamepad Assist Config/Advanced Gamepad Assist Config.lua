local lib = require "../../../extension/lua/joypad-assist/Advanced Gamepad Assist/AGALib"

local uiData = ac.connect{
    ac.StructItem.key("AGAData"),
    _appCanRun               = ac.StructItem.boolean(),
    _localHVelAngle          = ac.StructItem.double(),
    _selfSteerStrength       = ac.StructItem.double(),
    _frontNdSlip             = ac.StructItem.double(),
    _rearNdSlip              = ac.StructItem.double(),
    _limitReduction          = ac.StructItem.double(),
    assistEnabled            = ac.StructItem.boolean(),
    keyboardMode             = ac.StructItem.int32(), -- 0 = disabled, 1 = enabled, 2 = enabled + brake assist, 3 = enabled + throttle and brake assist
    useFilter                = ac.StructItem.boolean(),
    filterSetting            = ac.StructItem.double(),
    steeringRate             = ac.StructItem.double(),
    rateIncreaseWithSpeed    = ac.StructItem.double(),
    selfSteerResponse        = ac.StructItem.double(),
    dampingStrength          = ac.StructItem.double(),
    maxSelfSteerAngle        = ac.StructItem.double(),
    countersteerResponse     = ac.StructItem.double(),
    maxDynamicLimitReduction = ac.StructItem.double()
}

local tooltips = {
    lockedNote               = "Locked. Uncheck 'Simplified settings' to adjust manually!",
    calibration              = "Performs a quick steering calibration, just in case the assist isn't working correctly.\nYou must stop the car before doing this!",
    graphs                   = "Displays useful graphs to visualize what the assist is doing.\nThey can either be static or updated with live values.",
    assistEnabled            = "Enables or disables the assist.\nIf unchecked, AC's built-in input processing is used without alterations.",
    useFilter                = "Provides a single slider that will adjust most settings automatically for you.",
    keyboardMode             = "Enables gas, brake and steering input on keyboard.\nYou can also choose to have brake or gas assistance when ABS or TCS are off. These aren't as good as ABS or TCS, they just somewhat compensate for not having analog input.\nFor every vehicle control to work (like shifting or handbrake), you also have to enable the \"Combine with keyboard\" option in AC's control settings!",
    filterSetting            = "How much steering assistance you want in general.\nNote that 0% does not mean the assist is off, it's just a lower level of assistance.",
    steeringRate             = "How fast the steering is in general.",
    rateIncreaseWithSpeed    = "How much slower or faster the steering will get as you speed up.",
    selfSteerResponse        = "How aggressive the self-steer force will fight to keep the car straight.\nLow = looser feel and easier to oversteer, high = more assistance to prevent oversteer and keep the car stable.",
    dampingStrength          = "Prevents the self-steer force from overcorrecting.\nHigher 'Response' and 'Max angle' settings require more damping to prevent the self-steer force from making the car wobble.",
    maxSelfSteerAngle        = "Caps the self-steer force to a certain steering angle.\nBasically this limits how big of a slide the self-steer can help to recover from.",
    countersteerResponse     = "High = more effective manual countersteering, but also easier to overcorrect a slide.",
    maxDynamicLimitReduction = "How much the steering angle can reduce when the car oversteers while you turn inward, in order to maintain front grip.\nLow = more \"raw\" and more prone to steering too much, high = more assistance to keep front grip in a turn.\nFor the best grip it should be at least as high as the travel angle in a typical turn."
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

local graphSelection = 1

local function addTooltipToLastItem(tooltipKey)
    if ui.itemHovered() and tooltipKey and tooltips[tooltipKey] then
        ui.setTooltip(tooltips[tooltipKey])
    end
end

local function showCheckbox(cfgKey, name, inverted)
    local val = not uiData[cfgKey]
    if not inverted then val = not val end
    ui.offsetCursorX(sectionPadding)
    if ui.checkbox(name, val) then
        uiData[cfgKey] = not uiData[cfgKey]
    end
    addTooltipToLastItem(cfgKey)
end

local function showConfigSlider(cfgKey, name, format, minVal, maxVal, valueMult, locked, onHover, hoverOnInteract)
    local displayVal = uiData[cfgKey] * valueMult
    if locked then
        ui.offsetCursorX(sectionPadding)
        local cursorOld = ui.getCursor()
        ui.drawRectFilled(cursorOld, tmpVec1:set(cursorOld.x + ui.availableSpaceX() - sectionPadding, cursorOld.y + ui.frameHeight()), lockedSliderColor)
        ui.setCursorX(cursorOld.x)
        ui.textAligned(string.format(name .. ": " .. format, displayVal), tmpVec1:set(0.5, 0.5), tmpVec2:set(ui.availableSpaceX() - sectionPadding, ui.frameHeight()))
        ui.setCursor(cursorOld)
        ui.setItemAllowOverlap()
        ui.invisibleButton("##" .. cfgKey, tmpVec1:set(ui.availableSpaceX() - sectionPadding, ui.frameHeight()))
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
        ui.offsetCursorX(sectionPadding)
        ui.setNextItemWidth(ui.availableSpaceX() - sectionPadding)
        local value, changed = ui.slider("##" .. cfgKey, displayVal, minVal, maxVal, name .. ": " .. format)
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

local function showButton(text, tooltipKey, callback)
    ui.offsetCursorX(sectionPadding)
    ui.button(text, tmpVec1:set(ui.availableSpaceX() - sectionPadding, ui.frameHeight()))
    addTooltipToLastItem(tooltipKey)
    if ui.itemClicked(ui.MouseButton.Left) then callback() end
end

local function showCompactDropdown(label, tooltipKey, values, selectedIndex)
    ui.offsetCursorX(sectionPadding)
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
    return lib.clampEased(correctionBase, -uiData.maxSelfSteerAngle, uiData.maxSelfSteerAngle, selfSteerCapT) * ((graphSelection == 3) and uiData._selfSteerStrength or 1.0)
end

local function drawSelfSteerCurve()
    local liveAngle = (graphSelection == 3) and math.abs(uiData._localHVelAngle) or nil
    showGraph("Self-steer force\n(damping force not included)", vec2(ui.windowPos().x + ui.windowWidth(), ui.windowPos().y), vec2(300, 300), "Travel angle (degrees)", "Self-steer (degrees)", 0.0, 60.0, 0.0, 60.0, 10.0, 10.0, uiData.assistEnabled and selfSteerCurveCallback or nil, uiData.assistEnabled and liveAngle or nil, 3)
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

function script.windowMain(dt)
    if not uiData._appCanRun then
        ui.textWrapped("Advanced Gamepad Assist is currently not active!")
        return
    end

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
    -- ui.pushStyleColor(ui.StyleColor.Border, black)
    -- ui.pushStyleVar(ui.StyleVar.WindowBorderSize, 1)

    showHeader("General:")

    showButton("Re-calibrate steering", "calibration", sendRecalibrationEvent)
    graphSelection = showCompactDropdown("Graphs", "graphs", {"None", "Static", "Live"}, graphSelection)
    showCheckbox("assistEnabled", "Enable Advanced Gamepad Assist")
    uiData.keyboardMode = showCompactDropdown("Keyboard", "keyboardMode", {"Off", "On", "On (brake help)", "On (gas + brake help)"}, uiData.keyboardMode + 1) - 1
    showCheckbox("useFilter", "Simplified settings", false)

    if uiData.useFilter then
        showConfigSlider("filterSetting", "Steering assistance", "%.f%%", 0.0, 100.0, 100.0)
    else
        showDummyLine()
    end

    showHeader("Steering input:")

    showConfigSlider("steeringRate",             "Steering rate",           "%.f%%",    0.0, 100.0, 100.0)
    showConfigSlider("rateIncreaseWithSpeed",    "Steering rate at speed",  "%+.f%%", -50.0,  50.0, 100.0, uiData.useFilter)
    showConfigSlider("countersteerResponse",     "Countersteer response",   "%.f%%",    0.0, 100.0, 100.0, uiData.useFilter)
    showConfigSlider("maxDynamicLimitReduction", "Dynamic limit reduction", "%.1f°",    0.0,  10.0,   1.0, uiData.useFilter)

    showHeader("Self-steer force:")

    showConfigSlider("selfSteerResponse", "Response",  "%.f%%", 0.0, 100.0, 100.0, uiData.useFilter)
    showConfigSlider("maxSelfSteerAngle", "Max angle", "%.1f°", 0.0,  90.0,   1.0, uiData.useFilter)
    showConfigSlider("dampingStrength",   "Damping",   "%.f%%", 0.0, 100.0, 100.0, uiData.useFilter)

    showDummyLine(0.5)
    ui.alignTextToFramePadding()
    ui.textWrapped("Tip: hold SHIFT to fine-tune sliders, or CTRL-click them to edit the values!")

    -- ui.pushFont(ui.Font.Tiny)
    -- showDummyLine(0.5)
    -- ui.alignTextToFramePadding()
    -- ui.textAligned("v0.6b", tmpVec1:set(0.5 - (29 / ui.windowWidth()), 0), tmpVec2:set(ui.windowWidth(), 0))
    -- ui.popFont()

    if graphSelection > 1 then
        drawSelfSteerCurve()
        if graphSelection == 3 then
            drawLimitReductionBar()
            drawFrontSlipBar()
            drawRearSlipBar()
        end
    end

    -- ui.popStyleVar(1)
    ui.popStyleColor(9)
    ui.popFont()
end
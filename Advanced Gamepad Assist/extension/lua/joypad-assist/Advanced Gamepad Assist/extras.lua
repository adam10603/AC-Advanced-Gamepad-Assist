local lib = require "AGALib"

local M = {}

M.kbThrottleTarget = 1.0
M.brakeNdUsed      = 0.0
M.throttleNdUsed   = 0.0

-- Config
local maxAllowedUpshiftRPM   = 0.998
local maxAllowedDownshiftRPM = 0.995
local gearOverrideTime       = 1.5
local autoShiftCheckDelay    = 0.2
local gearSetCheckDelay      = 0.05 -- Has to be lower than the above

-- State
local autoClutchRaw          = false
local rawClutchEngagedTime   = 0.0
local autoClutchSmoother     = lib.SmoothTowards:new(10.0, 0.01, 0.0, 1.0, 0.0)
local RPMChangeRateSmoother  = lib.SmoothTowards:new(5.0, 0.01, 0.0, 1.0, 0.0)
local gAccelSmoother         = lib.SmoothTowards:new(20.0, 0.01, -1.0, 1.0, 0.0)
local prevRPM                = 0.0
local safeSpeedElapsed       = 0.0

local clutchTarget           = 0.0
local clutchEngagedBiasRaw   = false
local clutchEngagedBias      = lib.SmoothTowards:new(2.0, 1.0, 0.00, 1.0, 0.0)
local clutchFreeze           = false
local hbClutchSmoother       = lib.SmoothTowards:new(20.0, 0.1, 0.0, 1.0, 0.0)
local driftIndicatorSmoother = lib.SmoothTowards:new(1.8, 1.0, 0.0, 1.0, 0.0) -- 1.8 if >0

local clutchController       = lib.PIDController:new(3.5, 7.0, 0.0, true, 0.0, 1.0)
local revMatchController     = lib.PIDController:new(1.0, 100.0, 0.0, false, 0.0, 1.0) -- 8 5

local tSinceUpshift          = 0.0
local tSinceDownshift        = 0.0
local requestedGear          = 0 -- Only used for H shifters

local gearOverride           = nil -- Automatic shifting will not happen while this object exists
local downshiftProtectedGear = 0 -- After a gear override expires, a gear can still be partially protected from automatic downshifts if it was manually shifted up into
local RPMFallTime            = 0.0 -- How long the RPM has been decreasing for
local prevGearUp             = false
local prevGearDown           = false
local tSinceHighGearBurnoutStopped = 9999 -- Workaround for a very specific issue

local clutchSampleTimer      = 0.0
local canUseClutch           = true
local clutchSampled          = false

local gearData = {} -- Contains gear change RPMs for each gear except last

local function sanitize01Input(value)
    return lib.numberGuard(math.clamp(value, 0, 1))
end

local function getReferenceWheelIndicies(vData)
    return (vData.vehicle.tractionType == 1) and { 0, 1 } or { 2, 3 }
end

local function getWheels(indicies, vData)
    return { vData.vehicle.wheels[indicies[1]], vData.vehicle.wheels[indicies[2]] }
end

local function getPredictedRPM(speed, vData, drivetrainRatio)
    drivetrainRatio = drivetrainRatio or vData.drivetrainRatio
    local referenceWheels = getWheels(getReferenceWheelIndicies(vData), vData)
    local wheelDiameter = (referenceWheels[1].tyreRadius + referenceWheels[2].tyreRadius)
    return speed / (math.pi * wheelDiameter) * 60.0 * drivetrainRatio
end

local function getNormalizedRPM(rpm, vData)
    return math.lerpInvSat(rpm, vData.idleRPM, vData.maxRPM)
end

local function getAbsoluteRPM(normalizedRPM, vData)
    return math.lerp(vData.idleRPM, vData.maxRPM, normalizedRPM)
end

local function getPredictedSpeedForRPM(rpm, vData, drivetrainRatio)
    drivetrainRatio = drivetrainRatio or vData.drivetrainRatio
    local referenceWheels = getWheels(getReferenceWheelIndicies(vData), vData)
    local wheelDiameter = (referenceWheels[1].tyreRadius + referenceWheels[2].tyreRadius)
    return (rpm * math.pi * wheelDiameter) / (60.0 * drivetrainRatio)
end

local function clampGear(nGear, vData)
    return math.clamp(nGear, -1, vData.vehicle.gearCount)
end

local function getGearRatio(nGear, vData)
    return vData.cPhys.gearRatios[nGear + 1] or math.NaN
end

local function getDriveTrainRatioForGear(nGear, vData)
    return getGearRatio(nGear, vData) * vData.cPhys.finalRatio
end

local function getRPMInGear(nGear, vData, currentRPM)
    currentRPM = currentRPM or vData.vehicle.rpm
    return getGearRatio(nGear, vData) / getGearRatio(vData.vehicle.gear, vData) * currentRPM
end

local function getMaxTQ(rpm, gear, vData)
    local baseTorque = vData.baseTorqueCurve:get(rpm)

    local totalBoost = 0.0
    for _, turbo in ipairs(vData.turboData) do
        local tBoost = 0.0
        if turbo.controllerInput == "RPMS" then
            turbo.controllerLUT.useCubicInterpolation = true
            tBoost = tBoost + turbo.controllerLUT:get(rpm)
        elseif turbo.controllerInput == "GEAR" then
            turbo.controllerLUT.useCubicInterpolation = false
            tBoost = tBoost + turbo.controllerLUT:get(gear)
        else
            tBoost = tBoost + (rpm / turbo.referenceRPM) ^ turbo.gamma
        end
        totalBoost = totalBoost + math.min(tBoost, turbo.boostLimit)
    end

    return baseTorque * (1.0 + totalBoost)
end

local function getMaxHP(rpm, gear, vData)
    return getMaxTQ(rpm, gear, vData) * rpm / 5252.0
end

local function calcShiftingTable(vData)
    local minRPM = getAbsoluteRPM(0.1, vData)
    local maxShiftRPM = getAbsoluteRPM(maxAllowedUpshiftRPM, vData)

    for gear = 1, vData.vehicle.gearCount - 1, 1 do
        local bestArea = 0
        local bestUpshiftRPM = 0
        local areaSkew = math.lerp(0.9, 1.4, (gear - 1) / (vData.vehicle.gearCount - 2))
        local nextOverCurrentRatio = getGearRatio(gear + 1, vData) / getGearRatio(gear, vData)
        for i = 0, 200, 1 do
            local upshiftRPM = getAbsoluteRPM(i / 200.0, vData)
            local nextGearRPM = upshiftRPM * nextOverCurrentRatio
            if nextGearRPM > minRPM then
                local area = 0
                for j = 0, 50, 1 do
                    local simRPM = math.lerp(nextGearRPM, upshiftRPM, j / 50.0)
                    area = area + getMaxHP(simRPM, gear, vData) / 50.0 * math.lerp(1.0, areaSkew, (j / 50.0))
                end
                if area > bestArea then
                    bestArea = area
                    bestUpshiftRPM = upshiftRPM
                end
            end
        end
        gearData[gear] = {
            upshiftRPM = math.min(bestUpshiftRPM * ((vData.vehicle.mgukDeliveryCount) > 0 and 1.1 or 1.0), maxShiftRPM),
            gearStartRPM = (gear == 1) and vData.idleRPM or (gearData[gear - 1].upshiftRPM * getGearRatio(gear, vData) / getGearRatio(gear - 1, vData))
        }
    end

    gearData[1].gearStartRPM = (getGearRatio(2, vData) / getGearRatio(1, vData)) * gearData[2].gearStartRPM
end

local gasSampleTimer = 0.0
local gasHistory = lib.ValueLimitsBuffer:new(80)
local function getCruiseFactor(vData, uiData, absInitialSteering, dt)
    if not uiData.autoShiftingCruise then
        if gasHistory:count() > 0 then
            gasHistory:reset()
        end
        return 0.0
    end

    gasSampleTimer = gasSampleTimer + dt

    if gasSampleTimer >= ((absInitialSteering > 0.5 and 0.08 or 0.05)) then -- math.lerp(0.1, 0.15, lib.clamp01(2.0 * absInitialSteering - 1.0))
        gasSampleTimer = 0.0
        if vData.inputData.gas > 0.01 and vData.vehicle.gear > 0 then
            gasHistory:add(lib.clamp01(vData.inputData.gas / M.kbThrottleTarget))
        end
    end

    if gasHistory:count() > 40 then
        local cruiseThreshold = 0.75
        local maxGas = gasHistory:getMax()
        local cruiseFactor = ((maxGas < cruiseThreshold) and ((1.0 - ((gasHistory:getMax() / cruiseThreshold) ^ 2.0)) * 0.7 + 0.3) or 0.0)
        return cruiseFactor
    end

    return 0.0
end

local function updateGearOverride(vData, dt)
    if gearOverride ~= nil then
        gearOverride.timer = gearOverride.timer + dt

        if gearOverride and gearOverride.timer >= gearOverrideTime then
            if gearOverride.shiftedUp then downshiftProtectedGear = vData.vehicle.gear end
            gearOverride = nil
        end
    end

    if vData.inputData.gearUp and not prevGearUp then -- and vData.vehicle.gear < vData.vehicle.gearCount and vData.vehicle.gear > 0
        local newGear = clampGear(requestedGear + 1, vData)
        if newGear ~= requestedGear then
            requestedGear = newGear
            tSinceUpshift = 0.0
            gearOverride = {
                timer = 0.0,
                shiftedUp = true
            }
        end
    elseif vData.inputData.gearDown and not prevGearDown then -- and vData.vehicle.gear > 1
        local newGear = clampGear(requestedGear - 1, vData)
        if newGear ~= requestedGear then
            requestedGear = newGear
            tSinceDownshift = 0.0
            gearOverride = {
                timer = 0.0,
                shiftedUp = false
            }
        end
    end

    prevGearUp   = vData.inputData.gearUp
    prevGearDown = vData.inputData.gearDown
end

local mismatchTime = 0.0
local function requestGear(vData, dt)
    if vData.vehicle.gear ~= requestedGear then
        mismatchTime = mismatchTime + dt
    else
        mismatchTime = 0.0
    end

    if mismatchTime > (math.max(vData.shiftUpTime, vData.shiftDownTime) + 0.2) then
        requestedGear = vData.vehicle.gear
    end

    vData.inputData.gearUp   = false
    vData.inputData.gearDown = false

    if canUseClutch then
        if requestedGear > vData.vehicle.gear and tSinceUpshift > (vData.shiftUpTime + gearSetCheckDelay) then
            tSinceUpshift = 0.0
        elseif requestedGear < vData.vehicle.gear and tSinceDownshift > (vData.shiftDownTime + gearSetCheckDelay) then
            tSinceDownshift = 0.0
        end

        vData.inputData.requestedGearIndex = requestedGear + 1
    else
        if requestedGear > vData.vehicle.gear and tSinceUpshift > (vData.shiftUpTime + gearSetCheckDelay) then
            tSinceUpshift          = 0.0
            vData.inputData.gearUp = true
        elseif requestedGear < vData.vehicle.gear and tSinceDownshift > (vData.shiftDownTime + gearSetCheckDelay) then
            tSinceDownshift          = 0.0
            vData.inputData.gearDown = true
        end
    end
end

local function getDownshiftThresholdRPM(g, minAllowedRPM, absDownshiftLimit, downshiftBiasUsed, cruiseFactor)
    return math.lerp(minAllowedRPM, math.lerp(gearData[g].gearStartRPM, math.min(gearData[g].upshiftRPM, absDownshiftLimit), downshiftBiasUsed), 1.0 - (cruiseFactor * 0.75))
end

local function getUpshiftThresholdRPM(g, minAllowedRPM, cruiseFactor)
    return math.lerp(minAllowedRPM, gearData[g - 1].upshiftRPM, 1.0 - (cruiseFactor * 0.75))
end

-- local dragStart = 0.0
local slowLogTimer = 0.0
local errorShown1 = false -- Bad car data
local errorShown2 = false -- Clutch cant be ussed for this car
local errorShown3 = false -- Disable auto shifting in AC

M.update = function(vData, uiData, absInitialSteering, dt)

    if vData.baseTorqueCurve ~= nil then
        if slowLogTimer >= 0.012 then
            ac.debug("L) Drivertrain power [HP]", vData.vehicle.drivetrainPower, 0.0, math.ceil(getMaxHP(getAbsoluteRPM(0.85, vData), 2, vData) * 0.8 * ((vData.vehicle.mgukDeliveryCount > 0) and 1.75 or 1.0) / 100.0) * 100.0)
            slowLogTimer = 0.0
        else
            slowLogTimer = slowLogTimer + dt
        end
    end

    -- Determining if the clutch can be controlled on this car

    if not clutchSampled then
        clutchSampleTimer = clutchSampleTimer + dt
        if clutchSampleTimer < 0.05 then
            vData.inputData.clutch = 0.00069
            return
        else
            canUseClutch = (math.abs(vData.vehicle.clutch - 0.00069) < 0.000001)
            clutchSampled = true
        end

        requestedGear = vData.vehicle.gear
    end

    -- Wheel data that is used by every part of the script

    local referenceWheels    = getReferenceWheelIndicies(vData)
    local referenceWheelData = getWheels(referenceWheels, vData)
    local wheelVelRatio1     = math.clamp((referenceWheelData[1].angularSpeed * referenceWheelData[1].tyreRadius) / lib.signClampValue(vData.localWheelVelocities[referenceWheels[1]].z, lib.zeroGuard(vData.cPhys.gearRatio)), -9999, 9999) -- Around 1.0 when driving normally, >1.0 when getting wheelspin, <1.0 when locking up
    local wheelVelRatio2     = math.clamp((referenceWheelData[2].angularSpeed * referenceWheelData[2].tyreRadius) / lib.signClampValue(vData.localWheelVelocities[referenceWheels[2]].z, lib.zeroGuard(vData.cPhys.gearRatio)), -9999, 9999) -- Around 1.0 when driving normally, >1.0 when getting wheelspin, <1.0 when locking up

    -- ================================ Vibration

    if (uiData.triggerFeedbackL > 0.0 or uiData.triggerFeedbackR > 0.0) and vData.inputData.gamepadType == ac.GamepadType.XBox and vData.localHVelLen > 0.5 then
        local xbox = ac.setXbox(vData.inputData.gamepadIndex, 1000, dt * 3.0)

        if xbox ~= nil then
            -- xbox.triggerLeft  = (M.brakeNdUsed    > 0.8 and vData.inputData.brake > 0.3) and (math.lerpInvSat(M.brakeNdUsed,    0.8, 1.3) * uiData.triggerFeedbackL) or 0.0 -- With + 0.1
            -- xbox.triggerRight = (M.throttleNdUsed > 0.9 and vData.inputData.gas   > 0.3) and (math.lerpInvSat(M.throttleNdUsed, 0.9, 1.4) * uiData.triggerFeedbackR) or 0.0

            -- Checking wheel velocity ratios to avoid vibrating both triggers at the same time
            local actualBrakeNd = (wheelVelRatio1 > 1.1 or wheelVelRatio2 > 1.1) and 0.0 or M.brakeNdUsed
            local actualThrottleNd = (actualBrakeNd == 0) and M.brakeNdUsed or 0.0

            xbox.triggerLeft  = (actualBrakeNd > 0.65 and vData.inputData.brake > 0.2 and vData.vehicle.absMode == 0) and ((actualBrakeNd < 0.9 and 0.2 or (math.lerpInvSat(actualBrakeNd, 0.9, 1.3) * 0.8 + 0.2)) * uiData.triggerFeedbackL) or 0.0
            xbox.triggerRight = (actualThrottleNd > 0.7 and vData.inputData.gas > 0.2 and vData.vehicle.tractionControlMode == 0) and ((actualThrottleNd < 0.9 and 0.2 or (math.lerpInvSat(actualThrottleNd, 0.9, 1.3) * 0.8 + 0.2)) * uiData.triggerFeedbackR) or 0.0
        end
    end

    if not uiData.autoClutch and not uiData.autoShifting then return end -- Quit here if none of these are enabled

    -- ================================ Values used by both the auto clutch and auto shifting

    local normalizedRPM          = math.lerpInvSat(vData.vehicle.rpm, vData.idleRPM, vData.maxRPM) -- 0.0 is idle, 1.0 is max rpm
    local relevantSpeed          = lib.signClampValue(vData.localVel.z, lib.zeroGuard(vData.cPhys.gearRatio)) -- The local forward speed of the car if it matches the sign of the current gear ratio, otherwise 0
    local RPMChangeRate          = RPMChangeRateSmoother:get(((vData.vehicle.rpm - prevRPM) / vData.RPMRange) / dt, dt) -- RPM / s
    local smoothGAccel           = gAccelSmoother:get(vData.vehicle.acceleration.z, dt) -- Forward acceleration of the car, slightly filtered to avoid noise
    local currentDrivetrainRatio = getDriveTrainRatioForGear(vData.vehicle.gear, vData)
    local safeSpeedNorm          = lib.clamp01(relevantSpeed / getPredictedSpeedForRPM(getAbsoluteRPM(0.2, vData), vData, currentDrivetrainRatio))
    local safeSpeedNormAbs       = lib.clamp01(vData.localHVelLen / getPredictedSpeedForRPM(getAbsoluteRPM(0.2, vData), vData, currentDrivetrainRatio))
    local crawlSpeedNorm         = lib.clamp01(relevantSpeed / getPredictedSpeedForRPM(vData.idleRPM, vData, currentDrivetrainRatio)) -- Theoretical speed at idle
    prevRPM                      = vData.vehicle.rpm

    if safeSpeedNormAbs > 0.999 then
        safeSpeedElapsed = safeSpeedElapsed + dt
    else
        safeSpeedElapsed = 0.0
    end

    -- ================================ Auto clutch

    if uiData.autoClutch then

        if vData.brokenEngineIni then
            if not errorShown1 then
                ac.setMessage("Advanced Gamepad Assist", "Error reading engine data. Automatic clutch and shifting will be disabled.")
                errorShown1 = true
            end
        elseif not canUseClutch then
            if not errorShown2 then
                ac.setMessage("Advanced Gamepad Assist", "Custom auto-clutch will not be used for this car.")
                errorShown2 = true
            end
        else

            local minSpeedNorm = lib.clamp01(relevantSpeed / getPredictedSpeedForRPM(vData.idleRPM * 0.8, vData, currentDrivetrainRatio)) -- Only drops below 1.0 if the engine is about to stall
            local notLaunching = vData.vehicle.brake >= 0.01 or vData.vehicle.handbrake >= 0.01 or vData.inputData.gas <= 0.01 or vData.vehicle.gear == 0 -- True if the launch has been aborted

            if normalizedRPM > 0.1 and vData.inputData.gas > 0.01 and vData.inputData.brake < 0.01 and vData.inputData.handbrake < 0.01 then
                autoClutchRaw = true
            end

            if normalizedRPM < 0.05 and minSpeedNorm < 1.0 then
                autoClutchRaw = false
            end

            if vData.vehicle.tractionControlInAction then clutchFreeze = true end -- // FIXME this doesn't really work

            if (crawlSpeedNorm > 0.9999) then clutchEngagedBiasRaw = true end
            local currentEngagedBias = clutchEngagedBias:getWithRateMult(clutchEngagedBiasRaw and 1.0 or 0.0, dt, (vData.vehicle.gas ^ 1.5) * 0.8 + 0.2) ^ 2.0

            local clutchStateOverride = (minSpeedNorm < 1.0) and 0.0 or 1.0

            if autoClutchRaw then
                rawClutchEngagedTime = rawClutchEngagedTime + dt

                local RPMTarget = math.lerp(0.7, 0.2, safeSpeedNorm) * math.sqrt(vData.vehicle.gas)

                clutchController:setSetpoint(RPMTarget)
                local newTarget = clutchTarget
                if not clutchFreeze and not notLaunching then newTarget = clutchController:get(math.lerp(normalizedRPM, RPMTarget, currentEngagedBias), dt) end

                newTarget = lib.clamp01(newTarget - (1.0 - M.kbThrottleTarget)) -- // FIXME not the best workaround
                clutchTarget = notLaunching and clutchStateOverride or newTarget
                -- ac.debug("_ENGAGED_BIAS", currentEngagedBias, 0.0, 1.0)
                clutchTarget = math.lerp(clutchTarget, 1.0, currentEngagedBias)
            else
                rawClutchEngagedTime = 0
                clutchTarget = 0.0
                clutchEngagedBias:reset()
                clutchController:reset()
                clutchEngagedBiasRaw = false
                if not vData.vehicle.tractionControlInAction then clutchFreeze = false end
            end

            local autoClutchRate = (clutchTarget < autoClutchSmoother.state) and math.clamp((((vData.idleRPM * 0.8) / vData.vehicle.rpm - 1.0) * 40.0 + 1.0) * 0.5, 0.5, 20.0) or 100.0
            local autoClutchVal  = autoClutchSmoother:getWithRateMult(clutchTarget, dt, autoClutchRate)

            if vData.vehicle.tractionType ~= 1 and vData.vehicle.handbrake > 0.01 then
                vData.inputData.clutch = hbClutchSmoother:get(lib.clamp01(-2.0 * vData.vehicle.handbrake + 1.0), dt)
                clutchTarget = clutchStateOverride
            else
                hbClutchSmoother.state = vData.inputData.clutch
            end

            if vData.inputData.clutch < autoClutchVal then
                clutchTarget = clutchStateOverride
            end

            vData.inputData.clutch = math.min(vData.inputData.clutch, autoClutchVal)

        end
    end

    -- ================================ Auto shifting

    if vData.vehicle.gearCount < 2 or not uiData.autoShifting then
        return
    end

    if not vData.baseTorqueCurve then
        if not errorShown1 then
            ac.setMessage("Advanced Gamepad Assist", "Error reading engine data. Automatic shifting will be disabled.")
            errorShown1 = true
        end
        return
    end

    if vData.vehicle.autoShift then
        if not errorShown3 then
            ac.setMessage("Advanced Gamepad Assist", "Disable AC's automatic shifting for the custom auto-shifting to work!")
            errorShown3 = true
        end
        return
    end

    if #gearData == 0 then
        calcShiftingTable(vData)
    end

    -- local predictedRPM            = getPredictedRPM(relevantSpeed, vData)
    -- local predictedRPMError       = math.clamp(lib.numberGuard(vData.vehicle.rpm / predictedRPM, 9999), -9999, 9999)

    local referenceWheelsGrounded = (referenceWheelData[1].loadK > 0.0 or referenceWheelData[2].loadK > 0.0)

    tSinceDownshift = tSinceDownshift + dt
    tSinceUpshift   = tSinceUpshift + dt

    local prevRequestedGear = requestedGear

    updateGearOverride(vData, dt)
    local cruiseFactor = getCruiseFactor(vData, uiData, absInitialSteering, dt)

    local avoidDownshift = false -- Protects gears that were manually shifted up into

    if not gearOverride and downshiftProtectedGear == vData.vehicle.gear then -- and not cruiseJustOff
        if RPMChangeRate < 0.02 and safeSpeedElapsed > 0.5 and vData.inputData.clutch > 0.999 then
            RPMFallTime = RPMFallTime + dt
        else
            RPMFallTime = 0.0
        end
        avoidDownshift = (normalizedRPM > 0.05 and RPMFallTime < 1.0)
    else
        downshiftProtectedGear = 0
        RPMFallTime = 0.0
    end

    -- ac.debug("_safeSpeedElapsed", safeSpeedElapsed)

    -- Avoiding gear changes for a small amount of time after ending a drift, in order to allow for direction changes maintaining the same gear
    local burnoutRaw = (wheelVelRatio1 >= 1.1 or wheelVelRatio2 >= 1.1) and vData.inputData.gas > 0.5 and vData.vehicle.gear > 0
    local driftValue = driftIndicatorSmoother:get((burnoutRaw and math.abs(lib.numberGuard(math.deg(math.atan2(vData.rAxleLocalVel.x, vData.rAxleLocalVel.z)))) > 15.0 and vData.localHVelLen > 0.5) and 1.0 or 0.0, dt)
    local driftingProbably = driftValue > 0.0

    if not ((burnoutRaw or driftingProbably) and vData.inputData.gas > 0.5 and vData.vehicle.gear > 1) then
        tSinceHighGearBurnoutStopped = tSinceHighGearBurnoutStopped + dt
    else
        tSinceHighGearBurnoutStopped = 0.0
    end

    if not gearOverride then

        local canShiftUp = false
        if vData.vehicle.gear > 0 and vData.vehicle.gear < vData.vehicle.gearCount then
            canShiftUp = tSinceDownshift > 0.6 and tSinceUpshift > (vData.shiftUpTime + autoShiftCheckDelay) and (wheelVelRatio1 < 1.1 and wheelVelRatio2 < 1.1 and wheelVelRatio1 > 0.9 and wheelVelRatio2 > 0.9) and referenceWheelsGrounded and vData.vehicle.clutch > 0.999 and not driftingProbably
        end

        local canShiftDown = false
        if vData.vehicle.gear > 1 then
            canShiftDown = (tSinceUpshift > 0.6 or vData.inputData.brake > 0.2) and tSinceDownshift > (vData.shiftDownTime + autoShiftCheckDelay) and not avoidDownshift and referenceWheelsGrounded and not ((driftingProbably or burnoutRaw) and normalizedRPM > 0.5) and (vData.vehicle.clutch > 0.999 or safeSpeedElapsed > 1.0 or tSinceHighGearBurnoutStopped < ((vData.vehicle.gearCount - 1) * (vData.shiftDownTime + autoShiftCheckDelay + 0.05)))
        end

        local downshiftBiasUsed = math.lerp(uiData.autoShiftingDownBias, uiData.autoShiftingDownBias * 0.7, vData.inputData.gas)
        local absDownshiftLimit = getAbsoluteRPM(maxAllowedDownshiftRPM, vData)
        local minAllowedRPM     = getAbsoluteRPM(0.01, vData)

        if canShiftUp then
            -- Finding the best gear to upshift into
            local targetGear = requestedGear
            local extRPM = normalizedRPM + RPMChangeRate * dt -- extrapolated RPM to be safe
            local absExtRPM = getAbsoluteRPM(extRPM, vData)
            for g = clampGear(requestedGear + 1, vData), vData.vehicle.gearCount, 1 do
                local refRPM = getRPMInGear(g - 1, vData, absExtRPM)
                if refRPM >= getUpshiftThresholdRPM(g, minAllowedRPM, cruiseFactor) then
                    targetGear = g
                end
                if not canUseClutch or not vData.vehicle.hShifter then break end -- Only check 1 gear without H-shifter
            end
            requestedGear = targetGear
        end

        if canShiftDown and prevRequestedGear == requestedGear then
            -- Finding the best gear to downshift into
            local targetGear = requestedGear
            for g = clampGear(requestedGear - 1, vData), 1, -1 do
                local refRPM = getRPMInGear(g, vData, getPredictedRPM(vData.localHVelLen, vData)) -- // FIXME maybe not good
                if refRPM <= getDownshiftThresholdRPM(g, minAllowedRPM, absDownshiftLimit, downshiftBiasUsed, cruiseFactor) then
                    targetGear = g
                end
                if not canUseClutch or not vData.vehicle.hShifter then break end -- Only check 1 gear without H-shifter
            end
            requestedGear = targetGear
        end
    end

    -- Need this weird check for semi-automatic cars like the Ferrari 458, but a little weirdness still remains
    -- if not canUseClutch and vData.inputData.gas > 0.0 and requestedGear < prevRequestedGear and requestedGear > -1 then
    --     requestedGear = prevRequestedGear
    -- end

    requestGear(vData, dt) -- was below

    if (tSinceUpshift < vData.shiftUpTime or tSinceDownshift < vData.shiftDownTime) and vData.inputData.clutch > 0.999 then
        vData.inputData.clutch = 0.0
        -- if carNeedsBlip then
        local targetNormalizedRPM = math.clamp(getNormalizedRPM(getPredictedRPM(relevantSpeed, vData, getDriveTrainRatioForGear(requestedGear, vData)), vData) * ((tSinceUpshift < vData.shiftUpTime) and 1.0 or 0.8), 0.0, 0.95)
        revMatchController:setSetpoint(targetNormalizedRPM)
        vData.inputData.gas = revMatchController:get(normalizedRPM, dt)
        -- end
    else
        revMatchController:reset()
    end


    -- ac.debug("_REQ_GEAR", requestedGear, -1, vData.vehicle.gearCount)

    -- ac.debug("_CLUTCH", vData.inputData.clutch, 0.0, 1.0)
    -- ac.debug("_LIMITER", vData.vehicle.isEngineLimiterOn)
    -- ac.debug("_GEAR_DATA", gearData)
    -- ac.debug("_NORMALIZED_RPM", normalizedRPM, 0.0, 1.0)

    -- ac.debug("_W_RATIO1", wheelVelRatio1, 0.0, 2.0)
    -- ac.debug("_W_RATIO2", wheelVelRatio2, 0.0, 2.0)

    -- ac.debug("_GAS", vData.inputData.gas, 0.0, 1.0)
    -- ac.debug("_CRUISE_FACTOR", cruiseFactor, 0.0, 1.0)

    -- ac.debug("_GEAR", vData.vehicle.gear, -1, vData.vehicle.gearCount)
end

ac.onSharedEvent("AGA_factoryReset", function()
    errorShown1 = false
    errorShown2 = false
    errorShown3 = false
end)

ac.onCarJumped(car.index, function (carID)
    requestedGear = car.gear
    -- errorShown2 = false
    errorShown3 = false -- Show this one more often
end)

return M
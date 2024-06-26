local lib = require "AGALib"

local M = {}

-- Kind of ugly to have another script set these but it's ok for now
M.rawThrottle        = 0.0 -- Combined keyboard and controller throttle input, but doesn't include the reduction by the keyboard throttle helper
M.controllerThrottle = 0.0 -- Throttle input from only the controller
M.controllerBrake    = 0.0 -- Brake input from only the controller
M.brakeNdUsed        = 0.0
M.throttleNdUsed     = 0.0

-- Config
local maxAllowedUpshiftRPM   = 0.997 -- Automatic upshifts will never occur higher than this, unless upshifting is not possible at the moment
local maxAllowedDownshiftRPM = 0.99 -- Automatic downshifts will never occur if the predicted RPM in the target gear would be higher than this, and the prediction is based on speed only, so a slightly higher error margin is needed
local gearOverrideTime       = 1.0
local autoShiftCheckDelay    = 0.2
local gearSetCheckDelay      = 0.05 -- Has to be lower than the above
local wheelSpinThreshold     = 1.1
local downshiftClutchFadeT   = 0.05

-- State
local autoClutchRaw          = false
local rawClutchEngagedTime   = 0.0
local autoClutchSmoother     = lib.SmoothTowards:new(10.0, 0.01, 0.0, 1.0, 0.0)
local RPMChangeRateSmoother  = lib.SmoothTowards:new(5.0, 0.01, 0.0, 1.0, 0.0)
local gAccelSmoother         = lib.SmoothTowards:new(25.0, 0.01, -1.0, 1.0, 0.0)
local prevRPM                = 0.0
local safeSpeedElapsed       = 0.0

local clutchTarget           = 0.0
local clutchEngagedBiasRaw   = false
local clutchEngagedBias      = lib.SmoothTowards:new(2.0, 1.0, 0.00, 1.0, 0.0)
local clutchFreeze           = false
local hbClutchSmoother       = lib.SmoothTowards:new(20.0, 0.1, 0.0, 1.0, 0.0)
local driftIndicatorSmoother = lib.SmoothTowards:new(1.8, 1.0, 0.0, 1.0, 0.0) -- 1.8 if >0

local clutchController       = lib.PIDController:new(3.5, 7.0, 0.0, true, 0.0, 1.0)
local revMatchController     = lib.PIDController:new(6.0, 3.0, 0.0, false, 0.0, 1.0) -- 8 5

local tSinceUpshift          = 0.0
local tSinceDownshift        = 0.0
local tSinceDownshiftOver    = 999
local requestedGear          = 0 -- The target gear that the script will attempt to shift into

local gearOverride           = nil -- Automatic shifting will not happen while this object exists
local downshiftProtectedGear = 0 -- After a gear override expires, a gear can still be partially protected from automatic downshifts if it was manually shifted up into
local RPMFallTime            = 0.0 -- How long the RPM has been decreasing for
local prevGearUp             = false
local prevGearDown           = false
local prevCruiseFactor       = 0.0
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
    drivetrainRatio = drivetrainRatio or vData.perfData:getDrivetrainRatio()
    local referenceWheels = getWheels(getReferenceWheelIndicies(vData), vData)
    local wheelDiameter = (referenceWheels[1].tyreRadius + referenceWheels[2].tyreRadius)
    return speed / (math.pi * wheelDiameter) * 60.0 * drivetrainRatio
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
            gasHistory:add(lib.clamp01(M.rawThrottle))
        end
    end

    if gasHistory:count() > 40 then
        local cruiseThreshold = 0.9
        local maxGas = gasHistory:getMax()
        -- local cruiseFactor = ((maxGas < cruiseThreshold) and ((1.0 - ((gasHistory:getMax() / cruiseThreshold) ^ 2.0)) * 0.7 + 0.3) or 0.0)
        local cruiseFactor = ((maxGas < cruiseThreshold) and lib.clamp01(1.0 - ((gasHistory:getMax() / cruiseThreshold) ^ 2.0)) or 0.0)
        return cruiseFactor
    end

    return 0.0
end

-- Reads manual shifting inputs and manages the gear override state
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

local function clearGearOverride()
    gearOverride = nil
    downshiftProtectedGear = 0
end

local mismatchTime = 0.0 -- Counts up while the requested gear does not match the vehicle's current gear
local function requestGear(vData, dt)
    if vData.vehicle.gear ~= requestedGear then
        mismatchTime = mismatchTime + dt
    else
        mismatchTime = 0.0
    end

    if mismatchTime > (math.max(vData.perfData.shiftUpTime, vData.perfData.shiftDownTime) + 0.2) then
        requestedGear = vData.vehicle.gear
    end

    vData.inputData.gearUp   = false
    vData.inputData.gearDown = false

    if canUseClutch then
        -- The clutch has to be disengaged 1 update before the shifting starts

        if requestedGear > vData.vehicle.gear and tSinceUpshift > (vData.perfData.shiftUpTime + gearSetCheckDelay) then
            tSinceUpshift          = -dt
            vData.inputData.gas    = 0.0
            vData.inputData.clutch = 0.0
        elseif requestedGear < vData.vehicle.gear and tSinceDownshift > (vData.perfData.shiftDownTime + gearSetCheckDelay) then
            tSinceDownshift        = -dt
            vData.inputData.gas    = 1.0
            vData.inputData.clutch = 0.0
        end

        if vData.vehicle.clutch < 0.01 then
            vData.inputData.requestedGearIndex = requestedGear + 1
        end
    else
        if requestedGear > vData.vehicle.gear and tSinceUpshift > (vData.perfData.shiftUpTime + gearSetCheckDelay) then
            tSinceUpshift          = 0.0
            vData.inputData.gearUp = true
        elseif requestedGear < vData.vehicle.gear and tSinceDownshift > (vData.perfData.shiftDownTime + gearSetCheckDelay) then
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

local errorShown1 = false -- Bad car data
local errorShown2 = false -- Clutch cant be ussed for this car
local errorShown3 = false -- Disable auto shifting in AC
local errorShown4 = false -- MGU-K warning
-- local dragStart = 0.0

M.update = function(vData, uiData, absInitialSteering, dt)
    -- if vData.localHVelLen < 0.1 then
    --     dragStart = os.clock()
    -- elseif vData.localHVelLen > (250 / 3.6) then
    --     if dragStart > 0.0 then
    --         ac.log(os.clock() - dragStart)
    --     end
    --     dragStart = 0.0
    -- end

    -- Determining if the clutch can be controlled on this car

    if not clutchSampled then
        clutchSampleTimer = clutchSampleTimer + dt
        if clutchSampleTimer < 0.05 then
            vData.inputData.clutch = 0.00069
            return
        else
            canUseClutch = (math.abs(vData.vehicle.clutch - 0.00069) < 1e-5)
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

    if (uiData.triggerFeedbackL > 0.0 or uiData.triggerFeedbackR > 0.0) and vData.localHVelLen > 0.5 then
        local xbox = ac.setXbox(vData.inputData.gamepadIndex, 1000, dt * 3.0)

        if xbox ~= nil then
            -- Checking wheel velocity ratios to avoid vibrating both triggers at the same time
            local wheelspin        = (wheelVelRatio1 > 1.1 or wheelVelRatio2 > 1.1)
            local actualBrakeNd    = wheelspin and 0.0 or M.brakeNdUsed
            local actualThrottleNd = wheelspin and M.brakeNdUsed or 0.0

            local lVibration = 0.0
            local rVibration = 0.0

            if actualBrakeNd > 0.7 and M.controllerBrake > 0.2 and (vData.vehicle.absMode < 1 or uiData.triggerFeedbackAlwaysOn) then
                lVibration = (math.lerpInvSat(actualBrakeNd, 0.9, 1.3) * 0.9 + 0.1) * uiData.triggerFeedbackL
            end

            if actualThrottleNd > 0.7 and M.controllerThrottle > 0.2 and (vData.vehicle.tractionControlMode < 1 or uiData.triggerFeedbackAlwaysOn) then
                rVibration = (math.lerpInvSat(actualThrottleNd, 0.9, 1.3) * 0.9 + 0.1) * uiData.triggerFeedbackR
            end

            xbox.triggerLeft  = lVibration
            xbox.triggerRight = rVibration
        end
    end

    if not uiData.autoClutch and uiData.autoShiftingMode == 0 then return end -- Quit here if none of these are enabled

    -- ================================ Values used by both the auto clutch and auto shifting

    -- // TODO check if vData.cPhys.gearRatio is appropriate, it's the same as the engaged gear

    local normalizedRPM          = vData.perfData:getNormalizedRPM() -- 0.0 is idle, 1.0 is max rpm
    local relevantSpeed          = lib.signClampValue(vData.localVel.z, lib.zeroGuard(vData.cPhys.gearRatio)) -- The local forward speed of the car if it matches the sign of the current gear ratio, otherwise 0
    local RPMChangeRate          = RPMChangeRateSmoother:get(((vData.vehicle.rpm - prevRPM) / vData.perfData.RPMRange) / dt, dt) -- RPM / s
    local smoothGAccel           = gAccelSmoother:get(vData.vehicle.acceleration.z, dt) -- Forward acceleration of the car, slightly filtered to avoid noise
    local currentDrivetrainRatio = vData.perfData:getDrivetrainRatio()
    local safePredictedSpeed     = getPredictedSpeedForRPM(vData.perfData:getAbsoluteRPM(0.2), vData, currentDrivetrainRatio)
    local crawlPredictedSpeed    = getPredictedSpeedForRPM(vData.perfData.idleRPM, vData, currentDrivetrainRatio)
    local safeSpeedNorm          = lib.clamp01(relevantSpeed / safePredictedSpeed)
    local safeSpeedNormAbs       = lib.clamp01(vData.localHVelLen / safePredictedSpeed)
    local crawlSpeedNorm         = lib.clamp01(relevantSpeed / crawlPredictedSpeed) -- Theoretical speed at idle
    prevRPM                      = vData.vehicle.rpm

    if safeSpeedNormAbs > 0.999 then
        safeSpeedElapsed = safeSpeedElapsed + dt
    else
        safeSpeedElapsed = 0.0
    end

    -- ================================ Auto clutch

    if uiData.autoClutch then

        if vData.perfData.brokenEngineIni then
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
            local minSpeedReached   = lib.furtherFromZero(relevantSpeed, getPredictedSpeedForRPM(vData.perfData.idleRPM * 0.8, vData, currentDrivetrainRatio) or vData.vehicle.gear == 0) -- Only false if going so slow that the engine would stall
            local notLaunching      = vData.vehicle.brake >= 0.01 or vData.vehicle.handbrake >= 0.01 or vData.inputData.gas <= 0.01 or vData.vehicle.gear == 0 -- True if the launch has been aborted
            local signedSpeed       = vData.localVel.z * math.sign(lib.zeroGuard(vData.vehicle.gear))
            local reverseProtection = (signedSpeed < -0.5 and vData.inputData.gas < 0.01 and vData.vehicle.gear ~= 0)

            if normalizedRPM > 0.1 and vData.inputData.gas >= 0.01 and vData.inputData.brake < 0.01 and vData.inputData.handbrake < 0.01 then
                autoClutchRaw = true
            end

            if (normalizedRPM < 0.05 and not minSpeedReached) or reverseProtection then
                autoClutchRaw = false
            end

            if vData.vehicle.tractionControlInAction then clutchFreeze = true end -- // FIXME this doesn't really work

            if (crawlSpeedNorm > 0.9999) then clutchEngagedBiasRaw = true end
            local currentEngagedBias = clutchEngagedBias:getWithRateMult(clutchEngagedBiasRaw and 1.0 or 0.0, dt, (vData.vehicle.gas ^ 1.5) * 0.8 + 0.2) ^ 2.0 -- This will pull the clutch towards 1.0 when a safe speed has been reached

            local clutchStateOverride = (not minSpeedReached) and 0.0 or 1.0 -- In case the launch is aborted or something, this will be the new value of the clutch

            if autoClutchRaw then
                rawClutchEngagedTime = rawClutchEngagedTime + dt

                local RPMTarget = math.lerp(0.7, 0.2, safeSpeedNorm) * math.sqrt(vData.vehicle.gas) -- Normalized RPM targeted by the clutch controller during a launch

                clutchController:setSetpoint(RPMTarget)
                local newTarget = clutchTarget
                if not clutchFreeze and not notLaunching then newTarget = clutchController:get(math.lerp(normalizedRPM, RPMTarget, currentEngagedBias), dt) end

                newTarget = lib.clamp01(newTarget - (M.rawThrottle - vData.vehicle.gas)) -- // FIXME not the best workaround
                clutchTarget = notLaunching and clutchStateOverride or newTarget
                clutchTarget = math.lerp(clutchTarget, 1.0, currentEngagedBias)
            else
                rawClutchEngagedTime = 0
                clutchTarget = 0.0
                clutchEngagedBias:reset()
                clutchController:reset()
                clutchEngagedBiasRaw = false
                if not vData.vehicle.tractionControlInAction then clutchFreeze = false end
            end

            local autoClutchRate = (clutchTarget < autoClutchSmoother.state) and math.clamp((((vData.perfData.idleRPM * 0.8) / vData.vehicle.rpm - 1.0) * 40.0 + 1.0) * 0.5, 0.5, 20.0) or 100.0
            local autoClutchVal  = autoClutchSmoother:getWithRateMult(clutchTarget, dt, autoClutchRate)

            if not autoClutchRaw and reverseProtection then
                autoClutchVal = 0.0
            end

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

    if uiData.autoShiftingMode == 0 or vData.vehicle.gearCount < 2 then
        requestedGear = vData.vehicle.gear
        return
    end

    if not vData.perfData.baseTorqueCurve then
        if not errorShown1 then
            ac.setMessage("Advanced Gamepad Assist", "Error reading engine data. Custom shifting modes will be disabled.")
            errorShown1 = true
        end
        return
    end

    if vData.vehicle.autoShift then
        if not errorShown3 then
            ac.setMessage("Advanced Gamepad Assist", "Disable AC's automatic shifting for the custom shifting modes to work!")
            errorShown3 = true
        end
        return
    end

    if vData.vehicle.mgukDeliveryCount > 0 and uiData.autoShiftingMode == 2 then
        if not errorShown4 then
            ac.setMessage("Advanced Gamepad Assist", "Automatic shifting will have reduced accuracy with this car.")
            errorShown4 = true
        end
    end

    if #gearData == 0 then
        gearData = vData.perfData:calcShiftingTable(0.1, maxAllowedUpshiftRPM)
    end

    local referenceWheelsGrounded = (referenceWheelData[1].loadK > 0.0 or referenceWheelData[2].loadK > 0.0)

    tSinceDownshift = tSinceDownshift + dt
    tSinceUpshift   = tSinceUpshift + dt

    local prevRequestedGear = requestedGear

    updateGearOverride(vData, dt) -- Detecting manual shifting inputs and overriding gears accordingly
    local cruiseFactor = getCruiseFactor(vData, uiData, absInitialSteering, dt) -- Updating cruise mode based on throttle input history

    local avoidDownshift = false -- Protects gears that were manually shifted up into

    if not gearOverride and downshiftProtectedGear == vData.vehicle.gear then
        if RPMChangeRate < 0.02 and safeSpeedElapsed > 0.5 and vData.inputData.clutch > 0.999 then
            RPMFallTime = RPMFallTime + dt
        else
            RPMFallTime = 0.0
        end
        avoidDownshift = (normalizedRPM > 0.05 and RPMFallTime < 1.0 and vData.inputData.gas >= 0.01 and vData.inputData.brake < 0.01)
    else
        downshiftProtectedGear = 0
        RPMFallTime = 0.0
    end

    if cruiseFactor < 0.01 and prevCruiseFactor >= 0.01 then -- Allowing the car to shift freely when coming out of cruise mode
        clearGearOverride()
        avoidDownshift = false
    end

    prevCruiseFactor = cruiseFactor

    -- Avoiding gear changes for a small amount of time after ending a drift, in order to allow for direction changes maintaining the same gear
    local burnoutRaw = (wheelVelRatio1 >= wheelSpinThreshold or wheelVelRatio2 >= wheelSpinThreshold) and vData.inputData.gas > 0.5 and vData.vehicle.gear > 0
    local driftValue = driftIndicatorSmoother:get((burnoutRaw and math.abs(lib.numberGuard(math.deg(math.atan2(vData.rAxleLocalVel.x, vData.rAxleLocalVel.z)))) > 15.0 and vData.localHVelLen > 0.5) and 1.0 or 0.0, dt)
    local driftingProbably = driftValue > 0.0

    if not ((burnoutRaw or driftingProbably) and vData.inputData.gas > 0.5 and vData.vehicle.gear > 1) then
        tSinceHighGearBurnoutStopped = tSinceHighGearBurnoutStopped + dt
    else
        tSinceHighGearBurnoutStopped = 0.0
    end

    if uiData.autoShiftingMode == 2 and not gearOverride then

        -- Main shifting logic

        local canShiftUp = false
        if vData.vehicle.gear > 0 and vData.vehicle.gear < vData.vehicle.gearCount then
            canShiftUp = tSinceDownshift > 0.7 and tSinceUpshift > (vData.perfData.shiftUpTime + autoShiftCheckDelay) and (wheelVelRatio1 < wheelSpinThreshold and wheelVelRatio2 < wheelSpinThreshold and wheelVelRatio1 > 0.9 and wheelVelRatio2 > 0.9) and referenceWheelsGrounded and vData.vehicle.clutch > 0.999 and (not driftingProbably or getPredictedRPM(vData.localHVelLen, vData, vData.perfData:getDrivetrainRatio(vData.vehicle.gear + 1)) > gearData[vData.vehicle.gear + 1].gearStartRPM)
        end

        local canShiftDown = false
        if vData.vehicle.gear > 1 then
            canShiftDown = (tSinceUpshift > 0.7 or vData.inputData.brake > 0.2) and tSinceDownshift > (vData.perfData.shiftDownTime + autoShiftCheckDelay) and not avoidDownshift and referenceWheelsGrounded and not ((driftingProbably or burnoutRaw) and normalizedRPM > 0.5) and (vData.vehicle.clutch > 0.999 or safeSpeedElapsed > 1.0 or tSinceHighGearBurnoutStopped < ((vData.vehicle.gearCount - 1) * (vData.perfData.shiftDownTime + autoShiftCheckDelay + 0.05)))
        end

        local clampedBias       = math.max(0.1, uiData.autoShiftingDownBias) -- this is because of a recent change to have a minimum value of 10%, but saved settings might still have it lower
        local downshiftBiasUsed = math.lerp(clampedBias, clampedBias * 0.6, (lib.clamp01(lib.inverseLerp(0.05, 0.5, vData.inputData.gas)) - lib.clamp01(lib.inverseLerp(0.05, 0.5, vData.inputData.brake))) * 0.5 + 0.5)
        local absDownshiftLimit = vData.perfData:getAbsoluteRPM(maxAllowedDownshiftRPM)
        local minAllowedRPM     = vData.perfData:getAbsoluteRPM(0.01)

        if canShiftUp then
            -- Finding the best gear to upshift into
            local targetGear = requestedGear
            local extRPM = normalizedRPM + RPMChangeRate * dt -- extrapolated RPM to be safe
            local absExtRPM = vData.perfData:getAbsoluteRPM(extRPM)
            for g = math.max(2, clampGear(requestedGear + 1, vData)), vData.vehicle.gearCount, 1 do
                local refRPM = vData.perfData:getRPMInGear(g - 1, absExtRPM)
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
            local predSpeed = vData.localHVelLen + math.min(smoothGAccel * 9.81, 0.0) * (vData.perfData.shiftDownTime + downshiftClutchFadeT + 0.02)
            local absVelPredRPM = getPredictedRPM(predSpeed, vData)
            for g = clampGear(requestedGear - 1, vData), 1, -1 do
                local refRPM = vData.perfData:getRPMInGear(g, absVelPredRPM)
                if refRPM <= getDownshiftThresholdRPM(g, minAllowedRPM, absDownshiftLimit, downshiftBiasUsed, cruiseFactor) then
                    targetGear = g
                end
                if not canUseClutch or not vData.vehicle.hShifter then break end -- Only check 1 gear without H-shifter
            end
            requestedGear = targetGear
        end
    end

    -- Requesting the desired gear
    requestGear(vData, dt)

    local function getRevMatchedGasInput()
        if not (gearOverride and not canUseClutch and vData.perfData.electronicBlip == 1) then
            local targetAdjustment = 0.98
            local targetNormalizedRPM = math.clamp(vData.perfData:getNormalizedRPM(getPredictedRPM(relevantSpeed, vData, vData.perfData:getDrivetrainRatio(requestedGear))) * targetAdjustment, 0.0, 0.98)
            revMatchController:setSetpoint(targetNormalizedRPM)
            return revMatchController:get(normalizedRPM, dt)
        end
        return vData.inputData.gas
    end


    -- Dealing with clutch and rev-matching
    if (tSinceUpshift < vData.perfData.shiftUpTime or tSinceDownshift < vData.perfData.shiftDownTime) and vData.inputData.clutch > 0.999 then
        if tSinceDownshift < tSinceUpshift then tSinceDownshiftOver = 0.0 else tSinceDownshiftOver = 999.0 end
        vData.inputData.clutch = 0.0
        vData.inputData.gas = getRevMatchedGasInput()
    else
        tSinceDownshiftOver = tSinceDownshiftOver + dt
        local baseClutchT = lib.clamp01(tSinceDownshiftOver / downshiftClutchFadeT)
        if baseClutchT > 0.999 then
            revMatchController:reset()
        else
            vData.inputData.clutch = math.lerp(0.0, vData.inputData.clutch, baseClutchT ^ 2.0)
            vData.inputData.gas = math.lerp(getRevMatchedGasInput(), vData.inputData.gas, baseClutchT)
        end
    end
end

ac.onSharedEvent("AGA_factoryReset", function()
    errorShown1 = false
    errorShown2 = false
    errorShown3 = false
    errorShown4 = false
end)

ac.onCarJumped(car.index, function (carID)
    requestedGear = 0
    -- errorShown2 = false
    errorShown3 = false -- Show this one more often
    gearData = {}
end)

return M
if car.isAIControlled then return end

local lib = require "AGALib"
local extras = require "extras"

-- CONFIG =====================================================================================

-- Data shared with the UI app
local uiData = ac.connect{
    ac.StructItem.key("AGAData"),
    _appCanRun               = ac.StructItem.boolean(),
    _localHVelAngle          = ac.StructItem.double(),
    _selfSteerStrength       = ac.StructItem.double(),
    _frontNdSlip             = ac.StructItem.double(),
    _rearNdSlip              = ac.StructItem.double(),
    _limitReduction          = ac.StructItem.double(),
    assistEnabled            = ac.StructItem.boolean(),
    graphSelection           = ac.StructItem.int32(),
    keyboardMode             = ac.StructItem.int32(), -- 0 = disabled, 1 = enabled, 2 = enabled + brake assist, 3 = enabled + throttle and brake assist
    autoClutch               = ac.StructItem.boolean(),
    autoShifting             = ac.StructItem.boolean(),
    autoShiftingCruise       = ac.StructItem.boolean(),
    autoShiftingDownBias     = ac.StructItem.double(),
    triggerFeedbackL         = ac.StructItem.double(),
    triggerFeedbackR         = ac.StructItem.double(),
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

-- Config saved to disk
local savedCfg = ac.storage({
    assistEnabled            = true,
    graphSelection           = 1,
    keyboardMode             = 0,
    autoClutch               = false,
    autoShifting             = false,
    autoShiftingCruise       = true,
    autoShiftingDownBias     = 0.7,
    triggerFeedbackL         = 0.0,
    triggerFeedbackR         = 0.0,
    useFilter                = true,
    filterSetting            = 0.5,
    steeringRate             = 0.5,
    rateIncreaseWithSpeed    = 0.1,
    selfSteerResponse        = 0.37,
    dampingStrength          = 0.37,
    maxSelfSteerAngle        = 14.0,
    countersteerResponse     = 0.2,
    maxDynamicLimitReduction = 5.0
}, "AGA_")

-- Initializing shared cfg
uiData._appCanRun               = false
uiData.assistEnabled            = savedCfg.assistEnabled
uiData.keyboardMode             = savedCfg.keyboardMode
uiData.graphSelection           = savedCfg.graphSelection
uiData.useFilter                = savedCfg.useFilter
uiData.autoClutch               = savedCfg.autoClutch
uiData.autoShifting             = savedCfg.autoShifting
uiData.autoShiftingCruise       = savedCfg.autoShiftingCruise
uiData.autoShiftingDownBias     = savedCfg.autoShiftingDownBias
uiData.triggerFeedbackL         = savedCfg.triggerFeedbackL
uiData.triggerFeedbackR         = savedCfg.triggerFeedbackR
uiData.filterSetting            = savedCfg.filterSetting
uiData.steeringRate             = savedCfg.steeringRate
uiData.rateIncreaseWithSpeed    = savedCfg.rateIncreaseWithSpeed
uiData.selfSteerResponse        = savedCfg.selfSteerResponse
uiData.dampingStrength          = savedCfg.dampingStrength
uiData.maxSelfSteerAngle        = savedCfg.maxSelfSteerAngle
uiData.countersteerResponse     = savedCfg.countersteerResponse
uiData.maxDynamicLimitReduction = savedCfg.maxDynamicLimitReduction

-- MAIN LOGIC =================================================================================

local steeringSmoother         = lib.SmoothTowards:new( 7.0,  0.15, -1.0,  1.0,  0.0) -- Smooths the initial steering input
local absSteeringSmoother      = lib.SmoothTowards:new( 7.0,  0.15, -1.0,  1.0,  0.0) -- Smooths the absolute value of the initial steering input
local kbThrottleSmoother       = lib.SmoothTowards:new(12.0,  1.0,   0.0,  1.0,  0.0)
local kbBrakeSmoother          = lib.SmoothTowards:new(12.0,  1.0,   0.0,  1.0,  0.0)
local kbSteerSmoother          = lib.SmoothTowards:new( 7.0,  1.0,  -1.0,  1.0,  0.0)
local selfSteerSmoother        = lib.SmoothTowards:new(10.0,  0.15, -1.0,  1.0,  0.0) -- Smooths out the self-steer force
local limitSmoother            = lib.SmoothTowards:new( 8.0,  0.01,  0.0, 32.0, 32.0) -- Smooths out changes in the steering limit
-- local limitSmoother            = lib.SmoothTowards:new(12.0,  0.01,  0.0, 32.0, 32.0) -- Smooths out changes in the steering limit
local targetFrontSlipSmoother  = lib.SmoothTowards:new( 0.1,  0.05,  0.0, 15.0,  7.0) -- Smooths the measured ideal slip angle for the front wheels
local groundedSmoother         = lib.SmoothTowards:new( 5.0,  1.0,   0.0,  1.0,  1.0) -- Smooths the value that indicates if any of the front wheels are grounded
local frontSlipDisplaySmoother = lib.SmoothTowards:new(10.0,  0.05,  0.0,  1.0,  0.0) -- Smooths the relative front slip value sent to the UI app for visualization
local rearSlipDisplaySmoother  = lib.SmoothTowards:new(10.0,  0.05,  0.0,  1.0,  0.0) -- Smooths the relative rear slip value sent to the UI app for visualization
local vehicleSteeringLock      = math.NaN -- Degrees

local gameCfg                  = ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. "/controls.ini")
local kbThrottleBind           = ac.KeyIndex.Up
local kbBrakeBind              = ac.KeyIndex.Down
local kbSteerLBind             = ac.KeyIndex.Left
local kbSteerRBind             = ac.KeyIndex.Right

if gameCfg then
    kbThrottleBind = gameCfg:get("KEYBOARD", "GAS",   kbThrottleBind)
    kbBrakeBind    = gameCfg:get("KEYBOARD", "BRAKE", kbBrakeBind)
    kbSteerLBind   = gameCfg:get("KEYBOARD", "LEFT",  kbSteerLBind)
    kbSteerRBind   = gameCfg:get("KEYBOARD", "RIGHT", kbSteerRBind)
end

-- Calibration stuff

local calibrationPreDelay      = 0
local calibrationDelay         = 0
local calibrationLockDelay     = 0
local calibrationStage         = 0
local calibrationSmoother      = lib.SmoothTowards:new(1.2, 1.0, -1.0, 1.0, 0.0)
local calibrationSavedWheels   = false
local calibrationSuccess       = false
local calibrationTries         = 0
local calibrationMaxTries      = 2
local calibrationRateMult      = math.NaN

local localWheelPositions      = {[0] = vec3(0.7, -0.2, 1.3), vec3(-0.7, -0.2, 1.3), vec3(0.7, -0.2, -1.3), vec3(-0.7, -0.2, -1.3)} -- Local positions of all 4 wheels (0-based index). Only set once, not updated dynamically.
local fAxlePos                 = vec3(0.0, -0.2,  1.3)
local rAxlePos                 = vec3(0.0, -0.2, -1.3)
local avgWheelPos              = vec3(0.0, -0.2, 0.0)
local steeringCurveSamples     = {}
local steeringExponent         = 0.95
local fastLearningTime         = 0

-- Updates the config values based on the settings in the UI app
local function updateConfig(inputData)
    if uiData.useFilter then
        uiData.rateIncreaseWithSpeed    = (1.0 - uiData.filterSetting) * 0.2
        uiData.selfSteerResponse        = uiData.filterSetting * 0.5 + 0.12
        uiData.dampingStrength          = uiData.selfSteerResponse -- * 0.8
        uiData.maxSelfSteerAngle        = 28.0 * uiData.filterSetting
        uiData.maxDynamicLimitReduction = 2 * uiData.filterSetting + 4.0
        uiData.countersteerResponse     = (1.0 - uiData.filterSetting) * 0.4
    end

    savedCfg.assistEnabled            = uiData.assistEnabled
    savedCfg.keyboardMode             = uiData.keyboardMode
    savedCfg.graphSelection           = uiData.graphSelection
    savedCfg.useFilter                = uiData.useFilter
    savedCfg.autoClutch               = uiData.autoClutch
    savedCfg.autoShifting             = uiData.autoShifting
    savedCfg.autoShiftingCruise       = uiData.autoShiftingCruise
    savedCfg.autoShiftingDownBias     = uiData.autoShiftingDownBias
    savedCfg.triggerFeedbackL         = uiData.triggerFeedbackL
    savedCfg.triggerFeedbackR         = uiData.triggerFeedbackR
    savedCfg.filterSetting            = uiData.filterSetting
    savedCfg.steeringRate             = uiData.steeringRate
    savedCfg.rateIncreaseWithSpeed    = uiData.rateIncreaseWithSpeed
    savedCfg.selfSteerResponse        = uiData.selfSteerResponse
    savedCfg.dampingStrength          = uiData.dampingStrength
    savedCfg.maxSelfSteerAngle        = uiData.maxSelfSteerAngle
    savedCfg.countersteerResponse     = uiData.countersteerResponse
    savedCfg.maxDynamicLimitReduction = uiData.maxDynamicLimitReduction

    uiData._appCanRun = true
end

local function sanitizeSteeringInput(value)
    return lib.numberGuard(math.clamp(value, -1, 1))
end

local function sanitize01Input(value)
    return lib.numberGuard(math.clamp(value, 0, 1))
end

local function calcSteeringCurveExponent(Vx, Vy)
    Vy = math.clamp(Vy, 0.001, 0.999) -- Otherwise the function might do dumb shit
    return math.log(1.0 - Vy, 10) / math.log(1.0 - Vx, 10)
end

local function inputToNormalizedSteering(input, steeringCurveExp)
    return math.sign(input) * (1.0 - math.pow(1.0 - math.abs(input), steeringCurveExp))
end

local function normalizedSteeringToInput(steeringAngleNormalized, steeringCurveExp)
    return math.sign(steeringAngleNormalized) * (1.0 - math.pow(1.0 - math.abs(steeringAngleNormalized), 1.0 / steeringCurveExp))
end

local _tmpVec0 = vec3()
local _tmpVec1 = vec3()
-- Returns the current steering angle of the car in degrees. It's an average of the angle of both front wheels.
local function getCurrentSteeringAngleDeg(vehicle, inverseBodyTransform)
    inverseBodyTransform:transformVectorTo(_tmpVec0, vehicle.wheels[0].look)
    inverseBodyTransform:transformVectorTo(_tmpVec1, vehicle.wheels[1].look)
    return -math.deg(lib.numberGuard(math.atan2(_tmpVec0.x + _tmpVec1.x, _tmpVec0.z + _tmpVec1.z)))
end

-- Analyzes the samples collected during the steering calibration and returns the steering curve exponent that should be used with `inputToNormalizedSteering()` and `normalizedSteeringToInput()`.
local function evaluateSteeringCurve(samples, steeringLock)
    local sampleCount = 0
    local acc = 0
    for _, value in ipairs(samples) do
        if value[1] >= 0.3 and value[1] <= 0.7 then
            local valueToAdd = calcSteeringCurveExponent(value[1], value[2] / steeringLock)
            if valueToAdd and not math.isNaN(valueToAdd) then
                acc = acc + valueToAdd
                sampleCount = sampleCount + 1
            end
        end
    end
    return acc / sampleCount
end

local function retryCalibration(silent)
    if not silent then ac.setMessage("Advanced Gamepad Assist", "Error - Steering calibration failed. Retrying ...") end
    -- cfg._appCanRun = false
    calibrationSuccess = false
    calibrationSavedWheels = false
    calibrationStage = 0
    calibrationDelay = 0
    calibrationLockDelay = 0
    steeringExponent = 0.95
    fastLearningTime = 0
    calibrationRateMult = math.NaN
    table.clear(steeringCurveSamples)
    vehicleSteeringLock = math.NaN
end

-- Hijacks the throttle / brake / handbrake/ steering inputs to perform calibration. Returns `true` if the calibration is over or aborted, `false` if it's in progress.
local function performCalibration(inputData, vehicle, inverseBodyTransform, dt)
    if vehicle.velocity:length() > 0.5 and calibrationStage == 0 then
        calibrationPreDelay = calibrationPreDelay + dt
        if calibrationPreDelay > 1.0 then
            calibrationStage = 2
            return true
        else
            inputData.gas       = 0.0
            inputData.handbrake = 1.0
            inputData.brake     = 0.0
            inputData.clutch    = 0.0
            return false
        end
    end

    if calibrationStage < 2 then

        if math.isNaN(calibrationRateMult) then
            calibrationRateMult = math.clamp((ac.getSim().fps - 6.0) / 60.0, 0.6, 1.3)
        end

        inputData.gas       = 0.0
        inputData.handbrake = 1.0
        inputData.brake     = 0.0
        inputData.clutch    = 0.0
        inputData.steer     = calibrationSmoother.state

        local currentAbsAngle = lib.numberGuard(math.abs(getCurrentSteeringAngleDeg(vehicle, inverseBodyTransform)))

        if calibrationDelay < 0.7 or currentAbsAngle < 0.2 then
            calibrationDelay = calibrationDelay + dt
            inputData.steer = sanitizeSteeringInput(calibrationSmoother:getWithRateMult(0.05, dt, 5.0))
            return false
        end

        if not calibrationSavedWheels then
            calibrationSavedWheels = true
            inverseBodyTransform:transformPoint(vehicle.wheels[0].position):copyTo(localWheelPositions[0])
            inverseBodyTransform:transformPoint(vehicle.wheels[1].position):copyTo(localWheelPositions[1])
            inverseBodyTransform:transformPoint(vehicle.wheels[2].position):copyTo(localWheelPositions[2])
            inverseBodyTransform:transformPoint(vehicle.wheels[3].position):copyTo(localWheelPositions[3])
            fAxlePos:set(localWheelPositions[0]):add(localWheelPositions[1]):scale(0.5)
            rAxlePos:set(localWheelPositions[2]):add(localWheelPositions[3]):scale(0.5)
            avgWheelPos:set(localWheelPositions[0]):add(localWheelPositions[1]):add(localWheelPositions[2]):add(localWheelPositions[3]):scale(0.25)
            avgWheelPos.x = math.round(avgWheelPos.x * 1000.0) / 1000.0
            avgWheelPos.y = math.round(avgWheelPos.y * 1000.0) / 1000.0
            avgWheelPos.z = math.round(avgWheelPos.z * 1000.0) / 1000.0
            if math.abs(rAxlePos.x) > 0.01 or math.abs(fAxlePos.x) > 0.01 then
                ac.setMessage("Advanced Gamepad Assist", "Warning - The average wheel position seems off-center.")
            end
        end

        if calibrationStage == 0 then
            if #steeringCurveSamples == 0 or math.abs(currentAbsAngle - steeringCurveSamples[#steeringCurveSamples][2]) > 1e-6 then
                table.insert(steeringCurveSamples, {calibrationSmoother.state, currentAbsAngle})
            end
            inputData.steer = sanitizeSteeringInput(calibrationSmoother:getWithRateMult(1, dt, calibrationRateMult))
            if (1.0 - inputData.steer) < 1e-10 then
                calibrationLockDelay = calibrationLockDelay + dt
                if calibrationLockDelay > 0.2 then
                    calibrationStage = calibrationStage + 1
                end
            end
        elseif calibrationStage == 1 then
            if math.isNaN(vehicleSteeringLock) then
                vehicleSteeringLock = currentAbsAngle
                if not (vehicleSteeringLock > 3.0 and vehicleSteeringLock < 90.0) then
                    if calibrationTries < (calibrationMaxTries - 1) then
                        calibrationTries = calibrationTries + 1
                        retryCalibration()
                        return false
                    end
                    ac.setMessage("Advanced Gamepad Assist", "Error - Failed to determine steering lock. Using a fallback value.")
                    vehicleSteeringLock = -1
                end
                steeringExponent = lib.numberGuard(evaluateSteeringCurve(steeringCurveSamples, vehicleSteeringLock))
                if not (steeringExponent > 0.5 and steeringExponent < 2.0) then
                    if calibrationTries < (calibrationMaxTries - 1) then
                        calibrationTries = calibrationTries + 1
                        retryCalibration()
                        return false
                    end
                    ac.setMessage("Advanced Gamepad Assist", "Error - Failed to determine steering curve. Using a fallback value.")
                    steeringExponent = 0.95
                end
            end
            inputData.steer = sanitizeSteeringInput(calibrationSmoother:getWithRateMult(0, dt, 5.0))
            if inputData.steer < 1e-6 then
                calibrationStage = calibrationStage + 1
                calibrationSuccess = true
                if vehicleSteeringLock == -1 then vehicleSteeringLock = math.NaN end
            end
        end

        return false
    end

    return true
end

-- local function worldVecToLocal(objForward, objUp, worldVector)
--     local objRight = math.cross(objForward, objUp):scale(-1.0)
--     local localX   = worldVector:dot(objRight)
--     local localY   = worldVector:dot(objUp)
--     local localZ   = worldVector:dot(objForward)
--     objRight:set(localX, localY, localZ)
--     return objRight
-- end

local storedLocalWheelVel = {[0] = vec3(), vec3(), vec3(), vec3()} -- Stores local wheel velocities to avoid creating new vectors on every update
local storedWeightedFLocalVel = vec3()
local storedFAxleLocalVel = vec3()
local storedRAxleLocalVel = vec3()
local storedMiddleVel = vec3()
local storedIdleRPM   = 0
local storedMaxRPM    = 0
local storedTorqueCurve = nil
local storedTurboData = nil
local storedShiftUpTime = -1
local storedShiftDownTime = -1
-- local storedHasBlip = false
local storedMissingEngineIni = false

-- Returns all relevant measurements and data related to the vehicle, or `nil` if the steering clibration has not finished yet
local function getVehicleData(dt, skipCalibration)
    local inputData            = ac.getJoypadState()
    local vehicle              = ac.getCar(0) or car
    local inverseBodyTransform = vehicle.transform:inverse()

    if not skipCalibration then
        if not performCalibration(inputData, vehicle, inverseBodyTransform, dt) then return nil end
    end

    local fWheelWeights   = {lib.zeroGuard(vehicle.wheels[0].load), lib.zeroGuard(vehicle.wheels[1].load)}
    local rWheelWeights   = {lib.zeroGuard(vehicle.wheels[2].load), lib.zeroGuard(vehicle.wheels[3].load)}
    local allWheelWeights = {fWheelWeights[1], fWheelWeights[2], rWheelWeights[1], rWheelWeights[2]}

    -- Updating wheel loads and local wheel velocities
    for i = 0, 3 do
        lib.getPointVelocity(localWheelPositions[i], vehicle.localAngularVelocity, vehicle.localVelocity, storedLocalWheelVel[i])
    end

    lib.weightedVecAverage({storedLocalWheelVel[0], storedLocalWheelVel[1]}, fWheelWeights, storedWeightedFLocalVel)
    lib.getPointVelocity(fAxlePos, vehicle.localAngularVelocity, vehicle.localVelocity, storedFAxleLocalVel)
    lib.getPointVelocity(rAxlePos, vehicle.localAngularVelocity, vehicle.localVelocity, storedRAxleLocalVel)
    lib.getPointVelocity(avgWheelPos, vehicle.localAngularVelocity, vehicle.localVelocity, storedMiddleVel)

    if (storedIdleRPM == 0 or storedMaxRPM == 0) and not storedMissingEngineIni then
        local engineINI = ac.INIConfig.carData(vehicle.index, "engine.ini")

        if table.nkeys(engineINI.sections) > 0 then
            storedIdleRPM   = engineINI:get("ENGINE_DATA", "MINIMUM", 900)
            storedMaxRPM    = math.min(engineINI:get("ENGINE_DATA", "LIMITER", 99999), engineINI:get("DAMAGE", "RPM_THRESHOLD", 99999))

            if storedMaxRPM == 99999 then
                storedMaxRPM = ((vehicle.rpmLimiter > 0) and vehicle.rpmLimiter or 7000)
            end

            storedTurboData = {}
            for i = 0, 3, 1 do
                local maxBoost   = engineINI:get("TURBO_" .. i, "MAX_BOOST", 0)
                local wasteGate  = engineINI:get("TURBO_" .. i, "WASTEGATE", 0)
                local boostLimit = math.min(maxBoost, wasteGate)
                if boostLimit ~= 0 then
                    local referenceRPM    = engineINI:get("TURBO_" .. i, "REFERENCE_RPM", -1)
                    local gamma           = engineINI:get("TURBO_" .. i, "GAMMA", -1)

                    if referenceRPM ~= -1 and gamma ~= -1 then
                        local controller      = ac.INIConfig.carData(vehicle.index, "ctrl_turbo" .. i .. ".ini")
                        local controllerInput = controller:get("CONTROLLER_0", "INPUT", "")
                        local controllerLUT   = controller:tryGetLut("CONTROLLER_0", "LUT")

                        if controllerLUT then
                            controllerLUT.useCubicInterpolation = true
                            controllerLUT.extrapolate = true
                        end

                        table.insert(storedTurboData, {
                            boostLimit = boostLimit,
                            referenceRPM = referenceRPM,
                            gamma = gamma,
                            controllerInput = controllerInput,
                            controllerLUT = controllerLUT
                        })
                    end
                end
            end

            storedTorqueCurve = ac.DataLUT11.carData(vehicle.index, engineINI:get("HEADER", "POWER_CURVE", "power.lut")) -- engineINI:tryGetLut("HEADER", "POWER_CURVE")

            if storedTorqueCurve then
                storedTorqueCurve.useCubicInterpolation = true -- // TODO is this right?
                storedTorqueCurve.extrapolate = true
            end
        else
            ac.debug("_OK", true)
            storedMissingEngineIni = true
        end
    end

    if storedShiftUpTime == -1 or storedShiftDownTime == -1 then
        local drivetrainINI = ac.INIConfig.carData(vehicle.index, "drivetrain.ini")
        storedShiftUpTime   = drivetrainINI:get("GEARBOX", "CHANGE_UP_TIME", vehicle.hShifter and 300 or 50)
        storedShiftDownTime = drivetrainINI:get("GEARBOX", "CHANGE_DN_TIME", vehicle.hShifter and 300 or 50)
        -- storedHasBlip       = (drivetrainINI:get("AUTOBLIP", "ELECTRONIC", 0) == 1)
        -- local hasProtection = drivetrainINI:get("DOWNSHIFT_PROTECTION", "ACTIVE", 0)
        -- if hasProtection == 1 then
        --     storedDownshiftProtection = drivetrainINI:get("DOWNSHIFT_PROTECTION", "OVERREV", nil)
        -- end
    end

    local cPhys = ac.getCarPhysics(vehicle.index)

    -- ac.debug("_INERTIA", cPhys.engineInertia)

    -- ac.debug("_AC_AUTOCLUTCH", vehicle.autoClutch)
    -- ac.debug("_AC_AUTOSHIFT", vehicle.autoShift)


    return {
        inputData             = inputData, -- ac.getJoypadState()
        vehicle               = vehicle, -- ac.getCar(0)
        inverseBodyTransform  = inverseBodyTransform, -- Used for converting points or vectors from global space to local space
        -- localVel              = vehicle.localVelocity, -- Local velocity vector of the vehicle
        localVel              = storedMiddleVel, -- Local velocity vector of the vehicle at the average position of all 4 wheels
        -- localHVelLen          = math.sqrt(vehicle.localVelocity.x * vehicle.localVelocity.x + vehicle.localVelocity.z * vehicle.localVelocity.z), -- Velocity magnitude of the vehicle on the local horizontal plane (m/s)
        localHVelLen          = math.sqrt(storedMiddleVel.x * storedMiddleVel.x + storedMiddleVel.z * storedMiddleVel.z), -- Velocity magnitude of the vehicle on the local horizontal plane (m/s)
        localAngularVel       = vehicle.localAngularVelocity,
        localWheelVelocities  = storedLocalWheelVel, -- Wheel velocities in local space, 0-based indexing
        -- fWheelWeights         = fWheelWeights, -- Front wheel loads, for using a weighted average
        -- rWheelWeights         = rWheelWeights, -- Rear wheel loads, for using a weighted average
        travelDirection       = lib.numberGuard(math.deg(math.atan2(storedMiddleVel.x, storedMiddleVel.z))), -- The angle of the vehicle's velocity vector on the local horizontal plane (deg), at the average position of all wheels
        frontSlipDeg          = lib.numberGuard(lib.weightedAverage({vehicle.wheels[0].slipAngle, vehicle.wheels[1].slipAngle}, fWheelWeights)), -- Average front wheel slip angle, weighted by wheel load (deg)
        rearSlipDeg           = lib.numberGuard(lib.weightedAverage({vehicle.wheels[2].slipAngle, vehicle.wheels[3].slipAngle}, rWheelWeights)), -- Average rear wheel slip angle, weighted by wheel load (deg)
        frontNdSlip           = lib.numberGuard(lib.weightedAverage({vehicle.wheels[0].ndSlip,    vehicle.wheels[1].ndSlip},    fWheelWeights)), -- Average normalized front slip, weighted by wheel load
        rearNdSlip            = lib.numberGuard(lib.weightedAverage({vehicle.wheels[2].ndSlip,    vehicle.wheels[3].ndSlip},    rWheelWeights)), -- Average normalized rear slip, weighted by wheel load
        totalNdSlip           = lib.numberGuard(lib.weightedAverage({vehicle.wheels[0].ndSlip, vehicle.wheels[1].ndSlip, vehicle.wheels[2].ndSlip, vehicle.wheels[3].ndSlip}, allWheelWeights)),
        fwdVelClamped         = math.max(0.0, storedMiddleVel.z), -- Velocity along the local forwrad axis, positive only (m/s)
        steeringLockDeg       = lib.numberGuard(vehicleSteeringLock, math.abs(inputData.steerLock / inputData.steerRatio)),
        weightedFLocalVel     = storedWeightedFLocalVel, -- Weighted average local velocity of the front wheels
        fAxleLocalVel         = storedFAxleLocalVel, -- Local velocity of the front axle (same as the average of the front wheels)
        rAxleLocalVel         = storedRAxleLocalVel, -- Local velocity of the rear axle (same as the average of the rear wheels)
        fAxleHVelLen          = math.sqrt(storedFAxleLocalVel.x * storedFAxleLocalVel.x + storedFAxleLocalVel.z * storedFAxleLocalVel.z),
        steeringCurveExponent = steeringExponent,
        frontGrounded         = groundedSmoother:get((vehicle.wheels[0].loadK == 0.0 and vehicle.wheels[1].loadK == 0.0) and 0.0 or 1.0, dt), -- Smoothed 0-1 value to indicate if the steered wheels are grounded
        idleRPM               = storedIdleRPM,
        maxRPM                = storedMaxRPM,
        RPMRange              = storedMaxRPM - storedIdleRPM,
        cPhys                 = cPhys,
        drivetrainRatio       = cPhys.gearRatio * cPhys.finalRatio,
        baseTorqueCurve       = storedTorqueCurve,
        turboData             = storedTurboData,
        shiftUpTime           = storedShiftUpTime / 1000.0,
        shiftDownTime         = storedShiftDownTime / 1000.0,
        -- hasBlip               = storedHasBlip,
        brokenEngineIni       = storedMissingEngineIni
    }
end

-- Returns the rate multiplier that should be used for the steering filter
local function calcSteeringRateMult(fwdVelClamped, steeringLockDeg)
    local speedAdjustedRate = steeringLockDeg / math.min(65.0 / (math.max(fwdVelClamped, 8.0) - 7.3) + 3.5, steeringLockDeg)
    return math.pow(speedAdjustedRate, uiData.rateIncreaseWithSpeed) * uiData.steeringRate
end

local counterIndicatorSmoother = lib.SmoothTowards:new(12.0, 1.0, 0.0, 1.0, 0.0)

-- Returns the corrected sterering angle with the steering limit and self-steer force applied, normalized to the car's steering lock
local function calcCorrectedSteering(vData, targetFrontSlipDeg, initialSteering, absInitialSteering, steeringRateMult, dt)
    -- Calculating baseline data

    local fAxleHVelAngle       = lib.numberGuard(math.deg(math.atan2(vData.fAxleLocalVel.x, math.abs(vData.fAxleLocalVel.z)))) -- Angle of the weighted average front wheel velocity on the local horizontal plane, corrected for reverse (deg)
    local rAxleHVelAngle       = lib.numberGuard(math.deg(math.atan2(vData.rAxleLocalVel.x, math.abs(vData.rAxleLocalVel.z)))) -- Angle of the rear axle velocity on the local horizontal plane, corrected for reverse (deg)
    local localVelHAngle       = lib.numberGuard(math.deg(math.atan2(vData.localVel.x, math.abs(vData.localVel.z)))) -- Angle of the car's velocity on the local horizontal plane, corrected for reverse (deg)
    local inputSign            = math.sign(initialSteering) -- Sign of the initial steering input by the player (after smoothing)
    local angleSubLimit        = math.lerp(uiData.maxDynamicLimitReduction, uiData.maxDynamicLimitReduction * 0.8, vData.inputData.brake) -- How many degrees the steering limit is allowed to reduce when the car oversteers, in the process of trying to maintain peak front slip angle
    local clampedFAxleVelAngle = lib.clampEased(inputSign * fAxleHVelAngle, -vData.steeringLockDeg - 15.0, angleSubLimit, 3.0 / (vData.steeringLockDeg + 15.0 + angleSubLimit)) -- Limiting how much the front velocity angle can affect the steering limit
    uiData._localHVelAngle     = localVelHAngle
    uiData._limitReduction     = math.max(clampedFAxleVelAngle, 0.0)

    -- Self-steer force

    local correctionExponent  = 1.0 + (1.0 - math.log10(10.0 * (uiData.selfSteerResponse * 0.9 + 0.1))) -- This is just to make `cfg.selfSteerResponse` scale in a better way
    local correctionBase      = lib.signedPow(math.clamp(-localVelHAngle / 72.0, -1, 1), correctionExponent) * 72.0 / vData.steeringLockDeg -- Base self-steer force
    local selfSteerCap        = lib.clamp01(uiData.maxSelfSteerAngle / vData.steeringLockDeg) -- Max self-steer amount
    local selfSteerStrength   = math.sqrt(lib.clamp01(math.max(0.0, vData.localHVelLen - 0.5) / (35.0 / 3.6))) * vData.frontGrounded -- Multiplier that can fade the self-steer force in and out
    local dampingForce        = vData.localAngularVel.y * uiData.dampingStrength * 0.2125
    local selfSteerCapT       = math.min(1.0, 4.0 / (2.0 * selfSteerCap))
    local selfSteerForce      = math.clamp(selfSteerSmoother:get(lib.clampEased(correctionBase, -selfSteerCap, selfSteerCap, selfSteerCapT) + dampingForce, dt), -2.0, 2.0) * selfSteerStrength
    uiData._selfSteerStrength = selfSteerStrength * (1.0 - absInitialSteering)

    -- Steering limit

    local slipCorrection      = 1.035 -- // FIXME some cars change with speed, find out why
    local finalTargetSlip     = targetFrontSlipDeg * slipCorrection -- The max slip angle that the front wheels will target

    local isCountersteering   = (inputSign ~= math.sign(lib.zeroGuard(vData.rAxleLocalVel.x)) and math.abs(initialSteering) > 1e-6) -- Boolean to indicate if the player is countersteering
    local counterIndicator    = counterIndicatorSmoother:get(isCountersteering and lib.inverseLerpClampedEased(4.5, 9.5, math.abs(rAxleHVelAngle), 0.0, 1.0, 0.6) or 0.0, dt) -- 0-1 multiplier to indicate if the player is countersteering

    local antiSelfSteer       = absInitialSteering * -selfSteerForce -- This prevents the self-steer force from affecting the steering limit             -- math.sign(-initialSteering) * selfSteerForce (when added to the limit)
    local targetInward        = finalTargetSlip - clampedFAxleVelAngle -- Steering limit when turning inward
    local counterMult         = math.lerp(math.lerpInvSat(-inputSign * rAxleHVelAngle, 0.0, 30.0) * 0.333 + 0.666, 1.0, uiData.countersteerResponse) -- Makes manual countersteering a bit less sensitive near the center
    local targetCounter       = (finalTargetSlip * (uiData.countersteerResponse * counterMult * 0.85 + 0.15)) - (inputSign * rAxleHVelAngle) -- Steering limit when countersteering

    local targetSteeringAngle = math.clamp(math.lerp(targetInward, targetCounter, counterIndicator), -vData.steeringLockDeg, vData.steeringLockDeg) -- The steering angle that would result in the targeted slip angle
    local notForward          = math.sin(math.clamp(math.rad(vData.travelDirection * 0.75), -math.pi * 0.5, math.pi * 0.5)) ^ 6 -- Used to get rid of the steering limit when going backwards
    local limit               = math.lerp(limitSmoother:get(targetSteeringAngle, dt) / vData.steeringLockDeg, 1.0, notForward) -- The final steering limit

    return math.clamp((initialSteering * limit) + selfSteerForce + antiSelfSteer, -1.0, 1.0)
end

-- Smoothly updates the target slip angle for the front wheels over time, based on the current vehicle conditions
local function updateTargetSlipAngle(vData, initialSteering, dt)
    if (vData.frontNdSlip > 0.4 and vData.frontNdSlip < 1.5 and
        vData.fwdVelClamped > 8.0 and
        vData.rearNdSlip > 0.1 and vData.rearNdSlip < 1.2
        and vData.vehicle.wheels[0].surfaceType == ac.SurfaceType.Default and vData.vehicle.wheels[1].surfaceType == ac.SurfaceType.Default and
        vData.inputData.brake < 0.05 and
        math.abs(initialSteering) > 0.25 and
        math.abs(vData.vehicle.wheels[0].slipRatio) < 0.1 and math.abs(vData.vehicle.wheels[1].slipRatio) < 0.1) -- // TODO do something more with slip ratio maybe
    then
        local rateMult = 1.0
        if fastLearningTime < 1.5 then
            fastLearningTime = fastLearningTime + dt
            rateMult = 5.0
        end
        targetFrontSlipSmoother:getWithRateMult(math.clamp(math.abs(vData.frontSlipDeg) / vData.frontNdSlip, 4, 14.0), dt, rateMult) -- * clamp01(vData.frontNdSlip * 0.05 + 0.95)
    end
end

-- Updates the graphs in the UI app
local function updateDisplayValues(vData, assistFadeIn, assistEnabled, dt)
    if assistFadeIn < 1e-15 and assistEnabled then
        uiData._localHVelAngle = 0
        uiData._selfSteerStrength = 0
        uiData._limitReduction = 0
        uiData._frontNdSlip = 0
        uiData._rearNdSlip = 0
    else
        if not assistEnabled then
            uiData._localHVelAngle = 0
            uiData._selfSteerStrength = 0
            uiData._limitReduction = 0
        end
        uiData._frontNdSlip = frontSlipDisplaySmoother:get(vData.frontNdSlip, dt)
        uiData._rearNdSlip = rearSlipDisplaySmoother:get(vData.rearNdSlip, dt)
    end
end

ac.onSharedEvent("AGA_calibrateSteering", function()
    if not uiData.assistEnabled then
        ac.setMessage("Advanced Gamepad Assist", "You have to enable the assist to re-calibrating the steering!")
        return
    end
    if ac.getCar(0).velocity:length() > 0.5 then
        ac.setMessage("Advanced Gamepad Assist", "You must stop the car before re-calibrating the steering!")
        return
    end
    retryCalibration(true)
end)

local brakeTarget = 1.0
local throttleTarget = 1.0

local prevBrakeNd = 0.0
local prevThrottleNd = 0.0

-- Reads controller and keyboard input (if enabled), and performs the initial smoothing and processing
local function processInitialInput(vData, kbMode, steeringRateMult, dt)
    local kbSteer = 0

    if kbMode > 0 then
        -- Applying an extra layer of smoothing to keyboard steering input that works better for key tapping
        local kbRawSteer = (ac.isKeyDown(kbSteerRBind) and 1.0 or 0.0) + (ac.isKeyDown(kbSteerLBind) and -1.0 or 0.0)
        local kbRateMult = (math.abs(kbSteerSmoother.state) - math.sign(kbSteerSmoother.state) * kbRawSteer) > 0.0 and 1.5 or 1.0 -- 2.0 or 1.0 ?
        kbSteer          = kbSteerSmoother:getWithRateMult(kbRawSteer, dt, steeringRateMult * kbRateMult)
    else
        kbSteerSmoother.state = 0.0
    end

    local rawSteer           = sanitizeSteeringInput(vData.inputData.steerStickX + kbSteer)
    local centeringRate      = 1.0 -- Faster centering rate when the steering rate is under 50%
    if uiData.steeringRate > 0.0 then
        if (math.abs(rawSteer) < math.abs(steeringSmoother.state) and math.sign(rawSteer) == math.sign(steeringSmoother.state)) or (math.sign(rawSteer) ~= math.sign(steeringSmoother.state)) then centeringRate = (uiData.steeringRate * 0.5 + 0.25) / uiData.steeringRate end
    end
    local initialSteering    = steeringSmoother:getWithRateMult(rawSteer, dt, steeringRateMult * centeringRate) -- Steering input with no processing (except smoothing)
    local absInitialSteering = absSteeringSmoother:getWithRateMult(math.abs(rawSteer), dt, steeringRateMult * centeringRate) -- Absolute steering input with no processing (except smoothing)

    local kbThrottle = 0.0
    local kbBrake    = 0.0

    if kbMode > 0 then
        kbThrottle = kbThrottleSmoother:get(ac.isKeyDown(kbThrottleBind) and 1.0 or 0.0, dt)
        kbBrake    = kbBrakeSmoother:get(ac.isKeyDown(kbBrakeBind) and 1.0 or 0.0, dt)
    else
        kbThrottleSmoother.state = 0.0
        kbBrakeSmoother.state    = 0.0
    end

    -- // FIXME detect these in a better way
    local brakeNdUsed     = vData.totalNdSlip
    local slipSub         = math.lerp(0.3, 0.4, lib.clamp01(lib.inverseLerp(40.0, 160.0, vData.localHVelLen * 3.6)))
    local throttleNdUsed  = ((vData.vehicle.tractionType == 1) and vData.frontNdSlip or vData.rearNdSlip) - slipSub
    extras.brakeNdUsed    = brakeNdUsed
    extras.throttleNdUsed = throttleNdUsed

    if kbMode > 0 then

        local finalBrakeTarget = 1.0
        local finalThrottleTarget = 1.0

        if kbMode > 1 then
            if vData.vehicle.absMode == 0 then
                -- Applying brake assistance to keyboard input
                local brakNdUsed2     = brakeNdUsed + 0.1
                local extBrakeNd      = math.clamp(brakNdUsed2 + dt * 5000.0 * (brakNdUsed2 - prevBrakeNd), 0, 2.0)
                brakeTarget           = sanitize01Input(math.max(0.3, brakeTarget + dt * 10.0 * (extBrakeNd < 1 and (-1.0 * extBrakeNd + 1.0) or (-3.0 * extBrakeNd + 3.0))))
                finalBrakeTarget      = brakeTarget
                prevBrakeNd           = brakNdUsed2
            end
        end

        if kbMode > 2 then
            if vData.vehicle.tractionControlMode == 0 then
                -- Applying throttle assistance to keyboard input
                local extThrottleNd     = math.clamp(throttleNdUsed + dt * 5000.0 * (throttleNdUsed - prevThrottleNd), 0, 2.0)
                local tMin              = math.lerp(0.6, 0.8, lib.clamp01(lib.inverseLerp(40.0, 160.0, vData.localHVelLen * 3.6)))
                throttleTarget          = sanitize01Input(math.max(tMin, throttleTarget + dt * 10.0 * (extThrottleNd < 1 and (-1.0 * extThrottleNd + 1.0) or (-3.0 * extThrottleNd + 3.0))))
                finalThrottleTarget     = throttleTarget
                prevThrottleNd          = throttleNdUsed
                extras.kbThrottleTarget = throttleTarget
            end
        else
            extras.kbThrottleTarget = 1.0
        end

        vData.inputData.brake = sanitize01Input(vData.inputData.brake + kbBrake * finalBrakeTarget)
        vData.inputData.gas   = sanitize01Input(vData.inputData.gas + kbThrottle * finalThrottleTarget)

    else
        extras.kbThrottleTarget = 1.0
    end

    return initialSteering, absInitialSteering
end

function script.update(dt)
    if car.isAIControlled or not car.physicsAvailable then return end

    local vData = getVehicleData(dt, not uiData.assistEnabled) -- Vehicle data such as velocities, slip angles etc.

    if not vData then return end

    if uiData.assistEnabled and not calibrationSuccess then
        ac.setMessage("Advanced Gamepad Assist", "Error - Failed to calibrate steering. Stop the vehicle and try again. Using fallback values.")
        calibrationSuccess = true
    end

    if uiData.assistEnabled and calibrationSuccess and calibrationTries > 0 then
        ac.setMessage("Advanced Gamepad Assist", "Calibration successful!")
        calibrationTries = 0
    end

    updateConfig(vData.inputData) -- Updates the config values based on the settings in the UI app

    local desiredSteering = 0 -- The desired steering angle normalized to the car's steering lock
    local assistFadeIn    = 0 -- Controls how the steering processing is faded in and out at low speeds

    if uiData.assistEnabled then
        local steeringRateMult                    = calcSteeringRateMult(vData.localHVelLen, vData.steeringLockDeg)
        local initialSteering, absInitialSteering = processInitialInput(vData, uiData.keyboardMode, steeringRateMult, dt)

        updateTargetSlipAngle(vData, initialSteering, dt) -- Dynamically adjusts the target slip angle for the front wheels

        assistFadeIn            = math.lerpInvSat(vData.fAxleHVelLen, 2.0, 6.0)
        local processedSteering = calcCorrectedSteering(vData, targetFrontSlipSmoother:value(), initialSteering, absInitialSteering, steeringRateMult, dt)

        desiredSteering         = math.lerp(initialSteering, processedSteering, assistFadeIn)
        vData.inputData.steer   = sanitizeSteeringInput(normalizedSteeringToInput(desiredSteering, vData.steeringCurveExponent)) -- Final steering input sent to the car

        extras.update(vData, uiData, absInitialSteering, dt) -- Updating extra functionality like auto clutch etc.
    end

    updateDisplayValues(vData, assistFadeIn, uiData.assistEnabled, dt) -- Updating graphs

    -- Logging data

    local steeringAngleGraphLimit = math.ceil(vehicleSteeringLock / 10.0) * 10.0

    ac.debug("A) Relative front slip [%]",            math.round(vData.frontNdSlip * 100.0, 1), 0.0, 200.0)
    ac.debug("B) Relative rear slip [%]",             math.round(vData.rearNdSlip * 100.0, 1), 0.0, 200.0)
    ac.debug("C) Target front slip angle [deg]",      math.round(targetFrontSlipSmoother:value(), 2), 0.0, 20.0)
    ac.debug("D) Front slip angle [deg]",             math.round(vData.frontSlipDeg, 2), -45.0, 45.0)
    ac.debug("E) Rear slip angle [deg]",              math.round(vData.rearSlipDeg, 2), -45.0, 45.0)
    ac.debug("F) Measured steering lock [deg]",       math.round(vData.steeringLockDeg, 2), -90.0, 90.0)
    ac.debug("G) Steering angle [deg]",               math.round(getCurrentSteeringAngleDeg(vData.vehicle, vData.inverseBodyTransform), 2), -steeringAngleGraphLimit, steeringAngleGraphLimit)
    ac.debug("H) Intended steering angle [deg]",      math.round(desiredSteering * vData.steeringLockDeg, 2), -steeringAngleGraphLimit, steeringAngleGraphLimit)
    ac.debug("I) Steering curve exponent (measured)", math.round(vData.steeringCurveExponent, 3))
    ac.debug("J) RPM",                                vData.vehicle.rpm, 0.0, vData.maxRPM)
    ac.debug("K) Engine limiter active",              vData.vehicle.isEngineLimiterOn)
    -- L is power, logged from extras
    ac.debug("M) Extended physics",                   vData.vehicle.extendedPhysics)
end

ac.onRelease(function()
    uiData._appCanRun = false
end)
local M = {}

-- Returns the sum of all elements in the array `t`, and the number of elements that were summed.
-- The returned sum can be `nil` if it can't be calculated.
-- If `extractor` is provided, the return value of `extractor(element)` will be used in place of each array element.
-- If `extractor(element)` returns `nil`, the element is skipped and the returned sum and count will reflect this.
function M.sum(t, extractor)
    extractor = extractor or function(val) return val end

    if #t == 0 then
        return nil
    end

    local acc = nil
    local count = 0

    for _, tVal in ipairs(t) do
        local transformed = extractor(tVal)
        if transformed ~= nil then
            count = count + 1
            if acc == nil then
                acc = transformed
            else
                acc = acc + transformed
            end
        end
    end

    return acc, count
end

-- Returns the lowest and highest values in a table
function M.tableLimits(t)
    if #t == 0 then
        return nil, nil
    end

    local minVal = t[1]
    local maxVal = t[1]

    for _, tVal in ipairs(t) do
        if tVal < minVal then minVal = tVal end
        if tVal > maxVal then maxVal = tVal end
    end

    return minVal, maxVal
end

-- Like a clamp, but the output has a smooth transition (parabolic easing) to the min and max values instead of a sudden cutoff.
-- `easingWindow` should be between `0.0` - `1.0`, it's normalized to the range given by `minVal` - `maxVal`.
-- Example graph of `clampEased(x, 0.0, 10.0, 0.4)` : https://i.imgur.com/WY9zYHK.png
function M.clampEased(val, minVal, maxVal, easingWindow)
    local windowScaled     = easingWindow * (maxVal - minVal)
    local halfWindowScaled = windowScaled * 0.5
    local minLow           = minVal - halfWindowScaled
    local minHigh          = minVal + halfWindowScaled
    local maxLow           = maxVal - halfWindowScaled
    local maxHigh          = maxVal + halfWindowScaled

    if val < minLow  then return minVal end
    if val > maxHigh then return maxVal end

    if val < minHigh then
        local t = (val - minLow) / windowScaled -- inverseLerp(val, minLow, minHigh)
        return minVal + t * t * halfWindowScaled
    end
    if val > maxLow then
        local t = (val - maxLow - windowScaled) / windowScaled -- inverseLerp(val - windowScaled, maxLow, maxHigh)
        return maxVal - t * t * halfWindowScaled
    end

    return val
end

function M.signedPow(x, y)
    return math.sign(x) * math.pow(math.abs(x), y)
end

function M.inverseLerp(from, to, value)
    local dif = to - from
    return (math.abs(dif) > 1e-60) and ((value - from) / dif) or 0
end

-- Returns the angle between two vectors in radians. The lengths are optional, you can pass them in to avoid re-calculating them if you already have them.
function M.angleBetween(vecA, vecB, vecALen, vecBLen)
    vecALen = vecALen or vecA:length()
    vecBLen = vecBLen or vecB:length()
    if vecALen * vecBLen == 0 then return 0 end
    return math.acos((vecA.x * vecB.x + vecA.y * vecB.y + vecA.z * vecB.z) / (vecALen * vecBLen))
end

function M.isVec3Valid(v)
    return not ((not v) or math.isNaN(v.x) or math.isNaN(v.y) or math.isNaN(v.z))
end

function M.weightedAverage(values, weights)
    if #values ~= #weights or #values < 1 then return nil end
    local totalWeight = M.sum(weights)
    if not totalWeight or totalWeight == 0 then return nil end
    local avg = values[1] * weights[1]
    for i, v in ipairs(values) do
        if i ~= 1 then
            avg = avg + v * weights[i]
        end
    end
    return avg / totalWeight
end

-- Weighted average function, but specialized for vectors
function M.weightedVecAverage(values, weights, out)
    out = out or vec3()
    if #values ~= #weights or #values < 1 then return out end
    local totalWeight = M.sum(weights)
    if not totalWeight or totalWeight == 0 then return out end
    values[1]:copyTo(out)
    out:scale(weights[1])
    for i, v in ipairs(values) do
        if i ~= 1 then
            out:addScaled(v, weights[i])
        end
    end
    out:scale(1.0 / totalWeight)
    if not M.isVec3Valid(out) then out:set(0, 0, 0) end
    return out
end

function M.clamp01(v)
    return (v < 0) and 0 or ((v > 1) and 1 or v)
end

function M.clamp1Abs(v)
    return (v < -1) and -1 or ((v > 1) and 1 or v)
end

-- Returns the value if the sign of it matches the reference, or 0 otherwise
function M.signClampValue(val, signRef)
    return (math.sign(val) == math.sign(signRef)) and val or 0
end

function M.inverseLerpClampedEased(from, to, val, outMin, outMax, transitionWindow)
    return M.clampEased(M.inverseLerp(from, to, val), outMin, outMax, transitionWindow)
end

-- Ensures that the number is never 0
function M.zeroGuard(v)
    return 1.0 / math.max(math.min(1.0 / v, 1e15), -1e15)
end

-- Returns `v` if `v` is a valid number. Otherwise returns `alt`, or `0` if `alt` is not defined.
function M.numberGuard(v, alt)
    alt = alt or 0
    return (math.isNaN(v) or not v) and alt or v
end

-- Returns `true` if `A` is further from 0 than `B`
function M.furtherFromZero(A, B)
    return math.abs(A) > math.abs(B)
end

-- Calculates the velocity of a point in an object's local space. `localVel` and `outVec` are optional.
function M.getPointVelocity(localPointPos, localAngularVel, localVel, outVec)
    outVec = outVec or vec3()
    localAngularVel:cross(localPointPos, outVec)
    if localVel then outVec:add(localVel) end
    return outVec
end

-- Determines if two vectors are the same, meaning all 3 of their components are within `tolerance` of each other.
function M.isVec3Same(A, B, tolerance)
    tolerance = tolerance or 1e-15
    return (math.abs(A.x - B.x) < tolerance) and (math.abs(A.y - B.y) < tolerance) and (math.abs(A.z - B.z) < tolerance)
end

-- RunningAverage class

M.RunningAverage = {}

function M.RunningAverage:new(length)
    self.__index = self
    return setmetatable({
        length   = length or 3,
        elements = {},
        sum      = nil
    }, self)
end

function M.RunningAverage:add(element)
    if #self.elements >= self.length then
        self.sum = self.sum - table.remove(self.elements, 1)
    end
    table.insert(self.elements, element)
    if self.sum then self.sum = self.sum + element else self.sum = element end
end

function M.RunningAverage:get()
    if #self.elements == 0 then
        return nil
    end
    return self.sum and (self.sum / #self.elements) or nil
end

function M.RunningAverage:reset()
    table.clear(self.elements)
    self.sum      = nil
end

function M.RunningAverage:count()
    return #self.elements
end

-- ValueLimits class

M.ValueLimitsBuffer = {}

function M.ValueLimitsBuffer:new(length)
    self.__index = self
    return setmetatable({
        length   = length or 2,
        elements = {},
        minVal   = nil,
        maxVal   = nil,
    }, self)
end

function M.ValueLimitsBuffer:add(element)
    if self.minVal == nil or element < self.minVal then
        self.minVal = element
    elseif self.maxVal == nil or element > self.maxVal then
        self.maxVal = element
    end

    if #self.elements >= self.length then
        local removed = table.remove(self.elements, 1)
        if removed == self.minVal or removed == self.maxVal then
            self.minVal, self.maxVal = M.tableLimits(self.elements)
        end
    end

    table.insert(self.elements, element)
end

function M.ValueLimitsBuffer:getMin()
    return self.minVal
end

function M.ValueLimitsBuffer:getMax()
    return self.maxVal
end

function M.ValueLimitsBuffer:reset()
    table.clear(self.elements)
    self.minVal = nil
    self.maxVal = nil
end

function M.ValueLimitsBuffer:count()
    return #self.elements
end

-- PID controller class with a clamped output and anti-windup

M.PIDController = {}

function M.PIDController:new(Kp, Ki, Kd, inverted, minOutput, maxOutput)
    self.__index = self
    return setmetatable({
        Kp = Kp or 0,
        Ki = Ki or 0,
        Kd = Kd or 0,
        inverted = inverted,
        minOutput = minOutput or math.NaN,
        maxOutput = maxOutput or math.NaN,
        setpoint = 0,
        integral = 0,
        prevError = 0
    }, self)
end

function M.PIDController:setSetpoint(setpoint)
    self.setpoint = setpoint
end

function M.PIDController:setPID(Kp, Ki, Kd)
    self.Kp = Kp or self.Kp
    self.Ki = Ki or self.Ki
    self.Kd = Kd or self.Kd
end

function M.PIDController:get(currentValue, dt)
    local error = self.inverted and (currentValue - self.setpoint) or (self.setpoint - currentValue)
    local oldIntegral = self.integral
    self.integral = self.integral + (error * dt)
    local derivative = (error - self.prevError) / dt

    local output = (self.Kp * error) + (self.Ki * self.integral) + (self.Kd * derivative)

    if output < self.minOutput then
        output = self.minOutput
        self.integral = oldIntegral
    end

    if output > self.maxOutput then
        output = self.maxOutput
        self.integral = oldIntegral
    end

    self.prevError = error
    return output
end

function M.PIDController:reset()
    self.setpoint = 0
    self.integral = 0
    self.prevError = 0
end

-- SmoothTowards class

M.SmoothTowards = {}

-- `speed` is automatically normalized to the range given by `minValue` and `maxValue`.
-- Linearity: https://i.imgur.com/rXnDJuh.png
function M.SmoothTowards:new(rate, linearity, minValue, maxValue, startingValue)
    startingValue = startingValue or 0
    self.__index = self
    return setmetatable({
        rate          = rate,
        linearity     = linearity,
        range         = maxValue - minValue,
        state         = startingValue,
        startingValue = startingValue
    }, self)
end

function M.SmoothTowards:get(val, dt)
    local linearitySq       = self.linearity * self.linearity
    local rate              = self.rate / (1.0 - (1.0 / (linearitySq + (1.0 / 0.75)))) * 0.5
    local diffAbsNormalized = math.abs((val - self.state) / self.range)
    local diffSign          = math.sign(val - self.state)
    local adjustedRate      = (diffAbsNormalized * (1 - linearitySq) + linearitySq) * rate
    self.state              = self.state + diffSign * math.min(diffAbsNormalized, dt * adjustedRate) * self.range

    return self.state
end

function M.SmoothTowards:getWithRate(val, dt, rate)
    local originalRate = self.rate
    self.rate          = rate
    local ret          = self:get(val, dt)
    self.rate          = originalRate

    return ret
end

function M.SmoothTowards:getWithRateMult(val, dt, rateMult)
    return self:getWithRate(val, dt, self.rate * rateMult)
end

function M.SmoothTowards:value()
    return self.state
end

function M.SmoothTowards:reset()
    self.state = self.startingValue
end

local _valueHistory = {}
function M.measureUpdateRate(key, value, dt)
    if not _valueHistory[key] then
        _valueHistory[key]              = {}
        _valueHistory[key].lastVal      = 0
        _valueHistory[key].tSinceUpdate = 0
        _valueHistory[key].lastRate     = 0
    end
    _valueHistory[key].tSinceUpdate = _valueHistory[key].tSinceUpdate + dt
    if math.abs(value - _valueHistory[key].lastVal) > 1e-15 then
        _valueHistory[key].lastRate     = 1.0 / _valueHistory[key].tSinceUpdate
        _valueHistory[key].tSinceUpdate = 0
        _valueHistory[key].lastVal      = value
    end
    return _valueHistory[key].lastRate
end

return M
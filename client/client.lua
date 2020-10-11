Laser = {}

local function RayCast(origin, destination, flags)
  local ray = StartShapeTestRay(origin.x, origin.y, origin.z, destination.x, destination.y, destination.z, flags, nil, 0)
  return GetShapeTestResult(ray)
end

local function randomFloat(lower, greater)
  return lower + math.random()  * (greater - lower);
end

local function drawLaser(origin, destination, r, g, b, a)
  DrawLine(origin, destination, r, g, b, a)
end

-- Calculates the linearly interpreted point along the line from "fromPoint" to "toPoint"
-- as a percentage between deltaTime and travelTimeBetweenTargets
local function calculateCurrentPoint(fromPoint, toPoint, deltaTime, travelTimeBetweenTargets)
  local desiredDirection = toPoint - fromPoint
  local desiredDirectionDist = #desiredDirection
  local percentOfTravelTime = deltaTime / (travelTimeBetweenTargets * 1000)
  local distance = math.min(desiredDirectionDist * percentOfTravelTime, desiredDirectionDist)
  return fromPoint + (norm(desiredDirection) * distance)
end

local function getNextToIndex(fromIndex, targetPointCount, randomTargetSelection)
  local toIndex = fromIndex
  if randomTargetSelection then
    while toIndex == fromIndex do
      toIndex = math.random(1, targetPointCount)
    end
  else
    toIndex = (fromIndex % targetPointCount) + 1
  end
  return toIndex
end

function Laser.new(originPoint, targetPoints, options)
  local self = {}
  options = options or {}
  assert(options.color == nil or #options.color == 4, "Laser color must have four values {r, g, b, a}")

  self.name = options.name

  local collisionGranularity = 0.01
  local collisionCache = {}
  local visible = true
  local moving = true
  local active = false
  local r, g, b, a = 255, 0, 0, 255
  if options.color then r, g, b, a = table.unpack(options.color) end
  local randomTargetSelection = true
  if options.randomTargetSelection ~= nil then randomTargetSelection = options.randomTargetSelection end
  local maxDistance = options.maxDistance or 20.0
  local travelTimeBetweenTargets = options.travelTimeBetweenTargets or {}
  local minTravelTimeBetweenTargets = travelTimeBetweenTargets[1] or 1.0
  local maxTravelTimeBetweenTargets = travelTimeBetweenTargets[2] or 1.0
  local waitTimeAtTargets = options.waitTimeAtTargets or {}
  local minWaitTimeAtTargets = waitTimeAtTargets ~= nil and waitTimeAtTargets[1] or 0.0
  local maxWaitTimeAtTargets = waitTimeAtTargets ~= nil and waitTimeAtTargets[2] or 0.0

  function self.getActive() return active end
  function self.setActive(toggle)
    if active == toggle then return end
    active = toggle
    if active then self._startLaser() end
  end

  function self.getVisible() return visible end
  function self.setVisible(toggle)
    if visible == toggle then return end
    visible = toggle
  end

  function self.getMoving() return moving end
  function self.setMoving(toggle)
    if moving == toggle then return end
    moving = toggle
  end

  function self.getColor() return r, g, b, a end
  function self.setColor(_r, _g, _b, _a)
    if type(_r) ~= "number" or type(_g) ~= "number" or type(_b) ~= "number" or type(_a) ~= "number" then
      error("(r, g, b, a) must all be integers " .. string.format("{r = %s, g = %s, b = %s, a = %s}", _r, _g, _b, _a))
    end
    r, g, b, a = _r, _g, _b, _a
  end

  function self._getCachedCollision(fromIndex, toIndex, fromPoint, toPoint, deltaTime, currentTravelTime)
    local percentOfTravelTime = deltaTime / (currentTravelTime * 1000)
    local fromCollisionTable = collisionCache[fromIndex]
    if fromCollisionTable == nil then
      fromCollisionTable = {}
      collisionCache[fromIndex] = fromCollisionTable
    end
    local toCollisionTable = fromCollisionTable[toIndex]
    if toCollisionTable == nil then
      toCollisionTable = {}
      collisionCache[fromIndex][toIndex] = toCollisionTable
    end
    local collisionIndex = math.floor((percentOfTravelTime / collisionGranularity) + 0.5)
    local collisionDistance = collisionCache[fromIndex][toIndex][collisionIndex]
    if collisionDistance == nil then
      local delta = currentTravelTime * (collisionIndex * collisionGranularity) * 1000
      local tempPoint = calculateCurrentPoint(fromPoint, toPoint, delta, currentTravelTime)
      local tempDirection = norm(tempPoint - originPoint)
      local tempDestination = originPoint + tempDirection * maxDistance
      local handle, hit, hitPos, surfaceNormal, entity = RayCast(originPoint, tempDestination, 1 | 16)
      if hit then
        collisionDistance = #(hitPos - originPoint)
        collisionCache[fromIndex][toIndex][collisionIndex] = collisionDistance
      else
        collisionDistance = false
        collisionCache[fromIndex][toIndex][collisionIndex] = false
      end
    end
    return collisionDistance
  end

  function self._startLaser()
    if #targetPoints == 1 then
      Citizen.CreateThread(function ()
        local direction = norm(targetPoints[1] - originPoint)
        local destination = originPoint + direction * maxDistance
        while active do
          if visible then
            drawLaser(originPoint, destination, r, g, b, a)
          end
          Wait(0)
        end
      end)
    else
      Citizen.CreateThread(function ()
        local deltaTime = 0
        local fromIndex = 1
        local toIndex = 2
        if randomTargetSelection then
          fromIndex = math.random(1, #targetPoints)
          toIndex = getNextToIndex(fromIndex, #targetPoints, randomTargetSelection)
        end
        local waiting = false
        local waitTime = 0
        local currentTravelTime = randomFloat(minTravelTimeBetweenTargets, maxTravelTimeBetweenTargets)
        while active do
          local fromPoint = targetPoints[fromIndex]
          local toPoint = targetPoints[toIndex]
          local currentPoint = calculateCurrentPoint(fromPoint, toPoint, deltaTime, currentTravelTime)
          local currentDirection = norm(currentPoint - originPoint)
          local collisionDistance = self._getCachedCollision(fromIndex, toIndex, fromPoint, toPoint, deltaTime, currentTravelTime)
          local destination
          if collisionDistance == false then
            destination = originPoint + currentDirection * maxDistance
          else
            destination = originPoint + currentDirection * collisionDistance
          end

          if visible then
            drawLaser(originPoint, destination, r, g, b, a)
          end
          if moving and not waiting then
            if #(toPoint - currentPoint) < 0.001 then
              deltaTime = 0
              fromIndex = toIndex
              toIndex = getNextToIndex(fromIndex, #targetPoints, randomTargetSelection)
              currentTravelTime = randomFloat(minTravelTimeBetweenTargets, maxTravelTimeBetweenTargets)
              if minWaitTimeAtTargets > 0.0 or maxWaitTimeAtTargets > 0.0 then
                waiting = true
                waitTime = randomFloat(minWaitTimeAtTargets, maxWaitTimeAtTargets) * 1000
              end
            end
            deltaTime = deltaTime + (GetFrameTime() * 1000)
          elseif waiting then
            waitTime = waitTime - (GetFrameTime() * 1000)
            if waitTime <= 0.0 then waiting = false end
          end
          Wait(0)
        end
      end)
    end
  end

  return self
end

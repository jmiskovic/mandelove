require('autotable')

sw, sh = love.graphics.getDimensions()

t = 0

local color = love.graphics.setColor
local line = love.graphics.setLineWidth

love.graphics.setBackgroundColor(20, 20, 20)

local xscale = {-2.5, 1}
local yscale = {-sh / sw * 3.5 / 2, sh / sw * 3.5 / 2}

local constMaxIter = 255
local constPointSkip = 64
local constDiverge = 8
local constUpdateTime = 0.2

local pointSkip = constPointSkip
local diverge = constDiverge

local cachedImage
local mandelDone
local drawCloud
local totalPoints
local donePoints

function remap(minA, maxA, minB, maxB, amount)
  return minB + (amount - minA) * (maxB - minB) / (maxA - minA) 
end

function clearData()
  cachedImage = nil
  --diverge = constDiverge
  pointSkip = constPointSkip
  mandel = table.autotable(2)
  mandelDone = table.autotable(2)
  drawCloud = table.autotable(2)
  totalPoints = 0
  donePoints = 0
  for x = 1, sw, pointSkip do
    for y = 1, sh, pointSkip do
      mandel[x][y] = true
      totalPoints = totalPoints + 1
    end
  end
end

function nextLoD()
  drawCloud = table.autotable(2)
  mandel = table.autotable(2)
  totalPoints = 0
  donePoints = 0
  for x = 1, sw, pointSkip do
    for y = 1, sh, pointSkip do
      if not mandelDone[x][y] then
        mandel[x][y] = true
        totalPoints = totalPoints + 1
      end
    end
  end
end

function zoomTowards(focus, factor, min, max)
  local range = max - min
  if factor < 1 then 
    midpoint = (min + range / 2) + (focus - (min + range / 2)) / 2
  else
    midpoint = (min + range / 2) - (focus - (min + range / 2)) / 2
  end
  range = range * factor
  min = midpoint - range / 2
  max = midpoint + range / 2
  return min, max
end

function love.wheelmoved(hor, ver)
  if ver == 0 then return end
  x, y = love.mouse.getPosition()
  local zoom = ver > 0 and 2/3 or 3/2
  xscale = {zoomTowards(remap(0, sw, xscale[1], xscale[2], x), zoom, unpack(xscale))}
  yscale = {zoomTowards(remap(0, sh, yscale[1], yscale[2], y), zoom, unpack(yscale))}
  clearData()
end

function updateFract()
  local startTime = love.timer.getTime()
  local done = true
  for x, col in pairs(mandel) do
    for y, z in pairs(col) do
      done = false
      local xm = remap(0, sw, xscale[1], xscale[2], x)
      local ym = remap(0, sh, yscale[1], yscale[2], y)
      local zx, zy, iter = 0, 0, 0
      local zxn, zyn
      repeat
        ---[[ Mandelbrot: z = z^2 + x + jy
        zxn = zx^2 - zy^2 + xm
        zyn = 2 * zx * zy + ym
        zx, zy = zxn, zyn
        --]]
        --[[ Burning ship: z = |Re(z)| + j * |Im(z)|^2 + x + jy
        zxn = math.abs(zx)^2 - math.abs(zy)^2 + xm
        zyn = 2 * math.abs(zx) * math.abs(zy) + ym
        --]]
        iter = iter + 1
      until (zx^2 + zy^2 > diverge) or (iter > constMaxIter)
      drawCloud[x][y] = iter
      mandelDone[x][y] = true
      mandel[x][y] = nil
      donePoints = donePoints + 1
      if love.timer.getTime() - startTime > constUpdateTime then
        startTime = love.timer.getTime()
        coroutine.yield()
        if donePoints == 0 then return end
      end
    end
  end
  if done then coroutine.yield() end
end

function updateFunc()
  while true do
    updateFract()
  end
end

local updateCoroutine

function love.load()
  clearData()
  updateCoroutine = coroutine.create(updateFunc)
end

function love.update(dt)
  coroutine.resume(updateCoroutine)
end

function love.resize(w, h)
  sw, sh = w, h
  clearData()
end

local cacheTime = love.timer.getTime()

function isCompleted()
  local completed = true
  for x, col in pairs(mandelDone) do
    for y, z in pairs(col) do
      completed = not (z == false)
      break
    end
    if not completed then break end
  end
  return completed
end

function saveCache()
  local screenshot = love.graphics.newScreenshot(true)
  screenshot:mapPixel(
      function(x, y, r, g, b, a)
          return r, g, b, 255
      end)
  cachedImage = love.graphics.newImage(screenshot)
  pointSkip = math.max(0, math.floor(pointSkip / 1.3 - 0.1))
  cacheTime =   love.timer.getTime()
  if pointSkip > 0 then
    nextLoD()
  end
end

function love.draw()
  love.graphics.setColor(255,255,255,255)
  if cachedImage then love.graphics.draw(cachedImage, 0, 0) end

  local completed = isCompleted()

  if completed then
    if pointSkip > 0 then 
      love.graphics.setPointSize(pointSkip)
      for x,col in pairs(drawCloud) do
        for y,iter in pairs(col) do
          local c = math.atan(remap(0, constMaxIter, 0, 1, iter) * 20) * 255 -- * (25 - 20 * donePoints/totalPoints)
          local r, g, b = 40 + 0.5 * c, -80 + 0.5 * c, 60 - 0.3 * c
          love.graphics.setColor(r, g, b, 255)
          love.graphics.points(x, y)
        end
      end
    end
  end

  if completed and pointSkip >= 1 then
    saveCache()
  end
end

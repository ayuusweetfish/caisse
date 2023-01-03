-- convert -density 150 Vividness.pdf -channel rgba -alpha on Vividness.png
-- record=1 ~/Downloads/love-11.4.app/Contents/MacOS/love . && lua links.lua
-- sh links.sh

local W = 960 * 2
local H = 600 * 2
love.window.setMode(
  W, H,
  { fullscreen = false, highdpi = false }
)

local bgImg = love.graphics.newImage('stars.png', { mipmaps = true })
local bgW, bgH = bgImg:getDimensions()
local bgScale = math.max(W / bgW, H / bgH)

local imgs = {}
for i = 0, 20 do
  imgs[i] = love.graphics.newImage(
    string.format('Vividness-%d.png', i),
    { mipmaps = true })
end
local imgW, imgH = imgs[1]:getDimensions()
local imgScale = math.min(W / imgW, H / imgH)

local sequence = {}
for i = 0, 18 do sequence[#sequence + 1] = {i - 1, i, false} end
sequence[#sequence + 1] = {18, 17, true}
for i = 18, 20 do sequence[#sequence + 1] = {i - 1, i, false} end
sequence[#sequence + 1] = {20, -1, false}

local sequencePtr = 0
local fromIdx, toIdx, reversed
local T = 120

local function update()
  if T == 120 then
    if sequencePtr >= #sequence then
      love.event.quit()
      return
    end
    sequencePtr = sequencePtr + 1
    fromIdx, toIdx, reversed = unpack(sequence[sequencePtr])
    T = 0
  end
  T = T + 1
end

local function drawTransition(fromIdx, toIdx, progress, reversed)
  love.graphics.clear(0.99, 0.99, 0.99)
  -- love.graphics.clear(1, 1, 1)
  -- love.graphics.setColor(1, 1, 1, 0.0156)
  -- love.graphics.draw(bgImg, W / 2, H / 2, 0, bgScale, bgScale, bgW / 2, bgH / 2)
  local movt = 1 - math.exp(-3 * progress) * (1 - progress)
  local alphaA = (1 - movt) ^ 2
  local alphaB = movt ^ 2
  local MOVT = H / 60 * (reversed and -1 or 1)
  if fromIdx ~= -1 then
    love.graphics.setColor(1, 1, 1, alphaA)
    love.graphics.draw(
      imgs[fromIdx], W / 2, H / 2 - movt * MOVT,
      0, imgScale, imgScale, imgW / 2, imgH / 2)
  end
  if toIdx ~= -1 then
    love.graphics.setColor(1, 1, 1, alphaB)
    love.graphics.draw(
      imgs[toIdx], W / 2, H / 2 + (1 - movt) * MOVT,
      0, imgScale, imgScale, imgW / 2, imgH / 2)
  end
end

local frameName
local function draw()
  frameName = string.format('%02d.%02d.%02d',
    fromIdx, toIdx, math.floor((T/240) * 60 + 0.5))
  drawTransition(fromIdx, toIdx, T / 120, reversed)
--[[
  if T <= 600 then
    drawTransition(1, 2, math.max(0, math.min(1, (T - 240) / 120)), false)
  elseif T <= 1200 then
    drawTransition(2, 1, math.min(1, (T - 600) / 120), true)
  else
    drawTransition(1, -1, math.min(1, (T - 1200) / 120), false)
  end
]]
end

if os.getenv('record') ~= nil then
  love.filesystem.setIdentity('Vividness')
  love.update = function () end
  local T = 0
  love.draw = function ()
    update()
    T = T + 1
    if T % 4 == 0 then
      draw()
      local name = string.format('Vividness-%s.png', frameName)
      print(name)
      love.graphics.captureScreenshot(name)
    end
  end
else
  local cumtime = 0
  love.update = function (dt)
    cumtime = cumtime + math.min(dt, 1/30)
    while cumtime > 0 do
      cumtime = cumtime - 1/240
      update()
    end
  end
  love.draw = function ()
    draw()
    print(frameName)
  end
end

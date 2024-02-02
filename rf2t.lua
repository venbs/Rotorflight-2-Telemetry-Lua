--RF2 Telemetry Dashboard
--version 0.1

--default values
local modelName = "RF2"
local flyTimer = 0
local txBat = 0
local teleItem = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local teleItemId = {}
local teleItemName = { "RxBt", "Curr", "Capa", "Bat%", "FM", "Roll", "Yaw", "1RSS", "RQly" }
local connected = false
local currMax = 0

local function init()
  modelName = model.getInfo()["name"]
end

local function background()
end

local function run(event)
  if (isConnect()) then
    getTeleId()
    upValues()
  end
  getRadioStatus()
  drawMainPage()
end

function getRadioStatus()
  txBat = string.format("%.1f", getValue('tx-voltage'))
  flyTimer = model.getTimer(0)["value"]
end

function getTeleId()
  -- get telemetry id
  for k, v in pairs(teleItemName) do
    Info = getFieldInfo(v)
    if Info ~= nil then
      teleItemId[k] = Info.id
    end
  end
end

function upValues()
  for k, v in pairs(teleItemId) do
    if v ~= nil then
      teleItem[k] = getValue(v)
    end
  end
  --Detecting maximum current
  if (teleItem[2] > currMax) then
    currMax = teleItem[2]
  end
end

function isConnect()
  local rssi = getValue("1RSS")
  if (rssi ~= 0) then
    connected = true
    return true
  else
    connected = false
    --clear max values
    currMax = 0
    return false
  end
end

function drawMainPage()
  lcd.clear()

  --status bar
  lcd.drawFilledRectangle(0, 0, 128, 8)

  -- modelName
  lcd.drawText(1, 1, modelName, SMLSIZE + INVERS)

  --rxloss tips
  if (connected == false) then
    lcd.drawText(63, 1, "RX LOSS", SMLSIZE + INVERS + BLINK + CENTER)
  end

  -- TX Battery Voltage
  lcd.drawText(127, 1, txBat .. "V", SMLSIZE + RIGHT + INVERS)

  --battery block
  --battery graphic
  lcd.drawFilledRectangle(3, 10, 33, 8, SOLID)
  lcd.drawLine(36, 11, 36, 16, SOLID, FORCE)
  for i = 0, math.ceil(teleItem[4] / 10) do
    lcd.drawFilledRectangle(3 * i + 5, 12, 2, 4, ERASE)
  end

  --battery voltage
  lcd.drawText(3, 21, string.format("%.1f", teleItem[1]) .. "V", MIDSIZE)

  --------------------------------------------------------------
  lcd.drawLine(0, 36, 40, 36, SOLID, FORCE)

  --battery capa
  lcd.drawText(3, 41, string.format("%u", teleItem[3]) .. "mah", SMLSIZE)

  --------------------------------------------------------------
  lcd.drawLine(0, 51, 40, 51, SOLID, FORCE)

  --battery current

  lcd.drawText(3, 55, string.format("%u", teleItem[2]) .. "/" .. string.format("%u", currMax) .. "A", SMLSIZE)

  --other block

  function drawSignal(x, y)
    lcd.drawLine(x, y + 4, x, y + 5, SOLID, FORCE)
    lcd.drawLine(x + 2, y + 2, x + 2, y + 5, SOLID, FORCE)
    lcd.drawLine(x + 4, y, x + 4, y + 5, SOLID, FORCE)
  end

  --timer
  lcd.drawText(86, 11, "Time", SMLSIZE)
  lcd.drawTimer(126, 21, flyTimer, MIDSIZE + RIGHT)

  --------------------------------------------------------------
  lcd.drawLine(85, 36, 127, 36, SOLID, FORCE)

  --LQ
  drawSignal(86, 41)
  lcd.drawText(92, 41, "LQ", SMLSIZE)
  lcd.drawText(126, 41, teleItem[9], SMLSIZE + RIGHT)

  --------------------------------------------------------------
  lcd.drawLine(85, 51, 127, 51, SOLID, FORCE)


  --RSSI
  drawSignal(86, 55)
  lcd.drawText(92, 55, "RSSI", SMLSIZE)
  lcd.drawText(126, 55, teleItem[8], SMLSIZE + RIGHT)

  -- mid block
  lcd.drawFilledRectangle(42, 9, 42, 55, SOLID)

  --headSp
  lcd.drawText(64, 11, teleItem[5], DBLSIZE + INVERS + CENTER)
  lcd.drawText(64, 28, "RPM", SMLSIZE + INVERS + CENTER)
  --------------------------------------------------------------
  lcd.drawLine(44, 36, 81, 36, SOLID, ERASE)
  --esc Temp
  lcd.drawText(44, 41, "Esc", SMLSIZE + INVERS)
  lcd.drawText(83, 41, string.format("%u", math.abs(teleItem[6]) * 100) .. "°C", SMLSIZE + INVERS + RIGHT)
  --throttle
  lcd.drawText(44, 54, "Thr", SMLSIZE + INVERS)
  lcd.drawText(83, 54, string.format("%u", math.abs(teleItem[7]) * 100) .. "%", SMLSIZE + INVERS + RIGHT)
end

return { run = run, background = background, init = init }

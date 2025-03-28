-- Rotorflight Dashboard V2.1
-- 直观简洁的遥测数据面板，支持常见的遥测项，一键配置
-- 自带飞行结束后统计飞行数据，并记录当日飞行次数
-- 自带简易计时器，并在1/2/3/4/5分钟时播报语音提示
-- 仅支持rf2.1以上版本，并需要启用ELRS自定义遥测功能

local modelName = "RFDB2.1"
local deviceDate = {}
local txBat = 0
local teleItem = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 }
local teleItemId = {}
local teleItemName = { "Vbat", "Curr", "Hspd", "Capa", "Bat%", "Tesc", "Thr", "1RSS", "Vbec", "GOV" }
local gov_state_names = { "OFF", "IDLE", "SPOOLUP", "RECOVERY", "ACTIVE", "THR-OFF", "LOST-HS", "AUTOROT", "BAILOUT" }
local connected = false
local armed = false
-- log format 1.Date 2.ModelName 3.Timer 4.Times 5.Capa 6.LowVoltage 7.MaxCurrent 8.MaxPower 9.MaxRPM 10.LowBEC
local flightData = { "20250101", "Model", 0, 0, 0, 0, 0, 0, 0, 0 }
local flightTimes = 0
local showPage = 0 -- 0 Main  1 LogList

local log_v = ""
local log_c = ""
local log_a = ""
local log_r = ""
local logIndex = 1
local logCount = 0
local logListOffsetY = 0
local loglistOrgY = -2
local preUp = false
local preDown = false
local logIsNil = false
local logReadData = {}
for i = 1, 99 do
    logReadData[i] = {}
end

local ShowBoard = false
local closeBoardKey = false
local T_0 = 0 -- 基础时间
local T_P = 0 -- 暂停时间
local T_Ssecond = 0
local T_MM = "00"
local T_SS = "00"
local timerTipsNum = 0

local function init()
    T_0 = getRtcTime()
    -- 获取当日时间
    deviceDate = getDateTime()

    -- 读取当日的log文件 -------------
    local filename = "/LOGS/RFLog_" .. string.format("%04d%02d%02d", deviceDate.year, deviceDate.mon, deviceDate.day) ..
        ".csv"
    local logFile = io.open(filename, "r")
    -- 读取行数获得当日起洛数
    if logFile ~= nil then
        local linecount = 0
        while true do
            logdata = io.read(logFile, 1)
            if logdata == "\n" then
                linecount = linecount + 1
            end
            if not logdata or #logdata == 0 then
                break
            end
        end
        io.close(logFile)
        flightTimes = linecount
    end
end

local function background()
    if (checkConnect() and showPage == 0) then
        getTeleId() -- 先获取遥测id
        upValues()  -- 根据获取的id获取数据
        if (checkArm()) then
            startTimer()
            timerTips()
        else
            pauseTimer()
        end
    end
end

function startTimer()
    T_Ssecond = getRtcTime() - T_0 + T_P
    T_MM = string.format("%02d", math.floor(T_Ssecond / 60))
    T_SS = string.format("%02d", math.floor(T_Ssecond % 60))
end

function pauseTimer()
    T_P = T_Ssecond
    T_0 = getRtcTime()
end

function timerTips()
    if (armed) then
        if tonumber(T_MM) > timerTipsNum then
            timerTipsNum = tonumber(T_MM)
            playNumber(timerTipsNum, 36)
        end
    end
end

local function run(event)
    getRadioStatus()

    lcd.clear()
    drawMainPage()
    drawLogUI()
    -- 检测到按下滚轮
    if (event == EVT_ROT_BREAK) then
        if (ShowBoard) then --  不显示面板时不响应按键
            closeBoardKey = true
            closeBoard()
        end
    end

    -- 检测到按下菜单键
    if (event == EVT_VIRTUAL_MENU) then
        if (showPage == 0) then ---当前是否在首页
            showPage = 1
            loadLogData()       -- 读取数据
        end
    end

    -- 检测到按下返回键
    if (event == EVT_EXIT_BREAK) then
        if (showPage == 1) then ---当前是否在首页
            showPage = 0
            logIndex = 1
            logListOffsetY = 0
        else
            if (ShowBoard) then --  不显示面板时不响应按键
                closeBoardKey = true
                closeBoard()
            end
        end
    end

    -- 检测到滚轮拨动
    if (event == EVT_ROT_LEFT and logCount > 1 and showPage == 1) then
        if logIndex > 1 then
            logIndex = logIndex - 1
            if preUp then
                logListOffsetY = logListOffsetY + 11
                preUp = false
                preDown = false
            end
            print(preUp, preDown)
        end
    end
    if (event == EVT_ROT_RIGHT and logCount > 1 and showPage == 1) then
        if logIndex < logCount then
            logIndex = logIndex + 1
            if preDown then
                logListOffsetY = logListOffsetY - 11
                preDown = false
                preUp = false
            end
            print(preUp, preDown)
        end
    end
end

function getRadioStatus()
    txBat = string.format("%.1f", getValue('tx-voltage'))
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
    -- get modelName
    modelName = model.getInfo()["name"]
    -- get telemetry data
    for k, v in pairs(teleItemId) do
        if v ~= nil then
            teleItem[k] = getValue(v)
        end
    end
    -- updata Capa
    flightData[5] = teleItem[4]

    -- Detecting maximum current
    if (teleItem[2] > flightData[7]) then
        flightData[7] = teleItem[2]
    end

    -- Detecting maximum Hspd
    if (teleItem[3] > flightData[9]) then
        flightData[9] = teleItem[3]
    end

    -- Detecting lower battery
    -- 需要判断小于解锁时的电压，且不为0v（丢帧），且转速大于500转（确保已启动）
    if (teleItem[1] < flightData[6] and teleItem[1] ~= 0 and teleItem[3] > 500) then
        flightData[6] = teleItem[1]
    end

    -- Detecting maximum MaxPower
    local maxPow = teleItem[1] * teleItem[2]
    if (maxPow > flightData[8]) then
        flightData[8] = math.floor(maxPow)
    end

    -- Detecting lower BEC
    if (teleItem[9] < flightData[10] and teleItem[9] ~= 0 and teleItem[3] > 500) then
        flightData[10] = teleItem[9]
    end

    -- -- Detecting maximum G-Force
    -- -- 需要计算合加速度
    -- local totalAcc = math.sqrt(math.pow(teleItem[11], 2) + math.pow(teleItem[12], 2) + math.pow(teleItem[13], 2))

    -- if (totalAcc > flightData[10]) then
    --     flightData[10] = tonumber(string.format("%.2f", totalAcc))
    -- end
end

function checkConnect() -- 判断是否连接
    local rssi = getValue(teleItemName[8])
    if (rssi ~= 0) then
        if not connected then
            -- 连接

            print("connected!")
            connected = true
            T_MM = "00"
            T_SS = "00"

            closeBoard()
            closeBoardKey = false

            ---如果在log页，会返回到回传页

            if (showPage == 1) then
                showPage = 0
                logIndex = 1
                logListOffsetY = 0
            end
        end
        return true
    else
        if connected then
            -- 断开
            connected = false

            print("plautone")

            ----------- 记录飞行数据到本地 -----------------
            function writeLog()
                flightData[1] = string.format("%04d%02d%02d", deviceDate.year, deviceDate.mon, deviceDate.day)
                flightData[2] = model.getInfo()["name"]
                flightData[3] = T_MM .. ":" .. T_SS
                flightData[4] = flightTimes
                flightData[6] = string.format("%.1f", flightData[6])
                flightData[7] = string.format("%.1f", flightData[7])
                flightData[6] = string.format("%u", flightData[6])
                flightData[10] = string.format("%.1f", flightData[10])

                local filename = "/LOGS/RFLog_" .. flightData[1] .. ".csv"
                local logFile = io.open(filename, "a")

                -- 开始写入数据
                for index, logs in ipairs(flightData) do
                    io.write(logFile, logs .. "|")
                end
                io.write(logFile, "\n")

                io.close(logFile)
            end

            -- 判断是飞行是否超过30秒，超过则算作一次有效飞行
            if (T_Ssecond > 30) then
                flightTimes = flightTimes + 1
                writeLog()
            end

            -- show flightData board
            if not closeBoardKey then
                ShowBoard = true
            end

            -- reset timertips
            timerTipsNum = 0
        end
        -- pausetimer
        pauseTimer()
        T_P = 0
        T_Ssecond = 0
        return false
    end
end

function checkArm()
    local ch5 = getValue("ch5")
    if (ch5 > 0) then
        if not armed then                -- first arm 记录一次最大电压
            flightData[6] = teleItem[1]  -- BAT
            flightData[10] = teleItem[9] -- BEC
        end
        armed = true
        return armed
    else
        armed = false
        return armed
    end
end

function loadLogData()
    filename = "/LOGS/RFLog_" .. string.format("%04d%02d%02d", deviceDate.year, deviceDate.mon, deviceDate.day) ..
        ".csv"
    logFile = io.open(filename, "r")
    if logFile ~= nil then
        logIsNil = false
        local logdata = ""
        local buffer = ""
        local line = 1
        local key = 1

        ---开始读取数据
        while true do
            logdata = io.read(logFile, 1)        -- 每次读取1个字节

            if not logdata or #logdata == 0 then -- 读到文件尾时结束
                io.close(logFile)
                break
            else
                if logdata ~= "|" and logdata ~= "\n" then -- 非分隔符或者换行符，则为正常数据
                    buffer = buffer .. logdata             -- 拼接
                end
                if logdata == "|" then                     -- 读到分割符时，将拼接的字节注入table
                    logReadData[line][key] = buffer
                    buffer = ""
                    key = key + 1
                end
                if logdata == "\n" then
                    line = line + 1
                    key = 1
                    logCount = line - 1
                end
            end
        end
    else
        logIsNil = true
    end
end

function drawDataBoard()
    if (ShowBoard) then
        lcd.drawFilledRectangle(0, 0, 128, 64)
        lcd.drawFilledRectangle(2, 3, 124, 58, ERASE)
        lcd.drawRectangle(3, 4, 122, 56, FORCE)

        lcd.drawLine(4, 21, 123, 21, SOLID, FORCE)
        lcd.drawFilledRectangle(104, 5, 20, 16, FORCE)

        -- timer
        lcd.drawText(7, 7, T_MM .. ":" .. T_SS, MIDSIZE)
        -- date
        lcd.drawText(52, 10, string.format("%04d-%02d-%02d", deviceDate.year, deviceDate.mon, deviceDate.day), SMLSIZE)
        -- times
        lcd.drawText(115, 7, flightTimes, MIDSIZE + INVERS + CENTER)

        -- capa
        drawBatIcon(8, 26)
        lcd.drawText(20, 25, flightData[5] .. "mAh", SMLSIZE + LEFT)
        -- maxcurrent
        drawFlashIcon(8, 37)
        lcd.drawText(20, 37, flightData[7] .. "A", SMLSIZE + LEFT)
        -- maxrpm
        drawRotorIcon(8, 50)
        lcd.drawText(20, 49, flightData[9] .. "RPM", SMLSIZE + LEFT)

        -- voltage
        drawBatIcon(72, 26)
        lcd.drawText(85, 25, string.format("%.1f", flightData[6]) .. "V", SMLSIZE + LEFT)
        -- maxpower
        drawFlashIcon(72, 37)
        lcd.drawText(85, 37, flightData[8] .. "W", SMLSIZE + LEFT)
        -- low bec
        drawBEC(71, 50)
        lcd.drawText(85, 49, string.format("%.1f", flightData[10]) .. "V", SMLSIZE + LEFT)
    end
end

function closeBoard()
    -- hide flightdata board
    ShowBoard = false

    -- reset all flight data
    flightData = { "Model", "20250101", 0, 0, 0, 0, 0, 0, 0, 0 }
end

function drawMainPage()
    if showPage == 0 then
        lcd.clear()

        -- status bar
        lcd.drawFilledRectangle(0, 0, 128, 8)

        -- modelName
        lcd.drawText(1, 1, modelName, SMLSIZE + INVERS)

        -- Flight mode
        if (connected == false) then
            lcd.drawText(63, 1, "RX LOSS", SMLSIZE + INVERS + BLINK + CENTER)
        else
            lcd.drawText(63, 1, gov_state_names[teleItem[10]], SMLSIZE + INVERS + CENTER)
        end

        -- TX Battery Voltage
        lcd.drawText(127, 1, txBat .. "V", SMLSIZE + RIGHT + INVERS)

        -- battery block
        -- battery graphic
        lcd.drawFilledRectangle(2, 10, 33, 8, SOLID)
        lcd.drawLine(35, 11, 35, 16, SOLID, FORCE)
        for i = 0, math.ceil(teleItem[5] / 10) - 1, 1 do
            lcd.drawFilledRectangle(3 * i + 4, 12, 2, 4, ERASE)
        end

        -- battery voltage
        lcd.drawText(2, 21, string.format("%.1f", teleItem[1]) .. "V", MIDSIZE)

        --------------------------------------------------------------
        lcd.drawLine(0, 36, 40, 36, SOLID, FORCE)

        -- battery capa
        lcd.drawText(2, 41, string.format("%u", teleItem[4]) .. "mah", SMLSIZE)

        --------------------------------------------------------------
        lcd.drawLine(0, 51, 40, 51, SOLID, FORCE)

        -- battery current

        lcd.drawText(2, 55, string.format("%u", teleItem[2]) .. "/" .. string.format("%u", flightData[7]) .. "A",
            SMLSIZE)

        -- other block

        function drawSignal(x, y)
            lcd.drawLine(x, y + 4, x, y + 5, SOLID, FORCE)
            lcd.drawLine(x + 2, y + 2, x + 2, y + 5, SOLID, FORCE)
            lcd.drawLine(x + 4, y, x + 4, y + 5, SOLID, FORCE)
        end

        -- timer
        lcd.drawText(86, 11, "Time", SMLSIZE)
        lcd.drawText(126, 21, T_MM .. ":" .. T_SS, MIDSIZE + RIGHT)

        --------------------------------------------------------------
        lcd.drawLine(85, 36, 127, 36, SOLID, FORCE)

        -- BEC
        lcd.drawText(86, 41, "BEC", SMLSIZE)
        lcd.drawText(126, 41, string.format("%.1f", teleItem[9]) .. "V", SMLSIZE + RIGHT)

        --------------------------------------------------------------
        lcd.drawLine(85, 51, 127, 51, SOLID, FORCE)

        -- RSSI
        drawSignal(88, 55)
        lcd.drawText(126, 55, teleItem[8] .. "dB", SMLSIZE + RIGHT)

        -- mid block
        lcd.drawFilledRectangle(42, 9, 42, 55, SOLID)

        -- headSp
        lcd.drawText(64, 11, teleItem[3], DBLSIZE + INVERS + CENTER)
        lcd.drawText(64, 28, "RPM", SMLSIZE + INVERS + CENTER)
        --------------------------------------------------------------
        lcd.drawLine(44, 36, 81, 36, SOLID, ERASE)
        -- throttle
        lcd.drawText(44, 41, "Thr", SMLSIZE + INVERS)
        lcd.drawText(83, 41, teleItem[7] .. "%", SMLSIZE + INVERS + RIGHT)
        -- esc Temp
        lcd.drawText(44, 54, "ESC", SMLSIZE + INVERS)
        lcd.drawText(83, 54, teleItem[6] .. "°C", SMLSIZE + INVERS + RIGHT)

        -- draw flightdata board
        drawDataBoard()
    end
end

function drawLogUI()
    if showPage == 1 then
        if logIsNil then
            log_v = "-- "
            log_c = "-- "
            log_a = "-- "
            log_r = "-- "
            --- 无日志数据时显示""
            lcd.drawText(16, 32, "No logs!", SMLSIZE + LEFT)
        else
            log_v = logReadData[logIndex][6]
            log_c = logReadData[logIndex][5]
            log_a = logReadData[logIndex][7]
            log_r = logReadData[logIndex][9]
        end

        for i = 1, logCount do
            LogPosY = i * 11 + logListOffsetY + loglistOrgY

            if LogPosY > 0 and LogPosY < 64 then ---超出屏幕的部分不渲染
                local Sta = false                ---默认不被选中
                if i == logIndex then
                    Sta = true                   ---当前指针位置选中
                    if LogPosY > 42 then
                        preDown = true
                    else
                        preDown = false
                    end

                    if LogPosY < 11 then
                        preUp = true
                    else
                        preUp = false
                    end
                end
                drawLogItem(i, logReadData[i][2], logReadData[i][3], LogPosY, Sta)
            end
        end

        --------------------------------------------------------------
        -- status bar
        lcd.drawFilledRectangle(0, 0, 128, 8, FORCE)

        -- title
        lcd.drawText(1, 1, string.format("%04d-%02d-%02d", deviceDate.year, deviceDate.mon, deviceDate.day),
            SMLSIZE + INVERS)

        -- Log Date
        lcd.drawText(127, 1, logCount .. " Flights", SMLSIZE + RIGHT + INVERS)
        --------------------------------------------------------------

        lcd.drawFilledRectangle(75, 8, 1, 56, FORCE)

        --------------------------------------------------------------
        -- voltage
        drawBatIcon(79, 14)
        lcd.drawText(90, 13, log_v .. "V", SMLSIZE + LEFT)
        -- battery used
        drawBatIcon(79, 27)
        lcd.drawText(90, 26, log_c .. "mAh", SMLSIZE + LEFT)
        -- MaxCurrent
        drawFlashIcon(79, 39)
        lcd.drawText(90, 39, log_a .. "A", SMLSIZE + LEFT)
        -- Max RPM
        drawRotorIcon(79, 53)
        lcd.drawText(90, 52, log_r .. "RPM", SMLSIZE + LEFT)
    end
end

-----------绘图函数
function drawBatIcon(x, y)
    lcd.drawFilledRectangle(x, y, 7, 5, FORCE)
    lcd.drawLine(x + 8, y + 1, x + 8, y + 3, SOLID, FORCE)
end

function drawFlashIcon(x, y)
    lcd.drawFilledRectangle(x + 3, y, 1, 7, FORCE)
    lcd.drawFilledRectangle(x, y + 3, 7, 1, FORCE)
    lcd.drawLine(x + 2, y + 1, x + 4, y + 5, SOLID, FORCE)
    lcd.drawLine(x + 5, y + 4, x + 1, y + 2, SOLID, FORCE)
end

function drawRotorIcon(x, y)
    lcd.drawFilledRectangle(x, y, 3, 2, FORCE)
    lcd.drawFilledRectangle(x + 6, y, 3, 2, FORCE)
    lcd.drawFilledRectangle(x + 4, y, 1, 5, FORCE)
end

function drawArrowIcon(x, y)
    lcd.drawLine(x + 3, y, x, y + 3, SOLID, FORCE)
    lcd.drawLine(x + 3, y, x + 6, y + 3, SOLID, FORCE)
    lcd.drawFilledRectangle(x + 2, y + 2, 3, 1, FORCE)
    lcd.drawFilledRectangle(x + 3, y + 1, 1, 5, FORCE)
end

function drawBEC(x, y)
    lcd.drawFilledRectangle(x, y + 1, 7, 1, FORCE)
    lcd.drawFilledRectangle(x, y + 3, 7, 1, FORCE)
    lcd.drawRectangle(x + 3, y, 6, 5, FORCE)
    lcd.drawFilledRectangle(x + 4, y + 2, 4, 1, FORCE)
end

function drawLogItem(Num, Name, Timer, PosY, Selected)
    if not Selected then
        lcd.drawFilledRectangle(0, PosY, 70, 10, SOLID)
        lcd.drawFilledRectangle(13, PosY + 1, 56, 8, ERASE)
        lcd.drawText(14, PosY + 2, Name, SMLSIZE)
        lcd.drawText(69, PosY + 2, Timer, SMLSIZE + RIGHT)
    else
        lcd.drawFilledRectangle(0, PosY, 73, 10, SOLID)
        lcd.drawText(14, PosY + 2, Name, SMLSIZE + INVERS)
        lcd.drawText(72, PosY + 2, Timer, SMLSIZE + RIGHT + INVERS)
    end
    lcd.drawText(2, PosY + 2, string.format("%02d", Num), SMLSIZE + INVERS)
end

return {
    run = run,
    background = background,
    init = init
}

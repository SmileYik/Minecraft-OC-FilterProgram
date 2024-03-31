local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local worker = {}
local modem = component.modem

local PORT = 16500
local SLEEP = 0.05
local FILTER_DELAY = 10
local filter = false
local filterDelay = 0
local runningFlag = true


modem.open(PORT)


-- command = {
--     name = "abc",
--     data = ???
-- }

local function getModemMessage(sleep)
    local t, _, from, port, _, message = computer.pullSignal(sleep)
    if t ~= "modem_message" or from == modem.address then return nil end
    return from, port, serialization.unserialize(message)
end

local function sendMessage(addr, port, table)
    modem.send(addr, port, serialization.serialize(table))
end

local function sendSuccessMessage(addr, port, msg)
	sendMessage(addr, port, {name = "showMessage", data = msg})
end

local commands = {}


function commands.getInterfaces(from, port, message)
    print("搜索接口")
    local interfaces = {}
    for address in pairs(component.list("me_interface")) do
        table.insert(interfaces, address)
    end
    sendMessage(from, port, {name = "registerInterfaces", data = interfaces})
end


function commands.setFilterStatus(from, port, message)
    filter = message.data.status
    filterDelay = 0
    print("筛选状态：", filter)
    if filter then sendSuccessMessage(from, port, "开启筛选")
    else sendSuccessMessage(from, port, "停止筛选") end
end


function commands.shutdown(from, port, message)
    runningFlag = false
    sendSuccessMessage(from, port, "终端即将终止")
end


function commands.updateRules(from, port, message)
    worker.updateRules(message.data)
    sendSuccessMessage(from, port, "接收且更新物品标签规则")
end

function commands.updateFiles(from, port, message)
    local file = io.open(string.format("/home/%s", message.data.fileName), "w")
    if file ~= nil then
        file:write(message.data.content)
        file:flush()
        file:close()
        print(message.data.fileName .. " 已更新， 请重启机器")
        if message.data.reboot then
            print("即将自动重启")
            os.sleep(0.5)
            computer.shutdown(true)
        end
    else
        print(message.data.fileName .. " 无法更新。")
    end
end

local function handleMessage()
    local from, port, message = getModemMessage(SLEEP)
    if from == nil or message == nil or message.name == nil then return end
    if commands[message.name] ~= nil then
        commands[message.name](from, port, message)
    end
end

local function main()
    handleMessage()
    if not filter then return end
    if filterDelay <= 0 then
        filterDelay = FILTER_DELAY
        worker.work()
    end
    filterDelay = filterDelay - SLEEP
end

local file = io.open("/home/worker.lua")
if file ~= nil then
    file:close()
    worker = require("worker")
end

while runningFlag do main() end

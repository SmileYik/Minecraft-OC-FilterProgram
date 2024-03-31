local component = require("component")
local computer = require("computer")
local reader = require("list_reader")
local serialization = require("serialization")
local setting = require("setting")
local chooser = require("role_chooser")
local config = require("config")
local ruleSpawner = require("rule_spawner")
local modem = component.modem
local PORT = 16500
local WAIT_RESPONSE = 0.05
modem.open(PORT)

local interfaceHost = {}

local function getModemMessage(sleep)
    local t, _, from, port, _, message = computer.pullSignal(sleep)
    if t ~= "modem_message" or from == modem.address then return nil end
    return from, port, serialization.unserialize(message)
end

local function sendMessage(addr, port, table)
    modem.send(addr, port, serialization.serialize(table))
end

local function searchInterface()
    local result = {}
    modem.broadcast(PORT, serialization.serialize({name = "getInterfaces"}))
    for _ = 1, 100 do
        local from, _, message = getModemMessage(WAIT_RESPONSE)
        if message ~= nil and message.name == "registerInterfaces" then
            for _, address in pairs(message.data) do
                result[address] = from
            end
        end
    end
    return result
end

local function waitResponse()
    for _ = 1, 100 do
        local from, _, message = getModemMessage(WAIT_RESPONSE)
        if message ~= nil and message.name == "showMessage" then
            print(from .. ": " .. message.data)
            break
        end
    end
end

local function updateRules()
    local rules = ruleSpawner.spawnRules()
    for iaddr, hostAddr in pairs(interfaceHost) do
        local role = setting.getAddressName(iaddr)
        if role ~= nil and rules[role] ~= nil then
            sendMessage(
                hostAddr, PORT,
                {
                    name = "updateRules",
                    data = {
                        address = iaddr,
                        rules = rules[role]
                    }
                }
            )
            waitResponse()
        end
    end
end

local function setOreProccess()
    local choosed = chooser.chooseProcessWithCheck()
    if choosed == nil then return end
    local str = ""
    for i, role in pairs(choosed) do
        str = str .. role .. " => "
    end
    str = str .. "结束"
    io.write(string.format("你选择的流程为：%s, 是否继续？\n> ", str))
    local ans = io.read()
    if ans == "n" then return end

    print("请输入矿石名称，如‘红石矿石’则输入‘红石’，停止添加时输入 ‘exit’")
    while true do
        io.write("\n> ")
        local ore = io.read()
        if ore == "exit" then break end
        io.write(string.format("是否将%s矿石制作工艺设置为：%s\n> ", ore, str))
        if io.read() ~= "n" then
            setting.setProcess(ore, choosed)
            setting.store()
            updateRules()
        end
    end
end

local function viewOreProcess()
    local all = setting.getAllProcessNames()
    local keyList, selected = reader.show(
        all,
        function(key, _) return key end,
        function(key, _) return key end
    )
    if selected == 0 then
        return
    end
    io.write("是否查看名单？")
    if io.read() ~= "n" then
        reader.showList(all[keyList[selected]])
    end
end

local function updateFileToClient(fileName)
    local file = io.open("/home/" .. fileName, "r")
    if file == nil then print("无 " .. fileName .. " 文件") return end
    local data = file:read("*a")
    file:close()
    local set = {}
    for _, addr in pairs(interfaceHost) do
        if set[addr] == nil then
            sendMessage(addr, PORT, {name = "updateFiles", data = {content = data, fileName = fileName, reboot = true}})
            set[addr] = true
        end
    end
end

local function setIdBlacklist()
    local role = chooser.chooseRole()
    io.write(string.format("已选择‘%s’职责, 输入空数据退出\n", role))
    while true do
        io.write("> ")
        local id = io.read()
        if id == nil or id == "" then break end
        io.write(string.format("输入了 %s, 是否继续\n> ", id))
        if io.read() ~= "n" then
            setting.addIdBlacklist(role, id)
            setting.store()
            updateRules()
        end
    end

end

local function setIdWhitelist()
    local role = chooser.chooseRole()
    io.write(string.format("已选择‘%s’职责, 输入空数据退出\n", role))
    while true do
        io.write("> ")
        local id = io.read()
        if id == nil or id == "" then break end
        io.write(string.format("输入了 %s, 是否继续\n> ", id))
        if io.read() ~= "n" then
            setting.addIdWhitelist(role, id)
            setting.store()
            updateRules()
        end
    end
end

local function main()
    io.write(
        "1. 设定矿处工艺\t2. 开始筛选\n" ..
        "3. 停止筛选\t4. 配置接口\n" ..
        "5. 查看矿处工艺\t6. 更新终端Woker\n" ..
        "7. 更新终端客户端\t8.上传文件\n" ..
        "9. 设置物品黑名单\t10. 设置物品白名单\n" ..
        "> "
    )
    local input = io.read()
    if input == "0" or input == "exit" then return false
    elseif input == "1" then setOreProccess()
    elseif input == "2" then
        updateRules()
        modem.broadcast(PORT, serialization.serialize({name = "setFilterStatus", data = {status = true}}))
    elseif input == "3" then modem.broadcast(PORT, serialization.serialize({name = "setFilterStatus", data = {status = false}}))
    elseif input == "5" then viewOreProcess()
    elseif input == "6" then updateFileToClient("worker.lua")
    elseif input == "7" then updateFileToClient("client.lua")
    elseif input == "8" then io.write("\n> ") updateFileToClient(io.read())
    elseif input == "9" then setIdBlacklist()
    elseif input == "10" then setIdWhitelist()
    end
    return true
end

local function init()
    while true do
        local result = searchInterface()
        local unconfig = {}
        local flag = false
        for address, ip in pairs(result) do
            if not setting.isConfigurated(address) then
                unconfig[address] = ip
                flag = true
            end
        end

        if flag then
            local keyList, selected = reader.show(
                unconfig,
                function(key, _) return key end,
                function(key, _) return key end
            )
            if selected ~= 0 then
                io.write(string.format("是否选中 %s?\n> ", keyList[selected]))
                if io.read() ~= "n" then
                    config.configurateInterface(keyList[selected])
                end
            end
        else
            interfaceHost = result
            break
        end
    end
end

setting.init()
init()

while main() do  end

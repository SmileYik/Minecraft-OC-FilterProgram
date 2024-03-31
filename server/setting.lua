local serialization = require("serialization")

local setting = {}

setting.FILE = "/home/.setting.new"

function setting.init()
    local file = io.open(setting.FILE, "r")
    if file ~= nil then
        setting.data = serialization.unserialize(file:read("*a"))
        file:close()
    end
--     setting.data = {
--         interfaces = {},
--         role = {name = "type"}
--     }
    if setting.data == nil then setting.data = {} end
    if setting.data.interfaces == nil then setting.data.interfaces = {} end
    if setting.data.role == nil then setting.data.role = {} end
    if setting.data.process == nil then setting.data.process = {} end
    if setting.data.processReverse == nil then setting.data.processReverse = {} end
    if setting.data.idWhitelist == nil then setting.data.idWhitelist = {} end
    if setting.data.idBlacklist == nil then setting.data.idBlacklist = {} end
end

function setting.store()
    local file = io.open(setting.FILE, "w")
    file:write(serialization.serialize(setting.data))
    file:flush()
    file:close()
end

function setting.isConfigurated(address)
    return setting.data.interfaces[address] ~= nil
end

function setting.setInterfaceRole(address, role)
    setting.data.interfaces[address] = role
end

function setting.getRole(role)
    return setting.data.role[role]
end

function setting.getRoles()
    return setting.data.role
end

function setting.setRole(role, t)
    setting.data.role[role] = t
end

function setting.getAddressName(address)
    return setting.data.interfaces[address]
end

function setting.getAddressRole(address)
    return setting.data.role[setting.getAddressName(address)]
end

function setting.removeProcess(name)
    if setting.data.process == nil or setting.data.process[name] == nil then return end
    local process = table.concat(setting.data.process[name], "=>")

    if setting.data.processReverse ~= nil and setting.data.processReverse[process] ~= nil then
        for i, v in pairs(setting.data.processReverse[process]) do
            if v == name then
                table.remove(setting.data.processReverse[process], i)
                break
            end
        end
    end

    setting.data.process[name] = nil
end

function setting.setProcess(name, process)
    setting.removeProcess(name)
    setting.data.process[name] = process
    local pid = table.concat(setting.data.process[name], "=>")
    if setting.data.processReverse[pid] == nil then
        setting.data.processReverse[pid] = {}
    end
    table.insert(setting.data.processReverse[pid], name)
    setting.store()
end

function setting.getNamesByProcess(process)
    return setting.data.processReverse[process]
end

function setting.getAllProcessNames()
    return setting.data.processReverse
end

function setting.getProcess(name)
    if setting.data.process[name] == nil then return {} end
    return setting.data.process[name]
end

function setting.getAllProcess()
    return setting.data.process
end

function setting.addIdWhitelist(role, id)
    if setting.data.idWhitelist[role] == nil then setting.data.idWhitelist[role] = {} end
    setting.data.idWhitelist[role][id] = true
end

function setting.addIdBlacklist(role, id)
    if setting.data.idBlacklist[role] == nil then setting.data.idBlacklist[role] = {} end
    setting.data.idBlacklist[role][id] = true
end

function setting.getAllIdWhitelist()
    return setting.data.idWhitelist
end

function setting.getAllIdBlacklist()
    return setting.data.idBlacklist
end

return setting

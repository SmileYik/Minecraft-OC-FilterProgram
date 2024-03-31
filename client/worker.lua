local component = require("component")
local itemUtil = require("item_util")

local worker = {
    rules = {}
}


local function split(str, chrs)
    local ret = {} string.gsub(str, "[^"..chrs.."]+", function(s) table.insert(ret, s) end) return ret
end


function worker.updateRules(data)
    if data.rules.whiteLabel == nil then data.rules.whiteLabel = {} end
    if data.rules.idBlacklist == nil then data.rules.idBlacklist = {} end
    if data.rules.nameBlacklist == nil then data.rules.nameBlacklist = {} end
    if data.rules.labelBlacklist == nil then data.rules.labelBlacklist = {} end
    if data.rules.idWhitelist == nil then data.rules.idWhitelist = {} end
    worker.rules[data.address] = data.rules
    print(string.format("接口 %s 的规则已更新", data.address))
end

function worker.setInterface(db, me, idx, filterItem)
    if idx == 10 then return end
    db.clear(1)
    me.store(filterItem, db.address, 1, 64)
    if db.get(1) ~= nil then
        me.setInterfaceConfiguration(idx, db.address, 1, 64)
        return true
    end
    return false
end

function worker.findSuit(me, filterItem, rules, flags, callback)
    for _, item in pairs(me.getItemsInNetwork(filterItem)) do
        if flags.stop then break end
        if rules.idBlacklist[itemUtil.getId(item)] ~= nil then
        elseif rules.nameBlacklist[item.name] ~= nil then
        elseif rules.labelBlacklist[item.name] ~= nil then
        else callback(item) end
    end
end

function worker.foreachByLabel(me, rules, flags, callback)
    for _, label in pairs(rules.whiteLabel) do
        if flags.stop then break end
        if string.find(label, "#") ~= nil then
            local names = split(label, "#")
            for i = 2, #names do
                worker.findSuit(me, {name = names[i], label = label}, rules, flags, callback)
            end
        else
            worker.findSuit(me, {label = label}, rules, flags, callback)
        end
    end
end

function worker.work()
    if component.list("database") == nil then
        print("No Database")
        return
    end
    local db = component.database
    for address in pairs(component.list("me_interface")) do
        local rules = worker.rules[address]
        if rules ~= nil then
            local idx = 1
            local me = component.proxy(address)
            local flags = {stop = false}
            worker.foreachByLabel(me, rules, flags, function(item)
                if idx == 10 then flags.stop = true end
                local flag = worker.setInterface(
                    db, me, idx, {
                        label = item.label,
                        name = item.name,
                        damage = item.damage
                    }
                )
                if flag then
                    idx = idx + 1
                end
            end)
            for key in pairs(rules.idWhitelist) do
                if idx == 10 then flags.stop = true break end
                if worker.setInterface(db, me, idx, itemUtil.getItemFromId(key)) then
                    idx = idx + 1
                end
            end
        end
    end
end

return worker

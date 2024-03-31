local setting = require("setting")
local roles = require("interface_type")

local spawner = {}

function spawner.spawnRules()
    local rules = {}
    local whiteLabelRules = spawner.spawnLableWhiteListRules()
    for role, list in pairs(whiteLabelRules) do
        if rules[role] == nil then rules[role] = {} end
        rules[role].whiteLabel = list
    end
    for role, map in pairs(setting.getAllIdBlacklist()) do
        if rules[role] == nil then rules[role] = {} end
        rules[role].idBlacklist = map
    end
    for role, map in pairs(setting.getAllIdWhitelist()) do
        if rules[role] == nil then rules[role] = {} end
        rules[role].idWhitelist = map
    end
    return rules
end

function spawner.spawnLableWhiteListRules()
    -- 返回一个键值对，键为职责，值为物品标签的白名单列表
    local process = setting.getAllProcess()
    local rules = {}
    for name, list in pairs(process) do
        for i, role in pairs(list) do
            local pattern = roles[setting.getRole(role)].self
            if i ~= 1 then
                if roles[setting.getRole(role)][setting.getRole(list[i - 1])] ~= nil then
                    pattern = roles[setting.getRole(role)][setting.getRole(list[i - 1])]
                end
            end

            if rules[role] == nil then
                rules[role] = {}
            end

            if type(pattern) == "table" then
                for _, lab in pairs(pattern) do
                    table.insert(rules[role], string.format(lab, name))
                end
            else
                table.insert(rules[role], string.format(pattern, name))
            end
        end
    end
    return rules
end

return spawner

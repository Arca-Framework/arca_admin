-- /admin menu: permission checks, menu data and every action the menu can run.
-- Actions live in AdminActions[name] = function(src, data) and are added here, in bans.lua and world.lua.

AdminActions = {}
local Perms = AdminConfig.Permissions
local startedAt = os.time()

local function can(src, perm)
    return exports.arca_core:HasPermission(src, perm)
end

---Highest arca_core permission this player has ('god', 'admin', 'mod' or nil)
local function rankOf(src)
    for _, perm in ipairs(Arca.Config.Server.Permissions) do
        if IsPlayerAceAllowed(tostring(src), 'arca.' .. perm) then return perm end
    end
end

function AdminNotify(src, msg, kind)
    if src == 0 then return print(msg) end
    TriggerClientEvent('arca_core:notify', src, msg, kind or 'inform')
end
local notify = AdminNotify

function AdminLog(src, text)
    print(('^3[arca_admin]^7 %s (%d): %s'):format(src == 0 and 'console' or GetPlayerName(tostring(src)), src, text))
end

---A connected player's ped, or nil
local function pedOf(id)
    id = tonumber(id)
    if not id or not GetPlayerName(tostring(id)) then return nil end
    local ped = GetPlayerPed(tostring(id))
    return ped ~= 0 and ped or nil, id
end

---------------------------------------------------------------------
-- Opening the menu
---------------------------------------------------------------------
local function open(src)
    if src == 0 then return print('/admin can only be used in game') end
    if not can(src, AdminConfig.OpenPermission) then
        return notify(src, 'You do not have permission to do this', 'error')
    end
    local allowed = {}
    for action, perm in pairs(Perms) do allowed[action] = can(src, perm) end
    TriggerClientEvent('arca_admin:client:open', src, { allowed = allowed, rank = rankOf(src), self = src })
end

RegisterCommand(AdminConfig.Command, function(src) open(src) end, false)
RegisterNetEvent('arca_admin:open', function() open(source) end)

---------------------------------------------------------------------
-- Menu data
---------------------------------------------------------------------
local function playerList()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = exports.arca_core:GetPlayer(src)
        local ped = GetPlayerPed(id)
        local entry = {
            id = src,
            name = GetPlayerName(id),
            ping = GetPlayerPing(id),
            health = ped ~= 0 and GetEntityHealth(ped) or 0,
            armor = ped ~= 0 and GetPedArmour(ped) or 0,
            rank = rankOf(src),
            loaded = player ~= nil,
        }
        if player then
            local pd = player.PlayerData
            entry.citizenid = pd.citizenid
            entry.charname = ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname)
            entry.job = ('%s · %s'):format(pd.job.label, pd.job.grade.name)
            entry.gang = pd.gang and pd.gang.name ~= 'none' and ('%s · %s'):format(pd.gang.label, pd.gang.grade.name) or nil
            entry.cash = pd.money.cash
            entry.bank = pd.money.bank
            entry.dead = pd.metadata.isdead or pd.metadata.inlaststand
        end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function jobList(source)
    local list = {}
    for name, job in pairs(source or {}) do
        local grades = {}
        for level, grade in pairs(job.grades or {}) do
            grades[#grades + 1] = { level = tonumber(level), name = grade.name }
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
        list[#list + 1] = { name = name, label = job.label, grades = grades }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function itemList()
    if GetResourceState('arca_inventory') ~= 'started' then return {} end
    local list = {}
    for name, d in pairs(exports.arca_inventory:GetItems()) do
        list[#list + 1] = { name = name, label = d.label }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function resourceList()
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then list[#list + 1] = { name = name, state = GetResourceState(name) } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

---Everything the menu shows. `full` adds the static lists (jobs, items...) sent once on open.
Arca.Callback.Register('arca_admin:data', function(src, full)
    if not can(src, AdminConfig.OpenPermission) then return nil end
    local data = {
        players = playerList(),
        server = {
            name = GetConvar('sv_projectName', GetConvar('sv_hostname', 'Arca')),
            uptime = os.time() - startedAt,
            maxPlayers = GetConvarInt('sv_maxclients', 48),
            resources = GetNumResources(),
        },
        world = AdminWorldState and AdminWorldState() or nil,
    }
    if full then
        local core = exports.arca_core:GetCoreObject()
        data.jobs = jobList(core.Shared.Jobs)
        data.gangs = jobList(core.Shared.Gangs)
        data.items = itemList()
        data.weatherTypes = AdminConfig.World.Types
        data.quickVehicles = AdminConfig.QuickVehicles
        data.moneyTypes = Arca.Config.Player.MoneyTypes or { 'cash', 'bank' }
    end
    if can(src, Perms.resources) then data.resourceList = resourceList() end
    if can(src, Perms.unban) then data.bans = AdminBanList and AdminBanList() or {} end
    return data
end)

---------------------------------------------------------------------
-- Running actions
---------------------------------------------------------------------
RegisterNetEvent('arca_admin:action', function(action, data)
    local src = source
    local fn = type(action) == 'string' and AdminActions[action]
    local perm = fn and Perms[action]
    if not fn or not perm then return end
    if not can(src, perm) then
        return notify(src, 'You do not have permission to do this', 'error')
    end
    fn(src, type(data) == 'table' and data or {})
end)

---Actions that run on the admin's own client after the permission check
for _, name in ipairs({ 'noclip', 'godmode', 'invisible', 'names', 'tpm', 'coords', 'tpcoords',
    'fixvehicle', 'cleanvehicle', 'flipvehicle', 'tunevehicle', 'refuelvehicle' }) do
    AdminActions[name] = function(src, data)
        TriggerClientEvent('arca_admin:client:self', src, name, data)
    end
end

-- players ------------------------------------------------------------
local lastPos = {} -- [target] = coords before being brought

---Looks up the target player and tells the admin if they're gone
local function target(src, data)
    local ped, id = pedOf(data.id)
    if not ped then notify(src, 'Player is not online', 'error') end
    return ped, id
end

AdminActions.tpto = function(src, data)
    local ped = target(src, data)
    if ped then TriggerClientEvent('arca_core:client:teleport', src, GetEntityCoords(ped)) end
end

AdminActions.bring = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    lastPos[id] = GetEntityCoords(ped)
    TriggerClientEvent('arca_core:client:teleport', id, GetEntityCoords(GetPlayerPed(tostring(src))))
    notify(src, ('Brought %s'):format(GetPlayerName(tostring(id))), 'success')
end

AdminActions.sendback = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    if not lastPos[id] then return notify(src, 'They haven\'t been brought anywhere', 'error') end
    TriggerClientEvent('arca_core:client:teleport', id, lastPos[id])
    lastPos[id] = nil
    notify(src, 'Sent back', 'success')
end

AdminActions.spectate = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    if id == src then return notify(src, 'You can\'t spectate yourself', 'error') end
    TriggerClientEvent('arca_admin:client:spectate', src, id, GetEntityCoords(ped))
end

local frozen = {}
AdminActions.freeze = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    frozen[id] = not frozen[id]
    FreezeEntityPosition(ped, frozen[id])
    TriggerClientEvent('arca_admin:client:freeze', id, frozen[id])
    notify(src, ('%s %s'):format(frozen[id] and 'Froze' or 'Unfroze', GetPlayerName(tostring(id))), 'success')
end

local function revive(id)
    local player = exports.arca_core:GetPlayer(id)
    if player then
        player.SetMetaData('isdead', false)
        player.SetMetaData('inlaststand', false)
    end
    TriggerClientEvent('arca_admin:client:revive', id)
end
AdminRevive = revive

AdminActions.heal = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    local player = exports.arca_core:GetPlayer(id)
    if player then
        player.SetMetaData('hunger', 100)
        player.SetMetaData('thirst', 100)
    end
    TriggerClientEvent('arca_admin:client:heal', id)
    notify(src, 'Healed', 'success')
end

AdminActions.revive = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    revive(id)
    notify(src, 'Revived', 'success')
end

AdminActions.kill = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    TriggerClientEvent('arca_admin:client:kill', id)
    AdminLog(src, ('killed %d'):format(id))
end

AdminActions.message = function(src, data)
    local ped, id = target(src, data)
    if not ped or type(data.text) ~= 'string' or data.text == '' then return end
    TriggerClientEvent('arca_core:notify', id, { title = 'Message from staff', description = data.text:sub(1, 300), type = 'warning', duration = 12000 })
    notify(src, 'Message sent', 'success')
end

AdminActions.kick = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    local reason = (type(data.reason) == 'string' and data.reason ~= '') and data.reason or 'Kicked by staff'
    AdminLog(src, ('kicked %s (%d): %s'):format(GetPlayerName(tostring(id)), id, reason))
    DropPlayer(tostring(id), reason)
end

local function arcaPlayer(src, data)
    local player = exports.arca_core:GetPlayer(tonumber(data.id) or -1)
    if not player then notify(src, 'That player has no character loaded', 'error') end
    return player
end

AdminActions.setjob = function(src, data)
    local player = arcaPlayer(src, data)
    if not player then return end
    if player.SetJob(tostring(data.job), tonumber(data.grade) or 0) then
        notify(src, 'Job updated', 'success')
    else
        notify(src, 'Invalid job or grade', 'error')
    end
end

AdminActions.setgang = function(src, data)
    local player = arcaPlayer(src, data)
    if not player then return end
    if player.SetGang(tostring(data.gang), tonumber(data.grade) or 0) then
        notify(src, 'Gang updated', 'success')
    else
        notify(src, 'Invalid gang or grade', 'error')
    end
end

local function moneyAction(add)
    return function(src, data)
        local player = arcaPlayer(src, data)
        if not player then return end
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount <= 0 then return notify(src, 'Enter an amount', 'error') end
        local fn = add and player.AddMoney or player.RemoveMoney
        if fn(tostring(data.type), amount, 'admin') then
            AdminLog(src, ('%s $%d %s for %s'):format(add and 'gave' or 'removed', amount, data.type, player.PlayerData.citizenid))
            notify(src, ('%s $%d %s'):format(add and 'Gave' or 'Removed', amount, data.type), 'success')
        else
            notify(src, 'Invalid account or not enough money', 'error')
        end
    end
end
AdminActions.givemoney = moneyAction(true)
AdminActions.removemoney = moneyAction(false)

local function inventoryRunning(src)
    if GetResourceState('arca_inventory') == 'started' then return true end
    notify(src, 'arca_inventory is not running', 'error')
end

AdminActions.giveitem = function(src, data)
    if not arcaPlayer(src, data) or not inventoryRunning(src) then return end
    local count = math.max(1, math.floor(tonumber(data.count) or 1))
    if exports.arca_inventory:AddItem(tonumber(data.id), tostring(data.item), count) then
        AdminLog(src, ('gave %dx %s to %d'):format(count, data.item, data.id))
        notify(src, ('Gave %dx %s'):format(count, data.item), 'success')
    else
        notify(src, 'Unknown item or no room', 'error')
    end
end

AdminActions.clearinventory = function(src, data)
    if not arcaPlayer(src, data) or not inventoryRunning(src) then return end
    exports.arca_inventory:ClearInventory(tonumber(data.id))
    AdminLog(src, ('cleared inventory of %d'):format(data.id))
    notify(src, 'Inventory cleared', 'success')
end

AdminActions.openinventory = function(src, data)
    if not arcaPlayer(src, data) or not inventoryRunning(src) then return end
    if tonumber(data.id) == src then return notify(src, 'That\'s your own inventory', 'error') end
    exports.arca_inventory:OpenPlayerInventory(src, tonumber(data.id))
end

AdminActions.clothing = function(src, data)
    local ped, id = target(src, data)
    if not ped then return end
    if GetResourceState('illenium-appearance') ~= 'started' then
        return notify(src, 'illenium-appearance is not running', 'error')
    end
    -- the full ped menu (every clothing category); illenium saves it when they're done
    TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', id, true)
    if id == src then
        TriggerClientEvent('arca_admin:client:closeMenu', src)
    else
        notify(src, ('Opened the clothing menu for %s'):format(GetPlayerName(tostring(id))), 'success')
    end
end

-- vehicles -----------------------------------------------------------
AdminActions.spawnvehicle = function(src, data)
    local model = type(data.model) == 'string' and data.model:lower() or ''
    if not model:match('^[%w_]+$') then return notify(src, 'Enter a vehicle model', 'error') end
    local id = tonumber(data.id) or src
    if not GetPlayerName(tostring(id)) then return notify(src, 'Player is not online', 'error') end
    TriggerClientEvent('arca_core:client:spawnVehicle', id, model)
end

AdminActions.deletevehicle = function(src)
    local ped = GetPlayerPed(tostring(src))
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local pos, best = GetEntityCoords(ped), 6.0
        for _, v in ipairs(GetAllVehicles()) do
            local d = #(pos - GetEntityCoords(v))
            if d < best then veh, best = v, d end
        end
    end
    if veh == 0 then return notify(src, 'No vehicle nearby', 'error') end
    DeleteEntity(veh)
    notify(src, 'Vehicle deleted', 'success')
end

local function occupied(veh)
    for seat = -1, 6 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and IsPedAPlayer(p) then return true end
    end
end

AdminActions.clearvehicles = function(src, data)
    local radius = tonumber(data.radius) or 0  -- 0 = whole map
    local pos = GetEntityCoords(GetPlayerPed(tostring(src)))
    local count = 0
    for _, v in ipairs(GetAllVehicles()) do
        if not occupied(v) and (radius <= 0 or #(pos - GetEntityCoords(v)) <= radius) then
            DeleteEntity(v)
            count = count + 1
        end
    end
    AdminLog(src, ('cleared %d vehicles (radius %s)'):format(count, radius))
    notify(src, ('Deleted %d empty vehicles'):format(count), 'success')
end

-- server -------------------------------------------------------------
AdminActions.announce = function(src, data)
    if type(data.text) ~= 'string' or data.text == '' then return end
    TriggerClientEvent('arca_core:notify', -1, { title = 'Announcement', description = data.text:sub(1, 500), type = 'inform', duration = 15000, position = 'top' })
    AdminLog(src, 'announced: ' .. data.text)
end

AdminActions.reviveall = function(src)
    for _, id in ipairs(GetPlayers()) do revive(tonumber(id)) end
    notify(src, 'Everyone revived', 'success')
end

AdminActions.resources = function(src, data)
    local name, op = tostring(data.name or ''), data.op
    if name == '' or GetResourceState(name) == 'missing' then return notify(src, 'Unknown resource', 'error') end
    if name == GetCurrentResourceName() and op ~= 'restart' then return notify(src, 'Use restart for arca_admin', 'error') end
    if op == 'start' then
        StartResource(name)
    elseif op == 'stop' then
        StopResource(name)
    elseif op == 'restart' then
        StopResource(name)
        SetTimeout(250, function() StartResource(name) end)
    else
        return
    end
    AdminLog(src, ('%s %s'):format(op, name))
    notify(src, ('%s: %s'):format(name, op), 'success')
end

-- blips (positions of everyone, sent to admins who turned blips on) --
local blipWatchers = {}
AdminActions.blips = function(src)
    blipWatchers[src] = not blipWatchers[src] or nil
    TriggerClientEvent('arca_admin:client:blips', src, blipWatchers[src] ~= nil)
end

CreateThread(function()
    while true do
        Wait(AdminConfig.BlipInterval)
        if next(blipWatchers) then
            local list = {}
            for _, id in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(id)
                if ped ~= 0 then
                    local c = GetEntityCoords(ped)
                    list[#list + 1] = { id = tonumber(id), name = GetPlayerName(id), x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), veh = GetVehiclePedIsIn(ped, false) ~= 0 }
                end
            end
            for watcher in pairs(blipWatchers) do
                TriggerClientEvent('arca_admin:client:blipData', watcher, list)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    blipWatchers[src], frozen[src], lastPos[src] = nil, nil, nil
end)

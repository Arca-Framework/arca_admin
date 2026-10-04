-- Bans: stored in arca_bans, checked when a player connects.

local bans = {} -- cached rows, [id] = row

local function identifiers(src)
    local ids = {}
    for _, kind in ipairs({ 'license', 'discord', 'fivem', 'ip' }) do
        ids[kind] = GetPlayerIdentifierByType(tostring(src), kind)
    end
    return ids
end

local function expired(row)
    return row.expire > 0 and row.expire <= os.time()
end

local function findBan(ids)
    for _, row in pairs(bans) do
        if not expired(row) then
            for kind, value in pairs(ids) do
                if value and row[kind] == value then return row end
            end
        end
    end
end

local function banMessage(row)
    local untilText = row.expire == 0 and 'permanently' or ('until %s'):format(os.date('%Y-%m-%d %H:%M', row.expire))
    return ('You are banned %s.\nReason: %s\nBan ID: %d'):format(untilText, row.reason, row.id)
end

function AdminBanList()
    local list = {}
    for _, row in pairs(bans) do
        if not expired(row) then
            list[#list + 1] = { id = row.id, name = row.name, reason = row.reason, expire = row.expire, by = row.banned_by }
        end
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    return list
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    local row = findBan(identifiers(src))
    if row then
        deferrals.done(banMessage(row))
    else
        deferrals.done()
    end
end)

---@param data { id: number, reason?: string, hours?: number } hours 0 / nil = permanent
AdminActions.ban = function(src, data)
    local id = tonumber(data.id)
    if not id or not GetPlayerName(tostring(id)) then return AdminNotify(src, 'Player is not online', 'error') end
    if id == src then return AdminNotify(src, 'You can\'t ban yourself', 'error') end

    local hours = math.max(0, tonumber(data.hours) or 0)
    local reason = (type(data.reason) == 'string' and data.reason ~= '') and data.reason:sub(1, 250) or 'No reason given'
    local ids = identifiers(id)
    local row = {
        name = GetPlayerName(tostring(id)), license = ids.license, discord = ids.discord, fivem = ids.fivem, ip = ids.ip,
        reason = reason, expire = hours > 0 and (os.time() + math.floor(hours * 3600)) or 0,
        banned_by = GetPlayerName(tostring(src)),
    }
    row.id = MySQL.insert.await('INSERT INTO arca_bans (name, license, discord, fivem, ip, reason, expire, banned_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        row.name, row.license, row.discord, row.fivem, row.ip, row.reason, row.expire, row.banned_by,
    })
    bans[row.id] = row
    AdminLog(src, ('banned %s (%d) %s: %s'):format(row.name, id, hours > 0 and (hours .. 'h') or 'permanently', reason))
    DropPlayer(tostring(id), banMessage(row))
    AdminNotify(src, ('Banned %s'):format(row.name), 'success')
end

AdminActions.unban = function(src, data)
    local id = tonumber(data.banId)
    if not id or not bans[id] then return AdminNotify(src, 'Ban not found', 'error') end
    MySQL.query('DELETE FROM arca_bans WHERE id = ?', { id })
    AdminLog(src, ('unbanned %s (ban %d)'):format(bans[id].name, id))
    bans[id] = nil
    AdminNotify(src, 'Ban removed', 'success')
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `arca_bans` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `license` VARCHAR(60) DEFAULT NULL,
            `discord` VARCHAR(60) DEFAULT NULL,
            `fivem` VARCHAR(60) DEFAULT NULL,
            `ip` VARCHAR(60) DEFAULT NULL,
            `reason` VARCHAR(255) NOT NULL,
            `expire` INT NOT NULL DEFAULT 0,
            `banned_by` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    for _, row in ipairs(MySQL.query.await('SELECT * FROM arca_bans WHERE expire = 0 OR expire > ?', { os.time() }) or {}) do
        bans[row.id] = row
    end
end)

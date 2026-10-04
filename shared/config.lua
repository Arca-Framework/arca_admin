AdminConfig = {
    Command = 'admin',          -- /admin opens the menu
    Key = 'F10',                -- default key (players can rebind in GTA settings), false = command only
    OpenPermission = 'mod',     -- lowest arca_core permission that can open the menu

    -- Permission needed for each action (god > admin > mod, see ArcaConfig.Server.Permissions).
    -- Buttons the admin can't use are hidden in the menu and refused by the server.
    Permissions = {
        -- players
        tpto = 'mod', bring = 'mod', sendback = 'mod', spectate = 'mod', freeze = 'mod',
        heal = 'mod', revive = 'mod', kill = 'admin', message = 'mod', kick = 'mod',
        ban = 'admin', unban = 'admin',
        setjob = 'admin', setgang = 'admin', givemoney = 'god', removemoney = 'god',
        giveitem = 'admin', clearinventory = 'admin', openinventory = 'admin', clothing = 'admin',
        -- vehicles
        spawnvehicle = 'admin', fixvehicle = 'mod', cleanvehicle = 'mod', deletevehicle = 'mod',
        flipvehicle = 'mod', tunevehicle = 'admin', refuelvehicle = 'mod', clearvehicles = 'admin',
        -- world / server
        weather = 'admin', time = 'admin', freezetime = 'admin', blackout = 'admin',
        announce = 'mod', reviveall = 'admin', resources = 'god',
        -- self
        noclip = 'mod', godmode = 'admin', invisible = 'admin', names = 'mod', blips = 'mod',
        tpm = 'mod', coords = 'admin', tpcoords = 'mod',
    },

    -- Weather & time sync (turn off if you use another weather script)
    World = {
        Enabled = true,
        Weather = 'EXTRASUNNY',     -- starting weather
        Hour = 8, Minute = 0,       -- starting time
        MinuteLength = 2000,        -- real ms per in-game minute (2000 = 48 minute day)
        Transition = 15.0,          -- seconds to blend into new weather
        Types = {
            'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY', 'CLEARING',
            'RAIN', 'THUNDER', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN', 'NEUTRAL',
        },
    },

    -- quick-spawn buttons on the Vehicles tab
    QuickVehicles = {
        { label = 'Sultan', model = 'sultan' }, { label = 'Kuruma', model = 'kuruma' },
        { label = 'Adder', model = 'adder' }, { label = 'Zentorno', model = 'zentorno' },
        { label = 'Bati 801', model = 'bati' }, { label = 'Sanchez', model = 'sanchez' },
        { label = 'Police', model = 'police' }, { label = 'Ambulance', model = 'ambulance' },
        { label = 'Buzzard', model = 'buzzard2' }, { label = 'Dinghy', model = 'dinghy' },
    },

    BlipInterval = 2500,        -- ms between player blip updates for admins with blips on
}

--=========================================================
-- QC-ADVANCED MEDIC - COMMAND HANDLERS
--=========================================================
-- Admin commands for medical system
-- Consolidated /revive and /clearwounds (duplicate functionality removed)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- ADMIN COMMANDS
--=========================================================

-- Consolidated revive/clear wounds command (replaces both /revive and /clearwounds)
RSGCore.Commands.Add('revive', 'Revive player and clear all wounds', {{name = 'id', help = 'Player ID (optional - defaults to self)'}}, false, function(source, args)
    local src = source
    local targetId = args[1] and tonumber(args[1]) or src

    local Player = RSGCore.Functions.GetPlayer(targetId)
    if not Player then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            locale('sv_player_not_online')
        )
        return
    end

    -- Clear all medical data from database
    local citizenid = Player.PlayerData.citizenid
    if citizenid then
        MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('DELETE FROM player_fractures WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('DELETE FROM player_infection WHERE citizenid = ?', {citizenid})

        -- Log medical event
        MySQL.Async.execute([[
            INSERT INTO medical_history
            (citizenid, event_type, details, performed_by)
            VALUES (?, 'admin_clear_wounds', '{"reason": "Admin revive/clear wounds", "target_id": ?}', ?)
        ]], {citizenid, targetId, 'admin_' .. src})
    end

    -- Revive and clear client-side data
    TriggerClientEvent('QC-AdvancedMedic:client:adminRevive', Player.PlayerData.source)
    TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', Player.PlayerData.source)

    -- Notifications
    if targetId == src then
        QCMedServer.NotifySuccess(src,
            locale('sv_medical_system'),
            locale('sv_wounds_cleared')
        )
    else
        QCMedServer.NotifySuccess(src,
            locale('sv_medical_system'),
            string.format(locale('sv_wounds_cleared_player'), targetId)
        )

        QCMedServer.NotifyInfo(Player.PlayerData.source,
            locale('sv_medical_system'),
            locale('sv_wounds_cleared_admin')
        )
    end

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[COMMANDS] Admin %d revived player %d^7", src, targetId))
    end
end, 'admin')

-- Admin kill command
RSGCore.Commands.Add('kill', 'Kill a player', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            "Invalid player ID"
        )
        return
    end

    local Player = RSGCore.Functions.GetPlayer(targetId)
    if not Player then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            locale('sv_player_not_online')
        )
        return
    end

    TriggerClientEvent('QC-AdvancedMedic:client:KillPlayer', Player.PlayerData.source)

    QCMedServer.NotifySuccess(src,
        locale('sv_medical_system'),
        string.format("Killed player %d", targetId)
    )

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^1[COMMANDS] Admin %d killed player %d^7", src, targetId))
    end
end, 'admin')

-- Medic inspect nearest player
RSGCore.Commands.Add('inspect', 'Inspect a nearby player\'s medical condition (medic only)', {}, false, function(source)
    local src = source
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then
        QCMedServer.NotifyValidationError(src, err)
        return
    end

    if not Medic.PlayerData.job.onduty then
        QCMedServer.NotifyError(src, locale('sv_error'), "You must be on duty to inspect patients")
        return
    end

    TriggerClientEvent('QC-AdvancedMedic:client:InspectPlayer', src)
end)

--=========================================================
-- PLAYER COMMANDS (Accessible to all)
--=========================================================

-- Check health status (accessible to all players)
RSGCore.Commands.Add('checkhealth', 'Check your current medical status', {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            'Failed to get player data'
        )
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            'Invalid player data'
        )
        return
    end

    -- Request client to show medical status UI
    TriggerClientEvent('QC-AdvancedMedic:client:ShowHealthStatus', src)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[COMMANDS] Player %d checked their health status^7", src))
    end
end)

--=========================================================
-- MEDIC JOB EVENTS (Not commands but related)
--=========================================================

-- Medic revive player (requires firstaid kit)
RegisterNetEvent('QC-AdvancedMedic:server:RevivePlayer')
AddEventHandler('QC-AdvancedMedic:server:RevivePlayer', function(playerId)
    local src = source

    -- Validate medic
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then
        QCMedServer.NotifyValidationError(src, err)
        return
    end

    -- Validate patient
    local Patient, err2 = QCMedServer.ValidatePlayer(playerId)
    if not Patient then
        QCMedServer.NotifyValidationError(src, err2)
        return
    end

    -- Check if medic has firstaid kit
    if not QCMedServer.HasItem(src, 'firstaid') then
        QCMedServer.NotifyError(src,
            locale('sv_error'),
            "You need a first aid kit to revive"
        )
        return
    end

    -- Remove firstaid kit
    if Medic.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], 'remove')

        -- Revive patient
        TriggerClientEvent('QC-AdvancedMedic:client:playerRevive', Patient.PlayerData.source)

        QCMedServer.NotifySuccess(src,
            locale('sv_medical_system'),
            string.format("Revived %s", Patient.PlayerData.charinfo.firstname)
        )

        if Config.WoundSystem.debugging.enabled then
            print(string.format("^2[COMMANDS] Medic %d revived player %d^7", src, playerId))
        end
    end
end)

-- Medic heal injuries (full heal)
RegisterNetEvent('QC-AdvancedMedic:server:HealInjuries')
AddEventHandler('QC-AdvancedMedic:server:HealInjuries', function(playerId)
    local src = source

    -- Validate medic
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then
        QCMedServer.NotifyValidationError(src, err)
        return
    end

    -- Validate patient
    local Patient, err2 = QCMedServer.ValidatePlayer(playerId)
    if not Patient then
        QCMedServer.NotifyValidationError(src, err2)
        return
    end

    -- Clear wounds and restore health
    local citizenid = Patient.PlayerData.citizenid
    if citizenid then
        MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
    end

    TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', Patient.PlayerData.source)
    TriggerClientEvent('QC-AdvancedMedic:client:RestoreHealth', Patient.PlayerData.source)

    QCMedServer.NotifySuccess(src,
        locale('sv_medical_system'),
        string.format("Healed all injuries on %s", Patient.PlayerData.charinfo.firstname)
    )

    QCMedServer.NotifyInfo(playerId,
        locale('sv_medical_system'),
        string.format("Dr. %s healed your injuries", Medic.PlayerData.charinfo.lastname)
    )
end)

--=========================================================
-- MISSION REWARDS
--=========================================================

-- Mission reward event
RegisterNetEvent('QC-AdvancedMedic:server:MissionReward')
AddEventHandler('QC-AdvancedMedic:server:MissionReward', function(missionType)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    -- Determine reward based on mission type
    local rewardAmount = 50 -- Default
    if missionType == 'surgery' then
        rewardAmount = 100
    elseif missionType == 'transport' then
        rewardAmount = 75
    end

    -- Give reward
    Player.Functions.AddMoney('cash', rewardAmount)

    QCMedServer.NotifySuccess(src,
        locale('cl_menu_mission_complete'),
        string.format("Mission completed! Earned $%d", rewardAmount)
    )

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[COMMANDS] Player %d completed %s mission - reward: $%d^7", src, missionType, rewardAmount))
    end
end)

--=========================================================
-- DEATH/HEALTH EVENTS
--=========================================================

-- Death actions (inventory/cash wipe)
RegisterNetEvent('QC-AdvancedMedic:server:deathactions')
AddEventHandler('QC-AdvancedMedic:server:deathactions', function()
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?',
            {json.encode({}), Player.PlayerData.citizenid})
        QCMedServer.NotifyInfo(src,
            locale('sv_death'),
            locale('sv_lost_all_items')
        )
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        QCMedServer.NotifyInfo(src,
            locale('sv_death'),
            locale('sv_lost_cash')
        )
    end

    if Config.WipeBloodmoneyOnRespawn then
        Player.Functions.SetMoney('bloodmoney', 0)
        QCMedServer.NotifyInfo(src,
            locale('sv_death'),
            locale('sv_lost_bloodmoney')
        )
    end
end)

-- Set player health
RegisterNetEvent('QC-AdvancedMedic:server:SetHealth')
AddEventHandler('QC-AdvancedMedic:server:SetHealth', function(amount)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    amount = tonumber(amount)
    if amount > Config.MaxHealth then
        amount = Config.MaxHealth
    end

    Player.Functions.SetMetaData('health', amount)
end)

--=========================================================
-- CALLBACKS
--=========================================================

-- Get player health callback
RSGCore.Functions.CreateCallback('QC-AdvancedMedic:server:getplayerhealth', function(source, cb)
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        cb(0)
        return
    end

    local health = Player.PlayerData.metadata.health or 0
    cb(health)
end)

--=========================================================
-- INITIALIZATION
--=========================================================

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER COMMANDS] Command handlers loaded^7")
    print("^2[SERVER COMMANDS] /revive - Admin revive + clear wounds command^7")
    print("^2[SERVER COMMANDS] /kill - Admin kill command^7")
    print("^2[SERVER COMMANDS] /checkhealth - Check medical status (accessible to all)^7")
end

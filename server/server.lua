local RSGCore = exports['rsg-core']:GetCoreObject()
local playerInjury = {}

-----------------------
-- Helper Functions
-----------------------
-- Check if player has any medic job
local function IsMedicJob(jobName)
    if not jobName then return false end

    -- Check against all jobs in MedicJobLocations
    for _, location in pairs(Config.MedicJobLocations) do
        if location.job == jobName then
            return true
        end
    end

    return false
end

function GetCharsInjuries(source)
    return playerInjury[source]
end

-----------------------
-- use bandage (dynamically created from config)
-----------------------
-- Create useable items for all bandage types defined in config
for bandageType, bandageConfig in pairs(Config.BandageTypes) do
    local itemName = bandageConfig.itemName or bandageType
    
    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        local src = source
        TriggerClientEvent('QC-AdvancedMedic:client:usebandage', src, bandageType)
    end)
    
    if Config.WoundSystem.debugging.enabled then
        print(string.format("[BANDAGE SYSTEM] Registered useable item: %s -> %s", itemName, bandageType))
    end
end

-- Create useable items for all cure items defined in infection config
for cureType, cureConfig in pairs(Config.InfectionSystem.cureItems) do
    local itemName = cureConfig.itemName or cureType
    
    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        
        -- Trigger client-side infection treatment
        TriggerClientEvent('QC-AdvancedMedic:client:UseCureItem', src, cureType)
        
        -- Remove item from inventory
        Player.Functions.RemoveItem(itemName, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "remove", 1)
    end)
    
    if Config.InfectionSystem.debugging.enabled then
        print(string.format("[INFECTION SYSTEM] Registered cure item: %s -> %s", itemName, cureType))
    end
end

-- Create useable items for all tourniquet types
for tourniquetType, tourniquetConfig in pairs(Config.TourniquetTypes or {}) do
    local itemName = tourniquetConfig.itemName or tourniquetType

    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        local src = source
        TriggerClientEvent('QC-AdvancedMedic:client:usetourniquet', src, tourniquetType)
    end)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("[TOURNIQUET SYSTEM] Registered useable item: %s -> %s", itemName, tourniquetType))
    end
end

-- Create useable items for all injection types
for injectionType, injectionConfig in pairs(Config.InjectionTypes or {}) do
    local itemName = injectionConfig.itemName or injectionType

    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        local src = source
        TriggerClientEvent('QC-AdvancedMedic:client:useinjection', src, injectionType)
    end)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("[INJECTION SYSTEM] Registered useable item: %s -> %s", itemName, injectionType))
    end
end

---------------------------------
-- medic storage
---------------------------------
RegisterNetEvent('QC-AdvancedMedic:server:openstash', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = locale('sv_medical_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots }
    local stashName = 'medic_' .. location
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

----------------------------------
-- Admin Revive Player
----------------------------------
RSGCore.Commands.Add('revive', locale('sv_revive'), {{name = 'id', help = locale('sv_revive_2')}}, false, function(source, args)
    local src = source

    if not args[1] then
        -- Revive self and clear all wounds
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            TriggerClientEvent('QC-AdvancedMedic:client:adminRevive', src)
            TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', src)

            -- Clear from database
            local citizenid = Player.PlayerData.citizenid
            if citizenid then
                MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('DELETE FROM player_fractures WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('UPDATE player_infections SET is_active = 0, cured_at = NOW(), cured_by = ? WHERE citizenid = ?', {'admin_' .. src, citizenid})
            end
        end
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error'), description = locale('sv_player_not_online'), type = 'error', duration = 7000 })
        return
    end

    -- Revive target player and clear all wounds
    TriggerClientEvent('QC-AdvancedMedic:client:adminRevive', Player.PlayerData.source)
    TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', Player.PlayerData.source)

    -- Clear from database
    local citizenid = Player.PlayerData.citizenid
    if citizenid then
        MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('DELETE FROM player_fractures WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE player_infections SET is_active = 0, cured_at = NOW(), cured_by = ? WHERE citizenid = ?', {'admin_' .. src, citizenid})
    end
end, 'admin')

-- Admin Clear Wounds
RSGCore.Commands.Add('clearwounds', 'Clear all wounds and fractures from a player (Admin Only)', {{name = 'id', help = 'Player ID (may be empty)'}}, false, function(source, args)
    local src = source
    
    if not args[1] then
        -- Clear wounds from self
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', src)
            
            -- Clear from database for self (optimized 3-table schema)
            local citizenid = Player.PlayerData.citizenid
            if citizenid then
                -- Clear all wound-related data from optimized database
                MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('DELETE FROM player_fractures WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
                MySQL.Async.execute('UPDATE player_infections SET is_active = 0, cured_at = NOW(), cured_by = ? WHERE citizenid = ?', {'admin_' .. src, citizenid})
                
                -- Log the medical event
                MySQL.Async.execute([[
                    INSERT INTO medical_history 
                    (citizenid, event_type, details, performed_by)
                    VALUES (?, 'admin_clear_wounds', '{"reason": "Admin cleared all wounds and fractures"}', ?)
                ]], {citizenid, 'admin_' .. src})
            end
            
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_medical_system'), description = locale('sv_wounds_cleared'), type = 'success'})
        else
            TriggerClientEvent('ox_lib:notify', src, {title = locale('cl_error'), description = locale('sv_error_no_player'), type = 'error'})
        end
        return
    end
    
    local targetId = tonumber(args[1])
    local Player = RSGCore.Functions.GetPlayer(targetId)
    
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error'), description = locale('sv_player_not_online'), type = 'error'})
        return
    end
    
    -- Clear wounds from target player
    TriggerClientEvent('QC-AdvancedMedic:client:ClearAllWounds', Player.PlayerData.source)
    
    -- Also clear from database (optimized 3-table schema)
    local citizenid = Player.PlayerData.citizenid
    if citizenid then
        -- Clear all wound-related data from optimized database
        MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('DELETE FROM player_fractures WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ?', {citizenid})
        MySQL.Async.execute('UPDATE player_infections SET is_active = 0, cured_at = NOW(), cured_by = ? WHERE citizenid = ?', {'admin_' .. src, citizenid})
        
        -- Log the medical event
        MySQL.Async.execute([[
            INSERT INTO medical_history 
            (citizenid, event_type, details, performed_by)
            VALUES (?, 'admin_clear_wounds', '{"reason": "Admin cleared all wounds and fractures", "target_id": ?}', ?)
        ]], {citizenid, targetId, 'admin_' .. src})
    end
    
    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_medical_system'), description = string.format(locale('sv_wounds_cleared_player'), targetId), type = 'success'})
    TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {title = locale('sv_medical_system'), description = locale('sv_wounds_cleared_admin'), type = 'inform'})
    
end, 'admin')

-- Admin Kill Player
RSGCore.Commands.Add('kill', locale('sv_kill'), {{name = 'id', help = locale('sv_kill_id')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error'), description = locale('sv_player_not_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('QC-AdvancedMedic:client:KillPlayer', Player.PlayerData.source)
end, 'admin')

-- /heal command removed - use /clearwounds and /revive instead

----------------------
-- EVENTS 
-----------------------
-- Death Actions: Remove Inventory / Cash
RegisterNetEvent('QC-AdvancedMedic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_death'), description = locale('sv_lost_all_items'), type = 'info', duration = 7000 })
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_death'), description = locale('sv_lost_cash'), type = 'info', duration = 7000 })
    end
    if Config.WipeBloodmoneyOnRespawn then
        Player.Functions.SetMoney('bloodmoney', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_death'), description = locale('sv_lost_bloodmoney'), type = 'info', duration = 7000 })
    end
end)

-- Get Players Health
RSGCore.Functions.CreateCallback('QC-AdvancedMedic:server:getplayerhealth', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local health = Player.PlayerData.metadata['health']
    cb(health)
end)

-- Set Player Health
RegisterNetEvent('QC-AdvancedMedic:server:SetHealth', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    amount = tonumber(amount)

    if amount > Config.MaxHealth then
        amount = Config.MaxHealth
    end

    Player.Functions.SetMetaData('health', amount)
end)

-- Medic Revive Player
RegisterNetEvent('QC-AdvancedMedic:server:RevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if not IsMedicJob(Player.PlayerData.job.name) then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error'), description = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], 'remove')
        TriggerClientEvent('QC-AdvancedMedic:client:playerRevive', Patient.PlayerData.source)
    end
end)

-- Medic Treat Wounds
RegisterNetEvent('QC-AdvancedMedic:server:TreatWounds', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if not IsMedicJob(Player.PlayerData.job.name) then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error'), description = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bandage'], 'remove')
        TriggerClientEvent('QC-AdvancedMedic:client:HealInjuries', Patient.PlayerData.source, 'full')
    end
end)

-- Medic Alert
RegisterNetEvent('QC-AdvancedMedic:server:medicAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if IsMedicJob(v.PlayerData.job.name) and v.PlayerData.job.onduty then
            TriggerClientEvent('QC-AdvancedMedic:client:medicAlert', v.PlayerData.source, coords, text)
        end
    end
end)

-- Emergency Call (from death screen "Call Medic" button)
RegisterNetEvent('QC-AdvancedMedic:server:EmergencyCall', function(coords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if IsMedicJob(v.PlayerData.job.name) and v.PlayerData.job.onduty then
            -- Fixed: Changed to EmergencyAlert to match client handler
            TriggerClientEvent('QC-AdvancedMedic:client:EmergencyAlert', v.PlayerData.source, {
                caller = playerName,
                location = coords
            })
        end
    end
end)

--------------------------
-- Medics On-Duty Callback
-------------------------
RSGCore.Functions.CreateCallback('QC-AdvancedMedic:server:getmedics', function(source, cb)
    local amount = 0
    local players = RSGCore.Functions.GetRSGPlayers()
    for k, v in pairs(players) do
        if IsMedicJob(v.PlayerData.job.name) and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)

---------------------------------
-- remove item
---------------------------------
RegisterServerEvent('QC-AdvancedMedic:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)

RegisterServerEvent('QC-AdvancedMedic:SyncWounds')
AddEventHandler('QC-AdvancedMedic:SyncWounds', function(data)
    playerInjury[source] = data
end)

--=========================================================
-- ENHANCED DUTY & PAYMENT SYSTEM (10-MINUTE INTERVALS)
--=========================================================

local dutyTimers = {} -- Track duty timers by player source

-- Pay rates per hour (1890s appropriate)
local payRates = {
    [0] = 1,   -- Recruit: $1/hour
    [1] = 2,   -- Trainee: $2/hour  
    [2] = 3,   -- Pharmacist: $3/hour
    [3] = 4,   -- Doctor: $4/hour
    [4] = 6,   -- Surgeon: $6/hour
    [5] = 8,   -- Manager: $8/hour
}

-- Calculate 10-minute pay (16.67% of hourly rate)
local function Calculate10MinutePay(hourlyRate)
    return math.floor((hourlyRate * 10) / 60) -- 10 minutes / 60 minutes = 16.67%
end

-- Helper function to check if job is a medic job
local function IsMedicJob(jobName)
    for _, location in pairs(Config.MedicJobLocations) do
        if location.job == jobName then
            return true
        end
    end
    return false
end

-- Start duty pay timer (every 10 minutes)
RegisterNetEvent('QC-AdvancedMedic:server:StartDutyPayTimer')
AddEventHandler('QC-AdvancedMedic:server:StartDutyPayTimer', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local job = Player.PlayerData.job
    if not IsMedicJob(job.name) then return end
    
    -- Clear existing timer if any
    if dutyTimers[src] then
        ClearTimeout(dutyTimers[src])
    end
    
    -- Start 10-minute payment loop
    local function PaymentLoop()
        local CurrentPlayer = RSGCore.Functions.GetPlayer(src)
        if not CurrentPlayer then 
            dutyTimers[src] = nil
            return 
        end
        
        local currentJob = CurrentPlayer.PlayerData.job
        if not IsMedicJob(currentJob.name) or not currentJob.onduty then
            dutyTimers[src] = nil
            return
        end
        
        -- Calculate and give pay
        local hourlyRate = payRates[currentJob.grade.level] or 2
        local payAmount = Calculate10MinutePay(hourlyRate)
        
        if payAmount > 0 then
            CurrentPlayer.Functions.AddMoney('cash', payAmount, 'medic-duty-pay-interval')
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_duty_pay'),
                description = string.format(locale('sv_duty_pay_earned'), payAmount),
                type = 'success',
                duration = 5000
            })
            
            if Config.Debug then
                print(string.format('[MEDIC PAY] %s earned $%d for 10 minutes at $%d/hour rate', 
                    CurrentPlayer.PlayerData.name, payAmount, hourlyRate))
            end
        end
        
        -- Schedule next payment in 10 minutes (600,000 ms)
        dutyTimers[src] = SetTimeout(600000, PaymentLoop)
    end
    
    -- Start first payment in 10 minutes
    dutyTimers[src] = SetTimeout(600000, PaymentLoop)
    
    if Config.Debug then
        print(string.format('[MEDIC PAY] Started 10-minute pay timer for %s', Player.PlayerData.name))
    end
end)

-- Process final duty pay when going off duty
RegisterNetEvent('QC-AdvancedMedic:server:ProcessDutyPay')
AddEventHandler('QC-AdvancedMedic:server:ProcessDutyPay', function(sessionTimeSeconds)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Stop the timer
    if dutyTimers[src] then
        ClearTimeout(dutyTimers[src])
        dutyTimers[src] = nil
    end
    
    local job = Player.PlayerData.job
    if not IsMedicJob(job.name) then return end
    
    -- Calculate any remaining partial pay (for time less than 10 minutes since last payment)
    local hourlyRate = payRates[job.grade.level] or 2
    local minutesWorked = sessionTimeSeconds / 60 -- Convert to minutes
    local remainingMinutes = minutesWorked % 10 -- Get remainder after 10-minute intervals
    
    if remainingMinutes >= 5 then -- Pay if worked at least 5 minutes of partial time
        local partialPay = math.floor((hourlyRate * remainingMinutes) / 60)
        if partialPay > 0 then
            Player.Functions.AddMoney('cash', partialPay, 'medic-duty-pay-final')
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_final_duty_pay'),
                description = string.format(locale('sv_final_duty_pay_earned'), partialPay, remainingMinutes),
                type = 'success',
                duration = 5000
            })
            
            if Config.Debug then
                print(string.format('[MEDIC PAY] %s earned final $%d for %.1f remaining minutes', 
                    Player.PlayerData.name, partialPay, remainingMinutes))
            end
        end
    end
end)

-- Clean up timer when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    if dutyTimers[src] then
        ClearTimeout(dutyTimers[src])
        dutyTimers[src] = nil
    end
end)

--=========================================================
-- PHARMACEUTICAL SHOP SYSTEM
--=========================================================

-- Purchase pharmaceutical items
RegisterNetEvent('QC-AdvancedMedic:server:PurchasePharmaceutical')
AddEventHandler('QC-AdvancedMedic:server:PurchasePharmaceutical', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local job = Player.PlayerData.job
    if not IsMedicJob(job.name) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_access_denied'),
            description = locale('sv_must_be_medic_pharma'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if player is pharmacist or boss
    if job.grade.level < 2 and not job.grade.isboss then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_access_denied'),
            description = locale('sv_pharmacist_only'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if player has enough money
    local playerMoney = Player.PlayerData.money['cash'] or 0
    if playerMoney < data.totalCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_insufficient_funds'),
            description = string.format(locale('sv_need_money'), data.totalCost, playerMoney),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if player has inventory space
    local hasSpace = Player.Functions.AddItem(data.item, data.quantity, false, nil, true) -- dry run
    if not hasSpace then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_inventory_full'),
            description = locale('sv_not_enough_space'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Process purchase
    Player.Functions.RemoveMoney('cash', data.totalCost, 'pharmaceutical-purchase')
    Player.Functions.AddItem(data.item, data.quantity)
    
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[data.item], "add", data.quantity)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_purchase_successful'),
        description = string.format(locale('sv_purchased_items'), data.quantity, data.label, data.totalCost),
        type = 'success',
        duration = 5000
    })
    
    if Config.Debug then
        print(string.format('[PHARMACEUTICAL] %s purchased %dx %s for $%d', 
            Player.PlayerData.name, data.quantity, data.label, data.totalCost))
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	print('^8 '..resourceName..'^2 succesfully loaded^7')
end)

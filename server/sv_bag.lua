local RSGCore = exports['rsg-core']:GetCoreObject()

-- use medicalbag
RSGCore.Functions.CreateUseableItem("medicalbag", function(source, item)
	local src = source
	local Player = RSGCore.Functions.GetPlayer(src)
	TriggerClientEvent('qc-AdvancedMedic:client:medicbag', src)
	Player.Functions.RemoveItem('medicalbag', 1)
	TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['medicalbag'], "remove", 1)
end)

RegisterServerEvent('qc-AdvancedMedic:server:pickuptab')
AddEventHandler('qc-AdvancedMedic:server:pickuptab', function()
	local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	Player.Functions.AddItem('medicalbag', 1)
	TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['medicalbag'], "add", 1)
end)

RegisterNetEvent('qc-AdvancedMedic:server:pickup')
AddEventHandler('qc-AdvancedMedic:server:pickup', function(entity)
    local src = source
    --xSound:Destroy(src, tostring(entity))
end)

RSGCore.Functions.CreateCallback('qc-AdvancedMedic:server:checkingredients', function(source, cb, ingredients)
    local src = source
    local hasItems = false
    local icheck = 0
    local Player = RSGCore.Functions.GetPlayer(src)
    for k, v in pairs(ingredients) do
        if Player.Functions.GetItemByName(v.item) and Player.Functions.GetItemByName(v.item).amount >= v.amount then
            icheck = icheck + 1
            if icheck == #ingredients then
                cb(true)
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {title = "You don/t have the require items!", type = 'error' })
            cb(false)
            return
        end
    end
end)

-- finish cooking
RegisterServerEvent('qc-AdvancedMedic:server:finishcrafting')
AddEventHandler('qc-AdvancedMedic:server:finishcrafting', function(ingredients, receive)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    -- remove ingredients
    for k, v in pairs(ingredients) do
        if Config.Debug == true then
            print(v.item)
            print(v.amount)
        end
        Player.Functions.RemoveItem(v.item, v.amount)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[v.item], "remove")
    end
    Player.Functions.AddItem(receive, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[receive], "add")
    TriggerClientEvent('ox_lib:notify', source, {title = "Crafting finished!", type = 'success' })
end)

RegisterNetEvent('qc-AdvancedMedic:server:openbaginv', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = 'Medical Bag', maxweight = Config.BagMaxWeight, slots = Config.BagMaxSlots }
    local stashName = 'medic_bag'
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

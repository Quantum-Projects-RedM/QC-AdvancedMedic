local RSGCore = exports['rsg-core']:GetCoreObject()

-- use medicalbag
RSGCore.Functions.CreateUseableItem("medicalbag", function(source, item)
	local src = source
	local Player = RSGCore.Functions.GetPlayer(src)
	TriggerClientEvent('QC-AdvancedMedic:client:medicbag', src)
	Player.Functions.RemoveItem('medicalbag', 1)
	TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['medicalbag'], "remove", 1)
end)

RegisterServerEvent('QC-AdvancedMedic:server:pickuptab')
AddEventHandler('QC-AdvancedMedic:server:pickuptab', function()
	local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	Player.Functions.AddItem('medicalbag', 1)
	TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['medicalbag'], "add", 1)
end)

RegisterNetEvent('QC-AdvancedMedic:server:pickup')
AddEventHandler('QC-AdvancedMedic:server:pickup', function(entity)
    local src = source
    --might add soon :)
end)

RSGCore.Functions.CreateCallback('QC-AdvancedMedic:server:checkingredients', function(source, cb, ingredients)
    local src = source
    local hasItems = false
    local icheck = 0
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    for k, v in pairs(ingredients) do
        if Player.Functions.GetItemByName(v.item) and Player.Functions.GetItemByName(v.item).amount >= v.amount then
            icheck = icheck + 1
            if icheck == #ingredients then
                cb(true)
            end
        else
            cb(false)
        end
    end
end)

RegisterServerEvent('QC-AdvancedMedic:server:finishcrafting', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    for _, ingredient in pairs(data.ingredients) do
        local removed = Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
        if removed then
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ingredient.item], 'remove', ingredient.amount)
        else
            return
        end
    end
    local added = Player.Functions.AddItem(data.receive, data.giveamount)
    if added then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[data.receive], 'add', data.giveamount)
    end
end)



RegisterNetEvent('QC-AdvancedMedic:server:openbaginv', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = 'Medical Bag', maxweight = Config.BagMaxWeight, slots = Config.BagMaxSlots }
    local stashName = 'medic_bag' .. Player.PlayerData.citizenid
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

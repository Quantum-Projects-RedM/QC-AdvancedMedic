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
    --might add soon :)
end)

RSGCore.Functions.CreateCallback('qc-AdvancedMedic:server:checkingredients', function(source, cb, ingredients)
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

RegisterServerEvent('qc-AdvancedMedic:server:finishcrafting', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then 
        print("[DEBUG] Player not found on finish crafting.") -- Debug
        return 
    end

    print("[DEBUG] Finalizing crafting for player: " .. Player.PlayerData.citizenid) -- Debug

    -- Debugging Data Received
    print("[DEBUG] Crafting data received: " .. json.encode(data))

    -- Verify Ingredients Removal
    for _, ingredient in pairs(data.ingredients) do
        local removed = Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
        if removed then
            print("[DEBUG] Removed " .. ingredient.amount .. " of " .. ingredient.item) -- Debug
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ingredient.item], 'remove', ingredient.amount)
        else
            print("[DEBUG] Failed to remove item: " .. ingredient.item .. " - Player may not have enough.") -- Debug
            return
        end
    end

    -- Validate Item Addition
    local added = Player.Functions.AddItem(data.receive, data.giveamount)
    if added then
        print("[DEBUG] Successfully added crafted item: " .. data.receive .. " x" .. data.giveamount) -- Debug
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[data.receive], 'add', data.giveamount)
    else
        print("[DEBUG] Failed to add crafted item: " .. data.receive) -- Debug
        print("[DEBUG] Check if the item exists in RSGCore.Shared.Items or inventory configuration.")
    end
end)



RegisterNetEvent('qc-AdvancedMedic:server:openbaginv', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = 'Medical Bag', maxweight = Config.BagMaxWeight, slots = Config.BagMaxSlots }
    local stashName = 'medic_bag' .. Player.PlayerData.citizenid
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

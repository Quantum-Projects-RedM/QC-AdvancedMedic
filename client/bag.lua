local RSGCore = exports['rsg-core']:GetCoreObject()
local medicbag = 0
local deployedtable = nil
local MedicMenus = {}
lib.locale()
exports['rsg-target']:AddTargetModel(1259819729, {
    options = {
        {
            type = "client",
            event = 'qc-AdvancedMedic:client:pickup',
            icon = "fas fa-undo",
            label = "Pickup Medical Bag",
            distance = 3.0
        }
    }
})

exports['rsg-target']:AddTargetModel(1259819729, {
    options = {
        {
            icon = 'far fa-gear',
            label = 'Open Medical Bag',
            type = "client",
            event = 'qc-AdvancedMedic:client:medicbagMenu',
        },
    },
    distance = 2.0,
})

AddEventHandler('qc-AdvancedMedic:client:bagstorage', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then return end
    TriggerServerEvent('qc-AdvancedMedic:server:openbaginv')
end)

RegisterNetEvent('qc-AdvancedMedic:client:pickup', function()
    if deployedtable ~= nil then
        local obj = NetworkGetEntityFromNetworkId(deployedtable)
        local objCoords = GetEntityCoords()
        local ped = PlayerPedId()
        NetworkRequestControlOfEntity(obj)
        SetEntityAsMissionEntity(obj,false,true)
        DeleteEntity(obj)
        DeleteObject(obj)
        if not DoesEntityExist(obj) then
            TriggerServerEvent('qc-AdvancedMedic:server:pickup', deployedtable)
            TriggerServerEvent('qc-AdvancedMedic:server:pickuptab')
            deployedtable = nil
        end
        Wait(500)
        ClearPedTasks(ped)
    else
        lib.notify( {title = "No Medic Bag to pick up.", type = 'error' })
    end
end)

RegisterNetEvent('qc-AdvancedMedic:client:medicbag', function()
    print("Event triggered!")
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forward = GetEntityForwardVector(ped)
    local x, y, z = table.unpack(coords + forward * 0.5)
    local model = GetHashKey('p_bag_leather_doctor')
    if not HasModelLoaded(model) then
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
    end
    local object = CreateObject(model, x, y, z + 1.0, true, true, false)
    if DoesEntityExist(object) then
        PlaceObjectOnGroundProperly(object)
        SetEntityHeading(object, heading)
        FreezeEntityPosition(object, true)
        deployedtable = NetworkGetNetworkIdFromEntity(object)
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CROUCH_INSPECT", -1, true)
        Wait(5000)
        ClearPedTasks(ped)
    else
        print("Failed to spawn the object!")
    end
    SetModelAsNoLongerNeeded(model)
end)

CreateThread(function()
    for _, v in ipairs(Config.MedicBagCrafting) do
        local IngredientsMetadata = {}
        local setheader = RSGCore.Shared.Items[tostring(v.receive)].label
        local itemimg = "nui://"..Config.Image..RSGCore.Shared.Items[tostring(v.receive)].image
        for i, ingredient in ipairs(v.ingredients) do
            table.insert(IngredientsMetadata, { label = RSGCore.Shared.Items[ingredient.item].label, value = ingredient.amount })
        end
        local option = {
            title = setheader,
            icon = itemimg,
            event = 'qc-AdvancedMedic:client:mediccraft',
            metadata = IngredientsMetadata,
            args = {
                title = setheader,
                category = v.category,
                ingredients = v.ingredients,
                crafttime = v.crafttime,
                craftingrep = v.craftingrep,
                receive = v.receive,
                giveamount = v.giveamount
            }
        }
        if not MedicMenus[v.category] then
            MedicMenus[v.category] = {
                id = 'crafting_menu_' .. v.category,
                title = v.category,
                menu = 'crafting_menu',
                onBack = function() end,
                options = { option }
            }
        else
            table.insert(MedicMenus[v.category].options, option)
        end
    end
end)

CreateThread(function()
    for category, MenuData in pairs(MedicMenus) do
        RegisterNetEvent('qc-AdvancedMedic:client:' .. category)
        AddEventHandler('qc-AdvancedMedic:client:' .. category, function()
            lib.registerContext(MenuData)
            lib.showContext(MenuData.id)
        end)
    end
end)

RegisterNetEvent('qc-AdvancedMedic:client:craftingmenu', function()
    local Menu = {
        id = 'med_craft',
        title = 'Medical Crafting',
        options = {}
    }

    for category, MenuData in pairs(MedicMenus) do
        table.insert(Menu.options, {
            title = category,
            event = 'qc-AdvancedMedic:client:' .. category,
            arrow = true
        })
    end
    lib.registerContext(Menu)
    lib.showContext(Menu.id)
end)

RegisterNetEvent('qc-AdvancedMedic:client:medicbagMenu', function()
    lib.registerContext({
        id = 'medicbag_menu',
        title = 'Medic Bag',
        options = {
            {
                title = 'Crafting Menu',
                description = 'Useful Crafting medical equipment',
                icon = 'fa-solid fa-user-secret',
                event = 'qc-AdvancedMedic:client:craftingmenu',
                arrow = true
            },
            {
                title = 'Open Stash',
                description = 'Medical storage for equipment',
                icon = 'fa-solid fa-user',
                event = 'qc-AdvancedMedic:client:bagstorage',
                arrow = true
            },
        }
    })
    lib.showContext('medicbag_menu')
end)

RegisterNetEvent('qc-AdvancedMedic:client:checkingredients', function(data)
    RSGCore.Functions.TriggerCallback('qc-AdvancedMedic:server:checkingredients', function(hasRequired)
    if (hasRequired) then
        if Config.Debug == true then
            print("passed")
        end
        TriggerEvent('qc-AdvancedMedic:crafting', data.name, data.item, tonumber(data.crafttime), data.receive)
    else
        if Config.Debug == true then
            print("failed")
        end
        return
    end
    end, Config.medicbagRecipes[data.item].ingredients)
end)

RegisterNetEvent('qc-AdvancedMedic:client:mediccraft', function(data)
    RSGCore.Functions.TriggerCallback('qc-AdvancedMedic:server:checkingredients', function(hasRequired)
        if hasRequired == true then
            lib.progressBar({
                duration = tonumber(data.crafttime),
                position = 'bottom',
                useWhileDead = false,
                canCancel = false,
                disableControl = true,
                disable = {
                    move = true,
                    mouse = true,
                },
                label = "Crafting ".. RSGCore.Shared.Items[data.receive].label,
            })
            TriggerServerEvent('qc-AdvancedMedic:server:finishcrafting', data)
        else
            lib.notify({ title = "Crafting items missing!", type = 'inform', duration = 7000 })
        end
    end, data.ingredients)
end)


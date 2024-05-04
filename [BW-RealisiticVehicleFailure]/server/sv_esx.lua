if GetResourceState('es_extended') ~= 'started' then return end

-- Framework detection
if exports['es_extended'] then
    ESX = exports['es_extended']:getSharedObject()
    QBCore = nil -- Set QBCore to nil to avoid false detection
    print("Detected framework: esx")
elseif exports['qb-core'] then
    ESX = nil -- Set ESX to nil to avoid false detection
    print("Detected framework: qb")
else
    print("Unknown framework or resource not started")
    return
end

ESX = exports["es_extended"]:getSharedObject()

local function countMechanics()
    local mechCount = 0
    for _, player in ipairs(ESX.GetExtendedPlayers()) do
        local job = player.getJob()
        for _, jobName in ipairs(cfg.mechJob) do
            if job and job.name == jobName then 
                mechCount = mechCount + 1
            end
        end
    end
    return mechCount
end

lib.callback.register('RealisticVehicleFailure:mechCount', countMechanics)

ESX.RegisterUsableItem('repairkit', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local item = xPlayer.getInventoryItem('repairkit')
        if item and item.count > 0 then
            TriggerClientEvent('RealisticVehicleFailure:client:RepairVehicleFull', source)
        end
    end
end)

RegisterNetEvent('RealisticVehicleFailure:removeItem')
AddEventHandler('RealisticVehicleFailure:removeItem', function(item)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        xPlayer.removeInventoryItem(item, 1)
    end
end)

ESX.RegisterUsableItem('cleaningkit', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local item = xPlayer.getInventoryItem('cleaningkit')
        if item and item.count > 0 then
            TriggerClientEvent('RealisticVehicleFailure:client:CleanVehicle', source)
        end
    end
end)

RegisterNetEvent('RealisticVehicleFailure:removecleaningkit')
AddEventHandler('RealisticVehicleFailure:removecleaningkit', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        xPlayer.removeInventoryItem('cleaningkit', 1)
    end
end)

ESX.RegisterServerCallback('RealisticVehicleFailure:checkCleaningKit', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local hasCleaningKit = xPlayer.getInventoryItem('cleaningkit').count > 0
        cb(hasCleaningKit)
    else
        cb(false)
    end
end)
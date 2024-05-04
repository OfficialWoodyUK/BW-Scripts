if GetResourceState('qb-core') ~= 'started' then return end

-- Framework detection
if exports['qb-core'] then
    QBCore = exports['qb-core']:GetCoreObject()
    ESX = nil -- Set ESX to nil to avoid false detection
    print("Detected framework: qb")
elseif exports['es_extended'] then
    QBCore = nil -- Set QBCore to nil to avoid false detection
    print("Detected framework: esx")
else
    print("Unknown framework or resource not started")
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem("cleaningkit", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local slotItem = Player.Functions.GetItemBySlot(item.slot)
        if slotItem then
            TriggerClientEvent("RealisticVehicleFailure:client:CleanVehicle", source)
        end
    end
end)

QBCore.Functions.CreateUseableItem("repairkit", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local slotItem = Player.Functions.GetItemBySlot(item.slot)
        if slotItem then
            TriggerClientEvent("RealisticVehicleFailure:client:RepairVehicleFull", source)
        end
    end
end)

RegisterNetEvent('RealisticVehicleFailure:removeItem', function(item)
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if ply then
        ply.Functions.RemoveItem(item, 1)
    end
end)

RegisterNetEvent('RealisticVehicleFailure:server:removewashingkit', function(veh)
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if ply then
        ply.Functions.RemoveItem("cleaningkit", 1)
        TriggerClientEvent('RealisticVehicleFailure:client:SyncWash', -1, veh)
    end
end)

if QBCore then
    lib.callback.register('RealisticVehicleFailure:mechCount', function(mechCount)
        local mechJobs = {}
        for _, job in pairs(cfg.mechJob) do
            mechJobs[job] = true
        end

        local mechanicCount = 0
        for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
            local job = player.PlayerData.job
            if mechJobs[job.name] then
                mechanicCount = mechanicCount + 1
            end
        end

        return mechanicCount
    end)
end

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

local pedInSameVehicleLast=false
local vehicle
local lastVehicle
local vehicleClass
local fCollisionDamageMult = 0.0
local fDeformationDamageMult = 0.0
local fEngineDamageMult = 0.0
local fBrakeForce = 1.0
local isBrakingForward = false
local isBrakingReverse = false

local healthEngineLast = 1000.0
local healthEngineCurrent = 1000.0
local healthEngineNew = 1000.0
local healthEngineDelta = 0.0
local healthEngineDeltaScaled = 0.0

local healthBodyLast = 1000.0
local healthBodyCurrent = 1000.0
local healthBodyNew = 1000.0
local healthBodyDelta = 0.0
local healthBodyDeltaScaled = 0.0

local healthPetrolTankLast = 1000.0
local healthPetrolTankCurrent = 1000.0
local healthPetrolTankNew = 1000.0
local healthPetrolTankDelta = 0.0
local healthPetrolTankDeltaScaled = 0.0
local tireBurstLuckyNumber

math.randomseed(GetGameTimer());
---qb-core stuff
---@param veh number
local function cleanVehicle(veh)
    local ped = cache.ped
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_MAID_CLEAN", 0, true)
    QBCore.Functions.Progressbar("cleaning_vehicle", "Cleaning the vehicle", cfg.cleaningTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        QBCore.Functions.Notify('Vehicle cleaned successfully', 'success', 5000)
        SetVehicleDirtLevel(veh, 0.1)
        SetVehicleUndriveable(veh, false)
        WashDecalsFromVehicle(veh, 1.0)
        TriggerServerEvent('RealisticVehicleFailure:server:removewashingkit', veh)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["cleaningkit"], "remove")
        ClearAllPedProps(ped)
        ClearPedTasks(ped)
    end, function() -- Cancel
        QBCore.Functions.Notify('Failed to clean the vehicle', 'error', 5000)
        ClearAllPedProps(ped)
        ClearPedTasks(ped)
    end)
end

local function isBackEngine(vehModel)
    if BackEngineVehicles[vehModel] then return true else return false end
end
---@param veh number
local function openVehicleDoors(veh)
    if isBackEngine(GetEntityModel(veh)) then
        SetVehicleDoorOpen(veh, 5, false, false)
    else
        SetVehicleDoorOpen(veh, 4, false, false)
    end
end

---@param veh number
local function closeVehicleDoors(veh)
    if isBackEngine(GetEntityModel(veh)) then
        SetVehicleDoorShut(veh, 5, false)
    else
        SetVehicleDoorShut(veh, 4, false)
    end
end

local function repairVehicle(veh, engineHealth, itemName, timeLowerBound, timeUpperBound)
    local mechCount = lib.callback.await('RealisticVehicleFailure:mechCount', mechCount)
    if mechCount <= 0 then 
        openVehicleDoors(veh)
        
        QBCore.Functions.Progressbar("repair_vehicle", "Repairing the vehicle", cfg.repairTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "mini@repair",
            anim = "fixing_a_player",
            flags = 16,
        }, {}, {}, function() -- Done
            StopAnimTask(cache.ped, "mini@repair", "fixing_a_player", 1.0)
            QBCore.Functions.Notify('Vehicle repaired successfully', 'success', 5000)
            SetVehicleEngineHealth(veh, 1000)
            SetVehicleEngineOn(veh, true, false)
            SetVehicleTyreFixed(veh, 0)
            SetVehicleTyreFixed(veh, 1)
            SetVehicleTyreFixed(veh, 2)
            SetVehicleTyreFixed(veh, 3)
            SetVehicleTyreFixed(veh, 4)
            closeVehicleDoors(veh)
            SetVehicleFixed(veh)
            TriggerServerEvent('RealisticVehicleFailure:removeItem', itemName)
        end, function() -- Cancel
            StopAnimTask(cache.ped, "mini@repair", "fixing_a_player", 1.0)
            QBCore.Functions.Notify('Failed to repair the vehicle', 'error', 5000)
            closeVehicleDoors(veh)
        end)
    else
		QBCore.Functions.Notify('There are too many mechanics on duty! Call someone.', 'error', 5000)
	end
end

---@param veh number
local function repairVehicleFull(veh)
    repairVehicle(veh, 1000, 'repairkit', cfg.repairTime)
end

---@return number? veh
local function getVehicleToRepair()
    if cache.vehicle then
        QBCore.Functions.Notify('You are already inside a vehicle', 'error', 5000)
        return
    end

    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5, false)
    if not veh then
        QBCore.Functions.Notify('No vehicle nearby', 'error', 5000)
        return
    end

    local pos = GetEntityCoords(cache.ped)
    local drawpos = GetOffsetFromEntityInWorldCoords(veh, 0, 2.5, 0)
    if (isBackEngine(GetEntityModel(veh))) then
        drawpos = GetOffsetFromEntityInWorldCoords(veh, 0, -2.5, 0)
    end

    if #(pos - drawpos) >= 2.0 then
        return
    end

    return veh
end

RegisterNetEvent('RealisticVehicleFailure:client:RepairVehicle', function()
    local veh = getVehicleToRepair()
    if not veh then return end

    local engineHealth = GetVehicleEngineHealth(veh) --This is to prevent people from "repairing" a vehicle and setting engine health lower than what the vehicles engine health was before repairing.
    if engineHealth >= 500 then
        QBCore.Functions.Notify('The vehicle is already in good condition', 'error', 5000)
        return
    end

    repairVehicleHalf(veh)
end)

RegisterNetEvent('RealisticVehicleFailure:client:RepairVehicleFull', function()
    local veh = getVehicleToRepair()
    if not veh then return end
    repairVehicleFull(veh)
end)

---@param veh number
RegisterNetEvent('RealisticVehicleFailure:client:SyncWash', function(veh)
    SetVehicleDirtLevel(veh, 0.1)
    SetVehicleUndriveable(veh, false)
    WashDecalsFromVehicle(veh, 1.0)
end)

RegisterNetEvent('RealisticVehicleFailure:client:CleanVehicle', function()
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3, false)
    if not veh then return end
    cleanVehicle(veh)
end)



local tireBurstMaxNumber = cfg.randomTireBurstInterval * 1200;                                               -- the tire burst lottery runs roughly 1200 times per minute
if cfg.randomTireBurstInterval ~= 0 then tireBurstLuckyNumber = math.random(tireBurstMaxNumber) end          -- If we hit this number again randomly, a tire will burst.

local function notification(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

local function isPedDrivingAVehicle()
    local ped = GetPlayerPed(-1)
    vehicle = GetVehiclePedIsIn(ped, false)
    if IsPedInAnyVehicle(ped, false) then
        -- Check if ped is in driver seat
        if GetPedInVehicleSeat(vehicle, -1) == ped then
            local class = GetVehicleClass(vehicle)
            -- We don't want planes, helicopters, bicycles and trains
            if class ~= 15 and class ~= 16 and class ~=21 and class ~=13 then
                return true
            end
        end
    end
    return false
end

local function fscale(inputValue, originalMin, originalMax, newBegin, newEnd, curve)
    local OriginalRange = 0.0
    local NewRange = 0.0
    local zeroRefCurVal = 0.0
    local normalizedCurVal = 0.0
    local rangedValue = 0.0
    local invFlag = 0

    if (curve > 10.0) then curve = 10.0 end
    if (curve < -10.0) then curve = -10.0 end

    curve = (curve * -.1)
    curve = 10.0 ^ curve

    if (inputValue < originalMin) then
      inputValue = originalMin
    end
    if inputValue > originalMax then
      inputValue = originalMax
    end

    OriginalRange = originalMax - originalMin

    if (newEnd > newBegin) then
        NewRange = newEnd - newBegin
    else
      NewRange = newBegin - newEnd
      invFlag = 1
    end

    zeroRefCurVal = inputValue - originalMin
    normalizedCurVal  =  zeroRefCurVal / OriginalRange

    if (originalMin > originalMax ) then
      return 0
    end

    if (invFlag == 0) then
        rangedValue =  ((normalizedCurVal ^ curve) * NewRange) + newBegin
    else
        rangedValue =  newBegin - ((normalizedCurVal ^ curve) * NewRange)
    end

    return rangedValue
end



local function tireBurstLottery()
    local tireBurstNumber = math.random(tireBurstMaxNumber)
    if tireBurstNumber == tireBurstLuckyNumber then
        -- We won the lottery, lets burst a tire.
        if GetVehicleTyresCanBurst(vehicle) == false then return end
        local numWheels = GetVehicleNumberOfWheels(vehicle)
        local affectedTire
        if numWheels == 2 then
            affectedTire = (math.random(2)-1)*4        -- wheel 0 or 4
        elseif numWheels == 4 then
            affectedTire = (math.random(4)-1)
            if affectedTire > 1 then affectedTire = affectedTire + 2 end    -- 0, 1, 4, 5
        elseif numWheels == 6 then
            affectedTire = (math.random(6)-1)
        else
            affectedTire = 0
        end
        SetVehicleTyreBurst(vehicle, affectedTire, false, 1000.0)
        tireBurstLuckyNumber = math.random(tireBurstMaxNumber)            -- Select a new number to hit, just in case some numbers occur more often than others
    end
end


if cfg.torqueMultiplierEnabled or cfg.preventVehicleFlip or cfg.limpMode then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if cfg.torqueMultiplierEnabled or cfg.sundayDriver or cfg.limpMode then
                if pedInSameVehicleLast then
                    local factor = 1.0
                    if cfg.torqueMultiplierEnabled and healthEngineNew < 900 then
                        factor = (healthEngineNew+200.0) / 1100
                    end
                    if cfg.sundayDriver and GetVehicleClass(vehicle) ~= 14 then -- Not for boats
                        local accelerator = GetControlValue(2,71)
                        local brake = GetControlValue(2,72)
                        local speed = GetEntitySpeedVector(vehicle, true)['y']
                        -- Change Braking force
                        local brk = fBrakeForce
                        if speed >= 1.0 then
                            -- Going forward
                            if accelerator > 127 then
                                -- Forward and accelerating
                                local acc = fscale(accelerator, 127.0, 254.0, 0.1, 1.0, 10.0-(cfg.sundayDriverAcceleratorCurve*2.0))
                                factor = factor * acc
                            end
                            if brake > 127 then
                                -- Forward and braking
                                isBrakingForward = true
                                brk = fscale(brake, 127.0, 254.0, 0.01, fBrakeForce, 10.0-(cfg.sundayDriverBrakeCurve*2.0))
                            end
                        elseif speed <= -1.0 then
                            -- Going reverse
                            if brake > 127 then
                                -- Reversing and accelerating (using the brake)
                                local rev = fscale(brake, 127.0, 254.0, 0.1, 1.0, 10.0-(cfg.sundayDriverAcceleratorCurve*2.0))
                                factor = factor * rev
                            end
                            if accelerator > 127 then
                                -- Reversing and braking (Using the accelerator)
                                isBrakingReverse = true
                                brk = fscale(accelerator, 127.0, 254.0, 0.01, fBrakeForce, 10.0-(cfg.sundayDriverBrakeCurve*2.0))
                            end
                        else
                            -- Stopped or almost stopped or sliding sideways
                            local entitySpeed = GetEntitySpeed(vehicle)
                            if entitySpeed < 1 then
                                -- Not sliding sideways
                                if isBrakingForward == true then
                                    --Stopped or going slightly forward while braking
                                    DisableControlAction(2,72,true) -- Disable Brake until user lets go of brake
                                    SetVehicleForwardSpeed(vehicle,speed*0.98)
                                    SetVehicleBrakeLights(vehicle,true)
                                end
                                if isBrakingReverse == true then
                                    --Stopped or going slightly in reverse while braking
                                    DisableControlAction(2,71,true) -- Disable reverse Brake until user lets go of reverse brake (Accelerator)
                                    SetVehicleForwardSpeed(vehicle,speed*0.98)
                                    SetVehicleBrakeLights(vehicle,true)
                                end
                                if isBrakingForward == true and GetDisabledControlNormal(2,72) == 0 then
                                    -- We let go of the brake
                                    isBrakingForward=false
                                end
                                if isBrakingReverse == true and GetDisabledControlNormal(2,71) == 0 then
                                    -- We let go of the reverse brake (Accelerator)
                                    isBrakingReverse=false
                                end
                            end
                        end
                        if brk > fBrakeForce - 0.02 then brk = fBrakeForce end -- Make sure we can brake max.
                        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', brk)  -- Set new Brake Force multiplier
                    end
                    if cfg.limpMode == true and healthEngineNew < cfg.engineSafeGuard + 5 then
                        factor = cfg.limpModeMultiplier
                    end
                    SetVehicleEngineTorqueMultiplier(vehicle, factor)
                end
            end
            if cfg.preventVehicleFlip then
                local roll = GetEntityRoll(vehicle)
                if (roll > 75.0 or roll < -75.0) and GetEntitySpeed(vehicle) < 2 then
                    DisableControlAction(2,59,true) -- Disable left/right
                    DisableControlAction(2,60,true) -- Disable up/down
                end
            end
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(50)
        local ped = GetPlayerPed(-1)
        if isPedDrivingAVehicle() then
            vehicle = GetVehiclePedIsIn(ped, false)
            vehicleClass = GetVehicleClass(vehicle)
            healthEngineCurrent = GetVehicleEngineHealth(vehicle)
            if healthEngineCurrent == 1000 then healthEngineLast = 1000.0 end
            healthEngineNew = healthEngineCurrent
            healthEngineDelta = healthEngineLast - healthEngineCurrent
            healthEngineDeltaScaled = healthEngineDelta * cfg.damageFactorEngine * cfg.classDamageMultiplier[vehicleClass]

            healthBodyCurrent = GetVehicleBodyHealth(vehicle)
            if healthBodyCurrent == 1000 then healthBodyLast = 1000.0 end
            healthBodyNew = healthBodyCurrent
            healthBodyDelta = healthBodyLast - healthBodyCurrent
            healthBodyDeltaScaled = healthBodyDelta * cfg.damageFactorBody * cfg.classDamageMultiplier[vehicleClass]

            healthPetrolTankCurrent = GetVehiclePetrolTankHealth(vehicle)
            if cfg.compatibilityMode and healthPetrolTankCurrent < 1 then
                --  SetVehiclePetrolTankHealth(vehicle, healthPetrolTankLast)
                --  healthPetrolTankCurrent = healthPetrolTankLast
                healthPetrolTankLast = healthPetrolTankCurrent
            end
            if healthPetrolTankCurrent == 1000 then healthPetrolTankLast = 1000.0 end
            healthPetrolTankNew = healthPetrolTankCurrent
            healthPetrolTankDelta = healthPetrolTankLast-healthPetrolTankCurrent
            healthPetrolTankDeltaScaled = healthPetrolTankDelta * cfg.damageFactorPetrolTank * cfg.classDamageMultiplier[vehicleClass]

            if healthEngineCurrent > cfg.engineSafeGuard+1 then
                SetVehicleUndriveable(vehicle,false)
            end

            if healthEngineCurrent <= cfg.engineSafeGuard+1 and cfg.limpMode == false then
                SetVehicleUndriveable(vehicle,true)
            end

            -- If ped spawned a new vehicle while in a vehicle or teleported from one vehicle to another, handle as if we just entered the car
            if vehicle ~= lastVehicle then
                pedInSameVehicleLast = false
            end


            if pedInSameVehicleLast == true then
                -- Damage happened while in the car = default scale
                --  notification("Damage: "..healthEngineDeltaScaled.."/"..healthBodyDeltaScaled.."/"..healthPetrolTankDeltaScaled)
                SetVehiclePetrolTankHealth(vehicle,healthPetrolTankNew+healthPetrolTankDeltaScaled)
                if cfg.randomTireBurstInterval ~= 0 then tireBurstLottery() end
                if cfg.debug then
                    notification("Delta: "..healthEngineDeltaScaled.."/"..healthBodyDeltaScaled.."/"..healthPetrolTankDeltaScaled)
                    notification("Vehicle class: "..vehicleClass.." Engine Health: "..healthEngineNew.." Body Health: "..healthBodyNew.." Tank Health: "..healthPetrolTankNew)
                end
            end

            --  notification("Health: "..healthEngineCurrent.."/"..healthBodyCurrent.."/"..healthPetrolTankCurrent)
            if cfg.debug then
                notification("Vehicle class: "..vehicleClass.." Engine Health: "..healthEngineNew.." Body Health: "..healthBodyNew.." Tank Health: "..healthPetrolTankNew)
            end

            lastVehicle = vehicle
            pedInSameVehicleLast = true
            healthEngineLast = healthEngineCurrent
            healthBodyLast = healthBodyCurrent
            healthPetrolTankLast = healthPetrolTankCurrent

        else
            pedInSameVehicleLast = false
        end
    end
end)

function RefreshVehicleMods(vehicle)
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 11, 2)
    SetVehicleMod(vehicle, 12, 2)
    SetVehicleMod(vehicle, 13, 2)
    SetVehicleMod(vehicle, 15, 2)
    SetVehicleMod(vehicle, 16, 2)
    ToggleVehicleMod(vehicle, 18, false)
    ToggleVehicleMod(vehicle, 20, false)
    ToggleVehicleMod(vehicle, 22, false)
    ToggleVehicleMod(vehicle, 23, false)
    ToggleVehicleMod(vehicle, 24, false)
    ToggleVehicleMod(vehicle, 25, false)
    ToggleVehicleMod(vehicle, 27, false)
    ToggleVehicleMod(vehicle, 28, false)
    ToggleVehicleMod(vehicle, 29, false)
    ToggleVehicleMod(vehicle, 30, false)
    ToggleVehicleMod(vehicle, 35, false)
    ToggleVehicleMod(vehicle, 38, false)
    ToggleVehicleMod(vehicle, 40, false)
    ToggleVehicleMod(vehicle, 42, false)
    ToggleVehicleMod(vehicle, 43, false)
    ToggleVehicleMod(vehicle, 45, false)
    ToggleVehicleMod(vehicle, 46, false)
    ToggleVehicleMod(vehicle, 48, false)
    SetVehicleTyresCanBurst(vehicle, false)
    SetVehicleWheelsCanBreak(vehicle, false)
    SetVehicleNumberPlateTextIndex(vehicle, 5)
    SetVehicleWindowTint(vehicle, 1)
    SetVehicleNumberPlateText(vehicle, "ADMIN")
    SetVehicleModColor_1(vehicle, 117, 117, 117)
    SetVehicleModColor_2(vehicle, 117, 117, 117)
    SetVehicleCustomPrimaryColour(vehicle, 117, 117, 117)
    SetVehicleCustomSecondaryColour(vehicle, 117, 117, 117)
    SetVehicleColours(vehicle, 117, 117)
    SetVehicleExtraColours(vehicle, 70, 70)
    SetVehicleNeonLightsColour(vehicle, 70, 70, 70)
    SetVehicleIsConsideredByPlayer(vehicle, true)
    SetVehicleBurnout(vehicle, true)
    SetVehicleEnginePowerMultiplier(vehicle, 25.0)
    SetVehicleEngineTorqueMultiplier(vehicle, 25.0)
    SetVehicleCanBeVisiblyDamaged(vehicle, false)
    SetVehicleExplodesOnHighExplosionDamage(vehicle, false)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineOn(vehicle, true, true)
    SetVehicleOilLevel(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleTyreFixed(vehicle, 0)
    SetVehicleTyreFixed(vehicle, 1)
    SetVehicleTyreFixed(vehicle, 2)
    SetVehicleTyreFixed(vehicle, 3)
    SetVehicleTyreFixed(vehicle, 4)
    SetVehicleTyreFixed(vehicle, 5)
end
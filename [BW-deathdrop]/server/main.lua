if GetResourceState('es_extended') ~= 'started' then return end

-- Framework detection
if exports['es_extended'] then
    ESX = exports['es_extended']:getSharedObject()
    QBCore = nil -- Set QBCore to nil to avoid false detection
    print("Detected framework: esx")
elseif exports['qb-core'] then
    ESX = nil -- Set ESX to nil to avoid false detection
    print("Detected framework: qb is not supported at the moment")
else
    print("Unknown framework or resource not started")
    return
end

ESX = exports["es_extended"]:getSharedObject()

local expectedFolderName = "BW-deathdrop"

local function checkFolderName()
    local currentFolder = GetCurrentResourceName()
    if currentFolder ~= expectedFolderName then
        print("^1WARNING: Script folder has been renamed! It has to be 'BW-deathdrop'^0")
    end
end

local function checkFileIntegrity()

end

local function InitializeScript()
    checkFolderName()
    checkFileIntegrity()

end

InitializeScript()

RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    data.victim = source
    local xPlayer = ESX.GetPlayerFromId(data.victim)
    local rawInventory = exports.ox_inventory:Inventory(data.victim).items
    local inventory = {}
        
    if Config.includeItemsToDrop then
        for _, itemName in ipairs(Config.itemsToDrop) do
            for _, v in pairs(rawInventory) do
                if v.name == itemName then
                    inventory[#inventory + 1] = {
                        v.name,
                        v.count,
                        v.metadata
                    }
                    exports.ox_inventory:RemoveItem(data.victim, v.name, v.count, v.metadata)
                end
            end
        end
    end

    if Config.includeWeaponsInDrop then
        for _, v in pairs(rawInventory) do
            for _, weaponName in ipairs(Config.weaponsToDrop) do
                if v.name == weaponName then
                    inventory[#inventory + 1] = {
                        v.name,
                        v.count,
                        v.metadata
                    }
                    exports.ox_inventory:RemoveItem(data.victim, v.name, v.count, v.metadata)
                end
            end
        end
    end

    local deathCoords = xPlayer.getCoords(true)
    if #inventory > 0 then
        exports.ox_inventory:CustomDrop('Death Drop', inventory, deathCoords)
        end
    end)

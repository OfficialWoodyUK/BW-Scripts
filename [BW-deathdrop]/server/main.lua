if Config.Framework == "ESX" then

ESX = exports["es_extended"]:getSharedObject()

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
end
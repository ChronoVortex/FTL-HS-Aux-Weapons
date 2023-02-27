if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order", 2)
end

local vter = mods.vertexutil.vter

-- Pre-ignite weapons to the right of the light igniter
local wasJumping = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local isJumping = false
    if pcall(function() isJumping = Hyperspace.ships.player.bJumping end) then
        if not isJumping and wasJumping then
            local weapons = nil
            pcall(function() weapons = Hyperspace.ships.player.weaponSystem.weapons end)
            if weapons then
                local lastWeaponWasIgniter = false
                for weapon in vter(weapons) do
                    if lastWeaponWasIgniter and weapon.powered then
                        weapon:ForceCoolup()
                    end
                    lastWeaponWasIgniter = weapon.blueprint.name == "LIGHT_PRE_IGNITER"
                end
            end
        end
        wasJumping = isJumping
    end
end)

local painters = {}
painters["LASER_PAINT"] = true
painters["LASER_PIERCE_PAINT"] = true

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    if weaponName then
        -- Make drones target the location the target painter laser hit
        if painters[weaponName] then
            for drone in vter(Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2).spaceDrones) do
                drone.targetLocation = location
            end
        end
        
        -- Change sex for trans bomb
        if weaponName == "BOMB_TRANS" then
            local impactRoom = shipManager.ship:GetSelectedRoomId(location.x, location.y, true)
            for crewmem in vter(shipManager.vCrewList) do
                if crewmem.iRoomId == impactRoom then
                    crewmem:SetSex(not crewmem.crewAnim.bMale)
                end
            end
        end
    end
end)

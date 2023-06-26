if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.vertexutil.vter
local INT_MAX = 2147483647

-----------------------
-- TACTICAL RECYCLER --
-----------------------
local function handle_tac_recycler(weapons)
    for weapon in vter(weapons) do
        if weapon.blueprint.name == "RECYCLER_CORE" then
            if not weapon.powered then
                weapon.cooldown.first = 0
                weapon.chargeLevel = 0
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local weaponsPlayer = nil
    if pcall(function() weaponsPlayer = Hyperspace.ships.player.weaponSystem.weapons end) and weaponsPlayer then
        handle_tac_recycler(weaponsPlayer)
    end
    local weaponsEnemy = nil
    if pcall(function() weaponsEnemy = Hyperspace.ships.enemy.weaponSystem.weapons end) and weaponsEnemy then
        handle_tac_recycler(weaponsEnemy)
    end
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "RECYCLER_CORE" then
        projectile:Kill()
    end
end, INT_MAX)

-----------------------------
-- LIGHTWEIGHT PRE-IGNITER --
-----------------------------
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

----------------------------------------------------
-- TARGET PAINTER LASERS, TRANS BOMB, DE-ION BOMB --
----------------------------------------------------
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
        
        -- Reduce ionization for de-ionizer bomb
        if weaponName == "BOMB_ION_ANTI" then
            local impactSys = shipManager:GetSystemInRoom(shipManager.ship:GetSelectedRoomId(location.x, location.y, true))
            if impactSys and impactSys.iLockCount > 0 then
                impactSys.iLockCount = math.max(0, impactSys.iLockCount - 2)
                impactSys:ForceIncreasePower(math.min(2, impactSys:GetMaxPower() - impactSys:GetEffectivePower()))
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

---------------
-- EM JAMMER --
---------------
local emJamTimeShip = {}
emJamTimeShip[0] = 0
emJamTimeShip[1] = 0

local emJamIon = Hyperspace.Damage()
emJamIon.iIonDamage = 1

-- Apply shield and weapon cooldown debuffs
script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if emJamTimeShip[shipManager.iShipId] > 0 and (augName == "SHIELD_RECHARGE" or augName == "AUTO_COOLDOWN") then
        augValue = augValue - 0.5
    end
    return Defines.Chain.CONTINUE, augValue
end)

-- Tick down the debuff timers
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if emJamTimeShip[ship.iShipId] > 0 then
        emJamTimeShip[ship.iShipId] = math.max(0, emJamTimeShip[ship.iShipId] - Hyperspace.FPS.SpeedFactor/16)
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not Hyperspace.ships.player then emJamTimeShip[0] = 0 end
    if not Hyperspace.ships.enemy  then emJamTimeShip[1] = 0 end
end)

-- Set timer for debuffs and ion engines when jammer is fired
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "EM_JAMMER" then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((weapon.iShipId + 1)%2)
        if otherShip then
            emJamTimeShip[otherShip.iShipId] = 5
            local engineRoom = nil
            if pcall(function() engineRoom = otherShip:GetSystemRoom(1) end) and engineRoom then
                local engineRoomShape = Hyperspace.ShipGraph.GetShipInfo(otherShip.iShipId):GetRoomShape(engineRoom)
                otherShip:DamageArea(Hyperspace.Pointf(engineRoomShape.x + engineRoomShape.w/2, engineRoomShape.y + engineRoomShape.h/2), emJamIon, true)
            end
        end
        projectile:Kill()
    end
end, INT_MAX)

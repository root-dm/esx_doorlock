ESX = nil
local PlayerClub, PlayerRankNum = nil, 0

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while not ESX.GetPlayerData().job do
		Citizen.Wait(10)
	end

	ESX.PlayerData = ESX.GetPlayerData()

	-- Update the door list
	ESX.TriggerServerCallback('esx_doorlock:getDoorState', function(doorState)
		for index,state in pairs(doorState) do
			Config.DoorList[index].locked = state
		end
	end)

	ESX.TriggerServerCallback('sody_clubs:getPlayerClub', function(playerdata)
		PlayerClub = playerdata.club
		PlayerRankNum = playerdata.club_rank
	end)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx_doorlock:setDoorState')
AddEventHandler('esx_doorlock:setDoorState', function(index, state) Config.DoorList[index].locked = state end)


RegisterNetEvent('sody_clubs:clubAdded')
AddEventHandler('sody_clubs:clubAdded', function(club)
	ESX.TriggerServerCallback('sody_clubs:getPlayerClub', function(playerdata)
		PlayerClub = playerdata.club
		PlayerRankNum = playerdata.club_rank
	end)
end)

RegisterNetEvent('sody_clubs:clubRemoved')
AddEventHandler('sody_clubs:clubRemoved', function()
	PlayerClub, PlayerRankNum = nil, 0
end)

Citizen.CreateThread(function()
	while true do
		local playerCoords = GetEntityCoords(PlayerPedId())

		for k,v in ipairs(Config.DoorList) do
			v.isAuthorized = isAuthorized(v)

			if v.doors then
				for k2,v2 in ipairs(v.doors) do
					if v2.object and DoesEntityExist(v2.object) then
						if k2 == 1 then
							v.distanceToPlayer = #(playerCoords - GetEntityCoords(v2.object))
						end
					else
						v.distanceToPlayer = nil
						v2.object = GetClosestObjectOfType(v2.objCoords, 1.0, v2.objHash, false, false, false)
					end
				end
			else
				if v.object and DoesEntityExist(v.object) then
					v.distanceToPlayer = #(playerCoords - GetEntityCoords(v.object))
				else
					v.distanceToPlayer = nil
					v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
				end
			end
		end

		Citizen.Wait(500)
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local letSleep = true

		for k,v in ipairs(Config.DoorList) do
			if v.distanceToPlayer and v.distanceToPlayer < 50 then
				letSleep = false

				if v.doors then
					for k2,v2 in ipairs(v.doors) do
						FreezeEntityPosition(v2.object, v.locked)
					end
				else
					FreezeEntityPosition(v.object, v.locked)
				end
			end

			if v.distanceToPlayer and v.distanceToPlayer < v.maxDistance then
				local size, displayText = 1, _U('unlocked')

				if v.size then size = v.size end
				if v.locked then displayText = _U('locked') end
				if v.isAuthorized then displayText = _U('press_button', displayText) end

				ESX.Game.Utils.DrawText3D(v.textCoords, displayText, size)

				if IsControlJustReleased(0, 38) then
					if v.isAuthorized then
						v.locked = not v.locked
						TriggerServerEvent('esx_doorlock:updateState', k, v.locked, PlayerClub, PlayerRankNum) -- broadcast new state of the door to everyone
					end
				end
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)


function isAuthorized(door)
	if not ESX or not ESX.PlayerData.job then
		return false
	end

	for k,job in pairs(door.authorizedJobs) do
		if job == ESX.PlayerData.job.name then
			return true
		end
	end

	if door.authorizedClubs ~= nil then
		if PlayerClub ~= nil and PlayerRankNum ~= nil then
			for _,club in pairs(door.authorizedClubs) do
				if club == PlayerClub and door.authorizedClubRank[1] <= PlayerRankNum then
					return true
				end
			end
		end
	end

	return false
end

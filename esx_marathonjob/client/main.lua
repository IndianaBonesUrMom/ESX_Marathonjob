ESX = nil				
local playerData = {}	
Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(1)
	end
end)

math.randomseed(GetGameTimer())

local stopWatch = FiveWatch.new('marathon')

local taskPoints = {}	
local marathonBlips = {}
local MarathonTimes = {}
local onDuty = false	
local jobDone = false
local onMarathon = false	
local isInMarker = false
local menuIsOpen = false   
local currentZone = 'none'
	
local currentIndex = 1 
local lastRoute = 0

local zOffset = -0.65	
local hintToDisplay = "no hint bru"			
local displayHint = false																			
local currentPlate = ''
								

chat = function(clr, msg) TriggerEvent('chatMessage', "", {255, 0, 0}, "^8>> ^" .. clr .. tostring(msg)) end

function sizeOfTable (tab)
  local count = 0
  for k, v in pairs(tab) do
    count = count + 1
  end
  return count
end

function elementAt(tab, indx)
 
  local count = 0
  local ret = nil
  for k, v in pairs(tab) do
    count = count + 1
	if count == indx then
	ret = v
	break
	end
  end
  return ret
end


function table.clone(org)
  return {table.unpack(org)}
end


function msToClock(seconds)
  local seconds = tonumber(seconds / 1000)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs
  end
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)		
    playerData = xPlayer								
    refreshBlips()										
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)	
  playerData.job = job						
  onDuty = false							
  deleteBlips()								
  refreshBlips()							
end)

AddEventHandler('esx_marathonjob:celebrate', function()
	Citizen.CreateThread(function()
	  TaskStartScenarioInPlace(GetPlayerPed(-1), Config.celebrationScenario, 0, false)
	  stopWatch:StartTimer('celebrate')
	  repeat
		Citizen.Wait(500)
	  until stopWatch:GetTime('celebrate') > Config.celebrationTime
	  stopWatch:RemoveTime('celebrate')
	  ClearPedTasks(GetPlayerPed(-1))
	end)
end)

AddEventHandler('esx_marathonjob:grieve', function()
	Citizen.CreateThread(function()
	  RequestAnimDict(Config.failAnimDict) 
	  while not HasAnimDictLoaded(Config.failAnimDict) do
	    Citizen.Wait(100)
	  end
	  TaskPlayAnim(GetPlayerPed(-1), Config.failAnimDict , Config.failAnim ,8.0, -8.0, -1, 0, 0, false, false, false )
	end)
end)

AddEventHandler('esx_marathonjob:ragequit', function()
	Citizen.CreateThread(function()
	  RequestAnimDict(Config.quitAnimDict) 
	  while not HasAnimDictLoaded(Config.quitAnimDict) do
	    Citizen.Wait(100)
	  end
	  TaskPlayAnim(GetPlayerPed(-1), Config.quitAnimDict , Config.quitAnim,8.0, -8.0, -1, 0, 0, false, false, false )
	end)
end)

function drawBlip(coords, icon, text)

  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)	
  
  SetBlipSprite (blip, icon)		
  SetBlipDisplay(blip, 4)			
  SetBlipScale  (blip, 0.9)			
  SetBlipColour (blip, 4)			
  SetBlipAsShortRange(blip, true)	
	
  BeginTextCommandSetBlipName("STRING")	
  AddTextComponentString(text)		
  EndTextCommandSetBlipName(blip)	
  table.insert(marathonBlips, blip)	

end

function refreshBlips()
	if playerData.job.name ~= nil and playerData.job.name == 'runner' then 
		drawBlip(Config.locker, 366, "Maratoonarin pukukoppi")					
		drawBlip(Config.carSpawn, 126, "Ilmoittautuminen")					
		drawBlip(Config.carDel, 430, "Palkintojen jako")					
	end
end

function deleteBlips()
  if marathonBlips[1] ~= nil then 	
    for i = 1, #marathonBlips, 1 do	
      RemoveBlip(marathonBlips[i])	
      marathonBlips[i] = nil		
    end
  end
end


Citizen.CreateThread(function()
  while true do										
    Citizen.Wait(1)
    if displayHint then							
      SetTextComponentFormat("STRING")				
      AddTextComponentString(hintToDisplay)			
      DisplayHelpTextFromStringLabel(0, 0, 1, -1)	
    end
  end
end)


function displayMarker(coords) 
	DrawMarker(4, coords.x, coords.y, coords.z + 0.15, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 25, 155, false, true, 2, false, false, false, false) 
end


function startWork(flag)
	local playerPed = GetPlayerPed(-1)
	if not IsPedInAnyVehicle(playerPed) then 
		updateCurrentIndex()								
		if elementAt(taskPoints, currentIndex) == nil then
			ESX.ShowNotification('~w~Juoksit maratonin ~w~ajassa ~y~' .. msToClock(stopWatch:SaveTime('lap')))
			chat("6", "Aika: ^4" .. msToClock(stopWatch:GetSavedTime('lap')))
			jobDone = true
			setGps(Config.carDel)
			TriggerEvent('esx:showNotification', "Lunasta ~b~palkintosi ~w~ palkintojenjaosta.")
		else
			if flag then
				ESX.ShowNotification('~w~Väliaika: ~b~' .. msToClock(stopWatch:GetTime('lap')))
				TriggerServerEvent('esx_marathonjob:onWaypoint')
			end
			setGps(elementAt(taskPoints, currentIndex))	
		end
	else
		ESX.ShowNotification('~r~Miksi olet autossa?')	
	end
end

function giveWork()
	currentIndex = 1													
	jobDone = false
	onMarathon = true
	local route = 1
	
	lastRoute = route
	
	taskPoints = table.clone(Config.Routes[route].track)
	
	ESX.ShowNotification("Osallistumismaksu ~r~" .. Config.caution .. "~g~ € ~w~otettiin sinulta.")
	TriggerServerEvent('esx_marathonjob:getPunished', Config.caution)
	setGps(elementAt(taskPoints, currentIndex))									     
	ESX.ShowNotification("~w~Kun olet valmis, siirry~b~ lähtöviivalle~w~.") --alert player
end

function getPayAmount()
	
	local amount = Config.Routes[lastRoute].rewards.fail
	
	local trackinfo = getTrackinfo(lastRoute)
	
	if stopWatch:GetSavedTime('lap') < trackinfo.gold then
		amount = Config.Routes[lastRoute].rewards.gold
		TriggerServerEvent('esx_marathonjob:onRecord', lastRoute, stopWatch:GetSavedTime('lap'))
		TriggerServerEvent('esx_marathonjob:giveAward', 'goldmedal_run')
		ESX.ShowNotification('~w~Sait ~y~kultamitalin!')
		TriggerEvent('esx_marathonjob:celebrate')
	elseif stopWatch:GetSavedTime('lap') < trackinfo.silver then
		amount = Config.Routes[lastRoute].rewards.silver
		TriggerServerEvent('esx_marathonjob:giveAward', 'silvermedal_run')
		ESX.ShowNotification('~w~Sait ~y~hopeamitalin!')
		TriggerEvent('esx_marathonjob:celebrate')
	elseif stopWatch:GetSavedTime('lap') < trackinfo.bronze then
		amount = Config.Routes[lastRoute].rewards.bronze
		TriggerServerEvent('esx_marathonjob:giveAward', 'bronzemedal_run')
		ESX.ShowNotification('~w~Sait ~y~pronssimitalin!')
		TriggerEvent('esx_marathonjob:celebrate')
	else
		TriggerEvent('esx_marathonjob:grieve')
	end
	
	ESX.ShowNotification('~w~Tienasit ~b~' .. amount)
	amount = amount + Config.caution
	TriggerServerEvent('esx_marathonjob:getPaid', amount)
	
	stopWatch:RemoveTime('lap')
end 


function disqualify(reason)
	onDuty = false
	onMarathon = false
	jobDone = false											
	setGps(0)										
	taskPoints = {}
	ESX.ShowNotification('Sinut ~r~diskattu ~y~kilpailusta~r~! ~w~Syy: ~b~' .. reason)
	TriggerEvent('esx_marathonjob:ragequit')
end

function getPaid()
	
	if onMarathon and jobDone then
		getPayAmount()											
	else
		TriggerEvent('esx_marathonjob:ragequit')
		ESX.ShowNotification('Osallistumismaksua ~r~ei ~w~palauteta')
	end									
	jobDone = false
	onMarathon = false
	setGps(0)										
	taskPoints = {}											
end

function updateCurrentIndex()
	currentIndex = currentIndex + 1
end

Citizen.CreateThread(function()
	while true do
		if onDuty and onMarathon then 
			if IsPedInAnyVehicle(GetPlayerPed(-1)) then
				disqualify('Ajoneuvon käyttö kilpailussa.')
				Citizen.Wait(500)
			elseif GetEntitySpeed(GetPlayerPed(-1)) > Config.speedLimit then
				disqualify('Yliluonnollinen nopeus.')
				Citizen.Wait(500)
			end
		end
		Citizen.Wait(100)
	end
end)

function setGps(coords)
	if marathonBlips['marathon'] ~= nil then 	
		RemoveBlip(marathonBlips['marathon'])	
		marathonBlips['marathon'] = nil			
	end
	if coords ~= 0 then
		marathonBlips['marathon'] = AddBlipForCoord(coords.x, coords.y, coords.z)	
		SetBlipRoute(marathonBlips['marathon'], true)									
	end
end

function isInside(playerCoords, coords, distance) 
	return GetDistanceBetweenCoords(playerCoords, coords.x, coords.y, coords.z, true) < distance			
end

function taskTrigger(zone)					--WHY THE FUCK LUA DOESN'T HAVE SWITCH ??? @ WUT
	if zone == 'locker' then				
		openMenu()
	elseif zone == 'start' then				
		giveWork()
	elseif zone == 'pay' then				
		getPaid()
	end
end

function getTrackinfo(lastRoute)
	for i = 1, #MarathonTimes, 1 do
		if MarathonTimes[i].track == lastRoute then
			return {bronze = math.floor(MarathonTimes[i].laptime * Config.bronze), silver = math.floor(MarathonTimes[i].laptime * Config.silver), gold = MarathonTimes[i].laptime, runner = MarathonTimes[i].runner}
		end
	end
	return {bronze = 9060100, silver = 9051000, gold = 9000000, runner = "Hemuli Harjula"} --default time should be quite high
end

Citizen.CreateThread(function()
	while true do
		if onDuty and onMarathon and elementAt(taskPoints, currentIndex) ~= nil then
			local pCoords = GetEntityCoords(GetPlayerPed(-1))
			if currentIndex == 1 and isInside(pCoords, elementAt(taskPoints, currentIndex), 0.9) then
				
				FreezeEntityPosition(GetPlayerPed(-1), true)
				ESX.ShowNotification('~w~Kilpailu ~g~alkaa~w~...')
				startWork(false)
				
				ESX.TriggerServerCallback('esx_marathonjob:getTimes', function(times)
					MarathonTimes = times
					local trackinfo = getTrackinfo(lastRoute)
					chat("7", "Reitti ^5::[ ^9" .. Config.Routes[lastRoute].name .. "^5 ]:: ^4pronssi: ^3" .. msToClock(trackinfo.bronze) .. " ^0|^4 Hopea: ^3" .. msToClock(trackinfo.silver) .. " ^0| ^4Kulta: ^3" .. msToClock(trackinfo.gold))
					chat("7", "Kultaa juossut ^3@^9" .. trackinfo.runner)
					Citizen.Wait(3000)
					ESX.ShowNotification('~r~3~w~...')
					Citizen.Wait(1000)
					ESX.ShowNotification('~y~2~w~...')
					Citizen.Wait(1000)
					ESX.ShowNotification('~g~1~w~...')
					Citizen.Wait(1000)
					FreezeEntityPosition(GetPlayerPed(-1), false)
					ESX.ShowNotification('~g~JUOKSE~r~!~y~!~w~!')
					stopWatch:StartTimer('lap')
				end)
				
			elseif currentIndex ~= 1 and isInside(pCoords, elementAt(taskPoints, currentIndex), 4.95) then
				startWork(true)
				Citizen.Wait(500)
			end
		end
		Citizen.Wait(50)
	end
end)


Citizen.CreateThread(function()
	while true do																
		Citizen.Wait(2)																
	
		if not menuIsOpen then
			
			local pCoords = GetEntityCoords(GetPlayerPed(-1))
			
			if playerData.job ~= nil and playerData.job.name == "runner" and isInside(pCoords, Config.locker, 1.5) then 			
				isInMarker = true
				displayHint = true																
				hintToDisplay = "Paina E vaihtaaksesi vaatteita"								
				currentZone = 'locker'																
			elseif onDuty and elementAt(taskPoints, currentIndex) == nil and isInside(pCoords, Config.carSpawn, 1.5) then
				isInMarker = true
				displayHint = true
				hintToDisplay = "Paina E ilmoittautuaksesi kilpailuun"
				currentZone = 'start'
			elseif playerData.job ~= nil and playerData.job.name == "runner" and onMarathon and isInside(pCoords, Config.carDel, 2.5) then  				
				isInMarker = true
				displayHint = true
				hintToDisplay = "Paina E lunastaaksesi palkinto"
				currentZone = 'pay'
			else																				
				isInMarker = false
				displayHint = false
				hintToDisplay = "No hint to display"
				currentZone = 'none'
			end
		
			if IsControlJustReleased(0, 38) and isInMarker then
				taskTrigger(currentZone)														
				Citizen.Wait(500)
			end
			
		end
	end
end)


Citizen.CreateThread(function()
	while true do																		
		Citizen.Wait(1)
		local pCoords = GetEntityCoords(GetPlayerPed(-1))
		
		if playerData.job ~= nil and playerData.job.name == "runner" and isInside(pCoords, Config.locker, 100)  then 				
			displayMarker(Config.locker)
		end
		if onDuty and elementAt(taskPoints,currentIndex) == nil and not onMarathon and isInside(pCoords, Config.carSpawn, 100) then			
			displayMarker(Config.carSpawn)
		end
		if onDuty and elementAt(taskPoints,currentIndex) ~= nil and isInside(pCoords, elementAt(taskPoints, currentIndex), 100) then 	
			displayMarker(elementAt(taskPoints, currentIndex))
		end
		if playerData.job ~= nil and playerData.job.name == "runner" and onDuty and onMarathon and isInside(pCoords, Config.carDel, 100) then  		
			displayMarker(Config.carDel)
		end																			
	end
end)

function openMenu()									
 
  menuIsOpen = true
  
  ESX.UI.Menu.CloseAll()									

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'locker',		
    {
      title    = "Maratoonarin pukukoppi",							
      elements = {
        {label = "Työvaatteet", value = 'marathon_wear'},		
        {label = "Arkivaatteet", value = 'everyday_wear'}	
      }
    },
    function(data, menu)									
      if data.current.value == 'everyday_wear' then			
        onDuty = false										
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)	
            TriggerEvent('skinchanger:loadSkin', skin)					
        end)
      end
      if data.current.value == 'marathon_wear' then
        onDuty = true
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
          if skin.sex == 0 then
              TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
          else
              TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
          end
        end)
      end
      menu.close()											
	  menuIsOpen = false
    end,
    function(data, menu)
      menu.close()
	  menuIsOpen = false
    end
  )
end


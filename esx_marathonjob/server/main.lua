ESX = nil
MarathonTimes = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

AddEventHandler('onMySQLReady', function()
	MySQL.Async.fetchAll(	
	'SELECT * FROM marathon_times WHERE 1',
    {},
    function (result)								
      for i = 1, #result, 1 do
        table.insert(MarathonTimes, result[i])
      end
    end)
end)


ESX.RegisterServerCallback('esx_marathonjob:getTimes', function(source, cb, gang)
	cb(MarathonTimes)
end)

RegisterServerEvent('esx_marathonjob:onRecord')
AddEventHandler('esx_marathonjob:onRecord', function(track, laptime)						
	
	local _track = track
	local _laptime = laptime
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local _runner = GetPlayerName(_source)
	
	Citizen.Trace("Track record on track " .. _track .. ", name :" .. GetPlayerName(source) .. " laptime: " .. _laptime .. "\n")
	
	local found = false
	local record = false
	
	for i = 1, #MarathonTimes, 1 do
		if MarathonTimes[i].track == _track then
			found = true
			if MarathonTimes[i].laptime > _laptime then
				record = true
				MarathonTimes[i].laptime = _laptime
				MarathonTimes[i].runner = _runner
			end
			break
		end
	end
	
	if not found then
		table.insert(MarathonTimes, {id = -1, track = _track, runner = _runner, laptime = _laptime})
		xPlayer.addMoney(11000)
		TriggerClientEvent('esx:showNotification', _source, '~g~Uusi ~w~ennätys~y~!!!~g~+~y~5000~g~€ ~w~bonus!')
		Citizen.Trace("Lap record inserted!\n")
		MySQL.Async.execute(
		'INSERT INTO `marathon_times` (`track`, `runner`, `laptime`) VALUES (@track, @runner, @laptime)',
		{
			['@track']   = _track,
			['@runner'] = _runner,
			['@laptime'] = _laptime
		})	
	elseif found and record then
		table.insert(MarathonTimes, {id = -1 , track = _track, runner = _runner, laptime = _laptime})
		xPlayer.addMoney(11000)
		TriggerClientEvent('esx:showNotification', _source, '~g~Rikoit~w~ rataennätyksen! ~g~+~w~5000~g~€ ~w~bonus!')
		Citizen.Trace("Lap record updated!\n")
		MySQL.Async.execute(
		'UPDATE `marathon_times` SET laptime = @laptime, runner = @runner WHERE track = @track',
		{
			['@laptime']   = _laptime,
			['@runner'] = _runner,
			['@track'] = _track
		})
	else
		TriggerClientEvent('esx:showNotification', _source, '~w~Valitettavasti ratennätyksesi ~r~rikottiin ~w~kotimatkallasi!')
	end
end)

RegisterServerEvent('esx_marathonjob:getPaid')
AddEventHandler('esx_marathonjob:getPaid', function(amount)						
	local xPlayer = ESX.GetPlayerFromId(source)					
	xPlayer.addMoney(math.floor(amount))
end)

RegisterServerEvent('esx_marathonjob:getPunished')
AddEventHandler('esx_marathonjob:getPunished', function(amount)					
	local xPlayer = ESX.GetPlayerFromId(source)		
	xPlayer.removeMoney(math.floor(amount)) 
end)

RegisterServerEvent('esx_marathonjob:giveAward')
AddEventHandler('esx_marathonjob:giveAward', function(award)					
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.addInventoryItem(award, 1)
end)

RegisterServerEvent('esx_marathonjob:onWaypoint')
AddEventHandler('esx_marathonjob:onWaypoint', function()					
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.addInventoryItem('bread', 1)
	xPlayer.addInventoryItem('water', 1)
end)



script.on_event(defines.events.on_built_entity, function(event)
  if (event.created_entity.name == "dynamic-train-stop") then
    addDTSToTable(event.created_entity)
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
  if (event.created_entity.name == "dynamic-train-stop") then
    addDTSToTable(event.created_entity)
  end
end)

script.on_event(defines.events.on_preplayer_mined_item, function(event)
  removeDynamicStation(event.entity)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
  removeDynamicStation(event.entity)
end)

script.on_event(defines.events.on_entity_died, function(event)
  removeDynamicStation(event.entity)
end)

		
script.on_init(function()
  onLoad()
end)

script.on_event(defines.events.on_tick, function(event)
    for i, dynamic_station in ipairs(dynamic_stations) do
     updateDynamicStation(dynamic_station)
   end   
end)

script.on_load(function()
  onLoad()
end)

function onLoad()
  if not global.dynamicStations then
    global.dynamicStations = {}
  end
  dynamic_stations = global.dynamicStations
end

function addDTSToTable(entity)
  table.insert(dynamic_stations, entity)
end

function removeDynamicStation(entity)
	for i, dynamic_station in ipairs(dynamic_stations) do
		if notNil(dynamic_station, "position") then
			if dynamic_station.position.x == entity.position.x and dynamic_station.position.y == entity.position.y then
				table.remove(dynamic_stations, i)
				break
			end
		end
	end
end

function updateDynamicStation(entity)
	stationNewName = ""
	stationName = string.match(entity.backer_name, '.+|')
	stationFlag = ""
	colors = 
		{
			{color = "Black", value = 0, signal_name = "signal-black"},
			{color = "Grey", value = 0, signal_name = "signal-grey"},
			{color = "White", value = 0, signal_name = "signal-white"},
			{color = "Cyan", value = 0, signal_name = "signal-cyan"},
			{color = "Pink", value = 0, signal_name = "signal-pink"},
			{color = "Yellow", value = 0, signal_name = "signal-yellow"},
			{color = "Blue", value = 0, signal_name = "signal-blue"},
			{color = "Green", value = 0, signal_name = "signal-green"},
			{color = "Red", value = 0, signal_name  = "signal-red"}
		}
	if stationName ~= nil
	then
		redTotal = 0
		greenTotal = 0
		redNet = entity.get_circuit_network(defines.wire_type.red)
		greenNet = entity.get_circuit_network(defines.wire_type.green)
		if redNet ~= nil
		then
			for i, signal in ipairs(colors) do 
				signal.value = redNet.get_signal({type = "virtual", name = signal.signal_name})
			
			end
		end
		if greenNet ~= nil
		then
			for i, signal in ipairs(colors) do 
				signal.value = signal.value + greenNet.get_signal({type = "virtual", name = signal.signal_name})
			end
		end	
		stationNewName = stationName
		for i, signal in ipairs(colors) do
			if signal.value > 0
			then
				stationFlag = signal.color
			end
		end
		stationNewName = stationName .. stationFlag
		if stationNewName ~= entity.backer_name
			then
			renameDynamicStation(entity, stationNewName)
		end
	end
end

function renameDynamicStation(entity, stationNewName)
	stationName = entity.name
	stationPosition = entity.position
	stationDirection = entity.direction
	stationForce = entity.force
	stationCircuits = entity.circuit_connection_definitions
	removeDynamicStation(entity)
	entity.destroy()
	newStation = game.surfaces[1].create_entity{name = stationName, position = stationPosition, direction = stationDirection, force = stationForce}
	for i, wire in ipairs(stationCircuits) do
		newStation.connect_neighbour(wire)
	end
	addDTSToTable(newStation)
	newStation.backer_name = stationNewName
end

function notNil(class, var)
	value = false
	pcall (function()
		if class[var] then
			value = true
		end
	end)
	return value
end


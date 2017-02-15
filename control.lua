script.on_event(defines.events.on_built_entity, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.created_entity)
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.created_entity)
  end
end)

script.on_event(defines.events.on_preplayer_mined_item, function(event)
  removeStringyStation(event.entity)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
  removeStringyStation(event.entity)
end)

script.on_event(defines.events.on_entity_died, function(event)
  removeStringyStation(event.entity)
end)


script.on_init(function()
  onLoad()
end)

script.on_event(defines.events.on_tick, function(event)
    for i, stringy_station in ipairs(stringy_stations) do
     updateStringyStation(stringy_station)
   end
end)

script.on_load(function()
  onLoad()
end)

function onLoad()
  if not global.stringyStations then
    global.stringyStations = {}
  end
  stringy_stations = global.stringyStations
end

function addDTSToTable(entity)
  table.insert(stringy_stations, entity)
end

function removeStringyStation(entity)
	for i, stringy_station in ipairs(stringy_stations) do
		if notNil(stringy_station, "position") then
			if stringy_station.position.x == entity.position.x and stringy_station.position.y == entity.position.y then
				table.remove(stringy_stations, i)
				break
			end
		end
	end
end

function updateStringyStation(entity)
	local stationNewName = string.match(entity.backer_name, '.*|')
	if stationNewName ~= nil	then
		local net = entity.get_circuit_network(defines.wire_type.red) or entity.get_circuit_network(defines.wire_type.green)

    --TODO: fetch both and combine them? would kill performance...

    if net then
      local string = remote.call('signalstrings','signals_to_string',net.signals)
  		stationNewName = stationNewName .. string
    end

		if stationNewName ~= entity.backer_name
			then
			renameStringyStation(entity, stationNewName)
		end
	end
end

function renameStringyStation(entity, stationNewName)
	stationName = entity.name
	stationPosition = entity.position
	stationDirection = entity.direction
	stationForce = entity.force
	stationCircuits = entity.circuit_connection_definitions
	removeStringyStation(entity)
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

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

script.on_event(defines.events.on_pre_player_mined_item, function(event)
  removeStringyStation(event.entity)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
  removeStringyStation(event.entity)
end)

script.on_event(defines.events.on_entity_died, function(event)
  removeStringyStation(event.entity)
end)


script.on_init(function()
  global = {
    stringyStations = {},
    schedules = {},
  }
  onLoad()
end)

script.on_configuration_changed(function(event)
  if not global.stringyStations then
    global.stringyStations = {}
  end
  if not global.schedules then
    global.schedules = {}
  end
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
  stringy_stations = global.stringyStations
  schedules = global.schedules
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
  local net = entity.get_circuit_network(defines.wire_type.red) or entity.get_circuit_network(defines.wire_type.green)
  --TODO: fetch both and combine them? would kill performance...

  if net and net.signals and #net.signals > 0 then
    -- use *vanilla* train stop signal
    if net.get_signal({name="signal-stopname",type="virtual"}) == 1 then
      -- rename station
      local string = remote.call('signalstrings','signals_to_string',net.signals)
      if string ~= entity.backer_name then
  			renameStringyStation(entity, string)
  		end
      return
    end
    local sigsched = net.get_signal({name="signal-schedule",type="virtual"})
    if sigsched > 0 then
      -- build schedule
      if not global.schedules then global.schedules = {} schedules = global.schedules end
      if not schedules[entity.unit_number] then schedules[entity.unit_number] = {} end

      local string = remote.call('signalstrings','signals_to_string',net.signals)
      if string == "" then return end
      schedules[entity.unit_number][sigsched] = {station=string}

      local sigwaitt = net.get_signal({name="signal-wait-time",type="virtual"})
      if sigwaitt > 0 then
        schedules[entity.unit_number][sigsched].wait_conditions = {{
          type="time",
          compare_type="and",
          ticks = sigwaitt
        }}
        return
      end
      local sigwaiti = net.get_signal({name="signal-wait-inactivity",type="virtual"})
      if sigwaiti > 0 then
        schedules[entity.unit_number][sigsched].wait_conditions = {{
          type="inactivity",
          compare_type="and",
          ticks = sigwaiti
        }}
        return
      end
      local sigwaite = net.get_signal({name="signal-wait-empty",type="virtual"})
      if sigwaite > 0 then
        schedules[entity.unit_number][sigsched].wait_conditions = {{
          type="empty",
          compare_type="and",
        }}
        return
      end
      local sigwaitf = net.get_signal({name="signal-wait-full",type="virtual"})
      if sigwaitf > 0 then
        schedules[entity.unit_number][sigsched].wait_conditions = {{
          type="full",
          compare_type="and",
        }}
        return
      end
      local sigwaitc = net.get_signal({name="signal-wait-circuit",type="virtual"})
      if sigwaitc > 0 then
        schedules[entity.unit_number][sigsched].wait_conditions = {{
          type="circuit",
          compare_type="and",
          condition = { first_signal = {name="signal-black",type="virtual"}, comparator = "≠" }
        }}
        return
      end
    elseif sigsched == -1 then
      -- set schedule, send to first
      for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
        if train.train.state == defines.train_state.wait_station and train.train.station == entity then

          --game.print(serpent.block({ current = 1, records = schedules[entity.unit_number]}))
          train.train.manual_mode = true
          train.train.schedule = { current = 1, records = schedules[entity.unit_number]}
          train.train.manual_mode = false
          schedules[entity.unit_number] = {}
        end
      end
      return
    end
    if net.get_signal({name="signal-goto",type="virtual"}) ~= 0 then
      -- send train to named station
      for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
        if train.train.state == defines.train_state.wait_station and train.train.station == entity then
          local string = remote.call('signalstrings','signals_to_string',net.signals)

          train.train.manual_mode = true
          train.train.schedule = { current = 1, records = {{station=string}}}
          train.train.manual_mode = false
        end
      end
      return
    end
  end
end

function renameStringyStation(entity, stationNewName)
	stationName = entity.name
	stationPosition = entity.position
	stationDirection = entity.direction
	stationForce = entity.force
	stationCircuits = entity.circuit_connection_definitions

	stationControlBehavior = entity.get_control_behavior()

	stationSendToTrain = stationControlBehavior.send_to_train
	stationReadFromTrain = stationControlBehavior.read_from_train
	stationReadStoppedTrain = stationControlBehavior.read_stopped_train
	stationEnableDisable = stationControlBehavior.enable_disable
	stationStoppedTrainSignal = stationControlBehavior.stopped_train_signal
	stationCircuitCondition = stationControlBehavior.circuit_condition

	removeStringyStation(entity)
	entity.destroy()
	newStation = game.surfaces[1].create_entity{name = stationName, position = stationPosition, direction = stationDirection, force = stationForce}
	for i, wire in ipairs(stationCircuits) do
		newStation.connect_neighbour(wire)
	end

	newStationControlBehavior = newStation.get_control_behavior()

	newStationControlBehavior.send_to_train = stationSendToTrain
	newStationControlBehavior.read_from_train = stationReadFromTrain
	newStationControlBehavior.read_stopped_train = stationReadStoppedTrain
	newStationControlBehavior.enable_disable = stationEnableDisable
	newStationControlBehavior.stopped_train_signal = stationStoppedTrainSignal
	newStationControlBehavior.circuit_condition = stationCircuitCondition

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

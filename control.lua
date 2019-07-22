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

function get_signal_from_set(signal,set)
  for _,sig in pairs(set) do
    if sig.signal.type == signal.type and sig.signal.name == signal.name then
      return sig.count
    end
  end
  return nil
end

function parseScheduleEntry(signals,surface)
  local schedule = {wait_conditions = {}}

  local userail = get_signal_from_set({name="rail",type="item"},signals) or 0
  if userail ~= 0 then 
    local x = get_signal_from_set({name="signal-X",type="virtual"},signals) or 0
    local y = get_signal_from_set({name="signal-Y",type="virtual"},signals) or 0

    x = x - (x % 2)
    y = y - (y % 2)

    if surface and surface.valid then
      local rails = surface.find_entities_filtered{type={"straight-rail","curved-rail"},area={{x,y},{x+1,y+1}}}
      if rails and rails[1] then
        schedule.rail = rails[1]
      else
        -- list as "Invalid"
        schedule.station = ""
      end
    else
      -- list as "Invalid"
      schedule.station = ""
    end  
  else
    local string = remote.call('signalstrings','signals_to_string',signals)
    schedule.station = string
  end


  local sigwaitt = get_signal_from_set({name="signal-wait-time",type="virtual"},signals) or 0
  if sigwaitt > 0 then
    table.insert(schedule.wait_conditions, {
      type="time",
      compare_type="and",
      ticks = sigwaitt
    })
  end
  local sigwaiti = get_signal_from_set({name="signal-wait-inactivity",type="virtual"},signals) or 0
  if sigwaiti > 0 then
    table.insert(schedule.wait_conditions, {
      type="inactivity",
      compare_type="and",
      ticks = sigwaiti
    })
  end
  local sigwaite = get_signal_from_set({name="signal-wait-empty",type="virtual"},signals) or 0
  if sigwaite > 0 then
    table.insert(schedule.wait_conditions, {
      type="empty",
      compare_type="and",
    })
  end
  local sigwaitf = get_signal_from_set({name="signal-wait-full",type="virtual"},signals) or 0
  if sigwaitf > 0 then
    table.insert(schedule.wait_conditions, {
      type="full",
      compare_type="and",
    })
  end
  local sigwaitc = get_signal_from_set({name="signal-wait-circuit",type="virtual"},signals) or 0
  if sigwaitc > 0 then
    table.insert(schedule.wait_conditions, {
      type="circuit",
      compare_type="and",
      condition = { first_signal = {name="signal-black",type="virtual"}, comparator = "≠" }
    })
  end
  local sigwaitp = get_signal_from_set({name="signal-wait-passenger",type="virtual"},signals) or 0
  if sigwaitp > 0 then
    table.insert(schedule.wait_conditions, {
      type="passenger_present",
      compare_type="and",
    })
  elseif sigwaitp < 0 then
    table.insert(schedule.wait_conditions, {
      type="passenger_not_present",
      compare_type="and",
    })
  end
  return schedule
end

function updateStringyStation(entity)
  local signals = entity.get_merged_signals()

  if signals and #signals > 0 then
    if (get_signal_from_set({name="signal-stopname",type="virtual"},signals) or 0) == 1 then
      -- rename station
      local string = remote.call('signalstrings','signals_to_string',signals)
      if string ~= entity.backer_name then
  			renameStringyStation(entity, string)
  		end
      return
    end
    local sigsched = get_signal_from_set({name="signal-schedule",type="virtual"},signals) or 0
    if sigsched > 0 then
      -- build schedule
      if not global.schedules then global.schedules = {} end
      if not global.schedules[entity.unit_number] then global.schedules[entity.unit_number] = {} end

      local schedule = parseScheduleEntry(signals,entity.surface)

      if schedule.name == "" then
        global.schedules[entity.unit_number][sigsched] = {}
      else
        global.schedules[entity.unit_number][sigsched] = schedule
      end

      return
    elseif sigsched == -1 then
      -- set schedule, send to first
      for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
        if train.train.state == defines.train_state.wait_station and train.train.station == entity then

          --game.print(serpent.block({ current = 1, records = schedules[entity.unit_number]}))
          train.train.manual_mode = true
          train.train.schedule = { current = 1, records = global.schedules[entity.unit_number]}
          train.train.manual_mode = false
          global.schedules[entity.unit_number] = {}
        end
      end
      return
    end
    if (get_signal_from_set({name="signal-goto",type="virtual"},signals) or 0) ~= 0 then
      -- send train to named station
      for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
        if train.train.state == defines.train_state.wait_station and train.train.station == entity then
          local string = remote.call('signalstrings','signals_to_string',signals)

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

remote.add_interface("stringy-train-stop",{
  parseScheduleEntry = parseScheduleEntry
})

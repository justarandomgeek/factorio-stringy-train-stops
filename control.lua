local knownsignals = {
  parseSchedule = {
    richtext = {name="signal-stopname-richtext",type="virtual"},
    schedulerail = {name="signal-schedule-rail",type="virtual"},
    X = {name="signal-X",type="virtual"},
    Y = {name="signal-Y",type="virtual"},
    
    wait_time = {name="signal-wait-time",type="virtual"},
    wait_inactivity = {name="signal-wait-inactivity",type="virtual"},
    wait_empty = {name="signal-wait-empty",type="virtual"},
    wait_full = {name="signal-wait-full",type="virtual"},
    wait_passenger = {name="signal-wait-passenger",type="virtual"},
    wait_circuit = {name="signal-wait-circuit",type="virtual"},
    wait_robots = {name="signal-wait-robots",type="virtual"},

    info = {name="signal-info",type="virtual"},
  },
  updateStation = {
    richtext = {name="signal-stopname-richtext",type="virtual"},
    schedule = {name="signal-schedule",type="virtual"},
    stopname = {name="signal-stopname",type="virtual"},
    go = {name="signal-goto",type="virtual"},
  }
}

local events = {
  on_renamed_station = script.generate_event_name(),
}

local function get_signals_filtered(filters,signals)
  --   filters = {
  --  SignalID,
  --  }
  local results = {}
  local numfilters = table_size(filters)
  local count = 0
  for _,sig in pairs(signals) do
    for i,f in pairs(filters) do
      if f.name and sig.signal.type == f.type and sig.signal.name == f.name then
        results[i] = sig.count
        count = count + 1
        if count == numfilters then return results end
      end
    end
  end
  return results
end

-- signal-info used to report errors
-- 0000|0000|0000|0000||0000|0000|0000|0000
--     |    |    |    ||    |    |xxxx|xxxx number of omitted wait conditions
--     |    |    |   1||    |    |    |     contains item_count wait condition
--     |    |    |  1 ||    |    |    |     contains fluid_count wait condition
--     |    |    | 1  ||    |    |    |     contains circuit wait condition other than black!=0
--     |    |    |1   ||    |    |    |     contains contradictory passenger conditions
--     |   1|    |    ||    |    |    |     contains "OR" conditions

local function reportScheduleEntry(schedule)
  local outsignals = {}
  if schedule.rail then
    local position = schedule.rail.position
    outsignals[#outsignals+1]={index=#outsignals+1,count=position.x,signal=knownsignals.parseSchedule.X}
    outsignals[#outsignals+1]={index=#outsignals+1,count=position.y,signal=knownsignals.parseSchedule.Y}
  elseif schedule.station then
    outsignals = remote.call('signalstrings','string_to_signals', schedule.station)
  end
  local waits = {}
  local waittype = {
    -- no arguments
    full = function() waits.wait_full = 1 end,
    empty = function() waits.wait_empty = 1 end,
    robots_inactive = function() waits.wait_robots = 1 end,
  
    -- value is time in ticks
    time = function(wait) waits.wait_time = wait.ticks end,
    inactivity = function(wait) waits.wait_inactivity = wait.ticks end,
    
    -- no signal for these, report as info
    item_count = function(wait)
      wait.info = bit32.bor((wait.info or 0)+1, 0x10000)
    end,
    fluid_count = function(wait)
      wait.info = bit32.bor((wait.info or 0)+1, 0x20000)
    end,
  
    -- no signal format for circuit conditions except black!=0, report those as an error bit on info too
    circuit = function(wait)
      local condition = wait.condition
      if condition.first_signal and condition.first_signal.name == "signal-black" and 
          condition.comparator == "≠" and 
          not condition.second_signal and condition.constant == 0 then
        waits.wait_circuit = 1
      else
        wait.info = bit32.bor((wait.info or 0)+1, 0x40000)
      end
    end,
  
    -- these share a signal, set an info bit if both present.
    passenger_present = function(wait)
      if not waits.wait_passenger then
        waits.wait_passenger = 1
      elseif waits.wait_passenger == -1 then
        wait.info = bit32.bor((wait.info or 0)+1, 0x80000)
      end
    end,
    passenger_not_present = function(wait)
      if not waits.wait_passenger then
        waits.wait_passenger = -1
      elseif waits.wait_passenger == 1 then
        wait.info = bit32.bor((wait.info or 0)+1, 0x80000)
      end
    end,
  }
  for i,wait in pairs(schedule.wait_conditions) do
    if wait.compare_type == "or" then 
      wait.info = bit32.bor((wait.info or 0)+1+(#wait - i), 0x01000000)
      break
    else
      waittype[wait.type](wait)
    end
  end
  for name,value in pairs(waits) do
    outsignals[#outsignals+1]={index=#outsignals+1,count=value,signal=knownsignals.parseSchedule[name]}
  end
  --Array of frames, for future expansion to multi-frame reports of OR groups
  return {outsignals}
end

local function parseScheduleEntry(signals,surface)
  local knownsigs = get_signals_filtered(knownsignals.parseSchedule,signals)

  local schedule = {wait_conditions = {}}

  local userail = knownsigs.schedulerail or 0
  if userail ~= 0 then 
    local x = knownsigs.X or 0
    local y = knownsigs.Y or 0

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
    local string = remote.call('signalstrings','signals_to_string',signals,knownsigs.richtext or false)
    schedule.station = string
  end


  local sigwaitt = knownsigs.wait_time or 0
  if sigwaitt > 0 then
    table.insert(schedule.wait_conditions, {
      type="time",
      compare_type="and",
      ticks = sigwaitt
    })
  end
  local sigwaiti = knownsigs.wait_inactivity or 0
  if sigwaiti > 0 then
    table.insert(schedule.wait_conditions, {
      type="inactivity",
      compare_type="and",
      ticks = sigwaiti
    })
  end
  local sigwaite = knownsigs.wait_empty or 0
  if sigwaite > 0 then
    table.insert(schedule.wait_conditions, {
      type="empty",
      compare_type="and",
    })
  end
  local sigwaitf = knownsigs.wait_full or 0
  if sigwaitf > 0 then
    table.insert(schedule.wait_conditions, {
      type="full",
      compare_type="and",
    })
  end
  local sigwaitc = knownsigs.wait_circuit or 0
  if sigwaitc > 0 then
    table.insert(schedule.wait_conditions, {
      type="circuit",
      compare_type="and",
      condition = { first_signal = {name="signal-black",type="virtual"}, comparator = "≠" }
    })
  end
  local sigwaitp = knownsigs.wait_passenger or 0
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
  local sigwaitr = knownsigs.wait_robots or 0
  if sigwaitr > 0 then
    table.insert(schedule.wait_conditions, {
      type="robots_inactive",
      compare_type="and",
    })
  end
  return schedule
end


local function addDTSToTable(entity)
  global.stringyStations[entity.unit_number] = { entity = entity, schedule = {}}
end

local function renameStringyStation(entity, stationNewName)
  -- we can't just rename the station directly because if it is the only stop
  -- of that name, it will edit existing schedules to replace the old name with new
  local create_order = {
    name = entity.name,
    position = entity.position,
    direction = entity.direction,
    force = entity.force,
  }
  local stationUnitNumber = entity.unit_number
  local stationCircuits = entity.circuit_connection_definitions

  local stationControlBehavior = entity.get_control_behavior()

  local stationSendToTrain = stationControlBehavior.send_to_train
  local stationReadFromTrain = stationControlBehavior.read_from_train
  local stationReadStoppedTrain = stationControlBehavior.read_stopped_train
  local stationEnableDisable = stationControlBehavior.enable_disable
  local stationStoppedTrainSignal = stationControlBehavior.stopped_train_signal
  local stationCircuitCondition = stationControlBehavior.circuit_condition

  local surface = entity.surface
  -- raising destroyed here prevents rename of multiple stations connected together,
  -- or possibly other updates of multiple unconnected stations in the same tick
  entity.destroy()
  local newStation = surface.create_entity(create_order)
  for i, wire in pairs(stationCircuits) do
    newStation.connect_neighbour(wire)
  end

  local newStationControlBehavior = newStation.get_control_behavior()

  newStationControlBehavior.send_to_train = stationSendToTrain
  newStationControlBehavior.read_from_train = stationReadFromTrain
  newStationControlBehavior.read_stopped_train = stationReadStoppedTrain
  newStationControlBehavior.enable_disable = stationEnableDisable
  newStationControlBehavior.stopped_train_signal = stationStoppedTrainSignal
  newStationControlBehavior.circuit_condition = stationCircuitCondition

  addDTSToTable(newStation)
  newStation.backer_name = stationNewName
  script.raise_event(events.on_renamed_station,{old_unit_number = stationUnitNumber, entity = newStation})
  return true
end

local function updateStringyStation(station)
  local entity = station.entity
  if not entity.valid then return true end
  local signals = entity.get_merged_signals()
  if signals and #signals >0 then
    local knownsigs = get_signals_filtered(knownsignals.updateStation,signals)

    if (knownsigs.stopname or 0) == 1 then
      -- rename station
      local string = remote.call('signalstrings','signals_to_string',signals,knownsigs.richtext or false)
      if string ~= entity.backer_name then
        return renameStringyStation(entity, string)
      end
      return
    end
    local sigsched = knownsigs.schedule or 0
    if sigsched > 0 then
      -- build schedule
      local schedule = parseScheduleEntry(signals,entity.surface)
      station.schedule[sigsched] = schedule
      return
    elseif sigsched == -1 then
      -- set schedule, send to first
      if station.schedule[1] then
        for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
          if train.train.state == defines.train_state.wait_station and train.train.station == entity then
            train.train.manual_mode = true
            train.train.schedule = { current = 1, records = station.schedule}
            train.train.manual_mode = false
            station.schedule = {}
            return
          end
        end
      end
      return
    end
    if (knownsigs.go or 0) ~= 0 then
      -- send train to named station
      for _,train in pairs(entity.surface.find_entities_filtered{area={{x=entity.position.x-2,y=entity.position.y-2},{x=entity.position.x+2,y=entity.position.y+2}},type='locomotive'}) do
        if train.train.state == defines.train_state.wait_station and train.train.station == entity then
          local string = remote.call('signalstrings','signals_to_string',signals,knownsigs.richtext or false)
          train.train.manual_mode = true
          train.train.schedule = { current = 1, records = {{station=string}}}
          train.train.manual_mode = false
          return
        end
      end
      return
    end
  end
end

script.on_event(defines.events.on_built_entity, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.created_entity)
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.on_robot_built_entity, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.created_entity)
  end
end, {{filter="name",name="stringy-train-stop"}})


script.on_event(defines.events.on_entity_cloned, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.destination)
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.script_raised_built, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.entity)
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.script_raised_revive, function(event)
  if (event.created_entity.name == "stringy-train-stop") then
    addDTSToTable(event.entity)
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.on_pre_player_mined_item, function(event)
  if (event.entity.name == "stringy-train-stop") then
    global.stringyStations[event.entity.unit_number] = nil
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.on_robot_pre_mined, function(event)
  if (event.entity.name == "stringy-train-stop") then
    global.stringyStations[event.entity.unit_number] = nil
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.on_entity_died, function(event)
  if (event.entity.name == "stringy-train-stop") then
    global.stringyStations[event.entity.unit_number] = nil
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_event(defines.events.script_raised_destroy, function(event)
  if (event.entity.name == "stringy-train-stop") then
    global.stringyStations[event.entity.unit_number] = nil
  end
end, {{filter="name",name="stringy-train-stop"}})

script.on_init(function()
  global = {
    stringyStations = {
      -- [unit_number] = {entity=entity,schedule={}}
    },
  }
end)

script.on_configuration_changed(function(event)
  if global.schedules then
    local data = {}
    for _,entity in pairs(global.stringyStations) do
      if entity.valid then
        data[entity.unit_number] = { entity = entity, schedule = global.schedules[entity.unit_number] or {} }
      end
    end
    global.stringyStations = data
    global.schedules = nil
  elseif not global.stringyStations then
    global.stringyStations = {}
  end
end)

script.on_event(defines.events.on_tick, function()
  for id, station in pairs(global.stringyStations) do
    if updateStringyStation(station) then
      global.stringyStations[id] = nil
    end
  end
end)

remote.add_interface("stringy-train-stop",{
  reportScheduleEntry = reportScheduleEntry,
  parseScheduleEntry = parseScheduleEntry,
  getEvents = function() return events end,
})

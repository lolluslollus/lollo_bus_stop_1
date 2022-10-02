local arrayUtils = require('lollo_streetside_passenger_stops.arrayUtils')
local edgeUtils = require('lollo_streetside_passenger_stops.edgeUtils')
local logger = require('lollo_streetside_passenger_stops.logger')
local transfUtils = require('lollo_streetside_passenger_stops.transfUtils')


local _eventId = '__lolloStreetsidePassengerStopsEvent__'
-- local _eventProperties = {
--     streetsideBusStopBuilt = { conName = 'station/street/lollo_streetside_passenger_stops/lollo_lorry_bay_with_edges.con', eventName = 'streetsideBusStopBuilt' },
--     ploppableModularCargoStationBuilt = { conName = 'station/street/lollo_streetside_passenger_stops/lollo_lorry_bay_with_edges_ploppable.con', eventName = 'ploppableModularCargoStationBuilt' },
--     ploppableStreetsideCargoStationBuilt = { conName = nil, eventName = 'ploppableStreetsideCargoStationBuilt' },
--     ploppableStreetsidePassengerStationBuilt = { conName = nil, eventName = 'ploppableStreetsidePassengerStationBuilt' },
-- }

local _guiConstants = {
    _ploppablePassengersModelId = false,
}

local function _myErrorHandler(err)
    print('lollo lorry station ERROR: ', err)
end


function data()
    return {
        guiHandleEvent = function(id, name, args)
            -- LOLLO NOTE param can have different types, even boolean, depending on the event id and name
            -- if (name ~= 'builder.apply') then return end

            -- logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
            -- if name ~= 'builder.proposalCreate' then
            --  logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
            -- end

            -- xpcall(
            --     function()
            if name == 'builder.apply' then
                logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
                if id == 'streetTerminalBuilder' then
                    -- waypoint or streetside stations have been built
                    if (args and args.proposal and args.proposal.proposal
                    and args.proposal.proposal.edgeObjectsToAdd
                    and args.proposal.proposal.edgeObjectsToAdd[1]
                    and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance)
                    then
                        if _guiConstants._ploppablePassengersModelId
                        and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance.modelId == _guiConstants._ploppablePassengersModelId then
                            logger.print('args =') logger.debugPrint(args)
                            local stationId = args.proposal.proposal.edgeObjectsToAdd[1].resultEntity
                            logger.print('stationId =') logger.debugPrint(stationId)
                            local edgeId = args.proposal.proposal.edgeObjectsToAdd[1].segmentEntity
                            logger.print('edgeId =') logger.debugPrint(edgeId)
                            if not(edgeId) or not(stationId) then return end

                            -- api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                            --     string.sub(debug.getinfo(1, 'S').source, 1),
                            --     _eventId,
                            --     _eventProperties.ploppableStreetsidePassengerStationBuilt.eventName,
                            --     {
                            --         edgeId = edgeId,
                            --         stationId = stationId,
                            --     }
                            -- ))
                        end
                    end
                end
            end
            --     end,
            --     _myErrorHandler
            -- )
        end,
        guiInit = function()
            _guiConstants._ploppablePassengersModelId = api.res.modelRep.find('station/bus/small_mid.mdl')
        end,
        handleEvent = function(src, id, name, args)
            if (id ~= _eventId) then return end
            logger.print('handleEvent starting, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)
            if type(args) ~= 'table' then return end

        end,
        -- update = function()
        -- end,
        -- guiUpdate = function()
        -- end,
    }
end

local constants = require('lollo_bus_stop.constants')

local helpers = {
    getVoidBoundingInfo = function()
        return {} -- this seems the same as the following
        -- return {
        --     bbMax = { 0, 0, 0 },
        --     bbMin = { 0, 0, 0 },
        -- }
    end,
    getVoidCollider = function()
        -- return {
        --     params = {
        --         halfExtents = { 0, 0, 0, },
        --     },
        --     transf = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, },
        --     type = 'BOX',
        -- }
        return {
            type = 'NONE'
        }
    end,
    getTransportNetworkProvider4WaitingArea = function()
        local xFactor = 3
        local yShift = -0.25
        return {
            laneLists = {
                {
                    linkable = false,
                    nodes = {
                        {{ -xFactor * constants.outerEdgeX, yShift, 0 }, { xFactor * constants.outerEdgeX, -yShift, 0, }, 1}, -- edge 0 -- node 0
                        {{ 0, 0, 0 }, { xFactor * constants.outerEdgeX, -yShift, 0, }, 1}, -- node 1

                        {{ 0, 0, 0 }, { xFactor * constants.outerEdgeX, yShift, -0 }, 1}, -- edge 1 -- node 2
                        {{ xFactor * constants.outerEdgeX, yShift, 0 }, { xFactor * constants.outerEdgeX, yShift, -0 }, 1}, -- node 3
                    },
                    speedLimit = 20,
                    transportModes = { 'PERSON' },
                },
            },
            runways = { },
            terminals = {
                {
                    -- order = 999,
                    personEdges = { 0, 1 },
                    personNodes = { 0, 3 },
                    -- vehicleNode = 2,
                },
            },
        }
    end
}

return helpers

return {
    cargoNodeZ = -2,
    halfEdgeLength = 0.5,
    outerEdgeX = 1, -- 1 is enough for straightaways, curves need more than 5. The longer this is, the more buildings will be destroyed.
    -- outerEdgeXCon = 0.7, -- we make this smaller then outerEdgeX so we can snap in curves -- useless, curves fail anyway
    outerEdgeXCon = 1,
    vehicleNodeZ = 0
}

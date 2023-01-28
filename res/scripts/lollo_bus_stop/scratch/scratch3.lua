package.path = package.path .. ';res/scripts/?.lua'
package.path = package.path .. ';C:/Program Files (x86)/Steam/steamapps/common/Transport Fever 2/res/scripts/?.lua'

local transfUtils = require('lollo_bus_stop.transfUtils')
local edgeData4Con = {
    edge0Tan0 = { 0.24333998560905, 0.42974358797073, 0.052750755101442, },
    edge0Tan1 = { 0.122756715964, 0.21616093099859, 0.026556366384643, },
    edge1Tan0 = { 0.24551343192801, 0.43232186199718, 0.053112732769287, },
    edge1Tan1 = { 0.24660081430097, 0.4317007773906, 0.053126991129232, },
    edge2Tan0 = { 0.12330040715049, 0.2158503886953, 0.026563495564616, },
    edge2Tan1 = { 0.24549423158169, 0.42851310968399, 0.052779000252485, },
    innerNode0Pos = { 444.47705710772, 878.22848889977, 30.825984847732, },
    innerNode1Pos = { 444.96422881912, 879.08383532614, 30.93115796987, },
    outerNode0Pos = { 444.23382568359, 877.79956054688, 30.77331161499, },
    outerNode1Pos = { 445.20907592773, 879.51184082031, 30.983852386475, },
}

local distancePos00 = transfUtils.getVectorLength({
    edgeData4Con.outerNode0Pos[1] - edgeData4Con.innerNode0Pos[1],
    edgeData4Con.outerNode0Pos[2] - edgeData4Con.innerNode0Pos[2],
    edgeData4Con.outerNode0Pos[3] - edgeData4Con.innerNode0Pos[3],
})
local distanceTan00 = transfUtils.getVectorLength(edgeData4Con.edge0Tan0)
local distanceTan01 = transfUtils.getVectorLength(edgeData4Con.edge0Tan1)

local dummy = 123

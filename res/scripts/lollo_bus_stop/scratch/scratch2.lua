package.path = package.path .. ';res/scripts/?.lua'
package.path = package.path .. ';C:/Program Files (x86)/Steam/steamapps/common/Transport Fever 2/res/scripts/?.lua'

local arrayUtils = require('lollo_bus_stop.arrayUtils')
local mapItem = {
    [1] = 28420,
    [2] = 28635,
}
local tab1 = {[1] = 12345, [2] = 2345}
local tab2 = {[1] = 28420, [2] = 2345}
local tab3 = {[1] = 28420, [2] = 28635}
local tab4 = {[1] = 28635, [2] = 28420}

local test1, test2, test3, test4
for _, edgeId in pairs(mapItem) do
    test1 = arrayUtils.findIndex(tab1, nil, edgeId)
end
for _, edgeId in pairs(mapItem) do
    test2 = arrayUtils.findIndex(tab2, nil, edgeId)
end
for _, edgeId in pairs(mapItem) do
    test3 = arrayUtils.findIndex(tab3, nil, edgeId)
end
for _, edgeId in pairs(mapItem) do
    test4 = arrayUtils.findIndex(tab4, nil, edgeId)
end

local isNodeAttachedToSomethingElse = function(tab, mapItem)
    for _, edgeId in pairs(mapItem) do
        if arrayUtils.findIndex(tab, nil, edgeId) == -1 then return true end
    end
    return false
end
local test11 = isNodeAttachedToSomethingElse(tab1, mapItem)
local test12 = isNodeAttachedToSomethingElse(tab2, mapItem)
local test13 = isNodeAttachedToSomethingElse(tab3, mapItem)
local test14 = isNodeAttachedToSomethingElse(tab4, mapItem)

local dummy = 123

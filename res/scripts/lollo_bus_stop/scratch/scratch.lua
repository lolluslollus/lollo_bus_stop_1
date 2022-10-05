package.path = package.path .. ';res/scripts/?.lua'
package.path = package.path .. ';C:/Program Files (x86)/Steam/steamapps/common/Transport Fever 2/res/scripts/?.lua'

local moduleHelpers = require('lollo_bus_stop.moduleHelpers')
local params = {}
moduleHelpers.setIntParamsFromFloat(params, 'aa1', 'ab1', 1000.0001)
local test1 = moduleHelpers.getFloatFromIntParams(params, 'aa1', 'ab1')

moduleHelpers.setIntParamsFromFloat(params, 'aa2', 'ab2', -1000.0001)
local test2 = moduleHelpers.getFloatFromIntParams(params, 'aa2', 'ab2')

moduleHelpers.setIntParamsFromFloat(params, 'aa3', 'ab3', 1000)
local test3 = moduleHelpers.getFloatFromIntParams(params, 'aa3', 'ab3')

moduleHelpers.setIntParamsFromFloat(params, 'aa4', 'ab4', -1000)
local test4 = moduleHelpers.getFloatFromIntParams(params, 'aa4', 'ab4')

moduleHelpers.setIntParamsFromFloat(params, 'aa5', 'ab5', 1000.000000001)
local test5 = moduleHelpers.getFloatFromIntParams(params, 'aa5', 'ab5')

moduleHelpers.setIntParamsFromFloat(params, 'aa6', 'ab6', -1000.000000001)
local test6 = moduleHelpers.getFloatFromIntParams(params, 'aa6', 'ab6')

moduleHelpers.setIntParamsFromFloat(params, 'aa7', 'ab7', 1000000000.0000000001)
local test7 = moduleHelpers.getFloatFromIntParams(params, 'aa7', 'ab7')

moduleHelpers.setIntParamsFromFloat(params, 'aa8', 'ab8', -1000000000.0000000001)
local test8 = moduleHelpers.getFloatFromIntParams(params, 'aa8', 'ab8')

moduleHelpers.setIntParamsFromFloat(params, 'aa9', 'ab9', 0.0000000001)
local test9 = moduleHelpers.getFloatFromIntParams(params, 'aa9', 'ab9')

moduleHelpers.setIntParamsFromFloat(params, 'aa10', 'ab10', -0.0000000001)
local test10 = moduleHelpers.getFloatFromIntParams(params, 'aa10', 'ab10')

moduleHelpers.setIntParamsFromFloat(params, 'aa11', 'ab11', 100000000.000000001)
local test11 = moduleHelpers.getFloatFromIntParams(params, 'aa11', 'ab11')

moduleHelpers.setIntParamsFromFloat(params, 'aa12', 'ab12', -100000000.000000001)
local test12 = moduleHelpers.getFloatFromIntParams(params, 'aa12', 'ab12')

local dummy = 123

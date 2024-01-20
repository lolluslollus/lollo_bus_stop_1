--[[

conIds = game.interface.getEntities({pos = {0, 0, 0}, radius = 1e100}, { type = "CONSTRUCTION" })
for key,conId in pairs(conIds) do
    local con = game.interface.getEntity(conId)
    if con.fileName:match("lollo_bus_stop/") then print(conId) end
end

451195

442609

447134
]]
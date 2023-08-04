-- the main object
ArcCW = {}

ArcCWInstalled = true
ArcCW.GenerateAttEntities = true

local lcl = SERVER and AddCSLuaFile or include
local lsv = SERVER and include or function() end
local lsh = function(path) lsv(path) lcl(path) end

for _, v in ipairs(file.Find("arccw/shared/*", "LUA")) do
    lsh("arccw/shared/" .. v)
end

for _, v in ipairs(file.Find("arccw/client/*", "LUA")) do
    lcl("arccw/client/" .. v)
end

-- TODO: Remove SP check after upcoming June 2023 update
if SERVER or game.SinglePlayer() then
    for _, v in ipairs(file.Find("arccw/server/*", "LUA")) do
        include("arccw/server/" .. v)
    end
end

-- if you want to override arccw functions, put your override files in the arccw/mods directory so it will be guaranteed to override the base

for _, v in ipairs(file.Find("arccw/mods/shared/*", "LUA")) do
    lsh("arccw/mods/shared/" .. v)
end

for _, v in ipairs(file.Find("arccw/mods/client/*", "LUA")) do
    lcl("arccw/mods/client/" .. v)
end

-- TODO: Remove SP check after upcoming June 2023 update
if SERVER or game.SinglePlayer() then
    for _, v in ipairs(file.Find("arccw/mods/server/*", "LUA")) do
        include("arccw/mods/server/" .. v)
    end
end

lcl, lsv, lsh = nil, nil, nil

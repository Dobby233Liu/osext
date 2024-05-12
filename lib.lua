local ffi = require("ffi")

---@class OSExt
-- Extra OS functions for Kristal modders who need them for some reason
OSExt = {}

---@private
function OSExt._typeExists(type)
    local _
    return ({pcall(
        function()
            _ = ffi.typeof(type)
        end)
    })[1]
end

if ffi.os == "Windows" then
    libRequire("osext", "win32/init")
end

if Utils.containsValue({ "Linux", "OSX" }, ffi.os) then
    libRequire("osext", "unix/init")
end


local kristalEvents = {}

function kristalEvents:preInit()
    if OSExt.Unix then
        OSExt.Unix:init()
    end
end

function kristalEvents:unload()
    _G.OSExt = nil
end

return kristalEvents
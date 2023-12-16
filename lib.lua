---@class OSExt
OSExt = {}

local ffi = require("ffi")

if ffi.os == "Windows" then
    libRequire("osext", "win32")
end

-- do not expose any events
return {}
local ffi = require("ffi")

---@class OSExt
-- Extra OS functions for Kristal modders who need them for some reason
OSExt = {}

if ffi.os == "Windows" then
    libRequire("osext", "win32/init")
end

-- do not expose any events
return {}
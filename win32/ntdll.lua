local ffi = require("ffi")

OSExt.Win32.Libs.ntdll = ffi.load("ntdll")
if not OSExt.Win32.Libs.ntdll then
    error("ntdll not available?!")
end

libRequire("osext", "win32/ntsysapi")


ffi.cdef[[
    char *wine_get_version(void);
]]

-- Returns the version of Wine the game is running under.
-- If the result is nil, the game is not running under Wine.
---@return string? wineVersion
function OSExt.Win32.getWineVersion()
    local success, result = pcall(function()
        return OSExt.Win32.Libs.ntdll.wine_get_version()
    end)
    if not success then return nil end
    return result
end
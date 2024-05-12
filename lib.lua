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

return {
    unload = function()
        _G.OSExt = nil
    end
}
local ffi = require("ffi")

---@class OSExt
-- Extra OS functions for Kristal modders who need them for some reason
OSExt = {}

---@private
function OSExt._typeExists(type)
    local throwaway
    return select(1, pcall(
        function()
            throwaway = ffi.new(type)
        end)
    )
end

if ffi.os == "Windows" then
    libRequire("osext", "win32/init")
end

-- do not expose any events
return {}
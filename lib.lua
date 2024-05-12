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

assert(ffi.os ~= "OSX", "macOS not properly supported yet")
if Utils.containsValue({ "Linux", "OSX" }, ffi.os) then
    libRequire("osext", "unix/init")
end


-- Gets the name of the user playing the game
---@return string?
function OSExt.getUserName()
    if OSExt.Win32 then
        return OSExt.Win32.getUserName()
    elseif OSExt.Unix then
        return OSExt.Unix.getUserName()
    end
end

-- Gets the full name (as set in the system) of the user playing the game
---@return string?
function OSExt.getUserFullName()
    if OSExt.Win32 then
        local ok, result = pcall(OSExt.Win32.getUserNameEx, OSExt.Win32.ExtendedNameFormat.display)
        if ok then return result end
    elseif OSExt.Unix then
        local gecos = OSExt.Unix.parseGecosOfUser()
        if gecos then return gecos.fullName end
    end
end

-- Gets the name of the computer that is running the game (hostname on Unix)
---@return string?
function OSExt.getComputerName()
    if OSExt.Win32 then
        return OSExt.Win32.getComputerName()
    elseif OSExt.Unix then
        return OSExt.Unix.getHostName()
    end
end

-- Gets the PID of the current process.
---@return integer?
function OSExt.getCurrentProcessId()
    if OSExt.Win32 then
        return OSExt.Win32.getCurrentProcessId()
    elseif OSExt.Unix then
        return OSExt.Unix.getCurrentProcessId()
    end
end

-- Gets a list of currently running processes by their exe names.
---@return string[]?
function OSExt.getProcessNames()
    if OSExt.Win32 then
        return OSExt.Win32.getProcessNames()
    elseif OSExt.Unix then
        return OSExt.Unix.getProcessNames()
    end
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
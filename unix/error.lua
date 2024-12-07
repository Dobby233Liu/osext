local ffi = require "ffi"

ffi.cdef[[
    typedef int errno_t;
]]

OSExt.Unix.Errnos = {
    EINVAL = 22, -- Invalid argument
    EACCES = 13, -- Permission denied
    EBADF = 9, -- Bad file number
    ENOENT = 2, -- No such file or directory
    ENOTDIR = 20, -- Not a directory
    ENOTEMPTY = 39, -- Directory not empty
    EISDIR = 21, -- Is a directory
    ENOSPC = 28, -- No space left on device
}

ffi.cdef[[
    char *strerror(errno_t errnum);
]]

-- Gets the message corresponding to the given errno
---@param errno integer
---@return string?
function OSExt.Unix.getSystemMessage(errno)
    local strPtr = ffi.C.strerror(errno)
    if not strPtr then return nil end
    return ffi.string(strPtr)
end

-- Raises a Lua error from the given errno
---@param errno integer
---@param format? boolean # whether to get a readable error message or not
function OSExt.Unix.raiseLuaError(errno, format)
    if format == nil then format = true end
    if errno ~= 0 then
        local message = ""
        if format then
            message = OSExt.Unix.getSystemMessage(errno) or ""
        end
        if message ~= "" then message = message .. " " end
        error(string.format("Syscall failed with error: %s(%d)", message, errno))
    end
end

-- Raises a Lua error from the currently set errno.
--
-- To be called if it's certain that the last syscall failed.
-- (Reset errno to 0 beforehand if that can't be inferred easily.)
---@param format? boolean # whether to get a readable error message or not
function OSExt.Unix.raiseLastError(format)
    local err = ffi.errno()
    if err == 0 then return end
    OSExt.Unix.raiseLuaError(err, format)
end
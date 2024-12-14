local ffi = require "ffi"

---@alias OSExt.Unix.pid integer

ffi.cdef[[
    typedef int pid_t;
]]

ffi.cdef[[
    pid_t getpid(void);
    pid_t getppid(void);
]]

-- Gets the PID of the current process.
function OSExt.Unix.getCurrentProcessId()
    -- can't fail
    return ffi.C.getpid()
end

if ffi.os == "Linux" then
    libRequire("osext", "unix/proc_linux")
--[[elseif ffi.os == "OSX" or ffi.os == "BSD" then
    libRequire("osext", "unix/proc_bsd")]]
end
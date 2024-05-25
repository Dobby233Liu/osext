local ffi = require "ffi"
local fs = OSExt.Unix.fs

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

-- Gets the path to the /proc directory corresponding to the given PID.
function OSExt.Unix.getProcessFs(pid)
    if pid == nil then pid = OSExt.Unix.getCurrentProcessId() end
    return "/proc/"..pid
end

-- Gets the path to the executable of the process corresponding to the given PID.
function OSExt.Unix.getProcessExePath(pid)
    return fs.readlink(OSExt.Unix.getProcessFs(pid).."/exe")
end
-- Gets the name of the executable of the process corresponding to the given PID.
function OSExt.Unix.getProcessExeName(pid)
    local name, _ = string.gsub(OSExt.Unix.getProcessExePath(pid), ".*/(.*)", "%1")
    return name
end

-- Gets a list of currently running processes by their PIDs.
---@return OSExt.Unix.pid[]
function OSExt.Unix.getProcesses()
    local pids = {}
    for name, d in fs.dir("/proc") do
        if name and d:attr("type") == "dir" and tonumber(name) then
            table.insert(pids, tonumber(name))
        end
    end
    return pids
end

-- Gets a list of currently running processes by their exe names.
---@return string[]
function OSExt.Unix.getProcessNames()
    local names = {}
    for _, pid in ipairs(OSExt.Unix.getProcesses()) do
        table.insert(names, OSExt.Unix.getProcessExeName(pid))
    end
    return names
end
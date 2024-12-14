local ffi = require "ffi"
local fs = OSExt.Unix.fs

-- Gets the path to the /proc directory corresponding to the given PID.
function OSExt.Unix.getProcessFs(pid)
    if pid == nil then pid = OSExt.Unix.getCurrentProcessId() end
    return "/proc/"..pid
end

-- Gets the path to the executable of the process corresponding to the given PID.
function OSExt.Unix.getProcessExePath(pid)
    local procFs = OSExt.Unix.getProcessFs(pid)
    local exeSymPath = procFs.."/exe"
    -- Try to resolve the "exe" symlink - most reliable
    local ret = fs.readlink(exeSymPath)

    -- If that fails, try to read the "cmdline" file - less reliable
    if not ret or ret == exeSymPath then
        local cmdlineFile = fs.open(procFs.."/cmdline", "r")
        if cmdlineFile then
            local cmdlineStrBuf, cmdlineStrLen = cmdlineFile:readall_hungry()
            if cmdlineStrBuf then
                local cmdline = ffi.string(cmdlineStrBuf, cmdlineStrLen)
                if cmdline then
                    ret = Utils.split(cmdline, "\0")[1]
                end
            end
        end
    end

    if ret == exeSymPath then return nil end
    return ret
end

-- Gets the name of the executable of the process corresponding to the given PID.
function OSExt.Unix.getProcessExeName(pid)
    local path = OSExt.Unix.getProcessExePath(pid)
    if not path then return nil end
    local name, _ = string.gsub(path, ".*/(.*)", "%1")
    return name
end

-- Gets a list of currently running processes by their PIDs.
---@return OSExt.Unix.pid[]
function OSExt.Unix.getProcesses()
    local pids = {}
    for name, d in fs.dir("/proc") do
        if name and d:is("dir") and tonumber(name) then
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
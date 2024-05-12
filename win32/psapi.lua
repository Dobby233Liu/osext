local ffi = require "ffi"
local bit = require "bit"

-- Implements misc process related things
--
-- [PSApi MSDN](https://learn.microsoft.com/en-us/windows/win32/psapi/process-status-helper)

OSExt.Win32.ProcessAccessRights = Utils.merge(OSExt.Win32.AccessRights, {
    createProcess = 0x0080,
    createThread = 0x0002,
    duplicateHandle = 0x0040,
    queryInformation = 0x0400,
    queryLimitedInformation = 0x1000,
    setInformation = 0x0200,
    setQuota = 0x0100,
    suspendResume = 0x0800,
    terminate = 0x0001,
    vmOperation = 0x0008,
    vmRead = 0x0010,
    vmWrite = 0x0020
})
OSExt.Win32.ProcessAccessRights.allAccess = bit.bor(
    OSExt.Win32.ProcessAccessRights.standardRightsRequired,
    OSExt.Win32.ProcessAccessRights.synchronize,
    0xFFFF
)

ffi.cdef[[
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
]]

-- Opens an existing local process object.
---@param processId number # process id
---@param accessRights number # access rights, defaults to queryInformation
---@return OSExt.Win32.HANDLE handle
function OSExt.Win32.openProcess(processId, accessRights)
    if accessRights == nil then
        accessRights = bit.bor(
            OSExt.Win32.ProcessAccessRights.queryInformation,
            OSExt.Win32.ProcessAccessRights.vmRead
        )
    end

    local ret = OSExt.Win32.markHandleForGC(OSExt.Win32.Libs.kernel32.OpenProcess(accessRights, false, processId))
    if ret == OSExt.Win32.INVALID_HANDLE_VALUE then
        OSExt.Win32.raiseLastError()
    end
    return ret
end


ffi.cdef[[
    DWORD K32GetProcessImageFileNameW(HANDLE hProcess, LPWSTR lpImageFileName, DWORD nSize);
    DWORD K32GetModuleBaseNameW(HANDLE hProcess, HMODULE hModule, LPWSTR lpBaseName, DWORD nSize);
]]

---@param process OSExt.Win32.HANDLE # process handle
---@return string imageName # how the kernel sees it at least (TODO)
function OSExt.Win32.getProcessImageFileName(process)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local len = ffi.C.MAX_PATH ---@type integer
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.K32GetProcessImageFileNameW(process, buf, len)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len)
end

---@param process OSExt.Win32.HANDLE # process handle
---@param module OSExt.Win32.HMODULE # module handle
---@return string imageName
function OSExt.Win32.getModuleBaseName(process, module)
    process = OSExt.Win32.markHandleForGC(process)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local len = ffi.C.MAX_PATH ---@type integer
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.K32GetModuleBaseNameW(process, module, buf, len)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len)
end
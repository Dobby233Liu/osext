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

---@alias OSExt.Win32.HPROCESS OSExt.Win32.HANDLE # fantasy alias

ffi.cdef[[
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
]]

-- Opens an existing local process object.
---@param processId integer # process id
---@param accessRights? integer # access rights, defaults to queryInformation
---@return OSExt.Win32.HPROCESS handle
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
    //DWORD K32GetProcessImageFileNameW(HANDLE hProcess, LPWSTR lpImageFileName, DWORD nSize);
    DWORD K32GetModuleBaseNameW(HANDLE hProcess, HMODULE hModule, LPWSTR lpBaseName, DWORD nSize);
]]

--[[
-- For obtaining the full path to a process' image file in device form.
---@param process OSExt.Win32.HPROCESS # process handle
---@return string imageName
function OSExt.Win32.getProcessImageFileNameNative(process)
    --process = OSExt.Win32.markHandleForGC(process)
    local len = OSExt.Win32.MAX_PATH
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
]]

-- For obtaining the base name of one of a process' modules.
---@param process OSExt.Win32.HPROCESS # process handle
---@param module OSExt.Win32.HMODULE # module handle
---@return string imageName
function OSExt.Win32.getModuleBaseName(process, module)
    --process = OSExt.Win32.markHandleForGC(process)
    local len = OSExt.Win32.MAX_PATH
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


ffi.cdef[[
    BOOL QueryFullProcessImageNameW(HANDLE hProcess, DWORD dwFlags, LPWSTR lpExeName, PDWORD lpdwSize);
]]
-- For obtaining the full path to a process' image file in device form.
---@param process OSExt.Win32.HPROCESS # process handle
---@param nativeStyle boolean
---@return string imageName
function OSExt.Win32.getProcessImageFileName(process, nativeStyle)
    --process = OSExt.Win32.markHandleForGC(process)
    local len = OSExt.Win32.MAX_PATH
    local buf = ffi.new("WCHAR[?]", len)
    local lenBuf = ffi.new("DWORD[1]", len)
    local ret = OSExt.Win32.Libs.kernel32.QueryFullProcessImageNameW(process, nativeStyle or false, buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            buf = ffi.new("WCHAR[?]", lenBuf[0])
            ret = OSExt.Win32.Libs.kernel32.QueryFullProcessImageNameW(process, nativeStyle or false, buf, lenBuf)
            e = ret and OSExt.Win32.Libs.kernel32.GetLastError() or OSExt.Win32.HResults.ERROR_SUCCESS
        end
        if e ~= OSExt.Win32.HResults.ERROR_SUCCESS then
            OSExt.Win32.raiseLuaError(e)
        end
    end
    return OSExt.Win32.wideToLuaString(buf, lenBuf[0])
end
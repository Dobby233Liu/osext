local ffi = require("ffi")

-- Implements some of psapi.dll's interfaces
--
-- The Process Status API provides data about currently running processes or so
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/psapi/process-status-helper)
OSExt.Win32.PSApi = {}

OSExt.Win32.Libs.psapi = ffi.load("psapi")
if not OSExt.Win32.Libs.psapi then
    print("psapi not available")
    return
end

ffi.cdef[[
    DWORD K32GetProcessImageFileNameW(HANDLE hProcess, LPWSTR lpImageFileName, DWORD nSize);
    DWORD K32GetModuleBaseNameW(HANDLE hProcess, HMODULE hModule, LPWSTR lpBaseName, DWORD nSize);
]]

---@param process OSExt.Win32.HANDLE # process handle
---@return string imageName # how the kernel sees it at least (TODO)
function OSExt.Win32.getProcessImageName(process)
    local len = 1024
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.K32GetProcessImageFileNameW(process, buf, len-1)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len-1)
end

---@param process OSExt.Win32.HANDLE # process handle
---@param module OSExt.Win32.HMODULE # process handle
---@return string imageName # how the kernel sees it at least (TODO)
function OSExt.Win32.getModuleBaseName(process, module)
    process = OSExt.Win32.makeHandle(process)
    local len = 1024
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.K32GetModuleBaseNameW(process, module, buf, len-1)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len-1)
end
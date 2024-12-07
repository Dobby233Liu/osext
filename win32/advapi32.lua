local ffi = require "ffi"

-- Implements some advapi32.dll interfaces
--
-- Contains advanced APIs that basesrv doesn't cover
OSExt.Win32.Libs.advapi32 = ffi.load("advapi32")
if not OSExt.Win32.Libs.advapi32 then
    error("advapi32 not available?")
end

ffi.cdef[[
    BOOL GetUserNameW(LPWSTR lpBuffer, LPDWORD pcbBuffer);
]]

-- TODO: allow pulling data from other users, by ImpersonateLoggedOnUser perhaps??

-- Gets the name of the user that is running the game,
-- excluding the domain name.
function OSExt.Win32.getUserName()
    local len = 1024
    local buf = ffi.new("WCHAR[?]", len+1)
    local lenBuf = ffi.new("DWORD[1]", len+1)
    local ret = OSExt.Win32.Libs.advapi32.GetUserNameW(buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.Win32Errors.ERROR_MORE_DATA then
            buf = ffi.new("WCHAR[?]", lenBuf[0])
            ret = OSExt.Win32.Libs.advapi32.GetUserNameW(buf, lenBuf)
            e = ret and OSExt.Win32.Libs.kernel32.GetLastError() or OSExt.Win32.Win32Errors.ERROR_SUCCESS
        end
        if e ~= OSExt.Win32.Win32Errors.ERROR_SUCCESS then
            OSExt.Win32.raiseLuaError(e)
        end
    end
    return OSExt.Win32.wideToLuaString(buf, lenBuf[0])
end
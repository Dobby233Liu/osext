local ffi = require "ffi"

-- Implements some secur32.dll interfaces that are covered by secext.h
--
-- This provides various functions to deal with user/computer object names
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/api/secext/)

OSExt.Win32.Libs.secur32 = ffi.load("secur32")
if not OSExt.Win32.Libs.secur32 then
    print("secur32 not available")
    return
end

---@enum OSExt.Win32.ExtendedNameFormat
OSExt.Win32.ExtendedNameFormat = {
    samCompatible = 2,

    canonical = 7,
    canonicalEx = 9,

    uniqueId = 6,

    display = 3,
    givenName = 13,
    surName = 14,

    userPrincipal = 8,
    servicePrincipal = 10,

    -- DN stands for uhh domain name IDK what you were thinking about
    fullyQualifiedDN = 1,
    dnsDomain = 12,
}

ffi.cdef[[
    // whatever
    typedef int EXTENDED_NAME_FORMAT;

    BOOLEAN GetUserNameExW(EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
    BOOLEAN GetComputerObjectNameW(EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
]]

-- Gets the name of the user that is running the game, in a specific format
---@param nameFormat OSExt.Win32.ExtendedNameFormat # defaults to samCompatible
function OSExt.Win32.getUserNameEx(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.ExtendedNameFormat.samCompatible

    local len = 1024
    local buf = ffi.new("WCHAR[?]", len+1)
    local lenBuf = ffi.new("DWORD[1]", len+1) -- seriously
    local ret = OSExt.Win32.Libs.secur32.GetUserNameExW(nameFormat, buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, lenBuf[0])
end

-- Gets the name of the computer that is running the game, in a specific format
--
-- FIXME: ??? Windows API operation failed with error: Configuration information 
-- could not be read from the domain controller, either because the machine is
-- unavailable, or access has been denied. (0x00000547)
--
-- Use OSExt.Win32.getComputerName instead
---@param nameFormat OSExt.Win32.ExtendedNameFormat # defaults to samCompatible
function OSExt.Win32.getComputerObjectNameEx(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.ExtendedNameFormat.samCompatible

    local len = 15
    local buf = ffi.new("WCHAR[?]", len+1)
    local lenBuf = ffi.new("DWORD[1]", len) -- seriously
    local ret = OSExt.Win32.Libs.secur32.GetComputerObjectNameW(nameFormat, buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, lenBuf[0])
end
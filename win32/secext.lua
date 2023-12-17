local ffi = require "ffi"

-- Implements some secur32.dll interfaces that are covered by secext.h
--
-- This provides various functions to deal with user/computer object names
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/api/secext/)
OSExt.Win32.SecExt = {}

OSExt.Win32.Libs.secur32 = ffi.load("secur32")
if not OSExt.Win32.Libs.secur32 then
    print("secur32 not available")
    OSExt.Win32.SecExt = nil
    return
end

---@enum OSExt.Win32.SecExt.NameFormats
-- This is EXTENDED_NAME_FORMAT in secext.h
OSExt.Win32.SecExt.NameFormats = {
    nameUnknown = 0,

    nameSamCompatible = 2,

    nameCanonical = 7,
    nameCanonicalEx = 9,

    nameUniqueId = 6,

    nameDisplay = 3,
    nameGivenName = 13,
    nameSurName = 14,

    nameUserPrincipal = 8,
    nameServicePrincipal = 10,

    -- DN stands for uhh domain name IDK what you were thinking about
    nameFullyQualifiedDN = 1,
    nameDnsDomain = 12,
}

ffi.cdef[[
    // whatever
    typedef int EXTENDED_NAME_FORMAT;

    BOOLEAN GetUserNameExW(EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
    //BOOLEAN GetComputerObjectNameW(EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
]]

-- Gets the name of the user that is running the game, in a specific format
---@param nameFormat OSExt.Win32.SecExt.NameFormats # defaults to nameSamCompatible
function OSExt.Win32.SecExt.getCurrentUserName(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.SecExt.NameFormats.nameSamCompatible

    local len = 1024
    local buf = ffi.new("WCHAR[?]", len)
    local lenBuf = ffi.new("DWORD[1]", len-1) -- seriously
    local ret = OSExt.Win32.Libs.secur32.GetUserNameExW(nameFormat, buf, lenBuf)
    if ret == 0 then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len-1)
end

-- This is noop
--[[
-- Gets the name of the computer that is running the game, in a specific format
---@param nameFormat OSExt.Win32.SecExt.NameFormats # defaults to nameSamCompatible
function OSExt.Win32.SecExt.getComputerName(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.SecExt.NameFormats.nameSamCompatible

    local len = 1024
    local buf = ffi.new("WCHAR[?]", len)
    local lenBuf = ffi.new("DWORD[1]", len-1) -- seriously
    local ret = OSExt.Win32.Libs.secur32.GetComputerObjectNameW(nameFormat, buf, lenBuf)
    if ret == 0 then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len-1)
end
]]
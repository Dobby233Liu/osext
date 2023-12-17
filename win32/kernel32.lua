local ffi = require("ffi")
local bit = require("bit")

-- kernel32 (WINBASEAPI) is pretty much for general OS stuff

OSExt.Win32.Libs.kernel32 = ffi.load("kernel32")
if not OSExt.Win32.Libs.kernel32 then
    error("kernel32 not available?!")
end

ffi.cdef[[
    BOOL CloseHandle(HANDLE hObject);
]]
-- Makes a handle cdata that is automatically GC'd
---@param handle ffi.cdata*
---@return OSExt.Win32.HANDLE
function OSExt.Win32.makeHandle(handle)
    handle = ffi.cast(OSExt.Win32.HANDLE, handle)
    if handle == OSExt.Win32.INVALID_HANDLE_VALUE then return handle end
    return ffi.gc(handle, OSExt.Win32.Libs.kernel32.CloseHandle)
end

ffi.cdef[[
    int WideCharToMultiByte(
        UINT CodePage,
        DWORD dwFlags,
        LPWSTR lpWideCharStr, int cchWideChar,
        LPSTR lpMultiByteStr, int cbMultiByte,
        LPCCH lpDefaultChar,
        LPBOOL lpUsedDefaultChar
    );
    int MultiByteToWideChar(
        UINT CodePage,
        DWORD dwFlags,
        LPSTR lpMultiByteStr, int cbMultiByte,
        LPWSTR lpWideCharStr, int cchWideChar
    );
]]
OSExt.Win32.CP_UTF8 = 65001
-- Converts a Win32 wide (UTF-16) string to a UTF-8 Lua string
-- (through WideCharToMultiByte instead of handling it ourselves)
---@param wideBuf ffi.cdata* # (LPWSTR) widebyte string itself
---@param wideLen integer # widebyte string's length
---@return string
function OSExt.Win32.wideToLuaString(wideBuf, wideLen)
    local len = OSExt.Win32.Libs.kernel32.WideCharToMultiByte(OSExt.Win32.CP_UTF8, 0, wideBuf, wideLen, nil, 0, nil, nil)
    if len == 0 then OSExt.Win32.raiseLastError() end
    local buf = ffi.new("char[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.WideCharToMultiByte(OSExt.Win32.CP_UTF8, 0, wideBuf, wideLen, buf, len, nil, nil)
    if ret == 0 then OSExt.Win32.raiseLastError() end
    return ffi.string(buf, ret)
end
-- Converts a UTF-8 Lua string to a Win32 wide (UTF-16) string
-- (through MultiByteToWideChar instead of handling it ourselves)
---@param str string
---@return ffi.cdata* wideStr # (LPWSTR)
---@return integer wideLen # supposed length
function OSExt.Win32.luaToWideString(str)
    -- do not use utf8.len here
    local multiBuf = ffi.new("CHAR[?]", #str, str)
    local multiLen = #str+1
    local len = OSExt.Win32.Libs.kernel32.MultiByteToWideChar(OSExt.Win32.CP_UTF8, 0, multiBuf, multiLen, nil, 0)
    if len == 0 then OSExt.Win32.raiseLastError() end
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.MultiByteToWideChar(OSExt.Win32.CP_UTF8, 0, multiBuf, multiLen, buf, len)
    if ret == 0 then OSExt.Win32.raiseLastError() end
    return buf, ret
end

ffi.cdef[[
    DWORD FormatMessageW(
        DWORD dwFlags,
        LPCVOID lpSource,
        DWORD dwMessageId,
        DWORD dwLanguageId,
        LPWSTR lpBuffer,
        DWORD nSize,
        va_list *Arguments
    );
]]
OSExt.Win32.FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
OSExt.Win32.FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
OSExt.Win32.FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
-- For obtaining a user-facing message corresponding to a HRESULT \
-- Note that there may be a trailing newline
---@param messageId integer # the HRESULT
---@param languageId? integer # desired language of the resulting string, defaults to English (US)
function OSExt.Win32.getSystemMessage(messageId, languageId)
    -- usually we shouldn't care about locale, but stock fonts have a limited charset
    languageId = languageId or 0x0409 -- MAKELANGID(LANG_ENGLISH,SUBLANG_ENGLISH_US)

    -- FIXME: let the system allocate the buffer
    local temp_dchar_len = 8192
    local buf = ffi.new("WCHAR[?]", temp_dchar_len)
    local len = OSExt.Win32.Libs.kernel32.FormatMessageW(
        bit.bor(
            OSExt.Win32.FORMAT_MESSAGE_FROM_SYSTEM,
            OSExt.Win32.FORMAT_MESSAGE_IGNORE_INSERTS--[[,
            OSExt.Win32.FORMAT_MESSAGE_ALLOCATE_BUFFER]]
        ), nil,
        messageId, languageId,
        buf, temp_dchar_len - 1,
        nil
    )
    if len == 0 then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        -- guard against stack overflow
        OSExt.Win32.raiseLuaError(e, not Utils.containsValue({
            OSExt.Win32.HResults.ERROR_INVALID_PARAMETER
        }, e))
    end
    return OSExt.Win32.wideToLuaString(buf, len)
end
-- {@func OSExt.Win32.getSystemMessage} which automatically trims trailing newlines
---@overload fun(messageId: integer, languageId?: integer)
function OSExt.Win32.getSystemMessageTrimmed(...)
    local rawMessage = OSExt.Win32.getSystemMessage(...)
    local len = utf8.len(rawMessage)
    if Utils.sub(rawMessage, len-1, len) == "\r\n" then
        rawMessage = Utils.sub(rawMessage, 1, len-2)
    end
    return rawMessage
end

ffi.cdef[[
    DWORD GetLastError();
]]

-- Raises a Lua error from a Win32 API error
---@param w32Error integer # the HRESULT
---@param format? boolean # whether to get a readable error message or not
function OSExt.Win32.raiseLuaError(w32Error, format)
    if format == nil then format = true end
    if w32Error ~= OSExt.Win32.HResults.ERROR_SUCCESS then
        local message = ""
        if format then
            message = OSExt.Win32.getSystemMessageTrimmed(w32Error) .. " "
        end
        error(string.format("Windows API operation failed with error: %s(0x%08x)", message, w32Error))
    end
end
-- Raises a Lua error from the last Win32 API error
---@param format? boolean # whether to get a readable error message or not
function OSExt.Win32.raiseLastError(format)
    OSExt.Win32.raiseLuaError(OSExt.Win32.Libs.kernel32.GetLastError(), format)
end

ffi.cdef[[
    HANDLE GetCurrentProcess();
    BOOL IsWow64Process(HANDLE hProcess, PBOOL Wow64Process);
]]

-- For obtaining a pseudo handle to the current process
---@return OSExt.Win32.HANDLE handle # (normally INVALID_HANDLE_VALUE)
function OSExt.Win32.getCurrentProcess()
    return OSExt.Win32.Libs.kernel32.GetCurrentProcess()
end

-- Checks whether a process is running with x86-32 compat layer or not
---@param process? OSExt.Win32.HANDLE # process handle, defaults to the game
---@return boolean
function OSExt.Win32.isWow64Process(process)
    process = process or OSExt.Win32.getCurrentProcess()

    local isWow64 = ffi.new("BOOL[1]", false)
    local ret = OSExt.Win32.Libs.kernel32.IsWow64Process(process, isWow64)
    if not ret then OSExt.Win32.raiseLastError() end
    return isWow64[0]
end

---@enum OSExt.Win32.COMPUTER_NAME_FORMAT
OSExt.Win32.COMPUTER_NAME_FORMAT = {
    netBIOS = 0,
    dnsHostname = 1,
    dnsDomain = 2,
    dnsFullyQualified = 3,
    physicalNetBIOS = 4,
    physicalDnsHostname = 5,
    physicalDnsDomain = 6,
    physicalDnsFullyQualified = 7
}

ffi.cdef[[
    typedef int COMPUTER_NAME_FORMAT;

    BOOL GetComputerNameExW(COMPUTER_NAME_FORMAT NameType, LPWSTR lpBuffer, LPDWORD nSize);
]]

-- Gets the name of the computer that is running the game,
-- in a specific format if needed
---@param nameFormat OSExt.Win32.EXTENDED_NAME_FORMAT # defaults to netBIOS
function OSExt.Win32.getComputerName(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.COMPUTER_NAME_FORMAT.netBIOS

    local len = 1024
    local buf = ffi.new("WCHAR[?]", len)
    local lenBuf = ffi.new("DWORD[1]", len-1) -- seriously
    local ret = OSExt.Win32.Libs.kernel32.GetComputerNameExW(nameFormat, buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        if e == OSExt.Win32.HResults.ERROR_MORE_DATA then
            error("Internal error - buffer is too small, my fault")
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.wideToLuaString(buf, len-1)
end
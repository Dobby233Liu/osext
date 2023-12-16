local ffi = require("ffi")
local bit = require("bit")

-- General Win32 interactions
local win32 = {}
OSExt.Win32 = win32

win32.Libs = {}
win32.Libs.kernel32 = ffi.load("kernel32")
if not win32.Libs.kernel32 then
    error("kernel32 not available?!")
end

win32.HResults = {
    ERROR_SUCCESS = 0,
    ERROR_INVALID_PARAMETER = 0x57,
    ERROR_MORE_DATA = 0xea,
    ERROR_MR_MID_NOT_FOUND = 0x13d
}

---@alias OSExt.Win32.DWORD ffi.cdata*
ffi.cdef[[
    typedef unsigned int UINT;
    typedef unsigned long DWORD;
    typedef unsigned long *PULONG;
]]

---@alias OSExt.Win32.BOOL ffi.cdata*
ffi.cdef[[
    // 0=false 1=true
    typedef bool BOOL;
    typedef BOOL BOOLEAN;
    typedef BOOL *PBOOL;
    typedef BOOL *LPBOOL;
]]

---@alias OSExt.Win32.HANDLE ffi.cdata*
ffi.cdef[[
    typedef void *HANDLE;

    BOOL CloseHandle(HANDLE hObject);
]]
win32.HANDLE = ffi.typeof("HANDLE")
-- A handle that is invalid
---@type OSExt.Win32.HANDLE
win32.INVALID_HANDLE_VALUE = ffi.cast(win32.HANDLE, -1)
-- Makes a handle cdata that is automatically GC'd
---@param handle ffi.cdata*
---@return OSExt.Win32.HANDLE
function win32.makeHandle(handle)
    handle = ffi.cast(win32.HANDLE, handle)
    if handle == win32.INVALID_HANDLE_VALUE then return handle end
    return ffi.gc(handle, win32.Libs.kernel32.CloseHandle)
end

ffi.cdef[[
    typedef wchar_t WCHAR;
    typedef WCHAR *LPWSTR;
    typedef char CHAR;
    typedef CHAR *LPSTR;
    typedef const char *LPCCH;
    typedef const wchar_t *LPCWCH;
    
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
win32.CP_UTF8 = 65001
-- Converts a Win32 wide (UTF-16) string to a UTF-8 Lua string
-- (through WideCharToMultiByte instead of handling it ourselves)
---@param wideBuf ffi.cdata* # (LPWSTR) widebyte string itself
---@param wideLen integer # widebyte string's length (counting \0 I think?)
---@return string
function win32.wideToLuaString(wideBuf, wideLen)
    local len = win32.Libs.kernel32.WideCharToMultiByte(win32.CP_UTF8, 0, wideBuf, wideLen, nil, 0, nil, nil)
    if len == 0 then win32.raiseLastError() end
    local buf = ffi.new("char[?]", len)
    local ret = win32.Libs.kernel32.WideCharToMultiByte(win32.CP_UTF8, 0, wideBuf, wideLen, buf, len, nil, nil)
    if ret == 0 then win32.raiseLastError() end
    return ffi.string(buf, ret)
end
-- Converts a UTF-8 Lua string to a Win32 wide (UTF-16) string
-- (through MultiByteToWideChar instead of handling it ourselves)
---@param str string
---@return ffi.cdata* wideStr # (LPWSTR)
---@return integer wideLen # supposed length
function win32.luaToWideString(str)
    -- do not use utf8.len here
    local multiBuf = ffi.new("CHAR[?]", #str, str)
    local multiLen = #str+1
    local len = win32.Libs.kernel32.MultiByteToWideChar(win32.CP_UTF8, 0, multiBuf, multiLen, nil, 0)
    if len == 0 then win32.raiseLastError() end
    local buf = ffi.new("WCHAR[?]", len)
    local ret = win32.Libs.kernel32.MultiByteToWideChar(win32.CP_UTF8, 0, multiBuf, multiLen, buf, len)
    if ret == 0 then win32.raiseLastError() end
    return buf, ret
end

ffi.cdef[[
    typedef const void *LPCVOID;

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
win32.FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
win32.FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
win32.FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
-- For obtaining a user-facing message corresponding to a HRESULT
-- Note that there may be a trailing newline
---@param messageId integer # the HRESULT
---@param languageId? integer # desired language of the resulting string, defaults to English (US)
function win32.getSystemMessage(messageId, languageId)
    -- usually we shouldn't care about locale, but stock fonts have a limited charset
    languageId = languageId or 0x0409 -- MAKELANGID(LANG_ENGLISH,SUBLANG_ENGLISH_US)

    -- FIXME: let the system allocate the buffer
    local temp_dchar_len = 32768
    local buf = ffi.new("WCHAR[?]", temp_dchar_len)
    local ret = win32.Libs.kernel32.FormatMessageW(
        bit.bor(
            win32.FORMAT_MESSAGE_FROM_SYSTEM,
            win32.FORMAT_MESSAGE_IGNORE_INSERTS--[[,
            win32.FORMAT_MESSAGE_ALLOCATE_BUFFER]]
        ), nil,
        messageId, languageId,
        buf, temp_dchar_len - 1,
        nil
    )
    if ret == 0 then
        local e = win32.Libs.kernel32.GetLastError()
        -- guard against stack overflow
        win32.raiseLuaError(e, not Utils.containsValue({
            win32.HResults.ERROR_INVALID_PARAMETER
        }, e))
    end
    return win32.widetoLuaString(buf, ret)
end
-- {@func OSExt.Win32.getSystemMessage} which automatically trims trailing newlines
---@overload fun(messageId: integer, languageId?: integer)
function win32.getSystemMessageTrimmed(...)
    local rawMessage = win32.getSystemMessage(...)
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
function win32.raiseLuaError(w32Error, format)
    if format == nil then format = true end
    if w32Error ~= win32.HResults.ERROR_SUCCESS then
        local message = ""
        if format then
            message = win32.getSystemMessageTrimmed(w32Error) .. " "
        end
        error(string.format("Windows API operation failed with error: %s(0x%08x)", message, w32Error))
    end
end
-- Raises a Lua error from the last Win32 API error
---@param format? boolean # whether to get a readable error message or not
function win32.raiseLastError(format)
    win32.raiseLuaError(win32.Libs.kernel32.GetLastError(), format)
end

ffi.cdef[[
    HANDLE GetCurrentProcess();
    BOOL IsWow64Process(HANDLE hProcess, PBOOL Wow64Process);
]]

-- For obtaining a pseudo handle to the current process
---@return OSExt.Win32.HANDLE handle # (normally INVALID_HANDLE_VALUE)
function win32.getCurrentProcess()
    return win32.Libs.kernel32.GetCurrentProcess()
end

-- Checks whether a process is running with x86-32 compat layer or not
---@param process? OSExt.Win32.HANDLE # process handle, defaults to the game
---@return boolean
function win32.isWow64Process(process)
    process = process or win32.getCurrentProcess()

    local isWow64 = ffi.new("BOOL[1]", false)
    local ret = win32.Libs.kernel32.IsWow64Process(process, isWow64)
    if ret ~= 0 then win32.raiseLastError() end
    return isWow64[0] == 0
end

libRequire("osext", "win32/psapi")
libRequire("osext", "win32/secext")
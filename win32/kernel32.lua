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
function OSExt.Win32.markHandleForGC(handle)
    handle = ffi.cast(OSExt.Win32.HANDLE, handle)
    if handle == OSExt.Win32.INVALID_HANDLE_VALUE then return handle end
    return ffi.gc(handle, OSExt.Win32.Libs.kernel32.CloseHandle)
end

ffi.cdef[[
    HLOCAL LocalFree(HLOCAL hMem);
]]

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
    local buf = ffi.new("char[?]", len+1)
    local ret = OSExt.Win32.Libs.kernel32.WideCharToMultiByte(OSExt.Win32.CP_UTF8, 0, wideBuf, wideLen, buf, len+1, nil, nil)
    if ret == 0 then OSExt.Win32.raiseLastError() end
    return ffi.string(buf) -- result is probably null-terminated
end
-- Converts a UTF-8 Lua string to a Win32 wide (UTF-16) string
-- (through MultiByteToWideChar instead of handling it ourselves)
---@param str string
---@return ffi.cdata* wideStr # (LPWSTR)
---@return integer wideLen # supposed length
function OSExt.Win32.luaToWideString(str)
    -- do not use utf8.len here
    local multiBuf = ffi.new("CHAR[?]", #str+1, str)
    local multiLen = #str
    local len = OSExt.Win32.Libs.kernel32.MultiByteToWideChar(OSExt.Win32.CP_UTF8, 0, multiBuf, multiLen, nil, 0)
    if len == 0 then OSExt.Win32.raiseLastError() end
    local buf = ffi.new("WCHAR[?]", len)
    local ret = OSExt.Win32.Libs.kernel32.MultiByteToWideChar(OSExt.Win32.CP_UTF8, 0, multiBuf, multiLen, buf, len)
    if ret == 0 then OSExt.Win32.raiseLastError() end
    return buf, ret
end

ffi.cdef[[
    HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
]]
-- Loads a DLL
---@param path string
---@return OSExt.Win32.HMODULE?
function OSExt.Win32.loadLibrary(path)
    local pathWstr, _ = OSExt.Win32.luaToWideString(path)
    local module = OSExt.Win32.Libs.kernel32.LoadLibraryW(pathWstr)
    if not module then
        local e = OSExt.Win32.getLastWin32Error()
        if e == OSExt.Win32.Win32Errors.ERROR_FILE_NOT_FOUND then
            return nil
        end
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.markHandleForGC(module)
end

ffi.cdef[[
    DWORD FormatMessageW(
        DWORD dwFlags,
        LPCVOID lpSource,
        DWORD dwMessageId,
        DWORD dwLanguageId,
        // FIXME: If this is left be LPWSTR then ffi will try to convert this to ushort*
        ULONG_PTR lpBuffer,
        DWORD nSize,
        va_list *Arguments
    );
]]
OSExt.Win32.FormatMessageFlags = {
    fromSystem = 0x00001000,
    fromHModule = 0x00000800,
    ignoreInserts = 0x00000200,
    allocateBuffer = 0x00000100
}
-- For obtaining a user-facing message corresponding, either from the system or from a module \
-- Note that there may be a trailing newline
---@param messageId integer # message ID; when module is nil, the status (win32 error, hresult)
---@param languageId? integer # desired language of the resulting string, defaults to English (US)
---@param module? OSExt.Win32.HMODULE # module handle, defaults to nil (system)
---@param systemFallback? boolean # whether to fallback to the system. recommended if querying from ntdll
function OSExt.Win32.getMessage(messageId, languageId, module, systemFallback)
    -- usually we shouldn't care about locale, but stock fonts have a limited charset
    languageId = languageId or 0x0409 -- MAKELANGID(LANG_ENGLISH,SUBLANG_ENGLISH_US)

    local buf = ffi.new("uintptr_t[1]")
    local flags = bit.bor(
        -- TODO: support arguments
        OSExt.Win32.FormatMessageFlags.ignoreInserts,
        OSExt.Win32.FormatMessageFlags.allocateBuffer
    )
    if module then
        flags = bit.bor(flags, OSExt.Win32.FormatMessageFlags.fromHModule)
    end
    if not module or systemFallback then
        flags = bit.bor(flags, OSExt.Win32.FormatMessageFlags.fromSystem)
    end
    local len = OSExt.Win32.Libs.kernel32.FormatMessageW(
        flags, module,
        messageId, languageId,
        ffi.cast("uintptr_t", buf), 512,
        nil
    )
    if len == 0 then
        local e = OSExt.Win32.getLastWin32Error()
        -- guard against stack overflow
        OSExt.Win32.raiseLuaError(e, not Utils.containsValue({
            OSExt.Win32.Win32Errors.ERROR_INVALID_PARAMETER
        }, e))
        return
    end
    local strPtr = ffi.cast("WCHAR*", buf[0])
    ffi.gc(strPtr, OSExt.Win32.Libs.kernel32.LocalFree)
    local ret = OSExt.Win32.wideToLuaString(strPtr, len)
    return ret
end
-- [getSystemMessage](lua://OSExt.Win32.getSystemMessage) which automatically trims trailing newlines
---@overload fun(messageId: integer, languageId?: integer)
function OSExt.Win32.getMessageTrimmed(...)
    local rawMessage = OSExt.Win32.getMessage(...)
    local len = utf8.len(rawMessage)
    if Utils.sub(rawMessage, len-1, len) == "\r\n" then
        rawMessage = Utils.sub(rawMessage, 1, len-2)
    end
    return rawMessage
end


ffi.cdef[[
    DWORD GetLastError();
    void SetLastError(DWORD dwErrCode);
]]

-- Gets the last Win32 error in integer format
function OSExt.Win32.getLastWin32Error()
    return OSExt.Win32.Libs.kernel32.GetLastError()
end

libRequire("osext", "win32/dataclasses/status")

-- Sets the last Win32 error
---@param err integer|OSExt.Win32.Status
function OSExt.Win32.setLastWin32Error(err)
    if isClass(err) and err:includes(OSExt.Win32.Status) then
        return err:setAsWin32Error()
    end
    return OSExt.Win32.Libs.kernel32.SetLastError(err)
end

-- Makes a friendly error string from a Win32 API error
---@param w32Error integer # the Win32 error
---@param format? boolean # whether to get a readable error message or not
function OSExt.Win32.makeErrorString(w32Error, format)
    if format == nil then format = true end
    local message = ""
    if format then
        message = OSExt.Win32.getMessageTrimmed(w32Error) .. " "
    end
    return string.format("Windows API operation failed with error: %s(0x%08x)", message, w32Error)
end
-- Raises a Lua error from a Win32 API error
---@param w32Error integer # the Win32 error
---@param format? boolean # whether to get a readable error message or not
function OSExt.Win32.raiseLuaError(w32Error, format)
    if w32Error ~= OSExt.Win32.Win32Errors.ERROR_SUCCESS then
        error(OSExt.Win32.makeErrorString(w32Error, format))
    end
end
-- Raises a Lua error from the last Win32 API error
---@param format? boolean # whether to get a readable error message or not
function OSExt.Win32.raiseLastError(format)
    OSExt.Win32.raiseLuaError(OSExt.Win32.getLastWin32Error(), format)
end

ffi.cdef[[
    HANDLE GetCurrentProcess();
    DWORD GetCurrentProcessId();
    BOOL IsWow64Process(HANDLE hProcess, PBOOL Wow64Process);
]]

-- For obtaining a pseudo handle to the current process
---@return OSExt.Win32.HANDLE handle # (can be INVALID_HANDLE_VALUE)
function OSExt.Win32.getCurrentProcess()
    return OSExt.Win32.Libs.kernel32.GetCurrentProcess()
end

-- Returns the PID of the current process
function OSExt.Win32.getCurrentProcessId()
    return OSExt.Win32.Libs.kernel32.GetCurrentProcessId()
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

---@enum OSExt.Win32.ComputerNameFormat
OSExt.Win32.ComputerNameFormat = {
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
---@param nameFormat? OSExt.Win32.ComputerNameFormat # defaults to netBIOS
function OSExt.Win32.getComputerName(nameFormat)
    nameFormat = nameFormat or OSExt.Win32.ComputerNameFormat.netBIOS

    local len = 256
    local buf = ffi.new("WCHAR[?]", len+1)
    local lenBuf = ffi.new("DWORD[1]", len+1)
    local ret = OSExt.Win32.Libs.kernel32.GetComputerNameExW(nameFormat, buf, lenBuf)
    if not ret then
        local e = OSExt.Win32.getLastWin32Error()
        if e == OSExt.Win32.Win32Errors.ERROR_MORE_DATA then
            buf = ffi.new("WCHAR[?]", lenBuf[0])
            ret = OSExt.Win32.Libs.kernel32.GetComputerNameExW(nameFormat, buf, lenBuf)
            e = ret and OSExt.Win32.getLastWin32Error() or OSExt.Win32.Win32Errors.ERROR_SUCCESS
        end
        if e ~= OSExt.Win32.Win32Errors.ERROR_SUCCESS then
            OSExt.Win32.raiseLuaError(e)
        end
    end
    return OSExt.Win32.wideToLuaString(buf, lenBuf[0])
end


OSExt.Win32.AccessRights = {
    delete = 0x00010000,
    readControl = 0x00020000,
    writeDAC = 0x00040000,
    writeOwner = 0x00080000,
    synchronize = 0x00100000
}
OSExt.Win32.AccessRights.standardRightsRequired = bit.bor(
    OSExt.Win32.AccessRights.delete,
    OSExt.Win32.AccessRights.readControl,
    OSExt.Win32.AccessRights.writeDAC,
    OSExt.Win32.AccessRights.writeOwner
)
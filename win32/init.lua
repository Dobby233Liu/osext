local ffi = require("ffi")

-- Win32 interfaces
--
-- Most stuff in the root scope comes from kernel32
OSExt.Win32 = {}

OSExt.Win32.Libs = {}

ffi.cdef[[
    typedef uint8_t BYTE;
    typedef unsigned char UCHAR;
    typedef unsigned short USHORT;
    typedef unsigned int UINT;
    typedef unsigned long DWORD;
    typedef unsigned long *PDWORD;
    typedef unsigned long *LPDWORD;
    typedef unsigned long ULONG;
    typedef unsigned long *PULONG;
    typedef uintptr_t ULONG_PTR;
    typedef ULONG_PTR SIZE_T;
    typedef long LONG;
]]
---@alias OSExt.Win32.DWORD ffi.cdata*

ffi.cdef[[
    // 0=false 1=true
    typedef bool BOOL;
    typedef BOOL BOOLEAN;

    typedef BOOL *PBOOL;
    typedef BOOL *LPBOOL;
]]
---@alias OSExt.Win32.BOOL ffi.cdata*

ffi.cdef[[
    typedef wchar_t WCHAR;
    typedef WCHAR *LPWSTR;
    typedef const WCHAR *LPCWSTR;

    typedef char CHAR;
    typedef CHAR *LPSTR;

    typedef const char *LPCCH;
    typedef const wchar_t *LPCWCH;
]]

ffi.cdef[[
    typedef void *HANDLE;
]]
---@alias OSExt.Win32.HANDLE ffi.cdata*
OSExt.Win32.HANDLE = ffi.typeof("HANDLE")
-- A handle that is invalid
---@type OSExt.Win32.HANDLE
OSExt.Win32.INVALID_HANDLE_VALUE = ffi.cast(OSExt.Win32.HANDLE, -1)
ffi.cdef[[
    typedef HANDLE HLOCAL;
    typedef HANDLE HINSTANCE;
    typedef HINSTANCE HMODULE;
]]
---@alias OSExt.Win32.HINSTANCE ffi.cdata*
---@alias OSExt.Win32.HMODULE OSExt.Win32.HINSTANCE

ffi.cdef[[
    typedef void *LPVOID;
    typedef const void *LPCVOID;
]]

if not OSExt._typeExists("char[MAX_PATH]") then
    ffi.cdef[[
        enum { MAX_PATH = 260 };
    ]]
end
if not OSExt._typeExists("char[MAX_MODULE_NAME32]") then
    ffi.cdef[[
        enum { MAX_MODULE_NAME32 = 255 }
    ]]
end

OSExt.Win32.MAX_PATH = 260
OSExt.Win32.MAX_MODULE_NAME32 = 255

ffi.cdef[[
    typedef LONG HRESULT;
    typedef LONG NTSTATUS;
]]
OSExt.Win32.Win32Errors = {
    ERROR_SUCCESS = 0,
    ERROR_NO_MORE_FILES = 0x12,
    ERROR_INVALID_PARAMETER = 0x57,
    ERROR_MORE_DATA = 0xea,
    ERROR_PARTIAL_COPY = 0x12b,
    ERROR_MR_MID_NOT_FOUND = 0x13d
}
OSExt.Win32.NtStatuses = {
    STATUS_SUCCESS = 0
}
OSExt.Win32.HResultFacilities = {
    FACILITY_WIN32 = 7
}
OSExt.Win32.NtStatusFacilities = {
    FACILITY_NTWIN32 = 7
}

libRequire("osext", "win32/kernel32")
libRequire("osext", "win32/ntdll")
libRequire("osext", "win32/advapi32")
libRequire("osext", "win32/secur32")
libRequire("osext", "win32/psapi")
libRequire("osext", "win32/toolhelp32")
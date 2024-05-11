local ffi = require("ffi")

-- General Win32 interactions
--
-- Most stuff in the root scope comes from kernel32
OSExt.Win32 = {}

OSExt.Win32.Libs = {}

ffi.cdef[[
    typedef unsigned int UINT;
    typedef unsigned long DWORD;
    typedef unsigned long *LPDWORD;
    typedef unsigned long *PULONG;
    typedef unsigned long ULONG_PTR;
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
    typedef const void *LPCVOID;
]]

ffi.cdef[[
    typedef LONG HRESULT;
    typedef LONG NTSTATUS;
]]
OSExt.Win32.HResults = {
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
OSExt.Win32.NtStatusFacilities = {
    FACILITY_WIN32 = 7
}

libRequire("osext", "win32/ntdll")
libRequire("osext", "win32/kernel32")
libRequire("osext", "win32/advapi32")
libRequire("osext", "win32/secext")
libRequire("osext", "win32/psapi")
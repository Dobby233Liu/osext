local ffi = require("ffi")

-- Think of this like hidden system APIs that are not in kernel32
OSExt.Win32.NtSysApi = {}

if not OSExt._typeExists("OSVERSIONINFOEXW") then
    ffi.cdef[[
        typedef struct _OSVERSIONINFOEXW {
            ULONG dwOSVersionInfoSize;
            ULONG dwMajorVersion;
            ULONG dwMinorVersion;
            ULONG dwBuildNumber;
            ULONG dwPlatformId;
            WCHAR szCSDVersion[128];
            USHORT wServicePackMajor;
            USHORT wServicePackMinor;
            USHORT wSuiteMask;
            UCHAR wProductType;
            UCHAR wReserved;
        } OSVERSIONINFOEXW, *LPOSVERSIONINFOEXW;
    ]]
end
---@class OSExt.Win32.OSVERSIONINFOEX : ffi.cdata*
---@field dwOSVersionInfoSize integer
---@field dwMajorVersion integer
---@field dwMinorVersion integer
---@field dwBuildNumber integer
---@field dwPlatformId integer
---@field szCSDVersion ffi.cdata* # TODO
---@field wServicePackMajor integer
---@field wServicePackMinor integer
---@field wSuiteMask integer
---@field wProductType integer
---@field wReserved integer
ffi.cdef[[
    NTSTATUS RtlGetVersion(LPOSVERSIONINFOEXW lpVersionInformation);
]]

-- For obtaining the OS version \
-- Compared to WINBASEAPI GetVersionEx, this returns the true version in Windows 10+
---@return OSExt.Win32.OSVERSIONINFOEX?
function OSExt.Win32.NtSysApi.getVersion()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local info = ffi.new("OSVERSIONINFOEXW") ---@type OSExt.Win32.OSVERSIONINFOEX
    info.dwOSVersionInfoSize = ffi.sizeof(info)
    local ret = OSExt.Win32.Status.fromNtStatus(OSExt.Win32.Libs.ntdll.RtlGetVersion(info))
    if ret.severity ~= OSExt.Win32.Status.SEVERITY.success then
        ret:raise()
    end
    return info
end
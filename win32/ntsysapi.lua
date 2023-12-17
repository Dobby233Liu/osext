local ffi = require("ffi")

-- Think of this like hidden system APIs that are not in kernel32
OSExt.Win32.NtSysApi = {}

OSExt.Win32.Libs.ntdll = ffi.load("ntdll")
if not OSExt.Win32.Libs.ntdll then
    error("ntdll not available?!")
end

-- Raises a Lua error from a NTSTATUS (temporary, TODO)
function OSExt.Win32.NtSysApi.raiseLuaError(status)
    if status ~= OSExt.Win32.NtStatuses.STATUS_SUCCESS then
        error(string.format("NTSYSAPI operation resulted in NTSTATUS %08x", status))
    end
end

---@alias OSExt.Win32.OSVERSIONINFO ffi.cdata*
if not ffi.typeof("OSVERSIONINFOW") then
    ffi.cdef[[
        typedef struct _OSVERSIONINFOW {
            DWORD dwOSVersionInfoSize;
            DWORD dwMajorVersion;
            DWORD dwMinorVersion;
            DWORD dwBuildNumber;
            DWORD dwPlatformId;
            WCHAR szCSDVersion[128];
        } OSVERSIONINFOW, *LPOSVERSIONINFOW;
    ]]
end
ffi.cdef[[
    NTSTATUS RtlGetVersion(LPOSVERSIONINFOW lpVersionInformation);
]]

-- For obtaining the OS version \
-- Compared to WINBASEAPI GetVersionEx, this returns the true version in Windows 10+
---@return OSExt.Win32.OSVERSIONINFO
function OSExt.Win32.NtSysApi.getVersion()
    local info = ffi.new("OSVERSIONINFOW[1]")
    info[0].dwOSVersionInfoSize = ffi.sizeof(info[0])
    local ret = OSExt.Win32.Libs.ntdll.RtlGetVersion(info[0])
    if ret ~= OSExt.Win32.NtStatuses.STATUS_SUCCESS then
        OSExt.Win32.NtSysApi.raiseLuaError(ret)
    end
    return info[0]
end
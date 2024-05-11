local ffi = require "ffi"
local bit = require "bit"

-- Implements the majority of tlhelp32's interface
--
-- This provides information about currently executing applications
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/toolhelp/tool-help-library)
OSExt.Win32.ToolHelp = {}

OSExt.Win32.Libs.tlhelp32 = ffi.load("tlhelp32")
if not OSExt.Win32.Libs.tlhelp32 then
    print("tlhelp32 not available")
    return
end

OSExt.Win32.ToolHelp.SnapshotContents = {
    heapList = 0x00000001,
    moduleList = 0x00000008,
    module32List = 0x00000010,
    processList = 0x00000002,
    threadList = 0x00000004,
    returnInheritableHandle = 0x80000000
}
OSExt.Win32.ToolHelp.SnapshotContents.all = bit.bor(
    OSExt.Win32.ToolHelp.SnapshotContents.heapList,
    OSExt.Win32.ToolHelp.SnapshotContents.moduleList,
    OSExt.Win32.ToolHelp.SnapshotContents.processList,
    OSExt.Win32.ToolHelp.SnapshotContents.threadList
)


ffi.cdef[[
    HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
]]

-- Takes a snapshot of the specified processes, as well as the heaps, modules, and threads used by these processes.
---@param pid integer # The PID of the process to be included in the snapshot, can be and defaults to \
--- zero to indicate the current process. Used when one of heapList, moduleList, or module32List is being queried, \
--- otherwise all processes will be included.
---@return OSExt.Win32.HANDLE snapshot
function OSExt.Win32.ToolHelp.createSnapshot(contents, pid)
    pid = pid or 0

    local ret = OSExt.Win32.Libs.tlhelp32.CreateToolhelp32Snapshot(contents, pid)
    if not ret then
        local e = OSExt.Win32.Libs.kernel32.GetLastError()
        -- TODO: ERROR_PARTIAL_COPY
        OSExt.Win32.raiseLuaError(e)
    end
    return OSExt.Win32.makeHandle(ret)
end


if not OSExt._typeExists("HEAPLIST32") then
    ffi.cdef[[
        typedef struct {
            SIZE_T    dwSize;
            DWORD     th32ProcessID;
            ULONG_PTR th32HeapID;
            DWORD     dwFlags;
        } HEAPLIST32;
    ]]
end
OSExt.Win32.ToolHelp.HF32_DEFAULT = 1
if not OSExt._typeExists("HEAPENTRY32") then
    ffi.cdef[[
        typedef struct {
            SIZE_T    dwSize;
            HANDLE    hHandle;
            ULONG_PTR dwAddress;
            SIZE_T    dwBlockSize;
            DWORD     dwFlags;
            DWORD     dwLockCount;
            DWORD     dwResvd;
            DWORD     th32ProcessID;
            ULONG_PTR th32HeapID;
        } HEAPENTRY32;
    ]]
end

function OSExt.Win32.ToolHelp.iterSnapshotHeapList(snapshot)
    local i = 0
    return function()
        i = i + 1
        local listInfo = ffi.new("HEAPLIST32[1]")
        listInfo[0].dwSize = ffi.sizeof(listInfo[0])
        -- WIP
    end
end
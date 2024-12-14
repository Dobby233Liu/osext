---@diagnostic disable: inject-field
local ffi = require "ffi"
local bit = require "bit"

-- Implements the majority of tlhelp32's interface
--
-- This provides information about currently executing applications
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/toolhelp/tool-help-library)
OSExt.Win32.ToolHelp = {}

-- This is just kernel32 \
-- In 16-bit Windows TOOLHELP.dll provided these functionalities
OSExt.Win32.Libs.tlhelp32 = OSExt.Win32.Libs.kernel32

---@enum OSExt.Win32.ToolHelp.SnapshotContents
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


---@class OSExt.Win32.ToolHelp.Snapshot : Class
-- A snapshot of specific processes, as well as the heaps, modules, and threads used by these processes.
---@field private _handle ffi.cdata*
OSExt.Win32.ToolHelp.Snapshot = Class()


ffi.cdef[[
    HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
]]

-- Takes a snapshot of the specified processes.
---@param pid? integer # The PID of the process to be included in the snapshot, can be and defaults to \
--- zero to indicate the current process. Used when one of heapList, moduleList, or module32List is being queried, \
--- otherwise all processes will be included.
--- @param contents OSExt.Win32.ToolHelp.SnapshotContents # The contents of the snapshot.
function OSExt.Win32.ToolHelp.Snapshot:init(contents, pid)
    self.pid = pid or 0
    self.contents = contents

    self._handle = OSExt.Win32.markHandleForGC(OSExt.Win32.Libs.tlhelp32.CreateToolhelp32Snapshot(self.contents, self.pid))
    if self._handle == OSExt.Win32.INVALID_HANDLE_VALUE then
        local e = OSExt.Win32.getLastWin32Error()
        local msg = OSExt.Win32.makeErrorString(e)
        if e == OSExt.Win32.Win32Errors.ERROR_PARTIAL_COPY
            and (OSExt.Win32.isWow64Process()
                and not OSExt.Win32.isWow64Process(OSExt.Win32.openProcess(pid)))
        then
            msg = msg .. ". Note that a WoW64 process can't spy on a proper 64-bit process."
        end
        error(msg)
    end
end


if not OSExt._typeExists("HEAPLIST32") then
    ffi.cdef[[
        typedef struct tagHEAPLIST32 {
            SIZE_T    dwSize;
            DWORD     th32ProcessID;
            ULONG_PTR th32HeapID;
            DWORD     dwFlags;
        } HEAPLIST32, *LPHEAPLIST32;
    ]]
end
OSExt.Win32.ToolHelp.HF32_DEFAULT = 1
OSExt.Win32.ToolHelp.HF32_SHARED = 2
if not OSExt._typeExists("HEAPENTRY32") then
    ffi.cdef[[
        typedef struct tagHEAPENTRY32 {
            SIZE_T    dwSize;
            HANDLE    hHandle;
            ULONG_PTR dwAddress;
            SIZE_T    dwBlockSize;
            DWORD     dwFlags;
            DWORD     dwLockCount;
            DWORD     dwResvd;
            DWORD     th32ProcessID;
            ULONG_PTR th32HeapID;
        } HEAPENTRY32, *LPHEAPENTRY32;
    ]]
end
ffi.cdef[[
    BOOL Heap32ListFirst(HANDLE hSnapshot, LPHEAPLIST32 lphl);
    BOOL Heap32ListNext(HANDLE hSnapshot, LPHEAPLIST32 lphl);

    BOOL Heap32First(LPHEAPENTRY32 lphe, DWORD th32ProcessID, ULONG_PTR th32HeapID);
    BOOL Heap32Next(LPHEAPENTRY32 lphe);
]]

-- Iterator for heap lists in a ToolHelp snapshot
function OSExt.Win32.ToolHelp.Snapshot:iterHeapLists()
    local i = 0
    local info = ffi.new("HEAPLIST32")
    info.dwSize = ffi.sizeof(info)
    return function()
        i = i + 1
        local ret
        if i == 1 then
            ret = OSExt.Win32.Libs.tlhelp32.Heap32ListFirst(self._handle, info)
        else
            ret = OSExt.Win32.Libs.tlhelp32.Heap32ListNext(self._handle, info)
        end
        if not ret then
            local e = OSExt.Win32.getLastWin32Error()
            if e == OSExt.Win32.Win32Errors.ERROR_NO_MORE_FILES then
                return nil
            end
            OSExt.Win32.raiseLuaError(e)
        end
        info.dwSize = ffi.sizeof(info)
        return i, info
    end
end

-- Iterator for a heap list snapshotted by ToolHelp
function OSExt.Win32.ToolHelp.Snapshot:iterHeapList(heapList)
    -- FIXME: "If the target process dies, the system may create a new process using the same process identifier.
    -- "Therefore, the caller should maintain a reference to the target process as long as it is using Heap32Next."
    local i = 0
    local info
    return function()
        i = i + 1
        local ret
        if not info then
            info = ffi.new("HEAPENTRY32")
            info.dwSize = ffi.sizeof(info)
            ret = OSExt.Win32.Libs.tlhelp32.Heap32First(info, heapList.th32ProcessID, heapList.th32HeapID)
        else
            ret = OSExt.Win32.Libs.tlhelp32.Heap32Next(info)
        end
        if not ret then
            local e = OSExt.Win32.getLastWin32Error()
            if e == OSExt.Win32.Win32Errors.ERROR_NO_MORE_FILES then
                return nil
            end
            OSExt.Win32.raiseLuaError(e)
        end
        info.dwSize = ffi.sizeof(info)
        return i, info
    end
end


if not OSExt._typeExists("char[MAX_MODULE_NAME32 + 1]") then
    ffi.cdef[[
        enum { MAX_MODULE_NAME32 = 255 }
    ]]
end
if not OSExt._typeExists("MODULEENTRY32W") then
    ffi.cdef[[
        typedef struct tagMODULEENTRY32W {
            DWORD   dwSize;
            DWORD   th32ModuleID;
            DWORD   th32ProcessID;
            DWORD   GlblcntUsage;
            DWORD   ProccntUsage;
            BYTE    *modBaseAddr;
            DWORD   modBaseSize;
            HMODULE hModule;
            WCHAR   szModule[MAX_MODULE_NAME32 + 1];
            WCHAR   szExePath[MAX_PATH];
        } MODULEENTRY32W, *LPMODULEENTRY32W;
    ]]
end
ffi.cdef[[
    BOOL Module32FirstW(HANDLE hSnapshot, LPMODULEENTRY32W lpme);
    BOOL Module32NextW(HANDLE hSnapshot, LPMODULEENTRY32W lpme);
]]

-- Iterator for modules in a ToolHelp snapshot
function OSExt.Win32.ToolHelp.Snapshot:iterModules()
    local i = 0
    local info = ffi.new("MODULEENTRY32W")
    info.dwSize = ffi.sizeof(info)
    return function()
        i = i + 1
        local ret
        if i == 1 then
            ret = OSExt.Win32.Libs.tlhelp32.Module32FirstW(self._handle, info)
        else
            ret = OSExt.Win32.Libs.tlhelp32.Module32NextW(self._handle, info)
        end
        if not ret then
            local e = OSExt.Win32.getLastWin32Error()
            if e == OSExt.Win32.Win32Errors.ERROR_NO_MORE_FILES then
                return nil
            end
            OSExt.Win32.raiseLuaError(e)
        end
        info.dwSize = ffi.sizeof(info)
        return i, info
    end
end


if not OSExt._typeExists("PROCESSENTRY32W") then
    ffi.cdef[[
        typedef struct tagPROCESSENTRY32W {
            DWORD     dwSize;
            DWORD     cntUsage;
            DWORD     th32ProcessID;
            ULONG_PTR th32DefaultHeapID;
            DWORD     th32ModuleID;
            DWORD     cntThreads;
            DWORD     th32ParentProcessID;
            LONG      pcPriClassBase;
            DWORD     dwFlags;
            WCHAR     szExeFile[MAX_PATH];
        } PROCESSENTRY32W, *LPPROCESSENTRY32W;
    ]]
end
ffi.cdef[[
    BOOL Process32FirstW(HANDLE hSnapshot, LPPROCESSENTRY32W lppe);
    BOOL Process32NextW(HANDLE hSnapshot, LPPROCESSENTRY32W lppe);
]]

-- Iterator for processes in a ToolHelp snapshot
function OSExt.Win32.ToolHelp.Snapshot:iterProcesses()
    local i = 0
    local info = ffi.new("PROCESSENTRY32W")
    info.dwSize = ffi.sizeof(info)
    return function()
        i = i + 1
        local ret
        if i == 1 then
            ret = OSExt.Win32.Libs.tlhelp32.Process32FirstW(self._handle, info)
        else
            ret = OSExt.Win32.Libs.tlhelp32.Process32NextW(self._handle, info)
        end
        if not ret then
            local e = OSExt.Win32.getLastWin32Error()
            if e == OSExt.Win32.Win32Errors.ERROR_NO_MORE_FILES then
                return nil
            end
            OSExt.Win32.raiseLuaError(e)
        end
        info.dwSize = ffi.sizeof(info)
        return i, info
    end
end


if not OSExt._typeExists("THREADENTRY32") then
    ffi.cdef[[
        typedef struct tagTHREADENTRY32 {
            DWORD     dwSize;
            DWORD     cntUsage;
            DWORD     th32ThreadID;
            DWORD     th32OwnerProcessID;
            LONG      tpBasePri;
            LONG      tpDeltaPri;
            DWORD     dwFlags;
        } THREADENTRY32, *LPTHREADENTRY32;
    ]]
end
ffi.cdef[[
    BOOL Thread32First(HANDLE hSnapshot, LPTHREADENTRY32 lpte);
    BOOL Thread32Next(HANDLE hSnapshot, LPTHREADENTRY32 lpte);
]]

-- Iterator for threads in a ToolHelp snapshot
function OSExt.Win32.ToolHelp.Snapshot:iterThreads()
    local i = 0
    local info = ffi.new("THREADENTRY32")
    info.dwSize = ffi.sizeof(info)
    return function()
        i = i + 1
        local ret
        if i == 1 then
            ret = OSExt.Win32.Libs.tlhelp32.Thread32First(self._handle, info)
        else
            ret = OSExt.Win32.Libs.tlhelp32.Thread32Next(self._handle, info)
        end
        if not ret then
            local e = OSExt.Win32.getLastWin32Error()
            if e == OSExt.Win32.Win32Errors.ERROR_NO_MORE_FILES then
                return nil
            end
            OSExt.Win32.raiseLuaError(e)
        end
        info.dwSize = ffi.sizeof(info)
        return i, info
    end
end

-- ~~~~~~~~~~~~~~~~ end of OSExt.Win32.ToolHelp.Snapshot ~~~~~~~~~~~~~~~~


ffi.cdef[[
    BOOL Toolhelp32ReadProcessMemory(
        DWORD       th32ProcessID,
        LPCVOID     lpBaseAddress,
        // FIXME: ffi can't compherd LPCVOID
        ULONG_PTR   lpBuffer,
        SIZE_T      cbRead,
        SIZE_T      *lpNumberOfBytesRead
    );
]]

-- Reads size bytes at the specific base address of a process' memory
--
-- dunno why would you want this but whatever \
-- ReadProcessMemory would be more useful
function OSExt.Win32.ToolHelp.readProcessMemory(pid, address, size)
    local buffer = ffi.new("char[?]", size)
    local lenBuf = ffi.new("SIZE_T[1]", size)
    local result = OSExt.Win32.Libs.tlhelp32.Toolhelp32ReadProcessMemory(pid, address, buffer, size, lenBuf)
    if not result then
        OSExt.Win32.raiseLastError()
    end
    return buffer, lenBuf[0]
end


-- ~~~~~~~~~~~~~~~~ end of toolhelp API interop ~~~~~~~~~~~~~~~~


-- For obtaining a list of the currently running processes on the computer
---@return table names
function OSExt.Win32.getProcessNames()
    local snapshot = OSExt.Win32.ToolHelp.Snapshot(OSExt.Win32.ToolHelp.SnapshotContents.processList)
    local names = {}
    for _, process in snapshot:iterProcesses() do
        print(ffi.sizeof(process.szExeFile))
        table.insert(names, OSExt.Win32.wideToLuaString(process.szExeFile, ffi.sizeof(process.szExeFile)))
    end
    return names
end
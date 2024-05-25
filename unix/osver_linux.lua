local ffi = require "ffi"
local fs = OSExt.Unix.fs

-- TODO: lsb-release

OSExt.Unix.LinuxOSVer = {}

-- TODO: "Part of the utsname information is also accessible via /proc/sys/kernel/{ostype, hostname, osrelease,
--              version, domainname}."
if not OSExt._typeExists("struct utsname") then
    ffi.cdef[[
        struct utsname {
            char sysname[65];
            char nodename[65];
            char release[65];
            char version[65];
            char machine[65];
            char domainname[65];
        };
    ]]
end
ffi.cdef[[
    int uname(struct utsname *buf);
]]

-- Returns the name and information about the current kernel.
function OSExt.Unix.LinuxOSVer.getKernelVersion()
    local struc = ffi.new("struct utsname")
    local ret = ffi.C.uname(struc)
    if ret ~= 0 then OSExt.Unix.raiseLastError() end
    return {
        systemName = ffi.string(struc.sysname),
        nodeName = ffi.string(struc.nodename),
        release = ffi.string(struc.release),
        version = ffi.string(struc.version),
        machine = ffi.string(struc.machine),
        domainName = ffi.string(struc.domainname)
    }
end

local function parseBshKV(str)
    local ret = {}
    for _,line in ipairs(Utils.split(str, "\n")) do
        local k, v = line:match('^(%w+)=(?:"?)(.+?)(?:"?)$')
        if k and v then ret[k] = v end
    end
    return ret
end

-- Returns the content of the os-release file.
function OSExt.Unix.LinuxOSVer.getOSReleaseData()
    local function tryLoading(file)
        if not fs.is(file) then return nil end
        print(2)
        local osReleaseFile = fs.open(file, "r")
        print(2)
        local osReleaseStrBuf, osReleaseStrLen = osReleaseFile:readall()
        print(osReleaseStrBuf, osReleaseStrLen)
        local ret = ffi.string(osReleaseStrBuf, osReleaseStrLen)
        print(ret)
        osReleaseFile:close()
        print(2)
        return ret
    end
    local osReleaseStr = tryLoading("/etc/os-release")
    print(1)
    if not osReleaseStr then osReleaseStr = tryLoading("/usr/lib/os-release")
        print(1) end
    return parseBshKV(osReleaseStr)
end
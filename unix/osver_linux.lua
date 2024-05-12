local ffi = require "ffi"
local fs = libRequire("osext", "fslib/fs")

-- TODO: lsb-release

OSExt.Unix.LinuxOSVer = {}

-- Returns the content of /proc/version.
function OSExt.Unix.LinuxOSVer.getKernelVersion()
    local versionFile = fs.open("/proc/version", "r")
    local versionStrBuf, versionStrLen = versionFile:readall()
    versionFile:close()
    local versionStr = ffi.string(versionStrBuf, versionStrLen)
    return versionStr
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
        local osReleaseFile = fs.open(file, "r")
        local osReleaseStrBuf, osReleaseStrLen = osReleaseFile:readall()
        osReleaseFile:close()
        return ffi.string(osReleaseStrBuf, osReleaseStrLen)
    end
    local osReleaseStr = tryLoading("/etc/os-release")
    if not osReleaseStr then osReleaseStr = tryLoading("/usr/lib/os-release") end
    return parseBshKV(osReleaseStr)
end
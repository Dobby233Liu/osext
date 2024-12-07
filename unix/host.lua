local ffi = require "ffi"

-- Welp... hardcoded. I don't think there's a better way to do this.
-- null terminator included
OSExt.Unix.MAX_HOSTNAME = 64 + 1
OSExt.Unix.MAX_DOMAINNAME = 64 + 1

ffi.cdef[[
    int gethostname(char *name, size_t len);
    int getdomainname(char *name, size_t len);
]]

-- Gets the hostname of the machine.
---@return string hostName
function OSExt.Unix.getHostName()
    if ffi.os == "Linux" or not ffi.C.gethostname then
        -- on Linux glibc implements this by looking in uname
        return OSExt.Unix.LinuxOSVer.getKernelVersion().nodeName
    end

    local buf = ffi.new("char[?]", OSExt.Unix.MAX_HOSTNAME)
    local ok = ffi.C.gethostname(buf, OSExt.Unix.MAX_HOSTNAME)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    return ffi.string(buf)
end

-- Gets the domain name of the machine.
---@return string domainName
function OSExt.Unix.getDomainName()
    if ffi.os == "Linux" or not ffi.C.getdomainname then
        -- glibc implements this by looking in uname
        -- if the domainname field exists in utsname
        return OSExt.Unix.LinuxOSVer.getKernelVersion().domainName
    end

    local buf = ffi.new("char[?]", OSExt.Unix.MAX_DOMAINNAME)
    local ok = ffi.C.getdomainname(buf, OSExt.Unix.MAX_DOMAINNAME)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    return ffi.string(buf)
end
local ffi = require "ffi"

-- with null terminator

OSExt.Unix.MAX_HOSTNAME = 64 + 1
OSExt.Unix.MAX_DOMAINNAME = 64

ffi.cdef[[
    int gethostname(char *name, size_t len);
    int getdomainname(char *name, size_t len);
]]

-- Gets the hostname of the machine.
---@return string hostName
function OSExt.Unix.getHostName()
    print(1)
    local buf = ffi.new("char[?]", OSExt.Unix.MAX_HOSTNAME)
    print(1)
    local ok = ffi.C.gethostname(name, OSExt.Unix.MAX_HOSTNAME)
    print(1)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    print(1)
    return ffi.string(buf)
end

-- Gets the domain name of the machine.
---@return string domainName
function OSExt.Unix.getDomainName()
    local buf = ffi.new("char[?]", OSExt.Unix.MAX_DOMAINNAME)
    local ok = ffi.C.getdomainname(name, OSExt.Unix.MAX_DOMAINNAME)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    return ffi.string(buf)
end
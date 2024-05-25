local ffi = require "ffi"

if ffi.os == "Linux" then
    libRequire("osext", "unix/osver_linux")
end

ffi.cdef[[
    int uname(char *buf);
]]

-- FIXME: don't fucking do this
-- "Part of the utsname information is also accessible via /proc/sys/kernel/{ostype, hostname, osrelease, version, domainname}.""
function OSExt.Unix.getKernelVersion()
    -- this one is a gamble
    -- 5 entries x 65, not certain about the GNU extension
    local uname_raw = ffi.new("utsname_raw[?]", 65 * 5)
    local ok = ffi.C.uname(uname_raw)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    local keys = {"sysname", "nodename", "release", "version", "machine" --[[, "domainname" ]]}
    local ret = {}
    local pos = 0
    for _,key in ipairs(keys) do
        local str_here = ffi.string(uname_raw + pos)
        ret[key] = str_here
        pos = pos + #str_here + 1
    end
    return ret
end
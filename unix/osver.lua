local ffi = require "ffi"

if ffi.os == "Linux" then
    libRequire("osext", "unix/osver_linux")
end

if not OSExt._typeExists("utsname_raw") then
    ffi.cdef[[
        // 5 entries x 65
        // not certain about the GNU extension
        typedef char utsname_raw;
    ]]
end

ffi.cdef[[
    int uname(utsname_raw[325] *buf);
]]

function OSExt.Unix.getKernelVersion()
    -- this one is a gamble
    local uname_raw = ffi.new("utsname_raw[325]")
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
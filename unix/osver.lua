local ffi = require "ffi"

if ffi.os == "Linux" then
    libRequire("osext", "unix/osver_linux")
end

if not OSExt._typeExists("struct utsname") then
    ffi.cdef[[
        struct utsname {
            char *sysname;
            char *nodename;
            char *release;
            char *version;
            char *machine;
            char *domainname; /* GNU extension */
        };
    ]]
end

ffi.cdef[[
    int uname(struct utsname *buf);
]]

function OSExt.Unix.getKernelVersion()
    local uname = ffi.new("struct utsname")
    local ok = ffi.C.uname(uname)
    if ok ~= 0 then OSExt.Unix.raiseLastError() end
    local ret = {}
    for _,key in ipairs({"sysname", "nodename", "release", "version", "machine", "domainname"}) do
        if uname[key] then
            ret[key] = ffi.string(uname[key])
        end
    end
    return ret
end
local ffi = require "ffi"


-- HACK: Property sizes in struct utsname varies from system to system.
-- Without doing weird crap like loading system headers, we can't know the exact size.
-- So, we just assume it's 64 + 1 for each of the 5/6 fields; and instead of having a struct
-- definition, we just use a char* and split it by \0.
-- (For each entry's size Linux has 65, AIX has 32, and BSD/Solaris has 256,
--  so it's not like we can just assume 64 for all of them, but ffs I'm not
--  allocating that much memory...)
--
-- TODO: "Part of the utsname information is also accessible via
--          /proc/sys/kernel/{ostype, hostname, osrelease, version, domainname}."
-- That would allow us to avoid using the absolutely dreadful uname() call...

if not OSExt._typeExists("utsname_hack") then
    ffi.cdef[[
        typedef char *utsname_hack;
    ]]
end
ffi.cdef[[
    int uname(utsname_hack *buf);
]]

---@param str string
local function splitNull(str)
    local t = {}
    local i = 1
    local s = ""
    local last_char = ""
    while i <= str:len() do
        local char = str:sub(i, i)
        if char == "\0" then
            if char ~= last_char then
                table.insert(t, s)
            end
            s = ""
        else
            s = s .. char
        end
        last_char = char
        i = i + 1
    end
    table.insert(t, s)
    return t
end

-- Returns the name and information about the current kernel.
function OSExt.Unix.getKernelVersion()
    local struc = ffi.new("char[?]", (64 + 1) * 6)
    ffi.fill(struc, ffi.sizeof(struc))
    local strucOut = ffi.cast("utsname_hack*", struc)

    local ret = ffi.C.uname(strucOut)
    if ret ~= 0 then OSExt.Unix.raiseLastError() end

    local strucContents = ffi.string(ffi.cast("void *", struc), ffi.sizeof(struc))
    local parts = splitNull(strucContents)
    for i = 1, #parts do
        if parts[i] == "" then
            parts[i] = nil
        end
    end
    --assert(#parts == 5 or #parts == 6, "uname() returned an unexpected number of fields")

    return {
        systemName  = parts[1],
        nodeName    = parts[2],
        release     = parts[3],
        version     = parts[4],
        machine     = parts[5],
        domainName  = parts[6] -- GNU-only
    }
end

-- Returns the name and information about the current kernel using /proc/sys/kernel/ files.
-- In case using uname is unfestible, this is a fallback. HOWEVER, it might only work on Linux anyways.
function OSExt.Unix.getKernelVersionAlt()
    local function readFile(name)
        local file = fs.open("/proc/sys/kernel/"..name, "r")
        local strBuf, strLen = file:readall()
        if strBuf then
            return ffi.string(strBuf, strLen)
        end
    end

    return {
        systemName  = readFile("ostype"),
        nodeName    = readFile("hostname"),
        release     = readFile("osrelease"),
        version     = readFile("version"),
        machine     = ffi.arch,
        domainName  = readFile("domainname")
    }
end


if ffi.os == "Linux" then
    libRequire("osext", "unix/osver_linux")
end
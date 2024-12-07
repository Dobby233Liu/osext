local ffi = require "ffi"
local fs = OSExt.Unix.fs

OSExt.Unix.LinuxOSVer = {}

-- HACK: Property sizes in struct utsname varies from system to system.
-- Without doing weird crap like loading system headers, we can't know the exact size.
-- So, we just assume it's 64 + 1 for each of the 5/6 fields; and instead of having a struct
-- definition, we just use a char* and split it by \0.
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

-- Returns the name and information about the current kernel.
function OSExt.Unix.LinuxOSVer.getKernelVersion()
    local struc = ffi.new("char[?]", (64 + 1) * 6)
    ffi.fill(struc, ffi.sizeof(struc))

    local ret = ffi.C.uname(struc)
    if ret ~= 0 then OSExt.Unix.raiseLastError() end

    local parts = Utils.split(ffi.string(struc), "\0")
    table.remove(parts, #parts) -- remove the last empty string
    --assert(#parts == 5 or #parts == 6, "uname() returned an unexpected number of fields")

    local function nilIfEmpty(x)
        return x == "" and nil or x
    end
    return {
        systemName  = nilIfEmpty(parts[1]),
        nodeName    = nilIfEmpty(parts[2]),
        release     = nilIfEmpty(parts[3]),
        version     = nilIfEmpty(parts[4]),
        machine     = nilIfEmpty(parts[5]),
        domainName  = nilIfEmpty(parts[6]) -- GNU-only
    }
end


---@class OSExt.Unix.LinuxOSVer.OSReleaseData # Rough representation of the os-release file.
---@field name string?
---@field id string?
---@field idLike string?
---@field prettyName string?
---@field cpeName string?
---@field variant string?
---@field variantId string?
---@field version string?
---@field versionId string?
---@field versionCodename string?
---@field buildId string?
---@field imageId string?
---@field imageVersion string?

-- Parses Bourne Shell-style key-value pairs to a table.
-- Used to parse os-release. \
-- XREF: https://www.freedesktop.org/software/systemd/man/latest/os-release.html#Examples
-- ex. 5
local function parseBshKV(str, keyTransformer)
    local ret = {}
    for _,line in ipairs(Utils.split(str, "\n")) do
        line = line:match("^(.-)%s*$")
        if not line or line == "" or Utils.startsWith(line, "#") then goto continue end

        local k, v = line:match('([A-Z][A-Z_0-9]+)=(.-)')
        if not k then
            assert(false) -- TODO
        end
        if keyTransformer then k = keyTransformer(k) end

        if v then
            if Utils.startsWith(v, '"') then
                assert(Utils.endsWith(v, '"'))
                v = Utils.sub(v, 2, -2)
            end
            -- http://lua-users.org/lists/lua-l/2010-06/msg00096.html
            -- FIXME: absolutely disgusting
            v = v
                :gsub('\\(%d%d?%d?)', function(c)
                    return string.char(tonumber(c))
                end)
                :gsub('\\(.)', function(c)
                    local unescaped = ({
                        a='\a', b='\b', f='\f', n='\n', r='\r', t='\t',
                        v='\v',
                        ['\\']='\\',
                        ['\"']='\"',
                        ['\'']='\''
                    })[c]
                    return unescaped or c
                end)

            ret[k] = v
        end

        ::continue::
    end
    return ret
end

-- Returns the content of the os-release file.
--
-- See the following for possible fields:
--      https://www.freedesktop.org/software/systemd/man/latest/os-release.html#Options \
-- The key names are transformed to camel case.
--
---@return OSExt.Unix.LinuxOSVer.OSReleaseData?
function OSExt.Unix.LinuxOSVer.getOSReleaseData()
    local function tryLoading(file)
        if not fs.is(file) then return nil end
        local osReleaseFile = fs.open(file, "r")
        local osReleaseStrBuf, osReleaseStrLen = osReleaseFile:readall()
        if osReleaseStrBuf == nil then return nil end
        local ret = ffi.string(osReleaseStrBuf, osReleaseStrLen)
        osReleaseFile:close()
        return ret
    end

    local osReleaseStr = tryLoading("/etc/os-release")
    if not osReleaseStr then osReleaseStr = tryLoading("/usr/lib/os-release") end
    if not osReleaseStr then return nil end

    return parseBshKV(osReleaseStr, function(k)
        -- kinda ugly
        return k:lower():gsub("_([%a])", function(c)
            return c:upper()
        end):gsub("_", "")
    end)
end


-- Returns the result of lsb_release. \
-- This is another way to obtain OS info. These days though os-release is more refined.
--
-- This will require the lsb_release binary to be installed.
--
-- WIP
--[[function OSExt.Unix.LinuxOSVer.getLSBReleaseData()
    -- TODO
end]]
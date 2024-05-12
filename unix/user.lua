local ffi = require "ffi"

---@alias OSExt.Unix.uid integer
---@alias OSExt.Unix.gid integer

ffi.cdef[[
    typedef unsigned int uid_t;
    typedef unsigned int gid_t;
]]

ffi.cdef[[
    uid_t getuid(void);
    uid_t geteuid(void);
]]

-- For obtaining the real user ID of the current process (not the effective user ID)
---@return OSExt.Unix.uid uid
function OSExt.Unix.getUserId()
    -- can't fail
    return ffi.C.getuid()
end


if not OSExt._typeExists("passwd") then
    ffi.cdef[[
        struct _passwd {
            char    *pw_name;
            char    *pw_passwd;
            uid_t   pw_uid;
            gid_t   pw_gid;
            char    *pw_gecos;
            char    *pw_dir;
            char    *pw_shell;
        } passwd;
    ]]
end
---@class (exact) OSExt.Unix.passwd : ffi.cdata*
---@field pw_name string # username
---@field pw_passwd string # user password
---@field pw_uid OSExt.Unix.uid
---@field pw_gid OSExt.Unix.gid
---@field pw_gecos string
---@field pw_dir string
---@field pw_shell string

ffi.cdef[[
    struct passwd *getpwuid(uid_t uid);
]]

-- Gets the passwd entry for the user with the given UID
---@param uid? OSExt.Unix.uid # defaults to the real UID
---@return OSExt.Unix.passwd passwd
function OSExt.Unix.getUserPasswd(uid)
    if uid == nil then uid = OSExt.Unix.getUserId() end
    local ret = ffi.C.getpwuid(uid)
    if not ret then OSExt.Unix.raiseLastError() end
    return ret
end


-- Gets the username of the user with the given UID
---@param uid? OSExt.Unix.uid # defaults to the real UID of the process
---@return string name
function OSExt.Unix.getUsername(uid)
    local passwd = OSExt.Unix.getUserPasswd(uid)
    return passwd.pw_name
end


---@class OSExt.Unix.gecos # General information about the user. See FreeBSD manpage passwd(5)
---@field fullName? string
---@field office? string
---@field officePhone? string
---@field homePhone? string
---@field other? string

-- Parses the given GECOS field
---@param gecos string
---@return OSExt.Unix.gecos
function OSExt.Unix.parseGecos(gecos)
    local contents = Utils.split(gecos, ",")
    -- don't worry about commas in each field, because according to shadow src they can't be in these fields
    return {
        fullName = contents[1],
        office = contents[2],
        officePhone = contents[3],
        homePhone = contents[4],
        other = contents[5]
    }
end

-- Parses the GECOS field of the user with the given UID
---@param uid? OSExt.Unix.uid # defaults to the real UID of the process
---@return OSExt.Unix.gecos
function OSExt.Unix.parseGecosOfUser(uid)
    local passwd = OSExt.Unix.getUserPasswd(uid)
    return OSExt.Unix.parseGecos(passwd.pw_gecos)
end
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
function OSExt.Unix.getRealUserId()
    -- can't fail
    return ffi.C.getuid()
end


if not OSExt._typeExists("passwd") then
    ffi.cdef[[
        typedef struct _passwd {
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
    passwd *getpwuid(uid_t uid);
    passwd *getpwnam(const char *name);
]]

-- Gets the passwd entry for the user with the given UID.
-- The result should NOT be freed. In addition, with subsequent calls to this function,
-- the result will likely be clobbered, unless `copy` is true, in which case the result
-- (except strings) will be copied. (TODO)
---@param uid? OSExt.Unix.uid # defaults to the real UID
---@param copy? boolean # whether to duplicate the result. defaults to false
---@return OSExt.Unix.passwd passwd
function OSExt.Unix.getUserPasswd(uid, copy)
    if uid == nil then uid = OSExt.Unix.getRealUserId() end
    -- FIXME: thread-unsafe
    local res = ffi.C.getpwuid(uid)
    if not res then OSExt.Unix.raiseLastError() end
    if copy then
        local buf = ffi.new("passwd[1]")
        ffi.copy(buf[0], res, ffi.sizeof("passwd"))
        return buf[0]
    else
        return res
    end
end

-- Gets the passwd entry for the user with the given name.
-- The result should NOT be freed. In addition, with subsequent calls to this function,
-- the result will likely be clobbered, unless `copy` is true, in which case the result
-- (except strings) will be copied. (TODO)
---@param name string
---@param copy? boolean # whether to duplicate the result. defaults to false
---@return OSExt.Unix.passwd passwd
function OSExt.Unix.getUserPasswdByName(name, copy)
    assert(name) -- TODO
    -- FIXME: thread-unsafe
    local res = ffi.C.getpwnam(name)
    if not res then OSExt.Unix.raiseLastError() end
    if copy then
        local buf = ffi.new("passwd[1]")
        ffi.copy(buf[0], res, ffi.sizeof("passwd"))
        return buf[0]
    else
        return res
    end
end


-- Gets the username of the user with the given UID
---@param uid? OSExt.Unix.uid # defaults to the real UID of the process
---@return string name
function OSExt.Unix.getUserName(uid)
    local passwd = OSExt.Unix.getUserPasswd(uid)
    return ffi.string(passwd.pw_name)
end

-- Gets the UID of the user with the given username
---@param name string
---@return OSExt.Unix.uid uid
function OSExt.Unix.getUserIdByName(name)
    local passwd = OSExt.Unix.getUserPasswdByName(name)
    return passwd.pw_uid
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
---@return OSExt.Unix.gecos?
function OSExt.Unix.parseGecosOfUser(uid)
    local passwd = OSExt.Unix.getUserPasswd(uid)
    if not passwd.pw_gecos then return nil end
    local ret = OSExt.Unix.parseGecos(ffi.string(passwd.pw_gecos))
    -- Git: "Also & stands for capitalized form of the login name."
    if ret and ret.fullName == "&" then
        local username = passwd.pw_name
        ret.fullName = Utils.sub(username, 1, 1):upper() .. Utils.sub(username, 2, 1)
    end
    return ret
end

-- For reference there's this email acquiring method in Git
-- https://github.com/git/git/blob/b9cfe4845cb2562584837bc0101c0ab76490a239/ident.c#L171
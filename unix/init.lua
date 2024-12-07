-- Unix interfaces
OSExt.Unix = {}

OSExt.Unix._oldLocale = {}
local locTypes = {"all", "collate", "ctype", "monetary", "numeric", "time"}

function OSExt.Unix.init()
    -- For our sake force stuff to use UTF-8.
    -- Don't know how to decode system strings to UTF-8.
    for _,locType in ipairs(locTypes) do
        local oldLocale = os.setlocale(nil, locType)
        OSExt.Unix._oldLocale[locType] = oldLocale
        local newLocale = Utils.split(oldLocale, ".", true)[1] .. ".UTF-8"
        os.setlocale(newLocale, locType)
    end
end

function OSExt.Unix.unload()
    -- restore old locales
    for _,locType in ipairs(locTypes) do
        os.setlocale(OSExt.Unix._oldLocale[locType], locType)
    end
end

OSExt.Unix.fs = libRequire("osext", "fslib/fs")

libRequire("osext", "unix/error")
libRequire("osext", "unix/user")
libRequire("osext", "unix/host")
libRequire("osext", "unix/proc")
libRequire("osext", "unix/osver")
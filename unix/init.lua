-- Unix interfaces
OSExt.Unix = {}

function OSExt.Unix.init()
    -- force stuff to use UTF-8
    for _,locType in ipairs({"all", "collate", "ctype", "monetary", "numeric", "time"}) do
        local oldLocale = os.setlocale(nil, locType)
        local newLocale = Utils.split(oldLocale, ".", true)[1] .. ".UTF-8"
        os.setlocale(newLocale, locType)
    end
end

OSExt.Unix.fs = libRequire("osext", "fslib/fs")

libRequire("osext", "unix/error")
libRequire("osext", "unix/user")
libRequire("osext", "unix/host")
libRequire("osext", "unix/proc")
libRequire("osext", "unix/osver")
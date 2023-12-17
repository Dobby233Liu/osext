local ffi = require("ffi")

OSExt.Win32.Libs.ntdll = ffi.load("ntdll")
if not OSExt.Win32.Libs.ntdll then
    error("ntdll not available?!")
end

libRequire("osext", "win32/ntsysapi")
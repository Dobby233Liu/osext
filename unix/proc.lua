local ffi = require "ffi"

if ffi.os == "Linux" then
    libRequire("osext", "unix/proc_linux")
--[[elseif ffi.os == "OSX" or ffi.os == "BSD" then
    libRequire("osext", "unix/proc_bsd")]]
end
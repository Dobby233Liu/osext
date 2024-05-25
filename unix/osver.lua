local ffi = require "ffi"

if ffi.os == "Linux" then
    libRequire("osext", "unix/osver_linux")
end
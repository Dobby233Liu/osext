-- General Win32 interactions
--
-- Most stuff in the root scope comes from kernel32
OSExt.Win32 = {}

libRequire("osext", "win32/kernel32")
libRequire("osext", "win32/psapi")
libRequire("osext", "win32/secext")
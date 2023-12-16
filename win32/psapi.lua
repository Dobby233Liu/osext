-- Implements some of psapi.dll's interfaces
--
-- The Process Status API provides data about currently running processes or so
--
-- [MSDN](https://learn.microsoft.com/en-us/windows/win32/psapi/process-status-helper)
local psapi = {}
OSExt.Win32.PSApi = psapi

-- TODO
-- WIP
--
-- [MS-ERREF](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/1bc92ddf-b79e-413c-bbaa-99a5281a6c90)
OSExt.Win32.Status = Class()

---@enum OSExt.Win32.Status.SEVERITY
-- Maps to NTSTATUS' STATUS_SEVERITY_*
OSExt.Win32.Status.SEVERITY = {
    -- means success in HRESULT
    success = 0,
    informational = 1,
    -- means failure in HRESULT
    warning = 2,
    error = 3
}
---@enum (key) OSExt.Win32.Status.FACILITY_MODES
OSExt.Win32.Status.FACILITY_KINDS = {
    hResult = 0,
    ntStatus = 1
}

---@private
function OSExt.Win32.Status:init()
    self.customer = false
    self.facility = 0 -- FIXME
    self.facility_kind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    self.code = 0 -- FIXME
    self.severity = OSExt.Win32.Status.SEVERITY.success
end

function OSExt.Win32.Status:fromWin32(w32Error)
    assert(w32Error >= 0)
    local status = OSExt.Win32.Status()
    status.customer = false
    status.facility_kind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    status.facility = OSExt.Win32.NtStatusFacilities.FACILITY_WIN32 -- FIXME
    status.code = w32Error
    if w32Error == 0 --[[ FIXME ]] then
        status.severity = OSExt.Win32.Status.SEVERITY.success
    else
        status.severity = OSExt.Win32.Status.SEVERITY.failure
    end
    return status
end
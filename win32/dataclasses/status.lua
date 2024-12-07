local bit = require"bit"

---@class OSExt.Win32.Status
-- WIP
--
-- [MS-ERREF](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/1bc92ddf-b79e-413c-bbaa-99a5281a6c90)
OSExt.Win32.Status = Class()

---@enum (key) OSExt.Win32.Status.SEVERITY
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
-- (To be changed) Do NOT have code that manually inits a Status instance for now
function OSExt.Win32.Status:init()
    self.customer = false
    self.facility = 0 -- FIXME
    self.facility_kind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    self.code = 0 -- FIXME
    self.severity = OSExt.Win32.Status.SEVERITY.success
end

function OSExt.Win32.Status.fromWin32Error(w32Error)
    assert(w32Error >= 0)
    local status = OSExt.Win32.Status()
    status.customer = false
    status.facility_kind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    status.facility = OSExt.Win32.NtStatusFacilities.FACILITY_WIN32 -- FIXME
    status.code = w32Error
    if w32Error == OSExt.Win32.Win32Errors.ERROR_SUCCESS --[[ FIXME ]] then
        status.severity = OSExt.Win32.Status.SEVERITY.success
    else
        status.severity = OSExt.Win32.Status.SEVERITY.error
    end
    return status
end

function OSExt.Win32.Status:_sanityCheck()
    assert(self.code >= 0 and self.code <= 0xffff)
end

function OSExt.Win32.Status:toHResult()
    self:_sanityCheck()

    local code = 0
    local bitWidth = 32
    local function set(index, value)
        print(code)
        if value then value = 0x1 else value = 0 end
        code = bit.bor(code, bit.lshift(value, bitWidth - index - 1))
    end

    set(0, self.severity >= OSExt.Win32.Status.SEVERITY.error) -- S
    -- R todo
    set(2, self.customer) -- C
    set(3, self.facility_kind == OSExt.Win32.Status.FACILITY_KINDS.ntStatus) -- N
    set(4, false) -- X
    print(code)
    code = bit.bor(code, bit.lshift(bit.band(self.facility, 0xfff), 16))
    print(code)
    code = bit.bor(code, bit.band(self.code, 0x0000ffff))

    return code
end
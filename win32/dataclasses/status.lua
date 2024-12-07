local bit = require"bit"

---@class OSExt.Win32.Status : Class
-- Represents a Windows status code (Win32 error/HRESULT/NTSTATUS)
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
    self.facilityKind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    self.code = 0 -- FIXME
    self.severity = OSExt.Win32.Status.SEVERITY.success
end

function OSExt.Win32.Status.fromWin32Error(w32Error)
    assert(w32Error >= 0)
    local status = OSExt.Win32.Status()
    status.customer = false
    status.facilityKind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    status.facility = OSExt.Win32.HResultFacilities.FACILITY_WIN32
    status.code = w32Error
    if w32Error == OSExt.Win32.Win32Errors.ERROR_SUCCESS then
        status.severity = OSExt.Win32.Status.SEVERITY.success
    else
        -- As far as I know anyway
        status.severity = OSExt.Win32.Status.SEVERITY.warning
    end
    return status
end

function OSExt.Win32.Status.fromLastWin32Error()
    return OSExt.Win32.Status.fromWin32Error(OSExt.Win32.getLastWin32Error())
end

function OSExt.Win32.Status.fromHResult(hResult)
    return OSExt.Win32.Status.fromNtStatus(hResult, true)
end

function OSExt.Win32.Status.fromNtStatus(ntStatus, _isHResult)
    local status = OSExt.Win32.Status()
    status.severity = bit.rshift(ntStatus, 30)
    if _isHResult and bit.band(status.severity, 0x1) == 1 then
        error("HRESULT should not have a severity of informational or error. Use fromNtStatus to convert NTSTATUS to Status")
    end
    status.customer = bit.band(bit.rshift(ntStatus, 29), 0x1) == 1
    local wasNtStatus = bit.band(bit.rshift(ntStatus, 28), 0x1) == 1
    if _isHResult and not wasNtStatus then
        status.facilityKind = OSExt.Win32.Status.FACILITY_KINDS.hResult
    else
        status.facilityKind = OSExt.Win32.Status.FACILITY_KINDS.ntStatus
    end
    status.facility = bit.band(bit.rshift(ntStatus, 16), 0xfff)
    --[[if _isHResult then
        status.facility = bit.band(status.facility, 0x7ff)
    end]]
    status.code = bit.band(ntStatus, 0xffff)
    return status
end

function OSExt.Win32.Status:_sanityCheck()
    -- TODO
    assert(self.code >= 0 and self.code <= 0xffff)
end


function OSExt.Win32.Status:getMessage(languageId)
    return OSExt.Win32.getSystemMessageTrimmed(self:toHResult(), languageId)
end


function OSExt.Win32.Status:toWin32Error()
    self:_sanityCheck()
    if self.customer or self.facility ~= OSExt.Win32.NtStatusFacilities.FACILITY_NTWIN32 then
        error("Can't convert non-Win32 Status to Win32 error code")
    end
    return self.code
end

function OSExt.Win32.Status:toHResult()
    return self:toNtStatus(true)
end

function OSExt.Win32.Status:toNtStatus(_isHResult)
    self:_sanityCheck()

    local code = 0
    local bitWidth = 32
    local function set(index, value)
        if value then value = 0x1 else value = 0 end
        code = bit.bor(code, bit.lshift(value, bitWidth - index - 1))
    end

    if _isHResult and bit.band(self.severity, 0x1) == 1 then
        error("A severity of informational or error can't be used in an HRESULT")
    end
    code = bit.bor(code, bit.lshift(bit.band(self.severity, 0x3), 30)) -- Sev
    set(2, self.customer) -- C
    local facility = self.facility
    if _isHResult then
        -- N is set to 1 if this was a NTSTATUS
        set(3, self.facilityKind == OSExt.Win32.Status.FACILITY_KINDS.ntStatus) -- N
    elseif self.facilityKind == OSExt.Win32.Status.FACILITY_KINDS.hResult then
        -- TODO
        facility = ({
            [OSExt.Win32.HResultFacilities.FACILITY_WIN32] = OSExt.Win32.NtStatusFacilities.FACILITY_NTWIN32
        })[self.facility]
        if not facility then
            error(string.format("HRESULT facility %d can't be corresponded to a NTSTATUS facility", self.facility))
        end
    end
    code = bit.bor(code, bit.lshift(bit.band(facility, 0xfff), 16))
    code = bit.bor(code, bit.band(self.code, 0xffff))

    return code
end


function OSExt.Win32.Status:setAsWin32Error()
    OSExt.Win32.Libs.kernel32.SetLastError(self:toWin32Error())
end


function OSExt.Win32.Status:needsAttention()
    return self.severity >= self.SEVERITY.warning
end
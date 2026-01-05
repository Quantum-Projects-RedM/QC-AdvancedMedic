--=========================================================
-- QC-ADVANCED MEDIC - SERVER NOTIFICATIONS
--=========================================================
-- Centralized notification patterns for consistent UI feedback
--=========================================================

--=========================================================
-- NOTIFICATION HELPERS
--=========================================================

-- Send error notification to player
local function NotifyError(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = 'error',
        duration = 5000
    })
end

-- Send success notification to player
local function NotifySuccess(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = 'success',
        duration = 5000
    })
end

-- Send info notification to player
local function NotifyInfo(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = 'inform',
        duration = 5000
    })
end

-- Send warning notification to player
local function NotifyWarning(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = 'warning',
        duration = 5000
    })
end

--=========================================================
-- MEDICAL-SPECIFIC NOTIFICATIONS
--=========================================================

-- Notify about treatment application
local function NotifyTreatmentApplied(source, treatmentType, bodyPart)
    local messages = {
        bandage = string.format("Bandage applied to %s", bodyPart),
        tourniquet = string.format("Tourniquet applied to %s", bodyPart),
        medicine = "Medicine administered successfully",
        injection = "Injection administered successfully"
    }

    NotifySuccess(source, locale('cl_menu_treatment_success'), messages[treatmentType] or "Treatment applied")
end

-- Notify about validation errors
local function NotifyValidationError(source, errorCode)
    local errorMessages = {
        PLAYER_NOT_FOUND = "Player not found",
        NO_CITIZENID = "Player has no citizen ID",
        NOT_MEDIC = "You must be a medic to perform this action",
        INVALID_WOUND_DATA = "Invalid wound data",
        INVALID_BODY_PART = "Invalid body part",
        INVALID_PAIN_LEVEL = "Invalid pain level",
        INVALID_BLEEDING_LEVEL = "Invalid bleeding level",
        INVALID_TREATMENT = "Invalid treatment type",
        NO_ARTERY = "This body part doesn't have an artery for tourniquet",
        TOO_FAR = "You are too far from the patient",
        MISSING_ITEM = "You don't have the required item",
        TREATMENT_COOLDOWN = "Please wait before applying another treatment"
    }

    local message = errorMessages[errorCode] or "An error occurred"
    NotifyError(source, locale('sv_error'), message)
end

--=========================================================
-- EXPORTS
--=========================================================

exports('NotifyError', NotifyError)
exports('NotifySuccess', NotifySuccess)
exports('NotifyInfo', NotifyInfo)
exports('NotifyWarning', NotifyWarning)
exports('NotifyTreatmentApplied', NotifyTreatmentApplied)
exports('NotifyValidationError', NotifyValidationError)

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER NOTIFICATIONS] Notification helpers loaded^7")
end

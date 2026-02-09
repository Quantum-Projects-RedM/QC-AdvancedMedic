--=========================================================
-- QC-ADVANCED MEDIC - SERVER NOTIFICATIONS
--=========================================================
-- Centralized notification patterns for consistent UI feedback
--=========================================================

QCMedServer = QCMedServer or {}

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
        bandage = string.format(locale('sv_notify_bandage_applied'), bodyPart),
        tourniquet = string.format(locale('sv_notify_tourniquet_applied'), bodyPart),
        medicine = locale('sv_notify_medicine_administered'),
        injection = locale('sv_notify_injection_administered')
    }

    NotifySuccess(source, locale('cl_menu_treatment_success'), messages[treatmentType] or locale('sv_notify_treatment_applied_generic'))
end

-- Notify about validation errors
local function NotifyValidationError(source, errorCode)
    local errorMessages = {
        PLAYER_NOT_FOUND = locale('sv_notify_player_not_found'),
        NO_CITIZENID = locale('sv_notify_no_citizenid'),
        NOT_MEDIC = locale('sv_notify_not_medic'),
        INVALID_WOUND_DATA = locale('sv_notify_invalid_wound_data'),
        INVALID_BODY_PART = locale('sv_notify_invalid_body_part'),
        INVALID_PAIN_LEVEL = locale('sv_notify_invalid_pain_level'),
        INVALID_BLEEDING_LEVEL = locale('sv_notify_invalid_bleeding_level'),
        INVALID_TREATMENT = locale('sv_notify_invalid_treatment'),
        NO_ARTERY = locale('sv_notify_no_artery'),
        TOO_FAR = locale('sv_notify_too_far'),
        MISSING_ITEM = locale('sv_notify_missing_item'),
        TREATMENT_COOLDOWN = locale('sv_notify_treatment_cooldown')
    }

    local message = errorMessages[errorCode] or locale('sv_notify_unknown_error')
    NotifyError(source, locale('sv_error'), message)
end

--=========================================================
-- EXPORTS
--=========================================================

QCMedServer.NotifyError = NotifyError
QCMedServer.NotifySuccess = NotifySuccess
QCMedServer.NotifyInfo = NotifyInfo
QCMedServer.NotifyWarning = NotifyWarning
QCMedServer.NotifyTreatmentApplied = NotifyTreatmentApplied
QCMedServer.NotifyValidationError = NotifyValidationError

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER NOTIFICATIONS] Notification helpers loaded^7")
end

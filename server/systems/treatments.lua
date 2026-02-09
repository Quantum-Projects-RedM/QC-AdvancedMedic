--=========================================================
-- QC-ADVANCED MEDIC - TREATMENT SYSTEM (SERVER)
--=========================================================
-- Server-authoritative treatment application with integrated validation
-- Includes distance checks, rate limiting, and item validation
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- RATE LIMITING
--=========================================================

-- Treatment cooldowns to prevent spam
local treatmentCooldowns = {}

local function CanApplyTreatment(medicSource, patientSource, cooldownSecs)
    cooldownSecs = cooldownSecs or 5 -- Default 5 second cooldown

    local key = medicSource .. "_" .. patientSource
    local lastTime = treatmentCooldowns[key] or 0
    local now = os.time()

    if (now - lastTime) < cooldownSecs then
        return false, "TREATMENT_COOLDOWN"
    end

    treatmentCooldowns[key] = now
    return true
end

--=========================================================
-- SERVER-AUTHORITATIVE TREATMENT AUTHORIZATION
--=========================================================

-- Comprehensive treatment authorization (integrated validation)
local function AuthorizeTreatment(medicSource, patientSource, treatmentType, itemName)
    -- Check if medic exists and has medic job
    local Medic, err = QCMedServer.ValidateMedic(medicSource)
    if not Medic then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[TREATMENT AUTH] Medic validation failed for %d: %s^7", medicSource, err))
        end
        return false, err
    end

    -- Check if patient exists
    local Patient, err2 = QCMedServer.ValidatePlayer(patientSource)
    if not Patient then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[TREATMENT AUTH] Patient validation failed for %d: %s^7", patientSource, err2))
        end
        return false, err2
    end

    -- Check distance (within 5 meters)
    if not QCMedServer.CheckDistance(medicSource, patientSource, 5.0) then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[TREATMENT AUTH] Distance check failed: medic %d too far from patient %d^7",
                medicSource, patientSource))
        end
        return false, "TOO_FAR"
    end

    -- Check cooldown / rate limiting
    local canApply, cooldownErr = CanApplyTreatment(medicSource, patientSource)
    if not canApply then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[TREATMENT AUTH] Cooldown active for medic %d treating patient %d^7",
                medicSource, patientSource))
        end
        return false, cooldownErr
    end

    -- Check item possession
    if not QCMedServer.HasItem(medicSource, itemName) then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[TREATMENT AUTH] Medic %d missing item: %s^7", medicSource, itemName))
        end
        return false, "MISSING_ITEM"
    end

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TREATMENT AUTH] Authorized: medic %d treating patient %d with %s^7",
            medicSource, patientSource, itemName))
    end

    return true, Medic, Patient
end

--=========================================================
-- TREATMENT APPLICATION
--=========================================================

-- Apply bandage to player (server-authoritative)
local function ApplyBandageToPlayer(medicSource, patientSource, bandageData)
    -- Server-authoritative validation
    local authorized, MedicOrErr, Patient = AuthorizeTreatment(
        medicSource,
        patientSource,
        'bandage',
        bandageData.itemName or bandageData.bandageType
    )

    if not authorized then
        -- MedicOrErr contains error code
        QCMedServer.NotifyValidationError(medicSource, MedicOrErr)
        return false, MedicOrErr
    end

    local Medic = MedicOrErr

    -- Remove item from medic's inventory
    if not Medic.Functions.RemoveItem(bandageData.itemName or bandageData.bandageType, 1) then
        QCMedServer.NotifyError(medicSource, locale('sv_error'), "Failed to remove item")
        return false, "FAILED_REMOVE_ITEM"
    end

    -- Send treatment to client
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveBandage', patientSource, {
        bodyPart = bandageData.bodyPart,
        bandageType = bandageData.bandageType,
        appliedBy = medicSource
    })

    -- Log event
    pcall(function()
        QCMedServer.LogMedicalEvent(
            Patient.PlayerData.citizenid,
            'bandage_applied',
            bandageData.bodyPart,
            {
                bandageType = bandageData.bandageType,
                appliedBy = Medic.PlayerData.citizenid,
                isSelfApplied = medicSource == patientSource
            }
        )
    end)

    -- Success notification
    QCMedServer.NotifyTreatmentApplied(medicSource, 'bandage', bandageData.bodyPart)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TREATMENT] Bandage applied: %s on %s (medic: %d, patient: %d)^7",
            bandageData.bandageType, bandageData.bodyPart, medicSource, patientSource))
    end

    return true
end

-- Apply tourniquet to player (server-authoritative)
-- Global application - no body part needed (circuit-damage pattern)
local function ApplyTourniquetToPlayer(medicSource, patientSource, tourniquetData)
    -- Server-authoritative validation
    local authorized, MedicOrErr, Patient = AuthorizeTreatment(
        medicSource,
        patientSource,
        'tourniquet',
        tourniquetData.itemName or tourniquetData.tourniquetType
    )

    if not authorized then
        QCMedServer.NotifyValidationError(medicSource, MedicOrErr)
        return false, MedicOrErr
    end

    local Medic = MedicOrErr

    -- Remove item from inventory
    if not Medic.Functions.RemoveItem(tourniquetData.itemName or tourniquetData.tourniquetType, 1) then
        QCMedServer.NotifyError(medicSource, locale('sv_error'), "Failed to remove item")
        return false, "FAILED_REMOVE_ITEM"
    end

    -- Send global tourniquet to client (no body part)
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveTourniquet', patientSource, {
        tourniquetType = tourniquetData.tourniquetType,
        appliedBy = medicSource
    })

    -- Log event (global application)
    pcall(function()
        QCMedServer.LogMedicalEvent(
            Patient.PlayerData.citizenid,
            'tourniquet_applied',
            nil, -- No body part - global application
            {
                tourniquetType = tourniquetData.tourniquetType,
                appliedBy = Medic.PlayerData.citizenid,
                isGlobal = true
            }
        )
    end)

    QCMedServer.NotifyTreatmentApplied(medicSource, 'tourniquet', nil)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TREATMENT] Global tourniquet applied: %s (stops ALL bleeding)^7",
            tourniquetData.tourniquetType))
    end

    return true
end

-- Administer medicine to player (server-authoritative)
local function AdministreMedicineToPlayer(medicSource, patientSource, medicineData)
    -- Server-authoritative validation
    local authorized, MedicOrErr, Patient = AuthorizeTreatment(
        medicSource,
        patientSource,
        'medicine',
        medicineData.itemName or medicineData.medicineType
    )

    if not authorized then
        QCMedServer.NotifyValidationError(medicSource, MedicOrErr)
        return false, MedicOrErr
    end

    local Medic = MedicOrErr

    -- Remove item from inventory
    if not Medic.Functions.RemoveItem(medicineData.itemName or medicineData.medicineType, 1) then
        QCMedServer.NotifyError(medicSource, locale('sv_error'), "Failed to remove item")
        return false, "FAILED_REMOVE_ITEM"
    end

    -- Send treatment to client
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveMedicine', patientSource, medicineData)

    -- Log event
    pcall(function()
        QCMedServer.LogMedicalEvent(
            Patient.PlayerData.citizenid,
            'medicine_administered',
            nil,
            {
                medicineType = medicineData.medicineType,
                appliedBy = Medic.PlayerData.citizenid
            }
        )
    end)

    QCMedServer.NotifyTreatmentApplied(medicSource, 'medicine', nil)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TREATMENT] Medicine administered: %s^7", medicineData.medicineType))
    end

    return true
end

-- Administer injection to player (server-authoritative)
local function AdministerInjectionToPlayer(medicSource, patientSource, injectionData)
    -- Server-authoritative validation
    local authorized, MedicOrErr, Patient = AuthorizeTreatment(
        medicSource,
        patientSource,
        'injection',
        injectionData.itemName or injectionData.injectionType
    )

    if not authorized then
        QCMedServer.NotifyValidationError(medicSource, MedicOrErr)
        return false, MedicOrErr
    end

    local Medic = MedicOrErr

    -- Remove item from inventory
    if not Medic.Functions.RemoveItem(injectionData.itemName or injectionData.injectionType, 1) then
        QCMedServer.NotifyError(medicSource, locale('sv_error'), "Failed to remove item")
        return false, "FAILED_REMOVE_ITEM"
    end

    -- Send treatment to client
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveInjection', patientSource, injectionData)

    -- Log event
    pcall(function()
        QCMedServer.LogMedicalEvent(
            Patient.PlayerData.citizenid,
            'injection_administered',
            nil,
            {
                injectionType = injectionData.injectionType,
                appliedBy = Medic.PlayerData.citizenid
            }
        )
    end)

    QCMedServer.NotifyTreatmentApplied(medicSource, 'injection', nil)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TREATMENT] Injection administered: %s^7", injectionData.injectionType))
    end

    return true
end

--=========================================================
-- TREATMENT DATA SAVE
--=========================================================

-- Handle treatment data update
local function HandleTreatmentUpdate(source, treatmentData)
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    local success = pcall(function()
        QCMedServer.SaveTreatmentData(
            Player.PlayerData.citizenid,
            treatmentData
        )
    end)

    return success, success and nil or "DATABASE_ERROR"
end

--=========================================================
-- EXPORTS
--=========================================================

QCMedServer.ApplyBandageToPlayer = ApplyBandageToPlayer
QCMedServer.ApplyTourniquetToPlayer = ApplyTourniquetToPlayer
QCMedServer.AdministreMedicineToPlayer = AdministreMedicineToPlayer
QCMedServer.AdministerInjectionToPlayer = AdministerInjectionToPlayer
QCMedServer.HandleTreatmentUpdate = HandleTreatmentUpdate
QCMedServer.AuthorizeTreatment = AuthorizeTreatment

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER TREATMENTS] Treatment system with server-authoritative validation loaded^7")
end

-- QC-AdvancedMedic Client Shared Functions
-- This file contains shared functions used across multiple client files
-- Replaces dangerous internal exports with direct function calls

-- Debug to confirm module is loading
if Config and Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("[SHARED MODULE] Loading client_shared.lua")
end

-- Helper function to check if player has any medic job
function IsMedicJob(jobName)
    if not jobName then return false end

    -- Check against all jobs in MedicJobLocations
    for _, location in pairs(Config.MedicJobLocations) do
        if location.job == jobName then
            return true
        end
    end

    return false
end

-- Function to get player wounds (references global PlayerWounds from wound_system.lua)
function GetPlayerWounds()
    if PlayerWounds then
        return PlayerWounds
    end
    return {}
end

-- Function to get active treatments (references global ActiveTreatments from treatment_system.lua)
function GetActiveTreatments()
    if ActiveTreatments then
        return ActiveTreatments
    end
    return {}
end

-- Function to get infection data (references global PlayerInfections from infection_system.lua)
function GetInfectionData(bodyPart)
    if PlayerInfections then
        if bodyPart then
            return PlayerInfections[bodyPart]
        end
        return PlayerInfections
    end
    return bodyPart and {} or {}
end

-- Function to get cure progress (references global InfectionCureProgress from infection_system.lua)
function GetCureProgress(bodyPart)
    if InfectionCureProgress and bodyPart then
        return InfectionCureProgress[bodyPart] or 0
    end
    return 0
end

-- Note: Functions ApplyBandage, RemoveTreatment, AddBandage, RemoveBandage, CreateForceInfection
-- are defined as global functions in their respective modules and accessible directly
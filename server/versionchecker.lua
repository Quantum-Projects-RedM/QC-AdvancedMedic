local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Quantum-Projects-RedM/QC-VersionCheckers/master/QC-AdvancedMedic.txt', function(err, newestVersion, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')
        local resourceName = GetCurrentResourceName()
        local githubLink = GetResourceMetadata(resourceName, 'quantum_github') or "No GitHub URL provided"

        if not newestVersion then
            print("\n^1[Quantum Projects]^7 Unable to perform version check.\n")
            return
        end

        local isLatestVersion = newestVersion:gsub("%s+", "") == currentVersion:gsub("%s+", "")
        if isLatestVersion then
            print(("^3[Quantum Projects]^7: You are running the latest version of ^2%s^7 (^2%s^7)."):format(resourceName, currentVersion))
        else
            print("\n^6========================================^7")
            print("^3[Quantum Projects]^7 Version Checker")
            print("")
            print(("^3Version Check^7:\n ^2Current^7: %s\n ^2Latest^7: %s\n"):format(currentVersion, newestVersion))
            print(("^1You are running an outdated version of %s.\n^6Repository: ^4%s^7\n"):format(resourceName, githubLink))
            print("^6========================================^7\n")
        end
    end)
end

CheckVersion()

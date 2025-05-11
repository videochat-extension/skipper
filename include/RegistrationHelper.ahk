; RegistrationHelper class to manage native messaging host registration
class RegistrationHelper {
    ; Static properties
    static hostName := ""
    static hostDescription := ""
    static allowedOrigins := []
    static manifestPath := ""
    static altManifestPath := ""  ; Alternative path in AppData
    static registryKey := ""
    static lastError := ""  ; Store the last error message

    ; Constructor with configurable host details
    __New(hostName, hostDescription, allowedOrigins) {
        this.hostName := hostName
        this.hostDescription := hostDescription
        this.allowedOrigins := allowedOrigins
        this.lastError := ""

        ; Set paths
        scriptDir := A_ScriptDir
        this.manifestPath := scriptDir . "\manifest.json"

        ; Set alternative path in AppData\Local
        this.altManifestPath := A_AppData . "\OmegleLike Skipper\manifest.json"

        ; Define registry key (current user only, no admin required)
        this.registryKey := "HKEY_CURRENT_USER\SOFTWARE\Google\Chrome\NativeMessagingHosts\" . hostName
    }

    ; Check if the native messaging host is registered
    IsRegistered() {
        try {
            ; Try to read the registry key
            regValue := RegRead(this.registryKey)

            ; Check if the manifest file exists at registry path
            if (FileExist(regValue)) {
                return true
            }

            ; Registry key exists but manifest missing
            this.lastError := "Registry key exists but manifest file is missing: " . regValue
            Log(this.lastError)
            return false
        } catch Error as e {
            ; Key doesn't exist
            this.lastError := "Registry key doesn't exist: " . this.registryKey
            Log(this.lastError)
            return false
        }
    }

    ; Force registration regardless of current status
    ForceRegister() {
        return this.Register()
    }

    ; Get the current manifest path being used
    GetCurrentManifestPath() {
        try {
            ; Try to read the registry key to see which path is registered
            regValue := RegRead(this.registryKey)
            if (FileExist(regValue)) {
                return regValue
            }

            this.lastError := "Registry points to non-existent manifest: " . regValue
            Log(this.lastError)
        } catch Error as e {
            ; Registry key doesn't exist, check if either manifest exists
            if (FileExist(this.manifestPath))
                return this.manifestPath
            if (FileExist(this.altManifestPath))
                return this.altManifestPath

            this.lastError := "Registry key doesn't exist and no manifest files found"
            Log(this.lastError)
        }

        ; Default to primary path if nothing exists yet
        return this.manifestPath
    }

    ; Register the native messaging host
    Register() {
        Log("Starting registration process (user-level only)...")
        this.lastError := ""

        ; Create the manifest file
        Log("Creating manifest file...")
        manifestCreated := this.CreateManifest()
        if (!manifestCreated) {
            this.lastError := "Failed to create manifest file"
            Log(this.lastError)
            return false
        }

        ; Use the path where manifest was successfully created
        manifestPath := manifestCreated
        Log("Manifest created at: " . manifestPath)

        ; Create/update the registry key (always write, even if it exists)
        try {
            Log("Writing registry key (HKEY_CURRENT_USER only): " . this.registryKey . " = " . manifestPath)
            RegWrite(manifestPath, "REG_SZ", this.registryKey)
            Log("Registration successful")
            return true
        } catch Error as e {
            this.lastError := "Failed to create registry key: " . e.Message
            Log(this.lastError)
            MsgBox("Failed to create registry key: " . e.Message, "Registration Error", "Icon!")
            return false
        }
    }

    ; Create the manifest file
    CreateManifest() {
        ; Prepare manifest content - ensure we use the main script path (skipper.ahk), not the include file
        mainScriptPath := A_ScriptDir . "\skipper.ahk"
        if (A_IsCompiled) {
            mainScriptPath := A_ScriptFullPath  ; If compiled, use the exe path
        }

        manifest := Map(
            "name", this.hostName,
            "description", this.hostDescription,
            "path", mainScriptPath,
            "type", "stdio",
            "allowed_origins", this.allowedOrigins
        )

        Log("Preparing manifest with path: " . mainScriptPath)

        ; Convert to JSON
        try {
            manifestJson := Jxon_Dump(manifest, true)  ; true for pretty formatting

            ; First try the primary path
            try {
                Log("Attempting to write manifest to primary path: " . this.manifestPath)
                ; Create directory if needed for primary path
                SplitPath(this.manifestPath, , &dirPath)
                if (!DirExist(dirPath)) {
                    Log("Creating directory: " . dirPath)
                    DirCreate(dirPath)
                }

                FileObj := FileOpen(this.manifestPath, "w", "UTF-8")
                if (FileObj) {
                    FileObj.Write(manifestJson)
                    FileObj.Close()
                    Log("Manifest successfully written to primary path")
                    return this.manifestPath
                } else {
                    this.lastError := "Could not open primary manifest file for writing"
                    Log(this.lastError)
                }
            } catch Error as e {
                this.lastError := "Could not write to primary manifest path: " . e.Message
                Log(this.lastError)
                ; Primary path failed, try alternative path
            }

            ; Try the alternative path in AppData
            try {
                Log("Attempting to write manifest to alternative path (user AppData): " . this.altManifestPath)
                ; Create directory structure if it doesn't exist
                SplitPath(this.altManifestPath, , &dirPath)
                if (!DirExist(dirPath)) {
                    Log("Creating directory: " . dirPath)
                    DirCreate(dirPath)
                }

                FileObj := FileOpen(this.altManifestPath, "w", "UTF-8")
                if (!FileObj) {
                    this.lastError := "Failed to open manifest file in AppData for writing"
                    Log(this.lastError)
                    MsgBox("Failed to create manifest file in AppData!", "Registration Error", "Icon!")
                    return false
                }

                FileObj.Write(manifestJson)
                FileObj.Close()
                Log("Manifest successfully written to alternative path")
                return this.altManifestPath
            } catch Error as e {
                this.lastError := "Failed to create manifest in AppData: " . e.Message
                Log(this.lastError)
                MsgBox("Failed to create manifest in AppData: " . e.Message, "Registration Error", "Icon!")
                return false
            }
        } catch Error as e {
            this.lastError := "Failed to create manifest: " . e.Message
            Log(this.lastError)
            MsgBox("Failed to create manifest: " . e.Message, "Registration Error", "Icon!")
            return false
        }
    }

    ; Unregister the native messaging host
    Unregister() {
        try {
            Log("Starting unregistration process...")
            this.lastError := ""

            ; Get the current manifest path from registry
            currentManifestPath := ""
            try {
                currentManifestPath := RegRead(this.registryKey)
                Log("Found registered manifest at: " . currentManifestPath)
            } catch Error as e {
                Log("Registry key doesn't exist: " . e.Message)
                ; Registry key doesn't exist
            }

            ; Log what we're attempting to delete
            Log("Attempting to delete registry key: " . this.registryKey)

            ; First try to delete the entire key structure with RegDeleteKey
            ; This is designed to delete a key and all its subkeys/values
            try {
                RegDeleteKey(this.registryKey)
                Log("Registry key deleted successfully using RegDeleteKey")
            } catch Error as e {
                ; If RegDeleteKey fails, try RegDelete as fallback
                Log("RegDeleteKey failed: " . e.Message)
                RegDelete(this.registryKey)
                Log("Attempted fallback with RegDelete")
            }

            ; Delete manifest file - try both possible locations
            if (FileExist(this.manifestPath)) {
                Log("Deleting manifest file: " . this.manifestPath)
                FileDelete(this.manifestPath)
                Log("Deleted manifest file: " . this.manifestPath)
            }

            if (FileExist(this.altManifestPath)) {
                Log("Deleting alternative manifest file: " . this.altManifestPath)
                FileDelete(this.altManifestPath)
                Log("Deleted alternative manifest file: " . this.altManifestPath)
            }

            ; If we had a specific path from registry, make sure it's deleted
            if (currentManifestPath && currentManifestPath != this.manifestPath && currentManifestPath != this.altManifestPath) {
                if (FileExist(currentManifestPath)) {
                    Log("Deleting registered manifest file: " . currentManifestPath)
                    FileDelete(currentManifestPath)
                    Log("Deleted registered manifest file: " . currentManifestPath)
                }
            }

            ; Verify key is gone
            try {
                RegRead(this.registryKey)
                this.lastError := "WARNING: Registry key still exists after deletion attempts"
                Log(this.lastError)
            } catch Error as e {
                Log("Verified registry key was deleted successfully")
            }

            Log("Unregistration completed successfully")
            return true
        } catch Error as e {
            this.lastError := "Failed to unregister: " . e.Message
            Log(this.lastError)
            MsgBox("Failed to unregister: " . e.Message, "Unregister Error", "Icon!")
            Log("Unregister error: " . e.Message)
            return false
        }
    }

    ; Get the last error message
    GetLastError() {
        return this.lastError
    }
}
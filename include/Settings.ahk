; Settings.ahk - Handles persistent application settings
; Manages loading/saving settings from/to INI file with proper fallback logic

class Settings {
    ; Default settings to use if no INI exists or can't be read
    static Defaults := Map(
        "isSkipDoubleClicked", false,
        "skipRegionLeft", 0,
        "skipRegionTop", 0,
        "skipRegionRight", 0,
        "skipRegionBottom", 0,
        "skipRegionActive", false,
        "isLeftArrowBlocked", false,
        "isRightArrowBlocked", false,
        "isUpArrowBlocked", false,
        "isDownArrowBlocked", false,
        "isEmergencyShutdownEnabled", false,
        "isRegionAlwaysVisible", true,
        "isSkipperSuppressed", false,
        "regionTransparency", 135,
        "regionColor", "0x209CEE",  ; Default blue color
        "showRegionText", true,
        "showTooltipHints", true
    )

    ; Storage for current settings
    values := Map()
    iniPath := ""
    isInitialized := false

    __New() {
        this.DetermineIniPath()
        this.LoadSettings()
    }

    ; Determine the best path for INI storage
    DetermineIniPath() {
        ; First try script directory (same as exe/ahk)
        scriptDirPath := A_ScriptDir "\skipper.ini"

        ; Test if we can write to script directory
        try {
            testFile := A_ScriptDir "\writetest.tmp"
            FileAppend("test", testFile)
            FileDelete(testFile)

            this.iniPath := scriptDirPath
            Logger.Info("Settings: Using script directory for settings: " . this.iniPath)
            return
        }
        catch {
            Logger.Info("Settings: Cannot write to script directory, falling back to local app data")
        }

        ; Fallback to local app data folder
        this.iniPath := A_AppData "\OmegleLike Skipper\skipper.ini"

        ; Ensure directory exists
        SplitPath(this.iniPath, , &settingsDir)
        if !DirExist(settingsDir)
            DirCreate(settingsDir)

        Logger.Info("Settings: Using local app data for settings: " . this.iniPath)
    }

    ; Load settings from INI file or use defaults
    LoadSettings() {
        ; Always start with defaults for safety
        this.ResetToDefaults()

        ; Try to read from INI file
        if !FileExist(this.iniPath) {
            Logger.Info("Settings: No settings file found, creating with defaults")
            ; Save defaults to create initial file
            this.SaveSettings()
            this.isInitialized := true
            return
        }

        Logger.Info("Settings: Found INI file: " . this.iniPath)

        ; Check if file is readable and valid
        try {
            ; Load all settings safely (with validation)
            Logger.Info("Settings: Loading values from INI file...")

            ; Skip region settings
            this._LoadIntValue("skipRegionLeft", "Regions", "SkipLeft", 0, 10000)
            this._LoadIntValue("skipRegionTop", "Regions", "SkipTop", 0, 10000)
            this._LoadIntValue("skipRegionRight", "Regions", "SkipRight", 0, 10000)
            this._LoadIntValue("skipRegionBottom", "Regions", "SkipBottom", 0, 10000)
            this._LoadBoolValue("skipRegionActive", "Regions", "SkipActive")
            this._LoadBoolValue("isSkipDoubleClicked", "Features", "SkipDoubleClick")
            this._LoadBoolValue("isRegionAlwaysVisible", "Features", "RegionAlwaysVisible")
            this._LoadIntValue("regionTransparency", "Appearance", "RegionTransparency", 0, 255)
            this._LoadStringValue("regionColor", "Appearance", "RegionColor")

            ; New options
            this._LoadBoolValue("showRegionText", "Options", "ShowRegionText")
            this._LoadBoolValue("showTooltipHints", "Options", "ShowTooltips")

            ; Key blocking section
            this._LoadBoolValue("isLeftArrowBlocked", "Features", "LeftArrowBlock")
            this._LoadBoolValue("isRightArrowBlocked", "Features", "RightArrowBlock")
            this._LoadBoolValue("isUpArrowBlocked", "Features", "UpArrowBlock")
            this._LoadBoolValue("isDownArrowBlocked", "Features", "DownArrowBlock")

            ; Emergency shutdown setting
            this._LoadBoolValue("isEmergencyShutdownEnabled", "Features", "EmergencyShutdown")

            Logger.Info("Settings: Successfully loaded all settings from INI")
        }
        catch as err {
            Logger.Error("Settings: Error loading settings, using defaults and rebuilding file: " . err.Message)
            this.ResetToDefaults()

            ; Try to back up the corrupted file
            try {
                if FileExist(this.iniPath) {
                    backupPath := this.iniPath . ".bak"
                    FileCopy(this.iniPath, backupPath, true)
                    Logger.Info("Settings: Backed up corrupted file to " . backupPath)
                }
            } catch as backupErr {
                Logger.Info("Settings: Could not back up corrupted file: " . backupErr.Message)
            }

            ; Create a new clean file
            this.SaveSettings()
        }

        this.isInitialized := true
    }

    ; Reset all settings to default values
    ResetToDefaults() {
        this.values := Settings.Defaults.Clone()
        Logger.Info("Settings: Reset to defaults")
    }

    ; Read a value from INI safely, never throwing an exception
    _ReadIniSafe(section, key, defaultValue) {
        try {
            return IniRead(this.iniPath, section, key, defaultValue)
        } catch {
            return defaultValue
        }
    }

    ; Helper to load a boolean value with validation
    _LoadBoolValue(key, section, name) {
        try {
            defaultValue := this.values[key]
            stringValue := this._ReadIniSafe(section, name, this.BoolToString(defaultValue))
            this.values[key] := this.StringToBool(stringValue)
            Logger.Info("Settings: Loaded " . key . " = " . this.values[key])
        } catch {
            ; If any error occurs, keep the default
            Logger.Info("Settings: Error loading " . key . ", using default: " . this.values[key])
        }
    }

    ; Helper to load an integer value with range validation
    _LoadIntValue(key, section, name, min := -100000, max := 100000) {
        try {
            defaultValue := this.values[key]
            stringValue := this._ReadIniSafe(section, name, defaultValue)

            ; Convert to integer and validate range
            intValue := Integer(stringValue)
            if (intValue < min || intValue > max) {
                Logger.Info("Settings: Value for " . key . " out of range (" . intValue . "), using default")
                return
            }

            this.values[key] := intValue
            Logger.Info("Settings: Loaded " . key . " = " . this.values[key])
        } catch {
            ; If any error occurs, keep the default
            Logger.Info("Settings: Error loading " . key . ", using default: " . this.values[key])
        }
    }

    ; Helper to load a string value
    _LoadStringValue(key, section, name) {
        try {
            defaultValue := this.values[key]
            stringValue := this._ReadIniSafe(section, name, defaultValue)
            this.values[key] := stringValue
            Logger.Info("Settings: Loaded " . key . " = " . this.values[key])
        } catch {
            ; If any error occurs, keep the default
            Logger.Info("Settings: Error loading " . key . ", using default: " . this.values[key])
        }
    }

    ; Save current settings to INI file
    SaveSettings() {
        try {
            Logger.Info("Settings: Saving settings to " . this.iniPath)

            ; Skip region settings
            IniWrite(this.values["skipRegionLeft"], this.iniPath, "Regions", "SkipLeft")
            IniWrite(this.values["skipRegionTop"], this.iniPath, "Regions", "SkipTop")
            IniWrite(this.values["skipRegionRight"], this.iniPath, "Regions", "SkipRight")
            IniWrite(this.values["skipRegionBottom"], this.iniPath, "Regions", "SkipBottom")
            IniWrite(this.BoolToString(this.values["skipRegionActive"]), this.iniPath, "Regions", "SkipActive")
            IniWrite(this.BoolToString(this.values["isSkipDoubleClicked"]), this.iniPath, "Features", "SkipDoubleClick")
            IniWrite(this.BoolToString(this.values["isRegionAlwaysVisible"]), this.iniPath, "Features", "RegionAlwaysVisible")
            IniWrite(this.values["regionTransparency"], this.iniPath, "Appearance", "RegionTransparency")
            IniWrite(this.values["regionColor"], this.iniPath, "Appearance", "RegionColor")

            ; New options
            IniWrite(this.BoolToString(this.values["showRegionText"]), this.iniPath, "Options", "ShowRegionText")
            IniWrite(this.BoolToString(this.values["showTooltipHints"]), this.iniPath, "Options", "ShowTooltips")

            ; Key blocking settings
            IniWrite(this.BoolToString(this.values["isLeftArrowBlocked"]), this.iniPath, "Features", "LeftArrowBlock")
            IniWrite(this.BoolToString(this.values["isRightArrowBlocked"]), this.iniPath, "Features", "RightArrowBlock")
            IniWrite(this.BoolToString(this.values["isUpArrowBlocked"]), this.iniPath, "Features", "UpArrowBlock")
            IniWrite(this.BoolToString(this.values["isDownArrowBlocked"]), this.iniPath, "Features", "DownArrowBlock")

            ; Emergency shutdown setting
            IniWrite(this.BoolToString(this.values["isEmergencyShutdownEnabled"]), this.iniPath, "Features", "EmergencyShutdown")

            Logger.Info("Settings: Successfully saved all settings to INI")

            return true
        }
        catch as err {
            Logger.Error("Settings: Failed to save settings: " . err.Message)
            return false
        }
    }

    ; Get a setting value
    Get(key, defaultValue := "") {
        ; If we have this key, return it
        if (this.values.Has(key))
            return this.values[key]

        ; If not but we have a matching Default, use that
        if (Settings.Defaults.Has(key))
            return Settings.Defaults[key]

        ; Otherwise fall back to provided default
        return defaultValue
    }

    ; Set a setting value
    Set(key, value) {
        ; Check if value changed
        valueChanged := (!this.values.Has(key) || this.values[key] != value)

        ; Store new value
        this.values[key] := value

        ; Only update file if value changed and we're initialized
        if (valueChanged && this.isInitialized) {
            this.SaveSettings()
        }

        return value
    }

    ; Convert boolean to string
    BoolToString(boolValue) {
        return boolValue ? "true" : "false"
    }

    ; Convert string to boolean
    StringToBool(strValue) {
        ; Any case variation of "true" or "1" is considered true
        return (StrLower(strValue) = "true" || strValue = "1")
    }
}
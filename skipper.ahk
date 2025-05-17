#NoTrayIcon
#SingleInstance Force
;@Ahk2Exe-SetMainIcon icon.ico
;@Ahk2Exe-AddResource icon.ico, 160  ; Replaces 'H on blue'
;@Ahk2Exe-AddResource icon.ico, 206  ; Replaces 'S on green'
;@Ahk2Exe-AddResource icon.ico, 207  ; Replaces 'H on red'
;@Ahk2Exe-AddResource icon.ico, 208  ; Replaces 'S on red'
;@Ahk2Exe-Obey U_VERSION, U_Version := Integer(EnvGet("CI_VERSION"))
;@Ahk2Exe-SetVersion %U_VERSION%

; Include dependencies - updated to use include folder
#Include include/Jxon.ahk
#Include include/NativeMessagingHost.ahk
#Include include/RegistrationHelper.ahk
#Include include/ClickHandler.ahk
#Include include/RegionHandler.ahk
#Include include/MessagingHostGUI.ahk
#Include include/MessageProcessor.ahk
#Include include/Utilities.ahk
#Include include/ClickState.ahk
#Include include/TooltipManager.ahk
#Include include/Hotkeys.ahk
#Include include/Settings.ahk

; Version information for update checking
global AppVersion := A_IsCompiled ? FileGetVersion(A_ScriptFullPath) : "dev"
global AppName := "OmegleLike Skipper"
global RepoOwner := "videochat-extension"
global RepoName := "skipper"

; Set coordinate mode to screen (absolute) for mouse operations
CoordMode("Mouse", "Screen")  ; Use absolute screen coordinates
CoordMode("ToolTip", "Screen")  ; Also set ToolTips to use screen coordinates

; Settings manager object
global settingsManager := ""

; Feature flags - each of these can be toggled through the GUI
global isSkipDoubleClicked := false  ; Whether to double-click the skip button
global isLeftArrowBlocked := true  ; Block left arrow key for skip
global isRightArrowBlocked := true  ; Block right arrow key for toggle
global isUpArrowBlocked := true  ; Block up arrow key for blacklist + skip
global isDownArrowBlocked := true  ; Block down arrow key for blacklist only
global isEmergencyShutdownEnabled := false  ; Enable emergency shutdown on right-arrow hold
global isRegionAlwaysVisible := false  ; Whether to always show the region
global isSkipperSuppressed := false  ; Whether skipper functionality is suppressed
global showRegionText := false  ; Show text in region overlay
global showTooltipHints := true  ; Show tooltip hints by default

; Other global variables
global host := ""  ; Global reference to messaging host for hotkey notifications

; Configuration for the native messaging host
global HOST_NAME := "com.omeglelike.skipper"  ; Host identifier
global HOST_DESCRIPTION := "AutoHotkey Automation Assistant for Omegle-like sites"
global ALLOWED_ORIGINS := ["chrome-extension://alchldmijhnnapijdmchpkdeikibjgoi/", "chrome-extension://jdpiggacibaaecfbegkhakcmgaafjajn/"]

; Main application
Main() {
    global host, HOST_NAME, HOST_DESCRIPTION, ALLOWED_ORIGINS
    global settingsManager, isSkipDoubleClicked, isRegionAlwaysVisible, isSkipperSuppressed, regionTransparency, regionColor
    global isLeftArrowBlocked, isRightArrowBlocked, isUpArrowBlocked, isDownArrowBlocked, isEmergencyShutdownEnabled
    global showRegionText, showTooltipHints

    Log("====== Application Starting ======")
    Log("Version: " . AppVersion)
    Log("Running as executable: " . (A_IsCompiled ? "Yes" : "No"))
    Log("Script directory: " . A_ScriptDir)
    Log("Working directory: " . A_WorkingDir)
    Log("OS version: " . A_OSVersion)
    Log("==============================")

    ; Create a mutex to help Inno Setup detect if the application is running
    DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "OmegleLikeSkipperMutex")
    Log("Created application mutex for single-instance detection")

    ; Initialize settings manager
    Log("Initializing settings manager...")
    settingsManager := Settings()

    ; Load settings into global variables for compatibility
    Log("Loading settings into global variables...")
    isSkipDoubleClicked := settingsManager.Get("isSkipDoubleClicked")
    isRegionAlwaysVisible := settingsManager.Get("isRegionAlwaysVisible")
    isSkipperSuppressed := settingsManager.Get("isSkipperSuppressed")
    regionTransparency := settingsManager.Get("regionTransparency")
    regionColor := settingsManager.Get("regionColor", "0x33FF33")  ; Default to green if not set

    isLeftArrowBlocked := settingsManager.Get("isLeftArrowBlocked")
    isRightArrowBlocked := settingsManager.Get("isRightArrowBlocked")
    isUpArrowBlocked := settingsManager.Get("isUpArrowBlocked")
    isDownArrowBlocked := settingsManager.Get("isDownArrowBlocked")
    isEmergencyShutdownEnabled := settingsManager.Get("isEmergencyShutdownEnabled")
    
    showRegionText := settingsManager.Get("showRegionText")
    showTooltipHints := settingsManager.Get("showTooltipHints")

    ; Initialize TooltipManager with tooltip setting
    Log("Initializing TooltipManager...")
    TooltipManager.Initialize(showTooltipHints)

    Log("Settings loaded: Double-click settings: Skip=" . isSkipDoubleClicked)
    Log("Region always visible: " . isRegionAlwaysVisible)
    Log("Skipper suppressed: " . isSkipperSuppressed)
    Log("Region transparency: " . regionTransparency)
    Log("Region color: " . regionColor)
    Log("Show region text: " . showRegionText)
    Log("Show tooltip hints: " . showTooltipHints)
    Log("Key blocking: Left Arrow=" . isLeftArrowBlocked . ", Right Arrow=" . isRightArrowBlocked . ", Up Arrow=" . isUpArrowBlocked . ", Down Arrow=" . isDownArrowBlocked)
    Log("Emergency Shutdown: " . isEmergencyShutdownEnabled)

    ; Initialize and load region handler
    Log("Initializing region handler...")
    RegionHandler.Initialize()
    RegionHandler.LoadFromSettings()

    ; Check for updates silently at startup
    Log("Checking for updates (silent mode)...")
    CheckForUpdates(true)

    ; Create the registration helper
    Log("Creating registration helper...")
    regHelper := RegistrationHelper(HOST_NAME, HOST_DESCRIPTION, ALLOWED_ORIGINS)

    ; Always force registration on startup (foolproof approach)
    Log("Always recreating manifest and registry on startup...")
    registrationSucceeded := regHelper.ForceRegister()

    if (registrationSucceeded) {
        Log("Registration successful")
    } else {
        errorMsg := regHelper.GetLastError()
        Log("Registration failed: " . errorMsg)
    }

    ; Create the native messaging host
    Log("Creating native messaging host...")
    host := NativeMessagingHost()

    ; Create the GUI with registration helper
    Log("Creating application GUI...")
    gui := MessagingHostGUI(host, regHelper)

    ; Set the global GUI reference for centralized logging
    Log("Setting up centralized logging...")
    SetGUIReference(gui)

    ; Create the message processor
    Log("Creating message processor...")
    processor := MessageProcessor(gui, host)

    ; Set the message callback
    host.onMessageCallback := ObjBindMethod(processor, "ProcessMessage")
    Log("Message callback handler registered")

    ; Set up disconnect callback if not in manual mode
    if (!host.isManualMode) {
        host.onDisconnect := ObjBindMethod(gui, "LogDisconnection")
        Log("Disconnect handler registered")
    }

    ; Start listening for messages if not in manual mode
    if (!host.isManualMode) {
        host.StartListening(100)  ; Check every 100ms
        Log("Chrome Native Messaging Host started")
        Log("Waiting for messages...")

        ; Log registration status
        regStatusText := regHelper.IsRegistered()
            ? "Native messaging host is registered"
            : "Native messaging host is NOT registered - automatic connections from Chrome won't work"

        Log(regStatusText)
    } else {
        ; Log manual mode
        Log("Application started in MANUAL MODE")
        Log("No Chrome connection - running standalone")
    }

    ; Initialize UI elements with loaded settings
    Log("Initializing UI elements with loaded settings...")
    gui.InitializeUIFromSettings()

    ; If region always visible is enabled, show the region
    if (isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
        Log("Showing always-visible region overlay...")
        RegionHandler.ShowRegionOverlay()
    }

    Log("Initialization complete!")
}

; Function to update a setting in a more reliable way
UpdateSetting(key, value) {
    global settingsManager

    ; Update in settings manager first
    settingsManager.Set(key, value)

    ; Now update global variables directly - using a much safer approach
    ; Instead of dynamic variable references, use the proper global keywords
    global isSkipDoubleClicked
    global isLeftArrowBlocked, isRightArrowBlocked, isUpArrowBlocked, isDownArrowBlocked
    global isEmergencyShutdownEnabled
    global isRegionAlwaysVisible
    global isSkipperSuppressed
    global regionTransparency
    global regionColor
    global showRegionText, showTooltipHints

    ; Now we can use a switch statement which is cleaner and more maintainable
    switch key {
        case "isSkipDoubleClicked": isSkipDoubleClicked := value
        case "isLeftArrowBlocked": isLeftArrowBlocked := value
        case "isRightArrowBlocked": isRightArrowBlocked := value
        case "isUpArrowBlocked": isUpArrowBlocked := value
        case "isDownArrowBlocked": isDownArrowBlocked := value
        case "isEmergencyShutdownEnabled": isEmergencyShutdownEnabled := value
        case "isRegionAlwaysVisible": 
            isRegionAlwaysVisible := value
            ; Handle visibility toggle regardless of active status
            if (value) {
                ; If toggled on, show region overlay if region exists
                if (RegionHandler.skipRegion.active)
                    RegionHandler.ShowRegionOverlay()
            } else {
                ; If toggled off, always hide region overlay
                RegionHandler.HideRegionOverlay()
            }
        case "isSkipperSuppressed": isSkipperSuppressed := value
        case "regionTransparency": 
            regionTransparency := value
            if (isRegionAlwaysVisible && RegionHandler.skipRegion.active)
                RegionHandler.UpdateRegionTransparency(value)
        case "regionColor":
            regionColor := value
            if (isRegionAlwaysVisible && RegionHandler.skipRegion.active)
                RegionHandler.UpdateRegionColor(value)
        case "showRegionText": showRegionText := value
        case "showTooltipHints": 
            showTooltipHints := value
            TooltipManager.SetTooltipsEnabled(value)
        case "skipRegionLeft", "skipRegionTop", "skipRegionRight", "skipRegionBottom", "skipRegionActive":
            ; If any region property is updated, refresh the RegionHandler
            RegionHandler.LoadFromSettings()
            ; Update region overlay if always visible is enabled
            if (isRegionAlwaysVisible && RegionHandler.skipRegion.active)
                RegionHandler.ShowRegionOverlay()
    }

    return value
}

; Start the application
Main()
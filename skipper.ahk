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
#Include include/Logger.ahk
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

; URL Constants
global URL_FEEDBACK_FORM := "https://skipper.omeglelike.com/feedback"
global URL_EXTENSION_INSTALL := "https://vext.omeglelike.com/install"
global URL_PROJECT_HOMEPAGE := "https://skipper.omeglelike.com"
global URL_OMEGLE_DIRECTORY := "https://omeglelike.com"
global URL_MANUAL_UPDATE := "https://skipper.omeglelike.com/latest"
global URL_EMERGENCY_TROUBLESHOOTING := "https://pastebin.com/embed_iframe/sfG3zvRT"

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

    ; Initialize the Logger
    Logger.Init()
    
    Logger.Info("====== Application Starting ======")
    Logger.Info("Version: " . AppVersion)
    Logger.Info("Running as executable: " . (A_IsCompiled ? "Yes" : "No"))
    Logger.Info("Script directory: " . A_ScriptDir)
    Logger.Info("Working directory: " . A_WorkingDir)
    Logger.Info("OS version: " . A_OSVersion)
    Logger.Info("==============================")

    ; Create a mutex to help Inno Setup detect if the application is running
    DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "OmegleLikeSkipperMutex")
    Logger.Info("Created application mutex for single-instance detection")

    ; Initialize settings manager
    Logger.Info("Initializing settings manager...")
    settingsManager := Settings()

    ; Load settings into global variables for compatibility
    Logger.Info("Loading settings into global variables...")
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
    Logger.Info("Initializing TooltipManager...")
    TooltipManager.Initialize(showTooltipHints)

    Logger.Info("Settings loaded: Double-click settings: Skip=" . isSkipDoubleClicked)
    Logger.Info("Region always visible: " . isRegionAlwaysVisible)
    Logger.Info("Skipper suppressed: " . isSkipperSuppressed)
    Logger.Info("Region transparency: " . regionTransparency)
    Logger.Info("Region color: " . regionColor)
    Logger.Info("Show region text: " . showRegionText)
    Logger.Info("Show tooltip hints: " . showTooltipHints)
    Logger.Info("Key blocking: Left Arrow=" . isLeftArrowBlocked . ", Right Arrow=" . isRightArrowBlocked . ", Up Arrow=" . isUpArrowBlocked . ", Down Arrow=" . isDownArrowBlocked)
    Logger.Info("Emergency Shutdown: " . isEmergencyShutdownEnabled)

    ; Initialize and load region handler
    Logger.Info("Initializing region handler...")
    RegionHandler.Initialize()
    RegionHandler.LoadFromSettings()

    ; Check for updates silently at startup
    Logger.Info("Checking for updates (silent mode)...")
    CheckForUpdates(true)

    ; Create the registration helper
    Logger.Info("Creating registration helper...")
    regHelper := RegistrationHelper(HOST_NAME, HOST_DESCRIPTION, ALLOWED_ORIGINS)

    ; Always force registration on startup (foolproof approach)
    Logger.Info("Always recreating manifest and registry on startup...")
    registrationSucceeded := regHelper.ForceRegister()

    if (registrationSucceeded) {
        Logger.Info("Registration successful")
    } else {
        errorMsg := regHelper.GetLastError()
        Logger.Error("Registration failed: " . errorMsg)
    }

    ; Create the native messaging host
    Logger.Info("Creating native messaging host...")
    host := NativeMessagingHost()

    ; Create the GUI with registration helper
    Logger.Info("Creating application GUI...")
    gui := MessagingHostGUI(host, regHelper)

    ; Create the message processor
    Logger.Info("Creating message processor...")
    processor := MessageProcessor(gui, host)

    ; Set the message callback
    host.onMessageCallback := ObjBindMethod(processor, "ProcessMessage")
    Logger.Info("Message callback handler registered")

    ; Set up disconnect callback if not in manual mode
    if (!host.isManualMode) {
        host.onDisconnect := ObjBindMethod(gui, "LogDisconnection")
        Logger.Info("Disconnect handler registered")
    }

    ; Start listening for messages if not in manual mode
    if (!host.isManualMode) {
        host.StartListening(100)  ; Check every 100ms
        Logger.Info("Chrome Native Messaging Host started")
        Logger.Info("Waiting for messages...")

        ; Log registration status
        regStatusText := regHelper.IsRegistered()
            ? "Native messaging host is registered"
            : "Native messaging host is NOT registered - automatic connections from Chrome won't work"

        Logger.Info(regStatusText)
    } else {
        ; Log manual mode
        Logger.Info("Application started in MANUAL MODE")
        Logger.Info("No Chrome connection - running standalone")
    }

    ; Initialize UI elements with loaded settings
    Logger.Info("Initializing UI elements with loaded settings...")
    gui.InitializeUIFromSettings()

    ; If region always visible is enabled, show the region
    if (isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
        Logger.Info("Showing always-visible region overlay...")
        RegionHandler.ShowRegionOverlay()
    }

    Logger.Info("Initialization complete!")
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
; GUI class to handle the user interface
class MessagingHostGUI {
    ; GUI components
    MainGui := ""
    LogEdit := ""
    guiLog := ""
    logEntryCount := 0  ; Track number of log entries
    maxLogEntries := 100  ; Maximum number of log entries to keep
    StatusBar := ""
    TabsControl := ""  ; Store tabs control as class property

    ; Tracking flags for tab rendering
    wasLaunchedMinimized := false
    redrawAlreadyPerformed := false

    ; Skip region info display components
    skipRegionText := ""
    skipDoubleClickCb := ""  ; Component for skip double-click option
    regionAlwaysVisibleCb := ""  ; Component for always show region option
    skipperEnabledCb := ""  ; Component for enabling/disabling skipper functionality
    transparencySlider := ""  ; Slider for region overlay transparency
    transparencyText := ""    ; Text for transparency label
    regionColorBtn := ""      ; Button for region color selection
    regionColorText := ""     ; Text to display current color
    option1Cb := ""          ; New checkbox 1
    option2Cb := ""          ; New checkbox 2

    ; Arrow key checkboxes
    leftArrowCb := ""
    rightArrowCb := ""
    upArrowCb := ""
    downArrowCb := ""
    emergencyShutdownCb := ""  ; New checkbox for emergency shutdown feature

    ; Reference to the messaging host
    host := ""

    ; Registration helper reference
    regHelper := ""

    ; Constructor
    __New(host, regHelper := "") {
        this.host := host
        this.regHelper := regHelper
        this.CreateGui()

        ; Store global reference to this GUI instance for hotkey access
        global gGui := this

        ; Show manual mode warning if needed
        if (host.isManualMode)
            this.ShowManualModeWarning()
    }

    ; Create the GUI
    CreateGui() {
        ; Create the main window with fixed size
        this.MainGui := Gui("", "OmegleLike Skipper - Skip Automation")
        this.MainGui.SetFont("s10", "Segoe UI")
        this.MainGui.MarginX := 10
        this.MainGui.MarginY := 10

        ; No menu bar needed

        ; Add status bar
        this.StatusBar := this.MainGui.Add("StatusBar")
        this.UpdateStatusBar()

        ; Create tabs
        this.TabsControl := this.MainGui.Add("Tab3", "w460 h495", ["Clicker", "Log", "About"])

        ; ================ CLICKER TAB ================
        this.TabsControl.UseTab(1)

        ; Skip region text display moved to the top
        this.skipRegionText := this.MainGui.Add("Text", "x20 y40 w430 h20", "No region selected. Please define a region for the Skip button.")
        this.skipRegionText.SetFont("bold")
        ; Add instruction text
        this.MainGui.Add("Text", "x20 y60 w430 h20", "Define the skip button region and use arrows or extension to skip.")
        this.MainGui.Add("Text", "x20 y80 w430 h20", "If the mouse is within the area and not moving, it will automate the skip.")

        ; Skip Region Selection - center - moved down slightly
        this.MainGui.SetFont("s10 bold")
        this.MainGui.Add("GroupBox", "x15 y100 w450 h135", "Skip Button Region")
        this.MainGui.SetFont("s10 norm")

        ; Initialize the color button with current color
        global regionColor
        if (!regionColor)
            regionColor := "0x33FF33"  ; Default green

        this.skipperEnabledCb := this.MainGui.Add("Checkbox", "x30 y122 w180 h25", "Disable everything (temp)")
        this.skipperEnabledCb.OnEvent("Click", ObjBindMethod(this, "ToggleSkipperEnabled"))

        ; Add the new option checkboxes at the same y-level but at transparency x position
        this.option1Cb := this.MainGui.Add("Checkbox", "x245 y122 w210 h25", "Show text in region overlay")
        this.option1Cb.OnEvent("Click", ObjBindMethod(this, "ToggleOption1"))

        this.option2Cb := this.MainGui.Add("Checkbox", "x245 y147 w210 h25", "Show Tooltip Hints")
        this.option2Cb.OnEvent("Click", ObjBindMethod(this, "ToggleOption2"))

        ; Add double-click checkbox for skip - moved down
        this.skipDoubleClickCb := this.MainGui.Add("Checkbox", "x30 y147 w180 h25", "Use Double-Click")
        this.skipDoubleClickCb.OnEvent("Click", ObjBindMethod(this, "ToggleSkipDoubleClick"))

        ; Add always show region checkbox - moved further down
        this.regionAlwaysVisibleCb := this.MainGui.Add("Checkbox", "x30 y172 w200 h25", "Always Show Region Selected")
        this.regionAlwaysVisibleCb.OnEvent("Click", ObjBindMethod(this, "ToggleRegionAlwaysVisible"))

        ; Add transparency slider - adjusted position
        this.transparencyText := this.MainGui.Add("Text", "x245 y175 w80 h25", "Transparency:")
        this.transparencySlider := this.MainGui.Add("Slider", "x330 y175 w100 h25 Range0-255 TickInterval32 Tooltip", 128)
        this.transparencySlider.OnEvent("Change", ObjBindMethod(this, "UpdateRegionTransparency"))

        ; Skip action buttons - store references directly
        this.defineSkipRegionBtn := this.MainGui.Add("Button", "x25 y200 w210 h30", "Define Skip Region")
        this.defineSkipRegionBtn.SetFont("bold")
        this.defineSkipRegionBtn.OnEvent("Click", ObjBindMethod(this, "DefineSkipRegion"))

        this.changeRegionColorBtn := this.MainGui.Add("Button", "x245 y200 w210 h30", "Change Region Color")
        this.changeRegionColorBtn.OnEvent("Click", ObjBindMethod(this, "ChooseRegionColor"))

        ; Keyboard triggers - adjusted to have consistent spacing
        this.MainGui.SetFont("s10 bold")
        this.MainGui.Add("GroupBox", "x15 y240 w450 h110", "Keyboard Triggers")
        this.MainGui.SetFont("s10 norm")

        ; Restore checkboxes for keyboard triggers - left side
        this.leftArrowCb := this.MainGui.Add("Checkbox", "x30 y260 w200 h25", "Use Left Arrow Key to SKIP")
        this.leftArrowCb.OnEvent("Click", ObjBindMethod(this, "ToggleLeftArrowBlock"))

        this.rightArrowCb := this.MainGui.Add("Checkbox", "x30 y290 w200 h25", "Right Arrow to ON/OFF")
        this.rightArrowCb.OnEvent("Click", ObjBindMethod(this, "ToggleRightArrowBlock"))

        ; Add checkboxes for up/down arrow keys - right side
        this.upArrowCb := this.MainGui.Add("Checkbox", "x240 y260 w210 h25", "Up Arrow to BLACKLIST + SKIP")
        this.upArrowCb.OnEvent("Click", ObjBindMethod(this, "ToggleUpArrowBlock"))

        this.downArrowCb := this.MainGui.Add("Checkbox", "x240 y290 w210 h25", "Down Arrow to BLACKLIST")
        this.downArrowCb.OnEvent("Click", ObjBindMethod(this, "ToggleDownArrowBlock"))

        ; Disable up/down arrow checkboxes in manual mode
        if (this.host.isManualMode) {
            this.upArrowCb.Enabled := false
            this.downArrowCb.Enabled := false
        }

        ; Add emergency shutdown checkbox with updated description
        this.emergencyShutdownCb := this.MainGui.Add("Checkbox", "x30 y320 w420 h25 +cRed", "Shutdown: Right Arrow (released after 1s+) exits immediately")
        this.emergencyShutdownCb.OnEvent("Click", ObjBindMethod(this, "ToggleEmergencyShutdown"))

        ; Instructions - adjusted to have consistent spacing
        this.MainGui.SetFont("s10 bold")
        this.MainGui.Add("GroupBox", "x15 y350 w450 h155", "Instructions")
        this.MainGui.SetFont("s10 norm")

        instructionsText := "QUICK START GUIDE:`r`n`r`n"
            . "1. Click 'Define Skip Region' and select where the skip button is on your screen, depending on the site you are using.`r`n"
            . "2. If your skip button needs a double-click, check that box.`r`n"
            . "3. Enable keyboard shortcuts or use Videochat Extension.`r`n"
            . "4. Move your mouse to the skip region, now when skip is needed it will be automated.`r`n"
            . "5. KEYBOARD SHORTCUTS - Just press and release:`r`n"
            . "   - Left Arrow: Skip current chat`r`n"
            . "   - Right Arrow (quick tap): Turn Skipper ON/OFF`r`n"
            . "   - Right Arrow (hold 1-3s): Skip or exit (if emergency shutdown is on)`r`n"
            . "   - Up Arrow: Blacklist + Skip (needs extension)`r`n"
            . "   - Down Arrow: Just blacklist (needs extension)`r`n"
            . "   Pro tip: Hold any key for 3+ seconds to cancel the action.`r`n"
            . "6. SHUTDOWN KEY: If enabled, holding Right Arrow for 1-3s will instantly close the app.`r`n"
            . "7. REMEMBER: Your mouse must be stationary within the skip region for clicks to work.`r`n"
            . "8. EXTENSION USERS: Don't forget to enable Skipper in your extension settings!"

        ; Use Edit control with readonly and scrollbars instead of Text control
        this.MainGui.Add("Edit", "x30 y370 w420 h125 +ReadOnly +Multi +VScroll", instructionsText)

        ; ================ LOG TAB ================
        this.TabsControl.UseTab(2)

        this.LogEdit := this.MainGui.Add("Edit", "x15 y45 w450 h455 +Multi +ReadOnly +VScroll +WantReturn", "")
        this.LogEdit.Value := "Logging is temporarily disabled"

        ; ================ ABOUT & FEEDBACK TAB ================
        this.TabsControl.UseTab(3)

        ; Using the same consistent y40 starting position
        this.MainGui.Add("GroupBox", "x15 y40 w450 h145", "About " . AppName)
        this.MainGui.Add("Text", "x30 y65 w420 Center", "Version: " . AppVersion)
        this.MainGui.Add("Text", "x30 y90 w420 Center", "Automate clicks on Omegle-like sites.")
        this.MainGui.Add("Text", "x30 y115 w420 Center", "Github: " . RepoOwner . "/" . RepoName)

        ; Update button - part of the About section - added emoji
        updateBtn := this.MainGui.Add("Button", "x125 y145 w230 h35", "🔄 Check for Updates")
        updateBtn.OnEvent("Click", (*) => CheckForUpdates(false))

        ; Links section - moved to be second in order
        this.MainGui.Add("GroupBox", "x15 y200 w450 h80", "Useful Links")

        ; Homepage button
        homepageBtn := this.MainGui.Add("Button", "x35 y230 w190 h35", "🏠 Open Homepage")
        homepageBtn.OnEvent("Click", ObjBindMethod(this, "OpenHomepage"))

        ; Directory button with omega symbol
        directoryBtn := this.MainGui.Add("Button", "x240 y230 w190 h35", "Ω List of Omegle Clones")
        directoryBtn.OnEvent("Click", ObjBindMethod(this, "OpenDirectory"))

        ; Help & Feedback section - moved to be third
        this.MainGui.Add("GroupBox", "x15 y290 w450 h95", "Feedback")
        this.MainGui.Add("Text", "x30 y315 w420 Center", "We value your feedback! Please help us improve.")

        ; Feedback button with stronger styling - adjusted y position for consistent spacing
        feedbackBtn := this.MainGui.Add("Button", "x125 y345 w230 h35 +c0x4CAF50", "🗣️ Leave Feedback")
        feedbackBtn.OnEvent("Click", ObjBindMethod(this, "OpenFeedbackForm"))

        ; Window events
        this.MainGui.OnEvent("Close", (*) => ExitApp())

        ; Add a custom handler for WM_SYSCOMMAND to detect unminimize
        OnMessage(0x0112, ObjBindMethod(this, "OnSysCommand"))

        ; Show the GUI with fixed size, minimized if region is already configured
        if (RegionHandler.skipRegion.active) {
            ; Show minimized since region is already defined
            this.MainGui.Show("w480 h530 Minimize")
            this.UpdateLog("Started minimized - skip region already configured")

            ; Mark as launched minimized for redraw handling
            this.wasLaunchedMinimized := true
            this.redrawAlreadyPerformed := false
        } else {
            ; Show normally since no region is defined
            this.MainGui.Show("w480 h530")

            ; We didn't start minimized
            this.wasLaunchedMinimized := false
        }

        ; Display registration status
        if (this.regHelper) {
            if (this.regHelper.IsRegistered()) {
                this.UpdateLog("✓ Native messaging host is registered with Chrome")
            } else {
                this.UpdateLog("⚠️ Registration status could not be confirmed")
            }
        }

        return this
    }

    ; Initialize UI elements from loaded settings
    InitializeUIFromSettings() {
        ; Load UI state from settings
        global isSkipDoubleClicked
        global isLeftArrowBlocked, isRightArrowBlocked, isUpArrowBlocked, isDownArrowBlocked
        global isEmergencyShutdownEnabled
        global isRegionAlwaysVisible
        global isSkipperSuppressed
        global regionTransparency
        global regionColor
        global showRegionText, showTooltipHints

        ; Update UI for skip region
        this.UpdateRegionDisplay()

        ; Update skipper enabled checkbox (directly matches suppressed state)
        this.skipperEnabledCb.Value := isSkipperSuppressed

        ; Update double-click checkboxes
        this.skipDoubleClickCb.Value := isSkipDoubleClicked

        ; Update new option checkboxes
        this.option1Cb.Value := showRegionText
        this.option2Cb.Value := showTooltipHints

        ; Update always show region checkbox
        this.regionAlwaysVisibleCb.Value := isRegionAlwaysVisible

        ; Update transparency slider
        this.transparencySlider.Value := regionTransparency

        ; Update arrow key checkboxes
        this.leftArrowCb.Value := isLeftArrowBlocked
        this.rightArrowCb.Value := isRightArrowBlocked

        ; Only update up/down arrow checkboxes if not in manual mode
        if (!this.host.isManualMode) {
            this.upArrowCb.Value := isUpArrowBlocked
            this.downArrowCb.Value := isDownArrowBlocked
        }

        ; Update emergency shutdown checkbox
        this.emergencyShutdownCb.Value := isEmergencyShutdownEnabled

        ; Update controls enabled state based on suppressed state
        this.UpdateControlsEnabledState(isSkipperSuppressed)
    }

    ; Toggle region always visible option
    ToggleRegionAlwaysVisible(*) {
        isAlwaysVisible := this.regionAlwaysVisibleCb.Value
        UpdateSetting("isRegionAlwaysVisible", isAlwaysVisible)
        Log("Always show region " . (isAlwaysVisible ? "enabled" : "disabled"))
    }

    ; Start the region selection process for the skip button
    DefineSkipRegion(*) {
        ; Call the RegionHandler to start selection
        RegionHandler.StartRegionSelection("skip")

        ; Update the UI after selection is complete
        SetTimer(() => this.UpdateRegionDisplay(), -1000)
    }

    ; Update the skip region display
    UpdateRegionDisplay() {
        if (RegionHandler.skipRegion.active) {
            ; Simplified display - just show that it's defined
            this.skipRegionText.Text := "Skip button region defined"
        } else {
            this.skipRegionText.Text := "No region selected. Please define a region for the Skip button."
        }
    }

    ; Test the click functionality
    TestClick(clickType, *) {
        this.UpdateLog("Testing " . clickType . " click...")

        ; Get the appropriate double-click setting
        useDoubleClick := false
        if (clickType = "skip") {
            useDoubleClick := this.skipDoubleClickCb.Value
        }

        ; Perform the click operation
        result := ClickHandler.PerformClick(clickType, useDoubleClick)

        if (result) {
            this.UpdateLog("Test " . clickType . " click successful")
        } else {
            this.UpdateLog("Test " . clickType . " click failed - cursor may not be in region")
        }
    }

    ; Toggle skip double-click option
    ToggleSkipDoubleClick(*) {
        isDoubleClick := this.skipDoubleClickCb.Value
        UpdateSetting("isSkipDoubleClicked", isDoubleClick)
        Log("Skip double-click " . (isDoubleClick ? "enabled" : "disabled"))
    }

    ; Toggle left arrow key block
    ToggleLeftArrowBlock(*) {
        isBlocked := this.leftArrowCb.Value
        UpdateSetting("isLeftArrowBlocked", isBlocked)
        Log("Left arrow key " . (isBlocked ? "blocked" : "unblocked"))
    }

    ; Toggle right arrow key block
    ToggleRightArrowBlock(*) {
        isBlocked := this.rightArrowCb.Value
        UpdateSetting("isRightArrowBlocked", isBlocked)
        Log("Right arrow key " . (isBlocked ? "blocked" : "unblocked"))
    }

    ; Toggle up arrow key block
    ToggleUpArrowBlock(*) {
        isBlocked := this.upArrowCb.Value
        UpdateSetting("isUpArrowBlocked", isBlocked)
        Log("Up arrow key " . (isBlocked ? "blocked" : "unblocked"))
    }

    ; Toggle down arrow key block
    ToggleDownArrowBlock(*) {
        isBlocked := this.downArrowCb.Value
        UpdateSetting("isDownArrowBlocked", isBlocked)
        Log("Down arrow key " . (isBlocked ? "blocked" : "unblocked"))
    }

    ; Toggle emergency shutdown
    ToggleEmergencyShutdown(*) {
        isShutdown := this.emergencyShutdownCb.Value
        UpdateSetting("isEmergencyShutdownEnabled", isShutdown)
        Log("Emergency shutdown " . (isShutdown ? "enabled" : "disabled"))
    }

    ; Toggle skipper enabled option
    ToggleSkipperEnabled(*) {
        isSuppressed := this.skipperEnabledCb.Value
        UpdateSetting("isSkipperSuppressed", isSuppressed)
        Log("Skipper functionality " . (isSuppressed ? "disabled" : "enabled"))

        ; Update UI controls based on suppressed state
        this.UpdateControlsEnabledState(isSuppressed)

        ; Handle region visibility when suppressed
        global isRegionAlwaysVisible
        if (isSuppressed && isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
            ; Hide the region overlay if suppressed and it was set to always visible
            RegionHandler.HideRegionOverlay()
        } else if (!isSuppressed && isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
            ; Show the region overlay if no longer suppressed and set to always visible
            RegionHandler.ShowRegionOverlay()
        }
    }

    ; Update UI controls enabled state based on skipper suppressed state
    UpdateControlsEnabledState(isSuppressed) {
        ; 1. Skip action buttons
        this.defineSkipRegionBtn.Enabled := !isSuppressed
        this.changeRegionColorBtn.Enabled := !isSuppressed

        ; 2. Transparency slider and text
        this.transparencySlider.Enabled := !isSuppressed
        this.transparencyText.Enabled := !isSuppressed

        ; 3. Double-click checkbox
        this.skipDoubleClickCb.Enabled := !isSuppressed

        ; 4. Always show region checkbox
        this.regionAlwaysVisibleCb.Enabled := !isSuppressed

        ; 5. Up/Down/Left arrow checkboxes
        this.leftArrowCb.Enabled := !isSuppressed

        ; 6. New option checkboxes
        this.option1Cb.Enabled := !isSuppressed
        this.option2Cb.Enabled := !isSuppressed

        ; Only enable Up/Down if not in manual mode and skipper is not suppressed
        if (!this.host.isManualMode) {
            this.upArrowCb.Enabled := !isSuppressed
            this.downArrowCb.Enabled := !isSuppressed
        }

        ; 7. DO NOT disable right arrow checkbox (always enabled)
        ; this.rightArrowCb.Enabled is not changed
    }

    ; Update region transparency from slider
    UpdateRegionTransparency(*) {
        transparency := this.transparencySlider.Value
        UpdateSetting("regionTransparency", transparency)
        Log("Region transparency set to " . transparency)
    }

    ; Update the status bar with Chrome connection status
    UpdateStatusBar(message := "") {
        if (this.host.isManualMode) {
            this.StatusBar.SetText("⚠️ MANUAL MODE - NOT CONNECTED TO VIDEOCHAT EXTENSION")
            this.StatusBar.SetParts(500)
            this.StatusBar.SetFont("cRed bold")
        } else {
            this.StatusBar.SetText("✓ Connected to Videochat Extension")
            this.StatusBar.SetFont("cGreen")
        }
    }

    ; Update the log display
    UpdateLog(text) {
        ; Skip empty messages
        ; disable logging for now
        if (true || text = "")
            return

        ; Add timestamp to log entry
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        this.guiLog .= timestamp . " | " . text . "`r`n"

        ; Update the edit control if it exists
        if (this.LogEdit) {
            ; Check if GUI exists first
            if (WinExist("ahk_id " . this.MainGui.Hwnd)) {
                this.LogEdit.Value := this.guiLog

                ; Auto-scroll to bottom using SendMessage
                DllCall("SendMessage", "Ptr", this.LogEdit.Hwnd, "UInt", 0x115, "Ptr", 7, "Ptr", 0)
            }
        }
    }

    ; Log a disconnection event
    LogDisconnection(*) {
        this.UpdateLog("!!! Chrome Native Messaging connection closed !!!")
        this.UpdateLog("Application will exit soon...")

        ; MsgBox("Chrome connection closed. Application will exit.", "Connection Closed", "T2 Icon!")
    }

    ; Show a warning about manual mode
    ShowManualModeWarning() {
        ; Create a custom dialog instead of MsgBox
        manualModeGui := Gui("+AlwaysOnTop -MinimizeBox", "OmegleLike Skipper Setup")
        manualModeGui.SetFont("s10", "Segoe UI")
        manualModeGui.MarginX := 15
        manualModeGui.MarginY := 15

        ; Add title and header
        manualModeGui.SetFont("s12 bold")
        if (A_Args.Length && A_Args[1] = "--from-setup") {
            manualModeGui.Add("Text", "w450 Center", "Setup Complete!")
            headerText := "OmegleLike Skipper has been installed successfully.`n"
                . "The skipper is now visible to your browser.`n`n"
                . "To use with Videochat Extension, you need to complete one more step."
        } else {
            manualModeGui.Add("Text", "w450 Center", "Running in Manual Mode")
            headerText := "OmegleLike Skipper is running but not connected to Videochat Extension.`n`n"
                . "For the best experience, the program should be connected.`n"
                . "Integration provides automated skipping based on your preferences."
        }

        ; Add main instruction text
        manualModeGui.SetFont("s10 norm")
        manualModeGui.Add("Text", "w450 y+15", headerText)

        ; Add options as buttons
        manualModeGui.SetFont("s10")
        manualModeGui.Add("GroupBox", "w450 h115 y+15", "What would you like to do?")

        ; Option 1 - Install extension
        installBtn := manualModeGui.Add("Button", "x30 yp+30 w430 h30", "Install Videochat Extension")
        installBtn.OnEvent("Click", (*) => this.OpenExtensionInstallPage(manualModeGui))

        ; Option 2 - Already have extension
        configBtn := manualModeGui.Add("Button", "x30 y+10 w430 h30", "I Already Have the Extension - Configure It")
        configBtn.OnEvent("Click", (*) => this.ShowExtensionUrlsDialog(manualModeGui))

        ; Option 3 - Continue in manual mode
        manualBtn := manualModeGui.Add("Button", "x30 y+25 w430 h35", "Continue in Manual Mode")
        manualBtn.OnEvent("Click", (*) => manualModeGui.Destroy())

        ; Add instruction text for manual mode as a clickable link
        manualModeGui.Add("Link", "w450 y+15", 'Manual Mode works too! <a href="https://pastebin.com/embed_iframe/sfG3zvRT">If something is VERY wrong, check this link.</a>')

        ; Set up handler for X button - exit the application
        manualModeGui.OnEvent("Close", (*) => ExitApp())

        ; Set initial focus on the appropriate button based on launch condition
        if (A_Args.Length && A_Args[1] = "--from-setup") {
            configBtn.Focus()  ; Focus on "Already Have the Extension" if from setup
        } else {
            manualBtn.Focus()  ; Focus on "Continue in Manual Mode" otherwise
        }

        ; Show dialog as modal - blocks until closed
        manualModeGui.Opt("+Owner" . this.MainGui.Hwnd)  ; Make it owned by the main window
        manualModeGui.Show("w480 h340")

        ; Create a WinWaitClose loop to make this function blocking
        WinWait("ahk_id " . manualModeGui.Hwnd)
        WinWaitClose("ahk_id " . manualModeGui.Hwnd)

        ; Update the window title to indicate manual mode
        this.MainGui.Title := this.MainGui.Title . " [MANUAL MODE]"
    }

    ; Open the extension installation page
    OpenExtensionInstallPage(ownerGui) {
        try {
            Run("https://vext.omeglelike.com/install")
            this.UpdateLog("Opened Videochat Extension installation page")
            ownerGui.Destroy()
        } catch Error as e {
            this.UpdateLog("Error opening extension installation page: " e.Message)
            MsgBox("Failed to open website. Please visit https://vext.omeglelike.com/install manually.", "Error", "Icon!")
        }
    }

    ; Show dialog with browser extension URLs to copy
    ShowExtensionUrlsDialog(ownerGui := "") {
        ; Close the parent dialog if provided
        if (ownerGui) {
            ownerGui.Destroy()
        }

        ; Create a new dialog for extension URLs
        urlsGui := Gui("+AlwaysOnTop -MinimizeBox", "Extension Configuration")
        urlsGui.SetFont("s10", "Segoe UI")
        urlsGui.MarginX := 15
        urlsGui.MarginY := 15

        ; Add instructions
        urlsGui.SetFont("s11 bold")
        urlsGui.Add("Text", "w400 Center", "Copy and Paste in Your Browser")

        urlsGui.SetFont("s10 norm")
        urlsGui.Add("Text", "w400 y+5", "1. Click a URL below to select it")
        urlsGui.Add("Text", "w400 y+5", "2. Press Ctrl+C to copy it")
        urlsGui.Add("Text", "w400 y+5", "3. Paste it in the browser where the extension is installed")

        ; Chrome URL field - renamed to Chrome Web Store
        urlsGui.Add("Text", "w120 y+15", "Chrome Web Store:")
        chromeUrl := urlsGui.Add("Edit", "x+5 yp-3 w275 h25 ReadOnly", "chrome-extension://alchldmijhnnapijdmchpkdeikibjgoi/ui/connect-skipper.html")
        chromeUrl.OnEvent("Focus", (*) => this.SelectAllText(chromeUrl))

        ; Edge URL field - renamed to Edge Add-ons
        urlsGui.Add("Text", "xm w120 y+8", "Edge Addons:")
        edgeUrl := urlsGui.Add("Edit", "x+5 yp-3 w275 h25 ReadOnly", "edge-extension://jdpiggacibaaecfbegkhakcmgaafjajn/ui/connect-skipper.html")
        edgeUrl.OnEvent("Focus", (*) => this.SelectAllText(edgeUrl))

        ; Close button - centered
        closeBtn := urlsGui.Add("Button", "w120 h28 x150 y+15", "Close")
        closeBtn.OnEvent("Click", (*) => urlsGui.Destroy())

        ; Show the dialog - smaller size
        urlsGui.OnEvent("Close", (*) => urlsGui.Destroy())
        urlsGui.Show("w430 h220")

        this.UpdateLog("Showed extension configuration dialog")
    }

    ; Helper to select all text in an edit control
    SelectAllText(editCtrl) {
        ; Select all text (from position 0 to end)
        SendMessage(0xB1, 0, -1, editCtrl.Hwnd)
    }

    ; Open the project homepage
    OpenHomepage(*) {
        Run("https://skipper.videochat.tools")
    }

    ; Open the directory of Omegle clones
    OpenDirectory(*) {
        Run("https://videochat.tools")
    }

    ; Open the feedback form
    OpenFeedbackForm(*) {
        Run("https://forms.gle/c9WPBvTQtPuVqz449")
    }

    ; Handler for system commands - used to detect unminimize
    OnSysCommand(wParam, lParam, msg, hwnd) {
        ; Check if this is our window
        if (hwnd != this.MainGui.Hwnd)
            return

        ; SC_RESTORE = 0xF120 - Window being restored from minimized state
        if (wParam = 0xF120) {
            ; Only process this if we started minimized and haven't fixed it yet
            if (this.wasLaunchedMinimized && !this.redrawAlreadyPerformed) {
                this.UpdateLog("Performing scheduled redraw after restore")

                this.TabsControl.Value := 2

                this.TabsControl.Value := 1

                ; Mark that we've performed the redraw
                this.redrawAlreadyPerformed := true

                this.UpdateLog("Tab rendering should be fixed now")
            }
        }
    }

    ; Choose a color for the region overlay
    ChooseRegionColor(*) {
        global regionColor
        global custColors

        ; Include the color picker
        #Include "ColorPicker.ahk"

        ; Initialize custom colors array if needed
        if (!IsSet(custColors) || !IsObject(custColors))
            custColors := []

        ; Show color dialog with current color
        currColor := regionColor
        newColor := ColorSelect(currColor, this.MainGui.Hwnd, &custColors, true)

        ; Update if a valid color was chosen
        if (newColor != -1) {
            regionColor := newColor
            UpdateSetting("regionColor", newColor)

            ; Update region overlay if visible
            if (isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
                RegionHandler.UpdateRegionColor(newColor)
            }

            this.UpdateLog("Region color set to: " . newColor)
        }
    }

    ; Toggle option 1
    ToggleOption1(*) {
        isEnabled := this.option1Cb.Value
        UpdateSetting("showRegionText", isEnabled)
        Log("Region overlay text " . (isEnabled ? "enabled" : "disabled"))

        ; Refresh the region overlay to apply text change
        global isRegionAlwaysVisible
        if (isRegionAlwaysVisible && RegionHandler.skipRegion.active) {
            RegionHandler.ShowRegionOverlay()
        }
    }

    ; Toggle option 2
    ToggleOption2(*) {
        isEnabled := this.option2Cb.Value
        UpdateSetting("showTooltipHints", isEnabled)
        Log("Tooltip hints " . (isEnabled ? "enabled" : "disabled"))

        ; Clear any active tooltips when disabling
        if (!isEnabled) {
            ClearTooltips()
        }
    }
}
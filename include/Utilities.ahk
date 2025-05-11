; Function to check for updates
CheckForUpdates(silent := true)
{
    try {
        ; Create WinHTTP object
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        
        ; Set timeout to 10 seconds (10000 milliseconds)
        http.SetTimeouts(10000, 10000, 10000, 10000)

        ; Set request URL to GitHub API
        apiUrl := "https://api.github.com/repos/" RepoOwner "/" RepoName "/releases/latest"
        http.Open("GET", apiUrl, true)
        http.SetRequestHeader("User-Agent", "AutoHotkey/" AppName " v" AppVersion)
        http.Send()
        http.WaitForResponse()

        ; Get status code
        statusCode := http.Status
        if (statusCode != 200) {
            manualUrl := "https://skipper.omeglelike.com/latest"
            if (ShowErrorWithLink("Failed to check for updates. HTTP Status: " statusCode "`n`nCurrent version: " AppVersion "`n`n"
                . "Would you like to check for updates manually?",
                "https://pastebin.com/embed_iframe/sfG3zvRT", "If something is VERY wrong, check this link.") = "Yes")
                Run "explorer.exe " manualUrl
            return
        }

        ; Parse response JSON
        response := http.ResponseText
        latestVersion := ""
        downloadUrl := ""

        ; Parse the GitHub API response using RegEx
        versionRegex := '"tag_name":\s*"v?([\d\.]+)"'
        if RegExMatch(response, versionRegex, &vMatch)
            latestVersion := vMatch[1]
        if IsNewerVersion(latestVersion, AppVersion) {
            ; First try to find any .exe file in assets
            browserDownloadUrlRegex := '"browser_download_url":\s*"([^"]+\.exe)"'
            if RegExMatch(response, browserDownloadUrlRegex, &dMatch)
                downloadUrl := dMatch[1]

            ; Get the release page URL regardless of whether we have a download URL
            releaseUrlRegex := '"html_url":\s*"([^"]+)"'
            releaseUrl := ""
            if RegExMatch(response, releaseUrlRegex, &rMatch)
                releaseUrl := rMatch[1]

            ; If no downloadable assets, offer to go to the release page
            if (downloadUrl = "") {
                try {
                    result := ShowUpdateWithLink("A new version (" latestVersion ") is available!`n`nCurrent version: " AppVersion "`n`nWould you like to visit the release page?", 
                        releaseUrl, "Click here to view the release page")
                } catch Error as e {
                    ; Fallback to standard MsgBox if custom dialog fails
                    Log("Error showing update dialog: " e.Message)
                    result := MsgBox("A new version (" latestVersion ") is available!`n`nCurrent version: " AppVersion "`n`nWould you like to visit the release page?`n`nRelease page: " releaseUrl, "Update Available", "YesNo")
                }
                
                if (releaseUrl && result = "Yes") {
                    Run "explorer.exe " releaseUrl
                    MsgBox("The release page has been opened in your browser.`n`nPlease download and install the update for " AppName ".", "Download Update")
                    return
                }
            }
            else {
                try {
                    result := ShowUpdateWithLink("A new version (" latestVersion ") is available!`n`nCurrent version: " AppVersion "`n`nWould you like to download and install the update?", 
                        releaseUrl, "Click here to view the release page")
                } catch Error as e {
                    ; Fallback to standard MsgBox if custom dialog fails
                    Log("Error showing update dialog: " e.Message)
                    result := MsgBox("A new version (" latestVersion ") is available!`n`nCurrent version: " AppVersion "`n`nWould you like to download and install the update?`n`nRelease page: " releaseUrl, "Update Available", "YesNo")
                }
                
                if (result = "Yes") {
                    Run "explorer.exe " downloadUrl
                    MsgBox("The installer has been opened in your browser.`n`nPlease download and run it to update " AppName ".", "Downloading Update")
                }
            }
        }
        else if (!silent) {
            MsgBox("You are running the latest version (" AppVersion ").", "No Updates Available")
        }
    } catch Error as e {
        manualUrl := "https://skipper.omeglelike.com/latest"
        if (ShowErrorWithLink("Error: " e.Message "`n`nCurrent version: " AppVersion "`n`n"
            . "Would you like to check for updates manually?",
            "https://pastebin.com/embed_iframe/sfG3zvRT", "If something is VERY wrong, check this link.") = "Yes")
            Run "explorer.exe " manualUrl
    }
}

; Function to compare versions
IsNewerVersion(latestVersion, currentVersion)
{
    if currentVersion = "dev"
        return false

    ; Extract first integer from version strings using RegEx
    latestMatch := ""
    currentMatch := ""

    if RegExMatch(latestVersion, "(\d+)", &latestMatch)
        latestNum := Integer(latestMatch[1])
    else
        throw Error("Invalid latest version format: " latestVersion)

    if RegExMatch(currentVersion, "(\d+)", &currentMatch)
        currentNum := Integer(currentMatch[1])
    else
        throw Error("Invalid current version format: " currentVersion)

    if (currentVersion = "dev")
        return false

    return latestNum > currentNum
}

; Utility functions for the application

; Global reference to the GUI for logging
global gGui := ""

; Set the GUI reference for logging
SetGUIReference(guiRef) {
    global gGui
    gGui := guiRef
}

; Central logging function to redirect all debug messages to GUI log and system debug
Log(message) {
    ; Always output to system debug
    OutputDebug(message)

    ; Also send to GUI log if available
    global gGui
    if (IsSet(gGui) && gGui) {
        try {
            gGui.UpdateLog(message)
        } catch Error as e {
            ; If GUI logging fails, at least we have the system debug output
            ; But who cares?
            OutputDebug("Failed to log to GUI: " . e.Message)
        }
    }
}

; Custom dialog function with clickable link
ShowErrorWithLink(message, linkUrl, linkText) {
    ; Dialog width
    dialogWidth := 320

    ; Create a custom GUI dialog
    errorGui := Gui("+AlwaysOnTop -MinimizeBox", "OmegleLike Skipper - Update Check Failed")
    errorGui.SetFont("s10", "Segoe UI")
    errorGui.MarginX := 20
    errorGui.MarginY := 20

    ; Add error message with auto-wrapping
    messageText := errorGui.Add("Text", "w350 Wrap", message)

    ; Get text dimensions to calculate optimal window height
    messageText.GetPos(&textX, &textY, &textWidth, &textHeight)

    ; Add clickable link without focus
    linkCtrl := errorGui.Add("Link", "w350 y+15 -Tabstop", '<a href="' linkUrl '">' linkText '</a>')
    linkCtrl.GetPos(&linkX, &linkY, &linkWidth, &linkHeight)

    ; Calculate button position - ensure they're below the text with proper spacing
    buttonY := textY + textHeight + linkHeight + 30

    ; Define button dimensions
    buttonWidth := 100
    buttonSpacing := 20
    totalButtonsWidth := (2 * buttonWidth) + buttonSpacing

    ; Calculate left position for the first button to center both buttons
    firstButtonX := (dialogWidth - totalButtonsWidth) / 2

    ; Add Yes/No buttons centered horizontally
    yesBtn := errorGui.Add("Button", "Default x" firstButtonX " y" buttonY " w" buttonWidth, "&Yes")
    noBtn := errorGui.Add("Button", "x+" buttonSpacing " y" buttonY " w" buttonWidth, "&No")

    ; Calculate optimal window height based on content
    ; Min height of 180 pixels, but can grow with content
    optimalHeight := buttonY + 50  ; Extra space for the buttons and bottom margin
    windowHeight := Max(180, optimalHeight)

    ; Initialize result
    result := ""

    ; Set up button events
    yesBtn.OnEvent("Click", (*) => (result := "Yes", errorGui.Destroy()))
    noBtn.OnEvent("Click", (*) => (result := "No", errorGui.Destroy()))
    errorGui.OnEvent("Close", (*) => (result := "No", errorGui.Destroy()))

    ; Show dialog with dynamically calculated height and centered on screen
    errorGui.Show("w" dialogWidth " h" windowHeight " Center")

    ; Focus on Yes button
    WinActivate("ahk_id " errorGui.Hwnd)
    ControlFocus(yesBtn.Hwnd, "ahk_id " errorGui.Hwnd)

    ; Wait for a result
    WinWaitClose(errorGui.Hwnd)

    return result
}

; Custom dialog function with clickable link for updates
ShowUpdateWithLink(message, linkUrl, linkText) {
    ; Dialog width
    dialogWidth := 360

    ; Create a custom GUI dialog
    updateGui := Gui("+AlwaysOnTop -MinimizeBox", "OmegleLike Skipper - Update Available")
    updateGui.SetFont("s10", "Segoe UI")
    updateGui.MarginX := 20
    updateGui.MarginY := 20

    ; Add message with auto-wrapping
    messageText := updateGui.Add("Text", "w320 Wrap", message)

    ; Get text dimensions to calculate optimal window height
    messageText.GetPos(&textX, &textY, &textWidth, &textHeight)

    ; Add clickable link without focus
    linkCtrl := updateGui.Add("Link", "w320 y+15 -Tabstop", '<a href="' linkUrl '">' linkText '</a>')
    linkCtrl.GetPos(&linkX, &linkY, &linkWidth, &linkHeight)
    
    ; Add backup link for emergency cases
    backupLinkCtrl := updateGui.Add("Link", "w320 y+10 -Tabstop", '<a href="https://pastebin.com/embed_iframe/sfG3zvRT">If something is VERY wrong, check this link.</a>')
    backupLinkCtrl.GetPos(&backupLinkX, &backupLinkY, &backupLinkWidth, &backupLinkHeight)

    ; Calculate button position - ensure they're below the text with proper spacing
    buttonY := backupLinkY + backupLinkHeight + 20

    ; Define button dimensions
    buttonWidth := 100
    buttonSpacing := 20
    totalButtonsWidth := (2 * buttonWidth) + buttonSpacing

    ; Calculate left position for the first button to center both buttons
    firstButtonX := (dialogWidth - totalButtonsWidth) / 2

    ; Add Yes/No buttons centered horizontally
    yesBtn := updateGui.Add("Button", "Default x" firstButtonX " y" buttonY " w" buttonWidth, "&Yes")
    noBtn := updateGui.Add("Button", "x+" buttonSpacing " y" buttonY " w" buttonWidth, "&No")

    ; Calculate optimal window height based on content
    ; Min height of 180 pixels, but can grow with content
    optimalHeight := buttonY + 50  ; Extra space for the buttons and bottom margin
    windowHeight := Max(200, optimalHeight)

    ; Initialize result
    result := ""

    ; Set up button events
    yesBtn.OnEvent("Click", (*) => (result := "Yes", updateGui.Destroy()))
    noBtn.OnEvent("Click", (*) => (result := "No", updateGui.Destroy()))
    updateGui.OnEvent("Close", (*) => (result := "No", updateGui.Destroy()))

    ; Add event for clickable link - open in browser when clicked
    linkCtrl.OnEvent("Click", (*) => Run("explorer.exe " linkUrl))
    backupLinkCtrl.OnEvent("Click", (*) => Run("explorer.exe https://pastebin.com/embed_iframe/sfG3zvRT"))

    ; Show dialog with dynamically calculated height and centered on screen
    updateGui.Show("w" dialogWidth " h" windowHeight " Center")

    ; Focus on Yes button
    WinActivate("ahk_id " updateGui.Hwnd)
    ControlFocus(yesBtn.Hwnd, "ahk_id " updateGui.Hwnd)

    ; Wait for a result
    WinWaitClose(updateGui.Hwnd)

    return result
}
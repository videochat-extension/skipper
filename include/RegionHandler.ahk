; RegionHandler.ahk
; Handles screen region selection and checking if mouse is within defined regions

class RegionHandler {
    ; Properties to store region coordinates
    static skipRegion := { left: 0, top: 0, right: 0, bottom: 0, active: false, visible: false }
    static X1 := 0
    static Y1 := 0
    static X2 := 0
    static Y2 := 0
    static SelectionActive := false
    static SelectionComplete := false
    static CurrentRegionType := ""
    static overlayGui := ""
    static fullscreenOverlayGui := ""  ; New property for fullscreen overlay
    static regionOverlayGui := ""      ; Always-visible region overlay
    static overlayText := ""           ; Text control in the region overlay
    static previousRegionOverlayGui := "" ; Show previous region during selection
    static ShowDebugTooltips := false  ; Control whether to show debug tooltips
    static DPIScale := A_ScreenDPI / 96  ; Calculate DPI scaling factor
    static EscapePressed := false     ; Track if Escape was pressed
    static lastMouseX := 0            ; Track last mouse position for performance
    static lastMouseY := 0
    static initialMouseX := 0         ; Store initial mouse position for teleporting back
    static initialMouseY := 0

    ; Initialize the region handler
    static Initialize() {
        Log("Initializing RegionHandler...")
        ; Set up Escape hotkey for cancellation
        Hotkey("Escape", (*) => this.CancelSelection(), "On")
    }

    ; Start selection of a region for skip button
    static StartRegionSelection(regionType) {
        Log("Starting region selection for: " . regionType)

        ; Store initial mouse position for teleporting back later
        MouseGetPos(&initialX, &initialY)
        this.initialMouseX := initialX
        this.initialMouseY := initialY

        ; Reset the selection status
        this.X1 := 0
        this.Y1 := 0
        this.X2 := 0
        this.Y2 := 0
        this.SelectionActive := true
        this.SelectionComplete := false
        this.CurrentRegionType := regionType
        this.EscapePressed := false
        this.lastMouseX := 0
        this.lastMouseY := 0

        ; Set coordinate mode to screen for global mouse tracking
        CoordMode("Mouse", "Screen")

        ; Create a transparent overlay with DPI awareness
        try {
            ; Try to set per-monitor DPI awareness for accurate overlay positioning
            prevDpiContext := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        }

        ; Create fullscreen overlay that blocks clicks
        this.fullscreenOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow")  ; No E0x20 flag to ensure clicks are captured
        this.fullscreenOverlayGui.BackColor := "FFFFFF"  ; White background
        WinSetTransparent(50, this.fullscreenOverlayGui)  ; 50% transparency
        this.fullscreenOverlayGui.Show("x0 y0 w" A_ScreenWidth / this.DPIScale " h" A_ScreenHeight / this.DPIScale " NoActivate")

        ; Show the previous region if it exists
        if (regionType = "skip" && this.skipRegion.active) {
            this.ShowPreviousRegionOverlay()
        }

        this.overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.overlayGui.BackColor := "FF3333"  ; Bright red
        WinSetTransparent(100, this.overlayGui)  ; More visible (less transparent)

        ; Restore previous DPI context if we changed it
        if (IsSet(prevDpiContext))
            DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiContext, "ptr")

        ; Display instructions as tooltip instead of MsgBox
        MouseGetPos(&mouseX, &mouseY)
        this.lastMouseX := mouseX
        this.lastMouseY := mouseY
        TooltipManager.Show("Click and drag to select the region for " . regionType . " button.`nPress Esc to cancel.", mouseX + 20, mouseY - 40)

        ; Use a timer to poll mouse position and state instead of OnMessage
        SetTimer(ObjBindMethod(this, "MouseCheck"), 10)
    }

    ; Shows the previous region overlay during selection
    static ShowPreviousRegionOverlay() {
        if (!this.skipRegion.active)
            return

        ; Hide any existing overlay first
        this.HidePreviousRegionOverlay()

        ; Try to set per-monitor DPI awareness for accurate overlay positioning
        try {
            prevDpiContext := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        }

        ; Create a blue overlay to show the previous region
        this.previousRegionOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.previousRegionOverlayGui.BackColor := "3333FF"  ; Blue color
        WinSetTransparent(50, this.previousRegionOverlayGui)  ; 50% transparency

        ; Calculate position and size
        left := this.skipRegion.left
        top := this.skipRegion.top
        width := this.skipRegion.right - this.skipRegion.left
        height := this.skipRegion.bottom - this.skipRegion.top

        ; Scale dimensions for DPI
        scaledWidth := width / this.DPIScale
        scaledHeight := height / this.DPIScale

        ; Show the overlay
        this.previousRegionOverlayGui.Show("x" left " y" top " w" scaledWidth " h" scaledHeight " NoActivate")

        ; Restore previous DPI context if we changed it
        if (IsSet(prevDpiContext))
            DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiContext, "ptr")

        Log("Showing previous region overlay during selection")
    }

    ; Hides the previous region overlay
    static HidePreviousRegionOverlay() {
        if (IsObject(this.previousRegionOverlayGui) && this.previousRegionOverlayGui.HasProp("Hwnd")) {
            this.previousRegionOverlayGui.Destroy()
            this.previousRegionOverlayGui := ""
        }
    }

    ; Shows the always-visible region overlay
    static ShowRegionOverlay() {
        global regionTransparency
        global regionColor
        global showRegionText

        if (!this.skipRegion.active)
            return

        ; Set visible state to true
        this.skipRegion.visible := true

        ; Hide any existing overlay first
        this.HideRegionOverlay()

        ; Try to set per-monitor DPI awareness for accurate overlay positioning
        try {
            prevDpiContext := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        }

        ; Create a colored overlay using the user's selected color
        this.regionOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")

        ; Use the custom color if set, otherwise default to green
        overlayColor := regionColor ? RegExReplace(regionColor, "^0x", "") : "33FF33"
        this.regionOverlayGui.BackColor := overlayColor

        WinSetTransparent(regionTransparency, this.regionOverlayGui)  ; Use global transparency setting

        ; Calculate position and size
        left := this.skipRegion.left
        top := this.skipRegion.top
        width := this.skipRegion.right - this.skipRegion.left
        height := this.skipRegion.bottom - this.skipRegion.top

        ; Scale dimensions for DPI
        scaledWidth := width / this.DPIScale
        scaledHeight := height / this.DPIScale

        ; Add text to the overlay if Option1 is enabled
        if (showRegionText) {
            ; Calculate contrasting text color based on background
            textColor := this.GetContrastingTextColor(overlayColor)

            ; Add text to the overlay
            this.regionOverlayGui.SetFont("s10 c" textColor " bold", "Arial")
            
            ; First create the text control at position 0,0
            this.overlayText := this.regionOverlayGui.Add("Text", "Center x0 y0 w" scaledWidth, "Skip Button Region")
            
            ; Get the actual dimensions of the text control
            this.overlayText.GetPos(&textX, &textY, &textWidth, &textHeight)
            
            ; Reposition the text to be exactly centered vertically
            this.overlayText.Move(0, (scaledHeight - textHeight) / 2, scaledWidth, textHeight)
        }

        ; Show the overlay
        this.regionOverlayGui.Show("x" left " y" top " w" scaledWidth " h" scaledHeight " NoActivate")

        ; Restore previous DPI context if we changed it
        if (IsSet(prevDpiContext))
            DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiContext, "ptr")

        Log("Showing always-visible region overlay with transparency: " . regionTransparency . " and color: " . regionColor)
    }

    ; Calculate a contrasting text color (black or white) based on background color
    static GetContrastingTextColor(bgColor) {
        ; Convert bgColor to RGB values
        if (SubStr(bgColor, 1, 2) = "0x")
            bgColor := SubStr(bgColor, 3)

        ; Parse RGB components - accounting for both hex formats
        if (StrLen(bgColor) = 6) {
            r := Integer("0x" . SubStr(bgColor, 1, 2))
            g := Integer("0x" . SubStr(bgColor, 3, 2))
            b := Integer("0x" . SubStr(bgColor, 5, 2))
        } else {
            r := Integer("0x" . SubStr(bgColor, 1, 2))
            g := Integer("0x" . SubStr(bgColor, 3, 2))
            b := Integer("0x" . SubStr(bgColor, 5, 2))
        }

        ; Calculate relative luminance using the formula
        ; Luminance = 0.299*R + 0.587*G + 0.114*B
        luminance := (0.299 * r + 0.587 * g + 0.114 * b) / 255

        ; Use white text for dark backgrounds, black for light backgrounds
        return (luminance > 0.5) ? "000000" : "FFFFFF"
    }

    ; Hides the always-visible region overlay
    static HideRegionOverlay() {
        if (IsObject(this.regionOverlayGui) && this.regionOverlayGui.HasProp("Hwnd")) {
            this.regionOverlayGui.Destroy()
            this.regionOverlayGui := ""
            this.overlayText := ""
            
            ; Set visible state to false
            this.skipRegion.visible := false
        }
    }

    ; Cancel the current selection process - accepts any number of parameters for Hotkey compatibility
    static CancelSelection(*) {
        if (this.SelectionActive) {
            Log("Selection cancelled by user")
            this.EscapePressed := true
            this.SelectionActive := false

            ; Stop the timer
            SetTimer(ObjBindMethod(this, "MouseCheck"), 0)

            ; Clear any tooltips using the global function
            TooltipManager.ClearTooltip()

            ; 1. Teleport mouse back to its initial position
            MouseMove(this.initialMouseX, this.initialMouseY, 0)

            ; 2. Wait 100ms
            Sleep(100)

            ; 3. Clean up the fullscreen overlay
            if (IsObject(this.fullscreenOverlayGui) && this.fullscreenOverlayGui.HasProp("Hwnd")) {
                this.fullscreenOverlayGui.Destroy()
            }

            ; Clean up the overlay
            if (IsObject(this.overlayGui) && this.overlayGui.HasProp("Hwnd")) {
                this.overlayGui.Destroy()
            }

            ; Clean up the previous region overlay
            this.HidePreviousRegionOverlay()

            ; Show cancellation message as tooltip
            TooltipManager.Show("Selection cancelled", this.initialMouseX + 20, this.initialMouseY - 40)

            ; Restore always-visible overlay if enabled
            global isRegionAlwaysVisible
            if (isRegionAlwaysVisible && this.skipRegion.active) {
                this.ShowRegionOverlay()
            }
        }
    }

    ; Mouse check timer function - replaces OnMessage hooks with more reliable timer
    static MouseCheck() {
        static isMouseDown := false

        if (!this.SelectionActive)
            return

        ; Get current mouse position
        MouseGetPos(&mouseX, &mouseY)

        ; Check for Escape key to cancel selection
        if (this.EscapePressed) {
            isMouseDown := false
            return
        }

        ; Only update tooltip if mouse position changed
        mousePositionChanged := (mouseX != this.lastMouseX || mouseY != this.lastMouseY)

        if (mousePositionChanged) {
            this.lastMouseX := mouseX
            this.lastMouseY := mouseY

            ; Show instructions or debug tooltip
            if (this.ShowDebugTooltips) {
                tooltipText := "Mouse: X=" mouseX ", Y=" mouseY "`n"
                    . "Start: X1=" this.X1 ", Y1=" this.Y1 "`n"
                    . "Current: X2=" this.X2 ", Y2=" this.Y2 "`n"
                    . "Width: " Abs(this.X2 - this.X1) ", Height: " Abs(this.Y2 - this.Y1) "`n"
                    . "DPI Scale: " this.DPIScale "`n"
                    . "isMouseDown: " isMouseDown
                TooltipManager.Show(tooltipText, mouseX + 20, mouseY - 40)
            } else if (!isMouseDown) {
                ; Show instruction tooltip when not yet dragging
                TooltipManager.Show("Click and drag to select the region for " . this.CurrentRegionType . " button.`nPress Esc to cancel.", mouseX + 20, mouseY - 40)
            } else {
                ; Show current dimensions while dragging
                width := Abs(this.X2 - this.X1)
                height := Abs(this.Y2 - this.Y1)
                TooltipManager.Show("Selection: Width=" width ", Height=" height, mouseX + 20, mouseY - 40)
            }
        }

        ; Check left mouse button state
        if (GetKeyState("LButton", "P")) {
            if (!isMouseDown) {
                ; Mouse button just pressed - record starting position
                this.X1 := mouseX
                this.Y1 := mouseY
                isMouseDown := true
            } else {
                ; Mouse is being dragged - update current position
                this.X2 := mouseX
                this.Y2 := mouseY

                ; Calculate rectangle dimensions
                left := Min(this.X1, this.X2)
                top := Min(this.Y1, this.Y2)
                width := Abs(this.X2 - this.X1)
                height := Abs(this.Y2 - this.Y1)

                ; Try to set per-monitor DPI awareness for accurate overlay positioning
                try {
                    prevDpiContext := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
                }

                ; Calculate scaled dimensions for DPI
                scaledWidth := width / this.DPIScale
                scaledHeight := height / this.DPIScale

                ; Update overlay position without affecting focus
                ; Using Show with NoActivate prevents focus changes
                this.overlayGui.Show("x" left " y" top " w" scaledWidth " h" scaledHeight " NoActivate")

                ; Restore previous DPI context if we changed it
                if (IsSet(prevDpiContext))
                    DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiContext, "ptr")
            }
        } else if (isMouseDown) {
            ; Mouse button released - complete selection
            isMouseDown := false
            this.SelectionActive := false
            this.SelectionComplete := true

            ; Calculate final rectangle dimensions
            left := Min(this.X1, this.X2)
            top := Min(this.Y1, this.Y2)
            right := Max(this.X1, this.X2)
            bottom := Max(this.Y1, this.Y2)
            width := right - left
            height := bottom - top

            ; Stop timer
            SetTimer(ObjBindMethod(this, "MouseCheck"), 0)

            ; 1. Teleport mouse back to its initial position first
            MouseMove(this.initialMouseX, this.initialMouseY, 0)

            ; 2. Wait 100ms
            Sleep(100)

            ; 3. Destroy fullscreen overlay
            if (IsObject(this.fullscreenOverlayGui) && this.fullscreenOverlayGui.HasProp("Hwnd")) {
                this.fullscreenOverlayGui.Destroy()
            }

            ; Destroy overlay
            if (IsObject(this.overlayGui) && this.overlayGui.HasProp("Hwnd")) {
                this.overlayGui.Destroy()
            }

            ; Destroy previous region overlay
            this.HidePreviousRegionOverlay()

            ; Clear tooltip when selection is complete
            TooltipManager.ClearTooltip()

            ; Store region based on type - check minimum size
            if (this.CurrentRegionType = "skip" && width > 10 && height > 10) {
                this.skipRegion := { left: left, top: top, right: right, bottom: bottom, active: true, visible: false }
                Log("Skip region selected: Left=" . left . ", Top=" . top . ", Right=" . right . ", Bottom=" . bottom)

                ; Update settings
                UpdateSetting("skipRegionLeft", left)
                UpdateSetting("skipRegionTop", top)
                UpdateSetting("skipRegionRight", right)
                UpdateSetting("skipRegionBottom", bottom)
                UpdateSetting("skipRegionActive", true)

                ; Show completion message as tooltip instead of MsgBox
                TooltipManager.Show("Skip button region selected!`nSize: " width "x" height, this.initialMouseX + 20, this.initialMouseY - 40)

                ; Show region overlay if always-visible is enabled
                global isRegionAlwaysVisible
                if (isRegionAlwaysVisible) {
                    this.ShowRegionOverlay()
                }
            } else if (width <= 10 || height <= 10) {
                ; Region is too small - show message as tooltip instead of MsgBox
                TooltipManager.Show("Region is too small! Please try again with a larger selection.", this.initialMouseX + 20, this.initialMouseY - 40)

                ; Restore always-visible overlay if enabled
                global isRegionAlwaysVisible
                if (isRegionAlwaysVisible && this.skipRegion.active) {
                    this.ShowRegionOverlay()
                }
            }
        }
    }

    ; Toggle debug tooltips
    static ToggleDebugTooltips() {
        this.ShowDebugTooltips := !this.ShowDebugTooltips
        if (!this.ShowDebugTooltips) {
            TooltipManager.ClearTooltip()
        }

        ; Show status as tooltip instead of MsgBox
        MouseGetPos(&mouseX, &mouseY)
        TooltipManager.Show("Debug tooltips " . (this.ShowDebugTooltips ? "enabled" : "disabled"), mouseX + 20, mouseY - 40)
    }

    ; Check if mouse is within the defined skip region
    static IsMouseInSkipRegion() {
        if (!this.skipRegion.active)
            return false

        MouseGetPos(&mouseX, &mouseY)

        return (mouseX >= this.skipRegion.left &&
            mouseX <= this.skipRegion.right &&
            mouseY >= this.skipRegion.top &&
            mouseY <= this.skipRegion.bottom)
    }

    ; Load regions from settings
    static LoadFromSettings() {
        global settingsManager

        ; Load skip region
        this.skipRegion.left := settingsManager.Get("skipRegionLeft", 0)
        this.skipRegion.top := settingsManager.Get("skipRegionTop", 0)
        this.skipRegion.right := settingsManager.Get("skipRegionRight", 0)
        this.skipRegion.bottom := settingsManager.Get("skipRegionBottom", 0)
        this.skipRegion.active := settingsManager.Get("skipRegionActive", false)

        Log("Loaded skip region from settings: Left=" . this.skipRegion.left .
            ", Top=" . this.skipRegion.top .
            ", Right=" . this.skipRegion.right .
            ", Bottom=" . this.skipRegion.bottom .
            ", Active=" . this.skipRegion.active)
    }

    ; Updates the transparency of the region overlay
    static UpdateRegionTransparency(transparency := 128) {
        ; If the overlay doesn't exist, there's nothing to update
        if (!IsObject(this.regionOverlayGui) || !this.regionOverlayGui.HasProp("Hwnd")) {
            return
        }

        ; Update the transparency
        WinSetTransparent(transparency, this.regionOverlayGui)
        Log("Updated region overlay transparency to: " . transparency)
    }

    ; Updates the color of the region overlay
    static UpdateRegionColor(color) {
        ; If the overlay doesn't exist, just recreate it with the new color
        if (!IsObject(this.regionOverlayGui) || !this.regionOverlayGui.HasProp("Hwnd")) {
            return
        }

        ; Store current properties
        global regionTransparency

        ; Hide existing overlay
        this.HideRegionOverlay()

        ; Recreate with new color
        global regionColor := color
        this.ShowRegionOverlay()

        Log("Updated region overlay color to: " . color)
    }

    ; Shows the skip region temporarily
    static ShowSkipRegion() {
        if (!this.skipRegion.active)
            return false
            
        this.ShowRegionOverlay()
        return true
    }
    
    ; Hides the skip region
    static HideSkipRegion() {
        this.HideRegionOverlay()
        return true
    }
}
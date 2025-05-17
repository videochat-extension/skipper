; TooltipManager.ahk
; Class for managing transparent, click-through tooltips

class TooltipManager {
    static tooltipGui := ""          ; The actual GUI object
    static tooltipVisible := false    ; Whether tooltip is currently visible
    static showTooltipHints := true   ; Controls whether tooltips are enabled
    static currentTimer := 0          ; Timer ID for the current tooltip

    ; Initialize the tooltip system
    static Initialize(showHints := true) {
        this.showTooltipHints := showHints
        Logger.Info("TooltipManager initialized. Hints enabled: " . this.showTooltipHints)
    }

    ; Set whether tooltips should be shown
    static SetTooltipsEnabled(enabled) {
        this.showTooltipHints := enabled
        if (!enabled) {
            this.ClearTooltip()
        }
        Logger.Info("Tooltips " . (enabled ? "enabled" : "disabled"))
    }

    ; Show a tooltip with the specified parameters
    static Show(text, x := "", y := "", timeout := 3000, bgColor := "222222", textColor := "FFFFFF", transparency := 200) {
        ; Check if tooltips are disabled
        if (!this.showTooltipHints) {
            return
        }

        ; Calculate position if not provided
        if (x = "" || y = "") {
            MouseGetPos(&mouseX, &mouseY)
            x := (x = "") ? mouseX + 20 : x
            y := (y = "") ? mouseY + 20 : y
        }

        ; Stop existing hide timer if one exists
        if (this.currentTimer) {
            SetTimer(this.currentTimer, 0)
            this.currentTimer := 0
        }

        ; Create the tooltip GUI if it doesn't exist, otherwise update it
        if (!this.tooltipGui) {
            ; Create new tooltip GUI
            this.tooltipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")  ; E0x20 makes it click-through
            this.tooltipGui.BackColor := bgColor
            this.tooltipGui.SetFont("s10 c" . textColor, "Segoe UI")
            this.tooltipGui.Add("Text", "Background" . bgColor, text)
            this.tooltipGui.Opt("AlwaysOnTop")
            WinSetTransparent(transparency, this.tooltipGui)
            this.tooltipGui.Show("AutoSize x" . x . " y" . y . " NoActivate")
            this.tooltipVisible := true
        } else {
            ; Update existing tooltip
            try {
                ; First hide the GUI to avoid flickering
                if (this.tooltipVisible) {
                    this.tooltipGui.Hide()
                }
                
                ; Update tooltip properties
                this.tooltipGui.BackColor := bgColor
                
                ; Remove any existing controls
                for ctrl in this.tooltipGui {
                    ctrl.Destroy()
                }
                
                ; Add new text
                this.tooltipGui.SetFont("s10 c" . textColor, "Segoe UI")
                this.tooltipGui.Add("Text", "Background" . bgColor, text)
                
                ; Show tooltip at new position
                this.tooltipGui.Show("AutoSize x" . x . " y" . y . " NoActivate")
                WinSetTransparent(transparency, this.tooltipGui)
                this.tooltipVisible := true
            } catch Error as e {
                ; If updating fails, recreate the tooltip
                if (this.tooltipGui) {
                    this.tooltipGui.Destroy()
                }
                
                this.tooltipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
                this.tooltipGui.BackColor := bgColor
                this.tooltipGui.SetFont("s10 c" . textColor, "Segoe UI")
                this.tooltipGui.Add("Text", "Background" . bgColor, text)
                this.tooltipGui.Opt("AlwaysOnTop")
                WinSetTransparent(transparency, this.tooltipGui)
                this.tooltipGui.Show("AutoSize x" . x . " y" . y . " NoActivate")
                this.tooltipVisible := true
            }
        }

        ; Create a new timer to hide the tooltip after specified timeout
        hideFn := ObjBindMethod(this, "HideTooltip")
        SetTimer(hideFn, -timeout)
        this.currentTimer := hideFn
    }

    ; Hide the tooltip
    static HideTooltip() {
        if (this.tooltipGui && this.tooltipVisible) {
            this.tooltipGui.Hide()
            this.tooltipVisible := false
        }
        
        ; Clear timer reference
        this.currentTimer := 0
    }

    ; Clear tooltip (alias for HideTooltip for backward compatibility)
    static ClearTooltip() {
        this.HideTooltip()
    }

    ; For compatibility with old code that used ClearTooltips (plural)
    static ClearTooltips() {
        this.ClearTooltip()
    }
} 
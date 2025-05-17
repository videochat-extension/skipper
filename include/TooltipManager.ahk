; TooltipManager.ahk
; Class for managing transparent, click-through tooltips

class TooltipManager {
    static tooltipGui := ""          ; The actual GUI object
    static tooltipVisible := false    ; Whether tooltip is currently visible
    static showTooltipHints := true   ; Controls whether tooltips are enabled
    static clearFn := ""             ; Stored function reference for tooltip clearing
    static activeTimer := false      ; Flag indicating if a timer is currently active

    ; Initialize the tooltip system
    static Initialize(showHints := true) {
        this.showTooltipHints := showHints
        ; Create a persistent function reference for the timer
        this.clearFn := ObjBindMethod(this, "ClearTooltip")
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

        ; Cancel any existing timer
        if (this.activeTimer) {
            SetTimer(this.clearFn, 0)
            this.activeTimer := false
        }

        ; Destroy any existing tooltip GUI to prevent multiple tooltips
        if (this.tooltipGui) {
            this.tooltipGui.Destroy()
            this.tooltipGui := ""
        }
        
        ; Create new tooltip GUI
        this.tooltipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")  ; E0x20 makes it click-through
        this.tooltipGui.BackColor := bgColor
        this.tooltipGui.SetFont("s10 c" . textColor, "Segoe UI")
        this.tooltipGui.Add("Text", "Background" . bgColor, text)
        WinSetTransparent(transparency, this.tooltipGui)
        this.tooltipGui.Show("AutoSize x" . x . " y" . y . " NoActivate")
        this.tooltipVisible := true

        ; Set a new timer to clear the tooltip after specified timeout
        ; Use a longer minimum timeout to prevent immediate disappearance
        if (timeout < 500)
            timeout := 500
            
        SetTimer(this.clearFn, -timeout)
        this.activeTimer := true
    }

    ; Clear the tooltip
    static ClearTooltip() {
        if (this.tooltipGui) {
            this.tooltipGui.Destroy()
            this.tooltipGui := ""
            this.tooltipVisible := false
        }
        
        ; Mark timer as inactive
        this.activeTimer := false
    }

    ; For compatibility with old code that used ClearTooltips (plural)
    static ClearTooltips() {
        this.ClearTooltip()
    }
} 
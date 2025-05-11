; ClickHandler class to handle mouse movement and clicking
class ClickHandler {
    ; Function to set cursor to crosshair
    static SetCursorToCrosshair() {
        Log("Setting cursor to crosshair")
        ; IDC_CROSS = 32515
        CursorHandle := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr")
        ; OCR_CROSS = 32515
        DllCall("SetSystemCursor", "Ptr", CursorHandle, "Int", 32512)  ; Replace normal arrow (OCR_NORMAL = 32512)
    }

    ; Function to restore default cursor
    static RestoreDefaultCursor() {
        Log("Restoring default cursor")
        DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)  ; SPI_SETCURSORS := 0x57
    }

    ; Function to perform a natural-looking click
    static NaturalClick(useDoubleClick := false, clickId := 0) {
        ; Record position at start
        MouseGetPos(&startX, &startY)

        ; Human-like pre-click hesitation (wider range for more realism)
        Sleep(Random(30, 90))

        ; Check for cancellation before first click
        if (ClickState.ShouldCancel(clickId)) {
            Log("Cancelling click operation before first click")
            TransparentToolTip("Click cancelled", startX + 20, startY + 20)
            return false
        }

        ; Check if mouse has moved since starting the click operation
        MouseGetPos(&currentX, &currentY)
        if (Abs(currentX - startX) > 3 || Abs(currentY - startY) > 3) {
            Log("Mouse moved before click execution. Start: (" .
                startX . "," . startY . "), Current: (" .
                currentX . "," . currentY . "). Cancelling click.")
            TransparentToolTip("Click cancelled - mouse moved", currentX + 20, currentY + 20)
            return false
        }

        ; Send mouse down
        Click("Down")

        ; Natural hold time variation with occasional outliers (10% chance)
        if (Random(1, 10) = 1) {
            ; Occasional wider variation (60-140ms) for more human-like behavior
            Sleep(Random(50, 130))
            Log("Using outlier hold timing")
        } else {
            ; More typical human-like hold range (80-120ms)
            Sleep(Random(70, 110))
        }

        ; Send mouse up
        Click("Up")

        ; If double click is requested, perform second click after a short delay
        if (useDoubleClick) {
            ; Human-like double-click timing (more varied)
            Sleep(Random(80, 160))

            ; Second click down
            Click("Down")

            ; Natural hold time for second click (may be slightly different from first)
            if (Random(1, 10) = 1) {
                Sleep(Random(50, 130)) ; Occasional outlier
            } else {
                Sleep(Random(70, 110))
            }

            ; Second click up
            Click("Up")
            Log("Second click of double-click completed")
        }

        ; Natural post-click settling time (wider range)
        Sleep(Random(20, 60))
        return true
    }

    ; Function to perform click if mouse is within region
    static PerformClick(clickType := "", useDoubleClick := false) {
        global isSkipperSuppressed

        ; Check if skipper functionality is suppressed
        if (isSkipperSuppressed) {
            Log("Click operation cancelled - Skipper functionality is suppressed")
            return false
        }

        ; Register this click operation with the state manager
        clickId := ClickState.StartClick(clickType)

        ; Get current mouse position
        MouseGetPos(&currentX, &currentY)
        clickResult := false

        if (clickType = "skip") {
            ; Check if mouse is within skip region
            if (RegionHandler.IsMouseInSkipRegion()) {
                Log("Mouse is within skip region. Performing " . (useDoubleClick ? "double-click" : "click") . " at current position (" . currentX . "," . currentY . ")")
                clickResult := this.NaturalClick(useDoubleClick, clickId)
            } else {
                Log("Mouse is NOT within skip region. Current position (" . currentX . "," . currentY . "). Skipping click.")
                ; Optionally display a tooltip to inform user
                TransparentToolTip("Move mouse to the skip button region first", currentX + 20, currentY + 20)
                clickResult := false
            }
        } else {
            ; Handle undefined click type
            Log("Error: Undefined click type '" . clickType . "'. Using current mouse position.")

            ; Just perform click at current position without checking regions
            Log("Performing click at current position (" . currentX . "," . currentY . ")" . (useDoubleClick ? " (double-click)" : ""))
            clickResult := this.NaturalClick(useDoubleClick, clickId)
        }

        ; Mark the click operation as complete
        ClickState.EndClick(clickId)
        return clickResult
    }
}
; ClickState.ahk - Class to manage click action state and cancellation
; This class provides centralized tracking of active click operations and cancellation support

; Initialize global variables for click state tracking
global ClickState_IsInProgress := false    ; Flag to track if any click operation is in progress
global ClickState_CurrentType := ""        ; Type of the current click operation ("skip" or "stop")
global ClickState_CurrentId := 0           ; ID of the current click operation (incremented for each new click)
global ClickState_ShouldCancel := false    ; Flag to indicate if the current click should be cancelled
global ClickState_InitiatedByHotkey := false ; Flag to track if action was initiated by keyboard hotkey

class ClickState {
    ; Start a new click operation, cancelling any in progress
    static StartClick(clickType) {
        global ClickState_IsInProgress, ClickState_CurrentType, ClickState_CurrentId, ClickState_ShouldCancel

        ; Force cancel any previous click operation
        this.CancelClick("New operation started")
        Sleep(10)                          ; Short delay to allow cancellation to take effect

        ; Initialize new click operation
        ClickState_ShouldCancel := false
        ClickState_IsInProgress := true
        ClickState_CurrentType := clickType
        ClickState_CurrentId += 1

        Log("ClickState: Started " . clickType . " click operation with ID " . ClickState_CurrentId)
        return ClickState_CurrentId        ; Return ID of the current click operation
    }

    ; Complete a click operation
    static EndClick(clickId) {
        global ClickState_IsInProgress, ClickState_CurrentId, ClickState_CurrentType

        ; Only end the click if it matches the current ID
        if (clickId == ClickState_CurrentId) {
            ClickState_IsInProgress := false
            ClickState_CurrentType := ""
            Log("ClickState: Ended click operation with ID " . clickId)
        } else {
            Log("ClickState: Ignored EndClick for outdated operation ID " . clickId . " (current is " . ClickState_CurrentId . ")")
        }
    }

    ; Check if the current click operation should be cancelled
    static ShouldCancel(clickId) {
        global ClickState_ShouldCancel, ClickState_CurrentId

        ; Cancel if explicitly set or if this is not the current click
        shouldCancel := ClickState_ShouldCancel || (ClickState_CurrentId != clickId)

        ; Log cancelled operations for debugging (avoid excessive logs from constant polling)
        static lastLogTime := 0
        if (shouldCancel && (A_TickCount - lastLogTime > 500)) {
            if (ClickState_CurrentId != clickId) {
                Log("ClickState: Operation " . clickId . " should cancel - operation is outdated (current is " . ClickState_CurrentId . ")")
            } else {
                Log("ClickState: Operation " . clickId . " should cancel - explicit cancellation flag set")
            }
            lastLogTime := A_TickCount
        }

        return shouldCancel
    }

    ; Explicitly cancel current click operation with reason
    static CancelClick(reason := "Unspecified") {
        global ClickState_IsInProgress, ClickState_ShouldCancel, ClickState_CurrentType
        global ClickState_CurrentId

        if (ClickState_IsInProgress) {
            ClickState_ShouldCancel := true
            Log("ClickState: Cancelling current click operation (" . ClickState_CurrentType . " with ID " . ClickState_CurrentId . ") - Reason: " . reason)
            return true
        }
        return false
    }

    ; Check if any click is currently in progress
    static IsClickInProgress() {
        global ClickState_IsInProgress
        return ClickState_IsInProgress
    }

    ; Get type of current click operation
    static GetCurrentClickType() {
        global ClickState_CurrentType
        return ClickState_CurrentType
    }

    ; Get the current click operation ID
    static GetCurrentId() {
        global ClickState_CurrentId
        return ClickState_CurrentId
    }
}
; Global variables to track key press times
global leftKeyDownTime := 0
global rightKeyDownTime := 0
global upKeyDownTime := 0
global downKeyDownTime := 0
global leftKeyIsDown := false
global rightKeyIsDown := false
global upKeyIsDown := false
global downKeyIsDown := false
global host

; Task management variables
global currentTaskId := 0
global pendingCancellation := false
global activeActionType := ""
global cancelledByKey := ""
global cancelledActionType := ""

; Track which keys have just cancelled actions to prevent immediate triggering
global leftKeyCancelledAction := false
global rightKeyCancelledAction := false
global upKeyCancelledAction := false
global downKeyCancelledAction := false

; Transparent tooltip GUI references
global tooltipGui := Map()
global tooltipTimer := Map()
global activeTooltipId := 0  ; Track the currently active tooltip ID

; Function to clear all transparent tooltips
ClearTooltips() {
    global tooltipGui, tooltipTimer, activeTooltipId
    for id, gui in tooltipGui {
        if (gui) {
            try {
                gui.Destroy()
            }
        }
    }
    tooltipGui := Map()
    tooltipTimer := Map()
    activeTooltipId := 0  ; Reset active tooltip ID
}

; Function to create transparent, click-through tooltips that don't steal focus
TransparentToolTip(text, x := "", y := "", id := 1, timeout := 3000, bgColor := "222222", textColor := "FFFFFF", transparency := 200) {
    global tooltipGui, tooltipTimer, activeTooltipId, showTooltipHints

    ; Check if tooltips are disabled via Option 2
    if (IsSet(showTooltipHints) && !showTooltipHints) {
        ; Tooltips are disabled, return early
        return
    }

    ; Clear any existing tooltip regardless of ID to ensure only one tooltip at a time
    ClearTooltips()

    ; Create tooltip GUI
    tooltipGui[id] := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")  ; E0x20 makes it click-through
    tooltipGui[id].BackColor := bgColor
    tooltipGui[id].SetFont("s10 c" . textColor, "Segoe UI")
    tooltipGui[id].Add("Text", "Background" . bgColor, text)

    ; Calculate position if not provided
    if (x = "" || y = "") {
        MouseGetPos(&mouseX, &mouseY)
        x := (x = "") ? mouseX + 20 : x
        y := (y = "") ? mouseY + 20 : y
    }

    ; Apply transparency and show the tooltip at specified position
    tooltipGui[id].Opt("AlwaysOnTop")
    WinSetTransparent(transparency, tooltipGui[id])
    tooltipGui[id].Show("AutoSize x" . x . " y" . y . " NoActivate")

    ; Create timer function to destroy the tooltip
    tooltipTimer[id] := ObjBindMethod(tooltipGui[id], "Destroy")
    SetTimer(tooltipTimer[id], -timeout)

    ; Update active tooltip ID
    activeTooltipId := id

    return tooltipGui[id]
}

; Function to process arrow key actions asynchronously
ProcessArrowAction(actionType, key, clickType, useDoubleClick) {
    global pendingCancellation, activeActionType, cancelledByKey, cancelledActionType

    ; Set active action info
    activeActionType := actionType

    ; Mark that this click operation was not initiated by a hotkey
    ; This might seem counterintuitive, but we're using a different mechanism now
    global ClickState_InitiatedByHotkey := false

    ; Check if another action is already in progress
    if (ClickState.IsClickInProgress()) {
        ; Cancel existing action
        currentActionType := ClickState.GetCurrentClickType()
        Log("Cancelling existing " . currentActionType . " action due to new " . actionType . " request")
        pendingCancellation := true
        cancelledByKey := key
        cancelledActionType := currentActionType
        ClickState.CancelClick("New " . actionType . " action requested")
        Sleep(50) ; Give time for cancellation to take effect
    }

    ; Check if the skip region is defined
    if (clickType = "skip" && !RegionHandler.skipRegion.active) {
        Log(actionType . " action ignored - skip region not defined")
        ; Get current mouse position for the tooltip
        MouseGetPos(&mouseX, &mouseY)
        ; Show tooltip guiding user to define region first
        TransparentToolTip("Please define a skip region first!`nClick the 'Define Skip Region' button.", mouseX + 20, mouseY - 40, 3, 3000, "993333", "FFFFFF", 230)
        ; Clear state variables
        pendingCancellation := false
        cancelledByKey := ""
        activeActionType := ""
        cancelledActionType := ""
        return false
    }

    ; Check if the region is defined
    if (clickType = "skip") {
        if (!RegionHandler.skipRegion.active) {
            Log(actionType . " action ignored - skip region not defined")
            ; Clear state variables even for ignored actions
            pendingCancellation := false
            cancelledByKey := ""
            activeActionType := ""
            cancelledActionType := ""
            return false
        }
    }

    ; Register a new task ID
    currentTaskId := ClickState.StartClick(clickType)

    ; Log starting the action
    Log("Starting " . actionType . " action (Task ID: " . currentTaskId . ") - " . clickType . " click")

    ; Get the mouse position to check if it's in the region
    MouseGetPos(&mouseX, &mouseY)

    if (clickType = "skip") {
        ; Check if the mouse is in the skip region
        inRegion := RegionHandler.IsMouseInSkipRegion()

        if (!inRegion) {
            Log("Mouse is not in the skip region. Move mouse to the region first.")
            TransparentToolTip("Move mouse to the skip button region first", mouseX + 20, mouseY + 20)
            ; No need for a separate timer as the TransparentToolTip function handles auto-hiding

            ; Clean up
            ClickState.EndClick(currentTaskId)
            pendingCancellation := false
            cancelledByKey := ""
            activeActionType := ""
            cancelledActionType := ""
            return false
        }
    }

    ; Perform the action
    success := ClickHandler.PerformClick(clickType, useDoubleClick)

    ; Get results for notification
    if (success) {
        ; Get final position for notification
        MouseGetPos(&endX, &endY)
        Log(actionType . " action completed successfully (Task ID: " . currentTaskId . ")")

        ; Show a tooltip for successful skip
        if (clickType = "skip") {
            TransparentToolTip("SKIP!", endX + 30, endY - 30, 2, 1000, "339933", "FFFFFF", 230)
        }

        ; Notify through messaging host if available
        global host
        if (host) {
            response := Map(
                "type", "hotkey_action",
                "key", key,
                "clickType", clickType,
                "doubleClick", useDoubleClick,
                "position", Map("x", endX, "y", endY)
            )
            try {
                host.SendMessage(response)
                Log("Sent hotkey notification to Chrome for " . key)
            } catch Error as e {
                Log("Failed to send " . key . " hotkey notification: " . e.Message)
            }
        }
    } else {
        ; Check if it was cancelled by another key press
        if (pendingCancellation && cancelledByKey != "") {
            Log(actionType . " action was cancelled by " . cancelledByKey . " key press (Task ID: " . currentTaskId . ")")
        } else {
            Log(actionType . " action failed or was cancelled (Task ID: " . currentTaskId . ")")
        }
    }

    ; Clear state
    ClickState.EndClick(currentTaskId)
    pendingCancellation := false
    cancelledByKey := ""
    activeActionType := ""
    cancelledActionType := ""

    return success
}

#HotIf isLeftArrowBlocked && !isSkipperSuppressed  ; Only active when blocking is enabled
; Block the key-down event completely but record the time only once
Left::
{
    global leftKeyDownTime, leftKeyIsDown, pendingCancellation, cancelledByKey
    global leftKeyCancelledAction, cancelledActionType

    ; Only record the timestamp the first time the key is pressed down
    if (!leftKeyIsDown) {
        leftKeyDownTime := A_TickCount
        leftKeyIsDown := true
        Log("Left key down at: " . leftKeyDownTime)

        ; Set default - we didn't cancel anything yet
        leftKeyCancelledAction := false

        ; If an action is in progress, cancel it and mark that this key did it
        if (ClickState.IsClickInProgress()) {
            currentActionType := ClickState.GetCurrentClickType()
            Log("Action in progress - will be cancelled by left arrow key press")
            pendingCancellation := true
            cancelledByKey := "left_arrow"
            cancelledActionType := currentActionType
            ClickState.CancelClick("Cancelled by left arrow key press")

            ; Only set flag if we cancelled our own action type (skip)
            if (currentActionType = "skip") {
                leftKeyCancelledAction := true
                Log("Left arrow key cancelled its own action type (skip)")
            } else {
                ; If we cancelled another action, do not prevent our action from running
                Log("Left arrow key cancelled a different action type (" . currentActionType . "), will execute on key-up")
                leftKeyCancelledAction := false
            }
        }

        ; Region selection key combination removed
    }
    return
}

; Process on key-up instead
Left Up::  ; Left arrow key handler
{
    global leftKeyDownTime, leftKeyIsDown, isSkipDoubleClicked, leftKeyCancelledAction

    ; Calculate time between down and up only if we recorded a valid down event
    if (leftKeyIsDown) {
        keyUpTime := A_TickCount
        keyPressDuration := keyUpTime - leftKeyDownTime
        Log("Left arrow key was pressed for " . keyPressDuration . " ms (Down: " . leftKeyDownTime . ", Up: " . keyUpTime . ")")
        leftKeyIsDown := false

        ; Only proceed if key was held less than 3000ms
        if (keyPressDuration >= 3000) {
            Log("Left arrow action skipped - key was held too long (" . keyPressDuration . "ms)")
            ; Get mouse position for tooltip
            MouseGetPos(&mouseX, &mouseY)
            ; Show tooltip indicating cancellation by long press
            TransparentToolTip("Left arrow action cancelled - key held too long", mouseX + 20, mouseY - 40, 3, 2000, "333399", "FFFFFF", 220)
            return
        }

        ; Check if this key just cancelled its own action type
        if (leftKeyCancelledAction) {
            Log("Left arrow key-up ignored - this key just cancelled its own action type")
            leftKeyCancelledAction := false
            return
        }

        ; Trigger the action asynchronously
        SetTimer(() => ProcessArrowAction("left_arrow", "left_arrow", "skip", isSkipDoubleClicked), -1)
    }
    return
}
#HotIf  ; End conditional hotkey block

; Set up hotkey for right arrow
#HotIf isRightArrowBlocked || isEmergencyShutdownEnabled  ; Active when either regular functionality OR emergency shutdown is enabled
; Block the key-down event completely but record the time only once
Right::
{
    global rightKeyDownTime, rightKeyIsDown, pendingCancellation, cancelledByKey
    global rightKeyCancelledAction, cancelledActionType

    ; Only record the timestamp the first time the key is pressed down
    if (!rightKeyIsDown) {
        rightKeyDownTime := A_TickCount
        rightKeyIsDown := true
        Log("Right key down at: " . rightKeyDownTime)

        ; Set default - we didn't cancel anything yet
        rightKeyCancelledAction := false

        ; If an action is in progress, cancel it and mark that this key did it
        if (ClickState.IsClickInProgress()) {
            currentActionType := ClickState.GetCurrentClickType()
            Log("Action in progress - will be cancelled by right arrow key press")
            pendingCancellation := true
            cancelledByKey := "right_arrow"
            cancelledActionType := currentActionType
            ClickState.CancelClick("Cancelled by right arrow key press")

            ; Only set flag if we cancelled our own action type
            if (currentActionType = "skip") {
                rightKeyCancelledAction := true
                Log("Right arrow key cancelled its own action type")
            } else {
                ; If we cancelled another action, do not prevent our action from running
                Log("Right arrow key cancelled a different action type (" . currentActionType . "), will execute on key-up")
                rightKeyCancelledAction := false
            }
        }

        ; Region selection key combination removed
    }
    return
}

; Process on key-up instead
Right Up::  ; Right arrow key handler
{
    global rightKeyDownTime, rightKeyIsDown, isSkipDoubleClicked, rightKeyCancelledAction
    global isEmergencyShutdownEnabled, isSkipperSuppressed, isRightArrowBlocked

    ; Calculate time between down and up only if we recorded a valid down event
    if (rightKeyIsDown) {
        keyUpTime := A_TickCount
        keyPressDuration := keyUpTime - rightKeyDownTime
        Log("Right arrow key was pressed for " . keyPressDuration . " ms (Down: " . rightKeyDownTime . ", Up: " . keyUpTime . ")")
        rightKeyIsDown := false

        ; Check for emergency shutdown activation if held for more than 1 second but less than 3 seconds
        ; This works regardless of isRightArrowBlocked state, if emergency shutdown is enabled
        if (isEmergencyShutdownEnabled && keyPressDuration >= 1000 && keyPressDuration < 3000) {
            Log("Emergency shutdown sequence initiated. Using 200ms delay in separate thread...")
            ; Use SetTimer to exit after 200ms delay in a separate thread
            SetTimer(() => ExitApp(), -200)
            return
        }

        ; Only proceed with toggle/skip actions if right arrow blocking is enabled
        if (!isRightArrowBlocked) {
            Log("Right arrow regular actions skipped - right arrow toggle is off")
            return
        }

        ; Only proceed if key was held less than 3000ms
        if (keyPressDuration >= 3000) {
            Log("Right arrow action skipped - key was held too long (" . keyPressDuration . "ms)")
            ; Get mouse position for tooltip
            MouseGetPos(&mouseX, &mouseY)
            ; Show tooltip indicating cancellation by long press
            TransparentToolTip("Right arrow action cancelled - key held too long", mouseX + 20, mouseY - 40, 3, 2000, "333399", "FFFFFF", 220)
            return
        }

        ; Check if this key just cancelled its own action type
        if (rightKeyCancelledAction) {
            Log("Right arrow key-up ignored - this key just cancelled its own action type")
            rightKeyCancelledAction := false
            return
        }

        ; Toggle skipper functionality if held for less than 1 second
        if (keyPressDuration < 1000) {
            global isSkipperSuppressed
            isSkipperSuppressed := !isSkipperSuppressed
            UpdateSetting("isSkipperSuppressed", isSkipperSuppressed)

            ; Log the change
            Log("Skipper functionality " . (isSkipperSuppressed ? "disabled" : "enabled") . " by right arrow key")

            ; Update GUI - using the global gGui variable
            global gGui
            if (IsSet(gGui) && gGui) {
                try {
                    ; Update UI through the method that also handles region visibility
                    gGui.skipperEnabledCb.Value := isSkipperSuppressed
                    gGui.ToggleSkipperEnabled()

                    Log("Updated UI controls from hotkey")
                } catch Error as e {
                    Log("Failed to update UI from hotkey: " . e.Message)
                }
            }

            ; Show tooltip for toggle action
            MouseGetPos(&mouseX, &mouseY)
            if (isEmergencyShutdownEnabled) {
                TransparentToolTip("Skipper " . (isSkipperSuppressed ? "DISABLED" : "ENABLED") . ", right arrow still blocked, hold + release right arrow for 1 second to exit", mouseX + 20, mouseY - 40, 4, 1500, isSkipperSuppressed ? "993333" : "339933", "FFFFFF", 230)
            } else {
                TransparentToolTip("Skipper " . (isSkipperSuppressed ? "DISABLED" : "ENABLED") . ", right arrow still blocked, press to toggle.", mouseX + 20, mouseY - 40, 4, 1500, isSkipperSuppressed ? "993333" : "339933", "FFFFFF", 230)
            }
            ; Notify through messaging host if available
            global host
            if (host) {
                response := Map(
                    "type", "hotkey_action",
                    "key", "right_arrow",
                    "action", "toggle_skipper",
                    "skipper_enabled", !isSkipperSuppressed
                )
                try {
                    host.SendMessage(response)
                    Log("Sent skipper toggle notification to Chrome")
                } catch Error as e {
                    Log("Failed to send skipper toggle notification: " . e.Message)
                }
            }
            return
        }

        ; Trigger the action asynchronously - this only happens if key was held between 1-3 seconds
        ; and emergency shutdown is not enabled
        SetTimer(() => ProcessArrowAction("right_arrow", "right_arrow", "skip", isSkipDoubleClicked), -1)
    }
    return
}
#HotIf  ; End conditional hotkey block

; Set up hotkey for up arrow
#HotIf isUpArrowBlocked && (!host.isManualMode) && !isSkipperSuppressed  ; Only active when blocking is enabled
; Block the key-down event completely but record the time only once
Up::
{
    ; Skip processing if in manual mode
    global host
    if (host && host.isManualMode) {
        return
    }

    global upKeyDownTime, upKeyIsDown, pendingCancellation, cancelledByKey
    global upKeyCancelledAction, cancelledActionType

    ; Only record the timestamp the first time the key is pressed down
    if (!upKeyIsDown) {
        upKeyDownTime := A_TickCount
        upKeyIsDown := true
        Log("Up key down at: " . upKeyDownTime)

        ; Set default - we didn't cancel anything yet
        upKeyCancelledAction := false

        ; If an action is in progress, cancel it and mark that this key did it
        if (ClickState.IsClickInProgress()) {
            currentActionType := ClickState.GetCurrentClickType()
            Log("Action in progress - will be cancelled by up arrow key press")
            pendingCancellation := true
            cancelledByKey := "up_arrow"
            cancelledActionType := currentActionType
            ClickState.CancelClick("Cancelled by up arrow key press")

            ; Only set flag if we cancelled our own action type (skip)
            if (currentActionType = "skip") {
                upKeyCancelledAction := true
                Log("Up arrow key cancelled its own action type (skip)")
            } else {
                ; If we cancelled another action (like stop), do not prevent our action from running
                Log("Up arrow key cancelled a different action type (" . currentActionType . "), will execute on key-up")
                upKeyCancelledAction := false
            }
        }

        ; Region selection key combination removed
    }
    return
}

; Process on key-up instead
Up Up::  ; Up arrow key handler
{
    ; Skip processing if in manual mode

    if (host && host.isManualMode) {
        return
    }

    global upKeyDownTime, upKeyIsDown, skipClickX, skipClickY, isSkipDoubleClicked, host, upKeyCancelledAction

    ; Calculate time between down and up only if we recorded a valid down event
    if (upKeyIsDown) {
        keyUpTime := A_TickCount
        keyPressDuration := keyUpTime - upKeyDownTime
        Log("Up arrow key was pressed for " . keyPressDuration . " ms (Down: " . upKeyDownTime . ", Up: " . keyUpTime . ")")
        upKeyIsDown := false

        ; Only proceed if key was held less than 3000ms
        if (keyPressDuration >= 3000) {
            Log("Up arrow action skipped - key was held too long (" . keyPressDuration . "ms)")
            ; Get mouse position for tooltip
            MouseGetPos(&mouseX, &mouseY)
            ; Show tooltip indicating cancellation by long press
            TransparentToolTip("Up arrow action cancelled - key held too long", mouseX + 20, mouseY - 40, 3, 2000, "333399", "FFFFFF", 220)
            return
        }

        ; Check if this key just cancelled its own action type
        if (upKeyCancelledAction) {
            Log("Up arrow key-up ignored - this key just cancelled its own action type")
            upKeyCancelledAction := false
            return
        }

        ; Check if host is available for blacklist operations
        if (!host || host.isManualMode) {
            Log("Up arrow hotkey (blacklist+skip) - blacklist action failed: Host not connected")
            MsgBox("Cannot add to blacklist - Videochat Extension connection is required.`n`nPlease make sure the extension is installed and connected to Skipper (there is a dedicated tab for it in the extension UI).", "Extension Not Connected", "Icon!")
            return
        } else {
            ; First, send blacklist message to Chrome
            blacklistMsg := Map(
                "type", "blacklist_action",
                "action", "toggle",
                "source", "skipper_hotkey",
                "hotkey", "up_arrow"
            )
            try {
                host.SendMessage(blacklistMsg)
                Log("Sent blacklist add notification to Chrome for up arrow")

                ; Show tooltip for blacklist+skip action
                MouseGetPos(&mouseX, &mouseY)
                TransparentToolTip("BLACKLISTED + SKIP!", mouseX + 20, mouseY - 40, 5, 1500, "992200", "FFFFFF", 230)
            } catch Error as e {
                Log("Failed to send up arrow blacklist notification: " . e.Message)
            }
        }

        ; Trigger the skip action asynchronously
        SetTimer(() => ProcessArrowAction("up_arrow", "up_arrow", "skip", isSkipDoubleClicked), -1)
    }
    return
}
#HotIf  ; End conditional hotkey block

; Set up hotkey for down arrow
#HotIf isDownArrowBlocked && (!host.isManualMode) && !isSkipperSuppressed  ; Only active when blocking is enabled
; Block the key-down event completely but record the time only once
Down::
{
    global downKeyDownTime, downKeyIsDown, pendingCancellation, cancelledByKey
    global downKeyCancelledAction, cancelledActionType

    ; Only record the timestamp the first time the key is pressed down
    if (!downKeyIsDown) {
        downKeyDownTime := A_TickCount
        downKeyIsDown := true
        Log("Down key down at: " . downKeyDownTime)

        ; Down arrow performs an instant action (blacklist), so it shouldn't cancel ongoing actions
        ; This allows blacklisting while skip/stop is in progress
        downKeyCancelledAction := false

        ; Log if an action is in progress, but don't cancel it
        if (ClickState.IsClickInProgress()) {
            currentActionType := ClickState.GetCurrentClickType()
            Log("Action in progress (" . currentActionType . ") - Down arrow will NOT cancel it (instant action)")
        }
    }
    return
}

; Process on key-up instead
Down Up::  ; Down arrow key handler
{
    ; Skip processing if in manual mode
    global host
    if (host && host.isManualMode) {
        return
    }

    global downKeyDownTime, downKeyIsDown, host, downKeyCancelledAction

    ; Calculate time between down and up only if we recorded a valid down event
    if (downKeyIsDown) {
        keyUpTime := A_TickCount
        keyPressDuration := keyUpTime - downKeyDownTime
        Log("Down arrow key was pressed for " . keyPressDuration . " ms (Down: " . downKeyDownTime . ", Up: " . keyUpTime . ")")
        downKeyIsDown := false

        ; Only proceed if key was held less than 3000ms
        if (keyPressDuration >= 3000) {
            Log("Down arrow action skipped - key was held too long (" . keyPressDuration . "ms)")
            ; Get mouse position for tooltip
            MouseGetPos(&mouseX, &mouseY)
            ; Show tooltip indicating cancellation by long press
            TransparentToolTip("Down arrow action cancelled - key held too long", mouseX + 20, mouseY - 40, 3, 2000, "333399", "FFFFFF", 220)
            return
        }

        ; No need to check for downKeyCancelledAction since down arrow never cancels

        ; Check if host is available for blacklist operations
        if (!host || host.isManualMode) {
            Log("Down arrow hotkey (blacklist) - blacklist action failed: Host not connected")
            MsgBox("Cannot add to blacklist - Videochat Extension connection is required.`n`nPlease make sure the extension is installed and connected to Skipper (there is a dedicated tab for it in the extension UI).", "Extension Not Connected", "Icon!")
            return
        }

        ; Send blacklist message to Chrome
        blacklistMsg := Map(
            "type", "blacklist_action",
            "action", "toggle",
            "source", "skipper_hotkey",
            "hotkey", "down_arrow"
        )
        try {
            host.SendMessage(blacklistMsg)
            Log("Sent blacklist add notification to Chrome for down arrow")

            ; Show tooltip for blacklist-only action
            MouseGetPos(&mouseX, &mouseY)
            TransparentToolTip("BAN/UNBAN", mouseX + 20, mouseY - 40, 5, 1500, "992200", "FFFFFF", 230)
        } catch Error as e {
            Log("Failed to send down arrow blacklist notification: " . e.Message)
        }
    }
    return
}
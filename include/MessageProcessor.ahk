; Message processor class to handle business logic
class MessageProcessor {
    gui := ""
    host := ""

    __New(gui, host) {
        this.gui := gui
        this.host := host
    }

    ; Process incoming messages
    ProcessMessage(msg) {
        Logger.Info("Received message: " . Jxon_Dump(msg))

        ; Ensure msg is an object
        if (Type(msg) == "String") {
            try {
                msg := Jxon_Load(msg)
                Logger.Info("Converted string message to object")
            } catch Error as e {
                Logger.Error("Error parsing message: " . e.Message)
                return
            }
        }

        ; Debug: Log message structure
        Logger.Debug("Message type: " . (msg.Has("type") ? msg["type"] : "NOT FOUND"))

        ; If 'type' is not present, ignore message
        if (!msg.Has("type")) {
            Logger.Error("Message has no type field")
            return
        }

        ; Get type value
        msgType := msg["type"]

        ; Process message based on type
        switch msgType {
            case "ping":
                response := Map("type", "pong")
                this.SendResponse(response)
                Logger.Info("Sent: pong response")
                return

            case "version":
                global AppVersion, AppName
                response := Map(
                    "type", "version",
                    "version", AppVersion,
                    "name", AppName
                )
                this.SendResponse(response)
                Logger.Info("Sent version information: " . AppVersion)
                return

            case "skipper":
                if (msg.Has("action")) {
                    action := msg["action"]
                    if (action = "skip") {
                        Logger.Info("Executing SKIP command")
                        this.ExecuteClickAction("skip")
                    }
                    else if (action = "cancel") {
                        Logger.Info("Executing CANCEL command")
                        ; Check if we should exclude hotkey-initiated actions
                        excludeHotkeys := msg.Has("excludeHotkeys") ? msg["excludeHotkeys"] : false

                        if (excludeHotkeys) {
                            ; Use the special API to exclude hotkey-initiated actions
                            cancelResult := this.CancelNonHotkeyAction("Requested by extension")
                            response := Map("type", "skipper", "status", "success", "action", action, "cancelled", cancelResult.cancelled, "wasHotkey", cancelResult.wasHotkey)
                        } else {
                            ; Cancel any action, including hotkey-initiated ones
                            cancelSuccess := this.CancelClickAction("Requested by extension")
                            response := Map("type", "skipper", "status", "success", "action", action, "cancelled", cancelSuccess)
                        }

                        this.SendResponse(response)
                        return
                    }
                    else {
                        Logger.Warn("Unknown skipper action: " . action)
                    }

                    response := Map("type", "skipper", "status", "success", "action", action)
                    this.SendResponse(response)
                    return
                }

                Logger.Error("Skipper message missing action")
                return

            case "define_region":
                Logger.Info("Received request to define skip region")
                RegionHandler.StartRegionSelection("skip")
                response := Map("type", "define_region", "status", "initiated")
                this.SendResponse(response)
                return

            case "show_region":
                Logger.Info("Received request to show skip region temporarily")
                if (!RegionHandler.skipRegion.active) {
                    response := Map("type", "show_region", "status", "error", "message", "Skip region not defined")
                } else {
                    global isRegionAlwaysVisible, isSkipperSuppressed
                    
                    ; Check if region is already visible - either directly or through always visible setting
                    if (RegionHandler.skipRegion.visible || (isRegionAlwaysVisible && !isSkipperSuppressed)) {
                        response := Map("type", "show_region", "status", "info", "message", "Skip region already visible")
                    } else {
                        ; Show the region
                        RegionHandler.ShowSkipRegion()
                        ; Set a timer to hide it after 1 second
                        SetTimer(() => RegionHandler.HideSkipRegion(), -1000)
                        response := Map("type", "show_region", "status", "success")
                    }
                }
                this.SendResponse(response)
                return

            default:
                Logger.Warn("Unknown message type: " . msgType)
                return
        }
    }

    ; Cancel non-hotkey initiated click actions
    CancelNonHotkeyAction(reason := "API Request") {
        global ClickState_InitiatedByHotkey

        ; Prepare result object
        result := Map(
            "cancelled", false,
            "wasHotkey", false,
            "actionType", ""
        )

        ; Check if there's an action in progress
        if (ClickState.IsClickInProgress()) {
            result.actionType := ClickState.GetCurrentClickType()

            ; Check if this was initiated by a hotkey
            if (ClickState_InitiatedByHotkey) {
                ; Don't cancel hotkey-initiated actions
                Logger.Info("Not cancelling " . result.actionType . " operation - it was initiated by a hotkey")
                result.wasHotkey := true
                return result
            }

            ; Not a hotkey action, proceed with cancellation
            lastTaskId := ClickState.GetCurrentId()
            clickType := ClickState.GetCurrentClickType()

            ; Cancel the click operation with reason
            ClickState.CancelClick(reason)

            Logger.Info("Cancelled " . clickType . " operation (Task ID: " . lastTaskId . ") - Reason: " . reason)

            ; Set global tracking variables
            global pendingCancellation := true
            global cancelledByKey := "api_request"

            result.cancelled := true
            return result
        } else {
            Logger.Info("No click operation in progress to cancel")
            return result
        }
    }

    ; Cancel current click action if one is in progress
    ; Set excludeHotkeys to true to avoid cancelling hotkey-initiated actions
    CancelClickAction(reason := "Unspecified", excludeHotkeys := false) {
        global ClickState_InitiatedByHotkey

        if (ClickState.IsClickInProgress()) {
            ; Check if we should exclude hotkey actions
            if (excludeHotkeys && ClickState_InitiatedByHotkey) {
                Logger.Info("Not cancelling action - it was initiated by a hotkey and excludeHotkeys is true")
                return false
            }

            lastTaskId := ClickState.GetCurrentId()
            clickType := ClickState.GetCurrentClickType()

            ; Cancel the click operation with reason
            ClickState.CancelClick(reason)

            Logger.Info("Cancelled " . clickType . " operation (Task ID: " . lastTaskId . ") - Reason: " . reason)

            ; Set global tracking variables
            global pendingCancellation := true
            global cancelledByKey := "extension_command"

            return true
        } else {
            Logger.Info("No click operation in progress to cancel")
            return false
        }
    }

    ; Execute a click action
    ExecuteClickAction(clickType) {
        ; Check if there's already an action in progress
        if (ClickState.IsClickInProgress()) {
            this.CancelClickAction("New action requested: " . clickType)
            ; Add small sleep to allow cancellation to complete
            Sleep(50)
        }

        ; Log and execute the action
        Logger.Info("Processing click request: " . clickType)
        
        ; Mark this as NOT initiated by hotkey (it's from API)
        global ClickState_InitiatedByHotkey := false

        ; Perform the appropriate action
        if (clickType = "skip") {
            global isSkipDoubleClicked

            ; First check if region is defined
            if (!RegionHandler.skipRegion.active) {
                Logger.Info("Skip region not defined - cannot perform action")
                response := Map("type", "skipper", "status", "error", "message", "Skip region not defined")
                this.SendResponse(response)
                return false
            }

            ; Get current mouse position, similar to Hotkeys.ahk structure
            MouseGetPos(&apiMouseX, &apiMouseY)

            ; Check if mouse is in skip region
            if (!RegionHandler.IsMouseInSkipRegion()) {
                Logger.Info("Mouse is not in skip region (API check at " . apiMouseX . "," . apiMouseY . ") - cannot perform action")
                ; Show tooltip guiding user to move mouse to the skip region
                TooltipManager.Show("Move mouse to the skip button region first", apiMouseX + 20, apiMouseY + 20, 2000, "993333", "FFFFFF", 230)
                response := Map("type", "skipper", "status", "error", "message", "Mouse cursor is not in the skip region")
                this.SendResponse(response)
                return false
            }

            ; Perform the click
            result := ClickHandler.PerformClick("skip", isSkipDoubleClicked)
            
            ; Show a tooltip for successful skip, similar to Hotkeys.ahk
            if (result) {
                MouseGetPos(&endX, &endY)
                TooltipManager.Show("SKIP!", endX + 30, endY - 30, 1000, "339933", "FFFFFF", 230)
            }
            
            return result
        }

        return false
    }

    ; Send a response to the Chrome extension
    SendResponse(response) {
        try {
            if (this.host) { ; Simplified check: ensure host object exists
                this.host.SendMessage(response)
            } else {
                Logger.Error("Error sending response: Host object not available.")
            }
        } catch Error as e {
            Logger.Error("Error sending response: " . e.Message)
        }
    }

    ; Handle skipper command
    HandleSkipperCommand(command, args, messageType) {
        Logger.Info("Processing skipper command: " . command)

        ; Handle skip command
        if (command = "skip") {
            ; First check if region is defined
            if (!RegionHandler.skipRegion.active) {
                Logger.Info("Skip command from extension ignored - skip region not defined")
                ; Get current mouse position for the tooltip
                MouseGetPos(&mouseX, &mouseY)
                ; Show tooltip guiding user to define region first
                TooltipManager.Show("Please define a skip region first!`nClick the 'Define Skip Region' button.", mouseX + 20, mouseY - 40, 3000, "993333", "FFFFFF", 230)
                return Map("success", false, "error", "Skip region not defined")
            }

            ; Check if double-click is enabled
            global isSkipDoubleClicked
            
            ; Mark this as NOT initiated by hotkey (it's from API)
            global ClickState_InitiatedByHotkey := false

            ; Create task to perform skip
            taskId := ClickState.StartClick("skip")

            ; Perform the skip click
            clickResult := ClickHandler.PerformClick("skip", isSkipDoubleClicked)

            ; End the task
            ClickState.EndClick(taskId)

            ; Return result
            if (clickResult) {
                MouseGetPos(&endX, &endY)
                ; Show a tooltip for successful skip
                TooltipManager.Show("SKIP!", endX + 30, endY - 30, 1000, "339933", "FFFFFF", 230)
                return Map("success", true, "x", endX, "y", endY, "doubleClick", isSkipDoubleClicked)
            } else {
                return Map("success", false, "error", "Skip action failed")
            }
        }
    }
}
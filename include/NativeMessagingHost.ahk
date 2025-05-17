; NativeMessagingHost class to handle stdin/stdout communication
class NativeMessagingHost {
    ; Standard handles - using instance properties instead of static
    hStdIn := DllCall("GetStdHandle", "Int", -10, "Ptr")  ; STD_INPUT_HANDLE = -10
    hStdOut := DllCall("GetStdHandle", "Int", -11, "Ptr") ; STD_OUTPUT_HANDLE = -11

    ; Event callbacks
    onMessageCallback := ""
    onDisconnect := ""  ; Callback for when connection is closed

    ; State flags
    isDisconnecting := false  ; Flag to prevent multiple disconnect notifications
    isManualMode := false     ; Flag indicating if app was launched manually instead of by Chrome

    ; Constructor
    __New(onMessageCallback := "", onDisconnect := "") {
        this.onMessageCallback := onMessageCallback
        this.onDisconnect := onDisconnect

        ; Detect if we're in manual mode (not launched by Chrome)
        this.isManualMode := this.DetectManualMode()
        Logger.Info("NativeMessagingHost created. Manual mode: " . (this.isManualMode ? "Yes" : "No"))
    }

    ; Detect if the application was launched manually rather than by Chrome
    DetectManualMode() {
        ; Check if stdin handle is valid and has expected properties
        if (this.hStdIn = 0 || this.hStdIn = -1) {
            Logger.Info("Invalid stdin handle detected. Assuming manual mode.")
            return true  ; Invalid handle - manual mode
        }

        ; Try to peek the pipe - if this fails, we're probably not connected to Chrome
        bytesAvailable := 0
        result := DllCall("PeekNamedPipe", "Ptr", this.hStdIn, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt*", &bytesAvailable, "Ptr", 0)

        ; If pipe peek fails, we're in manual mode
        if (!result) {
            errorCode := DllCall("GetLastError")
            Logger.Info("PeekNamedPipe failed with error code: " . errorCode . ". Assuming manual mode.")
            ; ERROR_BROKEN_PIPE (109) or other pipe-related errors indicate we're not connected to Chrome
            return true
        }

        ; If we got here, the pipe is valid and we're likely launched by Chrome
        Logger.Info("Valid pipe connection detected. Running in Chrome mode.")
        return false
    }

    ; Start listening for messages
    StartListening(interval := 100) {
        Logger.Info("Starting message listener with interval: " . interval . "ms")
        ; Create a timer that calls the CheckStdin method
        timer := ObjBindMethod(this, "CheckStdin")
        SetTimer(timer, interval)
    }

    ; Stop listening for messages
    StopListening() {
        Logger.Info("Stopping message listener")
        timer := ObjBindMethod(this, "CheckStdin")
        SetTimer(timer, 0)
    }

    ; Read a message from stdin and decode it
    ReceiveMessage() {
        ; Check if data is available to read without blocking
        bytesAvailable := 0
        result := DllCall("PeekNamedPipe", "Ptr", this.hStdIn, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt*", &bytesAvailable, "Ptr", 0)

        ; If no data or error, return empty
        if (!result || bytesAvailable < 4) {
            if (!result) {
                Logger.Error("PeekNamedPipe failed when checking for messages")
            }
            return ""
        }

        ; Read 4 bytes for the message length (UInt)
        lengthBuffer := Buffer(4, 0)
        bytesRead := 0
        DllCall("ReadFile", "Ptr", this.hStdIn, "Ptr", lengthBuffer, "UInt", 4, "UInt*", &bytesRead, "Ptr", 0)

        if (bytesRead != 4) {
            Logger.Error("Failed to read message length. Expected 4 bytes, got " . bytesRead)
            return ""
        }

        messageLength := NumGet(lengthBuffer, 0, "UInt")

        if (!messageLength) {
            Logger.Info("Received message with zero length")
            return ""
        }

        Logger.Info("Preparing to read message of length: " . messageLength . " bytes")

        ; Check if the full message is available
        if (bytesAvailable < 4 + messageLength) {
            Logger.Info("Full message not available yet. Available: " . bytesAvailable . ", Need: " . (4 + messageLength))
            return ""
        }

        ; Read the actual message
        messageBuffer := Buffer(messageLength, 0)
        DllCall("ReadFile", "Ptr", this.hStdIn, "Ptr", messageBuffer, "UInt", messageLength, "UInt*", &bytesRead, "Ptr", 0)

        message := StrGet(messageBuffer, bytesRead, "UTF-8")
        Logger.Info("Raw message received: " . (StrLen(message) > 100 ? SubStr(message, 1, 100) . "..." : message))

        ; Parse JSON with error handling
        try {
            ; Create a variable to pass by reference to Jxon_Load
            messageVar := message
            parsed := Jxon_Load(&messageVar)
            Logger.Info("Successfully parsed JSON message")
            return parsed
        } catch Error as e {
            ; Log error and return the raw message string
            Logger.Error("JSON parsing error: " . e.Message)
            return message
        }
    }

    ; Encode a message for transmission
    EncodeMessage(messageContent) {
        try {
            ; Try to encode the message content
            encodedContent := Jxon_Dump(messageContent)
            encodedLength := StrLen(encodedContent)
            Logger.Info("Message encoded successfully. Length: " . encodedLength . " bytes")
            return { length: encodedLength, content: encodedContent }
        } catch Error as e {
            ; If encoding fails, create a simple error message
            Logger.Error("Failed to encode message: " . e.Message)
            errorMsg := Map(
                "error", true,
                "message", "Failed to encode message: " . e.Message
            )
            encodedContent := Jxon_Dump(errorMsg)
            encodedLength := StrLen(encodedContent)
            Logger.Info("Created error response instead. Length: " . encodedLength . " bytes")
            return { length: encodedLength, content: encodedContent }
        }
    }

    ; Send a message to stdout
    SendMessage(messageContent) {
        ; If in manual mode, just log the message attempt but don't try to send
        if (this.isManualMode) {
            Logger.Info("Manual mode: Not sending message to Chrome")
            return 0
        }

        Logger.Info("Preparing to send message to Chrome")

        ; Normal message sending when connected to Chrome
        encodedMessage := this.EncodeMessage(messageContent)

        ; Write the length as UInt (4 bytes)
        lengthBuffer := Buffer(4, 0)
        NumPut("UInt", encodedMessage.length, lengthBuffer)
        bytesWritten := 0
        DllCall("WriteFile", "Ptr", this.hStdOut, "Ptr", lengthBuffer, "UInt", 4, "UInt*", &bytesWritten, "Ptr", 0)

        if (bytesWritten != 4) {
            Logger.Error("Failed to write message length. Expected 4 bytes, wrote " . bytesWritten)
            return 0
        }

        ; Write the content
        contentBuffer := Buffer(encodedMessage.length)
        StrPut(encodedMessage.content, contentBuffer, "UTF-8")
        DllCall("WriteFile", "Ptr", this.hStdOut, "Ptr", contentBuffer, "UInt", encodedMessage.length, "UInt*", &bytesWritten, "Ptr", 0)

        Logger.Info("Message sent. Wrote " . bytesWritten . " of " . encodedMessage.length . " bytes")
        return bytesWritten
    }

    ; Timer function to check stdin
    CheckStdin() {
        ; If already disconnecting, don't check again
        if (this.isDisconnecting)
            return

        ; If in manual mode, we don't need to check stdin
        if (this.isManualMode)
            return

        ; Check if data is available to read without blocking
        bytesAvailable := 0
        result := DllCall("PeekNamedPipe", "Ptr", this.hStdIn, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt*", &bytesAvailable, "Ptr", 0)

        ; If pipe is closed (result = 0), exit the application
        if (!result) {
            ; Set the disconnecting flag first to prevent re-entry
            this.isDisconnecting := true

            ; Log disconnection and exit
            Logger.Warn("Native messaging pipe closed. Chrome connection lost. Exiting application.")
            this.StopListening()

            ; If we have an onDisconnect callback, call it first
            if (IsObject(this.onDisconnect))
                this.onDisconnect.Call()

            ; Exit after a short delay to allow logs to be written
            Logger.Info("Application will exit in 500ms")
            SetTimer(() => ExitApp(), -500)
            return
        }

        ; If no data, return
        if (bytesAvailable < 4)
            return

        receivedMessage := this.ReceiveMessage()
        if (receivedMessage != "") {
            ; Call the callback if defined
            if (this.onMessageCallback && IsObject(this.onMessageCallback)) {
                Logger.Info("Calling message callback handler")
                this.onMessageCallback.Call(receivedMessage)
            } else {
                Logger.Info("No message callback handler defined")
            }
        }
    }
}
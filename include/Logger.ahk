; Logger.ahk - Simple logging class for the Skipper application
class Logger {
    static logFile := A_ScriptDir . "\skipper.log"
    static isInitialized := false
    static enableFileLogging := true
    static enableDebugOutput := true
    
    ; Initialize logger - resets the log file on startup
    static Init() {
        if (this.isInitialized)
            return
            
        ; Clear log file at startup
        if (this.enableFileLogging && FileExist(this.logFile))
            FileDelete(this.logFile)
            
        ; Set initialized flag BEFORE logging anything
        this.isInitialized := true
            
        ; Log startup header - now safe to call since isInitialized is true
        this.Info("===== Skipper Started - " . FormatTime(, "yyyy-MM-dd HH:mm:ss") . " =====")
    }
    
    ; Write a log entry with the specified level
    static Write(message, level) {
        if (!this.isInitialized)
            this.Init()
            
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logEntry := timestamp . " [" . level . "] " . message
        
        ; Write to debug console
        if (this.enableDebugOutput)
            OutputDebug(logEntry)
            
        ; Write to log file
        if (this.enableFileLogging) {
            try {
                FileAppend(logEntry . "`n", this.logFile)
            } catch Error as e {
                OutputDebug("ERROR: Failed to write to log file: " . e.Message)
            }
        }
    }
    
    ; Log debug level message
    static Debug(message) {
        this.Write(message, "DEBUG")
    }
    
    ; Log info level message
    static Info(message) {
        this.Write(message, "INFO")
    }
    
    ; Log warning level message
    static Warn(message) {
        this.Write(message, "WARN")
    }
    
    ; Log error level message
    static Error(message) {
        this.Write(message, "ERROR")
    }
    
    ; Set file logging on/off
    static SetFileLogging(enabled) {
        this.enableFileLogging := enabled
    }
    
    ; Set debug output on/off
    static SetDebugOutput(enabled) {
        this.enableDebugOutput := enabled
    }
    
    ; Change log file path
    static SetLogFile(filePath) {
        this.logFile := filePath
    }
} 
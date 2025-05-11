; ColorPicker.ahk
; Based on https://raw.githubusercontent.com/TheArkive/ColorPicker_ahk2/refs/heads/master/_Color_Picker_Dialog.ahk

; Color selection dialog
ColorSelect(Color := 0, hwnd := 0, &custColorObj := "", disp := false) {
    Static p := A_PtrSize
    disp := disp ? 0x3 : 0x1 ; init disp / 0x3 = full panel / 0x1 = basic panel

    If (custColorObj.Length > 16)
        throw Error("Too many custom colors. The maximum allowed values is 16.")

    Loop (16 - custColorObj.Length)
        custColorObj.Push(0) ; fill out custColorObj to 16 values

    CUSTOM := Buffer(16 * 4, 0) ; init custom colors obj
    CHOOSECOLOR := Buffer((p = 4) ? 36 : 72, 0) ; init dialog

    If (IsObject(custColorObj)) {
        Loop 16 {
            custColor := RGB_BGR(custColorObj[A_Index])
            NumPut("UInt", custColor, CUSTOM, (A_Index - 1) * 4)
        }
    }

    NumPut("UInt", CHOOSECOLOR.size, CHOOSECOLOR, 0) ; lStructSize
    NumPut("UPtr", hwnd, CHOOSECOLOR, p) ; hwndOwner
    NumPut("UInt", RGB_BGR(color), CHOOSECOLOR, 3 * p) ; rgbResult
    NumPut("UPtr", CUSTOM.ptr, CHOOSECOLOR, 4 * p) ; lpCustColors
    NumPut("UInt", disp, CHOOSECOLOR, 5 * p) ; Flags

    if !DllCall("comdlg32\ChooseColor", "UPtr", CHOOSECOLOR.ptr, "UInt")
        return -1

    custColorObj := []
    Loop 16 {
        newCustCol := NumGet(CUSTOM, (A_Index - 1) * 4, "UInt")
        custColorObj.InsertAt(A_Index, RGB_BGR(newCustCol))
    }

    Color := NumGet(CHOOSECOLOR, 3 * A_PtrSize, "UInt")
    return Format("0x{:06X}", RGB_BGR(color))

    RGB_BGR(c) {
        return ((c & 0xFF) << 16 | c & 0xFF00 | c >> 16)
    }
}
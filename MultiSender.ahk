#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode 2
SendMode "Event"

; ══════════════════════════════════════════
;    ⚙️ CONFIG & STORAGE
; ══════════════════════════════════════════
MARGIN_WIN   := 2     ; ระยะห่างระหว่างหน้าต่าง 2px
MSG_FILE     := "messages.txt"
CONFIG_FILE  := "MultiSender.ini"
isSending    := false
blinkState   := false
isNetworkInitialized := false

currentWinIdx := 1
lastInBytes  := 0
lastOutBytes := 0
lastNetUpdate := 0

followers := []
geoIPCache := Map()
geoIPCacheTime := 0

LoadConfig() {
    global followers, CONFIG_FILE
    followers := []
    n := Integer(IniRead(CONFIG_FILE, "Win", "count", "0"))
    Loop n
        followers.Push(IniRead(CONFIG_FILE, "Win", "f" A_Index, ""))
}

SaveConfig() {
    global followers, CONFIG_FILE
    IniWrite(followers.Length, CONFIG_FILE, "Win", "count")
    Loop followers.Length
        IniWrite(followers[A_Index], CONFIG_FILE, "Win", "f" A_Index)
}

LoadMessages() {
    global MSG_FILE
    if !FileExist(MSG_FILE) {
        defaultMsgs := "สวัสดีครับ สนใจสอบถามได้เลยนะ`nขอบคุณที่แวะมารับชมครับผม`nฝากกดหัวใจและติดตามด้วยนะครับ"
        FileAppend(defaultMsgs, MSG_FILE, "UTF-8")
    }
    return FileRead(MSG_FILE, "UTF-8")
}

SaveMessages(txt) {
    global MSG_FILE
    if FileExist(MSG_FILE)
        FileDelete(MSG_FILE)
    FileAppend(Trim(txt, "`r`n "), MSG_FILE, "UTF-8")
}

LoadConfig()
initialText := LoadMessages()

; ══════════════════════════════════════════
;    🎨 UI DESIGN: PREMIUM NEON v6.0
; ══════════════════════════════════════════
BG   := "0A0E27"  
BG2  := "0F1438"  
BG3  := "1A1F3A"  
LINE := "2D2A5C"  
ACC  := "00D9FF"  
ACC2 := "FF006E"  
GRN  := "00FF9F"  
RED  := "FF1744"  
YEL  := "FFD700"  
CYN  := "00D9FF"  
PUR  := "9D4EDD"  
FG   := "E8E8F0"  
FG2  := "A8A8C0"  

UI_W  := 360
UI_H  := 650  
PAD   := 16        
COMP_W := UI_W - (PAD * 2) 

G := Gui("+AlwaysOnTop -MaximizeBox -Caption +Border", "GRID SENDER PRO v6.0")
G.BackColor := BG

; ══════════════════════════════════════════
;    HEADER & CONTROLS
; ══════════════════════════════════════════
G.SetFont("s13 Bold", "Segoe UI Semibold")
G.AddText("x" PAD " y12 Background" BG " c" ACC, "⚡ GRID SENDER")
G.SetFont("s8 cBold c", "Segoe UI")
G.AddText("x+8 yp+3 Background" BG " c" CYN, "v6.0 PREMIUM")

; นาฬิกา + ปุ่มควบคุม
G.SetFont("s10 Bold", "Consolas")
clockDisplay := G.AddText("x" (UI_W - PAD - 140) " y13 w130 h16 Right Background" BG " c" YEL, "00:00:00")

G.SetFont("s9 Bold", "Segoe UI")
G.AddButton("x" (UI_W - PAD - 38) " y11 w18 h18 +0x200 c" ACC, "↻").OnEvent("Click", RefreshNetwork)
G.AddButton("x" (UI_W - PAD - 18) " y11 w18 h18 +0x200 c" RED, "✕").OnEvent("Click", (*) => ExitApp())

G.OnEvent("Size", (*) => WinSetRegion("0-0 w" UI_W " h" UI_H " r8-8", G.Hwnd))

; ドラッグ可能
OnMessage(0x0201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    if (hwnd == G.Hwnd)
        PostMessage(0xA1, 2,,, G.Hwnd)
}

; ══════════════════════════════════════════
;    NETWORK STATUS PANEL
; ══════════════════════════════════════════
G.AddText("x" PAD " y+12 w" COMP_W " h1 Background" LINE, "")

G.SetFont("s8.5 Bold", "Consolas")
ipDisplay := G.AddText("x" PAD " y+5 w" COMP_W " h13 Background" BG2 " c" ACC " Center", "📡 IP: ---")

G.SetFont("s7.5", "Consolas")
geoDisplay := G.AddText("x" PAD " y+3 w" COMP_W " h12 Background" BG2 " c" CYN " Center", "📍 LOCATION: Initializing...")

G.SetFont("s8 Bold", "Consolas")
netSpeedDisplay := G.AddText("x" PAD " y+3 w" COMP_W " h13 Background" BG2 " c" GRN " Center", "⬇ 0.0 KB/s | ⬆ 0.0 KB/s")

; ══════════════════════════════════════════
;    STATUS INDICATOR
; ══════════════════════════════════════════
G.AddText("x" PAD " y+6 w" COMP_W " h1 Background" LINE, "")
G.SetFont("s8.5 Bold", "Segoe UI")
statusDot  := G.AddText("x" PAD " y+6 w12 h16 Background" BG " c" GRN, "●")
statusText := G.AddText("x+5 yp w" (COMP_W - 17) " h16 Background" BG " c" GRN, "SYSTEM READY")

; ══════════════════════════════════════════
;    WINDOW REGISTRATION
; ══════════════════════════════════════════
G.AddText("x" PAD " y+8 w" COMP_W " h1 Background" LINE, "")
G.SetFont("s8 Bold", "Segoe UI")
G.AddText("x" PAD " y+6 c" FG2, "📺 ลงท���เบียนเป้าหมายจัดเรียงหน้าจอ:")

BTN2_W := Floor((COMP_W - 8) / 2)
G.AddButton("x" PAD " y+5 w" BTN2_W " h24 +0x200 c" ACC, "+ เพิ่มจอ (F6)").OnEvent("Click", AddFollower)
G.AddButton("x+8 yp w" BTN2_W " h24 +0x200 c" RED, "🗑 ล้างทั้งหมด").OnEvent("Click", ClearFollowers)

; ══════════════════════════════════════════
;    MESSAGE EDITOR
; ══════════════════════════════════════════
G.AddText("x" PAD " y+10 w" COMP_W " h1 Background" LINE, "")
G.SetFont("s8 Bold", "Segoe UI")
G.AddText("x" PAD " y+6 c" ACC, "✏️ บรรณาธิการข้อความ (แต่ละบรรทัด = 1 ข้อความ):")
G.SetFont("s9", "Segoe UI")
msgEditor := G.AddEdit("x" PAD " y+5 w" COMP_W " h100 Background" BG3 " c" FG " WantTab +VScroll", initialText)

; ══════════════════════════════════════════
;    ACTION BUTTONS
; ══════════════════════════════════════════
G.AddText("x" PAD " y+8 w" COMP_W " h1 Background" LINE, "")
G.SetFont("s10 Bold", "Segoe UI")
btnTrigger := G.AddButton("x" PAD " y+7 w" BTN2_W " h36 c" ACC2, "🚀 ยิงข้อความ (F1)")
btnArrange := G.AddButton("x+8 yp w" BTN2_W " h36 c" PUR, "🎯 จัดหน้าจอ")
btnTrigger.OnEvent("Click", ManualSendAction)
btnArrange.OnEvent("Click", ArrangeWindows)

; ══════════════════════════════════════════
;    LOG DISPLAY
; ══════════════════════════════════════════
G.AddText("x" PAD " y+8 w" COMP_W " h1 Background" LINE, "")
G.SetFont("s7.5", "Consolas")
logBox := G.AddEdit("x" PAD " y+5 w" COMP_W " h55 ReadOnly -Wrap +0x200000 Background" BG3 " c" GRN)

; Window Queue Info
G.SetFont("s7.5 Bold", "Segoe UI")
queueInfo := G.AddText("x" PAD " y+6 w" COMP_W " h13 Background" BG " c" FG2, "📌 ยังไม่มีจอที่ลงทะเบียน")

; ══════════════════════════════════════════
;    INITIALIZATION
; ══════════════════════════════════════════
InitNetworkCounter()
SetTimer UpdateClock, 1000
SetTimer UpdateNetworkSpeed, 2000
SetTimer FetchGeoIPEnhanced, -500

UpdateStatusLabel()
G.Show("w" UI_W " h" UI_H)
WinSetTransparent(240, G.Hwnd)

; ══════════════════════════════════════════
;    🕐 TIMER FUNCTIONS
; ══════════════════════════════════════════
UpdateClock() {
    global clockDisplay
    clockDisplay.Value := FormatTime(, "HH:mm:ss")
}

BlinkLED() {
    global blinkState, statusDot, isSending, YEL, BG
    if !isSending {
        SetTimer BlinkLED, 0 
        return
    }
    blinkState := !blinkState
    statusDot.SetFont(blinkState ? "c" YEL : "c" BG)
}

RefreshNetwork() {
    global geoIPCache, geoIPCacheTime
    geoIPCache := Map()
    geoIPCacheTime := 0
    FetchGeoIPEnhanced()
    SetStatus("🔄 รีเฟรชเน็ตเวิร์ก...", "FFD700")
    Sleep 500
    UpdateStatusLabel()
}

; ══════════════════════════════════════════
;    🌐 ENHANCED NETWORK & GEOLOCATION
; ══════════════════════════════════════════
FetchGeoIPEnhanced() {
    global ipDisplay, geoDisplay, geoIPCache, geoIPCacheTime, isNetworkInitialized
    
    ; ตรวจสอบ Cache
    currentTime := A_TickCount
    if (geoIPCacheTime != 0 && (currentTime - geoIPCacheTime) < 30000) {
        return
    }
    
    try {
        ; Primary API: ip-api.com
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(5000, 5000, 5000, 5000)
        whr.Open("GET", "http://ip-api.com/json/?fields=status,query,country,regionName,city,isp,lat,lon", false)
        whr.Send()
        
        if (whr.Status == 200) {
            res := whr.ResponseText
            if InStr(res, '"status":"success"') {
                RegExMatch(res, '"query":"([^"]+)"', &matchIp)
                RegExMatch(res, '"country":"([^"]+)"', &matchCountry)
                RegExMatch(res, '"regionName":"([^"]+)"', &matchRegion)
                RegExMatch(res, '"city":"([^"]+)"', &matchCity)
                RegExMatch(res, '"isp":"([^"]+)"', &matchISP)
                RegExMatch(res, '"lat":([^,}]+)', &matchLat)
                RegExMatch(res, '"lon":([^,}]+)', &matchLon)
                
                ip := matchIp ? matchIp[1] : "Unknown"
                country := matchCountry ? matchCountry[1] : "—"
                region := matchRegion ? matchRegion[1] : "—"
                city := matchCity ? matchCity[1] : "—"
                isp := matchISP ? matchISP[1] : "—"
                
                geoIPCache["ip"] := ip
                geoIPCache["country"] := country
                geoIPCache["region"] := region
                geoIPCache["city"] := city
                geoIPCache["isp"] := isp
                geoIPCacheTime := currentTime
                isNetworkInitialized := true
                
                ipDisplay.Value := "📡 IP: " ip " | ISP: " isp
                geoDisplay.Value := "📍 " city ", " region " | " country
                return
            }
        }
        
        ; Fallback: ipify (ง่ายกว่า)
        whr2 := ComObject("WinHttp.WinHttpRequest.5.1")
        whr2.SetTimeouts(5000, 5000, 5000, 5000)
        whr2.Open("GET", "https://api.ipify.org?format=json", false)
        whr2.Send()
        
        if (whr2.Status == 200) {
            res2 := whr2.ResponseText
            RegExMatch(res2, '"ip":"([^"]+)"', &matchIp2)
            if (matchIp2) {
                ip := matchIp2[1]
                geoIPCache["ip"] := ip
                geoIPCacheTime := currentTime
                isNetworkInitialized := true
                
                ipDisplay.Value := "📡 IP: " ip " | (Limited Info)"
                geoDisplay.Value := "📍 Location data unavailable"
                return
            }
        }
        
        ipDisplay.Value := "📡 IP: Unable to fetch"
        geoDisplay.Value := "📍 No location data"
        
    } catch error {
        if !isNetworkInitialized {
            ipDisplay.Value := "📡 ⚠️ Network Error/Offline"
            geoDisplay.Value := "📍 ⚠️ Check your connection"
        }
    }
}

InitNetworkCounter() {
    global lastInBytes, lastOutBytes
    try {
        for obj in ComObjGet("winmgmts:").ExecQuery("Select BytesReceivedPersec, BytesSentPersec From Win32_PerfRawData_Tcpip_NetworkInterface") {
            lastInBytes  += Integer(obj.BytesReceivedPersec)
            lastOutBytes += Integer(obj.BytesSentPersec)
        }
    } catch {
        lastInBytes  := 0
        lastOutBytes := 0
    }
}

UpdateNetworkSpeed() {
    global lastInBytes, lastOutBytes, netSpeedDisplay
    currentIn := 0, currentOut := 0
    
    try {
        for obj in ComObjGet("winmgmts:").ExecQuery("Select BytesReceivedPersec, BytesSentPersec From Win32_PerfRawData_Tcpip_NetworkInterface") {
            currentIn  += Integer(obj.BytesReceivedPersec)
            currentOut += Integer(obj.BytesSentPersec)
        }
    } catch {
        return
    }
    
    if (lastInBytes = 0 && lastOutBytes = 0) {
        lastInBytes := currentIn
        lastOutBytes := currentOut
        return
    }
    
    diffIn := currentIn - lastInBytes
    diffOut := currentOut - lastOutBytes
    
    if (diffIn < 0 || diffOut < 0) {
        lastInBytes := currentIn
        lastOutBytes := currentOut
        return
    }
    
    netSpeedDisplay.Value := "⬇ " FormatBytes(diffIn) " | ⬆ " FormatBytes(diffOut)
    lastInBytes := currentIn
    lastOutBytes := currentOut
}

FormatBytes(bytes) {
    if (bytes > 1048576)
        return Round(bytes / 1048576, 2) " MB/s"
    else if (bytes > 1024)
        return Round(bytes / 1024, 1) " KB/s"
    else
        return bytes " B/s"
}

; ══════════════════════════════════════════
;    🎯 WINDOW MANAGEMENT
; ══════════════════════════════════════════
AddFollower(*) {
    global followers
    MouseGetPos(,, &hw)
    if !hw
        return
    
    id := "ahk_id " hw
    for v in followers {
        if (v = id) {
            Flash("⚠️ หน้าต่างนี้มีอยู่แล้ว!", RED)
            return
        }
    }
    
    followers.Push(id)
    SaveConfig()
    UpdateStatusLabel()
    Flash("✅ เพิ่มหน้าต่างสำเร็จ!", GRN)
}

ClearFollowers(*) {
    global followers, currentWinIdx, queueInfo
    if (followers.Length == 0) {
        Flash("ℹ️ ไม่มีหน้าต่างให้ล้าง", FG2)
        return
    }
    
    followers := []
    currentWinIdx := 1
    SaveConfig()
    UpdateStatusLabel()
    Flash("🗑 ล้างหน้าต่างทั้งหมดแล้ว!", GRN)
}

UpdateStatusLabel() {
    global followers, currentWinIdx, queueInfo, GRN, RED
    
    if (followers.Length == 0) {
        SetStatus("🔴 ยังไม่มีจอที่ลงทะเบียน | กด F6 เพิ่ม", RED)
        queueInfo.SetFont("c" RED)
        queueInfo.Value := "📌 ล็อกหน้าต่าง: 0"
    } else {
        SetStatus("🟢 ล็อกไว้ " followers.Length " จอ | ถัดไป: #" currentWinIdx, GRN)
        queueInfo.SetFont("c" GRN)
        queueInfo.Value := "📌 ล็อกหน้าต่าง: " followers.Length " | เป้าหมายถัดไป: #" currentWinIdx "/" followers.Length
    }
}

ArrangeWindows(*) {
    global followers, MARGIN_WIN
    
    if (followers.Length == 0) {
        SetStatus("❌ กรุณากด F6 ล็อกหน้าต่างแรกก่อน", RED)
        return
    }
    
    ; นับหน้าต่างที่เปิดอยู่
    activeFollowers := []
    for id in followers {
        if WinExist(id)
            activeFollowers.Push(id)
    }
    
    totalCount := activeFollowers.Length
    if (totalCount == 0) {
        SetStatus("❌ ไม่พบหน้าต่างใดเปิดอยู่", RED)
        return
    }
    
    ; ดึงขนาดจอ
    MonitorGetWorkArea(1, &M_L, &M_T, &M_R, &M_B)
    screenW := M_R - M_L
    screenH := M_B - M_T
    
    ; คำนวณแถว/คอลัมน์อัตโนมัติ
    cols := Ceil(Sqrt(totalCount))
    rows := Ceil(totalCount / cols)
    
    ; ขนาดหน้าต่าง
    winW := Floor((screenW - (MARGIN_WIN * (cols + 1))) / cols)
    winH := Floor((screenH - (MARGIN_WIN * (rows + 1))) / rows)
    
    ; จัดเรียง
    movedCount := 0
    for id in activeFollowers {
        WinRestore(id)
        
        colIdx := Mod(movedCount, cols)
        rowIdx := Floor(movedCount / cols)
        
        X := M_L + MARGIN_WIN + (colIdx * (winW + MARGIN_WIN))
        Y := M_T + MARGIN_WIN + (rowIdx * (winH + MARGIN_WIN))
        
        WinMove(X, Y, winW, winH, id)
        movedCount++
    }
    
    SetStatus("🎯 จัดเรียง " movedCount " จอ (" cols "x" rows ") สำเร็จ", ACC)
    AddLog("✅ Grid Layout: " cols "x" rows " | Window: " winW "x" winH)
}

; ══════════════════════════════════════════
;    🚀 MESSAGE SENDER ENGINE
; ══════════════════════════════════════════
ManualSendAction(*) {
    global isSending, msgEditor, followers, currentWinIdx
    
    if isSending
        return
    
    if (followers.Length == 0) {
        SetStatus("❌ กรุณากด F6 ล็อกหน้าต่างแรกก่อน!", RED)
        return
    }
    
    ; โหลดข้อความ
    rawTxt := msgEditor.Value
    SaveMessages(rawTxt)
    
    lines := []
    Loop Parse rawTxt, "`n", "`r" {
        t := Trim(A_LoopField)
        if (t != "")
            lines.Push(t)
    }
    
    if (lines.Length == 0) {
        SetStatus("❌ กรุณาพิมพ์ข้อความก่อน!", RED)
        return
    }
    
    ; หา ID เป้าหมาย
    if (currentWinIdx > followers.Length)
        currentWinIdx := 1
    
    targetID := followers[currentWinIdx]
    
    if !WinExist(targetID) {
        AddLog("⚠️ จอ #" currentWinIdx " ปิดแล้ว")
        currentWinIdx++
        if (currentWinIdx > followers.Length)
            currentWinIdx := 1
        return
    }
    
    isSending := true
    SetStatus("⚡ ส่งไปยังจอ #" currentWinIdx "...", YEL)
    SetTimer BlinkLED, 250
    
    chosenMsg := lines[Random(1, lines.Length)]
    shortMsg := StrLen(chosenMsg) > 20 ? SubStr(chosenMsg, 1, 20) "..." : chosenMsg
    
    ; เตรียม
    Send "{ShiftUp}{CtrlUp}{AltUp}{LButtonUp}"
    Sleep 40
    
    WinActivate(targetID)
    if !WinWaitActive(targetID,, 3) {
        isSending := false
        SetStatus("❌ ไม่สามารถเปิดใจหน้าต่าง", RED)
        return
    }
    Sleep 60
    
    ; ล้างข้อความเก่า
    Loop 5
        Send "{Backspace}"
    Sleep 40
    
    SetKeyDelay 10, 10
    
    ; พิมพ์ข้อความ
    Loop Parse chosenMsg {
        if !isSending
            break
        SendEvent "{Raw}" A_LoopField
    }
    
    if !isSending {
        isSending := false
        return
    }
    
    Sleep 100
    Send "{Enter}"
    
    AddLog("✅ จอ #" currentWinIdx ": " shortMsg)
    
    currentWinIdx++
    if (currentWinIdx > followers.Length)
        currentWinIdx := 1
    
    UpdateStatusLabel()
    isSending := false
    SetTimer BlinkLED, 0
    SetStatus("🟢 READY", GRN)
}

EmergencyStop(*) {
    global isSending
    isSending := false
    SetStatus("🛑 EMERGENCY STOP", RED)
    AddLog("🛑 หยุดฉุกเฉิน!")
}

SetStatus(txt, col) {
    global statusText, statusDot
    statusText.Value := txt
    statusText.SetFont("c" col)
    statusDot.SetFont("c" col)
}

AddLog(txt) {
    global logBox
    timestamp := FormatTime(, "HH:mm:ss")
    logBox.Value := logBox.Value "[" timestamp "] " txt "`r`n"
    SendMessage(0x115, 7, 0, logBox)
}

Flash(txt, col) {
    ToolTip txt
    ToolTipOptions "c" col
    SetTimer () => ToolTip(), -2500
}

; ══════════════════════════════════════════
;    ⌨️ HOTKEYS
; ══════════════════════════════════════════
$F1::ManualSendAction()
$F2::EmergencyStop()
F4::ExitApp()
F6::AddFollower()

; <COMPILER: v1.1.37.02a2>
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
SafeTarget(path) {
    SplitPath(path,,&directory)
    loop {
        if FileExist(directory) && (DllCall("GetFileAttributesW","Str",directory,"UInt") & 0x400)
            throw Error("Import cannot write through linked folders.")
        SplitPath(directory,,&parent)
        if parent = directory || parent = ""
            break
        directory := parent
    }
}

class AAInstance {
static handle := 0
static Acquire(name := "Local\BayzoAAMacroInteractive") {
if this.handle
throw Error("The interactive instance lock is already held by this process.")
handle := DllCall("kernel32\CreateMutexW","Ptr",0,"Int",0,"Str",name,"Ptr")
status := A_LastError
if !handle
throw Error("Could not check whether the macro is already open. Windows error " status ".")
if status = 183 {
DllCall("kernel32\CloseHandle","Ptr",handle)
this.ActivateExisting()
return false
}
this.handle := handle
OnExit(ObjBindMethod(this,"Release"))
return true
}
static ActivateExisting() {
previous := A_DetectHiddenWindows
DetectHiddenWindows(true)
try {
for hwnd in WinGetList() {
if !DllCall("GetPropW","Ptr",hwnd,"Str","BayzosAAInteractive","Ptr")
continue
try {
WinShow("ahk_id " hwnd)
WinRestore("ahk_id " hwnd)
WinActivate("ahk_id " hwnd)
}
return
}
} finally DetectHiddenWindows(previous)
}
static Release(*) {
if this.handle {
handle := this.handle, this.handle := 0
DllCall("kernel32\CloseHandle","Ptr",handle)
}
}
}
#Requires AutoHotkey v2.0
#SingleInstance Off
class CrusadersUpdater {
    static Version := "2.2-clean"
    static Repo := ""
    static AssetRoot := EnvGet("LOCALAPPDATA") "\BayzoAnimeAdventuresMacro"
    static Check(window) => 0
    static Respond(accepted, window) => 0
    static checked := true
    static pending := 0
    static installing := false
}
AADisplay.UsePhysicalPixels()
class AADisplay {
static UsePhysicalPixels() {
static change := DllCall("GetProcAddress","Ptr",DllCall("GetModuleHandle","Str","user32","Ptr"),
"AStr","SetThreadDpiAwarenessContext","Ptr")
if !change
return false
return !!(DllCall(change,"Ptr",-4,"Ptr") || DllCall(change,"Ptr",-3,"Ptr"))
}
static FitBounds(left,top,right,bottom,width,height,x := unset,y := unset) {
width := Min(width,Max(1,right-left-8)), height := Min(height,Max(1,bottom-top-8))
x := IsSet(x) ? Max(left,Min(x,right-width)) : left+(right-left-width)//2
y := IsSet(y) ? Max(top,Min(y,bottom-height)) : top+(bottom-top-height)//2
return [x,y,width,height]
}
static Dpi(hwnd) {
this.UsePhysicalPixels()
try return DllCall("GetDpiForWindow","Ptr",hwnd,"UInt") || 96
catch
return 96
}
}
if A_Args.Length = 1 && A_Args[1] = "--update-version" {
FileAppend(CrusadersUpdater.Version, "*")
ExitApp()
}
class CrusadersTheme {
static Path(root, name) {
if IsObject(name) || !RegExMatch(name, "^[A-Za-z0-9][A-Za-z0-9 _-]{0,47}$") || RegExMatch(name, "i)^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?: |$)") || SubStr(name, -1) = " "
throw Error("Use a theme name with 1-48 letters, numbers, spaces, dashes or underscores.")
path := root "\" name ".json"
CrusadersConfigCodes.SafeTarget(path)
return path
}
static Store(root, name, colors, background := 0) {
path := this.Path(root, name), json := this.CustomColors(colors)
data := Map("version", 1, "name", name, "colors", Jxon_Load(&json))
if IsObject(background)
data["background"] := this.BackgroundOptions(background)
expected := FileExist(path) ? FileRead(path) : ""
DirCreate(root)
temporary := CrusadersStorage.Temporary(path)
try {
FileAppend(Jxon_Dump(data, 0), temporary, "UTF-8-RAW")
CrusadersStorage.Commit(temporary, path, expected)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
return path
}
static List(root) {
themes := []
if !DirExist(root)
return themes
CrusadersConfigCodes.SafeTarget(root)
loop files root "\*.json" {
try {
if FileGetSize(A_LoopFileFullPath) > 4096
continue
CrusadersConfigCodes.SafeTarget(A_LoopFileFullPath)
text := FileRead(A_LoopFileFullPath), theme := Jxon_Load(&text)
if !(theme is Map) || theme.Get("version",0) != 1 || this.Path(root, theme["name"]) != A_LoopFileFullPath
continue
json := this.CustomColors(theme["colors"])
themes.Push(Map("name",theme["name"],"colors",Jxon_Load(&json),"background",this.BackgroundOptions(theme.Get("background",Map()))))
} catch Error {
continue
}
}
return themes
}
static CustomColors(colors) {
keys := ["bg", "surface", "raised", "field", "line", "text", "muted", "accent", "accent-ink", "select"]
if !(colors is Map) || colors.Count != keys.Length
throw Error("Choose a color for every theme field.")
normalized := Map()
for key in keys {
if !colors.Has(key) || IsObject(colors[key]) || !RegExMatch(colors[key], "^#[0-9A-Fa-f]{6}$")
throw Error("Theme colors must be valid RGB colors.")
normalized[key] := StrLower(colors[key])
}
return Jxon_Dump(normalized, 0)
}
static BackgroundOptions(input) {
if !(input is Map)
throw Error("Invalid background settings.")
file := input.Get("file", "")
if IsObject(file) || (file != "" && !RegExMatch(file, "i)^[a-f0-9]{16}\.(png|jpg|jpeg|gif|mp4)$"))
throw Error("Invalid background file.")
label := input.Get("label", "")
if IsObject(label) || StrLen(label) > 150 || InStr(label,"`n") || InStr(label,"`r")
throw Error("Invalid background label.")
output := Map("file",file,"label",label,"opacity",input.Get("opacity",35),"dim",input.Get("dim",35),"fit",input.Get("fit","Fill"),"paused",input.Get("paused",false))
for key in ["opacity","dim"]
if !IsNumber(output[key]) || output[key] < 0 || output[key] > 100
throw Error("Background sliders must be between 0 and 100.")
if IsObject(output["fit"]) || !InStr("|Fill|Fit|Tile|", "|" output["fit"] "|") || (output["paused"] != 0 && output["paused"] != 1)
throw Error("Invalid background display settings.")
if RegExMatch(file,"i)\.mp4$") && output["fit"] = "Tile"
throw Error("Use Fill or Fit for an MP4 background.")
return output
}
static CheckVideo(duration, width, height, rate) {
if !IsNumber(duration) || !IsNumber(width) || !IsNumber(height) || !IsNumber(rate)
throw Error("Could not read MP4 metadata. Use an H.264 MP4.")
if duration <= 0 || duration > 300000000 || width <= 0 || height <= 0 || width > 1920 || height > 1080 || rate <= 0 || rate > 30000
throw Error("MP4 limit: 30 seconds, 1920 x 1080, and 30 FPS.")
}
static MediaRange(header,size) {
if header = ""
return [0,size-1,200]
if !RegExMatch(header,"^bytes=(\d*)-(\d*)$",&match) || (match[1]="" && match[2]="")
throw Error("Invalid media range")
if match[1] = "" {
start := Max(0,size-Integer(match[2])), end := size-1
} else {
start := Integer(match[1]), end := match[2]="" ? size-1 : Min(size-1,Integer(match[2]))
}
if start < 0 || start >= size || end < start
throw Error("Media range unavailable")
return [start,end,206]
}
static ImportBackground(root, path) {
SplitPath(path,&name,&directory,&extension)
extension := StrLower(extension)
if !InStr("|png|jpg|jpeg|gif|mp4|", "|" extension "|") || !FileExist(path)
throw Error("Choose a PNG, JPG, GIF, or MP4 file.")
if FileGetSize(path) <= 0 || FileGetSize(path) > 20 * 1024 * 1024
throw Error("Background files must be 20 MB or smaller.")
if extension = "mp4" {
item := ComObject("Shell.Application").NameSpace(directory).ParseName(name)
this.CheckVideo(item.ExtendedProperty("System.Media.Duration"),item.ExtendedProperty("System.Video.FrameWidth"),item.ExtendedProperty("System.Video.FrameHeight"),item.ExtendedProperty("System.Video.FrameRate"))
} else {
token := Gdip_Startup(), bitmap := 0
if !token
throw Error("Could not initialize image loading.")
try {
bitmap := Gdip_CreateBitmapFromFile(path)
if !bitmap
throw Error("This image could not be opened.")
Gdip_GetImageDimensions(bitmap,&width,&height)
if width <= 0 || height <= 0 || width > 4096 || height > 4096
throw Error("Image dimensions must be 4096 x 4096 or smaller.")
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
}
}
CrusadersConfigCodes.SafeTarget(root)
DirCreate(root)
source := FileRead(path,"RAW")
loop files root "\*." extension {
if !RegExMatch(A_LoopFileName,"i)^[a-f0-9]{16}\.(png|jpg|jpeg|gif|mp4)$")
continue
CrusadersConfigCodes.SafeTarget(A_LoopFileFullPath)
if FileGetSize(A_LoopFileFullPath) != source.Size
continue
candidate := FileRead(A_LoopFileFullPath,"RAW")
if candidate.Size = source.Size && DllCall("ntdll\RtlCompareMemory","Ptr",source,"Ptr",candidate,"UPtr",source.Size,"UPtr") = source.Size
return Map("file",A_LoopFileName,"label",SubStr(name,1,150),"opacity",35,"dim",35,"fit","Fill","paused",false)
}
loop {
file := Format("{:08x}{:08x}",Random(0,0x7fffffff),Random(0,0x7fffffff)) "." extension
target := root "\" file
if !FileExist(target)
break
}
CrusadersConfigCodes.SafeTarget(target)
FileCopy(path,target)
return Map("file",file,"label",SubStr(name,1,150),"opacity",35,"dim",35,"fit","Fill","paused",false)
}
static CleanupBackgrounds(root, active) {
CrusadersConfigCodes.SafeTarget(root)
media := root "\Backgrounds"
CrusadersConfigCodes.SafeTarget(media)
if !DirExist(media)
return 0
keep := Map(), candidates := []
keep.CaseSense := "Off"
current := this.BackgroundOptions(active)
if current["file"] != ""
keep[current["file"]] := true
loop files root "\*.json" {
CrusadersConfigCodes.SafeTarget(A_LoopFileFullPath)
if FileGetSize(A_LoopFileFullPath)>4096
throw Error("A saved theme could not be checked for background references.")
text := FileRead(A_LoopFileFullPath), theme := Jxon_Load(&text)
if !(theme is Map) || theme.Get("version",0)!=1
throw Error("A saved theme could not be checked for background references.")
background := this.BackgroundOptions(theme.Get("background",Map()))
if background["file"] != ""
keep[background["file"]] := true
}
loop files media "\*" {
if !RegExMatch(A_LoopFileName,"i)^[a-f0-9]{16}\.(png|jpg|jpeg|gif|mp4)$") || keep.Has(A_LoopFileName)
continue
CrusadersConfigCodes.SafeTarget(A_LoopFileFullPath)
candidates.Push(A_LoopFileFullPath)
}
removed := 0
for path in candidates {
try {
FileDelete(path)
removed++
}
}
return removed
}
static Background := "18191C"
static Sage := "202125"
static Ink := "F0F1F3"
static Muted := "B0B3BC"
static Rose := "202125"
static Accent := "EF8293"
static Field := "17181B"
static Line := "37393F"
static Selected := "35262D"
static roots := Map()
static buttons := Map()
static brushes := Map()
static installed := false
static Mascot := A_ScriptDir "\Images\App\Bayzo.png"
static AppIcon := A_ScriptDir "\Images\App\Bayzo.ico"
static appIcons := Map()
static ApplyAppIcon(gui) {
if !FileExist(this.AppIcon)
return
for kind, size in Map(0, 16, 1, 32) {
if !this.appIcons.Has(kind) {
icon := DllCall("LoadImage", "Ptr", 0, "Str", this.AppIcon, "UInt", 1,
"Int", size, "Int", size, "UInt", 0x10, "Ptr")
if !icon
continue
this.appIcons[kind] := icon
}
SendMessage(0x80, kind, this.appIcons[kind], , gui)
}
}
static Color(hex) {
rgb := Integer("0x" hex)
return ((rgb & 255) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 255)
}
static Brush(hex) {
if !this.brushes.Has(hex)
this.brushes[hex] := DllCall("CreateSolidBrush", "UInt", this.Color(hex), "Ptr")
return this.brushes[hex]
}
static Apply(gui, tileGrid := false) {
this.roots[gui.Hwnd] := true
if !this.installed {
this.installed := true
this.colorHandler := ObjBindMethod(this, "ControlColor")
this.drawHandler := ObjBindMethod(this, "DrawButton")
for message in [0x133, 0x134, 0x135, 0x138]
OnMessage(message, this.colorHandler)
OnMessage(0x2B, this.drawHandler)
OnExit(ObjBindMethod(this, "Dispose"))
}
gui.BackColor := this.Background
for control in gui {
this.roots[control.Hwnd] := true
if control.Type = "Button" && !tileGrid {
WinSetStyle((WinGetStyle(control) & ~0xF) | 0xB, control)
this.buttons[control.Hwnd] := control
} else if control.Type = "DropDownList" || control.Type = "ComboBox" {
WinSetStyle((WinGetStyle(control) & ~0x20) | 0x210, control)
this.buttons[control.Hwnd] := control
SendMessage(0x153, 0, 23, control)
} else if control.Type = "Edit" {
control.Opt("-E0x200 +Border Background" this.Field)
control.SetFont("c" this.Ink)
} else if control.Type = "Checkbox" {
control.Opt("Background" this.Sage)
control.SetFont("c" this.Ink)
} else if control.Type = "ListView" {
control.Opt("Background" this.Field)
control.SetFont("c" this.Ink)
SendMessage(0x1024, 0, this.Color(this.Ink), control)
SendMessage(0x1026, 0, this.Color(this.Field), control)
header := SendMessage(0x101F, 0, 0, control)
this.buttons[header] := {Hwnd: header, Type: "Header", Text: "", Enabled: true}
loop SendMessage(0x1200, 0, 0, header) {
item := Buffer(48, 0)
NumPut("UInt", 4, item)
SendMessage(0x120B, A_Index - 1, item.Ptr, header)
formatOffset := A_PtrSize = 8 ? 28 : 20
NumPut("UInt", NumGet(item, formatOffset, "UInt") | 0x8000, item, formatOffset)
SendMessage(0x120C, A_Index - 1, item.Ptr, header)
}
}
if control.Type != "Picture"
try DllCall("uxtheme\SetWindowTheme", "Ptr", control.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
}
}
static ControlColor(dc, child, message, parent) {
if !this.roots.Has(parent)
return
DllCall("SetTextColor", "Ptr", dc, "UInt", this.Color(this.Ink))
color := message = 0x138 ? this.Sage : this.Field
DllCall("SetBkColor", "Ptr", dc, "UInt", this.Color(color))
return this.Brush(color)
}
static DrawButton(wParam, data, message, parent) {
offset := A_PtrSize = 8 ? 24 : 20
hwnd := NumGet(data, offset, "Ptr")
if !this.buttons.Has(hwnd)
return
control := this.buttons[hwnd]
dc := NumGet(data, offset + A_PtrSize, "Ptr")
rect := data + offset + A_PtrSize * 2
state := NumGet(data, 16, "UInt")
combo := control.Type = "DropDownList" || control.Type = "ComboBox"
text := control.Text
if control.Type = "Header" {
item := Buffer(48, 0)
textBuffer := Buffer(512, 0)
NumPut("UInt", 2, item)
NumPut("Ptr", textBuffer.Ptr, item, 8)
NumPut("Int", 256, item, A_PtrSize = 8 ? 24 : 16)
SendMessage(0x120B, NumGet(data, 8, "UInt"), item.Ptr, control.Hwnd)
text := StrGet(textBuffer)
}
if combo {
index := NumGet(data, 8, "UInt")
if index != 0xFFFFFFFF {
length := SendMessage(0x149, index, 0, control)
if length >= 0 {
textBuffer := Buffer((length + 1) * 2, 0)
SendMessage(0x148, index, textBuffer.Ptr, control)
text := StrGet(textBuffer)
}
}
}
primary := !combo && InStr(text, "Save") = 1
active := !control.Enabled || (state & 1)
color := primary ? this.Accent : active ? this.Selected : combo ? this.Field : this.Sage
DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", this.Brush(color))
DllCall("FrameRect", "Ptr", dc, "Ptr", rect, "Ptr", this.Brush(active ? this.Accent : this.Line))
oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", SendMessage(0x31, 0, 0, control.Hwnd), "Ptr")
DllCall("SetBkMode", "Ptr", dc, "Int", 1)
DllCall("SetTextColor", "Ptr", dc, "UInt", this.Color(primary ? "28151A" : active ? this.Accent : this.Ink))
textRect := Buffer(16)
DllCall("RtlMoveMemory", "Ptr", textRect, "Ptr", rect, "UPtr", 16)
if combo
NumPut("Int", NumGet(textRect, 0, "Int") + 6, textRect, 0)
DllCall("DrawText", "Ptr", dc, "Str", text, "Int", -1, "Ptr", textRect, "UInt", combo ? 0x824 : 0x825)
if state & 0x10
DllCall("DrawFocusRect", "Ptr", dc, "Ptr", rect)
DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
return true
}
static Dispose(*) {
for color, brush in this.brushes
DllCall("DeleteObject", "Ptr", brush)
this.brushes.Clear()
}
}
CrusadersLog(message) {
global macroWindow
if IsSet(macroWindow)
macroWindow.Log(message)
}
PaintCrusadersBackground(hwnd, dc, split, rightColor) {
rect := Buffer(16)
DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
width := NumGet(rect, 8, "Int")
for side, color in [CrusadersTheme.Sage, rightColor] {
rgb := Integer("0x" color)
bgr := ((rgb & 255) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 255)
brush := DllCall("CreateSolidBrush", "UInt", bgr, "Ptr")
NumPut("Int", side = 1 ? 0 : split, rect, 0)
NumPut("Int", side = 1 ? split : width, rect, 8)
DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
DllCall("DeleteObject", "Ptr", brush)
}
return 1
}
class CrusadersLobbyTimeout extends Error {
}
class CrusadersRuntime {
static Tick() => DllCall("GetTickCount64","UInt64")
static DisplayScale(monitor, dc, rect, data) {
scale := 0
if DllCall("Shcore\GetScaleFactorForMonitor", "Ptr", monitor, "Int*", &scale, "Int") != 0 || scale != 100
NumPut("Int", 1, data)
return true
}
static RequireDisplayScale() {
invalid := Buffer(4, 0)
callback := CallbackCreate(ObjBindMethod(CrusadersRuntime, "DisplayScale"), , 4)
try {
if !DllCall("EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", callback, "Ptr", invalid.Ptr)
throw Error("Could not check Windows display scaling.")
if NumGet(invalid, 0, "Int")
throw Error("Set Windows display scale to 100% on every connected monitor before starting.")
} finally CallbackFree(callback)
return true
}
static paused := false
static waitStatus := ""
static Status(base, running) => !running ? base : this.paused ? "Paused" : base = "Running" && this.waitStatus != "" ? this.waitStatus : base
static joining := false
static pausedAt := 0
static pauseTotal := 0
static holdingCamera := false
static cameraButtonDown := false
static CameraSend(down) => SendEvent("{RButton " (down ? "down}" : "up}"))
static CameraButton(down) {
previousCritical := A_IsCritical
Critical("On")
try {
if down = this.cameraButtonDown
return
this.CameraSend(down)
this.cameraButtonDown := down
} finally Critical(previousCritical)
}
static ReleaseCamera() {
this.holdingCamera := false
this.CameraButton(false)
}
static ReleaseControls(*) {
this.ReleaseCamera()
if this.rotationKey != "" {
SendEvent("{" this.rotationKey " up}")
this.rotationKey := ""
}
}
static rotationKey := ""
static zoomInDelay := 50
static zoomOutDelay := 75
static dragDelay := 1
static scanDelay := 150
static InputBusy(window) {
if this.holdingCamera || this.rotationKey != ""
return true
for key in ["inputRecorder", "routeRecorder", "challengeRouteRecorder", "dailyRouteRecorder", "samuraiRouteRecorder"]
if window.HasOwnProp(key) && (window.%key%.playing || window.%key%.recording)
return true
return false
}
static FocusWindow(target) => WinExist(target)
static AutomationActive() {
global testRunning
return IsSet(testRunning) && testRunning
}
static Focused(target) => WinActive(target)
static ActivateWindow(hwnd) => WinActivate("ahk_id " hwnd)
static FocusClock() => CrusadersRuntime.Tick()
static FocusSleep(ms) => Sleep(ms)
static FocusHolds(down) {
if this.holdingCamera
this.CameraButton(down)
if this.rotationKey != ""
SendEvent("{" this.rotationKey (down ? " down}" : " up}"))
}
static EnsureFocus(target := "ahk_exe RobloxPlayerBeta.exe", shouldStop := 0) {
if shouldStop && shouldStop.Call()
return false
if this.Focused(target)
return true
if !this.AutomationActive()
return false
hwnd := this.FocusWindow(target)
if !hwnd
throw Error("Roblox window is no longer open; cannot restore focus.")
started := this.FocusClock()
lastActivation := started - 250
this.FocusHolds(false)
CrusadersLog("Refocusing Roblox")
try {
loop {
if !this.AutomationActive()
return false
if shouldStop && shouldStop.Call()
return false
if !this.FocusWindow("ahk_id " hwnd)
throw Error("Roblox closed while restoring focus.")
if this.FocusClock() - lastActivation >= 250 {
this.ActivateWindow(hwnd)
lastActivation := this.FocusClock()
}
this.FocusSleep(50)
if this.Focused("ahk_id " hwnd) {
if shouldStop && shouldStop.Call()
return false
this.FocusHolds(true)
CrusadersLog("Roblox focused; continuing")
return true
}
if this.FocusClock() - started >= 5000
throw Error("Unable to refocus Roblox. No gameplay input sent.")
}
} finally {
if !this.paused
this.pauseTotal += this.FocusClock() - started
}
}
static Reset() {
this.waitStatus := ""
this.paused := false
this.pausedAt := 0
this.pauseTotal := 0
this.ReleaseCamera()
}
static SetPaused(value) {
if !value && IsObject(CrusadersDetection.snip)
CrusadersDetection.snip.Cancel()
if value = this.paused
return
this.paused := value
if value {
this.pausedAt := CrusadersRuntime.Tick()
this.CameraButton(false)
if this.rotationKey != ""
SendEvent("{" this.rotationKey " up}")
} else {
this.pauseTotal += CrusadersRuntime.Tick() - this.pausedAt
this.pausedAt := 0
if this.holdingCamera
this.CameraButton(true)
if this.rotationKey != ""
SendEvent("{" this.rotationKey " down}")
}
}
static Now() {
return CrusadersRuntime.Tick() - this.pauseTotal - (this.paused ? CrusadersRuntime.Tick() - this.pausedAt : 0)
}
static Wait(milliseconds, shouldStop := 0) {
deadline := this.Now() + milliseconds
while this.Now() < deadline {
if shouldStop && shouldStop.Call()
return false
Sleep(Max(1, Min(20, deadline - this.Now())))
}
return true
}
}
UpdateLayeredWindow(hwnd, hdc, x:="", y:="", w:="", h:="", Alpha:=255)
{
if ((x != "") && (y != "")) {
pt := Buffer(8)
NumPut("UInt", x, "UInt", y, pt)
}
if (w = "") || (h = "") {
WinGetRect(hwnd,,, &w, &h)
}
return DllCall("UpdateLayeredWindow"
, "UPtr", hwnd
, "UPtr", 0
, "UPtr", ((x = "") && (y = "")) ? 0 : pt.Ptr
, "Int64*", w|h<<32
, "UPtr", hdc
, "Int64*", 0
, "UInt", 0
, "UInt*", Alpha<<16|1<<24
, "UInt", 2)
}
BitBlt(ddc, dx, dy, dw, dh, sdc, sx, sy, Raster:="")
{
return DllCall("gdi32\BitBlt"
, "UPtr", dDC
, "Int", dx
, "Int", dy
, "Int", dw
, "Int", dh
, "UPtr", sDC
, "Int", sx
, "Int", sy
, "UInt", Raster ? Raster : 0x00CC0020)
}
StretchBlt(ddc, dx, dy, dw, dh, sdc, sx, sy, sw, sh, Raster:="")
{
return DllCall("gdi32\StretchBlt"
, "UPtr", ddc
, "Int", dx
, "Int", dy
, "Int", dw
, "Int", dh
, "UPtr", sdc
, "Int", sx
, "Int", sy
, "Int", sw
, "Int", sh
, "UInt", Raster ? Raster : 0x00CC0020)
}
SetStretchBltMode(hdc, iStretchMode:=4)
{
return DllCall("gdi32\SetStretchBltMode"
, "UPtr", hdc
, "Int", iStretchMode)
}
SetImage(hwnd, hBitmap)
{
_E := DllCall( "SendMessage", "UPtr", hwnd, "UInt", 0x172, "UInt", 0x0, "UPtr", hBitmap )
DeleteObject(_E)
return _E
}
SetSysColorToControl(hwnd, SysColor:=15)
{
WinGetRect(hwnd,,, &w, &h)
bc := DllCall("GetSysColor", "Int", SysColor, "UInt")
pBrushClear := Gdip_BrushCreateSolid(0xff000000 | (bc >> 16 | bc & 0xff00 | (bc & 0xff) << 16))
pBitmap := Gdip_CreateBitmap(w, h), G := Gdip_GraphicsFromImage(pBitmap)
Gdip_FillRectangle(G, pBrushClear, 0, 0, w, h)
hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
SetImage(hwnd, hBitmap)
Gdip_DeleteBrush(pBrushClear)
Gdip_DeleteGraphics(G), Gdip_DisposeImage(pBitmap), DeleteObject(hBitmap)
return 0
}
Gdip_BitmapFromScreen(Screen:=0, Raster:="")
{
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
hhdc := 0
if (Screen = 0) {
_x := DllCall( "GetSystemMetrics", "Int", 76 )
_y := DllCall( "GetSystemMetrics", "Int", 77 )
_w := DllCall( "GetSystemMetrics", "Int", 78 )
_h := DllCall( "GetSystemMetrics", "Int", 79 )
}
else if (SubStr(Screen, 1, 5) = "hwnd:") {
Screen := SubStr(Screen, 6)
if !WinExist("ahk_id " Screen) {
return -2
}
WinGetRect(Screen,,, &_w, &_h)
_x := _y := 0
hhdc := GetDCEx(Screen, 3)
}
else if IsInteger(Screen) {
M := GetMonitorInfo(Screen)
_x := M.Left, _y := M.Top, _w := M.Right-M.Left, _h := M.Bottom-M.Top
}
else {
S := StrSplit(Screen, "|")
_x := S[1], _y := S[2], _w := S[3], _h := S[4]
}
if (_x = "") || (_y = "") || (_w = "") || (_h = "") {
return -1
}
chdc := CreateCompatibleDC()
hbm := CreateDIBSection(_w, _h, chdc)
obm := SelectObject(chdc, hbm)
hhdc := hhdc ? hhdc : GetDC()
BitBlt(chdc, 0, 0, _w, _h, hhdc, _x, _y, Raster)
ReleaseDC(hhdc)
pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
SelectObject(chdc, obm)
DeleteObject(hbm)
DeleteDC(hhdc)
DeleteDC(chdc)
return pBitmap
}
Gdip_BitmapFromHWND(hwnd)
{
WinGetRect(hwnd,,, &Width, &Height)
hbm := CreateDIBSection(Width, Height), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
PrintWindow(hwnd, hdc)
pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
return pBitmap
}
CreateRectF(&RectF, x, y, w, h)
{
RectF := Buffer(16)
NumPut(
"Float", x,
"Float", y,
"Float", w,
"Float", h,
RectF)
}
CreateRect(&Rect, x, y, w, h)
{
Rect := Buffer(16)
NumPut("UInt", x, "UInt", y, "UInt", w, "UInt", h, Rect)
}
CreateSizeF(&SizeF, w, h)
{
SizeF := Buffer(8)
NumPut("Float", w, "Float", h, SizeF)
}
CreatePointF(&PointF, x, y)
{
PointF := Buffer(8)
NumPut("Float", x, "Float", y, PointF)
}
CreateDIBSection(w, h, hdc:="", bpp:=32, &ppvBits:=0)
{
hdc2 := hdc ? hdc : GetDC()
bi := Buffer(40, 0)
NumPut("UInt", 40, "UInt", w, "UInt", h, "ushort", 1, "ushort", bpp, "UInt", 0, bi)
hbm := DllCall("CreateDIBSection"
, "UPtr", hdc2
, "UPtr", bi.Ptr
, "UInt", 0
, "UPtr*", &ppvBits
, "UPtr", 0
, "UInt", 0, "UPtr")
if (!hdc) {
ReleaseDC(hdc2)
}
return hbm
}
PrintWindow(hwnd, hdc, Flags:=0)
{
return DllCall("PrintWindow", "UPtr", hwnd, "UPtr", hdc, "UInt", Flags)
}
DestroyIcon(hIcon)
{
return DllCall("DestroyIcon", "UPtr", hIcon)
}
GetIconDimensions(hIcon, &Width:=0, &Height:=0) {
ICONINFO := Buffer(size := 16 + 2 * A_PtrSize, 0)
if !DllCall("user32\GetIconInfo", "UPtr", hIcon, "UPtr", ICONINFO.Ptr) {
return -1
}
hbmMask := NumGet(ICONINFO.Ptr, 16, "UPtr")
hbmColor := NumGet(ICONINFO.Ptr, 16 + A_PtrSize, "UPtr")
BITMAP := Buffer(size, 0)
if DllCall("gdi32\GetObject", "UPtr", hbmColor, "Int", size, "UPtr", BITMAP.Ptr) {
Width := NumGet(BITMAP.Ptr, 4, "Int")
Height := NumGet(BITMAP.Ptr, 8, "Int")
}
if !DllCall("gdi32\DeleteObject", "UPtr", hbmMask) {
return -2
}
if !DllCall("gdi32\DeleteObject", "UPtr", hbmColor) {
return -3
}
return 0
}
PaintDesktop(hdc)
{
return DllCall("PaintDesktop", "UPtr", hdc)
}
CreateCompatibleBitmap(hdc, w, h)
{
return DllCall("gdi32\CreateCompatibleBitmap", "UPtr", hdc, "Int", w, "Int", h)
}
CreateCompatibleDC(hdc:=0)
{
return DllCall("CreateCompatibleDC", "UPtr", hdc)
}
SelectObject(hdc, hgdiobj)
{
return DllCall("SelectObject", "UPtr", hdc, "UPtr", hgdiobj)
}
DeleteObject(hObject)
{
return DllCall("DeleteObject", "UPtr", hObject)
}
GetDC(hwnd:=0)
{
return DllCall("GetDC", "UPtr", hwnd)
}
GetDCEx(hwnd, flags:=0, hrgnClip:=0)
{
return DllCall("GetDCEx", "UPtr", hwnd, "UPtr", hrgnClip, "Int", flags)
}
ReleaseDC(hdc, hwnd:=0)
{
return DllCall("ReleaseDC", "UPtr", hwnd, "UPtr", hdc)
}
DeleteDC(hdc)
{
return DllCall("DeleteDC", "UPtr", hdc)
}
Gdip_LibraryVersion()
{
return 1.45
}
Gdip_LibrarySubVersion()
{
return 1.54
}
Gdip_BitmapFromBRA(BRAFromMemIn, File, Alternate := 0) {
if (!BRAFromMemIn) {
return -1
}
Headers := StrSplit(StrGet(BRAFromMemIn.Ptr, 256, "CP0"), "`n")
Header := StrSplit(Headers[1], "|")
HeaderLength := Header.Length
if (HeaderLength != 4) || (Header[2] != "BRA!") {
return -2
}
_Info := StrSplit(Headers[2], "|")
_InfoLength := _Info.Length
if (_InfoLength != 3) {
return -3
}
OffsetTOC := StrPut(Headers[1], "CP0") + StrPut(Headers[2], "CP0")
OffsetData := _Info[2]
SearchIndex := Alternate ? 1 : 2
TOC := StrGet(BRAFromMemIn.Ptr + OffsetTOC, OffsetData - OffsetTOC - 1, "CP0")
RX1 := "mi`n)^"
Offset := Size := 0
if RegExMatch(TOC, RX1 . (Alternate ? File "\|.+?" : "\d+\|" . File) . "\|(\d+)\|(\d+)$", &FileInfo:="") {
Offset := OffsetData + FileInfo[1]
Size := FileInfo[2]
}
if (Size = 0) {
return -4
}
hData := DllCall("GlobalAlloc", "UInt", 2, "UInt", Size, "UPtr")
pData := DllCall("GlobalLock", "Ptr", hData, "UPtr")
DllCall("RtlMoveMemory", "Ptr", pData, "Ptr", BRAFromMemIn.Ptr + Offset, "Ptr", Size)
DllCall("GlobalUnlock", "Ptr", hData)
DllCall("Ole32.dll\CreateStreamOnHGlobal", "Ptr", hData, "Int", 1, "Ptr*", &pStream:=0)
DllCall("Gdiplus.dll\GdipCreateBitmapFromStream", "Ptr", pStream, "Ptr*", &pBitmap:=0)
ObjRelease(pStream)
return pBitmap
}
Gdip_BitmapFromBase64(&Base64)
{
if !(DllCall("crypt32\CryptStringToBinary", "UPtr", StrPtr(Base64), "UInt", 0, "UInt", 0x01, "UPtr", 0, "UInt*", &DecLen:=0, "UPtr", 0, "UPtr", 0)) {
return -1
}
Dec := Buffer(DecLen, 0)
if !(DllCall("crypt32\CryptStringToBinary", "UPtr", StrPtr(Base64), "UInt", 0, "UInt", 0x01, "UPtr", Dec.Ptr, "UInt*", &DecLen, "UPtr", 0, "UPtr", 0)) {
return -2
}
if !(pStream := DllCall("shlwapi\SHCreateMemStream", "UPtr", Dec.Ptr, "UInt", DecLen, "UPtr")) {
return -3
}
DllCall("gdiplus\GdipCreateBitmapFromStreamICM", "UPtr", pStream, "Ptr*", &pBitmap:=0)
ObjRelease(pStream)
return pBitmap
}
Gdip_EncodeBitmapTo64string(pBitmap, extension := "png", quality := "") {
DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", &count:=0, "uint*", &size:=0)
DllCall("gdiplus\GdipGetImageEncoders", "uint", count, "uint", size, "ptr", ci := Buffer(size))
loop {
if (A_Index > count)
throw Error("Could not find a matching encoder for the specified file format.")
idx := (48+7*A_PtrSize)*(A_Index-1)
} until InStr(StrGet(NumGet(ci, idx+32+3*A_PtrSize, "ptr"), "UTF-16"), extension)
pCodec := ci.ptr + idx
if (quality ~= "^-?\d+$") and ("image/jpeg" = StrGet(NumGet(ci, idx+32+4*A_PtrSize, "ptr"), "UTF-16")) {
v := Buffer(4)
NumPut("uint", quality, v)
ep := Buffer(24+2*A_PtrSize)
NumPut(  "uptr",     1, ep,            0)
DllCall("ole32\CLSIDFromString", "wstr", "{1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB}", "ptr", ep.ptr+A_PtrSize, "HRESULT")
NumPut(  "uint",     1, ep, 16+A_PtrSize)
NumPut(  "uint",     4, ep, 20+A_PtrSize)
NumPut(   "ptr", v.ptr, ep, 24+A_PtrSize)
}
DllCall("ole32\CreateStreamOnHGlobal", "ptr", 0, "int", True, "ptr*", &pStream:=0, "HRESULT")
DllCall("gdiplus\GdipSaveImageToStream", "ptr", pBitmap, "ptr", pStream, "ptr", pCodec, "ptr", IsSet(ep) ? ep : 0)
DllCall("ole32\GetHGlobalFromStream", "ptr", pStream, "ptr*", &hbin:=0, "HRESULT")
bin := DllCall("GlobalLock", "ptr", hbin, "ptr")
size := DllCall("GlobalSize", "uint", bin, "uptr")
flags := 0x40000001
length := 4 * Ceil(size/3) + 1
str := Buffer(length)
DllCall("crypt32\CryptBinaryToStringA", "ptr", bin, "uint", size, "uint", flags, "ptr", str, "uint*", &length)
DllCall("GlobalUnlock", "ptr", hbin)
ObjRelease(pStream)
return StrGet(str, length, "CP0")
}
Gdip_DrawRectangle(pGraphics, pPen, x, y, w, h)
{
return DllCall("gdiplus\GdipDrawRectangle", "UPtr", pGraphics, "UPtr", pPen, "Float", x, "Float", y, "Float", w, "Float", h)
}
Gdip_DrawRoundedRectangle(pGraphics, pPen, x, y, w, h, r)
{
Gdip_SetClipRect(pGraphics, x-r, y-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x+w-r, y-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x-r, y+h-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x+w-r, y+h-r, 2*r, 2*r, 4)
_E := Gdip_DrawRectangle(pGraphics, pPen, x, y, w, h)
Gdip_ResetClip(pGraphics)
Gdip_SetClipRect(pGraphics, x-(2*r), y+r, w+(4*r), h-(2*r), 4)
Gdip_SetClipRect(pGraphics, x+r, y-(2*r), w-(2*r), h+(4*r), 4)
Gdip_DrawEllipse(pGraphics, pPen, x, y, 2*r, 2*r)
Gdip_DrawEllipse(pGraphics, pPen, x+w-(2*r), y, 2*r, 2*r)
Gdip_DrawEllipse(pGraphics, pPen, x, y+h-(2*r), 2*r, 2*r)
Gdip_DrawEllipse(pGraphics, pPen, x+w-(2*r), y+h-(2*r), 2*r, 2*r)
Gdip_ResetClip(pGraphics)
return _E
}
Gdip_DrawEllipse(pGraphics, pPen, x, y, w, h)
{
return DllCall("gdiplus\GdipDrawEllipse", "UPtr", pGraphics, "UPtr", pPen, "Float", x, "Float", y, "Float", w, "Float", h)
}
Gdip_DrawBezier(pGraphics, pPen, x1, y1, x2, y2, x3, y3, x4, y4)
{
return DllCall("gdiplus\GdipDrawBezier"
, "UPtr", pgraphics
, "UPtr", pPen
, "Float", x1
, "Float", y1
, "Float", x2
, "Float", y2
, "Float", x3
, "Float", y3
, "Float", x4
, "Float", y4)
}
Gdip_DrawArc(pGraphics, pPen, x, y, w, h, StartAngle, SweepAngle)
{
return DllCall("gdiplus\GdipDrawArc"
, "UPtr", pGraphics
, "UPtr", pPen
, "Float", x
, "Float", y
, "Float", w
, "Float", h
, "Float", StartAngle
, "Float", SweepAngle)
}
Gdip_DrawPie(pGraphics, pPen, x, y, w, h, StartAngle, SweepAngle)
{
return DllCall("gdiplus\GdipDrawPie", "UPtr", pGraphics, "UPtr", pPen, "Float", x, "Float", y, "Float", w, "Float", h, "Float", StartAngle, "Float", SweepAngle)
}
Gdip_DrawLine(pGraphics, pPen, x1, y1, x2, y2)
{
return DllCall("gdiplus\GdipDrawLine"
, "UPtr", pGraphics
, "UPtr", pPen
, "Float", x1
, "Float", y1
, "Float", x2
, "Float", y2)
}
Gdip_DrawLines(pGraphics, pPen, points)
{
points := StrSplit(points, "|")
pointF := Buffer(8*points.Length)
pointsLength := 0
for point in points {
coords := StrSplit(point, ",")
if (coords.Length != 2) {
if (coords.Length > 0) {
MsgBox("Skipping wrong points of length " coords.Length)
}
continue
}
NumPut("Float", coords[1], pointF, 8*(A_Index-1))
NumPut("Float", coords[2], pointF, (8*(A_Index-1))+4)
pointsLength += 1
}
return DllCall("gdiplus\GdipDrawLines", "UPtr", pGraphics, "UPtr", pPen, "UPtr", pointF.Ptr, "Int", pointsLength)
}
Gdip_FillRectangle(pGraphics, pBrush, x, y, w, h)
{
return DllCall("gdiplus\GdipFillRectangle"
, "UPtr", pGraphics
, "UPtr", pBrush
, "Float", x
, "Float", y
, "Float", w
, "Float", h)
}
Gdip_FillRoundedRectangle(pGraphics, pBrush, x, y, w, h, r)
{
Region := Gdip_GetClipRegion(pGraphics)
Gdip_SetClipRect(pGraphics, x-r, y-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x+w-r, y-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x-r, y+h-r, 2*r, 2*r, 4)
Gdip_SetClipRect(pGraphics, x+w-r, y+h-r, 2*r, 2*r, 4)
_E := Gdip_FillRectangle(pGraphics, pBrush, x, y, w, h)
Gdip_SetClipRegion(pGraphics, Region, 0)
Gdip_SetClipRect(pGraphics, x-(2*r), y+r, w+(4*r), h-(2*r), 4)
Gdip_SetClipRect(pGraphics, x+r, y-(2*r), w-(2*r), h+(4*r), 4)
Gdip_FillEllipse(pGraphics, pBrush, x, y, 2*r, 2*r)
Gdip_FillEllipse(pGraphics, pBrush, x+w-(2*r), y, 2*r, 2*r)
Gdip_FillEllipse(pGraphics, pBrush, x, y+h-(2*r), 2*r, 2*r)
Gdip_FillEllipse(pGraphics, pBrush, x+w-(2*r), y+h-(2*r), 2*r, 2*r)
Gdip_SetClipRegion(pGraphics, Region, 0)
Gdip_DeleteRegion(Region)
return _E
}
Gdip_FillPolygon(pGraphics, pBrush, Points, FillMode:=0)
{
Points := StrSplit(Points, "|")
PointsLength := Points.Length
PointF := Buffer(8*PointsLength)
For eachPoint, Point in Points
{
Coord := StrSplit(Point, ",")
NumPut("Float", Coord[1], PointF, 8*(A_Index-1))
NumPut("Float", Coord[2], PointF, (8*(A_Index-1))+4)
}
return DllCall("gdiplus\GdipFillPolygon", "UPtr", pGraphics, "UPtr", pBrush, "UPtr", PointF.Ptr, "Int", PointsLength, "Int", FillMode)
}
Gdip_FillPie(pGraphics, pBrush, x, y, w, h, StartAngle, SweepAngle)
{
return DllCall("gdiplus\GdipFillPie"
, "UPtr", pGraphics
, "UPtr", pBrush
, "Float", x
, "Float", y
, "Float", w
, "Float", h
, "Float", StartAngle
, "Float", SweepAngle)
}
Gdip_FillEllipse(pGraphics, pBrush, x, y, w, h)
{
return DllCall("gdiplus\GdipFillEllipse", "UPtr", pGraphics, "UPtr", pBrush, "Float", x, "Float", y, "Float", w, "Float", h)
}
Gdip_FillRegion(pGraphics, pBrush, Region)
{
return DllCall("gdiplus\GdipFillRegion", "UPtr", pGraphics, "UPtr", pBrush, "UPtr", Region)
}
Gdip_FillPath(pGraphics, pBrush, pPath)
{
return DllCall("gdiplus\GdipFillPath", "UPtr", pGraphics, "UPtr", pBrush, "UPtr", pPath)
}
Gdip_DrawImagePointsRect(pGraphics, pBitmap, Points, sx:="", sy:="", sw:="", sh:="", Matrix:=1)
{
Points := StrSplit(Points, "|")
PointsLength := Points.Length
PointF := Buffer(8*PointsLength)
For eachPoint, Point in Points
{
Coord := StrSplit(Point, ",")
NumPut("Float", Coord[1], PointF, 8*(A_Index-1))
NumPut("Float", Coord[2], PointF, (8*(A_Index-1))+4)
}
if !IsNumber(Matrix)
ImageAttr := Gdip_SetImageAttributesColorMatrix(Matrix)
else if (Matrix != 1)
ImageAttr := Gdip_SetImageAttributesColorMatrix("1|0|0|0|0|0|1|0|0|0|0|0|1|0|0|0|0|0|" Matrix "|0|0|0|0|0|1")
else
ImageAttr := 0
if (sx = "" && sy = "" && sw = "" && sh = "")
{
sx := 0, sy := 0
sw := Gdip_GetImageWidth(pBitmap)
sh := Gdip_GetImageHeight(pBitmap)
}
_E := DllCall("gdiplus\GdipDrawImagePointsRect"
, "UPtr", pGraphics
, "UPtr", pBitmap
, "UPtr", PointF.Ptr
, "Int", PointsLength
, "Float", sx
, "Float", sy
, "Float", sw
, "Float", sh
, "Int", 2
, "UPtr", ImageAttr
, "UPtr", 0
, "UPtr", 0)
if ImageAttr
Gdip_DisposeImageAttributes(ImageAttr)
return _E
}
Gdip_DrawImage(pGraphics, pBitmap, dx:="", dy:="", dw:="", dh:="", sx:="", sy:="", sw:="", sh:="", Matrix:=1)
{
if !IsNumber(Matrix)
ImageAttr := Gdip_SetImageAttributesColorMatrix(Matrix)
else if (Matrix != 1)
ImageAttr := Gdip_SetImageAttributesColorMatrix("1|0|0|0|0|0|1|0|0|0|0|0|1|0|0|0|0|0|" Matrix "|0|0|0|0|0|1")
else
ImageAttr := 0
if (sx = "" && sy = "" && sw = "" && sh = "")
{
if (dx = "" && dy = "" && dw = "" && dh = "")
{
sx := dx := 0, sy := dy := 0
sw := dw := Gdip_GetImageWidth(pBitmap)
sh := dh := Gdip_GetImageHeight(pBitmap)
}
else
{
sx := sy := 0
sw := Gdip_GetImageWidth(pBitmap)
sh := Gdip_GetImageHeight(pBitmap)
}
}
_E := DllCall("gdiplus\GdipDrawImageRectRect"
, "UPtr", pGraphics
, "UPtr", pBitmap
, "Float", dx
, "Float", dy
, "Float", dw
, "Float", dh
, "Float", sx
, "Float", sy
, "Float", sw
, "Float", sh
, "Int", 2
, "UPtr", ImageAttr
, "UPtr", 0
, "UPtr", 0)
if ImageAttr
Gdip_DisposeImageAttributes(ImageAttr)
return _E
}
Gdip_SetImageAttributesColorMatrix(Matrix)
{
ColourMatrix := Buffer(100, 0)
Matrix := RegExReplace(RegExReplace(Matrix, "^[^\d-\.]+([\d\.])", "$1", , 1), "[^\d-\.]+", "|")
Matrix := StrSplit(Matrix, "|")
loop 25 {
M := (Matrix[A_Index] != "") ? Matrix[A_Index] : Mod(A_Index-1, 6) ? 0 : 1
NumPut("Float", M, ColourMatrix, (A_Index-1)*4)
}
DllCall("gdiplus\GdipCreateImageAttributes", "UPtr*", &ImageAttr:=0)
DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "UPtr", ImageAttr, "Int", 1, "Int", 1, "UPtr", ColourMatrix.Ptr, "UPtr", 0, "Int", 0)
return ImageAttr
}
Gdip_GraphicsFromImage(pBitmap)
{
DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pBitmap, "UPtr*", &pGraphics:=0)
return pGraphics
}
Gdip_GraphicsFromHDC(hdc)
{
DllCall("gdiplus\GdipCreateFromHDC", "UPtr", hdc, "UPtr*", &pGraphics:=0)
return pGraphics
}
Gdip_GetDC(pGraphics)
{
DllCall("gdiplus\GdipGetDC", "UPtr", pGraphics, "UPtr*", &hdc:=0)
return hdc
}
Gdip_ReleaseDC(pGraphics, hdc)
{
return DllCall("gdiplus\GdipReleaseDC", "UPtr", pGraphics, "UPtr", hdc)
}
Gdip_GraphicsClear(pGraphics, ARGB:=0x00ffffff)
{
return DllCall("gdiplus\GdipGraphicsClear", "UPtr", pGraphics, "Int", ARGB)
}
Gdip_BlurBitmap(pBitmap, Blur)
{
if (Blur > 100 || Blur < 1) {
return -1
}
sWidth := Gdip_GetImageWidth(pBitmap), sHeight := Gdip_GetImageHeight(pBitmap)
dWidth := sWidth//Blur, dHeight := sHeight//Blur
pBitmap1 := Gdip_CreateBitmap(dWidth, dHeight)
G1 := Gdip_GraphicsFromImage(pBitmap1)
Gdip_SetInterpolationMode(G1, 7)
Gdip_DrawImage(G1, pBitmap, 0, 0, dWidth, dHeight, 0, 0, sWidth, sHeight)
Gdip_DeleteGraphics(G1)
pBitmap2 := Gdip_CreateBitmap(sWidth, sHeight)
G2 := Gdip_GraphicsFromImage(pBitmap2)
Gdip_SetInterpolationMode(G2, 7)
Gdip_DrawImage(G2, pBitmap1, 0, 0, sWidth, sHeight, 0, 0, dWidth, dHeight)
Gdip_DeleteGraphics(G2)
Gdip_DisposeImage(pBitmap1)
return pBitmap2
}
Gdip_SaveBitmapToFile(pBitmap, sOutput, Quality:=75)
{
_p := 0
SplitPath sOutput,,, &extension:=""
if (!RegExMatch(extension, "^(?i:BMP|DIB|RLE|JPG|JPEG|JPE|JFIF|GIF|TIF|TIFF|PNG)$")) {
return -1
}
extension := "." extension
DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", &nCount:=0, "uint*", &nSize:=0)
ci := Buffer(nSize)
DllCall("gdiplus\GdipGetImageEncoders", "UInt", nCount, "UInt", nSize, "UPtr", ci.Ptr)
if !(nCount && nSize) {
return -2
}
loop nCount {
address := NumGet(ci, (idx := (48+7*A_PtrSize)*(A_Index-1))+32+3*A_PtrSize, "UPtr")
sString := StrGet(address, "UTF-16")
if !InStr(sString, "*" extension)
continue
pCodec := ci.Ptr+idx
break
}
if !pCodec {
return -3
}
if (Quality != 75) {
Quality := (Quality < 0) ? 0 : (Quality > 100) ? 100 : Quality
if RegExMatch(extension, "^\.(?i:JPG|JPEG|JPE|JFIF)$") {
DllCall("gdiplus\GdipGetEncoderParameterListSize", "UPtr", pBitmap, "UPtr", pCodec, "uint*", &nSize)
EncoderParameters := Buffer(nSize, 0)
DllCall("gdiplus\GdipGetEncoderParameterList", "UPtr", pBitmap, "UPtr", pCodec, "UInt", nSize, "UPtr", EncoderParameters.Ptr)
nCount := NumGet(EncoderParameters, "UInt")
loop nCount
{
elem := (24+(A_PtrSize ? A_PtrSize : 4))*(A_Index-1) + 4 + (pad := A_PtrSize = 8 ? 4 : 0)
if (NumGet(EncoderParameters, elem+16, "UInt") = 1) && (NumGet(EncoderParameters, elem+20, "UInt") = 6)
{
_p := elem + EncoderParameters.Ptr - pad - 4
NumPut("UInt", Quality, NumGet(NumPut("UInt", 4, NumPut("UInt", 1, _p+0)+20), "UInt"))
break
}
}
}
}
_E := DllCall("gdiplus\GdipSaveImageToFile", "UPtr", pBitmap, "UPtr", StrPtr(sOutput), "UPtr", pCodec, "UInt", _p ? _p : 0)
return _E ? -5 : 0
}
Gdip_GetPixel(pBitmap, x, y)
{
DllCall("gdiplus\GdipBitmapGetPixel", "UPtr", pBitmap, "Int", x, "Int", y, "uint*", &ARGB:=0)
return ARGB
}
Gdip_SetPixel(pBitmap, x, y, ARGB)
{
return DllCall("gdiplus\GdipBitmapSetPixel", "UPtr", pBitmap, "Int", x, "Int", y, "Int", ARGB)
}
Gdip_GetImageWidth(pBitmap)
{
DllCall("gdiplus\GdipGetImageWidth", "UPtr", pBitmap, "uint*", &Width:=0)
return Width
}
Gdip_GetImageHeight(pBitmap)
{
DllCall("gdiplus\GdipGetImageHeight", "UPtr", pBitmap, "uint*", &Height:=0)
return Height
}
Gdip_GetImageDimensions(pBitmap, &Width, &Height)
{
DllCall("gdiplus\GdipGetImageWidth", "UPtr", pBitmap, "uint*", &Width:=0)
DllCall("gdiplus\GdipGetImageHeight", "UPtr", pBitmap, "uint*", &Height:=0)
}
Gdip_GetDimensions(pBitmap, &Width, &Height)
{
Gdip_GetImageDimensions(pBitmap, &Width, &Height)
}
Gdip_GetImagePixelFormat(pBitmap)
{
DllCall("gdiplus\GdipGetImagePixelFormat", "UPtr", pBitmap, "UPtr*", &_Format:=0)
return _Format
}
Gdip_GetDpiX(pGraphics)
{
DllCall("gdiplus\GdipGetDpiX", "UPtr", pGraphics, "float*", &dpix:=0)
return Round(dpix)
}
Gdip_GetDpiY(pGraphics)
{
DllCall("gdiplus\GdipGetDpiY", "UPtr", pGraphics, "float*", &dpiy:=0)
return Round(dpiy)
}
Gdip_GetImageHorizontalResolution(pBitmap)
{
DllCall("gdiplus\GdipGetImageHorizontalResolution", "UPtr", pBitmap, "float*", &dpix:=0)
return Round(dpix)
}
Gdip_GetImageVerticalResolution(pBitmap)
{
DllCall("gdiplus\GdipGetImageVerticalResolution", "UPtr", pBitmap, "float*", &dpiy:=0)
return Round(dpiy)
}
Gdip_BitmapSetResolution(pBitmap, dpix, dpiy)
{
return DllCall("gdiplus\GdipBitmapSetResolution", "UPtr", pBitmap, "Float", dpix, "Float", dpiy)
}
Gdip_CreateBitmapFromFile(sFile, IconNumber:=1, IconSize:="")
{
SplitPath sFile,,, &extension:=""
if RegExMatch(extension, "^(?i:exe|dll)$") {
Sizes := IconSize ? IconSize : 256 "|" 128 "|" 64 "|" 48 "|" 32 "|" 16
BufSize := 16 + (2*(A_PtrSize ? A_PtrSize : 4))
buf := Buffer(BufSize, 0)
hIcon := 0
for eachSize, Size in StrSplit( Sizes, "|" ) {
DllCall("PrivateExtractIcons", "str", sFile, "Int", IconNumber-1, "Int", Size, "Int", Size, "UPtr*", &hIcon, "UPtr*", 0, "UInt", 1, "UInt", 0)
if (!hIcon) {
continue
}
if !DllCall("GetIconInfo", "UPtr", hIcon, "UPtr", buf.Ptr) {
DestroyIcon(hIcon)
continue
}
hbmMask  := NumGet(buf, 12 + ((A_PtrSize ? A_PtrSize : 4) - 4))
hbmColor := NumGet(buf, 12 + ((A_PtrSize ? A_PtrSize : 4) - 4) + (A_PtrSize ? A_PtrSize : 4))
if !(hbmColor && DllCall("GetObject", "UPtr", hbmColor, "Int", BufSize, "UPtr", buf.Ptr))
{
DestroyIcon(hIcon)
continue
}
break
}
if (!hIcon) {
return -1
}
Width := NumGet(buf, 4, "Int"), Height := NumGet(buf, 8, "Int")
hbm := CreateDIBSection(Width, -Height), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
if !DllCall("DrawIconEx", "UPtr", hdc, "Int", 0, "Int", 0, "UPtr", hIcon, "UInt", Width, "UInt", Height, "UInt", 0, "UPtr", 0, "UInt", 3) {
DestroyIcon(hIcon)
return -2
}
dib := Buffer(104)
DllCall("GetObject", "UPtr", hbm, "Int", A_PtrSize = 8 ? 104 : 84, "UPtr", dib.Ptr)
Stride := NumGet(dib, 12, "Int"), Bits := NumGet(dib, 20 + (A_PtrSize = 8 ? 4 : 0))
DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Width, "Int", Height, "Int", Stride, "Int", 0x26200A, "UPtr", Bits, "UPtr*", &pBitmapOld:=0)
pBitmap := Gdip_CreateBitmap(Width, Height)
_G := Gdip_GraphicsFromImage(pBitmap)
, Gdip_DrawImage(_G, pBitmapOld, 0, 0, Width, Height, 0, 0, Width, Height)
SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
Gdip_DeleteGraphics(_G), Gdip_DisposeImage(pBitmapOld)
DestroyIcon(hIcon)
} else {
DllCall("gdiplus\GdipCreateBitmapFromFile", "UPtr", StrPtr(sFile), "UPtr*", &pBitmap:=0)
}
return pBitmap
}
Gdip_CreateBitmapFromHBITMAP(hBitmap, Palette:=0)
{
DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "UPtr", hBitmap, "UPtr", Palette, "UPtr*", &pBitmap:=0)
return pBitmap
}
Gdip_CreateHBITMAPFromBitmap(pBitmap, Background:=0xffffffff)
{
DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", pBitmap, "UPtr*", &hbm:=0, "Int", Background)
return hbm
}
Gdip_CreateARGBBitmapFromHBITMAP(&hBitmap) {
dib := Buffer(76+2*(A_PtrSize=8?4:0)+2*A_PtrSize)
DllCall("GetObject"
,    "ptr", hBitmap
,    "Int", dib.Size
,    "ptr", dib.Ptr)
, width  := NumGet(dib, 4, "UInt")
, height := NumGet(dib, 8, "UInt")
, bpp    := NumGet(dib, 18, "ushort")
if (bpp != 32) {
DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", &pBitmap:=0)
return pBitmap
}
hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
obm := DllCall("SelectObject", "ptr", hdc, "ptr", hBitmap, "ptr")
cdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
bi := Buffer(40, 0)
NumPut(
"UInt", 	40,
"UInt", 	width,
"Int", 		height,
"ushort",	1,
"ushort",	32,
bi)
hbm := DllCall("CreateDIBSection", "ptr", cdc, "ptr", bi.Ptr, "UInt", 0
, "ptr*", &pBits:=0
, "ptr", 0, "UInt", 0, "ptr")
ob2 := DllCall("SelectObject", "ptr", cdc, "ptr", hbm, "ptr")
DllCall("gdiplus\GdipCreateBitmapFromScan0"
, "Int", width, "Int", height, "Int", 0, "Int", 0x26200A, "ptr", 0, "ptr*", &pBitmap:=0)
Rect := Buffer(16, 0)
NumPut(
"UInt",   width,
"UInt",  height,
Rect, 8)
BitmapData := Buffer(16+2*A_PtrSize, 0)
NumPut(
"UInt", width,
"UInt", height,
"Int",  4 * width,
"Int",  0xE200B,
"ptr",  pBits,
BitmapData)
DllCall("gdiplus\GdipBitmapLockBits"
,    "ptr", pBitmap
,    "ptr", Rect.Ptr
,   "UInt", 6
,    "Int", 0xE200B
,    "ptr", BitmapData.Ptr)
DllCall("gdi32\BitBlt"
, "ptr", cdc, "Int", 0, "Int", 0, "Int", width, "Int", height
, "ptr", hdc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", BitmapData.Ptr)
DllCall("SelectObject", "ptr", cdc, "ptr", ob2)
DllCall("DeleteObject", "ptr", hbm)
DllCall("DeleteDC",     "ptr", cdc)
DllCall("SelectObject", "ptr", hdc, "ptr", obm)
DllCall("DeleteDC",     "ptr", hdc)
return pBitmap
}
Gdip_CreateARGBHBITMAPFromBitmap(&pBitmap) {
DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &width:=0)
DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &height:=0)
hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
bi := Buffer(40, 0)
NumPut(
"UInt",     40,
"UInt",    	width,
"Int",  	-height,
"ushort",   1,
"ushort",   32,
bi)
hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi.Ptr, "UInt", 0, "ptr*", &pBits:=0, "ptr", 0, "UInt", 0, "ptr")
obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
Rect := Buffer(16, 0)
NumPut(
"UInt",   width,
"UInt",  height,
Rect, 8)
BitmapData := Buffer(16+2*A_PtrSize, 0)
NumPut(
"UInt",     width,
"UInt",    height,
"Int",  4 * width,
"Int",    0xE200B,
"ptr",      pBits,
BitmapData)
DllCall("gdiplus\GdipBitmapLockBits"
,    "ptr", pBitmap
,    "ptr", Rect.Ptr
,   "UInt", 5
,    "Int", 0xE200B
,    "ptr", BitmapData.Ptr)
DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", BitmapData.Ptr)
DllCall("SelectObject", "ptr", hdc, "ptr", obm)
DllCall("DeleteDC",     "ptr", hdc)
return hbm
}
Gdip_CreateBitmapFromHICON(hIcon)
{
DllCall("gdiplus\GdipCreateBitmapFromHICON", "UPtr", hIcon, "UPtr*", &pBitmap:=0)
return pBitmap
}
Gdip_CreateHICONFromBitmap(pBitmap)
{
DllCall("gdiplus\GdipCreateHICONFromBitmap", "UPtr", pBitmap, "UPtr*", &hIcon:=0)
return hIcon
}
Gdip_CreateBitmap(Width, Height, Format:=0x26200A)
{
DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Width, "Int", Height, "Int", 0, "Int", Format, "UPtr", 0, "UPtr*", &pBitmap:=0)
return pBitmap
}
Gdip_CreateBitmapFromClipboard()
{
if !DllCall("IsClipboardFormatAvailable", "UInt", 8) {
return -2
}
if !DllCall("OpenClipboard", "UPtr", 0) {
return -1
}
hBitmap := DllCall("GetClipboardData", "UInt", 2, "UPtr")
if !DllCall("CloseClipboard") {
return -5
}
if !hBitmap {
return -3
}
pBitmap := Gdip_CreateBitmapFromHBITMAP(hBitmap)
if (!pBitmap) {
return -4
}
DeleteObject(hBitmap)
return pBitmap
}
Gdip_SetBitmapToClipboard(pBitmap)
{
off1 := A_PtrSize = 8 ? 52 : 44, off2 := A_PtrSize = 8 ? 32 : 24
hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
oi := Buffer(A_PtrSize = 8 ? 104 : 84, 0)
DllCall("GetObject", "UPtr", hBitmap, "Int", oi.Size, "UPtr", oi.Ptr)
hdib := DllCall("GlobalAlloc", "UInt", 2, "UPtr", 40+NumGet(oi, off1, "UInt"), "UPtr")
pdib := DllCall("GlobalLock", "UPtr", hdib, "UPtr")
DllCall("RtlMoveMemory", "UPtr", pdib, "UPtr", oi.Ptr+off2, "UPtr", 40)
DllCall("RtlMoveMemory", "UPtr", pdib+40, "UPtr", NumGet(oi, off2 - (A_PtrSize ? A_PtrSize : 4), "UPtr"), "UPtr", NumGet(oi, off1, "UInt"))
DllCall("GlobalUnlock", "UPtr", hdib)
DllCall("DeleteObject", "UPtr", hBitmap)
DllCall("OpenClipboard", "UPtr", 0)
DllCall("EmptyClipboard")
DllCall("SetClipboardData", "UInt", 8, "UPtr", hdib)
DllCall("CloseClipboard")
}
Gdip_CloneBitmapArea(pBitmap, x, y, w, h, Format:=0x26200A)
{
DllCall("gdiplus\GdipCloneBitmapArea"
, "Float", x
, "Float", y
, "Float", w
, "Float", h
, "Int", Format
, "UPtr", pBitmap
, "UPtr*", &pBitmapDest:=0)
return pBitmapDest
}
Gdip_CreatePen(ARGB, w)
{
DllCall("gdiplus\GdipCreatePen1", "UInt", ARGB, "Float", w, "Int", 2, "UPtr*", &pPen:=0)
return pPen
}
Gdip_CreatePenFromBrush(pBrush, w)
{
DllCall("gdiplus\GdipCreatePen2", "UPtr", pBrush, "Float", w, "Int", 2, "UPtr*", &pPen:=0)
return pPen
}
Gdip_BrushCreateSolid(ARGB:=0xff000000)
{
DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB, "UPtr*", &pBrush:=0)
return pBrush
}
Gdip_BrushCreateHatch(ARGBfront, ARGBback, HatchStyle:=0)
{
DllCall("gdiplus\GdipCreateHatchBrush", "Int", HatchStyle, "UInt", ARGBfront, "UInt", ARGBback, "UPtr*", &pBrush:=0)
return pBrush
}
Gdip_CreateTextureBrush(pBitmap, WrapMode:=1, x:=0, y:=0, w:="", h:="")
{
if !(w && h) {
DllCall("gdiplus\GdipCreateTexture", "UPtr", pBitmap, "Int", WrapMode, "UPtr*", &pBrush:=0)
} else {
DllCall("gdiplus\GdipCreateTexture2", "UPtr", pBitmap, "Int", WrapMode, "Float", x, "Float", y, "Float", w, "Float", h, "UPtr*", &pBrush:=0)
}
return pBrush
}
Gdip_CreateLineBrush(x1, y1, x2, y2, ARGB1, ARGB2, WrapMode:=1)
{
CreatePointF(&PointF1:="", x1, y1), CreatePointF(&PointF2:="", x2, y2)
DllCall("gdiplus\GdipCreateLineBrush", "UPtr", PointF1.Ptr, "UPtr", PointF2.Ptr, "UInt", ARGB1, "UInt", ARGB2, "Int", WrapMode, "UPtr*", &LGpBrush:=0)
return LGpBrush
}
Gdip_CreateLineBrushFromRect(x, y, w, h, ARGB1, ARGB2, LinearGradientMode:=1, WrapMode:=1)
{
CreateRectF(&RectF:="", x, y, w, h)
DllCall("gdiplus\GdipCreateLineBrushFromRect", "UPtr", RectF.Ptr, "Int", ARGB1, "Int", ARGB2, "Int", LinearGradientMode, "Int", WrapMode, "UPtr*", &LGpBrush:=0)
return LGpBrush
}
Gdip_CloneBrush(pBrush)
{
DllCall("gdiplus\GdipCloneBrush", "UPtr", pBrush, "UPtr*", &pBrushClone:=0)
return pBrushClone
}
Gdip_DeletePen(pPen)
{
return DllCall("gdiplus\GdipDeletePen", "UPtr", pPen)
}
Gdip_DeleteBrush(pBrush)
{
return DllCall("gdiplus\GdipDeleteBrush", "UPtr", pBrush)
}
Gdip_DisposeImage(pBitmap)
{
return DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)
}
Gdip_DeleteGraphics(pGraphics)
{
return DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pGraphics)
}
Gdip_DisposeImageAttributes(ImageAttr)
{
return DllCall("gdiplus\GdipDisposeImageAttributes", "UPtr", ImageAttr)
}
Gdip_DeleteFont(hFont)
{
return DllCall("gdiplus\GdipDeleteFont", "UPtr", hFont)
}
Gdip_DeleteStringFormat(hFormat)
{
return DllCall("gdiplus\GdipDeleteStringFormat", "UPtr", hFormat)
}
Gdip_DeleteFontFamily(hFamily)
{
return DllCall("gdiplus\GdipDeleteFontFamily", "UPtr", hFamily)
}
Gdip_DeleteMatrix(Matrix)
{
return DllCall("gdiplus\GdipDeleteMatrix", "UPtr", Matrix)
}
Gdip_TextToGraphics(pGraphics, Text, Options, Font:="Arial", Width:="", Height:="", Measure:=0)
{
IWidth := Width
IHeight := Height
PassBrush := 0
pattern_opts := "i)"
RegExMatch(Options, pattern_opts "X([\-\d\.]+)(p*)", &xpos:="")
RegExMatch(Options, pattern_opts "Y([\-\d\.]+)(p*)", &ypos:="")
RegExMatch(Options, pattern_opts "W([\-\d\.]+)(p*)", &Width:="")
RegExMatch(Options, pattern_opts "H([\-\d\.]+)(p*)", &Height:="")
RegExMatch(Options, pattern_opts "C(?!(entre|enter))([a-f\d]+)", &Colour:="")
RegExMatch(Options, pattern_opts "Top|Up|Bottom|Down|vCentre|vCenter", &vPos:="")
RegExMatch(Options, pattern_opts "NoWrap", &NoWrap:="")
RegExMatch(Options, pattern_opts "R(\d)", &Rendering:="")
RegExMatch(Options, pattern_opts "S(\d+)(p*)", &Size:="")
if Colour && IsInteger(Colour[2]) && !Gdip_DeleteBrush(Gdip_CloneBrush(Colour[2])) {
PassBrush := 1, pBrush := Colour[2]
}
if !(IWidth && IHeight) && ((xpos && xpos[2]) || (ypos && ypos[2]) || (Width && Width[2]) || (Height && Height[2]) || (Size && Size[2])) {
return -1
}
Style := 0
Styles := "Regular|Bold|Italic|BoldItalic|Underline|Strikeout"
for eachStyle, valStyle in StrSplit( Styles, "|" ) {
if RegExMatch(Options, "\b" valStyle)
Style |= (valStyle != "StrikeOut") ? (A_Index-1) : 8
}
Align := 0
Alignments := "Near|Left|Centre|Center|Far|Right"
for eachAlignment, valAlignment in StrSplit( Alignments, "|" ) {
if RegExMatch(Options, "\b" valAlignment) {
Align |= A_Index*10//21
}
}
xpos := (xpos && (xpos[1] != "")) ? xpos[2] ? IWidth*(xpos[1]/100) : xpos[1] : 0
ypos := (ypos && (ypos[1] != "")) ? ypos[2] ? IHeight*(ypos[1]/100) : ypos[1] : 0
Width := (Width && Width[1]) ? Width[2] ? IWidth*(Width[1]/100) : Width[1] : IWidth
Height := (Height && Height[1]) ? Height[2] ? IHeight*(Height[1]/100) : Height[1] : IHeight
if !PassBrush {
Colour := "0x" (Colour && Colour[2] ? Colour[2] : "ff000000")
}
Rendering := (Rendering && (Rendering[1] >= 0) && (Rendering[1] <= 5)) ? Rendering[1] : 4
Size := (Size && (Size[1] > 0)) ? Size[2] ? IHeight*(Size[1]/100) : Size[1] : 12
hFamily := Gdip_FontFamilyCreate(Font)
hFont := Gdip_FontCreate(hFamily, Size, Style)
FormatStyle := NoWrap ? 0x4000 | 0x1000 : 0x4000
hFormat := Gdip_StringFormatCreate(FormatStyle)
pBrush := PassBrush ? pBrush : Gdip_BrushCreateSolid(Colour)
if !(hFamily && hFont && hFormat && pBrush && pGraphics) {
return !pGraphics ? -2 : !hFamily ? -3 : !hFont ? -4 : !hFormat ? -5 : !pBrush ? -6 : 0
}
CreateRectF(&RC:="", xpos, ypos, Width, Height)
Gdip_SetStringFormatAlign(hFormat, Align)
Gdip_SetTextRenderingHint(pGraphics, Rendering)
ReturnRC := Gdip_MeasureString(pGraphics, Text, hFont, hFormat, &RC)
if vPos {
ReturnRC := StrSplit(ReturnRC, "|")
if (vPos[0] = "vCentre") || (vPos[0] = "vCenter")
ypos += (Height-ReturnRC[4])//2
else if (vPos[0] = "Top") || (vPos[0] = "Up")
ypos := 0
else if (vPos[0] = "Bottom") || (vPos[0] = "Down")
ypos := Height-ReturnRC[4]
CreateRectF(&RC, xpos, ypos, Width, ReturnRC[4])
ReturnRC := Gdip_MeasureString(pGraphics, Text, hFont, hFormat, &RC)
}
if !Measure {
ReturnRC := Gdip_DrawString(pGraphics, Text, hFont, hFormat, pBrush, &RC)
}
if !PassBrush {
Gdip_DeleteBrush(pBrush)
}
Gdip_DeleteStringFormat(hFormat)
Gdip_DeleteFont(hFont)
Gdip_DeleteFontFamily(hFamily)
return ReturnRC
}
Gdip_DrawString(pGraphics, sString, hFont, hFormat, pBrush, &RectF)
{
return DllCall("gdiplus\GdipDrawString"
, "UPtr", pGraphics
, "UPtr", StrPtr(sString)
, "Int", -1
, "UPtr", hFont
, "UPtr", RectF.Ptr
, "UPtr", hFormat
, "UPtr", pBrush)
}
Gdip_MeasureString(pGraphics, sString, hFont, hFormat, &RectF)
{
RC := Buffer(16)
DllCall("gdiplus\GdipMeasureString"
, "UPtr", pGraphics
, "UPtr", StrPtr(sString)
, "Int", -1
, "UPtr", hFont
, "UPtr", RectF.Ptr
, "UPtr", hFormat
, "UPtr", RC.Ptr
, "uint*", &Chars:=0
, "uint*", &Lines:=0)
return RC.Ptr ? NumGet(RC, 0, "Float") "|" NumGet(RC, 4, "Float") "|" NumGet(RC, 8, "Float") "|" NumGet(RC, 12, "Float") "|" Chars "|" Lines : 0
}
Gdip_SetStringFormatAlign(hFormat, Align)
{
return DllCall("gdiplus\GdipSetStringFormatAlign", "UPtr", hFormat, "Int", Align)
}
Gdip_StringFormatCreate(Format:=0, Lang:=0)
{
DllCall("gdiplus\GdipCreateStringFormat", "Int", Format, "Int", Lang, "UPtr*", &hFormat:=0)
return hFormat
}
Gdip_FontCreate(hFamily, Size, Style:=0)
{
DllCall("gdiplus\GdipCreateFont", "UPtr", hFamily, "Float", Size, "Int", Style, "Int", 0, "UPtr*", &hFont:=0)
return hFont
}
Gdip_FontFamilyCreate(Font)
{
DllCall("gdiplus\GdipCreateFontFamilyFromName"
, "UPtr", StrPtr(Font)
, "UInt", 0
, "UPtr*", &hFamily:=0)
return hFamily
}
Gdip_CreateAffineMatrix(m11, m12, m21, m22, x, y)
{
DllCall("gdiplus\GdipCreateMatrix2", "Float", m11, "Float", m12, "Float", m21, "Float", m22, "Float", x, "Float", y, "UPtr*", &Matrix:=0)
return Matrix
}
Gdip_CreateMatrix()
{
DllCall("gdiplus\GdipCreateMatrix", "UPtr*", &Matrix:=0)
return Matrix
}
Gdip_CreatePath(BrushMode:=0)
{
DllCall("gdiplus\GdipCreatePath", "Int", BrushMode, "UPtr*", &pPath:=0)
return pPath
}
Gdip_AddPathEllipse(pPath, x, y, w, h)
{
return DllCall("gdiplus\GdipAddPathEllipse", "UPtr", pPath, "Float", x, "Float", y, "Float", w, "Float", h)
}
Gdip_AddPathPolygon(pPath, Points)
{
Points := StrSplit(Points, "|")
PointsLength := Points.Length
PointF := Buffer(8*PointsLength)
for eachPoint, Point in Points
{
Coord := StrSplit(Point, ",")
NumPut("Float", Coord[1], PointF, 8*(A_Index-1))
NumPut("Float", Coord[2], PointF, (8*(A_Index-1))+4)
}
return DllCall("gdiplus\GdipAddPathPolygon", "UPtr", pPath, "UPtr", PointF.Ptr, "Int", PointsLength)
}
Gdip_DeletePath(pPath)
{
return DllCall("gdiplus\GdipDeletePath", "UPtr", pPath)
}
Gdip_SetTextRenderingHint(pGraphics, RenderingHint)
{
return DllCall("gdiplus\GdipSetTextRenderingHint", "UPtr", pGraphics, "Int", RenderingHint)
}
Gdip_SetInterpolationMode(pGraphics, InterpolationMode)
{
return DllCall("gdiplus\GdipSetInterpolationMode", "UPtr", pGraphics, "Int", InterpolationMode)
}
Gdip_SetSmoothingMode(pGraphics, SmoothingMode)
{
return DllCall("gdiplus\GdipSetSmoothingMode", "UPtr", pGraphics, "Int", SmoothingMode)
}
Gdip_SetCompositingMode(pGraphics, CompositingMode:=0)
{
return DllCall("gdiplus\GdipSetCompositingMode", "UPtr", pGraphics, "Int", CompositingMode)
}
Gdip_Startup()
{
if (!DllCall("LoadLibrary", "str", "gdiplus", "UPtr")) {
throw Error("Could not load GDI+ library")
}
si := Buffer(A_PtrSize = 4 ? 20:32, 0)
NumPut("uint", 0x2, si)
NumPut("uint", 0x4, si, A_PtrSize = 4 ? 16:24)
DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken:=0, "Ptr", si, "UPtr", 0)
if (!pToken) {
throw Error("Gdiplus failed to start. Please ensure you have gdiplus on your system")
}
return pToken
}
Gdip_Shutdown(pToken)
{
DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
hModule := DllCall("GetModuleHandle", "str", "gdiplus", "UPtr")
if (!hModule) {
throw Error("GDI+ library was unloaded before shutdown")
}
if (!DllCall("FreeLibrary", "UPtr", hModule)) {
throw Error("Could not free GDI+ library")
}
return 0
}
Gdip_RotateWorldTransform(pGraphics, Angle, MatrixOrder:=0)
{
return DllCall("gdiplus\GdipRotateWorldTransform", "UPtr", pGraphics, "Float", Angle, "Int", MatrixOrder)
}
Gdip_ScaleWorldTransform(pGraphics, x, y, MatrixOrder:=0)
{
return DllCall("gdiplus\GdipScaleWorldTransform", "UPtr", pGraphics, "Float", x, "Float", y, "Int", MatrixOrder)
}
Gdip_TranslateWorldTransform(pGraphics, x, y, MatrixOrder:=0)
{
return DllCall("gdiplus\GdipTranslateWorldTransform", "UPtr", pGraphics, "Float", x, "Float", y, "Int", MatrixOrder)
}
Gdip_ResetWorldTransform(pGraphics)
{
return DllCall("gdiplus\GdipResetWorldTransform", "UPtr", pGraphics)
}
Gdip_GetRotatedTranslation(Width, Height, Angle, &xTranslation, &yTranslation)
{
pi := 3.14159, TAngle := Angle*(pi/180)
Bound := (Angle >= 0) ? Mod(Angle, 360) : 360-Mod(-Angle, -360)
if ((Bound >= 0) && (Bound <= 90)) {
xTranslation := Height*Sin(TAngle), yTranslation := 0
} else if ((Bound > 90) && (Bound <= 180)) {
xTranslation := (Height*Sin(TAngle))-(Width*Cos(TAngle)), yTranslation := -Height*Cos(TAngle)
} else if ((Bound > 180) && (Bound <= 270)) {
xTranslation := -(Width*Cos(TAngle)), yTranslation := -(Height*Cos(TAngle))-(Width*Sin(TAngle))
} else if ((Bound > 270) && (Bound <= 360)) {
xTranslation := 0, yTranslation := -Width*Sin(TAngle)
}
}
Gdip_GetRotatedDimensions(Width, Height, Angle, &RWidth, &RHeight)
{
pi := 3.14159, TAngle := Angle*(pi/180)
if !(Width && Height) {
return -1
}
RWidth := Ceil(Abs(Width*Cos(TAngle))+Abs(Height*Sin(TAngle)))
RHeight := Ceil(Abs(Width*Sin(TAngle))+Abs(Height*Cos(Tangle)))
}
Gdip_ImageRotateFlip(pBitmap, RotateFlipType:=1)
{
return DllCall("gdiplus\GdipImageRotateFlip", "UPtr", pBitmap, "Int", RotateFlipType)
}
Gdip_SetClipRect(pGraphics, x, y, w, h, CombineMode:=0)
{
return DllCall("gdiplus\GdipSetClipRect",  "UPtr", pGraphics, "Float", x, "Float", y, "Float", w, "Float", h, "Int", CombineMode)
}
Gdip_SetClipPath(pGraphics, pPath, CombineMode:=0)
{
return DllCall("gdiplus\GdipSetClipPath", "UPtr", pGraphics, "UPtr", pPath, "Int", CombineMode)
}
Gdip_ResetClip(pGraphics)
{
return DllCall("gdiplus\GdipResetClip", "UPtr", pGraphics)
}
Gdip_GetClipRegion(pGraphics)
{
Region := Gdip_CreateRegion()
DllCall("gdiplus\GdipGetClip", "UPtr", pGraphics, "UInt", Region)
return Region
}
Gdip_SetClipRegion(pGraphics, Region, CombineMode:=0)
{
return DllCall("gdiplus\GdipSetClipRegion", "UPtr", pGraphics, "UPtr", Region, "Int", CombineMode)
}
Gdip_CreateRegion()
{
DllCall("gdiplus\GdipCreateRegion", "UInt*", &Region:=0)
return Region
}
Gdip_DeleteRegion(Region)
{
return DllCall("gdiplus\GdipDeleteRegion", "UPtr", Region)
}
Gdip_LockBits(pBitmap, x, y, w, h, &Stride, &Scan0, &BitmapData, LockMode := 3, PixelFormat := 0x26200a)
{
CreateRect(&_Rect:="", x, y, w, h)
BitmapData := Buffer(16+2*(A_PtrSize ? A_PtrSize : 4), 0)
_E := DllCall("Gdiplus\GdipBitmapLockBits", "UPtr", pBitmap, "UPtr", _Rect.Ptr, "UInt", LockMode, "Int", PixelFormat, "UPtr", BitmapData.Ptr)
Stride := NumGet(BitmapData, 8, "Int")
Scan0 := NumGet(BitmapData, 16, "UPtr")
return _E
}
Gdip_UnlockBits(pBitmap, &BitmapData)
{
return DllCall("Gdiplus\GdipBitmapUnlockBits", "UPtr", pBitmap, "UPtr", BitmapData.Ptr)
}
Gdip_SetLockBitPixel(ARGB, Scan0, x, y, Stride)
{
Numput("UInt", ARGB, Scan0+0, (x*4)+(y*Stride))
}
Gdip_GetLockBitPixel(Scan0, x, y, Stride)
{
return NumGet(Scan0+0, (x*4)+(y*Stride), "UInt")
}
Gdip_PixelateBitmap(pBitmap, &pBitmapOut, BlockSize)
{
static PixelateBitmap := ""
if (!PixelateBitmap)
{
if A_PtrSize != 8
MCode_PixelateBitmap := "
		(LTrim Join
		558BEC83EC3C8B4514538B5D1C99F7FB56578BC88955EC894DD885C90F8E830200008B451099F7FB8365DC008365E000894DC88955F08945E833FF897DD4
		397DE80F8E160100008BCB0FAFCB894DCC33C08945F88945FC89451C8945143BD87E608B45088D50028BC82BCA8BF02BF2418945F48B45E02955F4894DC4
		8D0CB80FAFCB03CA895DD08BD1895DE40FB64416030145140FB60201451C8B45C40FB604100145FC8B45F40FB604020145F883C204FF4DE475D6034D18FF
		4DD075C98B4DCC8B451499F7F98945148B451C99F7F989451C8B45FC99F7F98945FC8B45F899F7F98945F885DB7E648B450C8D50028BC82BCA83C103894D
		C48BC82BCA41894DF48B4DD48945E48B45E02955E48D0C880FAFCB03CA895DD08BD18BF38A45148B7DC48804178A451C8B7DF488028A45FC8804178A45F8
		8B7DE488043A83C2044E75DA034D18FF4DD075CE8B4DCC8B7DD447897DD43B7DE80F8CF2FEFFFF837DF0000F842C01000033C08945F88945FC89451C8945
		148945E43BD87E65837DF0007E578B4DDC034DE48B75E80FAF4D180FAFF38B45088D500203CA8D0CB18BF08BF88945F48B45F02BF22BFA2955F48945CC0F
		B6440E030145140FB60101451C0FB6440F010145FC8B45F40FB604010145F883C104FF4DCC75D8FF45E4395DE47C9B8B4DF00FAFCB85C9740B8B451499F7
		F9894514EB048365140033F63BCE740B8B451C99F7F989451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB
		038975F88975E43BDE7E5A837DF0007E4C8B4DDC034DE48B75E80FAF4D180FAFF38B450C8D500203CA8D0CB18BF08BF82BF22BFA2BC28B55F08955CC8A55
		1488540E038A551C88118A55FC88540F018A55F888140183C104FF4DCC75DFFF45E4395DE47CA68B45180145E0015DDCFF4DC80F8594FDFFFF8B451099F7
		FB8955F08945E885C00F8E450100008B45EC0FAFC38365DC008945D48B45E88945CC33C08945F88945FC89451C8945148945103945EC7E6085DB7E518B4D
		D88B45080FAFCB034D108D50020FAF4D18034DDC8BF08BF88945F403CA2BF22BFA2955F4895DC80FB6440E030145140FB60101451C0FB6440F010145FC8B
		45F40FB604080145F883C104FF4DC875D8FF45108B45103B45EC7CA08B4DD485C9740B8B451499F7F9894514EB048365140033F63BCE740B8B451C99F7F9
		89451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB038975F88975103975EC7E5585DB7E468B4DD88B450C
		0FAFCB034D108D50020FAF4D18034DDC8BF08BF803CA2BF22BFA2BC2895DC88A551488540E038A551C88118A55FC88540F018A55F888140183C104FF4DC8
		75DFFF45108B45103B45EC7CAB8BC3C1E0020145DCFF4DCC0F85CEFEFFFF8B4DEC33C08945F88945FC89451C8945148945103BC87E6C3945F07E5C8B4DD8
		8B75E80FAFCB034D100FAFF30FAF4D188B45088D500203CA8D0CB18BF08BF88945F48B45F02BF22BFA2955F48945C80FB6440E030145140FB60101451C0F
		B6440F010145FC8B45F40FB604010145F883C104FF4DC875D833C0FF45108B4DEC394D107C940FAF4DF03BC874068B451499F7F933F68945143BCE740B8B
		451C99F7F989451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB038975F88975083975EC7E63EB0233F639
		75F07E4F8B4DD88B75E80FAFCB034D080FAFF30FAF4D188B450C8D500203CA8D0CB18BF08BF82BF22BFA2BC28B55F08955108A551488540E038A551C8811
		8A55FC88540F018A55F888140883C104FF4D1075DFFF45088B45083B45EC7C9F5F5E33C05BC9C21800
)"
else
MCode_PixelateBitmap := "
		(LTrim Join
		4489442418488954241048894C24085355565741544155415641574883EC28418BC1448B8C24980000004C8BDA99488BD941F7F9448BD0448BFA8954240C
		448994248800000085C00F8E9D020000418BC04533E4458BF299448924244C8954241041F7F933C9898C24980000008BEA89542404448BE889442408EB05
		4C8B5C24784585ED0F8E1A010000458BF1418BFD48897C2418450FAFF14533D233F633ED4533E44533ED4585C97E5B4C63BC2490000000418D040A410FAF
		C148984C8D441802498BD9498BD04D8BD90FB642010FB64AFF4403E80FB60203E90FB64AFE4883C2044403E003F149FFCB75DE4D03C748FFCB75D0488B7C
		24188B8C24980000004C8B5C2478418BC59941F7FE448BE8418BC49941F7FE448BE08BC59941F7FE8BE88BC69941F7FE8BF04585C97E4048639C24900000
		004103CA4D8BC1410FAFC94863C94A8D541902488BCA498BC144886901448821408869FF408871FE4883C10448FFC875E84803D349FFC875DA8B8C249800
		0000488B5C24704C8B5C24784183C20448FFCF48897C24180F850AFFFFFF8B6C2404448B2424448B6C24084C8B74241085ED0F840A01000033FF33DB4533
		DB4533D24533C04585C97E53488B74247085ED7E42438D0C04418BC50FAF8C2490000000410FAFC18D04814863C8488D5431028BCD0FB642014403D00FB6
		024883C2044403D80FB642FB03D80FB642FA03F848FFC975DE41FFC0453BC17CB28BCD410FAFC985C9740A418BC299F7F98BF0EB0233F685C9740B418BC3
		99F7F9448BD8EB034533DB85C9740A8BC399F7F9448BD0EB034533D285C9740A8BC799F7F9448BC0EB034533C033D24585C97E4D4C8B74247885ED7E3841
		8D0C14418BC50FAF8C2490000000410FAFC18D04814863C84A8D4431028BCD40887001448818448850FF448840FE4883C00448FFC975E8FFC2413BD17CBD
		4C8B7424108B8C2498000000038C2490000000488B5C24704503E149FFCE44892424898C24980000004C897424100F859EFDFFFF448B7C240C448B842480
		000000418BC09941F7F98BE8448BEA89942498000000896C240C85C00F8E3B010000448BAC2488000000418BCF448BF5410FAFC9898C248000000033FF33
		ED33F64533DB4533D24533C04585FF7E524585C97E40418BC5410FAFC14103C00FAF84249000000003C74898488D541802498BD90FB642014403D00FB602
		4883C2044403D80FB642FB03F00FB642FA03E848FFCB75DE488B5C247041FFC0453BC77CAE85C9740B418BC299F7F9448BE0EB034533E485C9740A418BC3
		99F7F98BD8EB0233DB85C9740A8BC699F7F9448BD8EB034533DB85C9740A8BC599F7F9448BD0EB034533D24533C04585FF7E4E488B4C24784585C97E3541
		8BC5410FAFC14103C00FAF84249000000003C74898488D540802498BC144886201881A44885AFF448852FE4883C20448FFC875E941FFC0453BC77CBE8B8C
		2480000000488B5C2470418BC1C1E00203F849FFCE0F85ECFEFFFF448BAC24980000008B6C240C448BA4248800000033FF33DB4533DB4533D24533C04585
		FF7E5A488B7424704585ED7E48418BCC8BC5410FAFC94103C80FAF8C2490000000410FAFC18D04814863C8488D543102418BCD0FB642014403D00FB60248
		83C2044403D80FB642FB03D80FB642FA03F848FFC975DE41FFC0453BC77CAB418BCF410FAFCD85C9740A418BC299F7F98BF0EB0233F685C9740B418BC399
		F7F9448BD8EB034533DB85C9740A8BC399F7F9448BD0EB034533D285C9740A8BC799F7F9448BC0EB034533C033D24585FF7E4E4585ED7E42418BCC8BC541
		0FAFC903CA0FAF8C2490000000410FAFC18D04814863C8488B442478488D440102418BCD40887001448818448850FF448840FE4883C00448FFC975E8FFC2
		413BD77CB233C04883C428415F415E415D415C5F5E5D5BC3
)"
PixelateBitmap := Buffer(StrLen(MCode_PixelateBitmap)//2)
nCount := StrLen(MCode_PixelateBitmap)//2
loop nCount {
NumPut("UChar", "0x" SubStr(MCode_PixelateBitmap, (2*A_Index)-1, 2), PixelateBitmap, A_Index-1)
}
DllCall("VirtualProtect", "UPtr", PixelateBitmap.Ptr, "UPtr", PixelateBitmap.Size, "UInt", 0x40, "UPtr*", 0)
}
Gdip_GetImageDimensions(pBitmap, &Width:="", &Height:="")
if (Width != Gdip_GetImageWidth(pBitmapOut) || Height != Gdip_GetImageHeight(pBitmapOut))
return -1
if (BlockSize > Width || BlockSize > Height)
return -2
E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, &Stride1:="", &Scan01:="", &BitmapData1:="")
E2 := Gdip_LockBits(pBitmapOut, 0, 0, Width, Height, &Stride2:="", &Scan02:="", &BitmapData2:="")
if (E1 || E2)
return -3
DllCall(PixelateBitmap.Ptr, "UPtr", Scan01, "UPtr", Scan02, "Int", Width, "Int", Height, "Int", Stride1, "Int", BlockSize)
Gdip_UnlockBits(pBitmap, &BitmapData1), Gdip_UnlockBits(pBitmapOut, &BitmapData2)
return 0
}
Gdip_ToARGB(A, R, G, B)
{
return (A << 24) | (R << 16) | (G << 8) | B
}
Gdip_FromARGB(ARGB, &A, &R, &G, &B)
{
A := (0xff000000 & ARGB) >> 24
R := (0x00ff0000 & ARGB) >> 16
G := (0x0000ff00 & ARGB) >> 8
B := 0x000000ff & ARGB
}
Gdip_AFromARGB(ARGB)
{
return (0xff000000 & ARGB) >> 24
}
Gdip_RFromARGB(ARGB)
{
return (0x00ff0000 & ARGB) >> 16
}
Gdip_GFromARGB(ARGB)
{
return (0x0000ff00 & ARGB) >> 8
}
Gdip_BFromARGB(ARGB)
{
return 0x000000ff & ARGB
}
StrGetB(Address, Length:=-1, Encoding:=0)
{
if !IsInteger(Length) {
Encoding := Length,  Length := -1
}
if (Address+0 < 1024) {
return
}
if (Encoding = "UTF-16") {
Encoding := 1200
} else if (Encoding = "UTF-8") {
Encoding := 65001
} else if SubStr(Encoding,1,2)="CP" {
Encoding := SubStr(Encoding,3)
}
if !Encoding {
if (Length == -1)
Length := DllCall("lstrlen", "UInt", Address)
VarSetStrCapacity(&myString, Length)
DllCall("lstrcpyn", "str", myString, "UInt", Address, "Int", Length + 1)
} else if (Encoding = 1200) {
char_count := DllCall("WideCharToMultiByte", "UInt", 0, "UInt", 0x400, "UInt", Address, "Int", Length, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0)
VarSetStrCapacity(&myString, char_count)
DllCall("WideCharToMultiByte", "UInt", 0, "UInt", 0x400, "UInt", Address, "Int", Length, "str", myString, "Int", char_count, "UInt", 0, "UInt", 0)
} else if IsInteger(Encoding) {
char_count := DllCall("MultiByteToWideChar", "UInt", Encoding, "UInt", 0, "UInt", Address, "Int", Length, "UInt", 0, "Int", 0)
VarSetStrCapacity(&myString, char_count * 2)
char_count := DllCall("MultiByteToWideChar", "UInt", Encoding, "UInt", 0, "UInt", Address, "Int", Length, "UInt", myString.Ptr, "Int", char_count * 2)
myString := StrGetB(myString.Ptr, char_count, 1200)
}
return myString
}
GetMonitorCount()
{
Monitors := MDMF_Enum()
for k,v in Monitors {
count := A_Index
}
return count
}
GetMonitorInfo(MonitorNum)
{
Monitors := MDMF_Enum()
for k,v in Monitors {
if (v.Num = MonitorNum) {
return v
}
}
}
GetPrimaryMonitor()
{
Monitors := MDMF_Enum()
for k,v in Monitors {
if (v.Primary) {
return v.Num
}
}
}
MDMF_Enum(HMON := "") {
static EnumProc := CallbackCreate(MDMF_EnumProc)
static Monitors := Map()
if (HMON = "") {
Monitors := Map("TotalCount", 0)
if !DllCall("User32.dll\EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", EnumProc, "Ptr", ObjPtr(Monitors), "Int")
return False
}
return (HMON = "") ? Monitors : Monitors.HasKey(HMON) ? Monitors[HMON] : False
}
MDMF_EnumProc(HMON, HDC, PRECT, ObjectAddr) {
Monitors := ObjFromPtrAddRef(ObjectAddr)
Monitors[HMON] := MDMF_GetInfo(HMON)
Monitors["TotalCount"]++
if (Monitors[HMON].Primary) {
Monitors["Primary"] := HMON
}
return true
}
MDMF_FromHWND(HWND, Flag := 0) {
return DllCall("User32.dll\MonitorFromWindow", "Ptr", HWND, "UInt", Flag, "Ptr")
}
MDMF_FromPoint(&X:="", &Y:="", Flag:=0) {
if (X = "") || (Y = "") {
PT := Buffer(8, 0)
DllCall("User32.dll\GetCursorPos", "Ptr", PT.Ptr, "Int")
if (X = "") {
X := NumGet(PT, 0, "Int")
}
if (Y = "") {
Y := NumGet(PT, 4, "Int")
}
}
return DllCall("User32.dll\MonitorFromPoint", "Int64", (X & 0xFFFFFFFF) | (Y << 32), "UInt", Flag, "Ptr")
}
MDMF_FromRect(X, Y, W, H, Flag := 0) {
RC := Buffer(16, 0)
NumPut("Int", X, "Int", Y, "Int", X + W, "Int", Y + H, RC)
return DllCall("User32.dll\MonitorFromRect", "Ptr", RC.Ptr, "UInt", Flag, "Ptr")
}
MDMF_GetInfo(HMON) {
MIEX := Buffer(40 + (32 << !!1))
NumPut("UInt", MIEX.Size, MIEX)
if DllCall("User32.dll\GetMonitorInfo", "Ptr", HMON, "Ptr", MIEX.Ptr, "Int") {
return {Name:      (Name := StrGet(MIEX.Ptr + 40, 32))
, Num:       RegExReplace(Name, ".*(\d+)$", "$1")
, Left:      NumGet(MIEX, 4, "Int")
, Top:       NumGet(MIEX, 8, "Int")
, Right:     NumGet(MIEX, 12, "Int")
, Bottom:    NumGet(MIEX, 16, "Int")
, WALeft:    NumGet(MIEX, 20, "Int")
, WATop:     NumGet(MIEX, 24, "Int")
, WARight:   NumGet(MIEX, 28, "Int")
, WABottom:  NumGet(MIEX, 32, "Int")
, Primary:   NumGet(MIEX, 36, "UInt")}
}
return False
}
WinGetRect( hwnd, &x:="", &y:="", &w:="", &h:="" ) {
Ptr := A_PtrSize ? "UPtr" : "UInt"
CreateRect(&winRect, 0, 0, 0, 0)
DllCall( "GetWindowRect", "Ptr", hwnd, "Ptr", winRect )
x := NumGet(winRect,  0, "UInt")
y := NumGet(winRect,  4, "UInt")
w := NumGet(winRect,  8, "UInt") - x
h := NumGet(winRect, 12, "UInt") - y
}
GdipSetSmoothingMode(pGraphics, smoothingMode) {
return DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGraphics, "int", smoothingMode)
}
GdipSetInterpolationMode(pGraphics, interpolationMode) {
return DllCall("gdiplus\GdipSetInterpolationMode", "ptr", pGraphics, "int", interpolationMode)
}
GdipSetCompositingQuality(pGraphics, quality) {
return DllCall("gdiplus\GdipSetCompositingQuality", "ptr", pGraphics, "int", quality)
}
GdipSetPixelOffsetMode(pGraphics, offsetMode) {
return DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", pGraphics, "int", offsetMode)
}
Gdip_SetPixelOffsetMode(pGraphics, PixelOffsetMode) {
return DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", pGraphics, "int", PixelOffsetMode)
}
class AAMyConfigs {
static libraryOverride := ""
static SharedPath(root) {
if this.libraryOverride != ""
return this.libraryOverride
if StrLower(this.Root(root)) != StrLower(A_ScriptDir "\Settings")
return ""
base := EnvGet("LOCALAPPDATA")
if base = ""
throw Error("Windows Local AppData is unavailable. Creator records were kept in the macro folder.")
return base "\BayzosAA\MyConfigs.json"
}
static ReadFile(path,library := false) {
if !FileExist(path)
return library ? Map("version",1,"created",Map(),"removed",Map()) : Map("created",Map(),"imported",Map())
if FileGetSize(path)>10000000
throw Error("My Configs library is too large.")
text := FileRead(path,"UTF-8"), data := Jxon_Load(&text)
if !(data is Map) || !(data.Get("created",0) is Map) || !(data.Get(library ? "removed" : "imported",0) is Map)
throw Error("My Configs storage is invalid: " path)
if library && data.Get("version",0) != 1
throw Error("This creator library needs a newer macro version. Your records were kept.")
return data
}
static Lock(path) {
mutex := DllCall("CreateMutexW","Ptr",0,"Int",false,"Str","Local\BayzosAA-Creators-" CrusadersConfigCodes.Hash(path),"Ptr")
if !mutex
throw Error("Could not lock the creator library. Your records were kept.")
wait := DllCall("WaitForSingleObject","Ptr",mutex,"UInt",5000,"UInt")
if wait != 0 && wait != 0x80 {
DllCall("CloseHandle","Ptr",mutex)
throw Error("Another macro is saving My Configs. Try again shortly.")
}
return mutex
}
static Unlock(mutex) {
DllCall("ReleaseMutex","Ptr",mutex), DllCall("CloseHandle","Ptr",mutex)
}
static ValidateCreator(code,row) {
if !CrusadersConfigCodes.IsHosted(code) || !(row is Map) || row.Get("code","") != code || !IsInteger(row.Get("revision",0)) || row["revision"]<1
throw Error("Invalid creator record in My Configs.")
this.Name(row.Get("name",""))
try key := CrusadersCredentials.Decode(row.Get("ownerKey",""))
catch Error
throw Error("Windows could not unlock this creator library. Use the same Windows account that created it.")
if !RegExMatch(key,"^[a-f0-9]{64}$")
throw Error("The saved publishing key is invalid. No creator records were changed.")
}
static MergeCreators(library,rows,updatedCode := "") {
for code,row in rows {
if library["removed"].Has(code)
continue
if !library["created"].Has(code) || row.Get("revision",0)>library["created"][code].Get("revision",0) || (code=updatedCode && row.Get("revision",0)=library["created"][code].Get("revision",0)) {
this.ValidateCreator(code,row)
if library["created"].Has(code) && CrusadersCredentials.Decode(library["created"][code]["ownerKey"]) != CrusadersCredentials.Decode(row["ownerKey"])
throw Error("Conflicting creator ownership for " code ". Your existing library was kept.")
library["created"][code] := row.Clone()
}
}
}
static WriteLibrary(path,data) {
SplitPath(path,,&directory)
DirCreate(directory)
StoryFiles.Write(path,Jxon_Dump(data))
}
static EnsureLibraryWritable(root) {
shared := this.SharedPath(root)
if shared = ""
return
mutex := this.Lock(shared)
try this.WriteLibrary(shared,this.ReadFile(shared,true))
catch Error
throw Error("Cannot save the creator library in Local AppData. Publishing was cancelled before sending a bundle. Check folder access and try again.")
finally this.Unlock(mutex)
}
static Name(value) {
value := Trim(value)
if StrLen(value)<1 || StrLen(value)>80 || RegExMatch(value,"[\x00-\x1f\x7f]")
throw Error("Enter a bundle name (1-80 characters).")
return value
}
static Root(root) {
SplitPath(root,,&settings)
return settings
}
static Read(root) {
path := this.Root(root) "\MyConfigs.json"
data := this.ReadFile(path), shared := this.SharedPath(root)
if shared = ""
return data
mutex := this.Lock(shared)
try {
library := this.ReadFile(shared,true), before := Jxon_Dump(library)
this.MergeCreators(library,data["created"])
if Jxon_Dump(library) != before
this.WriteLibrary(shared,library)
data["created"] := library["created"].Clone()
} finally this.Unlock(mutex)
return data
}
static Save(root,data,removedCode := "",updatedCode := "") {
shared := this.SharedPath(root)
if shared != "" {
mutex := this.Lock(shared)
try {
library := this.ReadFile(shared,true)
this.MergeCreators(library,data["created"],updatedCode)
if removedCode != "" {
library["removed"][removedCode] := true
if library["created"].Has(removedCode)
library["created"].Delete(removedCode)
}
this.WriteLibrary(shared,library)
data["created"] := library["created"].Clone()
} finally this.Unlock(mutex)
}
DirCreate(this.Root(root))
StoryFiles.Write(this.Root(root) "\MyConfigs.json",Jxon_Dump(data))
}
static MigrateFile(root,path) {
if StrLower(path) = StrLower(this.SharedPath(root)) {
this.Read(root)
return this.Public(root)
}
legacy := this.ReadFile(path)
if !legacy["created"].Count
throw Error("This file contains no bundles you created. Imported bundles are not migrated.")
for code,row in legacy["created"]
this.ValidateCreator(code,row)
data := this.Read(root), merged := Map("created",data["created"].Clone(),"removed",Map())
this.MergeCreators(merged,legacy["created"])
data["created"] := merged["created"], this.Save(root,data)
return this.Public(root)
}
static RestoreSnapshot(root) {
snapshot := Map()
SplitPath(root,,&settings)
for directory in [root,settings "\Recordings"]
loop files directory "\*", "FR"
snapshot[A_LoopFileFullPath] := CrusadersConfigCodes.HashBytes(FileRead(A_LoopFileFullPath,"RAW"))
return snapshot
}
static RestorePreview(root,code) {
if !this.Read(root)["created"].Has(code)
throw Error("Restore is available only for bundles you created.")
remote := this.Remote(code), payload := this.UpdatePayload(remote["payload"])
summary := CrusadersConfigCodes.Preview(payload,root)
if !summary["configs"].Length && !summary["recordings"].Length
throw Error("This bundle contains no configs or recordings to restore.")
return Map("root",root,"code",code,"name",remote["name"],"revision",remote["revision"],"sha256",remote["sha256"],"payload",payload,"summary",summary,"snapshot",this.RestoreSnapshot(root))
}
static Restore(root,settingsFile,plan,replaceExisting := false,log := 0) {
if plan["root"] != root || !this.Read(root)["created"].Has(plan["code"])
throw Error("Creator ownership or config folder changed. Preview restore again.")
for group in ["configs","recordings"]
for item in plan["summary"][group]
if item.Get("exists",false) && !replaceExisting
throw Error("Confirm replacing the existing files before restoring.")
remote := this.Remote(plan["code"])
if remote["revision"] != plan["revision"] || remote["sha256"] != plan["sha256"]
throw Error("The bundle changed. Preview restore again.")
current := this.RestoreSnapshot(root), previous := plan["snapshot"]
if current.Count != previous.Count
throw Error("Local files changed. Preview restore again.")
for path,hash in previous
if !current.Has(path) || current[path] != hash
throw Error("Local files changed. Preview restore again.")
result := CrusadersConfigCodes.Import(plan["payload"],root,settingsFile,"append","replace",false,log)
data := this.Read(root)
for key in ["name","revision","sha256"]
data["created"][plan["code"]][key] := remote[key]
this.Save(root,data)
return result
}
static Public(root) {
result := Map("created",[],"imported",[])
for group in ["created","imported"]
for code,row in this.Read(root)[group] {
safe := row.Clone()
for field in ["ownerKey","baseline","published"]
if safe.Has(field)
safe.Delete(field)
result[group].Push(safe)
}
return result
}
static Refresh(root) {
data := this.Read(root)
for code,stored in data["created"] {
remote := this.Remote(code)
for field in ["name","revision","sha256"]
stored[field] := remote[field]
}
this.Save(root,data)
return this.Public(root)
}
static Remote(code) {
if !CrusadersConfigCodes.IsHosted(code)
throw Error("Invalid shared code.")
response := CrusadersConfigCodes.Http("GET","/v2/shares/" code), text := response["body"], row := Jxon_Load(&text)
this.Validate(row,row.Get("payload",""))
if row["code"] != code
throw Error("Shared bundle identity mismatch.")
return row
}
static Validate(row,payload) {
if !CrusadersConfigCodes.IsHosted(row.Get("code","")) || !IsInteger(row.Get("revision",0)) || row["revision"]<1 || row.Get("sha256","")!=CrusadersConfigCodes.Hash(payload)
throw Error("Shared bundle response failed its integrity check.")
this.Name(row.Get("name","")), CrusadersConfigCodes.Decode(payload)
}
static Publish(root,model,tasks,options) {
title := this.Name(options.Get("name","")), data := this.Read(root), code := options.Get("code","")
this.EnsureLibraryWritable(root)
old := code!="" && data["created"].Has(code) ? data["created"][code] : 0
if code!="" && !old
throw Error("Only bundles created on this computer can be published.")
if old
key := CrusadersCredentials.Decode(old["ownerKey"])
else {
bytes := Buffer(32)
if !DllCall("advapi32\SystemFunction036","Ptr",bytes,"UInt",32)
throw Error("Could not generate a publishing key.")
key := ""
loop 32
key .= Format("{:02x}",NumGet(bytes,A_Index-1,"UChar"))
}
warnings := [], payload := CrusadersConfigCodes.ExportSelected(model,tasks,options.Get("configs",[]),options.Get("modes",false),options.Get("settings",false),options.Get("themes",false),warnings,options.Get("recordings",[]),options.Get("customThemes",[]))
body := Map("name",title,"payload",payload,"ownerKey",key,"revision",old ? old["revision"] : 0)
if old && old["name"] == title && old["sha256"] = CrusadersConfigCodes.Hash(payload)
row := Map("code",code,"name",title,"revision",old["revision"],"sha256",old["sha256"],"unchanged",true)
else {
response := CrusadersConfigCodes.Http(old ? "PUT" : "POST","/v2/shares" (old ? "/" code : ""),Jxon_Dump(body))
text := response["body"], row := Jxon_Load(&text)
}
this.Validate(row,payload)
result := row.Clone(), result["warnings"] := warnings
row["ownerKey"] := old ? old["ownerKey"] : CrusadersCredentials.Encode(key)
selection := Map()
for field in ["configs","recordings","customThemes","modes","settings","themes"]
selection[field] := options.Get(field,InStr("|modes|settings|themes|","|" field "|") ? false : [])
row["selection"] := selection, row["configs"] := []
for config in CrusadersConfigCodes.Decode(payload)["configs"]
row["configs"].Push(config["path"])
row["recordings"] := []
for recording in CrusadersConfigCodes.Decode(payload).Get("recordings",[])
row["recordings"].Push(recording["name"])
data["created"][row["code"]] := row, this.Save(root,data,"",row["code"])
A_Clipboard := row["code"]
return result
}
static UpdatePayload(payload) {
data := CrusadersConfigCodes.Decode(payload)
data["modes"] := [], data["settings"] := Map(), data["themes"] := []
if data.Has("appearance")
data.Delete("appearance")
return CrusadersConfigCodes.Encode(data)
}
static Baseline(root,payload) {
result := Map(), data := CrusadersConfigCodes.Decode(this.UpdatePayload(payload))
for config in data["configs"] {
relative := CrusadersCatalog.ConfigRelative(config["path"]), path := root "\" StrReplace(relative,"/","\")
if FileExist(path)
result[relative] := CrusadersConfigCodes.HashBytes(FileRead(path,"RAW"))
}
for recording in data.Get("recordings",[]) {
path := this.Root(root) "\Recordings\" recording["name"]
if FileExist(path)
result["@recording/" recording["name"]] := CrusadersConfigCodes.HashBytes(FileRead(path,"RAW"))
}
return result
}
static Track(root,row,payload,applied := 0) {
data := this.Read(root), safe := Map()
for field in ["code","name","revision","sha256"]
safe[field] := row[field]
safe["baseline"] := this.Baseline(root,payload), safe["configs"] := []
safe["published"] := this.Fingerprints(payload)
if applied is Map && data["imported"].Has(row["code"])
for relative,hash in data["imported"][row["code"]].Get("baseline",Map())
if safe["published"].Has(relative) && !applied.Has(relative)
safe["baseline"][relative] := hash
for config in CrusadersConfigCodes.Decode(payload)["configs"]
safe["configs"].Push(CrusadersCatalog.ConfigRelative(config["path"]))
data["imported"][row["code"]] := safe, this.Save(root,data)
}
static Apply(root,settingsFile,expected,replaceLocal := false,log := 0) {
checked := this.Check(root,expected["row"]["code"])
if checked.Get("current",false) || checked["revision"] != expected["revision"]
throw Error("The bundle changed. Check for updates again.")
if checked["conflicts"].Length && !replaceLocal
throw Error("Local edits exist. Confirm replacing them before updating.")
result := checked["changed"].Length ? CrusadersConfigCodes.Import(checked["payload"],root,settingsFile,"append","replace",false,log) : Map("configs",0,"recordings",0,"warnings",[])
applied := Map()
for relative in checked["changed"]
applied[relative] := true
this.Track(root,checked["row"],checked["fullPayload"],applied)
return result
}
static Normalized(value) {
if value is Map {
result := Map(), keys := ""
for key,item in value
keys .= key "`n"
loop parse Sort(RTrim(keys,"`n"),"C"), "`n"
result[A_LoopField] := this.Normalized(value[A_LoopField])
return result
}
if value is Array {
result := []
for item in value
result.Push(this.Normalized(item))
return result
}
return value
}
static Fingerprints(payload) {
result := Map(), package := CrusadersConfigCodes.Decode(this.UpdatePayload(payload))
for config in package["configs"]
result[CrusadersCatalog.ConfigRelative(config["path"])] := CrusadersConfigCodes.Hash(Jxon_Dump(this.Normalized(config)))
for recording in package.Get("recordings",[])
result["@recording/" recording["name"]] := CrusadersConfigCodes.Hash(Jxon_Dump(this.Normalized(recording["data"])))
return result
}
static LegacyFingerprints(root,payload,old) {
result := Map(), work := CrusadersConfigCodes.Work()
try {
CrusadersConfigCodes.Stage(CrusadersConfigCodes.Decode(payload),work)
for relative,hash in this.Fingerprints(payload) {
staged := this.Target(work "\Settings\Configs",relative), target := this.Target(root,relative)
expected := old.Get("baseline",Map()).Get(relative,"")
if !FileExist(staged) || expected = ""
continue
if CrusadersConfigCodes.HashBytes(FileRead(staged,"RAW")) = expected {
result[relative] := hash
continue
}
if !InStr(relative,"@recording/") && FileExist(target) {
image := IniRead(target,"Map","Image","")
if image != ""
IniWrite(image,staged,"Map","Image")
if CrusadersConfigCodes.HashBytes(FileRead(staged,"RAW")) = expected
result[relative] := hash
}
}
} finally CrusadersConfigCodes.Clean(work)
return result
}
static Target(root,relative) {
if InStr(relative,"@recording/") = 1
return CrusadersRecording.Path(SubStr(relative,12),this.Root(root) "\Recordings")
return root "\" StrReplace(CrusadersCatalog.ConfigRelative(relative),"/","\")
}
static Acknowledge(root,data,old,row,payload) {
for field in ["revision","name","sha256"]
old[field] := row[field]
old["published"] := this.Fingerprints(payload)
this.Save(root,data)
return Map("current",true,"name",row["name"],"revision",row["revision"])
}
static DeleteCreated(root,code) {
data := this.Read(root)
if !data["created"].Has(code)
throw Error("This shared config was not created on this computer.")
row := data["created"][code]
response := CrusadersConfigCodes.Http("GET","/health"), text := response["body"], health := Jxon_Load(&text), supported := false
for feature in health.Get("features",[])
if feature = "delete-shares"
supported := true
if !supported
throw Error("The sharing service needs the updated Worker before deletion. Your config was kept.")
body := Map("ownerKey",CrusadersCredentials.Decode(row["ownerKey"]),"revision",row["revision"])
try response := CrusadersConfigCodes.Http("DELETE","/v2/shares/" code,Jxon_Dump(body))
catch Error as err {
if !InStr(err.Message,"404")
throw err
response := 0
}
if response {
text := response["body"], deleted := Jxon_Load(&text)
if !deleted.Get("deleted",false) || deleted.Get("code","") != code
throw Error("The sharing service did not confirm deletion.")
}
data["created"].Delete(code), this.Save(root,data,code)
return Map("deleted",true,"code",code)
}
static Removal(root,code) {
data := this.Read(root)
if !data["imported"].Has(code)
throw Error("This imported code was already removed.")
referenced := Map(), row := data["imported"][code]
for group in ["created","imported"]
for other,entry in data[group] {
if group = "imported" && other = code
continue
for path in entry.Get("configs",[])
referenced[CrusadersCatalog.ConfigRelative(path)] := true
for path,hash in entry.Get("baseline",Map())
referenced[path] := true
for name in entry.Get("recordings",[])
referenced["@recording/" name] := true
}
for task in CrusadersTasks(root).items
referenced[CrusadersCatalog.Folder(task.mode) "/" task.config] := true
for relative,used in referenced.Clone() {
if InStr(relative,"@recording/") = 1
continue
configPath := this.Target(root,relative)
if !FileExist(configPath)
continue
content := FileRead(configPath), position := 1
while found := RegExMatch(content,"im)^recording=([^`r`n]+)",&match,position) {
referenced["@recording/" Trim(match[1])] := true
position := found+StrLen(match[0])
}
}
removable := [], kept := []
for relative,expected in row.Get("baseline",Map()) {
path := this.Target(root,relative)
if !FileExist(path)
continue
if referenced.Has(relative) || CrusadersConfigCodes.HashBytes(FileRead(path,"RAW")) != expected
kept.Push(relative)
else removable.Push(relative)
}
return Map("code",code,"name",row["name"],"removable",removable,"kept",kept)
}
static DeleteImported(root,code,deleteFiles := false) {
plan := this.Removal(root,code), data := this.Read(root), moved := [], work := CrusadersConfigCodes.Work(), rollbackFailed := false
try {
if deleteFiles
for index,relative in plan["removable"] {
source := this.Target(root,relative)
CrusadersConfigCodes.SafeTarget(source)
if CrusadersConfigCodes.HashBytes(FileRead(source,"RAW")) != data["imported"][code]["baseline"][relative]
throw Error("An imported file changed. Review deletion again.")
destination := work "\removed-" index
FileMove(source,destination)
moved.Push(Map("source",source,"temporary",destination))
}
data["imported"].Delete(code), this.Save(root,data)
} catch Error as err {
for item in moved {
try FileMove(item["temporary"],item["source"])
catch Error
rollbackFailed := true
}
if rollbackFailed
throw Error("File cleanup stopped. Recoverable files were kept in " work)
throw err
} finally {
if !rollbackFailed
CrusadersConfigCodes.Clean(work)
}
return Map("deleted",true,"files",moved.Length,"kept",plan["kept"].Length)
}
static Check(root,code) {
data := this.Read(root)
if !data["imported"].Has(code)
throw Error("Import this bundle first.")
old := data["imported"][code], row := this.Remote(code)
full := this.UpdatePayload(row["payload"])
if row["revision"]<=old["revision"]
return Map("current",true,"name",row["name"],"revision",row["revision"])
if row["sha256"] = old["sha256"]
return this.Acknowledge(root,data,old,row,full)
CrusadersConfigCodes.Preview(full,root)
fresh := this.Fingerprints(full), previous := old.Get("published",0)
if !(previous is Map)
previous := this.LegacyFingerprints(root,full,old)
changed := [], conflicts := [], removed := [], wanted := Map(), current := this.Baseline(root,full)
for relative,hash in fresh
if !previous.Has(relative) || previous[relative] != hash {
changed.Push(relative), wanted[relative] := true
before := old.Get("baseline",Map())
if (current.Has(relative) && current[relative] != before.Get(relative,"")) || (!current.Has(relative) && before.Has(relative))
conflicts.Push(relative)
}
for relative in old.Get("configs",[])
if !fresh.Has(relative)
removed.Push(relative)
if !changed.Length && !removed.Length
return this.Acknowledge(root,data,old,row,full)
package := CrusadersConfigCodes.Decode(full), configs := [], recordings := []
for config in package["configs"]
if wanted.Has(CrusadersCatalog.ConfigRelative(config["path"]))
configs.Push(config)
for recording in package.Get("recordings",[])
if wanted.Has("@recording/" recording["name"])
recordings.Push(recording)
package["configs"] := configs, package["recordings"] := recordings
return Map("current",false,"name",row["name"],"revision",row["revision"],"changed",changed,"conflicts",conflicts,"removed",removed,"row",row,"payload",changed.Length ? CrusadersConfigCodes.Encode(package) : "","fullPayload",full)
}
}
class CrusadersConfigCodes {
    static SharingBusy := false
    static MaxCode := 1048576
    static SafeTarget(path) => SafeTarget(path)
    static HashBytes(bytes) {
        provider := 0, hash := 0
        try {
            if !DllCall("advapi32\CryptAcquireContextW","Ptr*",&provider,"Ptr",0,"Ptr",0,"UInt",24,"UInt",0xF0000000)
            || !DllCall("advapi32\CryptCreateHash","Ptr",provider,"UInt",0x800C,"Ptr",0,"UInt",0,"Ptr*",&hash)
            || !DllCall("advapi32\CryptHashData","Ptr",hash,"Ptr",bytes,"UInt",bytes.Size,"UInt",0)
                throw Error("Could not verify config integrity.")
            result := Buffer(32), size := 32
            if !DllCall("advapi32\CryptGetHashParam","Ptr",hash,"UInt",2,"Ptr",result,"UInt*",&size,"UInt",0)
                throw Error("Could not verify config integrity.")
            hex := ""
            loop 32
                hex .= Format("{:02x}",NumGet(result,A_Index-1,"UChar"))
            return hex
        } finally {
            if hash
                DllCall("advapi32\CryptDestroyHash","Ptr",hash)
            if provider
                DllCall("advapi32\CryptReleaseContext","Ptr",provider,"UInt",0)
        }
    }
    static ExportSelected(*) => ""
    static Upload(*) => ""
    static Import(*) => 0
    static Decode(*) => ""
    static Work(*) => ""
    static Stage(*) => 0
    static Clean(*) => 0
    static ClipboardCode(*) => ""
    static IsHosted(*) => false
    static List(*) => []
    static Preview(*) => ""
    static Resolve(*) => ""
    static Settings := ["ZoomInDelay", "ZoomOutDelay", "DragDelay", "ScanDelay", "PlacementRetryDelay", "StageClickDelay", "VictoryDelay", "WebhookScreenshotDelay", "PathingDelay", "DailyChallengeEnabled", "ChallengeEnabled", "ChallengeFirstMode", "ChallengeForceLeave"]
}
class CrusadersStorage {
static Temporary(path) {
guid := Buffer(16), text := Buffer(78)
if DllCall("ole32\CoCreateGuid", "Ptr", guid, "Int") != 0
throw Error("Could not create a unique save filename.")
DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 39)
return path "." StrGet(text) ".tmp"
}
static CheckCurrent(path, expected) {
if (FileExist(path) ? FileRead(path) : "") != expected
throw Error("File changed externally while saving. Reload before saving again.")
}
static Publish(temporary, path) {
if !FileExist(temporary)
throw Error("Completed temporary save is missing. The previous file was retained.")
file := FileOpen(temporary, "rw")
if !file
throw Error("Could not open the completed save for flushing.")
try {
if !DllCall("FlushFileBuffers", "Ptr", file.Handle, "Int")
throw OSError(A_LastError, "Could not flush the completed save.")
} finally file.Close()
if !DllCall("MoveFileExW", "Str", temporary, "Str", path, "UInt", 0x9, "Int")
throw OSError(A_LastError, "Could not replace the saved file. The previous file was retained.")
}
static Commit(temporary, path, expected) {
previousCritical := A_IsCritical
Critical("On")
try {
this.CheckCurrent(path, expected)
this.Publish(temporary, path)
} finally Critical(previousCritical)
}
}
class AAOcrLibrary {
static Load(root) {
path := root "\" (A_PtrSize*8) "bit\RapidOcrOnnx.dll"
if !FileExist(path)
throw Error("OCR engine file is missing: " path ". Extract the complete release ZIP; check antivirus quarantine if extraction removed it.")
library := DllCall("LoadLibraryExW","Str",path,"Ptr",0,"UInt",0x1100,"Ptr")
code := A_LastError
if library
return library
missing := ""
for name in ["MSVCP140.dll","CONCRT140.dll","VCRUNTIME140.dll","VCRUNTIME140_1.dll"] {
dependencyPath := root "\" (A_PtrSize*8) "bit\" name
handle := FileExist(dependencyPath) ? DllCall("LoadLibraryExW","Str",dependencyPath,"Ptr",0,"UInt",0x1100,"Ptr") : DllCall("LoadLibraryExW","Str",name,"Ptr",0,"UInt",0x800,"Ptr")
if handle
DllCall("FreeLibrary","Ptr",handle)
else
missing .= (missing="" ? "" : ", ") name
}
message := Buffer(2048,0)
DllCall("FormatMessageW","UInt",0x1200,"Ptr",0,"UInt",code,"UInt",0,"Ptr",message,"UInt",1024,"Ptr",0)
reason := Trim(StrGet(message)," `t`r`n")
hint := missing!="" ? " Missing Visual C++ runtime dependencies: " missing ". Install or repair the Microsoft Visual C++ v14 Redistributable (" (A_PtrSize*8) "-bit)." : code=193 ? " DLL architecture is incompatible with this " (A_PtrSize*8) "-bit macro. Re-extract the matching release files." : code=126 ? " A required DLL dependency could not be loaded. Re-extract the release and check antivirus quarantine." : " Windows rejected OCR DLL loading; check the extracted files and security software."
throw Error("Could not load OCR DLL (Windows error " code ": " reason "). File: " path "." hint)
}
static Models(root) {
for name in ["ch_PP-OCRv3_det_infer.onnx","ch_ppocr_mobile_v2.0_cls_infer.onnx","ch_PP-OCRv3_rec_infer.onnx","ppocr_keys_v1.txt"]
if !FileExist(root "\models\" name)
throw Error("OCR model file is missing: " root "\models\" name ". Extract the complete release ZIP.")
}
}
class CrusadersOcr {
static LabelWords := 0
static library := 0
static EnsureLibrary(root) {
if !this.library {
this.library := AAOcrLibrary.Load(root)
}
}
static NormalizeLabels(text) {
if !this.LabelWords {
words := Map()
labels := "Stage Stages Story Legend Raid Raids Boss Rush Event Challenge Challenges "
. "Daily Rewards Day Update Log Join Matchmaking Play Here Start Game Vote Yes No "
. "Select Normal Hard Advanced Continue Open Contracts Contract Active Hunter Mayhem "
. "Rookie Standard Elite Legendary Mythic Godlike Teleporting Soon Units Teams Load "
. "Priority Sell Upgrade Max Wave Auto Ability Abilities Rewrite Passive Blessed Cursed "
. "Choose Path Erase Motion Thought Force Form Beyond Heaven Strongest History Domain Clash "
. "Cancel Damage Placement Limit Slot Victory Defeat Defeated Replay Pick Next Gate "
. "Disconnected Error Code Leave Claim Time Machine Leaderboards Ruined High Cost"
for mode, names in CrusadersCatalog.Maps
for name in names
labels .= " " name
for word in StrSplit(StrLower(labels), " ")
if StrLen(word) >= 2 && RegExMatch(word, "^[a-z]+$")
words[word] := true
this.LabelWords := words
}
text := Trim(RegExReplace(text, "[ \t]+", " "), " `t`r`n")
result := ""
offset := 1
labelOnly := true
while position := RegExMatch(text, "[A-Za-z0-9]+", &token, offset) {
word := token[0]
replacement := word
if StrLen(word) >= 3 && RegExMatch(word, "[A-Za-z].*[A-Za-z]") && RegExMatch(word, "[01357]") {
candidate := StrLower(word)
for digit, letter in Map("0", "o", "1", "l", "3", "e", "5", "s", "7", "t")
candidate := StrReplace(candidate, digit, letter)
if this.LabelWords.Has(candidate)
replacement := candidate
}
labelOnly := labelOnly && this.LabelWords.Has(StrLower(replacement))
result .= SubStr(text, offset, position - offset) replacement
offset := position + StrLen(word)
}
result .= SubStr(text, offset)
if labelOnly && RegExMatch(result, "^[A-Za-z\s.!?]+$")
result := Trim(RegExReplace(RegExReplace(result, "[.!?]+", " "), "[ \t]+", " "), " `t`r`n")
return RegExReplace(result, "i)\b(Day)[\s\p{P}_]+(?=\d)", "$1 ")
}
__New() {
this.engine := 0
this.callback := 0
directory := A_ScriptDir "\Other"
root := directory "\RapidOcr"
CrusadersOcr.EnsureLibrary(root)
AAOcrLibrary.Models(root)
try {
this.engine := DllCall("RapidOcrOnnx\OcrInit",
"Str", root "\models\ch_PP-OCRv3_det_infer.onnx",
"Str", root "\models\ch_ppocr_mobile_v2.0_cls_infer.onnx",
"Str", root "\models\ch_PP-OCRv3_rec_infer.onnx",
"Str", root "\models\ppocr_keys_v1.txt", "Int", 2, "Ptr")
if !this.engine
throw Error("Could not initialize OCR.")
this.callback := CallbackCreate(ObjBindMethod(this, "ReceiveText"), , 3)
this.parameters := Buffer(42, 0)
NumPut("Int", 10, "Int", 1024, "Float", 0.5, "Float", 0.3, "Float", 2.0, this.parameters)
} catch Error as err {
this.Dispose()
throw err
}
}
ReceiveText(userdata, textPointer, resultPointer) {
this.result := StrGet(textPointer, "UTF-8")
return 0
}
Read(bitmap, x, y, width, height, scale := 3) {
scaled := 0, graphics := 0, locked := false
try {
scaled := Gdip_CreateBitmap(width * scale, height * scale)
if !scaled
throw Error("Could not allocate OCR pixels.")
graphics := Gdip_GraphicsFromImage(scaled)
if !graphics
throw Error("Could not initialize OCR graphics.")
if Gdip_DrawImage(graphics, bitmap, 0, 0, width * scale, height * scale, x, y, width, height)!=0
throw Error("Could not scale OCR pixels.")
if Gdip_LockBits(scaled, 0, 0, width * scale, height * scale, &stride, &pixels, &data, 1) != 0
throw Error("Could not prepare OCR pixels.")
locked := true
native := Buffer(A_PtrSize + 16, 0)
NumPut("Ptr", pixels, "Int", stride, "Int", width * scale, "Int", height * scale, "Int", 4, native)
this.result := ""
ok := this.DetectBitmap(native)
return ok ? CrusadersOcr.NormalizeLabels(this.result) : ""
} finally {
if locked
Gdip_UnlockBits(scaled, &data)
if graphics
Gdip_DeleteGraphics(graphics)
if scaled
Gdip_DisposeImage(scaled)
}
}
DetectBitmap(native) => DllCall("RapidOcrOnnx\OcrDetectBitmapData", "Ptr", this.engine, "Ptr", native,
"Ptr", this.parameters, "Ptr", this.callback, "Ptr", 0, "Int")
Dispose() {
engine := this.engine, callback := this.callback
this.engine := this.callback := 0
try {
if engine
DllCall("RapidOcrOnnx\OcrDestroy", "Ptr", engine)
} finally {
if callback
CallbackFree(callback)
}
}
}
class CrusadersVision {
static CreateReader() => CrusadersOcr()
static StartGraphics() => Gdip_Startup()
static StopGraphics(token) => Gdip_Shutdown(token)
static Open(owner) {
if (owner.HasOwnProp("token") && owner.token) || (owner.HasOwnProp("ocr") && owner.ocr)
throw Error("Screen-detection resources are already initialized.")
owner.token := 0, owner.ocr := 0
try {
owner.token := this.StartGraphics()
if !owner.token
throw Error("Could not initialize screen-detection graphics.")
owner.ocr := this.CreateReader()
} catch Error as err {
this.Close(owner)
throw err
}
}
static Close(owner) {
reader := owner.ocr, token := owner.token
owner.ocr := 0, owner.token := 0
try {
if reader
reader.Dispose()
} finally {
if token
this.StopGraphics(token)
}
}
}
class CrusadersRecording {
static Root := A_ScriptDir "\Settings\Recordings"
static MaxEvents := 30000
static MaxDuration := 600000
static ReleaseReserve := 512
static Clock() {
static frequency := 0
if !frequency
DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
DllCall("QueryPerformanceCounter", "Int64*", &counter := 0)
return Floor(counter * 1000 / frequency)
}
static PlaybackClock() => this.Clock() - CrusadersRuntime.pauseTotal
- (CrusadersRuntime.paused ? CrusadersRuntime.Tick() - CrusadersRuntime.pausedAt : 0)
static Path(name, root := unset) {
if !RegExMatch(name, "i)^[A-Za-z0-9][A-Za-z0-9 _-]{0,79}\.txt$")
|| RegExMatch(name, "i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.| )")
throw Error("Use a recording filename with letters, numbers, spaces, underscores or dashes.")
return (IsSet(root) ? root : this.Root) "\" name
}
static List(root := unset) {
directory := IsSet(root) ? root : this.Root
names := ""
loop files directory "\*.txt", "F"
try {
this.Path(A_LoopFileName, directory)
names .= A_LoopFileName "`n"
}
return names = "" ? [] : StrSplit(RTrim(Sort(names), "`n"), "`n")
}
static Validate(data) {
if !(data is Map) || data.Get("version", 0) != 1 || !(data.Get("events", 0) is Array)
throw Error("Recording must be version 1 JSON with an events array.")
for key in ["width", "height", "duration"]
if !data.Has(key) || !IsInteger(data[key]) || data[key] < (key = "duration" ? 0 : 1)
throw Error("Invalid recording " key)
if data["width"] > 8192 || data["height"] > 8192 || data["duration"] > this.MaxDuration
|| !data["events"].Length || data["events"].Length > this.MaxEvents
throw Error("Recordings must contain 1-30000 events and last at most 10 minutes.")
previous := -1, held := Map()
for event in data["events"] {
if !(event is Map) || !IsInteger(event.Get("at", "")) || event["at"] < 0 || event["at"] < previous || event["at"] > data["duration"]
throw Error("Event timestamps must be ordered milliseconds within the duration.")
previous := event["at"]
action := event.Get("action", "")
if !InStr("|keyDown|keyUp|mouseDown|mouseUp|move|wheel|", "|" action "|") || action = ""
throw Error("Unknown recording event action.")
if action = "keyDown" || action = "keyUp" {
key := event.Get("key", "")
if !RegExMatch(key, "i)^[a-z0-9_]{1,32}$") || (!GetKeyVK(key) && !GetKeySC(key))
throw Error("Invalid recording key.")
token := "key:" StrLower(key)
} else {
for axis in ["x", "y"]
if !IsInteger(event.Get(axis, "")) || event[axis] < 0 || event[axis] >= data[axis = "x" ? "width" : "height"]
throw Error("Mouse coordinates must be inside the recorded client area.")
if action = "mouseDown" || action = "mouseUp" {
button := event.Get("button", "")
if !InStr("|Left|Right|Middle|X1|X2|", "|" button "|") || button = ""
throw Error("Invalid recording mouse button.")
token := "mouse:" button
}
if action = "wheel" && (!IsInteger(event.Get("delta", "")) || !event["delta"] || Abs(event["delta"]) > 12000
|| !InStr("|vertical|horizontal|", "|" event.Get("axis", "vertical") "|"))
throw Error("Invalid recording wheel movement.")
}
if action = "keyDown" || action = "mouseDown" {
if held.Has(token)
throw Error("Duplicate down event; release the key or button first.")
held[token] := true
} else if action = "keyUp" || action = "mouseUp" {
if !held.Has(token)
throw Error("Up event has no matching down event.")
held.Delete(token)
}
}
if held.Count
throw Error("Recording ends with held keys or buttons; add matching up events.")
return data
}
static Load(name, root := unset) {
path := IsSet(root) ? this.Path(name, root) : this.Path(name)
if !FileExist(path)
throw Error("Recording '" name "' is missing. Choose another recording in Indexes or save it again in Recorder.")
if FileGetSize(path) > 8000000
throw Error("Recording file is too large.")
text := FileRead(path, "UTF-8")
return this.Validate(Jxon_Load(&text))
}
__New(window) {
this.window := window
if !(window.HasOwnProp("uiTest") && window.uiTest)
DirCreate(CrusadersRecording.Root)
this.recording := false, this.playing := false, this.cancelled := false
this.events := [], this.held := Map(), this.playbackHeld := Map(), this.duration := 0
this.width := 800, this.height := 600, this.revision := 0
this.message := "Ready", this.savedName := "", this.dirty := false, this.diskText := "", this.captureError := ""
this.hook := 0, this.callback := 0, this.input := 0
this.precisionActive := false
this.watchCallback := ObjBindMethod(this, "Watch")
this.preview := []
OnExit(ObjBindMethod(this, "Cancel"))
}
Ready() {
global testRunning
if this.window.HasOwnProp("uiTest") && this.window.uiTest
throw Error("Input capture and playback are disabled in UI tests.")
if IsSet(testRunning) && testRunning
throw Error("Stop the macro before recording or testing playback.")
}
Target() {
AADisplay.UsePhysicalPixels()
if !WinActive("Roblox ahk_exe RobloxPlayerBeta.exe")
return 0
return WinActive("Roblox ahk_exe RobloxPlayerBeta.exe")
}
Toggle(*) {
global selector
try {
if this.recording
this.Stop("Recording stopped")
else {
this.Ready()
if this.playing
throw Error("Stop playback before recording.")
if this.dirty
throw Error("Save or discard the current recording before starting another.")
target := this.Target()
if !target
throw Error("Click on the Roblox Window Before Starting a Recording.")
if selector.pickMode
throw Error("Cancel coordinate selection before recording.")
this.targetHwnd := target
WinGetClientPos(, , &w, &h, "ahk_id " target)
this.width := w, this.height := h
this.events := [], this.held := Map(), this.preview := []
this.duration := 0, this.savedName := "", this.diskText := "", this.cancelled := false, this.captureError := ""
this.reserved := []
for key in ["StartKey", "PauseKey", "CloseKey", "RestartKey", "CaptureKey", "ZoomtechKey", "WebhookTestKey", "RecordKey", "RecordingTestKey"]
this.reserved.Push(CrusadersHotkeys.Parse(selector.preferences[key]))
this.reserved.Push(CrusadersHotkeys.Parse("F11"))
this.input := InputHook("V L0 I1")
this.input.KeyOpt("{All}", "N")
this.input.OnKeyDown := ObjBindMethod(this, "KeyEvent", "keyDown")
this.input.OnKeyUp := ObjBindMethod(this, "KeyEvent", "keyUp")
this.callback := CallbackCreate(ObjBindMethod(this, "MouseEvent"), , 3)
this.hook := DllCall("SetWindowsHookExW", "Int", 14, "Ptr", this.callback,
"Ptr", DllCall("GetModuleHandleW", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
if !this.hook {
CallbackFree(this.callback), this.callback := 0
throw Error("Could not start mouse capture.")
}
this.lastMove := -100, this.lastX := 0, this.lastY := 0
this.BeginPrecision()
this.started := CrusadersRecording.Clock()
this.startedTick := DllCall("GetTickCount", "UInt")
this.recording := true
this.input.Start()
SetTimer(this.watchCallback, 100)
this.message := "Recording", this.revision += 1
this.window.Log("Recorder started; Roblox client-relative input only")
}
} catch Error as err {
if this.recording
this.Stop("Capture stopped after an error")
this.message := err.Message, this.revision += 1
this.window.Log("Recorder: " err.Message)
}
}
Add(event, capturedAt := unset) {
if !this.recording
return
if this.events.Length >= CrusadersRecording.MaxEvents - CrusadersRecording.ReleaseReserve
return
elapsed := IsSet(capturedAt) ? capturedAt : CrusadersRecording.Clock() - this.started
previous := this.events.Length ? this.events[this.events.Length]["at"] : 0
event["at"] := Max(previous,Min(CrusadersRecording.MaxDuration,Max(0,elapsed)))
this.events.Push(event)
this.dirty := true
this.revision += 1
}
KeyEvent(action, input, vk, sc) {
if !this.recording || (action = "keyDown" && this.ReservedKey(vk)) || this.Target() != this.targetHwnd
return
key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
if key = ""
key := Format("vk{:02X}sc{:03X}", vk, sc)
token := "key:" StrLower(key)
if action = "keyDown" {
if this.held.Has(token)
return
this.held[token] := Map("action", "keyUp", "key", key)
} else {
if !this.held.Has(token)
return
this.held.Delete(token)
}
this.Add(Map("action", action, "key", key))
}
MouseEvent(code, message, info) {
try this.CaptureMouse(code, message, info)
catch Error as err
this.captureError := "Recording stopped: " err.Message
return DllCall("CallNextHookEx", "Ptr", 0, "Int", code, "UPtr", message, "Ptr", info, "Ptr")
}
ReservedKey(vk) {
for binding in this.reserved {
if binding.vk != vk
continue
matches := true
for pair in [["^","Ctrl"],["!","Alt"],["+","Shift"],["#","LWin"]] {
down := pair[1] = "#" ? GetKeyState("LWin","P") || GetKeyState("RWin","P") : GetKeyState(pair[2],"P")
if !!InStr(binding.mods,pair[1]) != !!down
matches := false
}
if matches
return true
}
return false
}
CaptureMouse(code, message, info) {
AADisplay.UsePhysicalPixels()
if code = 0 && this.recording && !(NumGet(info, 12, "UInt") & 1) && this.Target() = this.targetHwnd {
WinGetClientPos(&left, &top, &w, &h, "ahk_id " this.targetHwnd)
if w != this.width || h != this.height {
this.captureError := "Recording stopped: Roblox client size changed"
return
}
capturedAt := Min(CrusadersRecording.Clock()-this.started,
(NumGet(info,16,"UInt")-this.startedTick) & 0xFFFFFFFF)
x := NumGet(info, 0, "Int") - left, y := NumGet(info, 4, "Int") - top
if message = 0x202 || message = 0x205 || message = 0x208 || message = 0x20C
x := Max(0, Min(w - 1, x)), y := Max(0, Min(h - 1, y))
if x >= 0 && y >= 0 && x < w && y < h {
this.lastX := x, this.lastY := y
if message = 0x200 {
if capturedAt - this.lastMove >= 8 {
this.lastMove := capturedAt
this.Add(Map("action", "move", "x", x, "y", y),capturedAt)
}
} else if message = 0x20A || message = 0x20E {
delta := NumGet(info, 10, "Short")
if delta
this.Add(Map("action", "wheel", "delta", delta, "axis", message = 0x20A ? "vertical" : "horizontal", "x", x, "y", y),capturedAt)
} else {
buttons := Map(0x201, "Left", 0x202, "Left", 0x204, "Right", 0x205, "Right", 0x207, "Middle", 0x208, "Middle", 0x20B, "X", 0x20C, "X")
if buttons.Has(message) {
button := buttons[message]
if button = "X"
button := NumGet(info, 10, "UShort") = 1 ? "X1" : "X2"
down := message = 0x201 || message = 0x204 || message = 0x207 || message = 0x20B
token := "mouse:" button
event := Map("action", down ? "mouseDown" : "mouseUp", "button", button, "x", x, "y", y)
if down && !this.held.Has(token) {
this.held[token] := Map("action", "mouseUp", "button", button, "x", x, "y", y)
this.Add(event,capturedAt)
} else if !down && this.held.Has(token) {
this.held.Delete(token)
this.Add(event,capturedAt)
}
}
}
}
}
}
Watch(*) {
if !this.recording
return
if this.captureError != "" {
this.Stop(this.captureError)
return
}
if this.Target() != this.targetHwnd || CrusadersRecording.Clock() - this.started >= CrusadersRecording.MaxDuration
|| this.events.Length >= CrusadersRecording.MaxEvents - CrusadersRecording.ReleaseReserve {
this.Stop("Recording stopped: focus changed or capture limit reached")
return
}
try {
WinGetClientPos(, , &w, &h, "ahk_id " this.targetHwnd)
if w != this.width || h != this.height
this.Stop("Recording stopped: Roblox client size changed")
} catch Error {
this.Stop("Recording stopped: Roblox window unavailable")
}
}
Stop(reason := "Recording stopped") {
if !this.recording
return
this.recording := false
SetTimer(this.watchCallback, 0)
if this.input
this.input.Stop()
if this.hook
DllCall("UnhookWindowsHookEx", "Ptr", this.hook)
this.hook := 0
if this.callback
CallbackFree(this.callback)
this.callback := 0
this.duration := Min(CrusadersRecording.MaxDuration, CrusadersRecording.Clock() - this.started)
this.EndPrecision()
for token, event in this.held {
if event["action"] = "mouseUp"
event["x"] := this.lastX, event["y"] := this.lastY
event["at"] := this.duration
this.events.Push(event)
}
this.held.Clear()
this.preview := this.events.Clone()
this.message := reason, this.revision += 1
this.window.Log(reason ": " this.events.Length " events, " this.duration "ms")
}
Data() => Map("version", 1, "width", this.width, "height", this.height, "duration", this.duration, "events", this.events)
Save(name) {
if this.recording || this.playing
throw Error("Stop recording or playback before saving.")
if !RegExMatch(name, "i)\.txt$")
name .= ".txt"
path := CrusadersRecording.Path(name)
CrusadersRecording.Validate(this.Data())
if FileExist(path) && name != this.savedName
throw Error("That recording already exists. Choose a different name.")
if FileExist(path) && FileRead(path, "UTF-8") != this.diskText
throw Error("Recording changed on disk. Reload it or save with a new name.")
expected := name = this.savedName ? this.diskText : ""
DirCreate(CrusadersRecording.Root)
temporary := CrusadersStorage.Temporary(path)
try {
FileAppend(Jxon_Dump(this.Data(), 2), temporary, "UTF-8")
CrusadersStorage.Commit(temporary, path, expected)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
this.diskText := FileRead(path, "UTF-8")
this.savedName := name, this.dirty := false, this.message := "Saved " name, this.revision += 1
this.window.Log("Recording saved: Settings\Recordings\" name)
}
Cancel(*) {
this.cancelled := true
this.Stop("Recording stopped")
this.ReleasePlayback()
this.EndPrecision()
}
BeginPrecision() {
if !this.precisionActive
this.precisionActive := DllCall("winmm\timeBeginPeriod", "UInt", 1, "UInt") = 0
}
EndPrecision() {
if this.precisionActive {
DllCall("winmm\timeEndPeriod", "UInt", 1)
this.precisionActive := false
}
}
ReleasePlayback() {
for token, event in this.playbackHeld
if event["action"] = "keyUp"
SendEvent("{Blind}{" event["key"] " up}")
else Click(event["button"] " Up")
this.playbackHeld.Clear()
}
State(includeFiles := true) {
events := [], data := this.recording ? this.events : this.preview
first := Max(1, data.Length - 7)
loop Max(0, data.Length - first + 1)
events.Push(data[first + A_Index - 1])
return Map("recording", Integer(this.recording), "playing", Integer(this.playing), "dirty", Integer(this.dirty),
"revision", this.revision, "message", this.message, "count", this.events.Length,
"duration", this.recording ? CrusadersRecording.Clock() - this.started : this.duration, "name", this.savedName,
"events", events, "files", includeFiles ? CrusadersRecording.List() : [])
}
Test(*) {
try {
if this.playing {
this.cancelled := true
return
}
this.Ready()
if this.recording
throw Error("Stop recording before playback.")
this.Play(CrusadersRecording.Validate(this.Data()))
} catch Error as err {
this.message := err.Message, this.revision += 1
this.window.Log("Recorder: " err.Message)
}
}
Play(data, shouldStop := 0, activeCheck := 0) {
AADisplay.UsePhysicalPixels()
CrusadersRecording.Validate(data)
if this.recording || this.playing
throw Error("Recorder is already busy.")
hwnd := this.Target()
if !hwnd
throw Error("Focus Roblox before playback.")
WinGetClientPos(, , &width, &height, "ahk_id " hwnd)
if width != data["width"] || height != data["height"]
throw Error("Roblox client size must match the recorded size.")
this.playing := true, this.cancelled := false, this.message := "Playing", this.revision += 1
held := Map(), began := CrusadersRecording.PlaybackClock(), completed := false, nextCheck := 0
resumePlayback := this.HasOwnProp("waitForFocus") && this.waitForFocus
this.playbackHeld := held
previous := A_CoordModeMouse, delay := A_MouseDelay
keyDelay := A_KeyDelay, keyDuration := A_KeyDuration
CoordMode("Mouse", "Screen"), SetMouseDelay(-1), SetKeyDelay(-1, -1)
try {
this.BeginPrecision()
playbackEvents := data["events"].Clone()
playbackEvents.Push(Map("action", "end", "at", data["duration"]))
for event in playbackEvents {
loop {
Sleep(-1)
if this.cancelled
return false
if CrusadersRuntime.paused && !resumePlayback {
if held.Count
throw Error("Playback stopped while paused; held inputs released.")
Sleep(20)
continue
}
if this.Target() != hwnd || CrusadersRuntime.paused {
if !resumePlayback
throw Error("Playback stopped: Roblox lost focus.")
suspended := held.Clone(), focusBegan := CrusadersRecording.PlaybackClock()
this.ReleasePlayback()
while this.Target() != hwnd || CrusadersRuntime.paused {
if this.cancelled || !WinExist("ahk_id " hwnd) || (shouldStop && shouldStop.Call())
return false
Sleep(20)
}
if activeCheck && !activeCheck.Call()
return false
began += CrusadersRecording.PlaybackClock()-focusBegan
for token,release in suspended {
down := release.Clone()
down["action"] := release["action"] = "keyUp" ? "keyDown" : "mouseDown"
WinGetClientPos(&focusX,&focusY,,,"ahk_id " hwnd)
this.SendPlaybackEvent(down,focusX,focusY)
held[token] := release
}
nextCheck := 0
}
now := CrusadersRecording.PlaybackClock()
if now >= nextCheck {
if (shouldStop && shouldStop.Call()) || (activeCheck && !activeCheck.Call())
return false
WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
if w != width || h != height
throw Error("Playback stopped: Roblox client size changed.")
nextCheck := CrusadersRecording.PlaybackClock() + 100
}
remaining := event["at"] - (CrusadersRecording.PlaybackClock() - began)
if remaining <= 0
break
DllCall("Sleep", "UInt", remaining <= 2 ? 1 : Min(4, remaining-1))
}
action := event["action"]
if action = "end"
continue
if action = "keyDown" || action = "keyUp" {
key := event["key"], token := "key:" key
if action = "keyDown"
held[token] := Map("action", "keyUp", "key", key)
else held.Delete(token)
this.SendPlaybackEvent(event)
} else {
WinGetClientPos(&left, &top, &w, &h, "ahk_id " hwnd)
if w != width || h != height
throw Error("Playback stopped: Roblox client size changed.")
if action = "mouseDown" || action = "mouseUp" {
button := event["button"], token := "mouse:" button
if action = "mouseDown"
held[token] := Map("action", "mouseUp", "button", button, "x", event["x"], "y", event["y"])
else held.Delete(token)
}
this.SendPlaybackEvent(event, left, top)
}
}
completed := true
return true
} finally {
try this.ReleasePlayback()
finally {
this.EndPrecision()
CoordMode("Mouse", previous), SetMouseDelay(delay), SetKeyDelay(keyDelay, keyDuration)
this.playing := false, this.message := completed ? "Playback finished" : "Playback stopped", this.revision += 1
}
}
}
SendPlaybackEvent(event, left := 0, top := 0) {
AADisplay.UsePhysicalPixels()
action := event["action"]
if action = "keyDown" || action = "keyUp" {
SendEvent("{Blind}{" event["key"] (action = "keyDown" ? " down}" : " up}"))
return
}
MouseMove(left + event["x"], top + event["y"], 0)
if action = "mouseDown" || action = "mouseUp"
Click(event["button"] (action = "mouseDown" ? " Down" : " Up"))
else if action = "wheel"
DllCall("mouse_event", "UInt", event.Get("axis", "vertical") = "horizontal" ? 0x1000 : 0x800,
"UInt", 0, "UInt", 0, "Int", event["delta"], "UPtr", 0)
}
}
class CrusadersRouteRecorder {
static DailySteps := [[0, "Shift", 1], [93, "Shift", 0], [218, "d", 1],
[7312, "s", 1], [10515, "d", 0], [10531, "s", 0]]
static SamuraiMatchSelected(preferences) {
return preferences["Mode"] = "Legend Stages" && preferences["Map"] = "Samurai Island"
&& (Integer(preferences["Act"]) = 2 || Integer(preferences["Act"]) = 3)
}
__New(logger := 0) {
this.mode := "Story"
this.bossName := "Aizen"
this.isRaid := false
this.logger := logger
this.keys := ["w", "a", "s", "d", "Space", "Shift"]
this.recording := this.playing := this.cancelled := false
this.shouldStop := 0
this.sent := Map()
this.focusDelay := 0
this.pathingDelay := 1000
OnExit(ObjBindMethod(this, "Cancel"))
}
Log(message) {
if this.logger
this.logger.Call(message)
}
Focused() => WinActive("ahk_exe RobloxPlayerBeta.exe")
Physical(key) => GetKeyState(key, "P")
Now() => CrusadersRuntime.Tick() - this.focusDelay
Label() => this.mode = "Daily Challenges" ? "Daily challenge route" : this.mode = "Samurai Match" ? "Samurai acts 2-3 match route" : this.mode = "Challenges" ? "Challenge route" : this.mode = "Boss Rush" ? "Boss Rush NPC route" : this.isRaid ? "Raid route" : "Shared stage route"
BuiltinEvents() {
if this.mode = "Daily Challenges" {
if !CrusadersRouteRecorder.DailySteps.Length
throw Error("Daily challenge route needs to be recorded first.")
steps := CrusadersRouteRecorder.DailySteps
} else if this.mode = "Samurai Match"
steps := [[0, "s", 1], [3016, "d", 1], [3219, "d", 0],
[8672, "s", 0], [9016, "a", 1], [9360, "a", 0]]
else if this.mode = "Challenges"
steps := [[0, "Shift", 1], [63, "Shift", 0], [266, "d", 1],
[6125, "d", 0], [6344, "w", 1], [10375, "w", 0]]
else if this.mode = "Boss Rush" {
if this.bossName = "Aizen"
steps := [[0, "Shift", 1], [94, "Shift", 0], [344, "a", 1], [5469, "a", 0]]
else if this.bossName = "Makima"
steps := [[0, "a", 1], [1156, "a", 0], [1500, "s", 1], [3015, "s", 0]]
else
throw Error("No built-in route for this Boss Rush.")
} else if this.isRaid || this.mode = "Story" || this.mode = "Infinite" || this.mode = "Legend Stages" {
steps := this.isRaid ? [[0, "Shift", 1], [94, "Shift", 0], [454, "w", 1],
[454, "a", 1], [5188, "a", 0], [7594, "w", 0]]
: [[0, "Shift", 1], [94, "Shift", 0], [203, "a", 1], [344, "w", 1],
[2109, "w", 0], [3375, "a", 0], [3844, "w", 1], [5656, "a", 1],
[7406, "a", 0], [7422, "d", 1], [9203, "w", 0], [9203, "d", 0]]
} else
throw Error("No built-in walking route for this gamemode.")
events := []
for step in steps
events.Push({time: step[1], key: step[2], down: step[3]})
this.Validate(events)
return events
}
PlaybackEvents() => this.BuiltinEvents()
Validate(events) {
if events.Length < 2 || events.Length > 2000
throw Error("Record a walking route before saving (2-2000 events).")
held := Map()
previous := -1
for event in events {
if !RegExMatch(event.key, "^(w|a|s|d|Space|Shift)$") || event.time < previous
|| event.time < 0 || event.time > 120000 || (event.down != 0 && event.down != 1)
throw Error("Invalid movement event in route file.")
if !!(held.Has(event.key) && held[event.key]) = !!event.down
throw Error("Route key presses/releases must be balanced.")
held[event.key] := !!event.down
previous := event.time
}
for key, down in held
if down
throw Error("Route ends with a held movement key.")
if events[1].time != 0 || events[-1].time <= 0
throw Error("Route must begin at 0 ms and contain actual movement duration.")
}
SendKey(key, down) {
SendEvent("{" key (down ? " down}" : " up}"))
this.sent[key] := !!down
}
Release() {
for key, down in this.sent
if down
this.SendKey(key, false)
}
Cancel(*) {
this.cancelled := true
this.recording := false
this.Release()
}
Check() {
if this.cancelled
return false
if this.shouldStop && this.shouldStop.Call()
return false
if !this.Focused() {
held := this.sent.Clone()
this.Release()
started := CrusadersRuntime.Tick()
try {
if !CrusadersRuntime.EnsureFocus("ahk_exe RobloxPlayerBeta.exe", this.shouldStop)
return false
} finally this.focusDelay += CrusadersRuntime.Tick() - started
if this.cancelled || (this.shouldStop && this.shouldStop.Call())
return false
for key, down in held
if down && key != "Shift"
this.SendKey(key, true)
}
return true
}
Wait(milliseconds) {
deadline := this.Now() + Max(0, milliseconds)
while this.Now() < deadline {
if !this.Check()
return false
Sleep(Min(10, Max(1, deadline - this.Now())))
}
return this.Check()
}
MenuBitmap(bitmap, ocr) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
throw Error("Route test needs an 800 x 599 Roblox client.")
if this.mode = "Challenges" || this.mode = "Daily Challenges"
return RegExMatch(ocr.Read(bitmap, 235, 202, 330, 42), "i)Join\s+Matchmaking")
&& RegExMatch(ocr.Read(bitmap, 260, 333, 135, 39), "i)Play\s*Here")
if this.mode = "Boss Rush"
return RegExMatch(ocr.Read(bitmap, 250, 473, 310, 40), this.bossName = "Makima" ? "i)^Continue$" : "i)Open\s*Boss\s*Rush")
&& RegExMatch(ocr.Read(bitmap, 240, 320, 120, 30), this.bossName = "Makima" ? "i)Denju" : "i)A[y i]?zen")
heading := ocr.Read(bitmap, 465, 174, 90, 29)
button := ocr.Read(bitmap, 540, 418, 100, 37)
if this.isRaid
return RegExMatch(ocr.Read(bitmap, 394, 211, 290, 47), "i)\bRaid\s*:")
&& RegExMatch(Trim(button), "i)^Select$")
return RegExMatch(Trim(heading), "i)^Story\s*Stages$") && RegExMatch(Trim(button), "i)^Select$")
}
MenuVisible() {
AADisplay.UsePhysicalPixels()
WinGetClientPos(&x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe")
bitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
if !bitmap
throw Error("Could not capture stage-selection menu.")
try return this.MenuBitmap(bitmap, this.ocr)
finally Gdip_DisposeImage(bitmap)
}
InteractNpc() {
if !this.Wait(300)
return false
SendEvent("{e down}")
try Sleep(60)
finally SendEvent("{e up}")
this.Log("Boss Rush NPC: E interaction sent")
return true
}
Test(shouldStop := 0) {
if this.mode = "Event"
throw Error("Hunter Mayhem uses its area indicator; no walking route is needed.")
if this.recording || this.playing
throw Error("Finish recording before testing a route.")
for key in this.keys
if this.Physical(key)
throw Error("Release movement keys before testing a route.")
events := this.PlaybackEvents()
this.cancelled := false
this.shouldStop := shouldStop
this.playing := true
token := Gdip_Startup()
try {
this.ocr := this.mode = "Samurai Match" ? 0 : CrusadersOcr()
if !this.Check()
return false
if this.mode != "Samurai Match" && this.MenuVisible()
throw Error("Entrance menu is already open; return to the " (this.mode = "Challenges" ? "Challenges" : this.isRaid ? "Raid" : "Story") " arrival point first.")
this.Log("Pathing delay: " this.pathingDelay " ms")
if !this.Wait(this.pathingDelay)
return false
this.Log(this.Label() " playback started")
started := this.Now()
for event in events {
if !this.Wait(event.time - (this.Now() - started))
return false
this.SendKey(event.key, event.down)
}
this.Release()
if this.mode = "Samurai Match" {
this.Log(this.Label() " playback finished; check the destination visually")
return true
}
if this.mode = "Boss Rush" && !this.InteractNpc()
return false
deadline := this.Now() + (this.mode = "Challenges" || this.mode = "Daily Challenges" ? 60000 : 5000)
if this.mode = "Challenges" || this.mode = "Daily Challenges"
this.Log("Waiting for challenge matchmaking")
frames := 0
loop {
if !this.Check()
return false
frames := this.MenuVisible() ? frames + 1 : 0
if frames >= 2 {
this.Log(this.Label() " verified: " (this.mode = "Challenges" ? "Join Matchmaking" : this.mode = "Boss Rush" ? this.bossName " NPC menu" : "stage-selection menu") " detected")
return true
}
if this.Now() >= deadline
throw Error("Route finished but stage-selection menu was not detected; no stage clicks sent.")
if !this.Wait(150)
return false
}
} finally {
this.Release()
this.playing := false
this.shouldStop := 0
if this.HasOwnProp("ocr") && this.ocr
this.ocr.Dispose()
this.ocr := 0
if token
Gdip_Shutdown(token)
}
}
}
FindCrusadersStart(&buttonX, &buttonY) {
if !WinActive("ahk_exe RobloxPlayerBeta.exe")
return false
WinGetClientPos(, , &width, &height, "ahk_exe RobloxPlayerBeta.exe")
if width != 800 || (height != 599 && height != 600)
throw Error("Restore Roblox to an 800 x 599 or 800 x 600 client. Current size: " width " x " height)
if CrusadersDetection.Configured("vote-yes")
return CrusadersDetection.Center("vote-yes", &buttonX, &buttonY)
CoordMode("Pixel", "Client")
moduleDirectory := A_ScriptDir "\Other"
directory := moduleDirectory "\..\Images\Detection\Prompts"
if !CrusadersDetection.Search("start", &promptX, &promptY)
return false
settings := CrusadersDetection.Get("start")
buttonX := promptX + settings.dx
buttonY := promptY + settings.dy
if buttonX >= width || buttonY >= height
return false
return true
}
class CrusadersDetection {
static definitions := Map(
"leaderboard-close", {name:"Leaderboard Close", group:"Menus", file:"AA\leaderboard-close.png", kind:"Image", x:630, y:64, w:28, h:19, tolerance:25, frames:2, cx:630, cy:64, cw:28, ch:19},
"upgrade-0", {name:"Upgrade 0", group:"Units", file:"AA\upgrade-0.png", kind:"Image", x:155, y:180, w:140, h:65, tolerance:25, frames:2, cx:165, cy:190, cw:115, ch:40},
"upgrade-1", {name:"Upgrade 1", group:"Units", file:"AA\upgrade-1.png", kind:"Image", x:155, y:180, w:140, h:65, tolerance:25, frames:2, cx:165, cy:190, cw:115, ch:40},
"upgrade-2", {name:"Upgrade 2", group:"Units", file:"AA\upgrade-2.png", kind:"Image", x:155, y:180, w:140, h:65, tolerance:25, frames:2, cx:165, cy:190, cw:115, ch:40},
"upgrade-3", {name:"Upgrade 3", group:"Units", file:"AA\upgrade-3.png", kind:"Image", x:155, y:180, w:140, h:65, tolerance:25, frames:2, cx:165, cy:190, cw:115, ch:40},
"upgrade-4", {name:"Upgrade 4", group:"Units", file:"AA\upgrade-4.png", kind:"Image", x:155, y:180, w:140, h:65, tolerance:25, frames:2, cx:165, cy:190, cw:115, ch:40},
"upgrade-max-button", {name:"Max Upgrade Button", group:"Units", file:"AA\upgrade-max-button.png", kind:"Image", x:185, y:340, w:130, h:55, tolerance:25, frames:2, cx:220, cy:350, cw:60, ch:35},
"replay", {name:"Replay", group:"Match", file:"AA\replay.png", kind:"Image", x:300, y:95, w:380, h:55, tolerance:25, frames:2, cx:316, cy:101, cw:168, ch:41},
"retry", {name:"Retry", group:"Match", file:"AA\retry.png", kind:"Image", x:300, y:95, w:380, h:55, tolerance:25, frames:2, cx:404, cy:101, cw:168, ch:41},
"next-room", {name:"Next Room", group:"Match", file:"AA\next-room.png", kind:"Image", x:300, y:95, w:380, h:55, tolerance:25, frames:2, cx:404, cy:101, cw:168, ch:41},
"vote-start", {name:"Vote Start", group:"Match", file:"AA\vote-start.png", kind:"Image", x:290, y:25, w:230, h:125, tolerance:25, frames:2, cx:310, cy:45, cw:180, ch:75},
"victory", {name:"Victory / Next", group:"Match", file:"AA\victory.png", kind:"Image", x:125, y:150, w:390, h:275, tolerance:25, frames:2, cx:265, cy:376, cw:110, ch:37},
"next-level", {name:"Next Level", group:"Match", file:"AA\next-level.png", kind:"Image", x:130, y:80, w:545, h:110, tolerance:25, frames:2, cx:494, cy:102, cw:164, ch:40},
"defeat", {name:"Defeat", group:"Match", file:"AA\defeat.png", kind:"Image", x:125, y:150, w:390, h:275, tolerance:25, frames:2, cx:0, cy:0, cw:0, ch:0})
static result := ""
static resultId := ""
static revision := 0
static settings := A_ScriptDir "\Settings\Detection\Overrides.ini"
static overrideRoot := A_ScriptDir "\Images\Detection\Overrides"
static pendingRoot := A_ScriptDir "\Images\Detection\Pending"
static configCache := Map()
static templateCache := Map()
static initialized := false
static snip := 0
static Initialize() {
this.initialized := true
}
static Configured(id) {
this.Initialize()
return this.definitions.Has(id) && !!FileExist(this.Path(id))
}
static Get(id) {
this.Initialize()
if !this.definitions.Has(id)
throw Error("Unknown detector")
if this.configCache.Has(id)
return this.configCache[id].Clone()
d := this.definitions[id].Clone()
if Integer(IniRead(this.settings, id, "ImageMatch", "0"))
d.kind := "Image"
for key in ["x", "y", "w", "h", "tolerance", "frames"]
d.%key% := Integer(IniRead(this.settings, id, key, d.%key%))
if d.kind = "Image"
for key in ["cx", "cy", "cw", "ch"]
d.%key% := Integer(IniRead(this.settings, id, key, d.%key%))
if id = "start"
for key in ["dx", "dy"]
d.%key% := Integer(IniRead(this.settings, id, key, d.%key%))
if d.kind = "Lettering"
d.cx := d.x, d.cy := d.y, d.cw := d.w, d.ch := d.h
this.Validate(d)
this.configCache[id] := d.Clone()
return d
}
static Validate(d) {
if d.x < 0 || d.y < 0 || d.w < 1 || d.h < 1 || d.x + d.w > 800 || d.y + d.h > 600
throw Error("Search region must fit inside 800 x 600")
if d.tolerance < 0 || d.tolerance > 255 || d.frames < 1 || d.frames > 5
throw Error("Tolerance must be 0-255; confirmation frames must be 1-5")
if d.cx < 0 || d.cy < 0 || d.cw < 0 || d.ch < 0 || d.cx + d.cw > 800 || d.cy + d.ch > 600
|| (!d.cw != !d.ch)
throw Error("Capture region must fit inside 800 x 600")
if d.HasOwnProp("dx") && (d.dx < 0 || d.dy < 0 || d.dx > 799 || d.dy > 599)
throw Error("Click offsets must fit inside the viewport")
}
static Path(id) {
d := this.definitions[id]
override := this.overrideRoot "\" id ".png"
return FileExist(override) ? override : A_ScriptDir "\Images\Detection\" d.file
}
static State(includeItems := true) {
if !includeItems
return Map("items", [], "result", this.result, "resultId", this.resultId, "revision", this.revision,
"snipping", Integer(IsObject(this.snip)))
this.Initialize()
items := []
for id, definition in this.definitions {
d := this.Get(id)
p := this.Path(id)
pending := this.pendingRoot "\" id ".png"
hasPending := !!FileExist(pending), hasImage := hasPending || FileExist(p)
items.Push(Map("id", id, "name", d.name, "group", d.group, "kind", d.kind,
"image", hasImage ? StrReplace(SubStr(hasPending ? pending : p, StrLen(A_ScriptDir "\Images\") + 1), "\", "/") : "",
"pending", Integer(hasPending),
"override", Integer(InStr(p, "\Overrides\") > 0), "x", d.x, "y", d.y, "w", d.w, "h", d.h,
"tolerance", d.tolerance, "frames", d.frames, "cx", d.cx, "cy", d.cy, "cw", d.cw, "ch", d.ch,
"dx", d.HasOwnProp("dx") ? d.dx : 0, "dy", d.HasOwnProp("dy") ? d.dy : 0))
}
return Map("items", items, "result", this.result, "resultId", this.resultId, "revision", this.revision,
"snipping", Integer(IsObject(this.snip)))
}
static Search(id, &x, &y) {
d := this.Get(id)
if !FileExist(this.Path(id))
return false
loop d.frames {
if !ImageSearch(&x, &y, d.x, d.y, d.x + d.w - 1, d.y + d.h - 1,
"*" d.tolerance " " this.Path(id))
return false
if A_Index < d.frames
Sleep(100)
}
return true
}
static FindBitmap(bitmap, id, &x := 0, &y := 0) {
if !this.Configured(id)
return false
d := this.Get(id)
path := this.Path(id)
stamp := path "|" FileGetTime(path, "M") "|" FileGetSize(path)
if !this.templateCache.Has(id) || this.templateCache[id].stamp != stamp {
reference := Gdip_CreateBitmapFromFile(path)
if !reference
throw Error("Cannot read detection reference: " d.name)
locked := false
try {
rw := Gdip_GetImageWidth(reference), rh := Gdip_GetImageHeight(reference)
if rw < 2 || rh < 2 || rw > 800 || rh > 600
throw Error("Unsupported detection image size")
if Gdip_LockBits(reference, 0, 0, rw, rh, &stride, &pixels, &bits, 1) != 0
throw Error("Could not read reference pixels")
locked := true
referenceData := Buffer(rw * rh * 4)
loop rh
DllCall("RtlMoveMemory", "Ptr", referenceData.Ptr + (A_Index - 1) * rw * 4,
"Ptr", pixels + (A_Index - 1) * stride, "UPtr", rw * 4)
samples := this.ReferenceSamples(referenceData,rw,rh)
this.templateCache[id] := {stamp:stamp, width:rw, height:rh, pixels:referenceData, samples:samples}
} finally {
if locked
Gdip_UnlockBits(reference, &bits)
Gdip_DisposeImage(reference)
}
}
t := this.templateCache[id]
right := Min(d.x + d.w, Gdip_GetImageWidth(bitmap)) - t.width
bottom := Min(d.y + d.h, Gdip_GetImageHeight(bitmap)) - t.height
if right < d.x || bottom < d.y
return false
bw := Gdip_GetImageWidth(bitmap), bh := Gdip_GetImageHeight(bitmap)
if Gdip_LockBits(bitmap, 0, 0, bw, bh, &screenStride, &screenPixels, &screenBits, 1) != 0
throw Error("Could not read test pixels")
try {
loop bottom - d.y + 1 {
sy := d.y + A_Index - 1
loop right - d.x + 1 {
sx := d.x + A_Index - 1
candidate := true
for sample in t.samples {
actual := NumGet(screenPixels + (sy + sample.y) * screenStride + (sx + sample.x) * 4, "UInt")
if !this.Similar(actual, sample.color, d.tolerance) {
candidate := false
break
}
}
if !candidate
continue
bad := 0, limit := 0
loop t.height {
ty := A_Index - 1
loop t.width {
tx := A_Index - 1
expected := NumGet(t.pixels, (ty * t.width + tx) * 4, "UInt")
if (expected >> 24) < 128
continue
actual := NumGet(screenPixels + (sy + ty) * screenStride + (sx + tx) * 4, "UInt")
if !this.Similar(actual, expected, d.tolerance)
bad += 1
if bad > limit
break
}
if bad > limit
break
}
if bad <= limit {
x := sx, y := sy
return true
}
}
}
return false
} finally Gdip_UnlockBits(bitmap, &screenBits)
}
static BitmapPoint(bitmap, id) {
if !this.FindBitmap(bitmap, id, &x, &y)
return false
reference := this.templateCache[id]
return {x:x + reference.width // 2, y:y + reference.height // 2}
}
static ReferenceSamples(data, width, height) {
pool := []
loop 16 {
offset := Floor((A_Index-1)*(width*height-1)/15)
color := NumGet(data,offset*4,"UInt")
if (color>>24)>=128
pool.Push({x:Mod(offset,width),y:offset//width,color:color})
}
if pool.Length<4
throw Error("Capture an opaque button or label, not a transparent image")
count := Min(256,width*height)
loop count {
offset := Floor((A_Index-1)*(width*height-1)/(count-1))
color := NumGet(data,offset*4,"UInt")
if (color>>24)>=128
pool.Push({x:Mod(offset,width),y:offset//width,color:color})
}
frequencies := Map()
for sample in pool {
color := sample.color
sample.bucket := ((color>>21)&7)*64+((color>>13)&7)*8+((color>>5)&7)
frequencies[sample.bucket] := frequencies.Get(sample.bucket,0)+1
}
ranks := ""
for index, sample in pool
ranks .= frequencies[sample.bucket] "`t" index "`n"
samples := []
for rank in StrSplit(RTrim(Sort(ranks,"N"),"`n"),"`n") {
samples.Push(pool[Integer(StrSplit(rank,"`t")[2])])
if samples.Length>=16
break
}
return samples
}
static Similar(a, b, tolerance) => Abs((a & 255) - (b & 255)) <= tolerance
&& Abs(((a >> 8) & 255) - ((b >> 8) & 255)) <= tolerance
&& Abs(((a >> 16) & 255) - ((b >> 16) & 255)) <= tolerance
static Stage(id, bitmap, rect) {
d := this.Get(id)
if rect.x < 0 || rect.y < 0 || rect.w < 4 || rect.h < 4 || rect.x + rect.w > 800 || rect.y + rect.h > 600
throw Error("Select at least 4 x 4 pixels inside Roblox")
crop := Gdip_CloneBitmapArea(bitmap, rect.x, rect.y, rect.w, rect.h)
if !crop
throw Error("Could not crop selected pixels")
DirCreate(this.pendingRoot)
pending := this.pendingRoot "\" id ".png"
temporary := pending ".tmp.png"
metadataTemp := pending ".tmp.ini"
published := false
try {
if Gdip_SaveBitmapToFile(crop, temporary) != 0
throw Error("Could not save snip")
IniWrite("cx=" rect.x "`ncy=" rect.y "`ncw=" rect.w "`nch=" rect.h, metadataTemp, "Capture")
FileMove(temporary, pending, true), published := true
FileMove(metadataTemp, pending ".ini", true)
} catch Error as err {
if published
for path in [pending, pending ".ini"]
if FileExist(path)
FileDelete(path)
throw err
} finally {
Gdip_DisposeImage(crop)
for path in [temporary, metadataTemp]
if FileExist(path)
FileDelete(path)
}
this.result := "Capture preview ready. Active reference unchanged."
this.resultId := id
this.revision += 1
}
static Commit(id, image, d) {
this.Validate(d)
token := Gdip_Startup()
bitmap := Gdip_CreateBitmapFromFile(image)
try {
if !bitmap
throw Error("Could not read replacement image")
this.ValidateImage(bitmap)
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
}
override := this.overrideRoot "\" id ".png"
SplitPath(this.settings, , &directory)
DirCreate(directory), DirCreate(this.overrideRoot)
suffix := "." CrusadersRuntime.Tick() ".tmp"
settingsTemp := this.settings suffix
imageTemp := override suffix
hadSettings := !!FileExist(this.settings), hadImage := !!FileExist(override)
originalSettings := hadSettings ? FileRead(this.settings,"RAW") : 0
originalImage := hadImage ? FileRead(override,"RAW") : 0
changedImage := false, changedSettings := false
try {
if hadSettings {
FileCopy(this.settings, settingsTemp)
}
FileCopy(image, imageTemp)
body := "ImageMatch=1`n"
for key in ["x", "y", "w", "h", "tolerance", "frames", "cx", "cy", "cw", "ch"]
body .= key "=" d.%key% "`n"
if d.HasOwnProp("dx")
body .= "dx=" d.dx "`ndy=" d.dy "`n"
IniWrite(RTrim(body, "`n"), settingsTemp, id)
FileMove(imageTemp, override, true), changedImage := true
FileMove(settingsTemp, this.settings, true), changedSettings := true
} catch Error as err {
if changedImage {
if hadImage
this.RestoreBytes(override,imageTemp,originalImage)
else if FileExist(override)
FileDelete(override)
}
if changedSettings && hadSettings
this.RestoreBytes(this.settings,settingsTemp,originalSettings)
throw err
} finally {
for path in [settingsTemp, imageTemp]
if FileExist(path)
FileDelete(path)
}
if this.configCache.Has(id)
this.configCache.Delete(id)
if this.templateCache.Has(id)
this.templateCache.Delete(id)
}
static RestoreBytes(path, temporary, bytes) {
file := FileOpen(temporary,"w")
try file.RawWrite(bytes)
finally file.Close()
FileMove(temporary,path,true)
}
static ValidateImage(bitmap) {
width := Gdip_GetImageWidth(bitmap), height := Gdip_GetImageHeight(bitmap)
if width < 4 || height < 4 || width > 800 || height > 600
throw Error("Reference must be between 4 x 4 and 800 x 600 pixels")
if Gdip_LockBits(bitmap, 0, 0, width, height, &stride, &pixels, &bits, 1) != 0
throw Error("Could not inspect replacement pixels")
try {
lowR := lowG := lowB := 255, highR := highG := highB := 0, opaque := 0
loop height {
row := A_Index - 1
loop width {
color := NumGet(pixels + row * stride + (A_Index - 1) * 4, "UInt")
if (color >> 24) < 128
continue
opaque += 1
r := (color >> 16) & 255, g := (color >> 8) & 255, b := color & 255
lowR := Min(lowR,r), lowG := Min(lowG,g), lowB := Min(lowB,b)
highR := Max(highR,r), highG := Max(highG,g), highB := Max(highB,b)
if opaque >= 16 && Max(highR-lowR,highG-lowG,highB-lowB) >= 32
return true
}
}
throw Error("Reference is blank or too uniform. Include the button text, icon or border.")
} finally Gdip_UnlockBits(bitmap, &bits)
}
static Center(id, &x, &y) {
previous := A_CoordModePixel
CoordMode("Pixel", "Client")
try {
if !this.Search(id, &x, &y)
return false
token := Gdip_Startup()
bitmap := Gdip_CreateBitmapFromFile(this.Path(id))
try {
if !bitmap
throw Error("Could not read button reference")
x += Gdip_GetImageWidth(bitmap) // 2
y += Gdip_GetImageHeight(bitmap) // 2
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
}
return true
} finally CoordMode("Pixel", previous)
}
static Outline(left, top, d) {
for box in [[left + d.x, top + d.y, d.w, 2], [left + d.x, top + d.y + d.h - 2, d.w, 2],
[left + d.x, top + d.y, 2, d.h], [left + d.x + d.w - 2, top + d.y, 2, d.h]] {
outline := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
outline.BackColor := "EF5262"
outline.Show("NA x" box[1] " y" box[2] " w" box[3] " h" box[4])
SetTimer(ObjBindMethod(outline, "Destroy"), -1500)
}
}
static Lettering(bitmap, id) {
d := this.Get(id)
if d.kind = "Image"
return this.FindBitmap(bitmap, id)
reference := Gdip_CreateBitmapFromFile(this.Path(id))
if !reference
throw Error("Detection reference missing: " d.name)
try {
full := Gdip_GetImageWidth(reference) = 800 && Gdip_GetImageHeight(reference) >= 600
if !full && (Gdip_GetImageWidth(reference) != d.w || Gdip_GetImageHeight(reference) != d.h)
return false
hits := 0, total := 0
loop d.h {
y := d.y + A_Index - 1
loop d.w {
x := d.x + A_Index - 1
expected := Gdip_GetPixel(reference, full ? x : x - d.x, full ? y : y - d.y)
if (expected & 255) < 180 || ((expected >> 8) & 255) < 180 || ((expected >> 16) & 255) < 180
continue
actual := Gdip_GetPixel(bitmap, x, y)
total += 1
threshold := d.tolerance ? 256 - d.tolerance : 255
hits += (actual & 255) >= threshold && ((actual >> 8) & 255) >= threshold && ((actual >> 16) & 255) >= threshold
}
}
return total > 50 && hits / total >= 0.85
} finally Gdip_DisposeImage(reference)
}
static Action(action, data) {
AADisplay.UsePhysicalPixels()
id := data["id"]
d := this.Get(id)
override := this.overrideRoot "\" id ".png"
pending := this.pendingRoot "\" id ".png"
if action = "cancel" {
if IsObject(this.snip)
this.snip.Cancel()
return
}
if action != "capture" && IsObject(this.snip)
throw Error("Finish or cancel the snip first")
if action = "capture" {
if IsObject(this.snip)
this.snip.Cancel()
this.snip := CrusadersDetectionSnip(id)
this.snip.Start()
this.result := "Select a rectangle in Roblox."
this.resultId := id
this.revision += 1
return
}
DirCreate(this.overrideRoot)
SplitPath(this.settings, , &settingsDirectory)
DirCreate(settingsDirectory)
if action = "save" {
keys := ["x", "y", "w", "h", "tolerance", "frames"]
if d.kind = "Image"
for key in ["cx", "cy", "cw", "ch"]
keys.Push(key)
if id = "start"
for key in ["dx", "dy"]
keys.Push(key)
for key in keys {
if !data.Has(key) || !IsInteger(data[key])
throw Error("Enter whole numbers for detection settings")
d.%key% := Integer(data[key])
}
this.Validate(d)
body := ""
for key in keys
body .= key "=" d.%key% "`n"
temporary := this.settings "." CrusadersRuntime.Tick() ".tmp"
try {
if FileExist(this.settings)
FileCopy(this.settings, temporary)
IniWrite(RTrim(body, "`n"), temporary, id)
FileMove(temporary, this.settings, true)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
this.configCache.Delete(id)
this.result := "Detection settings saved."
} else if action = "reset" {
if FileExist(override)
FileDelete(override)
if FileExist(this.settings)
IniDelete(this.settings, id)
if FileExist(pending)
FileDelete(pending)
if FileExist(pending ".ini")
FileDelete(pending ".ini")
this.configCache.Delete(id)
this.result := "Default reference and settings restored."
} else if action = "accept" {
if !FileExist(pending)
throw Error("No capture to accept")
if FileExist(pending ".ini") {
for key in ["cx", "cy", "cw", "ch"]
d.%key% := Integer(IniRead(pending ".ini", "Capture", key, d.%key%))
d.x := Max(0, d.cx - 64), d.y := Max(0, d.cy - 64)
d.w := Min(800, d.cx + d.cw + 64) - d.x
d.h := Min(600, d.cy + d.ch + 64) - d.y
}
if d.kind = "Lettering"
d.tolerance := 25
this.Commit(id, pending, d)
FileDelete(pending)
if FileExist(pending ".ini")
FileDelete(pending ".ini")
this.result := "Capture accepted. Default image preserved."
} else if action = "discard" {
if FileExist(pending)
FileDelete(pending)
if FileExist(pending ".ini")
FileDelete(pending ".ini")
this.result := "Capture discarded. Active reference unchanged."
} else if action = "replace" {
initial := this.Path(id)
SplitPath(initial, , &imageDirectory)
DirCreate(imageDirectory)
global macroWindow
if IsSet(macroWindow) {
macroWindow.detectionDialog := true
macroWindow.gui.Opt("+OwnDialogs")
}
try path := FileSelect(1, initial, "Replace " d.name, "Images (*.png; *.bmp; *.jpg)")
finally {
if IsSet(macroWindow)
macroWindow.detectionDialog := false
}
if path = ""
return
token := Gdip_Startup()
bitmap := Gdip_CreateBitmapFromFile(path)
replacement := pending ".replacement.png"
prepared := false
try {
if !bitmap
throw Error("Could not read this image")
if d.kind = "Lettering" {
if Gdip_GetImageWidth(bitmap) = 800 && Gdip_GetImageHeight(bitmap) >= 600 {
cropped := Gdip_CloneBitmapArea(bitmap, d.x, d.y, d.w, d.h)
if !cropped
throw Error("Could not crop the menu title")
Gdip_DisposeImage(bitmap)
bitmap := cropped
}
}
if Gdip_GetImageWidth(bitmap) > 800 || Gdip_GetImageHeight(bitmap) > 600
throw Error("Reference exceeds the game viewport")
if Gdip_GetImageWidth(bitmap) > d.w || Gdip_GetImageHeight(bitmap) > d.h
throw Error("Replacement is larger than the search region. Widen the region first.")
if d.kind = "Lettering"
d.tolerance := 25
DirCreate(this.pendingRoot)
if Gdip_SaveBitmapToFile(bitmap, replacement) != 0
throw Error("Could not save replacement")
prepared := true
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
if !prepared && FileExist(replacement)
FileDelete(replacement)
}
try this.Commit(id, replacement, d)
finally FileDelete(replacement)
this.result := "Replacement saved. Default image preserved."
if FileExist(pending)
FileDelete(pending)
if FileExist(pending ".ini")
FileDelete(pending ".ini")
} else if action = "test" {
if FileExist(pending)
throw Error("Use or discard the capture before testing")
if !this.Configured(id)
throw Error("Capture or replace an image before testing")
target := "ahk_exe RobloxPlayerBeta.exe"
if !WinExist(target) || WinGetMinMax(target) = -1
throw Error("Open and restore Roblox before capturing or testing")
WinGetClientPos(&left, &top, &width, &height, target)
if width != 800 || (height != 600 && height != 600)
throw Error("Roblox client must be 800 x 600 or 800 x 600")
token := Gdip_Startup()
bitmap := 0
try {
{
previous := A_CoordModePixel
CoordMode("Pixel", "Screen")
matches := 0
try {
loop d.frames {
if d.kind = "Image"
found := ImageSearch(&px, &py, left + d.x, top + d.y, left + d.x + d.w - 1,
top + d.y + d.h - 1, "*" d.tolerance " " this.Path(id))
else {
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Test capture failed")
found := this.Lettering(bitmap, id)
Gdip_DisposeImage(bitmap), bitmap := 0
}
matches += found
if A_Index < d.frames
Sleep(100)
}
} finally CoordMode("Pixel", previous)
this.result := (matches = d.frames ? "Matched" : "Not matched") " - " matches "/" d.frames " frames. No clicks sent."
if matches = d.frames {
reference := Gdip_CreateBitmapFromFile(this.Path(id))
try area := {x:d.kind = "Image" ? px - left : d.x, y:d.kind = "Image" ? py - top : d.y,
w:Gdip_GetImageWidth(reference), h:Gdip_GetImageHeight(reference)}
finally Gdip_DisposeImage(reference)
this.Outline(left, top, area)
} else
this.Outline(left, top, d)
}
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
}
} else
throw Error("Unknown detection action")
this.revision += 1
this.resultId := id
CrusadersLog(d.name ": " this.result)
}
}
class CrusadersDetectionSnip {
__New(id) {
this.id := id
this.closed := false
this.dragging := false
this.bitmap := 0
this.token := 0
}
Start(target := "ahk_exe RobloxPlayerBeta.exe") {
AADisplay.UsePhysicalPixels()
if !WinExist(target) || WinGetMinMax(target) = -1
throw Error("Open and restore Roblox before capturing")
WinGetClientPos(&left, &top, &width, &height, target)
if width != 800 || (height != 600 && height != 600)
throw Error("Roblox client must be 800 x 600 or 800 x 600")
this.left := left, this.top := top
this.target := target
this.token := Gdip_Startup()
try {
this.bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !this.bitmap
throw Error("Could not freeze Roblox for snipping")
this.gui := Gui("-Caption -DPIScale +AlwaysOnTop +ToolWindow")
this.gui.MarginX := 0, this.gui.MarginY := 0
handle := Gdip_CreateHBITMAPFromBitmap(this.bitmap)
if !handle
throw Error("Could not display snipping image")
try this.gui.AddPicture("x0 y0 w800 h600", "HBITMAP:" handle)
finally DllCall("DeleteObject", "Ptr", handle)
this.borders := []
loop 4
this.borders.Push(this.gui.AddText("x0 y0 w1 h1 BackgroundEF5262 Disabled", ""))
this.gui.OnEvent("Escape", (*) => this.Cancel())
this.gui.OnEvent("Close", (*) => this.Cancel())
this.gui.Show("x" left " y" top " w800 h600")
this.poller := ObjBindMethod(this, "Poll")
this.deadline := CrusadersRuntime.Tick() + 60000
this.waitRelease := GetKeyState("LButton", "P")
SetTimer(this.poller, 16)
} catch Error as err {
this.Close()
throw err
}
}
static Rect(x1, y1, x2, y2) {
x1 := Max(0, Min(800, x1)), x2 := Max(0, Min(800, x2))
y1 := Max(0, Min(600, y1)), y2 := Max(0, Min(600, y2))
return {x:Min(x1,x2), y:Min(y1,y2), w:Abs(x2-x1), h:Abs(y2-y1)}
}
Poll(*) {
AADisplay.UsePhysicalPixels()
if this.closed
return
if CrusadersRuntime.Tick() >= this.deadline || !WinExist(this.target) {
this.Cancel()
return
}
previous := A_CoordModeMouse
CoordMode("Mouse", "Screen")
try MouseGetPos(&mx, &my)
finally CoordMode("Mouse", previous)
x := Max(0, Min(800, mx - this.left)), y := Max(0, Min(600, my - this.top))
this.Selection(x, y, GetKeyState("LButton", "P"),
mx >= this.left && mx < this.left + 800 && my >= this.top && my < this.top + 600)
}
Selection(x, y, down, inside) {
if this.closed
return
if this.waitRelease {
this.waitRelease := down
return
}
if !this.dragging {
if !down || !inside
return
this.dragging := true, this.x := x, this.y := y
}
rect := CrusadersDetectionSnip.Rect(this.x, this.y, x, y)
for index, box in [[rect.x,rect.y,rect.w,2], [rect.x,rect.y+Max(0,rect.h-2),rect.w,2],
[rect.x,rect.y,2,rect.h], [rect.x+Max(0,rect.w-2),rect.y,2,rect.h]]
this.borders[index].Move(box[1],box[2],Max(1,box[3]),Max(1,box[4]))
if down
return
this.dragging := false
if rect.w < 4 || rect.h < 4
return
try {
CrusadersDetection.Stage(this.id, this.bitmap, rect)
CrusadersLog(CrusadersDetection.Get(this.id).name ": Capture preview ready")
} catch Error as err {
CrusadersDetection.result := err.Message
CrusadersDetection.resultId := this.id
CrusadersDetection.revision += 1
} finally this.Close()
}
Cancel() {
if this.closed
return
CrusadersDetection.result := "Capture cancelled. Active reference unchanged."
CrusadersDetection.resultId := this.id
CrusadersDetection.revision += 1
this.Close()
}
Close() {
if this.closed
return
this.closed := true
if this.HasOwnProp("poller")
SetTimer(this.poller, 0)
if this.HasOwnProp("gui")
this.gui.Destroy()
if this.bitmap
Gdip_DisposeImage(this.bitmap)
if this.token
Gdip_Shutdown(this.token)
this.bitmap := 0, this.token := 0
CrusadersDetection.snip := 0
global macroWindow
if IsSet(macroWindow) && macroWindow.HasOwnProp("core")
macroWindow.PushState()
}
}
class CrusadersStartStability {
__New() {
this.since := -1
this.x := this.y := 0
}
Observe(found, x, y, now) {
if !found {
this.since := -1
return false
}
if this.since < 0 || x != this.x || y != this.y {
this.since := now
this.x := x
this.y := y
return false
}
return now - this.since >= 350
}
}
class CrusadersPreflight {
static Issue(message, page := "gamemodes", mode := 0, index := 0) => Map("message",message,"page",page,"mode",mode,"index",index)
static Config(model, modeNumber := 0) {
issues := [], active := 0, coordinates := false
for number, item in model.indexes {
if !item.enabled || !item.configured
continue
active += 1
prefix := "Index " number ": "
if item.beforeStart && item.wave > 0
issues.Push(this.Issue(prefix "Before Starting needs On Wave set to 0.","indexes",modeNumber,number))
if item.recording != "" {
try CrusadersRecording.Load(item.recording)
catch Error as err
issues.Push(this.Issue(prefix "Recording '" item.recording "' is missing or invalid. Choose another recording or save it again in Recorder.","indexes",modeNumber,number))
continue
}
coordinates := true
if item.x < 0 || item.y < 0 || item.x >= model.mapWidth || item.y >= model.mapHeight
issues.Push(this.Issue(prefix "Choose coordinates inside the saved map using Select Coordinates.","indexes",modeNumber,number))
if item.slot <= 6 && item.priority != "First"
issues.Push(this.Issue(prefix "Priority changes are not supported yet. Set Priority to First.","indexes",modeNumber,number))
}
if !active
issues.Push(this.Issue("This config has no enabled, configured indexes. Set up at least one index.","indexes",modeNumber,1))
if coordinates && (!FileExist(model.imagePath) || model.mapWidth != 800 || (model.mapHeight != 599 && model.mapHeight != 600))
issues.Push(this.Issue("Capture this config's map with " model.preferences.Get("CaptureKey","F5") " at the normal Roblox size before setting coordinates.","indexes",modeNumber,1))
return issues
}
static Check(window, model) {
issues := [], enabled := 0
if window.inputRecorder.recording || window.inputRecorder.playing
issues.Push(this.Issue("Stop recording or playback in Recorder before starting.","recorder"))
if IsObject(CrusadersDetection.snip)
issues.Push(this.Issue("Finish or cancel the image capture in Detection before starting.","detection"))
if CrusadersRuntime.InputBusy(window) {
if !issues.Length
issues.Push(this.Issue("Finish the active camera or route action before starting.","main"))
return issues
}
seen := Map()
for number, item in window.tasks.items {
if !item.enabled
continue
enabled += 1
try {
window.tasks.Validate(item)
if item.mode = "Infinity Castle" {
issues.Push(this.Issue("Infinity Castle is a placeholder. Gameplay automation is not available yet.","gamemodes",number))
continue
}
if item.mode = "Events"
continue
path := window.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
if !FileExist(path) {
issues.Push(this.Issue("Mode " number ": Config '" item.config "' is missing. Edit this mode and choose an existing config.","gamemodes",number))
continue
}
if seen.Has(StrLower(path))
continue
seen[StrLower(path)] := true
candidate := path = model.path ? model : CrusadersSelector(path,"",model.settingsFile,model.imageRoot)
candidate.Validate()
for issue in this.Config(candidate,number) {
issue["message"] := "Mode " number " / " CrusadersMapName(path,item.mode) ": " issue["message"]
issues.Push(issue)
}
} catch Error as err
issues.Push(this.Issue("Mode " number ": " err.Message " Edit this mode or its config before starting.","gamemodes",number))
}
if !enabled
issues.Push(this.Issue("Add at least one enabled mode in Modes before starting."))
else
for relative in ["Units\Speedcart-Upgrade0.png","Units\Speedcart-Upgrade1.png","Units\Speedcart-UpgradeMax.png","Prompts\PlacementCancel.png"]
if !FileExist(A_ScriptDir "\Images\Detection\" relative)
issues.Push(this.Issue("Detection image '" relative "' is missing. Restore the Images folder from the macro download.","detection"))
return issues
}
}
class CrusadersCatalog {
static Modes := ["Story", "Infinite", "Legend Stages", "Raids", "Infinity Mansion", "Dungeons", "Portals", "Events"]
static CastleMaps := []
static DefaultContractPriority := "Rookie Contract|Standard Contract|Elite Contract|Legendary Contract|Mythic Contract|Godlike Contract"
static ContractPriorities(value) {
names := StrSplit(value, "|")
valid := StrSplit(this.DefaultContractPriority, "|")
seen := Map()
for name in names {
if seen.Has(name) || !InStr("|" this.DefaultContractPriority "|", "|" name "|")
throw Error("Invalid or duplicate contract priority: " name)
seen[name] := true
}
if names.Length = 5 && !seen.Has("Godlike Contract")
names.Push("Godlike Contract")
if names.Length != valid.Length
throw Error("Contract priority must contain all six contracts.")
return names
}
static NormalizeContractPriority(value) {
normalized := ""
for name in this.ContractPriorities(value)
normalized .= (normalized = "" ? "" : "|") name
return normalized
}
static StoryMaps := ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District"]
static RaidMaps := ["Ant Kingdom [Midnight]", "Sacred Planet", "Strange Town", "Ruined City [The Menace]", "Cursed Festival", "Future City [Tyrant's Invasion]", "Storm Hideout", "Future City", "Nightmare Train", "Sand Village"]
static ChallengeMaps := this.ChallengeMapList()
static ChallengeMapList() {
names := this.StoryMaps.Clone()
seen := Map()
for name in names
seen[name] := true
for raid in this.RaidMaps {
canonical := AADefaultPaths.CanonicalName(raid)
if !seen.Has(canonical)
names.Push(canonical),seen[canonical]:=true
}
return names
}
static MansionMaps := ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District", "Sacred Planet", "Strange Town", "Cursed Festival", "Future City", "Storm Hideout", "Nightmare Train", "Assassin Park", "Spirit Town"]
static Maps := Map("Events",["April Fools"],"Portals",["Portals"],"Challenges",this.ChallengeMaps,"Infinity Mansion", this.MansionMaps, "Story", this.StoryMaps, "Infinite", this.StoryMaps,
"Legend Stages", ["Magic Hills [Elf Invasion]", "Spirit Invasion", "Space Center", "Fabled Kingdom [Generals]", "Ruined City [Midnight]", "Virtual Dungeon [Bosses]", "Dungeon Throne", "Rain Village"], "Raids", this.RaidMaps,
"Boss Rush", [], "Event", [], "Infinity Castle", [], "InfinityCastle", [])
static StageCounts := Map("Magic Hills [Elf Invasion]", 3, "Spirit Invasion", 3, "Space Center", 3, "Fabled Kingdom [Generals]", 3, "Ruined City [Midnight]", 6, "Virtual Dungeon [Bosses]", 3, "Dungeon Throne", 3, "Rain Village", 3, "Ant Kingdom [Midnight]", 1, "Sacred Planet", 5, "Strange Town", 5, "Ruined City [The Menace]", 1, "Cursed Festival", 5, "Future City [Tyrant's Invasion]", 5, "Storm Hideout", 5, "Future City", 1, "Nightmare Train", 1, "Sand Village", 1)
static Folder(mode) {
return mode = "Legend" ? "Legend Stages" : mode = "Raid" ? "Raids" : mode = "Infinity Castle" ? "InfinityCastle" : mode
}
static ConfigMaps(mode) => this.Maps[mode]
static ConfigRelative(relative) {
if relative = "Legend Stages/SpiritTownLegend.txt"
return "Legend Stages/SpiritInvasionLegend.txt"
for alias,canonical in AADefaultPaths.Aliases
if alias != canonical && relative = "Infinity Mansion/" RegExReplace(alias,"[^A-Za-z0-9]","") "Mansion.txt"
return "Infinity Mansion/" RegExReplace(canonical,"[^A-Za-z0-9]","") "Mansion.txt"
relative := RegExReplace(relative,"i)Act[1-6](?=(?:Story|Legend|Raid)\.txt$)","")
for name in this.Maps["Story"]
if relative = "Challenges/" StrReplace(name," ","") "C.txt"
return "Challenges/" this.Filename("Challenges",name,1)
return relative
}
static MigrateMansion(root, settingsFile := "") {
this.MigrateSpiritLegend(root)
for alias,canonical in AADefaultPaths.Aliases {
if alias = canonical
continue
old := root "\Infinity Mansion\" RegExReplace(alias,"[^A-Za-z0-9]","") "Mansion.txt"
target := root "\Infinity Mansion\" RegExReplace(canonical,"[^A-Za-z0-9]","") "Mansion.txt"
if !FileExist(old) || !FileExist(target)
continue
left := FileRead(old), right := FileRead(target)
blank := IniRead(old,"Selector","Count","-1") = "0" && IniRead(target,"Selector","Count","-1") = "0"
if blank && RegExReplace(left,"im)^(Map|DisplayName)=[^\r\n]*","$1=" canonical) = RegExReplace(right,"im)^(Map|DisplayName)=[^\r\n]*","$1=" canonical)
FileDelete(old)
else {
variants := root "\..\MansionVariants"
DirCreate(variants)
saved := variants "\" RegExReplace(alias,"[^A-Za-z0-9]","") "Mansion.txt"
if FileExist(saved) && FileRead(saved) != left
saved := variants "\" RegExReplace(alias,"[^A-Za-z0-9]","") "-" A_Now "-" DllCall("GetTickCount64","UInt64") ".txt"
if FileExist(saved) && FileRead(saved) = left
FileDelete(old)
else
FileMove(old,saved)
readme := variants "\README.txt"
if !FileExist(readme)
FileAppend("Customized legacy Mansion variants were moved here during map consolidation. Active canonical configs remain in Configs/Infinity Mansion. Original indexes, settings and image references are preserved; variants are excluded from automatic category exports.`n",readme,"UTF-8")
}
}
if settingsFile != "" && FileExist(settingsFile) {
saved := IniRead(settingsFile,"Config","Path","")
normalized := StrReplace(this.ConfigRelative(StrReplace(saved,"\","/")),"/","\")
if saved != normalized && !FileExist(root "\" saved)
IniWrite(normalized,settingsFile,"Config","Path")
}
}
static MigrateSpiritLegend(root) {
old := root "\Legend Stages\SpiritTownLegend.txt", target := root "\Legend Stages\SpiritInvasionLegend.txt"
if !FileExist(old)
return
if !FileExist(target) || IniRead(target,"Selector","Count","0") = "0" {
FileCopy(old,target,1)
IniWrite("Spirit Invasion",target,"Settings","Map")
if IniRead(target,"Settings","DisplayName","") = "Spirit Town"
IniWrite("Spirit Invasion",target,"Settings","DisplayName")
FileDelete(old)
} else if IniRead(old,"Selector","Count","0") = "0"
FileDelete(old)
else {
directory := root "\..\MansionVariants"
DirCreate(directory)
saved := directory "\SpiritTownLegend.txt"
if FileExist(saved)
saved := directory "\SpiritTownLegend-" A_Now "-" DllCall("GetTickCount64","UInt64") ".txt"
FileMove(old,saved)
}
}
static MigrateChallenges(root, settingsFile := "") {
for name in this.Maps["Challenges"] {
old := root "\Challenges\" StrReplace(name," ","") "C.txt"
target := this.Resolve(root,"Challenges",name,1)
if FileExist(old) {
if FileExist(target)
throw Error("Both legacy and renamed challenge configs exist: " name ". Rename or remove the duplicate before continuing.")
FileMove(old,target)
}
}
if settingsFile != "" && FileExist(settingsFile) {
saved := IniRead(settingsFile,"Config","Path","")
for name in this.Maps["Challenges"]
if saved = "Challenges\" StrReplace(name," ","") "C.txt"
IniWrite("Challenges\" this.Filename("Challenges",name,1),settingsFile,"Config","Path")
}
}
static ImageDirectory(root, mode) {
mode := this.Folder(mode)
folder := mode = "Infinite" ? "Story\Infinites" : mode = "Legend Stages" ? "LegendStages" : mode
return this.Maps.Has(mode) || mode = "Challenges" ? root "\" folder : root
}
static ResolveMapImage(directory, imageName, mode, mapName := "") {
path := directory "\" imageName
if this.Folder(mode)="Challenges" && !FileExist(path) {
for name in this.Maps["Story"] {
stem := StrReplace(name," ","")
if imageName=stem "Challenge.png" && FileExist(directory "\" stem "C.png")
path := directory "\" stem "C.png"
}
}
sharedByMap := mapName != "" ? A_ScriptDir "\Images\Defaults\" RegExReplace(AADefaultPaths.CanonicalName(mapName),"[^A-Za-z0-9]","") ".png" : ""
placeholder := imageName = "Transparent.png" && AAInstalledAssets.IsPlaceholder(path)
bundledLegacy := imageName != "Transparent.png" && sharedByMap != "" && FileExist(sharedByMap) && FileExist(path) && AAInstalledAssets.IsBundledDefault(path)
if placeholder || !FileExist(path) || bundledLegacy {
stem := RegExReplace(imageName,"i)(Story|Infinite|Challenge|Mansion|Legend|Raid)?\.png$","")
if this.Folder(mode) = "Legend Stages" || this.Folder(mode) = "Raids" || this.Folder(mode) = "Infinity Mansion" {
for legendName,storyName in AADefaultPaths.Aliases
if stem = RegExReplace(legendName,"[^A-Za-z0-9]","")
stem := RegExReplace(storyName,"[^A-Za-z0-9]","")
}
if mapName != ""
stem := RegExReplace(AADefaultPaths.CanonicalName(mapName),"[^A-Za-z0-9]","")
shared := A_ScriptDir "\Images\Defaults\" stem ".png"
if FileExist(shared)
return shared
}
return path
}
static ActCount(mode, name) {
mode := this.Folder(mode)
if mode = "Legend Stages" && name = "Spirit Town"
name := "Spirit Invasion"
if !this.Maps.Has(mode)
throw Error("Unknown gamemode: " mode)
for mapName in this.Maps[mode] {
if mapName = name
return mode = "Story" || mode = "Challenges" ? 6 : mode = "Infinite" || mode = "Infinity Mansion" || mode = "Dungeons" || mode = "Portals" || mode = "Events" ? 1 : this.StageCounts[name]
}
throw Error("Unknown map: " name)
}
static HasDifficultySelection(mode, name) {
return this.Folder(mode) = "Story" || mode = "Infinity Mansion"
}
static EffectiveDifficulty(mode, name, difficulty) {
return this.HasDifficultySelection(mode,name) ? difficulty : "Normal"
}
static Filename(mode, name, act) {
if mode = "Legend Stages" && name = "Spirit Town"
name := "Spirit Invasion"
mode := this.Folder(mode), count := this.ActCount(mode,name)
if act < 1 || act > count
throw Error("Invalid act for " name)
suffix := mode = "Challenges" ? "Challenge" : mode = "Story" ? "Story" : mode = "Infinite" ? "Infinite" : mode = "Legend Stages" ? "Legend" : mode = "Raids" ? "Raid" : mode = "Infinity Mansion" ? "Mansion" : mode = "Dungeons" ? "Dungeons" : ""
return RegExReplace(name,"[^A-Za-z0-9]","") suffix ".txt"
}
static Name(filename) {
SplitPath(filename,,,,&stem)
stem := RegExReplace(stem,"i)(?:Act[1-6])?(?:Story[1-6]?|Infinite|Legend|Raid|Mansion|Challenge|Dungeons)$","")
for mode,names in this.Maps
for name in names
if RegExReplace(name,"[^A-Za-z0-9]","") = stem
return name
throw Error("Unknown config filename: " filename)
}
static Resolve(root, mode, name, act) {
return root "\" this.Folder(mode) "\" this.Filename(mode, name, act)
}
}
class CrusadersHotkeys {
static Names := ["StartKey", "PauseKey", "CloseKey", "RestartKey", "CaptureKey", "ZoomtechKey", "WebhookTestKey", "RecordKey", "RecordingTestKey"]
static Labels := Map("StartKey","Start","PauseKey","Pause / Resume","CloseKey","Close Macro","RestartKey","Restart Macro","CaptureKey","Replace Map Image","ZoomtechKey","Zoomtech","WebhookTestKey","Test Webhook","RecordKey","Record / Stop","RecordingTestKey","Test / Stop Recording")
static Parse(value) {
value := Trim(value)
mods := "", display := ""
while RegExMatch(value, "i)^(Ctrl|Control|Alt|Shift|Win)\+", &match) {
symbol := Map("ctrl","^","control","^","alt","!","shift","+","win","#")[StrLower(match[1])]
if InStr(mods,symbol)
throw Error("A modifier is repeated in this keybind.")
mods .= symbol, value := SubStr(value,StrLen(match[0])+1)
}
while StrLen(value) > 1 && RegExMatch(value,"^[\^!+#]",&match) {
if InStr(mods,match[0])
throw Error("A modifier is repeated in this keybind.")
mods .= match[0], value := SubStr(value,2)
}
if value = "" || InStr(value," ") || InStr(value,"&")
throw Error("Choose a keyboard key, such as 1, A, F1, or Ctrl+1.")
vk := GetKeyVK(value), sc := GetKeySC(value)
if !vk || InStr("|LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight|", "|" value "|")
throw Error("Choose a valid keyboard key or keyboard shortcut.")
key := GetKeyName(value)
if key = ""
throw Error("Unknown keyboard key: " value)
prefix := ""
for pair in [["^","Ctrl"],["!","Alt"],["+","Shift"],["#","Win"]]
if InStr(mods,pair[1])
prefix .= pair[1], display .= pair[2] "+"
code := InStr("^!+#",key) ? Format("vk{:02X}",vk) : key
return {display:display key,key:key,vk:vk,mods:prefix,hotkey:"$" prefix code,identity:prefix StrLower(key)}
}
static Validate(preferences) {
used := Map(), normalized := Map()
for name in this.Names {
binding := this.Parse(preferences[name])
if used.Has(binding.identity)
throw Error("Already Assigned to " this.Labels[used[binding.identity]])
used[binding.identity] := name, normalized[name] := binding.display
}
for name,value in normalized
preferences[name] := value
}
static Wait(value) => KeyWait(this.Parse(value).key)
static Conflict(preferences,name,value) {
if !this.Labels.Has(name)
throw Error("Unknown keybind")
binding := this.Parse(value)
for other in this.Names
if other != name && this.Parse(preferences[other]).identity = binding.identity
return {binding:binding,owner:other}
return false
}
}
class CrusadersSettingsLayout {
static Groups := [
["Keybinds",["StartKey","PauseKey","CloseKey","RestartKey","CaptureKey","ZoomtechKey","WebhookTestKey","RecordKey","RecordingTestKey"]],
["Server",["UsePrivateServerLink","PrivateServer","PublicRejoin","WaveRestart"]],
["Challenges",["DailyChallengeEnabled","ChallengeEnabled","ChallengeFirstMode","ChallengeForceLeave"]],
["Delays",["ZoomInDelay","ZoomOutDelay","DragDelay","ScanDelay","PlacementRetryDelay","StageClickDelay","PathingDelay","VictoryDelay","WebhookScreenshotDelay"]],
["Webhook",["WebhookEnabled","Webhook","WebhookPingEnabled","WebhookDiscordId"]],
["Webhook Display",["WebhookShowMap","WebhookShowMode","WebhookShowAct","WebhookShowRecord","WebhookShowSessionTime","WebhookShowChallengeRuns","WebhookShowModeRuns","WebhookShowNext","WebhookShowCompletion"]],
["Discord",["DiscordBotEnabled","DiscordChannel","DiscordUserId","DiscordToken"]],
["Themes",["ThemePreset","CustomThemeName","CustomTheme","ThemeBackground"]],
["Tutorials",["SkipGuideTutorial","SkipMacroOverview"]]
]
static IsToggle(key) {
return InStr("|UsePrivateServerLink|PublicRejoin|DailyChallengeEnabled|ChallengeEnabled|ChallengeForceLeave|WebhookEnabled|WebhookPingEnabled|WebhookShowMap|WebhookShowMode|WebhookShowAct|WebhookShowRecord|WebhookShowSessionTime|WebhookShowChallengeRuns|WebhookShowModeRuns|WebhookShowNext|WebhookShowCompletion|DiscordBotEnabled|SkipGuideTutorial|SkipMacroOverview|", "|" key "|") != 0
}
static Normalize(key,value) {
if this.IsToggle(key)
return value = "on" ? "1" : value = "off" ? "0" : value
return value
}
static IsSection(name) {
if name = "Settings" || name = "Other Settings"
return true
for group in this.Groups
if name = group[1]
return true
return false
}
static ReadAll(path) {
result := Map(), result.CaseSense := false
sections := ["Other Settings"]
for group in this.Groups
sections.Push(group[1])
sections.Push("Settings")
for section in sections {
seen := Map(), seen.CaseSense := false
for line in StrSplit(IniRead(path,section,,""),"`n","`r") {
delimiter := InStr(line,"=")
if !delimiter
continue
key := Trim(SubStr(line,1,delimiter-1))
if seen.Has(key)
continue
seen[key] := true
value := Trim(SubStr(line,delimiter+1), " `t")
if StrLen(value) >= 2 && ((SubStr(value,1,1) = '"' && SubStr(value,-1) = '"') || (SubStr(value,1,1) = "'" && SubStr(value,-1) = "'"))
value := SubStr(value,2,StrLen(value)-2)
result[key] := this.Normalize(key,value)
}
}
return result
}
static Read(path,key,default := "") {
section := "Other Settings"
for group in this.Groups {
for candidate in group[2] {
if key = candidate {
section := group[1]
break 2
}
}
}
return this.Normalize(key,IniRead(path,"Settings",key,IniRead(path,section,key,default)))
}
static Format(text) {
sections := Map(), sections.CaseSense := false, order := [], current := "", preamble := ""
for line in StrSplit(text,"`n","`r") {
if RegExMatch(line,"^\s*\[([^\]]+)\]\s*$",&header) {
current := Trim(header[1])
if !sections.Has(current)
sections[current] := "", order.Push(current)
} else if current = ""
preamble .= line "`r`n"
else
sections[current] .= line "`r`n"
}
values := Map(), values.CaseSense := false, extras := ""
sources := []
for section in order
if this.IsSection(section) && section != "Settings"
sources.Push(section)
if sections.Has("Settings")
sources.Push("Settings")
if !sources.Length
return text
for section in sources {
entries := Map(), entries.CaseSense := false
for line in StrSplit(sections[section],"`n","`r") {
if Trim(line) = ""
continue
if RegExMatch(line,"^\s*([^=;#]+?)\s*=",&entry) {
key := Trim(entry[1])
if this.IsToggle(key) {
delimiter := InStr(line,"=")
value := this.Normalize(key,Trim(SubStr(line,delimiter+1), " `t"))
if value = "0" || value = "1"
line := key "=" (value = "1" ? "on" : "off")
}
entries[key] := entries.Get(key,"") line "`r`n"
} else
extras .= line "`r`n"
}
for key, lines in entries
values[key] := lines
}
formatted := RTrim(preamble,"`r`n")
for section in order {
if this.IsSection(section)
continue
block := "[" section "]`r`n" RTrim(sections[section],"`r`n")
formatted .= (formatted != "" ? "`r`n`r`n" : "") block
}
for group in this.Groups {
block := ""
for key in group[2] {
if values.Has(key)
block .= values[key], values.Delete(key)
}
if block != ""
formatted .= (formatted != "" ? "`r`n`r`n" : "") "[" group[1] "]`r`n" RTrim(block,"`r`n")
}
for key, lines in values
extras .= lines
if extras != ""
formatted .= (formatted != "" ? "`r`n`r`n" : "") "[Other Settings]`r`n" RTrim(extras,"`r`n")
return formatted "`r`n"
}
static Reformat(path) {
before := FileRead(path), text := this.Format(before)
if before == text
return
temporary := CrusadersStorage.Temporary(path)
try {
FileAppend(text,temporary,"UTF-16")
CrusadersStorage.Commit(temporary,path,before)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
}
class AACategoryCopy {
static Allowed(running,paused,coordinates,recording := false,playing := false) {
return !recording && !playing && (!running || (paused && !coordinates))
}
static CloneIndexes(indexes) {
result := []
for item in indexes
result.Push(item.Clone())
return result
}
static Preview(source,matching := false,copyCoordinates := true) {
source.Validate()
SplitPath(source.path,,&directory)
SplitPath(directory,&category,&parent)
if StrLower(parent) != StrLower(source.configRoot) || !InStr("|Story|Infinite|Legend Stages|Raids|Infinity Mansion|Dungeons|Challenges|Portals|","|" category "|")
throw Error("This config category cannot be copied.")
plan := {id:CrusadersStorage.Temporary(source.path),path:source.path,source:source.ConfigText(),disk:FileRead(source.path),category:category,matching:matching,copyCoordinates:copyCoordinates,rows:[],overwrites:0}
paths := [], seen := Map()
if matching {
mapName := AADefaultPaths.CanonicalName(source.preferences["Map"])
for mode in ["Story","Infinite","Legend Stages","Raids","Infinity Mansion","Dungeons","Challenges"] {
if mode = category
continue
for name in CrusadersCatalog.ConfigMaps(mode) {
if AADefaultPaths.CanonicalName(name) != mapName
continue
path := CrusadersCatalog.Resolve(source.configRoot,mode,name,1)
if FileExist(path) && !seen.Has(StrLower(path))
paths.Push(path), seen[StrLower(path)] := true
}
}
} else {
Loop Files directory "\*.txt", "F"
if StrLower(A_LoopFileFullPath) != StrLower(source.path)
paths.Push(A_LoopFileFullPath)
}
for path in paths {
target := CrusadersSelector(path,"",source.settingsFile,source.imageRoot)
old := FileRead(path), bytes := FileRead(path,"RAW")
for item in target.indexes
if item.configured {
plan.overwrites++
break
}
if !copyCoordinates {
for number,item in source.indexes {
placement := target.indexes[number], copied := item.Clone()
for key in ["x","y","configured","recording"]
copied.%key% := placement.%key%
target.indexes[number] := copied
}
} else {
target.indexes := this.CloneIndexes(source.indexes)
target.mapWidth := source.mapWidth, target.mapHeight := source.mapHeight
}
target.preferences["Team"] := source.preferences["Team"]
target.Validate()
plan.rows.Push({path:path,old:old,bytes:bytes,text:target.ConfigText(),name:(matching ? target.preferences["Mode"] " — " : "") target.preferences["DisplayName"],temporary:""})
}
if !plan.rows.Length
throw Error(matching ? "No matching map configs were found in other categories." : "There are no other configs in this category.")
return plan
}
static Apply(source,plan) {
if source.path != plan.path || source.ConfigText() != plan.source
throw Error("The source config changed. Open Copy Settings again.")
CrusadersStorage.CheckCurrent(source.path,plan.disk)
committed := []
try {
for row in plan.rows {
CrusadersStorage.CheckCurrent(row.path,row.old)
row.temporary := CrusadersStorage.Temporary(row.path)
FileAppend(row.text,row.temporary,"UTF-16")
}
for row in plan.rows {
CrusadersStorage.Commit(row.temporary,row.path,row.old)
committed.Push(row)
}
} catch Error as err {
rollbackErrors := ""
Loop committed.Length {
row := committed[committed.Length-A_Index+1]
try {
CrusadersStorage.CheckCurrent(row.path,row.text)
temporary := CrusadersStorage.Temporary(row.path)
try {
file := FileOpen(temporary,"w")
try file.RawWrite(row.bytes)
finally file.Close()
CrusadersStorage.Commit(temporary,row.path,row.text)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
} catch Error as rollbackError
rollbackErrors .= "`n" row.path ": " rollbackError.Message
}
throw Error(err.Message (rollbackErrors = "" ? " No destination changes were retained." : " Some files could not be restored:" rollbackErrors))
} finally {
for row in plan.rows
if row.temporary != "" && FileExist(row.temporary)
FileDelete(row.temporary)
}
return plan.rows.Length
}
}
class CrusadersSelector {
static DelayKeys := ["PlacementRetryDelay","StageClickDelay","PathingDelay","VictoryDelay","WebhookScreenshotDelay"]
static DioForms := ["Erase Motion (Slow)", "Erase Thought (Stun)", "Erase Force (CC)", "Erase Form (Bleed)"]
static IniSections := Map()
__New(settingsPath := "", imagePath := "", settingsFile := "", imageRoot := "") {
this.configRoot := A_ScriptDir "\Settings\Configs"
relative := "Story\PlanetGreenieStory.txt"
activeFile := A_ScriptDir "\Settings.ini"
if settingsPath = "" && FileExist(activeFile) {
saved := IniRead(activeFile, "Config", "Path", relative)
if RegExMatch(saved, "^[\w -]+\\[\w -]+\.txt$") && FileExist(this.configRoot "\" saved)
relative := saved
}
this.path := settingsPath != "" ? settingsPath : this.configRoot "\" relative
SplitPath(this.path, , &configDirectory, , &configName)
SplitPath(configDirectory, &configFolder)
DirCreate(configDirectory)
production := settingsPath = "" || InStr(StrLower(this.path), StrLower(this.configRoot "\")) = 1
this.settingsFile := settingsFile != "" ? settingsFile : (production ? A_ScriptDir "\Settings.ini" : configDirectory "\Settings.ini")
this.imageRoot := imageRoot != "" ? imageRoot : (production ? A_ScriptDir "\Images\MapImages" : configDirectory "\Images\MapImages")
DirCreate(this.imageRoot)
this.explicitImage := imagePath != ""
this.mapImageDirectory := CrusadersCatalog.ImageDirectory(this.imageRoot, configFolder)
DirCreate(this.mapImageDirectory)
this.imagePath := imagePath != "" ? imagePath : CrusadersCatalog.ResolveMapImage(this.mapImageDirectory,configName ".png",configFolder,CrusadersCatalog.Name(this.path))
this.indexes := []
this.history := []
this.future := []
this.selected := 1
this.loading := false
this.dirty := false
this.open := false
this.pickMode := false
this.mapWidth := 0
this.mapHeight := 0
this.scroll := 0
this.controls := []
this.tiles := []
this.tileByHwnd := Map()
this.drawCount := 0
this.visibleIndexes := []
this.gridHeight := 164
this.editorPage := 1
this.preferences := this.DefaultPreferences()
this.saveTimer := ObjBindMethod(this, "AutoSave")
this.Load()
if settingsPath = "" {
this.SaveGlobalSettings()
if !FileExist(this.path) || !InStr(FileRead(this.path), "[Settings]") {
if relative = "Story\PlanetGreenieStory.txt" {
this.preferences["Mode"] := "Story"
this.preferences["Map"] := "Planet Greenie"
}
this.Save()
}
}
}
NewIndex() {
return {name: "", priority: "First", slot: 1, x: -1, y: -1, upgrade: "0",
wait: 0, wave: 0, beforeStart: false, firstRun: false, autoAbility: false, autoUpgrade: false, enabled: true, configured: false,
unit: "None", path: "Blessed", dioForm: "Erase Motion (Slow)", strongestHistory: false,
domainClash: false, domainWave: 20, domainWait: 0, domainImmediate: false, domainAbility: "Malevolent Shrine", recording: ""}
}
Load() {
this.indexes := []
this.iniSections := Map()
for path in [this.path, this.settingsFile] {
text := FileExist(path) ? FileRead(path) : ""
cached := CrusadersSelector.IniSections.Get(path, 0)
if !cached || cached.text != text {
cached := {text: text, sections: Map()}
if CrusadersSelector.IniSections.Count >= 64
CrusadersSelector.IniSections.Clear()
CrusadersSelector.IniSections[path] := cached
}
this.iniSections[path] := cached
}
metadata := this.ReadSection(this.path, "Selector")
count := Min(90, Integer(metadata.Get("Count", "0")))
compact := metadata.Get("Format", "1") = "2"
if FileExist(this.path) {
mapSettings := this.ReadSection(this.path, "Map")
this.mapWidth := Integer(mapSettings.Get("Width", "0"))
this.mapHeight := Integer(mapSettings.Get("Height", "0"))
imageName := mapSettings.Get("Image", "")
if imageName != "" {
if InStr(imageName, "\") || InStr(imageName, "/") || InStr(imageName, "..")
throw Error("Map Image must be a filename in Images\MapImages.")
if !this.explicitImage {
SplitPath(this.path,, &configDirectory)
SplitPath(configDirectory,&configFolder)
this.imagePath := CrusadersCatalog.ResolveMapImage(this.mapImageDirectory,imageName,configFolder,CrusadersCatalog.Name(this.path))
}
}
}
loop 90 {
item := this.NewIndex()
if A_Index <= count {
section := "Index " A_Index
fields := this.ReadSection(this.path, section)
if !fields.Count
fields := this.ReadSection(this.path, "Index" A_Index)
for key in ["name", "priority", "slot", "x", "y", "upgrade", "wait", "wave", "beforeStart", "firstRun", "autoAbility", "autoUpgrade", "enabled", "configured", "unit", "path", "dioForm", "strongestHistory", "domainClash", "domainWave", "domainWait", "domainImmediate", "domainAbility", "recording"] {
default := key = "configured" && !compact ? 1 : item.%key%
value := key = "name" ? fields.Get("indexname",fields.Get("name",default)) : fields.Get(key, default)
if key = "slot"
value := value = "leftclick" ? 7 : value = "rightclick" ? 8 : value
if InStr("|enabled|configured|beforeStart|firstRun|autoAbility|autoUpgrade|strongestHistory|domainClash|domainImmediate|", "|" key "|")
value := value = "on" ? 1 : value = "off" ? 0 : value
item.%key% := (key = "name" || key = "priority" || key = "upgrade" || key = "unit" || key = "path" || key = "dioForm" || key = "domainAbility" || key = "recording") ? value : Integer(value)
}
}
item.beforeStart := false, item.firstRun := false, item.autoUpgrade := false
if item.x >= 0 || item.y >= 0 || item.recording != ""
item.configured := true
item.unit := "None", item.strongestHistory := false, item.domainClash := false
this.indexes.Push(item)
}
mapPreferences := this.ReadSection(this.path, "Settings")
globalPreferences := CrusadersSettingsLayout.ReadAll(this.settingsFile)
for key, value in this.DefaultPreferences() {
source := this.IsMapPreference(key) ? mapPreferences : globalPreferences
this.preferences[key] := source.Get(key, value)
}
for pair in [["WebhookShowModeRecord","WebhookShowModeRuns"],["WebhookShowChallengeRecord","WebhookShowChallengeRuns"]]
if !globalPreferences.Has(pair[1]) && globalPreferences.Has(pair[2])
this.preferences[pair[1]] := globalPreferences[pair[2]]
if this.preferences["ThemePreset"] = "Midnight"
this.preferences["ThemePreset"] := "Graphite"
for key in ["RecordKey", "RecordingTestKey"] {
if globalPreferences.Has(key)
continue
occupied := Map()
for existing in ["StartKey", "PauseKey", "CloseKey", "RestartKey", "CaptureKey", "ZoomtechKey", "WebhookTestKey", "RecordKey", "RecordingTestKey"]
if existing != key
occupied[StrUpper(this.preferences[existing])] := true
if occupied.Has(this.preferences[key]) {
loop 24 {
candidate := "F" A_Index
if candidate != "F9" && !occupied.Has(candidate) {
this.preferences[key] := candidate
break
}
}
}
}
this.discordCredentialError := ""
try this.preferences["DiscordToken"] := CrusadersCredentials.Decode(this.preferences["DiscordToken"])
catch Error {
this.preferences["DiscordToken"] := ""
this.preferences["DiscordBotEnabled"] := "0"
this.discordCredentialError := "Saved bot token cannot be unlocked. Enter it again on this Windows account."
}
if AAAprilFools.IsPath(this.path) {
this.preferences["Mode"] := "Events", this.preferences["Map"] := "April Fools"
this.preferences["Runs"] := "9999"
}
this.settingsSource := FileExist(this.settingsFile) ? FileRead(this.settingsFile) : ""
this.EnsureMapDimensions()
this.Validate()
this.signature := FileExist(this.path) ? FileGetTime(this.path, "M") ":" FileGetSize(this.path) : ""
this.sourceText := FileExist(this.path) ? FileRead(this.path) : ""
}
EnsureMapDimensions() {
if !FileExist(this.imagePath)
return false
if this.mapWidth>0 && this.mapHeight>0
return true
token := Gdip_Startup(), bitmap := 0
if !token
return false
try {
bitmap := Gdip_CreateBitmapFromFile(this.imagePath)
if !bitmap
return false
Gdip_GetImageDimensions(bitmap,&width,&height)
if width<1 || height<1
return false
this.mapWidth := width, this.mapHeight := height
return true
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
}
}
ReadSection(path, section) {
cached := this.iniSections[path]
if cached.sections.Has(section)
return cached.sections[section]
values := Map()
values.CaseSense := false
cached.sections[section] := values
if !FileExist(path)
return values
contents := IniRead(path, section, , "")
for line in StrSplit(contents, "`n", "`r") {
delimiter := InStr(line, "=")
if !delimiter
continue
key := Trim(SubStr(line, 1, delimiter - 1), " `t")
value := Trim(SubStr(line, delimiter + 1), " `t")
if StrLen(value) >= 2 && ((SubStr(value, 1, 1) = '"' && SubStr(value, -1) = '"')
|| (SubStr(value, 1, 1) = "'" && SubStr(value, -1) = "'"))
value := SubStr(value, 2, StrLen(value) - 2)
if !values.Has(key)
values[key] := value
}
return values
}
DefaultPreferences() {
preferences := Map("Team", "0", "Mode", "Story", "Map", "", "DisplayName", "", "Act", "1", "Runs", "1", "Difficulty", "Normal", "BossRushMode", "Traits", "MakimaCard", "Unit Slot", "ContractPriority", CrusadersCatalog.DefaultContractPriority,
"PortalName", "", "PrivateServer", "", "UsePrivateServerLink", "1", "PublicRejoin", "1", "SkipGuideTutorial", "0", "SkipMacroOverview", "0", "WaveRestart", "0", "Webhook", "", "WebhookEnabled", "0",
"WebhookShowMap", "1", "WebhookShowMode", "1", "WebhookShowRecord", "1", "WebhookShowSessionTime", "1", "WebhookShowChallengeRuns", "1", "WebhookShowModeRuns", "1", "WebhookShowModeRecord", "1", "WebhookShowChallengeRecord", "1", "WebhookShowAct", "1", "WebhookShowNext", "1", "WebhookShowCompletion", "1", "WebhookPingEnabled", "0", "WebhookDiscordId", "",
"DiscordBotEnabled", "0", "DiscordChannel", "", "DiscordToken", "", "DiscordUserId", "",
"ZoomInDelay", "50", "ZoomOutDelay", "75", "DragDelay", "1", "ScanDelay", "150", "PlacementRetryDelay", "450", "StageClickDelay", "500", "VictoryDelay", "500", "WebhookScreenshotDelay", "1500", "PathingDelay", "1000",
"DailyChallengeEnabled", "0", "ChallengeEnabled", "0", "ChallengeFirstMode", "Challenges", "ChallengeForceLeave", "0", "ThemePreset", "Default", "CustomTheme", "", "CustomThemeName", "", "ThemeBackground", "",
"StartKey", "F1", "PauseKey", "F2", "CloseKey", "F3", "RestartKey", "F4", "CaptureKey", "F5", "ZoomtechKey", "F6", "WebhookTestKey", "F7", "RecordKey", "F8", "RecordingTestKey", "F10")
for key,value in AADungeons.Defaults
preferences[key] := value
return preferences
}
IsMapPreference(key) {
return InStr("|Team|Mode|Map|DisplayName|Act|Runs|Difficulty|BossRushMode|MakimaCard|ContractPriority|PortalName|", "|" key "|") != 0
}
Validate() {
AADungeons.Validate(this.preferences)
if !RegExMatch(this.preferences["Team"], "^\d+$") || Integer(this.preferences["Team"]) > 6
throw Error("Team must be between 0 and 6.")
AAPortalRoute.ValidateName(this.preferences["PortalName"],false)
this.preferences["ContractPriority"] := CrusadersCatalog.NormalizeContractPriority(this.preferences["ContractPriority"])
if this.preferences["MakimaCard"] != "Unit Slot" && this.preferences["MakimaCard"] != "Damage" && this.preferences["MakimaCard"] != "Placement Limit"
throw Error("Card must be Unit Slot, Damage, or Placement Limit.")
if this.preferences["BossRushMode"] != "Traits" && this.preferences["BossRushMode"] != "Traitless"
throw Error("Boss Rush mode must be Traits or Traitless.")
if this.preferences["Difficulty"] != "Normal" && this.preferences["Difficulty"] != "Hard"
throw Error("Difficulty must be Normal or Hard.")
if this.preferences["Mode"] != "Story" && this.preferences["Mode"] != "Raids" && this.preferences["Mode"] != "Infinity Mansion" && this.preferences["Difficulty"] != "Normal"
throw Error("Difficulty selection is only available for Story, Infinity Mansion, and supported raids.")
this.preferences["Difficulty"] := CrusadersCatalog.EffectiveDifficulty(this.preferences["Mode"],
this.preferences["Map"], this.preferences["Difficulty"])
if this.mapWidth < 0 || this.mapHeight < 0
throw Error("Map dimensions cannot be negative.")
for number, item in this.indexes {
if item.recording != ""
CrusadersRecording.Path(item.recording)
if (item.unit != "None" && item.unit != "Gojo v Sukuna" && item.unit != "Dio") || (item.path != "Blessed" && item.path != "Cursed")
throw Error("Invalid unit-specific action in Index" number)
validForm := false
for form in CrusadersSelector.DioForms
if item.dioForm = form
validForm := true
if !validForm
throw Error("Invalid Dio Form in Index" number)
if item.priority = "Strong"
item.priority := "Strongest"
else if item.priority = "Close"
item.priority := "Closest"
if item.slot < 1 || item.slot > 8 || !InStr("|First|Strongest|Closest|Last|Farthest|Weakest|", "|" item.priority "|")
throw Error("Invalid slot or priority in Index" number)
if item.upgrade != "MAX" && !RegExMatch(item.upgrade, "^\d+$")
throw Error("Invalid upgrade in Index" number)
if item.wait < 0 || item.wave < 0 || item.x < -1 || item.y < -1
|| (item.beforeStart && item.wave > 0)
throw Error("Invalid timing or coordinates in Index" number)
if this.mapWidth && (item.x >= this.mapWidth || item.y >= this.mapHeight)
throw Error("Coordinates outside the map in Index" number)
if item.domainWave < 1 || item.domainWave > 999 || item.domainWait < 0 || item.domainWait > 3600000
throw Error("Invalid Domain Clash timing in Index" number)
if item.domainAbility != "Malevolent Shrine" && item.domainAbility != "Infinite Void"
throw Error("Invalid Domain Clash ability in Index" number)
for key in ["beforeStart", "firstRun", "autoAbility", "autoUpgrade", "enabled", "configured", "strongestHistory", "domainClash", "domainImmediate"]
if item.%key% != 0 && item.%key% != 1
throw Error("Invalid toggle in Index" number)
}
for key in ["Act", "Runs", "WaveRestart", "ZoomInDelay", "ZoomOutDelay", "DragDelay", "ScanDelay", "PlacementRetryDelay", "StageClickDelay", "VictoryDelay", "WebhookScreenshotDelay", "PathingDelay"]
if !RegExMatch(this.preferences[key], "^\d+$") || Integer(this.preferences[key]) > 3600000
throw Error("Invalid setting: " key)
if Integer(this.preferences["Act"]) < 1 || Integer(this.preferences["Runs"]) < 1
throw Error("Act and Runs must be at least 1.")
if this.preferences["Map"] != "" {
expected := CrusadersCatalog.Filename(this.preferences["Mode"], this.preferences["Map"], Integer(this.preferences["Act"]))
SplitPath(this.path, &filename)
if filename != expected
throw Error("Act " this.preferences["Act"] " requires " expected)
}
CrusadersHotkeys.Validate(this.preferences)
if this.preferences["ChallengeFirstMode"] != "Mode List" && this.preferences["ChallengeFirstMode"] != "Challenges"
throw Error("First Mode must be Mode List or Challenges.")
for key in ["WebhookEnabled", "DiscordBotEnabled", "UsePrivateServerLink", "PublicRejoin", "SkipGuideTutorial", "SkipMacroOverview", "DailyChallengeEnabled", "ChallengeEnabled", "ChallengeForceLeave"]
if this.preferences[key] != "0" && this.preferences[key] != "1"
throw Error("Invalid toggle: " key)
for key in ["WebhookShowMap", "WebhookShowMode", "WebhookShowRecord", "WebhookShowSessionTime", "WebhookShowChallengeRuns", "WebhookShowModeRuns", "WebhookShowModeRecord", "WebhookShowChallengeRecord", "WebhookShowAct", "WebhookShowNext", "WebhookShowCompletion", "WebhookPingEnabled"]
if this.preferences[key] != "0" && this.preferences[key] != "1"
throw Error("Invalid toggle: " key)
if this.preferences["WebhookDiscordId"] != "" && !CrusadersWebhook.PingId(this.preferences["WebhookDiscordId"])
throw Error("Enter a numeric Discord user ID or <@ID> mention, not a username.")
if this.preferences["DiscordBotEnabled"] = "1" {
if !RegExMatch(this.preferences["DiscordUserId"], "^\d{17,20}$")
throw Error("Enter your numeric Discord user ID before enabling the integration.")
if !RegExMatch(this.preferences["DiscordChannel"], "^\d{17,20}$") || Trim(this.preferences["DiscordToken"]) = ""
throw Error("Discord integration requires a channel ID and bot token.")
}
for key, value in this.preferences
if InStr(value, "`n") || InStr(value, "`r")
throw Error("Settings must be single-line values.")
}
ReloadConfig(*) {
try {
candidate := CrusadersSelector(this.path, "", this.settingsFile, this.imageRoot)
this.indexes := candidate.indexes
this.preferences := candidate.preferences
this.mapWidth := candidate.mapWidth
this.mapHeight := candidate.mapHeight
this.signature := candidate.signature
this.sourceText := candidate.sourceText
this.imagePath := candidate.imagePath
this.mapImageDirectory := candidate.mapImageDirectory
this.settingsSource := candidate.settingsSource
this.history := []
this.future := []
this.SetSelected(this.selected)
this.status.Text := "Text config reloaded"
return true
} catch Error as err {
this.status.Text := "Config not loaded: " err.Message
return false
}
}
ConfigText() {
defaults := this.NewIndex(), last := 0, saved := []
for number, item in this.indexes {
changed := false
for key, value in defaults.OwnProps() {
if !(item.%key% == value) {
changed := true
break
}
}
if changed
saved.Push(number), last := number
}
text := "[Selector]`r`nFormat=2`r`nCount=" last "`r`n`r`n[Map]`r`n"
SplitPath(this.imagePath, &imageName)
text .= "Image=" imageName "`r`nWidth=" this.mapWidth "`r`nHeight=" this.mapHeight "`r`n`r`n[Settings]`r`n"
for key in ["Mode", "Map", "DisplayName", "Act", "Difficulty", "Team", "Runs"]
if key != "Team" || this.preferences["Mode"] != "Dungeons"
text .= key "=" this.preferences[key] "`r`n"
if this.preferences["Mode"] = "Portals"
text .= "PortalName=" this.preferences["PortalName"] "`r`n"
preferences := this.DefaultPreferences()
for key in ["BossRushMode", "MakimaCard", "ContractPriority"] {
relevant := key = "BossRushMode" ? this.preferences["Mode"] = "Boss Rush"
: key = "MakimaCard" ? this.preferences["Mode"] = "Boss Rush" && this.preferences["Map"] = "Makima"
: this.preferences["Mode"] = "Event" && this.preferences["Map"] = "Hunter Mayhem"
if relevant || !(this.preferences[key] == preferences[key])
text .= key "=" this.preferences[key] "`r`n"
}
groups := [
["Status", ["name", "enabled", "configured"]],
["Action and coordinates", ["slot", "priority", "upgrade", "x", "y", "recording"]],
["Timing and triggers", ["wait", "wave", "autoAbility"]],
["Unit options", ["unit", "path", "dioForm", "strongestHistory"]],
["Domain Clash", ["domainClash", "domainWave", "domainWait", "domainImmediate", "domainAbility"]]
]
for number in saved {
item := this.indexes[number]
text .= "`r`n[Index " number "]`r`n"
for groupNumber, group in groups {
body := ""
for key in group[2] {
if groupNumber > 3 && item.%key% == defaults.%key%
continue
value := InStr("|enabled|configured|beforeStart|firstRun|autoAbility|autoUpgrade|strongestHistory|domainClash|domainImmediate|", "|" key "|")
? (item.%key% ? "on" : "off") : item.%key%
if key = "slot"
value := item.slot = 7 ? "leftclick" : item.slot = 8 ? "rightclick" : item.slot
body .= (key = "name" ? "indexname" : key) "=" value "`r`n"
}
if body != ""
text .= body
}
text := RTrim(text, "`r`n") "`r`n"
}
return text
}
Save() {
if AAAprilFools.IsPath(this.path)
return this.SaveGlobalSettings()
if this.HasOwnProp("sourceText") && FileExist(this.path) && FileRead(this.path) != this.sourceText
throw Error("Text config changed externally. Restart to load it before saving.")
this.SaveGlobalSettings()
SplitPath(this.path, , &directory)
DirCreate(directory)
temporary := CrusadersStorage.Temporary(this.path)
try {
text := this.ConfigText()
FileAppend(text, temporary, "UTF-16")
CrusadersStorage.Commit(temporary, this.path, this.sourceText)
this.signature := FileGetTime(this.path, "M") ":" FileGetSize(this.path)
this.sourceText := FileRead(this.path)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
SaveGlobalSettings() {
body := ""
changed := !FileExist(this.settingsFile)
for key, value in this.preferences {
if this.IsMapPreference(key)
continue
if key = "DiscordToken" && value != "" {
stored := CrusadersSettingsLayout.Read(this.settingsFile,key,"")
same := false
if SubStr(stored, 1, 6) = "dpapi:"
try same := CrusadersCredentials.Decode(stored) = value
value := same ? stored : CrusadersCredentials.Encode(value)
} else if key = "DiscordToken" && this.discordCredentialError != "" {
value := CrusadersSettingsLayout.Read(this.settingsFile,key,"")
}
body .= key "=" value "`n"
if !changed && CrusadersSettingsLayout.Read(this.settingsFile,key,"") != value
changed := true
}
if !changed
return
if FileExist(this.settingsFile) && FileRead(this.settingsFile) != this.settingsSource
throw Error("Settings.ini changed externally. Restart before saving settings.")
temporary := CrusadersStorage.Temporary(this.settingsFile)
try {
if FileExist(this.settingsFile)
FileCopy(this.settingsFile, temporary, true)
IniWrite(RTrim(body, "`n"), temporary, "Settings")
formatted := CrusadersSettingsLayout.Format(FileRead(temporary))
FileDelete(temporary)
FileAppend(formatted, temporary, "UTF-16")
CrusadersStorage.Commit(temporary, this.settingsFile, this.settingsSource)
this.settingsSource := FileRead(this.settingsFile)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
AddControl(type, options, value := "") {
control := this.gui.Add(type, options, value)
control.GetPos(&left, &top)
control.Move(left + 48, top >= 462 ? top - 156 : top - 12)
this.controls.Push(control)
return control
}
Attach(hostGui) {
global macroWindow
this.gui := hostGui
this.undoButton := hostGui.AddButton("x1092 y728 w82 h32 Hidden", Chr(0xE7A7))
this.redoButton := hostGui.AddButton("x1186 y728 w82 h32 Hidden", Chr(0xE7A6))
this.undoButton.SetFont("s11", "Segoe MDL2 Assets")
this.redoButton.SetFont("s11", "Segoe MDL2 Assets")
this.undoButton.OnEvent("Click", (*) => this.Undo())
this.redoButton.OnEvent("Click", (*) => this.Undo(true))
title := this.AddControl("Text", "x844 y64 w180 h24 BackgroundTrans", "Indexes")
title.SetFont("s11 bold")
this.countLabel := this.AddControl("Text", "x1024 y64 w208 h24 Right BackgroundTrans", "0 / 90 configured")
this.search := this.AddControl("Edit", "x844 y94 w244 h28 Background17181B", "")
DllCall("SendMessage", "Ptr", this.search.Hwnd, "UInt", 0x1501, "Ptr", 1,
"WStr", "Search indexes...", "Ptr")
this.filter := this.AddControl("DropDownList", "x1100 y94 w130 Choose1", ["All", "Configured", "Empty"])
this.search.OnEvent("Change", (*) => this.FilterChanged())
this.filter.OnEvent("Change", (*) => this.FilterChanged())
this.grid := Gui("-DPIScale -Caption +Parent" hostGui.Hwnd " +0x40000000 +0x200000", "")
this.grid.BackColor := CrusadersTheme.Rose
this.grid.SetFont("s9 c" CrusadersTheme.Ink, "Segoe UI")
loop (this.HasOwnProp("webShell") && this.webShell ? 0 : 90) {
column := Mod(A_Index - 1, 2)
row := (A_Index - 1) // 2
tile := this.grid.AddButton("x" (column * 186 + 4) " y" (row * 40) " w178 h40 +0xB", "")
tile.OnEvent("Click", ObjBindMethod(this, "TileClick", A_Index))
this.tiles.Push(tile)
this.tileByHwnd[tile.Hwnd] := A_Index
}
this.scrollHandler := ObjBindMethod(this, "VScroll")
this.wheelHandler := ObjBindMethod(this, "Wheel")
this.drawHandler := ObjBindMethod(this, "DrawTile")
OnMessage(0x115, this.scrollHandler)
OnMessage(0x20A, this.wheelHandler)
OnMessage(0x2B, this.drawHandler)
this.AddControl("Text", "x1058 y506 w28 h24 BackgroundTrans", "CT:")
this.configTool := this.AddControl("Edit", "x1086 y502 w38 h28 Number Background17181B", "")
this.configToolHandler := ObjBindMethod(this, "ConfigToolKey")
OnMessage(0x100, this.configToolHandler)
if IsSet(macroWindow)
macroWindow.tooltips[this.configTool.Hwnd] := "Config Tool: source index number, Enter to copy"
this.editorTitle := this.AddControl("Text", "x844 y466 w154 h24 BackgroundTrans", "Index 1")
this.editorTitle.SetFont("s11 bold")
this.pageOne := this.AddControl("Button", "x1008 y462 w106 h30", "Page 1")
this.pageTwo := this.AddControl("Button", "x1124 y462 w106 h30", "Unit Actions")
this.pageOne.OnEvent("Click", (*) => this.SwitchEditorPage(1))
this.pageTwo.OnEvent("Click", (*) => this.SwitchEditorPage(2))
this.name := this.AddControl("Edit", "x844 y502 w202 h28 Background17181B", "")
this.moveUp := this.AddControl("Button", "x1136 y502 w42 h28", Chr(0xE74A))
this.moveDown := this.AddControl("Button", "x1188 y502 w42 h28", Chr(0xE74B))
this.moveUp.SetFont("s10", "Segoe MDL2 Assets")
this.moveDown.SetFont("s10", "Segoe MDL2 Assets")
this.moveUp.OnEvent("Click", (*) => this.Move(-1))
this.moveDown.OnEvent("Click", (*) => this.Move(1))
if IsSet(macroWindow) {
macroWindow.tooltips[this.moveUp.Hwnd] := "Move index up"
macroWindow.tooltips[this.moveDown.Hwnd] := "Move index down"
}
DllCall("SendMessage", "Ptr", this.name.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "Index name...", "Ptr")
pageStart := this.controls.Length
this.AddControl("Text", "x844 y540 w66 h24 BackgroundTrans", "Slot #")
this.slot := this.AddControl("DropDownList", "x920 y536 w80 Choose1", ["1", "2", "3", "4", "5", "6", "Left Click", "Right Click"])
this.AddControl("Text", "x1044 y540 w70 h24 BackgroundTrans", "Priority")
this.priority := this.AddControl("DropDownList", "x1122 y536 w108 Choose1", ["First", "Strongest", "Closest", "Last", "Farthest", "Weakest"])
this.AddControl("Text", "x844 y578 w76 h24 BackgroundTrans", "Upgrade")
this.upgrade := this.AddControl("ComboBox", "x920 y574 w80", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "MAX"])
this.upgrade.Text := "0"
this.pickButton := this.AddControl("Button", "x1050 y650 w180 h28", "Select Coordinates")
this.pickButton.OnEvent("Click", (*) => this.BeginPick())
this.AddControl("Text", "x1044 y578 w76 h24 BackgroundTrans", "On Wave")
this.wave := this.AddControl("Edit", "x1122 y574 w80 h26 Number Background17181B", "0")
this.AddControl("Text", "x844 y616 w76 h24 BackgroundTrans", "Wait (ms)")
this.wait := this.AddControl("Edit", "x920 y612 w96 h26 Number Background17181B", "0")
this.AddControl("Text", "x844 y654 w16 h24 BackgroundTrans", "X")
this.x := this.AddControl("Edit", "x864 y650 w72 h28 Number Background17181B", "")
this.AddControl("Text", "x946 y654 w16 h24 BackgroundTrans", "Y")
this.y := this.AddControl("Edit", "x966 y650 w72 h28 Number Background17181B", "")
this.beforeStart := this.AddControl("Checkbox", "x844 y692 w126 h24 Background" CrusadersTheme.Rose, "Before Starting")
this.firstRun := this.AddControl("Checkbox", "x978 y692 w126 h24 Background" CrusadersTheme.Rose, "First Run Only")
this.autoAbility := this.AddControl("Checkbox", "x1112 y692 w118 h24 Background" CrusadersTheme.Rose, "Auto Ability")
this.pageOneControls := []
loop this.controls.Length - pageStart
this.pageOneControls.Push(this.controls[pageStart + A_Index])
pageStart := this.controls.Length
heading := this.AddControl("Text", "x844 y544 w386 h24 BackgroundTrans", "Unit Specific Actions")
heading.SetFont("s10 bold")
this.AddControl("Text", "x844 y580 w386 h22 BackgroundTrans", "Unit")
this.unit := this.AddControl("DropDownList", "x844 y606 w186 Choose1", ["None", "Gojo v Sukuna", "Dio"])
this.pathLabel := this.AddControl("Text", "x1044 y580 w186 h22 BackgroundTrans", "Path")
this.unitPath := this.AddControl("DropDownList", "x1044 y606 w118 Choose1", ["Blessed", "Cursed"])
this.dioFormLabel := this.AddControl("Text", "x844 y648 w386 h22 BackgroundTrans", "Dio Form")
this.dioForm := this.AddControl("DropDownList", "x844 y674 w246 Choose1", CrusadersSelector.DioForms)
this.strongestHistory := this.AddControl("Checkbox", "x844 y636 w386 h22 Background" CrusadersTheme.Rose, "Activate Strongest in History Form")
this.domainClash := this.AddControl("Checkbox", "x844 y662 w190 h22 Background" CrusadersTheme.Rose, "Use Domain Clash")
this.domainWaveLabel := this.AddControl("Text", "x1044 y686 w80 h18 BackgroundTrans", "Wave")
this.domainWave := this.AddControl("Edit", "x1044 y704 w80 h22 Number", "20")
this.domainWaitLabel := this.AddControl("Text", "x1144 y686 w86 h18 BackgroundTrans", "Wait (ms)")
this.domainWait := this.AddControl("Edit", "x1144 y704 w86 h22 Number", "0")
this.domainImmediate := this.AddControl("Checkbox", "x1044 y662 w186 h22", "Immediate on MAX")
this.domainAbilityLabel := this.AddControl("Text", "x844 y686 w186 h18 BackgroundTrans", "Domain Clash Ability")
this.domainAbility := this.AddControl("DropDownList", "x844 y704 w186 Choose1", ["Malevolent Shrine", "Infinite Void"])
this.pageTwoControls := []
loop this.controls.Length - pageStart
this.pageTwoControls.Push(this.controls[pageStart + A_Index])
this.AddControl("Button", "x1136 y728 w94 h30", "Reset").OnEvent("Click", (*) => this.Delete())
this.status := this.AddControl("Text", "x844 y772 w386 h44 BackgroundTrans c" CrusadersTheme.Muted, "Saved")
for control in [this.name, this.priority, this.slot, this.upgrade, this.x, this.y, this.wait, this.wave, this.unitPath, this.dioForm, this.domainWave, this.domainWait, this.domainAbility]
control.OnEvent("Change", ObjBindMethod(this, "Changed"))
this.unit.OnEvent("Change", (*) => (this.RefreshEditorPage(), this.Changed()))
for control in [this.beforeStart, this.firstRun, this.autoAbility, this.strongestHistory, this.domainClash, this.domainImmediate]
control.OnEvent("Click", ObjBindMethod(this, "Changed"))
this.Refresh()
this.SetSelected(1)
this.SetVisible(false)
}
SetVisible(visible) {
this.open := visible
if this.HasOwnProp("webShell") && this.webShell {
for control in this.controls
control.Visible := false
this.grid.Hide()
return
}
for control in this.controls
control.Visible := visible
this.RefreshEditorPage()
if visible {
this.grid.Show("x892 y120 w396 h164 NA")
this.grid.Opt("+0x200000")
this.ScrollTo(this.scroll)
} else {
this.grid.Hide()
}
}
CompactEditor() {
positions := Map("CT:", [1208, 310, 28], "Slot #", [892, 438, 112],
"Upgrade", [1018, 438, 112], "Priority", [1144, 438, 134],
"On Wave", [892, 502, 112], "Wait (ms)", [1018, 502, 112],
"X", [892, 570, 16], "Y", [984, 570, 16])
for control in this.pageOneControls
if control.Type = "Text" && positions.Has(control.Text) {
position := positions[control.Text]
control.Move(position[1], position[2], position[3], 22)
if control.Text = "Slot #"
control.Text := "Unit slot"
}
for control in this.controls {
if control.Type = "Text" && control.Text = "CT:"
control.Move(1208, 310, 28, 22)
if control.Type = "Button" && control.Text = "Reset"
control.Move(1184, 646, 94, 30)
}
this.configTool.Move(1240, 306, 38, 28)
this.pageOne.Move(892, 340, 100, 30)
this.pageTwo.Move(1002, 340, 134, 30)
this.moveUp.Move(1174, 340, 46, 30)
this.moveDown.Move(1232, 340, 46, 30)
this.nameLabel := this.gui.AddText("x892 y374 w386 h22 BackgroundTrans", "Index Name")
this.controls.Push(this.nameLabel)
this.pageOneControls.Push(this.name, this.nameLabel)
this.name.Move(892, 398, 386, 28)
this.slot.Move(892, 462, 112)
this.upgrade.Move(1018, 462, 112)
this.priority.Move(1144, 462, 134)
this.wave.Move(892, 526, 112, 28)
this.wait.Move(1018, 526, 112, 28)
this.x.Move(912, 566, 62, 28)
this.y.Move(1004, 566, 62, 28)
this.pickButton.Move(1076, 566, 202, 28)
this.beforeStart.Move(892, 608, 126, 24)
this.firstRun.Move(1028, 608, 126, 24)
this.autoAbility.Move(1164, 608, 114, 24)
this.status.Move(892, 648, 280, 36)
}
SwitchEditorPage(page) {
if !this.Apply()
return
this.editorPage := page
this.RefreshEditorPage()
}
RefreshEditorPage() {
if this.HasOwnProp("webShell") && this.webShell
return
if !this.HasOwnProp("pageOneControls")
return
for control in this.pageOneControls
control.Visible := this.open && this.editorPage = 1
for control in this.pageTwoControls
control.Visible := this.open && this.editorPage = 2
showPath := this.open && this.editorPage = 2 && this.unit.Text = "Gojo v Sukuna"
this.pathLabel.Visible := showPath
this.unitPath.Visible := showPath
this.strongestHistory.Visible := showPath
for control in [this.domainClash, this.domainWaveLabel, this.domainWave, this.domainWaitLabel, this.domainWait, this.domainImmediate, this.domainAbility, this.domainAbilityLabel]
control.Visible := showPath
showDio := this.open && this.editorPage = 2 && this.unit.Text = "Dio"
this.dioFormLabel.Visible := showDio
this.dioForm.Visible := showDio
this.pageOne.SetFont(this.editorPage = 1 ? "bold" : "norm")
this.pageTwo.SetFont(this.editorPage = 2 ? "bold" : "norm")
}
Show(*) {
global macroWindow, testRunning
if testRunning {
macroWindow.Log("Stop the test before editing indexes")
return
}
macroWindow.Navigate("indexes")
}
Close(*) {
global macroWindow
macroWindow.Navigate("main")
}
Changed(*) {
if this.loading
return
this.dirty := true
this.status.Text := "Editing index " this.selected
SetTimer(this.saveTimer, -600)
}
AutoSave(*) {
this.Apply()
}
Snapshot() {
snapshot := []
for item in this.indexes
snapshot.Push(item.Clone())
return snapshot
}
Remember() {
this.history.Push(this.Snapshot())
if this.history.Length > 30
this.history.RemoveAt(1)
this.future := []
}
LinkCoordinateEdit(previous, replacement) {
if previous.x < 0 || previous.y < 0 || replacement.x < 0 || replacement.y < 0
|| (previous.x = replacement.x && previous.y = replacement.y)
return
for other in this.indexes
if other.x = previous.x && other.y = previous.y {
other.x := replacement.x
other.y := replacement.y
}
}
Apply(*) {
if !this.dirty
return true
SetTimer(this.saveTimer, 0)
try {
item := this.NewIndex()
item.recording := this.indexes[this.selected].recording
item.name := Trim(this.name.Value)
if InStr(item.name, "`n") || InStr(item.name, "`r")
throw Error("Index name must be a single line.")
item.priority := this.priority.Text
item.unit := this.unit.Text
item.path := this.unitPath.Text
item.dioForm := this.dioForm.Text
item.strongestHistory := this.strongestHistory.Value
item.domainClash := this.domainClash.Value
item.domainImmediate := this.domainImmediate.Value
item.domainAbility := this.domainAbility.Text
for key in ["domainWave", "domainWait"] {
if !RegExMatch(this.%key%.Value, "^\d+$")
throw Error("Domain Clash timing must use whole numbers.")
item.%key% := Integer(this.%key%.Value)
}
if item.domainWave < 1 || item.domainWave > 999 || item.domainWait > 3600000
throw Error("Domain Clash wave must be 1-999; wait must be 0-3600000 ms.")
item.slot := this.slot.Value
item.upgrade := StrUpper(Trim(this.upgrade.Text))
if item.upgrade != "MAX" && !RegExMatch(item.upgrade, "^\d+$")
throw Error("Upgrade must be a level from 0 upward, or MAX.")
for key in ["wait", "wave"] {
value := this.%key%.Value
if !RegExMatch(value, "^\d+$")
throw Error(key = "wait" ? "Wait must be milliseconds, zero or greater." : "On Wave must be zero or greater.")
item.%key% := Integer(value)
}
for key in ["x", "y"] {
value := this.%key%.Value
if value != "" && !RegExMatch(value, "^\d+$")
throw Error("Coordinates must be whole numbers.")
item.%key% := value = "" ? -1 : Integer(value)
}
if (item.x < 0) != (item.y < 0)
throw Error("Set both X and Y, or leave both empty.")
if this.mapWidth && (item.x >= this.mapWidth || item.y >= this.mapHeight)
throw Error("Coordinates are outside the captured map.")
item.beforeStart := this.beforeStart.Value
item.firstRun := this.firstRun.Value
item.autoAbility := this.autoAbility.Value
item.configured := true
if item.beforeStart && item.wave > 0
throw Error("Before Starting requires On Wave 0.")
this.Remember()
previous := this.indexes[this.selected], originalIndexes := this.Snapshot()
this.indexes[this.selected] := item
this.LinkCoordinateEdit(previous,item)
try this.Save()
catch Error as err {
this.indexes := originalIndexes
this.history.Pop()
throw err
}
this.dirty := false
this.Refresh()
this.editorTitle.Text := item.name != "" ? SubStr(item.name, 1, 20) : "Index " this.selected
this.status.SetFont("cB0B3BC")
this.status.Text := "Index " this.selected " saved"
return true
} catch Error as err {
this.status.Text := err.Message
this.status.SetFont("cB34862")
return false
}
}
Refresh() {
if this.HasOwnProp("webShell") && this.webShell
return
if !this.HasOwnProp("tiles") || !this.tiles.Length
return
count := 0
for index, item in this.indexes {
if item.configured {
count += 1
summary := "Unit " item.slot " / " (item.autoUpgrade ? "Auto Upgrade" : "Upg " item.upgrade)
title := item.name != "" ? SubStr(item.name, 1, 20) : "Index " index
label := title "`n" summary
} else {
label := "Index " index "`nEmpty"
}
this.tiles[index].Text := label
this.tiles[index].SetFont("s9 " (index = this.selected ? "bold cEF8293" : "norm cF0F1F3"))
style := (WinGetStyle("ahk_id " this.tiles[index].Hwnd) & ~0xF) | 0xB
WinSetStyle(style, "ahk_id " this.tiles[index].Hwnd)
}
this.countLabel.Text := count " / 90 configured"
this.FilterChanged()
}
TileClick(index, *) {
if !this.Apply()
return
this.SetSelected(index)
}
SetSelected(index) {
global macroWindow
wasPicking := this.pickMode
this.pickMode := false
this.pickButton.Text := "Select Coordinates"
this.selected := index
item := this.indexes[index]
this.loading := true
try {
this.editorTitle.Text := item.name != "" ? SubStr(item.name, 1, 20) : "Index " index
this.name.Value := item.name
this.priority.Choose(item.priority)
this.unit.Choose(item.unit)
this.unitPath.Choose(item.path)
this.dioForm.Choose(item.dioForm)
this.strongestHistory.Value := item.strongestHistory
this.domainClash.Value := item.domainClash
this.domainImmediate.Value := item.domainImmediate
this.domainAbility.Choose(item.domainAbility)
this.domainWave.Value := item.domainWave
this.domainWait.Value := item.domainWait
this.slot.Choose(item.slot)
this.upgrade.Text := item.upgrade
this.x.Value := item.x < 0 ? "" : item.x
this.y.Value := item.y < 0 ? "" : item.y
this.wait.Value := item.wait
this.wave.Value := item.wave
this.beforeStart.Value := item.beforeStart
this.firstRun.Value := item.firstRun
this.autoAbility.Value := item.autoAbility
this.dirty := false
this.status.SetFont("cB0B3BC")
this.status.Text := item.configured ? "Saved" : "Empty index"
} finally {
this.loading := false
}
this.Refresh()
this.RefreshEditorPage()
if wasPicking && IsSet(macroWindow)
macroWindow.BeginCoordinates()
}
ScrollTo(position) {
if this.HasOwnProp("webShell") && this.webShell
return
total := Ceil(this.visibleIndexes.Length / 2) * 40
this.scroll := Max(0, Min(Max(0, total - this.gridHeight), position))
for positionIndex, index in this.visibleIndexes {
tile := this.tiles[index]
y := ((positionIndex - 1) // 2) * 40 - this.scroll
tile.Move(Mod(positionIndex - 1, 2) * 186 + 4, y, 178, 40)
}
info := Buffer(28, 0)
NumPut("UInt", 28, "UInt", 15, "Int", 0, "Int", Max(0, total - 1), "UInt", this.gridHeight, "Int", this.scroll, info)
DllCall("SetScrollInfo", "Ptr", this.grid.Hwnd, "Int", 1, "Ptr", info, "Int", true)
}
FilterChanged() {
if this.HasOwnProp("webShell") && this.webShell
return
this.visibleIndexes := []
query := StrLower(Trim(this.search.Value))
filter := this.filter.Text
for index, item in this.indexes {
haystack := index " " item.name " slot " item.slot " " item.x " " item.y
matches := (query = "" || InStr(StrLower(haystack), query))
&& (filter = "All" || (filter = "Configured" && item.configured)
|| (filter = "Empty" && !item.configured))
this.tiles[index].Visible := matches
if matches
this.visibleIndexes.Push(index)
}
this.ScrollTo(this.scroll)
}
DrawTile(wParam, lParam, msg, hwnd) {
offset := A_PtrSize = 8 ? 24 : 20
button := NumGet(lParam, offset, "Ptr")
dc := NumGet(lParam, offset + A_PtrSize, "Ptr")
if !this.tileByHwnd.Has(button)
return
tileIndex := this.tileByHwnd[button]
this.drawCount += 1
rectOffset := offset + A_PtrSize * 2
left := NumGet(lParam, rectOffset, "Int")
top := NumGet(lParam, rectOffset + 4, "Int")
right := NumGet(lParam, rectOffset + 8, "Int")
bottom := NumGet(lParam, rectOffset + 12, "Int")
selected := tileIndex = this.selected
brush := DllCall("CreateSolidBrush", "UInt", CrusadersTheme.Color(selected ? CrusadersTheme.Selected : CrusadersTheme.Field), "Ptr")
pen := DllCall("CreatePen", "Int", 0, "Int", selected ? 2 : 1,
"UInt", CrusadersTheme.Color(selected ? CrusadersTheme.Accent : CrusadersTheme.Line), "Ptr")
oldBrush := DllCall("SelectObject", "Ptr", dc, "Ptr", brush, "Ptr")
oldPen := DllCall("SelectObject", "Ptr", dc, "Ptr", pen, "Ptr")
DllCall("Rectangle", "Ptr", dc, "Int", left, "Int", top, "Int", right, "Int", bottom)
font := SendMessage(0x31, 0, 0, this.tiles[tileIndex])
oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
DllCall("SetBkMode", "Ptr", dc, "Int", 1)
DllCall("SetTextColor", "Ptr", dc, "UInt", CrusadersTheme.Color(selected ? CrusadersTheme.Accent : CrusadersTheme.Ink))
textRect := Buffer(16)
NumPut("Int", left + 7, "Int", top + 3, "Int", right - 7, "Int", bottom - 3, textRect)
DllCall("DrawText", "Ptr", dc, "Str", this.tiles[tileIndex].Text, "Int", -1,
"Ptr", textRect, "UInt", 0x11)
DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
DllCall("SelectObject", "Ptr", dc, "Ptr", oldPen)
DllCall("SelectObject", "Ptr", dc, "Ptr", oldBrush)
DllCall("DeleteObject", "Ptr", pen)
DllCall("DeleteObject", "Ptr", brush)
return true
}
VScroll(wParam, lParam, msg, hwnd) {
if hwnd != this.grid.Hwnd
return
code := wParam & 0xFFFF
position := this.scroll
switch code {
case 0: position -= 40
case 1: position += 40
case 2: position -= 240
case 3: position += 240
case 4, 5:
info := Buffer(28, 0)
NumPut("UInt", 28, "UInt", 0x10, info)
DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", info)
position := NumGet(info, 24, "Int")
case 6: position := 0
case 7: position := 2400
}
this.ScrollTo(position)
return 0
}
Wheel(wParam, lParam, msg, hwnd) {
if !this.open
return
WinGetPos(&left, &top, &width, &height, this.grid)
previous := A_CoordModeMouse
CoordMode("Mouse", "Screen")
MouseGetPos(&x, &y)
CoordMode("Mouse", previous)
if x < left || y < top || x >= left + width || y >= top + height
return
delta := (wParam >> 16) & 0xFFFF
if delta >= 32768
delta -= 65536
this.ScrollTo(this.scroll - Round(delta / 120) * 40)
return 0
}
ConfigToolKey(key, lParam, msg, hwnd) {
if hwnd != this.configTool.Hwnd || key != 13
return
this.TransferIndex(this.configTool.Value)
return 0
}
TransferIndex(source, destination := 0) {
global testRunning
if testRunning {
this.status.Text := "Stop the run before copying indexes"
return false
}
if !RegExMatch(source, "^\d+$") || Integer(source) < 1 || Integer(source) > 90 {
this.status.Text := "Source must be an index number from 1 to 90"
return false
}
if destination && (!RegExMatch(destination, "^\d+$") || Integer(destination) < 1 || Integer(destination) > 90) {
this.status.Text := "Destination must be an index number from 1 to 90"
return false
}
if !this.Apply()
return false
source := Integer(source)
destination := destination ? Integer(destination) : this.selected
if source = destination
return true
previous := this.indexes[destination]
this.Remember()
try {
this.indexes[destination] := this.indexes[source].Clone()
this.Save()
this.SetSelected(destination)
this.configTool.Value := ""
this.status.Text := "Copied Index " source " to Index " destination
return true
} catch Error as err {
this.indexes[destination] := previous
this.status.Text := "Copy not saved: " err.Message
return false
}
}
Delete(*) {
this.Remember()
this.indexes[this.selected] := this.NewIndex()
this.dirty := false
SetTimer(this.saveTimer, 0)
this.Save()
this.SetSelected(this.selected)
}
Move(direction) {
if !this.Apply()
return
destination := this.selected + direction
if destination < 1 || destination > 90
return
this.Remember()
item := this.indexes[this.selected]
this.indexes[this.selected] := this.indexes[destination]
this.indexes[destination] := item
this.Save()
this.SetSelected(destination)
this.ScrollTo(((destination - 1) // 3) * 80)
}
ResetConfig() {
previous := this.indexes, preferences := this.preferences.Clone()
history := this.history.Clone(), future := this.future.Clone()
try {
this.Remember()
this.indexes := []
loop 90
this.indexes.Push(this.NewIndex())
this.preferences["Team"] := "0"
this.Validate()
this.Save()
} catch Error as err {
this.indexes := previous, this.preferences := preferences
this.history := history, this.future := future
throw err
}
this.SetSelected(1)
}
Undo(redo := false) {
if !this.Apply()
return
source := redo ? this.future : this.history
destination := redo ? this.history : this.future
if !source.Length {
this.status.Text := redo ? "Nothing to redo" : "Nothing to undo"
return
}
destination.Push(this.Snapshot())
this.indexes := source.Pop()
this.Save()
this.SetSelected(this.selected)
}
BeginPick() {
global macroWindow, testRunning
if !this.open || (testRunning && !CrusadersRuntime.paused)
return
if !this.Apply()
return
if this.pickMode
macroWindow.CancelPick()
else
macroWindow.BeginCoordinates()
}
PickLive(*) {
AADisplay.UsePhysicalPixels()
if !this.pickMode
return
previous := A_CoordModeMouse
CoordMode("Mouse", "Screen")
MouseGetPos(&mouseX, &mouseY)
CoordMode("Mouse", previous)
global macroWindow
WinGetClientPos(&left, &top, , , macroWindow.gui)
x := mouseX - left - macroWindow.mapLeft
y := mouseY - top - macroWindow.mapTop
if x < 0 || y < 0 || x >= macroWindow.mapDisplayWidth || y >= macroWindow.mapDisplayHeight
return
macroWindow.PickCoordinates(Floor(x * this.mapWidth / macroWindow.mapDisplayWidth),
Floor(y * this.mapHeight / macroWindow.mapDisplayHeight))
}
ApplyLiveCoordinate(x, y, width, height) {
this.mapWidth := width
this.mapHeight := height
this.x.Value := Max(0, Min(width - 1, Round(x)))
this.y.Value := Max(0, Min(height - 1, Round(y)))
this.dirty := true
return this.Apply()
}
Capture(*) {
AADisplay.UsePhysicalPixels()
global testRunning, macroWindow
if !this.Apply()
return
wasPaused := CrusadersRuntime.paused
previousPage := macroWindow.page
wasPicking := this.pickMode
if testRunning && !wasPaused
macroWindow.PauseRun()
token := 0
bitmap := 0
try {
if !macroWindow.ShowGame()
throw Error("Roblox window not found")
Sleep(200)
WinGetClientPos(&left, &top, &width, &height, "ahk_id " macroWindow.game)
token := Gdip_Startup()
bitmap := Gdip_BitmapFromScreen(left "|" top "|" width "|" height)
if !bitmap
throw Error("Could not capture Roblox")
SplitPath(this.imagePath, , &directory)
DirCreate(directory)
if Gdip_SaveBitmapToFile(bitmap, this.imagePath) != 0
throw Error("Could not save map image")
AAInstalledAssets.ImageVersion(this.imagePath,true)
this.mapWidth := width
this.mapHeight := height
this.Save()
CrusadersLog("Map image replaced: " CrusadersMapName(this.path, this.preferences["Mode"]))
} catch Error as err {
CrusadersLog("Map capture failed: " err.Message)
this.status.Text := err.Message
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
macroWindow.Navigate(previousPage, true)
if wasPicking
macroWindow.BeginCoordinates()
if testRunning && !wasPaused
macroWindow.PauseRun()
}
}
}
CrusadersMapName(path, mode := "") {
explicit := FileExist(path) ? IniRead(path, "Settings", "DisplayName", "") : ""
if explicit != ""
return explicit
return CrusadersCatalog.Name(path)
}
class CrusadersTasks {
__New(root) {
this.root := root
this.path := root "\..\ModeList\modelist.txt"
this.items := []
this.cursor := 0
this.run := 0
this.nextAction := ""
this.active := []
if FileExist(this.path) {
count := Integer(IniRead(this.path, "Queue", "Count", "0"))
if count < 0 || count > 500
throw Error("Task count must be between 0 and 500.")
loop count {
item := this.NewTask()
section := "Task" A_Index
for key in ["mode", "config", "difficulty", "bossRushMode", "makimaCard", "contractPriority", "portalName", "act", "runs", "wait", "enabled"] {
value := IniRead(this.path, section, key, item.%key%)
item.%key% := InStr("|mode|config|difficulty|bossRushMode|makimaCard|contractPriority|portalName|", "|" key "|") ? value : Integer(value)
}
if item.mode = "Raids" || item.mode = "Story" || item.mode = "Legend Stages"
item.config := RegExReplace(item.config,"i)Act[1-6](?=(?:Story|Legend|Raid)\.txt$)","")
this.Validate(item)
this.items.Push(item)
}
}
this.sourceText := FileExist(this.path) ? FileRead(this.path) : ""
}
NewTask() {
return {mode: "Story", config: "PlanetGreenieStory.txt", portalName: "", difficulty: "Normal", bossRushMode: "Traits", makimaCard: "Unit Slot", contractPriority: CrusadersCatalog.DefaultContractPriority, act: 1, runs: 1, wait: 0, enabled: true}
}
static LogDetails(item, mapName := "") {
if mapName = ""
mapName := CrusadersCatalog.Name(item.config)
details := "Gamemode: " (item.mode = "Infinity Castle" ? item.mode : CrusadersCatalog.Folder(item.mode))
if item.mode = "Portals"
details .= " | Portal Name: " item.portalName
else if item.mode != "Infinity Castle"
details .= " | Map: " mapName
if item.mode = "Boss Rush" || item.mode = "Infinity Castle"
details .= " | Trait Mode: " item.bossRushMode
else if item.mode != "Event" && item.mode != "Events" && item.mode != "Portals"
details .= item.mode = "Infinite" ? " | Act: Infinite" : " | Act " item.act
if CrusadersCatalog.HasDifficultySelection(item.mode,mapName)
details .= " | Difficulty: " item.difficulty
details .= " | Runs: " item.runs (item.runs = 1 ? " run" : " runs")
if item.mode = "Boss Rush" && mapName = "Makima"
details .= " | Card Modifier: " item.makimaCard
if item.mode = "Event"
details .= " | Contract Priority: " StrReplace(item.contractPriority,"|"," > ")
if item.wait > 0
details .= " | Wait: " item.wait " ms"
if !item.enabled
details .= " | Enabled: No"
return details
}
Validate(item) {
if item.mode = "Legend Stages" && item.config = "SpiritTownLegend.txt"
item.config := "SpiritInvasionLegend.txt"
if item.mode = "Infinity Mansion" && this.HasOwnProp("root") && !FileExist(this.root "\Infinity Mansion\" item.config)
item.config := StrReplace(CrusadersCatalog.ConfigRelative("Infinity Mansion/" item.config),"Infinity Mansion/","")
if !item.HasOwnProp("portalName")
item.portalName := ""
if item.mode = "Portals"
item.portalName := AAPortalRoute.ValidateName(item.portalName)
if !item.HasOwnProp("contractPriority")
item.contractPriority := CrusadersCatalog.DefaultContractPriority
item.contractPriority := CrusadersCatalog.NormalizeContractPriority(item.contractPriority)
if !item.HasOwnProp("makimaCard")
item.makimaCard := "Unit Slot"
if item.makimaCard != "Unit Slot" && item.makimaCard != "Damage" && item.makimaCard != "Placement Limit"
throw Error("Card must be Unit Slot, Damage, or Placement Limit.")
if !item.HasOwnProp("bossRushMode")
item.bossRushMode := "Traits"
if item.bossRushMode != "Traits" && item.bossRushMode != "Traitless"
throw Error("Boss Rush mode must be Traits or Traitless.")
if !item.HasOwnProp("difficulty")
item.difficulty := "Normal"
if (item.difficulty != "Normal" && item.difficulty != "Hard")
|| (CrusadersCatalog.Folder(item.mode) != "Story" && CrusadersCatalog.Folder(item.mode) != "Raids" && item.mode != "Infinity Mansion" && item.difficulty != "Normal")
throw Error("Normal/Hard difficulty is only configurable for Story, Infinity Mansion, and supported raids.")
if item.mode = "" || !RegExMatch(item.config, "i)^[^\\/:*?" Chr(34) "<>|]+\.txt$")
|| InStr(item.mode, "\") || InStr(item.mode, "/") || InStr(item.mode, "..")
throw Error("Choose a gamemode and text config.")
for key in ["mode", "config"]
if InStr(item.%key%, "`n") || InStr(item.%key%, "`r")
throw Error("Task values must be single-line.")
if item.act < 1 || item.act > 6 || item.runs < 1 || item.runs > 100000 || item.wait < 0 || item.wait > 3600000
throw Error("Acts are 1-6; runs are 1-100000; delay is 0-3600000 ms.")
expected := CrusadersCatalog.Filename(item.mode, CrusadersCatalog.Name(item.config), item.act)
if item.config != expected
throw Error("Act " item.act " requires " expected)
item.difficulty := CrusadersCatalog.EffectiveDifficulty(item.mode, CrusadersCatalog.Name(item.config), item.difficulty)
for key in ["enabled"]
if item.%key% != 0 && item.%key% != 1
throw Error("Task toggles must be 0 or 1.")
}
Save() {
if FileExist(this.path) && FileRead(this.path) != this.sourceText
throw Error("modelist.txt changed externally. Restart to load those changes.")
SplitPath(this.path, , &directory)
DirCreate(directory)
temporary := CrusadersStorage.Temporary(this.path)
try {
text := "[Queue]`r`nCount=" this.items.Length "`r`n"
for index, item in this.items {
this.Validate(item)
body := ""
for key in ["mode", "config", "difficulty", "bossRushMode", "makimaCard", "contractPriority", "portalName", "act", "runs", "wait", "enabled"]
body .= key "=" item.%key% "`n"
text .= "[Task" index "]`r`n" StrReplace(body, "`n", "`r`n")
}
FileAppend(text, temporary, "UTF-16")
CrusadersStorage.Commit(temporary, this.path, this.sourceText)
this.sourceText := FileRead(this.path)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
Commit(items) {
previous := this.items
this.items := items
try this.Save()
catch Error as err {
this.items := previous
throw err
}
}
CopyItems() {
items := []
for item in this.items
items.Push(item.Clone())
return items
}
Add(item) {
this.Validate(item)
if this.items.Length >= 500
throw Error("The task list is full (500 tasks).")
items := this.CopyItems()
items.Push(item.Clone())
this.Commit(items)
return items.Length
}
Update(index, item) {
this.Validate(item)
items := this.CopyItems()
items[index] := item.Clone()
this.Commit(items)
}
Delete(index) {
items := this.CopyItems()
items.RemoveAt(index)
this.Commit(items)
}
Move(index, offset) {
destination := index + offset
if destination < 1 || destination > this.items.Length
return index
items := this.CopyItems()
item := items.RemoveAt(index)
items.InsertAt(destination, item)
this.Commit(items)
return destination
}
Begin(preferences := unset) {
if IsSet(preferences) {
this.standaloneEvent := 0
if preferences.Get("Mode","") = "Events" && preferences.Get("Map","") = "April Fools" {
item := this.NewTask()
item.mode := "Events", item.config := "AprilFools.txt", item.runs := Integer(preferences.Get("Runs","9999"))
this.Validate(item)
this.standaloneEvent := item
}
}
this.remoteQueueChanged := false
this.active := []
this.cursor := 0
this.run := 0
this.nextAction := ""
for item in this.items {
if item.enabled {
if item.mode = "Infinity Castle"
throw Error("Infinity Castle is a placeholder. Gameplay automation is not available yet.")
if item.mode != "Events" && !FileExist(this.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config)
throw Error("Task config missing: " item.mode "\" item.config)
this.active.Push(item.Clone())
}
}
if !this.active.Length && this.HasOwnProp("standaloneEvent") && IsObject(this.standaloneEvent)
this.active.Push(this.standaloneEvent.Clone())
if !this.active.Length
throw Error("Add an enabled task in Modes before starting.")
this.cursor := 1
this.run := 1
this.nextAction := "Join"
return this.Current()
}
Current() {
return this.cursor ? this.active[this.cursor] : 0
}
CompleteMatch(won) {
if this.HasOwnProp("remoteQueueChanged") && this.remoteQueueChanged {
this.remoteQueueChanged := false
this.Begin()
this.nextAction := "Rejoin"
return this.Current()
}
item := this.Current()
if !item
return 0
this.nextAction := "Replay"
this.run += 1
if this.run > item.runs {
this.run := 1
this.nextAction := "Rejoin"
this.cursor += 1
if this.cursor > this.active.Length
this.cursor := 1
}
return this.Current()
}
}
class CrusadersJoinErrorDetected extends Error {
}
class CrusadersAccessDenied extends CrusadersJoinErrorDetected {
}
class CrusadersNewUpdateDetected extends Error {
}
class CrusadersJoinError {
static Matches(bitmap, ocr) {
return this.Kind(bitmap, ocr) != ""
}
static Kind(bitmap, ocr) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
return ""
for id, reason in Map("access-denied", "Access denied", "new-update", "New update",
"teleport-failed", "Teleport failed", "disconnected", "Disconnected", "join-error", "Join error")
if CrusadersDetection.Configured(id) && CrusadersDetection.FindBitmap(bitmap, id)
return reason
update := ocr.Read(bitmap, 145, 210, 510, 130)
if RegExMatch(update, "i)new\s*update\s*has\s*(?:just\s*)?(?:released|been\s*released)")
&& RegExMatch(update, "i)(teleporting|latest\s*server\s*version)")
return "New update"
heading := Trim(ocr.Read(bitmap, 245, 170, 310, 65))
kind := RegExMatch(heading, "i)^Disconnected$") ? "Disconnected"
: RegExMatch(heading, "i)^Join\s*Error$") ? "Join error"
: RegExMatch(heading, "i)^Connection\s*Failed$") ? "Connection failed"
: RegExMatch(heading, "i)^Teleport\s*Failed$") ? "Teleport failed" : ""
body := ocr.Read(bitmap, 214, 258, 373, 75)
if kind != "" && RegExMatch(body, "i)(do\s*not\s*have\s*permission|(?:not\s*authorized|no\s*permission)\s*to\s*join|place\s*that\s*is\s*restricted)")
return "Access denied"
if kind = "" || !RegExMatch(body, "i)(Error\s*Code\s*:\s*\d+|close\s*the\s*client)")
return ""
return kind
}
__New() {
CrusadersVision.Open(this)
this.active := false
this.lastScan := -1
}
Dispose() {
this.active := false
CrusadersVision.Close(this)
}
Visible() {
if !WinActive("ahk_exe RobloxPlayerBeta.exe")
return false
WinGetClientPos(&x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe")
bitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
if !bitmap
return false
try {
this.reason := CrusadersJoinError.Kind(bitmap, this.ocr)
return this.reason != ""
}
finally Gdip_DisposeImage(bitmap)
}
Observe() {
if !this.active || CrusadersRuntime.joining
return
now := CrusadersRuntime.Now()
if this.lastScan >= 0 && now - this.lastScan < 750
return
this.lastScan := now
if !this.Visible()
return
Sleep(100)
if this.Visible() {
if this.reason = "Access denied"
throw CrusadersAccessDenied("Access denied")
if this.reason = "New update"
throw CrusadersNewUpdateDetected("New update released")
throw CrusadersJoinErrorDetected(this.HasOwnProp("reason") ? this.reason : "Join error")
}
}
}
class CrusadersServer {
static PlaceId := "8304191830"
static RecoveryDelay(failures) => Min(60000, 3000 * 2 ** Min(Max(0, failures - 1), 5))
static RetryRecovery(attempt, wait, shouldStop) {
failures := 0
loop {
if shouldStop.Call()
return false
try {
if attempt.Call()
return true
} catch Error as err {
CrusadersLog("Recovery retry: " err.Message)
}
if shouldStop.Call()
return false
failures += 1
delay := this.RecoveryDelay(failures)
CrusadersLog("Recovery cooldown: " delay " ms")
if !wait.Call(delay)
return false
}
}
static RecoverLobby(window, config, route, shouldStop) {
lobby := CrusadersLobby(config, route, shouldStop)
try return CrusadersServer(window, config, shouldStop).Rejoin(lobby)
finally lobby.Dispose()
}
static PrivateLink(preferences) {
return (!preferences.Has("UsePrivateServerLink") || preferences["UsePrivateServerLink"] = "1")
? Trim(preferences["PrivateServer"]) : ""
}
static ShouldRejoinOnStart(preferences) {
return this.PrivateLink(preferences) != "" || preferences["PublicRejoin"] = "1"
}
static FindGameWindow(target := "ahk_exe RobloxPlayerBeta.exe") {
minimized := 0
for hwnd in WinGetList(target) {
try {
WinGetClientPos(, , &width, &height, "ahk_id " hwnd)
if width >= 600 && height >= 400
return hwnd
if WinGetMinMax("ahk_id " hwnd) = -1 && WinGetTitle("ahk_id " hwnd) = "Roblox"
minimized := hwnd
}
}
return minimized
}
static JoinUrl(link) {
link := Trim(link)
if link = ""
return "roblox://placeID=" this.PlaceId
if RegExMatch(link, '[\s\x00-\x1f"<>]')
throw Error("Private server link contains invalid characters. Copy the complete Roblox link again.")
if !RegExMatch(link, "i)^https://(?:www\.)?roblox\.com/(?:games/" this.PlaceId "(?:/[^?]*)?|share)\?")
throw Error("Wrong type of private server link. Paste an Anime Adventures private-server invite: a Roblox games link with privateServerLinkCode, or a Roblox share link with type=Server.")
if RegExMatch(link, "i)[?&]privateServerLinkCode=([a-z0-9_-]+)(?:&|$)", &code)
return "roblox://experiences/start?placeId=" this.PlaceId "&linkCode=" code[1]
if RegExMatch(link, "i)^https://(?:www\.)?roblox\.com/share\?")
&& RegExMatch(link, "i)[?&]code=[a-z0-9_-]+(?:&|$)")
&& RegExMatch(link, "i)[?&]type=Server(?:&|$)")
return link
throw Error("Wrong type of private server link: this link has no valid private-server invite code. Copy the private server invite, not the game page, profile, or experience share link.")
}
__New(window, config, shouldStop) {
this.window := window
this.config := config
this.shouldStop := shouldStop
}
Wait(ms) => CrusadersRuntime.Wait(ms, this.shouldStop)
Existing() => CrusadersServer.FindGameWindow()
ProcessId() => ProcessExist("RobloxPlayerBeta.exe")
StopProcess(pid) => ProcessClose(pid)
Shutdown(graceMs := 3000) {
deadline := CrusadersRuntime.Now() + 15000
gracefulUntil := CrusadersRuntime.Now() + graceMs
lastStopped := 0
while pid := this.ProcessId() {
if !this.Wait(100)
return false
if CrusadersRuntime.Now() >= deadline
throw Error("Roblox process did not exit; no new client was launched.")
if CrusadersRuntime.Now() >= gracefulUntil && pid != lastStopped {
lastStopped := pid
CrusadersLog("Closing remaining Roblox player process before deeplink launch")
try this.StopProcess(pid)
catch Error as err {
if this.ProcessId() = pid
throw Error("Could not close Roblox process: " err.Message)
}
}
}
return this.Wait(500)
}
Close(hwnd) {
WinHide("ahk_id " hwnd)
WinClose("ahk_id " hwnd)
if this.window.originalRegion {
DllCall("DeleteObject", "Ptr", this.window.originalRegion)
this.window.originalRegion := 0
}
}
Launch(url) => CrusadersServer.LaunchUrl(url)
static LaunchUrl(url, launcher := 0) {
try {
if launcher
launcher.Call(url)
else Run(url)
}
catch Error as err {
if InStr(url,"roblox://") = 1
throw Error("Roblox could not open its launch link. Install or repair Roblox Player so Windows can open roblox:// links, then try again.")
throw Error("Could not open the private-server invite. Check that it is a Roblox server invite and that a default browser is configured.")
}
}
Attach(hwnd) => this.window.AttachGame(hwnd)
Now() => CrusadersRuntime.Now()
JoinState(lobby, check := true) {
if check && !lobby.Check()
return ""
bitmap := lobby.Snapshot()
try return lobby.StateBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
}
RejoinOpen(lobby, url, old) {
if this.window.game != old && !this.Attach(old)
throw Error("Could not attach the existing Roblox window.")
lobby.gameWindow := this.window
this.window.ShowGame()
oldPid := this.ProcessId()
leftLobby := false
awayFrames := 0
launchedAt := this.Now()
deadline := launchedAt + 120000
CrusadersLog("Rejoining with Roblox open; waiting for a fresh lobby")
this.Launch(url)
loop {
if this.Now() >= deadline
return false
if !this.Wait(100)
return false
hwnd := this.Existing()
if !hwnd {
leftLobby := true
continue
}
pid := this.ProcessId()
if hwnd != this.window.game || (pid && pid != oldPid) {
leftLobby := true
if this.window.originalRegion {
DllCall("DeleteObject", "Ptr", this.window.originalRegion)
this.window.originalRegion := 0
}
if !this.Attach(hwnd)
throw Error("Could not attach the rejoined Roblox window.")
oldPid := pid
}
try current := this.JoinState(lobby)
catch CrusadersJoinErrorDetected as err {
if this.Now() - launchedAt < 1500
continue
throw err
} catch Error as err {
if this.Existing() != hwnd {
leftLobby := true
continue
}
throw err
}
awayFrames := (current = "" || current = "Teleport") ? awayFrames + 1 : 0
if awayFrames >= 3
leftLobby := true
if leftLobby && InStr("|Lobby|DailyRewards|UpdateLog|", "|" current "|") && current != "" {
remaining := deadline - this.Now()
if remaining <= 0
return false
try {
if !lobby.WaitState("Lobby", remaining)
return false
} catch CrusadersLobbyTimeout {
return false
}
CrusadersLog("Fresh lobby confirmed without closing Roblox")
return true
}
}
}
PauseForAccess() {
global testCancelled
private := CrusadersServer.PrivateLink(this.config.preferences) != ""
message := private ? "Private server access denied. Check your link or permissions."
: "Experience unavailable or access denied. Check your game access."
CrusadersRuntime.SetPaused(true)
this.window.runStatus := "Access denied"
CrusadersLog(message " Macro paused; resume when access is restored.")
CrusadersWebhook.Send(this.window, "Access denied")
while CrusadersRuntime.paused {
if testCancelled
return false
Sleep(50)
}
if testCancelled
return false
this.window.runStatus := "Recovering"
CrusadersLog("Resuming after access pause; retrying join")
return true
}
Rejoin(lobby, afkRecovery := false, permissionAlreadyDenied := false) {
if CrusadersRuntime.joining
throw Error("A Roblox rejoin is already in progress.")
previous := CrusadersRuntime.joining
CrusadersRuntime.joining := true
permissionFailures := permissionAlreadyDenied ? 1 : 0
transientFailures := 0
try {
loop {
if this.shouldStop && this.shouldStop.Call()
return false
CrusadersLog("Rejoining Roblox / waiting for the lobby")
try return this.RejoinAttempt(lobby, afkRecovery)
catch CrusadersAccessDenied {
permissionFailures += 1
if permissionFailures >= 2 {
if !this.PauseForAccess()
return false
permissionFailures := 0
transientFailures := 0
} else {
CrusadersLog("Access denied; retrying once before pausing")
if !this.Wait(3000)
return false
}
}
catch CrusadersJoinErrorDetected as err {
transientFailures += 1
if transientFailures = 1
CrusadersWebhook.Send(this.window, "Recovery", false, err.Message)
if transientFailures >= 3
throw Error("Roblox join failed after 3 attempts; try again later.")
CrusadersLog(err.Message " detected; retrying " (CrusadersServer.PrivateLink(this.config.preferences) = "" ? "public server" : "private server"))
if !this.Wait(3000)
return false
}
}
} finally CrusadersRuntime.joining := previous
}
RejoinAttempt(lobby, afkRecovery := false) {
url := CrusadersServer.JoinUrl(CrusadersServer.PrivateLink(this.config.preferences))
if !this.Wait(1)
return false
old := this.Existing()
if old {
failure := "timed out"
try {
if this.RejoinOpen(lobby, url, old)
return true
} catch CrusadersAccessDenied as err {
throw err
} catch CrusadersJoinErrorDetected as err {
failure := "failed"
CrusadersWebhook.Send(this.window, "Recovery", false, err.Message)
}
if !this.Wait(1)
return false
CrusadersLog("Open-client rejoin " failure "; restarting Roblox")
}
return this.RejoinClosed(lobby, url)
}
RejoinClosed(lobby, url) {
old := this.Existing()
if old
this.Close(old)
if !this.Shutdown()
return false
this.window.game := 0
this.window.original := 0
this.window.originalRegion := 0
if !this.Wait(1)
return false
CrusadersLog(CrusadersServer.PrivateLink(this.config.preferences) = "" ? "Joining public server" : "Joining private server")
this.Launch(url)
deadline := CrusadersRuntime.Now() + 120000
loop {
if !this.Wait(100)
return false
hwnd := this.Existing()
if hwnd {
if !this.Attach(hwnd)
throw Error("Could not attach the rejoined Roblox window.")
break
}
if CrusadersRuntime.Now() >= deadline
throw CrusadersJoinErrorDetected("Lobby timeout (2 minutes)")
}
CrusadersLog("New Roblox instance opened; waiting for lobby confirmation")
lobby.gameWindow := this.window
remaining := deadline - CrusadersRuntime.Now()
if remaining <= 0
throw CrusadersJoinErrorDetected("Lobby timeout (2 minutes)")
try {
if !lobby.WaitState("Lobby", remaining)
return false
} catch CrusadersLobbyTimeout {
throw CrusadersJoinErrorDetected("Lobby timeout (2 minutes)")
}
CrusadersLog("Rejoined lobby confirmed; beginning 5-second instance wait")
return true
}
}
class CrusadersLogFile {
static Path := A_ScriptDir "\Logs\LogFile.txt"
static MaxBytes := 1024 * 1024
static retryAfter := Map()
static Reset(path, text) {
temporary := CrusadersStorage.Temporary(path)
try {
FileAppend(text, temporary, "UTF-8")
CrusadersStorage.Publish(temporary, path)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
static Append(text, path := "", maxBytes := 0) {
path := path = "" ? this.Path : path
maxBytes := maxBytes ? maxBytes : this.MaxBytes
previousCritical := A_IsCritical
Critical("On")
try {
if maxBytes < 128
throw Error("Log size limit is too small.")
bytes := StrPut(text, "UTF-8") - 1
if bytes + 3 > maxBytes {
text := SubStr(text, 1, Max(0, maxBytes // 4 - 16)) " [oversized log entry truncated]`n"
bytes := StrPut(text, "UTF-8") - 1
}
SplitPath(path, , &directory)
DirCreate(directory)
if FileExist(path) && FileGetSize(path) + bytes > maxBytes {
if CrusadersRuntime.Tick() < this.retryAfter.Get(path, 0)
return false
try {
this.Reset(path, text)
if this.retryAfter.Has(path)
this.retryAfter.Delete(path)
return true
} catch Error {
this.retryAfter[path] := CrusadersRuntime.Tick() + 60000
return false
}
}
FileAppend(text, path, "UTF-8")
return true
} catch Error {
return false
} finally Critical(previousCritical)
}
}
class CrusadersProcessLog {
static Capitalize(message) {
start := 1
while RegExMatch(message,"(^|\s)([a-z][^\s]*)",&word,start) {
position := word.Pos(2), value := word[2]
minor := InStr("|a|an|the|and|or|but|for|to|of|in|on|at|by|with|from|as|into|my|your|x|ms|","|" Trim(value,",.;:!?()[]") "|")
if (position=1 || !minor) && !RegExMatch(value,"[\\/:]|\.[A-Za-z0-9]")
message := SubStr(message,1,position-1) StrUpper(SubStr(value,1,1)) SubStr(message,position+1)
start := position+StrLen(value)
}
return message
}
static Display(message) {
if RegExMatch(message, "i)^(MAX capacity |Placement preview |Placement upgrade debug:|Upgrade diagnostic:|Upgrade key T sent once:|Unit upgrade observed:|Hunter contracts: found |Hunter contracts: (end|beginning) of list|Lobby: map list scrolled |Start prompt settled|Start prompt closed|Map detected \(Start prompt visible\))")
return ""
rules := [
["^Daily challenge route recording completed:.*$", "Daily challenge route recorded"],
["^Index (\d+): placing slot (\d+) at .*$", "Index $1: Placing Unit $2"],
["^Index (\d+): waiting 0 ms before action$", ""],
["^Index (\d+): waiting (\d+) ms before action$", "Index $1: Waiting $2 ms"],
["^Index (\d+) completed$", "Index $1 complete"],
["^Unit placement confirmed: slot (\d+)$", "Unit $1 placed"],
["^Placement retry: reselecting slot (\d+).*$", "Retrying Unit $1 placement"],
["^Unit panel not detected; retrying placement after (\d+) ms$", "Waiting to place unit ($1 ms placement delay)"],
["^Unit panel disappeared;.*$", "Reselecting unit"],
["^Unit panel restored.*$", "Unit selected"],
["^Unit target upgrade confirmed: (\d+)$", "Upgrade complete: Level $1"],
["^Waiting for money:.*$", "Waiting for money"],
["^Waiting for readable upgrade price and money$", "Checking upgrade cost"],
["^Upgrade reading temporarily unavailable.*$", "Checking upgrade level"],
["^Closing unit panel with X at .*$", "Closing unit panel"],
["^Unit panel closed with X$", ""],
["^Configured indexes finished;.*$", "All indexes complete. Waiting for match result"],
["^Unit actions paused; waiting for match result:.*$", "Waiting for match result"],
["^Config finished: cleanup click.*$", "Waiting for match result"],
["^Auto Ability skipped:.*$", "Auto Ability unavailable; skipping"],
["^Auto Ability: On confirmed$", "Auto Ability enabled"],
["^Auto Ability: already On;.*$", "Auto Ability already enabled"],
["^Auto Ability: Off detected;.*$", "Enabling Auto Ability"],
["^Gojo v Sukuna: (.+) path selected;.*$", "Gojo v Sukuna: $1 selected"],
["^Dio Rewrite: (.+) selected at upgrade 3;.*$", "Dio: $1 selected"],
["^Roblox attached:.*$", "Roblox Attached"],
["^Mode list saved:.*$", "Mode list saved"],
["^Hunter contracts: choosing (.+) by priority$", "Choosing $1"],
["^Hunter contracts: (.+) unavailable or changed;.*$", "$1 unavailable; trying next priority"],
["^Hunter next gate: Start prompt confirmed;.*$", "Next gate ready"],
["^Hunter contract verified: (.+) / Normal selected$", "$1 selected (Normal)"],
["^Hunter NPC: E interaction sent$", "Talking to Hunter NPC"],
["^Boss Rush NPC: E interaction sent$", "Talking to Boss Rush NPC"],
["^Makima card selection confirmed: (.+) /.*$", "Card selected: $1"],
["^Camera tech: Makima wrong angle detected;.*$", "Adjusting camera angle"],
["^Camera tech: Makima correct angle confirmed.*$", "Camera angle ready"],
["^Replay camera retained;.*$", "Keeping current camera"],
["^Replay clicked once;.*$", "Replaying match"],
["^Pick Next Gate clicked once;.*$", "Picking next gate"],
["^Replay confirmed:.*$", "Next match ready"],
["^Victory confirmed; holding result screen for (\d+) ms.*$", "Victory! Waiting $1 ms before continuing"],
["^(Victory|Defeat) detected during active action;.*$", "$1 detected"],
["^(Victory|Defeat) confirmed: match \d+; wins (\d+), losses (\d+)$", "$1! Wins: $2 | Losses: $3"],
["^Starting from existing (.+) screen;.*$", "Continuing from $1 screen"],
["^Match ended before remaining indexes finished;.*$", "Match ended. Checking result"],
["^Lobby: waiting (\d+) ms after Play$", "Opening Mode Menu"],
["^Lobby: (.+) clicked$", "Selecting $1"],
["^Lobby: (.+) detected$", "$1 ready"],
["^Lobby selection verified: (.+)$", "Stage selected: $1"],
["^Rejoined lobby confirmed;.*$", "Lobby joined. Waiting 5 seconds"],
["^Lobby detected; waiting 5 seconds.*$", "Lobby joined. Waiting 5 seconds"],
["^Lobby detected; using current session$", "Lobby ready"],
["^Closing remaining Roblox player process.*$", "Preparing to rejoin"],
["^New Roblox instance opened;.*$", "Roblox Opened. Waiting for a Fresh Lobby"],
["^Match entry confirmed: Start vote detected$", "Match ready"],
["^Yes clicked$", "Starting match"],
["^Upgrade debug: Selected unit: upgrade (\w+) / total (\w+)( \(MAX\))? /.*$", "Selected unit: Level $1 of $2$3"],
["^Upgrade debug: number unreadable;.*$", "Cannot read upgrade level. Select a unit and try again"],
["^Upgrade debug: number changed between readings;.*$", "Upgrade level is changing. Try again"],
["^Hunter contract priority saved:.*$", "Contract priority saved"],
["^Map image replaced /.*$", "Map image updated"]
]
for rule in rules {
if RegExMatch(message, rule[1])
return this.Capitalize(RegExReplace(message, rule[1], rule[2]))
}
return this.Capitalize(message)
}
}
class CrusadersChallengeDue extends Error {
}
class CrusadersChallenges {
static MapRegion := {x: 24, y: 189, width: 215, height: 36}
static DailyFinished(bitmap, ocr) {
text := CrusadersOcr.NormalizeLabels(ocr.Read(bitmap, 180, 435, 440, 55, 3))
return !!RegExMatch(text, "i)\balready\s*finished\s*(?:this\s*)?daily\s*challenge\b")
}
static HalfHourlyFinished(bitmap, ocr) {
text := CrusadersOcr.NormalizeLabels(ocr.Read(bitmap, 140, 425, 520, 75, 3))
if RegExMatch(text, "i)\bdaily\b")
return false
return !!RegExMatch(text, "i)\balready\s*(?:finished|completed)\s*(?:this\s*)?(?:(?:half\W*hourly|half\W*hour)\s*)?challenge\b")
}
static MapFromText(text) {
normalized := RegExReplace(StrLower(CrusadersOcr.NormalizeLabels(text)), "[^a-z0-9]", "")
aliases := Map("westcityruined", "West City", "shibuyacity", "Shibuya",
"marinesford", "Marine Ford")
if aliases.Has(normalized)
return aliases[normalized]
for name in CrusadersCatalog.Maps["Challenges"]
if normalized = RegExReplace(StrLower(name), "[^a-z0-9]", "")
return name
return ""
}
static ReadyMap(bitmap, ocr) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
throw Error("Challenge detection requires an 800 x 599 client.")
if !RegExMatch(ocr.Read(bitmap, 43, 152, 174, 30), "i)Game will begin soon")
|| !RegExMatch(ocr.Read(bitmap, 280, 464, 242, 56), "i)^Start$")
return ""
for scale in [3, 5] {
region := this.MapRegion
text := ocr.Read(bitmap, region.x, region.y, region.width, region.height, scale)
name := this.MapFromText(text)
if name != ""
return name
}
return ""
}
static ConfigForMap(config, name) {
path := CrusadersCatalog.Resolve(config.configRoot, "Challenges", name, 1)
if !FileExist(path)
throw Error("Challenge config missing: " path)
candidate := CrusadersSelector(path, "", config.settingsFile, config.imageRoot)
if candidate.preferences["Mode"] != "Challenges" || candidate.preferences["Map"] != name
throw Error("Challenge config does not match the detected map.")
return candidate
}
static EasternTime(utc := A_NowUTC) {
static zone := 0
if !zone {
candidate := Buffer(432, 0)
loop 512 {
status := DllCall("advapi32\EnumDynamicTimeZoneInformation", "UInt", A_Index - 1, "Ptr", candidate, "UInt")
if status != 0
break
if StrGet(candidate.Ptr + 172, 128, "UTF-16") = "Eastern Standard Time" {
zone := candidate
break
}
}
if !zone
throw Error("Windows Eastern time zone could not be loaded.")
}
universal := Buffer(16, 0)
localTime := Buffer(16, 0)
for field in [[0, 1, 4], [2, 5, 2], [6, 7, 2], [8, 9, 2], [10, 11, 2], [12, 13, 2]]
NumPut("UShort", Integer(SubStr(utc, field[2], field[3])), universal, field[1])
if !DllCall("kernel32\SystemTimeToTzSpecificLocalTimeEx", "Ptr", zone, "Ptr", universal, "Ptr", localTime, "Int")
throw Error("Daily challenge reset time could not be converted.")
return Format("{:04}{:02}{:02}{:02}{:02}{:02}", NumGet(localTime, 0, "UShort"), NumGet(localTime, 2, "UShort"),
NumGet(localTime, 6, "UShort"), NumGet(localTime, 8, "UShort"), NumGet(localTime, 10, "UShort"), NumGet(localTime, 12, "UShort"))
}
static DailyCycle(utc := A_NowUTC) => SubStr(DateAdd(this.EasternTime(utc), -20, "Hours"), 1, 8)
static SecondsUntilDaily(utc := A_NowUTC) {
cycle := this.DailyCycle(utc)
low := 0, high := 90000
while low + 1 < high {
middle := (low + high) // 2
if this.DailyCycle(DateAdd(utc, middle, "Seconds")) = cycle
low := middle
else
high := middle
}
return high
}
__New(preferences, stateFile := "") {
this.enabled := Integer(preferences["ChallengeEnabled"])
this.dailyEnabled := Integer(preferences.Get("DailyChallengeEnabled", "0"))
this.stateFile := stateFile
this.lastDailyCycle := stateFile != "" ? IniRead(stateFile, "Daily", "LastAttempt", "") : ""
if this.lastDailyCycle != "" && !RegExMatch(this.lastDailyCycle, "^\d{8}$")
throw Error("Daily challenge completion record is invalid.")
this.dailyPending := false
this.dailyDeferred := false
this.startupDailyCheck := false
this.activeKind := ""
this.activeDailyCycle := ""
this.forceLeave := Integer(preferences["ChallengeForceLeave"])
this.firstMode := preferences["ChallengeFirstMode"]
this.pending := false
this.active := false
this.lastSlot := ""
}
static Slot(stamp) {
return SubStr(stamp, 1, 10) (Integer(SubStr(stamp, 11, 2)) < 30 ? "00" : "30")
}
static SecondsUntil(stamp := A_NowUTC) {
return 1800 - (Mod(Integer(SubStr(stamp, 11, 2)), 30) * 60 + Integer(SubStr(stamp, 13, 2)))
}
Begin(stamp := A_Now, utc := A_NowUTC) {
this.lastSlot := CrusadersChallenges.Slot(stamp)
this.pending := this.enabled && this.firstMode = "Challenges"
this.startupDailyCheck := !!this.dailyEnabled
this.dailyDeferred := false
this.active := false
this.activeKind := ""
this.Poll(stamp, utc)
if this.DailyDue() && this.enabled
this.pending := true
}
Poll(stamp := A_Now, utc := A_NowUTC) {
slot := CrusadersChallenges.Slot(stamp)
if this.lastSlot = ""
this.lastSlot := slot
if slot > this.lastSlot {
this.lastSlot := slot
this.dailyDeferred := false
if this.enabled && (!this.active || this.activeKind = "Daily")
this.pending := true
}
if this.dailyEnabled {
cycle := CrusadersChallenges.DailyCycle(utc)
this.dailyPending := this.startupDailyCheck || this.lastDailyCycle = "" || cycle > this.lastDailyCycle
}
return this.pending || this.DailyDue()
}
DailyDue() => this.dailyEnabled && this.dailyPending && !this.dailyDeferred
ShouldLeave(matchFinished := false) {
return ((this.enabled && this.pending) || this.DailyDue())
&& !this.active && (this.forceLeave || matchFinished)
}
InterruptIfDue(stamp := A_Now) {
this.Poll(stamp)
if this.ShouldLeave(false)
throw CrusadersChallengeDue(this.DailyDue() ? "Daily challenge due" : "Half-hourly challenge due")
}
Take(utc := A_NowUTC) {
if this.active || !((this.enabled && this.pending) || this.DailyDue())
return false
this.activeKind := this.DailyDue() ? "Daily" : "Half Hourly"
if this.activeKind = "Daily"
this.activeDailyCycle := CrusadersChallenges.DailyCycle(utc)
else
this.pending := false
this.active := true
return true
}
CompleteAttempt() {
if !this.active
throw Error("No active challenge attempt.")
if this.activeKind = "Daily" {
this.RecordDailyAttempt()
if this.enabled
this.pending := true
}
this.active := false
this.activeKind := ""
return "Rejoin"
}
RecordDailyAttempt() {
if this.activeKind != "Daily"
return
this.startupDailyCheck := false
if this.stateFile != "" && this.lastDailyCycle != this.activeDailyCycle {
SplitPath(this.stateFile, , &directory)
DirCreate(directory)
IniWrite(this.activeDailyCycle, this.stateFile, "Daily", "LastAttempt")
}
this.lastDailyCycle := this.activeDailyCycle
this.dailyPending := false
}
static EnsureConfigs(configRoot, settingsFile, imageRoot) {
CrusadersCatalog.MigrateChallenges(configRoot,settingsFile)
for name in CrusadersCatalog.Maps["Challenges"] {
path := CrusadersCatalog.Resolve(configRoot, "Challenges", name, 1)
if FileExist(path)
continue
model := CrusadersSelector(path, "", settingsFile, imageRoot)
model.preferences["Mode"] := "Challenges"
model.preferences["Team"] := "0"
model.preferences["Map"] := name
model.preferences["DisplayName"] := name
story := ""
for storyName in CrusadersCatalog.StoryMaps
if storyName=name {
story := CrusadersCatalog.Resolve(configRoot,"Story",name,1)
break
}
if FileExist(story) {
image := IniRead(story, "Map", "Image", "")
storyImage := CrusadersCatalog.ImageDirectory(imageRoot, "Story") "\" image
if image != "" && !InStr(image, "\") && !InStr(image, "/") && !InStr(image, "..") && FileExist(storyImage) {
if !FileExist(model.imagePath)
FileCopy(storyImage, model.imagePath)
model.mapWidth := Integer(IniRead(story, "Map", "Width", "0"))
model.mapHeight := Integer(IniRead(story, "Map", "Height", "0"))
}
}
model.Save()
}
for name in CrusadersCatalog.CastleMaps {
path := CrusadersCatalog.Resolve(configRoot,"Infinity Castle",name,1)
if FileExist(path)
continue
model := CrusadersSelector(path,"",settingsFile,imageRoot)
model.preferences["Mode"] := "Infinity Castle"
model.preferences["Map"] := name
model.preferences["DisplayName"] := name
model.Save()
}
}
}
class CrusadersWindow {
__New(webShell := false) {
AADisplay.UsePhysicalPixels()
global selector
this.webShell := webShell
selector.webShell := webShell
this.game := this.HasOwnProp("uiTest") && this.uiTest ? 0 : CrusadersServer.FindGameWindow()
this.original := 0
this.gameWidth := 800
this.gameHeight := 600
this.outerWidth := 816
this.outerHeight := 638
this.offsetX := 8
this.offsetY := 31
this.owner := 0
this.wrapperMinimized := false
this.restoring := false
this.fullscreenNormalizing := false
this.fullscreenRetryAfter := 0
this.gameResizeRetryAfter := 0
this.gameResizing := false
this.originalRegion := 0
this.entries := []
this.page := "main"
this.startConsumed := false
this.startRequested := false
this.startQueued := false
this.pages := Map("main", [], "gamemodes", [], "settings", [])
this.nav := Map()
this.settingsFields := Map()
this.settingsGroups := Map("General", [], "Delays", [], "Keybinds", [], "Challenges", [])
this.modeConfigPath := selector.path
this.configScope := "Current Mode"
this.settingsTab := "General"
this.tasks := CrusadersTasks(selector.configRoot)
if !FileExist(this.tasks.path) || RegExMatch(this.tasks.sourceText, "im)^(Repeat|retryLoss|stopLoss|name)=")
this.tasks.Save()
this.editingTask := 0
this.renderingTasks := false
this.loadingTask := false
this.taskSaveTimer := ObjBindMethod(this, "AutoSaveTask")
this.taskSelectTimer := ObjBindMethod(this, "LoadSelectedTask")
this.pendingTaskSelection := 0
this.idleCleanupEnabled := false
this.idleCleanupPaused := false
this.idleCleanupTimer := ObjBindMethod(this, "IdleCleanupTick")
this.tooltips := Map()
this.lastTooltip := 0
this.boundKeys := []
this.startedAt := 0
this.runStatus := "Idle"
this.routeRecorder := CrusadersRouteRecorder(ObjBindMethod(this, "Log"))
this.challengeRouteRecorder := CrusadersRouteRecorder(ObjBindMethod(this, "Log"))
this.challengeRouteRecorder.mode := "Challenges"
this.dailyRouteRecorder := CrusadersRouteRecorder(ObjBindMethod(this, "Log"))
this.dailyRouteRecorder.mode := "Daily Challenges"
this.samuraiRouteRecorder := CrusadersRouteRecorder(ObjBindMethod(this, "Log"))
this.samuraiRouteRecorder.mode := "Samurai Match"
this.inputRecorder := CrusadersRecording(this)
this.wins := 0
this.modeRuns := 0, this.challengeRuns := 0
this.losses := 0
this.resultEvents := []
this.resultAwaitingReplay := false
if this.game && !this.EnsureWindowed(this.game)
this.game := 0
if this.game {
WinGetPos(&x, &y, &w, &h, "ahk_id " this.game)
this.original := {x: x, y: y, w: w, h: h, style: WinGetStyle("ahk_id " this.game), exStyle: WinGetExStyle("ahk_id " this.game)}
if webShell {
this.ApplyGameFrame(this.game, false, true)
DllCall("SetWindowRgn", "Ptr", this.game, "Ptr", 0, "Int", true)
} else
this.SetGameFrame(this.game, true)
WinGetPos(, , &w, &h, "ahk_id " this.game)
info := Buffer(40, 0)
SendMessage(0x24, 0, info.Ptr, , "ahk_id " this.game)
WinGetClientPos(, , &clientWidth, &clientHeight, "ahk_id " this.game)
this.outerWidth := Max(NumGet(info, 24, "Int"), 800 + w - clientWidth)
this.outerHeight := Max(NumGet(info, 28, "Int"), 600 + h - clientHeight)
if clientWidth != 800 || clientHeight != 600 || WinGetMinMax("ahk_id " this.game) != 0 {
if WinGetMinMax("ahk_id " this.game) != 0 {
WinRestore("ahk_id " this.game)
}
WinMove(, , this.outerWidth, this.outerHeight, "ahk_id " this.game)
}
if !webShell
this.ApplyGameFrame(this.game, true)
WinGetPos(&outerX, &outerY, , , "ahk_id " this.game)
WinGetClientPos(&clientX, &clientY, &width, &height, "ahk_id " this.game)
this.offsetX := clientX - outerX
this.offsetY := clientY - outerY
this.gameWidth := width
this.gameHeight := height
region := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
if DllCall("GetWindowRgn", "Ptr", this.game, "Ptr", region)
this.originalRegion := region
else
DllCall("DeleteObject", "Ptr", region)
}
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
AADisplay.UsePhysicalPixels()
this.gui := Gui("-DPIScale -Caption " (webShell ? "-Border" : "+Border") " +MinimizeBox -MaximizeBox", "Bayzo's AA Macro v2.2")
CrusadersTheme.ApplyAppIcon(this.gui)
this.gui.BackColor := webShell ? "18191C" : CrusadersTheme.Background
this.gui.SetFont("s10 c" CrusadersTheme.Ink, "Segoe UI")
this.backgroundPainter := ObjBindMethod(this, "PaintBackground")
OnMessage(0x14, this.backgroundPainter)
if FileExist(CrusadersTheme.Mascot)
this.gui.AddPicture("x12 y10 w28 h28", CrusadersTheme.Mascot)
title := this.gui.AddText("x52 y14 w360 h24 BackgroundTrans", "Bayzo's AA Macro v2.2")
title.SetFont("s11 bold")
title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.gui))
this.status := this.gui.AddText("x890 y15 w290 h22 Right BackgroundTrans c" CrusadersTheme.Muted, "Ready")
this.minimizeButton := this.gui.AddButton("x1192 y8 w38 h32", Chr(0xE921))
this.closeButton := this.gui.AddButton("x1236 y8 w38 h32", Chr(0xE8BB))
for control in [this.minimizeButton, this.closeButton]
control.SetFont("s10", "Segoe MDL2 Assets")
this.minimizeButton.OnEvent("Click", ObjBindMethod(this, "Minimize"))
this.closeButton.OnEvent("Click", ObjBindMethod(this, "Close"))
this.tooltips[this.minimizeButton.Hwnd] := "Minimize macro"
this.tooltips[this.closeButton.Hwnd] := "Close macro"
row := 0
for item in [{page: "main", label: "Main", glyph: 0xE80F}, {page: "indexes", label: "Indexes", glyph: 0xE8A5},
{page: "gamemodes", label: "Modes", glyph: 0xE7FC}, {page: "settings", label: "Settings", glyph: 0xE713}] {
y := 74 + row * 74
button := this.gui.AddButton("x8 y" y " w42 h38", Chr(item.glyph))
button.SetFont("s15", "Segoe MDL2 Assets")
button.OnEvent("Click", ObjBindMethod(this, "NavClicked", item.page))
this.gui.AddText("x2 y" (y + 42) " w54 h20 Center BackgroundTrans", item.label).SetFont("s8")
this.nav[item.page] := button
row += 1
}
this.gameHeading := this.gui.AddText("x84 y64 w800 h24 BackgroundTrans", "Current Game")
this.gameHeading.SetFont("s11 bold")
this.mapPicture := this.gui.AddPicture("x84 y94 w800 h600 Hidden", "")
this.mapMarkers := []
this.markerByHwnd := Map()
this.markerDrawHandler := ObjBindMethod(this, "DrawMapMarker")
OnMessage(0x2B, this.markerDrawHandler)
selector.Attach(this.gui)
this.BuildMain()
this.BuildModes()
this.BuildSettings()
this.logControls := []
this.logControls.Push(this.gui.AddText("x84 y710 w460 h22 BackgroundTrans", "Process Log"))
this.logBox := this.gui.AddEdit("x84 y740 w460 h108 ReadOnly Multi -WantReturn Background17181B", "")
this.logBox.SetFont("s9")
this.logControls.Push(this.logBox)
this.logControls.Push(this.gui.AddText("x560 y710 w192 h22 BackgroundTrans", "Current Config"))
this.scopeField := this.gui.AddDropDownList("x560 y740 w192 Choose1", ["Current Mode", "Challenges", "Infinity Mansion", "Dungeons"])
this.scopeConfigField := this.gui.AddDropDownList("x560 y780 w192 Choose1 Disabled", ["Use Modes Tab"])
this.logControls.Push(this.scopeField, this.scopeConfigField)
this.scopeField.OnEvent("Change", ObjBindMethod(this, "ScopeChanged"))
this.scopeConfigField.OnEvent("Change", ObjBindMethod(this, "ScopeConfigChanged"))
this.logControls.Push(this.gui.AddText("x768 y710 w116 h22 BackgroundTrans", "Actions"))
this.saveConfigButton := this.gui.AddButton("x768 y740 w116 h34", "Save Config")
this.saveConfigButton.OnEvent("Click", ObjBindMethod(this, "SaveConfig"))
this.logControls.Push(this.saveConfigButton)
this.logControls.Push(this.gui.AddText("x560 y819 w54 h24 BackgroundTrans", "Team:"))
this.teamField := this.gui.AddEdit("x618 y816 w60 h28 Number", selector.preferences["Team"])
this.teamField.OnEvent("Change", ObjBindMethod(this, "TeamChanged"))
this.logControls.Push(this.teamField)
this.logControls.Push(selector.undoButton, selector.redoButton)
this.tooltips[selector.undoButton.Hwnd] := "Undo config change"
this.tooltips[selector.redoButton.Hwnd] := "Redo config change"
this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
this.moveHandler := ObjBindMethod(this, "Moved")
this.moveLoopHandler := ObjBindMethod(this, "MoveLoop")
this.windowMoving := false
this.sizeHandler := ObjBindMethod(this, "Sized")
this.activateHandler := ObjBindMethod(this, "Activated")
this.hoverHandler := ObjBindMethod(this, "HoverTool")
this.tooltipTimer := ObjBindMethod(this, "HideTooltip")
OnMessage(0x0003, this.moveHandler)
OnMessage(0x0231, this.moveLoopHandler)
OnMessage(0x0232, this.moveLoopHandler)
OnMessage(0x0005, this.sizeHandler)
OnMessage(0x0006, this.activateHandler)
OnMessage(0x200, this.hoverHandler)
this.ApplyCompactLayout()
if !webShell {
CrusadersTheme.Apply(this.gui)
CrusadersTheme.Apply(selector.grid, true)
}
this.gui.Show((webShell ? "Hide " : "") "w1288 h832")
if this.game {
getter := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
this.owner := DllCall(getter, "Ptr", this.game, "Int", -8, "Ptr")
if !webShell {
WinSetExStyle((this.original.exStyle | 0x40000) & ~0x80, "ahk_id " this.game)
this.SetGameFrame(this.game, true)
this.Arrange()
WinShow("ahk_id " this.game)
this.RaiseGame()
}
this.Log("Roblox attached: " this.gameWidth " x " this.gameHeight)
} else
this.Log("Roblox window not found")
OnExit(ObjBindMethod(this, "Restore"))
this.ApplyRuntimeSettings()
this.BindKeys()
this.fullscreenCondition := ObjBindMethod(this, "BlockFullscreen")
HotIf(this.fullscreenCondition)
Hotkey("$*F11", ObjBindMethod(this, "FullscreenKey"), "On")
HotIf()
this.pickCondition := ObjBindMethod(this, "CanPickCoordinates")
HotIf(this.pickCondition)
Hotkey("RButton", ObjBindMethod(selector, "PickLive"), "On")
HotIf()
if this.tasks.items.Length
this.LoadTask(1)
this.Navigate("main", true)
this.updateTimer := ObjBindMethod(this, "UpdateStats")
SetTimer(this.updateTimer, 1000)
this.LogConfig()
}
AddPage(page, type, options, value := "") {
control := this.gui.Add(type, options, value)
if page != "settings" {
control.GetPos(&x, &y, &w, &h)
control.Move(x - 16, page = "gamemodes" ? this.ModeY(y) : y - 12,
w, type = "ListView" ? Round(h * 0.77) : h)
}
this.pages[page].Push(control)
return control
}
ModeY(y) => 52 + Round((y - 64) * 0.77)
ApplyCompactLayout() {
global selector
selector.CompactEditor()
this.gameHeading.Move(64, 52, 800, 22)
this.mapPicture.Move(64, 76, 800, 600)
for control in this.pages["settings"] {
control.GetPos(&x, &y, &w, &h)
control.Move(x - 20, y - 12, w, y > 790 ? 28 : h)
}
for group, controls in this.settingsGroups
for control in controls {
control.GetPos(&x, &y)
control.Move(x - 20, y - 12)
}
this.logControls[1].Move(64, 700, 588, 22)
this.logBox.Move(64, 728, 588, 86)
this.logControls[3].Move(670, 700, 210, 22)
this.scopeField.Move(670, 728, 210)
this.scopeConfigField.Move(670, 763, 210)
this.logControls[8].Move(670, 800, 54, 22)
this.teamField.Move(728, 796, 60, 26)
this.logControls[6].Move(900, 700, 180, 22)
this.saveConfigButton.Move(900, 728, 180, 32)
selector.undoButton.Move(1092, 728, 82, 32)
selector.redoButton.Move(1186, 728, 82, 32)
}
BuildMain() {
title := this.AddPage("main", "Text", "x908 y64 w386 h30 BackgroundTrans", "Main")
title.SetFont("s14 bold")
this.stats := Map()
row := 0
for label in ["State", "Mode", "Current map", "Act", "Run limit", "Current action", "Elapsed", "Challenge in", "Wins / losses", "Win ratio"] {
y := 118 + row * 48
this.AddPage("main", "Text", "x908 y" y " w130 h40 BackgroundTrans cB0B3BC", label = "Challenge in" ? "Next Challenge In" : label)
this.stats[label] := this.AddPage("main", "Text", "x1048 y" y " w246 h40 BackgroundTrans", "Unknown")
row += 1
}
this.stats["Current action"].Text := "Ready"
this.stats["Wins / losses"].Text := "Not detected"
}
BuildModes() {
title := this.AddPage("gamemodes", "Text", "x908 y64 w386 h30 BackgroundTrans", "Gamemode Manager")
title.SetFont("s14 bold")
this.AddPage("gamemodes", "Text", "x908 y98 w386 h22 BackgroundTrans", "Stage").SetFont("bold")
this.AddPage("gamemodes", "Text", "x908 y126 w386 h22 BackgroundTrans", "Gamemode")
this.modeSelect := this.AddPage("gamemodes", "DropDownList", "x908 y150 w386", [])
this.modeSelect.OnEvent("Change", ObjBindMethod(this, "ModeChanged"))
this.modeMapLabel := this.AddPage("gamemodes", "Text", "x908 y184 w386 h22 BackgroundTrans", "Map")
this.configSelect := this.AddPage("gamemodes", "DropDownList", "x908 y208 w386", [])
this.configSelect.OnEvent("Change", ObjBindMethod(this, "ConfigSelected"))
this.actLabel := this.AddPage("gamemodes", "Text", "x908 y242 w100 h22 BackgroundTrans", "Act")
this.actField := this.AddPage("gamemodes", "DropDownList", "x908 y266 w100 Choose1", ["1", "2", "3", "4", "5", "6"])
this.actField.OnEvent("Change", ObjBindMethod(this, "ActChanged"))
this.difficultyLabel := this.AddPage("gamemodes", "Text", "x1022 y242 w100 h22 BackgroundTrans", "Difficulty")
this.difficultyField := this.AddPage("gamemodes", "DropDownList", "x1022 y266 w100 Choose1", ["Normal", "Hard"])
this.difficultyField.OnEvent("Change", ObjBindMethod(this, "DifficultyChanged"))
this.bossRushTraitsField := this.AddPage("gamemodes", "DropDownList", "x908 y266 w210 Choose1 Hidden", ["Traits", "Traitless"])
this.bossRushTraitsField.OnEvent("Change", ObjBindMethod(this, "BossRushOptionChanged"))
this.AddPage("gamemodes", "Text", "x1136 y242 w158 h22 BackgroundTrans", "Number of runs")
this.runsField := this.AddPage("gamemodes", "Edit", "x1136 y266 w158 h28 Background17181B Number", "1")
this.runsField.OnEvent("Change", ObjBindMethod(this, "QueueTaskSave"))
this.makimaCardLabel := this.AddPage("gamemodes", "Text", "x908 y304 w386 h22 Hidden BackgroundTrans", "Card")
this.makimaCardField := this.AddPage("gamemodes", "DropDownList", "x908 y328 w386 Choose1 Hidden", ["Unit Slot", "Damage", "Placement Limit"])
this.makimaCardField.OnEvent("Change", ObjBindMethod(this, "MakimaCardChanged"))
this.contractPriorityLabel := this.AddPage("gamemodes", "Text", "x908 y304 w386 h22 Hidden BackgroundTrans", "Contract Priority List")
this.contractPriorityList := this.AddPage("gamemodes", "ListBox", "x908 y330 w326 h126 Hidden", [])
this.contractUp := this.AddPage("gamemodes", "Button", "x1248 y330 w46 h32 Hidden", Chr(0xE74A))
this.contractDown := this.AddPage("gamemodes", "Button", "x1248 y370 w46 h32 Hidden", Chr(0xE74B))
for control in [this.contractUp, this.contractDown]
control.SetFont("s14", "Segoe MDL2 Assets")
this.tooltips[this.contractUp.Hwnd] := "Move contract priority up"
this.tooltips[this.contractDown.Hwnd] := "Move contract priority down"
this.contractUp.OnEvent("Click", (*) => this.MoveContractPriority(-1))
this.contractDown.OnEvent("Click", (*) => this.MoveContractPriority(1))
this.addModeButton := this.AddPage("gamemodes", "Button", "x908 y312 w184 h32", "Add Mode")
this.addModeButton.OnEvent("Click", (*) => this.SaveTask(false))
this.saveModeListButton := this.AddPage("gamemodes", "Button", "x1110 y312 w184 h32", "Save Mode List")
this.saveModeListButton.OnEvent("Click", ObjBindMethod(this, "SaveModeList"))
this.modeListLabel := this.AddPage("gamemodes", "Text", "x908 y366 w386 h24 BackgroundTrans", "Mode List")
this.modeListLabel.SetFont("bold")
this.taskList := this.AddPage("gamemodes", "ListView", "x908 y396 w386 h362 -Multi NoSortHdr +0x8", ["#", "Stage", "Act", "Variant", "Runs"])
this.taskList.OnEvent("ItemSelect", ObjBindMethod(this, "TaskSelected"))
for item in [{text: "Move up", x: 908, glyph: 0xE74A, method: "TaskUp"},
{text: "Move down", x: 1064, glyph: 0xE74B, method: "TaskDown"},
{text: "Delete mode", x: 1220, glyph: 0xE74D, method: "DeleteTask"}] {
button := this.AddPage("gamemodes", "Button", "x" item.x " y772 w74 h30", Chr(item.glyph))
button.SetFont("s14", "Segoe MDL2 Assets")
button.OnEvent("Click", ObjBindMethod(this, item.method))
this.tooltips[button.Hwnd] := item.text
}
this.modeStatus := this.AddPage("gamemodes", "Text", "x908 y816 w386 h38 BackgroundTrans cB0B3BC", "")
this.RefreshModes()
this.RenderTasks()
}
RefreshModes(*) {
global selector
modes := []
for mode in CrusadersCatalog.Modes
if mode = "Events" || DirExist(selector.configRoot "\" CrusadersCatalog.Folder(mode))
modes.Push(mode)
this.modeSelect.Delete()
this.modeSelect.Add(modes)
SplitPath(selector.path, , &directory)
SplitPath(directory, &mode)
if mode = "InfinityCastle"
mode := "Infinity Castle"
try this.modeSelect.Choose(mode)
catch {
if modes.Length
this.modeSelect.Choose(1)
}
this.RefreshConfigs()
}
RefreshConfigs(*) {
global selector
names := []
this.configChoices := []
selected := 0
currentName := CrusadersCatalog.Name(selector.path)
for name in CrusadersCatalog.Maps[this.modeSelect.Text] {
path := CrusadersCatalog.Resolve(selector.configRoot, this.modeSelect.Text, name, 1)
if !FileExist(path) && this.modeSelect.Text != "Events"
continue
names.Push(name)
this.configChoices.Push(path)
if name = currentName
selected := names.Length
}
this.configSelect.Delete()
this.configSelect.Add(names)
if names.Length
this.configSelect.Choose(selected ? selected : 1)
this.RefreshActs(Integer(selector.preferences["Act"]), selector.preferences["Mode"])
if !this.editingTask
this.runsField.Value := selector.preferences["Runs"]
if !names.Length
this.modeStatus.Text := "No text configs in this gamemode"
}
ModeChanged(*) {
this.RefreshConfigs()
if this.configSelect.Text != "" && this.SelectConfig()
this.AutoSaveTask()
}
ConfigSelected(*) {
if this.SelectConfig(this.SelectedMode() = "Infinite")
this.AutoSaveTask()
}
SelectedMode() {
return this.modeSelect.Text = "Story" && this.actField.Text = "Infinite" ? "Infinite" : this.modeSelect.Text
}
SelectedAct() {
if this.SelectedMode() = "Infinite"
return 1
return Integer(RegExReplace(this.actField.Text, "^Act\s+", ""))
}
SelectedDifficulty() {
return CrusadersCatalog.EffectiveDifficulty(this.SelectedMode(), this.configSelect.Text, this.difficultyField.Text)
}
RefreshActs(act := 1, mode := "") {
global selector
acts := []
story := this.modeSelect.Text = "Story"
if this.configSelect.Text != ""
loop CrusadersCatalog.ActCount(this.modeSelect.Text, this.configSelect.Text)
acts.Push(story ? "Act " A_Index : String(A_Index))
this.actField.Delete()
this.actField.Add(acts)
if acts.Length
this.actField.Choose(Min(Max(1, act), acts.Length))
bossRush := this.SelectedMode() = "Boss Rush" || this.SelectedMode() = "Infinity Castle"
event := this.SelectedMode() = "Event"
this.actField.Visible := !this.webShell && this.page = "gamemodes" && !bossRush && !event
this.actLabel.Text := bossRush ? "Mode" : "Act"
this.actLabel.Visible := !this.webShell && this.page = "gamemodes" && !event
if this.HasOwnProp("modeMapLabel")
this.modeMapLabel.Text := event ? "Event" : "Map"
selectable := CrusadersCatalog.HasDifficultySelection(this.SelectedMode(), this.configSelect.Text)
this.difficultyField.Visible := !this.webShell && this.page = "gamemodes" && selectable
this.difficultyLabel.Visible := this.difficultyField.Visible
this.difficultyField.Choose(CrusadersCatalog.EffectiveDifficulty(this.SelectedMode(), this.configSelect.Text, selector.preferences["Difficulty"]))
if this.HasOwnProp("bossRushTraitsField") {
this.bossRushTraitsField.Visible := !this.webShell && this.page = "gamemodes" && bossRush
this.bossRushTraitsField.Choose(bossRush ? selector.preferences["BossRushMode"] : "Traits")
}
if this.HasOwnProp("makimaCardField") {
makima := bossRush && this.configSelect.Text = "Makima"
this.makimaCardField.Visible := !this.webShell && this.page = "gamemodes" && makima
this.makimaCardLabel.Visible := this.makimaCardField.Visible
this.makimaCardField.Choose(selector.preferences["MakimaCard"])
offset := event ? 152 : makima ? 58 : 0
this.addModeButton.Move(, this.ModeY(312 + offset))
this.saveModeListButton.Move(, this.ModeY(312 + offset))
this.modeListLabel.Move(, this.ModeY(366 + offset))
if this.HasOwnProp("taskList")
this.taskList.Move(, this.ModeY(396 + offset), , Round((362 - offset) * 0.77))
}
if this.HasOwnProp("contractPriorityList") {
for control in [this.contractPriorityLabel, this.contractPriorityList, this.contractUp, this.contractDown]
control.Visible := !this.webShell && this.page = "gamemodes" && event
this.contractPriorityList.Delete()
this.contractPriorityList.Add(CrusadersCatalog.ContractPriorities(selector.preferences["ContractPriority"]))
this.contractPriorityList.Choose(1)
}
}
MoveContractPriority(direction) {
global selector, testRunning
if this.loadingTask || testRunning || this.SelectedMode() != "Event"
return
index := this.contractPriorityList.Value
names := CrusadersCatalog.ContractPriorities(selector.preferences["ContractPriority"])
target := index + direction
if index < 1 || target < 1 || target > names.Length
return
previous := selector.preferences["ContractPriority"]
try {
value := names[index]
names[index] := names[target]
names[target] := value
priority := ""
for name in names
priority .= (priority = "" ? "" : "|") name
selector.preferences["ContractPriority"] := priority
selector.Save()
this.AutoSaveTask()
this.contractPriorityList.Delete()
this.contractPriorityList.Add(names)
this.contractPriorityList.Choose(target)
this.Log("Hunter contract priority saved: " StrReplace(priority, "|", " > "))
} catch Error as err {
selector.preferences["ContractPriority"] := previous
this.modeStatus.Text := err.Message
}
}
MakimaCardChanged(*) {
global selector, testRunning
if this.loadingTask || testRunning || this.SelectedMode() != "Boss Rush" || this.configSelect.Text != "Makima"
return
try {
selector.preferences["MakimaCard"] := this.makimaCardField.Text
selector.Save()
this.AutoSaveTask()
this.Log("Makima card: " selector.preferences["MakimaCard"])
} catch Error as err
this.modeStatus.Text := err.Message
}
BossRushOptionChanged(*) {
global selector, testRunning
if this.loadingTask || testRunning || (this.SelectedMode() != "Boss Rush" && this.SelectedMode() != "Infinity Castle")
return
try {
selector.preferences["BossRushMode"] := this.bossRushTraitsField.Text
selector.Save()
this.AutoSaveTask()
this.Log("Boss Rush option: " selector.preferences["BossRushMode"])
} catch Error as err
this.modeStatus.Text := err.Message
}
ApplyBossRushOption(item) {
global selector
selector.preferences["PortalName"] := item.HasOwnProp("portalName") ? item.portalName : ""
selector.preferences["ContractPriority"] := item.HasOwnProp("contractPriority") ? item.contractPriority : CrusadersCatalog.DefaultContractPriority
selector.preferences["BossRushMode"] := item.bossRushMode
this.bossRushTraitsField.Choose(item.bossRushMode)
if this.HasOwnProp("makimaCardField") {
selector.preferences["MakimaCard"] := item.HasOwnProp("makimaCard") ? item.makimaCard : "Unit Slot"
this.makimaCardField.Choose(selector.preferences["MakimaCard"])
}
}
DifficultyChanged(*) {
global selector, testRunning
if this.loadingTask || testRunning
return
try {
selector.preferences["Difficulty"] := this.SelectedDifficulty()
selector.Save()
this.AutoSaveTask()
} catch Error as err
this.modeStatus.Text := err.Message
}
ActChanged(*) {
global selector
act := this.SelectedAct()
if this.SelectConfig(true) {
selector.preferences["Act"] := act
selector.Save()
this.AutoSaveTask()
}
}
SelectConfig(preserveAct := false, runtime := false, *) {
global selector, testRunning
if testRunning && !runtime {
this.modeStatus.Text := "Stop the run before changing configs"
return false
}
if !this.configSelect.Value || !selector.Apply()
return false
try {
act := preserveAct = true ? this.SelectedAct() : 1
if preserveAct != true
this.RefreshActs()
mode := this.SelectedMode()
path := CrusadersCatalog.Resolve(selector.configRoot, mode, this.configSelect.Text, act)
if !FileExist(path) && mode != "Events"
throw Error("Config missing: " path)
candidate := CrusadersSelector(path, "", selector.settingsFile, selector.imageRoot)
this.ValidateKeys(candidate.preferences)
candidate.preferences["Mode"] := mode
candidate.preferences["Act"] := act
this.LoadEditor(candidate)
this.modeConfigPath := path
this.configScope := "Current Mode"
if this.HasOwnProp("scopeField") {
this.scopeField.Choose("Current Mode")
this.scopeConfigField.Delete()
this.scopeConfigField.Add(["Use Modes Tab"])
this.scopeConfigField.Choose(1)
this.scopeConfigField.Enabled := false
}
SplitPath(path, &filename, &directory)
SplitPath(directory, &mode)
if mode != "Events"
IniWrite(mode "\" filename, selector.settingsFile, "Config", "Path")
selector.settingsSource := FileRead(selector.settingsFile)
this.RefreshActs(act, candidate.preferences["Mode"])
if !this.editingTask
this.runsField.Value := selector.preferences["Runs"]
this.LoadFields()
this.ApplyRuntimeSettings()
this.BindKeys()
this.modeStatus.Text := this.configSelect.Text " loaded / " (FileExist(selector.imagePath) ? "Map image linked" : "No map image yet")
this.LogConfig()
this.UpdateStats()
return true
} catch Error as err {
this.modeStatus.Text := "Config not loaded: " err.Message
return false
}
}
LoadEditor(candidate) {
global selector
for field in ["path", "imagePath", "mapImageDirectory", "indexes", "preferences", "mapWidth", "mapHeight", "signature", "sourceText", "settingsSource"]
selector.%field% := candidate.%field%
selector.history := []
selector.future := []
selector.SetSelected(1)
}
LoadChallengeConfig(name) {
global selector
if !selector.Apply()
throw Error("Save the current index before loading a challenge config.")
candidate := CrusadersChallenges.ConfigForMap(selector, name)
if this.configScope = "Current Mode"
this.modeConfigPath := selector.path
this.LoadEditor(candidate)
this.configScope := "Challenges"
this.scopeField.Choose("Challenges")
this.scopeConfigField.Delete()
this.scopeConfigField.Add(CrusadersCatalog.Maps["Story"])
this.scopeConfigField.Choose(name)
this.scopeConfigField.Enabled := true
this.LoadFields()
this.LogConfig()
this.UpdateStats()
}
SaveConfig(*) {
global selector, testRunning
if testRunning {
this.Log("Stop the macro before saving a config")
return false
}
try {
if !selector.Apply()
return false
selector.Save()
SplitPath(selector.path, &filename)
this.Log("Config saved: " filename)
return true
} catch Error as err {
selector.status.Text := err.Message
return false
}
}
ScopeChanged(*) {
global selector, testRunning
if (testRunning && !CrusadersRuntime.paused) || !selector.Apply() {
this.scopeField.Choose(this.configScope)
return false
}
requested := this.scopeField.Text
try {
if HasMethod(this,"BeginPausedBrowse")
this.BeginPausedBrowse()
if requested = "Challenges" || requested = "Infinity Castle" || requested = "Infinity Mansion" || requested = "Dungeons" {
if this.configScope = "Current Mode"
this.modeConfigPath := selector.path
path := CrusadersCatalog.Resolve(selector.configRoot, requested, CrusadersCatalog.ConfigMaps(requested)[1], 1)
} else
path := this.modeConfigPath
candidate := CrusadersSelector(path, "", selector.settingsFile, selector.imageRoot)
this.LoadEditor(candidate)
this.configScope := requested
this.scopeConfigField.Delete()
this.scopeConfigField.Add(requested != "Current Mode" ? CrusadersCatalog.ConfigMaps(requested) : ["Use Modes Tab"])
this.scopeConfigField.Choose(1)
this.scopeConfigField.Enabled := requested != "Current Mode"
this.LoadFields()
this.LogConfig()
this.UpdateStats()
if selector.pickMode
this.ShowGame(false)
return true
} catch Error as err {
this.scopeField.Choose(this.configScope)
this.Log("Config not loaded: " err.Message)
return false
}
}
ScopeConfigChanged(*) {
global selector, testRunning
if this.configScope = "Current Mode" && (selector.preferences["Mode"] = "Infinity Mansion" || selector.preferences["Mode"] = "Dungeons")
this.configScope := selector.preferences["Mode"]
if this.configScope != "Challenges" && this.configScope != "Infinity Castle" && this.configScope != "Infinity Mansion" && this.configScope != "Dungeons"
return
previous := selector.preferences["Map"]
if (testRunning && !CrusadersRuntime.paused) || !selector.Apply() {
this.scopeConfigField.Choose(previous)
return false
}
try {
if HasMethod(this,"BeginPausedBrowse")
this.BeginPausedBrowse()
path := CrusadersCatalog.Resolve(selector.configRoot, this.configScope, this.scopeConfigField.Text, 1)
this.LoadEditor(CrusadersSelector(path, "", selector.settingsFile, selector.imageRoot))
this.LoadFields()
this.LogConfig()
this.UpdateStats()
if selector.pickMode
this.ShowGame(false)
return true
} catch Error as err {
this.scopeConfigField.Choose(previous)
this.Log("Config not loaded: " err.Message)
return false
}
}
SaveModeList(*) {
global testRunning
if testRunning {
this.modeStatus.Text := "Stop the macro before saving the mode list"
return false
}
if !this.SaveModes()
return false
try {
this.tasks.Save()
this.modeStatus.Text := "Mode list saved"
this.Log("Mode list saved: " this.tasks.path)
return true
} catch Error as err {
this.modeStatus.Text := err.Message
this.Log("Mode list not saved: " err.Message)
return false
}
}
LoadRunningMode(task) {
global selector
this.loadingTask := true
try {
this.modeSelect.Choose(CrusadersCatalog.Folder(task.mode))
this.RefreshConfigs()
for index, path in this.configChoices {
SplitPath(path, &filename)
if CrusadersCatalog.Name(filename) != CrusadersCatalog.Name(task.config)
continue
this.configSelect.Choose(index)
this.RefreshActs(task.act, task.mode)
if !this.SelectConfig(true, true)
throw Error("Could not load next mode: " task.config)
selector.preferences["Act"] := task.act
selector.preferences["Difficulty"] := task.difficulty
this.ApplyBossRushOption(task)
selector.preferences["Runs"] := task.runs
this.difficultyField.Choose(task.difficulty)
this.runsField.Value := task.runs
activeIndex := 0
for index, queued in this.tasks.items {
if !queued.enabled
continue
activeIndex += 1
if activeIndex = this.tasks.cursor {
this.editingTask := index
break
}
}
this.RenderTasks(this.editingTask)
this.UpdateStats()
this.Log("Mode Loaded | " CrusadersTasks.LogDetails(task,CrusadersMapName(selector.path,task.mode)))
return true
}
throw Error("Mode config missing: " task.config)
} finally this.loadingTask := false
}
SaveModes(*) {
global selector
previous := selector.preferences.Clone()
try {
selector.preferences["Act"] := this.SelectedAct()
selector.preferences["Runs"] := this.runsField.Value
selector.preferences["Difficulty"] := this.SelectedDifficulty()
if this.SelectedMode() = "Boss Rush"
selector.preferences["BossRushMode"] := this.bossRushTraitsField.Text
if this.SelectedMode() = "Boss Rush" && this.configSelect.Text = "Makima"
selector.preferences["MakimaCard"] := this.makimaCardField.Text
selector.Validate()
if !selector.Apply()
throw Error(selector.status.Text)
selector.Save()
this.modeStatus.Text := this.configSelect.Text " saved"
this.UpdateStats()
return this.AutoSaveTask()
} catch Error as err {
selector.preferences := previous
this.modeStatus.Text := err.Message
return false
}
}
AddSetting(group, type, options, value := "") {
control := this.gui.Add(type, options, value)
this.settingsGroups[group].Push(control)
return control
}
Setting(group, key, label, y, x := 908, width := 386, inputWidth := 0) {
this.AddSetting(group, "Text", "x" x " y" y " w" width " h22 BackgroundTrans", label)
options := "x" x " y" (y + 24) " w" (inputWidth ? inputWidth : width) " h28 Background17181B"
if key = "DiscordToken"
options .= " Password"
this.settingsFields[key] := this.AddSetting(group, "Edit", options, "")
}
BuildSettings() {
for key,value in AADungeons.Defaults
this.settingsFields[key] := this.AddSetting("General","Edit","x0 y0 w1 h1",value)
title := this.AddPage("settings", "Text", "x84 y64 w600 h32 BackgroundTrans", "Settings")
title.SetFont("s14 bold")
for index, group in ["General", "Delays", "Keybinds", "Challenges"]
this.AddPage("settings", "Button", "x" (84 + (index - 1) * 160) " y110 w146 h34", group).OnEvent("Click", ObjBindMethod(this, "SwitchSettings", group))
for section in [{x: 84, text: "Server"}, {x: 504, text: "Webhooks"}, {x: 924, text: "Discord"}] {
heading := this.AddSetting("General", "Text", "x" section.x " y168 w370 h24 BackgroundTrans", section.text)
heading.SetFont("s11 bold")
}
this.Setting("General", "PrivateServer", "Private server link", 212, 84, 370)
this.settingsFields["UsePrivateServerLink"] := this.AddSetting("General", "Checkbox", "x84 y274 w370 h24 Background202125", "Use Private Server Link")
this.settingsFields["PublicRejoin"] := this.AddSetting("General", "Checkbox", "x84 y306 w370 h24 Background202125", "Rejoin Public Servers on Start")
this.settingsFields["SkipGuideTutorial"] := this.AddSetting("General", "Checkbox", "x84 y850 w370 h24 Hidden", "Skip Guide Tutorial on Startup")
this.settingsFields["SkipMacroOverview"] := this.AddSetting("General", "Checkbox", "x504 y850 w370 h24 Hidden", "Skip Macro Overview on Startup")
this.Setting("General", "WaveRestart", "Restart at wave (0 = off)", 340, 84, 370, 110)
this.Setting("General", "Webhook", "Webhook URL", 212, 504, 370)
this.settingsFields["WebhookEnabled"] := this.AddSetting("General", "Checkbox", "x504 y286 w370 h24 Background202125", "Enable webhook")
this.settingsFields["WebhookPingEnabled"] := this.AddSetting("General", "Checkbox", "x504 y350 w370 h24 Background202125", "Enable Pings")
this.Setting("General", "WebhookDiscordId", "Discord User ID", 380, 504, 370)
for index, key in ["WebhookShowMap", "WebhookShowMode", "WebhookShowRecord", "WebhookShowSessionTime", "WebhookShowChallengeRecord", "WebhookShowModeRecord", "WebhookShowAct", "WebhookShowNext", "WebhookShowCompletion"]
this.settingsFields[key] := this.AddSetting("General", "Checkbox", "x504 y" (430 + (index - 1) * 24) " w370 h24 Background202125", key)
this.Setting("General", "DiscordChannel", "Discord channel ID", 212, 924, 370)
this.Setting("General", "DiscordToken", "Bot token", 312, 924, 370)
this.Setting("General", "DiscordUserId", "Authorized Discord User ID", 420, 924, 370)
this.settingsFields["DiscordBotEnabled"] := this.AddSetting("General", "Checkbox", "x924 y386 w370 h24 Background202125", "Enable Discord bot")
this.AddSetting("General", "Text", "x504 y340 w370 h44 BackgroundTrans cB0B3BC", "Integrations: not connected")
for index, item in [{key: "PlacementRetryDelay", label: "Placement delay (ms)"},
{key: "StageClickDelay", label: "Stage selection click delay (ms)"},
{key: "VictoryDelay", label: "Victory screen delay (ms)"},
{key: "PathingDelay", label: "Pathing delay (ms)"},
{key: "WebhookScreenshotDelay", label: "Webhook Screenshot Delay (ms)"}]
this.Setting("Delays", item.key, item.label, 192 + ((index - 1) // 2) * 104, 84 + Mod(index - 1, 2) * 420, 370, 120)
for index, item in [{key: "StartKey", label: "Start"}, {key: "PauseKey", label: "Pause / Resume"},
{key: "CloseKey", label: "Close macro"}, {key: "RestartKey", label: "Restart macro"}, {key: "CaptureKey", label: "Replace map image"},
{key: "ZoomtechKey", label: "Zoomtech"}, {key: "WebhookTestKey", label: "Test Webhook"},
{key: "RecordKey", label: "Record / Stop"}, {key: "RecordingTestKey", label: "Test / Stop Recording"}]
this.Setting("Keybinds", item.key, item.label, 192 + ((index - 1) // 3) * 104, 84 + Mod(index - 1, 3) * 420, 370, 96)
this.settingsFields["DailyChallengeEnabled"] := this.AddSetting("Challenges", "Checkbox", "x84 y156 w386 h24 Background202125", "Enable Daily Challenge")
this.settingsFields["ChallengeEnabled"] := this.AddSetting("Challenges", "Checkbox", "x84 y192 w386 h24 Background202125", "Enable Half Hourly Challenges")
this.AddSetting("Challenges", "Text", "x84 y252 w220 h24 BackgroundTrans", "First Mode")
this.settingsFields["ChallengeFirstMode"] := this.AddSetting("Challenges", "DropDownList", "x84 y280 w220 Choose1", ["Mode List", "Challenges"])
this.settingsFields["ChallengeForceLeave"] := this.AddSetting("Challenges", "Checkbox", "x504 y192 w370 h24 Background202125", "Force Leave")
this.AddPage("settings", "Button", "x84 y790 w154 h36", "Save Settings").OnEvent("Click", ObjBindMethod(this, "SaveSettings"))
this.AddPage("settings", "Button", "x250 y790 w154 h36", "Reset Fields").OnEvent("Click", ObjBindMethod(this, "LoadFields"))
this.settingsStatus := this.AddPage("settings", "Text", "x424 y796 w870 h44 BackgroundTrans cB0B3BC", "Saved")
this.LoadFields()
}
SwitchSettings(group, *) {
this.settingsTab := group
for name, controls in this.settingsGroups
for control in controls
control.Visible := !this.webShell && this.page = "settings" && name = group
}
ReadTask() {
global selector
if !this.configSelect.Value
throw Error("Choose a map first.")
item := this.tasks.NewTask()
if selector.preferences.Has("ContractPriority")
item.contractPriority := selector.preferences["ContractPriority"]
item.mode := this.SelectedMode()
item.portalName := item.mode = "Portals" ? selector.preferences["PortalName"] : ""
if item.mode = "Boss Rush" || item.mode = "Infinity Castle"
item.bossRushMode := this.bossRushTraitsField.Text
if item.mode = "Boss Rush" && this.configSelect.Text = "Makima" && this.HasOwnProp("makimaCardField")
item.makimaCard := this.makimaCardField.Text
item.difficulty := this.SelectedDifficulty()
item.act := this.SelectedAct()
item.config := CrusadersCatalog.Filename(item.mode, this.configSelect.Text, item.act)
if !RegExMatch(this.runsField.Value, "^\d+$")
throw Error("Runs must be a whole number greater than zero.")
item.runs := Integer(this.runsField.Value)
item.wait := 0
item.enabled := true
this.tasks.Validate(item)
return item
}
SaveTask(update := false) {
global testRunning
if testRunning {
this.modeStatus.Text := "Stop the run before editing modes"
return false
}
try {
item := this.ReadTask()
if update {
if !this.editingTask
throw Error("Select a mode to edit first.")
this.tasks.Update(this.editingTask, item)
index := this.editingTask
} else {
index := this.tasks.Add(item)
this.editingTask := index
}
if update && !this.webShell {
path := this.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
label := CrusadersMapName(path, item.mode)
this.taskList.Modify(index, "", index, (item.mode = "Infinite" ? "Story" : item.mode = "Legend Stages" ? "LS" : item.mode) " / " label, item.mode = "Infinite" ? "Infinite" : (item.mode = "Boss Rush" || item.mode = "Event") ? "-" : "Act " item.act,
item.mode = "Boss Rush" ? item.bossRushMode : (item.mode = "Story" || item.mode = "Raids" || item.mode = "Event") ? item.difficulty : "-", item.runs)
} else {
this.RenderTasks(index)
}
this.modeStatus.Text := update ? "Mode updated" : "Mode added"
mapName := CrusadersMapName(this.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config, item.mode)
this.Log((update ? "Mode Changes Saved: " : "Mode Added: ") index " | " CrusadersTasks.LogDetails(item,mapName))
return true
} catch Error as err {
this.modeStatus.Text := err.Message
return false
}
}
RenderTasks(selected := 1) {
if this.webShell
return
this.renderingTasks := true
this.taskList.Delete()
for index, item in this.tasks.items {
path := this.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
label := CrusadersMapName(path, item.mode)
this.taskList.Add("", index, (item.mode = "Infinite" ? "Story" : item.mode = "Legend Stages" ? "LS" : item.mode) " / " label, item.mode = "Infinite" ? "Infinite" : (item.mode = "Boss Rush" || item.mode = "Event") ? "-" : "Act " item.act,
item.mode = "Boss Rush" ? item.bossRushMode : (item.mode = "Story" || item.mode = "Raids" || item.mode = "Event") ? item.difficulty : "-", item.runs)
}
for index, width in [25, 145, 65, 75, 54]
this.taskList.ModifyCol(index, width)
if selected && selected <= this.tasks.items.Length
this.taskList.Modify(selected, "Select Focus Vis")
this.renderingTasks := false
}
QueueTaskSave(*) {
if !this.loadingTask && !this.renderingTasks && this.editingTask
SetTimer(this.taskSaveTimer, -300)
}
AutoSaveTask(*) {
SetTimer(this.taskSaveTimer, 0)
if this.loadingTask || this.renderingTasks || !this.editingTask
return true
return this.SaveTask(true)
}
TaskSelected(control, index, selected) {
if selected && !this.renderingTasks && !this.loadingTask && index != this.editingTask {
this.pendingTaskSelection := index
SetTimer(this.taskSelectTimer, -1)
}
}
LoadSelectedTask(*) {
index := this.pendingTaskSelection
this.pendingTaskSelection := 0
if index && index <= this.tasks.items.Length
this.LoadTask(index)
}
LoadTask(index := 0, *) {
global testRunning
if testRunning {
this.modeStatus.Text := "Stop the run before editing modes"
return
}
if !index
index := this.taskList.GetNext()
if !index
return
if !this.webShell && !this.AutoSaveTask()
return
item := this.tasks.items[index]
this.loadingTask := true
try {
mode := CrusadersCatalog.Folder(item.mode)
if this.modeSelect.Text != mode {
this.modeSelect.Choose(mode)
this.RefreshConfigs()
}
found := false
for choice, path in this.configChoices {
SplitPath(path, &filename)
if CrusadersCatalog.Name(filename) = CrusadersCatalog.Name(item.config) {
this.configSelect.Choose(choice)
found := true
break
}
}
if !found
throw Error("Mode config missing: " item.config)
this.RefreshActs(item.act, item.mode)
global selector
target := this.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
if (!this.webShell || selector.path != target) && !this.SelectConfig(true)
return
this.editingTask := index
selector.preferences["Mode"] := item.mode
selector.preferences["Act"] := item.act
selector.preferences["Runs"] := item.runs
this.difficultyField.Choose(item.difficulty)
selector.preferences["Difficulty"] := item.difficulty
this.ApplyBossRushOption(item)
this.RefreshActs(item.act, item.mode)
this.runsField.Value := item.runs
if !this.webShell
this.taskList.Modify(index, "Select Focus Vis")
this.modeStatus.Text := "Mode " index " selected / Saved"
this.Log("Editing Mode " index " | " CrusadersTasks.LogDetails(item,CrusadersMapName(target,item.mode)))
} catch Error as err
this.modeStatus.Text := err.Message
finally
this.loadingTask := false
}
MoveTask(offset) {
global testRunning
if testRunning
return
index := this.webShell ? this.editingTask : this.taskList.GetNext()
if !index
return
try {
if !this.webShell && !this.AutoSaveTask()
return
destination := this.tasks.Move(index, offset)
this.editingTask := destination
this.RenderTasks(destination)
} catch Error as err
this.modeStatus.Text := err.Message
}
TaskUp(*) {
this.MoveTask(-1)
}
TaskDown(*) {
this.MoveTask(1)
}
DeleteTask(*) {
global testRunning
if testRunning
return
index := this.webShell ? this.editingTask : this.taskList.GetNext()
if !index
return
try {
if !this.webShell && !this.AutoSaveTask()
return
this.tasks.Delete(index)
this.editingTask := 0
selected := Min(index, this.tasks.items.Length)
this.RenderTasks(selected)
if selected
this.LoadTask(selected)
this.modeStatus.Text := "Mode deleted"
} catch Error as err
this.modeStatus.Text := err.Message
}
LogConfig() {
global selector
SplitPath(selector.path, &filename)
this.Log(AAAprilFools.IsPath(selector.path) ? "Built-in Event: April Fools" : "Config Loaded: " filename)
this.status.Text := "Map: " CrusadersMapName(selector.path, selector.preferences["Mode"])
}
TeamChanged(*) {
global selector, testRunning
if testRunning {
this.teamField.Value := selector.preferences["Team"]
return
}
value := this.teamField.Value
if !RegExMatch(value, "^\d+$") || Integer(value) > 6 {
this.status.Text := "Team must be 0-6; 0 keeps the current team"
return
}
if value = selector.preferences["Team"]
return
selector.preferences["Team"] := value
selector.Save()
this.status.Text := "Team " value " saved"
}
LoadFields(*) {
global selector
if this.HasOwnProp("teamField")
this.teamField.Value := selector.preferences["Team"]
for key, control in this.settingsFields {
if control.Type = "DDL" || control.Type = "DropDownList"
control.Choose(selector.preferences[key])
else
control.Value := control.Type = "CheckBox" ? Integer(selector.preferences[key]) : selector.preferences[key]
}
}
ValidateKeys(preferences) {
CrusadersHotkeys.Validate(preferences)
}
SaveSettings(*) {
global selector
previous := selector.preferences.Clone()
keysChanged := false
try {
for key, control in this.settingsFields
selector.preferences[key] := Trim((control.Type = "DDL" || control.Type = "DropDownList") ? control.Text : control.Value)
CrusadersWebhook.SyncChallengeSettings(selector.preferences, previous)
for key in ["WebhookShowChallengeRuns", "WebhookShowNext"]
if this.settingsFields.Has(key)
this.settingsFields[key].Value := selector.preferences[key]
selector.Validate()
this.ValidateKeys(selector.preferences)
changed := false, mapChanged := false, runtimeChanged := false
for key, value in selector.preferences {
if previous.Has(key) && previous[key] = value
continue
changed := true
if selector.IsMapPreference(key)
mapChanged := true
for bindingKey in CrusadersHotkeys.Names
if key = bindingKey
keysChanged := true
if InStr("|PathingDelay|ZoomInDelay|ZoomOutDelay|DragDelay|ScanDelay|DiscordBotEnabled|DiscordToken|DiscordChannel|DiscordUserId|", "|" key "|")
runtimeChanged := true
}
if mapChanged && !selector.Apply()
throw Error(selector.status.Text)
if keysChanged
this.BindKeys()
if changed {
if mapChanged
selector.Save()
else selector.SaveGlobalSettings()
}
if mapChanged || runtimeChanged
this.ApplyRuntimeSettings()
this.settingsStatus.Text := "Settings saved"
return true
} catch Error as err {
selector.preferences := previous
if keysChanged
try this.BindKeys()
this.settingsStatus.Text := err.Message
return false
}
}
ApplyRuntimeSettings() {
global selector
if selector.preferences["Mode"] != "Challenges" && selector.preferences["Mode"] != "Infinity Castle"
this.ConfigureRoute(selector.preferences["Mode"], selector.preferences["Map"])
this.routeRecorder.pathingDelay := Integer(selector.preferences["PathingDelay"])
CrusadersRuntime.zoomInDelay := Integer(selector.preferences["ZoomInDelay"])
CrusadersRuntime.zoomOutDelay := Integer(selector.preferences["ZoomOutDelay"])
CrusadersRuntime.dragDelay := Integer(selector.preferences["DragDelay"])
CrusadersRuntime.scanDelay := Max(10, Integer(selector.preferences["ScanDelay"]))
if this.HasOwnProp("discord")
this.ConfigureDiscord()
}
ConfigureRoute(mode, name := "") {
if this.routeRecorder.playing
throw Error("Finish the active route before switching gamemodes.")
if mode = "Boss Rush"
CrusadersCatalog.ActCount(mode, name)
this.routeRecorder.isRaid := CrusadersCatalog.Folder(mode) = "Raids"
this.routeRecorder.mode := CrusadersCatalog.Folder(mode)
if mode = "Boss Rush"
this.routeRecorder.bossName := name
}
BindKeys() {
global selector
this.ValidateKeys(selector.preferences)
if !this.HasOwnProp("boundKeyCondition")
this.boundKeyCondition := ObjBindMethod(this,"CanUseBoundKeys")
previous := this.HasOwnProp("boundBindings") ? this.boundBindings : []
pending := []
for pair in [{key: "StartKey", method: "Start"}, {key: "PauseKey", method: "PauseRun"},
{key: "CloseKey", method: "Close"}, {key: "RestartKey", method: "Restart"}, {key: "CaptureKey", method: "CaptureMap"},
{key: "ZoomtechKey", method: "Zoomtech"}, {key: "WebhookTestKey", method: "TestWebhook"},
{key: "RecordKey", method: "ToggleRecording"}, {key: "RecordingTestKey", method: "TestRecording"}] {
binding := CrusadersHotkeys.Parse(selector.preferences[pair.key])
pending.Push({display:selector.preferences[pair.key],binding:binding,callback:ObjBindMethod(this,"RunBoundAction",binding,ObjBindMethod(this,pair.method))})
}
HotIf(this.boundKeyCondition)
try {
for entry in previous
Hotkey(entry.binding.hotkey,"Off")
for entry in pending
Hotkey(entry.binding.hotkey,entry.callback,"On")
this.boundBindings := pending, this.boundKeys := []
for entry in pending
this.boundKeys.Push(entry.display)
} catch Error as err {
for entry in pending
try Hotkey(entry.binding.hotkey,"Off")
for entry in previous
Hotkey(entry.binding.hotkey,entry.callback,"On")
throw err
} finally HotIf()
}
CheckKeybind(name,value) {
global selector
conflict := CrusadersHotkeys.Conflict(selector.preferences,name,value)
if !conflict
return
if !this.HasOwnProp("keybindConflicts")
this.keybindConflicts := Map()
this.keybindConflicts[name] := conflict
this.Log("Keybind Conflict: " conflict.binding.display " Is Already Assigned to " CrusadersHotkeys.Labels[conflict.owner] ". Shortcut Blocked. Choose a Different Key or Restore Default Keybinds.")
throw Error("Already Assigned to " CrusadersHotkeys.Labels[conflict.owner])
}
ResolveKeybind(name) {
if !CrusadersHotkeys.Labels.Has(name)
throw Error("Unknown keybind")
if this.HasOwnProp("keybindConflicts") && this.keybindConflicts.Has(name) {
this.keybindConflicts.Delete(name)
this.Log("Keybind Conflict Cleared: " CrusadersHotkeys.Labels[name])
}
}
RunBoundAction(binding,callback,*) {
if this.HasOwnProp("keybindConflicts")
for name,conflict in this.keybindConflicts
if conflict.binding.identity = binding.identity {
this.Log("Keybind Blocked: " binding.display " Conflicts with " CrusadersHotkeys.Labels[name] ". Fix It in Settings > Keybinds or Restore Default Keybinds.")
return
}
callback.Call()
}
CanUseBoundKeys(*) {
if !WinActive("ahk_id " this.gui.Hwnd)
return true
if this.HasOwnProp("webInputFocused") && this.webInputFocused
return false
try {
if InStr(WinGetClass("ahk_id " ControlGetFocus(this.gui)),"Edit")
return false
}
return true
}
NavClicked(page, *) {
this.Navigate(page)
}
ToggleRecording(*) {
this.inputRecorder.Toggle()
global selector
CrusadersHotkeys.Wait(selector.preferences["RecordKey"])
}
TestRecording(*) {
global selector
if this.inputRecorder.playing {
this.inputRecorder.cancelled := true
CrusadersHotkeys.Wait(selector.preferences["RecordingTestKey"])
return
}
CrusadersHotkeys.Wait(selector.preferences["RecordingTestKey"])
SetTimer(ObjBindMethod(this.inputRecorder, "Test"), -30)
}
Navigate(page, force := false) {
global selector, testRunning
if page = "gamemodes" && this.configScope != "Current Mode" {
this.scopeField.Choose("Current Mode")
if !this.ScopeChanged()
return false
}
if !force {
if testRunning && !CrusadersRuntime.paused {
this.Log("Pause the macro before changing pages")
return false
}
if !selector.Apply()
return false
if this.page = "settings" && !this.SaveSettings()
return false
if this.page = "gamemodes" && !this.SaveModes()
return false
}
selector.pickMode := false
selector.pickButton.Text := "Select Coordinates"
this.page := page
for name, controls in this.pages
for control in controls
control.Visible := !this.webShell && name = page
selector.SetVisible(page = "indexes")
for control in this.logControls
control.Visible := !this.webShell && page != "settings"
this.gameHeading.Visible := !this.webShell && page != "settings"
this.gameHeading.Text := "Current Game"
for name, button in this.nav
button.Enabled := name != page
this.SwitchSettings(this.settingsTab)
if page = "gamemodes"
this.RefreshModes()
this.ShowGame(false)
if page = "gamemodes"
this.taskList.Focus()
this.UpdateStats()
DllCall("RedrawWindow", "Ptr", this.gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
return true
}
SyncGameClip(hwnd) {
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
region := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
try {
kind := DllCall("GetWindowRgn", "Ptr", hwnd, "Ptr", region)
box := Buffer(16, 0)
DllCall("GetRgnBox", "Ptr", region, "Ptr", box)
if kind != 1 {
target := "ahk_id " hwnd
WinGetPos(&outerX, &outerY, , , target)
WinGetClientPos(&x, &y, &w, &h, target)
w := Min(w,800), h := Min(h,600)
if !kind || NumGet(box, 0, "Int") != x - outerX || NumGet(box, 4, "Int") != y - outerY
|| NumGet(box, 8, "Int") != x - outerX + w || NumGet(box, 12, "Int") != y - outerY + h {
DllCall("SetRectRgn", "Ptr", region, "Int", x - outerX, "Int", y - outerY,
"Int", x - outerX + w, "Int", y - outerY + h)
if DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", true)
region := 0
}
}
} finally {
if region
DllCall("DeleteObject", "Ptr", region)
}
}
ApplyGameFrame(hwnd, docked := false, refresh := false) {
if docked
this.SyncGameClip(hwnd)
policy := Buffer(4, 0)
NumPut("UInt", docked ? 1 : 2, policy)
current := Buffer(4, 0)
if !refresh && DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 1, "Ptr", current, "UInt", 4) = 0
&& !!NumGet(current, 0, "UInt") = !docked
return
result := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 2, "Ptr", policy, "UInt", 4)
if result = 0
this.lastFramePolicy := docked ? 1 : 2
DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)
if docked && result = 0
this.SyncGameClip(hwnd)
}
SetGameFrame(hwnd, docked) {
target := "ahk_id " hwnd
frameBits := 0xC40000
style := WinGetStyle(target)
desired := this.original.style & frameBits
if !desired
desired := frameBits
changed := (style & frameBits) != desired
if changed
WinSetStyle((style & ~frameBits) | desired, target)
this.ApplyGameFrame(hwnd, docked, changed)
}
static FullscreenBounds(style, x, y, width, height, mx, my, mw, mh) {
return !(style & 0xC00000) && width >= mw - 8 && height >= mh - 8
&& Abs(x - mx) <= 8 && Abs(y - my) <= 8
}
IsGameFullscreen(hwnd) {
if !hwnd || !WinExist("ahk_id " hwnd) || WinGetMinMax("ahk_id " hwnd) = -1
return false
monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
info := Buffer(40, 0)
NumPut("UInt", 40, info)
if !DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
return false
WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)
mx := NumGet(info, 4, "Int"), my := NumGet(info, 8, "Int")
mw := NumGet(info, 12, "Int") - mx, mh := NumGet(info, 16, "Int") - my
return CrusadersWindow.FullscreenBounds(WinGetStyle("ahk_id " hwnd), x, y, width, height, mx, my, mw, mh)
}
RequestWindowed(hwnd) {
target := "ahk_id " hwnd
this.ApplyGameFrame(hwnd)
DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", true)
WinShow(target)
WinActivate(target)
if !WinWaitActive(target, , 1)
return false
previousLevel := A_SendLevel
try {
SendLevel(0)
SendEvent("{F11 down}")
try Sleep(80)
finally SendEvent("{F11 up}")
} finally SendLevel(previousLevel)
return true
}
WaitForWindowed(hwnd) {
deadline := CrusadersRuntime.Tick() + 4000, stableSince := 0, previous := ""
while WinExist("ahk_id " hwnd) && CrusadersRuntime.Tick() < deadline {
if this.IsGameFullscreen(hwnd) {
stableSince := 0, previous := ""
} else {
WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
signature := x ":" y ":" w ":" h ":" WinGetStyle("ahk_id " hwnd)
if signature != previous || !stableSince
previous := signature, stableSince := CrusadersRuntime.Tick()
if CrusadersRuntime.Tick() - stableSince >= 400
return true
}
Sleep(50)
}
return false
}
EnsureWindowed(hwnd) {
if this.fullscreenNormalizing
return false
if !this.IsGameFullscreen(hwnd)
return true
if CrusadersRuntime.Tick() < this.fullscreenRetryAfter
return false
this.fullscreenNormalizing := true
this.fullscreenRetryAfter := CrusadersRuntime.Tick() + 5000
try return this.RequestWindowed(hwnd) && this.WaitForWindowed(hwnd)
finally this.fullscreenNormalizing := false
}
BlockFullscreen(*) {
if this.restoring || !this.game
|| (this.HasOwnProp("uiTest") && this.uiTest) || WinGetMinMax(this.gui) = -1
|| !DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
return false
for key in this.boundKeys
if StrLower(key) = "f11"
return false
return !!WinActive("ahk_id " this.game)
}
FullscreenKey(*) {
this.Log("Roblox stays windowed while docked in the macro")
KeyWait("F11")
}
AttachGame(hwnd, activate := true) {
AADisplay.UsePhysicalPixels()
if !this.EnsureWindowed(hwnd)
return false
this.game := hwnd
WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
this.original := {x: x, y: y, w: w, h: h, style: WinGetStyle("ahk_id " hwnd), exStyle: WinGetExStyle("ahk_id " hwnd)}
this.SetGameFrame(hwnd, true)
WinGetPos(, , &w, &h, "ahk_id " hwnd)
this.originalRegion := 0
region := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
if DllCall("GetWindowRgn", "Ptr", hwnd, "Ptr", region)
this.originalRegion := region
else
DllCall("DeleteObject", "Ptr", region)
info := Buffer(40, 0)
SendMessage(0x24, 0, info.Ptr, , "ahk_id " hwnd)
WinGetClientPos(, , &clientWidth, &clientHeight, "ahk_id " hwnd)
this.outerWidth := Max(NumGet(info, 24, "Int"), 800 + w - clientWidth)
this.outerHeight := Max(NumGet(info, 28, "Int"), 600 + h - clientHeight)
if WinGetMinMax("ahk_id " hwnd) != 0 {
WinRestore("ahk_id " hwnd)
}
WinMove(, , this.outerWidth, this.outerHeight, "ahk_id " hwnd)
WinGetPos(&outerX, &outerY, , , "ahk_id " hwnd)
WinGetClientPos(&clientX, &clientY, &width, &height, "ahk_id " hwnd)
this.offsetX := clientX - outerX
this.offsetY := clientY - outerY
this.gameWidth := width
this.gameHeight := height
getter := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
this.owner := DllCall(getter, "Ptr", hwnd, "Int", -8, "Ptr")
WinSetExStyle((this.original.exStyle | 0x40000) & ~0x80, "ahk_id " hwnd)
this.SetGameFrame(hwnd, true)
return this.ShowGame(activate)
}
DiscoverGame() {
global selector, testRunning
if this.restoring || testRunning || CrusadersRuntime.joining || selector.pickMode
|| (this.HasOwnProp("uiTest") && this.uiTest)
|| (this.HasOwnProp("attachingGame") && this.attachingGame)
|| WinGetMinMax(this.gui) = -1
|| !DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
return
if this.game && WinExist("ahk_id " this.game) {
if WinGetMinMax("ahk_id " this.game) != -1
this.EnsureGameSize(false)
foreground := DllCall("GetForegroundWindow", "Ptr")
foregroundRoot := DllCall("GetAncestor", "Ptr", foreground, "UInt", 2, "Ptr")
if foregroundRoot = this.gui.Hwnd || foregroundRoot = this.game
this.RaiseGame()
return
}
hwnd := CrusadersServer.FindGameWindow()
if !hwnd
return
this.attachingGame := true
try {
if this.originalRegion {
DllCall("DeleteObject", "Ptr", this.originalRegion)
this.originalRegion := 0
}
if this.AttachGame(hwnd, false)
this.Log("Roblox attached: " this.gameWidth " x " this.gameHeight)
} catch Error {
this.game := 0
this.original := 0
} finally this.attachingGame := false
}
EnsureGameSize(activate := false) {
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return !!this.game
global selector
if !this.game || !WinExist("ahk_id " this.game)
return false
if !this.EnsureWindowed(this.game)
return false
this.SetGameFrame(this.game, true)
WinGetClientPos(, , &width, &height, "ahk_id " this.game)
if width = 800 && height = 600 && WinGetMinMax("ahk_id " this.game) = 0 {
this.UpdateGameMetrics(this.game)
this.gameResizeRetryAfter := 0
return true
}
if this.gameResizing || CrusadersRuntime.Tick() < this.gameResizeRetryAfter
return false
this.gameResizing := true
try {
if WinGetMinMax("ahk_id " this.game) != 0
WinRestore("ahk_id " this.game)
if !this.ResizeGameClient(this.game) {
this.gameResizeRetryAfter := CrusadersRuntime.Tick() + 5000
failure := this.gameWidth " x " this.gameHeight
if this.HasOwnProp("logBox") && (!this.HasOwnProp("lastResizeFailure") || this.lastResizeFailure != failure)
this.Log("Roblox client size " failure "; requires 800 x 600")
this.lastResizeFailure := failure
return false
}
this.gameResizeRetryAfter := 0
} finally this.gameResizing := false
this.Arrange()
if activate && !selector.pickMode
WinActivate("ahk_id " this.game)
return true
}
UpdateGameMetrics(hwnd) {
AADisplay.UsePhysicalPixels()
outer := Buffer(16), client := Buffer(16), origin := Buffer(8,0)
if !DllCall("GetWindowRect","Ptr",hwnd,"Ptr",outer)
|| !DllCall("GetClientRect","Ptr",hwnd,"Ptr",client)
|| !DllCall("ClientToScreen","Ptr",hwnd,"Ptr",origin)
throw Error("Roblox window dimensions could not be measured.")
this.outerWidth := NumGet(outer,8,"Int")-NumGet(outer,0,"Int")
this.outerHeight := NumGet(outer,12,"Int")-NumGet(outer,4,"Int")
this.offsetX := NumGet(origin,0,"Int")-NumGet(outer,0,"Int")
this.offsetY := NumGet(origin,4,"Int")-NumGet(outer,4,"Int")
this.gameWidth := NumGet(client,8,"Int"), this.gameHeight := NumGet(client,12,"Int")
}
ResizeGameClient(hwnd) {
if !WinExist("ahk_id " hwnd)
return false
loop 6 {
this.UpdateGameMetrics(hwnd)
if this.gameWidth = 800 && this.gameHeight = 600 {
Sleep(25)
this.UpdateGameMetrics(hwnd)
if this.gameWidth = 800 && this.gameHeight = 600
return true
}
width := Max(100,this.outerWidth+800-this.gameWidth)
height := Max(100,this.outerHeight+600-this.gameHeight)
flags := A_Index >= 3 ? 0x616 : 0x216
if !DllCall("SetWindowPos","Ptr",hwnd,"Ptr",0,"Int",0,"Int",0,
"Int",width,"Int",height,"UInt",flags)
return false
Sleep(50)
}
this.UpdateGameMetrics(hwnd)
return this.gameWidth = 800 && this.gameHeight = 600
}
ShowGame(activate := true) {
global selector
if this.HasOwnProp("interfaceVisible") && !this.interfaceVisible
return !!this.game
selector.pickMode := false
this.mapPicture.Visible := false
for marker in this.mapMarkers
marker.Visible := false
this.UpdateGameCutout()
if !this.game || !WinExist("ahk_id " this.game) {
this.Log("Roblox window not found")
return false
}
if !activate && WinGetMinMax("ahk_id " this.game) = -1
return true
if WinGetMinMax("ahk_id " this.game) = -1
WinRestore("ahk_id " this.game)
if !this.EnsureGameSize(false)
return false
this.Arrange()
WinShow("ahk_id " this.game)
this.RaiseGame()
if activate {
WinActivate("ahk_id " this.game)
WinWaitActive("ahk_id " this.game, , 2)
return !!WinActive("ahk_id " this.game)
}
return true
}
BeginCoordinates() {
global selector
if !selector.EnsureMapDimensions() {
selector.status.Text := "The saved map image is missing or unreadable. Use F5 to replace it."
return false
}
scale := Min(this.gameWidth / selector.mapWidth, this.gameHeight / selector.mapHeight)
this.mapDisplayWidth := Floor(selector.mapWidth * scale)
this.mapDisplayHeight := Floor(selector.mapHeight * scale)
this.mapLeft := 64 + (this.gameWidth - this.mapDisplayWidth) // 2
this.mapTop := 76 + (this.gameHeight - this.mapDisplayHeight) // 2
this.mapPicture.Value := selector.imagePath
this.mapPicture.Move(this.mapLeft, this.mapTop, this.mapDisplayWidth, this.mapDisplayHeight)
selector.pickMode := true
this.mapPicture.Visible := true
this.RenderMapMarkers()
selector.pickButton.Text := "Cancel Selection"
this.gameHeading.Text := "Map / " CrusadersMapName(selector.path)
this.Arrange()
WinActivate(this.gui)
return true
}
CanPickCoordinates(*) {
global selector
if !selector.pickMode || !WinActive(this.gui)
return false
MouseGetPos(, , , &control, 2)
return control = this.mapPicture.Hwnd || this.markerByHwnd.Has(control)
}
RenderMapMarkers() {
global selector
if !selector.pickMode
return
diameter := 26
for number, item in selector.indexes {
if this.mapMarkers.Length < number {
marker := this.gui.AddText("x0 y0 w26 h26 Hidden Center +0x200 +0x100 BackgroundD9363E cFFFFFF", String(number))
marker.SetFont("s9 bold", "Segoe UI")
style := DllCall("GetWindowLong", "Ptr", marker.Hwnd, "Int", -16, "UInt")
DllCall("SetWindowLong", "Ptr", marker.Hwnd, "Int", -16, "UInt", (style & ~0x1F) | 0x10D)
this.mapMarkers.Push(marker)
this.markerByHwnd[marker.Hwnd] := number
}
marker := this.mapMarkers[number]
valid := item.configured && item.x >= 0 && item.y >= 0 && item.x < selector.mapWidth && item.y < selector.mapHeight
if valid {
x := Round(item.x * this.mapDisplayWidth / selector.mapWidth) - diameter // 2
y := Round(item.y * this.mapDisplayHeight / selector.mapHeight) - diameter // 2
marker.Move(this.mapLeft + Max(0, Min(this.mapDisplayWidth - diameter, x)),
this.mapTop + Max(0, Min(this.mapDisplayHeight - diameter, y)))
this.tooltips[marker.Hwnd] := "Index " number (item.name != "" ? " / " item.name : "") " / " item.x ", " item.y
}
marker.Visible := valid
}
}
DrawMapMarker(wParam, lParam, msg, hwnd) {
offset := A_PtrSize = 8 ? 24 : 20
control := NumGet(lParam, offset, "Ptr")
if !this.markerByHwnd.Has(control)
return
dc := NumGet(lParam, offset + A_PtrSize, "Ptr")
number := this.markerByHwnd[control]
marker := this.mapMarkers[number]
marker.GetPos(&x, &y, &width, &height)
bitmap := SendMessage(0x173, 0, 0, this.mapPicture)
if bitmap {
info := Buffer(32, 0)
DllCall("GetObject", "Ptr", bitmap, "Int", info.Size, "Ptr", info)
sourceWidth := NumGet(info, 4, "Int")
sourceHeight := NumGet(info, 8, "Int")
sourceDC := DllCall("CreateCompatibleDC", "Ptr", dc, "Ptr")
previousBitmap := DllCall("SelectObject", "Ptr", sourceDC, "Ptr", bitmap, "Ptr")
DllCall("StretchBlt", "Ptr", dc, "Int", 0, "Int", 0, "Int", width, "Int", height,
"Ptr", sourceDC, "Int", Round((x - this.mapLeft) * sourceWidth / this.mapDisplayWidth),
"Int", Round((y - this.mapTop) * sourceHeight / this.mapDisplayHeight),
"Int", Round(width * sourceWidth / this.mapDisplayWidth),
"Int", Round(height * sourceHeight / this.mapDisplayHeight), "UInt", 0xCC0020)
DllCall("SelectObject", "Ptr", sourceDC, "Ptr", previousBitmap)
DllCall("DeleteDC", "Ptr", sourceDC)
}
brush := DllCall("CreateSolidBrush", "UInt", 0x3E36D9, "Ptr")
pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0xFFFFFF, "Ptr")
previousBrush := DllCall("SelectObject", "Ptr", dc, "Ptr", brush, "Ptr")
previousPen := DllCall("SelectObject", "Ptr", dc, "Ptr", pen, "Ptr")
DllCall("Ellipse", "Ptr", dc, "Int", 1, "Int", 1, "Int", width - 1, "Int", height - 1)
font := SendMessage(0x31, 0, 0, marker)
previousFont := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
DllCall("SetBkMode", "Ptr", dc, "Int", 1)
DllCall("SetTextColor", "Ptr", dc, "UInt", 0xFFFFFF)
rect := Buffer(16)
NumPut("Int", 0, "Int", 0, "Int", width, "Int", height, rect)
DllCall("DrawText", "Ptr", dc, "Str", String(number), "Int", -1, "Ptr", rect, "UInt", 0x25)
DllCall("SelectObject", "Ptr", dc, "Ptr", previousFont)
DllCall("SelectObject", "Ptr", dc, "Ptr", previousPen)
DllCall("SelectObject", "Ptr", dc, "Ptr", previousBrush)
DllCall("DeleteObject", "Ptr", pen)
DllCall("DeleteObject", "Ptr", brush)
return true
}
PickCoordinates(x, y) {
global selector
if x < 0 || y < 0 || x >= selector.mapWidth || y >= selector.mapHeight
return false
if !selector.ApplyLiveCoordinate(x, y, selector.mapWidth, selector.mapHeight)
return false
this.Log("Index " selector.selected " coordinates: " x ", " y)
this.CancelPick()
return true
}
CancelPick(*) {
global selector
selector.pickMode := false
selector.pickButton.Text := "Select Coordinates"
this.gameHeading.Text := "Current Game"
this.ShowGame()
}
CaptureMap(*) {
global selector
selector.Capture()
}
TestWebhook(*) {
global selector
static sending := false
if sending || (this.HasOwnProp("uiTest") && this.uiTest)
return
sending := true
try {
CrusadersWebhook.Send(this, "Test", true)
CrusadersHotkeys.Wait(selector.preferences["WebhookTestKey"])
} finally sending := false
}
Start(*) {
if this.inputRecorder.recording || this.inputRecorder.playing {
this.Log("Stop the recorder before starting the macro")
return
}
if IsObject(CrusadersDetection.snip) {
this.Log("Finish or cancel the detection snip before starting")
return
}
if this.startConsumed
return
this.startConsumed := true
if this.routeRecorder.recording || this.routeRecorder.playing || this.challengeRouteRecorder.recording || this.challengeRouteRecorder.playing || this.dailyRouteRecorder.recording || this.dailyRouteRecorder.playing || this.samuraiRouteRecorder.recording || this.samuraiRouteRecorder.playing {
this.Log("Finish or cancel the route session before starting the macro")
return
}
this.StopIdleCleanup()
global selector, testRunning
if testRunning {
return
}
if this.configScope != "Current Mode" {
this.scopeField.Choose("Current Mode")
if !this.ScopeChanged()
return
}
if this.ConfigChanged() {
if !selector.ReloadConfig() {
this.Log(selector.status.Text)
return
}
this.LoadFields()
this.RefreshModes()
}
if this.page = "settings" && !this.SaveSettings()
return
if this.page = "gamemodes" && !this.SaveModes()
return
if !this.webShell && Integer(selector.preferences["ChallengeEnabled"]) {
try this.challengeRouteRecorder.BuiltinEvents()
catch Error as err {
this.Log("Challenge route not ready: " err.Message)
return
}
}
if !this.webShell && Integer(selector.preferences["DailyChallengeEnabled"]) {
try this.dailyRouteRecorder.PlaybackEvents()
catch Error as err {
this.Log("Daily challenge route not ready: " err.Message)
return
}
}
if !selector.Apply()
return
if FileExist(selector.path) {
if !selector.ReloadConfig() {
this.Log(selector.status.Text)
return
}
this.ApplyRuntimeSettings()
this.LoadFields()
this.RefreshModes()
this.BindKeys()
} else
selector.Save()
this.LogConfig()
this.loadingTask := true
try {
task := this.tasks.Begin(selector.preferences)
this.modeSelect.Choose(CrusadersCatalog.Folder(task.mode))
this.RefreshConfigs()
selected := false
for index, path in this.configChoices {
SplitPath(path, &filename)
if CrusadersCatalog.Name(filename) = CrusadersCatalog.Name(task.config) {
this.configSelect.Choose(index)
this.RefreshActs(task.act, task.mode)
selected := this.SelectConfig(true)
break
}
}
if !selected
throw Error("Mode config could not be loaded: " task.config)
selector.preferences["Act"] := task.act
selector.preferences["Difficulty"] := task.difficulty
this.ApplyBossRushOption(task)
this.difficultyField.Choose(task.difficulty)
selector.preferences["Runs"] := task.runs
this.runsField.Value := task.runs
for index, queued in this.tasks.items {
if queued.enabled {
this.editingTask := index
break
}
}
this.RenderTasks(this.editingTask)
this.Log("Starting Mode " this.editingTask " | " CrusadersTasks.LogDetails(task,CrusadersMapName(selector.path,task.mode)))
} catch Error as err {
this.Log("Mode list stopped: " err.Message)
return
} finally {
this.loadingTask := false
}
this.Navigate("main", true)
this.startedAt := CrusadersRuntime.Tick()
this.finishedAt := 0
RunTest()
}
Zoomtech(*) {
if this.routeRecorder.recording || this.routeRecorder.playing {
this.Log("Finish or cancel the route session before using Zoomtech")
return
}
this.StopIdleCleanup()
global testRunning, selector
if testRunning {
this.Log("Stop the current run before using Zoomtech")
return
}
if this.page = "settings" && !this.SaveSettings()
return
if !selector.Apply()
return
this.ApplyRuntimeSettings()
this.Navigate("main", true)
if this.ShowGame() {
this.startedAt := CrusadersRuntime.Tick()
this.finishedAt := 0
this.Log("Zoomtech: top-down camera setup")
RunTest(true)
}
}
BeginIdleCleanup() {
this.StopIdleCleanup()
this.idleCleanupEnabled := true
this.idleCleanupPaused := false
this.IdleCleanupTick()
SetTimer(this.idleCleanupTimer, 10000)
this.Log("Config finished: cleanup click enabled every 10 seconds while Roblox is active")
}
RecordMatchResult(result, matchNumber, challenge := false) {
global selector
if result != "Victory" && result != "Defeat"
throw Error("Unrecognized match result.")
if this.resultAwaitingReplay
return false
this.resultAwaitingReplay := true
if challenge
this.challengeRuns += 1
else
this.modeRuns += 1
won := result = "Victory"
if won
this.wins += 1
else
this.losses += 1
SplitPath(selector.path, &filename)
this.resultEvents.Push({result: result, won: won, match: matchNumber,
config: filename, mode: selector.preferences["Mode"], act: selector.preferences["Act"], difficulty: selector.preferences["Difficulty"],
timestamp: A_Now, wins: this.wins, losses: this.losses})
this.stats["Wins / losses"].Text := this.wins " / " this.losses
this.stats["Win ratio"].Text := Round(100 * this.wins / (this.wins + this.losses), 1) "%"
this.Log(result " confirmed: match " matchNumber "; wins " this.wins ", losses " this.losses)
CrusadersWebhook.Send(this, result, false, matchNumber)
return true
}
StopIdleCleanup() {
this.idleCleanupEnabled := false
this.idleCleanupPaused := false
if this.HasOwnProp("idleCleanupTimer")
SetTimer(this.idleCleanupTimer, 0)
}
CanIdleCleanup() {
global testRunning, selector
return !this.restoring && this.idleCleanupEnabled && !this.idleCleanupPaused && !testRunning
&& !CrusadersRuntime.InputBusy(this)
&& !selector.pickMode && WinActive("Roblox ahk_exe RobloxPlayerBeta.exe")
}
IdleCleanupTick(*) {
if this.CanIdleCleanup()
this.PerformIdleCleanupClick()
}
PerformIdleCleanupClick() {
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
Click(3, 3)
} finally {
CoordMode("Mouse", previous)
}
}
PauseRun(*) {
if this.routeRecorder.recording || this.routeRecorder.playing {
global selector
this.Log("Route sessions do not pause; use " selector.preferences["CloseKey"] " to close the macro or " selector.preferences["RestartKey"] " to restart")
return
}
global testRunning
if !testRunning {
if this.idleCleanupEnabled {
this.idleCleanupPaused := !this.idleCleanupPaused
SetTimer(this.idleCleanupTimer, this.idleCleanupPaused ? 0 : 10000)
this.Log(this.idleCleanupPaused ? "Idle cleanup paused" : "Idle cleanup resumed")
return
}
this.Log("No macro is running")
return
}
if CrusadersRuntime.paused {
this.Navigate("main", true)
this.ShowGame()
CrusadersRuntime.SetPaused(false)
this.runStatus := "Running"
} else {
CrusadersRuntime.SetPaused(true)
this.runStatus := "Paused"
}
this.Log(this.runStatus)
}
Stop(*) {
this.inputRecorder.Cancel()
this.routeRecorder.Cancel()
this.dailyRouteRecorder.Cancel()
this.samuraiRouteRecorder.Cancel()
this.StopIdleCleanup()
global testCancelled, selector
if selector.pickMode {
this.CancelPick()
return
}
testCancelled := true
CrusadersRuntime.ReleaseCamera()
CrusadersRuntime.SetPaused(false)
this.runStatus := "Stopped"
}
Persist() {
global selector
if !selector.Apply()
return false
if this.page = "settings" && !this.SaveSettings()
return false
if this.page = "gamemodes" && !this.SaveModes()
return false
if !FileExist(selector.path)
selector.Save()
return true
}
Close(*) {
try this.Persist()
catch Error as err
this.Log("Unsaved fields: " err.Message)
this.Stop()
ExitApp()
}
Restart(*) {
if this.ConfigChanged() || (FileExist(this.tasks.path) && FileRead(this.tasks.path) != this.tasks.sourceText) {
this.Stop()
try this.Restore("Reload")
finally this.ReloadProcess()
return
}
if this.Persist() {
this.Stop()
try this.Restore("Reload")
finally this.ReloadProcess()
}
}
ReloadProcess() => Reload()
UpdateStats(*) {
global selector, testRunning
if this.restoring
return
minimized := WinGetMinMax(this.gui) = -1
if minimized != this.wrapperMinimized
this.Sized(minimized ? 1 : 0, 0, 0x0005, this.gui.Hwnd)
this.DiscoverGame()
this.stats["State"].Text := CrusadersRuntime.Status(this.runStatus,testRunning)
this.stats["Mode"].Text := selector.preferences["Mode"]
this.stats["Current map"].Text := CrusadersMapName(selector.path, selector.preferences["Mode"])
this.stats["Act"].Text := (selector.preferences["Mode"] = "Infinite" || selector.preferences["Mode"] = "Boss Rush" || selector.preferences["Mode"] = "Event" || selector.preferences["Mode"] = "Challenges") ? "-" : selector.preferences["Act"]
this.stats["Run limit"].Text := selector.preferences["Runs"]
now := this.HasOwnProp("finishedAt") && this.finishedAt ? this.finishedAt : CrusadersRuntime.Now()
elapsed := this.startedAt ? Max(0, (now - this.startedAt) // 1000) : 0
this.stats["Elapsed"].Text := Format("{:02}:{:02}:{:02}", elapsed // 3600, Mod(elapsed // 60, 60), Mod(elapsed, 60))
seconds := CrusadersChallenges.SecondsUntil()
this.stats["Challenge in"].Text := Integer(selector.preferences["ChallengeEnabled"])
? Format("{:02}:{:02}", seconds // 60, Mod(seconds, 60))
: Integer(selector.preferences["DailyChallengeEnabled"]) ? this.DailyCountdown() : "Off"
}
DailyCountdown() {
seconds := CrusadersChallenges.SecondsUntilDaily()
return Format("{:02}:{:02}:{:02}", seconds // 3600, Mod(seconds // 60, 60), Mod(seconds, 60))
}
ConfigChanged() {
global selector
return (FileExist(selector.path) && FileRead(selector.path) != selector.sourceText)
|| (FileExist(selector.settingsFile) && FileRead(selector.settingsFile) != selector.settingsSource)
}
HoverTool(wParam, lParam, msg, hwnd) {
if this.tooltips.Has(hwnd) {
if this.lastTooltip != hwnd {
this.lastTooltip := hwnd
ToolTip(this.tooltips[hwnd])
SetTimer(this.tooltipTimer, -1500)
}
} else if this.lastTooltip
this.HideTooltip()
}
HideTooltip(*) {
ToolTip()
this.lastTooltip := 0
}
Log(message) {
saved := CrusadersLogFile.Append(FormatTime(, "HH:mm:ss") "  " message "`n")
if !saved && !this.HasOwnProp("logWriteFailed") {
this.logWriteFailed := true
this.entries.Push(FormatTime(, "HH:mm:ss") "  Could not write Logs\LogFile.txt; check folder permissions.")
} else if saved && this.HasOwnProp("logWriteFailed")
this.DeleteProp("logWriteFailed")
message := CrusadersProcessLog.Display(message)
if message = "" || (this.HasOwnProp("lastProcessMessage") && this.lastProcessMessage = message && !RegExMatch(message, "i)^Map image (?:replaced:|updated$)"))
return
this.lastProcessMessage := message
line := FormatTime(, "HH:mm:ss") "  " message
this.entries.Push(line)
if this.entries.Length > 200
this.entries.RemoveAt(1)
if this.webShell {
global selector
SplitPath(selector.path, &filename)
this.status.Text := SubStr(StrReplace(message, filename, CrusadersMapName(selector.path, selector.preferences["Mode"])), 1, 58)
return
}
content := ""
loop this.entries.Length
content .= this.entries[this.entries.Length - A_Index + 1] "`r`n"
SendMessage(0xB, 0, 0, this.logBox)
try {
this.logBox.Value := content
SendMessage(0xB1, 0, 0, this.logBox)
SendMessage(0xB7, 0, 0, this.logBox)
SendMessage(0x115, 6, 0, this.logBox)
} finally {
SendMessage(0xB, 1, 0, this.logBox)
DllCall("RedrawWindow", "Ptr", this.logBox.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x105)
}
global selector
SplitPath(selector.path, &filename)
uiMessage := StrReplace(message, filename, CrusadersMapName(selector.path, selector.preferences["Mode"]))
this.status.Text := SubStr(uiMessage, 1, 58)
if this.HasOwnProp("stats")
this.stats["Current action"].Text := uiMessage
}
PaintBackground(dc, lParam, msg, hwnd) {
if hwnd = this.gui.Hwnd && this.webShell {
rect := Buffer(16)
DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
DllCall("SetDCBrushColor", "Ptr", dc, "UInt", 0x1C1918)
DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", DllCall("GetStockObject", "Int", 18, "Ptr"))
return 1
}
if hwnd = this.gui.Hwnd
return PaintCrusadersBackground(hwnd, dc, this.page = "settings" ? 60 : 882,
this.page = "settings" ? CrusadersTheme.Sage : CrusadersTheme.Rose)
}
UpdateGameCutout() {
AADisplay.UsePhysicalPixels()
global selector
if this.restoring || WinGetMinMax(this.gui) = -1
return
WinGetPos(&outerX, &outerY, &width, &height, this.gui)
WinGetClientPos(&clientX, &clientY, , , this.gui)
region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1, "Int", 16, "Int", 16, "Ptr")
if this.page != "settings" && this.page != "themes" && this.page != "export" && this.page != "guides" && !selector.pickMode && this.game && WinExist("ahk_id " this.game) {
x := clientX - outerX + 64
y := clientY - outerY + 76
hole := DllCall("CreateRectRgn", "Int", x, "Int", y, "Int", x + 800, "Int", y + 600, "Ptr")
try DllCall("CombineRgn", "Ptr", region, "Ptr", region, "Ptr", hole, "Int", 4)
finally DllCall("DeleteObject", "Ptr", hole)
}
if !DllCall("SetWindowRgn", "Ptr", this.gui.Hwnd, "Ptr", region, "Int", true)
DllCall("DeleteObject", "Ptr", region)
}
Arrange() {
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
global selector
if this.HasOwnProp("interfaceVisible") && !this.interfaceVisible
return
if this.restoring || WinGetMinMax(this.gui) = -1
return
this.UpdateGameCutout()
if !this.game || !WinExist("ahk_id " this.game)
return
if this.gameResizing || this.fullscreenNormalizing || this.IsGameFullscreen(this.game)
return
if WinGetMinMax("ahk_id " this.game) = -1
return
WinGetClientPos(&left, &top, , , this.gui)
WinMove(left + 64 - this.offsetX, top + 76 - this.offsetY,
this.outerWidth, this.outerHeight, "ahk_id " this.game)
region := DllCall("CreateRectRgn", "Int", this.offsetX, "Int", this.offsetY,
"Int", this.offsetX + (selector.pickMode ? 0 : this.gameWidth),
"Int", this.offsetY + (selector.pickMode ? 0 : this.gameHeight), "Ptr")
if !DllCall("SetWindowRgn", "Ptr", this.game, "Ptr", region, "Int", true)
DllCall("DeleteObject", "Ptr", region)
this.RaiseGame()
}
RaiseGame() {
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
global selector
if this.HasOwnProp("detectionDialog") && this.detectionDialog
return
if this.HasOwnProp("interfaceVisible") && !this.interfaceVisible
return
if this.wrapperMinimized || WinGetMinMax(this.gui) = -1
return
if !this.restoring && !selector.pickMode && this.game && WinExist("ahk_id " this.game) && WinGetMinMax("ahk_id " this.game) != -1 {
nextWindow := DllCall("GetWindow", "Ptr", this.gui.Hwnd, "UInt", 2, "Ptr")
while nextWindow && !DllCall("IsWindowVisible", "Ptr", nextWindow)
nextWindow := DllCall("GetWindow", "Ptr", nextWindow, "UInt", 2, "Ptr")
if nextWindow != this.game
DllCall("SetWindowPos", "Ptr", this.game, "Ptr", this.gui.Hwnd, "Int", 0, "Int", 0,
"Int", 0, "Int", 0, "UInt", 0x13)
}
}
Activated(wParam, lParam, msg, hwnd) {
if hwnd = this.gui.Hwnd && (wParam & 0xFFFF)
this.RaiseGame()
}
Minimize(*) {
this.Sized(1, 0, 0x0005, this.gui.Hwnd)
WinMinimize(this.gui)
}
Sized(wParam, lParam, msg, hwnd) {
AADisplay.UsePhysicalPixels()
if this.restoring || hwnd != this.gui.Hwnd
return
if wParam = 1 {
if this.wrapperMinimized
return
this.wrapperMinimized := true
if this.game && WinExist("ahk_id " this.game) {
this.SetGameFrame(this.game, false)
DllCall("SetWindowRgn", "Ptr", this.game, "Ptr", 0, "Int", true)
DllCall("SetWindowPos", "Ptr", this.game, "Ptr", 0, "Int", 0, "Int", 0,
"Int", 0, "Int", 0, "UInt", 0x37)
DllCall("RedrawWindow", "Ptr", this.game, "Ptr", 0, "Ptr", 0, "UInt", 0x585)
}
} else if this.wrapperMinimized {
this.wrapperMinimized := false
if this.game && WinExist("ahk_id " this.game) {
this.EnsureGameSize(false)
}
this.Arrange()
}
}
MoveLoop(wParam, lParam, msg, hwnd) {
if hwnd = this.gui.Hwnd
this.windowMoving := msg = 0x0231
}
Moved(wParam, lParam, msg, hwnd) {
global selector
if hwnd != this.gui.Hwnd || this.restoring || WinGetMinMax(this.gui) = -1
return
if this.windowMoving && !selector.pickMode && this.game && WinExist("ahk_id " this.game) && WinGetMinMax("ahk_id " this.game) = -1
WinRestore("ahk_id " this.game)
this.Arrange()
}
Restore(reason := "", exitCode := 0) {
this.restoring := true
this.StopIdleCleanup()
if this.HasOwnProp("updateTimer")
SetTimer(this.updateTimer, 0)
if this.HasOwnProp("restoreComplete") && this.restoreComplete
return
if !this.original || !WinExist("ahk_id " this.game) {
this.restoreComplete := true
return
}
setter := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
DllCall(setter, "Ptr", this.game, "Int", -8, "Ptr", this.owner, "Ptr")
if this.originalRegion
DllCall("DeleteObject", "Ptr", this.originalRegion)
this.ApplyGameFrame(this.game, false, true)
DllCall("SetWindowRgn", "Ptr", this.game, "Ptr", 0, "Int", true)
WinSetStyle(this.original.style & ~0x21000000, "ahk_id " this.game)
WinSetExStyle(this.original.exStyle, "ahk_id " this.game)
this.originalRegion := 0
DllCall("SetWindowPos", "Ptr", this.game, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)
DllCall("RedrawWindow", "Ptr", this.game, "Ptr", 0, "Ptr", 0, "UInt", 0x585)
if !DllCall("IsWindowVisible", "Ptr", this.game)
WinShow("ahk_id " this.game)
this.restoreComplete := true
}
}
class CrusadersWebhook {
static SyncChallengeSettings(preferences, previous) {
enabled := preferences.Get("ChallengeEnabled","0") = "1" || preferences.Get("DailyChallengeEnabled","0") = "1"
changed := preferences.Get("ChallengeEnabled","0") != previous.Get("ChallengeEnabled","0")
|| preferences.Get("DailyChallengeEnabled","0") != previous.Get("DailyChallengeEnabled","0")
if !enabled || changed
for key in ["WebhookShowChallengeRuns", "WebhookShowNext"]
preferences[key] := enabled ? "1" : "0"
}
static VictoryThumbnailUrl := "https://cdn.discordapp.com/emojis/1502975382209691699.gif?size=128"
static LossThumbnailUrl := "https://media.giphy.com/media/mtUlcBh7V0qm5TLYYD/giphy.gif"
static RecoveryThumbnailUrl := "https://media.giphy.com/media/HEgUFl2cisPXDqZiA8/giphy.gif"
static jobs := []
static polling := false
static timer := ObjBindMethod(CrusadersWebhook, "Poll")
static CancelAll(*) {
SetTimer(this.timer,0)
jobs := this.jobs, this.jobs := []
for job in jobs
if job.request
try job.request.Abort()
}
static PingId(value) {
if RegExMatch(Trim(value), "^(?:<@!?([0-9]{17,20})>|([0-9]{17,20}))$", &match)
return match[1] != "" ? match[1] : match[2]
return ""
}
static Url(value) {
value := Trim(value)
if !RegExMatch(value, "i)^https://(?:(?:canary|ptb)\.)?discord(?:app)?\.com/api/(?:v\d+/)?webhooks/\d+/[\w-]+(?:\?[^\s#]*)?$")
throw Error("Enter a valid Discord webhook URL in Settings.")
if RegExMatch(value, "[?&]wait=")
return RegExReplace(value, "([?&])wait=[^&]*", "$1wait=true")
return value (InStr(value, "?") ? "&" : "?") "wait=true"
}
static Payload(window, preferences, result, test := false, match := "", completionTime := "Not available") {
window.UpdateStats()
mode := preferences["Mode"]
if mode = "Challenges" && (result = "Victory" || result = "Defeat") && !IsNumber(match) && match != ""
mode := match
mode := mode = "Daily challenge" ? "Daily Challenges"
: mode = "Half-hourly challenge" ? "Half-Hourly Challenges" : StrTitle(mode)
accessPaused := result = "Access denied"
recoveryNotice := accessPaused || result = "Recovery"
privateAccess := accessPaused && CrusadersServer.PrivateLink(preferences) != ""
title := accessPaused ? (privateAccess ? "Macro Paused: Private Server Access Denied" : "Macro Paused: Public Server Access Denied")
: result = "Recovery" ? (match = "AFK Chamber" ? "AFK Chamber Detected" : "Join Error Detected")
: result = "Dungeon Reward" ? "Dungeon Chest Reward" : test ? "Webhook Test" : result = "Victory" ? "You Won :D" : "You Lost D:"
fields := []
if preferences.Get("WebhookShowMap", "1") = "1"
fields.Push({name:"Map", value:preferences["Map"], inline:ComValue(11, -1)})
if preferences.Get("WebhookShowMode", "1") = "1"
fields.Push({name:"Mode", value:mode, inline:ComValue(11, -1)})
if preferences.Get("WebhookShowRecord", "1") = "1"
fields.Push({name:"Wins / Losses", value:window.wins " / " window.losses, inline:ComValue(11, -1)})
if preferences.Get("WebhookShowSessionTime", "1") = "1"
fields.Push({name:"Session Time", value:window.HasOwnProp("stats") && window.stats.Has("Elapsed") ? window.stats["Elapsed"].Text : "00:00:00", inline:ComValue(11, -1)})
if preferences.Get("WebhookShowModeRecord",preferences.Get("WebhookShowModeRuns","1")) = "1"
fields.Push({name:"Mode W/L", value:(window.HasOwnProp("modeWins") ? window.modeWins : 0) " / " (window.HasOwnProp("modeLosses") ? window.modeLosses : 0), inline:ComValue(11,-1)})
if preferences.Get("WebhookShowChallengeRecord",preferences.Get("WebhookShowChallengeRuns","1")) = "1"
fields.Push({name:"Challenge W/L", value:(window.HasOwnProp("challengeWins") ? window.challengeWins : 0) " / " (window.HasOwnProp("challengeLosses") ? window.challengeLosses : 0), inline:ComValue(11,-1)})
if preferences.Get("WebhookShowAct", "1") = "1" && (mode = "Story" || mode = "Legend Stages" || mode = "Raids")
fields.Push({name:"Act / Difficulty", value:preferences["Act"] " / " preferences["Difficulty"], inline:ComValue(11, -1)})
if mode="Dungeons" || result="Dungeon Reward" {
fields.Push({name:"Normal Chests",value:"" (window.HasOwnProp("normalChestsCollected") ? window.normalChestsCollected : 0),inline:ComValue(11,-1)})
fields.Push({name:"Rare Chests",value:"" (window.HasOwnProp("rareChestsCollected") ? window.rareChestsCollected : 0),inline:ComValue(11,-1)})
}
for field in fields
field.name := StrReplace(field.name, " ", Chr(0xA0))
timing := ""
if preferences.Get("WebhookShowNext", "1") = "1" {
if preferences.Get("ChallengeEnabled", "0") = "1" {
seconds := CrusadersChallenges.SecondsUntil()
timing := "**" StrReplace("Next Half Hourly Challenge In", " ", Chr(0xA0)) "**:`n" Format("{:02}:{:02}", seconds // 60, Mod(seconds, 60))
}
if preferences.Get("DailyChallengeEnabled", "0") = "1"
timing .= (timing != "" ? "`n`n" : "") "**" StrReplace("Next Daily Challenge In", " ", Chr(0xA0)) "**:`n" window.DailyCountdown()
}
if !recoveryNotice && preferences.Get("WebhookShowCompletion", "1") = "1"
timing .= (timing != "" ? "`n`n" : "") "**" StrReplace("Total Time", " ", Chr(0xA0)) "**:`n" StrReplace(completionTime, "Not available", "Not Available")
if timing != ""
fields.Push({name:Chr(0x200B), inline:ComValue(11, 0), value:timing})
embed := {title:title, color:(test || recoveryNotice) ? 0xE4BB66 : result = "Victory" ? 0x70B68C : 0xE47F85,
fields:fields, footer:{text:"Bayzo's AA Macro v2.2 | Bayzo Session Report"},
timestamp:FormatTime(A_NowUTC, "yyyy-MM-dd") "T" FormatTime(A_NowUTC, "HH:mm:ss") "Z"}
if accessPaused
embed.description := privateAccess
? "The macro is paused because the private server could not be joined. Check your server link and permissions, then resume the macro when access is restored."
: "The macro is paused because the experience is unavailable or access was denied when joining a public server. Check game availability and your access, then resume the macro when access is restored."
else if result = "Recovery"
embed.description := StrTitle(match) " detected. Rejoining " (CrusadersServer.PrivateLink(preferences) = "" ? "a public server." : "your private server.")
if recoveryNotice
embed.thumbnail := {url:this.RecoveryThumbnailUrl}
if !test && (result = "Victory" || result = "Defeat")
embed.thumbnail := {url:result = "Victory" ? this.VictoryThumbnailUrl : this.LossThumbnailUrl}
if !fields.Length
embed.DeleteProp("fields")
payload := {username:"Bayzo's AA Macro v2.2", allowed_mentions:{parse:[]}, embeds:[embed]}
if preferences.Get("WebhookPingEnabled", "0") = "1" {
id := this.PingId(preferences.Get("WebhookDiscordId", ""))
if id != "" {
payload.content := "<@" id ">"
payload.allowed_mentions := {parse:[], users:[id]}
}
}
return payload
}
static CompletionTime(bitmap, ocr) {
previous := ""
for scale in [2,3] {
text := ocr.Read(bitmap,200,250,300,75,scale)
if !RegExMatch(text,"i)Total\s*Time\s*:?\s*(\d{1,2}:\d{2}(?::\d{2})?)\b",&match)
return "Not available"
parts := StrSplit(match[1],":")
if Integer(parts[parts.Length]) >= 60 || (parts.Length = 3 && Integer(parts[2]) >= 60)
return "Not available"
if previous != "" && previous != match[1]
return "Not available"
previous := match[1]
}
return previous
}
static Capture(window, test, readCompletion := true) {
AADisplay.UsePhysicalPixels()
target := CrusadersServer.FindGameWindow()
if !target {
if test
return 0
throw Error("Roblox screenshot unavailable")
}
target := "ahk_id " target
WinActivate(target)
if !WinWaitActive(target, , 2)
throw Error("Roblox screenshot unavailable")
WinGetClientPos(&x, &y, &width, &height, target)
if width != 800 || (height != 599 && height != 600)
throw Error("Roblox screenshot size invalid")
token := Gdip_Startup()
bitmap := 0
path := A_Temp "\bayzo-webhook-" DllCall("GetCurrentProcessId") "-" CrusadersRuntime.Tick() ".png"
try {
bitmap := Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
if !bitmap || Gdip_SaveBitmapToFile(bitmap, path) != 0
throw Error("Could not save Roblox screenshot")
completionTime := "Not available"
if readCompletion {
ocr := 0
try {
ocr := CrusadersOcr()
completionTime := this.CompletionTime(bitmap, ocr)
} catch Error {
completionTime := "Not available"
} finally {
if ocr
ocr.Dispose()
}
}
return {bytes:FileRead(path, "RAW"), completionTime:completionTime}
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
Gdip_Shutdown(token)
if FileExist(path)
FileDelete(path)
}
}
static Bytes(text) {
bytes := Buffer(StrPut(text, "UTF-8"), 0)
StrPut(text, bytes, "UTF-8")
bytes.Size -= 1
return bytes
}
static JsonData(value) {
if !IsObject(value) || value is ComValue
return value
if value is Array {
result := []
for item in value
result.Push(this.JsonData(item))
return result
}
result := Map()
if value is Map {
for key, item in value
result[key] := this.JsonData(item)
return result
}
for key, item in value.OwnProps()
result[key] := this.JsonData(item)
return result
}
static Multipart(payload, files) {
boundary := "BayzoMacro" CrusadersRuntime.Tick() Random(100000, 999999)
chunks := [this.Bytes("--" boundary "`r`nContent-Disposition: form-data; name=" Chr(34) "payload_json" Chr(34)
"`r`nContent-Type: application/json`r`n`r`n" Jxon_Dump(this.JsonData(payload)) "`r`n")]
for file in files {
chunks.Push(this.Bytes("--" boundary "`r`nContent-Disposition: form-data; name=" Chr(34) "files[" (A_Index - 1) "]" Chr(34)
"; filename=" Chr(34) file.name Chr(34) "`r`nContent-Type: image/png`r`n`r`n"))
chunks.Push(file.bytes, this.Bytes("`r`n"))
}
chunks.Push(this.Bytes("--" boundary "--`r`n"))
size := 0
for chunk in chunks
size += chunk.Size
body := ComObjArray(0x11, size)
data := 0
if DllCall("oleaut32\SafeArrayAccessData", "Ptr", ComObjValue(body), "Ptr*", &data, "Int") != 0
throw Error("Could not prepare webhook upload")
try {
offset := 0
for chunk in chunks {
DllCall("ntdll\RtlMoveMemory", "Ptr", data + offset, "Ptr", chunk, "UPtr", chunk.Size)
offset += chunk.Size
}
} finally DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", ComObjValue(body))
return {body:body, contentType:"multipart/form-data; boundary=" boundary}
}
static Send(window, result, test := false, match := "") {
global selector, testCancelled
accessPaused := result = "Access denied"
recoveryNotice := accessPaused || result = "Recovery"
if !test && !Integer(selector.preferences["WebhookEnabled"])
return false
try {
if this.jobs.Length >= 4
throw Error("Webhook queue full")
url := this.Url(selector.preferences["Webhook"])
if selector.preferences.Get("WebhookPingEnabled", "0") = "1" && !this.PingId(selector.preferences.Get("WebhookDiscordId", ""))
CrusadersLog("Webhook ping skipped: enter a valid Discord User ID in Webhooks settings")
files := []
if !test && !recoveryNotice && result!="Dungeon Reward" {
delay := Integer(selector.preferences.Get("WebhookScreenshotDelay", "1500"))
CrusadersLog("Webhook screenshot delay: " delay " ms")
if !CrusadersRuntime.Wait(delay, (*) => testCancelled)
return false
}
screenshot := 0
if recoveryNotice {
try screenshot := this.Capture(window, true, false)
catch Error
CrusadersLog("Recovery screenshot unavailable; sending notification without it")
} else screenshot := this.Capture(window, test,result!="Dungeon Reward")
payload := this.Payload(window, selector.preferences, result, test, match, screenshot ? screenshot.completionTime : "Not available")
if screenshot {
files.Push({name:"result.png", bytes:screenshot.bytes})
payload.embeds[1].image := {url:"attachment://result.png"}
}
if !payload.embeds[1].HasOwnProp("thumbnail") && FileExist(CrusadersTheme.Mascot) {
files.Push({name:"bayzo.png", bytes:FileRead(CrusadersTheme.Mascot, "RAW")})
payload.embeds[1].thumbnail := {url:"attachment://bayzo.png"}
}
upload := this.Multipart(payload, files)
job := {url:url, upload:upload, test:test, accessPaused:accessPaused, recoveryNotice:recoveryNotice, retries:0, nextSend:0, request:0, deadline:CrusadersRuntime.Tick() + 30000}
this.StartRequest(job)
this.jobs.Push(job)
SetTimer(this.timer, 250)
CrusadersLog(recoveryNotice ? "Sending recovery webhook" : test ? "Test webhook sending" : "Sending match screenshot to webhook")
return true
} catch Error {
CrusadersLog("Webhook not sent. Check the webhook URL, connection, and Roblox window.")
return false
}
}
static StartRequest(job) {
request := ComObject("WinHttp.WinHttpRequest.5.1")
request.SetTimeouts(3000, 5000, 5000, 15000)
request.Option[6] := false
request.Open("POST", job.url, true)
request.SetRequestHeader("Content-Type", job.upload.contentType)
request.Send(job.upload.body)
job.request := request
}
static Poll() {
if this.polling
return
this.polling := true
try {
count := this.jobs.Length
loop count {
index := count - A_Index + 1
job := this.jobs[index]
try {
if job.nextSend {
if CrusadersRuntime.Tick() < job.nextSend
continue
job.nextSend := 0
this.StartRequest(job)
}
if CrusadersRuntime.Tick() >= job.deadline
throw Error("Webhook delivery timed out")
if !job.request.WaitForResponse(0)
continue
status := job.request.Status
if status = 429 && job.retries = 0 {
json := job.request.ResponseText
response := Jxon_Load(&json)
job.retries := 1
job.nextSend := CrusadersRuntime.Tick() + Max(1000, Min(30000, Ceil(response.Get("retry_after", 1) * 1000)))
job.deadline := job.nextSend + 30000
continue
}
CrusadersLog(status >= 200 && status < 300 ? (job.recoveryNotice ? "Recovery webhook sent" : job.test ? "Test webhook sent" : "Match webhook sent")
: "Webhook delivery failed (HTTP " status "). Macro continuing.")
} catch Error {
try job.request.Abort()
CrusadersLog("Webhook delivery failed. Macro continuing.")
}
this.jobs.RemoveAt(index)
}
if !this.jobs.Length
SetTimer(this.timer, 0)
} finally this.polling := false
}
}
class CrusadersHunter {
__New(lobby) {
this.lobby := lobby
this.selected := ""
this.normalConfirmed := false
this.detailFromSelection := false
this.lastPageSignature := []
this.lastPageCards := []
this.rejectedCostTiers := Map()
}
static ContractName(text) {
text := RegExReplace(text, "\s+", "")
for name in StrSplit(CrusadersCatalog.DefaultContractPriority, "|") {
pattern := StrReplace(name, " ", "")
if RegExMatch(text, "i)\b" pattern "\b")
return name
}
return ""
}
DetailPanelBitmap(bitmap) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
return false
button := 0, close := 0
for point in [{x:342,y:402}, {x:460,y:402}, {x:342,y:425}, {x:460,y:425}, {x:632,y:145}, {x:654,y:145}] {
rgb := Gdip_GetPixel(bitmap, point.x, point.y)
r := (rgb >> 16) & 255, g := (rgb >> 8) & 255, b := rgb & 255
gold := r >= 170 && g >= 100 && b < g * 0.65
if point.y = 145
close += gold
else
button += gold
}
return button >= 3 && close >= 1
}
StateBitmap(bitmap) {
lobby := this.lobby
if RegExMatch(lobby.Text(bitmap, 210, 162, 260, 40), "i)Active\s*Contracts")
return "HunterContracts"
if RegExMatch(lobby.Text(bitmap, 205, 103, 198, 36), "i)^Normal[.!]?$" )
&& RegExMatch(lobby.Text(bitmap, 455, 92, 195, 36), "i)^Advanced[.!]?$")
return "HunterDifficulty"
if RegExMatch(lobby.Text(bitmap, 244, 321, 95, 28), "i)^Kit$")
&& RegExMatch(lobby.Text(bitmap, 353, 475, 110, 34), "i)Contract\s*UI")
return "HunterNpc"
if this.selected != "" && this.DetailPanelBitmap(bitmap)
return "HunterDetail"
if CrusadersHunter.ContractName(lobby.Text(bitmap, 222, 121, 224, 43)) != ""
return "HunterDetail"
if RegExMatch(lobby.Text(bitmap, 125, 120, 675, 65), "i)Hunter\s*Mayhem\s*Event")
return "HunterArrival"
return ""
}
CardsBitmap(bitmap) {
result := []
ink := this.TitleInk(bitmap)
first := 0
last := 0
spans := []
loop 501 {
x := 149 + A_Index
white := ink.columns[A_Index]
if white {
if !first
first := x
last := x
} else if first && x - last > 14 {
spans.Push({left: first, right: last})
first := 0
}
}
if first
spans.Push({left: first, right: last})
for span in spans {
if span.right - span.left < 35 || span.left < 155 || span.right > 642
continue
center := Round((span.left + span.right) / 2)
width := Max(125, span.right - span.left + 12)
left := Max(150, span.left - 5)
text := this.lobby.Text(bitmap, left, 226, Min(width, 650 - left), 20)
name := CrusadersHunter.ContractName(text)
if name = "" || RegExReplace(text, "[\s.!]", "") != StrReplace(name, " ", "")
continue
modifier := this.CardModifier(bitmap, left, Min(width, 650 - left))
result.Push({name: name, x: center, modifier: modifier, eligible: modifier = "Other"})
}
return result
}
static ModifierKind(text) {
text := StrLower(RegExReplace(CrusadersOcr.NormalizeLabels(text), "[\s\p{P}_]+", ""))
if RegExMatch(text, "h[i1l]?[gqo]hc[o0](?:[s5]t|[s5]|d|t)?")
return "HighCost"
return RegExMatch(text, "(?:fast|fa[dt]|tank|regen|regeneration)enem(?:ies|es|e[s5]|y)") ? "Other" : "Unknown"
}
CardModifier(bitmap, left, width) {
width := Min(width, 100)
first := CrusadersHunter.ModifierKind(this.lobby.ocr.Read(bitmap, left, 220, width, 40, 5))
if first = "HighCost"
return first
second := CrusadersHunter.ModifierKind(this.lobby.ocr.Read(bitmap, left, 220, width, 40, 7))
if second = "HighCost"
return second
if first = "Other" && second = "Other"
return "Other"
first := CrusadersHunter.ModifierKind(this.lobby.ocr.Read(bitmap, left, 241, width, 10, 5))
second := CrusadersHunter.ModifierKind(this.lobby.ocr.Read(bitmap, left, 241, width, 10, 7))
if first = "HighCost" || second = "HighCost"
return "HighCost"
return first = "Other" && second = "Other" ? "Other" : "Unknown"
}
TitlePixel(rgb) {
r := (rgb >> 16) & 255
g := (rgb >> 8) & 255
b := rgb & 255
return Min(r, g, b) >= 185 && Max(r, g, b) - Min(r, g, b) <= 35
}
Signature(bitmap) {
return this.TitleInk(bitmap).signature
}
TitleInk(bitmap) {
if Gdip_LockBits(bitmap, 150, 231, 501, 12, &stride, &pixels, &data, 1) != 0
throw Error("Could not read Hunter contract titles; no card clicked.")
columns := []
signature := []
try {
loop 501 {
column := A_Index - 1
white := false
loop 12 {
value := this.TitlePixel(NumGet(pixels + (A_Index - 1) * stride + column * 4, "UInt"))
signature.Push(value)
white := white || value
}
columns.Push(white)
}
} finally Gdip_UnlockBits(bitmap, &data)
return {columns: columns, signature: signature}
}
ExactSignature(first, second) {
if first.Length != second.Length
return false
for index, value in first
if value != second[index]
return false
return true
}
SameSignature(first, second) {
matches := 0
ink := 0
for index, value in first {
if value || second[index] {
ink += 1
if value && second[index]
matches += 1
}
}
return ink >= 30 && matches >= ink * 0.90
}
Scroll(direction) {
lobby := this.lobby
if !lobby.Check()
return false
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
MouseGetPos(&x, &y)
if Abs(x - 400) > 2 || Abs(y - 250) > 2 {
MouseMove(400, 250, 2)
MouseMove(401, 250, 2)
MouseMove(400, 250, 2)
if !lobby.Wait(100)
return false
}
SendEvent("{Wheel" direction " 1}")
return lobby.Wait(100)
} finally CoordMode("Mouse", previous)
}
ReadPage(found := 0) {
bitmap := this.lobby.Snapshot()
try {
signature := this.Signature(bitmap)
if found {
if !this.ExactSignature(this.lastPageSignature, signature) {
this.lastPageCards := this.CardsBitmap(bitmap)
this.lastPageSignature := signature
}
for card in this.lastPageCards {
if card.modifier = "HighCost" && !this.rejectedCostTiers.Has(card.name) {
this.rejectedCostTiers[card.name] := true
CrusadersLog("Skipping High Cost " card.name)
}
if card.eligible && !found.Has(card.name) {
found[card.name] := true
CrusadersLog("Hunter contracts: found " card.name)
}
}
}
return signature
} finally Gdip_DisposeImage(bitmap)
}
Traverse(direction, found := 0) {
previous := this.ReadPage(found)
unchanged := 0
loop 40 {
if !this.Scroll(direction)
return false
current := this.ReadPage(found)
unchanged := this.SameSignature(previous, current) ? unchanged + 1 : 0
previous := current
if unchanged >= 2 {
CrusadersLog("Hunter contracts: " (direction = "Down" ? "end" : "beginning") " of list confirmed")
return true
}
}
throw Error("Hunter contract list boundary not confirmed; no contract clicked.")
}
PickPriority(found) {
for name in CrusadersCatalog.ContractPriorities(this.lobby.config.preferences["ContractPriority"])
if found.Has(name)
return name
throw Error("No recognized available Hunter contracts; no card clicked.")
}
SelectContract() {
this.normalConfirmed := false
this.detailFromSelection := false
found := Map()
this.lastPageSignature := []
this.lastPageCards := []
this.rejectedCostTiers := Map()
if !this.Traverse("Down", found) || !this.Traverse("Up", found)
return false
while found.Count {
wanted := this.PickPriority(found)
CrusadersLog("Hunter contracts: choosing " wanted " by priority")
outcome := this.TrySelectContract(wanted)
if outcome = "Selected"
return true
if outcome = "Cancelled"
return false
found.Delete(wanted)
CrusadersLog("Hunter contracts: " wanted " unavailable or changed; trying next priority")
if found.Count && !this.Traverse("Up")
return false
}
throw Error("No eligible Hunter contract could be confirmed; High Cost and unreadable modifiers skipped, no card clicked.")
}
TrySelectContract(wanted) {
previous := []
unchanged := 0
loop 40 {
if !this.lobby.Check()
return "Cancelled"
bitmap := this.lobby.Snapshot()
try {
cards := this.CardsBitmap(bitmap)
signature := this.Signature(bitmap)
}
finally Gdip_DisposeImage(bitmap)
for card in cards {
if card.name != wanted || !card.eligible
continue
if !this.lobby.Wait(100)
return "Cancelled"
bitmap := this.lobby.Snapshot()
try confirm := this.CardsBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
for match in confirm {
if match.name = wanted && match.eligible && Abs(match.x - card.x) < 30 {
this.selected := wanted
return this.lobby.ClickStep(match.x, 350, wanted) ? "Selected" : "Cancelled"
}
}
}
unchanged := previous.Length && this.SameSignature(previous, signature) ? unchanged + 1 : 0
if unchanged >= 2
return "Unavailable"
previous := signature
if !this.Scroll("Down")
return "Cancelled"
}
return "Unavailable"
}
StartVisible() => FindCrusadersStart(&x, &y)
WaitContractTransition() {
deadline := CrusadersRuntime.Now() + 10000
stability := CrusadersStartStability()
difficultyFrames := 0
loop {
if !this.lobby.Check()
return "Cancelled"
found := this.lobby.StartVoteVisible(&x, &y)
if stability.Observe(found, found ? x : 0, found ? y : 0, CrusadersRuntime.Now()) {
if !this.VerifyMatch()
return "Cancelled"
this.lobby.retainCamera := true
CrusadersLog("Hunter next gate ready; keeping current camera")
return "Match"
}
difficultyFrames := !found && this.lobby.State() = "HunterDifficulty" ? difficultyFrames + 1 : 0
if difficultyFrames >= 2
return "Difficulty"
if CrusadersRuntime.Now() >= deadline
throw CrusadersLobbyTimeout("Hunter contract did not open difficulty selection or Start Game.")
if !this.lobby.Wait(75)
return "Cancelled"
}
}
NextGate() {
lobby := this.lobby
if !lobby.WaitState("HunterContracts", 30000) || !this.SelectContract()
return false
deadline := CrusadersRuntime.Now() + 60000
frames := 0
loop {
if !lobby.Check()
return false
frames := this.StartVisible() ? frames + 1 : 0
if frames >= 2 {
CrusadersLog("Hunter next gate: Start prompt confirmed; keeping current camera (no zoomtech)")
return true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Hunter next gate did not show the Start prompt; no zoom or Start click sent.")
if !lobby.Wait(100)
return false
}
}
VerifyDetail() {
if !this.normalConfirmed
throw Error("Hunter Normal selection was not confirmed. Return to the contracts list; Play not clicked.")
confirmed := "", frames := 0, wrong := "", wrongFrames := 0
deadline := CrusadersRuntime.Now() + 8000
loop {
if !this.lobby.Check()
return false
bitmap := this.lobby.Snapshot()
try {
name := CrusadersHunter.ContractName(this.lobby.ocr.Read(bitmap, 222, 121, 224, 43, 5))
if name = ""
name := CrusadersHunter.ContractName(this.lobby.ocr.Read(bitmap, 222, 121, 224, 43, 3))
} finally Gdip_DisposeImage(bitmap)
if name = "" {
frames := 0
wrongFrames := 0
} else if this.selected != "" && name != this.selected {
frames := 0
wrongFrames := name = wrong ? wrongFrames + 1 : 1
wrong := name
if wrongFrames >= 2
throw Error("Hunter detail shows " name " instead of " this.selected "; Play not clicked.")
} else {
wrongFrames := 0
frames := name = confirmed ? frames + 1 : 1
confirmed := name
if frames >= 2 {
this.selected := name
CrusadersLog("Hunter contract verified: " name " / Normal selected")
return true
}
}
if CrusadersRuntime.Now() >= deadline
throw Error("Hunter contract title could not be read; Play not clicked.")
if !this.lobby.Wait(150)
return false
}
}
VerifyMatch() {
confirmed := "", frames := 0, wrong := "", wrongFrames := 0
deadline := CrusadersRuntime.Now() + 8000
loop {
if !this.lobby.Check()
return false
bitmap := this.lobby.Snapshot()
try {
name := CrusadersHunter.ContractName(this.lobby.ocr.Read(bitmap, 620, 210, 180, 100, 4))
if name = ""
name := CrusadersHunter.ContractName(this.lobby.ocr.Read(bitmap, 650, 230, 150, 65, 6))
} finally Gdip_DisposeImage(bitmap)
if name != "" {
if this.selected != "" && name != this.selected {
frames := 0
wrongFrames := name = wrong ? wrongFrames + 1 : 1
wrong := name
if wrongFrames >= 2
throw Error("Hunter match shows " name " instead of " this.selected "; vote not clicked.")
} else {
wrongFrames := 0
frames := name = confirmed ? frames + 1 : 1
confirmed := name
if frames >= 2 {
CrusadersLog("Hunter match confirmed: " name)
return true
}
}
} else {
frames := 0
wrongFrames := 0
}
if CrusadersRuntime.Now() >= deadline
throw Error("Hunter match contract label could not be read; vote not clicked.")
if !this.lobby.Wait(150)
return false
}
}
Interact() {
if !this.lobby.Check()
return false
SendEvent("{e down}")
try Sleep(60)
finally SendEvent("{e up}")
CrusadersLog("Hunter NPC: E interaction sent")
return true
}
Join(state, waitForInstance) {
lobby := this.lobby
if state = "Lobby" {
if waitForInstance && !lobby.Wait(5000)
return false
if !lobby.ClickStep(327, 158, "Hunter Mayhem area") || !lobby.WaitState("HunterArrival") || !lobby.Wait(500)
return false
state := "HunterArrival"
}
if state = "HunterArrival" {
if !this.Interact()
return false
if !lobby.WaitState("HunterNpc")
return false
state := "HunterNpc"
}
if state = "HunterNpc" {
if !lobby.ClickTransition(405, 493, "Open Contract UI", "HunterNpc", "HunterContracts")
return false
state := "HunterContracts"
}
if state = "HunterContracts" {
if !this.SelectContract()
return false
transition := this.WaitContractTransition()
if transition = "Match"
return true
if transition = "Cancelled"
return false
state := "HunterDifficulty"
}
if state = "HunterDifficulty" {
if !lobby.WaitState("HunterDifficulty") || !lobby.ClickTransition(305, 260, "Normal only", "HunterDifficulty", "HunterDetail", 750)
return false
this.normalConfirmed := true
this.detailFromSelection := this.selected != ""
state := "HunterDetail"
}
if state = "HunterDetail" {
if !this.detailFromSelection {
if !this.VerifyDetail()
return false
} else
CrusadersLog("Hunter contract selected: " this.selected " / Normal; waiting for Play animation")
if !lobby.ClickTransition(400, 414, "Contract Play", "HunterDetail", "Matchmaking", 750)
return false
state := "Matchmaking"
}
if state = "Matchmaking" {
if !this.normalConfirmed
throw Error("Hunter Normal selection not verified; return to contracts before starting.")
if !lobby.ClickTransition(328, 318, "Play Here", "Matchmaking", "Ready")
return false
state := "Ready"
}
if state != "Ready"
throw Error("Unrecognized Hunter join state; no Start click sent.")
if !this.normalConfirmed
throw Error("Hunter Normal selection not verified; Start not clicked.")
if !lobby.StartVerifiedSelection()
return false
return lobby.WaitMatch()
}
}
class CrusadersDailyRewards {
static Days := [{x:275,y:266}, {x:351,y:266}, {x:427,y:266},
{x:275,y:356}, {x:351,y:356}, {x:427,y:356}, {x:516,y:313}]
__New(lobby) {
this.lobby := lobby
}
static Matches(bitmap, ocr) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
return false
if CrusadersDetection.Configured("daily-rewards")
return CrusadersDetection.FindBitmap(bitmap, "daily-rewards")
return RegExMatch(ocr.Read(bitmap, 263, 180, 170, 30, 5), "i)^Daily\s*Rewards$")
&& RegExMatch(ocr.Read(bitmap, 246, 215, 62, 30, 5), "i)^Day[\s\p{P}_]*1$")
&& RegExMatch(ocr.Read(bitmap, 480, 215, 78, 30, 5), "i)^Day[\s\p{P}_]*7$")
}
Visible() {
bitmap := this.lobby.Snapshot()
try return CrusadersDailyRewards.Matches(bitmap, this.lobby.ocr)
finally Gdip_DisposeImage(bitmap)
}
HandleIfVisible() {
this.handled := false
if !this.lobby.Check()
return false
if !this.Visible()
return true
if !this.lobby.Wait(150)
return false
if !this.Visible()
return true
CrusadersLog("Daily rewards detected")
this.handled := true
for day, point in CrusadersDailyRewards.Days {
if !this.lobby.Check()
return false
if !this.Visible() {
CrusadersLog("Daily rewards closed")
return true
}
CrusadersLog("Checking Day " day " reward")
if !this.lobby.ClickInput(point.x, point.y) || !this.lobby.Wait(200)
return false
}
if this.Visible()
if !this.lobby.ClickInput(3, 3) || !this.lobby.Wait(200)
return false
frames := 0
deadline := CrusadersRuntime.Now() + 3000
loop {
if !this.lobby.Check()
return false
frames := !this.Visible() ? frames + 1 : 0
if frames >= 2 {
CrusadersLog("Daily rewards closed")
return true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Daily rewards are still open. No lobby navigation click sent.")
if !this.lobby.Wait(100)
return false
}
}
}
class CrusadersUpdateLog {
__New(lobby) {
this.lobby := lobby
}
static Matches(bitmap, ocr) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
return false
if CrusadersDetection.Configured("update-log")
return CrusadersDetection.FindBitmap(bitmap, "update-log")
if !RegExMatch(ocr.Read(bitmap, 210, 130, 160, 35, 5), "i)^Update\s*Log$")
return false
red := 0
for point in [{x:630,y:152}, {x:652,y:152}, {x:642,y:138}, {x:642,y:171}] {
rgb := Gdip_GetPixel(bitmap, point.x, point.y)
r := (rgb >> 16) & 255
g := (rgb >> 8) & 255
b := rgb & 255
red += r >= 150 && r > g * 1.5 && r > b * 1.5
}
return red >= 3
}
Visible() {
bitmap := this.lobby.Snapshot()
try return CrusadersUpdateLog.Matches(bitmap, this.lobby.ocr)
finally Gdip_DisposeImage(bitmap)
}
HandleIfVisible() {
this.handled := false
if !this.lobby.Check()
return false
if !this.Visible()
return true
if !this.lobby.Wait(150)
return false
if !this.Visible()
return true
CrusadersLog("Update log detected")
this.handled := true
if !this.lobby.ClickInput(643, 155)
return false
deadline := CrusadersRuntime.Now() + 3000
frames := 0
loop {
if !this.lobby.Wait(100)
return false
frames := !this.Visible() ? frames + 1 : 0
if frames >= 2 {
CrusadersLog("Update log closed")
return true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Update log did not close. No lobby navigation click sent.")
}
}
WaitAfterRewards() {
CrusadersLog("Checking for update log")
deadline := CrusadersRuntime.Now() + 1500
loop {
if !this.HandleIfVisible()
return false
if this.handled || CrusadersRuntime.Now() >= deadline
return true
if !this.lobby.Wait(100)
return false
}
}
}
class CrusadersTeams {
static Positions := Map(1, [0, 275], 2, [0, 348], 3, [1, 320], 4, [1, 392],
5, [2, 365], 6, [3, 338], 7, [4, 311], 8, [4, 384], 9, [5, 357], 10, [6, 349])
static MatchPositions := Map(1, [0, 266], 2, [0, 339], 3, [1, 312], 4, [1, 384],
5, [2, 357], 6, [3, 329], 7, [4, 303], 8, [4, 376], 9, [5, 348], 10, [6, 340])
__New(lobby) {
this.lobby := lobby
directory := A_ScriptDir "\Other"
this.root := directory "\..\Images\Detection\Teams"
}
Matches(bitmap, name) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
return false
return CrusadersDetection.Lettering(bitmap, StrLower(name))
}
Visible(name) {
bitmap := this.lobby.Snapshot()
try return this.Matches(bitmap, name)
finally Gdip_DisposeImage(bitmap)
}
WaitMenu(name, expected := true) {
deadline := CrusadersRuntime.Now() + 4000
frames := 0
loop {
if !this.lobby.Check()
return false
frames := this.Visible(name) = expected ? frames + 1 : 0
if frames >= CrusadersDetection.Get(StrLower(name)).frames
return true
if CrusadersRuntime.Now() >= deadline
throw Error(name " menu did not " (expected ? "open" : "close") "; team swap stopped.")
if !this.lobby.Wait(100)
return false
}
}
Wheel(direction, count) {
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
MouseMove(460, 300, 2)
if !this.lobby.Wait(150)
return false
loop count {
if !this.lobby.Check()
return false
SendEvent("{Wheel" direction "}")
if !this.lobby.Wait(180)
return false
}
return true
} finally CoordMode("Mouse", previous)
}
Load(team, inMatch := false) {
if !RegExMatch(team, "^\d+$") || Integer(team) > 10
throw Error("Team must be between 0 and 10.")
team := Integer(team)
if !team
return true
if !this.lobby.Check() || !this.lobby.HandlePopups()
return false
CrusadersLog("Loading Team " team)
if !this.Visible("Teams") {
if !this.Visible("Units") {
unitX := inMatch ? 48 : 34
unitY := inMatch ? 255 : 234
if !this.lobby.ClickStep(unitX, unitY, "Units") || !this.WaitMenu("Units")
return false
}
if !this.lobby.ClickStep(600, 215, "Teams") || !this.WaitMenu("Teams")
return false
}
if !this.Wheel("Up", 8)
return false
position := inMatch ? CrusadersTeams.MatchPositions[team] : CrusadersTeams.Positions[team]
if position[1] && !this.Wheel("Down", position[1])
return false
if !this.lobby.ClickStep(527, position[2], "Load Team " team) || !this.WaitMenu("Teams")
return false
if !this.lobby.ClickStep(567, 185, "Close Teams") || !this.WaitMenu("Teams", false)
return false
if this.Visible("Units")
if !this.lobby.ClickStep(654, 166, "Close Units") || !this.WaitMenu("Units", false)
return false
CrusadersLog("Team " team " load clicked; menus closed")
return true
}
}
class CrusadersLobby {
static LobbyBitmap(bitmap, ocr) {
return RegExMatch(ocr.Read(bitmap, 625, 3, 165, 32), "i)UPDATE\s*6\.0\.0")
&& RegExMatch(ocr.Read(bitmap, 69, 286, 48, 30), "i)^Play$")
}
static BossStages := Map("Aizen", "Perfection", "Makima", "Control")
static RaidSelectionMaps := Map(
"Amusement Park", {y: 228, pattern: "i)\bAmusement\s*Park\b",
stages: ["Psychic", "Immortal", "Crusher", "Lonely Fool", "Thunderbird"]},
"Tokyo Empire", {y: 270, pattern: "i)\bTokyo\s*Empire\b", stages: ["Emperor"]},
"Desert", {y: 312, pattern: "i)\bDesert\b",
stages: ["Bone King", "Spear Servant", "Bow Servant", "Sword Servant", "King of Desert"]},
"Destroyed Soul Society", {y: 354, pattern: "i)\bDestroyed\s*Soul\s*Society\b", stages: ["Wolf"]},
"Cell Arena", {y: 396, pattern: "i)\bC(?:ell|all)\s*Arena\b",
stages: ["Future's Saiyan", "Golden Alien", "Crazy Android", "Majin Boo", "PERFECT"]},
"Shinjuku", {y: 337, scrolls: 1, pattern: "i)\bShinjuku\b",
stages: ["Rejected Sister", "Blood Manipulator", "Lightning God", "Deadly Attorney", "Reckless Gambler"]})
static LegendSelectionMaps := Map(
"Shibuya", {y: 228, pattern: "i)\bShibuya\b"},
"Nightmare Train", {y: 270, pattern: "i)\bNigh\s*tmare\s*Train\b"},
"Mirror Dimension", {y: 312, pattern: "i)\bMirror\s*Dimen\s*sion\b"},
"Samurai Island", {y: 354, pattern: "i)\bSamurai\s*Island\b"},
"False Karakura", {y: 396, pattern: "i)\bFalse\s*Karakura\b"},
"Godly Arena", {y: 337, scrolls: 1, pattern: "i)\bGodly\s*Arena\b"})
static SelectionMaps := Map(
"Planet Greenie", {y: 228, pattern: "i)\bPlanet\s*Namak\b"},
"Marine Ford", {y: 270, pattern: "i)\bMarine\s*(?:['\x{2019}]?\s*s)?\s*Ford\b"},
"Karakura Town", {y: 312, pattern: "i)\bKarakura\s*Town\b"},
"Shibuya", {y: 354, pattern: "i)\bShibuya\b"},
"Demon District", {y: 396, pattern: "i)\bDemon\s*District\b"},
"Devil City", {y: 237, scrolls: 2, pattern: "i)\bDevil\s*City\b"},
"Soul Society", {y: 279, scrolls: 2, pattern: "i)\bSoul\s*Society\b"},
"West City", {y: 321, scrolls: 2, pattern: "i)\bWest\s*City(?:\s*\(Ruined\))?\b"},
"Culling Games", {y: 363, scrolls: 2, pattern: "i)\bCul{1,2}ing\s*Games\b"},
"Doldrey", {y: 405, scrolls: 2, pattern: "i)\bDoldrey\b"})
__New(config, route, shouldStop := 0) {
this.config := config
this.route := route
this.shouldStop := shouldStop
CrusadersVision.Open(this)
this.dailyRewards := CrusadersDailyRewards(this)
this.updateLog := CrusadersUpdateLog(this)
this.hunter := CrusadersHunter(this)
}
Dispose() {
CrusadersVision.Close(this)
}
Check() {
if this.shouldStop && this.shouldStop.Call()
return false
if this.HasOwnProp("gameWindow")
this.gameWindow.EnsureGameSize(true)
if !CrusadersRuntime.EnsureFocus(this.Target(), this.shouldStop)
return false
WinGetClientPos(, , &w, &h, this.Target())
if w != 800 || (h != 599 && h != 600)
throw Error("Lobby joining requires an 800 x 599 Roblox client.")
if CrusadersRuntime.joining && (!this.HasOwnProp("lastJoinErrorScan") || CrusadersRuntime.Now() - this.lastJoinErrorScan >= 750) {
this.lastJoinErrorScan := CrusadersRuntime.Now()
bitmap := this.Snapshot()
try failure := CrusadersJoinError.Kind(bitmap, this.ocr)
finally Gdip_DisposeImage(bitmap)
if failure = "Access denied"
throw CrusadersAccessDenied("Access denied")
if failure != ""
throw CrusadersJoinErrorDetected(failure)
}
return true
}
Wait(ms) => CrusadersRuntime.Wait(ms, this.shouldStop) && this.Check()
Target() => this.HasOwnProp("gameWindow") ? "ahk_id " this.gameWindow.game : "ahk_exe RobloxPlayerBeta.exe"
Snapshot() {
WinGetClientPos(&x, &y, &w, &h, this.Target())
bitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
if !bitmap
throw Error("Could not capture lobby.")
return bitmap
}
Text(bitmap, x, y, w, h) => this.ocr.Read(bitmap, x, y, w, h)
StateBitmap(bitmap) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) < 599
throw Error("Lobby reference has an unsupported size.")
if CrusadersDailyRewards.Matches(bitmap, this.ocr)
return "DailyRewards"
if CrusadersUpdateLog.Matches(bitmap, this.ocr)
return "UpdateLog"
if CrusadersDetection.Configured("stage-menu") && CrusadersDetection.FindBitmap(bitmap, "stage-menu")
return "StageMenu"
if CrusadersDetection.Configured("mode-menu") && CrusadersDetection.FindBitmap(bitmap, "mode-menu")
return "ModeMenu"
if CrusadersDetection.Configured("matchmaking") ? CrusadersDetection.FindBitmap(bitmap, "matchmaking")
: RegExMatch(this.Text(bitmap, 235, 202, 330, 42), "i)Join\s+Matchmaking")
return "Matchmaking"
if RegExMatch(this.Text(bitmap, 280, 464, 242, 56), "i)^Start$")
&& RegExMatch(this.Text(bitmap, 43, 152, 174, 30), "i)Game will begin soon")
return "Ready"
if this.config.preferences["Mode"] = "Event" {
state := this.hunter.StateBitmap(bitmap)
if state != ""
return state
}
if this.config.preferences["Mode"] = "Boss Rush" {
if this.config.preferences["Map"] = "Makima" && this.CardsBitmap(bitmap)
return "Cards"
if this.TraitsBitmap(bitmap) != ""
return "BossMenu"
makima := this.config.preferences["Map"] = "Makima"
if RegExMatch(this.Text(bitmap, 250, 473, 310, 40), makima ? "i)^Continue$" : "i)Open\s*Boss\s*Rush")
&& RegExMatch(this.Text(bitmap, 240, 320, 120, 30), makima ? "i)Denju" : "i)A[y i]?zen")
return "BossNpc"
if RegExMatch(this.Text(bitmap, 390, 222, 155, 115), "i)Leaderboards")
return "Areas"
}
if RegExMatch(this.Text(bitmap, 465, 174, 90, 29), "i)^Story\s*Stages$")
&& RegExMatch(this.Text(bitmap, 540, 418, 100, 37), "i)^Select$")
return "StageMenu"
if this.config.preferences["Mode"] = "Raids"
&& RegExMatch(this.Text(bitmap, 394, 211, 290, 47), "i)\bRaid\s*:")
&& RegExMatch(this.Text(bitmap, 540, 418, 100, 37), "i)^Select$")
return "StageMenu"
if RegExMatch(this.Text(bitmap, 375, 138, 55, 28), "i)^Story\b")
&& RegExMatch(this.Text(bitmap, 144, 190, 65, 28), "i)^Raids$")
return "ModeMenu"
if RegExMatch(this.Text(bitmap, 342, 375, 125, 28), "i)Teleporting\s+To")
return "Teleport"
if CrusadersLobby.LobbyBitmap(bitmap, this.ocr)
return "Lobby"
return ""
}
State() {
if !this.Check()
return ""
bitmap := this.Snapshot()
try state := this.StateBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
if state = "DailyRewards" || state = "UpdateLog" {
if !this.HandlePopups()
return ""
bitmap := this.Snapshot()
try state := this.StateBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
}
return state
}
HandlePopups() {
loop 2 {
if this.HasOwnProp("dailyRewards") && !this.dailyRewards.HandleIfVisible()
return false
if this.HasOwnProp("updateLog") && !this.updateLog.HandleIfVisible()
return false
if this.HasOwnProp("dailyRewards") && this.dailyRewards.HasOwnProp("handled") && this.dailyRewards.handled
if this.HasOwnProp("updateLog") && !this.updateLog.WaitAfterRewards()
return false
}
return true
}
WaitState(expected, ms := 10000) {
deadline := CrusadersRuntime.Now() + ms
frames := 0
loop {
if !this.Check()
return false
frames := this.State() = expected ? frames + 1 : 0
if frames >= 2 {
CrusadersLog("Lobby: " expected " detected")
return true
}
if CrusadersRuntime.Now() >= deadline
throw CrusadersLobbyTimeout("Lobby timed out waiting for " expected "; no next click sent.")
if !this.Wait(100)
return false
}
}
OpenChallengeArea() {
if !this.ClickStep(91, 292, "Play", 0)
return false
CrusadersLog("Lobby: waiting 1500 ms after Play")
if !this.Wait(1500)
return false
return this.ClickStep(636, 260, "Challenges", 0)
}
ClickStep(x, y, label, delay := unset) {
if !this.Check()
return false
if !this.HandlePopups()
return false
buttons := Map("Play", "play", "Start", "pod-start", "Story", "story", "Raids", "raids",
"Leaderboards", "leaderboards")
detector := buttons.Has(label) ? buttons[label] : ""
if detector != "" && CrusadersDetection.Configured(detector) {
deadline := CrusadersRuntime.Now() + 3000
while !CrusadersDetection.Center(detector, &x, &y) {
if !this.Wait(150)
return false
if CrusadersRuntime.Now() >= deadline
throw Error("Button image not found: " label "; no fixed-coordinate click sent")
}
}
if !this.ClickInput(x, y)
return false
CrusadersLog("Lobby: " label " clicked")
return this.Wait(IsSet(delay) ? delay : Integer(this.config.preferences["StageClickDelay"]))
}
ClickTransition(x, y, label, source, expected, settle := 500) {
loop 2 {
if !this.ClickStep(x, y, label, settle)
return false
try return this.WaitState(expected, 5000)
catch CrusadersLobbyTimeout as err {
if A_Index = 2 || this.State() != source
throw err
CrusadersLog("Lobby: retrying " label)
}
}
return false
}
ClickInput(x, y) {
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
MouseMove(x, y, 2)
if !this.Wait(100)
return false
Click(x, y, "Down")
Sleep(60)
Click("Up")
return true
} finally {
SendEvent("{LButton up}")
CoordMode("Mouse", previous)
}
}
TaskLabel() {
preferences := this.config.preferences
if preferences["Mode"] = "Event"
return "Hunter Mayhem"
if preferences["Mode"] = "Boss Rush"
return preferences["Map"] " / Boss Rush: " CrusadersLobby.BossStages[preferences["Map"]] " / " preferences["BossRushMode"]
if preferences["Mode"] = "Raids" && this.MapProfiles().Has(preferences["Map"])
return preferences["Map"] " / Raid: " this.MapProfiles()[preferences["Map"]].stages[Integer(preferences["Act"])] " / "
CrusadersCatalog.EffectiveDifficulty("Raids", preferences["Map"], preferences["Difficulty"])
return preferences["Map"] " / " (preferences["Mode"] = "Infinite" ? "Infinite" : "Act " preferences["Act"] " / " preferences["Difficulty"])
}
MapProfiles() {
mode := this.config.preferences["Mode"]
return mode = "Raids" ? CrusadersLobby.RaidSelectionMaps
: mode = "Legend Stages" ? CrusadersLobby.LegendSelectionMaps : CrusadersLobby.SelectionMaps
}
MatchesStage(text) {
if this.config.preferences["Mode"] = "Event"
return RegExMatch(text, "i)Island\s*of\s*Greed")
if this.config.preferences["Mode"] = "Boss Rush"
return CrusadersLobby.BossStages.Has(this.config.preferences["Map"])
&& RegExMatch(text, "i)\bBoss\s*Rush\s*:\s*" CrusadersLobby.BossStages[this.config.preferences["Map"]] "\b")
profiles := this.MapProfiles()
if !profiles.Has(this.config.preferences["Map"])
return false
if !RegExMatch(text, profiles[this.config.preferences["Map"]].pattern)
return false
if this.config.preferences["Mode"] = "Raids" {
act := Integer(this.config.preferences["Act"])
stages := profiles[this.config.preferences["Map"]].stages
if act < 1 || act > stages.Length
return false
title := StrReplace(StrReplace(stages[act], " ", "\s*"), "'", "['\x{2019}]?")
return RegExMatch(text, "i)\bRaid\s*:\s*" title "\b")
}
if this.config.preferences["Mode"] = "Legend Stages"
return RegExMatch(text, "i)\bLegend\s*Stage\s*" Integer(this.config.preferences["Act"]) "\b")
if this.config.preferences["Mode"] = "Infinite"
return RegExMatch(text, "i)\bInfinite\b") && !RegExMatch(text, "i)\bAct\s*\d+\b")
return RegExMatch(text, "i)\bAct\s*" Integer(this.config.preferences["Act"]) "\b")
&& !RegExMatch(text, "i)\bInfinite\b")
}
MatchesTask(text) {
if this.config.preferences["Mode"] = "Raids"
return this.MatchesStage(text) && RegExMatch(text, "i)\b"
CrusadersCatalog.EffectiveDifficulty("Raids", this.config.preferences["Map"], this.config.preferences["Difficulty"]) "\b")
return this.MatchesStage(text) && (this.config.preferences["Mode"] != "Story"
|| RegExMatch(text, "i)\b" this.config.preferences["Difficulty"] "\b"))
}
ScrollStages(direction, count := 1) {
if !this.Check()
return false
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
MouseMove(330, 310, 2)
if !this.Wait(100)
return false
SendEvent("{Wheel" direction " " count "}")
return this.Wait(Integer(this.config.preferences["StageClickDelay"]))
} finally CoordMode("Mouse", previous)
}
SelectMap() {
profiles := this.MapProfiles()
profile := profiles[this.config.preferences["Map"]]
if profile.HasOwnProp("scrolls") && !this.ScrollMaps(profile.scrolls)
return false
return this.ClickStep(205, profile.y, this.config.preferences["Map"])
}
ScrollMaps(count) {
if !this.Check()
return false
previous := A_CoordModeMouse
CoordMode("Mouse", "Client")
try {
MouseMove(205, 310, 2)
if !this.Wait(100)
return false
loop count {
if !this.Check()
return false
SendEvent("{WheelDown 1}")
if !this.Wait(Integer(this.config.preferences["StageClickDelay"]))
return false
}
CrusadersLog("Lobby: map list scrolled " count " times")
return true
} finally CoordMode("Mouse", previous)
}
SelectStage() {
if !this.Check()
return false
if this.config.preferences["Mode"] = "Raids" {
act := Integer(this.config.preferences["Act"])
return this.ClickStep(330, 229 + (act - 1) * 42,
"Raid: " this.MapProfiles()[this.config.preferences["Map"]].stages[act])
}
if this.config.preferences["Mode"] = "Legend Stages" {
act := Integer(this.config.preferences["Act"])
return this.ClickStep(330, 229 + (act - 1) * 42, "Legend Stage " act)
}
if this.config.preferences["Mode"] = "Story" && Integer(this.config.preferences["Act"]) >= 5 {
act := Integer(this.config.preferences["Act"])
if !this.ScrollStages("Down", 1)
return false
return this.ClickStep(330, act = 5 ? 340 : 382, "Act " act)
}
infinite := this.config.preferences["Mode"] = "Infinite"
act := Integer(this.config.preferences["Act"])
return this.ClickStep(330, infinite ? 229 : 270 + (act - 1) * 42,
infinite ? "Infinite" : "Act " act)
}
VerifyReady() {
this.readyTaskIdentity := ""
identity := this.TaskIdentity()
deadline := CrusadersRuntime.Now() + 10000
frames := 0
loop {
if !this.Check()
throw Error("Ready verification cancelled; Start not clicked.")
matched := this.ReadReadyTaskMatches()
if identity != this.TaskIdentity()
throw Error("Selection changed during verification; Start not clicked.")
frames := matched ? frames + 1 : 0
if frames >= 2 {
this.readyTaskIdentity := identity
CrusadersLog("Lobby selection verified: " this.TaskLabel())
return
}
if CrusadersRuntime.Now() >= deadline
throw Error("Ready screen does not match " this.TaskLabel() "; Start not clicked.")
if !this.Wait(100)
throw Error("Ready verification cancelled; Start not clicked.")
}
}
ReadReadyTaskMatches() {
bitmap := this.Snapshot()
try {
text := (this.config.preferences["Mode"] = "Boss Rush" || this.config.preferences["Mode"] = "Event")
? this.Text(bitmap, 24, 189, 215, 156) : this.Text(bitmap, 24, 189, 215, 78)
return this.MatchesTask(text)
} finally Gdip_DisposeImage(bitmap)
}
VerifySelection() {
bitmap := this.Snapshot()
try {
text := this.Text(bitmap, 394, 211, 290, 47)
if !this.MatchesStage(text)
throw Error("Map/act selection could not be verified; Select not clicked. Read: " StrReplace(text, "`n", " / "))
} finally Gdip_DisposeImage(bitmap)
}
TaskIdentity() {
preferences := this.config.preferences
return preferences["Mode"] "|" preferences["Map"] "|" Integer(preferences["Act"]) "|"
. preferences["Difficulty"] "|" preferences["BossRushMode"]
}
StartVerifiedSelection() {
this.submittedTaskIdentity := ""
this.VerifyReady()
return this.SubmitReadySelection()
}
SubmitReadySelection() {
this.submittedTaskIdentity := ""
if !this.HasOwnProp("readyTaskIdentity") || this.readyTaskIdentity != this.TaskIdentity()
throw Error("Selection changed before joining; Start not clicked.")
if !this.ClickStep(400, 493, "Start")
return false
this.submittedTaskIdentity := this.readyTaskIdentity
return true
}
HasVerifiedSubmission() {
return this.HasOwnProp("submittedTaskIdentity") && this.submittedTaskIdentity = this.TaskIdentity()
}
TeleportMatchesTask() {
bitmap := this.Snapshot()
try {
if !RegExMatch(this.Text(bitmap, 342, 375, 125, 28), "i)Teleporting\s+To")
return false
return this.MatchesTask(this.Text(bitmap, 300, 398, 214, 78))
} finally Gdip_DisposeImage(bitmap)
}
StartVoteVisible(&x, &y) => FindCrusadersStart(&x, &y)
MatchHudContradicts(text) {
preferences := this.config.preferences
mode := preferences["Mode"]
if RegExMatch(text, "i)\bLegend\s*Stag[e3]\s*(\d+)\b", &match)
return mode != "Legend Stages" || Integer(match[1]) != Integer(preferences["Act"])
if RegExMatch(text, "i)\bAct\s*(\d+)\b", &match)
return mode != "Challenges" && (mode != "Story" || Integer(match[1]) != Integer(preferences["Act"]))
if RegExMatch(text, "i)\bInfinite\s*Mode\b")
return mode != "Infinite" && mode != "Challenges"
return false
}
ReadMatchHud() {
bitmap := this.Snapshot()
try return this.Text(bitmap, 640, 230, 160, 43)
finally Gdip_DisposeImage(bitmap)
}
WaitMatch() {
deadline := CrusadersRuntime.Now() + 120000
teleportConfirmed := false
startStability := CrusadersStartStability()
wrongHudFrames := 0
loop {
if !this.Check()
return false
if this.config.preferences["Mode"] = "Boss Rush" && this.config.preferences["Map"] = "Makima"
if !this.HandleMakimaCards()
return false
if !teleportConfirmed && !this.HasVerifiedSubmission() && this.TeleportMatchesTask() {
teleportConfirmed := true
CrusadersLog("Teleport map detected: " this.TaskLabel())
}
found := this.StartVoteVisible(&x, &y)
if startStability.Observe(found, found ? x : 0, found ? y : 0, CrusadersRuntime.Now()) {
if this.config.preferences["Mode"] = "Boss Rush" {
if !this.PrepareBossMatch()
return false
} else if this.config.preferences["Mode"] = "Event" {
if !this.hunter.VerifyMatch()
return false
}
else if !teleportConfirmed && !this.HasVerifiedSubmission()
throw Error("Match loaded, but teleport map/act/difficulty were not verified; vote not clicked.")
else {
wrongHudFrames := this.MatchHudContradicts(this.ReadMatchHud()) ? wrongHudFrames + 1 : 0
if wrongHudFrames >= 2
throw Error("Match stage does not match the selected mode or act; vote not clicked.")
if wrongHudFrames {
if !this.Wait(100)
return false
continue
}
}
CrusadersLog("Match entry confirmed: Start vote detected")
return true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Match entry timed out; vote not clicked.")
if !this.Wait(100)
return false
}
}
Join(state, waitForInstance := true) {
this.submittedTaskIdentity := ""
preferences := this.config.preferences
if state = "Lobby" && Integer(preferences["Team"]) {
if waitForInstance && !this.Wait(5000)
return false
if !CrusadersTeams(this).Load(preferences["Team"])
return false
waitForInstance := false
}
if preferences["Mode"] = "Event"
return this.hunter.Join(state, waitForInstance)
if preferences["Mode"] = "Boss Rush"
return this.JoinBoss(state, waitForInstance)
legend := preferences["Mode"] = "Legend Stages"
raid := preferences["Mode"] = "Raids"
profiles := this.MapProfiles()
if (!legend && !raid && preferences["Mode"] != "Story" && preferences["Mode"] != "Infinite") || !profiles.Has(preferences["Map"])
throw Error("This map or mode is not connected for lobby joining yet.")
if Integer(preferences["Act"]) < 1 || Integer(preferences["Act"]) > CrusadersCatalog.ActCount(preferences["Mode"], preferences["Map"])
throw Error("Invalid stage for " preferences["Map"] "; no selection clicks sent.")
if state = "Lobby" {
CrusadersLog(waitForInstance ? "Lobby detected; waiting 5 seconds before joining" : "Lobby detected; using current session")
if waitForInstance && !this.Wait(5000)
return false
if !this.ClickStep(91, 292, "Play", 0)
return false
CrusadersLog("Lobby: waiting 1000 ms after Play")
if !this.Wait(1000)
return false
state := "ModeMenu"
}
if state = "ModeMenu" {
if !this.ClickStep(raid ? 168 : 400, 260, raid ? "Raids" : "Story") || !this.WaitState("Lobby") || !this.Wait(500)
return false
if !this.route.Test(this.shouldStop)
return false
state := "StageMenu"
}
if state = "StageMenu" {
if !this.WaitState("StageMenu")
return false
if legend && !this.ClickStep(602, 189, "Legend Stages")
return false
if !this.SelectMap() || !this.SelectStage()
return false
if CrusadersCatalog.HasDifficultySelection(preferences["Mode"], preferences["Map"]) {
difficultyX := preferences["Difficulty"] = "Hard" ? 479 : 427
if !this.ClickStep(difficultyX, 352, preferences["Difficulty"])
return false
}
this.VerifySelection()
if !this.ClickTransition(588, 437, "Select", "StageMenu", "Matchmaking")
return false
state := "Matchmaking"
}
if state = "Matchmaking" {
if !this.ClickTransition(328, 318, "Play Here", "Matchmaking", "Ready")
return false
state := "Ready"
}
if state != "Ready"
throw Error("Unrecognized lobby join state; no Start click sent.")
if !this.StartVerifiedSelection()
return false
return this.WaitMatch()
}
TraitsBitmap(bitmap) {
if !RegExMatch(this.Text(bitmap, 215, 144, 145, 40), "i)Boss\s*Rush")
return ""
text := this.Text(bitmap, 495, 372, 157, 38)
if RegExMatch(text, "i)Traits\s*Enabled")
return "Traits"
if RegExMatch(text, "i)Traits\s*Disabled")
return "Traitless"
return ""
}
SelectTraits() {
wanted := this.config.preferences["BossRushMode"]
toggled := false
frames := 0
deadline := CrusadersRuntime.Now() + 8000
loop {
if !this.Check()
return false
bitmap := this.Snapshot()
try current := this.TraitsBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
frames := current = wanted ? frames + 1 : 0
if frames >= 2 {
CrusadersLog("Boss Rush mode verified: " wanted)
return true
}
if current != "" && current != wanted && !toggled {
if !this.ClickStep(464, 389, wanted)
return false
toggled := true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Boss Rush traits mode not confirmed; Play not clicked.")
if !this.Wait(100)
return false
}
}
VerifyBossMatch() {
bitmap := this.Snapshot()
try {
text := this.Text(bitmap, 660, 238, 140, 29)
if !this.MatchesStage(text)
throw Error(this.config.preferences["Map"] " match label not verified; vote not clicked. Read: " text)
CrusadersLog("Match map confirmed: " this.TaskLabel())
} finally Gdip_DisposeImage(bitmap)
}
JoinBoss(state, waitForInstance) {
makima := this.config.preferences["Map"] = "Makima"
if !CrusadersLobby.BossStages.Has(this.config.preferences["Map"])
throw Error("Unknown Boss Rush; no joining inputs sent.")
if state = "Lobby" {
if waitForInstance && !this.Wait(5000)
return false
if makima {
if !this.ClickStep(91, 292, "Play", 0) || !this.Wait(1000)
return false
state := "ModeMenu"
} else {
if !this.ClickStep(774, 466, "Areas") || !this.WaitState("Areas")
return false
state := "Areas"
}
}
if state = "ModeMenu" && makima {
if !this.ClickStep(400, 260, "Story") || !this.WaitState("Lobby") || !this.Wait(500)
return false
if !this.route.Test(this.shouldStop)
return false
state := "BossNpc"
}
if state = "Areas" {
if !this.ClickStep(470, 281, "Leaderboards") || !this.WaitState("Lobby") || !this.Wait(500)
return false
if !this.route.Test(this.shouldStop)
return false
state := "BossNpc"
}
if state = "BossNpc" {
if !this.WaitState("BossNpc") || !this.ClickTransition(406, 493, makima ? "Continue" : "Open Boss Rush", "BossNpc", "BossMenu")
return false
state := "BossMenu"
}
if state = "BossMenu" {
if !this.SelectTraits() || !this.ClickTransition(330, 438, "Play", "BossMenu", "Matchmaking")
return false
state := "Matchmaking"
}
if state = "Matchmaking" {
if !this.ClickTransition(328, 318, "Play Here", "Matchmaking", "Ready")
return false
state := "Ready"
}
if state != "Ready"
throw Error("Unrecognized Boss Rush join state; no Start click sent.")
if !this.StartVerifiedSelection()
return false
return this.WaitMatch()
}
CardsBitmap(bitmap) {
return RegExMatch(this.Text(bitmap, 200, 272, 125, 42), "i)Unit\s*Slot")
&& RegExMatch(this.Text(bitmap, 340, 272, 120, 42), "i)Damage")
&& RegExMatch(this.Text(bitmap, 478, 272, 127, 42), "i)Placement\s*Limit")
}
PrepareBossMatch() {
if this.config.preferences["Map"] = "Makima" && !this.SelectMakimaCard()
return false
this.VerifyBossMatch()
return true
}
HandleMakimaCards() {
if !this.Check()
return false
bitmap := this.Snapshot()
try visible := this.CardsBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
return !visible || this.SelectMakimaCard()
}
SelectMakimaCard() {
positions := Map("Unit Slot", 260, "Damage", 400, "Placement Limit", 540)
wanted := this.config.preferences["MakimaCard"]
if !positions.Has(wanted)
throw Error("Invalid Makima card; no card click sent.")
deadline := CrusadersRuntime.Now() + 10000
visibleFrames := absentFrames := 0
clicked := false
if !this.Wait(500)
return false
loop {
if !this.Check()
return false
bitmap := this.Snapshot()
try visible := this.CardsBitmap(bitmap)
finally Gdip_DisposeImage(bitmap)
visibleFrames := visible ? visibleFrames + 1 : 0
absentFrames := !visible ? absentFrames + 1 : 0
if visibleFrames >= 2 && !clicked {
if !this.ClickStep(positions[wanted], 340, "Makima card: " wanted)
return false
clicked := true
absentFrames := 0
}
if absentFrames >= 2 {
if clicked
CrusadersLog("Makima card selection confirmed: " wanted " / overlay closed")
return true
}
if CrusadersRuntime.Now() >= deadline
throw Error("Makima cards did not close; zoom/start not sent.")
if !this.Wait(100)
return false
}
}
}
class ComVar extends Buffer {
static Call(vVal := 0, vType := 0xC, convert := false) {
static size := 8 + 2 * A_PtrSize
if vVal is ComVar
return vVal
var := super(size, 0), IsObject(vVal) && vType := 0xC
var.ref := ref := ComValue(0x4000 | vType, var.Ptr + (vType = 0xC ? 0 : 8))
if convert && (vVal is Array) {
switch Type(vVal[1]) {
case "Integer": vType := 3
case "String": vType := 8
case "Float": vType := 5
case "ComValue", "ComObject": vType := ComObjType(vVal[1])
default: vType := 0xC
}
ComObjFlags(ref[] := obj := ComObjArray(vType, vVal.Length), i := -1)
for v in vVal
obj[++i] := v
} else ref[] := vVal
if vType & 0xC
var.IsVariant := 1
return var
}
__Delete() => DllCall("oleaut32\VariantClear", "ptr", this)
__Item {
get => this.ref[]
set => this.ref[] := Value
}
Type {
get => NumGet(this, "ushort")
set {
if (!this.IsVariant)
throw PropertyError("VarType is not VT_VARIANT, Type is read-only.", -2)
NumPut("ushort", Value, this)
}
}
static Prototype.IsVariant := 0
static Prototype.ref := 0
}
class Promise {
static Prototype.status := 'pending'
static Prototype.result := ''
static Prototype.thrown := false
__New(executor) {
this.callbacks := []
try
(executor.MaxParams = 1) ? executor(resolve) : executor(resolve, reject)
catch Any as e
reject(e)
resolve(value := '') {
if value is Promise {
if !ObjHasOwnProp(value, 'status') {
if this !== value
return value.onCompleted(resolve)
this.status := 'rejected', this.result := ValueError('Chaining cycle detected for promise', -1)
} else if this
this.status := value.status, this.result := value.result
else return
} else if this
this.status := 'fulfilled', this.result := value
else return
SetTimer(task.Bind(this), -1), this := 0
}
reject(reason?) {
if !this
return
this.status := 'rejected', this.result := reason ?? Error(, -1)
SetTimer(task.Bind(this), -1), this := 0
}
static task(this) {
for cb in this.DeleteProp('callbacks')
cb(this)
else if !ObjHasOwnProp(this, 'thrown') && this.status == 'rejected' && this.thrown := true
throw this.result
}
}
onCompleted(callback) {
ObjHasOwnProp(this, 'callbacks') ? this.callbacks.Push(callback) : nextTick(this, callback)
static nextTick(this, callback) => SetTimer(() => callback(this), -1)
}
onSettled(onfulfilled, onrejected := Promise.throw) {
this.onCompleted(val => (val.status == 'fulfilled' ? onfulfilled : onrejected)(val.result))
}
then(onfulfilled, onrejected := Promise.throw) {
return Promise(executor)
executor(resolve, reject) {
this.onCompleted(task)
task(p1) {
try
resolve((p1.status == 'fulfilled' ? onfulfilled : onrejected)(p1.result))
catch Any as e
reject(e)
}
}
}
catch(onrejected) => this.then(val => val, onrejected)
finally(onfinally) => this.then(
val => (onfinally(), val),
err => (onfinally(), (Promise.throw)(err))
)
await2(timeout := -1) {
end := A_TickCount + timeout, old := Critical(0)
while (pending := !ObjHasOwnProp(this, 'status')) && (timeout < 0 || A_TickCount < end)
Sleep(1)
Critical(old)
if !pending && this.status == 'fulfilled'
return this.result
throw pending ? TimeoutError() : (this.thrown := true) && this.result
}
await(timeout := -1) {
static hEvent := DllCall('CreateEvent', 'ptr', 0, 'int', 1, 'int', 0, 'ptr', 0, 'ptr')
static __del := { Ptr: hEvent, __Delete: this => DllCall('CloseHandle', 'ptr', this) }
static msg := Buffer(4 * A_PtrSize + 16)
t := A_TickCount, r := 258, old := Critical(0)
while (pending := !ObjHasOwnProp(this, 'status')) && timeout &&
(DllCall('PeekMessage', 'ptr', msg, 'ptr', 0, 'uint', 0, 'uint', 0, 'uint', 0) ||
1 == r := DllCall('MsgWaitForMultipleObjects', 'uint', 1, 'ptr*', hEvent,
'int', 0, 'uint', timeout, 'uint', 7423, 'uint'))
Sleep(-1), (timeout < 0) || timeout := Max(timeout - A_TickCount + t, 0)
Critical(old)
if !pending && this.status == 'fulfilled'
return this.result
throw pending ? r == 0xffffffff ? OSError() : TimeoutError() : (this.thrown := true) && this.result
}
static throw() {
throw this
}
static resolve(value) => { base: this.Prototype, result: value, status: 'fulfilled' }
static reject(reason) => Promise((_, reject) => reject(reason))
static all(promises) {
return Promise(executor)
executor(resolve, reject) {
res := [], count := res.Length := promises.Length
resolve2 := (index, val) => (res[index] := val, !--count && resolve(res))
for val in promises {
if val is Promise
val.onSettled(resolve2.Bind(A_Index), reject)
else resolve2(A_Index, val)
} else resolve(res)
}
}
static allSettled(promises) {
return Promise(executor)
executor(resolve, reject) {
res := [], count := res.Length := promises.Length
callback := (index, val) => (res[index] := { result: val.result, status: val.status }, !--count && resolve(res))
for val in promises {
if val is Promise
val.onCompleted(callback.Bind(A_Index))
else res[A_Index] := { result: val, status: 'fulfilled' }, !--count && resolve(res)
} else resolve(res)
}
}
static any(promises) {
return Promise(executor)
executor(resolve, reject) {
errs := [], count := errs.Length := promises.Length
reject2 := (index, err) => (errs[index] := err, !--count && (
err := Error('All promises were rejected'), err.errors := errs, reject(err)))
for val in promises
val.onSettled(resolve, reject2.Bind(A_Index))
}
}
static race(promises) {
return Promise(executor)
executor(resolve, reject) {
for val in promises
if val is Promise
val.onSettled(resolve, reject)
else return resolve(val)
}
}
static try(fn) {
try {
val := fn()
return Promise.resolve(val)
} catch Any as e
return Promise.reject(e)
}
static withResolvers() {
local resolvers := 0
resolvers.promise := Promise((resolve, reject) => resolvers := { resolve: resolve, reject: reject })
return resolvers
}
}
Jxon_Load(&src, args*) {
key := "", is_key := false
stack := [ tree := [] ]
next := '"{[01234567890-tfn'
pos := 0
while ( (ch := SubStr(src, ++pos, 1)) != "" ) {
if InStr(" `t`n`r", ch)
continue
if !InStr(next, ch, true) {
testArr := StrSplit(SubStr(src, 1, pos), "`n")
ln := testArr.Length
col := pos - InStr(src, "`n",, -(StrLen(src)-pos+1))
msg := Format("{}: line {} col {} (char {})"
,   (next == "")      ? ["Extra data", ch := SubStr(src, pos)][1]
: (next == "'")     ? "Unterminated string starting at"
: (next == "\")     ? "Invalid \escape"
: (next == ":")     ? "Expecting ':' delimiter"
: (next == '"')     ? "Expecting object key enclosed in double quotes"
: (next == '"}')    ? "Expecting object key enclosed in double quotes or object closing '}'"
: (next == ",}")    ? "Expecting ',' delimiter or object closing '}'"
: (next == ",]")    ? "Expecting ',' delimiter or array closing ']'"
: [ "Expecting JSON value(string, number, [true, false, null], object or array)"
, ch := SubStr(src, pos, (SubStr(src, pos)~="[\]\},\s]|$")-1) ][1]
, ln, col, pos)
throw Error(msg, -1, ch)
}
obj := stack[1]
is_array := (obj is Array)
if i := InStr("{[", ch) {
val := (i = 1) ? Map() : Array()
is_array ? obj.Push(val) : obj[key] := val
stack.InsertAt(1,val)
next := '"' ((is_key := (ch == "{")) ? "}" : "{[]0123456789-tfn")
} else if InStr("}]", ch) {
stack.RemoveAt(1)
next := (stack[1]==tree) ? "" : (stack[1] is Array) ? ",]" : ",}"
} else if InStr(",:", ch) {
is_key := (!is_array && ch == ",")
next := is_key ? '"' : '"{[0123456789-tfn'
} else {
if (ch == '"') {
i := pos
while i := InStr(src, '"',, i+1) {
val := StrReplace(SubStr(src, pos+1, i-pos-1), "\\", "\u005C")
if (SubStr(val, -1) != "\")
break
}
if !i ? (pos--, next := "'") : 0
continue
pos := i
val := StrReplace(val, "\/", "/")
val := StrReplace(val, '\"', '"')
, val := StrReplace(val, "\b", "`b")
, val := StrReplace(val, "\f", "`f")
, val := StrReplace(val, "\n", "`n")
, val := StrReplace(val, "\r", "`r")
, val := StrReplace(val, "\t", "`t")
i := 0
while i := InStr(val, "\",, i+1) {
if (SubStr(val, i+1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
continue 2
xxxx := Abs("0x" . SubStr(val, i+2, 4))
if (xxxx < 0x100)
val := SubStr(val, 1, i-1) . Chr(xxxx) . SubStr(val, i+6)
}
if is_key {
key := val, next := ":"
continue
}
} else {
val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos)-pos)
if IsInteger(val)
val += 0
else if IsFloat(val)
val += 0
else if (val == "true" || val == "false")
val := (val == "true")
else if (val == "null")
val := ""
else if is_key {
pos--, next := "#"
continue
}
pos += i-1
}
is_array ? obj.Push(val) : obj[key] := val
next := obj == tree ? "" : is_array ? ",]" : ",}"
}
}
return tree[1]
}
Jxon_Dump(obj, indent:="", lvl:=1) {
if obj is ComValue && ComObjType(obj) = 11
return ComObjValue(obj) ? "true" : "false"
if IsObject(obj) {
If !(obj is Array || obj is Map || obj is String || obj is Number)
throw Error("Object type not supported.", -1, Format("<Object at 0x{:p}>", ObjPtr(obj)))
if IsInteger(indent)
{
if (indent < 0)
throw Error("Indent parameter must be a postive integer.", -1, indent)
spaces := indent, indent := ""
Loop spaces
indent .= " "
}
indt := ""
Loop indent ? lvl : 0
indt .= indent
is_array := (obj is Array)
lvl += 1, out := ""
for k, v in obj {
if IsObject(k) || (k == "")
throw Error("Invalid object key.", -1, k ? Format("<Object at 0x{:p}>", ObjPtr(obj)) : "<blank>")
if !is_array
out .= (ObjGetCapacity([k]) ? Jxon_Dump(k) : escape_str(k)) (indent ? ": " : ":")
out .= Jxon_Dump(v, indent, lvl)
.  ( indent ? ",`n" . indt : "," )
}
if (out != "") {
out := Trim(out, ",`n" . indent)
if (indent != "")
out := "`n" . indt . out . "`n" . SubStr(indt, StrLen(indent)+1)
}
return is_array ? "[" . out . "]" : "{" . out . "}"
} Else If (obj is Number)
return obj
Else
return escape_str(obj)
escape_str(obj) {
obj := StrReplace(obj,"\","\\")
obj := StrReplace(obj,"`t","\t")
obj := StrReplace(obj,"`r","\r")
obj := StrReplace(obj,"`n","\n")
obj := StrReplace(obj,"`b","\b")
obj := StrReplace(obj,"`f","\f")
obj := StrReplace(obj,"/","\/")
obj := StrReplace(obj,'"','\"')
return '"' obj '"'
}
}
class WebView2 {
static create(hwnd := -3, callback?, createdEnvironment := 0, dataDir := '', edgeRuntime := '', options := 0, dllPathOrFuncPtr := 'WebView2Loader.dll') {
p := createdEnvironment ? createdEnvironment.CreateCoreWebView2ControllerAsync(hwnd) :
this.CreateControllerAsync(hwnd, options, dataDir, edgeRuntime, dllPathOrFuncPtr)
if !IsSet(callback)
return p.await()
p.then(callback)
}
static CreateControllerAsync(hwnd := -3, options := 0, dataDir := '', edgeRuntime := '', dllPathOrFuncPtr := 'WebView2Loader.dll') {
return this.CreateEnvironmentAsync(options, dataDir, edgeRuntime, dllPathOrFuncPtr)
.then(r => r.CreateCoreWebView2ControllerAsync(hwnd))
}
static CreateEnvironmentAsync(options := 0, dataDir := '', edgeRuntime := '', dllPathOrFuncPtr := 'WebView2Loader.dll') {
if !(dllPathOrFuncPtr is Integer) {
if !FileExist(dllPathOrFuncPtr)
throw Error('WebView2 loader is missing: ' dllPathOrFuncPtr)
dllPathOrFuncPtr .= '\CreateCoreWebView2EnvironmentWithOptions'
}
if !edgeRuntime {
ver := '0.2.0.0'
for root in [EnvGet('ProgramFiles(x86)'), A_AppData '\..\Local']
loop files root '\Microsoft\EdgeWebView\Application\*', 'D'
if RegExMatch(A_LoopFilePath, '\\([\d.]+)$', &m) && VerCompare(m[1], ver) > 0
edgeRuntime := A_LoopFileFullPath, ver := m[1]
}
if options && !(options is this.EnvironmentOptions) {
if !options.HasOwnProp('TargetCompatibleBrowserVersion')
options.TargetCompatibleBrowserVersion := ver
options := this.EnvironmentOptions(options)
}
DllCall(dllPathOrFuncPtr, 'str', edgeRuntime,
'str', dataDir || RegExReplace(A_AppData, 'Roaming$', 'Local\Microsoft\Edge\User Data'), 'ptr', options,
'ptr', this.AsyncHandler(&p, this.Environment), 'hresult')
return p
}
static CreateFileStream(filePath, mode := 'r') {
DllCall('shlwapi\SHCreateStreamOnFileEx', 'wstr', filePath, 'uint',
InStr(mode, 'w') && (!InStr(mode, 'r') || !FileExist(filePath) ? 0x1002 : 2),
'uint', 128, 'int', 0, 'ptr', 0, 'ptr*', s := this.Stream(), 'hresult')
return s
}
static CreateMemStream(ptr := 0, size := 0) {
(s := this.Stream()).Ptr := DllCall('shlwapi\SHCreateMemStream', 'ptr', ptr,
'uint', size || ptr && ptr.Size, 'ptr')
return s
}
static CreateTextStream(text, encoding := 'utf-8') {
if encoding = 'utf-16'
return this.CreateMemStream(StrPtr(text), StrLen(text) << 1)
StrPut(text, buf := Buffer(StrPut(text, encoding) - 1), encoding)
return this.CreateMemStream(buf)
}
static AsyncHandler(&p, wrapper := 0) {
p := Promise(executor.Bind(&ret, wrapper))
return ret
static executor(&ret, type, resolve, reject) {
(ret := WebView2.Handler(handler, 3 - !type)).reject := reject
ret.resolve := type && type !== Integer ? r => resolve(type(r)) : resolve
}
static handler(this, err, result := '') {
this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
if err && (!result || err !== 0x80070057)
(this.reject)(OSError(err))
else
(this.resolve)(result)
}
}
static TypedHandler(invoke, cls, ea := 0) {
e := WebView2.Handler(handler)
e.invoke := invoke, e.cls := cls, e.ea := ea || v => v
return e
static handler(this, sender, args) {
this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
(this.invoke)((this.cls)(sender), (this.ea)(args))
}
}
class Base {
static Prototype.Ptr := 0
static DefaultIID {
set {
this.Prototype.DefineProp('Ptr', { set: QueryInterface })
QueryInterface(this, ptr) {
if !ptr
return
obj := ComObjQuery(ptr, Value)
if ptr !== nptr := ComObjValue(obj)
ObjRelease(ptr), ObjAddRef(ptr := nptr)
this.DefineProp('Ptr', { value: ptr })
}
}
}
static __New() {
pthis := ObjPtr(this)
for k in (proto := this.Prototype).OwnProps() {
if SubStr(k, 1, 4) !== 'add_'
continue
if ObjHasOwnProp(WebView2, ea := SubStr(k, 5) 'EventArgs') ||
ObjHasOwnProp(WebView2, ea := StrReplace(ea, 'Frame'))
ea := WebView2.%ea%
else ea := 0
proto.DefineProp(k, { call: add_handler.Bind(proto.%k%, pthis, ea) })
}
static add_handler(method, pcls, ea, this, handler) {
if !IsInteger(handler) && !(handler is WebView2.Handler) {
if !HasMethod(handler, , 2)
throw TypeError('Handler function requires 2 parameters.')
handler := WebView2.TypedHandler(handler, ObjFromPtrAddRef(pcls), ea)
}
return method(this, handler)
}
}
__New(ptr := 0) => ptr && (ObjAddRef(ptr), this.Ptr := ptr)
__Delete() => (ptr := this.ptr) && ObjRelease(ptr)
__Call(Name, Params) {
if HasMethod(this, Name 'Async')
return this.%Name%Async(Params*).await()
if HasMethod(this, 'add_' Name)
return { ptr: this.ptr, __Delete: this.remove_%Name%.Bind(, this.add_%Name%(Params[1])) }
throw MethodError('This value of type "' this.__Class '" has no method named "' Name '".', -1)
}
as(cls, iid?) {
ptr := ComObjValue(obj := ComObjQuery(this, iid ?? cls.IID))
if ptr == this.Ptr
ObjSetBase(this, cls.Prototype)
else if this is cls
ObjRelease(this.Ptr), ObjAddRef(this.Ptr := ptr)
else return cls(ptr)
return this
}
unique() {
static caches := Map()
if ptr := caches.Get(this.Ptr, 0)
return ObjFromPtrAddRef(ptr)
if ptr := this.Ptr {
caches[ptr] := ObjPtr(this)
cache := { Ptr: ptr, __Delete: this => caches.Delete(this.Ptr) }
this.DefineProp('unique', { call: (this) => (cache, this) })
}
return this
}
}
class List extends WebView2.Base {
__Item[index] => this.GetValueAtIndex(index)
__Enum(n) {
if n = 1
return (n := this.Count, i := 0, (&v) => i < n ? (v := this.GetValueAtIndex(i++), true) : false)
return (n := this.Count, i := 0, (&k, &v, *) => i < n ? (v := this.GetValueAtIndex(k := i++), true) : false)
}
}
class AcceleratorKeyPressedEventArgs extends WebView2.Base {
static IID := '{9f760f8a-fb79-42be-9990-7b56900fa9c7}'
KeyEventKind => (ComCall(3, this, 'int*', &keyEventKind := 0), keyEventKind)
VirtualKey => (ComCall(4, this, 'uint*', &virtualKey := 0), virtualKey)
KeyEventLParam => (ComCall(5, this, 'int*', &lParam := 0), lParam)
PhysicalKeyStatus => (ComCall(6, this, 'ptr*', physicalKeyStatus := WebView2.PHYSICAL_KEY_STATUS()), physicalKeyStatus)
Handled {
get => (ComCall(7, this, 'int*', &handled := 0), handled)
set => ComCall(8, this, 'int', Value)
}
static IID_2 := '{03b2c8c8-7799-4e34-bd66-ed26aa85f2bf}'
IsBrowserAcceleratorKeyEnabled {
get => (ComCall(9, this, 'int*', &value := 0), value)
set => ComCall(10, this, 'int', Value)
}
}
class BasicAuthenticationRequestedEventArgs extends WebView2.Base {
static IID := '{ef05516f-d897-4f9e-b672-d8e2307a3fb0}'
Uri => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Challenge => (ComCall(4, this, 'ptr*', &challenge := 0), CoTaskMem_String(challenge))
Response => (ComCall(5, this, 'ptr*', response := WebView2.BasicAuthenticationResponse()), response)
Cancel {
get => (ComCall(6, this, 'int*', &cancel := 0), cancel)
set => ComCall(7, this, 'int', Value)
}
GetDeferral() => (ComCall(8, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class BasicAuthenticationResponse extends WebView2.Base {
UserName {
get => (ComCall(3, this, 'ptr*', &userName := 0), CoTaskMem_String(userName))
set => ComCall(4, this, 'wstr', Value)
}
Password {
get => (ComCall(5, this, 'ptr*', &password := 0), CoTaskMem_String(password))
set => ComCall(6, this, 'wstr', Value)
}
}
class BrowserExtension extends WebView2.Base {
static IID := '{7EF7FFA0-FAC5-462C-B189-3D9EDBE575DA}'
Id => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Name => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
RemoveAsync() => (ComCall(5, this, 'ptr', WebView2.AsyncHandler(&p)), p)
IsEnabled => (ComCall(6, this, 'int*', &value := 0), value)
EnableAsync(isEnabled) => (ComCall(7, this, 'int', isEnabled, 'ptr', WebView2.AsyncHandler(&p)), p)
}
class BrowserExtensionList extends WebView2.List {
static IID := '{2EF3D2DC-BD5F-4F4D-90AF-FD67798F0C2F}'
Count => (ComCall(3, this, 'uint*', &count := 0), count)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', extension := WebView2.BrowserExtension()), extension)
}
class BrowserProcessExitedEventArgs extends WebView2.Base {
static IID := '{1f00663f-af8c-4782-9cdd-dd01c52e34cb}'
BrowserProcessExitKind => (ComCall(3, this, 'int*', &browserProcessExitKind := 0), browserProcessExitKind)
BrowserProcessId => (ComCall(4, this, 'uint*', &value := 0), value)
}
class Certificate extends WebView2.Base {
static IID := '{C5FB2FCE-1CAC-4AEE-9C79-5ED0362EAAE0}'
Subject => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Issuer => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ValidFrom => (ComCall(5, this, 'double*', &value := 0), value)
ValidTo => (ComCall(6, this, 'double*', &value := 0), value)
DerEncodedSerialNumber => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
DisplayName => (ComCall(8, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ToPemEncoding() => (ComCall(9, this, 'ptr*', &pemEncodedData := 0), CoTaskMem_String(pemEncodedData))
PemEncodedIssuerCertificateChain => (ComCall(10, this, 'ptr*', value := WebView2.StringCollection()), value)
}
class CompositionController extends WebView2.Base {
static IID := '{3df9b733-b9ae-4a15-86b4-eb9ee9826469}'
RootVisualTarget {
get => (ComCall(3, this, 'ptr*', &target := 0), ComValue(0xd, target))
set => ComCall(4, this, 'ptr', Value)
}
SendMouseInput(eventKind, virtualKeys, mouseData, point) => ComCall(5, this, 'int', eventKind, 'int', virtualKeys, 'uint', mouseData, 'int64', point)
SendPointerInput(eventKind, pointerInfo) => ComCall(6, this, 'int', eventKind, 'ptr', pointerInfo)
Cursor => (ComCall(7, this, 'ptr*', &cursor := 0), cursor)
SystemCursorId => (ComCall(8, this, 'uint*', &systemCursorId := 0), systemCursorId)
add_CursorChanged(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_CursorChanged(token) => ComCall(10, this, 'int64', token)
static IID_2 := '{0b6a3d24-49cb-4806-ba20-b5e0734a7b26}'
AutomationProvider => (ComCall(11, this, 'ptr*', &provider := 0), ComValue(0xd, provider))
static IID_3 := '{9570570e-4d76-4361-9ee1-f04d0dbdfb1e}'
DragEnter(dataObject, keyState, point, peffect) => ComCall(12, this, 'ptr', dataObject, 'uint', keyState, 'int64', point, 'ptr', peffect)
DragLeave() => ComCall(13, this)
DragOver(keyState, point, peffect) => ComCall(14, this, 'uint', keyState, 'int64', point, 'ptr', peffect)
Drop(dataObject, keyState, point, peffect) => ComCall(15, this, 'ptr', dataObject, 'uint', keyState, 'int64', point, 'ptr', peffect)
static IID_4 := '{7C367B9B-3D2B-450F-9E58-D61A20F486AA}'
GetNonClientRegionAtPoint(point) => (ComCall(16, this, 'int64', point, 'int*', &value := 0), value)
QueryNonClientRegion(kind) => (ComCall(17, this, 'int', kind, 'ptr*', rects := WebView2.RegionRectCollectionView()), rects)
add_NonClientRegionChanged(eventHandler) => (ComCall(18, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NonClientRegionChanged(token) => ComCall(19, this, 'int64', token)
}
class Controller extends WebView2.Base {
static IID := '{4d00c0d1-9434-4eb6-8078-8697a560334f}'
Fill() {
if !this.ptr
return
DllCall('user32\GetClientRect', 'ptr', this.ParentWindow, 'ptr', RECT := Buffer(16))
this.Bounds := RECT
return this
}
IsVisible {
get => (ComCall(3, this, 'int*', &isVisible := 0), isVisible)
set => ComCall(4, this, 'int', Value)
}
Bounds {
get => (ComCall(5, this, 'ptr', bounds := WebView2.RECT()), bounds)
set => A_PtrSize = 8 ? ComCall(6, this, 'ptr', Value) : ComCall(6, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64'))
}
ZoomFactor {
get => (ComCall(7, this, 'double*', &zoomFactor := 0), zoomFactor)
set => ComCall(8, this, 'double', Value)
}
add_ZoomFactorChanged(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ZoomFactorChanged(token) => ComCall(10, this, 'int64', token)
SetBoundsAndZoomFactor(bounds, zoomFactor) => (A_PtrSize = 8 ? ComCall(11, this, 'ptr', bounds, 'double', zoomFactor) : ComCall(11, this, 'int64', NumGet(bounds, 'int64'), 'int64', NumGet(bounds, 8, 'int64'), 'double', zoomFactor))
MoveFocus(reason) => ComCall(12, this, 'int', reason)
add_MoveFocusRequested(eventHandler) => (ComCall(13, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_MoveFocusRequested(token) => ComCall(14, this, 'int64', token)
add_GotFocus(eventHandler) => (ComCall(15, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_GotFocus(token) => ComCall(16, this, 'int64', token)
add_LostFocus(eventHandler) => (ComCall(17, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_LostFocus(token) => ComCall(18, this, 'int64', token)
add_AcceleratorKeyPressed(eventHandler) => (ComCall(19, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_AcceleratorKeyPressed(token) => ComCall(20, this, 'int64', token)
ParentWindow {
get => (ComCall(21, this, 'ptr*', &parentWindow := 0), parentWindow)
set => ComCall(22, this, 'ptr', Value)
}
NotifyParentWindowPositionChanged() => ComCall(23, this)
Close() => ComCall(24, this)
CoreWebView2 => (ComCall(25, this, 'ptr*', coreWebView2 := WebView2.Core()), coreWebView2)
static IID_2 := '{c979903e-d4ca-4228-92eb-47ee3fa96eab}'
DefaultBackgroundColor {
get => (ComCall(26, this, 'uint*', &backgroundColor := 0), backgroundColor)
set => ComCall(27, this, 'uint', Value)
}
static IID_3 := '{f9614724-5d2b-41dc-aef7-73d62b51543b}'
RasterizationScale {
get => (ComCall(28, this, 'double*', &scale := 0), scale)
set => ComCall(29, this, 'double', Value)
}
ShouldDetectMonitorScaleChanges {
get => (ComCall(30, this, 'int*', &value := 0), value)
set => ComCall(31, this, 'int', Value)
}
add_RasterizationScaleChanged(eventHandler) => (ComCall(32, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_RasterizationScaleChanged(token) => ComCall(33, this, 'int64', token)
BoundsMode {
get => (ComCall(34, this, 'int*', &boundsMode := 0), boundsMode)
set => ComCall(35, this, 'int', Value)
}
static IID_4 := '{97d418d5-a426-4e49-a151-e1a10f327d9e}'
AllowExternalDrop {
get => (ComCall(36, this, 'int*', &value := 0), value)
set => ComCall(37, this, 'int', Value)
}
}
class ControllerOptions extends WebView2.Base {
static IID := '{12aae616-8ccb-44ec-bcb3-eb1831881635}'
ProfileName {
get => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(4, this, 'wstr', Value)
}
IsInPrivateModeEnabled {
get => (ComCall(5, this, 'int*', &value := 0), value)
set => ComCall(6, this, 'int', Value)
}
static IID_2 := '{06c991d8-9e7e-11ed-a8fc-0242ac120002}'
ScriptLocale {
get => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(8, this, 'wstr', Value)
}
}
class ContentLoadingEventArgs extends WebView2.Base {
static IID := '{0c8a1275-9b6b-4901-87ad-70df25bafa6e}'
IsErrorPage => (ComCall(3, this, 'int*', &isErrorPage := 0), isErrorPage)
NavigationId => (ComCall(4, this, 'int64*', &navigationId := 0), navigationId)
}
class ContextMenuItem extends WebView2.Base {
static IID := '{7aed49e3-a93f-497a-811c-749c6b6b6c65}'
Name => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Label => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
CommandId => (ComCall(5, this, 'int*', &value := 0), value)
ShortcutKeyDescription => (ComCall(6, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Icon => (ComCall(7, this, 'ptr*', value := WebView2.Stream()), value)
Kind => (ComCall(8, this, 'int*', &value := 0), value)
IsEnabled {
set => ComCall(9, this, 'int', Value)
get => (ComCall(10, this, 'int*', &value := 0), value)
}
IsChecked {
set => ComCall(11, this, 'int', Value)
get => (ComCall(12, this, 'int*', &value := 0), value)
}
Children => (ComCall(13, this, 'ptr*', value := WebView2.ContextMenuItemCollection()), value)
add_CustomItemSelected(eventHandler) => (ComCall(14, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_CustomItemSelected(token) => ComCall(15, this, 'int64', token)
}
class ContextMenuItemCollection extends WebView2.List {
static IID := '{f562a2f5-c415-45cf-b909-d4b7c1e276d3}'
Count => (ComCall(3, this, 'uint*', &value := 0), value)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', value := WebView2.ContextMenuItem()), value)
RemoveValueAtIndex(index) => ComCall(5, this, 'uint', index)
InsertValueAtIndex(index, value) => ComCall(6, this, 'uint', index, 'ptr', value)
}
class ContextMenuRequestedEventArgs extends WebView2.Base {
static IID := '{a1d309ee-c03f-11eb-8529-0242ac130003}'
MenuItems => (ComCall(3, this, 'ptr*', value := WebView2.ContextMenuItemCollection()), value)
ContextMenuTarget => (ComCall(4, this, 'ptr*', value := WebView2.ContextMenuTarget()), value)
Location => (ComCall(5, this, 'int64*', &value := 0), value)
SelectedCommandId {
set => ComCall(6, this, 'int', Value)
get => (ComCall(7, this, 'int*', &value := 0), value)
}
Handled {
set => ComCall(8, this, 'int', Value)
get => (ComCall(9, this, 'int*', &value := 0), value)
}
GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class ContextMenuTarget extends WebView2.Base {
static IID := '{b8611d99-eed6-4f3f-902c-a198502ad472}'
Kind => (ComCall(3, this, 'int*', &value := 0), value)
IsEditable => (ComCall(4, this, 'int*', &value := 0), value)
IsRequestedForMainFrame => (ComCall(5, this, 'int*', &value := 0), value)
PageUri => (ComCall(6, this, 'ptr*', &value := 0), CoTaskMem_String(value))
FrameUri => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
HasLinkUri => (ComCall(8, this, 'int*', &value := 0), value)
LinkUri => (ComCall(9, this, 'ptr*', &value := 0), CoTaskMem_String(value))
HasLinkText => (ComCall(10, this, 'int*', &value := 0), value)
LinkText => (ComCall(11, this, 'ptr*', &value := 0), CoTaskMem_String(value))
HasSourceUri => (ComCall(12, this, 'int*', &value := 0), value)
SourceUri => (ComCall(13, this, 'ptr*', &value := 0), CoTaskMem_String(value))
HasSelection => (ComCall(14, this, 'int*', &value := 0), value)
Selection => (ComCall(15, this, 'ptr*', &value := 0), CoTaskMem_String(value))
}
class Cookie extends WebView2.Base {
static IID := '{AD26D6BE-1486-43E6-BF87-A2034006CA21}'
Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
Value {
get => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(5, this, 'wstr', Value)
}
Domain => (ComCall(6, this, 'ptr*', &domain := 0), CoTaskMem_String(domain))
Path => (ComCall(7, this, 'ptr*', &path := 0), CoTaskMem_String(path))
Expires {
get => (ComCall(8, this, 'double*', &expires := 0), expires)
set => ComCall(9, this, 'double', Value)
}
IsHttpOnly {
get => (ComCall(10, this, 'int*', &isHttpOnly := 0), isHttpOnly)
set => ComCall(11, this, 'int', Value)
}
SameSite {
get => (ComCall(12, this, 'int*', &sameSite := 0), sameSite)
set => ComCall(13, this, 'int', Value)
}
IsSecure {
get => (ComCall(14, this, 'int*', &isSecure := 0), isSecure)
set => ComCall(15, this, 'int', Value)
}
IsSession => (ComCall(16, this, 'int*', &isSession := 0), isSession)
}
class CookieList extends WebView2.List {
static IID := '{F7F6F714-5D2A-43C6-9503-346ECE02D186}'
Count => (ComCall(3, this, 'uint*', &count := 0), count)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', cookie := WebView2.Cookie()), cookie)
}
class CookieManager extends WebView2.Base {
static IID := '{177CD9E7-B6F5-451A-94A0-5D7A3A4C4141}'
CreateCookie(name, value, domain, path) => (ComCall(3, this, 'wstr', name, 'wstr', value, 'wstr', domain, 'wstr', path, 'ptr*', cookie := WebView2.Cookie()), cookie)
CopyCookie(cookieParam) => (ComCall(4, this, 'ptr', cookieParam, 'ptr*', cookie := WebView2.Cookie()), cookie)
GetCookiesAsync(uri) => (ComCall(5, this, 'wstr', uri, 'ptr', WebView2.AsyncHandler(&p, WebView2.CookieList)), p)
AddOrUpdateCookie(cookie) => ComCall(6, this, 'ptr', cookie)
DeleteCookie(cookie) => ComCall(7, this, 'ptr', cookie)
DeleteCookies(name, uri) => ComCall(8, this, 'wstr', name, 'wstr', uri)
DeleteCookiesWithDomainAndPath(name, domain, path) => ComCall(9, this, 'wstr', name, 'wstr', domain, 'wstr', path)
DeleteAllCookies() => ComCall(10, this)
}
class Core extends WebView2.Base {
static IID := '{76eceacb-0462-4d94-ac83-423a6793775e}'
InjectAhkComponent() {
static _ := !Promise.Prototype.DefineProp('then', {
call: (this, resolve, reject) => !this.onSettled(resolve, err => reject(IsObject(err) ? err.Message : err)) })
script := '
			(
			(function () {
				const { objectSerializer: OS, remoteMessenger: RM, remoteRefTracker: RRT } = (window.ahk = chrome.webview.hostObjects)._options;
				if (Object.hasOwn(OS, 'createKnownRemoteProxy'))
					return;
				const ahk_fns = ['call', 'get', 'set'];
				const { _serializationOptionsPropertyName: SOPN, createKnownRemoteProxy: CKRP } = OS;
				ahk._options.forceLocalProperties.push(...ahk_fns);
				OS.createKnownRemoteProxy = function (objId, thenable, sync, debugId, basis, hostKeyNames) {
					const proxy = CKRP.call(OS, objId, thenable, sync, debugId, basis, hostKeyNames);
					if (!basis && objId) {
						for (const k of ahk_fns) proxy.setLocalProperty(k, invoke.bind(proxy, k === 'call' ? 'apply' : k))
						thenable || proxy.setLocalProperty('then', then.bind(proxy));
					}
					return proxy;
				};
				function then(onfulfilled, onrejected) {
					return new Promise(async (resolve, reject) => {
						let thenable = this._debugId.at(-1) !== '\x05then()';
						try { thenable && await invoke.call(this, 'apply', '\x05then', resolve, err => reject(new Error(err))); }
						catch { thenable = false; }
						thenable || (delete this.then, resolve(this));
					}).then(onfulfilled, onrejected);
				}
				function invoke(operation, methodName, ...parameters) {
					const debugId = this._debugId.concat(operation === 'apply' ? (methodName ??= '') + '()' : methodName ||= '__item');
					if (!Object.hasOwn(this, '_resultObjectId')) {
						const promise = RM.postRequestMessage(this._remoteObjectId, methodName, operation, parameters);
						const resolve = getResult.bind(null, false, promise._callId, operation, debugId);
						return promise.then(resolve, resolve);
					}
					const callId = RM._idGenerator.getNextId();
					return getResult(true, operation, callId, debugId, RM._postRemoteProxyMessage(this._resultObjectId, methodName, {
						kind: "request", options: { operation, typedArrayIndices: RM.GetTypedArrayParametersIndices(parameters) }, parameters,
					}, callId, true));
				}
				function getResult(sync, operation, callId, debugId, rawResult) {
					const { error, has_object, result } = rawResult.parameters;
					if (error !== undefined)
						throw new Error(OS.deserialize(sync, false, debugId, error));
					if (has_object && result.hasOwnProperty(SOPN)) {
						if (operation === 'get') {
							const options = result[SOPN];
							if (options.seq_no && options.cache_able && options.groupId === 'native') {
								RRT.addSequenceId(options.seq_no), RRT._releaseObjectsCallback(RRT._maxRemoteSequenceId, options.remoteObjectId);
								delete OS._paramTracker[callId];
								return undefined;
							}
						}
						result.callId = callId;
					}
					const val = OS.deserialize(false, has_object, debugId, result);
					delete OS._paramTracker[callId];
					return val;
				}
			})();
)'
this.ExecuteScriptAsync(script)
return this.AddScriptToExecuteOnDocumentCreatedAsync(script)
}
Settings => (ComCall(3, this, 'ptr*', settings := WebView2.Settings()), settings)
Source => (ComCall(4, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
Navigate(uri) => ComCall(5, this, 'wstr', uri)
NavigateToString(htmlContent) => ComCall(6, this, 'wstr', htmlContent)
add_NavigationStarting(eventHandler) => (ComCall(7, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NavigationStarting(token) => ComCall(8, this, 'int64', token)
add_ContentLoading(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ContentLoading(token) => ComCall(10, this, 'int64', token)
add_SourceChanged(eventHandler) => (ComCall(11, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_SourceChanged(token) => ComCall(12, this, 'int64', token)
add_HistoryChanged(eventHandler) => (ComCall(13, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_HistoryChanged(token) => ComCall(14, this, 'int64', token)
add_NavigationCompleted(eventHandler) => (ComCall(15, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NavigationCompleted(token) => ComCall(16, this, 'int64', token)
add_FrameNavigationStarting(eventHandler) => (ComCall(17, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_FrameNavigationStarting(token) => ComCall(18, this, 'int64', token)
add_FrameNavigationCompleted(eventHandler) => (ComCall(19, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_FrameNavigationCompleted(token) => ComCall(20, this, 'int64', token)
add_ScriptDialogOpening(eventHandler) => (ComCall(21, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ScriptDialogOpening(token) => ComCall(22, this, 'int64', token)
add_PermissionRequested(eventHandler) => (ComCall(23, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_PermissionRequested(token) => ComCall(24, this, 'int64', token)
add_ProcessFailed(eventHandler) => (ComCall(25, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ProcessFailed(token) => ComCall(26, this, 'int64', token)
AddScriptToExecuteOnDocumentCreatedAsync(javaScript) => (ComCall(27, this, 'wstr', javaScript, 'ptr', WebView2.AsyncHandler(&p, StrGet)), p)
RemoveScriptToExecuteOnDocumentCreated(id) => ComCall(28, this, 'wstr', id)
ExecuteScriptAsync(javaScript) => (ComCall(29, this, 'wstr', javaScript, 'ptr', WebView2.AsyncHandler(&p, StrGet)), p)
CapturePreviewAsync(imageFormat, imageStream) => (ComCall(30, this, 'int', imageFormat, 'ptr', imageStream, 'ptr', WebView2.AsyncHandler(&p)), p)
Reload() => ComCall(31, this)
PostWebMessageAsJson(webMessageAsJson) => ComCall(32, this, 'wstr', webMessageAsJson)
PostWebMessageAsString(webMessageAsString) => ComCall(33, this, 'wstr', webMessageAsString)
add_WebMessageReceived(eventHandler) => (ComCall(34, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_WebMessageReceived(token) => ComCall(35, this, 'int64', token)
CallDevToolsProtocolMethodAsync(methodName, parametersAsJson) => (ComCall(36, this, 'wstr', methodName, 'wstr', parametersAsJson, 'ptr', WebView2.AsyncHandler(&p, StrGet)), p)
BrowserProcessId => (ComCall(37, this, 'uint*', &value := 0), value)
CanGoBack => (ComCall(38, this, 'int*', &canGoBack := 0), canGoBack)
CanGoForward => (ComCall(39, this, 'int*', &canGoForward := 0), canGoForward)
GoBack() => ComCall(40, this)
GoForward() => ComCall(41, this)
GetDevToolsProtocolEventReceiver(eventName) => (ComCall(42, this, 'wstr', eventName, 'ptr*', receiver := WebView2.DevToolsProtocolEventReceiver()), receiver)
Stop() => ComCall(43, this)
add_NewWindowRequested(eventHandler) => (ComCall(44, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NewWindowRequested(token) => ComCall(45, this, 'int64', token)
add_DocumentTitleChanged(eventHandler) => (ComCall(46, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_DocumentTitleChanged(token) => ComCall(47, this, 'int64', token)
DocumentTitle => (ComCall(48, this, 'ptr*', &title := 0), CoTaskMem_String(title))
AddHostObjectToScript(name, object) => ComCall(49, this, 'wstr', name, 'ptr', ComVar(object))
RemoveHostObjectFromScript(name) => ComCall(50, this, 'wstr', name)
OpenDevToolsWindow() => ComCall(51, this)
add_ContainsFullScreenElementChanged(eventHandler) => (ComCall(52, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ContainsFullScreenElementChanged(token) => ComCall(53, this, 'int64', token)
ContainsFullScreenElement => (ComCall(54, this, 'int*', &containsFullScreenElement := 0), containsFullScreenElement)
add_WebResourceRequested(eventHandler) => (ComCall(55, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_WebResourceRequested(token) => ComCall(56, this, 'int64', token)
AddWebResourceRequestedFilter(uri, resourceContext) => ComCall(57, this, 'wstr', uri, 'int', resourceContext)
RemoveWebResourceRequestedFilter(uri, resourceContext) => ComCall(58, this, 'wstr', uri, 'int', resourceContext)
add_WindowCloseRequested(eventHandler) => (ComCall(59, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_WindowCloseRequested(token) => ComCall(60, this, 'int64', token)
static IID_2 := '{9E8F0CF8-E670-4B5E-B2BC-73E061E3184C}'
add_WebResourceResponseReceived(eventHandler) => (ComCall(61, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_WebResourceResponseReceived(token) => ComCall(62, this, 'int64', token)
NavigateWithWebResourceRequest(request) => ComCall(63, this, 'ptr', request)
add_DOMContentLoaded(eventHandler) => (ComCall(64, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_DOMContentLoaded(token) => ComCall(65, this, 'int64', token)
CookieManager => (ComCall(66, this, 'ptr*', cookieManager := WebView2.CookieManager()), cookieManager)
Environment => (ComCall(67, this, 'ptr*', environment := WebView2.Environment()), environment)
static IID_3 := '{A0D6DF20-3B92-416D-AA0C-437A9C727857}'
TrySuspendAsync() => (ComCall(68, this, 'ptr', WebView2.AsyncHandler(&p, Integer)), p)
Resume() => ComCall(69, this)
IsSuspended => (ComCall(70, this, 'int*', &isSuspended := 0), isSuspended)
SetVirtualHostNameToFolderMapping(hostName, folderPath, accessKind) => ComCall(71, this, 'wstr', hostName, 'wstr', folderPath, 'int', accessKind)
ClearVirtualHostNameToFolderMapping(hostName) => ComCall(72, this, 'wstr', hostName)
static IID_4 := '{20d02d59-6df2-42dc-bd06-f98a694b1302}'
add_FrameCreated(eventHandler) => (ComCall(73, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_FrameCreated(token) => ComCall(74, this, 'int64', token)
add_DownloadStarting(eventHandler) => (ComCall(75, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_DownloadStarting(token) => ComCall(76, this, 'int64', token)
static IID_5 := '{bedb11b8-d63c-11eb-b8bc-0242ac130003}'
add_ClientCertificateRequested(eventHandler) => (ComCall(77, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ClientCertificateRequested(token) => ComCall(78, this, 'int64', token)
static IID_6 := '{499aadac-d92c-4589-8a75-111bfc167795}'
OpenTaskManagerWindow() => ComCall(79, this)
static IID_7 := '{79c24d83-09a3-45ae-9418-487f32a58740}'
PrintToPdfAsync(resultFilePath, printSettings) => (ComCall(80, this, 'wstr', resultFilePath, 'ptr', printSettings, 'ptr', WebView2.AsyncHandler(&p, Integer)), p)
static IID_8 := '{E9632730-6E1E-43AB-B7B8-7B2C9E62E094}'
add_IsMutedChanged(eventHandler) => (ComCall(81, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_IsMutedChanged(token) => ComCall(82, this, 'int64', token)
IsMuted {
get => (ComCall(83, this, 'int*', &value := 0), value)
set => ComCall(84, this, 'int', Value)
}
add_IsDocumentPlayingAudioChanged(eventHandler) => (ComCall(85, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_IsDocumentPlayingAudioChanged(token) => ComCall(86, this, 'int64', token)
IsDocumentPlayingAudio => (ComCall(87, this, 'int*', &value := 0), value)
static IID_9 := '{4d7b2eab-9fdc-468d-b998-a9260b5ed651}'
add_IsDefaultDownloadDialogOpenChanged(eventHandler) => (ComCall(88, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_IsDefaultDownloadDialogOpenChanged(token) => ComCall(89, this, 'int64', token)
IsDefaultDownloadDialogOpen => (ComCall(90, this, 'int*', &value := 0), value)
OpenDefaultDownloadDialog() => ComCall(91, this)
CloseDefaultDownloadDialog() => ComCall(92, this)
DefaultDownloadDialogCornerAlignment {
get => (ComCall(93, this, 'int*', &value := 0), value)
set => ComCall(94, this, 'int', Value)
}
DefaultDownloadDialogMargin {
get => (ComCall(95, this, 'int64*', &value := 0), value)
set => ComCall(96, this, 'int64', Value)
}
static IID_10 := '{b1690564-6f5a-4983-8e48-31d1143fecdb}'
add_BasicAuthenticationRequested(eventHandler) => (ComCall(97, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_BasicAuthenticationRequested(token) => ComCall(98, this, 'int64', token)
static IID_11 := '{0be78e56-c193-4051-b943-23b460c08bdb}'
CallDevToolsProtocolMethodForSessionAsync(sessionId, methodName, parametersAsJson) => (ComCall(99, this, 'wstr', sessionId, 'wstr', methodName, 'wstr', parametersAsJson, 'ptr', WebView2.AsyncHandler(&p, StrGet)), p)
add_ContextMenuRequested(eventHandler) => (ComCall(100, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ContextMenuRequested(token) => ComCall(101, this, 'int64', token)
static IID_12 := '{35D69927-BCFA-4566-9349-6B3E0D154CAC}'
add_StatusBarTextChanged(eventHandler) => (ComCall(102, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_StatusBarTextChanged(token) => ComCall(103, this, 'int64', token)
StatusBarText => (ComCall(104, this, 'ptr*', &value := 0), CoTaskMem_String(value))
static IID_13 := '{F75F09A8-667E-4983-88D6-C8773F315E84}'
Profile => (ComCall(105, this, 'ptr*', value := WebView2.Profile()), value)
static IID_14 := '{6DAA4F10-4A90-4753-8898-77C5DF534165}'
add_ServerCertificateErrorDetected(eventHandler) => (ComCall(106, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ServerCertificateErrorDetected(token) => ComCall(107, this, 'int64', token)
ClearServerCertificateErrorActionsAsync() => (ComCall(108, this, 'ptr', WebView2.AsyncHandler(&p)), p)
static IID_15 := '{517B2D1D-7DAE-4A66-A4F4-10352FFB9518}'
add_FaviconChanged(eventHandler) => (ComCall(109, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_FaviconChanged(token) => ComCall(110, this, 'int64', token)
FaviconUri => (ComCall(111, this, 'ptr*', &value := 0), CoTaskMem_String(value))
GetFaviconAsync(format) => (ComCall(112, this, 'int', format, 'ptr', WebView2.AsyncHandler(&p, WebView2.Stream)), p)
static IID_16 := '{0EB34DC9-9F91-41E1-8639-95CD5943906B}'
PrintAsync(printSettings) => (ComCall(113, this, 'ptr', printSettings, 'ptr', WebView2.AsyncHandler(&p, Integer)), p)
ShowPrintUI(printDialogKind) => ComCall(114, this, 'int', printDialogKind)
PrintToPdfStreamAsync(printSettings) => (ComCall(115, this, 'ptr', printSettings, 'ptr', WebView2.AsyncHandler(&p, WebView2.Stream)), p)
static IID_17 := '{702E75D4-FD44-434D-9D70-1A68A6B1192A}'
PostSharedBufferToScript(sharedBuffer, access, additionalDataAsJson) => ComCall(116, this, 'ptr', sharedBuffer, 'int', access, 'wstr', additionalDataAsJson)
static IID_18 := '{7A626017-28BE-49B2-B865-3BA2B3522D90}'
add_LaunchingExternalUriScheme(eventHandler) => (ComCall(117, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_LaunchingExternalUriScheme(token) => ComCall(118, this, 'int64', token)
static IID_19 := '{6921F954-79B0-437F-A997-C85811897C68}'
MemoryUsageTargetLevel {
get => (ComCall(119, this, 'int*', &level := 0), level)
set => ComCall(120, this, 'int', Value)
}
static IID_20 := '{b4bc1926-7305-11ee-b962-0242ac120002}'
FrameId => (ComCall(121, this, 'uint*', &id := 0), id)
static IID_21 := '{c4980dea-587b-43b9-8143-3ef3bf552d95}'
ExecuteScriptWithResultAsync(javaScript) => (ComCall(122, this, 'wstr', javaScript, 'ptr', WebView2.AsyncHandler(&p, WebView2.ExecuteScriptResult)), p)
static IID_22 := '{DB75DFC7-A857-4632-A398-6969DDE26C0A}'
AddWebResourceRequestedFilterWithRequestSourceKinds(uri, resourceContext, requestSourceKinds) => ComCall(123, this, 'wstr', uri, 'int', resourceContext, 'int', requestSourceKinds)
RemoveWebResourceRequestedFilterWithRequestSourceKinds(uri, resourceContext, requestSourceKinds) => ComCall(124, this, 'wstr', uri, 'int', resourceContext, 'int', requestSourceKinds)
static IID_23 := '{508f0db5-90c4-5872-90a7-267a91377502}'
PostWebMessageAsJsonWithAdditionalObjects(webMessageAsJson, additionalObjects) => ComCall(125, this, 'wstr', webMessageAsJson, 'ptr', additionalObjects)
static IID_24 := '{39a7ad55-4287-5cc1-88a1-c6f458593824}'
add_NotificationReceived(eventHandler) => (ComCall(126, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NotificationReceived(token) => ComCall(127, this, 'int64', token)
static IID_25 := '{b5a86092-df50-5b4f-a17b-6c8f8b40b771}'
add_SaveAsUIShowing(eventHandler) => (ComCall(128, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_SaveAsUIShowing(token) => ComCall(129, this, 'int64', token)
ShowSaveAsUIAsync() => (ComCall(130, this, 'ptr', WebView2.AsyncHandler(&p, Integer)), p)
static IID_26 := '{806268b8-f897-5685-88e5-c45fca0b1a48}'
add_SaveFileSecurityCheckStarting(eventHandler) => (ComCall(131, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_SaveFileSecurityCheckStarting(token) => ComCall(132, this, 'int64', token)
static IID_27 := '{00fbe33b-8c07-517c-aa23-0ddd4b5f6fa0}'
add_ScreenCaptureStarting(eventHandler) => (ComCall(133, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ScreenCaptureStarting(token) => ComCall(134, this, 'int64', token)
}
class ClientCertificate extends WebView2.Base {
static IID := '{e7188076-bcc3-11eb-8529-0242ac130003}'
Subject => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Issuer => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ValidFrom => (ComCall(5, this, 'double*', &value := 0), value)
ValidTo => (ComCall(6, this, 'double*', &value := 0), value)
DerEncodedSerialNumber => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
DisplayName => (ComCall(8, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ToPemEncoding() => (ComCall(9, this, 'ptr*', &pemEncodedData := 0), CoTaskMem_String(pemEncodedData))
PemEncodedIssuerCertificateChain => (ComCall(10, this, 'ptr*', value := WebView2.StringCollection()), value)
Kind => (ComCall(11, this, 'int*', &value := 0), value)
}
class CustomSchemeRegistration extends Buffer {
static IID := '{d60ac92c-37a6-4b26-a39e-95cfe59047bb}'
__New(SchemeName, AllowedOrigins, TreatAsSecure := false, HasAuthorityComponent := false) {
super.__New(11 * A_PtrSize)
p_this := ObjPtr(this), p_unk := this.Ptr + A_PtrSize
p := NumPut('ptr', p_unk, this), fnptrs := []
this.DefineProp('__Delete', { call: __Delete })
for cb in [
QueryInterface, AddRef, Release,
get_SchemeName, get_TreatAsSecure, put_xxx,
GetAllowedOrigins, SetAllowedOrigins,
get_HasAuthorityComponent, put_xxx
]
p := NumPut('ptr', _ := CallbackCreate(cb), p), fnptrs.Push(_)
QueryInterface(this, riid, ppvObject) {
DllCall("ole32.dll\StringFromGUID2", "ptr", riid, "ptr", buf := Buffer(78), "int", 39)
iid := StrGet(buf)
if iid = '{d60ac92c-37a6-4b26-a39e-95cfe59047bb}' {
ObjAddRef(p_this), NumPut('ptr', p_unk, ppvObject)
return 0
}
NumPut('ptr', 0, ppvObject)
return 0x80004002
}
AddRef(this) => ObjAddRef(p_this)
Release(this) => ObjRelease(p_this)
put_xxx(this, value) => 0
get_SchemeName(this, pvalue) {
p := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(SchemeName) * 2 + 2, 'ptr')
DllCall('RtlMoveMemory', 'ptr', p, 'ptr', StrPtr(SchemeName), 'uptr', s)
return (NumPut('ptr', p, pvalue), 0)
}
get_TreatAsSecure(this, pvalue) => (NumPut('int', TreatAsSecure, pvalue), 0)
get_HasAuthorityComponent(this, pvalue) => (NumPut('int', HasAuthorityComponent, pvalue), 0)
GetAllowedOrigins(this, pallowedOriginsCount, pallowedOrigins) {
local l, p, p, ps
NumPut('uint', l := AllowedOrigins.Length, pallowedOriginsCount)
if l {
p := p := DllCall('ole32\CoTaskMemAlloc', 'uptr', l * A_PtrSize, 'ptr')
for origin in AllowedOrigins {
ps := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(origin) * 2 + 2, 'ptr')
DllCall('RtlMoveMemory', 'ptr', ps, 'ptr', StrPtr(origin), 'uptr', s)
p := NumPut('ptr', ps, p)
}
} else p := 0
NumPut('ptr', p, pallowedOrigins)
return 0
}
SetAllowedOrigins(this, allowedOriginsCount, pallowedOrigins) {
AllowedOrigins := []
loop allowedOriginsCount
AllowedOrigins.Push(StrGet(NumGet(pallowedOrigins, (A_Index - 1) * A_PtrSize, 'ptr')))
return 0
}
__Delete(*) {
for ptr in fnptrs
CallbackFree(ptr)
}
}
}
class ClientCertificateCollection extends WebView2.List {
static IID := '{ef5674d2-bcc3-11eb-8529-0242ac130003}'
Count => (ComCall(3, this, 'uint*', &value := 0), value)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', certificate := WebView2.ClientCertificate()), certificate)
}
class ClientCertificateRequestedEventArgs extends WebView2.Base {
static IID := '{bc59db28-bcc3-11eb-8529-0242ac130003}'
Host => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Port => (ComCall(4, this, 'int*', &value := 0), value)
IsProxy => (ComCall(5, this, 'int*', &value := 0), value)
AllowedCertificateAuthorities => (ComCall(6, this, 'ptr*', value := WebView2.StringCollection()), value)
MutuallyTrustedCertificates => (ComCall(7, this, 'ptr*', value := WebView2.ClientCertificateCollection()), value)
SelectedCertificate {
get => (ComCall(8, this, 'ptr*', value := WebView2.ClientCertificate()), value)
set => ComCall(9, this, 'ptr', Value)
}
Cancel {
get => (ComCall(10, this, 'int*', &value := 0), value)
set => ComCall(11, this, 'int', Value)
}
Handled {
get => (ComCall(12, this, 'int*', &value := 0), value)
set => ComCall(13, this, 'int', Value)
}
GetDeferral() => (ComCall(14, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class DOMContentLoadedEventArgs extends WebView2.Base {
static IID := '{16B1E21A-C503-44F2-84C9-70ABA5031283}'
NavigationId => (ComCall(3, this, 'int64*', &navigationId := 0), navigationId)
}
class Deferral extends WebView2.Base {
static IID := '{c10e7f7b-b585-46f0-a623-8befbf3e4ee0}'
Complete() => ComCall(3, this)
}
class DevToolsProtocolEventReceivedEventArgs extends WebView2.Base {
static IID := '{653c2959-bb3a-4377-8632-b58ada4e66c4}'
ParameterObjectAsJson => (ComCall(3, this, 'ptr*', &parameterObjectAsJson := 0), CoTaskMem_String(parameterObjectAsJson))
static IID_2 := '{2DC4959D-1494-4393-95BA-BEA4CB9EBD1B}'
SessionId => (ComCall(4, this, 'ptr*', &sessionId := 0), CoTaskMem_String(sessionId))
}
class DevToolsProtocolEventReceiver extends WebView2.Base {
static IID := '{b32ca51a-8371-45e9-9317-af021d080367}'
add_DevToolsProtocolEventReceived(eventHandler) => (ComCall(3, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_DevToolsProtocolEventReceived(token) => ComCall(4, this, 'int64', token)
}
class DownloadOperation extends WebView2.Base {
static IID := '{3d6b6cf2-afe1-44c7-a995-c65117714336}'
add_BytesReceivedChanged(eventHandler) => (ComCall(3, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_BytesReceivedChanged(token) => ComCall(4, this, 'int64', token)
add_EstimatedEndTimeChanged(eventHandler) => (ComCall(5, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_EstimatedEndTimeChanged(token) => ComCall(6, this, 'int64', token)
add_StateChanged(eventHandler) => (ComCall(7, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_StateChanged(token) => ComCall(8, this, 'int64', token)
Uri => (ComCall(9, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
ContentDisposition => (ComCall(10, this, 'ptr*', &contentDisposition := 0), CoTaskMem_String(contentDisposition))
MimeType => (ComCall(11, this, 'ptr*', &mimeType := 0), CoTaskMem_String(mimeType))
TotalBytesToReceive => (ComCall(12, this, 'int64*', &totalBytesToReceive := 0), totalBytesToReceive)
BytesReceived => (ComCall(13, this, 'int64*', &bytesReceived := 0), bytesReceived)
EstimatedEndTime => (ComCall(14, this, 'ptr*', &estimatedEndTime := 0), CoTaskMem_String(estimatedEndTime))
ResultFilePath => (ComCall(15, this, 'ptr*', &resultFilePath := 0), CoTaskMem_String(resultFilePath))
State => (ComCall(16, this, 'int*', &downloadState := 0), downloadState)
InterruptReason => (ComCall(17, this, 'int*', &interruptReason := 0), interruptReason)
Cancel() => ComCall(18, this)
Pause() => ComCall(19, this)
Resume() => ComCall(20, this)
CanResume => (ComCall(21, this, 'int*', &canResume := 0), canResume)
}
class DownloadStartingEventArgs extends WebView2.Base {
static IID := '{e99bbe21-43e9-4544-a732-282764eafa60}'
DownloadOperation => (ComCall(3, this, 'ptr*', downloadOperation := WebView2.DownloadOperation()), downloadOperation)
Cancel {
get => (ComCall(4, this, 'int*', &cancel := 0), cancel)
set => ComCall(5, this, 'int', Value)
}
ResultFilePath {
get => (ComCall(6, this, 'ptr*', &resultFilePath := 0), CoTaskMem_String(resultFilePath))
set => ComCall(7, this, 'wstr', Value)
}
Handled {
get => (ComCall(8, this, 'int*', &handled := 0), handled)
set => ComCall(9, this, 'int', Value)
}
GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class Environment extends WebView2.Base {
static IID := '{b96d755e-0319-4e92-a296-23436f46a1fc}'
CreateCoreWebView2ControllerAsync(parentWindow) => (ComCall(3, this, 'ptr', parentWindow, 'ptr', WebView2.AsyncHandler(&p, WebView2.Controller)), p.then(r => r.Fill()))
CreateWebResourceResponse(content, statusCode, reasonPhrase, headers) => (ComCall(4, this, 'ptr', content, 'int', statusCode, 'wstr', reasonPhrase, 'wstr', headers, 'ptr*', response := WebView2.WebResourceResponse()), response)
BrowserVersionString => (ComCall(5, this, 'ptr*', &versionInfo := 0), CoTaskMem_String(versionInfo))
add_NewBrowserVersionAvailable(eventHandler) => (ComCall(6, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NewBrowserVersionAvailable(token) => ComCall(7, this, 'int64', token)
static IID_2 := '{41F3632B-5EF4-404F-AD82-2D606C5A9A21}'
CreateWebResourceRequest(uri, method, postData, headers) => (ComCall(8, this, 'wstr', uri, 'wstr', method, 'ptr', postData, 'wstr', headers, 'ptr*', request := WebView2.WebResourceRequest()), request)
static IID_3 := '{80a22ae3-be7c-4ce2-afe1-5a50056cdeeb}'
CreateCoreWebView2CompositionControllerAsync(parentWindow) => (ComCall(9, this, 'ptr', parentWindow, 'ptr', WebView2.AsyncHandler(&p, WebView2.CompositionController)), p)
CreateCoreWebView2PointerInfo() => (ComCall(10, this, 'ptr*', pointerInfo := WebView2.PointerInfo()), pointerInfo)
static IID_4 := '{20944379-6dcf-41d6-a0a0-abc0fc50de0d}'
GetAutomationProviderForWindow(hwnd) => (ComCall(11, this, 'ptr', hwnd, 'ptr*', &provider := 0), ComValue(0xd, provider))
static IID_5 := '{319e423d-e0d7-4b8d-9254-ae9475de9b17}'
add_BrowserProcessExited(eventHandler) => (ComCall(12, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_BrowserProcessExited(token) => ComCall(13, this, 'int64', token)
static IID_6 := '{e59ee362-acbd-4857-9a8e-d3644d9459a9}'
CreatePrintSettings() => (ComCall(14, this, 'ptr*', printSettings := WebView2.PrintSettings()), printSettings)
static IID_7 := '{43C22296-3BBD-43A4-9C00-5C0DF6DD29A2}'
UserDataFolder => (ComCall(15, this, 'ptr*', &value := 0), CoTaskMem_String(value))
static IID_8 := '{D6EB91DD-C3D2-45E5-BD29-6DC2BC4DE9CF}'
add_ProcessInfosChanged(eventHandler) => (ComCall(16, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ProcessInfosChanged(token) => ComCall(17, this, 'int64', token)
GetProcessInfos() => (ComCall(18, this, 'ptr*', value := WebView2.ProcessInfoCollection()), value)
static IID_9 := '{f06f41bf-4b5a-49d8-b9f6-fa16cd29f274}'
CreateContextMenuItem(label, iconStream, kind) => (ComCall(19, this, 'wstr', label, 'ptr', iconStream, 'int', kind, 'ptr*', item := WebView2.ContextMenuItem()), item)
static IID_10 := '{ee0eb9df-6f12-46ce-b53f-3f47b9c928e0}'
CreateCoreWebView2ControllerOptions() => (ComCall(20, this, 'ptr*', options := WebView2.ControllerOptions()), options)
CreateCoreWebView2ControllerWithOptionsAsync(parentWindow, options) => (ComCall(21, this, 'ptr', parentWindow, 'ptr', options, 'ptr', WebView2.AsyncHandler(&p, WebView2.Controller)), p.then(r => r.Fill()))
CreateCoreWebView2CompositionControllerWithOptionsAsync(parentWindow, options) => (ComCall(22, this, 'ptr', parentWindow, 'ptr', options, 'ptr', WebView2.AsyncHandler(&p, WebView2.CompositionController)), p)
static IID_11 := '{F0913DC6-A0EC-42EF-9805-91DFF3A2966A}'
FailureReportFolderPath => (ComCall(23, this, 'ptr*', &value := 0), CoTaskMem_String(value))
static IID_12 := '{F503DB9B-739F-48DD-B151-FDFCF253F54E}'
CreateSharedBuffer(size) => (ComCall(24, this, 'uint64', size, 'ptr*', shared_buffer := WebView2.SharedBuffer()), shared_buffer)
static IID_13 := '{af641f58-72b2-11ee-b962-0242ac120002}'
GetProcessExtendedInfosAsync() => (ComCall(25, this, 'ptr', WebView2.AsyncHandler(&p, WebView2.ProcessExtendedInfoCollection)), p)
static IID_14 := 'a5e9fad9-c875-59da-9bd7-473aa5ca1cef'
CreateWebFileSystemFileHandle(path, permission) => ComCall(26, this, 'wstr', path, 'int', permission, 'ptr*', value := WebView2.FileSystemHandle(), value)
CreateWebFileSystemDirectoryHandle(path, permission) => ComCall(27, this, 'wstr', path, 'int', permission, 'ptr*', value := WebView2.FileSystemHandle(), value)
CreateObjectCollection(objects) {
items := Buffer(A_PtrSize * len := objects.Length), p := items.Ptr
for it in objects
p := NumPut('ptr', it.Ptr, p)
ComCall(28, this, 'uint', len, 'ptr', items, 'ptr*', objectCollection := WebView2.ObjectCollection())
return objectCollection
}
}
class EnvironmentOptions extends Buffer {
__New(opts) {
cbs := [
QueryInterface, AddRef, Release,
get_xxx_str.Bind('AdditionalBrowserArguments'), put_xxx,
get_xxx_str.Bind('Language'), put_xxx,
get_xxx_str.Bind('TargetCompatibleBrowserVersion'), put_xxx,
get_xxx_int.Bind('AllowSingleSignOnUsingOSPrimaryAccount'), put_xxx,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('ExclusiveUserDataFolderAccess'), put_xxx,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('IsCustomCrashReportingEnabled'), put_xxx,
QueryInterface, AddRef, Release,
GetCustomSchemeRegistrations, SetCustomSchemeRegistrations,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('EnableTrackingPrevention'), put_xxx,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('AreBrowserExtensionsEnabled'), put_xxx,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('ChannelSearchKind'), put_xxx,
get_xxx_int.Bind('ReleaseChannels'), put_xxx,
QueryInterface, AddRef, Release,
get_xxx_int.Bind('ScrollBarStyle'), put_xxx,
]
n := 8, i := 0
super.__New((n + cbs.Length) * A_PtrSize)
p_this := ObjPtr(this), p_unk := this.Ptr, p := p_unk + n * A_PtrSize
mp := Map(), fnptrs := [], this.DefineProp('__Delete', { call: __Delete })
for cb in cbs {
if cb == QueryInterface
NumPut('ptr', p, this, (i++) * A_PtrSize)
p := NumPut('ptr', mp.Get(cb, 0) || mp[cb] := CallbackCreate(cb, , cb.MinParams || 2), p)
}
for _, p in mp
fnptrs.Push(p)
QueryInterface(this, riid, ppvObject) {
static iids := Map(
'{2FDE08A8-1E9A-4766-8C05-95A9CEB9D1C5}', 0,
'{FF85C98A-1BA7-4A6B-90C8-2B752C89E9E2}', 1,
'{4A5C436E-A9E3-4A2E-89C3-910D3513F5CC}', 2,
'{AC52D13F-0D38-475A-9DCA-876580D6793E}', 3,
'{0AE35D64-C47F-4464-814E-259C345D1501}', 4,
'{57D29CC3-C84F-42A0-B0E2-EFFBD5E179DE}', 5,
'{C48D539F-E39F-441C-AE68-1F66E570BDC5}', 6,
'{7c7ecf51-e918-5caf-853c-e9a2bcc27775}', 7,
)
DllCall("ole32.dll\StringFromGUID2", "ptr", riid, "ptr", buf := Buffer(78), "int", 39)
if (index := iids.Get(iid := StrUpper(StrGet(buf)), -1)) >= 0 {
ObjAddRef(p_this)
NumPut('ptr', p_unk + index * A_PtrSize, ppvObject)
return 0
}
NumPut('ptr', 0, ppvObject)
return 0x80004002
}
AddRef(this) => ObjAddRef(p_this)
Release(this) => ObjRelease(p_this)
put_xxx(this, value) => 0
get_xxx_str(prop, this, pvalue) {
if opts.HasOwnProp(prop) {
p := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(v := opts.%prop%) * 2 + 2, 'ptr')
DllCall('RtlMoveMemory', 'ptr', p, 'ptr', StrPtr(v), 'uptr', s)
} else p := 0
return (NumPut('ptr', p, pvalue), 0)
}
get_xxx_int(prop, this, pvalue) {
if opts.HasOwnProp(prop)
v := opts.%prop%
else switch prop {
case 'EnableTrackingPrevention': v := true
case 'ReleaseChannels': v := 15
default: v := 0
}
return (NumPut('int', v, pvalue), 0)
}
GetCustomSchemeRegistrations(this, pcount, pschemeRegistrations) {
if opts.HasOwnProp('CustomSchemeRegistrations') && (csrs := opts.CustomSchemeRegistrations).Length {
NumPut('uint', csrs.Length, pcount)
NumPut('ptr', p := DllCall('ole32\CoTaskMemAlloc', 'uptr', csrs.Length * A_PtrSize, 'ptr'), pschemeRegistrations)
for csr in csrs
ObjPtrAddRef(csr), p := NumPut('ptr', csr.Ptr, p)
} else NumPut('uint', 0, pcount), NumPut('ptr', 0, pschemeRegistrations)
return 0
}
SetCustomSchemeRegistrations(this, count, schemeRegistrations) => 0
__Delete(*) {
for ptr in fnptrs
CallbackFree(ptr)
}
}
}
class ExecuteScriptResult extends WebView2.Base {
static IID := '{0CE15963-3698-4DF7-9399-71ED6CDD8C9F}'
Succeeded => (ComCall(3, this, 'int*', &value := 0), value)
ResultAsJson => (ComCall(4, this, 'ptr*', &jsonResult := 0), CoTaskMem_String(jsonResult))
TryGetResultAsString(&resultIsString?) => (ComCall(5, this, 'ptr*', &result := 0, 'int*', &resultIsString := 0), CoTaskMem_String(result))
Exception => (ComCall(6, this, 'ptr*', exception := WebView2.ScriptException()), exception)
}
class File extends WebView2.Base {
static IID := '{f2c19559-6bc1-4583-a757-90021be9afec}'
Path => (ComCall(3, this, 'ptr*', &path := 0), CoTaskMem_String(path))
}
class FileSystemHandle extends WebView2.Base {
static IID := '{c65100ac-0de2-5551-a362-23d9bd1d0e1f}'
Kind => (ComCall(3, this, 'int*', &value := 0), value)
Path => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Permission => (ComCall(5, this, 'int*', &value := 0), value)
}
class Frame extends WebView2.Base {
static IID := '{f1131a5e-9ba9-11eb-a8b3-0242ac130003}'
Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
add_NameChanged(eventHandler) => (ComCall(4, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NameChanged(token) => ComCall(5, this, 'int64', token)
AddHostObjectToScriptWithOrigins(name, object, originsArr*) {
if originsCount := originsArr.Length {
p := (origins := Buffer(originsCount * A_PtrSize)).Ptr
loop originsCount
p := NumPut('ptr', StrPtr(originsArr[A_Index]), p)
}
ComCall(6, this, 'wstr', name, 'ptr', ComVar(object), 'uint', originsCount, 'ptr', origins)
}
RemoveHostObjectFromScript(name) => ComCall(7, this, 'wstr', name)
add_Destroyed(eventHandler) => (ComCall(8, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_Destroyed(token) => ComCall(9, this, 'int64', token)
IsDestroyed() => (ComCall(10, this, 'int*', &destroyed := 0), destroyed)
static IID_2 := '{7a6a5834-d185-4dbf-b63f-4a9bc43107d4}'
add_NavigationStarting(eventHandler) => (ComCall(11, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NavigationStarting(token) => ComCall(12, this, 'int64', token)
add_ContentLoading(eventHandler) => (ComCall(13, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ContentLoading(token) => ComCall(14, this, 'int64', token)
add_NavigationCompleted(eventHandler) => (ComCall(15, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_NavigationCompleted(token) => ComCall(16, this, 'int64', token)
add_DOMContentLoaded(eventHandler) => (ComCall(17, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_DOMContentLoaded(token) => ComCall(18, this, 'int64', token)
ExecuteScriptAsync(javaScript) => (ComCall(19, this, 'wstr', javaScript, 'ptr', WebView2.AsyncHandler(&p, StrGet)), p)
PostWebMessageAsJson(webMessageAsJson) => ComCall(20, this, 'wstr', webMessageAsJson)
PostWebMessageAsString(webMessageAsString) => ComCall(21, this, 'wstr', webMessageAsString)
add_WebMessageReceived(eventHandler) => (ComCall(22, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_WebMessageReceived(token) => ComCall(23, this, 'int64', token)
static IID_3 := '{b50d82cc-cc28-481d-9614-cb048895e6a0}'
add_PermissionRequested(eventHandler) => (ComCall(24, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_PermissionRequested(token) => ComCall(25, this, 'int64', token)
static IID_4 := '{188782DC-92AA-4732-AB3C-FCC59F6F68B9}'
PostSharedBufferToScript(sharedBuffer, access, additionalDataAsJson) => ComCall(26, this, 'ptr', sharedBuffer, 'int', access, 'wstr', additionalDataAsJson)
static IID_5 := '{99d199c4-7305-11ee-b962-0242ac120002}'
FrameId => (ComCall(27, this, 'uint*', &id := 0), id)
static IID_6 := '{0de611fd-31e9-5ddc-9d71-95eda26eff32}'
add_ScreenCaptureStarting(eventHandler) => (ComCall(28, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_ScreenCaptureStarting(token) => ComCall(29, this, 'int64', token)
}
class FrameCreatedEventArgs extends WebView2.Base {
static IID := '{4d6e7b5e-9baa-11eb-a8b3-0242ac130003}'
Frame => (ComCall(3, this, 'ptr*', frame := WebView2.Frame()), frame)
}
class FrameInfo extends WebView2.Base {
static IID := '{da86b8a1-bdf3-4f11-9955-528cefa59727}'
Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
Source => (ComCall(4, this, 'ptr*', &source := 0), CoTaskMem_String(source))
static IID_2 := this.DefaultIID := '{56f85cfa-72c4-11ee-b962-0242ac120002}'
ParentFrameInfo => (ComCall(5, this, 'ptr*', frameInfo := WebView2.FrameInfo()), frameInfo)
FrameId => (ComCall(6, this, 'uint*', &id := 0), id)
FrameKind => (ComCall(7, this, 'uint*', &kind := 0), kind)
}
class FrameInfoCollection extends WebView2.Base {
static IID := '{8f834154-d38e-4d90-affb-6800a7272839}'
GetIterator() => (ComCall(3, this, 'ptr*', iterator := WebView2.FrameInfoCollectionIterator()), iterator)
}
class FrameInfoCollectionIterator extends WebView2.Base {
static IID := '{1bf89e2d-1b2b-4629-b28f-05099b41bb03}'
HasCurrent => (ComCall(3, this, 'int*', &hasCurrent := 0), hasCurrent)
GetCurrent() => (ComCall(4, this, 'ptr*', frameInfo := WebView2.FrameInfo()), frameInfo)
MoveNext() => (ComCall(5, this, 'int*', &hasNext := 0), hasNext)
__Enum(n) => (&fi, *) => this.HasCurrent && (fi := this.GetCurrent(), this.MoveNext(), true)
}
class Handler extends Buffer {
static Call(invoke, numParams := 3) {
static pfns := [CallbackCreate(QueryInterface), CallbackCreate(AddRef), CallbackCreate(Release)]
.DefineProp('__Delete', { call: __Delete })
if HasMethod(invoke) {
handler := super(6 * A_PtrSize)
NumPut('ptr', handler.Ptr + 2 * A_PtrSize, 'ptr', ObjPtr(handler),
'ptr', pfns[1], 'ptr', pfns[2], 'ptr', pfns[3],
'ptr', CallbackCreate(invoke, , numParams), handler)
handler.__Delete := (this) => CallbackFree(NumGet(this, 5 * A_PtrSize, 'ptr'))
return handler
}
return invoke
QueryInterface(interface, riid, ppvObject) => 0x80004002
AddRef(this) => ObjAddRef(NumGet(this, A_PtrSize, 'ptr'))
Release(this) => ObjRelease(NumGet(this, A_PtrSize, 'ptr'))
__Delete(this) {
for p in this
CallbackFree(p)
}
}
}
class HttpHeadersCollectionIterator extends WebView2.Base {
static IID := '{0702fc30-f43b-47bb-ab52-a42cb552ad9f}'
GetCurrentHeader(&name, &value) {
ComCall(3, this, 'ptr*', &name := 0, 'ptr*', &value := 0)
name := CoTaskMem_String(name), value := CoTaskMem_String(value)
}
HasCurrentHeader => (ComCall(4, this, 'int*', &hasCurrent := 0), hasCurrent)
MoveNext() => (ComCall(5, this, 'int*', &hasNext := 0), hasNext)
__Enum(n) => (&name, &value, *) => this.HasCurrentHeader && (this.GetCurrentHeader(&name, &value), this.MoveNext(), true)
}
class HttpRequestHeaders extends WebView2.Base {
static IID := '{e86cac0e-5523-465c-b536-8fb9fc8c8c60}'
GetHeader(name) => (ComCall(3, this, 'wstr', name, 'ptr*', &value := 0), CoTaskMem_String(value))
GetHeaders(name) => (ComCall(4, this, 'wstr', name, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
RetVal(name) => (ComCall(5, this, 'wstr', name, 'int*', &RetVal := 0), RetVal)
SetHeader(name, value) => ComCall(6, this, 'wstr', name, 'wstr', value)
RemoveHeader(name) => ComCall(7, this, 'wstr', name)
GetIterator() => (ComCall(8, this, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
}
class HttpResponseHeaders extends WebView2.Base {
static IID := '{03c5ff5a-9b45-4a88-881c-89a9f328619c}'
AppendHeader(name, value) => ComCall(3, this, 'wstr', name, 'wstr', value)
RetVal(name) => (ComCall(4, this, 'wstr', name, 'int*', &RetVal := 0), RetVal)
GetHeader(name) => (ComCall(5, this, 'wstr', name, 'ptr*', &value := 0), CoTaskMem_String(value))
GetHeaders(name) => (ComCall(6, this, 'wstr', name, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
GetIterator() => (ComCall(7, this, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
}
class LaunchingExternalUriSchemeEventArgs extends WebView2.Base {
static IID := '{07D1A6C3-7175-4BA1-9306-E593CA07E46C}'
Uri => (ComCall(3, this, 'ptr*', value := 0), CoTaskMem_String(value))
InitiatingOrigin => (ComCall(4, this, 'ptr*', value := 0), CoTaskMem_String(value))
IsUserInitiated => (ComCall(5, this, 'int*', &value := 0), value)
Cancel {
get => (ComCall(6, this, 'int*', &value := 0), value)
set => ComCall(7, this, 'int', Value)
}
GetDeferral() => (ComCall(8, this, 'ptr*', value := WebView2.Deferral()), value)
}
class MoveFocusRequestedEventArgs extends WebView2.Base {
static IID := '{2d6aa13b-3839-4a15-92fc-d88b3c0d9c9d}'
Reason => (ComCall(3, this, 'int*', &reason := 0), reason)
Handled {
get => (ComCall(4, this, 'int*', &value := 0), value)
set => ComCall(5, this, 'int', Value)
}
}
class NavigationCompletedEventArgs extends WebView2.Base {
static IID := '{30d68b7d-20d9-4752-a9ca-ec8448fbb5c1}'
IsSuccess => (ComCall(3, this, 'int*', &isSuccess := 0), isSuccess)
WebErrorStatus => (ComCall(4, this, 'int*', &webErrorStatus := 0), webErrorStatus)
NavigationId => (ComCall(5, this, 'int64*', &navigationId := 0), navigationId)
static IID_2 := '{FDF8B738-EE1E-4DB2-A329-8D7D7B74D792}'
HttpStatusCode => (ComCall(6, this, 'int*', &http_status_code := 0), http_status_code)
}
class NavigationStartingEventArgs extends WebView2.Base {
static IID := '{5b495469-e119-438a-9b18-7604f25f2e49}'
Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
IsUserInitiated => (ComCall(4, this, 'int*', &isUserInitiated := 0), isUserInitiated)
IsRedirected => (ComCall(5, this, 'int*', &isRedirected := 0), isRedirected)
RequestHeaders => (ComCall(6, this, 'ptr*', requestHeaders := WebView2.HttpRequestHeaders()), requestHeaders)
Cancel {
get => (ComCall(7, this, 'int*', &cancel := 0), cancel)
set => ComCall(8, this, 'int', Value)
}
NavigationId => (ComCall(9, this, 'int64*', &navigationId := 0), navigationId)
static IID_2 := '{9086BE93-91AA-472D-A7E0-579F2BA006AD}'
AdditionalAllowedFrameAncestors {
get => (ComCall(10, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(11, this, 'wstr', Value)
}
static IID_3 := '{DDFFE494-4942-4BD2-AB73-35B8FF40E19F}'
NavigationKind => (ComCall(12, this, 'int*', &navigation_kind := 0), navigation_kind)
}
class NewWindowRequestedEventArgs extends WebView2.Base {
static IID := '{34acb11c-fc37-4418-9132-f9c21d1eafb9}'
Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
NewWindow {
set => ComCall(4, this, 'ptr', Value)
get => (ComCall(5, this, 'ptr*', newWindow := WebView2.Core()), newWindow)
}
Handled {
set => ComCall(6, this, 'int', Value)
get => (ComCall(7, this, 'int*', &handled := 0), handled)
}
IsUserInitiated => (ComCall(8, this, 'int*', &isUserInitiated := 0), isUserInitiated)
GetDeferral() => (ComCall(9, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
WindowFeatures => (ComCall(10, this, 'ptr*', value := WebView2.WindowFeatures()), value)
static IID_2 := '{bbc7baed-74c6-4c92-b63a-7f5aeae03de3}'
Name => (ComCall(11, this, 'ptr*', &value := 0), CoTaskMem_String(value))
static IID_3 := '{842bed3c-6ad6-4dd9-b938-28c96667ad66}'
OriginalSourceFrameInfo => (ComCall(12, this, 'ptr*', frameInfo := WebView2.FrameInfo()), frameInfo)
}
class NonClientRegionChangedEventArgs extends WebView2.Base {
static IID := '{AB71D500-0820-4A52-809C-48DB04FF93BF}'
RegionKind => (ComCall(3, this, 'int*', &value := 0), value)
}
class Notification extends WebView2.Base {
static IID := '{B7434D98-6BC8-419D-9DA5-FB5A96D4DACD}'
add_CloseRequested(eventHandler) => (ComCall(3, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_CloseRequested(token) => ComCall(4, this, 'int64', token)
ReportShown() => ComCall(5, this)
ReportClicked() => ComCall(6, this)
ReportClosed() => ComCall(7, this)
Body => (ComCall(8, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Direction => ComCall(9, this, 'int*', &value := 0)
Language => (ComCall(10, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Tag => (ComCall(11, this, 'ptr*', &value := 0), CoTaskMem_String(value))
IconUri => (ComCall(12, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Title => (ComCall(13, this, 'ptr*', &value := 0), CoTaskMem_String(value))
BadgeUri => (ComCall(14, this, 'ptr*', &value := 0), CoTaskMem_String(value))
BodyImageUri => (ComCall(15, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ShouldRenotify => (ComCall(16, this, 'int*', &value := 0), value)
RequiresInteraction => (ComCall(17, this, 'int*', &value := 0), value)
IsSilent => (ComCall(18, this, 'int*', &value := 0), value)
Timestamp => (ComCall(19, this, 'double*', &value := 0), value)
GetVibrationPattern() {
ComCall(20, this, 'uint*', &count := 0, 'ptr*', &pvi := 0)
(vibrationPattern := []).Capacity := count
loop count
vibrationPattern.Push(NumGet(pvi, 'int64')), pvi += 8
return vibrationPattern
}
}
class NotificationReceivedEventArgs extends WebView2.Base {
static IID := '{1512DD5B-5514-4F85-886E-21C3A4C9CFE6}'
SenderOrigin => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Notification => (ComCall(4, this, 'ptr*', value := WebView2.Notification()), value)
Handled {
set => ComCall(5, this, 'int', Value)
get => (ComCall(6, this, 'int*', &value := 0), value)
}
GetDeferral() => (ComCall(7, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class ObjectCollection extends WebView2.ObjectCollectionView {
static IID := '{5cfec11c-25bd-4e8d-9e1a-7acdaeeec047}'
RemoveValueAtIndex(index) => ComCall(5, this, 'uint', index)
InsertValueAtIndex(index, value) => ComCall(6, this, 'uint', index, 'ptr', value)
}
class ObjectCollectionView extends WebView2.List {
static IID := '{0f36fd87-4f69-4415-98da-888f89fb9a33}'
Count => (ComCall(3, this, 'uint*', &value := 0), value)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', value := WebView2.Base()), value)
}
class PermissionRequestedEventArgs extends WebView2.Base {
static IID := '{973ae2ef-ff18-4894-8fb2-3c758f046810}'
Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
PermissionKind => (ComCall(4, this, 'int*', &permissionKind := 0), permissionKind)
IsUserInitiated => (ComCall(5, this, 'int*', &isUserInitiated := 0), isUserInitiated)
State {
get => (ComCall(6, this, 'int*', &state := 0), state)
set => ComCall(7, this, 'int', Value)
}
GetDeferral() => (ComCall(8, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
static IID_2 := '{74d7127f-9de6-4200-8734-42d6fb4ff741}'
Handled {
get => (ComCall(9, this, 'int*', &handled := 0), handled)
set => ComCall(10, this, 'int', Value)
}
static IID_3 := '{e61670bc-3dce-4177-86d2-c629ae3cb6ac}'
SavesInProfile {
get => (ComCall(11, this, 'int*', &value := 0), value)
set => ComCall(12, this, 'int', Value)
}
}
class PermissionSetting extends WebView2.Base {
static IID := '{792b6eca-5576-421c-9119-74ebb3a4ffb3}'
PermissionKind => (ComCall(3, this, 'int*', &value := 0), value)
PermissionOrigin => (ComCall(4, this, 'int*', &value := 0), CoTaskMem_String(value))
PermissionState => (ComCall(5, this, 'int*', &value := 0), value)
}
class PermissionSettingCollectionView extends WebView2.List {
static IID := '{f5596f62-3de5-47b1-91e8-a4104b596b96}'
GetValueAtIndex(index) => (ComCall(3, this, 'ptr*', permissionSetting := WebView2.PermissionSetting()), permissionSetting)
Count => (ComCall(4, this, 'uint*', &value := 0), value)
}
class PointerInfo extends WebView2.Base {
static IID := '{e6995887-d10d-4f5d-9359-4ce46e4f96b9}'
PointerKind {
get => (ComCall(3, this, 'uint*', &pointerKind := 0), pointerKind)
set => ComCall(4, this, 'uint', Value)
}
PointerId {
get => (ComCall(5, this, 'uint*', &pointerId := 0), pointerId)
set => ComCall(6, this, 'uint', Value)
}
FrameId {
get => (ComCall(7, this, 'uint*', &frameId := 0), frameId)
set => ComCall(8, this, 'uint', Value)
}
PointerFlags {
get => (ComCall(9, this, 'uint*', &pointerFlags := 0), pointerFlags)
set => ComCall(10, this, 'uint', Value)
}
PointerDeviceRect {
get => (ComCall(11, this, 'ptr', pointerDeviceRect := WebView2.RECT()), pointerDeviceRect)
set => (A_PtrSize = 8 ? ComCall(12, this, 'ptr', Value) : ComCall(12, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
}
DisplayRect {
get => (ComCall(13, this, 'ptr', displayRect := WebView2.RECT()), displayRect)
set => (A_PtrSize = 8 ? ComCall(14, this, 'ptr', Value) : ComCall(14, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
}
PixelLocation {
get => (ComCall(15, this, 'int64*', &pixelLocation := 0), pixelLocation)
set => ComCall(16, this, 'int64', Value)
}
HimetricLocation {
get => (ComCall(17, this, 'int64*', &himetricLocation := 0), himetricLocation)
set => ComCall(18, this, 'int64', Value)
}
PixelLocationRaw {
get => (ComCall(19, this, 'int64*', &pixelLocationRaw := 0), pixelLocationRaw)
set => ComCall(20, this, 'int64', Value)
}
HimetricLocationRaw {
get => (ComCall(21, this, 'int64*', &himetricLocationRaw := 0), himetricLocationRaw)
set => ComCall(22, this, 'int64', Value)
}
Time {
get => (ComCall(23, this, 'uint*', &time := 0), time)
set => ComCall(24, this, 'uint', Value)
}
HistoryCount {
get => (ComCall(25, this, 'uint*', &historyCount := 0), historyCount)
set => ComCall(26, this, 'uint', Value)
}
InputData {
get => (ComCall(27, this, 'int*', &inputData := 0), inputData)
set => ComCall(28, this, 'int', Value)
}
KeyStates {
get => (ComCall(29, this, 'uint*', &keyStates := 0), keyStates)
set => ComCall(30, this, 'uint', Value)
}
PerformanceCount {
get => (ComCall(31, this, 'uint64*', &performanceCount := 0), performanceCount)
set => ComCall(32, this, 'uint64', Value)
}
ButtonChangeKind {
get => (ComCall(33, this, 'int*', &buttonChangeKind := 0), buttonChangeKind)
set => ComCall(34, this, 'int', Value)
}
PenFlags {
get => (ComCall(35, this, 'uint*', &penFLags := 0), penFLags)
set => ComCall(36, this, 'uint', Value)
}
PenMask {
get => (ComCall(37, this, 'uint*', &penMask := 0), penMask)
set => ComCall(38, this, 'uint', Value)
}
PenPressure {
get => (ComCall(39, this, 'uint*', &penPressure := 0), penPressure)
set => ComCall(40, this, 'uint', Value)
}
PenRotation {
get => (ComCall(41, this, 'uint*', &penRotation := 0), penRotation)
set => ComCall(42, this, 'uint', Value)
}
PenTiltX {
get => (ComCall(43, this, 'int*', &penTiltX := 0), penTiltX)
set => ComCall(44, this, 'int', Value)
}
PenTiltY {
get => (ComCall(45, this, 'int*', &penTiltY := 0), penTiltY)
set => ComCall(46, this, 'int', Value)
}
TouchFlags {
get => (ComCall(47, this, 'uint*', &touchFlags := 0), touchFlags)
set => ComCall(48, this, 'uint', Value)
}
TouchMask {
get => (ComCall(49, this, 'uint*', &touchMask := 0), touchMask)
set => ComCall(50, this, 'uint', Value)
}
TouchContact {
get => (ComCall(51, this, 'ptr', touchContact := WebView2.RECT()), touchContact)
set => (A_PtrSize = 8 ? ComCall(52, this, 'ptr', Value) : ComCall(52, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
}
TouchContactRaw {
get => (ComCall(53, this, 'ptr', touchContactRaw := WebView2.RECT()), touchContactRaw)
set => (A_PtrSize = 8 ? ComCall(54, this, 'ptr', Value) : ComCall(54, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
}
TouchOrientation {
get => (ComCall(55, this, 'uint*', &touchOrientation := 0), touchOrientation)
set => ComCall(56, this, 'uint', Value)
}
TouchPressure {
get => (ComCall(57, this, 'uint*', &touchPressure := 0), touchPressure)
set => ComCall(58, this, 'uint', Value)
}
}
class PrintSettings extends WebView2.Base {
static IID := '{377f3721-c74e-48ca-8db1-df68e51d60e2}'
Orientation {
get => (ComCall(3, this, 'int*', &orientation := 0), orientation)
set => ComCall(4, this, 'int', Value)
}
ScaleFactor {
get => (ComCall(5, this, 'double*', &scaleFactor := 0), scaleFactor)
set => ComCall(6, this, 'double', Value)
}
PageWidth {
get => (ComCall(7, this, 'double*', &pageWidth := 0), pageWidth)
set => ComCall(8, this, 'double', Value)
}
PageHeight {
get => (ComCall(9, this, 'double*', &pageHeight := 0), pageHeight)
set => ComCall(10, this, 'double', Value)
}
MarginTop {
get => (ComCall(11, this, 'double*', &marginTop := 0), marginTop)
set => ComCall(12, this, 'double', Value)
}
MarginBottom {
get => (ComCall(13, this, 'double*', &marginBottom := 0), marginBottom)
set => ComCall(14, this, 'double', Value)
}
MarginLeft {
get => (ComCall(15, this, 'double*', &marginLeft := 0), marginLeft)
set => ComCall(16, this, 'double', Value)
}
MarginRight {
get => (ComCall(17, this, 'double*', &marginRight := 0), marginRight)
set => ComCall(18, this, 'double', Value)
}
ShouldPrintBackgrounds {
get => (ComCall(19, this, 'int*', &shouldPrintBackgrounds := 0), shouldPrintBackgrounds)
set => ComCall(20, this, 'int', Value)
}
ShouldPrintSelectionOnly {
get => (ComCall(21, this, 'int*', &shouldPrintSelectionOnly := 0), shouldPrintSelectionOnly)
set => ComCall(22, this, 'int', Value)
}
ShouldPrintHeaderAndFooter {
get => (ComCall(23, this, 'int*', &shouldPrintHeaderAndFooter := 0), shouldPrintHeaderAndFooter)
set => ComCall(24, this, 'int', Value)
}
HeaderTitle {
get => (ComCall(25, this, 'ptr*', &headerTitle := 0), CoTaskMem_String(headerTitle))
set => ComCall(26, this, 'wstr', Value)
}
FooterUri {
get => (ComCall(27, this, 'ptr*', &footerUri := 0), CoTaskMem_String(footerUri))
set => ComCall(28, this, 'wstr', Value)
}
static IID_2 := '{CA7F0E1F-3484-41D1-8C1A-65CD44A63F8D}'
PageRanges {
get => (ComCall(29, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(30, this, 'wstr', Value)
}
PagesPerSide {
get => (ComCall(31, this, 'int*', &value := 0), value)
set => ComCall(32, this, 'int', Value)
}
Copies {
get => (ComCall(33, this, 'int*', &value := 0), value)
set => ComCall(34, this, 'int', Value)
}
Collation {
get => (ComCall(35, this, 'int*', &value := 0), value)
set => ComCall(36, this, 'int', Value)
}
ColorMode {
get => (ComCall(37, this, 'int*', &value := 0), value)
set => ComCall(38, this, 'int', Value)
}
Duplex {
get => (ComCall(39, this, 'int*', &value := 0), value)
set => ComCall(40, this, 'int', Value)
}
MediaSize {
get => (ComCall(41, this, 'int*', &value := 0), value)
set => ComCall(42, this, 'int', Value)
}
PrinterName {
get => (ComCall(43, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(44, this, 'wstr', Value)
}
}
class ProcessExtendedInfo extends WebView2.Base {
static IID := '{af4c4c2e-45db-11ee-be56-0242ac120002}'
ProcessInfo => (ComCall(3, this, 'ptr*', processInfo := WebView2.ProcessInfo()), processInfo)
AssociatedFrameInfos => (ComCall(3, this, 'ptr*', frames := WebView2.FrameInfoCollection()), frames)
}
class ProcessExtendedInfoCollection extends WebView2.List {
static IID := '{32efa696-407a-11ee-be56-0242ac120002}'
Count => (ComCall(3, this, 'uint*', &count := 0), count)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', processInfo := WebView2.ProcessExtendedInfo()), processInfo)
}
class ProcessInfo extends WebView2.Base {
static IID := '{84FA7612-3F3D-4FBF-889D-FAD000492D72}'
ProcessId => (ComCall(3, this, 'int*', &value := 0), value)
Kind => (ComCall(4, this, 'int*', &kind := 0), kind)
}
class ProcessInfoCollection extends WebView2.List {
static IID := '{402B99CD-A0CC-4FA5-B7A5-51D86A1D2339}'
Count => (ComCall(3, this, 'uint*', &count := 0), count)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', processInfo := WebView2.ProcessInfo()), processInfo)
}
class Profile extends WebView2.Base {
static IID := '{79110ad3-cd5d-4373-8bc3-c60658f17a5f}'
ProfileName => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
IsInPrivateModeEnabled => (ComCall(4, this, 'int*', &value := 0), value)
ProfilePath => (ComCall(5, this, 'ptr*', &value := 0), CoTaskMem_String(value))
DefaultDownloadFolderPath {
get => (ComCall(6, this, 'ptr*', &value := 0), CoTaskMem_String(value))
set => ComCall(7, this, 'wstr', Value)
}
PreferredColorScheme {
get => (ComCall(8, this, 'int*', &value := 0), value)
set => ComCall(9, this, 'int', Value)
}
static IID_2 := '{fa740d4b-5eae-4344-a8ad-74be31925397}'
ClearBrowsingDataAsync(dataKinds) => (ComCall(10, this, 'int', dataKinds, 'ptr', WebView2.AsyncHandler(&p)), p)
ClearBrowsingDataInTimeRangeAsync(dataKinds, startTime, endTime) => (ComCall(11, this, 'int', dataKinds, 'double', startTime, 'double', endTime, 'ptr', WebView2.AsyncHandler(&p)), p)
ClearBrowsingDataAllAsync() => (ComCall(12, this, 'ptr', WebView2.AsyncHandler(&p)), p)
static IID_3 := '{B188E659-5685-4E05-BDBA-FC640E0F1992}'
PreferredTrackingPreventionLevel {
get => (ComCall(13, this, 'int*', &value := 0), value)
set => ComCall(14, this, 'int', Value)
}
static IID_4 := '{8F4ae680-192e-4eC8-833a-21cfadaef628}'
SetPermissionStateAsync(permissionKind, origin, state) => (ComCall(15, this, 'int', permissionKind, 'wstr', origin, 'int', state, 'ptr', WebView2.AsyncHandler(&p)), p)
GetNonDefaultPermissionSettingsAsync() => (ComCall(16, this, 'ptr', WebView2.AsyncHandler(&p, WebView2.PermissionSettingCollectionView)), p)
static IID_5 := '{2EE5B76E-6E80-4DF2-BCD3-D4EC3340A01B}'
CookieManager => (ComCall(17, this, 'ptr*', cookieManager := WebView2.CookieManager()), cookieManager)
static IID_6 := '{BD82FA6A-1D65-4C33-B2B4-0393020CC61B}'
IsPasswordAutosaveEnabled {
get => (ComCall(18, this, 'int*', &value := 0), value)
set => ComCall(19, this, 'int', Value)
}
IsGeneralAutofillEnabled {
get => (ComCall(20, this, 'int*', &value := 0), value)
set => ComCall(21, this, 'int', Value)
}
static IID_7 := '{7b4c7906-a1aa-4cb4-b723-db09f813d541}'
AddBrowserExtensionAsync(extensionFolderPath) => (ComCall(22, this, 'wstr', extensionFolderPath, 'ptr', WebView2.AsyncHandler(&p, WebView2.BrowserExtension)), p)
GetBrowserExtensionsAsync() => (ComCall(23, this, 'ptr', WebView2.AsyncHandler(&p, WebView2.BrowserExtensionList)), p)
static IID_8 := '{fbf70c2f-eb1f-4383-85a0-163e92044011}'
Delete() => ComCall(24, this)
add_Deleted(eventHandler) => (ComCall(25, this, 'ptr', eventHandler, 'int64*', &token := 0), token)
remove_Deleted(token) => ComCall(26, this, 'int64', token)
}
class ProcessFailedEventArgs extends WebView2.Base {
static IID := '{8155a9a4-1474-4a86-8cae-151b0fa6b8ca}'
ProcessFailedKind => (ComCall(3, this, 'int*', &processFailedKind := 0), processFailedKind)
static IID_2 := '{4dab9422-46fa-4c3e-a5d2-41d2071d3680}'
Reason => (ComCall(4, this, 'int*', &reason := 0), reason)
ExitCode => (ComCall(5, this, 'int*', &exitCode := 0), exitCode)
ProcessDescription => (ComCall(6, this, 'ptr*', &processDescription := 0), CoTaskMem_String(processDescription))
FrameInfosForFailedProcess => (ComCall(7, this, 'ptr*', frames := WebView2.FrameInfoCollection()), frames)
static IID_3 := '{ab667428-094d-5fd1-b480-8b4c0fdbdf2f}'
FailureSourceModulePath => (ComCall(8, this, 'ptr*', &value := 0), CoTaskMem_String(value))
}
class RegionRectCollectionView extends WebView2.List {
static IID := '{333353B8-48BF-4449-8FCC-22697FAF5753}'
Count => (ComCall(3, this, 'uint*', &value := 0), value)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr', value := WebView2.RECT()), value)
}
class SaveAsUIShowingEventArgs extends WebView2.Base {
static IID := '{55902952-0e0d-5aaa-a7d0-e833cdb34f62}'
ContentMimeType => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Cancel {
set => ComCall(4, this, 'int', Value)
get => (ComCall(5, this, 'int*', &value := 0), value)
}
SuppressDefaultDialog {
set => ComCall(6, this, 'int', Value)
get => (ComCall(7, this, 'int*', &value := 0), value)
}
GetDeferral() => (ComCall(8, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
SaveAsFilePath {
set => ComCall(9, this, 'wstr', Value)
get => (ComCall(10, this, 'ptr*', &value := 0), CoTaskMem_String(value))
}
AllowReplace {
set => ComCall(11, this, 'int', Value)
get => (ComCall(12, this, 'int*', &value := 0), value)
}
Kind {
set => ComCall(13, this, 'int', Value)
get => (ComCall(14, this, 'int*', &value := 0), value)
}
}
class SaveFileSecurityCheckStartingEventArgs extends WebView2.Base {
static IID := '{cf4ff1d1-5a67-5660-8d63-ef699881ea65}'
CancelSave {
get => (ComCall(3, this, 'int*', &value := 0), value)
set => ComCall(4, this, 'int', Value)
}
DocumentOriginUri => (ComCall(5, this, 'ptr*', &value := 0), CoTaskMem_String(value))
FileExtension => (ComCall(6, this, 'ptr*', &value := 0), CoTaskMem_String(value))
FilePath => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
SuppressDefaultPolicy {
get => (ComCall(8, this, 'int*', &value := 0), value)
set => ComCall(9, this, 'int', Value)
}
GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class ScreenCaptureStartingEventArgs extends WebView2.Base {
static IID := '{892c03fd-aee3-5eba-a1fa-6fd2f6484b2b}'
Cancel {
get => (ComCall(3, this, 'int*', &value := 0), value)
set => ComCall(4, this, 'int', Value)
}
Handled {
get => (ComCall(5, this, 'int*', &value := 0), value)
set => ComCall(6, this, 'int', Value)
}
OriginalSourceFrameInfo => (ComCall(7, this, 'ptr*', value := WebView2.FrameInfo()), value)
GetDeferral() => (ComCall(8, this, 'ptr*', value := WebView2.Deferral()), value)
}
class ScriptDialogOpeningEventArgs extends WebView2.Base {
static IID := '{7390bb70-abe0-4843-9529-f143b31b03d6}'
Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
Kind => (ComCall(4, this, 'int*', &kind := 0), kind)
Message => (ComCall(5, this, 'ptr*', &message := 0), CoTaskMem_String(message))
Accept() => ComCall(6, this)
DefaultText => (ComCall(7, this, 'ptr*', &defaultText := 0), CoTaskMem_String(defaultText))
ResultText {
get => (ComCall(8, this, 'ptr*', &resultText := 0), CoTaskMem_String(resultText))
set => ComCall(9, this, 'wstr', Value)
}
GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class ScriptException extends WebView2.Base {
static IID := '{054DAE00-84A3-49FF-BC17-4012A90BC9FD}'
LineNumber => (ComCall(3, this, 'uint*', &value := 0), value)
ColumnNumber => (ComCall(4, this, 'uint*', &value := 0), value)
Name => (ComCall(5, this, 'ptr*', &value := 0), CoTaskMem_String(value))
Message => (ComCall(6, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ToJson => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
}
class ServerCertificateErrorDetectedEventArgs extends WebView2.Base {
static IID := '{012193ED-7C13-48FF-969D-A84C1F432A14}'
ErrorStatus => (ComCall(3, this, 'int*', &value := 0), value)
RequestUri => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
ServerCertificate => (ComCall(5, this, 'ptr*', value := WebView2.Certificate()), value)
Action {
get => (ComCall(6, this, 'int*', &value := 0), value)
set => ComCall(7, this, 'int', Value)
}
GetDeferral() => (ComCall(8, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
}
class Settings extends WebView2.Base {
static IID := '{e562e4f0-d7fa-43ac-8d71-c05150499f00}'
IsScriptEnabled {
get => (ComCall(3, this, 'int*', &isScriptEnabled := 0), isScriptEnabled)
set => ComCall(4, this, 'int', Value)
}
IsWebMessageEnabled {
get => (ComCall(5, this, 'int*', &isWebMessageEnabled := 0), isWebMessageEnabled)
set => ComCall(6, this, 'int', Value)
}
AreDefaultScriptDialogsEnabled {
get => (ComCall(7, this, 'int*', &areDefaultScriptDialogsEnabled := 0), areDefaultScriptDialogsEnabled)
set => ComCall(8, this, 'int', Value)
}
IsStatusBarEnabled {
get => (ComCall(9, this, 'int*', &isStatusBarEnabled := 0), isStatusBarEnabled)
set => ComCall(10, this, 'int', Value)
}
AreDevToolsEnabled {
get => (ComCall(11, this, 'int*', &areDevToolsEnabled := 0), areDevToolsEnabled)
set => ComCall(12, this, 'int', Value)
}
AreDefaultContextMenusEnabled {
get => (ComCall(13, this, 'int*', &enabled := 0), enabled)
set => ComCall(14, this, 'int', Value)
}
AreHostObjectsAllowed {
get => (ComCall(15, this, 'int*', &allowed := 0), allowed)
set => ComCall(16, this, 'int', Value)
}
IsZoomControlEnabled {
get => (ComCall(17, this, 'int*', &enabled := 0), enabled)
set => ComCall(18, this, 'int', Value)
}
IsBuiltInErrorPageEnabled {
get => (ComCall(19, this, 'int*', &enabled := 0), enabled)
set => ComCall(20, this, 'int', Value)
}
static IID_2 := '{ee9a0f68-f46c-4e32-ac23-ef8cac224d2a}'
UserAgent {
get => (ComCall(21, this, 'ptr*', &userAgent := 0), CoTaskMem_String(userAgent))
set => ComCall(22, this, 'wstr', Value)
}
static IID_3 := '{fdb5ab74-af33-4854-84f0-0a631deb5eba}'
AreBrowserAcceleratorKeysEnabled {
get => (ComCall(23, this, 'int*', &areBrowserAcceleratorKeysEnabled := 0), areBrowserAcceleratorKeysEnabled)
set => ComCall(24, this, 'int', Value)
}
static IID_4 := '{cb56846c-4168-4d53-b04f-03b6d6796ff2}'
IsPasswordAutosaveEnabled {
get => (ComCall(25, this, 'int*', &value := 0), value)
set => ComCall(26, this, 'int', Value)
}
IsGeneralAutofillEnabled {
get => (ComCall(27, this, 'int*', &value := 0), value)
set => ComCall(28, this, 'int', Value)
}
static IID_5 := '{183e7052-1d03-43a0-ab99-98e043b66b39}'
IsPinchZoomEnabled {
get => (ComCall(29, this, 'int*', &enabled := 0), enabled)
set => ComCall(30, this, 'int', Value)
}
static IID_6 := '{11cb3acd-9bc8-43b8-83bf-f40753714f87}'
IsSwipeNavigationEnabled {
get => (ComCall(31, this, 'int*', &enabled := 0), enabled)
set => ComCall(32, this, 'int', Value)
}
static IID_7 := '{488dc902-35ef-42d2-bc7d-94b65c4bc49c}'
HiddenPdfToolbarItems {
get => (ComCall(33, this, 'int*', &hidden_pdf_toolbar_items := 0), hidden_pdf_toolbar_items)
set => ComCall(34, this, 'int', Value)
}
static IID_8 := '{9e6b0e8f-86ad-4e81-8147-a9b5edb68650}'
IsReputationCheckingRequired {
get => (ComCall(35, this, 'int*', &value := 0), value)
set => ComCall(36, this, 'int', Value)
}
static IID_9 := '{0528A73B-E92D-49F4-927A-E547DDDAA37D}'
IsNonClientRegionSupportEnabled {
get => (ComCall(37, this, 'int*', &enabled := 0), enabled)
set => ComCall(38, this, 'int', Value)
}
}
class SharedBuffer extends WebView2.Base {
static IID := '{B747A495-0C6F-449E-97B8-2F81E9D6AB43}'
Size => (ComCall(3, this, 'uint64', &value := 0), value)
Buffer => (ComCall(4, this, 'ptr*', &value := 0), value)
OpenStream() => (ComCall(5, this, 'ptr*', value := WebView2.Stream()), value)
FileMappingHandle => (ComCall(6, this, 'ptr*', &value := 0), value)
Close() => ComCall(7, this)
}
class SourceChangedEventArgs extends WebView2.Base {
static IID := '{31e0e545-1dba-4266-8914-f63848a1f7d7}'
IsNewDocument => (ComCall(3, this, 'int*', &isNewDocument := 0), isNewDocument)
}
class Stream extends WebView2.Base {
ToBuffer() {
DllCall('shlwapi\IStream_Reset', 'ptr', this)
DllCall('shlwapi\IStream_Size', 'ptr', this, 'uint64*', &sz := 0)
DllCall('shlwapi\IStream_Read', 'ptr', this, 'ptr', buf := Buffer(sz), 'uint', sz)
return buf
}
ToString(encoding := 'utf-8') => StrGet(this.ToBuffer(), encoding)
}
class StringCollection extends WebView2.List {
static IID := '{f41f3f8a-bcc3-11eb-8529-0242ac130003}'
Count => (ComCall(3, this, 'uint*', &value := 0), value)
GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', &value := 0), CoTaskMem_String(value))
}
class WebMessageReceivedEventArgs extends WebView2.Base {
static IID := '{0f99a40c-e962-4207-9e92-e3d542eff849}'
Source => (ComCall(3, this, 'ptr*', &source := 0), CoTaskMem_String(source))
WebMessageAsJson => (ComCall(4, this, 'ptr*', &webMessageAsJson := 0), CoTaskMem_String(webMessageAsJson))
TryGetWebMessageAsString() => (ComCall(5, this, 'ptr*', &webMessageAsString := 0), CoTaskMem_String(webMessageAsString))
static IID_2 := '{06fc7ab7-c90c-4297-9389-33ca01cf6d5e}'
AdditionalObjects => (ComCall(6, this, 'ptr*', value := WebView2.ObjectCollectionView()), value)
}
class WebResourceRequest extends WebView2.Base {
static IID := '{97055cd4-512c-4264-8b5f-e3f446cea6a5}'
Uri {
get => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
set => ComCall(4, this, 'wstr', Value)
}
Method {
get => (ComCall(5, this, 'ptr*', &method := 0), CoTaskMem_String(method))
set => ComCall(6, this, 'wstr', Value)
}
Content {
get => (ComCall(7, this, 'ptr*', content := WebView2.Stream()), content)
set => ComCall(8, this, 'ptr', Value)
}
Headers => (ComCall(9, this, 'ptr*', headers := WebView2.HttpRequestHeaders()), headers)
}
class WebResourceRequestedEventArgs extends WebView2.Base {
static IID := '{453e667f-12c7-49d4-be6d-ddbe7956f57a}'
Request => (ComCall(3, this, 'ptr*', request := WebView2.WebResourceRequest()), request)
Response {
get => (ComCall(4, this, 'ptr*', response := WebView2.WebResourceResponse()), response)
set => ComCall(5, this, 'ptr', Value)
}
GetDeferral() => (ComCall(6, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
ResourceContext => (ComCall(7, this, 'int*', &context := 0), context)
static IID_2 := '{9C562C24-B219-4D7F-92F6-B187FBBADD56}'
RequestedSourceKind => (ComCall(8, this, 'int*', &requestedSourceKind := 0), requestedSourceKind)
}
class WebResourceResponse extends WebView2.Base {
static IID := '{aafcc94f-fa27-48fd-97df-830ef75aaec9}'
Content {
get => (ComCall(3, this, 'ptr*', content := WebView2.Stream()), content)
set => ComCall(4, this, 'ptr', Value)
}
Headers => (ComCall(5, this, 'ptr*', headers := WebView2.HttpResponseHeaders()), headers)
StatusCode {
get => (ComCall(6, this, 'int*', &statusCode := 0), statusCode)
set => ComCall(7, this, 'int', Value)
}
ReasonPhrase {
get => (ComCall(8, this, 'ptr*', &reasonPhrase := 0), CoTaskMem_String(reasonPhrase))
set => ComCall(9, this, 'wstr', Value)
}
}
class WebResourceResponseReceivedEventArgs extends WebView2.Base {
static IID := '{D1DB483D-6796-4B8B-80FC-13712BB716F4}'
Request => (ComCall(3, this, 'ptr*', request := WebView2.WebResourceRequest()), request)
Response => (ComCall(4, this, 'ptr*', response := WebView2.WebResourceResponseView()), response)
}
class WebResourceResponseView extends WebView2.Base {
static IID := '{79701053-7759-4162-8F7D-F1B3F084928D}'
Headers => (ComCall(3, this, 'ptr*', headers := WebView2.HttpResponseHeaders()), headers)
StatusCode => (ComCall(4, this, 'int*', &statusCode := 0), statusCode)
ReasonPhrase => (ComCall(5, this, 'ptr*', &reasonPhrase := 0), CoTaskMem_String(reasonPhrase))
GetContentAsync() => (ComCall(6, this, 'ptr', WebView2.AsyncHandler(&p, WebView2.Stream)), p)
}
class WindowFeatures extends WebView2.Base {
static IID := '{5eaf559f-b46e-4397-8860-e422f287ff1e}'
HasPosition => (ComCall(3, this, 'int*', &value := 0), value)
HasSize => (ComCall(4, this, 'int*', &value := 0), value)
Left => (ComCall(5, this, 'uint*', &value := 0), value)
Top => (ComCall(6, this, 'uint*', &value := 0), value)
Height => (ComCall(7, this, 'uint*', &value := 0), value)
Width => (ComCall(8, this, 'uint*', &value := 0), value)
ShouldDisplayMenuBar => (ComCall(9, this, 'int*', &value := 0), value)
ShouldDisplayStatus => (ComCall(10, this, 'int*', &value := 0), value)
ShouldDisplayToolbar => (ComCall(11, this, 'int*', &value := 0), value)
ShouldDisplayScrollBars => (ComCall(12, this, 'int*', &value := 0), value)
}
class PHYSICAL_KEY_STATUS extends Buffer {
__New() => super.__New(24)
RepeatCount {
get => NumGet(this, 'uint')
set => NumPut('uint', Value, this)
}
ScanCode {
get => NumGet(this, 4, 'uint')
set => NumPut('uint', Value, this, 4)
}
IsExtendedKey {
get => NumGet(this, 8, 'int')
set => NumPut('int', Value, this, 8)
}
IsMenuKeyDown {
get => NumGet(this, 12, 'int')
set => NumPut('int', Value, this, 12)
}
WasKeyDown {
get => NumGet(this, 16, 'int')
set => NumPut('int', Value, this, 16)
}
IsKeyReleased {
get => NumGet(this, 20, 'int')
set => NumPut('int', Value, this, 20)
}
}
class RECT extends Buffer {
__New() => super.__New(16)
left {
get => NumGet(this, 'int')
set => NumPut('int', Value, this)
}
top {
get => NumGet(this, 4, 'int')
set => NumPut('int', Value, this, 4)
}
right {
get => NumGet(this, 8, 'int')
set => NumPut('int', Value, this, 8)
}
bottom {
get => NumGet(this, 12, 'int')
set => NumPut('int', Value, this, 12)
}
}
static BOUNDS_MODE := { USE_RAW_PIXELS: 0, USE_RASTERIZATION_SCALE: 1 }
static BROWSER_PROCESS_EXIT_KIND := { NORMAL: 0, FAILED: 1 }
static BROWSING_DATA_KINDS := { FILE_SYSTEMS: (1 << 0), INDEXED_DB: (1 << 1), LOCAL_STORAGE: (1 << 2), WEB_SQL: (1 << 3), CACHE_STORAGE: (1 << 4), ALL_DOM_STORAGE: (1 << 5), COOKIES: (1 << 6), ALL_SITE: (1 << 7), DISK_CACHE: (1 << 8), DOWNLOAD_HISTORY: (1 << 9), GENERAL_AUTOFILL: (1 << 10), PASSWORD_AUTOSAVE: (1 << 11), BROWSING_HISTORY: (1 << 12), SETTINGS: (1 << 13), ALL_PROFILE: (1 << 14), SERVICE_WORKERS: (1 << 15) }
static CAPTURE_PREVIEW_IMAGE_FORMAT := { PNG: 0, JPEG: 1 }
static CHANNEL_SEARCH_KIND := { MOST_STABLE: 0, LEAST_STABLE: 1 }
static CLIENT_CERTIFICATE_KIND := { SMART_CARD: 0, PIN: 1, OTHER: 2 }
static CONTEXT_MENU_ITEM_KIND := { COMMAND: 0, CHECK_BOX: 1, RADIO: 2, SEPARATOR: 3, SUBMENU: 4 }
static CONTEXT_MENU_TARGET_KIND := { PAGE: 0, IMAGE: 1, SELECTED_TEXT: 2, AUDIO: 3, VIDEO: 4 }
static COOKIE_SAME_SITE_KIND := { NONE: 0, LAX: 1, STRICT: 2 }
static DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT := { TOP_LEFT: 0, TOP_RIGHT: 1, BOTTOM_LEFT: 2, BOTTOM_RIGHT: 3 }
static DOWNLOAD_INTERRUPT_REASON := { NONE: 0, FILE_FAILED: 1, FILE_ACCESS_DENIED: 2, FILE_NO_SPACE: 3, FILE_NAME_TOO_LONG: 4, FILE_TOO_LARGE: 5, FILE_MALICIOUS: 6, FILE_TRANSIENT_ERROR: 7, FILE_BLOCKED_BY_POLICY: 8, FILE_SECURITY_CHECK_FAILED: 9, FILE_TOO_SHORT: 10, FILE_HASH_MISMATCH: 11, NETWORK_FAILED: 12, NETWORK_TIMEOUT: 13, NETWORK_DISCONNECTED: 14, NETWORK_SERVER_DOWN: 15, NETWORK_INVALID_REQUEST: 16, SERVER_FAILED: 17, SERVER_NO_RANGE: 18, SERVER_BAD_CONTENT: 19, SERVER_UNAUTHORIZED: 20, SERVER_CERTIFICATE_PROBLEM: 21, SERVER_FORBIDDEN: 22, SERVER_UNEXPECTED_RESPONSE: 23, SERVER_CONTENT_LENGTH_MISMATCH: 24, SERVER_CROSS_ORIGIN_REDIRECT: 25, USER_CANCELED: 26, USER_SHUTDOWN: 27, USER_PAUSED: 28, DOWNLOAD_PROCESS_CRASHED: 29 }
static DOWNLOAD_STATE := { IN_PROGRESS: 0, INTERRUPTED: 1, COMPLETED: 2 }
static FAVICON_IMAGE_FORMAT := { PNG: 0, JPEG: 1 }
static FILE_SYSTEM_HANDLE_KIND := { FILE: 0, DIRECTORY: 1 }
static FILE_SYSTEM_HANDLE_PERMISSION := { READ_ONLY: 0, READ_WRITE: 1 }
static FRAME_KIND := { UNKNOWN: 0, MAIN_FRAME: 1, IFRAME: 2, EMBED: 3, OBJECT: 4 }
static HOST_RESOURCE_ACCESS_KIND := { DENY: 0, ALLOW: 1, DENY_CORS: 2 }
static KEY_EVENT_KIND := { KEY_DOWN: 0, KEY_UP: 1, SYSTEM_KEY_DOWN: 2, SYSTEM_KEY_UP: 3 }
static MEMORY_USAGE_TARGET_LEVEL := { NORMAL: 0, LOW: 1 }
static MOUSE_EVENT_KIND := { HORIZONTAL_WHEEL: 0x20e, LEFT_BUTTON_DOUBLE_CLICK: 0x203, LEFT_BUTTON_DOWN: 0x201, LEFT_BUTTON_UP: 0x202, LEAVE: 0x2a3, MIDDLE_BUTTON_DOUBLE_CLICK: 0x209, MIDDLE_BUTTON_DOWN: 0x207, MIDDLE_BUTTON_UP: 0x208, MOVE: 0x200, RIGHT_BUTTON_DOUBLE_CLICK: 0x206, RIGHT_BUTTON_DOWN: 0x204, RIGHT_BUTTON_UP: 0x205, WHEEL: 0x20a, X_BUTTON_DOUBLE_CLICK: 0x20d, X_BUTTON_DOWN: 0x20b, X_BUTTON_UP: 0x20c, NON_CLIENT_RIGHT_BUTTON_DOWN: 0xa4, NON_CLIENT_RIGHT_BUTTON_UP: 0xa5 }
static MOUSE_EVENT_VIRTUAL_KEYS := { NONE: 0, LEFT_BUTTON: 0x1, RIGHT_BUTTON: 0x2, SHIFT: 0x4, CONTROL: 0x8, MIDDLE_BUTTON: 0x10, X_BUTTON1: 0x20, X_BUTTON2: 0x40 }
static MOVE_FOCUS_REASON := { PROGRAMMATIC: 0, NEXT: 1, PREVIOUS: 2 }
static NAVIGATION_KIND := { RELOAD: 0, BACK_OR_FORWARD: 1, NEW_DOCUMENT: 2 }
static NON_CLIENT_REGION_KIND := { NOWHERE: 0, CLIENT: 1, CAPTION: 2, MINIMIZE: 8, MAXIMIZE: 9, LOSE: 20 }
static PDF_TOOLBAR_ITEMS := { ITEMS_NONE: 0, ITEMS_SAVE: 0x1, ITEMS_PRINT: 0x2, ITEMS_SAVE_AS: 0x4, ITEMS_ZOOM_IN: 0x8, ITEMS_ZOOM_OUT: 0x10, ITEMS_ROTATE: 0x20, ITEMS_FIT_PAGE: 0x40, ITEMS_PAGE_LAYOUT: 0x80, ITEMS_BOOKMARKS: 0x100, ITEMS_PAGE_SELECTOR: 0x200, ITEMS_SEARCH: 0x400, ITEMS_FULL_SCREEN: 0x800, ITEMS_MORE_SETTINGS: 0x1000 }
static PERMISSION_KIND := { UNKNOWN_PERMISSION: 0, MICROPHONE: 1, CAMERA: 2, GEOLOCATION: 3, NOTIFICATIONS: 4, OTHER_SENSORS: 5, CLIPBOARD_READ: 6, MULTIPLE_AUTOMATIC_DOWNLOADS: 7, FILE_READ_WRITE: 8, AUTOPLAY: 9, LOCAL_FONTS: 10, MIDI_SYSTEM_EXCLUSIVE_MESSAGES: 11, WINDOW_MANAGEMENT: 12 }
static PERMISSION_STATE := { DEFAULT: 0, ALLOW: 1, DENY: 2 }
static POINTER_EVENT_KIND := { ACTIVATE: 0x24b, DOWN: 0x246, ENTER: 0x249, LEAVE: 0x24a, UP: 0x247, UPDATE: 0x245 }
static PREFERRED_COLOR_SCHEME := { AUTO: 0, LIGHT: 1, DARK: 2 }
static PRINT_COLLATION := { DEFAULT: 0, COLLATED: 1, UNCOLLATED: 2 }
static PRINT_COLOR_MODE := { DEFAULT: 0, COLOR: 1, GRAYSCALE: 2 }
static PRINT_DIALOG_KIND := { BROWSER: 0, SYSTEM: 1 }
static PRINT_DUPLEX := { DEFAULT: 0, ONE_SIDED: 1, TWO_SIDED_LONG_EDGE: 2, TWO_SIDED_SHORT_EDGE: 3 }
static PRINT_MEDIA_SIZE := { DEFAULT: 0, CUSTOM: 1 }
static PRINT_ORIENTATION := { PORTRAIT: 0, LANDSCAPE: 1 }
static PRINT_STATUS := { SUCCEEDED: 0, PRINTER_UNAVAILABLE: 1, OTHER_ERROR: 2 }
static PROCESS_FAILED_KIND := { BROWSER_PROCESS_EXITED: 0, RENDER_PROCESS_EXITED: 1, RENDER_PROCESS_UNRESPONSIVE: 2, FRAME_RENDER_PROCESS_EXITED: 3, UTILITY_PROCESS_EXITED: 4, SANDBOX_HELPER_PROCESS_EXITED: 5, GPU_PROCESS_EXITED: 6, PPAPI_PLUGIN_PROCESS_EXITED: 7, PPAPI_BROKER_PROCESS_EXITED: 8, UNKNOWN_PROCESS_EXITED: 9 }
static PROCESS_FAILED_REASON := { UNEXPECTED: 0, UNRESPONSIVE: 1, TERMINATED: 2, CRASHED: 3, LAUNCH_FAILED: 4, OUT_OF_MEMORY: 5, PROFILE_DELETED: 6 }
static PROCESS_KIND := { BROWSER: 0, RENDERER: 1, UTILITY: 2, SANDBOX_HELPER: 3, GPU: 4, PPAPI_PLUGIN: 5, PPAPI_BROKER: 6 }
static RELEASE_CHANNELS := { NONE: 0, STABLE: 1, BETA: 2, DEV: 4, CANARY: 8 }
static SAVE_AS_KIND := { DEFAULT: 0, HTML_ONLY: 1, SINGLE_FILE: 2, COMPLETE: 3 }
static SAVE_AS_UI_RESULT := { SUCCESS: 0, INVALID_PATH: 1, FILE_ALREADY_EXISTS: 2, KIND_NOT_SUPPORTED: 3, CANCELLED: 4 }
static SCRIPT_DIALOG_KIND := { ALERT: 0, CONFIRM: 1, PROMPT: 2, BEFOREUNLOAD: 3 }
static SCROLLBAR_STYLE := { DEFAULT: 0, FLUENT_OVERLAY: 1 }
static SERVER_CERTIFICATE_ERROR_ACTION := { ALWAYS_ALLOW: 0, CANCEL: 1, DEFAULT: 2 }
static SHARED_BUFFER_ACCESS := { READ_ONLY: 0, READ_WRITE: 1 }
static TEXT_DIRECTION_KIND := { DEFAULT: 0, LEFT_TO_RIGHT: 1, RIGHT_TO_LEFT: 2 }
static TRACKING_PREVENTION_LEVEL := { NONE: 0, BASIC: 1, BALANCED: 2, STRICT: 3 }
static WEB_ERROR_STATUS := { UNKNOWN: 0, CERTIFICATE_COMMON_NAME_IS_INCORRECT: 1, CERTIFICATE_EXPIRED: 2, CLIENT_CERTIFICATE_CONTAINS_ERRORS: 3, CERTIFICATE_REVOKED: 4, CERTIFICATE_IS_INVALID: 5, SERVER_UNREACHABLE: 6, TIMEOUT: 7, ERROR_HTTP_INVALID_SERVER_RESPONSE: 8, CONNECTION_ABORTED: 9, CONNECTION_RESET: 10, DISCONNECTED: 11, CANNOT_CONNECT: 12, HOST_NAME_NOT_RESOLVED: 13, OPERATION_CANCELED: 14, REDIRECT_FAILED: 15, UNEXPECTED_ERROR: 16, VALID_AUTHENTICATION_CREDENTIALS_REQUIRED: 17, VALID_PROXY_AUTHENTICATION_REQUIRED: 18 }
static WEB_RESOURCE_CONTEXT := { ALL: 0, DOCUMENT: 1, STYLESHEET: 2, IMAGE: 3, MEDIA: 4, FONT: 5, SCRIPT: 6, XML_HTTP_REQUEST: 7, FETCH: 8, TEXT_TRACK: 9, EVENT_SOURCE: 10, WEBSOCKET: 11, MANIFEST: 12, SIGNED_EXCHANGE: 13, PING: 14, CSP_VIOLATION_REPORT: 15, OTHER: 16 }
static WEB_RESOURCE_REQUEST_SOURCE_KINDS := { NONE: 0, DOCUMENT: 1, SHARED_WORKER: 2, SERVICE_WORKER: 4, ALL: 0Xffffffff }
}
CoTaskMem_String(ptr) {
s := StrGet(ptr), DllCall('ole32\CoTaskMemFree', 'ptr', ptr)
return s
}
CrusadersCreateSelector() {
for name in ["ChallengeState.ini","Guides.ini"]
CrusadersState.Path(A_ScriptDir,name)
CrusadersCatalog.MigrateMansion(A_ScriptDir "\Settings\Configs",A_ScriptDir "\Settings.ini")
AADungeons.EnsureConfigs(A_ScriptDir "\Settings\Configs")
return CrusadersSelector()
}
CrusadersJsonValue(value) {
if !IsObject(value)
return value
result := value is Array ? [] : Map()
if value is Array {
for item in value
result.Push(CrusadersJsonValue(item))
} else if value is Map {
for key, item in value
result[key] := CrusadersJsonValue(item)
} else {
for key, item in value.OwnProps()
result[key] := CrusadersJsonValue(item)
}
return result
}
class CrusadersState {
static Path(root, name) {
if name != "ChallengeState.ini" && name != "AAChallenges.ini" && name != "Guides.ini"
throw Error("Unknown internal state file")
directory := root "\Other\State", path := directory "\" name
CrusadersConfigCodes.SafeTarget(directory)
DirCreate(directory)
previous := root "\Settings\" name
if FileExist(previous) && !FileExist(path) {
CrusadersConfigCodes.SafeTarget(directory)
DirCreate(directory)
FileMove(previous,path)
}
return path
}
}
class CrusadersInterfaceAssets {
static Files := ["GuideImages\Planet-Greenie-Overview.png", "aa.css", "GuideImages\Anime-Adventures-Settings.png", "index.html", "style.css", "compact.css", "runtime.css", "runtime.js", "guides.js", "guides.css",
"updater.js", "updater.css", "lucide.js", "sortable.js", "LICENSE-LUCIDE.txt", "LICENSE-SORTABLE.txt",
"GuideImages\Roblox-Settings.png",
"GuideImages\Windows-Display.png", "GuideImages\Discord-Overlay.png", "GuideImages\NVIDIA-Color.png",
"GuideImages\NVIDIA-3D.png", "GuideImages\Discord-Token.png", "GuideImages\Discord-Installation.png",
"GuideImages\Discord-Copy-User-ID.png", "GuideImages\Discord-Copy-Channel-ID.png", "GuideImages\Macro-Connection.png"]
static Fingerprint(path) => CrusadersConfigCodes.HashBytes(FileRead(path, "RAW"))
static Valid(directory, identity, installer) {
try {
json := FileRead(directory "\assets.json", "UTF-8"), manifest := Jxon_Load(&json)
if !(manifest is Map) || manifest.Get("identity", "") != identity
|| !(manifest.Get("files", 0) is Map) || manifest["files"].Count != this.Files.Length
return false
for name in this.Files
if !manifest["files"].Has(name) || this.Fingerprint(directory "\" name) != manifest["files"][name]
return false
return this.Fingerprint(installer) = manifest.Get("installer", "") && installer != ""
} catch Error {
return false
}
}
static Seal(directory, identity, installer := "") {
files := Map()
for name in this.Files
files[name] := this.Fingerprint(directory "\" name)
json := Jxon_Dump(Map("identity", identity, "files", files, "installer", (installer != "") ? this.Fingerprint(installer) : ""))
marker := directory "\assets.json", temporary := CrusadersStorage.Temporary(marker)
previous := FileExist(marker) ? FileRead(marker) : ""
try {
FileAppend(json, temporary, "UTF-8-RAW")
CrusadersStorage.Commit(temporary, marker, previous)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
}
class CrusadersWebWindow extends CrusadersWindow {
__New() {
this.catalogChecked := 0
this.webReady := false
this.interfaceShown := false
this.interfaceVisible := false
this.webGameLeft := 68
this.webGameTop := 89
this.pageGeneration := 0
this.pageRendered := false
this.uiTest := false
super.__New(true)
global selector
OnMessage(0x20A, selector.wheelHandler, 0)
SplitPath(selector.configRoot,, &guideSettingsRoot)
this.guideSettingsRoot := guideSettingsRoot
this.guidesRequired := selector.preferences["SkipGuideTutorial"] != "1"
OnMessage(0x100, selector.configToolHandler, 0)
try {
interfaceDirectory := this.InterfaceDirectory()
this.ValidateInterfaceDirectory(interfaceDirectory)
} catch Error as err {
super.Restore()
MsgBox("The interface files could not be loaded. Extract the complete release folder and try again.`n`n" err.Message,
"Bayzo's AA Macro v2.2", "Iconx")
ExitApp(1)
}
this.HideNativeControls()
options := {AdditionalBrowserArguments: "--autoplay-policy=no-user-gesture-required" (this.uiTest ? " --remote-debugging-port=9223" : "")}
dataDir := EnvGet("LOCALAPPDATA") "\BayzoAnimeAdventuresMacro\WebView2" (this.uiTest ? "-Test" : "")
try this.controller := this.AwaitController(WebView2.CreateControllerAsync(this.gui.Hwnd, options, dataDir, "",
A_ScriptDir "\Other\WebView2\" (A_PtrSize * 8) "bit\WebView2Loader.dll"))
catch Error as err {
super.Restore()
MsgBox("The interface could not start. Check that Microsoft Edge WebView2 Runtime is installed.`n`n" err.Message,
"Bayzo's AA Macro v2.2", "Iconx")
ExitApp(1)
}
this.controller.as(WebView2.Controller, WebView2.Controller.IID_3)
this.core := this.controller.CoreWebView2.as(WebView2.Core, WebView2.Core.IID_4)
this.controller.DefaultBackgroundColor := 0x1C1918FF
this.ConfigurePixelLayout()
this.core.SetVirtualHostNameToFolderMapping("macro.example", interfaceDirectory, 1)
this.core.SetVirtualHostNameToFolderMapping("assets.macro.example", A_ScriptDir "\Images", 1)
SplitPath(selector.configRoot,,&mediaSettingsDirectory)
this.backgroundRoot := mediaSettingsDirectory "\Themes\Backgrounds"
DirCreate(this.backgroundRoot)
this.core.SetVirtualHostNameToFolderMapping("media.macro.example", this.backgroundRoot, 1)
this.core.AddWebResourceRequestedFilter("https://video.macro.example/*.mp4",0)
this.mediaRequestEvent := this.core.WebResourceRequested(ObjBindMethod(this,"ServeBackgroundVideo"))
this.core.Settings.AreDefaultContextMenusEnabled := false
this.core.Settings.AreDevToolsEnabled := this.uiTest
this.core.Settings.IsZoomControlEnabled := false
this.core.Settings.IsStatusBarEnabled := false
this.messageEvent := this.core.WebMessageReceived(ObjBindMethod(this, "ReceiveMessage"))
this.navigationEvent := this.core.NavigationStarting((sender, args) => args.Cancel := args.Uri != "https://macro.example/index.html")
this.newWindowEvent := this.core.NewWindowRequested((sender, args) => args.Handled := true)
this.downloadEvent := this.core.DownloadStarting((sender, args) => args.Cancel := true)
this.controller.Fill()
this.FitInterfaceToWorkArea(true)
this.controller.Fill()
this.controller.IsVisible := true
this.core.Navigate("https://macro.example/index.html")
this.webTick := ObjBindMethod(this, "PushState")
SetTimer(this.webTick, 500)
this.discord := 0
}
FitInterfaceToWorkArea(center := false) {
AADisplay.UsePhysicalPixels()
monitor := DllCall("MonitorFromWindow","Ptr",this.gui.Hwnd,"UInt",2,"Ptr")
info := Buffer(40,0), NumPut("UInt",40,info)
if !DllCall("GetMonitorInfoW","Ptr",monitor,"Ptr",info)
return false
WinGetPos(&x,&y,,,this.gui)
args := [NumGet(info,20,"Int"),NumGet(info,24,"Int"),NumGet(info,28,"Int"),NumGet(info,32,"Int"),1266,882]
if !center
args.Push(x,y)
bounds := AADisplay.FitBounds(args*)
return !!DllCall("SetWindowPos","Ptr",this.gui.Hwnd,"Ptr",0,
"Int",bounds[1],"Int",bounds[2],"Int",bounds[3],"Int",bounds[4],"UInt",0x214)
}
ConfigurePixelLayout() {
AADisplay.UsePhysicalPixels()
this.controller.ShouldDetectMonitorScaleChanges := false
this.controller.BoundsMode := 0
this.controller.RasterizationScale := 1.0
this.controller.ZoomFactor := 1.0
if !this.HasOwnProp("dpiHandler") {
this.dpiHandler := ObjBindMethod(this,"DisplayChanged")
OnMessage(0x2E0,this.dpiHandler)
}
this.ObserveDisplayScale()
}
ObserveDisplayScale() {
dpi := AADisplay.Dpi(this.gui.Hwnd)
if !this.HasOwnProp("displayDpi") || this.displayDpi != dpi {
this.displayDpi := dpi
this.Log("Windows display scale: " Round(dpi*100/96) "%; using 800 x 600 physical game pixels")
}
}
DisplayChanged(wParam,lParam,msg,hwnd) {
if hwnd != this.gui.Hwnd
return
AADisplay.UsePhysicalPixels()
if lParam
DllCall("SetWindowPos","Ptr",hwnd,"Ptr",0,
"Int",NumGet(lParam,0,"Int"),"Int",NumGet(lParam,4,"Int"),
"Int",0,"Int",0,"UInt",0x215)
this.FitInterfaceToWorkArea()
this.ObserveDisplayScale()
this.controller.Fill()
this.cutoutSignature := ""
this.EnsureGameSize(false)
this.Arrange()
return 0
}
ServeBackgroundVideo(sender,args) {
request := args.Request
environment := this.core.Environment
headers := "Content-Type: video/mp4`r`nAccept-Ranges: bytes`r`nCache-Control: private, max-age=3600`r`nAccess-Control-Allow-Origin: https://macro.example"
try {
if request.Method != "GET" || !RegExMatch(request.Uri,"i)^https://video\.macro\.example/([a-f0-9]{16}\.mp4)$",&match)
throw Error("Invalid media request")
path := this.backgroundRoot "\" match[1]
CrusadersConfigCodes.SafeTarget(path)
size := FileGetSize(path)
if size <= 0 || size > 20*1024*1024
throw Error("Invalid media size")
rangeHeader := ""
try rangeHeader := request.Headers.GetHeader("Range")
try range := CrusadersTheme.MediaRange(rangeHeader,size)
catch Error {
args.Response := environment.CreateWebResourceResponse(0,416,"Range Not Satisfiable",headers "`r`nContent-Range: bytes */" size)
return
}
length := range[2]-range[1]+1
file := FileOpen(path,"r")
try {
file.Pos := range[1], bytes := Buffer(length)
if file.RawRead(bytes,length) != length
throw Error("Incomplete media read")
} finally file.Close()
stream := WebView2.CreateMemStream(bytes,length)
headers .= "`r`nContent-Length: " length
if range[3] = 206
headers .= "`r`nContent-Range: bytes " range[1] "-" range[2] "/" size
args.Response := environment.CreateWebResourceResponse(stream,range[3],range[3]=206?"Partial Content":"OK",headers)
} catch Error {
args.Response := environment.CreateWebResourceResponse(0,404,"Not Found",headers)
}
}
AwaitController(promise) {
deadline := CrusadersRuntime.Tick()+20000, previousCritical := Critical(0)
try {
while !promise.HasOwnProp("status") {
if CrusadersRuntime.Tick()>=deadline
throw TimeoutError("WebView2 initialization timed out.")
Sleep(1)
}
if promise.status="fulfilled"
return promise.result
promise.thrown := true
throw promise.result
} finally Critical(previousCritical)
}
HideNativeControls() {
global selector
if this.HasOwnProp("adaptersHidden") && this.adaptersHidden
return
for control in this.gui {
control.Visible := false
control.Enabled := false
}
selector.grid.Hide()
this.adaptersHidden := true
}
FocusInterface() {
try {
this.controller.MoveFocus(0)
return true
} catch OSError {
return false
}
}
ShowInterface(*) {
previousDelay := A_WinDelay
SetWinDelay(-1)
try this.ShowInterfaceNow()
finally SetWinDelay(previousDelay)
}
ShowInterfaceNow() {
if this.restoring
return
showGame := this.game && WinExist("ahk_id " this.game) && WinGetMinMax("ahk_id " this.game) != -1
if showGame {
WinSetExStyle((this.original.exStyle | 0x40000) & ~0x80, "ahk_id " this.game)
this.SetGameFrame(this.game, true)
}
this.FitInterfaceToWorkArea()
this.interfaceVisible := true
this.Arrange()
this.gui.Show()
if showGame
this.ShowGame(false)
this.FocusInterface()
{
this.ConfigureDiscord()
SetTimer((*) => CrusadersUpdater.Check(this), -100)
}
}
ValidateInterfaceDirectory(directory) {
missing := ""
for name in ["aa.css", "index.html", "style.css", "compact.css", "runtime.css", "guides.css", "updater.css",
"runtime.js", "guides.js", "updater.js", "lucide.js", "sortable.js"] {
path := directory "\" name
if !FileExist(path) || InStr(FileExist(path), "D") || FileGetSize(path) = 0
missing .= (missing = "" ? "" : "`n") name
}
if missing != ""
throw Error("Missing or empty interface files in " directory ":`n" missing)
}
InterfaceDirectory() {
if !A_IsCompiled
return A_ScriptDir "\UI"
identity := CrusadersInterfaceAssets.Fingerprint(A_ScriptFullPath)
directory := EnvGet("LOCALAPPDATA") "\BayzoAnimeAdventuresMacro\UI\" identity
; installer removed (auto-update disabled)
if CrusadersInterfaceAssets.Valid(directory, identity, "")
return directory
DirCreate(directory)
DirCreate(directory "\GuideImages")
FileInstall("UI\GuideImages\Planet-Greenie-Overview.png", directory "\GuideImages\Planet-Greenie-Overview.png", true)
FileInstall("UI\aa.css", directory "\aa.css", true)
FileInstall("UI\GuideImages\Anime-Adventures-Settings.png", directory "\GuideImages\Anime-Adventures-Settings.png", true)
FileInstall("UI\index.html", directory "\index.html", true)
FileInstall("UI\style.css", directory "\style.css", true)
FileInstall("UI\compact.css", directory "\compact.css", true)
FileInstall("UI\runtime.css", directory "\runtime.css", true)
FileInstall("UI\runtime.js", directory "\runtime.js", true)
FileInstall("UI\guides.js", directory "\guides.js", true)
FileInstall("UI\guides.css", directory "\guides.css", true)
FileInstall("UI\updater.js", directory "\updater.js", true)
FileInstall("UI\updater.css", directory "\updater.css", true)
; UpdateInstaller.ps1 removed (auto-update disabled)
DirCreate(directory "\GuideImages")
FileInstall("UI\GuideImages\Roblox-Settings.png", directory "\GuideImages\Roblox-Settings.png", true)
FileInstall("UI\GuideImages\Windows-Display.png", directory "\GuideImages\Windows-Display.png", true)
FileInstall("UI\GuideImages\Discord-Overlay.png", directory "\GuideImages\Discord-Overlay.png", true)
FileInstall("UI\GuideImages\NVIDIA-Color.png", directory "\GuideImages\NVIDIA-Color.png", true)
FileInstall("UI\GuideImages\NVIDIA-3D.png", directory "\GuideImages\NVIDIA-3D.png", true)
FileInstall("UI\GuideImages\Discord-Token.png", directory "\GuideImages\Discord-Token.png", true)
FileInstall("UI\GuideImages\Discord-Installation.png", directory "\GuideImages\Discord-Installation.png", true)
FileInstall("UI\GuideImages\Discord-Copy-User-ID.png", directory "\GuideImages\Discord-Copy-User-ID.png", true)
FileInstall("UI\GuideImages\Discord-Copy-Channel-ID.png", directory "\GuideImages\Discord-Copy-Channel-ID.png", true)
FileInstall("UI\GuideImages\Macro-Connection.png", directory "\GuideImages\Macro-Connection.png", true)
FileInstall("UI\lucide.js", directory "\lucide.js", true)
FileInstall("UI\LICENSE-LUCIDE.txt", directory "\LICENSE-LUCIDE.txt", true)
FileInstall("UI\sortable.js", directory "\sortable.js", true)
FileInstall("UI\LICENSE-SORTABLE.txt", directory "\LICENSE-SORTABLE.txt", true)
CrusadersInterfaceAssets.Seal(directory, identity, "")
return directory
}
Navigate(page, force := false) {
global selector, testRunning
if !this.HasOwnProp("controller")
return super.Navigate(page, force)
if !force && this.HasOwnProp("guidesRequired") && this.guidesRequired && this.page = "guides" && page != "guides"
return false
if page = this.page
return true
if IsObject(CrusadersDetection.snip)
CrusadersDetection.snip.Cancel()
if !force && testRunning && !CrusadersRuntime.paused {
this.Log("Pause the macro before changing pages")
return false
}
if !selector.Apply()
return false
if page = "gamemodes" && this.configScope != "Current Mode" {
this.scopeField.Choose("Current Mode")
if !this.ScopeChanged()
return false
}
wasPicking := selector.pickMode
selector.pickMode := false
this.pageRendered := !wasPicking && this.CanKeepGameVisible(page)
this.pageGeneration += 1
this.page := page
selector.open := page = "indexes"
previousDelay := A_WinDelay
SetWinDelay(-1)
try {
if wasPicking
this.Arrange()
else {
this.UpdateGameCutout()
this.RaiseGame()
}
} finally SetWinDelay(previousDelay)
this.FocusInterface()
this.UpdateStats()
if page = "recorder" && this.pageRendered && !this.uiTest
SetTimer(ObjBindMethod(this, "FocusRecorderGame"), -30)
return true
}
FocusRecorderGame(*) {
if this.uiTest || this.restoring || this.page != "recorder" || !this.pageRendered || WinGetMinMax(this.gui) = -1
return
if !this.game || !WinExist("ahk_id " this.game)
this.DiscoverGame()
if this.game && WinExist("ahk_id " this.game) && WinGetMinMax("ahk_id " this.game) != -1 {
previousDelay := A_WinDelay
SetWinDelay(-1)
try WinActivate("ahk_id " this.game)
finally SetWinDelay(previousDelay)
}
}
FolderPath(kind) {
folders := Map("configs", A_ScriptDir "\Settings\Configs", "recordings", A_ScriptDir "\Settings\Recordings", "themes", A_ScriptDir "\Settings\Themes")
if !folders.Has(kind)
throw Error("Unknown macro folder.")
return folders[kind]
}
ReadModeName(path, mode) => CrusadersMapName(path, mode)
SnapshotModes() {
modes := [], names := Map()
names.CaseSense := "Off"
for item in this.tasks.items {
path := this.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
if !names.Has(path)
names[path] := this.ReadModeName(path,item.mode)
data := CrusadersJsonValue(item)
data["map"] := names[path]
modes.Push(data)
}
return modes
}
Snapshot() {
global selector
this.stateRevision := this.HasOwnProp("stateRevision") ? this.stateRevision + 1 : 1
revision := this.stateRevision
indexes := []
for number, item in selector.indexes {
data := CrusadersJsonValue(item)
data["number"] := number
indexes.Push(data)
}
if !this.HasOwnProp("catalogCache") || !this.HasOwnProp("catalogChecked") || CrusadersRuntime.Tick() - this.catalogChecked > 10000 {
this.catalogCache := Map()
for mode in ["Story", "Infinite", "Legend Stages", "Raids", "Infinity Mansion", "Dungeons", "Portals", "Events"] {
choices := []
for name in CrusadersCatalog.Maps[mode]
if mode = "Events" || FileExist(CrusadersCatalog.Resolve(selector.configRoot, mode, name, 1))
choices.Push(Map("name", name, "acts", CrusadersCatalog.ActCount(mode, name),
"difficulty", Integer(CrusadersCatalog.HasDifficultySelection(mode, name))))
this.catalogCache[mode] := choices
}
this.catalogChecked := CrusadersRuntime.Tick()
}
modes := this.SnapshotModes()
stats := Map()
for key, control in this.stats
stats[key] := control.Text
halfHourlySeconds := CrusadersChallenges.SecondsUntil()
stats["Half hourly challenge in"] := Integer(selector.preferences["ChallengeEnabled"])
? Format("{:02}:{:02}", halfHourlySeconds // 60, Mod(halfHourlySeconds, 60)) : "Off"
stats["Daily challenge in"] := Integer(selector.preferences["DailyChallengeEnabled"]) ? this.DailyCountdown() : "Off"
image := StrReplace(SubStr(selector.imagePath, StrLen(A_ScriptDir "\Images\") + 1), "\", "/")
return Map("uiModalVisible",Integer(this.HasOwnProp("webModalVisible") && this.webModalVisible),"stateRevision", revision, "version", CrusadersUpdater.Version, "page", this.page, "guidesRequired", selector.preferences["SkipGuideTutorial"] != "1", "overviewRequired", selector.preferences["SkipMacroOverview"] != "1", "pageGeneration", this.pageGeneration, "selected", selector.selected, "indexes", indexes,
"preferences", selector.preferences, "mapName", CrusadersMapName(selector.path, selector.preferences["Mode"]),
"configPath", selector.path, "dungeonMaps", CrusadersCatalog.Maps["Dungeons"], "scope", this.configScope = "Current Mode" && (selector.preferences["Mode"] = "Infinity Mansion" || selector.preferences["Mode"] = "Dungeons") ? selector.preferences["Mode"] : this.configScope, "challengeMaps", CrusadersCatalog.Maps["Challenges"], "castleMaps", CrusadersCatalog.CastleMaps, "mansionMaps", CrusadersCatalog.MansionMaps,
"mapImage", image, "imageVersion", AAInstalledAssets.ImageVersion(selector.imagePath),
"mapWidth", selector.mapWidth, "mapHeight", selector.mapHeight, "picking", Integer(selector.pickMode),
"connected", Integer(!!this.game && !!WinExist("ahk_id " this.game)), "wins", this.wins,
"losses", this.losses, "stats", stats, "batchRuns", this.tasks.run, "taskIndex", this.editingTask,
"modes", modes, "catalog", this.catalogCache, "dioForms", CrusadersSelector.DioForms, "log", this.entries,
"hunterPriority", IniRead(selector.configRoot "\Event\HunterContracts.txt", "Settings", "ContractPriority", CrusadersCatalog.DefaultContractPriority),
"discord", IsObject(this.discord) ? this.discord.PublicState() : Map(),
"detection", CrusadersDetection.State(this.page = "detection"),
"recorder", this.inputRecorder.State(this.page = "indexes" || this.page = "recorder"),
"canUndo", Integer(selector.history.Length > 0), "canRedo", Integer(selector.future.Length > 0))
}
PushState(*) {
if this.restoring || !this.webReady || !this.HasOwnProp("core")
|| WinGetMinMax(this.gui) = -1 || (this.HasOwnProp("pushingState") && this.pushingState)
return
this.pushingState := true
try {
snapshot := this.Snapshot()
revision := snapshot.Has("stateRevision") ? snapshot.Delete("stateRevision") : 0
json := Jxon_Dump(Map("state", snapshot))
if this.HasOwnProp("lastStateJson") && this.lastStateJson = json
return
if revision
snapshot["stateRevision"] := revision
this.core.PostWebMessageAsJson(revision ? Jxon_Dump(Map("state", snapshot)) : json)
this.lastStateJson := json
} catch Error as err {
if !this.restoring && (!this.HasOwnProp("lastPushError") || CrusadersRuntime.Tick()-this.lastPushError>=30000) {
this.lastPushError := CrusadersRuntime.Tick()
this.Log("UI refresh delayed: " err.Message)
}
} finally this.pushingState := false
}
ReceiveMessage(sender, args) {
if args.Source != "https://macro.example/index.html"
return
json := args.WebMessageAsJson
if StrLen(json) > 450000
return
SetTimer(ObjBindMethod(this, "DispatchMessage", json), -1)
}
DispatchMessage(json) {
global selector, testRunning
id := 0
previousDelay := A_WinDelay
try {
message := Jxon_Load(&json)
if message is Map && message.Get("command", "") = "updateAnswer" {
if !this.uiTest
CrusadersUpdater.Respond(message.Get("accept", false), this)
return
}
if !(message is Map) || !message.Has("id") || !message.Has("action") || !message.Has("data")
throw Error("Invalid UI request")
id := message["id"]
if !IsInteger(id) || id < 1 || !(message["data"] is Map)
throw Error("Invalid UI request")
action := message["action"]
if StrLen(json) > 65536
throw Error("UI request is too large")
resultData := 0
SetWinDelay(-1)
data := message["data"]
if testRunning && !CrusadersRuntime.paused && !InStr("|ready|layout|ui.modal|page.rendered|navigate|minimize|close|restart|drag|log.clear|pause|webhook.test|hotkeys.typing|", "|" action "|")
throw Error("Stop the macro before editing configs")
switch action {
case "ready":
this.webReady := true
if this.guidesRequired {
this.Navigate("guides", true)
if !this.interfaceShown {
this.interfaceShown := true
SetTimer(ObjBindMethod(this, "ShowInterface"), -1)
}
}
case "guides.reviewed":
this.UpdateSettings(Map("SkipGuideTutorial", "1"))
this.guidesRequired := false
this.Log("Setup Guides Reviewed")
case "overview.reviewed":
this.UpdateSettings(Map("SkipMacroOverview", "1"))
this.Log("Macro Overview Dismissed")
case "hotkeys.typing":
this.webInputFocused := !!data.Get("active",false)
case "keybinds.check": this.CheckKeybind(data["key"],data["value"])
case "keybinds.resolve": this.ResolveKeybind(data["key"])
case "delays.reset":
defaults := selector.DefaultPreferences(), fields := Map()
for key in CrusadersSelector.DelayKeys
fields[key] := defaults[key]
this.UpdateSettings(fields)
this.Log("Default Delays Restored")
case "keybinds.reset":
defaults := selector.DefaultPreferences(), fields := Map()
for key in CrusadersHotkeys.Names
fields[key] := defaults[key]
this.UpdateSettings(fields)
if this.HasOwnProp("keybindConflicts")
this.keybindConflicts.Clear()
this.Log("Default Keybinds Restored")
case "folder.open":
path := this.FolderPath(data["folder"])
if this.uiTest
throw Error("Opening folders is disabled in UI tests.")
DirCreate(path)
Run('explorer.exe "' path '"')
case "pause": AAExecution.Pause()
case "recorder.save": this.inputRecorder.Save(Trim(data["name"]))
case "recorder.discard":
this.inputRecorder.Cancel()
if this.inputRecorder.playing
throw Error("Wait until playback stops before discarding.")
this.inputRecorder.events := [], this.inputRecorder.preview := []
this.inputRecorder.duration := 0, this.inputRecorder.dirty := false
this.inputRecorder.savedName := "", this.inputRecorder.message := "Ready", this.inputRecorder.revision += 1
case "recorder.open":
if this.uiTest
throw Error("External editors are disabled in UI tests.")
path := CrusadersRecording.Path(data["name"])
if !FileExist(path)
throw Error("Recording not found.")
Run('notepad.exe "' path '"')
case "recorder.load":
if this.inputRecorder.recording || this.inputRecorder.playing || this.inputRecorder.dirty
throw Error("Save or discard the current draft before opening another recording.")
recording := CrusadersRecording.Load(data["name"])
this.inputRecorder.events := recording["events"], this.inputRecorder.preview := recording["events"].Clone()
this.inputRecorder.width := recording["width"], this.inputRecorder.height := recording["height"]
this.inputRecorder.duration := recording["duration"], this.inputRecorder.savedName := data["name"]
this.inputRecorder.diskText := FileRead(CrusadersRecording.Path(data["name"]), "UTF-8")
this.inputRecorder.message := "Loaded " data["name"], this.inputRecorder.revision += 1
case "webhook.test":
if this.uiTest
throw Error("Webhook delivery is disabled in the UI test")
if !CrusadersWebhook.Send(this, "Test", true)
throw Error("Test webhook could not be queued. Check the process log.")
case "log.clear":
this.entries := []
this.lastProcessMessage := ""
case "event.priority": this.SaveHunterPriority(data["contractPriority"])
case "ui.modal":
if !data.Has("visible") || (data["visible"] != 0 && data["visible"] != 1)
throw Error("Invalid modal visibility.")
this.webModalVisible := !!data["visible"]
this.UpdateGameCutout()
if this.webModalVisible
this.FocusInterface()
case "layout":
WinGetClientPos(, , &width, &height, this.gui)
if data["width"] != 800 || data["height"] != 600 || data["x"] < 0 || data["y"] < 0
|| data["x"] + 800 > width || data["y"] + 600 > height
throw Error("The game viewport must be 800 x 600")
this.webGameLeft := Integer(data["x"])
this.webGameTop := Integer(data["y"])
this.Arrange()
if !this.interfaceShown {
this.interfaceShown := true
SetTimer(ObjBindMethod(this, "ShowInterface"), -1)
}
case "navigate":
if !InStr("|main|indexes|gamemodes|detection|recorder|themes|export|guides|settings|", "|" data["page"] "|")
throw Error("Unknown page")
if !this.Navigate(data["page"])
throw Error("Page could not be opened")
case "page.rendered":
if data.Get("page","") = this.page && data.Get("generation",-1) = this.pageGeneration && !this.pageRendered {
this.pageRendered := true
this.Arrange()
if this.page = "recorder" && !this.uiTest
SetTimer(ObjBindMethod(this, "FocusRecorderGame"), -30)
}
case "minimize": this.Minimize()
case "drag": SetTimer(ObjBindMethod(this, "DragWindow"), -1)
case "start":
if data.Get("aprilCancel",false) {
this.CancelAprilStart()
} else {
if this.uiTest
throw Error("Gameplay is disabled in the UI test")
if data.Get("aprilConfirm",false) {
if this.HasOwnProp("aprilStartPending") && this.aprilStartPending
SetTimer(ObjBindMethod(this,"ConfirmAprilStart"),-30)
} else if !this.startConsumed && !this.startQueued {
this.startQueued := true
SetTimer(ObjBindMethod(this,"StartBackend"),-30)
}
}
case "close":
this.core.PostWebMessageAsJson(Jxon_Dump(Map("id",id)))
SetTimer(ObjBindMethod(this, "CloseBackend"), -1)
return
case "start.fix":
if testRunning
throw Error("Stop the macro before fixing its setup.")
number := data.Get("issue",0)
if !this.HasOwnProp("preflightIssues") || !IsInteger(number) || number<1 || number>this.preflightIssues.Length
throw Error("Press Start again to refresh the setup checks.")
if this.preflightQueueSignature != Jxon_Dump(CrusadersJsonValue(this.tasks.items))
throw Error("The mode list changed. Close this popup and press Start again to refresh the checks.")
issue := this.preflightIssues[number]
if issue["mode"] {
this.CheckModeIndex(issue["mode"])
this.LoadTask(issue["mode"])
if issue["page"]="gamemodes"
this.editingTask := issue["mode"]
else {
task := this.tasks.items[issue["mode"]]
if selector.path != this.tasks.root "\" CrusadersCatalog.Folder(task.mode) "\" task.config
throw Error("This mode's config could not be opened. Choose an existing config in Modes.")
}
}
if issue["index"]
selector.SetSelected(issue["index"])
if !this.Navigate(issue["page"])
throw Error("The setup section could not be opened.")
case "restart":
this.core.PostWebMessageAsJson(Jxon_Dump(Map("id",id)))
SetTimer(ObjBindMethod(this, "RestartBackend"), -1)
return
case "index.update": this.UpdateIndex(data)
case "index.select":
this.CheckIndex(data["index"])
selector.SetSelected(data["index"])
case "index.move":
if data.Has("index") && data["index"] != selector.selected
throw Error("Selected index changed before the move. Try again.")
selector.Move(this.CheckDirection(data["direction"]))
case "index.reset": selector.Delete()
case "config.reset":
if !data.Has("path") || data["path"] != selector.path
throw Error("Current config changed. Open Reset Config again.")
selector.ResetConfig()
this.LoadFields()
this.Log("Config Reset: " RegExReplace(selector.path, "^.*\\"))
case "index.copy":
this.CheckIndex(data["source"])
destination := data.Has("destination") ? data["destination"] : selector.selected
this.CheckIndex(destination)
if !selector.TransferIndex(data["source"], destination)
throw Error(selector.status.Text)
case "coordinates.begin":
if !this.BeginCoordinates()
throw Error(selector.status.Text)
case "coordinates.cancel": this.ShowGame(false)
case "coordinates.pick":
if !selector.pickMode
throw Error("Select coordinates first")
if !selector.ApplyLiveCoordinate(data["x"], data["y"], selector.mapWidth, selector.mapHeight)
throw Error(selector.status.Text)
this.ShowGame(false)
case "config.category.preview":
if !AACategoryCopy.Allowed(testRunning,CrusadersRuntime.paused,data.Get("copyCoordinates",false),this.inputRecorder.recording,this.inputRecorder.playing)
throw Error("Stop the macro and recorder before copying configs.")
if !data.Has("path") || data["path"] != selector.path
throw Error("Current config changed. Open Copy Settings again.")
this.pendingCategoryCopy := AACategoryCopy.Preview(selector,false,data.Get("copyCoordinates",false))
plan := this.pendingCategoryCopy, names := []
for row in plan.rows
names.Push(row.name)
resultData := Map("id",plan.id,"path",plan.path,"category",plan.category,"count",plan.rows.Length,"overwrites",plan.overwrites,"names",names,"matching",plan.matching,"copyCoordinates",plan.copyCoordinates)
case "config.category.copy":
if !this.HasOwnProp("pendingCategoryCopy") || !data.Has("id") || data["id"] != this.pendingCategoryCopy.id
throw Error("Copy preview expired. Open Copy Settings again.")
plan := this.pendingCategoryCopy
if !AACategoryCopy.Allowed(testRunning,CrusadersRuntime.paused,plan.copyCoordinates,this.inputRecorder.recording,this.inputRecorder.playing)
throw Error("Pause the macro for Copy Without Coordinates, or stop it for Copy Everything. Stop the recorder first.")
this.DeleteProp("pendingCategoryCopy")
count := AACategoryCopy.Apply(selector,plan)
this.Log("Copied " (plan.copyCoordinates ? "all indexes, coordinates and team" : "index settings and team; destination coordinates and recordings preserved") " to " count " other " plan.category " configs")
resultData := Map("count",count)
case "config.save":
if !selector.Apply()
throw Error(selector.status.Text)
selector.Save()
this.Log("Config saved: " RegExReplace(selector.path, "^.*\\"))
case "undo": selector.Undo()
case "redo": selector.Undo(true)
case "mode.update":
this.UpdateMode(data)
if !this.editingTask
this.Log("Mode Selection Saved | " CrusadersTasks.LogDetails(this.ReadTask(),this.configSelect.Text))
case "mode.new":
SetTimer(this.taskSaveTimer, 0)
this.editingTask := 0
case "mode.select":
this.CheckModeIndex(data["index"])
this.LoadTask(data["index"])
case "mode.move":
index := this.CheckModeIndex(data["index"])
destination := this.tasks.Move(index, this.CheckDirection(data["direction"]))
if this.editingTask = index
this.editingTask := destination
else if this.editingTask = destination
this.editingTask := index
case "mode.delete":
index := this.CheckModeIndex(data["index"])
this.tasks.Delete(index)
if this.editingTask = index
this.editingTask := 0
else if this.editingTask > index
this.editingTask -= 1
case "mode.add":
previousTask := this.editingTask
this.editingTask := 0
try {
if data.Has("mode")
this.UpdateMode(data)
if !this.SaveTask(false)
throw Error(this.modeStatus.Text)
this.editingTask := 0
} catch Error as err {
this.editingTask := previousTask
throw err
}
case "modes.save":
if !this.AutoSaveTask()
throw Error(this.modeStatus.Text)
this.tasks.Save()
case "settings.update": this.UpdateSettings(data["fields"])
case "share.export", "my.publish":
if testRunning || this.inputRecorder.recording || this.inputRecorder.playing
throw Error("Stop the macro and recording before publishing.")
if CrusadersConfigCodes.SharingBusy
throw Error("A config transfer is already in progress.")
CrusadersConfigCodes.SharingBusy := true
try {
resultData := AAMyConfigs.Publish(this.tasks.root,selector,this.tasks,data)
this.Log(resultData.Get("unchanged",false) ? "No config changes to publish; same code copied" : "Published " resultData["name"] " revision " resultData["revision"] "; code copied")
} finally CrusadersConfigCodes.SharingBusy := false
case "my.list":
resultData := AAMyConfigs.Public(this.tasks.root)
case "my.refresh", "my.check", "my.apply", "my.deleteCreated", "my.removePreview", "my.deleteImported", "my.migrate", "my.restorePreview", "my.restoreApply":
if testRunning || this.inputRecorder.recording || this.inputRecorder.playing
throw Error("Stop the macro and recording before updating configs.")
if CrusadersConfigCodes.SharingBusy
throw Error("A config transfer is already in progress.")
CrusadersConfigCodes.SharingBusy := true
try {
if action = "my.migrate" {
if this.uiTest
throw Error("File selection is disabled in UI tests.")
creatorLibraryPath := AAMyConfigs.SharedPath(this.tasks.root)
if creatorLibraryPath = ""
throw Error("The shared creator-library folder is unavailable.")
AAMyConfigs.EnsureLibraryWritable(this.tasks.root)
selectedLibrary := FileSelect(1,creatorLibraryPath,"Load saved MyConfigs.json from Local AppData","My Configs (*.json)")
resultData := selectedLibrary = "" ? AAMyConfigs.Public(this.tasks.root) : AAMyConfigs.MigrateFile(this.tasks.root,selectedLibrary)
resultData["cancelled"] := selectedLibrary = ""
} else if action = "my.restorePreview" {
this.pendingCreatorRestore := 0
plan := AAMyConfigs.RestorePreview(this.tasks.root,data["code"])
this.pendingCreatorRestore := plan, this.pendingCreatorRestoreAt := CrusadersRuntime.Tick()
resultData := plan.Clone(), resultData.Delete("payload"), resultData.Delete("snapshot"), resultData.Delete("root")
} else if action = "my.restoreApply" {
if !this.HasOwnProp("pendingCreatorRestore") || !this.pendingCreatorRestore || CrusadersRuntime.Tick()-this.pendingCreatorRestoreAt>600000
throw Error("Restore preview expired. Preview restore again.")
resultData := AAMyConfigs.Restore(this.tasks.root,selector.settingsFile,this.pendingCreatorRestore,data.Get("replaceExisting",false),ObjBindMethod(this,"Log"))
this.pendingCreatorRestore := 0
selector.Load(), this.LoadFields()
this.Log("Restored creator bundle: " resultData["configs"] " configs and " resultData["recordings"] " recordings")
} else if action = "my.refresh"
resultData := AAMyConfigs.Refresh(this.tasks.root)
else if action = "my.check" {
this.pendingMyUpdate := 0
resultData := AAMyConfigs.Check(this.tasks.root,data["code"])
if !resultData["current"] {
this.pendingMyUpdate := resultData.Clone(), this.pendingMyAt := CrusadersRuntime.Tick()
resultData.Delete("row"), resultData.Delete("payload"), resultData.Delete("fullPayload")
}
} else if action = "my.deleteCreated"
resultData := AAMyConfigs.DeleteCreated(this.tasks.root,data["code"])
else if action = "my.removePreview"
resultData := AAMyConfigs.Removal(this.tasks.root,data["code"])
else if action = "my.deleteImported" {
resultData := AAMyConfigs.DeleteImported(this.tasks.root,data["code"],data.Get("deleteFiles",false))
selector.Load(), this.LoadFields()
} else {
if !this.HasOwnProp("pendingMyUpdate") || !this.pendingMyUpdate || CrusadersRuntime.Tick()-this.pendingMyAt>600000
throw Error("Update preview expired; check again.")
resultData := AAMyConfigs.Apply(this.tasks.root,selector.settingsFile,this.pendingMyUpdate,data.Get("replaceLocal",false),ObjBindMethod(this,"Log"))
this.pendingMyUpdate := 0
selector.Load(), this.LoadFields()
this.Log("Shared configs updated; local mode queue and settings preserved")
}
} finally CrusadersConfigCodes.SharingBusy := false
case "share.list":
SplitPath(this.tasks.root,,&exportSettingsRoot)
resultData := Map("configs",CrusadersConfigCodes.List(this.tasks.root),"recordings",CrusadersRecording.List(exportSettingsRoot "\Recordings"),"themes",[])
for theme in CrusadersTheme.List(exportSettingsRoot "\Themes")
resultData["themes"].Push(theme["name"])
case "share.copy":
if !CrusadersConfigCodes.IsHosted(data["code"])
CrusadersConfigCodes.Decode(data["code"])
A_Clipboard := data["code"]
case "share.preview":
if CrusadersConfigCodes.SharingBusy
throw Error("A config transfer is already in progress.")
CrusadersConfigCodes.SharingBusy := true
try {
if this.HasOwnProp("pendingShareCode")
this.DeleteProp("pendingShareCode")
original := CrusadersConfigCodes.ClipboardCode(data.Has("code") ? data["code"] : A_Clipboard)
this.pendingMySource := 0
if CrusadersConfigCodes.IsHosted(original) {
try this.pendingMySource := AAMyConfigs.Remote(original)
catch Error as err {
if !InStr(err.Message,"404")
throw err
}
}
resolved := this.pendingMySource ? this.pendingMySource["payload"] : CrusadersConfigCodes.Resolve(original)
resultData := CrusadersConfigCodes.Preview(resolved,this.tasks.root)
this.pendingShareCode := resolved
this.pendingShareAt := CrusadersRuntime.Tick()
} finally CrusadersConfigCodes.SharingBusy := false
case "share.import":
if CrusadersConfigCodes.SharingBusy
throw Error("A config transfer is already in progress.")
if this.inputRecorder.recording || this.inputRecorder.playing
throw Error("Stop recording or playback before importing configs")
CrusadersConfigCodes.SharingBusy := true
try {
if !this.HasOwnProp("pendingShareCode") || CrusadersRuntime.Tick()-this.pendingShareAt > 600000
throw Error("Import preview expired. Copy the code and choose Import Config again.")
resolved := this.pendingShareCode
if this.inputRecorder.recording || this.inputRecorder.playing || (testRunning && !CrusadersRuntime.paused)
throw Error("Stop playback and pause the macro before importing configs.")
this.Log("Importing all bundle contents...")
resultData := CrusadersConfigCodes.Import(resolved,this.tasks.root,selector.settingsFile,data.Get("queuePolicy","append"),data.Get("conflict","replace"),data.Get("applySettings",true),ObjBindMethod(this,"Log"))
if this.HasOwnProp("pendingMySource") && this.pendingMySource
AAMyConfigs.Track(this.tasks.root,this.pendingMySource,resolved)
this.pendingMySource := 0
this.DeleteProp("pendingShareCode")
} finally CrusadersConfigCodes.SharingBusy := false
SetTimer(this.taskSaveTimer,0)
this.editingTask := 0
selector.Load()
selector.history := [], selector.future := []
this.tasks := CrusadersTasks(this.tasks.root)
this.LoadFields(), this.RenderTasks(0), this.ApplyRuntimeSettings()
for warning in resultData["warnings"]
this.Log("Config import note: " warning)
this.Log("Config imported - " resultData["configs"] " configs imported; " resultData["recordings"] " recordings")
case "theme.background.choose":
if this.uiTest
throw Error("File selection is disabled in UI tests.")
chosen := FileSelect(1,,"Choose Background","Backgrounds (*.png; *.jpg; *.jpeg; *.gif; *.mp4)")
SplitPath(this.tasks.root,,&themeSettingsDirectory)
resultData := chosen = "" ? Map("cancelled",true) : Map("background",CrusadersTheme.ImportBackground(themeSettingsDirectory "\Themes\Backgrounds",chosen))
case "theme.list":
SplitPath(this.tasks.root,,&themeSettingsDirectory)
resultData := Map("themes",CrusadersTheme.List(themeSettingsDirectory "\Themes"))
case "theme.set", "theme.background.remove", "theme.background.set":
removingBackground := action = "theme.background.remove"
backgroundOnly := removingBackground || action = "theme.background.set"
preset := backgroundOnly ? selector.preferences["ThemePreset"] : data["preset"]
if !InStr("|Default|Rose|Lavender|Mint|Ocean|Amber|Light|Cherry|Blossom|Arctic|High Contrast|Graphite|Custom|", "|" preset "|")
throw Error("Unknown theme")
customTheme := !backgroundOnly && preset = "Custom" ? CrusadersTheme.CustomColors(data["colors"]) : selector.preferences["CustomTheme"]
if !selector.Apply()
throw Error(selector.status.Text)
previousTheme := selector.preferences["ThemePreset"]
previousCustom := selector.preferences["CustomTheme"]
previousName := selector.preferences["CustomThemeName"]
previousBackground := selector.preferences["ThemeBackground"]
themePath := "", themeStored := false
SplitPath(this.tasks.root,,&themeSettingsDirectory)
themeRoot := themeSettingsDirectory "\Themes"
name := !backgroundOnly && preset = "Custom" ? data.Get("name",previousName) : previousName
background := backgroundOnly || preset = "Custom" ? CrusadersTheme.BackgroundOptions(removingBackground ? Map() : data.Get("background",Map())) : Map()
if (backgroundOnly || preset = "Custom") && background["file"] != "" && !FileExist(themeRoot "\Backgrounds\" background["file"])
throw Error("Background file is missing. Choose it again or remove it.")
if preset = "Custom" && name != "" {
themePath := CrusadersTheme.Path(themeRoot,name)
themeExisted := !!FileExist(themePath)
themePrevious := themeExisted ? FileRead(themePath) : ""
}
try {
if themePath != "" {
themeColors := backgroundOnly ? Jxon_Load(&customTheme) : data["colors"]
CrusadersTheme.Store(themeRoot,name,themeColors,background)
themeStored := true
}
selector.preferences["ThemePreset"] := preset
selector.preferences["CustomTheme"] := customTheme
selector.preferences["CustomThemeName"] := name
if backgroundOnly || preset = "Custom"
selector.preferences["ThemeBackground"] := Jxon_Dump(background,0)
selector.Save()
resultData := Map("themes",CrusadersTheme.List(themeRoot))
} catch Error {
selector.preferences["ThemePreset"] := previousTheme
selector.preferences["CustomTheme"] := previousCustom
selector.preferences["CustomThemeName"] := previousName
selector.preferences["ThemeBackground"] := previousBackground
if themeStored {
if themeExisted {
recovery := CrusadersStorage.Temporary(themePath)
FileAppend(themePrevious,recovery,"UTF-8-RAW")
CrusadersStorage.Commit(recovery,themePath,FileRead(themePath))
} else FileDelete(themePath)
}
throw
}
try {
savedBackground := selector.preferences["ThemeBackground"]
CrusadersTheme.CleanupBackgrounds(themeRoot,savedBackground="" ? Map() : Jxon_Load(&savedBackground))
}
case "discord.portal": Run("https://discord.com/developers/applications")
case "discord.test": this.discord.TestConnection()
case "detection.save", "detection.capture", "detection.replace", "detection.test", "detection.reset", "detection.accept", "detection.discard", "detection.cancel":
CrusadersDetection.Action(SubStr(action, 11), data)
case "config.scope":
if data["scope"] != "Current Mode" && data["scope"] != "Challenges" && data["scope"] != "Infinity Castle" && data["scope"] != "Infinity Mansion" && data["scope"] != "Dungeons"
throw Error("Unknown config source")
this.scopeField.Choose(data["scope"])
if !this.ScopeChanged()
throw Error("Config could not be opened")
case "config.challenge":
if this.configScope = "Current Mode" && (selector.preferences["Mode"] = "Infinity Mansion" || selector.preferences["Mode"] = "Dungeons") {
this.scopeConfigField.Delete()
this.scopeConfigField.Add(CrusadersCatalog.ConfigMaps(selector.preferences["Mode"]))
}
this.scopeConfigField.Choose(data["map"])
if !this.ScopeConfigChanged()
throw Error("Challenge config could not be opened")
case "config.team":
if selector.preferences["Mode"] = "Dungeons"
throw Error("Use the universal Team in Settings > Dungeons.")
if !RegExMatch(data["team"], "^\d+$") || Integer(data["team"]) > 6
throw Error("Team must be between 0 and 6")
oldTeam := selector.preferences["Team"]
try {
selector.preferences["Team"] := data["team"]
selector.Validate()
selector.Save()
this.teamField.Value := data["team"]
} catch Error as err {
selector.preferences["Team"] := oldTeam
throw err
}
default: throw Error("Unknown UI command")
}
this.HideNativeControls()
reply := Map("id", id, "state", this.Snapshot())
if IsObject(resultData)
reply["result"] := resultData
this.core.PostWebMessageAsJson(Jxon_Dump(reply))
} catch Error as err {
this.HideNativeControls()
reply := Map("id",id,"error",err.Message)
if IsSet(action) && RegExMatch(action,"^(mode\.|modes\.)")
this.Log("Mode request failed (" action "): " err.Message)
if this.uiTest
reply["error"] .= "`n" err.Stack
this.core.PostWebMessageAsJson(Jxon_Dump(reply))
} finally SetWinDelay(previousDelay)
}
CheckIndex(number) {
if !IsInteger(number) || number < 1 || number > 90
throw Error("Index must be between 1 and 90")
}
DragWindow(*) {
DllCall("ReleaseCapture")
PostMessage(0xA1, 2, 0, this.gui)
}
CheckModeIndex(number) {
if !IsInteger(number) || number < 1 || number > this.tasks.items.Length
throw Error("Select a valid mode")
return number
}
CheckDirection(direction) {
if direction != -1 && direction != 1
throw Error("Invalid move direction")
return direction
}
UpdateIndex(data) {
global selector
this.CheckIndex(data["index"])
if !(data["fields"] is Map)
throw Error("Invalid index fields")
original := selector.indexes[data["index"]]
candidate := original.Clone()
for key, value in data["fields"] {
if key = "beforeStart" || key = "firstRun" || key = "autoUpgrade" || key = "unit" || key = "path" || key = "dioForm" || key = "strongestHistory" || SubStr(key,1,6) = "domain"
throw Error("This toggle was removed from AA indexes.")
if !InStr("|name|slot|upgrade|priority|wave|wait|x|y|unit|path|dioForm|beforeStart|firstRun|autoAbility|autoUpgrade|strongestHistory|domainClash|domainWave|domainWait|domainImmediate|domainAbility|recording|", "|" key "|")
throw Error("Unknown index field")
if key = "slot" && (value = "Left Click" || value = "Right Click")
value := value = "Left Click" ? 7 : 8
if InStr("|name|upgrade|priority|unit|path|dioForm|domainAbility|recording|", "|" key "|")
candidate.%key% := Trim(String(value))
else {
if (key = "x" || key = "y") && value = ""
value := -1
if InStr("|wave|wait|domainWave|domainWait|", "|" key "|") && value = ""
value := 0
if !RegExMatch(value, "^-?\d+$")
throw Error("Use whole numbers for " key)
candidate.%key% := Integer(value)
}
}
if InStr(candidate.name, "`n") || InStr(candidate.name, "`r")
throw Error("Index name must be a single line")
candidate.configured := true
snapshot := selector.Snapshot()
history := selector.history.Clone()
future := selector.future.Clone()
try {
selector.Remember()
selector.indexes[data["index"]] := candidate
selector.LinkCoordinateEdit(original,candidate)
selector.Validate()
selector.Save()
selector.SetSelected(data["index"])
} catch Error as err {
selector.indexes := snapshot
selector.history := history
selector.future := future
throw err
}
}
UpdateMode(data) {
global selector
mode := data["mode"]
if mode = "Challenges"
throw Error("Use the Auto Challenge settings instead of adding Challenges to the mode queue.")
portalName := mode = "Portals" ? AAPortalRoute.ValidateName(data.Get("portalName","")) : ""
name := mode = "Portals" ? "Portals" : data["map"]
act := data["act"] = "Infinite" ? 1 : Integer(RegExReplace(data["act"], "^Act ", ""))
actualMode := mode = "Story" && data["act"] = "Infinite" ? "Infinite" : mode
if !CrusadersCatalog.Maps.Has(mode) || act < 1 || act > CrusadersCatalog.ActCount(mode, name)
throw Error("Invalid mode or act")
if !RegExMatch(data["runs"], "^\d+$") || StrLen(data["runs"]) > 6 || Integer(data["runs"]) < 1 || Integer(data["runs"]) > 100000
throw Error("Runs must be a whole number from 1 to 100000.")
priority := ""
for contract in data["contractPriority"]
priority .= (priority = "" ? "" : "|") contract
priority := CrusadersCatalog.NormalizeContractPriority(priority)
if data["bossRushMode"] != "Traits" && data["bossRushMode"] != "Traitless"
throw Error("Invalid boss rush mode")
if !InStr("|Unit Slot|Damage|Placement Limit|", "|" data["makimaCard"] "|")
throw Error("Invalid card")
this.loadingTask := true
try {
if this.modeSelect.Text != mode {
this.modeSelect.Choose(mode)
this.RefreshConfigs()
}
this.configSelect.Choose(name)
this.RefreshActs(act, actualMode)
target := CrusadersCatalog.Resolve(selector.configRoot, actualMode, name, act)
if selector.path != target && !this.SelectConfig(true)
throw Error(this.modeStatus.Text)
selector.preferences["PortalName"] := portalName
selector.preferences["ContractPriority"] := actualMode = "Event"
? IniRead(target, "Settings", "ContractPriority", CrusadersCatalog.DefaultContractPriority) : priority
this.bossRushTraitsField.Choose(data["bossRushMode"])
this.makimaCardField.Choose(data["makimaCard"])
this.difficultyField.Choose(CrusadersCatalog.EffectiveDifficulty(actualMode, name, data["difficulty"]))
this.runsField.Value := data["runs"]
} finally this.loadingTask := false
if !this.SaveModes()
throw Error(this.modeStatus.Text)
}
UpdateSettings(fields) {
for key,value in fields
if !this.settingsFields.Has(key)
throw Error("Unknown setting: " key)
for key, value in fields {
control := this.settingsFields[key]
if control.Type = "DDL" || control.Type = "DropDownList"
control.Choose(value)
else control.Value := value
}
if !this.SaveSettings() {
this.LoadFields()
throw Error(this.settingsStatus.Text)
}
}
SaveHunterPriority(names) {
global selector
if !(names is Array) || names.Length != 6
throw Error("Choose all six Hunter contracts")
priority := ""
for name in names
priority .= (priority = "" ? "" : "|") name
normalized := CrusadersCatalog.NormalizeContractPriority(priority)
if normalized != priority
throw Error("Contract priority must contain each contract once")
path := selector.configRoot "\Event\HunterContracts.txt"
target := selector.path = path ? selector : CrusadersSelector(path, "", selector.settingsFile, selector.imageRoot)
target.preferences["ContractPriority"] := priority
target.Save()
selector.settingsSource := FileRead(selector.settingsFile)
for task in this.tasks.items
if task.mode = "Event"
task.contractPriority := priority
this.tasks.Save()
this.Log("Hunter contract priority saved")
}
BeginCoordinates() {
global selector
if !selector.EnsureMapDimensions() {
selector.status.Text := "The saved map image is missing or unreadable. Use F5 to replace it."
return false
}
selector.pickMode := true
this.Arrange()
WinActivate(this.gui)
return true
}
CanPickCoordinates(*) => false
CanKeepGameVisible(page) {
coveredPages := "|settings|themes|export|guides|"
return this.pageRendered && !InStr(coveredPages, "|" this.page "|")
&& !InStr(coveredPages, "|" page "|")
}
SyncPageGameClip() {
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
global selector
if !this.game || !WinExist("ahk_id " this.game)
return
showGame := (!this.HasOwnProp("pageRendered") || this.pageRendered)
&& this.page != "settings" && this.page != "themes" && this.page != "export" && this.page != "guides" && !selector.pickMode
&& !(this.HasOwnProp("webModalVisible") && this.webModalVisible)
region := DllCall("CreateRectRgn", "Int", this.offsetX, "Int", this.offsetY,
"Int", this.offsetX + (showGame ? Min(this.gameWidth,800) : 0),
"Int", this.offsetY + (showGame ? Min(this.gameHeight,600) : 0), "Ptr")
current := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
try {
if DllCall("GetWindowRgn", "Ptr", this.game, "Ptr", current)
&& DllCall("EqualRgn", "Ptr", current, "Ptr", region)
return
if DllCall("SetWindowRgn", "Ptr", this.game, "Ptr", region, "Int", true)
region := 0
} finally {
DllCall("DeleteObject", "Ptr", current)
if region
DllCall("DeleteObject", "Ptr", region)
}
}
UpdateGameCutout() {
AADisplay.UsePhysicalPixels()
global selector
if this.restoring || WinGetMinMax(this.gui) = -1
return
WinGetPos(&outerX, &outerY, &width, &height, this.gui)
WinGetClientPos(&clientX, &clientY, , , this.gui)
this.SyncPageGameClip()
cutout := this.pageRendered && !(this.HasOwnProp("webModalVisible") && this.webModalVisible) && this.page != "settings" && this.page != "themes" && this.page != "export" && this.page != "guides" && !selector.pickMode && this.game && WinExist("ahk_id " this.game)
signature := width "|" height "|" (clientX - outerX) "|" (clientY - outerY) "|" cutout "|" this.webGameLeft "|" this.webGameTop
if this.HasOwnProp("cutoutSignature") && this.cutoutSignature = signature
return
region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1, "Int", 16, "Int", 16, "Ptr")
if cutout {
x := clientX - outerX + this.webGameLeft
y := clientY - outerY + this.webGameTop
hole := DllCall("CreateRectRgn", "Int", x, "Int", y, "Int", x + 800, "Int", y + 600, "Ptr")
try DllCall("CombineRgn", "Ptr", region, "Ptr", region, "Ptr", hole, "Int", 4)
finally DllCall("DeleteObject", "Ptr", hole)
}
if !DllCall("SetWindowRgn", "Ptr", this.gui.Hwnd, "Ptr", region, "Int", true)
DllCall("DeleteObject", "Ptr", region)
else
this.cutoutSignature := signature
}
Arrange() {
AADisplay.UsePhysicalPixels()
if this.HasOwnProp("aprilDetached") && this.aprilDetached
return
global selector
if !this.interfaceVisible
return
if this.restoring || WinGetMinMax(this.gui) = -1
return
this.UpdateGameCutout()
if !this.game || !WinExist("ahk_id " this.game)
return
if this.gameResizing || this.fullscreenNormalizing || this.IsGameFullscreen(this.game)
return
if WinGetMinMax("ahk_id " this.game) = -1
return
WinGetClientPos(&left, &top, , , this.gui)
previousDelay := A_WinDelay
SetWinDelay(-1)
try DllCall("SetWindowPos","Ptr",this.game,"Ptr",0,
"Int",left+this.webGameLeft-this.offsetX,"Int",top+this.webGameTop-this.offsetY,
"Int",0,"Int",0,"UInt",0x215)
finally SetWinDelay(previousDelay)
this.SyncPageGameClip()
this.RaiseGame()
}
Sized(wParam, lParam, msg, hwnd) {
AADisplay.UsePhysicalPixels()
if this.restoring
return
super.Sized(wParam, lParam, msg, hwnd)
if hwnd = this.gui.Hwnd && this.HasOwnProp("controller")
try this.core.ExecuteScriptAsync("window.setBackgroundSuspended?.(" (wParam = 1 ? "true" : "false") ")")
if hwnd = this.gui.Hwnd && wParam != 1 && this.HasOwnProp("controller")
this.controller.Fill()
}
Start(*) {
if CrusadersUpdater.pending || CrusadersUpdater.installing
return
if this.startRequested || this.startConsumed
return
if this.webReady {
this.startRequested := true
this.core.ExecuteScriptAsync("window.startMacro()")
}
}
Close(*) {
if this.webReady
this.core.ExecuteScriptAsync("window.closeMacro()")
else super.Close()
}
Restart(*) {
if this.webReady
this.core.ExecuteScriptAsync("window.restartMacro()")
else super.Restart()
}
ConfigureDiscord() {
global selector
if !IsObject(this.discord)
this.discord := CrusadersDiscord(this)
this.discord.Configure(selector.preferences)
if selector.discordCredentialError != "" && selector.preferences["DiscordToken"] = ""
this.discord.SetConnection("Needs Attention", selector.discordCredentialError)
}
StartBackend(*) {
global selector, testRunning
this.startQueued := false, this.startRequested := false
if CrusadersUpdater.pending || CrusadersUpdater.installing
return
if testRunning
return
this.preflightIssues := CrusadersPreflight.Check(this,selector)
this.preflightQueueSignature := Jxon_Dump(CrusadersJsonValue(this.tasks.items))
if this.preflightIssues.Length {
this.Log("Start blocked: " this.preflightIssues.Length " setup problems. Open Fix to resolve each problem, then press Start again.")
for issue in this.preflightIssues
this.Log("Setup: " issue["message"])
if this.webReady
this.core.ExecuteScriptAsync("showPreflight(" Jxon_Dump(this.preflightIssues) ")")
return false
}
super.Start()
}
PauseRun(*) {
if this.HasOwnProp("webReady") && this.webReady
this.core.ExecuteScriptAsync("window.pauseMacro()")
else super.PauseRun()
}
CloseBackend(*) {
previousDelay := A_WinDelay
SetWinDelay(-1)
try super.Close()
finally SetWinDelay(previousDelay)
}
RestartBackend(*) {
previousDelay := A_WinDelay
SetWinDelay(-1)
try super.Restart()
finally SetWinDelay(previousDelay)
}
ReloadProcess() => super.ReloadProcess()
Persist() {
global selector
if !this.webReady
return super.Persist()
if !selector.Apply()
return false
if !FileExist(selector.path)
selector.Save()
return true
}
Restore(reason := "", exitCode := 0) {
previousDelay := A_WinDelay
SetWinDelay(-1)
try this.RestoreNow(reason, exitCode)
finally SetWinDelay(previousDelay)
}
RestoreNow(reason := "", exitCode := 0) {
if this.HasOwnProp("restoreComplete") && this.restoreComplete
return
if IsObject(CrusadersDetection.snip)
CrusadersDetection.snip.Cancel()
this.restoring := true
this.inputRecorder.Cancel()
this.interfaceVisible := false
this.gui.Hide()
CrusadersUpdater.CancelCheck()
CrusadersUpdater.CancelDownload()
super.Restore(reason, exitCode)
if this.HasOwnProp("discord") && IsObject(this.discord)
this.discord.Stop()
if this.HasOwnProp("webTick")
SetTimer(this.webTick, 0)
if this.HasOwnProp("controller")
try this.controller.Close()
}
}
HandleMacroError(err, mode) {
global selector, macroWindow
CrusadersLog("Error: " err.Message)
if IsSet(selector) && selector.HasOwnProp("status")
selector.status.Text := err.Message
return true
}
RunTest(cameraOnly := false) {
AAExecution.Start(cameraOnly)
}
#DllLoad winhttp.dll
class CrusadersCredentials {
static Transform(input, decrypt := false) {
blob := Buffer(2 * A_PtrSize, 0), result := Buffer(2 * A_PtrSize, 0)
NumPut("UInt", input.Size, blob)
NumPut("Ptr", input.Ptr, blob, A_PtrSize)
fn := decrypt ? "CryptUnprotectData" : "CryptProtectData"
if !DllCall("crypt32\" fn, "Ptr", blob, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0,
"UInt", 1, "Ptr", result, "Int")
throw Error("Windows could not unlock or protect the bot token.")
pointer := NumGet(result, A_PtrSize, "Ptr")
try {
bytes := Buffer(NumGet(result, 0, "UInt"))
DllCall("ntdll\RtlMoveMemory", "Ptr", bytes, "Ptr", pointer, "UPtr", bytes.Size)
return bytes
} finally DllCall("LocalFree", "Ptr", pointer)
}
static Encode(value) {
if value = ""
return ""
encrypted := this.Transform(CrusadersWebhook.Bytes(value))
size := 0
flags := 0x40000001
if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", encrypted, "UInt", encrypted.Size,
"UInt", flags, "Ptr", 0, "UInt*", &size)
throw Error("Could not encode protected bot token.")
output := Buffer(size * 2)
if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", encrypted, "UInt", encrypted.Size,
"UInt", flags, "Ptr", output, "UInt*", &size)
throw Error("Could not encode protected bot token.")
return "dpapi:" StrGet(output)
}
static Decode(value) {
if SubStr(value, 1, 6) != "dpapi:"
return value
text := SubStr(value, 7), size := 0
if !DllCall("crypt32\CryptStringToBinaryW", "Str", text, "UInt", 0, "UInt", 1,
"Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0) || size < 1
throw Error("Invalid protected bot token.")
encrypted := Buffer(size)
if !DllCall("crypt32\CryptStringToBinaryW", "Str", text, "UInt", 0, "UInt", 1,
"Ptr", encrypted, "UInt*", &size, "Ptr", 0, "Ptr", 0)
throw Error("Invalid protected bot token.")
decrypted := this.Transform(encrypted, true)
return StrGet(decrypted, decrypted.Size, "UTF-8")
}
}
class CrusadersDiscord {
__New(window) {
this.window := window
this.signature := ""
this.enabled := false
this.socket := 0
this.jobs := []
this.seen := Map()
this.forms := Map()
this.session := ""
this.sequence := -1
this.app := ""
this.guild := ""
this.pollTimer := ObjBindMethod(this, "Poll")
this.connectTimer := ObjBindMethod(this, "Connect")
this.restartTimer := ObjBindMethod(this, "FinishRestart")
this.pendingRestart := false
this.backoff := 5000
this.lastIdentify := -5000
this.heartbeatAt := 0
this.heartbeatInterval := 0
this.awaitingAck := false
this.token := ""
this.channel := ""
this.owner := ""
this.connectionState := "Disabled"
this.connectionMessage := ""
this.testing := false
this.testMessage := ""
this.testFailed := false
this.polling := false
}
Configure(preferences) {
signature := Jxon_Dump([preferences.Get("DiscordBotEnabled", "0"), preferences.Get("DiscordToken", ""),
preferences.Get("DiscordChannel", ""), preferences.Get("DiscordUserId", "")])
if signature = this.signature
return
this.Stop()
this.signature := signature
this.enabled := preferences.Get("DiscordBotEnabled", "0") = "1"
this.token := Trim(preferences["DiscordToken"])
this.channel := preferences["DiscordChannel"]
this.owner := preferences["DiscordUserId"]
if !this.enabled
return
this.SetConnection("Connecting", "Connecting to Discord.")
this.backoff := 5000
SetTimer(this.pollTimer, 100)
SetTimer(this.connectTimer, -100)
}
Stop() {
this.enabled := false
SetTimer(this.pollTimer, 0)
SetTimer(this.connectTimer, 0)
SetTimer(this.restartTimer, 0)
for job in this.jobs
try job.request.Abort()
this.jobs := []
this.forms.Clear()
this.CloseSocket()
this.session := ""
this.app := ""
this.guild := ""
this.pendingRestart := false
this.testing := false
this.testMessage := ""
this.SetConnection("Disabled")
}
SetConnection(state, message := "") {
this.connectionState := state
this.connectionMessage := message
}
PublicState() => Map("state", this.connectionState, "message", this.connectionMessage,
"testing", Integer(this.testing), "testMessage", this.testMessage, "testFailed", Integer(this.testFailed))
TestConnection() {
if this.testing
throw Error("A connection test is already running.")
if this.token = "" || !RegExMatch(this.channel, "^\d{17,20}$") || !RegExMatch(this.owner, "^\d{17,20}$")
throw Error("Fill in your bot token, Discord User ID, and Channel ID first.")
this.testing := true
this.testFailed := false
this.testMessage := "Checking bot token and channel access..."
SetTimer(this.pollTimer, 100)
try this.Request("GET", "/oauth2/applications/@me", "", (data) =>
this.Request("GET", "/channels/" this.channel, "", (channel) => this.TestChannel(channel), false, 0, true), false, 0, true)
catch Error {
this.FinishTest("Connection test could not start. Check your connection and try again.", true)
}
}
TestChannel(channel) {
if channel.Get("guild_id", "") = "" || !InStr("|0|5|", "|" channel.Get("type", -1) "|")
this.FinishTest("Choose a normal server text channel, not a DM, forum, or thread.", true)
else this.FinishTest("Test Passed: bot token is valid and the server channel is accessible.")
}
FinishTest(message, failed := false) {
this.testing := false
this.testMessage := message
this.testFailed := failed
this.window.Log(message)
if !this.enabled
SetTimer(this.pollTimer, 0)
}
CloseSocket() {
if this.socket {
try {
if this.socket.Ptr {
timeout := 50
DllCall("winhttp\WinHttpSetOption", "Ptr", this.socket, "UInt", 115, "UInt*", &timeout, "UInt", 4)
}
}
try this.socket.shutdown()
}
this.socket := 0
this.heartbeatInterval := 0
}
Connect(*) {
if !this.enabled
return
if CrusadersRuntime.InputBusy(this.window) {
SetTimer(this.connectTimer, -500)
return
}
try {
if !this.app {
this.Request("GET", "/oauth2/applications/@me", "", (data) => this.Application(data))
return
}
this.CloseSocket()
this.socket := CrusadersDiscordSocket(this)
} catch Error {
this.Disconnected()
}
}
Application(data) {
this.app := data["id"]
this.Request("GET", "/channels/" this.channel, "", (data) => this.ChannelReady(data))
}
ChannelReady(data) {
this.guild := data.Get("guild_id", "")
if this.guild = "" || !InStr("|0|5|", "|" data.Get("type", -1) "|") {
this.SetConnection("Needs Attention", "Choose a normal server text channel.")
this.window.Log("Use a server text channel for the Discord integration.")
this.enabled := false
SetTimer(this.pollTimer, 0)
SetTimer(this.connectTimer, 0)
return
}
options := []
for name, description in Map("screenshot", "Capture only the Roblox game", "pause", "Pause macro actions",
"resume", "Resume macro actions", "restart", "Rejoin and restart the run", "modes", "Manage modes while paused")
options.Push({type:1, name:name, description:description})
command := {name:"macro", description:"Bayzo's Crusaders Macro controls", type:1, options:options}
this.Request("POST", "/applications/" this.app "/guilds/" this.guild "/commands", command,
(data) => this.Registered())
}
Registered() {
this.window.Log("Discord commands registered: /macro")
this.Connect()
}
Disconnected(code := 0) {
if !this.enabled
return
this.CloseSocket()
if code = 4004 || code = 4013 || code = 4014 {
reason := code = 4004 ? "Bot token is invalid or has been reset. Replace it, then turn integration off and on."
: "Discord rejected gateway intents. Check the application settings and update the macro."
this.SetConnection("Needs Attention", reason)
this.window.Log(reason)
this.enabled := false
SetTimer(this.pollTimer, 0)
SetTimer(this.connectTimer, 0)
return
}
if code = 4007 || code = 4009
this.session := ""
this.SetConnection("Reconnecting", "Retrying in " this.backoff // 1000 " seconds.")
this.window.Log("Discord disconnected; reconnecting in " this.backoff // 1000 " seconds")
SetTimer(this.connectTimer, -this.backoff)
this.backoff := Min(300000, this.backoff * 2)
}
Gateway(socket, text) {
if !this.enabled || (this.socket && socket != this.socket)
return
try {
data := Jxon_Load(&text)
if data.Has("s") && IsNumber(data["s"])
this.sequence := data["s"]
switch data["op"] {
case 10:
this.heartbeatInterval := data["d"]["heartbeat_interval"]
this.awaitingAck := false
this.heartbeatAt := CrusadersRuntime.Tick() + Random(0, this.heartbeatInterval)
if this.session != ""
socket.sendText(Jxon_Dump(Map("op", 6, "d", Map("token", this.token, "session_id", this.session, "seq", this.sequence))))
else {
if CrusadersRuntime.Tick() - this.lastIdentify < 5000 {
this.Disconnected()
return
}
this.lastIdentify := CrusadersRuntime.Tick()
socket.sendText(Jxon_Dump(Map("op", 2, "d", Map("token", this.token, "intents", 0,
"properties", Map("os", "windows", "browser", "bayzo-crusaders", "device", "bayzo-crusaders")))))
}
case 11: this.awaitingAck := false
case 1: this.Heartbeat(socket)
case 7: this.Disconnected()
case 9:
this.session := ""
this.Disconnected()
case 0:
if data["t"] = "READY" {
this.session := data["d"]["session_id"]
this.backoff := 5000
this.SetConnection("Connected", "Bot is ready for /macro commands.")
this.window.Log("Discord connected")
} else if data["t"] = "RESUMED" {
this.backoff := 5000
this.SetConnection("Connected", "Bot is ready for /macro commands.")
} else if data["t"] = "INTERACTION_CREATE"
this.Interaction(data["d"])
}
} catch Error {
this.window.Log("Discord event could not be processed; macro actions are unaffected")
}
}
Heartbeat(socket) {
socket.sendText('{"op":1,"d":' (this.sequence < 0 ? "null" : this.sequence) '}')
this.awaitingAck := true
this.heartbeatAt := CrusadersRuntime.Tick() + this.heartbeatInterval
}
Request(method, path, payload := "", done := 0, interaction := false, files := 0, test := false) {
if this.jobs.Length >= 20
throw Error("Discord request queue is busy. Try again shortly.")
url := "https://discord.com/api/v10" path
if files {
body := CrusadersWebhook.Multipart(payload, files)
} else body := {body:payload = "" ? "" : Jxon_Dump(CrusadersWebhook.JsonData(payload)), contentType:"application/json"}
job := {method:method, url:url, body:body, done:done, interaction:interaction, test:test, path:path, attempt:0,
born:CrusadersRuntime.Tick(), retryAt:0, request:0}
this.SendRequest(job)
this.jobs.Push(job)
}
SendRequest(job) {
request := this.Http()
request.SetTimeouts(1000, 2000, 3000, 3000)
request.Open(job.method, job.url, true)
request.SetRequestHeader("User-Agent", "BayzoAnimeAdventuresMacro/0.0 (Discord Integration)")
request.SetRequestHeader("Content-Type", job.body.contentType)
if !job.interaction
request.SetRequestHeader("Authorization", "Bot " this.token)
request.Send(job.body.body)
job.request := request
job.sent := CrusadersRuntime.Tick()
job.attempt += 1
}
Http() => ComObject("WinHttp.WinHttpRequest.5.1")
static ResponseError(status, path, body := "") {
code := 0
try {
data := Jxon_Load(&body)
if data is Map && IsNumber(data.Get("code", 0))
code := data.Get("code", 0)
}
if status = 401
return "Bot token is invalid or has been reset. Replace it, then turn integration off and on."
if code = 50001 || code = 10003 || (status = 404 && InStr(path, "/channels/") = 1)
return "Bot cannot access the channel. Check the Channel ID, invite the bot to that server, and allow View Channels."
if code = 50013
return "Bot permissions are missing. Check channel overrides and allow View Channels, Send Messages, and Attach Files."
if code = 10062 || code = 10015
return "Discord control expired. Open /macro again and retry."
if code = 40060
return "Discord command was already acknowledged. Open /macro again."
if status = 403
return "Discord denied access. Check bot installation, channel permissions, and network access."
if status = 400
return "Discord rejected the command form. Reopen /macro modes; update the macro if this repeats."
if status = 429
return "Discord rate limit reached. Wait a moment and try again."
if status >= 500
return "Discord service is unavailable. The integration will retry."
return "Discord request failed (HTTP " status "). Check your connection and retry."
}
Poll(*) {
if this.polling || (!this.enabled && !this.testing)
return
this.polling := true
try {
if this.socket && this.heartbeatInterval && CrusadersRuntime.Tick() >= this.heartbeatAt {
if this.awaitingAck
this.Disconnected()
else this.Heartbeat(this.socket)
}
for job in this.jobs.Clone() {
if !this.enabled && !this.testing
break
index := 0
for position, pending in this.jobs
if pending = job {
index := position
break
}
if !index
continue
try {
if job.retryAt {
if CrusadersRuntime.Tick() >= job.retryAt {
job.retryAt := 0
this.SendRequest(job)
}
continue
}
if !job.request.WaitForResponse(0) {
if CrusadersRuntime.Tick() - job.sent > 10000
throw Error("Discord request timed out")
continue
}
status := job.request.Status
if status = 429 && job.attempt < 3 {
text := job.request.ResponseText
delay := Min(30000, Max(100, Ceil(Jxon_Load(&text).Get("retry_after", 1) * 1000)))
if job.interaction && CrusadersRuntime.Tick() - job.born + delay > 2400
throw Error("Discord interaction rate limited")
job.retryAt := CrusadersRuntime.Tick() + delay
continue
}
this.jobs.RemoveAt(index)
if status < 200 || status >= 300 {
reason := CrusadersDiscord.ResponseError(status, job.path, job.request.ResponseText)
if job.test {
this.FinishTest(reason, true)
} else this.window.Log(reason)
if !job.interaction && !job.test {
this.app := ""
this.Disconnected(status = 401 ? 4004 : 0)
if status = 403 || status = 404 || status = 400
this.SetConnection("Needs Attention", reason)
}
continue
}
if job.done {
text := job.request.ResponseText
job.done.Call(text = "" ? Map() : Jxon_Load(&text))
}
} catch Error {
if index <= this.jobs.Length && this.jobs[index] = job
this.jobs.RemoveAt(index)
try job.request.Abort()
if job.test
this.FinishTest("Connection test failed. Check your internet connection and try again.", true)
else this.window.Log("Discord network request failed or timed out; macro actions are unaffected")
if !job.interaction && !job.test {
this.app := ""
this.Disconnected()
}
}
}
for id, tick in this.seen.Clone()
if CrusadersRuntime.Tick() - tick > 900000
this.seen.Delete(id)
for id, form in this.forms.Clone()
if CrusadersRuntime.Tick() - form.created > 300000
this.forms.Delete(id)
} catch Error {
this.window.Log("Discord polling error; macro actions are unaffected")
} finally this.polling := false
}
Authorized(interaction) {
user := interaction.Has("member") ? interaction["member"]["user"] : interaction.Get("user", Map())
return this.enabled && interaction.Get("channel_id", "") = this.channel && user.Get("id", "") = this.owner
}
Reply(interaction, text, components := 0, done := 0) {
data := {content:SubStr(text, 1, 1900), flags:64, allowed_mentions:{parse:[]}}
if components
data.components := components
this.Callback(interaction, 4, data, done)
}
Callback(interaction, type, data, done := 0) {
this.Request("POST", "/interactions/" interaction["id"] "/" interaction["token"] "/callback",
{type:type, data:data}, done, true)
}
Interaction(interaction) {
if !this.enabled || this.seen.Has(interaction["id"])
return
this.seen[interaction["id"]] := CrusadersRuntime.Tick()
try {
if !this.Authorized(interaction) {
this.Reply(interaction, "This command is restricted to the configured user and channel.")
return
}
if interaction["type"] = 2 {
if interaction["data"]["name"] != "macro"
return
command := interaction["data"]["options"][1]["name"]
switch command {
case "pause", "resume":
this.SetPause(command = "pause")
this.Reply(interaction, command = "pause" ? "Macro paused." : "Macro resumed.")
case "screenshot":
this.Callback(interaction, 5, {flags:64}, (data) => this.Screenshot(interaction))
case "restart":
id := this.Form("restart")
this.Reply(interaction, "Rejoin your configured server and restart the run?",
[this.Row([this.Button("Restart Run", "confirm:" id, 4), this.Button("Cancel", "cancel:" id)])])
case "modes": this.RequirePaused(), this.ModeList(interaction)
}
} else {
parts := StrSplit(interaction["data"]["custom_id"], ":")
action := parts[1], id := parts[2]
if !this.forms.Has(id)
throw Error("This control expired. Run /macro again.")
form := this.forms[id]
if CrusadersRuntime.Tick() - form.created > 300000
throw Error("This control expired. Run /macro again.")
if action = "cancel" {
this.forms.Delete(id)
this.Reply(interaction, "Cancelled.")
return
}
if action = "confirm" && form.action = "restart" {
this.forms.Delete(id)
this.Reply(interaction, "Restarting the run and rejoining your configured server.", 0,
(data) => this.StartRestart())
return
}
this.RequirePaused()
if form.fingerprint != this.Fingerprint()
throw Error("The mode list changed. Open /macro modes again.")
switch action {
case "list": this.ModeList(interaction, form.page)
case "add": this.ChooseMode(interaction)
case "mode": this.ChooseMap(interaction, interaction["data"]["values"][1], form.index)
case "map":
value := interaction["data"]["values"][1]
this.EditForm(interaction, form.index, form.mode, value)
case "edit":
if this.window.tasks.items[form.index].mode = "Event"
this.EventEditor(interaction, form.index)
else this.ChooseMode(interaction, form.index)
case "details": this.ChooseMode(interaction, form.index)
case "priority": this.PriorityEditor(interaction, form.index)
case "contract", "priorityup", "prioritydown":
selected := form.selected
names := CrusadersCatalog.ContractPriorities(this.window.tasks.items[form.index].contractPriority)
if action = "contract" {
selected := interaction["data"]["values"][1]
found := false
for name in names
found := found || name = selected
if !found
throw Error("Unknown contract.")
} else {
position := 0
for number, name in names
if name = selected
position := number
destination := position + (action = "priorityup" ? -1 : 1)
if !position || destination < 1 || destination > names.Length
throw Error("Cannot move this contract further.")
names.RemoveAt(position)
names.InsertAt(destination, selected)
priority := ""
for name in names
priority .= (priority = "" ? "" : "|") name
items := this.window.tasks.CopyItems()
items[form.index].contractPriority := priority
this.Commit(items)
}
this.forms.Delete(id)
this.PriorityEditor(interaction, form.index, selected, true)
case "save": this.SaveForm(interaction, id, form)
case "remove":
confirm := this.Form("delete", form.index)
this.Reply(interaction, "Remove mode " form.index "?", [this.Row([this.Button("Remove", "delete:" confirm, 4), this.Button("Cancel", "cancel:" confirm)])])
case "toggle": throw Error("Mode Enable/Disable controls have been removed. Open /macro modes again.")
case "delete", "up", "down":
this.Mutate(form, action)
this.forms.Delete(id)
this.ModeList(interaction, form.page)
}
}
} catch Error as err {
this.Reply(interaction, err.Message)
}
}
SetPause(paused) {
global testRunning
if this.pendingRestart
throw Error("Restart is in progress. Wait for the run to start.")
this.window.StopIdleCleanup()
if !paused && HasMethod(this.window,"RestorePausedBrowse")
this.window.RestorePausedBrowse()
CrusadersRuntime.SetPaused(paused)
this.window.runStatus := paused ? "Paused" : testRunning ? "Running" : "Idle"
this.window.Log(paused ? "Paused from Discord" : "Resumed from Discord")
}
RequirePaused() {
if !CrusadersRuntime.paused || this.pendingRestart
throw Error("Pause the macro before using the mode list.")
}
CaptureUi() {
return CrusadersWebhook.Capture(this.window, false, false).bytes
}
Screenshot(interaction) {
try {
screenshot := this.CaptureUi()
this.Request("PATCH", "/webhooks/" this.app "/" interaction["token"] "/messages/@original",
{content:"Roblox screenshot", attachments:[{id:0, filename:"Roblox.png"}], allowed_mentions:{parse:[]}},
0, true, [{name:"Roblox.png", bytes:screenshot}])
} catch Error as err {
this.Request("PATCH", "/webhooks/" this.app "/" interaction["token"] "/messages/@original",
{content:err.Message}, 0, true)
}
}
StartRestart() {
global testCancelled, selector
if this.pendingRestart
return
this.pendingRestart := true
if selector.pickMode
this.window.CancelPick()
CrusadersRuntime.holdingCamera := false
if CrusadersRuntime.rotationKey != "" {
SendEvent("{" CrusadersRuntime.rotationKey " up}")
CrusadersRuntime.rotationKey := ""
}
this.window.Stop()
testCancelled := true
CrusadersRuntime.SetPaused(false)
this.window.Log("Discord requested Restart Run")
SetTimer(this.restartTimer, 100)
}
FinishRestart(*) {
global testRunning
if testRunning
return
SetTimer(this.restartTimer, 0)
this.pendingRestart := false
this.window.startConsumed := false
this.window.remoteRejoin := true
try this.window.StartBackend()
catch Error {
this.window.Log("Discord restart could not start. Check the mode list and configuration.")
} finally this.window.remoteRejoin := false
}
Fingerprint() => Jxon_Dump(CrusadersWebhook.JsonData(this.window.tasks.items))
Form(action, index := 0, page := 0) {
if this.forms.Count > 200
this.forms.Clear()
id := CrusadersRuntime.Tick() "-" Random(100000, 999999)
this.forms[id] := {action:action, index:index, page:page, created:CrusadersRuntime.Tick(), fingerprint:this.Fingerprint()}
return id
}
Row(components) => {type:1, components:components}
Button(label, id, style := 2) => {type:2, label:label, custom_id:id, style:style}
ModeList(interaction, page := 0) {
this.RequirePaused()
items := this.window.tasks.items
page := Max(0, Min(page, Max(0, (items.Length - 1) // 3)))
content := "**Mode List** - " items.Length " modes"
rows := []
loop 3 {
index := page * 3 + A_Index
if index > items.Length
break
item := items[index]
content .= "`n**" index ". " item.mode " / " CrusadersCatalog.Name(item.config) "** - Act " item.act " - " item.runs " runs" (item.enabled ? "" : " (Disabled)")
id := this.Form("item", index, page)
buttons := [this.Button("Edit " index, "edit:" id), this.Button("Remove", "remove:" id)]
if index > 1
buttons.Push(this.Button("Move Up", "up:" id))
if index < items.Length
buttons.Push(this.Button("Move Down", "down:" id))
rows.Push(this.Row(buttons))
}
buttons := [this.Button("Add Mode", "add:" this.Form("add"), 1)]
if page > 0
buttons.Push(this.Button("Previous", "list:" this.Form("list", 0, page - 1)))
if (page + 1) * 3 < items.Length
buttons.Push(this.Button("Next", "list:" this.Form("list", 0, page + 1)))
rows.Push(this.Row(buttons))
this.Reply(interaction, content, rows)
}
ChooseMode(interaction, index := 0) {
options := []
for mode in CrusadersCatalog.Modes
options.Push({label:mode, value:mode})
this.Reply(interaction, "Choose a gamemode.", [this.Row([{type:3, custom_id:"mode:" this.Form("mode", index), options:options}])])
}
EventEditor(interaction, index) {
id := this.Form("event", index)
this.Reply(interaction, "**" CrusadersCatalog.Name(this.window.tasks.items[index].config) "**",
[this.Row([this.Button("Edit Details", "details:" id), this.Button("Contract Priority", "priority:" id)])])
}
PriorityEditor(interaction, index, selected := "", update := false) {
this.RequirePaused()
item := this.window.tasks.items[index]
if item.mode != "Event"
throw Error("Contract priority is only available for Event modes.")
names := CrusadersCatalog.ContractPriorities(item.contractPriority)
if selected = ""
selected := names[1]
id := this.Form("priority", index, (index - 1) // 3)
this.forms[id].selected := selected
text := "**Contract Priority - " CrusadersCatalog.Name(item.config) "**"
options := [], position := 0
for number, name in names {
text .= "`n" number ". " name
options.Push({label:name, value:name, default:ComValue(11, name = selected ? -1 : 0)})
if name = selected
position := number
}
up := this.Button("Move Up", "priorityup:" id)
down := this.Button("Move Down", "prioritydown:" id)
up.disabled := ComValue(11, position = 1 ? -1 : 0)
down.disabled := ComValue(11, position = names.Length ? -1 : 0)
rows := [this.Row([{type:3, custom_id:"contract:" id, options:options}]),
this.Row([up, down, this.Button("Done", "list:" id, 1)])]
if update
this.Callback(interaction, 7, {content:text, components:rows, allowed_mentions:{parse:[]}})
else this.Reply(interaction, text, rows)
}
ChooseMap(interaction, mode, index := 0) {
if !CrusadersCatalog.Maps.Has(mode)
throw Error("Unknown gamemode.")
options := []
for name in CrusadersCatalog.Maps[mode]
options.Push({label:name, value:name})
id := this.Form("map", index)
this.forms[id].mode := mode
this.Reply(interaction, "Choose a map.", [this.Row([{type:3, custom_id:"map:" id, options:options}])])
}
EditForm(interaction, index, mode := "", name := "") {
item := index ? this.window.tasks.items[index].Clone() : this.window.tasks.NewTask()
if mode != "" {
CrusadersCatalog.ActCount(mode, name)
item.mode := mode
item.act := Min(item.act, CrusadersCatalog.ActCount(mode, name))
item.config := CrusadersCatalog.Filename(mode, name, item.act)
item.difficulty := CrusadersCatalog.EffectiveDifficulty(mode, name, item.difficulty)
if mode = "Event" && !index
item.contractPriority := IniRead(this.window.tasks.root "\Event\" item.config, "Settings", "ContractPriority", item.contractPriority)
}
id := this.Form("save", index)
this.forms[id].item := item
fields := [{key:"act", label:"Act", value:item.act}, {key:"runs", label:"Runs", value:item.runs}]
if CrusadersCatalog.HasDifficultySelection(item.mode, CrusadersCatalog.Name(item.config))
fields.Push({key:"difficulty", label:"Difficulty", value:item.difficulty})
if item.mode = "Boss Rush" {
fields.Push({key:"bossRushMode", label:"Trait Mode", value:item.bossRushMode})
if CrusadersCatalog.Name(item.config) = "Makima"
fields.Push({key:"makimaCard", label:"Card Modifier", value:item.makimaCard})
}
rows := []
for field in fields {
choices := field.key = "act" ? [] : field.key = "difficulty" ? ["Normal", "Hard"] : field.key = "bossRushMode" ? ["Traits", "Traitless"]
: field.key = "makimaCard" ? ["Unit Slot", "Damage", "Placement Limit"] : 0
if field.key = "act" {
loop CrusadersCatalog.ActCount(item.mode, CrusadersCatalog.Name(item.config))
choices.Push(String(A_Index))
}
if choices {
options := []
for choice in choices
options.Push(Map("label", choice, "value", choice, "default", ComValue(11, choice = field.value ? -1 : 0)))
component := {type:3, custom_id:field.key, options:options}
} else component := {type:4, custom_id:field.key, style:field.key = "contractPriority" ? 2 : 1,
value:String(field.value), required:ComValue(11, -1), max_length:field.key = "contractPriority" ? 500 : 30}
rows.Push({type:18, label:SubStr(field.label, 1, 45), component:component})
}
this.Callback(interaction, 9, {custom_id:"save:" id, title:SubStr((index ? "Edit " : "Add ") CrusadersCatalog.Name(item.config), 1, 45), components:rows})
}
SaveForm(interaction, id, form) {
this.RequirePaused()
values := Map()
for row in interaction["data"]["components"] {
components := row.Has("component") ? [row["component"]] : row["components"]
for component in components
values[component["custom_id"]] := component.Has("values") ? component["values"][1] : component["value"]
}
item := form.item.Clone()
item.wait := 0
for key in ["act", "runs"] {
if !RegExMatch(values[key], "^\d+$")
throw Error("Act and runs must be whole numbers.")
item.%key% := Integer(values[key])
}
for key in ["difficulty", "bossRushMode", "makimaCard", "contractPriority"]
if values.Has(key)
item.%key% := key = "contractPriority" ? StrReplace(StrReplace(Trim(values[key]), "`r", ""), "`n", "|") : Trim(values[key])
this.ValidateItem(item)
items := this.window.tasks.CopyItems()
if form.index
items[form.index] := item
else {
if items.Length >= 500
throw Error("The mode list limit is 500.")
items.Push(item)
}
this.Commit(items)
this.forms.Delete(id)
if item.mode = "Event"
this.PriorityEditor(interaction, form.index ? form.index : items.Length)
else this.ModeList(interaction, form.index ? (form.index - 1) // 3 : (items.Length - 1) // 3)
}
ValidateItem(item) {
global selector
name := CrusadersCatalog.Name(item.config)
if !CrusadersCatalog.Maps.Has(item.mode) || item.act < 1 || item.act > CrusadersCatalog.ActCount(item.mode, name)
throw Error("Invalid gamemode, map or act.")
item.config := CrusadersCatalog.Filename(item.mode, name, item.act)
this.window.tasks.Validate(item)
if item.mode != "Events" && !FileExist(this.window.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config)
throw Error("The selected config does not exist.")
}
Mutate(form, action) {
this.RequirePaused()
items := this.window.tasks.CopyItems()
if form.index < 1 || form.index > items.Length
throw Error("Mode no longer exists.")
if action = "delete"
items.RemoveAt(form.index)
else {
destination := form.index + (action = "up" ? -1 : 1)
if destination < 1 || destination > items.Length
throw Error("Cannot move this mode further.")
item := items.RemoveAt(form.index)
items.InsertAt(destination, item)
}
this.Commit(items)
}
Commit(items) {
global testRunning
this.RequirePaused()
if testRunning {
enabled := false
for item in items
enabled := enabled || item.enabled
if !enabled
throw Error("Keep at least one enabled mode during a paused run.")
}
SetTimer(this.window.taskSaveTimer, 0)
this.window.tasks.Commit(items)
this.window.tasks.remoteQueueChanged := testRunning
this.window.editingTask := 0
this.window.RenderTasks(0)
this.window.Log("Discord mode list saved")
}
}
class CrusadersDiscordSocket extends CrusadersDiscordSocketBase {
__New(owner, url := "wss://gateway.discord.gg/?v=10&encoding=json") {
this.owner := owner
super.__New(url, {
message:ObjBindMethod(owner, "Gateway"), close:(socket, code, reason) => owner.Disconnected(code)}, true,
"User-Agent: BayzoAnimeAdventuresMacro/0.0 (Discord Integration)", 2000)
}
onError(*) => this.owner.Disconnected()
}
class CrusadersDiscordSocketBase {
Ptr := 0, async := 0, readyState := 0, url := ''
HINTERNETs := []
onOpen() => 0
onClose(status, reason) => 0
onData(data, size) => 0
onMessage(msg) => 0
reconnect() => 0
__New(Url, Events := 0, Async := true, Headers := '', TimeOut := 0, InitialSize := 8192) {
static contexts := Map()
if (!RegExMatch(Url, 'i)^((?<SCHEME>wss?)://)?((?<USERNAME>[^:]+):(?<PASSWORD>.+)@)?(?<HOST>[^/:\s]+)(:(?<PORT>\d+))?(?<PATH>/\S*)?$', &m))
Throw CrusadersDiscordSocketBase.Error('Invalid websocket url')
if !hSession := DllCall('Winhttp\WinHttpOpen', 'ptr', 0, 'uint', 0, 'ptr', 0, 'ptr', 0, 'uint', Async ? 0x10000000 : 0, 'ptr')
Throw CrusadersDiscordSocketBase.Error()
this.async := Async := !!Async, this.url := Url
this.HINTERNETs.Push(hSession)
port := m.PORT ? Integer(m.PORT) : m.SCHEME = 'ws' ? 80 : 443
dwFlags := m.SCHEME = 'wss' ? 0x800000 : 0
if TimeOut
DllCall('Winhttp\WinHttpSetTimeouts', 'ptr', hSession, 'int', TimeOut, 'int', TimeOut, 'int', TimeOut, 'int', TimeOut, 'int')
if !hConnect := DllCall('Winhttp\WinHttpConnect', 'ptr', hSession, 'wstr', m.HOST, 'ushort', port, 'uint', 0, 'ptr')
Throw CrusadersDiscordSocketBase.Error()
this.HINTERNETs.Push(hConnect)
switch Type(Headers) {
case 'Object', 'Map':
s := ''
for k, v in Headers is Map ? Headers : Headers.OwnProps()
s .= '`r`n' k ': ' v
Headers := LTrim(s, '`r`n')
case 'String':
default:
Headers := ''
}
if (Events) {
for k, v in Events.OwnProps()
if (k ~= 'i)^(open|data|message|close)$')
this.DefineProp('on' k, { call: v })
}
if (Async) {
this.DefineProp('shutdown', { call: async_shutdown })
.DefineProp('receive', { call: receive })
.DefineProp('_send', { call: async_send })
} else this.__cache_size := InitialSize
connect(this), this.DefineProp('reconnect', { call: connect })
connect(self) {
if !self.HINTERNETs.Length
Throw CrusadersDiscordSocketBase.Error('The connection is closed')
self.shutdown()
if !hRequest := DllCall('Winhttp\WinHttpOpenRequest', 'ptr', hConnect, 'wstr', 'GET', 'wstr', m.PATH, 'ptr', 0, 'ptr', 0, 'ptr', 0, 'uint', dwFlags, 'ptr')
Throw CrusadersDiscordSocketBase.Error()
self.HINTERNETs.Push(hRequest), self.onOpen()
if (Headers)
DllCall('Winhttp\WinHttpAddRequestHeaders', 'ptr', hRequest, 'wstr', Headers, 'uint', -1, 'uint', 0x20000000, 'int')
if (!DllCall('Winhttp\WinHttpSetOption', 'ptr', hRequest, 'uint', 114, 'ptr', 0, 'uint', 0, 'int')
|| !DllCall('Winhttp\WinHttpSendRequest', 'ptr', hRequest, 'ptr', 0, 'uint', 0, 'ptr', 0, 'uint', 0, 'uint', 0, 'uptr', 0, 'int')
|| !DllCall('Winhttp\WinHttpReceiveResponse', 'ptr', hRequest, 'ptr', 0)
|| !DllCall('Winhttp\WinHttpQueryHeaders', 'ptr', hRequest, 'uint', 19, 'ptr', 0, 'wstr', status := '00000', 'uint*', 10, 'ptr', 0, 'int')
|| status != '101')
Throw IsSet(status) ? CrusadersDiscordSocketBase.Error('Invalid status: ' status) : CrusadersDiscordSocketBase.Error()
if !self.Ptr := DllCall('Winhttp\WinHttpWebSocketCompleteUpgrade', 'ptr', hRequest, 'ptr', 0)
Throw CrusadersDiscordSocketBase.Error()
DllCall('Winhttp\WinHttpCloseHandle', 'ptr', self.HINTERNETs.Pop())
self.HINTERNETs.Push(self.Ptr), self.readyState := 1
(Async && async_receive(self))
}
async_receive(self) {
static on_read_complete := get_sync_callback(), hHeap := DllCall('GetProcessHeap', 'ptr')
static msg_gui := Gui(), wm_ahkmsg := DllCall('RegisterWindowMessage', 'str', 'AHK_WEBSOCKET_STATUSCHANGE', 'uint')
static pHeapReAlloc := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'kernel32', 'ptr'), 'astr', 'HeapReAlloc', 'ptr')
static pSendMessageW := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'user32', 'ptr'), 'astr', 'SendMessageW', 'ptr')
static pWinHttpWebSocketReceive := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'winhttp', 'ptr'), 'astr', 'WinHttpWebSocketReceive', 'ptr')
static _ := (OnMessage(wm_ahkmsg, WEBSOCKET_READ_WRITE_COMPLETE, 0xff), DllCall('SetParent', 'ptr', msg_gui.Hwnd, 'ptr', -3))
NumPut('ptr', pws := ObjPtr(self), 'ptr', msg_gui.Hwnd, 'uint', wm_ahkmsg, 'uint', InitialSize, 'ptr', hHeap,
'ptr', cache := DllCall('HeapAlloc', 'ptr', hHeap, 'uint', 0, 'uptr', InitialSize, 'ptr'), 'uptr', 0, 'uptr', InitialSize,
'ptr', pHeapReAlloc, 'ptr', pSendMessageW, 'ptr', pWinHttpWebSocketReceive,
contexts[pws] := context := Buffer(11 * A_PtrSize)), self.__send_queue := []
context.DefineProp('__Delete', { call: self => DllCall('HeapFree', 'ptr', hHeap, 'uint', 0, 'ptr', NumGet(self, 3 * A_PtrSize + 8, 'ptr')) })
DllCall('Winhttp\WinHttpSetOption', 'ptr', self, 'uint', 45, 'ptr*', context.Ptr, 'uint', A_PtrSize)
DllCall('Winhttp\WinHttpSetStatusCallback', 'ptr', self, 'ptr', on_read_complete, 'uint', 0x80000, 'uptr', 0, 'ptr')
if err := DllCall('Winhttp\WinHttpWebSocketReceive', 'ptr', self, 'ptr', cache, 'uint', InitialSize, 'uint*', 0, 'uint*', 0)
self.onError(err)
}
static WEBSOCKET_READ_WRITE_COMPLETE(wp, lp, msg, hwnd) {
static map_has := Map.Prototype.Has
if !map_has(contexts, ws := NumGet(wp, 'ptr')) || (ws := ObjFromPtrAddRef(ws)).readyState != 1
return
switch lp {
case 5:
try ws.__send_queue.Pop()
case 4:
if err := NumGet(wp, A_PtrSize, 'uint')
return ws.onError(err)
rea := ws.QueryCloseStatus(), ws.shutdown()
return ws.onClose(rea.status, rea.reason)
default:
data := NumGet(wp, A_PtrSize, 'ptr')
size := NumGet(wp, 2 * A_PtrSize, 'uptr')
if lp == 2
return ws.onMessage(StrGet(data, size, 'utf-8'))
else return ws.onData(data, size)
}
}
static async_send(self, type, buf, size) {
if (self.readyState != 1)
Throw CrusadersDiscordSocketBase.Error('websocket is disconnected')
(q := self.__send_queue).InsertAt(1, buf)
while (err := DllCall('Winhttp\WinHttpWebSocketSend', 'ptr', self, 'uint', type, 'ptr', buf, 'uint', size, 'uint')) = 4317 && A_Index < 60
Sleep(15)
if err
q.RemoveAt(1), self.onError(err)
}
static async_shutdown(self) {
if self.Ptr
DllCall('Winhttp\WinHttpSetOption', 'ptr', self, 'uint', 45, 'ptr*', 0, 'uint', A_PtrSize)
(CrusadersDiscordSocketBase.Prototype.shutdown)(self)
try contexts.Delete(ObjPtr(self))
}
static get_sync_callback() {
mcodes := ['g+wMVot0JBiF9g+E0QAAAItEJBw9AAAQAHUVi0YkagVW/3YI/3YE/9Beg8QMwhQAPQAACAAPhaYAAACLBolEJASLRCQgU1VXi1AEx0QkFAAAAADHRCQYAAAAAIP6BHRsi04Yi+qLAI0MAYlOGIPlAXV2i0YUiUQkFI1EJBBSUP92CItGJP92BIlMJCjHRhgAAAAA/9CNfhyFwHQHi14MOx91UYsHK0YYagBqAFCLRhQDRhhQ/3QkMItGKP/QhcB0HT3dEAAAdBaJRCQUagSNRCQUUP92CItGJP92BP/QX11bXoPEDMIUAIteHI1+HDvLcrED24tGIFP/dhRqAP92EP/QhcB0B4lGFIkf65aF7XSSx0QkFA4AB4DrsQ==',
'SIXSD4QvAQAASIlcJCBBVkiD7FBIi9pMi/FBgfgAABAAdR9Ii0sITIvCi1IQQbkFAAAA/1NASItcJHhIg8RQQV7DQYH4AAAIAA+F3gAAAEiLAkljUQRIiWwkYEiJRCQwM8BIiXQkaEiJfCRwSMdEJDgAAAAASIlEJECD+gQPhIYAAABFiwGL6kiLQyhNjQQATIlDKIPlAQ+FnAAAAEiLQyBMi8qLUxBIi0sITIlEJEBMjUQkMEiJRCQ4SMdDKAAAAAD/U0BIjXswSIXAdAiLcxRIOzd1c0SLB0UzyUiLUyBJi85EK0MoSANTKEjHRCQgAAAAAP9TSIXAdCM93RAAAHQci8BIiUQkOItTEEyNRCQwSItLCEG5BAAAAP9TQEiLdCRoSItsJGBIi3wkcEiLXCR4SIPEUEFew0iLczBIjXswTDvGcpBIA/ZMi0MgTIvOSItLGDPS/1M4SIXAdAxIiUMgSIk36Wz///+F7Q+EZP///0jHRCQ4DgAHgOuM']
DllCall('crypt32\CryptStringToBinary', 'str', hex := mcodes[A_PtrSize >> 2], 'uint', 0, 'uint', 1, 'ptr', 0, 'uint*', &s := 0, 'ptr', 0, 'ptr', 0) &&
DllCall('crypt32\CryptStringToBinary', 'str', hex, 'uint', 0, 'uint', 1, 'ptr', code := Buffer(s), 'uint*', &s, 'ptr', 0, 'ptr', 0) &&
DllCall('VirtualProtect', 'ptr', code, 'uint', s, 'uint', 0x40, 'uint*', 0)
return code
}
static receive(*) {
Throw CrusadersDiscordSocketBase.Error('Used only in synchronous mode')
}
}
__Delete() {
this.shutdown()
while (this.HINTERNETs.Length)
DllCall('Winhttp\WinHttpCloseHandle', 'ptr', this.HINTERNETs.Pop())
}
onError(err, what := 0) {
if err != 12030
Throw CrusadersDiscordSocketBase.Error(err, what - 5)
if this.readyState == 3
return
this.readyState := 3
try this.onClose(1006, '')
}
class Error extends Error {
__New(err := A_LastError, what := -4) {
static module := DllCall('GetModuleHandle', 'str', 'winhttp', 'ptr')
if err is Integer
if (DllCall("FormatMessage", "uint", 0x900, "ptr", module, "uint", err, "uint", 0, "ptr*", &pstr := 0, "uint", 0, "ptr", 0), pstr)
err := (msg := StrGet(pstr), DllCall('LocalFree', 'ptr', pstr), msg)
else err := OSError(err).Message
super.__New(err, what)
}
}
queryCloseStatus() {
if (!DllCall('Winhttp\WinHttpWebSocketQueryCloseStatus', 'ptr', this, 'ushort*', &usStatus := 0, 'ptr', vReason := Buffer(123), 'uint', 123, 'uint*', &len := 0))
return { status: usStatus, reason: StrGet(vReason, len, 'utf-8') }
else if (this.readyState > 1)
return { status: 1006, reason: '' }
}
_send(type, buf, size) {
if (this.readyState != 1)
Throw CrusadersDiscordSocketBase.Error('websocket is disconnected')
if err := DllCall('Winhttp\WinHttpWebSocketSend', 'ptr', this, 'uint', type, 'ptr', buf, 'uint', size, 'uint')
return this.onError(err)
}
sendText(str) {
if (size := StrPut(str, 'utf-8') - 1) {
StrPut(str, buf := Buffer(size), 'utf-8')
this._send(2, buf, size)
} else
this._send(2, 0, 0)
}
send(buf) => this._send(0, buf, buf.Size)
receive() {
if (this.readyState != 1)
Throw CrusadersDiscordSocketBase.Error('websocket is disconnected')
ptr := (cache := Buffer(size := this.__cache_size)).Ptr, offset := 0
while (!err := DllCall('Winhttp\WinHttpWebSocketReceive', 'ptr', this, 'ptr', ptr + offset, 'uint', size - offset, 'uint*', &dwBytesRead := 0, 'uint*', &eBufferType := 0)) {
switch eBufferType {
case 1, 3:
offset += dwBytesRead
if offset == size
cache.Size := size *= 2, ptr := cache.Ptr
case 0, 2:
offset += dwBytesRead
if eBufferType == 2
return StrGet(ptr, offset, 'utf-8')
cache.Size := offset
return cache
case 4:
rea := this.QueryCloseStatus(), this.shutdown()
try this.onClose(rea.status, rea.reason)
return
}
}
(err != 4317 && this.onError(err))
}
shutdown() {
if (this.readyState = 1) {
this.readyState := 2
DllCall('Winhttp\WinHttpWebSocketClose', 'ptr', this, 'ushort', 1006, 'ptr', 0, 'uint', 0)
this.readyState := 3
}
while (this.HINTERNETs.Length > 2)
DllCall('Winhttp\WinHttpCloseHandle', 'ptr', this.HINTERNETs.Pop())
this.Ptr := 0
}
}
class Adventures {
static Tick() => DllCall("GetTickCount64", "UInt64")
static KeyPattern := "i)^(?:[1-6]|[a-z]|Space|Enter|Tab|Escape|Up|Down|Left|Right)$"
static Validate(profile) {
if !(profile is Map) || !profile.Has("actions") || !(profile["actions"] is Array)
throw ValueError("Profile must contain an actions array.")
if profile["actions"].Length > 2000
throw ValueError("Maximum 2000 actions per profile.")
if StrLen(profile.Get("name",""))>80
throw ValueError("Profile name must be at most 80 characters.")
for field in ["width", "height"]
if !profile.Has(field) || !(profile[field] is Integer) || profile[field] < 1 || profile[field] > 16384
throw ValueError("Capture a valid Roblox client size first.")
for action in profile["actions"] {
if !(action is Map) || !action.Has("type")
throw ValueError("Each action needs a type.")
switch action["type"] {
case "click":
for axis, limit in Map("x",profile["width"],"y",profile["height"])
if !action.Has(axis) || !(action[axis] is Integer) || action[axis]<0 || action[axis]>=limit
throw ValueError("Click coordinates must be inside the captured client.")
if !RegExMatch(action.Get("button","Left"),"^(Left|Right)$")
throw ValueError("Click button must be Left or Right.")
case "key":
if !RegExMatch(action.Get("key",""),this.KeyPattern)
throw ValueError("Use a single letter, 1-6, Space, Enter, Tab, Escape, or arrow key.")
case "wait":
if !action.Has("ms") || !(action["ms"] is Integer) || action["ms"]<0 || action["ms"]>3600000
throw ValueError("Wait must be 0-3600000 milliseconds.")
default: throw ValueError("Unknown action type.")
}
}
return profile
}
static Write(path, content) {
temporary := path ".tmp"
try {
file := FileOpen(temporary,"w","UTF-8-RAW")
try file.Write(content)
finally file.Close()
FileMove(temporary,path,1)
} finally {
if FileExist(temporary)
FileDelete(temporary)
}
}
}
class AdventuresApp {
CheckClient() {
AADisplay.UsePhysicalPixels()
if !this.hwnd || !WinExist(this.hwnd)
throw Error("Roblox closed. Stop and start again after reopening it.")
if !WinActive(this.hwnd) || WinGetMinMax(this.hwnd)=-1
throw Error("Roblox must be the active, visible window.")
WinGetClientPos(,,&width,&height,this.hwnd)
if width!=this.profile["width"] || height!=this.profile["height"]
throw Error("Roblox client size changed. Restore the captured size before resuming.")
if IsSet(AAPauseMenu) && this.status = "Running"
AAPauseMenu.Guard(this)
}
Step() {
if this.busy || this.status!="Running"
return
this.busy := true
try {
this.CheckClient()
if Adventures.Tick()<this.due
return
if this.finishing {
this.FinishCycle()
return
}
action := this.profile["actions"][this.index]
previous := Critical(1)
try {
this.CheckClient()
switch action["type"] {
case "click":
WinGetClientPos(&left,&top,,,this.hwnd)
CoordMode("Mouse","Screen")
Click(left+action["x"],top+action["y"],action.Get("button","Left"))
case "key": SendEvent("{" action["key"] "}")
case "wait": this.remaining := action["ms"]
}
this.index++
this.due := Adventures.Tick()+(action["type"]="wait"?action["ms"]:100)
this.finishing := this.index>this.profile["actions"].Length
} finally Critical(previous)
this.Publish()
} catch Error as err {
this.Pause(err.Message)
} finally this.busy := false
}
FinishCycle() {
if this.status!="Running"
return
try this.CheckClient()
catch Error as err {
this.Pause(err.Message)
return
}
this.completed++, this.index := 1, this.finishing := false
if this.limit && this.completed>=this.limit {
this.Stop(false)
this.Log("Requested sequence cycles completed.")
} else {
this.due := Adventures.Tick()+100
SetTimer(this.timer,25)
this.Publish()
}
}
Pause(reason:="") {
if this.tutorial && this.status="Paused" {
this.Log("Finish or close Macro Overview before resuming.")
return
}
if this.loop {
this.loop.Pause(reason)
return
}
if this.status="Running" {
this.remaining := Max(0,this.due-Adventures.Tick())
SetTimer(this.timer,0)
this.status := "Paused"
this.Log(reason!=""?reason:"Paused.")
} else if this.status="Paused" {
try this.CheckClient()
catch Error as err {
this.Log(err.Message)
return
}
this.due := Adventures.Tick()+this.remaining, this.status := "Running"
SetTimer(this.timer,25)
this.Log("Resumed.")
}
}
Stop(log:=true) {
if this.HasOwnProp("picker") && this.picker
this.picker.Cancel(false)
if this.loop {
this.loop.Stop(log)
return
}
SetTimer(this.timer,0)
this.status := "Idle", this.index := 1, this.remaining := 0, this.finishing := false
if log
this.Log("Stopped.")
else this.Publish()
}
}
class AdventuresOcr {
static library := 0
static NormalizeLabels(text) => Trim(RegExReplace(text, "[ \t]+", " "), " `t`r`n")
static EnsureLibrary(root) {
if !this.library {
this.library := AAOcrLibrary.Load(root)
}
}
__New() {
this.engine := 0
this.callback := 0
directory := A_ScriptDir "\Other"
root := directory "\RapidOcr"
AdventuresOcr.EnsureLibrary(root)
AAOcrLibrary.Models(root)
try {
this.engine := DllCall("RapidOcrOnnx\OcrInit",
"Str", root "\models\ch_PP-OCRv3_det_infer.onnx",
"Str", root "\models\ch_ppocr_mobile_v2.0_cls_infer.onnx",
"Str", root "\models\ch_PP-OCRv3_rec_infer.onnx",
"Str", root "\models\ppocr_keys_v1.txt", "Int", 2, "Ptr")
if !this.engine
throw Error("Could not initialize OCR.")
this.callback := CallbackCreate(ObjBindMethod(this, "ReceiveText"), , 3)
this.parameters := Buffer(42, 0)
NumPut("Int", 10, "Int", 1024, "Float", 0.5, "Float", 0.3, "Float", 2.0, this.parameters)
} catch Error as err {
this.Dispose()
throw err
}
}
ReceiveText(userdata, textPointer, resultPointer) {
this.result := StrGet(textPointer, "UTF-8")
return 0
}
Read(bitmap, x, y, width, height, scale := 3) {
scaled := 0, graphics := 0, locked := false
try {
scaled := Gdip_CreateBitmap(width * scale, height * scale)
if !scaled
throw Error("Could not allocate OCR pixels.")
graphics := Gdip_GraphicsFromImage(scaled)
if !graphics
throw Error("Could not initialize OCR graphics.")
if Gdip_DrawImage(graphics, bitmap, 0, 0, width * scale, height * scale, x, y, width, height)!=0
throw Error("Could not scale OCR pixels.")
if Gdip_LockBits(scaled, 0, 0, width * scale, height * scale, &stride, &pixels, &data, 1) != 0
throw Error("Could not prepare OCR pixels.")
locked := true
native := Buffer(A_PtrSize + 16, 0)
NumPut("Ptr", pixels, "Int", stride, "Int", width * scale, "Int", height * scale, "Int", 4, native)
this.result := ""
ok := this.DetectBitmap(native)
return ok ? AdventuresOcr.NormalizeLabels(this.result) : ""
} finally {
if locked
Gdip_UnlockBits(scaled, &data)
if graphics
Gdip_DeleteGraphics(graphics)
if scaled
Gdip_DisposeImage(scaled)
}
}
DetectBitmap(native) => DllCall("RapidOcrOnnx\OcrDetectBitmapData", "Ptr", this.engine, "Ptr", native,
"Ptr", this.parameters, "Ptr", this.callback, "Ptr", 0, "Int")
Dispose() {
engine := this.engine, callback := this.callback
this.engine := this.callback := 0
try {
if engine
DllCall("RapidOcrOnnx\OcrDestroy", "Ptr", engine)
} finally {
if callback
CallbackFree(callback)
}
}
}
class StoryVision {
static Regions := Map("vote",[290,25,230,125],"result",[125,150,390,275],"choice",[130,80,545,110])
static ChoiceFallback(bitmap) {
for id in ["next-room","retry","replay"] {
if !CrusadersDetection.FindBitmap(bitmap,id,&x,&y)
continue
result := Map("kind","choice","text",id,"ownerWait",0,"hasNextLevel",0)
if id = "next-room"
result["hasNextRoom"] := 1, result["nextRoomX"] := x+84
else {
result["replayX"] := x+84
if id = "retry"
result["hasRetry"] := 1
}
return result
}
return Map("kind","none","text","","ownerWait",0)
}
static Parse(stage,text) {
normalized := StrLower(RegExReplace(text,"[^a-zA-Z0-9]",""))
result := Map("kind","none","text",text,"ownerWait",0)
if stage="vote" && InStr(normalized,"votestart") && InStr(normalized,"yes")
result["kind"] := "vote"
if stage="result" {
if InStr(normalized,"victory") && InStr(normalized,"next")
result["kind"] := "victory"
else if InStr(normalized,"defeat") || InStr(normalized,"gameover")
result["kind"] := "defeat"
}
if stage="choice" && InStr(normalized,"picknextportal") && InStr(normalized,"returntolobby")
result["kind"] := "choice", result["hasNextPortal"] := 1, result["hasNextLevel"] := 0
if stage="choice" && InStr(normalized,"returntolobby") && !RegExMatch(normalized,"replay|retry|nextroom|nextlevel|picknextportal")
result["kind"] := "challenge-exit"
if stage="choice" && InStr(normalized,"replay") && (InStr(normalized,"nextlevel") || InStr(normalized,"returntolobby")) {
result["kind"] := "choice"
result["ownerWait"] := InStr(normalized,"waitingforowner")?1:0
result["hasNextLevel"] := InStr(normalized,"nextlevel")?1:0
result["replayX"] := result["hasNextLevel"] ? 400 : 488
}
if stage="choice" && InStr(normalized,"retry") && InStr(normalized,"returntolobby") {
result["kind"] := "choice"
result["hasRetry"] := 1
result["hasNextLevel"] := 0
result["replayX"] := 488
}
if stage="choice" && InStr(normalized,"nextroom") && InStr(normalized,"returntolobby") {
result["kind"] := "choice"
result["hasNextRoom"] := 1
result["nextRoomX"] := 488
result["hasNextLevel"] := 0
}
if stage = "reward" && RegExMatch(normalized,"(?:c[l1i][i1l]ck|tap)any(?:w|vv)here(?:t[o0])?c[o0]nt[i1l]nue")
result["kind"] := "reward"
if stage = "placement" && RegExMatch(text,"i)\b(?:Sell|First|Strongest|Closest|Last|Farthest|Weakest)\b") && (InStr(normalized,"upgrade") || InStr(normalized,"max"))
result["kind"] := "unit-panel"
return result
}
static DungeonResult(reader,bitmap) {
if CrusadersDetection.FindBitmap(bitmap,"dungeon-victory-title") && (CrusadersDetection.FindBitmap(bitmap,"victory") || CrusadersDetection.FindBitmap(bitmap,"dungeon-next-label"))
return Map("kind","victory","text","Dungeon Victory + Next","ownerWait",0)
return this.Parse("result",reader.Read(bitmap,125,150,390,275,2))
}
static ReadReward(reader,bitmap) {
text := ""
for crop in [[200,420,400,100,2],[200,445,400,45,3],[200,420,400,100,3]] {
text := reader.Read(bitmap,crop[1],crop[2],crop[3],crop[4],crop[5])
result := this.Parse("reward",text)
if result["kind"] = "reward"
return result
}
if this.RewardLettering(bitmap)
return Map("kind","reward","text","Click anywhere to continue (lettering)","ownerWait",0)
return Map("kind","none","text",text,"ownerWait",0)
}
static RewardWhite(color) => Min((color>>16)&255,(color>>8)&255,color&255)>=170 && Max((color>>16)&255,(color>>8)&255,color&255)-Min((color>>16)&255,(color>>8)&255,color&255)<=70
static RewardDark(color) => Max((color>>16)&255,(color>>8)&255,color&255)<=110
static RewardLettering(bitmap) {
static mask := 0
if !mask {
reference := Gdip_CreateBitmapFromFile(A_ScriptDir "\Images\Detection\AA\reward-continue.png")
if !reference
return false
try {
strokes := [], edges := [], white := Map()
Loop 17 {
y := A_Index+2
Loop 191 {
x := A_Index+5, color := Gdip_GetPixel(reference,x,y)
if Min((color>>16)&255,(color>>8)&255,color&255)>=180 && Max((color>>16)&255,(color>>8)&255,color&255)-Min((color>>16)&255,(color>>8)&255,color&255)<=45
strokes.Push([x,y]), white[x "," y] := true
}
}
if strokes.Length < 100
return false
for point in strokes
for delta in [[-1,0],[1,0],[0,-1],[0,1]] {
x := point[1]+delta[1], y := point[2]+delta[2]
if !white.Has(x "," y) && this.RewardDark(Gdip_GetPixel(reference,x,y))
edges.Push([x,y])
}
if edges.Length < 50
return false
anchors := []
Loop 6
anchors.Push(strokes[1+Floor((A_Index-1)*(strokes.Length-1)/5)])
mask := {strokes:strokes,edges:edges,anchors:anchors}
} finally Gdip_DisposeImage(reference)
}
if Gdip_LockBits(bitmap,0,0,800,600,&stride,&pixels,&bits,1) != 0
return false
try {
Loop 68 {
top := 419+A_Index
Loop 121 {
left := 239+A_Index, candidate := true
for point in mask.anchors
if !this.RewardWhite(NumGet(pixels+(top+point[2])*stride+(left+point[1])*4,"UInt")) {
candidate := false
break
}
if !candidate
continue
hits := 0
for point in mask.strokes
if this.RewardWhite(NumGet(pixels+(top+point[2])*stride+(left+point[1])*4,"UInt"))
hits++
if hits < mask.strokes.Length*0.88
continue
hits := 0
for point in mask.edges
if this.RewardDark(NumGet(pixels+(top+point[2])*stride+(left+point[1])*4,"UInt"))
hits++
if hits >= mask.edges.Length*0.65
return true
}
}
return false
} finally Gdip_UnlockBits(bitmap,&bits)
}
static WaveNumber(text) {
if RegExMatch(text,"i)\bWave\s*:?\s*(\d{1,4})\b",&match)
return Integer(match[1])
return -1
}
static UpgradeLevel(text) {
if RegExMatch(text,"i)\bUpgrade\s*[\[({]\s*([0-9OIl]{1,2})\s*[\])}]",&match) {
digits := StrReplace(StrReplace(StrReplace(match[1],"O","0"),"o","0"),"I","1")
digits := StrReplace(StrReplace(digits,"l","1"),"i","1")
return Integer(digits)
}
if RegExMatch(text,"i)\bUpgrade\s+(\d{1,2})(?![A-Za-z0-9\]])",&match)
return Integer(match[1])
return -1
}
static MaxUpgrade(reader,bitmap,header := "") {
if header = ""
header := reader.Read(bitmap,165,190,145,40,3)
if RegExMatch(header,"i)\bMAX\b") || CrusadersDetection.FindBitmap(bitmap,"upgrade-max-button")
return true
button := reader.Read(bitmap,210,350,80,35,3)
return RegExMatch(button,"i)^\s*max\s*$") ? true : false
}
static PriorityName(text) {
text := StrLower(RegExReplace(text,"[^A-Za-z]",""))
aliases := Map("first","First","strong","Strongest","strongest","Strongest","close","Closest","closest","Closest","last","Last","farthest","Farthest","weakest","Weakest")
return aliases.Get(text,"")
}
static ReadPriority(reader,bitmap) {
text := reader.Read(bitmap,15,240,105,145,3)
names := [], seen := Map(), offset := 1
while position := RegExMatch(text,"i)\b(First|Strongest|Strong|Closest|Close|Last|Farthest|Weakest)\b",&match,offset) {
name := this.PriorityName(match[1])
if !seen.Has(name)
names.Push(name), seen[name] := true
offset := position+StrLen(match[0])
}
menu := names.Length >= 3, options := Map()
ys := [258,280,302,325,347,372]
if names.Length = 6 {
for row, name in names
options[name] := Map("x",54,"y",ys[row])
} else if menu {
for y in ys {
name := this.PriorityName(reader.Read(bitmap,16,y-10,76,21,4))
if name != ""
options[name] := Map("x",54,"y",y)
}
}
selected := menu && names.Length = 6 ? names[6] : this.PriorityName(reader.Read(bitmap,15,357,80,28,4))
return Map("kind","priority","menu",menu,"selected",selected,"options",options,"text",text,"ownerWait",0)
}
static ReadAutoAbility(bitmap,result) {
AAAprilFools.Register()
if CrusadersDetection.FindBitmap(bitmap,"april-auto-on",&x,&y)
result["auto"] := "on"
else if CrusadersDetection.FindBitmap(bitmap,"april-auto-off",&x,&y)
result["auto"] := "off", result["autoX"] := x+25, result["autoY"] := y+8
return result
}
static ReadUpgrade(reader,bitmap,autoAbility := true,panel := 0) {
if IsObject(panel) && (panel.Get("level",-1)>=0 || panel.Get("max",false)) {
level := panel.Get("level",-1)
result := Map("kind","upgrade","text",panel["text"],"level",level,"max",panel.Get("max",false) || this.MaxUpgrade(reader,bitmap,panel["text"]),"ownerWait",0)
} else result := this.ReadUpgradeLevel(reader,bitmap)
if autoAbility && (result["level"] >= 0 || result["max"])
this.ReadAutoAbility(bitmap,result)
return result
}
static ReadUpgradeLevel(reader,bitmap) {
for knownLevel in [0,1,2,3,4]
if CrusadersDetection.FindBitmap(bitmap,"upgrade-" knownLevel)
return Map("kind","upgrade","text","Upgrade [" knownLevel "]","level",knownLevel,"max",this.MaxUpgrade(reader,bitmap,"Upgrade [" knownLevel "]"),"ownerWait",0)
header := reader.Read(bitmap,165,190,115,40,2)
level := this.UpgradeLevel(header)
if level >= 0 || RegExMatch(header,"i)\bMAX\b")
return Map("kind","upgrade","text",header,"level",level,"max",this.MaxUpgrade(reader,bitmap,header),"ownerWait",0)
text := ""
for scale in [2,3,4] {
text := reader.Read(bitmap,160,180,145,65,scale)
level := this.UpgradeLevel(text)
if level >= 0
return Map("kind","upgrade","text",text,"level",level,"max",this.MaxUpgrade(reader,bitmap,text),"ownerWait",0)
}
return Map("kind","upgrade","text",text,"level",-1,"max",this.MaxUpgrade(reader,bitmap,text),"ownerWait",0)
}
static FastPlacement(reader,bitmap) {
for id in ["upgrade-0","upgrade-1","upgrade-2","upgrade-3","upgrade-4","upgrade-max-button"]
if CrusadersDetection.FindBitmap(bitmap,id)
return Map("kind","unit-panel","text","Calibrated upgrade control","level",id = "upgrade-max-button" ? -1 : Integer(SubStr(id,9)),"max",id = "upgrade-max-button","ownerWait",0)
red1 := Gdip_GetPixel(bitmap,317,188), red2 := Gdip_GetPixel(bitmap,329,176)
cross := Gdip_GetPixel(bitmap,329,188)
sell := Gdip_GetPixel(bitmap,104,363)
for red in [red1,red2]
if ((red>>16)&255) < 160 || ((red>>8)&255) > 90 || (red&255) > 100
return 0
if Min((cross>>16)&255,(cross>>8)&255,cross&255) < 170
return 0
if !this.UpgradeLettering(bitmap) {
header := reader.Read(bitmap,165,190,115,40,3)
if this.UpgradeLevel(header)<0 && !RegExMatch(header,"i)\bMAX\b")
return 0
}
return Map("kind","unit-panel","text","Upgrade controls","ownerWait",0)
}
static UpgradeLettering(bitmap) {
static strokes := 0
if !strokes {
reference := Gdip_CreateBitmapFromFile(A_ScriptDir "\Images\Detection\AA\upgrade-0.png")
if !reference
return false
try {
points := []
Loop Gdip_GetImageHeight(reference) {
y := A_Index-1
Loop 64 {
x := A_Index+6
color := Gdip_GetPixel(reference,x,y)
if this.UpgradeGold(color)
points.Push([x,y])
}
}
if points.Length < 50
return false
strokes := points
} finally Gdip_DisposeImage(reference)
}
for dy in [0,-1,1,-2,2] {
for dx in [0,-1,1,-2,2] {
hits := 0, misses := 0, allowed := Floor(strokes.Length*0.12)
for point in strokes {
if this.UpgradeGold(Gdip_GetPixel(bitmap,165+dx+point[1],190+dy+point[2]))
hits++
else if ++misses > allowed
break
}
if hits >= Ceil(strokes.Length*0.88)
return true
}
}
return false
}
static UpgradeGold(color) => ((color>>16)&255)>150 && ((color>>8)&255)>120 && (color&255)<130
static CoveredResult(reader,bitmap) {
dark := 0
for point in [[540,145],[735,145],[540,430],[735,430]] {
color := Gdip_GetPixel(bitmap,point[1],point[2])
r := (color>>16)&255, g := (color>>8)&255, b := color&255
if Max(r,g,b) <= 65 && Max(r,g,b)-Min(r,g,b) <= 15
dark++
}
if dark < 3
return false
if !CrusadersDetection.FindBitmap(bitmap,"dungeon-xp-title") {
heading := reader.Read(bitmap,525,120,245,60,2)
if !InStr(StrLower(RegExReplace(heading,"[^a-zA-Z]","")),"xpprogress")
return false
}
if this.FastPlacement(reader,bitmap)
return true
panel := this.Parse("placement",reader.Read(bitmap,5,180,335,225,2))
return panel["kind"] = "unit-panel"
}
static SettingsSpawn(reader,bitmap) {
none := Map("kind","none","ownerWait",0)
if Gdip_GetImageWidth(bitmap)!=800 || Gdip_GetImageHeight(bitmap)!=600
return none
text := StrLower(RegExReplace(reader.Read(bitmap,210,120,405,365,2),"[^A-Za-z]",""))
if !InStr(text,"teleport") || !InStr(text,"spawn") || !InStr(text,"returntolobby")
return none
left := 800, right := 0, top := 600, bottom := 0, count := 0
loop 61 {
y := 110+(A_Index-1)*2
loop 46 {
x := 540+(A_Index-1)*2, rgb := Gdip_GetPixel(bitmap,x,y)
if ((rgb>>16)&255)>170 && ((rgb>>8)&255)<90 && (rgb&255)<90
left := Min(left,x), right := Max(right,x), top := Min(top,y), bottom := Max(bottom,y), count++
}
}
if count<100 || right-left<30 || right-left>70 || bottom-top<30 || bottom-top>70
return none
loop 10 {
y := 220+(A_Index-1)*24
label := StrLower(RegExReplace(reader.Read(bitmap,230,y,295,36,3),"[^A-Za-z]",""))
if !InStr(label,"teleport") || !InStr(label,"spawn")
continue
best := 0, distance := 999
loop 19 {
cy := y+2+(A_Index-1)*2
for cx in [520,516,524,512,528] {
for radius in [12,13,14,15] {
upper := Gdip_GetPixel(bitmap,cx,cy-radius), lower := Gdip_GetPixel(bitmap,cx,cy+radius)
if !this.SettingsEdge(upper) || !this.SettingsEdge(lower)
continue
inner1 := Gdip_GetPixel(bitmap,cx,cy-radius+4), inner2 := Gdip_GetPixel(bitmap,cx,cy+radius-4)
if Max((inner1>>16)&255,(inner1>>8)&255,inner1&255)>35
|| Max((inner2>>16)&255,(inner2>>8)&255,inner2&255)>35
continue
delta := Abs(cy-(y+22))+Abs(cx-520)/8
if delta<distance
distance := delta, best := [cx,cy]
}
}
}
if best
return Map("kind","settings-spawn","x",best[1],"y",best[2],"closeX",(left+right)//2,"closeY",(top+bottom)//2,"ownerWait",0)
}
return none
}
static SettingsEdge(rgb) {
r := (rgb>>16)&255, g := (rgb>>8)&255, b := rgb&255
return Min(r,g,b)>=40 && Max(r,g,b)<=110 && Max(r,g,b)-Min(r,g,b)<=15
}
static Read(reader,bitmap,stage,autoAbility := true) {
connection := AAConnection.Poll(reader,bitmap)
if connection["kind"] != "none"
return connection
if stage = "settings-spawn"
return this.SettingsSpawn(reader,bitmap)
if stage = "april-exit"
return AAAprilFools.ReadExit(reader,bitmap)
if stage = "dungeon-death-exit" {
if (exit := AADungeons.ReadReturnLobby(reader,bitmap))
return exit
if (death := AADungeons.ReadDeath(reader,bitmap))
return death
return AALobbyVision.Read(reader,bitmap)
}
if stage = "dungeon-board" {
board := AADungeons.Read(reader,bitmap,false,true,0,false)
if board["kind"] = "dungeon-died" || (board["kind"] = "dungeon-board" && board["cards"].Length)
return board
stage := "dungeon"
}
if stage = "dungeon-chest-reward" {
if menu := AADungeons.FastMenu(reader,bitmap)
if menu["kind"]="dungeon-chests"
return AADungeons.Read(reader,bitmap,false,false,menu,false)
reward := this.ReadReward(reader,bitmap)
if reward["kind"] = "reward"
return reward
return AADungeons.Read(reader,bitmap,false,false,0,false)
}
if stage = "dungeon" || stage = "dungeon-transition" || stage = "dungeon-result" {
if stage != "dungeon-transition" && (menu := AADungeons.FastMenu(reader,bitmap))
return AADungeons.Read(reader,bitmap,false,false,menu,false)
if stage != "dungeon-transition" {
if this.CoveredResult(reader,bitmap)
return Map("kind","result-covered","text","Unit panel covers dungeon results","ownerWait",0)
ended := this.DungeonResult(reader,bitmap)
if ended["kind"] != "none"
return ended
reward := this.ReadReward(reader,bitmap)
if reward["kind"] = "reward"
return reward
}
result := AADungeons.Read(reader,bitmap,stage = "dungeon-transition",false,0,false)
if result["kind"] != "none" || stage = "dungeon-transition"
return result
stage := "result"
}
if stage = "april-vote-or-wave" {
mapScan := AAAprilFools.ReadMap(reader,bitmap)
if mapScan["kind"] != "none"
return mapScan
stage := "vote-or-wave"
}
startedMatchCheck := stage = "vote-or-wave"
if startedMatchCheck
stage := "vote"
if stage = "mansion-transition" {
loading := AAMansionRoute.ReadLoadingMap(reader,bitmap)
if loading["kind"] = "mansion-map"
return loading
vote := this.Parse("vote",reader.Read(bitmap,290,25,230,125,2))
if vote["kind"] = "vote"
return vote
stage := "choice"
}
if AALeaderboard.Visible(bitmap)
return Map("kind","leaderboard","text","Leaderboard","ownerWait",0)
if stage = "portal-picker"
return AAPortalReplay.Read(reader,bitmap)
if stage = "matchmaking-numbers" {
text := Trim(reader.Read(bitmap,228,260,346,50,4))
valid := RegExMatch(text,"^\s*(\d(?:[ \t]*\d){0,11})\s*$",&digits)
return Map("kind",valid ? "matchmaking-numbers" : "matchmaking-missing",
"text",valid ? RegExReplace(digits[1],"\s","") : text,"ownerWait",0)
}
if stage = "april-map"
return AAAprilFools.ReadMap(reader,bitmap)
if stage = "matchmaking-lobby" {
mapScan := AAAprilFools.ReadMap(reader,bitmap)
if mapScan["kind"] != "none"
return mapScan
status := reader.Read(bitmap,180,350,450,135,3)
greenPixels := 0
loop 45 {
y := 350+(A_Index-1)*3
loop 150 {
color := Gdip_GetPixel(bitmap,180+(A_Index-1)*3,y)
red := (color>>16)&255, green := (color>>8)&255, blue := color&255
if green > 150 && green > red*1.15 && blue < 110
greenPixels++
}
}
return Map("kind",AALobbyVision.MatchmakingStarted(status) ? "matchmaking-ready" : greenPixels >= 30 ? "matchmaking-visible" : "matchmaking-waiting",
"text",status,"ownerWait",0)
}
if stage = "april-entry" {
text := reader.Read(bitmap,210,215,390,175,2)
normalized := StrLower(RegExReplace(text,"[^A-Za-z]",""))
ready := InStr(normalized,"findmatch") || (InStr(normalized,"joinmatchmaking") && InStr(normalized,"playhere"))
return Map("kind",ready ? "april-entry" : "none","text",text,"ownerWait",0)
}
if stage = "april" || stage = "april-upgrade" {
ended := AAAprilFools.ReadResult(reader,bitmap)
if ended["kind"] != "none"
return ended
}
if stage = "april-upgrade"
return Map("kind","none","text","","ownerWait",0)
if (stage = "april" || stage = "priority" || stage = "placement-auto") && this.CoveredResult(reader,bitmap)
return Map("kind","result-covered","text","Unit panel covers results","ownerWait",0)
if stage = "april"
return AAAprilFools.Read(reader,bitmap,false)
if stage = "priority" || stage = "placement-auto" {
ended := this.Parse("result",reader.Read(bitmap,125,150,390,275,2))
if ended["kind"] != "none"
return ended
choice := this.ChoiceFallback(bitmap)
if choice["kind"] = "choice"
return choice
if stage = "priority"
return this.ReadPriority(reader,bitmap)
return this.ReadAutoAbility(bitmap,Map("kind","upgrade","level",-1,"max",false,"ownerWait",0))
}
if stage = "challenge-entry" {
loading := AAChallengeDetection.ReadLoadingMap(reader,bitmap)
if loading["kind"] = "challenge-map"
return loading
pod := AAChallengeDetection.ReadPodMap(reader,bitmap)
if pod["kind"] = "challenge-map"
return pod
return this.Parse("vote",reader.Read(bitmap,290,25,230,125,2))
}
if stage = "challenge-pod"
return AAChallengeDetection.ReadPodMap(reader,bitmap)
if stage = "challenge-loading" {
challenge := AAChallengeDetection.ReadLoadingMap(reader,bitmap)
if challenge["kind"] = "challenge-map"
return challenge
return this.Parse("vote",reader.Read(bitmap,290,25,230,125,2))
}
if stage = "lobby"
return AALobbyVision.Read(reader,bitmap)
if stage = "mansion-initial"
return AAMansionRoute.ReadInitialMap(reader,bitmap)
if stage = "mansion-loading"
return AAMansionRoute.ReadLoadingMap(reader,bitmap)
if this.CoveredResult(reader,bitmap)
return Map("kind","result-covered","text","Unit panel covers results","ownerWait",0)
if stage = "choice" {
reward := this.ReadReward(reader,bitmap)
if reward["kind"] = "reward"
return reward
}
if (stage = "placement" || stage = "upgrade") && (panel := this.FastPlacement(reader,bitmap)) {
for resultId in ["victory","defeat"]
if CrusadersDetection.FindBitmap(bitmap,resultId)
return Map("kind",resultId,"text",resultId,"ownerWait",0)
choice := this.ChoiceFallback(bitmap)
if choice["kind"] = "choice"
return choice
if stage = "upgrade"
return this.ReadUpgrade(reader,bitmap,autoAbility,panel)
panel["auto"] := ""
if autoAbility
this.ReadAutoAbility(bitmap,panel)
return panel
}
if stage = "placement" || stage = "upgrade" {
ended := this.Parse("result",reader.Read(bitmap,125,150,390,275,2))
if ended["kind"] != "none"
return ended
}
if stage != "choice" {
choice := this.Parse("choice",reader.Read(bitmap,130,80,545,110,2))
if choice["kind"] = "choice"
return choice
choice := this.ChoiceFallback(bitmap)
if choice["kind"] = "choice"
return choice
}
if stage = "placement" || stage = "upgrade" || stage = "wave" || stage = "priority" {
if stage != "placement" && stage != "upgrade" {
result := this.Parse("result",reader.Read(bitmap,125,150,390,275,2))
if result["kind"] != "none"
return result
}
for resultId in ["victory","defeat"]
if CrusadersDetection.FindBitmap(bitmap,resultId)
return Map("kind",resultId,"text",resultId,"ownerWait",0)
if stage = "wave" {
text := reader.Read(bitmap,140,60,220,65,3)
return Map("kind","wave","wave",this.WaveNumber(text),"text",text,"ownerWait",0)
}
if stage = "priority"
return this.ReadPriority(reader,bitmap)
if stage = "upgrade"
return this.ReadUpgrade(reader,bitmap,autoAbility)
panel := this.Parse("placement",reader.Read(bitmap,5,180,335,225,2))
if panel["kind"] = "unit-panel" {
panel["auto"] := ""
if autoAbility
this.ReadAutoAbility(bitmap,panel)
}
return panel
}
id := stage = "vote" ? "vote-start" : stage = "choice" ? "next-level" : "victory"
detector := CrusadersDetection.Get(id)
result := this.Parse(stage,reader.Read(bitmap,detector.x,detector.y,detector.w,detector.h,2))
if startedMatchCheck && result["kind"] = "none" {
ended := this.Parse("result",reader.Read(bitmap,125,150,390,275,2))
if ended["kind"] != "none"
return ended
text := reader.Read(bitmap,140,60,220,65,3)
wave := this.WaveNumber(text)
if wave >= 1
return Map("kind","wave","wave",wave,"text",text,"ownerWait",0)
}
if stage = "result" && result["kind"] = "none" {
for resultId in ["victory","defeat"]
if CrusadersDetection.FindBitmap(bitmap,resultId)
return Map("kind",resultId,"text",resultId,"ownerWait",0)
}
if stage = "result" && FileExist(CrusadersDetection.overrideRoot "\defeat.png")
&& CrusadersDetection.FindBitmap(bitmap,"defeat")
result["kind"] := "defeat"
if result["kind"] = "none" && FileExist(CrusadersDetection.overrideRoot "\" id ".png")
&& CrusadersDetection.FindBitmap(bitmap,id) {
result["kind"] := stage = "vote" ? "vote" : stage = "choice" ? "choice" : "victory"
normalized := StrLower(RegExReplace(result["text"],"[^a-zA-Z0-9]",""))
result["ownerWait"] := !!InStr(normalized,"waitingforowner")
}
if stage = "choice" && result["kind"] = "none"
return this.ChoiceFallback(bitmap)
return result
}
}
class StoryFiles {
static Retry(operation) {
Loop 10 {
try return operation.Call()
catch OSError as err {
if (err.Number != 32 && err.Number != 33) || A_Index = 10
throw err
Sleep(15)
}
}
}
static Read(path) => this.Retry((*)=>FileRead(path,"UTF-8"))
static Delete(path) => this.Retry((*)=>FileDelete(path))
static Write(path,text) => this.Retry((*)=>Adventures.Write(path,text))
}
class StoryOcrClient {
static sequence := 0
static ScanTimeout := 30000
static InitTimeout := 60000
static MaxRecoveries := 3
__New(owner) {
this.owner := owner, this.pid := 0, this.pending := false, this.serial := 0, this.token := 0
this.recoveries := 0
StoryOcrClient.sequence++
this.root := A_Temp "\BayzosAA-" DllCall("GetCurrentProcessId") "-" Adventures.Tick() "-" StoryOcrClient.sequence
DirCreate(this.root)
try {
this.token := Gdip_Startup()
if !this.token
throw Error("Could not initialize screen capture.")
this.born := Adventures.Tick()
executable := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
arguments := A_IsCompiled ? "" : ' "' A_ScriptFullPath '"'
Run('"' executable '"' arguments ' --ocr-worker "' this.root '" ' DllCall("GetCurrentProcessId"),,"Hide",&pid)
this.pid := pid
} catch Error as err {
this.Dispose()
throw err
}
}
Ready() {
statusFile := this.root "\ready.txt"
if FileExist(statusFile) {
status := Trim(StoryFiles.Read(statusFile))
if SubStr(status,1,1) = "{" {
detail := Jxon_Load(&status)
if detail.Has("error")
throw Error("OCR: " detail["error"])
}
}
if !ProcessExist(this.pid)
return this.Restart("worker exited")
if !FileExist(this.root "\ready.txt") && Adventures.Tick()-this.born>StoryOcrClient.InitTimeout
return this.Restart("initialization timed out")
return FileExist(this.root "\ready.txt")
}
Restart(reason) {
attempts := this.recoveries+1
if attempts > StoryOcrClient.MaxRecoveries
throw Error("OCR recovery failed after " StoryOcrClient.MaxRecoveries " retries (" reason ").")
owner := this.owner, serial := this.serial
this.Dispose()
this.__New(owner)
this.recoveries := attempts, this.serial := serial+1
if IsObject(owner) && HasMethod(owner,"Log")
owner.Log("OCR " reason "; restarting scan worker (" attempts "/" StoryOcrClient.MaxRecoveries ")")
return false
}
Request(stage,autoAbility := true) {
if this.pending || !this.Ready()
return
this.owner.CheckClient()
WinGetClientPos(&x,&y,&width,&height,this.owner.hwnd)
bitmap := Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
if !bitmap
throw Error("Could not capture Roblox for OCR.")
try {
if Gdip_SaveBitmapToFile(bitmap,this.root "\frame.png")!=0
throw Error("Could not write the OCR frame.")
} finally Gdip_DisposeImage(bitmap)
this.serial++, this.pending := true, this.requested := Adventures.Tick()
StoryFiles.Write(this.root "\request.json",Jxon_Dump(Map("id",this.serial,"stage",stage,"autoAbility",autoAbility)))
}
Poll() {
if !this.Ready()
return 0
if !this.pending
return 0
path := this.root "\response.json"
if !FileExist(path) {
if Adventures.Tick()-this.requested>StoryOcrClient.ScanTimeout
return this.Restart("scan timed out")
return 0
}
raw := StoryFiles.Read(path), result := Jxon_Load(&raw)
StoryFiles.Delete(path)
this.pending := false
if result.Get("id",-1)!=this.serial
throw Error("OCR response did not match the current scan.")
if result.Has("error")
throw Error(result["error"])
this.recoveries := 0
return result
}
Dispose() {
if this.pid {
if ProcessExist(this.pid)
ProcessClose(this.pid)
this.pid := 0
}
if this.token
Gdip_Shutdown(this.token), this.token := 0
prefix := A_Temp "\BayzosAA-" DllCall("GetCurrentProcessId") "-"
if SubStr(this.root,1,StrLen(prefix))=prefix && !InStr(SubStr(this.root,StrLen(prefix)+1),"\")
try DirDelete(this.root,1)
}
}
StoryOcrWorker(root,parent) {
token := 0, reader := 0, bitmap := 0
try {
token := Gdip_Startup(), reader := AdventuresOcr()
StoryFiles.Write(root "\ready.txt","ready")
while ProcessExist(parent) {
if FileExist(root "\request.json") {
raw := StoryFiles.Read(root "\request.json"), request := Jxon_Load(&raw)
StoryFiles.Delete(root "\request.json")
response := Map("id",request["id"])
try {
bitmap := Gdip_CreateBitmapFromFile(root "\frame.png")
if !bitmap || Gdip_GetImageWidth(bitmap)!=800 || Gdip_GetImageHeight(bitmap)!=600
throw Error("OCR requires an 800x600 Roblox client.")
response := StoryVision.Read(reader,bitmap,request["stage"],request.Get("autoAbility",true))
response["id"] := request["id"]
} catch Error as err {
response["error"] := "OCR scan failed: " err.Message
} finally {
if bitmap
Gdip_DisposeImage(bitmap), bitmap := 0
}
StoryFiles.Write(root "\response.json",Jxon_Dump(response))
}
Sleep(15)
}
} catch Error as err {
try StoryFiles.Write(root "\ready.txt",Jxon_Dump(Map("error",err.Message)))
} finally {
if reader
reader.Dispose()
if token
Gdip_Shutdown(token)
}
}
class StoryLoop {
__New(app) {
this.app := app, this.timer := ObjBindMethod(this,"Tick"), this.busy := false
this.worker := 0, this.cameraHeld := false, this.stage := "AwaitVote", this.scanned := 0
this.epoch := 0, this.lastClick := 0, this.retries := 0, this.votes := 0, this.absent := 0
}
Start() {
if this.app.profile["width"]!=800 || this.app.profile["height"]!=600
throw Error("Story Farming is calibrated for an 800x600 client. Resize Roblox and capture at that size.")
this.worker := StoryOcrClient(this.app)
this.app.status := "Running", this.app.completed := 0
if !this.app.HasOwnProp("wins")
this.app.wins := 0
if !this.app.HasOwnProp("losses")
this.app.losses := 0
this.defeated := false, this.resultCounted := false
this.stage := "AwaitVote", this.deadline := Adventures.Tick()+120000, this.scanned := 0, this.due := 0
if HasMethod(this.app,"IsDungeon") && this.app.IsDungeon() {
this.dungeon := AADungeonRun(this)
this.stage := "Dungeon"
this.app.Log("Reading preserved Dungeon progress")
} else this.app.Log("Waiting for match")
SetTimer(this.timer,50)
}
Change(stage,timeout:=120000) {
this.configComplete := false
if stage = "AwaitVote" {
if this.HasOwnProp("startedWaveBeforeCamera")
this.DeleteProp("startedWaveBeforeCamera")
this.waveFrames := 0, this.waveCandidate := -1
}
if stage = "Camera" || stage = "AwaitVote" {
this.resultCounted := false
this.rewardSerial := 0, this.rewardDismissals := 0
}
if stage = "RewardDelay"
this.rewardDismissals := 0
if stage = "RewardDelay" && HasMethod(this.app,"IsChallenge") && this.app.IsChallenge() {
this.rewardClicks := 0
timeout := Max(timeout,this.app.rewardDelay+12*Max(750,this.Delay("StageClickDelay",1000))+15000)
}
this.stage := stage, this.deadline := Adventures.Tick()+timeout
this.due := Adventures.Tick(), this.scanned := 0, this.retries := 0, this.absent := 0
this.app.Publish()
}
Delay(key,fallback) {
return this.app.HasOwnProp("model") ? Max(0,Integer(this.app.model.preferences.Get(key,String(fallback)))) : fallback
}
ClickAt(x,y) {
previous := Critical(1)
try {
this.app.CheckClient()
AAInput.Click(this.app.hwnd,x,y,ObjBindMethod(this.app,"CheckClient"))
} finally Critical(previous)
}
ReleaseCamera() {
if this.cameraHeld {
SendEvent("{RButton up}")
this.cameraHeld := false
}
}
static SpawnPlan(scale) {
if scale>=138
return Map("scrolls",4,"x",520,"y",350,"closeX",574,"closeY",174)
if scale>=113
return Map("scrolls",6,"x",522,"y",328,"closeX",584,"closeY",151)
return Map("scrolls",6,"x",522,"y",327,"closeX",584,"closeY",151)
}
SpawnScale() {
scale := 100
monitor := DllCall("MonitorFromWindow","Ptr",this.app.hwnd,"UInt",2,"Ptr")
if DllCall("Shcore\GetScaleFactorForMonitor","Ptr",monitor,"Int*",&scale,"Int")!=0
scale := Round(AADisplay.Dpi(this.app.hwnd)*100/96)
return scale
}
ScrollSettings() {
this.app.CheckClient()
WinGetClientPos(&left,&top,,,this.app.hwnd)
previousMode := A_CoordModeMouse, previousSend := A_SendMode
CoordMode("Mouse","Screen"), SendMode("Event")
try {
MouseMove(left+460,top+350,2)
Sleep(50)
this.app.CheckClient()
Loop 1 {
this.app.CheckClient()
SendEvent("{WheelDown}")
Sleep(50)
}
} finally {
SendMode(previousSend)
CoordMode("Mouse",previousMode)
}
}
Camera() {
if Adventures.Tick()<this.due
return
this.app.CheckClient()
previous := Critical(1)
try {
this.app.CheckClient()
if this.cameraStep=0 {
if this.HasOwnProp("dungeon")
this.app.Log("Dungeon camera: starting top-down zoom and right-button tilt")
WinGetClientPos(&left,&top,,,this.app.hwnd)
CoordMode("Mouse","Screen")
MouseMove(left+400,top+330,5)
}
if this.cameraStep<20 {
SendEvent("{WheelUp 2}")
this.cameraStep++
}
else if this.cameraStep=20 {
SendEvent("{RButton down}")
this.cameraHeld := true
moved := 0
Loop 24 {
this.app.CheckClient()
if A_Index <= 16 {
destination := Round(1500*(1-Cos(A_Index*3.141592653589793/16))/2)
DllCall("mouse_event","UInt",1,"Int",0,"Int",destination-moved,"UInt",0,"UPtr",0)
moved := destination
}
if A_Index = 16
this.ReleaseCamera()
if A_Index >= 5
SendEvent("{WheelDown}")
Sleep(Max(12,Round(this.Delay(A_Index <= 16 ? "DragDelay" : "ZoomOutDelay",50)/3)))
}
this.cameraStep := 51
}
else {
if this.HasOwnProp("cameraOnly") && this.cameraOnly {
this.Stop(false)
this.app.Log("Zoomtech complete.")
return
}
if HasMethod(this.app,"NeedsSpawnReset") && this.app.NeedsSpawnReset() {
this.Change("SettingsOpen",30000)
this.due := Adventures.Tick()+500
} else if HasMethod(this.app,"NeedsMapPath") && this.app.NeedsMapPath()
this.Change("MapPath",20000)
else this.ReadyForVote()
this.app.Log("Camera ready")
return
}
this.cameraStep++, this.due := Adventures.Tick()+this.Delay(this.cameraStep <= 20 ? "ZoomInDelay" : this.cameraStep <= 32 ? "DragDelay" : "ZoomOutDelay",50)
} finally Critical(previous)
}
Tick() {
if this.app.HasOwnProp("owner") && this.app.owner.HasOwnProp("shopTestBusy") && this.app.owner.shopTestBusy
return
if this.busy || this.app.status!="Running"
return
this.busy := true, epoch := this.epoch
try {
now := Adventures.Tick()
if (this.stage = "AwaitMansionMap" || this.stage = "AwaitTransition" || this.stage = "AwaitVote" || this.stage = "AprilExitLobby" || (this.stage = "Dungeon" && this.HasOwnProp("dungeon") && this.dungeon.phase = "death-returning")) && HasMethod(this.app,"RefreshAfterTeleport") {
if !this.app.RefreshAfterTeleport() {
if now > this.deadline
throw Error("Roblox did not return after loading the match.")
return
}
}
if (this.app is AASession || this.app is AACameraSession) && AAInput.WaitingForFocus(this,this.app.hwnd)
return
this.app.CheckClient()
now := Adventures.Tick()
if SubStr(this.stage,1,9) = "AprilExit" {
if now>this.deadline
throw Error("April Fools could not confirm Next / Return to lobby. Check the screen, then resume.")
if now<this.due
return
scan := this.worker.Poll()
if scan {
if scan["kind"] = "rejoin" || scan["kind"] = "access-denied"
this.Handle(scan)
else AAAprilFools.HandleExit(this,scan)
}
if now-this.scanned>=150 {
this.worker.Request("april-exit"), this.scanned := now
}
return
}
if this.stage = "AprilResultRejoin"
return
if this.stage = "AprilResultSend" {
if now < this.due
return
if !this.HasOwnProp("resultCounted") || !this.resultCounted {
this.resultCounted := true
result := this.aprilResult = "defeat" ? "Defeat" : "Victory"
if result = "Victory"
this.app.wins++
else this.app.losses++
this.app.ReportResult(result)
if this.app.model.preferences.Get("WebhookEnabled","0") != "1" || this.app.model.preferences.Get("Webhook","") = ""
this.app.Log("April Fools | Webhook needs an enabled URL; continuing result flow")
this.app.Continuation()
if this.app.model.preferences.Get("PublicRejoin","1") = "1" {
this.Change("AprilResultRejoin",30000)
this.app.RejoinNextMode(true)
} else {
this.Change("AprilExitNext",30000)
this.aprilExitFrames := 0, this.aprilExitSignature := ""
this.aprilNextAttempts := 0, this.aprilReturnAttempts := 0
this.scanned := 0, this.due := 0
this.app.Log("April Fools | Public rejoin off: using Next and Return to lobby")
}
}
return
}
if now>this.deadline && (this.stage = "Actions" || this.stage = "BeforeActions" || this.stage = "AwaitResult")
this.deadline := now+3600000
if now>this.deadline {
if this.stage = "PlaceClear" || this.stage = "PlaceVerify" {
pending := this.worker.Poll()
if pending {
this.Handle(pending)
if this.stage != "PlaceClear" && this.stage != "PlaceVerify"
return
if this.stage = "PlaceVerify" && pending["kind"] = "unit-panel" {
this.deadline := Adventures.Tick()+2000
return
}
}
this.SkipUnconfirmedPlacement()
return
}
if this.stage = "Upgrade" {
pending := this.worker.Poll()
if pending {
this.Handle(pending)
if this.stage != "Upgrade"
return
}
this.app.Log("Upgrade target not confirmed; continuing config")
this.FinishPlacement()
return
}
if (this.stage = "AwaitVote" || this.stage = "AwaitStart" || this.stage = "AwaitTransition" || this.stage = "AwaitMansionMap") && HasMethod(this.app,"Recover") {
pending := this.worker.Poll()
if pending && (pending["kind"] = "access-denied" || pending["kind"] = "rejoin") {
this.Handle(pending)
return
}
if this.HasOwnProp("dungeon") {
detail := this.HasOwnProp("lastDungeonObservation") ? this.lastDungeonObservation : "No completed scan received"
reason := "Dungeon recovery: " this.stage " timed out; expected " (this.stage = "AwaitVote" ? "Vote Start or a readable Wave counter" : this.stage = "AwaitStart" ? "Vote Start to disappear or combat to start" : "a recognized loading-screen map") "; " detail "; rejoining server"
this.app.Log(reason)
if HasMethod(this.app,"SaveDungeonErrorReport")
this.app.SaveDungeonErrorReport(reason)
}
this.app.Log("Match loading timed out; recovering server connection")
this.app.Recover(true)
return
}
if this.stage="Dungeon" && this.HasOwnProp("dungeon") {
this.dungeon.RejoinDiagnostic("Dungeon encounter timed out; expected a recognized actionable menu or encounter transition")
return
}
throw Error("Timed out in " this.stage ". Check the game, then stop and restart the loop.")
}
if this.stage="ChallengeReturning"
return
if !this.worker.Ready()
return
if this.stage = "Dungeon" {
if this.dungeon.CheckDeathExit()
return
if now < this.due
return
if this.dungeon.phase = "shop-purchased" {
this.dungeon.ContinueShop()
return
}
scan := this.worker.Poll()
if scan {
if scan["kind"] = "rejoin" || scan["kind"] = "access-denied" || scan["kind"] = "leaderboard"
this.Handle(scan)
else if scan["kind"] = "reward" {
if this.dungeon.HasOwnProp("chestPending") && this.dungeon.chestPending
this.dungeon.Handle(scan)
else this.DismissReward()
} else this.dungeon.Handle(scan)
}
if this.app.status = "Running" && this.stage = "Dungeon" && now-this.scanned >= 100 {
this.worker.Request(this.dungeon.RequestStage())
this.scanned := now
}
return
}
if SubStr(this.stage,1,12) = "PortalReplay" {
AAPortalReplay.Tick(this)
return
}
if this.stage="Camera" {
this.Camera()
return
}
if this.stage = "SettingsOpen" {
if now < this.due
return
this.ClickAt(27,574)
this.spawnPoint := StoryLoop.SpawnPlan(this.SpawnScale()), this.spawnScrolls := 0
this.Change("SettingsScroll",60000)
this.due := Adventures.Tick()+Max(1000,this.Delay("StageClickDelay",1000))
this.app.Log("Opening game settings")
return
}
if this.stage = "SettingsScroll" {
if now < this.due
return
if this.spawnScrolls<this.spawnPoint["scrolls"] {
this.ScrollSettings(), this.spawnScrolls++
this.due := now+350
} else {
this.Change("SettingsTeleport",15000)
this.due := Adventures.Tick()+350
}
return
}
if this.stage = "SettingsTeleport" {
if now < this.due
return
this.ClickAt(this.spawnPoint["x"],this.spawnPoint["y"])
this.Change("SettingsClose",15000)
this.due := Adventures.Tick()+Max(1500,this.Delay("StageClickDelay",1000))
this.app.Log("Returning to spawn")
return
}
if this.stage = "SettingsClose" {
if now < this.due
return
this.ClickAt(this.spawnPoint["closeX"],this.spawnPoint["closeY"])
if HasMethod(this.app,"NeedsMapPath") && this.app.NeedsMapPath()
this.Change("MapPath",20000)
else this.ReadyForVote()
this.due := Adventures.Tick()+Max(1000,this.Delay("StageClickDelay",1000))
this.app.Log("Spawn reset complete")
return
}
if this.stage = "MapPath" {
if now < this.due
return
if !this.app.PlayMapPath() {
if this.app.status = "Running"
throw Error("Map route stopped before completion.")
return
}
if this.app.status = "Running"
this.ReadyForVote()
return
}
if this.stage="RewardDelay" {
if HasMethod(this.app,"IsChallenge") && this.app.IsChallenge() {
scan := this.worker.Poll()
if scan && scan["kind"] = "challenge-exit" && this.HasOwnProp("rewardClicks") && this.rewardClicks >= 3 {
this.app.ChallengeFinished(this.defeated)
return
}
if now-this.scanned >= 800 {
this.worker.Request("choice")
this.scanned := now
}
if now >= this.due {
this.ClickAt(400,300)
this.rewardClicks := this.HasOwnProp("rewardClicks") ? this.rewardClicks+1 : 1
if this.rewardClicks >= 12 {
this.app.Log("Rewards collected | Rejoining")
this.app.ChallengeFinished(this.defeated)
} else this.due := Adventures.Tick()+Max(750,this.Delay("StageClickDelay",1000))
}
return
}
scan := this.worker.Poll()
if scan && (scan["kind"] = "leaderboard" || scan["kind"] = "choice" || scan["kind"] = "result-covered" || scan["kind"] = "rejoin" || scan["kind"] = "access-denied" || scan["kind"] = "dungeon-result" || scan["kind"] = "dungeon-chests" || scan["kind"] = "dungeon-died") {
this.Handle(scan)
return
}
if now>=this.due {
this.Change("AwaitChoice",45000)
this.DismissReward()
this.app.Log("Dismissing rewards | Waiting for next screen")
} else if now-this.scanned >= 800 {
this.worker.Request(this.HasOwnProp("dungeon") ? "dungeon-result" : "choice")
this.scanned := now
}
return
}
if now < this.due
return
if this.stage = "VictoryDelay" {
this.ClickAt(319,394)
this.Change("RewardDelay",15000)
this.due := Adventures.Tick()+this.app.rewardDelay
return
}
scan := this.worker.Poll()
if this.epoch!=epoch || this.app.status!="Running"
return
if scan {
this.Handle(scan)
if scan["kind"] = "result-covered" || scan["kind"] = "april-result-covered" || scan["kind"] = "leaderboard"
return
}
if this.app.status!="Running"
return
if this.stage="Actions" {
if HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools()
this.april.Tick()
else this.ActionTick()
}
this.IdleTick()
if this.stage="BeforeActions" {
this.ActionTick()
return
}
if now<this.due
return
waitingWave := this.stage = "Actions" && this.app.index <= this.app.profile["actions"].Length && this.app.profile["actions"][this.app.index]["type"] = "wave"
region := this.stage = "Actions" && HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools() ? (this.april.placementDone ? "april-upgrade" : "april") : waitingWave ? "wave" : this.stage="AwaitMansionMap" ? "mansion-transition" : this.stage="Priority" ? "priority" : this.stage="PlacementAuto" ? "placement-auto" : this.stage="Upgrade" ? "upgrade" : this.stage="PlaceClear" || this.stage="PlaceVerify" ? "placement" : this.stage="Vote" || this.stage="AwaitVote" || this.stage="AwaitStart" ? "vote-or-wave"
: this.stage="AwaitChoice" || this.stage="AwaitTransition" ? "choice" : "result"
if this.HasOwnProp("dungeon") && (region = "result" || region = "choice")
region := "dungeon-result"
if region = "vote-or-wave" && HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools()
region := "april-vote-or-wave"
if now-this.scanned>=(this.stage="AwaitMansionMap" ? 150 : ((region = "april" || region = "april-upgrade") ? 150 : region = "priority" ? 75 : region = "placement-auto" ? 100 : region = "placement" || region = "upgrade" ? 50 : Max(150,this.Delay("ScanDelay",800)))) {
wantsAuto := region != "placement" && region != "upgrade" ? true : this.placement.Get("autoAbility",false) && !(this.HasOwnProp("autoState") && this.autoState.done)
this.worker.Request(region,wantsAuto)
this.scanned := now
}
} catch Error as err {
if err is AAFocusChanged {
AAInput.WaitingForFocus(this,this.app.hwnd)
return
}
if (this.app is AASession || this.app is AACameraSession) && AAInput.WaitingForFocus(this,this.app.hwnd)
return
if this.app.status = "Running" {
if this.HasOwnProp("dungeon") && HasMethod(this.app,"SaveDungeonErrorReport")
this.app.SaveDungeonErrorReport("Dungeon paused with error: " err.Message "; stage=" this.stage "; " (this.HasOwnProp("lastDungeonObservation") ? this.lastDungeonObservation : "No completed scan received"))
this.Pause(err.Message)
}
} finally {
this.busy := false
if this.HasOwnProp("disposing") && this.disposing
this.FinishDispose()
}
}
Handle(scan) {
if this.HasOwnProp("dungeon")
this.lastDungeonObservation := AADungeons.Diagnostic(scan)
kind := scan["kind"]
if kind = "april-map" && HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools() {
this.app.owner.aprilMap := scan["map"]
return
}
if this.HasOwnProp("postUnitSerial") && scan.Get("id",0) >= this.postUnitSerial
this.DeleteProp("postUnitSerial")
if kind = "april-state" && this.stage = "Actions" && this.HasOwnProp("april") {
if this.april.phase != "ability" || this.worker.serial > this.april.awaitSerial
this.april.Observe(scan)
return
}
now := Adventures.Tick()
if this.HasOwnProp("dungeon") && (kind = "dungeon-result" || kind = "dungeon-chests" || kind = "dungeon-died") {
this.dungeon.phase := "result"
this.Change("Dungeon",120000)
this.dungeon.Handle(scan)
return
}
if kind = "wave" {
value := scan.Get("wave",-1)
if value < 0 {
this.waveFrames := 0
return
}
this.waveFrames := this.HasOwnProp("waveCandidate") && this.waveCandidate = value ? this.waveFrames+1 : 1
this.waveCandidate := value
if this.waveFrames >= 2 {
this.confirmedWave := value
if this.stage = "AwaitVote" && value >= 1 {
this.app.Log("Wave " value " detected after late loading; setting top-down camera first")
this.Change("Camera",15000), this.cameraStep := 0
this.startedWaveBeforeCamera := value
} else if (this.stage = "Vote" || this.stage = "AwaitStart") && value >= 1 {
this.app.Log("Wave " value " Found")
this.BeginIndexes(value)
}
}
return
}
if kind = "leaderboard" {
this.CloseLeaderboard()
this.due := Adventures.Tick()+250
this.deadline += 250
this.scanned := 0
return
}
if HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools()
&& (kind = "victory" || kind = "defeat" || kind = "april-result-covered") {
if this.stage = "AprilResultSend" || this.stage = "AprilResultRejoin" || SubStr(this.stage,1,9) = "AprilExit"
return
if this.HasOwnProp("april")
this.april.phase := "result"
this.aprilResult := kind = "april-result-covered" ? scan.Get("result","victory") : kind
if scan.Get("panel",false)
this.ClickAt(329,188)
if scan.Get("overview",false)
this.ClickAt(660,543)
this.Change("AprilResultSend",30000)
this.due := Adventures.Tick()+500
this.app.Log("April Fools | Panels closed; sending result screenshot before leaving")
return
}
if kind = "result-covered" {
attempts := this.HasOwnProp("obstructionAttempts") ? this.obstructionAttempts : 0
if attempts >= 3
throw Error("The unit panel still covers the results. Close it, then resume.")
this.ClickAt(329,188)
this.obstructionAttempts := attempts+1
this.Change("AwaitResult",3600000)
this.due := Adventures.Tick()+250
this.scanned := 0
this.app.Log("Closing unit panel before results Next")
return
}
this.obstructionAttempts := 0
if kind = "access-denied"
throw Error(scan.Get("text","Roblox needs attention. Check access and account status."))
if kind = "rejoin" && HasMethod(this.app,"Recover") {
this.app.Recover(scan.Get("forcePublic",false))
return
}
if this.HasOwnProp("dungeon") && kind = "choice"
throw Error("Uncalibrated Dungeon result controls. Open Dungeon manually, then resume.")
if kind = "choice" && (this.stage = "Priority" || this.stage = "PlacementAuto" || this.stage = "Upgrade" || this.stage = "AwaitVote" || this.stage = "Actions" || this.stage = "AwaitResult" || this.stage = "RewardDelay" || this.stage = "VictoryDelay" || this.stage = "PlaceClear" || this.stage = "PlaceVerify")
this.Change("AwaitChoice",45000)
if (kind = "victory" || kind = "defeat") && (this.stage = "Priority" || this.stage = "PlacementAuto" || this.stage = "Upgrade" || this.stage = "PlaceClear" || this.stage = "PlaceVerify" || this.stage = "Vote")
this.Change("AwaitResult",3600000)
switch this.stage {
case "AwaitMansionMap":
if kind = "mansion-map" {
name := scan["map"]
if this.HasOwnProp("nextMansionMap") && this.nextMansionMap = name
this.nextMansionFrames++
else this.nextMansionMap := name, this.nextMansionFrames := 1
if this.nextMansionFrames >= 2 {
this.app.LoadMansionMap(name)
this.app.completed++
this.Change("AwaitVote",120000)
this.app.Log("Waiting for match")
}
} else {
this.nextMansionFrames := 0
if kind = "vote"
throw Error("Mansion loaded before its map could be identified. Stop and select the correct config before continuing.")
if kind = "choice" && scan.Get("hasNextRoom",0) && now-this.lastClick >= Max(750,this.Delay("StageClickDelay",1000)) {
this.ClickAt(this.choiceX,121)
this.lastClick := Adventures.Tick(), this.retries++
this.MoveTopLeft()
}
}
case "PlacementAuto":
if kind != "upgrade"
return
if !this.HandleAutoAbility(scan)
this.BeginPriority()
case "Priority":
if kind != "priority" || (this.HasOwnProp("prioritySerial") && this.worker && this.worker.serial < this.prioritySerial)
return
if this.priorityChosen {
if !scan.Get("menu",false) && scan.Get("selected","") = this.priorityTarget {
this.unitPriorities[this.placement.Get("slot",0)] := this.priorityTarget
if this.HasOwnProp("placedUnits") && this.placedUnits.Has(this.PlacementKey(this.placement))
this.placedUnits[this.PlacementKey(this.placement)]["priority"] := this.priorityTarget
this.app.Log("Targeting priority confirmed: " this.priorityTarget)
this.ContinuePlacedUnit()
}
return
}
if scan.Get("menu",false) && scan.Has("options") && scan["options"].Has(this.priorityTarget) {
point := scan["options"][this.priorityTarget]
this.ClickAt(point["x"],point["y"])
this.prioritySerial := this.worker ? this.worker.serial+1 : 0
this.priorityChosen := true, this.due := Adventures.Tick()+75
this.scanned := 0
}
case "Upgrade":
if kind != "upgrade" {
this.upgradeFrames := 0
return
}
if this.HandleAutoAbility(scan)
return
target := this.placement.Get("upgrade","0")
reached := scan.Get("max",false) || (target != "MAX" && scan.Get("level",-1) >= Integer(target))
if reached {
this.upgradeFrames++
if this.upgradeFrames >= 2 {
this.FinishPlacement()
}
} else {
this.upgradeFrames := 0
level := scan.Get("level",-1)
if level>=0
this.upgradeMissing := 0
if level >= 0 && (!this.HasOwnProp("lastUpgradeLevel") || level != this.lastUpgradeLevel) {
this.lastUpgradeLevel := level
this.deadline := now+180000
}
if level < 0 {
this.upgradeMissing := this.HasOwnProp("upgradeMissing") ? this.upgradeMissing+1 : 1
if Mod(this.upgradeMissing,3) = 0 {
this.ClickAt(this.placement["x"],this.placement["y"])
this.MoveTopLeft()
}
}
if scan.Get("level",-1) >= 0 {
this.UpgradeKey()
this.due := Adventures.Tick()+200
}
}
case "PlaceClear":
if kind = "unit-panel" {
if this.clearAttempts >= 3 {
this.SkipUnconfirmedPlacement()
return
}
this.ClickAt(329,188)
this.clearAttempts++, this.absent := 0
this.due := Adventures.Tick()+Max(250,this.Delay("PlacementRetryDelay",500))
} else if kind = "none" {
this.absent++
if this.absent >= 2 {
if this.HasOwnProp("reusePlaced") && this.reusePlaced
this.SelectExistingUnit()
else this.PlaceAttempt()
}
}
case "PlaceVerify":
if this.HasOwnProp("placementSerial") && this.placementSerial && scan.Get("id",0) < this.placementSerial
return
if kind = "unit-panel" {
this.placementPanelSeen := true, this.placementMisses := 0
this.panelFrames++
if this.panelFrames >= 2 {
if !this.HasOwnProp("placedUnits")
this.placedUnits := Map()
key := this.PlacementKey(this.placement)
if !this.placedUnits.Has(key)
this.placedUnits[key] := Map("slot",this.placement.Get("slot",0),"priority","First")
this.placedPriority := scan.Get("priority","")
if this.placement.Get("autoAbility",false) {
this.Change("PlacementAuto",15000)
if scan.Has("auto") && !this.HandleAutoAbility(scan)
this.BeginPriority()
} else this.BeginPriority()
}
} else if kind = "none" {
this.panelFrames := 0
if Adventures.Tick()-this.placementStarted >= 60000 {
this.SkipUnconfirmedPlacement()
return
}
this.placementMisses := this.HasOwnProp("placementMisses") ? this.placementMisses+1 : 1
if this.placementMisses < 2
return
this.placementMisses := 0
if this.HasOwnProp("reusePlaced") && this.reusePlaced
this.SelectExistingUnit()
else if this.HasOwnProp("placementProbe") && this.placementProbe && !this.placementPanelSeen
this.PlaceAttempt()
else
this.ProbePlacement()
}
case "AwaitVote":
if kind="vote" {
this.defeated := false
this.Change("Camera",15000), this.cameraStep := 0
this.app.Log("Setting top-down camera")
}
case "Vote":
if kind="vote" {
if HasMethod(this.app,"PrepareBeforeStart") && this.app.PrepareBeforeStart() {
this.Change("BeforeActions",3600000), this.app.index := 1, this.actionDue := now
return
}
this.ClickAt(353,104)
this.BeginIndexes()
}
case "AwaitStart":
if kind!="vote" {
this.absent++
if this.absent<2
return
if HasMethod(this.app,"PrepareMatchActions")
this.app.PrepareMatchActions()
this.Change("Actions",3600000), this.app.index := 1, this.actionDue := now
} else if this.votes<3 {
this.absent := 0
this.ClickAt(353,104), this.votes++, this.due := now+3000
}
case "Actions", "AwaitResult":
if kind="defeat" {
if !this.defeated {
this.defeated := true
if !this.HasOwnProp("resultCounted") || !this.resultCounted {
this.resultCounted := true
this.app.losses++
if HasMethod(this.app,"ReportResult")
this.app.ReportResult("Defeat")
}
}
if this.app.status != "Running"
return
delay := this.Delay("VictoryDelay",0)
this.Change("VictoryDelay",delay+15000), this.due := Adventures.Tick()+delay
this.app.Log("Defeat | Retrying this stage")
return
}
if kind="victory" {
if this.HasOwnProp("dungeon") && this.dungeon.depth = 20
this.dungeon.bossCleared := true
if !this.HasOwnProp("resultCounted") || !this.resultCounted {
this.resultCounted := true
this.app.wins++
if HasMethod(this.app,"ReportResult")
this.app.ReportResult("Victory")
}
if this.app.status != "Running"
return
delay := this.Delay("VictoryDelay",0)
if delay {
this.Change("VictoryDelay",delay+15000)
this.due := Adventures.Tick()+delay
} else {
this.ClickAt(319,394)
this.Change("RewardDelay",15000), this.due := Adventures.Tick()+this.app.rewardDelay
}
this.app.Log("Victory | Collecting rewards")
}
case "AwaitChoice":
if this.HasOwnProp("rewardSerial") && this.rewardSerial && (kind = "reward" || kind = "choice") && scan.Get("id",0) < this.rewardSerial
return
if kind = "reward" {
if now >= this.due
this.DismissReward()
return
}
if kind="choice" {
if this.HasOwnProp("rewardDismissals") && this.rewardDismissals
this.app.Log("Rewards closed")
if HasMethod(this.app,"IsPortal") && this.app.IsPortal() {
if this.app.Continuation() = "Lobby" {
this.app.RejoinNextMode()
return
}
this.ClickAt(488,121)
this.Change("PortalReplayPicker",120000)
this.due := Adventures.Tick()+Max(750,this.Delay("StageClickDelay",1000))
this.app.Log("Picking next portal")
return
}
if HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools() {
if this.app.Continuation() = "Lobby" {
this.app.RejoinNextMode()
return
}
this.defeated := false
}
if scan.Get("hasRetry",0)
this.defeated := true
if this.defeated && HasMethod(this.app,"ChallengePending") && this.app.ChallengePending() {
this.app.RejoinForChallenge()
return
}
if !this.defeated && HasMethod(this.app,"Continuation") && this.app.Continuation() = "Lobby" {
this.MoveTopLeft()
this.app.Log("Rejoining for next mode")
this.app.RejoinNextMode()
return
}
if scan.Get("hasNextRoom",0) {
if !HasMethod(this.app,"LoadMansionMap")
throw Error("Next Room requires a Mansion config loader.")
if HasMethod(this.app,"Continuation") && this.app.Continuation() != "Next Room"
throw Error("The next mode needs lobby navigation. Stop and return to the lobby before starting that mode.")
this.continueAction := "Next Room", this.choiceX := scan.Get("nextRoomX",488)
this.ClickAt(this.choiceX,121)
this.MoveTopLeft()
this.Change("AwaitMansionMap",120000)
this.nextMansionFrames := 0, this.nextMansionMap := "", this.lastClick := Adventures.Tick()
this.app.Log("Clicking Next Room")
return
}
this.continueAction := scan.Get("hasRetry",0) ? "Retry" : this.defeated ? "Replay" : HasMethod(this.app,"Continuation") ? this.app.Continuation() : scan.Get("hasNextLevel",1) ? "Next Level" : "Replay"
this.choiceX := this.continueAction = "Replay" || this.continueAction = "Retry" ? scan.Get("replayX",400) : 576
this.ClickAt(this.choiceX,121)
this.Change("AwaitTransition",30000), this.lastClick := Adventures.Tick()
this.app.Log("Clicking " this.continueAction)
}
case "AwaitTransition":
if kind!="choice" {
this.absent++
if this.absent<2
return
if !this.defeated
this.app.completed++
if this.app.limit && this.app.completed>=this.app.limit {
this.Stop(false)
this.app.Log("Requested Next Level cycles completed.")
} else {
this.Change("AwaitVote",120000), this.due := now+2000
if !this.defeated && HasMethod(this.app,"Advanced")
this.app.Advanced()
this.app.Log("Waiting for next match")
}
} else {
this.absent := 0
if now-this.lastClick >= Max(750,this.Delay("StageClickDelay",1000)) {
this.ClickAt(this.choiceX,121)
this.lastClick := Adventures.Tick(), this.retries++
}
}
}
}
ReadyForVote() {
if this.HasOwnProp("startedWaveBeforeCamera") {
wave := this.startedWaveBeforeCamera
this.DeleteProp("startedWaveBeforeCamera")
this.app.Log("Top-down setup complete; starting placement at wave " wave)
this.BeginIndexes(wave)
} else this.Change("Vote",45000)
}
BeginIndexes(wave := -1) {
this.unitPriorities := Map(), this.placedUnits := Map()
if HasMethod(this.app,"IsAprilFools") && this.app.IsAprilFools() {
this.april := AAAprilController(this)
this.Change("Actions",3600000)
this.app.Log("April Fools | Starting slot 1 circle placement")
SetTimer(this.timer,15)
return
}
if HasMethod(this.app,"PrepareMatchActions")
this.app.PrepareMatchActions()
this.Change("Actions",3600000), this.app.index := 1, this.actionDue := Adventures.Tick()
this.panelCleared := true
this.confirmedWave := wave, this.waveFrames := 0, this.waveCandidate := -1, this.waveIndex := 0
}
DismissReward() {
count := this.HasOwnProp("rewardDismissals") ? this.rewardDismissals : 0
if count >= 20
throw Error("Reward screen is still open after 20 dismissals. Close it, then resume.")
this.ClickAt(400,300)
this.rewardDismissals := count+1
this.lastClick := Adventures.Tick()
this.rewardSerial := this.worker && this.worker.HasOwnProp("serial") ? this.worker.serial+1 : 0
if count = 0
this.rewardHardDeadline := this.lastClick+90000
this.deadline := Min(this.rewardHardDeadline,Max(this.deadline,this.lastClick+15000))
this.due := this.lastClick+Max(750,this.Delay("StageClickDelay",1000))
}
PlacementKey(action) => action.Get("x",-1) "," action.Get("y",-1)
SelectExistingUnit() {
this.ClickAt(this.placement["x"],this.placement["y"])
this.stage := "PlaceVerify", this.panelFrames := 0, this.scanned := 0
this.deadline := this.placementStarted+60000
this.placementSerial := this.worker && this.worker.HasOwnProp("serial") ? this.worker.serial+1 : 0
this.due := Adventures.Tick()+100
}
PlaceAttempt() {
if this.HasOwnProp("reusePlaced") && this.reusePlaced {
this.SelectExistingUnit()
return
}
this.app.CheckClient()
SendEvent("{" this.placement["slot"] "}")
Sleep(70)
this.ClickAt(this.placement["x"],this.placement["y"])
this.stage := "PlaceVerify", this.panelFrames := 0, this.scanned := 0
this.placementProbe := false, this.placementMisses := 0
this.deadline := this.placementStarted+60000
this.placementSerial := this.worker && this.worker.HasOwnProp("serial") ? this.worker.serial+1 : 0
this.due := Adventures.Tick()+100
}
ProbePlacement() {
this.app.CheckClient()
SendEvent("{q}")
Sleep(70)
this.ClickAt(this.placement["x"],this.placement["y"])
this.placementProbe := true
this.due := Adventures.Tick()+Max(250,Round(this.Delay("PlacementRetryDelay",500)*0.8))
}
BeginPriority() {
if !this.placement.Has("priority") {
this.ContinuePlacedUnit()
return
}
target := this.placement.Get("priority","First")
target := target = "Strong" ? "Strongest" : target = "Close" ? "Closest" : target
if !this.HasOwnProp("unitPriorities")
this.unitPriorities := Map()
previousPriority := this.unitPriorities.Get(this.placement.Get("slot",0),"First")
if this.HasOwnProp("reusePlaced") && this.reusePlaced && this.placedUnits.Has(this.PlacementKey(this.placement))
previousPriority := this.placedUnits[this.PlacementKey(this.placement)]["priority"]
if target = "First" && previousPriority = "First" {
this.ContinuePlacedUnit()
return
}
this.priorityTarget := target, this.priorityChosen := false
this.Change("Priority",10000)
this.ClickAt(54,372)
this.prioritySerial := this.worker ? this.worker.serial+1 : 0
this.due := Adventures.Tick()+75
this.scanned := 0
this.app.Log("Setting targeting priority: " target)
}
ContinuePlacedUnit() {
if this.placement.Get("upgrade","0") != "0" {
this.MoveTopLeft()
this.upgradeFrames := 0, this.lastUpgradeLevel := -1, this.upgradeMissing := 0
this.Change("Upgrade",180000)
target := this.placement.Get("upgrade","0")
this.app.Log("Upgrading Unit " this.placement.Get("slot",0) " to " (target = "MAX" ? "MAX" : "Upgrade " target))
} else this.FinishPlacement()
}
HandleAutoAbility(scan) {
if !this.placement.Get("autoAbility",false)
return false
if this.app.status != "Running"
return true
if !this.HasOwnProp("autoState")
this.autoState := {done:false,clicked:false,frames:0,at:0}
state := this.autoState
if state.done
return false
auto := scan.Get("auto","")
if auto = "on" {
state.done := true
this.app.Log("Auto Ability: On confirmed")
return false
}
if state.clicked {
if Adventures.Tick()-state.at < 3000 {
this.due := Adventures.Tick()+150
return true
}
state.done := true
this.app.Log("Auto Ability could not be confirmed; continuing upgrades without another toggle click")
return false
}
if auto != "off" {
state.frames := 0
return false
}
state.frames++
if state.frames >= 2 {
this.ClickAt(scan["autoX"],scan["autoY"])
state.clicked := true, state.at := Adventures.Tick()
this.app.Log("Auto Ability: Off detected; enabling")
}
this.due := Adventures.Tick()+150
return true
}
UpgradeKey() {
AAInput.Check(ObjBindMethod(this.app,"CheckClient"))
SendEvent("{r down}")
try Sleep(80)
finally SendEvent("{r up}")
}
CloseLeaderboard() {
if !AALeaderboard.Close(this.app.hwnd,ObjBindMethod(this.app,"CheckClient"))
throw Error("Leaderboard could not be closed. Close it and resume the macro.")
}
MoveTopLeft(fast := false) => this.MoveCorner(3,fast)
MoveTopRight(fast := false) => this.MoveCorner(797,fast)
MoveCorner(x,fast := false) {
AAInput.Check(ObjBindMethod(this.app,"CheckClient"))
WinGetClientPos(&left,&top,,,this.app.hwnd)
previousMode := A_CoordModeMouse
CoordMode("Mouse","Screen")
try {
MouseGetPos(&startX,&startY)
targetX := left+x, targetY := top+3
if Abs(startX-targetX) <= 2 && Abs(startY-targetY) <= 2
return
steps := fast ? 2 : 4
Loop steps {
AAInput.Check(ObjBindMethod(this.app,"CheckClient"))
t := A_Index/steps
MouseMove(Round(startX+(targetX-startX)*t),Round(startY+(targetY-startY)*t),0)
Sleep(fast ? 1 : 8)
}
} finally CoordMode("Mouse",previousMode)
}
IdleTick() {
if this.app.status != "Running" || this.stage != "AwaitResult" || !this.HasOwnProp("configComplete") || !this.configComplete || !this.HasOwnProp("idleKeyDue") || Adventures.Tick() < this.idleKeyDue
return
this.MoveTopRight(true)
this.ClickAt(797,3)
this.idleKeyDue := Adventures.Tick()+15000
}
CancelPlacement() {
this.app.CheckClient()
SendEvent("{q}")
}
SkipUnconfirmedPlacement() {
this.CancelPlacement()
this.app.Log("Index " this.placement["index"] ": Placement not confirmed; continuing config")
this.panelCleared := false
this.app.index++
this.Change("Actions",3600000)
this.actionDue := Adventures.Tick()+Max(250,this.Delay("PlacementRetryDelay",500))
}
FinishPlacement() {
this.ClickAt(329,188)
this.panelCleared := true
this.app.index++
this.Change("Actions",3600000)
this.actionDue := Adventures.Tick()+220
if this.worker && this.worker.HasOwnProp("serial") && HasMethod(this.worker,"Request") {
this.postUnitSerial := this.worker.serial+1
this.worker.Request("result")
this.scanned := Adventures.Tick()
}
}
ActionTick() {
if this.HasOwnProp("postUnitSerial")
return
now := Adventures.Tick()
if now<this.actionDue
return
if this.app.index>this.app.profile["actions"].Length {
if this.stage = "BeforeActions" {
this.ReadyForVote()
return
}
this.Change("AwaitResult",3600000)
this.configComplete := true
this.MoveTopLeft(true)
this.idleKeyDue := Adventures.Tick()+5000
this.app.Log("Config Complete")
return
}
action := this.app.profile["actions"][this.app.index]
previous := Critical(1)
try {
this.app.CheckClient()
switch action["type"] {
case "wave":
if !this.HasOwnProp("waveIndex") || this.waveIndex != this.app.index {
this.waveIndex := this.app.index
this.app.Log("Waiting for Wave " action["target"])
}
if !this.HasOwnProp("confirmedWave") || this.confirmedWave < action["target"]
return
this.app.Log("Wave " this.confirmedWave " Found")
case "place":
this.autoState := {done:false,clicked:false,frames:0,at:0}
this.placedPriority := ""
this.placement := action, this.placementStarted := Adventures.Tick(), this.clearAttempts := 1
this.placementPanelSeen := false, this.placementProbe := false, this.placementMisses := 0
this.reusePlaced := this.HasOwnProp("placedUnits") && this.placedUnits.Has(this.PlacementKey(action))
this.app.Log((this.reusePlaced ? "Selecting placed Unit " : "Placing Unit ") action["slot"])
if this.HasOwnProp("panelCleared") && this.panelCleared {
this.panelCleared := false
if this.reusePlaced
this.SelectExistingUnit()
else this.PlaceAttempt()
return
}
this.Change("PlaceClear",60000)
this.due := Adventures.Tick()+Max(250,this.Delay("PlacementRetryDelay",500))
return
case "click":
this.app.Log("Performing " (action.Get("button","Left") = "Right" ? "Right" : "Left") " Click at coordinates (" action["x"] ", " action["y"] ")")
AAInput.Click(this.app.hwnd,action["x"],action["y"],ObjBindMethod(this.app,"CheckClient"),action.Get("button","Left"))
this.panelCleared := false
case "key": SendEvent("{" action["key"] "}")
case "recording":
Critical(previous)
if !this.app.PlayRecording(action["name"])
throw Error("Recording stopped before completion.")
this.panelCleared := false
}
this.app.index++
this.actionDue := Adventures.Tick()+(action["type"]="wait"?action["ms"]:action["type"]="click"?this.Delay("PlacementRetryDelay",500):100)
} finally Critical(previous)
this.app.Publish()
}
Pause(reason:="") {
if this.app.status="Running" {
now := Adventures.Tick(), this.pausedAt := now
this.epoch++, SetTimer(this.timer,0), this.ReleaseCamera()
if this.worker
this.worker.Dispose(), this.worker := 0
this.app.status := "Paused"
this.app.Log(reason!=""?reason:"Paused.")
} else if this.app.status="Paused" {
try {
this.app.CheckClient()
elapsed := Adventures.Tick()-this.pausedAt
this.deadline += elapsed, this.due += elapsed
if this.stage = "AwaitVote" && this.deadline <= Adventures.Tick()
this.deadline := Adventures.Tick()+120000
if (this.stage = "PlaceClear" || this.stage = "PlaceVerify") && this.HasOwnProp("placementStarted")
this.placementStarted += elapsed
if this.HasOwnProp("actionDue")
this.actionDue += elapsed
if this.HasOwnProp("idleKeyDue")
this.idleKeyDue += elapsed
if this.HasOwnProp("rewardHardDeadline")
this.rewardHardDeadline += elapsed
if this.stage="Camera"
this.cameraStep := 0
this.worker := StoryOcrClient(this.app)
for field in ["rewardSerial","placementSerial","prioritySerial"]
if this.HasOwnProp(field)
this.%field% := 0
if this.HasOwnProp("dungeon")
this.dungeon.Resume(elapsed)
this.scanned := 0, this.app.status := "Running"
if this.HasOwnProp("april") && this.april.phase = "ability"
this.april.awaitSerial := 0
SetTimer(this.timer,this.HasOwnProp("april") && this.stage = "Actions" ? 15 : 50)
this.app.Log("Resumed.")
} catch Error as err {
this.app.Log("Could not resume: " err.Message)
}
}
this.app.Publish()
}
Stop(log:=true) {
this.epoch++, SetTimer(this.timer,0), this.ReleaseCamera()
if this.worker
this.worker.Dispose(), this.worker := 0
this.app.status := "Idle", this.app.index := 1, this.stage := "Idle"
if log
this.app.Log("Stopped.")
else this.app.Publish()
}
Dispose() {
this.Stop(false)
this.disposing := true
if !this.busy
this.FinishDispose()
}
FinishDispose() {
this.timer := 0
this.app := 0
this.disposing := false
}
}
class AAWindow extends CrusadersWebWindow {
__New() {
this.catalogChecked := 0
super.__New()
this.inputRecorder.waitForFocus := true
if !this.uiTest
DllCall("SetPropW","Ptr",this.gui.Hwnd,"Str","BayzosAAInteractive","Ptr",DllCall("GetCurrentProcessId"))
if !this.uiTest {
this.startupReadyTimer := ObjBindMethod(this,"StartupReady")
SetTimer(this.startupReadyTimer,25)
}
OnExit((*)=>AAExecution.Stop())
}
StartupReady() {
if !this.webReady || !this.interfaceShown || !this.interfaceVisible || !this.pageRendered || !DllCall("IsWindowVisible","Ptr",this.gui.Hwnd)
return
global launchTick
SetTimer(this.startupReadyTimer,0)
this.startupReadyTimer := 0
this.startupReadyMs := DllCall("GetTickCount64","UInt64")-launchTick
}
RequiresElyssiaReminder() {
global selector
if selector.preferences.Get("Mode","") = "Events"
return true
for task in this.tasks.items
if task.enabled && task.mode = "Events"
return true
return false
}
ShowAprilStartReminder() {
this.aprilStartPending := true
this.core.ExecuteScriptAsync("window.showAprilStartReminder()")
}
CloseAprilStartReminder() {
this.aprilStartPending := false
this.core.ExecuteScriptAsync("window.closeAprilStartReminder?.()")
}
ConfirmAprilStart(*) {
this.CloseAprilStartReminder()
this.aprilStartConfirmed := true
this.StartBackend()
}
CancelAprilStart(*) {
this.CloseAprilStartReminder()
this.aprilStartConfirmed := false
this.startConsumed := false, this.startRequested := false, this.startQueued := false
}
StartBackend(*) {
global selector, testRunning
this.startQueued := false, this.startRequested := false
if testRunning || this.uiTest
return
try {
missing := AAPreflight.MissingConfigs(this,selector)
if missing.Length {
names := ""
for name in missing
names .= (names="" ? "" : ", ") name
this.Log("Cannot start: no indexes in " names)
this.startConsumed := false
return
}
this.preflightIssues := AAPreflight.Check(this,selector)
this.preflightQueueSignature := Jxon_Dump(CrusadersJsonValue(this.tasks.items))
if this.preflightIssues.Length {
this.Log("Start blocked: " this.preflightIssues.Length " setup problems. Open Fix to resolve them.")
for issue in this.preflightIssues
this.Log("Setup: " issue["message"])
if this.webReady
this.core.ExecuteScriptAsync("showPreflight(" Jxon_Dump(this.preflightIssues) ")")
this.startConsumed := false
return
}
CrusadersWindow.Prototype.Start.Call(this)
if !testRunning
this.startConsumed := false
} catch Error as err {
this.startConsumed := false
this.aprilStartConfirmed := false
this.Log("Start blocked: " err.Message)
}
}
TestDungeonBossCycle(*) {
global selector,testCancelled
if (this.HasOwnProp("shopTestBusy") && this.shopTestBusy) || (this.HasOwnProp("dungeonCycleDebug") && this.dungeonCycleDebug)
return
this.shopTestBusy := true,this.shopTestCancelled := false
bitmap := 0,token := 0
try {
this.CheckShopTestClient()
if selector.preferences.Get("WebhookEnabled","0")!="1"
throw Error("Enable Webhooks for the L boss-to-new-run test")
CrusadersWebhook.Url(selector.preferences["Webhook"])
token := Gdip_Startup(),reader := AdventuresOcr(),previous := ""
loop 2 {
this.CheckShopTestClient()
if bitmap
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Boss start capture failed")
scan := AADungeons.Read(reader,bitmap,false,false,0,false),card := AADungeons.DebugBossCard(scan)
if !card
throw Error("Expected available boss room at depth20; " AADungeons.Diagnostic(scan))
identity := card["x"] "," card["y"]
if A_Index=2 && identity!=previous
throw Error("Boss card changed between confirmation frames")
previous := identity
Sleep(200)
}
path := CrusadersCatalog.Resolve(selector.configRoot,"Dungeons","Planet Greenie",1)
candidate := CrusadersSelector(path,"",selector.settingsFile,selector.imageRoot)
AAExecution.Stop(),testCancelled := false
this.dungeonCycleDebug := true,this.dungeonBossDebug := true,this.dungeonBossChestQueued := false
this.dungeonCycleStarted := Adventures.Tick(),this.dungeonCycleStage := "",this.dungeonCycleStageAt := Adventures.Tick()
this.LoadEditor(candidate)
AAExecution.StartMatch(this,candidate)
this.dungeonCycleTimer := ObjBindMethod(this,"WatchDungeonCycle")
SetTimer(this.dungeonCycleTimer,500)
this.Log("L full test started: boss -> detected map config/fight -> chests -> Finish -> rejoin -> new room Enter -> stop")
} catch Error as err {
this.Log("L boss start failed: " err.Message)
context := {hwnd:this.game,model:selector,Log:(self,message)=>this.Log(message)}
AADungeons.SaveErrorReport(context,"L boss start failed: " err.Message)
if this.HasOwnProp("dungeonBossDebug") && this.dungeonBossDebug {
this.dungeonBossDebug := false,this.dungeonCycleDebug := false
AAExecution.Stop()
}
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
BeginBossChestTest(*) {
if !this.dungeonBossDebug
return
this.dungeonBossDebug := false,this.dungeonCycleDebug := false
if this.HasOwnProp("dungeonCycleTimer")
SetTimer(this.dungeonCycleTimer,0)
this.TestDungeonChests(true)
}
TestDungeonChests(fullCycle := false,*) {
global selector,testCancelled
if this.HasOwnProp("shopTestBusy") && this.shopTestBusy
return
this.shopTestBusy := true,this.shopTestCancelled := false
token := 0,bitmap := 0,controller := 0,started := Adventures.Tick(),label := fullCycle ? "L full Dungeon test" : "P chest debug"
try {
this.CheckShopTestClient()
if selector.preferences.Get("WebhookEnabled","0")!="1"
throw Error("Enable Webhooks before running the chest test")
CrusadersWebhook.Url(selector.preferences["Webhook"])
context := {hwnd:this.game,model:AAExecution.session ? AAExecution.session.model : selector,Log:(self,message)=>this.Log(message)}
io := {Click:(self,x,y)=>AAInput.Click(this.game,x,y,ObjBindMethod(this,"CheckShopTestClient")),Log:(self,message)=>this.Log(message),Reward:(self)=>this.DebugChestReward()}
io.DefineProp("ObserveChests",{Call:(self,scan)=>AAExecution.ObserveChests(this,scan)})
io.DefineProp("ChestOpened",{Call:(self,kind)=>AAExecution.ChestOpened(this,kind)})
controller := AAChestDebug(io),reader := AdventuresOcr(),token := Gdip_Startup()
this.Log(label " started: common -> rare -> Continue -> Finish" (fullCycle ? " -> rejoin -> Dungeon -> room Enter" : "") "; reward webhooks enabled")
loop {
this.CheckShopTestClient()
if Adventures.Tick()-started>1800000
throw Error("Chest debug reached its 30-minute safety limit")
if bitmap
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Chest debug capture failed")
scan := StoryVision.Read(reader,bitmap,(controller.phase="reward" || controller.phase="reward-chain") ? "dungeon-chest-reward" : "dungeon")
this.CheckShopTestClient()
controller.Handle(scan,Adventures.Tick())
if controller.phase="done" {
AADungeons.SaveErrorReport(context,"P chest debug complete: common/rare empty confirmed; Continue and Finish clicked; " AADungeons.Diagnostic(scan),"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
if fullCycle {
this.Log("L full Dungeon test: Finish clicked; waiting for in-match Enter Dungeon menu")
entryDeadline := Adventures.Tick()+30000,entryFrames := 0
loop {
this.CheckShopTestClient()
if Adventures.Tick()>entryDeadline
throw Error("After Finish: expected in-match Enter Dungeon menu; " AADungeons.Diagnostic(scan))
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Post-Finish capture failed")
scan := AADungeons.Read(reader,bitmap,false,false,0,false)
entryFrames := scan["kind"]="dungeon-entry-menu" && scan.Get("inMatch",false) ? entryFrames+1 : 0
if entryFrames>=2
break
Sleep(200)
}
this.CheckShopTestClient()
AAInput.Click(this.game,670,150,ObjBindMethod(this,"CheckShopTestClient"))
path := CrusadersCatalog.Resolve(selector.configRoot,"Dungeons","Planet Greenie",1)
candidate := CrusadersSelector(path,"",selector.settingsFile,selector.imageRoot)
AAExecution.Stop(),testCancelled := false
this.dungeonCycleDebug := true,this.dungeonCycleStarted := Adventures.Tick(),this.dungeonCycleStage := "",this.dungeonCycleStageAt := Adventures.Tick()
this.LoadEditor(candidate)
AAExecution.lobby := AALobbyFlow(this,candidate)
AAExecution.lobby.Start(true,true)
this.dungeonCycleTimer := ObjBindMethod(this,"WatchDungeonCycle")
SetTimer(this.dungeonCycleTimer,500)
this.Log("L full Dungeon test: X closed; rejoining lobby -> Dungeons -> available room -> Enter")
} else if AAExecution.session && AAExecution.session.loop.HasOwnProp("dungeon")
AAExecution.session.loop.Pause("P chest debug finished; stop/restart the macro to begin another run")
break
}
Sleep(200)
}
} catch Error as err {
this.Log(label " stopped: " err.Message)
if IsSet(context) && bitmap
AADungeons.SaveErrorReport(context,label " stopped: " err.Message,"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
if fullCycle && this.HasOwnProp("dungeonCycleDebug") && this.dungeonCycleDebug {
this.dungeonCycleDebug := false
AAExecution.Stop()
}
if controller && AAExecution.session && AAExecution.session.loop.HasOwnProp("dungeon") && AAExecution.session.status="Running"
AAExecution.session.loop.Pause("P chest debug stopped; inspect the report before resuming")
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
DebugChestReward() {
this.CheckShopTestClient()
return CrusadersWebhook.Send(this,"Dungeon Reward")
}
TestDungeonCycle(*) {
global selector,testCancelled
if this.HasOwnProp("shopTestBusy") && this.shopTestBusy
return
this.shopTestBusy := true,this.shopTestCancelled := false
token := 0,bitmap := 0
try {
this.CheckShopTestClient()
token := Gdip_Startup(),reader := AdventuresOcr(),previous := ""
loop 2 {
this.CheckShopTestClient()
if bitmap
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Entry-menu test capture failed")
scan := AADungeons.Read(reader,bitmap,false,false,0,false)
if scan["kind"]!="dungeon-entry-menu"
throw Error("Expected Enter Dungeon menu; " AADungeons.Diagnostic(scan))
identity := scan.Get("inMatch",false) "|" scan.Get("inLobby",false) "|" scan.Get("enterX",0)
if A_Index=2 && identity!=previous
throw Error("Enter Dungeon context changed between readings")
previous := identity
Sleep(200)
}
inMatch := scan.Get("inMatch",false),inLobby := scan.Get("inLobby",false)
if inMatch || !inLobby
throw Error("L needs the lobby Enter Dungeon menu; no rejoin or X click performed; " AADungeons.Diagnostic(scan))
path := CrusadersCatalog.Resolve(selector.configRoot,"Dungeons","Planet Greenie",1)
candidate := CrusadersSelector(path,"",selector.settingsFile,selector.imageRoot)
AAExecution.Stop()
testCancelled := false
this.dungeonCycleDebug := true,this.dungeonCycleStarted := Adventures.Tick(),this.dungeonCycleStage := "",this.dungeonCycleStageAt := Adventures.Tick()
this.LoadEditor(candidate)
AAExecution.StartMatch(this,candidate)
this.dungeonCycleTimer := ObjBindMethod(this,"WatchDungeonCycle")
SetTimer(this.dungeonCycleTimer,500)
this.Log("L Dungeon test: lobby entry -> room selection -> Enter; stop before indexes")
} catch Error as err {
this.Log("L Dungeon test failed: " err.Message)
context := {hwnd:this.game,model:selector,Log:(self,message)=>this.Log(message)}
AADungeons.SaveErrorReport(context,"L Dungeon test failed: " err.Message)
if this.HasOwnProp("dungeonCycleDebug") && this.dungeonCycleDebug {
this.dungeonCycleDebug := false
AAExecution.Stop()
}
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
WatchDungeonCycle(*) {
if !this.dungeonCycleDebug {
SetTimer(this.dungeonCycleTimer,0)
return
}
flow := AAExecution.session ? AAExecution.session.loop : AAExecution.lobby && !AAExecution.lobby.closed ? AAExecution.lobby : 0
if !flow
reason := "No active lobby or dungeon flow"
else {
stage := flow.stage (flow.HasOwnProp("dungeon") ? "/" flow.dungeon.phase : "")
bossTest := this.HasOwnProp("dungeonBossDebug") && this.dungeonBossDebug
if stage!=this.dungeonCycleStage
this.dungeonCycleStage := stage,this.dungeonCycleStageAt := Adventures.Tick()
status := flow.HasOwnProp("status") ? flow.status : flow.app.status
reason := status="Paused" ? "Flow paused before room entry" : Adventures.Tick()-this.dungeonCycleStageAt>(bossTest ? (flow.stage="Actions" || flow.stage="AwaitResult" || flow.stage="Upgrade" ? 3600000 : 180000) : flow.HasOwnProp("dungeon") ? 45000 : 180000) ? "Stage did not progress within its deadline" : Adventures.Tick()-this.dungeonCycleStarted>(bossTest ? 7200000 : 900000) ? "Test exceeded its total time limit" : ""
}
if reason!="" {
context := flow && flow.HasOwnProp("app") ? flow.app : flow ? flow : {hwnd:this.game,Log:(self,message)=>this.Log(message)}
AADungeons.SaveErrorReport(context,"L Dungeon test stalled: " reason "; stage=" this.dungeonCycleStage)
this.dungeonCycleDebug := false,this.dungeonBossDebug := false
SetTimer(this.dungeonCycleTimer,0)
AAExecution.Stop()
this.Log("L Dungeon test stopped; Error Report saved")
}
}
TestDungeonBoss(clickCard := false,*) {
global selector
if this.HasOwnProp("shopTestBusy") && this.shopTestBusy
return
this.shopTestBusy := true,this.shopTestCancelled := false
token := 0,bitmap := 0
try {
this.CheckShopTestClient()
context := {hwnd:this.game,model:AAExecution.session ? AAExecution.session.model : selector,Log:(self,message)=>this.Log(message)}
reader := AdventuresOcr(),token := Gdip_Startup(),previous := "",confirmed := false
loop 2 {
this.CheckShopTestClient()
if bitmap
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Boss debug capture failed")
scan := AADungeons.Read(reader,bitmap,false,false,0,false)
card := AADungeons.DebugBossCard(scan)
identity := card ? card["x"] "," card["y"] : ""
confirmed := identity!="" && identity=previous
previous := identity
if A_Index=1
Sleep(200)
}
AADungeons.SaveErrorReport(context,"Boss room test: confirmed=" confirmed "; clickRequested=" clickCard "; " AADungeons.Diagnostic(scan),"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
if !confirmed {
this.Log("Boss debug: no matching boss card confirmed at depth 20; no click")
return
}
if clickCard {
this.CheckShopTestClient()
AAInput.Click(this.game,card["x"],card["y"],ObjBindMethod(this,"CheckShopTestClient"))
this.Log("Boss debug: boss card clicked once; Enter was not clicked")
if AAExecution.session && AAExecution.session.loop.HasOwnProp("dungeon") {
active := AAExecution.session.loop.dungeon
active.phase := "details",active.pendingRoomMap := "",active.lastAction := Adventures.Tick()
active.frames := 0,active.candidate := "",active.minSerial := AAExecution.session.loop.worker.serial+1
AAExecution.session.loop.Pause("Boss debug opened room details; resume when ready")
}
} else this.Log("Boss debug: boss card confirmed; read-only report saved")
} catch Error as err {
this.Log("Boss debug stopped: " err.Message)
if IsSet(context) && bitmap
AADungeons.SaveErrorReport(context,"Boss debug stopped: " err.Message,"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
} finally {
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
TestDungeonCurse(clickCard := false,*) {
global selector
if this.HasOwnProp("shopTestBusy") && this.shopTestBusy
return
this.shopTestBusy := true,this.shopTestCancelled := false
token := 0,bitmap := 0
try {
this.CheckShopTestClient()
context := {hwnd:this.game,model:AAExecution.session ? AAExecution.session.model : selector,Log:(self,message)=>this.Log(message)}
reader := AdventuresOcr(),token := Gdip_Startup(),previous := "",confirmed := false
loop 2 {
this.CheckShopTestClient()
if bitmap
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Curse debug capture failed")
scan := AADungeons.Read(reader,bitmap,false,false,0,false)
card := AADungeons.DebugCurseCard(scan)
identity := card ? card["x"] "," card["y"] : ""
confirmed := identity!="" && identity=previous
previous := identity
if A_Index=1
Sleep(200)
}
AADungeons.SaveErrorReport(context,"Curse room test: confirmed=" confirmed "; clickRequested=" clickCard "; " AADungeons.Diagnostic(scan),"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
if !confirmed {
this.Log("Curse debug: no matching curse card confirmed; no click")
return
}
if clickCard {
this.CheckShopTestClient()
AAInput.Click(this.game,card["x"],card["y"],ObjBindMethod(this,"CheckShopTestClient"))
enteredTest := true,controller:=AACurseEntryDebug(),phaseStarted:=Adventures.Tick()
this.Log("Curse debug: card confirmed and clicked; waiting for room details")
loop {
this.CheckShopTestClient()
if Adventures.Tick()-phaseStarted>(controller.phase="details" ? 30000 : 90000)
throw Error("Curse test timed out waiting for " controller.phase "; " AADungeons.Diagnostic(scan))
Sleep(200)
Gdip_DisposeImage(bitmap),bitmap:=0
WinGetClientPos(&left,&top,,,this.game)
bitmap:=Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Curse debug capture failed")
scan:=AADungeons.Read(reader,bitmap,controller.phase="map",false,0,false)
this.CheckShopTestClient()
action:=controller.Handle(scan)
if action="enter" {
AAInput.Click(this.game,scan["enterX"],scan["enterY"],ObjBindMethod(this,"CheckShopTestClient"))
phaseStarted:=Adventures.Tick()
this.Log("Curse debug: Enter confirmed/clicked; waiting for transition map")
} else if action="done" {
this.Log("Curse debug complete: map detected - " controller.map "; no camera/path/unit actions")
AADungeons.SaveErrorReport(context,"Curse entry test complete: map=" controller.map "; " AADungeons.Diagnostic(scan))
break
}
}
} else this.Log("Curse debug: curse card confirmed; read-only report saved")
} catch Error as err {
this.Log("Curse debug stopped: " err.Message)
if IsSet(context) && bitmap
AADungeons.SaveErrorReport(context,"Curse debug stopped: " err.Message,"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
} finally {
if IsSet(enteredTest) && AAExecution.session && AAExecution.session.status!="Paused"
AAExecution.session.loop.Pause("Curse entry debug stopped before camera/path/unit actions")
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
CanUseDungeonDebugKeys(*) => this.game && WinActive(this.game) && this.CanUseBoundKeys()
TestDungeonMenu(kind := "shop",buyItems := false,*) {
global selector,testRunning
if this.HasOwnProp("shopTestBusy") && this.shopTestBusy
return
this.shopTestBusy := true, this.shopTestCancelled := false
token := 0,bitmap := 0,label := kind="entry" ? "Enter Dungeon read test" : kind="chests" ? "Chest read test" : kind="curse" ? "Curse room read test" : "Shop test"
try {
AADisplay.UsePhysicalPixels()
if !this.game || !WinActive(this.game)
throw Error("Keep the Roblox shop window active.")
WinGetClientPos(&left,&top,&width,&height,this.game)
if width!=800 || height!=600
throw Error("Roblox client must be 800x600; measured " width "x" height)
token := Gdip_Startup()
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap || !WinActive(this.game)
throw Error("Roblox lost focus during capture.")
this.Log(buyItems ? "Shop test: reading item names before priority purchase test." : label ": reading captured frame; no purchases will be made.")
scan := AADungeons.Read(AdventuresOcr(),bitmap,false,false,0,false)
summary := label ": expected=" kind "; " AADungeons.Diagnostic(scan)
if scan["kind"]="dungeon-shop" {
this.Log("Shop test: " scan["offers"].Length "/" scan["visibleOffers"] " item names read")
for row in scan.Get("shopRows",[])
this.Log("Shop test row " row["row"] ": " (row["item"]!="" ? row["item"] : "ITEM UNREADABLE"))
} else if kind="entry" {
this.Log("Enter Dungeon read test: " (scan["kind"]="dungeon-entry-menu" ? "DETECTED" : "NOT DETECTED") "; inMatch=" scan.Get("inMatch",false) "; inLobby=" scan.Get("inLobby",false) "; Enter button=" scan.Has("enterX"))
} else if kind="chests" && scan["kind"]="dungeon-chests" {
this.Log("Chest read test: normal=" scan.Get("normalCount",-1) "; rare=" scan.Get("rareCount",-1) "; Continue=" scan.Get("continue",false))
} else this.Log(label ": expected=" kind "; observed=" scan["kind"])
context := {hwnd:this.game,model:AAExecution.session ? AAExecution.session.model : selector,Log:(self,message)=>this.Log(message)}
AADungeons.SaveErrorReport(context,summary,"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
if !buyItems || kind!="shop" {
this.Log(label " complete: report saved; no purchase inputs sent.")
return
}
if scan["kind"]!="dungeon-shop" || scan["offers"].Length!=3 || scan["visibleOffers"]!=3 {
this.Log("Shop test: buying skipped; all 3 item names must be readable.")
return
}
preferences := context.model.preferences.Clone()
preferences["DungeonShopLimit"] := "3"
runner := {worker:{serial:0},due:0,app:{model:{preferences:preferences},Log:(self,message)=>this.Log("Shop test: " message)}}
runner.DefineProp("ClickAt",{Call:(self,x,y)=>this.ShopTestClick(x,y)})
runner.app.DefineProp("SaveDungeonErrorReport",{Call:(self,message)=>AADungeons.SaveErrorReport(context,message,"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))})
run := AADungeonRun(runner), reader := AdventuresOcr(), started := Adventures.Tick()
this.Log("Shop test: buying highest priority first; rereading shifted rows after each attempt.")
loop {
this.CheckShopTestClient()
if Adventures.Tick()-started>30000
throw Error("Purchase test timed out.")
run.ContinueShop()
if Adventures.Tick()<runner.due {
Sleep(50)
continue
}
Gdip_DisposeImage(bitmap),bitmap := 0
WinGetClientPos(&left,&top,,,this.game)
bitmap := Gdip_BitmapFromScreen(left "|" top "|800|600")
if !bitmap
throw Error("Shop capture failed.")
scan := AADungeons.Read(reader,bitmap,false,false,0,false)
this.CheckShopTestClient()
if scan["kind"]!="dungeon-shop"
throw Error("Shop menu is no longer visible.")
scan["id"] := ++runner.worker.serial
if (!run.HasOwnProp("shopAttempted") || !run.shopAttempted.Count) && (scan["offers"].Length!=3 || scan["visibleOffers"]!=3)
throw Error("All 3 item names must remain readable before buying.")
run.Handle(scan)
if run.phase="await-shop-return"
break
Sleep(180)
}
this.Log("Shop test complete: " run.shopPurchases " purchases confirmed; shop left open.")
AADungeons.SaveErrorReport(context,"Shop purchase test: confirmed=" run.shopPurchases "; " AADungeons.Diagnostic(scan),"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
} catch Error as err {
this.Log(label " failed: " err.Message)
if IsSet(context) && bitmap
AADungeons.SaveErrorReport(context,label " failed: " err.Message (IsSet(scan) ? "; " AADungeons.Diagnostic(scan) : ""),"",(path)=>Gdip_SaveBitmapToFile(bitmap,path))
} finally {
if IsSet(run) && run.HasOwnProp("shopAttempted") && AAExecution.session && AAExecution.session.HasOwnProp("loop") && AAExecution.session.loop.HasOwnProp("dungeon") {
active := AAExecution.session.loop.dungeon
active.phase := run.phase="await-shop-return" ? "shop-ready" : run.phase
active.shopPurchases := run.shopPurchases,active.shopAttempted := run.shopAttempted
if run.HasOwnProp("shopPending")
active.shopPending := run.shopPending
AAExecution.session.loop.due := runner.due
active.shopUnreadableSince := 0,active.emptySince := 0,active.lastShopIssue := "",active.shopContinueFrames := 0
active.frames := 0,active.candidate := "",active.minSerial := AAExecution.session.loop.worker.serial+1
}
if bitmap
Gdip_DisposeImage(bitmap)
if token
Gdip_Shutdown(token)
this.shopTestBusy := false
}
}
CheckShopTestClient() {
if this.shopTestCancelled || !this.game || !WinActive(this.game)
throw Error("Purchase test cancelled or Roblox lost focus.")
WinGetClientPos(,,&width,&height,this.game)
if width!=800 || height!=600
throw Error("Roblox client size changed during purchase test.")
return true
}
ShopTestClick(x,y) {
this.CheckShopTestClient()
if x=495 && y=407
return
AAInput.Click(this.game,x,y,ObjBindMethod(this,"CheckShopTestClient"))
}
BeginPausedBrowse() {
global selector,testRunning
if !testRunning || !CrusadersRuntime.paused || this.HasOwnProp("pausedBrowse")
return
this.pausedBrowse := {model:selector,scope:this.configScope,path:this.modeConfigPath}
selector := selector.Clone()
}
RestorePausedBrowse() {
global selector
if !this.HasOwnProp("pausedBrowse")
return
saved := this.pausedBrowse
this.DeleteProp("pausedBrowse")
selector := saved.model
this.configScope := saved.scope,this.modeConfigPath := saved.path
this.scopeField.Choose(this.configScope)
this.scopeConfigField.Delete()
choices := this.configScope="Current Mode" ? ["Use Modes Tab"] : CrusadersCatalog.ConfigMaps(this.configScope)
this.scopeConfigField.Add(choices)
this.scopeConfigField.Choose(this.configScope="Current Mode" ? 1 : selector.preferences["Map"])
this.scopeConfigField.Enabled := this.configScope!="Current Mode"
this.LoadFields(),this.UpdateStats()
}
BeginCoordinates() {
global selector, testRunning
if testRunning && !CrusadersRuntime.paused
throw Error("Pause the macro before selecting coordinates.")
if this.uiTest
throw Error("Live selection is disabled in UI tests.")
if RegExMatch(selector.imagePath,"i)\\Transparent\.png$") || !FileExist(selector.imagePath) || !selector.EnsureMapDimensions()
throw Error("No Map Image Detected, Press F5 to Create a New One")
return super.BeginCoordinates()
}
CaptureMap(*) {
global selector
if RegExMatch(selector.imagePath,"i)\\Transparent\.png$") || InStr(selector.imagePath,"\Images\Defaults\") {
stem := RegExReplace(AADefaultPaths.CanonicalName(selector.preferences["Map"]),"[^A-Za-z0-9]","")
selector.imagePath := selector.mapImageDirectory "\" stem ".png"
}
selector.Capture()
}
Stop(*) {
this.dungeonBossDebug := false
this.dungeonCycleDebug := false
this.shopTestCancelled := true
this.RestorePausedBrowse()
AAExecution.Stop()
super.Stop()
this.startConsumed := false
}
PauseRun(*) {
this.shopTestCancelled := true
AAExecution.Pause()
}
ReloadProcess() {
command := A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"'
arguments := ' --restart-from ' DllCall("GetCurrentProcessId")
if this.HasOwnProp("lifecycleTest") && this.lifecycleTest
arguments .= ' --lifecycle-test "' this.lifecycleRoot '" 2'
else if this.uiTest
arguments .= ' --ui-test "' A_Args[2] '"'
Run(command arguments,A_ScriptDir,"Hide")
ExitApp()
}
RestoreNow(reason := "", exitCode := 0) {
if this.HasOwnProp("startupReadyTimer") && this.startupReadyTimer {
SetTimer(this.startupReadyTimer,0)
this.startupReadyTimer := 0
}
AAExecution.Stop()
this.CancelPick()
super.RestoreNow(reason,exitCode)
}
Snapshot() {
result := super.Snapshot()
result["stats"]["Current action"] := this.HasOwnProp("lastProcessMessage") ? this.lastProcessMessage : "Ready"
if AAExecution.session {
result["wins"] := AAExecution.session.wins
result["losses"] := AAExecution.session.losses
if AAExecution.session.loop.HasOwnProp("dungeon") {
run := AAExecution.session.loop.dungeon
result["dungeon"] := Map("depth",run.depth,"hearts",run.hearts,"phase",run.phase,"roomWins",run.roomWins,"roomLosses",run.roomLosses,"completed",run.completed)
this.dungeonStatus := result["dungeon"]
}
}
result["aa"] := Map("nextLevel",true,"hostedSharing",false,"mapSelection","Live")
return result
}
}
class AAExecution {
static lobby := 0
static session := 0
static IndexConfigured(item) {
if item.x >= 0 || item.y >= 0 || item.recording != ""
item.configured := true
return item.configured
}
static Continuation(current, next) {
if current.mode = "Portals"
return next.mode = "Portals" ? "Pick Next Portal" : "Lobby"
if current.mode = "Infinity Mansion"
return next.mode = "Infinity Mansion" ? "Next Room" : "Lobby"
if current.mode = next.mode && current.config = next.config && current.act = next.act && current.difficulty = next.difficulty
return "Replay"
return "Lobby"
}
static NextLobby(session,forcePublic := false,rejoin := true) {
global selector
owner := session.owner, task := session.nextTask.Clone()
this.Stop(true)
if AAChallenges.Launch(owner,task)
return
try {
owner.LoadRunningMode(task)
if task.mode != "Infinity Mansion" && task.mode != "Dungeons"
this.CheckIndexes(selector)
if rejoin && !forcePublic && AAServer.Url(selector.preferences) = ""
throw Error("Enable Public Rejoin or set a private server link to change queued modes.")
this.lobby := AALobbyFlow(owner,selector)
this.lobby.Start(rejoin,forcePublic)
} catch Error as err {
this.Stop()
owner.Log("Next mode stopped: " err.Message)
}
}
static CheckIndexes(model) {
if model.preferences["Mode"] = "Events"
return
active := 0
for number,item in model.indexes {
if !item.enabled || !this.IndexConfigured(item)
continue
active++
if item.recording != "" {
CrusadersRecording.Load(item.recording)
continue
}
if item.autoUpgrade || item.unit != "None"
throw Error("Index " number ": AA unit actions still need calibration. Use a Recorder recording for these actions for now.")
if item.x < 0 || item.y < 0 || item.x >= 800 || item.y >= 600
throw Error("Index " number ": use Select Coordinates first.")
}
if !active
throw Error("This config has no enabled, configured indexes. Set up at least one index.")
}
static Start(cameraOnly := false) {
global macroWindow, selector, testRunning, testCancelled
if cameraOnly {
this.Stop()
if !macroWindow.ShowGame()
throw Error("Open Roblox before using Zoomtech.")
this.session := AACameraSession(macroWindow)
try this.session.Start()
catch Error as err {
this.Stop()
throw err
}
return
}
if selector.preferences["Mode"] != "Dungeons"
this.CheckIndexes(selector)
this.Stop()
testCancelled := false
macroWindow.wins := 0, macroWindow.losses := 0
this.ResetRecords(macroWindow)
AAChallenges.Begin(macroWindow,selector.preferences)
if AAChallenges.Launch(macroWindow,macroWindow.tasks.Current().Clone())
return
macroWindow.ShowGame()
if AAServer.Url(selector.preferences) != "" || selector.preferences["Mode"] = "Raids" || selector.preferences["Mode"] = "Story" || selector.preferences["Mode"] = "Infinite" || selector.preferences["Mode"] = "Infinity Mansion" || selector.preferences["Mode"] = "Legend Stages" || selector.preferences["Mode"] = "Portals" || selector.preferences["Mode"] = "Events" || selector.preferences["Mode"] = "Dungeons" {
this.lobby := AALobbyFlow(macroWindow,selector)
try this.lobby.Start()
catch Error as err {
this.Stop()
throw err
}
return
}
this.StartMatch(macroWindow,selector)
}
static ResetRecords(owner) {
owner.normalChestsCollected := 0,owner.rareChestsCollected := 0,owner.chestInventory := Map()
owner.modeWins := 0, owner.modeLosses := 0, owner.challengeWins := 0, owner.challengeLosses := 0
}
static ObserveChests(owner,scan) {
if scan.Get("kind","")!="dungeon-chests"
return
if !owner.HasOwnProp("chestInventory")
owner.chestInventory := Map()
for kind in ["normal","rare"] {
value := scan.Get(kind "Count",-1)
if value<0 {
if owner.chestInventory.Has(kind)
owner.chestInventory[kind].frames := 0
continue
}
if !owner.chestInventory.Has(kind)
owner.chestInventory[kind] := {last:-1,candidate:-1,frames:0}
state := owner.chestInventory[kind]
state.frames := state.candidate=value ? state.frames+1 : 1,state.candidate := value
if state.frames<2
continue
key := kind="normal" ? "normalChestsCollected" : "rareChestsCollected"
increase := state.last<0 ? value : Max(0,value-state.last)
owner.%key% := (owner.HasOwnProp(key) ? owner.%key% : 0)+increase
state.last := value
}
}
static ChestOpened(owner,kind) {
if owner.HasOwnProp("chestInventory") && owner.chestInventory.Has(kind) {
state := owner.chestInventory[kind]
state.last := Max(0,state.last-1),state.frames := 0,state.candidate := -1
}
}
static RecordResult(owner,challenge,result) {
if result != "Victory" && result != "Defeat"
return
key := (challenge ? "challenge" : "mode") (result = "Victory" ? "Wins" : "Losses")
owner.%key% := (owner.HasOwnProp(key) ? owner.%key% : 0)+1
}
static Recover(forcePublic := false) {
global macroWindow, selector, testCancelled
if !forcePublic && AAServer.Url(selector.preferences) = ""
return
this.Stop(true)
testCancelled := false
macroWindow.Log("Rejoining server")
this.lobby := AALobbyFlow(macroWindow,selector)
try this.lobby.Start(true,forcePublic)
catch Error as err {
this.Stop()
macroWindow.Log("Rejoin stopped: " err.Message)
}
}
static StartMatch(window,model) {
this.session := AASession(window,model)
try this.session.loop.Start()
catch Error as err {
this.Stop()
throw err
}
this.session.Publish()
}
static Pause() {
if this.lobby && !this.lobby.closed {
if this.lobby.status="Paused" && HasMethod(this.lobby.owner,"RestorePausedBrowse")
this.lobby.owner.RestorePausedBrowse()
this.lobby.Pause()
return
}
if this.session {
if this.session.status = "Paused" {
if HasMethod(this.session.owner,"RestorePausedBrowse")
this.session.owner.RestorePausedBrowse()
this.session.owner.ShowGame()
}
this.session.loop.Pause()
CrusadersRuntime.SetPaused(this.session.status = "Paused")
}
}
static Stop(preserveChallenges := false) {
global testRunning
if !preserveChallenges
AAChallenges.Stop()
if this.lobby {
this.lobby.Dispose()
this.lobby := 0
}
if this.session {
session := this.session
session.loop.Stop(false)
session.owner.startConsumed := false
this.session := 0
session.loop.Dispose()
session.loop := 0
}
testRunning := false
CrusadersRuntime.SetPaused(false)
}
}
class AASession extends AdventuresApp {
__New(owner,model) {
this.owner := owner, this.core := owner.core, this.hwnd := owner.game
this.status := "Idle", this.index := 1, this.completed := 0
this.wins := owner.HasOwnProp("wins") ? owner.wins : 0
this.losses := owner.HasOwnProp("losses") ? owner.losses : 0
this.limit := 0, this.rewardDelay := 2500
this.beforeDone := false
this.model := model
this.loadedTeam := AADungeons.Team(model)
if owner.HasOwnProp("dungeonCycleDebug") && owner.dungeonCycleDebug {
SplitPath(model.path,&debugConfig)
this.currentTask := {mode:"Dungeons",config:debugConfig,act:1,difficulty:"Normal",runs:1}
} else {
task := owner.tasks.Current()
if !IsObject(task)
throw Error("No enabled mode is queued. Add a mode before starting the macro.")
this.currentTask := task.Clone()
}
if model.preferences["Mode"] = "Challenges" {
SplitPath(model.path,&challengeConfig)
this.currentTask := {mode:"Challenges",config:challengeConfig,act:Integer(model.preferences["Act"]),difficulty:"Normal",runs:1}
}
if model.preferences["Mode"] = "Infinity Mansion" {
SplitPath(model.path,&mansionConfig)
this.currentTask.config := mansionConfig
}
this.continuationPlanned := false
this.profile := Map("width",800,"height",600,"actions",[])
this.loop := StoryLoop(this)
this.PrepareMatchActions()
}
Log(message) {
this.owner.Log(message)
this.Publish()
}
Publish() {
global testRunning
testRunning := this.status = "Running" || this.status = "Paused"
CrusadersRuntime.SetPaused(this.status = "Paused")
this.owner.runStatus := this.status
this.owner.wins := this.wins, this.owner.losses := this.losses
if !testRunning
this.owner.startConsumed := false
this.owner.PushState()
}
Recover(forcePublic := false) {
if !forcePublic && AAServer.Url(this.model.preferences) = ""
throw Error("Disconnected. Enable Public Rejoin or configure a private server to reconnect.")
this.loop.Pause("Rejoining server")
SetTimer((*)=>AAExecution.Recover(forcePublic),-1)
}
ReportResult(result) {
AAExecution.RecordResult(this.owner,this.IsChallenge(),result)
if this.loop.HasOwnProp("dungeon") {
if result = "Victory"
this.loop.dungeon.roomWins++
else if result = "Defeat"
this.loop.dungeon.roomLosses++
}
this.Publish()
try CrusadersWebhook.Send(this.owner,result)
catch Error as err
this.Log("Webhook failed: " err.Message)
}
ChallengePending() => !this.IsDungeon() && AAChallenges.Due()
RejoinForChallenge() {
this.nextTask := this.owner.tasks.Current().Clone()
this.RejoinNextMode()
}
IsDungeon() => this.currentTask.mode = "Dungeons"
IsPortal() => this.currentTask.mode = "Portals"
IsChallenge() => this.currentTask.mode = "Challenges"
ChallengeFinished(defeated) {
if this.HasOwnProp("challengeReturning") && this.challengeReturning
return
this.challengeReturning := true
this.loop.Change("ChallengeReturning",120000)
SetTimer((*)=>this.CompleteChallengeReturn(defeated),-1)
}
CompleteChallengeReturn(defeated) {
try AAChallenges.Finished(this,defeated)
catch Error as err {
message := "Challenge return failed: " err.Message
this.owner.Log(message)
if this.loop && this.status="Running"
this.loop.Pause(message)
}
}
IsAprilFools() => this.currentTask.mode = "Events"
NeedsSpawnReset() => true
NeedsMapPath() {
if HasMethod(this,"IsAprilFools") && this.IsAprilFools()
return this.owner.HasOwnProp("aprilMap") && this.owner.aprilMap = "Snowy Town"
name := CrusadersCatalog.Name(this.currentTask.config)
return InStr("|Story|Infinite|Challenges|Infinity Mansion|Dungeons|Legend Stages|Raids|","|" this.currentTask.mode "|") && AADefaultPaths.Has(name)
}
PlayMapPath() {
this.CheckClient()
name := HasMethod(this,"IsAprilFools") && this.IsAprilFools() ? this.owner.aprilMap : CrusadersCatalog.Name(this.currentTask.config)
this.Log("Walking " name " route")
data := HasMethod(this,"IsAprilFools") && this.IsAprilFools() ? AAAprilFools.SnowyTownPath() : AADefaultPaths.Get(name)
return this.owner.inputRecorder.Play(data,
(*)=>this.status = "Idle",(*)=>this.CheckPlaybackFocus())
}
PrepareBeforeStart() {
if this.beforeDone
return false
this.beforeDone := true
this.profile["actions"] := this.Actions(true)
return this.profile["actions"].Length > 0
}
RefreshAfterTeleport() {
if this.hwnd && WinExist(this.hwnd)
return true
hwnd := CrusadersServer.FindGameWindow()
if !hwnd
return false
if !this.owner.AttachGame(hwnd)
return false
this.hwnd := hwnd
return true
}
PrepareMatchActions() {
this.profile["actions"] := this.Actions(false)
}
DetectedMapPath(mode,name) {
known := false
for allowed in CrusadersCatalog.Maps[mode]
if name = allowed
known := true
if !known
throw Error(mode " map could not be identified; no config was selected. Retry the transition.")
path := CrusadersCatalog.Resolve(this.model.configRoot,mode,name,1)
if !FileExist(path)
throw Error(mode " map recognized: " name ". Its config is missing: " mode "\" CrusadersCatalog.Filename(mode,name,1))
return path
}
CheckDetectedMapIndexes(candidate,mode,name) {
active := false
for item in candidate.indexes
if item.enabled && AAExecution.IndexConfigured(item)
active := true
if !active
throw Error(mode " map recognized: " name ". No enabled, configured indexes in " mode "\" CrusadersCatalog.Filename(mode,name,1) ". Configure this map in Indexes, then resume.")
AAExecution.CheckIndexes(candidate)
}
LoadDungeonMap(name) {
path := this.DetectedMapPath("Dungeons",name)
candidate := CrusadersSelector(path,"",this.model.settingsFile,this.model.imageRoot)
candidate.preferences["Runs"] := this.currentTask.runs
SplitPath(candidate.imagePath,&imageName)
source := InStr(candidate.imagePath,"\Images\Defaults\") ? "bundled default" : "preserved map capture"
this.Log("Dungeon config selected: map=" name "; config=" CrusadersCatalog.Filename("Dungeons",name,1) "; image=" imageName "; source=" source "; imageHash=" AAInstalledAssets.ImageVersion(candidate.imagePath) "; route=" (AADefaultPaths.Has(name) ? "embedded " AADefaultPaths.Get(name)["duration"] "ms" : "none"))
this.CheckDetectedMapIndexes(candidate,"Dungeons",name)
this.owner.LoadEditor(candidate)
this.model := candidate
SplitPath(path,&filename)
this.currentTask.config := filename
this.beforeDone := false, this.index := 1
this.PrepareMatchActions()
this.owner.LoadFields()
this.owner.UpdateStats()
this.Log("Dungeon Map Detected: Loading " filename)
}
LoadMansionMap(name) {
path := this.DetectedMapPath("Infinity Mansion",name)
candidate := CrusadersSelector(path,"",this.model.settingsFile,this.model.imageRoot)
candidate.preferences["Runs"] := this.HasOwnProp("nextTask") ? this.nextTask.runs : this.model.preferences["Runs"]
candidate.preferences["Difficulty"] := this.HasOwnProp("nextTask") ? this.nextTask.difficulty : this.currentTask.difficulty
this.CheckDetectedMapIndexes(candidate,"Infinity Mansion",name)
this.owner.LoadEditor(candidate)
this.model := candidate
SplitPath(path,&filename)
if this.HasOwnProp("nextTask")
this.currentTask := this.nextTask.Clone()
this.currentTask.config := filename
this.continuationPlanned := false
this.beforeDone := false, this.index := 1
this.PrepareMatchActions()
this.owner.LoadFields()
this.owner.UpdateStats()
this.Log("Map Detected: Loading " filename)
}
Actions(before) {
if this.IsAprilFools()
return []
actions := []
for number,item in this.model.indexes {
if before || !item.enabled || !AAExecution.IndexConfigured(item)
continue
if item.wave
actions.Push(Map("type","wave","target",item.wave))
if item.wait
actions.Push(Map("type","wait","ms",item.wait))
if item.recording != "" {
actions.Push(Map("type","recording","name",item.recording))
continue
}
if item.slot <= 6
actions.Push(Map("type","place","slot",item.slot,"x",item.x,"y",item.y,"index",number,"upgrade",item.upgrade,"autoAbility",item.autoAbility,"priority",item.priority))
else actions.Push(Map("type","click","x",item.x,"y",item.y,"button",item.slot = 8 ? "Right" : "Left"))
}
return actions
}
Advanced() {
this.beforeDone := false
if this.HasOwnProp("nextTask") {
this.owner.LoadRunningMode(this.nextTask)
AAExecution.CheckIndexes(this.model)
this.currentTask := this.nextTask.Clone()
}
this.continuationPlanned := false
this.PrepareMatchActions()
}
Continuation() {
if this.currentTask.mode = "Dungeons"
return "Open Dungeon"
if !this.continuationPlanned {
this.owner.tasks.CompleteMatch(true)
this.nextTask := this.owner.tasks.Current().Clone()
this.continueAction := AAChallenges.Due() ? "Lobby" : AAExecution.Continuation(this.currentTask,this.nextTask)
if this.HasOwnProp("loadedTeam") && this.model.HasOwnProp("configRoot") {
path := this.model.configRoot "\" CrusadersCatalog.Folder(this.nextTask.mode) "\" this.nextTask.config
nextTeam := path = this.model.path ? Integer(this.model.preferences.Get("Team","0")) : Integer(IniRead(path,"Settings","Team","0"))
if nextTeam > 0 && nextTeam != this.loadedTeam
this.continueAction := "Lobby"
}
this.continuationPlanned := true
}
return this.continueAction
}
ResumeAfterAprilReturn() {
if !this.HasOwnProp("nextTask")
this.nextTask := this.currentTask.Clone()
SetTimer((*)=>AAExecution.NextLobby(this,false,false),-1)
}
ResumeDungeonLobby() {
this.nextTask := this.currentTask.Clone()
SetTimer((*)=>AAExecution.NextLobby(this,false,false),-1)
}
SaveDungeonErrorReport(message) => AADungeons.SaveErrorReport(this,message)
ObserveDungeonChests(scan) => AAExecution.ObserveChests(this.owner,scan)
CountDungeonChest(kind) => AAExecution.ChestOpened(this.owner,kind)
SendDungeonReward() {
this.CheckClient()
return CrusadersWebhook.Send(this.owner,"Dungeon Reward")
}
RejoinNextMode(forcePublic := false) {
if !this.HasOwnProp("nextTask")
this.nextTask := this.currentTask.Clone()
SetTimer((*)=>AAExecution.NextLobby(this,forcePublic),-1)
}
PlayRecording(name) {
this.CheckClient()
return this.owner.inputRecorder.Play(CrusadersRecording.Load(name),
(*)=>this.status = "Idle",(*)=>this.CheckPlaybackFocus())
}
CheckPlaybackFocus() {
try {
this.CheckClient()
return true
} catch Error {
return false
}
}
}
class AACameraSession extends AdventuresApp {
__New(owner) {
this.owner := owner, this.core := owner.core, this.hwnd := owner.game
this.status := "Idle", this.index := 1, this.wins := 0, this.losses := 0
this.profile := Map("width",800,"height",600,"actions",[])
this.loop := StoryLoop(this)
this.loop.cameraOnly := true
}
Start() {
this.CheckClient()
this.status := "Running"
this.loop.worker := {Ready:(*)=>true,Dispose:(*)=>0}
this.loop.Change("Camera",15000)
this.loop.cameraStep := 0
SetTimer(this.loop.timer,50)
this.Log("Zoomtech: setting the top-down camera.")
}
Log(message) {
this.owner.Log(message)
this.Publish()
}
Publish() {
global testRunning
testRunning := this.status = "Running" || this.status = "Paused"
CrusadersRuntime.SetPaused(this.status = "Paused")
this.owner.runStatus := this.status
if !testRunning
this.owner.startConsumed := false
this.owner.PushState()
}
}
class AAPreflight extends CrusadersPreflight {
static MissingConfigs(window,model) {
modes := Map(), missing := []
for task in window.tasks.items
if task.enabled && (task.mode="Dungeons" || task.mode="Infinity Mansion" || task.mode="Challenges")
modes[task.mode] := true
if Integer(model.preferences.Get("ChallengeEnabled","0")) || Integer(model.preferences.Get("DailyChallengeEnabled","0"))
modes["Challenges"] := true
for mode in modes {
for name in CrusadersCatalog.ConfigMaps(mode) {
filename := CrusadersCatalog.Filename(mode,name,1)
path := window.tasks.root "\" CrusadersCatalog.Folder(mode) "\" filename
ready := false
try {
if FileExist(path) {
candidate := StrLower(path)=StrLower(model.path) ? model : CrusadersSelector(path,"",model.settingsFile,model.imageRoot)
for item in candidate.indexes
if item.enabled && AAExecution.IndexConfigured(item) {
ready := true
break
}
}
}
if !ready
missing.Push(filename)
}
}
return missing
}
static Config(model,modeNumber := 0) {
if model.preferences["Mode"] = "Events"
return []
issues := [], active := 0
for number,item in model.indexes {
if !item.enabled || !AAExecution.IndexConfigured(item)
continue
active++
if item.recording != "" {
try CrusadersRecording.Load(item.recording)
catch Error
issues.Push(this.Issue("Index " number ": Recording is missing or invalid. Choose a saved recording.","indexes",modeNumber,number))
continue
}
if item.x < 0 || item.y < 0 || item.x >= 800 || item.y >= 600
issues.Push(this.Issue("Index " number ": Choose coordinates inside the game using Select Coordinates.","indexes",modeNumber,number))
if item.autoUpgrade || item.unit != "None"
issues.Push(this.Issue("Index " number ": This AA unit action is not set up yet. Use a saved recording for it.","indexes",modeNumber,number))
}
if !active
issues.Push(this.Issue("This config has no enabled, configured indexes. Set up at least one index.","indexes",modeNumber,1))
return issues
}
static Check(window,model) {
issues := [], enabled := 0
if window.inputRecorder.recording || window.inputRecorder.playing
issues.Push(this.Issue("Stop recording or playback before starting.","recorder"))
if IsObject(CrusadersDetection.snip)
issues.Push(this.Issue("Finish or cancel the detection capture before starting.","detection"))
if CrusadersRuntime.InputBusy(window)
issues.Push(this.Issue("Finish the active camera or route action before starting.","main"))
try AAServer.Url(model.preferences)
catch Error as err
issues.Push(this.Issue(err.Message,"settings"))
for number,item in window.tasks.items {
if !item.enabled
continue
enabled++
try {
window.tasks.Validate(item)
if item.mode = "Events" {
AAAprilFools.Approach()
continue
}
path := window.tasks.root "\" CrusadersCatalog.Folder(item.mode) "\" item.config
if !FileExist(path)
throw Error("Config is missing. Select an existing config.")
candidate := path = model.path ? model : CrusadersSelector(path,"",model.settingsFile,model.imageRoot)
candidate.Validate()
if item.mode != "Dungeons"
for issue in this.Config(candidate,number) {
issue["message"] := "Mode " number ": " issue["message"]
issues.Push(issue)
}
if item.mode = "Raids" {
name := CrusadersCatalog.Name(item.config)
if !AALobbyFlow.Maps.Has(name)
throw Error("This raid's lobby route is not set up yet.")
AALobbyFlow.Approach()
} else if item.mode = "Story" || item.mode = "Infinite" {
AAStoryRoute.Position(CrusadersCatalog.Name(item.config))
AAStoryRoute.Approach()
} else if item.mode = "Legend Stages" {
if !AALegendRoute.Maps.Has(CrusadersCatalog.Name(item.config))
throw Error("This Legend map has not been captured yet.")
AAStoryRoute.Approach()
} else if item.mode = "Infinity Mansion" {
AAMansionRoute.Approach()
} else if item.mode = "Dungeons" {
} else if item.mode = "Portals" {
AAPortalRoute.ValidateName(item.portalName)
} else if AAServer.Url(model.preferences) != ""
throw Error("This mode's automatic lobby entry is not set up yet. Disable rejoining to start inside a match.")
} catch Error as err
issues.Push(this.Issue("Mode " number ": " err.Message,"gamemodes",number))
}
if (Integer(model.preferences.Get("ChallengeEnabled","0")) || Integer(model.preferences.Get("DailyChallengeEnabled","0"))) && AAServer.Url(model.preferences) = ""
issues.Push(this.Issue("Auto Challenge requires Public Rejoin or a private server link.","settings"))
if !enabled && model.preferences.Get("Mode","") = "Events" && model.preferences.Get("Map","") = "April Fools" {
try AAAprilFools.Approach()
catch Error as err
issues.Push(this.Issue(err.Message,"gamemodes"))
} else if !enabled
issues.Push(this.Issue("Add at least one enabled mode in Modes before starting."))
if !CrusadersServer.FindGameWindow() && !CrusadersServer.ShouldRejoinOnStart(model.preferences)
issues.Push(this.Issue("Open Roblox or enable public/private rejoining before starting.","settings"))
return issues
}
}
class AAPauseMenu {
static busy := false
static last := 0
static generation := 0
static White(color) => Min((color>>16)&255,(color>>8)&255,color&255) >= 150 && Max((color>>16)&255,(color>>8)&255,color&255)-Min((color>>16)&255,(color>>8)&255,color&255) <= 65
static Keycap(bitmap,x,y) {
points := [[4,0],[10,0],[18,0],[0,4],[0,10],[0,18],[24,4],[24,10],[24,18],[4,24],[10,24],[18,24]]
loop 9 {
dy := (A_Index-1)*2-8
loop 7 {
dx := (A_Index-1)*2-6, hits := 0, gaps := 0
for p in points
hits += this.White(Gdip_GetPixel(bitmap,x+dx+p[1],y+dy+p[2]))
if hits < 10
continue
for p in [[3,3],[21,3],[3,21],[21,21]]
gaps += !this.White(Gdip_GetPixel(bitmap,x+dx+p[1],y+dy+p[2]))
if gaps >= 3
return true
}
}
return false
}
static Visible(bitmap) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) != 600
return false
underline := false
for y in [116,118,120,122] {
count := 0
loop 98
count += this.White(Gdip_GetPixel(bitmap,A_Index*8,y))
if count >= 12 {
underline := true
break
}
}
return underline && this.Keycap(bitmap,94,505) && this.Keycap(bitmap,625,505)
}
static Allowed(owner) {
if owner.status != "Running" || CrusadersRuntime.paused
throw Error("Pause-menu recovery cancelled: macro stopped or paused.")
if !WinExist(owner.hwnd) || !WinActive(owner.hwnd)
throw AAFocusChanged("Waiting for Roblox focus before checking the pause menu.")
WinGetClientPos(,,&w,&h,owner.hwnd)
if w != 800 || h != 600
throw Error("Pause-menu recovery requires the 800 x 600 Roblox client.")
}
static Open(owner) {
this.Allowed(owner)
WinGetClientPos(&x,&y,&w,&h,owner.hwnd)
bitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
try return bitmap && this.Visible(bitmap)
finally {
if bitmap
Gdip_DisposeImage(bitmap)
}
}
static Escape(owner) {
this.Allowed(owner)
SendEvent("{Escape down}")
try Sleep(35)
finally SendEvent("{Escape up}")
}
static Guard(owner) {
now := Adventures.Tick()
if this.busy || now-this.last < 100 || owner.status != "Running"
return false
this.last := now, this.busy := true, began := 0, restored := false, recorder := 0, held := Map(), camera := false
previous := Critical(false)
try {
if !this.Open(owner)
return false
began := Adventures.Tick()
Sleep(50)
if !this.Open(owner)
return false
if owner.HasOwnProp("owner") && owner.owner.HasOwnProp("inputRecorder") {
recorder := owner.owner.inputRecorder
if recorder.playing {
held := recorder.playbackHeld.Clone()
recorder.ReleasePlayback()
}
}
flow := owner.HasOwnProp("loop") ? owner.loop : owner
if flow.HasOwnProp("cameraHeld") && flow.cameraHeld {
camera := true
SendEvent("{RButton up}")
}
if HasMethod(owner,"Log")
owner.Log("Roblox pause menu detected; closing and retrying the interrupted step")
absent := 0, sent := 0
loop {
this.Allowed(owner)
if Adventures.Tick()-began > 5000
throw Error("Roblox pause menu did not close. Close it manually, then resume.")
if this.Open(owner) {
absent := 0
if !sent || Adventures.Tick()-sent >= 450 {
this.Escape(owner)
sent := Adventures.Tick()
}
} else {
absent++
if absent >= 2 {
restored := true, this.generation++
return true
}
}
Sleep(70)
}
} finally {
if began {
elapsed := Adventures.Tick()-began
CrusadersRuntime.pauseTotal += elapsed
flow := owner.HasOwnProp("loop") ? owner.loop : owner
for field in ["deadline","due","actionDue","idleKeyDue","placementStarted","rewardHardDeadline"]
if flow.HasOwnProp(field)
flow.%field% += elapsed
}
if restored && owner.status = "Running" && !CrusadersRuntime.paused && WinActive(owner.hwnd) {
if recorder && held.Count {
WinGetClientPos(&left,&top,,,owner.hwnd)
for token,release in held {
down := release.Clone()
down["action"] := release["action"] = "keyUp" ? "keyDown" : "mouseDown"
recorder.SendPlaybackEvent(down,left,top)
recorder.playbackHeld[token] := release
}
}
if camera
SendEvent("{RButton down}")
}
this.last := Adventures.Tick(), this.busy := false
Critical(previous)
}
}
}
class AAFocusChanged extends Error {
}
class AAInput {
static WaitingForFocus(flow,hwnd) {
if !hwnd || !WinExist(hwnd)
return false
if !WinActive(hwnd) {
running := flow.HasOwnProp("status") ? flow.status = "Running" : flow.HasOwnProp("app") && flow.app.status = "Running"
owner := flow.HasOwnProp("owner") ? flow.owner : flow.HasOwnProp("app") && flow.app.HasOwnProp("owner") ? flow.app.owner : 0
modal := IsObject(owner) && owner.HasOwnProp("webModalVisible") && owner.webModalVisible
now := Adventures.Tick()
if running && !CrusadersRuntime.paused && !modal && (!flow.HasOwnProp("lastFocusAttempt") || now-flow.lastFocusAttempt >= 750) {
flow.lastFocusAttempt := now
try {
if WinGetMinMax(hwnd) = -1
WinRestore(hwnd)
WinActivate(hwnd)
}
}
if !flow.HasOwnProp("focusWaitStarted")
flow.focusWaitStarted := Adventures.Tick()
return true
}
if flow.HasOwnProp("focusWaitStarted") {
elapsed := Adventures.Tick()-flow.focusWaitStarted
flow.DeleteProp("focusWaitStarted")
for field in ["deadline","due","actionDue","idleKeyDue","placementStarted","rewardHardDeadline"]
if flow.HasOwnProp(field)
flow.%field% += elapsed
}
return false
}
static Check(check) {
AADisplay.UsePhysicalPixels()
global testCancelled
check.Call()
if testCancelled || CrusadersRuntime.paused
throw Error("Game click cancelled: macro is paused or stopped.")
}
static MoveScreen(x,y,check) {
this.Check(check)
previousMode := A_SendMode
SendMode("Event")
try {
MouseGetPos(&currentX,&currentY)
if currentX != x || currentY != y
MouseMove(x,y,2)
} finally SendMode(previousMode)
}
static Click(hwnd,x,y,check,button := "Left",skipLeaderboard := false) {
this.Check(check)
static closingLeaderboard := false
if !skipLeaderboard && !closingLeaderboard && !(x = 641 && y = 73) {
WinGetClientPos(&captureX,&captureY,&captureW,&captureH,hwnd)
frame := Gdip_BitmapFromScreen(captureX "|" captureY "|" captureW "|" captureH)
try visible := frame && AALeaderboard.Visible(frame)
finally {
if frame
Gdip_DisposeImage(frame)
}
if visible {
closingLeaderboard := true
try {
if !AALeaderboard.Close(hwnd,check)
throw Error("Leaderboard could not be closed. Close it and resume the macro.")
} finally closingLeaderboard := false
this.Check(check)
}
}
if x < 0 || x >= 800 || y < 0 || y >= 600
throw Error("Game click is outside the client.")
WinGetClientPos(&left,&top,,,hwnd)
previousMode := A_CoordModeMouse
CoordMode("Mouse","Screen")
try this.MoveScreen(left+x,top+y,check)
finally CoordMode("Mouse",previousMode)
Sleep(120)
down := false
mouseButton := button = "Right" ? "Right " : ""
try {
this.Check(check)
SendEvent("{Click " mouseButton "Down}")
down := true
Sleep(100)
} finally {
if down
SendEvent("{Click " mouseButton "Up}")
}
}
}
class AALeaderboard {
static mask := 0
static lastX := 641
static lastY := 73
static Visible(bitmap) {
d := CrusadersDetection.Get("leaderboard-close")
if CrusadersDetection.FindBitmap(bitmap,"leaderboard-close") {
this.lastX := 641, this.lastY := 73
return true
}
if !this.mask {
reference := Gdip_CreateBitmapFromFile(A_ScriptDir "\Images\Detection\AA\leaderboard-close.png")
if !reference
return false
try {
width := Gdip_GetImageWidth(reference), height := Gdip_GetImageHeight(reference)
if width > 100 || height > 100
return false
points := [], holes := [], minX := width, minY := height, maxX := 0, maxY := 0
loop height {
y := A_Index-1
loop width {
x := A_Index-1, rgb := Gdip_GetPixel(reference,x,y)
if (rgb&255) >= 190 && ((rgb>>8)&255) >= 190 && ((rgb>>16)&255) >= 190 {
points.Push([x,y])
minX := Min(minX,x), maxX := Max(maxX,x), minY := Min(minY,y), maxY := Max(maxY,y)
}
}
}
if points.Length < 10
return false
loop maxY-minY+1 {
y := minY+A_Index-1
loop maxX-minX+1 {
x := minX+A_Index-1, rgb := Gdip_GetPixel(reference,x,y)
if (rgb&255) < 120 && ((rgb>>8)&255) < 120 && ((rgb>>16)&255) < 120
holes.Push([x,y])
}
}
this.mask := {points:points,holes:holes,x:(minX+maxX)/2,y:(minY+maxY)/2}
} finally Gdip_DisposeImage(reference)
}
loop 5 {
dy := A_Index-3
loop 5 {
dx := A_Index-3, hits := 0, gaps := 0
for point in this.mask.points
hits += this.White(Gdip_GetPixel(bitmap,630+dx+point[1],64+dy+point[2]))
if hits/this.mask.points.Length < 0.82
continue
for point in this.mask.holes
gaps += this.White(Gdip_GetPixel(bitmap,630+dx+point[1],64+dy+point[2]))
if this.mask.holes.Length && gaps/this.mask.holes.Length > 0.25
continue
this.lastX := Round(630+dx+this.mask.x), this.lastY := Round(64+dy+this.mask.y)
return true
}
}
return false
}
static White(rgb) {
r := (rgb>>16)&255, g := (rgb>>8)&255, b := rgb&255
return Min(r,g,b) >= 150 && Max(r,g,b)-Min(r,g,b) <= 60
}
static Open(hwnd,check) {
AAInput.Check(check)
WinGetClientPos(&left,&top,&width,&height,hwnd)
bitmap := Gdip_BitmapFromScreen(left "|" top "|" width "|" height)
try return bitmap && this.Visible(bitmap)
finally {
if bitmap
Gdip_DisposeImage(bitmap)
}
}
static Close(hwnd,check) {
if !this.Open(hwnd,check)
return true
AAInput.Check(check)
SendEvent("{Tab down}")
try Sleep(50)
finally SendEvent("{Tab up}")
Sleep(200)
if !this.Open(hwnd,check)
return true
AAInput.Click(hwnd,this.lastX,this.lastY,check,"Left",true)
loop 4 {
Sleep(75)
if !this.Open(hwnd,check)
return true
}
return false
}
}
class AALobbyVision {
static IsMatchTransition(lobbyText,loadingText,darkRatio) {
if RegExMatch(lobbyText,"i)\b(?:Areas|Items|Quests|Battlepass)\b")
return false
return darkRatio >= 0.90 || RegExMatch(loadingText,"i)\b(?:loading|connecting|joining\s+(?:server|game))\b")
}
static MatchmakingStarted(text) {
text := StrLower(RegExReplace(text,"[^a-zA-Z]",""))
return InStr(text,"matchmakingstarted") || InStr(text,"matchfound")
}
static Read(reader,bitmap) {
reward := reader.Read(bitmap,165,235,470,180,2)
rewardWords := StrLower(RegExReplace(reward,"[^a-zA-Z]",""))
if InStr(rewardWords,"dailyloginrewards") && InStr(rewardWords,"claim")
return Map("kind","daily-login-reward","text",reward,"ownerWait",0)
heading := reader.Read(bitmap,190,123,410,55,2)
normalized := StrLower(RegExReplace(heading,"[^a-zA-Z]",""))
if InStr(normalized,"switchteam")
return Map("kind","teams-menu","text",heading,"ownerWait",0)
collection := reader.Read(bitmap,145,170,410,75,2)
collectionWords := StrLower(RegExReplace(collection,"[^a-zA-Z]",""))
if InStr(collectionWords,"collection") && InStr(collectionWords,"teams")
return Map("kind","units-menu","text",collection,"ownerWait",0)
if InStr(normalized,"areas") && InStr(normalized,"teleport") {
raids := reader.Read(bitmap,406,385,184,54,2)
return Map("kind",RegExMatch(raids,"i)\bRaids\b") ? "raids-menu" : "areas-menu",
"text",heading "`n" raids,"ownerWait",0)
}
label := reader.Read(bitmap,720,430,80,120,3)
return Map("kind",RegExMatch(label,"i)\bAreas\b") ? "lobby" : "none","text",label,"ownerWait",0)
}
}
class AAConnection {
static Parse(text) {
normalized := StrLower(RegExReplace(text,"[^a-zA-Z0-9]",""))
dialog := RegExMatch(text,"i)\b(disconnected|connection\s*failed|join\s*error|teleport\s*failed)\b")
code := RegExMatch(text,"i)error\s*code\s*[:#]?\s*(\d{3})\b",&match) ? Integer(match[1]) : 0
datastoreFailure := code = 267 && InStr(normalized,"datastoresnotloadingpleaserejoin")
loadFailure := code = 267 && (InStr(normalized,"gamefailedtoloadpleaserejoin") || datastoreFailure)
restricted := RegExMatch(text,"i)(banned|not\s*authorized|do\s*not\s*have\s*permission|restricted|authentication|log\s*in)")
if !dialog && !loadFailure
return Map("kind","none","text",text,"ownerWait",0)
if loadFailure && !restricted
return Map("kind","rejoin","text",datastoreFailure ? "Roblox datastores not loading (PSS4/267); rejoining" : "Game failed to load (267); rejoining","ownerWait",0,"forcePublic",datastoreFailure ? true : false)
blocked := code = 267 || code = 268 || code = 272 || code = 524 || code = 403
|| RegExMatch(text,"i)(banned|not\s*authorized|do\s*not\s*have\s*permission|restricted|authentication|log\s*in)")
if blocked
return Map("kind","access-denied","text","Roblox needs attention" (code ? " (" code ")" : ""),"ownerWait",0)
recoverable := InStr("|256|260|261|262|264|266|273|274|277|278|279|285|288|517|522|529|","|" code "|")
|| RegExMatch(text,"i)(lost\s*(?:your\s*)?connection|connection\s*(?:was\s*)?(?:lost|timed\s*out)|failed\s*to\s*connect|server\s*(?:has\s*)?(?:shut\s*down|shutdown)|idle\s*for|same\s*account|server\s*is\s*full|teleport\s*failed)")
return Map("kind",recoverable ? "rejoin" : "none","text",recoverable ? "Roblox disconnected" (code ? " (" code ")" : "") : text,"ownerWait",0)
}
static Register() {
if CrusadersDetection.definitions.Has("connection-idle-278")
return
root := A_ScriptDir "\Images\Detection\AA\Connection"
DirCreate(root)
FileInstall("Images\Detection\AA\Connection\title.png",root "\title.png",1)
FileInstall("Images\Detection\AA\Connection\idle-278.png",root "\idle-278.png",1)
FileInstall("Images\Detection\AA\Connection\reconnect.png",root "\reconnect.png",1)
for name in ["title","idle-278","reconnect"]
CrusadersDetection.definitions["connection-" name] := {name:"Connection " name,group:"Connection",file:"AA\Connection\" name ".png",kind:"Image",x:200,y:165,w:400,h:280,tolerance:12,frames:2,cx:0,cy:0,cw:0,ch:0}
}
static Modal(bitmap) {
base := Gdip_GetPixel(bitmap,220,240), red := (base>>16)&255, green := (base>>8)&255, blue := base&255
if Min(red,green,blue)<25 || Max(red,green,blue)>105 || Max(red,green,blue)-Min(red,green,blue)>20
return false
flat := 0
for x in [220,225,575,580]
for y in [210,240,270,300,330] {
pixel := Gdip_GetPixel(bitmap,x,y)
if Max(Abs(((pixel>>16)&255)-red),Abs(((pixel>>8)&255)-green),Abs((pixel&255)-blue))<=12
flat++
}
return flat>=18
}
static Read(reader,bitmap) {
if !this.Modal(bitmap)
return Map("kind","none","text","","ownerWait",0)
title := reader.Read(bitmap,210,165,380,65,2)
buttons := reader.Read(bitmap,210,355,380,80,2)
words := StrLower(RegExReplace(title,"[^A-Za-z]",""))
header := RegExMatch(words,"disconnected|connectionfailed|joinerror|teleportfailed")
if header && RegExMatch(buttons,"i)\b(Leave|Reconnect|Retry|OK)\b") {
body := reader.Read(bitmap,215,235,370,125,2)
result := this.Parse(title "`n" body)
if result["kind"] != "none"
return result
result := this.Parse(title "`n" reader.Read(bitmap,215,235,370,125,3))
if result["kind"] != "none"
return result
}
this.Register()
if CrusadersDetection.FindBitmap(bitmap,"connection-idle-278") && CrusadersDetection.FindBitmap(bitmap,"connection-title") && CrusadersDetection.FindBitmap(bitmap,"connection-reconnect")
return Map("kind","rejoin","text","Roblox disconnected (278)","ownerWait",0)
return Map("kind","none","text","","ownerWait",0)
}
static Reset() {
this.candidate := "", this.frames := 0, this.scanned := 0
}
static Poll(reader,bitmap) {
if !this.Modal(bitmap) {
this.Reset()
return Map("kind","none","text","","ownerWait",0)
}
now := Adventures.Tick()
if this.HasOwnProp("scanned") && now-this.scanned<250
return Map("kind","none","text","","ownerWait",0)
this.scanned := now, result := this.Read(reader,bitmap)
signature := result["kind"] "|" result["text"]
if result["kind"] = "none" {
this.candidate := "", this.frames := 0
return result
}
this.frames := this.HasOwnProp("candidate") && this.candidate=signature ? this.frames+1 : 1
this.candidate := signature
return this.frames>=2 ? result : Map("kind","none","text","","ownerWait",0)
}
}
class AAServer {
static PlaceId := "8304191830"
static Url(preferences) {
link := CrusadersServer.PrivateLink(preferences)
if link != ""
return CrusadersServer.JoinUrl(link)
return preferences.Get("PublicRejoin","0") = "1" ? CrusadersServer.JoinUrl("") : ""
}
}
class AATransitionVision {
static FestivalScenery := [[360,140,0x7F7751],[440,140,0x6D2E09],[520,140,0x794411],[360,180,0x6F481A],[440,180,0x8D641E],[520,180,0x91661F],[680,180,0x975711],[760,180,0xEDC253],[680,260,0x47191D],[280,300,0x521D0E],[200,340,0x431E10],[280,340,0x4B190F],[600,340,0x5E1D07],[600,380,0x5D1B0A],[680,380,0x701F08],[760,380,0x6D1D07]]
static FestivalBackground(bitmap) {
return this.FestivalMatches(bitmap)>=13
}
static FestivalMatches(bitmap) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) != 600
return 0
matches := 0
for point in this.FestivalScenery {
rgb := Gdip_GetPixel(bitmap,point[1],point[2]), expected := point[3]
if Abs(((rgb>>16)&255)-((expected>>16)&255))<=40
&& Abs(((rgb>>8)&255)-((expected>>8)&255))<=40 && Abs((rgb&255)-(expected&255))<=40
matches++
}
return matches
}
static Read(reader,bitmap,names) {
title := reader.Read(bitmap,10,65,780,56,2)
name := AAMansionRoute.MatchMap(title,names)
if name = "" {
title := reader.Read(bitmap,10,65,780,56,3)
name := AAMansionRoute.MatchMap(title,names)
}
titleMap := name, sceneryMatches := name = "Mountain Temple" ? this.FestivalMatches(bitmap) : -1
if name = "Mountain Temple" && sceneryMatches>=13
for allowed in names
if allowed = "Cursed Festival"
name := "Cursed Festival"
detail := reader.Read(bitmap,10,122,780,65,2), text := title "`n" detail
normalized := StrLower(RegExReplace(detail,"[^A-Za-z0-9]",""))
context := InStr(normalized,"contract") || InStr(normalized,"infinitymansion") ? "mansion"
: RegExMatch(detail,"i)Dungeon\s*Room\s*\(?\s*Depth") ? "dungeon"
: RegExMatch(detail,"i)\bAct\s*([1-6])\b",&act) ? "stage"
: InStr(normalized,"dailychallenge") || RegExMatch(detail,"i)\bChallenge\b") ? "challenge" : ""
if context = "" && name = "Cursed Festival" && InStr(AAMansionRoute.CleanMapText(title),"mountaintemple")
context := "alternate-loading"
difficulty := RegExMatch(detail,"i)\b(Hard|Normal)\b",&level) ? level[1] : ""
blue := 0
loop 19 {
y := 65+(A_Index-1)*3
loop 180 {
color := Gdip_GetPixel(bitmap,15+(A_Index-1)*4,y)
red := (color>>16)&255, green := (color>>8)&255, cyan := color&255
if red < 140 && green > 105 && cyan > 155 && cyan-green > 12
blue++
}
}
valid := name != "" && context != "" && blue >= 35
return Map("kind",valid ? "transition-map" : "none","map",valid ? name : "","context",context,
"titleMap",titleMap,"festivalSceneryMatches",sceneryMatches,"titleBluePixels",blue,
"act",context = "stage" ? Integer(act[1]) : 0,"difficulty",difficulty,"text",text,"ownerWait",0)
}
}
class AAMansionRoute {
static TeleportPosition := [303,332]
static InitialMapRegion := [440,265,130,40]
static LoadingMapRegion := [10,45,780,125]
static StartPosition := [400,438]
static CleanMapText(text) => StrLower(RegExReplace(text,"[^a-zA-Z0-9]",""))
static EditDistance(a,b) {
previous := []
Loop StrLen(b)+1
previous.Push(A_Index-1)
Loop StrLen(a) {
row := [A_Index], ca := SubStr(a,A_Index,1), rowMinimum := A_Index
Loop StrLen(b) {
cb := SubStr(b,A_Index,1), cost := ca = cb ? 0 : 1
for group in ["0o","1il","3e","5s","8b","6g","7t","2z"]
if ca != cb && InStr(group,ca) && InStr(group,cb)
cost := 0.25
row.Push(Min(row[A_Index]+1,previous[A_Index+1]+1,previous[A_Index]+cost))
rowMinimum := Min(rowMinimum,row[row.Length])
}
if rowMinimum > 2
return Max(StrLen(a),StrLen(b))
previous := row
}
return previous[previous.Length]
}
static MatchMap(text,names := unset) {
if !IsSet(names)
names := CrusadersCatalog.MansionMaps
text := this.CleanMapText(text), exact := "", longest := 0
if InStr(text,"mountaintemple") {
hasMountain := false, hasFestival := false
for name in names {
hasMountain := hasMountain || name = "Mountain Temple"
hasFestival := hasFestival || name = "Cursed Festival"
}
if hasFestival && !hasMountain
return "Cursed Festival"
}
for name in names
if name = "Spirit Invasion" && InStr(text,"spirittown")
return "Spirit Invasion"
for alias,canonical in AADefaultPaths.Aliases {
for name in names
if name = canonical && InStr(text,this.CleanMapText(alias))
return canonical
}
for name in names {
key := this.CleanMapText(name)
if InStr(text,key) && StrLen(key) > longest
exact := name, longest := StrLen(key)
}
if exact != ""
return exact
best := 0, second := 0, selected := ""
for name in names {
key := this.CleanMapText(name), length := StrLen(key), score := 0
for offset in [-2,-1,0,1,2] {
width := length+offset
if width < 1 || width > StrLen(text)
continue
Loop StrLen(text)-width+1 {
distance := this.EditDistance(key,SubStr(text,A_Index,width))
score := Max(score,1-distance/Max(length,width))
}
}
if score > best
second := best, best := score, selected := name
else second := Max(second,score)
}
return best >= 0.90 && best-second >= 0.12 ? selected : ""
}
static ReadLoadingMap(reader,bitmap) {
scan := AATransitionVision.Read(reader,bitmap,CrusadersCatalog.MansionMaps)
if scan["kind"] != "none" && (scan["context"] = "mansion" || scan["context"] = "alternate-loading") {
scan["kind"] := "mansion-map"
return scan
}
r := this.LoadingMapRegion, text := reader.Read(bitmap,r[1],r[2],r[3],r[4],2)
context := this.CleanMapText(text)
if InStr(context,"dungeonroom")
return Map("kind","none","map","","text",text,"ownerWait",0)
if !InStr(context,"infinitymansion") && !InStr(context,"contract")
return Map("kind","none","map","","text",text,"ownerWait",0)
name := this.MatchMap(text)
return Map("kind",name != "" ? "mansion-map" : "none","map",name,"text",text,"ownerWait",0)
}
static ReadInitialMap(reader,bitmap) {
region := this.InitialMapRegion
text := reader.Read(bitmap,region[1],region[2],region[3],region[4],3)
name := this.MatchMap(text)
return Map("kind",name != "" ? "mansion-map" : "none","map",name,"text",text,"ownerWait",0)
}
static Approach() {
return CrusadersRecording.Validate(Map("version",1,"width",800,"height",600,"duration",4721,
"events",[Map("action","keyDown","at",640,"key","a"),Map("action","keyDown","at",2280,"key","w"),Map("action","keyUp","at",2857,"key","w"),Map("action","keyUp","at",3899,"key","a")]))
}
}
class AALegendRoute {
static ButtonPosition := [701,140]
static Acts := [[290,239],[290,274],[290,309],[290,344],[290,379],[290,383]]
static RuinedCityActs := [[289,238],[289,272],[289,306],[289,340],[289,374],[289,383]]
static Maps := Map("Magic Hills [Elf Invasion]",[696,238,0],"Spirit Invasion",[696,290,0],
"Space Center",[696,342,0],"Fabled Kingdom [Generals]",[696,394,0],"Ruined City [Midnight]",[696,441,0],
"Virtual Dungeon [Bosses]",[696,393,1],"Dungeon Throne",[696,440,1],"Rain Village",[696,394,2])
}
class AAPortalRoute {
static ItemsPosition := [36,297]
static Steps := Map("PortalTabClick",[436,227],"PortalSearchClick",[510,190],
"PortalFirstClick",[216,287],"PortalUseClick",[349,394],
"PortalOpenClick",[253,353],"PortalStartClick",[400,465])
static Next := Map("PortalTabClick","PortalSearchClick","PortalSearchClick","PortalSearchType",
"PortalSearchType","PortalFirstClick","PortalFirstClick","PortalUseClick",
"PortalUseClick","PortalOpenClick","PortalOpenClick","PortalStartClick","PortalStartClick","EnterMatch")
static ValidateName(value, required := true) {
if IsObject(value)
throw Error("Enter a portal name.")
value := Trim(String(value))
if (required && value = "") || StrLen(value) > 80 || RegExMatch(value,"[\x00-\x1F\x7F]")
throw Error("Portal Name must contain 1-80 characters on one line.")
return value
}
}
class AALobbyFlow {
static JoinTimeout := 300000
static MatchmakingTimeout := 120000
static Maps := Map("Ant Kingdom [Midnight]",[696,239,0],"Sacred Planet",[696,290,0],
"Strange Town",[696,343,0],"Ruined City [The Menace]",[696,394,0],"Cursed Festival",[696,444,0],
"Future City [Tyrant's Invasion]",[696,397,1],"Storm Hideout",[696,347,2],
"Future City",[696,399,2],"Nightmare Train",[696,350,3],"Sand Village",[696,403,3])
static Acts := [[291,239],[291,274],[291,309],[291,344],[291,379]]
static SelectPosition := [400,438]
static PlayHerePosition := [335,326]
static StartPosition := [400,465]
static Approach() {
return CrusadersRecording.Validate(Map("version",1,"width",800,"height",600,"duration",5512,
"events",[Map("action","keyDown","at",772,"key","LShift"),Map("action","keyDown","at",792,"key","a"),Map("action","keyDown","at",1380,"key","w"),Map("action","keyUp","at",3243,"key","w"),Map("action","keyUp","at",4915,"key","a"),Map("action","keyUp","at",4931,"key","LShift")]))
}
__New(window,model) {
this.owner := window, this.model := model, this.core := window.core
this.hwnd := window.game, this.worker := 0, this.busy := false, this.closed := false
this.timer := ObjBindMethod(this,"Tick"), this.scanned := 0, this.absent := 0
this.status := "Running", this.stage := "AwaitLobby", this.cleaned := false
this.deadline := Adventures.Tick()+120000, this.due := 0
this.teamDone := false, this.teamPhase := "units", this.teamLoaded := false
}
Start(rejoin := true,forcePublic := false) {
global testRunning
this.owner.aprilMap := ""
url := rejoin ? AAServer.Url(this.model.preferences) : ""
if rejoin && forcePublic && url = ""
url := CrusadersServer.JoinUrl("")
if url != "" {
this.deadline := Adventures.Tick()+AALobbyFlow.JoinTimeout
this.stage := "Joining", this.due := Adventures.Tick()+1000
this.rejoinStarted := Adventures.Tick(), this.departed := false
this.originalHwnd := this.hwnd, this.lobbyConfirmations := 0
this.Log(CrusadersServer.PrivateLink(this.model.preferences) != "" ? "Joining private server" : "Joining public server")
CrusadersServer.LaunchUrl(url)
}
if this.stage != "Joining" {
this.MoveLeft()
this.Log("Waiting for lobby")
}
this.worker := StoryOcrClient(this)
this.visionReady := false
testRunning := true, this.owner.runStatus := "Joining / Lobby"
this.owner.PushState()
SetTimer(this.timer,50)
}
Log(message) {
if this.closed || !IsObject(this.owner)
return
owner := this.owner
owner.Log(message)
if this.closed
return
owner.runStatus := this.status = "Paused" ? "Paused" : this.stage
owner.PushState()
}
MoveLeft() {
this.CheckClient()
WinGetClientPos(&left,&top,,,this.hwnd)
previousMode := A_CoordModeMouse
CoordMode("Mouse","Screen")
try MouseMove(left+3,top+3,0)
finally CoordMode("Mouse",previousMode)
}
CheckClient() {
AADisplay.UsePhysicalPixels()
if !this.hwnd || !WinExist(this.hwnd) || !WinActive(this.hwnd) || WinGetMinMax(this.hwnd) = -1
throw Error("Keep Roblox active while navigating the lobby.")
WinGetClientPos(,,&w,&h,this.hwnd)
if w != 800 || h != 600
throw Error("AA lobby navigation requires an 800 x 600 client.")
AAPauseMenu.Guard(this)
}
ClickAt(x,y) => AAInput.Click(this.hwnd,x,y,ObjBindMethod(this,"CheckClient"))
Tick() {
if this.owner.HasOwnProp("shopTestBusy") && this.owner.shopTestBusy
return
if this.closed || this.busy || this.status != "Running"
return
this.busy := true
try {
now := Adventures.Tick()
if this.stage = "AprilHoldDelay" {
if now < this.due
return
this.BeginAprilPopOut()
return
}
if this.stage = "AprilHoldPrepare" {
if AAInput.WaitingForFocus(this,this.hwnd)
return
if now < this.due
return
this.BeginAprilMinimizeHold()
return
}
if this.stage = "AprilMinimizeHold" {
if !WinActive(this.hwnd) {
this.SuspendAprilHold()
return
}
if IsObject(this.worker) && this.worker.Ready() && this.owner.aprilMap != "Snowy Town" {
scan := this.worker.Poll()
if scan && scan["kind"] = "april-map"
this.owner.aprilMap := scan["map"]
if now-this.scanned >= 200 {
this.worker.Request("april-map"), this.scanned := now
}
}
remaining := Max(0,Ceil((this.holdUntil-now)/1000))
if !this.HasOwnProp("holdSecondsShown") || this.holdSecondsShown != remaining {
this.holdSecondsShown := remaining
this.owner.runStatus := "April Fools: Waiting " remaining "s"
this.owner.PushState()
}
if now < this.holdUntil
return
SendEvent("{RButton up}")
this.rightHeld := false
DllCall("PostMessageW","Ptr",this.hwnd,"UInt",0x001F,"Ptr",0,"Ptr",0)
this.RestoreAprilWindow()
owner := this.owner, model := this.model
this.Finish("Loading match")
AAExecution.StartMatch(owner,model)
return
}
if this.stage != "Joining" && AAInput.WaitingForFocus(this,this.hwnd)
return
if now > this.deadline && this.stage = "AprilWaiting" {
this.Log("Matchmaking timed out after 2 minutes; rejoining and repeating lobby/pod pathing")
this.Handle(Map("kind","rejoin","text","Matchmaking timeout","forcePublic",true))
return
}
if now > this.deadline && SubStr(this.stage,1,5) = "April" {
this.Log("Matchmaking timeout, restarting mode")
this.CheckClient()
this.ClickAt(400,520)
this.stage := "PathDelay", this.due := now+1000, this.deadline := now+90000
return
}
if now > this.deadline && (this.stage = "Joining" || this.stage = "AwaitRejoin" || this.stage = "AwaitLobby") {
if this.model.preferences["Mode"] = "Dungeons" {
reason := "Dungeon recovery: " this.stage " timed out; expected Roblox lobby HUD and Dungeon navigation; " (this.HasOwnProp("lastDungeonObservation") ? this.lastDungeonObservation : "No completed scan received") "; retrying configured server"
this.Log(reason)
this.SaveDungeonErrorReport(reason)
}
this.Log("Server/lobby loading timed out; retrying the configured server")
this.Handle(Map("kind","rejoin","text","Server loading timed out","forcePublic",true))
return
}
if now > this.deadline
throw Error("AA rejoin/lobby timed out. Check server access, then restart the macro.")
if now < this.due
return
if this.stage = "RecoveryWait" {
Run(this.recoveryUrl)
this.stage := "Joining", this.rejoinStarted := now
this.lastRecoveryLaunch := now
return
}
if this.stage = "Joining" {
hwnd := CrusadersServer.FindGameWindow()
if !hwnd
return
if hwnd != this.originalHwnd
this.departed := true
if hwnd != this.owner.game
this.owner.AttachGame(hwnd)
this.hwnd := hwnd
if !this.owner.ShowGame()
return
this.MoveLeft()
this.stage := "AwaitRejoin"
this.Log("Joining server")
}
if AAInput.WaitingForFocus(this,this.hwnd)
return
this.CheckClient()
if SubStr(this.stage,1,6) = "Portal" {
this.PortalSelection()
return
}
if this.stage = "AprilPlayHere" {
if !this.worker.Ready()
return
scan := this.worker.Poll()
if scan && scan["kind"] = "april-entry" {
this.ClickAt(465,325)
this.Log("April Fools: Find Match at client (465,325) - screenshot fix")
this.stage := "AprilNumbers", this.due := Adventures.Tick()+300
this.deadline := Adventures.Tick()+90000, this.scanned := 0
} else if scan && (scan["kind"] = "rejoin" || scan["kind"] = "access-denied") {
this.Handle(scan)
} else if scan && scan["kind"] = "leaderboard" {
AALeaderboard.Close(this.hwnd,ObjBindMethod(this,"CheckClient"))
} else if now-this.scanned >= 200 {
this.worker.Request("april-entry"), this.scanned := now
}
return
}
if this.stage = "AprilSubmit" {
this.ClickAt(300,385)
this.stage := "AprilWaiting", this.due := Adventures.Tick()+300, this.deadline := Adventures.Tick()+AALobbyFlow.MatchmakingTimeout
this.matchNoticeSeen := false, this.noticeAbsentFrames := 0
this.scanned := 0
return
}
if this.stage = "AprilNumbers" || this.stage = "AprilWaiting" {
if !this.worker.Ready()
return
scan := this.worker.Poll()
if scan {
kind := scan["kind"]
if kind = "april-map"
this.owner.aprilMap := scan["map"]
if kind = "rejoin" || kind = "access-denied" {
this.Handle(scan)
return
}
if kind = "leaderboard" {
AALeaderboard.Close(this.hwnd,ObjBindMethod(this,"CheckClient"))
return
}
if this.stage = "AprilNumbers" && kind = "matchmaking-numbers" {
this.ClickAt(400,339)
AAInput.Check(ObjBindMethod(this,"CheckClient"))
SendEvent("^a")
Sleep(200)
for digit in StrSplit(scan["text"]) {
AAInput.Check(ObjBindMethod(this,"CheckClient"))
SendText(digit)
Sleep(150)
}
this.stage := "AprilSubmit", this.due := Adventures.Tick()+300
return
}
if this.stage = "AprilNumbers" && kind = "matchmaking-missing" {
this.Log("Captcha not detected, retrying...")
this.ClickAt(585,190)
this.stage := "AprilPlayHere", this.due := Adventures.Tick()+1000
return
}
if this.stage = "AprilWaiting" && kind = "matchmaking-ready" {
this.noticeAbsentFrames := 0
if this.matchNoticeSeen
return
this.matchNoticeSeen := true
this.Log("Matchmaking status detected; waiting for the green notice to disappear")
}
if this.stage = "AprilWaiting" && kind = "matchmaking-visible"
this.noticeAbsentFrames := 0
if this.stage = "AprilWaiting" && (kind = "matchmaking-waiting" || kind = "matchmaking-transition" || kind = "april-map") && this.matchNoticeSeen {
this.noticeAbsentFrames := (this.HasOwnProp("noticeAbsentFrames") ? this.noticeAbsentFrames : 0)+1
if this.noticeAbsentFrames < 2
return
this.Log("Green matchmaking notice disappeared; starting minimize hold immediately")
this.stage := "AprilHoldDelay", this.due := Adventures.Tick()
this.deadline := Adventures.Tick()+140000
return
}
}
if now-this.scanned >= 200 {
this.worker.Request(this.stage = "AprilNumbers" ? "matchmaking-numbers" : "matchmaking-lobby")
this.scanned := now
}
return
}
if this.stage = "ChallengeStartClick" {
if now<this.due
return
this.ClickAt(400,465)
this.stage := "ChallengePod", this.scanned := 0
this.Log("Challenge lobby: timed Start click; waiting for map transition")
return
}
if this.stage = "DailyPlayHereClick" || this.stage = "LegendButtonClick" || this.stage = "MansionDifficultyClick" || this.stage = "MansionStartClick" || this.stage = "MansionPlayHereClick" || this.stage = "MapClick" || this.stage = "ActClick" || this.stage = "ActConfirmClick" || this.stage = "DifficultyClick" || this.stage = "SelectClick" || this.stage = "PlayHereClick" || this.stage = "StartClick" || this.stage = "EnterMatch" {
this.TimedSelection()
return
}
if this.stage = "PathDelay" {
this.PlayApproach()
return
}
if !this.worker.Ready()
return
if !this.visionReady {
this.visionReady := true
}
result := this.worker.Poll()
if this.closed
return
if result
this.Handle(result)
if this.closed || this.stage = "PathDelay"
return
if now-this.scanned >= 700 {
requestStage := this.stage = "DungeonLaunch" ? "dungeon" : this.stage = "AwaitMansionMap" ? "mansion-initial" : "lobby"
if this.stage = "ChallengePod" {
requestStage := "challenge-entry"
}
this.worker.Request(requestStage)
this.scanned := now
}
} catch Error as err {
if err is AAFocusChanged {
if this.HasOwnProp("rightHeld") && this.rightHeld
this.SuspendAprilHold()
if !this.closed
AAInput.WaitingForFocus(this,this.hwnd)
return
}
if !this.closed && AAInput.WaitingForFocus(this,this.hwnd)
return
if !this.closed {
if this.model.preferences["Mode"] = "Challenges" {
AAChallenges.Skip(this.owner,"Challenge entry failed: " err.Message)
this.Finish("Returning to mode queue")
} else {
this.Log(err.Message)
if this.model.preferences["Mode"] = "Dungeons"
this.SaveDungeonErrorReport("Dungeon lobby error: " err.Message "; stage=" this.stage "; " (this.HasOwnProp("lastDungeonObservation") ? this.lastDungeonObservation : "No completed scan received"))
this.Finish("Lobby needs attention")
}
}
} finally {
this.busy := false
if this.closed
this.Release()
}
}
SaveDungeonErrorReport(message) => AADungeons.SaveErrorReport(this,message)
Handle(result) {
kind := result["kind"]
if this.model.HasOwnProp("preferences") && this.model.preferences.Get("Mode","") = "Dungeons"
this.lastDungeonObservation := AADungeons.Diagnostic(result)
if kind = "daily-login-reward" {
if this.stage = "TeamSwap"
this.teamPhase := "units", this.teamLoaded := false
this.ClickAt(400,392)
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
this.deadline += Max(1000,Integer(this.model.preferences["StageClickDelay"]))
this.scanned := 0
if this.stage = "AwaitRejoin"
this.departed := true, this.lobbyConfirmations := 0
this.Log("Claiming daily reward")
return
}
if this.stage = "DungeonLaunch" && SubStr(kind,1,8) = "dungeon-" {
owner := this.owner, model := this.model
this.Finish("Reading Dungeon")
AAExecution.StartMatch(owner,model)
return
}
if this.stage = "AwaitMansionMap" && kind = "mansion-map" {
name := result["map"]
if this.HasOwnProp("mansionMapCandidate") && this.mansionMapCandidate = name
this.mansionMapFrames++
else this.mansionMapCandidate := name, this.mansionMapFrames := 1
if this.mansionMapFrames >= 2 {
this.LoadMansionMap(name)
this.stage := "MansionDifficultyClick"
this.WaitForClick()
}
return
}
if this.stage = "AwaitMansionMap" && kind = "none"
this.mansionMapFrames := 0
if kind = "leaderboard" {
if this.stage = "TeamSwap"
this.teamPhase := "units", this.teamLoaded := false
if !AALeaderboard.Close(this.hwnd,ObjBindMethod(this,"CheckClient"))
throw Error("Leaderboard could not be closed. Close it and resume the macro.")
this.due := Adventures.Tick()+250
this.deadline += 250
this.scanned := 0
return
}
if kind = "access-denied"
throw Error(result.Get("text","Roblox needs attention. Check access and account status."))
if kind = "rejoin" {
if this.stage = "RecoveryWait"
return
if this.HasOwnProp("lastRecoveryLaunch") && Adventures.Tick()-this.lastRecoveryLaunch < 15000
return
url := AAServer.Url(this.model.preferences)
if url = "" && result.Get("forcePublic",false)
url := CrusadersServer.JoinUrl("")
attempts := this.HasOwnProp("joinAttempts") ? this.joinAttempts : 0
if url = "" || attempts >= 5
throw Error("Could not join the server. Check your connection and server settings.")
this.joinAttempts := attempts+1
this.teamDone := false, this.teamPhase := "units", this.teamLoaded := false
this.stage := "RecoveryWait", this.cleaned := false, this.recoveryUrl := url
this.rejoinStarted := Adventures.Tick(), this.departed := false
this.originalHwnd := this.hwnd, this.lobbyConfirmations := 0
this.due := Adventures.Tick()+Min(60000,3000*2**attempts), this.deadline := this.due+AALobbyFlow.JoinTimeout
this.Log("Reconnecting to Roblox")
return
}
if this.stage = "TeamSwap" {
this.TeamSwap(result)
return
}
if this.stage = "ChallengePod" {
if kind = "challenge-map" {
name := result["map"]
if this.HasOwnProp("challengeMap") && this.challengeMap = name
this.challengeMapFrames++
else this.challengeMap := name, this.challengeMapFrames := 1
if this.challengeMapFrames >= 2 && (!this.challengeLoaded || this.model.preferences["Map"] != name) {
try {
path := AASession.Prototype.DetectedMapPath.Call(this,"Challenges",name)
candidate := CrusadersSelector(path,"",this.model.settingsFile,this.model.imageRoot)
candidate.preferences["Act"] := "1"
AASession.Prototype.CheckDetectedMapIndexes.Call(this,candidate,"Challenges",name)
this.owner.LoadEditor(candidate)
this.model := candidate, this.challengeLoaded := true
SplitPath(path,&filename)
this.Log("Map Detected: Loading " filename)
} catch Error as err {
AAChallenges.Skip(this.owner,"Challenge config for " name " needs setup (configure enabled indexes before Auto Challenge): " err.Message)
this.Finish("Returning to mode queue")
}
}
} else if kind = "vote" {
this.challengeStartFrames := 0
this.challengeMapFrames := 0
owner := this.owner, model := this.model
if !this.challengeLoaded {
if !this.HasOwnProp("challengeWaitingLogged") || !this.challengeWaitingLogged {
this.challengeWaitingLogged := true
this.Log("Challenge vote appeared before map confirmation; waiting within entry timeout")
}
return
}
this.Finish("Loading challenge")
AAExecution.StartMatch(owner,model)
} else {
this.challengeMapFrames := 0, this.challengeStartFrames := 0
}
return
}
if this.stage = "AwaitRejoin" {
if kind != "lobby" {
this.departed := true
this.lobbyConfirmations := 0
} else if this.departed && Adventures.Tick()-this.rejoinStarted >= 10000 {
this.lobbyConfirmations++
if this.lobbyConfirmations >= 2 {
this.joinAttempts := 0, this.deadline := Adventures.Tick()+120000
this.MoveLeft()
this.stage := "AwaitLobby"
this.Log("Lobby ready")
}
}
return
}
if this.stage = "AwaitLobby" {
if kind = "teams-menu" || kind = "units-menu" {
this.ClickAt(kind = "teams-menu" ? 610 : 662,kind = "teams-menu" ? 124 : 204)
this.due := Adventures.Tick()+250
return
}
if kind = "lobby" {
if !this.cleaned {
this.ClickAt(3,3), this.cleaned := true
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
return
}
if !this.teamDone && AADungeons.Team(this.model) > 0 {
this.stage := "TeamSwap", this.teamPhase := "units", this.teamLoaded := false
this.deadline := Adventures.Tick()+90000
this.teamMinSerial := this.worker ? this.worker.serial : 0
this.Log("Loading config team " AADungeons.Team(this.model))
this.TeamSwap(result)
return
}
if this.model.preferences["Mode"] = "Dungeons" {
this.ClickAt(86,405)
this.stage := "DungeonLaunch", this.deadline := Adventures.Tick()+45000
this.due := Adventures.Tick()+750, this.scanned := 0
this.Log("Opening Dungeons; automatically entering a new run or resuming the route board")
return
}
if this.model.preferences.Get("Mode","") = "Events" {
point := AAStoryRoute.PlayPosition
this.ClickAt(point[1],point[2])
this.stage := "PathDelay", this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["PathingDelay"]))
this.deadline := this.due+15000
this.Log("Going to April Fools")
return
}
if this.model.preferences["Mode"] = "Portals" {
AAPortalRoute.ValidateName(this.model.preferences["PortalName"])
point := AAPortalRoute.ItemsPosition
this.ClickAt(point[1],point[2])
this.stage := "PortalTabClick"
this.WaitForClick()
this.Log("Opening Items")
return
}
if this.model.preferences["Mode"] = "Story" || this.model.preferences["Mode"] = "Infinite" || this.model.preferences["Mode"] = "Legend Stages" {
point := AAStoryRoute.PlayPosition
this.ClickAt(point[1],point[2])
this.stage := "PathDelay"
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["PathingDelay"]))
this.deadline := this.due+15000
this.Log("Going to Story")
return
}
if this.model.preferences["Mode"] != "Raids" && this.model.preferences["Mode"] != "Infinity Mansion" && this.model.preferences["Mode"] != "Challenges"
throw Error("Lobby reached. This mode's entry route has not been calibrated yet.")
this.ClickAt(766,490)
this.areasClickedAt := Adventures.Tick(), this.areasAttempts := 1
this.stage := "AwaitAreas", this.deadline := Adventures.Tick()+20000
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
this.Log("Opening Areas")
} else if kind = "raids-menu" {
this.stage := "AwaitAreas"
this.Handle(result)
}
} else if this.stage = "AwaitAreas" {
if kind = "raids-menu" {
mansion := this.model.preferences["Mode"] = "Infinity Mansion"
point := this.model.preferences["Mode"] = "Challenges" ? [302,417] : mansion ? AAMansionRoute.TeleportPosition : [496,417]
this.ClickAt(point[1],point[2])
this.stage := "AwaitRaidsTransition", this.deadline := Adventures.Tick()+30000
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"])), this.absent := 0
this.Log(this.model.preferences["Mode"] = "Challenges" ? "Going to Challenges" : mansion ? "Going to Infinity Mansion" : "Going to Raids")
} else if kind = "lobby" && Adventures.Tick()-this.areasClickedAt >= 2500 && this.areasAttempts < 3 {
this.ClickAt(766,490)
this.areasAttempts++
this.areasClickedAt := Adventures.Tick()
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
}
} else if this.stage = "AwaitRaidsTransition" {
if kind != "raids-menu" && kind != "areas-menu" {
this.absent++
if this.absent >= 2 {
this.stage := "PathDelay"
this.due := Adventures.Tick()+Integer(this.model.preferences["PathingDelay"])
this.deadline := this.due+15000
this.Log("Waiting " this.model.preferences["PathingDelay"] "ms before pathing")
}
} else this.absent := 0
}
}
TeamWait(ms := 300) {
this.due := Adventures.Tick()+ms
this.teamMinSerial := this.worker.serial+1
}
TeamWheel(direction,count) {
this.CheckClient()
WinGetClientPos(&left,&top,,,this.hwnd)
previous := A_CoordModeMouse
CoordMode("Mouse","Screen")
try {
MouseMove(left+410,top+300,2)
loop count {
if this.closed || this.status != "Running" {
this.teamPhase := "units"
return false
}
AAInput.Check(ObjBindMethod(this,"CheckClient"))
SendEvent("{Wheel" direction "}")
if A_Index < count
Sleep(150)
}
} catch Error as err {
this.teamPhase := "units"
throw err
} finally CoordMode("Mouse",previous)
return true
}
TeamSwap(result) {
if this.closed || this.status != "Running" || Adventures.Tick() < this.due || this.worker.serial < this.teamMinSerial
return
kind := result["kind"], team := AADungeons.Team(this.model)
if team < 1 || team > 6 {
this.teamDone := true, this.stage := "AwaitLobby"
return
}
if kind = "teams-menu" {
if this.teamPhase = "close-units" || this.teamPhase = "done" {
this.ClickAt(610,124), this.TeamWait()
return
}
if this.teamPhase = "units" || this.teamPhase = "teams" {
if !this.TeamWheel("Up",8)
return
this.teamPhase := "scroll", this.TeamWait()
return
}
if this.teamPhase = "scroll" {
scrolls := team <= 3 ? 0 : team = 4 ? 1 : 2
if scrolls && !this.TeamWheel("Down",scrolls)
return
this.teamPhase := "load", this.TeamWait()
return
}
if this.teamPhase = "load" {
rows := Map(1,233,2,319,3,406,4,392,5,377,6,463)
this.ClickAt(567,rows[team])
this.teamLoaded := true, this.teamPhase := "close-teams"
this.TeamWait(500)
return
}
if this.teamPhase = "close-teams" {
this.ClickAt(610,124)
this.teamPhase := "close-units", this.TeamWait()
return
}
} else if kind = "units-menu" {
if this.teamLoaded {
this.ClickAt(662,204)
this.teamPhase := "done", this.TeamWait()
} else {
this.ClickAt(400,224)
this.teamPhase := "teams", this.TeamWait()
}
} else if kind = "lobby" {
if this.teamLoaded {
this.teamDone := true, this.stage := "AwaitLobby"
this.Log("Config team " team " load clicked; menus closed")
this.Handle(result)
} else {
this.ClickAt(35,244)
this.teamPhase := "units", this.TeamWait()
}
}
}
PlayApproach() {
if this.model.preferences.Get("Mode","") = "Events" {
this.Log("Walking to April Fools pod")
if !this.owner.inputRecorder.Play(AAAprilFools.Approach(),(*)=>this.closed,(*)=>this.FocusValid())
throw Error("April Fools lobby path stopped before completion.")
if this.closed
return
this.stage := "AprilPlayHere", this.deadline := Adventures.Tick()+30000
this.due := Adventures.Tick()+500
return
}
if this.model.preferences["Mode"] = "Challenges" {
daily := AAChallenges.kind = "Daily"
route := daily ? AADailyRoute.Approach() : AAHalfHourlyRoute.Approach()
if !this.owner.inputRecorder.Play(route,(*)=>this.closed,(*)=>this.FocusValid())
throw Error("Challenge lobby path stopped before completion.")
if this.closed
return
this.stage := "DailyPlayHereClick"
this.WaitForClick()
this.due += 1000, this.deadline += 1000
this.Log(daily ? "Opening daily challenge" : "Opening half-hourly challenge")
return
}
story := this.model.preferences["Mode"] = "Story" || this.model.preferences["Mode"] = "Infinite" || this.model.preferences["Mode"] = "Legend Stages"
mansion := this.model.preferences["Mode"] = "Infinity Mansion"
data := mansion ? AAMansionRoute.Approach() : story ? AAStoryRoute.Approach() : AALobbyFlow.Approach()
this.Log(mansion ? "Walking to Mansion" : story ? "Walking to Story pod" : "Walking to raid pod")
if !this.owner.inputRecorder.Play(data,(*)=>this.closed,(*)=>this.FocusValid())
throw Error("Lobby path stopped before completion.")
if this.closed
return
if mansion {
this.stage := "AwaitMansionMap", this.deadline := Adventures.Tick()+30000
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
this.scanned := 0
this.Log("Reading Mansion map")
return
}
this.stage := this.model.preferences["Mode"] = "Legend Stages" ? "LegendButtonClick" : "MapClick"
this.WaitForClick()
this.Log(story ? "Selecting Story map" : "Selecting raid")
}
PortalSelection() {
stage := this.stage
if stage = "PortalSearchType" {
if !this.TypePortalSearch(AAPortalRoute.ValidateName(this.model.preferences["PortalName"]))
return
this.Log("Searching for " this.model.preferences["PortalName"])
} else {
point := AAPortalRoute.Steps[stage]
this.ClickAt(point[1],point[2])
labels := Map("PortalTabClick","Opening Portals","PortalSearchClick","Selecting portal search",
"PortalFirstClick","Selecting first portal","PortalUseClick","Using portal",
"PortalOpenClick","Opening portal","PortalStartClick","Joining portal match")
this.Log(labels[stage])
}
this.stage := AAPortalRoute.Next[stage]
this.WaitForClick()
if stage = "PortalOpenClick" || stage = "PortalStartClick" {
this.due += 1000, this.deadline += 1000
}
}
TypePortalSearch(name) {
if this.closed || this.status != "Running"
return false
this.CheckClient()
SendEvent("^a")
Sleep(100)
if this.closed || this.status != "Running"
return false
this.CheckClient()
SendText(name)
return !this.closed && this.status = "Running"
}
BeginChallengePod() {
this.stage := "ChallengeStartClick", this.deadline := Adventures.Tick()+150000
this.due := Adventures.Tick()+1500
this.scanned := 0, this.challengeLoaded := false, this.challengeMapFrames := 0, this.challengeRead := 0
this.challengeStartFrames := 0, this.challengeStartAt := 0
this.Log("Waiting for challenge map")
}
WaitForClick() {
this.due := Adventures.Tick()+Max(1000,Integer(this.model.preferences["StageClickDelay"]))
this.deadline := this.due+30000
}
LoadMansionMap(name) {
path := AASession.Prototype.DetectedMapPath.Call(this,"Infinity Mansion",name)
candidate := CrusadersSelector(path,"",this.model.settingsFile,this.model.imageRoot)
candidate.preferences["Runs"] := this.model.preferences["Runs"]
candidate.preferences["Difficulty"] := this.model.preferences.Get("Difficulty","Normal")
AASession.Prototype.CheckDetectedMapIndexes.Call(this,candidate,"Infinity Mansion",name)
this.owner.LoadEditor(candidate)
this.model := candidate
this.owner.LoadFields()
this.owner.UpdateStats()
SplitPath(path,&filename)
this.Log("Map Detected: Loading " filename)
}
ScrollStoryMaps(notches,x := 700,y := 350) {
this.CheckClient()
WinGetClientPos(&left,&top,,,this.hwnd)
previousMode := A_CoordModeMouse, previousSend := A_SendMode
CoordMode("Mouse","Screen"), SendMode("Event")
try {
MouseMove(left+x,top+y,2)
Sleep(200)
Loop notches {
this.CheckClient()
SendEvent("{WheelDown}")
Sleep(250)
}
} finally {
SendMode(previousSend)
CoordMode("Mouse",previousMode)
}
}
TimedSelection() {
if this.model.preferences.Get("Mode","") = "Events" {
this.stage := "AprilPlayHere", this.scanned := 0
this.due := Adventures.Tick(), this.deadline := Adventures.Tick()+30000
return
}
if this.stage = "DailyPlayHereClick" {
point := AADailyRoute.PlayHerePosition
this.ClickAt(point[1],point[2])
this.BeginChallengePod()
return
} else if this.stage = "LegendButtonClick" {
point := AALegendRoute.ButtonPosition
this.ClickAt(point[1],point[2])
this.stage := "MapClick"
this.Log("Opening Legend Stages")
} else if this.stage = "MansionDifficultyClick" {
hard := this.model.preferences.Get("Difficulty","Normal") = "Hard"
this.ClickAt(hard ? 487 : 419,382)
this.stage := "MansionStartClick"
this.Log("Infinity Mansion difficulty: " (hard ? "Hard" : "Normal"))
} else if this.stage = "MansionStartClick" {
point := AAMansionRoute.StartPosition
this.ClickAt(point[1],point[2])
this.stage := "MansionPlayHereClick"
this.due := Adventures.Tick()+2000,this.deadline := this.due+30000
this.Log("Infinity Mansion: waiting 2 seconds before Play Here")
return
} else if this.stage = "MansionPlayHereClick" {
if Adventures.Tick()<this.due
return
point := AALobbyFlow.PlayHerePosition
this.ClickAt(point[1],point[2])
this.stage := "EnterMatch"
this.Log("Infinity Mansion: Play Here clicked; joining match")
} else if this.stage = "MapClick" {
name := this.model.preferences["Map"]
if this.model.preferences.Get("Mode","Raids") = "Legend Stages" {
if !AALegendRoute.Maps.Has(name)
throw Error("This Legend map has not been captured yet: " name)
point := AALegendRoute.Maps[name]
if point[3] > 0 && !this.HasOwnProp("legendScrollDone") {
this.ScrollStoryMaps(point[3])
this.legendScrollDone := true
this.WaitForClick()
return
}
this.ClickAt(point[1],point[2])
} else if this.model.preferences.Get("Mode","Raids") = "Story" || this.model.preferences.Get("Mode","Raids") = "Infinite" {
position := AAStoryRoute.Position(name)
if position.scroll > 0 && !this.HasOwnProp("storyScrollDone") {
this.ScrollStoryMaps(position.scroll)
this.storyScrollDone := true
this.WaitForClick()
return
}
this.ClickAt(position.x,position.y)
} else {
if !AALobbyFlow.Maps.Has(name)
throw Error("This raid's map position has not been calibrated yet: " name)
point := AALobbyFlow.Maps[name]
if point[3] > 0 && !this.HasOwnProp("raidScrollDone") {
this.ScrollStoryMaps(point[3])
this.raidScrollDone := true
this.WaitForClick()
return
}
this.ClickAt(point[1],point[2])
}
this.stage := "ActClick"
if this.model.preferences.Get("Mode","Raids") = "Raids" && CrusadersCatalog.ActCount("Raids",name) = 1
this.stage := "SelectClick"
} else if this.stage = "ActClick" || this.stage = "ActConfirmClick" {
if this.model.preferences.Get("Mode","Raids") = "Legend Stages" {
act := Integer(this.model.preferences["Act"])
if act < 1 || act > AALegendRoute.Acts.Length
throw Error("Legend act " act " needs its scrolled button position captured first.")
if act = 6 && !this.HasOwnProp("legendActScrollDone") {
this.ScrollStoryMaps(1,288,330)
this.legendActScrollDone := true
this.WaitForClick()
return
}
point := this.model.preferences["Map"] = "Ruined City [Midnight]" ? AALegendRoute.RuinedCityActs[act] : AALegendRoute.Acts[act]
this.ClickAt(point[1],point[2])
this.stage := "SelectClick"
this.WaitForClick()
return
}
if this.model.preferences.Get("Mode","Raids") = "Story" || this.model.preferences.Get("Mode","Raids") = "Infinite" {
position := this.model.preferences["Mode"] = "Infinite" ? AAStoryRoute.InfinitePosition : AAStoryRoute.Acts[Integer(this.model.preferences["Act"])]
if position.scroll > 0 && !this.HasOwnProp("storyActScrollDone") {
this.ScrollStoryMaps(position.scroll,288,330)
this.storyActScrollDone := true
this.WaitForClick()
return
}
this.ClickAt(position.x,position.y)
this.stage := this.model.preferences["Mode"] = "Story" ? "DifficultyClick" : "SelectClick"
this.WaitForClick()
return
}
act := Integer(this.model.preferences["Act"])
if act < 1 || act > AALobbyFlow.Acts.Length
throw Error("Raid act must be between 1 and 5.")
point := AALobbyFlow.Acts[act]
this.ClickAt(point[1],point[2])
this.stage := this.stage = "ActClick" ? "ActConfirmClick" : "SelectClick"
} else if this.stage = "DifficultyClick" {
difficulty := this.model.preferences.Get("Difficulty","Normal")
if !AAStoryRoute.Difficulties.Has(difficulty)
throw Error("Story difficulty must be Normal or Hard.")
point := AAStoryRoute.Difficulties[difficulty]
this.ClickAt(point[1],point[2])
this.stage := "SelectClick"
} else if this.stage = "SelectClick" {
point := AALobbyFlow.SelectPosition
this.ClickAt(point[1],point[2])
this.stage := "PlayHereClick"
this.Log("Stage selected")
} else if this.stage = "PlayHereClick" {
point := AALobbyFlow.PlayHerePosition
this.ClickAt(point[1],point[2])
this.stage := "StartClick"
this.Log("Preparing match")
this.WaitForClick()
this.due += 1000
this.deadline += 1000
return
} else if this.stage = "StartClick" {
point := AALobbyFlow.StartPosition
this.ClickAt(point[1],point[2])
this.stage := "EnterMatch"
this.Log("Joining match")
} else {
owner := this.owner, model := this.model
this.Finish("Loading match")
AAExecution.StartMatch(owner,model)
return
}
this.WaitForClick()
}
BeginAprilPopOut() {
this.aprilPoppedOut := true
this.owner.aprilDetached := true
this.owner.SetGameFrame(this.hwnd,false)
DllCall("SetWindowRgn","Ptr",this.hwnd,"Ptr",0,"Int",true)
if WinGetMinMax(this.hwnd) = -1
WinRestore(this.hwnd)
WinShow(this.hwnd)
DllCall("SetWindowPos","Ptr",this.hwnd,"Ptr",0,"Int",0,"Int",0,"Int",0,"Int",0,"UInt",0x43)
WinActivate(this.hwnd)
this.stage := "AprilHoldPrepare", this.due := Adventures.Tick()+350
}
static MinimizePoint(hwnd) {
AADisplay.UsePhysicalPixels()
info := Buffer(140,0)
NumPut("UInt",140,info)
SendMessage(0x33F,0,info.Ptr,,hwnd)
left := NumGet(info,76,"Int"), top := NumGet(info,80,"Int")
right := NumGet(info,84,"Int"), bottom := NumGet(info,88,"Int")
if right > left && bottom > top
return [(left+right)//2,(top+bottom)//2]
WinGetPos(&wx,&wy,&ww,&wh,hwnd)
loop 7 {
y := wy+4+(A_Index-1)*5
loop 45 {
x := wx+ww-5-(A_Index-1)*4
packed := (x & 0xFFFF) | ((y & 0xFFFF)<<16)
if SendMessage(0x84,0,packed,,hwnd) = 8
return [x,y]
}
}
throw Error("Roblox minimize button was not found after popping out.")
}
SuspendAprilHold() {
if this.HasOwnProp("rightHeld") && this.rightHeld {
SendEvent("{RButton up}")
this.rightHeld := false
DllCall("PostMessageW","Ptr",this.hwnd,"UInt",0x001F,"Ptr",0,"Ptr",0)
}
this.stage := "AprilHoldPrepare", this.due := Adventures.Tick()+350
this.Log("April Fools | Focus changed; restarting the hold once Roblox is active")
}
BeginAprilMinimizeHold() {
WinActivate(this.hwnd)
if !WinWaitActive(this.hwnd,,2)
throw Error("Roblox did not activate for the two-minute minimize hold.")
point := AALobbyFlow.MinimizePoint(this.hwnd)
previousMode := A_CoordModeMouse
CoordMode("Mouse","Screen")
try MouseMove(point[1],point[2],0)
finally CoordMode("Mouse",previousMode)
this.rightHeld := true
SendEvent("{RButton down}")
this.holdUntil := Adventures.Tick()+120000
this.stage := "AprilMinimizeHold"
this.Log("April Fools: Waiting 120 seconds. The macro is still running; Roblox will return automatically.")
}
RestoreAprilWindow() {
if !this.HasOwnProp("aprilPoppedOut") || !this.aprilPoppedOut
return
this.owner.aprilDetached := false
WinRestore(this.owner.gui)
if !this.owner.ShowGame()
throw Error("Roblox could not be restored to the macro after the April Fools hold.")
this.aprilPoppedOut := false
}
FocusValid() {
try {
this.CheckClient()
return true
} catch Error {
return false
}
}
Pause() {
if this.closed || !IsObject(this.owner)
return
owner := this.owner
this.status := this.status = "Paused" ? "Running" : "Paused"
if this.status = "Paused" {
this.pausedAt := Adventures.Tick()
CrusadersRuntime.SetPaused(true)
} else {
owner.ShowGame()
elapsed := Adventures.Tick()-this.pausedAt
this.deadline += elapsed, this.due += elapsed
CrusadersRuntime.SetPaused(false)
}
owner.runStatus := this.status
owner.PushState()
}
Finish(message) {
global testRunning
if this.closed || !IsObject(this.owner)
return
owner := this.owner
if this.HasOwnProp("rightHeld") && this.rightHeld {
SendEvent("{RButton up}")
this.rightHeld := false
}
this.RestoreAprilWindow()
if this.closed
return
this.closed := true
SetTimer(this.timer,0)
if this.worker
this.worker.Dispose(), this.worker := 0
testRunning := false
owner.runStatus := message, owner.startConsumed := false
owner.PushState()
if !this.busy
this.Release()
}
Dispose() => this.Finish("Stopped")
Release() {
this.timer := 0, this.core := 0, this.model := 0, this.owner := 0
}
}
class AARaidPaths {
static StrangeTown() => AADefaultPaths.Get("Strange Town")
}
class AAStoryRoute {
static Difficulties := Map("Normal",[420,371],"Hard",[486,371])
static InfinitePosition := {x:288,y:239,scroll:0}
static Acts := Map(1,{x:288,y:274,scroll:0},2,{x:288,y:308,scroll:0},
3,{x:288,y:341,scroll:0},4,{x:288,y:375,scroll:0},
5,{x:288,y:349,scroll:1},6,{x:288,y:383,scroll:1})
static SelectPosition := [400,438]
static Maps := Map("Planet Greenie",{x:696,y:249,scroll:0},
"Walled City",{x:696,y:303,scroll:0},"Snowy Town",{x:696,y:357,scroll:0},
"Sand Village",{x:696,y:411,scroll:0},"Navy Bay",{x:696,y:363,scroll:1},
"Fiend City",{x:696,y:416,scroll:1},"Spirit World",{x:696,y:369,scroll:2},
"Ant Kingdom",{x:696,y:422,scroll:2},"Magic Town",{x:696,y:375,scroll:3},
"Haunted Academy",{x:696,y:428,scroll:3},"Magic Hills",{x:696,y:381,scroll:4},
"Space Center",{x:696,y:434,scroll:4},"Alien Spaceship",{x:696,y:388,scroll:5},
"Fabled Kingdom",{x:696,y:435,scroll:5},"Ruined City",{x:696,y:395,scroll:6},
"Puppet Island",{x:696,y:440,scroll:6},"Virtual Dungeon",{x:696,y:402,scroll:7},
"Snowy Kingdom",{x:696,y:355,scroll:8},"Dungeon Throne",{x:696,y:408,scroll:8},
"Mountain Temple",{x:696,y:362,scroll:9},"Rain Village",{x:696,y:415,scroll:9},
"Shibuya District",{x:696,y:379,scroll:10})
static PlayPosition := [86,302]
static Approach() {
raw := '{"duration":6174,"events":[{"action":"keyDown","at":706,"key":"d"},{"action":"keyDown","at":734,"key":"w"},{"action":"keyUp","at":3326,"key":"d"},{"action":"keyUp","at":5505,"key":"w"}],"height":600,"version":1,"width":800}'
return CrusadersRecording.Validate(Jxon_Load(&raw))
}
static Position(name) {
if !this.Maps.Has(name)
throw Error("This Story map has not been captured yet: " name)
return this.Maps[name]
}
}
class AAHalfHourlyRoute {
static Approach() {
return CrusadersRecording.Validate(Map("version",1,"width",800,"height",600,"duration",5137,
"events",[Map("action","keyDown","at",588,"key","a"),Map("action","keyUp","at",4691,"key","a")]))
}
}
class AAChallengeDetection {
static PodMapRegion := [20,225,200,80]
static LoadingMapRegion := [10,40,780,180]
static ParseMap(text) {
name := AAMansionRoute.MatchMap(text,CrusadersCatalog.Maps["Challenges"])
act := RegExMatch(text,"i)\bAct\s*([1-6])\b",&match) ? Integer(match[1]) : 0
return Map("kind",name != "" ? "challenge-map" : "none","map",name,
"config",name != "" ? StrReplace(name," ","") "Challenge.txt" : "","act",act,"text",text,"ownerWait",0)
}
static ReadPodMap(reader,bitmap) {
r := this.PodMapRegion
scan := this.ParseMap(reader.Read(bitmap,r[1],r[2],r[3],r[4],3))
scan["lobbyStart"] := false
if scan["kind"]="challenge-map" {
start := StrLower(Trim(reader.Read(bitmap,315,437,170,53,3)))
cancel := StrLower(Trim(reader.Read(bitmap,340,505,125,40,3)))
green := Gdip_GetPixel(bitmap,330,450), red := Gdip_GetPixel(bitmap,350,515)
if RegExMatch(start,"^start[.!]?$" ) && RegExMatch(cancel,"^cancel[.!]?$" )
&& ((green>>8)&255)>130 && ((green>>16)&255)<100 && (green&255)<100
&& ((red>>16)&255)>130 && ((red>>8)&255)<100 && (red&255)<100
scan["lobbyStart"] := true
}
return scan
}
static ReadLoadingMap(reader,bitmap) {
scan := AATransitionVision.Read(reader,bitmap,CrusadersCatalog.Maps["Challenges"])
if scan["kind"] != "none" && (scan["context"] = "stage" || scan["context"] = "challenge") {
scan["kind"] := "challenge-map"
scan["config"] := CrusadersCatalog.Filename("Challenges",scan["map"],1)
return scan
}
r := this.LoadingMapRegion
text := reader.Read(bitmap,r[1],r[2],r[3],r[4],2)
if RegExMatch(text,"i)Contract|Dungeon\s*Room") || !RegExMatch(text,"i)Travell?ing\s+to|Challenge")
return Map("kind","none","map","","config","","act",0,"text",text,"ownerWait",0)
return this.ParseMap(text)
}
}
class AADailyRoute {
static PlayHerePosition := [335,326]
static Approach() {
return CrusadersRecording.Validate(Map("version",1,"width",800,"height",600,"duration",4459,
"events",[Map("action","keyDown","at",780,"key","s"),Map("action","keyDown","at",786,"key","a"),Map("action","keyUp","at",4023,"key","a"),Map("action","keyUp","at",4031,"key","s")]))
}
}
class AAPortalReplay {
static Read(reader,bitmap) {
choice := StoryVision.Parse("choice",reader.Read(bitmap,130,80,545,110,2))
inventory := StrLower(RegExReplace(reader.Read(bitmap,150,170,480,75,2),"[^A-Za-z]",""))
prompt := StrLower(RegExReplace(reader.Read(bitmap,170,435,470,55,2),"[^A-Za-z]",""))
tooltip := StrLower(RegExReplace(reader.Read(bitmap,260,402,175,45,2),"[^A-Za-z]",""))
if InStr(tooltip,"select") && (InStr(inventory,"youritems") || InStr(inventory,"portal"))
return Map("kind","portal-select","text",tooltip)
if InStr(inventory,"youritems") && InStr(prompt,"selectaportal")
return Map("kind","portal-picker","text",prompt)
if choice["kind"] = "choice"
return choice
vote := StoryVision.Parse("vote",reader.Read(bitmap,290,25,230,125,2))
return vote
}
static TypeName(runner,name) {
if runner.app.status != "Running"
return false
runner.app.CheckClient()
SendEvent("^a")
Sleep(100)
if runner.app.status != "Running"
return false
runner.app.CheckClient()
SendText(AAPortalRoute.ValidateName(name))
return runner.app.status = "Running"
}
static Tick(runner) {
now := Adventures.Tick()
if now < runner.due
return
if runner.stage = "PortalReplaySearch" {
if !this.TypeName(runner,runner.app.nextTask.portalName)
return
runner.Change("PortalReplayFirst",120000)
runner.due := Adventures.Tick()+Max(1000,runner.Delay("StageClickDelay",1000))
return
}
if runner.stage = "PortalReplayFirst" {
runner.ClickAt(216,287)
runner.Change("PortalReplaySelect",120000)
runner.due := Adventures.Tick()+Max(750,runner.Delay("StageClickDelay",1000))
return
}
scan := runner.worker.Poll()
if scan {
kind := scan["kind"]
if kind = "rejoin" || kind = "access-denied" || kind = "leaderboard" {
runner.Handle(scan)
return
}
if runner.stage = "PortalReplayPicker" {
if kind = "portal-picker" {
runner.ClickAt(510,190)
runner.Change("PortalReplaySearch",120000)
runner.due := Adventures.Tick()+250
return
}
if kind = "choice" && now-runner.lastClick >= 1500 {
runner.ClickAt(488,121), runner.lastClick := Adventures.Tick()
}
} else if runner.stage = "PortalReplaySelect" && kind = "portal-select" {
runner.ClickAt(349,427)
runner.Change("PortalReplayLoading",120000)
runner.due := Adventures.Tick()+1000
runner.app.Log("Loading next portal")
return
} else if runner.stage = "PortalReplayLoading" {
if kind = "vote" {
runner.app.Advanced()
runner.app.completed++
runner.defeated := false
runner.Change("AwaitVote",120000)
runner.Handle(scan)
return
}
if kind = "portal-select" && now-runner.lastClick >= 2000 {
runner.ClickAt(349,427), runner.lastClick := Adventures.Tick()
}
}
}
if now-runner.scanned >= 300 {
runner.worker.Request("portal-picker")
runner.scanned := now
}
}
}
class AADefaultPaths {
static Routes := Map("Spirit Town",Map("duration",6743,"events",[Map("action","keyDown","at",888,"key","s"),Map("action","keyUp","at",3488,"key","s"),Map("action","keyDown","at",3672,"key","a"),Map("action","keyUp","at",6001,"key","a")],"height",600,"version",1,"width",800),"Ant Kingdom",Map("duration",14119,"events",[Map("action","keyDown","at",808,"key","s"),Map("action","keyUp","at",1256,"key","s"),Map("action","keyDown","at",1576,"key","a"),Map("action","keyUp","at",2543,"key","a"),Map("action","keyDown","at",2728,"key","s"),Map("action","keyDown","at",3304,"key","a"),Map("action","keyUp","at",4544,"key","a"),Map("action","keyDown","at",4792,"key","a"),Map("action","keyUp","at",5416,"key","a"),Map("action","keyDown","at",5616,"key","a"),Map("action","keyUp","at",5905,"key","a"),Map("action","keyDown","at",6336,"key","a"),Map("action","keyUp","at",7232,"key","s"),Map("action","keyDown","at",9144,"key","w"),Map("action","keyUp","at",9640,"key","a"),Map("action","keyDown","at",10152,"key","a"),Map("action","keyUp","at",10712,"key","w"),Map("action","keyDown","at",11177,"key","w"),Map("action","keyUp","at",11256,"key","a"),Map("action","keyUp","at",12609,"key","w")],"height",600,"version",1,"width",800),
"Fabled Kingdom",Map("duration",12912,"events",[Map("action","keyDown","at",628,"key","s"),Map("action","keyUp","at",1157,"key","s"),Map("action","keyDown","at",1424,"key","a"),Map("action","keyUp","at",2384,"key","a"),Map("action","keyDown","at",2612,"key","s"),Map("action","keyUp","at",2768,"key","s"),Map("action","keyDown","at",2952,"key","a"),Map("action","keyUp","at",4344,"key","a"),Map("action","keyDown","at",4520,"key","s"),Map("action","keyUp","at",7568,"key","s"),Map("action","keyDown","at",7912,"key","d"),Map("action","keyUp","at",8192,"key","d"),Map("action","keyDown","at",8304,"key","s"),Map("action","keyUp","at",8544,"key","s"),Map("action","keyDown","at",8672,"key","d"),Map("action","keyUp","at",9816,"key","d"),Map("action","keyDown","at",9960,"key","s"),Map("action","keyUp","at",11233,"key","s"),Map("action","keyDown","at",11384,"key","d"),Map("action","keyUp","at",12016,"key","d")],"height",600,"version",1,"width",800),
"Fiend City",Map("duration",11696,"events",[Map("action","keyDown","at",706,"key","s"),Map("action","keyUp","at",993,"key","s"),Map("action","keyDown","at",1681,"key","a"),Map("action","keyUp","at",5756,"key","a"),Map("action","keyDown","at",5977,"key","s"),Map("action","keyUp","at",8593,"key","s"),Map("action","keyDown","at",9289,"key","d"),Map("action","keyUp","at",10425,"key","d")],"height",600,"version",1,"width",800),
"Haunted Academy",Map("duration",7742,"events",[Map("action","keyDown","at",1190,"key","d"),Map("action","keyUp","at",6054,"key","d")],"height",600,"version",1,"width",800),
"Mountain Temple",Map("duration",4528,"events",[Map("action","keyDown","at",952,"key","s"),Map("action","keyUp","at",1736,"key","s"),Map("action","keyDown","at",1960,"key","a"),Map("action","keyUp","at",3536,"key","a")],"height",600,"version",1,"width",800),
"Sand Village",Map("duration",12200,"events",[Map("action","keyDown","at",1089,"key","s"),Map("action","keyUp","at",1633,"key","s"),Map("action","keyDown","at",2257,"key","d"),Map("action","keyDown","at",4217,"key","s"),Map("action","keyUp","at",5361,"key","d"),Map("action","keyUp","at",6864,"key","s"),Map("action","keyDown","at",7329,"key","a"),Map("action","keyDown","at",7625,"key","s"),Map("action","keyUp","at",8073,"key","s"),Map("action","keyDown","at",8841,"key","s"),Map("action","keyUp","at",9089,"key","s"),Map("action","keyUp","at",9793,"key","a"),Map("action","keyDown","at",10095,"key","s"),Map("action","keyUp","at",10833,"key","s")],"height",600,"version",1,"width",800),
"Snowy Kingdom",Map("duration",10186,"events",[Map("action","keyDown","at",1259,"key","w"),Map("action","keyDown","at",1763,"key","d"),Map("action","keyUp","at",2403,"key","d"),Map("action","keyDown","at",3443,"key","d"),Map("action","keyUp","at",4803,"key","w"),Map("action","keyDown","at",5907,"key","w"),Map("action","keyUp","at",6819,"key","d"),Map("action","keyUp","at",7859,"key","w"),Map("action","keyDown","at",8203,"key","a"),Map("action","keyUp","at",8555,"key","a")],"height",600,"version",1,"width",800),
"Space Center",Map("duration",9840,"events",[Map("action","keyDown","at",651,"key","w"),Map("action","keyUp","at",1200,"key","w"),Map("action","keyDown","at",1408,"key","a"),Map("action","keyUp","at",4593,"key","a"),Map("action","keyDown","at",4928,"key","s"),Map("action","keyUp","at",8008,"key","s")],"height",600,"version",1,"width",800),
"Spirit World",Map("duration",9204,"events",[Map("action","keyDown","at",536,"key","w"),Map("action","keyDown","at",1188,"key","d"),Map("action","keyUp","at",3776,"key","w"),Map("action","keyDown","at",5312,"key","w"),Map("action","keyUp","at",5952,"key","w"),Map("action","keyDown","at",6512,"key","w"),Map("action","keyUp","at",6544,"key","d"),Map("action","keyDown","at",6640,"key","d"),Map("action","keyUp","at",6960,"key","d"),Map("action","keyUp","at",7880,"key","w")],"height",600,"version",1,"width",800),
"Magic Town",Map("duration",11640,"events",[Map("action","keyDown","at",625,"key","d"),Map("action","keyUp","at",3267,"key","d"),Map("action","keyDown","at",3688,"key","s"),Map("action","keyUp","at",4849,"key","s"),Map("action","keyDown","at",5848,"key","d"),Map("action","keyUp","at",9601,"key","d")],"height",600,"version",1,"width",800),
"Magic Hills",Map("duration",24336,"events",[Map("action","keyDown","at",488,"key","a"),Map("action","keyDown","at",2408,"key","w"),Map("action","keyUp","at",3809,"key","w"),Map("action","keyDown","at",5009,"key","s"),Map("action","keyUp","at",5833,"key","s"),Map("action","keyDown","at",6272,"key","s"),Map("action","keyUp","at",6670,"key","s"),Map("action","keyDown","at",7121,"key","s"),Map("action","keyUp","at",8425,"key","s"),Map("action","keyDown","at",10408,"key","s"),Map("action","keyUp","at",10978,"key","a"),Map("action","keyDown","at",11800,"key","a"),Map("action","keyUp","at",12208,"key","s"),Map("action","keyDown","at",14112,"key","w"),Map("action","keyUp","at",14280,"key","w"),Map("action","keyDown","at",14632,"key","s"),Map("action","keyUp","at",14800,"key","s"),Map("action","keyDown","at",15112,"key","s"),Map("action","keyUp","at",15296,"key","s"),Map("action","keyDown","at",15825,"key","s"),Map("action","keyUp","at",16720,"key","s"),Map("action","keyDown","at",17929,"key","w"),Map("action","keyUp","at",19520,"key","w"),Map("action","keyDown","at",20032,"key","w"),Map("action","keyUp","at",20760,"key","w"),Map("action","keyDown","at",21137,"key","w"),Map("action","keyUp","at",22425,"key","a"),Map("action","keyUp","at",22464,"key","w")],"height",600,"version",1,"width",800),
"Snowy Town",Map("duration",6999,"events",[Map("action","keyDown","at",962,"key","d"),Map("action","keyUp","at",3784,"key","d"),Map("action","keyDown","at",4104,"key","w"),Map("action","keyUp","at",5608,"key","w")],"height",600,"version",1,"width",800),
"Nightmare Train",Map("duration",16374,"events",[Map("action","keyDown","at",1150,"key","a"),Map("action","keyDown","at",2125,"key","LShift"),Map("action","keyUp","at",4052,"key","LShift"),Map("action","keyDown","at",4717,"key","w"),Map("action","keyUp","at",7477,"key","w"),Map("action","keyDown","at",8040,"key","s"),Map("action","keyUp","at",9871,"key","a"),Map("action","keyDown","at",10306,"key","a"),Map("action","keyUp","at",11164,"key","a"),Map("action","keyDown","at",11695,"key","a"),Map("action","keyUp","at",12883,"key","s"),Map("action","keyUp","at",13026,"key","a")],"height",600,"version",1,"width",800),
"Future City",Map("duration",9420,"events",[Map("action","keyDown","at",828,"key","w"),Map("action","keyUp","at",4111,"key","w"),Map("action","keyDown","at",4234,"key","d"),Map("action","keyUp","at",4477,"key","d"),Map("action","keyDown","at",4554,"key","w"),Map("action","keyUp","at",6041,"key","w")],"height",600,"version",1,"width",800),
"Strange Town",Map("duration",4185,"events",[Map("action","keyDown","at",940,"key","d"),Map("action","keyDown","at",2597,"key","s"),Map("action","keyUp","at",2606,"key","d"),Map("action","keyUp","at",3138,"key","s")],"height",600,"version",1,"width",800))
static Aliases := Map("Magic Hills [Elf Invasion]","Magic Hills","Spirit Invasion","Spirit Town","Space Center","Space Center","Fabled Kingdom [Generals]","Fabled Kingdom","Ruined City [Midnight]","Ruined City","Virtual Dungeon [Bosses]","Virtual Dungeon","Dungeon Throne","Dungeon Throne","Rain Village","Rain Village","Ant Kingdom [Midnight]","Ant Kingdom","Ruined City [The Menace]","Ruined City","Future City [Tyrant's Invasion]","Future City")
static CanonicalName(name) => this.Aliases.Get(name,name)
static Has(name) => this.Routes.Has(this.CanonicalName(name))
static Get(name) => CrusadersRecording.Validate(this.Routes[this.CanonicalName(name)])
}
class AAInstalledAssets {
static Revision := "shared-maps-routes-refresh-2026-10-24"
static ExpectedHashes := Map("SpiritTown.png","401323dd0caa9db5198af51109861c3b13aa293bd06abee0e6839aec49866272","HauntedMansion.png","88944fc2f390cd225aa1b4681646458057091d28c98aeee19c4166ad6ef509a0","SkyAircraft.png","042c6195e78425f9bf7415685c808125ff924e9d67a55b9341e03199861211bc","HellishCity.png","f067b39afc42df2de0719d3fad058229d763a86a81a41ee3454b0fcf9eaaa185","AlienSpaceship.png","1def071289551780242ea5dcca568b5ca9eafaa75743100c644d0c2b83f08c4e","AntKingdom.png","88245e6868abf51e32385d968b4adb50cb1b30cbc116ae859af20bf29ffd99b1","DungeonThrone.png","c2f4a6e684ee7017dca29ba225eb24ed125f3d43bf384d34af7dc97e79a94781","FabledKingdom.png","085edff86f8b29fee3b8c2308d99edf413c3e23baf710cddfc5a259211e28622","FiendCity.png","c2cddd972851f4510370b6298a2ed0ee145dc0183d9b7f66afcf2ba2646df877","HauntedAcademy.png","f7c71d57a91727f56b1fccd03916dc23efc53c0d8a80156bafeacc0659c424fc","MagicTown.png","eca2eeddaf10ccb8c4c263c16d83ea20a48bdb28cc51baa1fd0a249b0e26ea3f","MountainTemple.png","34c597405bdd2a8ef700531242225ddbd78f7018568373bc87bf2bdeed699b03","NavyBay.png","530f6563273600c3ffa8255fb1126eb119f2b5a411e792526dab69d7fd078e0b","PlanetGreenie.png","f4683be6acf501c2a0471cc2184a18c15971c8a332f970eeefd4b08c938b59c4","PuppetIsland.png","f774024ec050f0ac71f85debed59513e2db9f9a67e35d2195f9e93d60b741a23","RainVillage.png","b96f0bca8f426e1ee271bcc92d49b42076a0ed949c88cb03f77b97335a0b0e29","RuinedCity.png","39e1e420bc44d0e00152cf8f1fa9090577bbf1aea861c509464296c51e3b4654","SandVillage.png","093c76bf78e3bb332a459f351352d44f6de83d95bbe91d0bbe342caec7079827","ShibuyaDistrict.png","4dfe9f2ce635602f1f340879b55976adf4ff89465a840065d507a11163a56c7b","SnowyKingdom.png","b54a2291134ca4433bf5a5b0f29f37f2481b9f8a4b6a7cd67ac9fdd9beeabea4","SpaceCenter.png","8f63d42d1545ff254e500cc74326230c89bd497c828cace9a2649f67b8cb18d2","SpiritWorld.png","71739265a4763ed85123d18c397c255b3534a7766166783753119dc6327255ac","VirtualDungeon.png","aa4d6c9f62bad91810b468a00d236fc939ead63c7b6b86aaae20fdd573b7cac7","MagicHills.png","7da742a3f1fe5d840a42862913b0b85759c36f79a7cad3c2e967718bff6ed73d","SnowyTown.png","ab4280b96ca959a7f79ff885fceb4a2b6bd73ec866689bf8677450e721874b1f","WalledCity.png","46fd172b2508b19eb78d85f920109508461e1351c86484d1864d26404dd4253f","AssassinPark.png","a8639e5f5cc4c1c49dcd25702f54b79895a705194131535cebfef5e4f0be9a7c","StormHideout.png","55465ae6c338b05c3224962a24a16817ca5351da6089ab5ee2e8413d890df957","CursedFestival.png","ebadd2928dfb22c961d76b6f83bda79e9b4a900f7c3732ebc404a5009b0e391f","NightmareTrain.png","3ce55cc502dc3ece8a9e20e83971a42a57b2e5bd2ce196c9bd8bf349522618b8","FutureCity.png","3a9847df98d551581b285fab7057b5913cf27cdb7ed732749399c5cade71d32c","StrangeTown.png","f809e872e5c48daa6a3fc2050267e4509d8219504a293c096e8ead04d1ce75c5","SacredPlanet.png","a1d78f01da048f75f9a56a2d7934071e0365d7da2e2fda42d5d164914d926db4","Portals.png","9f653579e359f00870430ed36f9f6887ce4527db0cfec8de62662886cf37ae0e")
static DefaultHashes := Map("f7c71d57a91727f56b1fccd03916dc23efc53c0d8a80156bafeacc0659c424fc",true,"eca2eeddaf10ccb8c4c263c16d83ea20a48bdb28cc51baa1fd0a249b0e26ea3f",true,"c2cddd972851f4510370b6298a2ed0ee145dc0183d9b7f66afcf2ba2646df877",true,"b54a2291134ca4433bf5a5b0f29f37f2481b9f8a4b6a7cd67ac9fdd9beeabea4",true,"ab4280b96ca959a7f79ff885fceb4a2b6bd73ec866689bf8677450e721874b1f",true,"8f63d42d1545ff254e500cc74326230c89bd497c828cace9a2649f67b8cb18d2",true,"88245e6868abf51e32385d968b4adb50cb1b30cbc116ae859af20bf29ffd99b1",true,"7da742a3f1fe5d840a42862913b0b85759c36f79a7cad3c2e967718bff6ed73d",true,"71739265a4763ed85123d18c397c255b3534a7766166783753119dc6327255ac",true,"401323dd0caa9db5198af51109861c3b13aa293bd06abee0e6839aec49866272",true,"34c597405bdd2a8ef700531242225ddbd78f7018568373bc87bf2bdeed699b03",true,"093c76bf78e3bb332a459f351352d44f6de83d95bbe91d0bbe342caec7079827",true,"085edff86f8b29fee3b8c2308d99edf413c3e23baf710cddfc5a259211e28622",true,"c2f4a6e684ee7017dca29ba225eb24ed125f3d43bf384d34af7dc97e79a94781",true,"88944fc2f390cd225aa1b4681646458057091d28c98aeee19c4166ad6ef509a0",true,"06add74b25a9c24ad18c8cfc1d0776fc072beac90df4629c4aceb35ed49b40c6",true,"07d2f004f9228eea546a5273d90155d67e99c59beadb84ac2bc2816810452008",true,"1969d708cd713499dd117fc4c4964424944d7aa4cc23a1530c288606b31c968e",true,"1def071289551780242ea5dcca568b5ca9eafaa75743100c644d0c2b83f08c4e",true,"39e1e420bc44d0e00152cf8f1fa9090577bbf1aea861c509464296c51e3b4654",true,"3c2922480b49e6a43ed4d70de20671803a04cab761252742f25b71c7a83fdf55",true,"423a546073d3e9be16b2d9228fb529d7b6b66bee4ed3e45a77c777c460211bec",true,"4297a0ff2df53cc7aeccfde376fae8fce2f33a1c442baf772cea536f2e1597a6",true,"46fd172b2508b19eb78d85f920109508461e1351c86484d1864d26404dd4253f",true,"4dfe9f2ce635602f1f340879b55976adf4ff89465a840065d507a11163a56c7b",true,"530f6563273600c3ffa8255fb1126eb119f2b5a411e792526dab69d7fd078e0b",true,"546190d366e941de790cc2d83045ec9028b374dd67e170e4b7faeb88a0b6423a",true,"5fd4a6ed08d6d70f8b3c002a21aa6f5a5ea4fe5197e182ca7784d0b13989490b",true,"60cbc8b3b0c7353a03f8d263a097fef5e25783dc00a6d0ede76caba4aa4e75b0",true,"9f653579e359f00870430ed36f9f6887ce4527db0cfec8de62662886cf37ae0e",true,"a2d0899489a5fa3f8d8e3b46f12191891eef744d54dc126e3b72e2f70702e803",true,"a8639e5f5cc4c1c49dcd25702f54b79895a705194131535cebfef5e4f0be9a7c",true,"aa4d6c9f62bad91810b468a00d236fc939ead63c7b6b86aaae20fdd573b7cac7",true,"b96f0bca8f426e1ee271bcc92d49b42076a0ed949c88cb03f77b97335a0b0e29",true,"e574f2f2c5cbc7837b574969cb43afa3c132401ad40b21e7c712c95d2c248e8b",true,"e6ed96f8fecc40c5f509d56fabb47fe8455b1558219a80074d0a74d670c9fb00",true,"e70c371a53ea7756d37f19860cb8018deeb19715d1c0a34b578f659ed28acef3",true,"f20a960c21d67cfd794ba255d95873f367e91417820e26544bca0413f7a5b5c8",true,"f394710cfa967fbb0d636d6cdcaa199bd0dce287a5cdd615ffb48a89151461d5",true,"f4683be6acf501c2a0471cc2184a18c15971c8a332f970eeefd4b08c938b59c4",true,"f774024ec050f0ac71f85debed59513e2db9f9a67e35d2195f9e93d60b741a23",true,"8bf561caa34158e12e9bbfbf81efb74a6296c5e831e9df2944b1f9bc12ab38e7",true,"2e41573dd4ee4c6b6088fb81cb8125b53cf777b47273e128339d1ff8b3a72f13",true,"743e98d4f66e8eeafa686ec112f359094c747c0022b74a6f9acc0d013cfebf48",true,"fc2182b24272af71618fb705833d3e13ed2b1288bc8d4decd72662cd84bd4754",true,"ea6f70b00d3a659d6ae6a72a57dfc00837aef6955491b85907d1b40f90b12dfe",true,"47aa09591f88647ea62d716ef1555399707d2e07e38b7f2e77c55c93c4280a5e",true,"a46709512953e1b736b09efa775e69bff4f2a2396579117099bba44ab2c17835",true,"ccf9a0bde5c0a2333106547acc18350414b741c9785c9715846368b0fc620239",true,"042c6195e78425f9bf7415685c808125ff924e9d67a55b9341e03199861211bc",true,"7bda3a623f5f4706e9747c70c9da748ebdeeff8003abc80cef6df383b528f994",true,"f067b39afc42df2de0719d3fad058229d763a86a81a41ee3454b0fcf9eaaa185",true,"00971e36d22c0e8984c89f9c070cf5ad86397f25991e8eade1df935bc30798c8",true,"0a46c3c895d37cb02928709a7d5dbec8b4fdca25d5a0848f2ddb7fe0c0613110",true,"2918adc914e37b77bf4f35662e899f8a0fe0c4c899b562072b428b403e3a192c",true,"2c7df0c8e45f63a677220ecf2f8c5a2148d42f62fe478b5baeb99557bb303d6d",true,"2fc4146a8b799057e0ad1a9f8b05c823b9fbbfb58cb83352222f6b913ff9f2bd",true,"346292d6d42b7a6567eac9a551d4e8f3c6094e316d53c78d856a3fcb327eeb7d",true,"3a9847df98d551581b285fab7057b5913cf27cdb7ed732749399c5cade71d32c",true,"3ce55cc502dc3ece8a9e20e83971a42a57b2e5bd2ce196c9bd8bf349522618b8",true,"48d84a03a1e85369a4ac44de1ab148ef23207b80a45fe9f9c51bd3020bca8793",true,"4d57ece9f2a6a25fefa7356cf88475eca017b93f5750182a98450e7f098307c5",true,"55465ae6c338b05c3224962a24a16817ca5351da6089ab5ee2e8413d890df957",true,"5d131d07f194fe6400bd81bbc3cc650ba86ce784ea2ac0b7e5244d33676cae90",true,"5de26ae37e6808e5d36093f14c445c401696b2cab1b03f226ae747223bfe60eb",true,"70ad6f6ac1981454b61076d57ba73232ec35d95208481655c04c47b95e162965",true,"71aa3c02fd0dbf52ace7595361bf918a6e819068971c8e442d6b05fb0a72d3a3",true,"761379ef773b0be3d83ef121d678875830215002d535cc51e7930b08dbf421a5",true,"854685f52813b86eb162da518821225a13ca4f2ab4a8b40ece99712a53cdc31c",true,"97aff761299f2e7cbcce258290cc4666586b0ab278f0effb05d4ff6fa899ab6c",true,"a1d78f01da048f75f9a56a2d7934071e0365d7da2e2fda42d5d164914d926db4",true,"a313fb24ad8c4e3979847b86571824f8157bfd16fa6e783c75943b59ed3b67b6",true,"a8101779553e2255273dabb35556c3d7816de83f964700b1241bb688b14a74f2",true,"ab23fdf68c36e2a111a285fe0ef8c205be30f965ecd36129ef475667ffe52311",true,"b0f7e7dd3b76b7cd602545c7e39e646707987d53c0bd5fe16c27ae7e8c49e8ab",true,"b762409db6bc60dc79925d14c936661509bbfda15feedcb944c04f4d4331cedf",true,"cba6aa0871145b67c284a929b5d020ed3ecfac045bd8d49aac7ed201e9bd4c71",true,"d2a7ca936570e4055b743df47c155ac879e19b7c284408d4eba64f7e0dfbe098",true,"d6e578883d74bcd94372e44d2cb04c20b73801eb76f2029d252dab3fd5202b62",true,"e0cabba8b9df0a237a81b865fb13b5bd66a7f456bca90db6321c33b7092992e4",true,"ebadd2928dfb22c961d76b6f83bda79e9b4a900f7c3732ebc404a5009b0e391f",true,"f809e872e5c48daa6a3fc2050267e4509d8219504a293c096e8ead04d1ce75c5",true)
static PlaceholderHashes := Map("e75475b489bba3e650f1f2ea541600153abf88b56b2c9c79e1a119440c9f768e",true)
static IsBundledDefault(path) {
try return this.DefaultHashes.Has(CrusadersConfigCodes.HashBytes(FileRead(path,"RAW")))
catch Error
return false
}
static IsPlaceholder(path) {
if !FileExist(path)
return true
try return this.PlaceholderHashes.Has(CrusadersConfigCodes.HashBytes(FileRead(path,"RAW")))
catch Error
return false
}
static NeedsRefresh(path) {
SplitPath(path,&name)
if !this.ExpectedHashes.Has(name)
throw Error("Unknown bundled map asset: " name)
try return CrusadersConfigCodes.HashBytes(FileRead(path,"RAW")) != this.ExpectedHashes[name]
catch Error
return true
}
static imageVersions := Map()
static ImageVersion(path,refresh := false) {
if !FileExist(path)
return "0"
stamp := FileGetTime(path,"M") ":" FileGetSize(path)
if !refresh && this.imageVersions.Has(path) && this.imageVersions[path].stamp = stamp
return this.imageVersions[path].hash
hash := CrusadersConfigCodes.HashBytes(FileRead(path,"RAW"))
this.imageVersions[path] := {stamp:stamp,hash:hash}
return hash
}
static Ensure(root := "") {
if root = ""
root := A_ScriptDir "\Images\Defaults"
DirCreate(root)
marker := root "\.revision"
refresh := true
if FileExist(marker) {
try refresh := FileRead(marker,"UTF-8") != this.Revision
catch Error
refresh := true
}
path := root "\SpiritTown.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\LegendStages\SpiritTown.png",path,1)
path := root "\HauntedMansion.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Dungeons\HauntedMansion.png",path,1)
path := root "\SkyAircraft.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Dungeons\SkyAircraft.png",path,1)
path := root "\HellishCity.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Dungeons\HellishCity.png",path,1)
path := root "\AlienSpaceship.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\AlienSpaceshipStory.png",path,1)
path := root "\AntKingdom.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\AntKingdomStory.png",path,1)
path := root "\DungeonThrone.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\DungeonThroneStory.png",path,1)
path := root "\FabledKingdom.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\FabledKingdomStory.png",path,1)
path := root "\FiendCity.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\FiendCityStory.png",path,1)
path := root "\HauntedAcademy.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\HauntedAcademyStory.png",path,1)
path := root "\MagicTown.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\MagicTownStory.png",path,1)
path := root "\MountainTemple.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\MountainTempleStory.png",path,1)
path := root "\NavyBay.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\NavyBayStory.png",path,1)
path := root "\PlanetGreenie.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\PlanetGreenieStory.png",path,1)
path := root "\PuppetIsland.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\PuppetIslandStory.png",path,1)
path := root "\RainVillage.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\RainVillageStory.png",path,1)
path := root "\RuinedCity.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\RuinedCityStory.png",path,1)
path := root "\SandVillage.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\SandVillageStory.png",path,1)
path := root "\ShibuyaDistrict.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\ShibuyaDistrictStory.png",path,1)
path := root "\SnowyKingdom.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\SnowyKingdomStory.png",path,1)
path := root "\SpaceCenter.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\SpaceCenterStory.png",path,1)
path := root "\SpiritWorld.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\SpiritWorldStory.png",path,1)
path := root "\VirtualDungeon.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\VirtualDungeonStory.png",path,1)
path := root "\MagicHills.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\MagicHillsStory.png",path,1)
path := root "\SnowyTown.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\SnowyTownStory.png",path,1)
path := root "\WalledCity.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Story\WalledCityStory.png",path,1)
path := root "\AssassinPark.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Dungeons\AssassinPark.png",path,1)
path := root "\StormHideout.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\StormHideout.png",path,1)
path := root "\CursedFestival.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\CursedFestival.png",path,1)
path := root "\NightmareTrain.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\NightmareTrain.png",path,1)
path := root "\FutureCity.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\FutureCity.png",path,1)
path := root "\StrangeTown.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\StrangeTown.png",path,1)
path := root "\SacredPlanet.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Raids\SacredPlanet.png",path,1)
path := root "\Portals.png"
if refresh || this.NeedsRefresh(path)
FileInstall("Images\DefaultMapImages\Portals.png",path,1)
if refresh {
revisionHandle := FileOpen(marker,"w","UTF-8-RAW")
revisionHandle.Write(this.Revision)
revisionHandle.Close()
}
}
}
class AAChallenges {
static schedule := 0
static owner := 0
static timer := 0
static kind := ""
static busy := false
static deferredDailyCycle := ""
static Begin(owner,preferences,stateFile := "") {
this.Stop()
if !Integer(preferences["ChallengeEnabled"]) && !Integer(preferences["DailyChallengeEnabled"])
return
if !owner.tasks.items.Length
throw Error("Add an enabled mode before using Auto Challenge.")
this.owner := owner
this.stateFile := stateFile != "" ? stateFile : CrusadersState.Path(A_ScriptDir,"AAChallenges.ini")
this.schedule := CrusadersChallenges(preferences,this.stateFile)
this.schedule.Begin(A_NowUTC,A_NowUTC)
this.lastObserved := CrusadersChallenges.Slot(A_NowUTC)
this.lastHalf := IniRead(this.stateFile,"HalfHourly","LastAttempt","")
if preferences["ChallengeFirstMode"] = "Mode List" {
this.schedule.pending := false
this.schedule.dailyDeferred := true
if !this.schedule.enabled
this.deferredDailyCycle := CrusadersChallenges.DailyCycle()
}
if owner.HasOwnProp("uiTest") && owner.uiTest
return
this.timer := ObjBindMethod(this,"Watch")
SetTimer(this.timer,250)
}
static Stop() {
if this.timer
SetTimer(this.timer,0)
this.timer := 0, this.schedule := 0, this.owner := 0, this.kind := "", this.deferredDailyCycle := ""
}
static Due() {
if !this.schedule
return false
s := this.schedule, slot := CrusadersChallenges.Slot(A_NowUTC)
s.Poll(A_NowUTC,A_NowUTC)
if slot != this.lastObserved {
if s.enabled
s.pending := true
this.lastObserved := slot
}
if this.lastHalf = slot
s.pending := false
if this.deferredDailyCycle != "" {
if this.deferredDailyCycle = CrusadersChallenges.DailyCycle()
s.dailyDeferred := true
else this.deferredDailyCycle := "", s.dailyDeferred := false
}
return s.DailyDue() || (s.enabled && s.pending)
}
static Launch(owner,task) {
global selector
if !this.Due() || this.schedule.active || !this.schedule.Take()
return false
this.kind := this.schedule.activeKind
this.activeSlot := CrusadersChallenges.Slot(A_NowUTC)
this.resumeTask := task.Clone()
path := CrusadersCatalog.Resolve(selector.configRoot,"Challenges","Planet Greenie",1)
candidate := CrusadersSelector(path,"",selector.settingsFile,selector.imageRoot)
owner.LoadEditor(candidate)
owner.Log("Joining " this.kind " challenge")
AAExecution.lobby := AALobbyFlow(owner,candidate)
AAExecution.lobby.Start()
return true
}
static Watch(*) {
global testRunning
if this.busy || !this.schedule || !testRunning || CrusadersRuntime.paused
return
this.busy := true
try {
due := this.Due()
if !this.schedule.forceLeave || !due
return
if this.schedule.active && this.activeSlot = CrusadersChallenges.Slot(A_NowUTC)
return
if this.schedule.active
this.schedule.active := false, this.schedule.activeKind := ""
this.owner.Log("Challenge rotation | Rejoining")
this.Rejoin(this.owner,this.owner.tasks.Current().Clone())
} catch Error as err {
if this.owner
this.owner.Log("Auto Challenge: " err.Message)
} finally this.busy := false
}
static Rejoin(owner,task) {
global selector
if owner.inputRecorder.playing
owner.inputRecorder.Cancel()
AAExecution.Stop(true)
this.kind := ""
owner.LoadRunningMode(task)
if this.Launch(owner,task)
return
if selector.preferences["Mode"] != "Infinity Mansion"
AAExecution.CheckIndexes(selector)
if AAServer.Url(selector.preferences) = ""
throw Error("Auto Challenge requires Public Rejoin or a private server link.")
AAExecution.lobby := AALobbyFlow(owner,selector)
AAExecution.lobby.Start()
}
static Complete() {
if !this.schedule || !this.schedule.active
return
if this.kind = "Half Hourly" {
this.lastHalf := this.activeSlot
SplitPath(this.stateFile,,&stateDirectory)
if stateDirectory!=""
DirCreate(stateDirectory)
IniWrite(this.lastHalf,this.stateFile,"HalfHourly","LastAttempt")
}
this.schedule.CompleteAttempt()
this.kind := ""
}
static Finished(session,defeated) {
owner := session.owner, task := owner.tasks.Current().Clone()
this.Complete()
this.Rejoin(owner,task)
}
static Skip(owner,reason) {
owner.Log(reason " | Returning to mode queue")
this.Complete()
SetTimer((*)=>this.Rejoin(owner,owner.tasks.Current().Clone()),-1)
}
}
class AAAprilFools {
static IsPath(path) => RegExMatch(path,"i)(?:^|[\\/])Events[\\/]AprilFools\.txt$")
static Approach() {
raw := '{"duration":5761,"events":[{"action":"keyDown","at":668,"key":"a"},{"action":"keyUp","at":5109,"key":"a"}],"height":600,"version":1,"width":800}'
return Jxon_Load(&raw)
}
static SnowyTownPath() {
raw := '{"duration":6120,"events":[{"action":"keyDown","at":593,"key":"d"},{"action":"keyUp","at":2523,"key":"d"},{"action":"keyDown","at":2605,"key":"w"},{"action":"keyUp","at":3959,"key":"w"},{"action":"keyDown","at":3996,"key":"d"},{"action":"keyUp","at":5188,"key":"d"}],"height":600,"version":1,"width":800}'
return Jxon_Load(&raw)
}
static SnowyScenery := [[55,220,0x161415],[165,220,0x351F19],[275,220,0x0E0E20],[385,220,0x0B0B1A],[495,220,0x090824],[605,220,0x051276],[715,220,0x021084],[55,270,0x211A16],[165,270,0x351E18],[275,270,0x140E14],[385,270,0x360D1B],[495,270,0x08115A],[605,270,0x411258],[715,270,0x0B0215],[55,320,0x201715],[165,320,0x43431F],[275,320,0x1D0E16],[385,320,0x3C1B21],[495,320,0x091157],[605,320,0x1B1051],[715,320,0x782629],[55,370,0x161516],[165,370,0x261313],[275,370,0x120F12],[385,370,0x130D16],[495,370,0x2E1223],[605,370,0x2E1028],[715,370,0x160A36],[55,420,0x1A1718],[165,420,0x151315],[275,420,0x1F1318],[385,420,0x201218],[495,420,0x1E0F19],[605,420,0x210E1B],[715,420,0x49223C]]
static SnowyBackground(bitmap) {
if Gdip_GetImageWidth(bitmap) != 800 || Gdip_GetImageHeight(bitmap) != 600
return false
matches := 0
for sample in this.SnowyScenery {
actual := Gdip_GetPixel(bitmap,sample[1],sample[2]), expected := sample[3]
if Abs(((actual>>16)&255)-((expected>>16)&255))<=32
&& Abs(((actual>>8)&255)-((expected>>8)&255))<=32 && Abs((actual&255)-(expected&255))<=32
matches++
}
return matches>=29
}
static ReadMap(reader,bitmap) {
scan := AATransitionVision.Read(reader,bitmap,["Snowy Town","Mountain Temple"])
if scan["kind"] = "transition-map" && scan["map"] = "Snowy Town" && scan["context"] = "stage" && scan["act"] = 1
return Map("kind","april-map","map","Snowy Town","text",scan["text"],"ownerWait",0)
text := AAMansionRoute.CleanMapText(scan["text"])
if InStr(text,"mountaintemple") && InStr(text,"foolshunt") && this.SnowyBackground(bitmap)
return Map("kind","april-map","map","Snowy Town","text",scan["text"],"ownerWait",0)
return Map("kind","none","text","","ownerWait",0)
}
static ReadExit(reader,bitmap) {
result := this.ReadResult(reader,bitmap)
if result["kind"] != "none"
return result
for center in [312,224,400,488,576] {
green := 0
for point in [[center-65,105],[center+65,105],[center-65,132],[center+65,132]]
green += AADungeons.GreenPixel(bitmap,point[1],point[2])
if green<2
continue
label := AAMansionRoute.CleanMapText(reader.Read(bitmap,center-88,95,176,55,3))
if InStr(label,"returntolobby")
return Map("kind","april-exit-choice","returnX",center,"returnY",120,"text",label,"ownerWait",0)
}
return AALobbyVision.Read(reader,bitmap)
}
static HandleExit(r,scan) {
kind := scan["kind"], now := Adventures.Tick()
signature := kind "|" scan.Get("returnX",0)
r.aprilExitFrames := r.HasOwnProp("aprilExitSignature") && r.aprilExitSignature = signature ? r.aprilExitFrames+1 : 1
r.aprilExitSignature := signature
if r.aprilExitFrames<2 || now<r.due
return
if kind = "april-result-covered" {
if scan.Get("panel",false)
r.ClickAt(329,188)
if scan.Get("overview",false)
r.ClickAt(660,543)
r.due := now+500
return
}
if (kind = "victory" || kind = "defeat") && r.stage != "AprilExitLobby" {
attempts := r.HasOwnProp("aprilNextAttempts") ? r.aprilNextAttempts : 0
if attempts>=3
return
r.ClickAt(319,394), r.aprilNextAttempts := attempts+1
r.Change("AprilExitChoice",30000), r.due := now+1500
r.aprilExitFrames := 0, r.aprilExitSignature := ""
r.app.Log("April Fools | Next clicked; waiting for Return to lobby")
} else if kind = "april-exit-choice" {
attempts := r.HasOwnProp("aprilReturnAttempts") ? r.aprilReturnAttempts : 0
if attempts>=3
return
r.ClickAt(scan["returnX"],scan["returnY"]), r.aprilReturnAttempts := attempts+1
r.Change("AprilExitLobby",120000), r.due := now+2000
r.aprilExitFrames := 0, r.aprilExitSignature := ""
r.app.Log("April Fools | Return to lobby clicked; waiting for lobby")
} else if kind = "lobby" && r.stage = "AprilExitLobby" {
r.Change("AprilResultRejoin",30000)
r.app.Log("April Fools | Lobby confirmed; continuing mode queue")
r.app.ResumeAfterAprilReturn()
}
}
static Slots := [276,326,376,426,476,526]
static Upgrades := [[620,172],[756,172],[620,264],[756,264],[620,356],[756,356],[620,450],[756,450]]
static CanPlace(x,y) => (x-400)**2+(y-300)**2 <= 220**2 && y >= 150 && y <= 450
static PlacementPoints() {
points := [[400,300]]
loop 11 {
radius := A_Index*20, count := Max(8,Ceil(2*3.141592653589793*radius/24))
loop count {
angle := (A_Index-1)*2*3.141592653589793/count
x := Round(400+radius*Cos(angle)), y := Round(300+radius*Sin(angle))
if this.CanPlace(x,y)
points.Push([x,y])
}
}
return points
}
static EnsureReferences() {
target := A_ScriptDir "\Images\Detection\AA\AprilFools"
DirCreate(target)
if !FileExist(target "\auto-off.png")
FileInstall("Images\Detection\AA\AprilFools\auto-off.png",target "\auto-off.png",1)
if !FileExist(target "\auto-on.png")
FileInstall("Images\Detection\AA\AprilFools\auto-on.png",target "\auto-on.png",1)
}
static Register() {
if CrusadersDetection.definitions.Has("april-auto-off")
return
this.EnsureReferences()
for name in ["auto-off","auto-on"] {
auto := InStr(name,"auto-") = 1
CrusadersDetection.definitions["april-" name] := {name:"April Fools " name,group:"April Fools",file:"AA\AprilFools\" name ".png",kind:"Image",
x:auto ? 300 : 250,y:auto ? 130 : 538,w:auto ? 495 : 305,h:auto ? 350 : 28,tolerance:25,frames:2,
cx:0,cy:0,cw:0,ch:0}
}
}
static LimitReached(text) {
text := StrLower(RegExReplace(text,"[^a-zA-Z0-9]",""))
return InStr(text,"cannotplacemorethan20units") || InStr(text,"cantplacemorethan20units")
}
static ReadResult(reader,bitmap) {
ended := StoryVision.Parse("result",reader.Read(bitmap,125,150,390,275,2))
if ended["kind"] = "none" {
heading := StrLower(RegExReplace(reader.Read(bitmap,230,140,285,105,3),"[^A-Za-z]",""))
next := StrLower(RegExReplace(reader.Read(bitmap,250,370,150,60,3),"[^A-Za-z]",""))
if RegExMatch(heading,"victory|ictory|ctory|ory|defeat") && InStr(next,"next") {
details := StrLower(RegExReplace(reader.Read(bitmap,250,250,265,115,2),"[^A-Za-z]",""))
if InStr(details,"completed") || InStr(details,"leted") || InStr(details,"time")
ended := Map("kind",InStr(heading,"defeat") ? "defeat" : "victory","text",heading,"ownerWait",0)
}
}
if ended["kind"] = "none" {
nextVisible := InStr(next,"next") || CrusadersDetection.FindBitmap(bitmap,"dungeon-next-label")
if nextVisible {
health := reader.Read(bitmap,145,45,400,45,3)
stats := reader.Read(bitmap,300,150,215,225,3)
overviewText := reader.Read(bitmap,545,65,250,50,2)
if this.CoveredDefeat(health,stats,overviewText)
ended := Map("kind","defeat","text","Covered defeat: zero health, completed waves, time and Next","ownerWait",0)
}
}
if ended["kind"] = "none"
return ended
overview := InStr(StrLower(RegExReplace(reader.Read(bitmap,545,65,250,50,2),"[^A-Za-z]","")),"unitoverview") > 0
panel := StoryVision.Parse("placement",reader.Read(bitmap,5,180,335,225,2))["kind"] = "unit-panel"
if overview || panel
return Map("kind","april-result-covered","result",ended["kind"],"overview",overview,"panel",panel,"text",ended["text"],"ownerWait",0)
return ended
}
static CoveredDefeat(health,stats,overview) {
return RegExMatch(health,"i)(?<![0-9.])0(?:[.,]0+)?\s*/\s*[1-9][0-9]*")
&& RegExMatch(stats,"\b[0-9]{1,2}:[0-9]{2}\b")
&& RegExMatch(stats,"i)(?:com)?pleted\s*:?\s*[0-9]+")
&& InStr(StrLower(RegExReplace(overview,"[^A-Za-z]","")),"unitoverview")
}
static Read(reader,bitmap,checkResult := true) {
if checkResult {
ended := this.ReadResult(reader,bitmap)
if ended["kind"] != "none"
return ended
}
choice := StoryVision.Parse("choice",reader.Read(bitmap,130,80,545,110,2))
if choice["kind"] = "choice"
return choice
limitText := reader.Read(bitmap,120,430,570,60,3)
panel := StoryVision.Parse("placement",reader.Read(bitmap,5,180,335,225,2))
return Map("kind","april-state","text",limitText,"ownerWait",0,
"unitLimit",this.LimitReached(limitText),"panel",panel["kind"] = "unit-panel",
"overview",InStr(StrLower(RegExReplace(reader.Read(bitmap,545,65,250,50,2),"[^A-Za-z]","")),"unitoverview") > 0)
}
}
class AAAprilController {
__New(runner) {
this.loop := runner, this.slot := 1, this.phase := "select", this.due := 0
this.placed := 0, this.clicked := false, this.panelFrames := 0, this.awaitSerial := 0
this.points := AAAprilFools.PlacementPoints(), this.pointIndex := 1
this.placementDone := false, this.upgrade := 1, this.observeSerial := 0
}
Observe(scan) {
if scan["kind"] != "april-state"
return
serial := scan.Get("id",this.loop.worker.serial)
if serial <= this.observeSerial
return
this.observeSerial := serial
this.latest := scan, this.observed := Adventures.Tick()
if scan.Get("unitLimit",false) && !this.placementDone {
this.CancelPreview()
this.placementDone := true, this.clicked := false, this.phase := "open-overview"
this.due := Adventures.Tick()+250
this.loop.app.Log("April Fools | 20-unit limit detected; starting eight-unit upgrade loop")
return
}
if this.placementDone
return
if this.loop.worker.serial <= this.awaitSerial
return
if this.clicked && scan.Get("panel",false) {
this.phase := "confirm", this.panelFrames++
if this.panelFrames >= 2 {
this.CancelPreview()
this.placed++, this.clicked := false, this.panelFrames := 0
this.phase := "select", this.due := Adventures.Tick()+65
this.loop.app.Log("April Fools | Slot 1 placement confirmed (" this.placed "); selecting 1 again")
}
} else {
this.panelFrames := 0
}
}
CancelPreview() {
AAInput.Check(ObjBindMethod(this.loop.app,"CheckClient"))
SendEvent("{q down}")
try Sleep(35)
finally SendEvent("{q up}")
}
SelectSlot(slot) {
AAInput.Check(ObjBindMethod(this.loop.app,"CheckClient"))
SendEvent("{" slot " down}")
try Sleep(35)
finally SendEvent("{" slot " up}")
}
FastPanel() {
this.loop.app.CheckClient()
WinGetClientPos(&left,&top,,,this.loop.app.hwnd)
CoordMode("Pixel","Screen")
green := PixelGetColor(left+200,top+353), red := PixelGetColor(left+104,top+363)
first := PixelGetColor(left+27,top+363)
return ((green>>8)&255)>140 && ((green>>16)&255)<100
&& ((((red>>16)&255)>120 && ((red>>8)&255)<100)
|| ((first&255)>140 && ((first>>8)&255)>120 && ((first>>16)&255)<100))
}
ResultVisible() {
this.loop.app.CheckClient()
WinGetClientPos(&left,&top,,,this.loop.app.hwnd)
CoordMode("Pixel","Screen")
green := PixelGetColor(left+280,top+383), green2 := PixelGetColor(left+357,top+383), dark := PixelGetColor(left+200,top+300)
return ((green>>8)&255)>140 && ((green>>16)&255)<100 && ((green2>>8)&255)>140 && ((green2>>16)&255)<100 && (dark&255)<35 && ((dark>>8)&255)<35 && ((dark>>16)&255)<35
}
MovePlacement(x,y) {
app := this.loop.app
previous := A_CoordModeMouse
CoordMode("Mouse","Screen")
try {
app.CheckClient()
MouseGetPos(&startX,&startY)
WinGetClientPos(&left,&top,,,app.hwnd)
targetX := left+x, targetY := top+y
loop 8 {
if app.status != "Running"
return false
app.CheckClient()
t := A_Index/8
MouseMove(Round(startX+(targetX-startX)*t),Round(startY+(targetY-startY)*t),0)
Sleep(3)
}
return true
} finally CoordMode("Mouse",previous)
}
FastClick(x,y) {
app := this.loop.app
if app.status != "Running"
return
if !this.MovePlacement(x,y)
return false
Sleep(8)
if app.status != "Running" || this.phase != "place"
return false
app.CheckClient()
DllCall("mouse_event","UInt",2,"UInt",0,"UInt",0,"UInt",0,"UPtr",0)
try Sleep(20)
finally DllCall("mouse_event","UInt",4,"UInt",0,"UInt",0,"UInt",0,"UPtr",0)
return true
}
Tick() {
runner := this.loop, now := Adventures.Tick()
if runner.app.status != "Running" || now < this.due || this.phase = "complete"
return
if !this.placementDone && this.ResultVisible()
return
if this.phase = "open-overview" {
runner.ClickAt(780,300)
this.phase := "await-overview", this.due := now+500
return
}
if this.phase = "await-overview" {
this.phase := "upgrade"
}
if this.phase = "upgrade" {
point := AAAprilFools.Upgrades[this.upgrade]
runner.ClickAt(point[1],point[2])
this.upgrade := Mod(this.upgrade,8)+1
this.due := Adventures.Tick()+500
return
}
if this.phase = "select" {
this.SelectSlot(1)
this.phase := "place", this.clicked := false, this.panelFrames := 0
this.awaitSerial := runner.worker.serial, this.due := now+65
return
}
if this.phase = "confirm" {
this.CancelPreview()
this.clicked := false, this.panelFrames := 0, this.phase := "select"
this.due := Adventures.Tick()+30
return
}
if this.phase != "place"
return
if this.pointIndex > this.points.Length
this.pointIndex := 1
point := this.points[this.pointIndex]
if AAAprilFools.CanPlace(point[1],point[2]) && this.FastClick(point[1],point[2]) {
this.pointIndex++, this.clicked := true, this.panelFrames := 0
this.awaitSerial := runner.worker.serial
this.phase := "confirm", this.due := Adventures.Tick()+240
}
}
}
class AADungeons {
static ExtraMaps := ["Assassin Park","Hellish City","Sky Aircraft","Strange Town","Sacred Planet","Cursed Festival","Future City","Storm Hideout","Nightmare Train","Haunted Mansion"]
static Rooms := "Rare Chest|Chest|Shop|Hoard|Shrine|Boss|Curse|Grey Room|Green Room|Purple Room"
static Items := "Golden Mushroom|Mask of Riches|Genie Lamp|Shimmering Moon Fragment|Philosopher's Stone|Golden Branch|Golden Fishhook|Fishhook|Archmage's Hat|Magic Tome|Scimitar|Glacial Axe|Ice Dagger|Sylvanthorn|Stormbringer|Mage Coat|Sword|Elf Bow|Longbow|Bow|Reaper Scythe|Speedy Boots|Dagger|Ninja Belt|Nimble Cloak|Aureus Maul|Headsplitter|Axe|Solar Cleaver|Celestial Blade"
static Defaults := Map("DungeonTeam","0","DungeonRoomPriority",this.Rooms,"DungeonShopPriority",this.Items,
"DungeonHoardReserve","0","DungeonShopLimit","2","DungeonShrineAction","Deny",
"DungeonNormalChests","End","DungeonRareChests","End","DungeonPauseHearts","0",
"DungeonRelicPreferred","","DungeonRelicBlocked","","DungeonUnknownRelic","Pause")
static registered := false
static Register() {
if this.registered
return
this.registered := true
maps := [], seen := Map()
for mode in ["Story","Legend Stages"]
for name in CrusadersCatalog.Maps[mode] {
name := AADefaultPaths.CanonicalName(name)
if !seen.Has(name)
maps.Push(name), seen[name] := true
}
for name in this.ExtraMaps
if !seen.Has(name)
maps.Push(name), seen[name] := true
CrusadersCatalog.Maps["Dungeons"] := maps
keys := []
for key in this.Defaults {
keys.Push(key)
CrusadersConfigCodes.Settings.Push(key)
}
CrusadersSettingsLayout.Groups.Push(["Dungeons",keys])
CrusadersDetection.definitions["dungeon-victory-title"] := {name:"Dungeon Victory Title",group:"Dungeons",file:"AA\Dungeons\victory-title.png",kind:"Image",x:145,y:150,w:350,h:90,tolerance:20,frames:2,cx:0,cy:0,cw:0,ch:0}
CrusadersDetection.definitions["dungeon-next-label"] := {name:"Dungeon Next Label",group:"Dungeons",file:"AA\Dungeons\next-label.png",kind:"Image",x:260,y:365,w:125,h:65,tolerance:25,frames:2,cx:0,cy:0,cw:0,ch:0}
CrusadersDetection.definitions["dungeon-xp-title"] := {name:"Dungeon XP Progress",group:"Dungeons",file:"AA\Dungeons\xp-title.png",kind:"Image",x:525,y:120,w:245,h:60,tolerance:25,frames:2,cx:0,cy:0,cw:0,ch:0}
for name in ["shop-title","shrine-title","chests-title"]
CrusadersDetection.definitions["dungeon-" name] := {name:"Dungeon " name,group:"Dungeons",file:"AA\Dungeons\" name ".png",kind:"Image",x:110,y:100,w:580,h:390,tolerance:20,frames:2,cx:0,cy:0,cw:0,ch:0}
}
static EnsureConfigs(root) {
directory := root "\Dungeons"
DirCreate(directory)
for name in CrusadersCatalog.Maps["Dungeons"] {
path := CrusadersCatalog.Resolve(root,"Dungeons",name,1)
if FileExist(path)
continue
text := "[Selector]`nFormat=2`nCount=0`n`n[Map]`nImage=" RegExReplace(name,"[^A-Za-z0-9]","") ".png`nWidth=800`nHeight=600`n`n[Settings]`nMode=Dungeons`nMap=" name "`nDisplayName=" name "`nAct=1`nDifficulty=Normal`nRuns=1`n"
FileAppend(text,path,"UTF-16")
}
}
static Ordered(value,allowed) {
order := StrSplit(value,"|"), seen := Map(), permitted := Map()
for name in StrSplit(allowed,"|")
permitted[name] := true
for name in order {
if !permitted.Has(name) || seen.Has(name)
throw Error("Dungeon priority contains an unknown or duplicate item: " name)
seen[name] := true
}
if allowed = this.Rooms {
for name in ["Grey Room","Green Room","Purple Room"]
if !seen.Has(name)
order.Push(name)
}
if order.Length != permitted.Count
throw Error("Dungeon priority must contain every item exactly once.")
return order
}
static Validate(p) {
if p["DungeonShrineAction"] = "Skip" || p["DungeonShrineAction"] = "Pause"
p["DungeonShrineAction"] := "Deny"
for pair in [["DungeonTeam",0,6],["DungeonPauseHearts",0,5],["DungeonHoardReserve",0,999999999]]
if !RegExMatch(p[pair[1]],"^\d+$") || Integer(p[pair[1]]) < pair[2] || Integer(p[pair[1]]) > pair[3]
throw Error("Invalid " pair[1] ".")
if p["DungeonShopLimit"]!="1" && p["DungeonShopLimit"]!="2" && p["DungeonShopLimit"]!="3"
p["DungeonShopLimit"] := "2"
this.Ordered(p["DungeonRoomPriority"],this.Rooms)
if !InStr("|" p["DungeonRoomPriority"] "|","|Grey Room|")
p["DungeonRoomPriority"] .= "|Grey Room"
if !InStr("|" p["DungeonRoomPriority"] "|","|Green Room|")
p["DungeonRoomPriority"] .= "|Green Room"
if !InStr("|" p["DungeonRoomPriority"] "|","|Purple Room|")
p["DungeonRoomPriority"] .= "|Purple Room"
this.Ordered(p["DungeonShopPriority"],this.Items)
for pair in [["DungeonShrineAction","Accept|Deny"],["DungeonNormalChests","Checkpoint|Both|End"],["DungeonRareChests","End"],["DungeonUnknownRelic","Pause|Decline"]]
if !InStr("|" pair[2] "|","|" p[pair[1]] "|")
throw Error("Invalid " pair[1] ".")
for key in ["DungeonRelicPreferred","DungeonRelicBlocked"]
if StrLen(p[key]) > 1000 || RegExMatch(p[key],"[\r\n]")
throw Error("Relic names must be one line, at most 1000 characters.")
}
static Team(model) => Integer(model.preferences.Get(model.preferences["Mode"] = "Dungeons" ? "DungeonTeam" : "Team","0"))
static MapName(text) {
normalized := StrLower(RegExReplace(text,"[^A-Za-z0-9]",""))
if InStr(normalized,"spirittown")
return "Spirit Town"
for name in this.ExtraMaps
if InStr(normalized,StrLower(RegExReplace(name,"[^A-Za-z0-9]","")))
return name
if InStr(normalized,"cityhellish")
return "Hellish City"
best := "", score := 0
for mode in ["Story","Legend Stages"]
for name in CrusadersCatalog.Maps[mode] {
key := StrLower(RegExReplace(name,"[^A-Za-z0-9]",""))
if StrLen(key) > score && InStr(normalized,key)
best := AADefaultPaths.CanonicalName(name), score := StrLen(key)
}
return best
}
static Parse(text) {
normalized := StrLower(RegExReplace(text,"[^A-Za-z0-9]",""))
result := Map("kind","none","text",text,"ownerWait",0)
if InStr(normalized,"youdied") && InStr(normalized,"depthreached") && InStr(normalized,"continue")
result["kind"] := "dungeon-died"
else if InStr(normalized,"leavedungeon") && InStr(normalized,"finish") && InStr(normalized,"cancel")
result["kind"] := "dungeon-finish"
else if InStr(normalized,"enterthedungeonandfacetheunknown") && InStr(normalized,"enterdungeon")
result["kind"] := "dungeon-entry-menu"
else if InStr(normalized,"opendungeon")
result["kind"] := "dungeon-result"
else if InStr(normalized,"dungeonroom") && RegExMatch(text,"i)\bEnter\b") {
result["kind"] := "dungeon-room", result["map"] := this.MapName(text)
if RegExMatch(text,"i)Depth\s*:?\s*(\d{1,2})\b",&m)
result["depth"] := Integer(m[1])
} else if (InStr(normalized,"dungeondepth") || InStr(normalized,"depthdungeon")) && RegExMatch(text,"(\d{1,2})\s*/\s*20",&m) {
result["kind"] := "dungeon-board", result["depth"] := Integer(m[1])
if RegExMatch(text,"([0-5])\s*/\s*5",&hearts)
result["hearts"] := Integer(hearts[1])
} else if InStr(normalized,"openchests")
result["kind"] := "dungeon-chests"
else if RegExMatch(text,"i)\bSHRINE\b")
result["kind"] := "dungeon-shrine"
else if RegExMatch(text,"i)\bSHOP\b") && !InStr(normalized,"dungeondepth")
result["kind"] := "dungeon-shop"
else if RegExMatch(text,"i)\bRELIC\b")
result["kind"] := "dungeon-relic"
else if InStr(normalized,"dungeon") && (InStr(normalized,"nokeys") || InStr(normalized,"notenoughkeys"))
result["kind"] := "dungeon-no-key"
return result
}
static FindEnter(bitmap,startY := 385) {
loop (startY = 365 ? 17 : 29) {
y := startY+(A_Index-1)*3, start := -1
loop 451 {
x := 220+A_Index-1
color := this.Pixel(bitmap,x,y)
red := (color>>16)&255, green := (color>>8)&255, blue := color&255
isGreen := green > 130 && green > red*1.6 && green > blue*1.4
if isGreen {
if start < 0
start := x
} else if start >= 0 {
width := x-start
if width >= 85 && width <= 200 {
center := Round((start+x-1)/2), filled := 0
for dy in [-4,0,4,8] {
for dx in [-30,0,30] {
c := this.Pixel(bitmap,center+dx,y+dy)
rr := (c>>16)&255, gg := (c>>8)&255, bb := c&255
filled += gg > 130 && gg > rr*1.6 && gg > bb*1.4
}
}
if filled >= 7
return [center,y+3]
}
start := -1
}
}
}
return false
}
static CardAvailable(bitmap,x) {
visible := 0
for point in [[x+3,325],[x+75,325],[x+3,397],[x+75,397]] {
bright := false
loop 7 {
dx:=A_Index-4
loop 7 {
c:=this.Pixel(bitmap,point[1]+dx,point[2]+A_Index-4)
if Max((c>>16)&255,(c>>8)&255,c&255)>=55
bright:=true
}
}
visible += bright
}
return visible>=3
}
static RoomDifficulty(bitmap,x) {
border := Map("Grey Room",0,"Green Room",0,"Purple Room",0)
leftCounts := Map("Grey Room",0,"Green Room",0,"Purple Room",0)
rightCounts := leftCounts.Clone()
for side in [0,1] {
for dx in (side ? [72,73,74,75,76,77,78] : [6,7,8,9,10,11,12]) {
column := Map("Grey Room",0,"Green Room",0,"Purple Room",0)
loop 9 {
c := this.Pixel(bitmap,x+dx,330+(A_Index-1)*8)
r := (c>>16)&255, g := (c>>8)&255, b := c&255
column["Grey Room"] += Abs(r-30)<=6 && Abs(g-31)<=6 && Abs(b-44)<=6
column["Green Room"] += Abs(r-18)<=6 && Abs(g-40)<=6 && Abs(b-15)<=6
column["Purple Room"] += Abs(r-27)<=6 && g<=6 && Abs(b-44)<=6
}
target := side ? rightCounts : leftCounts
for difficulty,count in column
target[difficulty] := Max(target[difficulty],count)
}
}
for point in [[x+3,325],[x+75,325],[x+3,397],[x+75,397]] {
found:=Map("Grey Room",false,"Green Room",false,"Purple Room",false)
loop 7 {
dx:=A_Index-4
loop 7 {
c:=this.Pixel(bitmap,point[1]+dx,point[2]+A_Index-4),r:=(c>>16)&255,g:=(c>>8)&255,b:=c&255
found["Grey Room"] := found["Grey Room"] || (b>=100 && r>=40 && g>=45 && Abs(r-g)<=25)
found["Green Room"] := found["Green Room"] || (g>=60 && g>r*1.5 && g>b*1.5)
found["Purple Room"] := found["Purple Room"] || (b>=60 && r>=25 && g<25 && b>r*1.3)
}
}
for difficulty,yes in found
border[difficulty]+=yes
}
for difficulty,count in leftCounts
if count>=5 && rightCounts[difficulty]>=5 && count+rightCounts[difficulty]>=12
&& (border[difficulty]>=(difficulty = "Grey Room" ? 2 : 3) || border["Green Room"]>=3)
return difficulty
return ""
}
static PurpleRoom(bitmap,x) => this.RoomDifficulty(bitmap,x) = "Purple Room"
static cardTextCache := Map()
static ReadCardText(reader,bitmap,x,scale) {
if !this.framePixels || bitmap != this.frameBitmap
return reader.Read(bitmap,x,320,86,85,scale)
crop := Buffer(86*85*4)
loop 85
DllCall("ntdll\RtlMoveMemory","Ptr",crop.Ptr+(A_Index-1)*86*4,"Ptr",this.framePixels.Ptr+(320+A_Index-1)*this.frameStride+x*4,"UPtr",86*4)
hash := CrusadersConfigCodes.HashBytes(crop), key := ObjPtr(reader) "|" x "|" scale, now := Adventures.Tick()
if this.cardTextCache.Has(key) {
cached := this.cardTextCache[key]
if cached.hash = hash && now-cached.at<1000
return cached.text
}
text := reader.Read(bitmap,x,320,86,85,scale)
if this.cardTextCache.Count>32
this.cardTextCache.Clear()
if Trim(text) != ""
this.cardTextCache[key] := {hash:hash,at:now,text:text}
return text
}
static CardRewards(text) {
label := StrLower(RegExReplace(text,"[^A-Za-z]","")), rewards := []
if InStr(label,"ches") || InStr(label,"open")
rewards.Push(InStr(label,"rare") ? "Rare Chest" : "Chest")
for pair in [["hoard","Hoard"],["shop","Shop"],["shrine","Shrine"],["curse","Curse"],["boss","Boss"]]
if InStr(label,pair[1])
rewards.Push(pair[2])
return rewards
}
static DebugCurseCard(scan) {
if scan.Get("kind","")!="dungeon-board"
return false
found:=false
for card in scan.Get("cards",[]) {
if !card.Get("available",true) || !this.MatchesPriority(card,"Curse")
continue
if !found || card["x"]<found["x"]
found:=card
}
return found
}
static DebugBossCard(scan) {
if scan.Get("kind","")!="dungeon-board" || scan.Get("depth",0)!=20
return false
found := false
for card in scan.Get("cards",[]) {
if card.Get("category","")!="Boss" || !card.Get("available",true)
continue
if !found || card["x"]<found["x"]
found := card
}
return found
}
static Diagnostic(scan) {
detail := "observed=" scan.Get("kind","none")
for key in ["map","titleMap","festivalSceneryMatches","titleBluePixels","context","depth","hearts","inLobby","inMatch","enterX","enterY","closeX","closeY","curseText","curseRisk","visibleOffers","hoard","offers","shopRows","unreadable","cardChecks","normalCount","rareCount","normalEmpty","rareEmpty","chestRows","chestNotice","emptyCorroborated","continue","buttons"]
if scan.Has(key)
detail .= "; " key "=" (IsObject(scan[key]) ? Jxon_Dump(scan[key]) : scan[key])
if scan.Has("cards")
detail .= "; recognizedCards=" Jxon_Dump(scan["cards"])
text := Trim(RegExReplace(scan.Get("text",""),"\s+"," "))
return detail "; OCR=" (text != "" ? SubStr(text,1,700) : "[empty]")
}
static reportSerial := 0
static SaveErrorReport(app,message,directory := "",capture := unset) {
if directory = ""
directory := A_ScriptDir "\Logs\Error Report"
try {
DirCreate(directory)
stem := directory "\Dungeon-" FormatTime(,"yyyyMMdd-HHmmss") "-" DllCall("GetCurrentProcessId") "-" Adventures.Tick() "-" (++this.reportSerial)
reportPath := stem ".txt"
context := ""
if app.HasOwnProp("model") && app.model.HasOwnProp("preferences") {
context := "`nMode: " app.model.preferences.Get("Mode","") "`nConfigured map: " app.model.preferences.Get("Map","")
if app.model.HasOwnProp("path") {
SplitPath(app.model.path,&configName)
context .= "`nConfig: " configName
}
}
FileAppend("Bayzo's AA Macro v" CrusadersUpdater.Version "`nTime: " FormatTime(,"yyyy-MM-dd HH:mm:ss") context "`n`n" message "`n",reportPath,"UTF-8-RAW")
app.Log("Dungeon Error Report saved: " reportPath)
return reportPath
} catch Error as err {
app.Log("Dungeon Error Report could not be saved: " err.Message)
return ""
}
}
static MatchesPriority(card,category) {
if card["category"] = category || card.Get("difficulty","") = category
return true
for reward in card.Get("rewards",[])
if reward = category
return true
return false
}
static PriorityScore(card,order) {
score := 0
for category in order
score := score*2+(this.MatchesPriority(card,category) ? 1 : 0)
return score
}
static PurpleClose(bitmap,enterX) {
left := 800, right := 0, top := 600, bottom := 0, count := 0
loop 22 {
y := 223+(A_Index-1)*2
loop 23 {
x := enterX+48+(A_Index-1)*2, c := this.Pixel(bitmap,x,y)
r := (c>>16)&255, g := (c>>8)&255, b := c&255
if r>180 && g<70 && b<70
left := Min(left,x), right := Max(right,x), top := Min(top,y), bottom := Max(bottom,y), count++
}
}
return count>=40 && right-left<=40 && bottom-top<=40 ? [Floor((left+right)/2),Floor((top+bottom)/2)] : false
}
static CurseRisk(text) {
label := StrLower(RegExReplace(text,"[^A-Za-z]",""))
return InStr(label,"shopping") || InStr(label,"shopprices") ? 1 : InStr(label,"explosi") || InStr(label,"plosiv") || InStr(label,"deathrange") || InStr(label,"deathsrange") ? 3 : 2
}
static ShopItemName(text) {
label := StrLower(RegExReplace(text,"[^A-Za-z]",""))
for known in StrSplit(this.Items,"|") {
key := StrLower(RegExReplace(known,"[^A-Za-z]",""))
if label = key || label = "t" key || label = "x" key
return known
}
variants := Map("spooduboote","Speedy Boots","bootespoody","Speedy Boots","glacilamo","Glacial Axe","glacislaho","Glacial Axe","raaporscuthe","Reaper Scythe","roaporscutho","Reaper Scythe","hagictono","Magic Tome","hagictone","Magic Tome","magictono","Magic Tome","goldonhuschroon","Golden Mushroom","goldonhhushroon","Golden Mushroom","goldonhuchroon","Golden Mushroom","goldonhushroon","Golden Mushroom","hinjabolt","Ninja Belt","ninjabolt","Ninja Belt","spooduboots","Speedy Boots","spoodyboots","Speedy Boots","bootsspoody","Speedy Boots","elfbou","Elf Bow","bootsspoodu","Speedy Boots","hagocoat","Mage Coat","ninbloclosk","Nimble Cloak","hinbloclosk","Nimble Cloak","hinblocloak","Nimble Cloak","hagocost","Mage Coat","magocost","Mage Coat","hinblclosk","Nimble Cloak","bou","Bow","suord","Sword","goldonbranch","Golden Branch","ninblocloak","Nimble Cloak","ninblcloak","Nimble Cloak","icodagger","Ice Dagger","amo","Axe","hackofrichos","Mask of Riches","thackofrichos","Mask of Riches","longbou","Longbow","icodaggor","Ice Dagger","icedaggor","Ice Dagger","aho","Axe","auroushaul","Aureus Maul","scinitar","Scimitar","ninblclosk","Nimble Cloak","hsckofrichos","Mask of Riches","thsckofrichos","Mask of Riches","xauroushaul","Aureus Maul")
if variants.Has(label)
return variants[label]
best := 0, second := 0, item := ""
for known in StrSplit(this.Items,"|") {
key := StrLower(RegExReplace(known,"[^A-Za-z]",""))
if StrLen(key)<6 || Abs(StrLen(label)-StrLen(key))>2
continue
score := 1-AAMansionRoute.EditDistance(label,key)/Max(StrLen(label),StrLen(key))
if score>best
second := best, best := score, item := known
else second := Max(second,score)
}
return best>=0.83 && best-second>=0.10 ? item : ""
}
static ShopImageItem(bitmap,y) {
path := A_ScriptDir "\Images\Detection\AA\Dungeons\shop-shimmering-fragment.png"
if !FileExist(path)
FileInstall("Images\Detection\AA\Dungeons\shop-shimmering-fragment.png",path,1)
id := "dungeon-shop-fragment-" y
if !CrusadersDetection.definitions.Has(id)
CrusadersDetection.definitions[id] := {name:"Shimmering Moon Fragment shop item",group:"Dungeons",file:"AA\Dungeons\shop-shimmering-fragment.png",kind:"Image",x:385,y:y+2,w:150,h:45,tolerance:12,frames:2,cx:0,cy:0,cw:0,ch:0}
return CrusadersDetection.FindBitmap(bitmap,id) ? "Shimmering Moon Fragment" : ""
}
static SameShopNames(offers,expected) {
counts := Map()
for offer in offers
counts[offer["name"]] := counts.Get(offer["name"],0)+1
for name in expected {
if !counts.Get(name,0)
return false
counts[name]--
}
return offers.Length=expected.Length
}
static ShopPrice(reader,bitmap,y,trace := 0) {
wide := RegExReplace(reader.Read(bitmap,536,y+5,54,28,4),"[^0-9]","")
tight := RegExReplace(reader.Read(bitmap,542,y+12,33,17,5),"[^0-9]","")
if IsObject(trace)
trace["wide"]:=wide,trace["tight"]:=tight
if wide != "" && wide = tight
return wide
if wide!="" && tight!="" && Integer(wide)>0 && Integer(tight)>Integer(wide) && Integer(tight)<=Integer(wide)*1.75 {
alternate := RegExReplace(reader.Read(bitmap,536,y+5,54,28,3),"[^0-9]","")
if alternate=tight
return tight
}
third := RegExReplace(reader.Read(bitmap,542,y+12,33,17,3),"[^0-9]","")
if IsObject(trace)
trace["third"]:=third
focused := []
for scale in [3,4,5] {
value := RegExReplace(reader.Read(bitmap,538,y+9,30,18,scale),"[^0-9]","")
focused.Push(value)
if IsObject(trace)
trace["focused" scale]:=value
}
if focused[1]!="" && focused[1]=focused[2] && focused[1]=focused[3]
&& (focused[1]=wide || focused[1]=tight || focused[1]=third)
return focused[1]
if tight != "" && Integer(tight)=0 && wide != "" && third != "" && Integer(third)>Integer(wide) && Integer(third)<=Integer(wide)*1.75
return third
if tight != "" && tight = third {
if wide = ""
return tight
if Integer(tight)>Integer(wide) && Integer(tight)<=Integer(wide)*1.75
return tight
}
alternate := RegExReplace(reader.Read(bitmap,536,y+5,54,28,3),"[^0-9]","")
if wide != "" && alternate != "" && Integer(alternate)=Integer(wide)
return wide
if wide != ""
for scale in [2,4,5] {
alternate := RegExReplace(reader.Read(bitmap,537,y+7,32,23,scale),"[^0-9]","")
if alternate != "" && Integer(alternate)=Integer(wide)
return wide
}
if wide!="" {
corroboration := RegExReplace(reader.Read(bitmap,535,y+10,34,17,3),"[^0-9]","")
if IsObject(trace)
trace["digitCrop"]:=corroboration
if corroboration=wide
return wide
}
return ""
}
static BossRoom(bitmap,x) {
fill := 0, frame := 0
loop 11 {
px := x+15+(A_Index-1)*5
loop 11 {
c := this.Pixel(bitmap,px,335+(A_Index-1)*5)
fill += Abs(((c>>16)&255)-41)<=5 && ((c>>8)&255)<=5 && (c&255)<=5
}
}
for p in [[x+3,325],[x+75,325],[x+3,397],[x+75,397]] {
c := this.Pixel(bitmap,p[1],p[2])
frame += ((c>>16)&255)>=45 && ((c>>8)&255)<15 && (c&255)<15
}
return fill>=60 && frame>=3
}
static ChestNotice(reader,bitmap) {
readings := [],normal := 0,rare := 0
for crop in [[115,390,565,135,2],[140,410,530,110,3],[140,375,530,110,3]] {
text := reader.Read(bitmap,crop*),label := StrLower(RegExReplace(text,"[^A-Za-z]",""))
readings.Push(text)
if InStr(label,"notenoughrarechest") || InStr(label,"notenoughraretreasurechest")
rare++
else if InStr(label,"notenoughtreasurechest")
normal++
if normal>=2 || rare>=2
break
}
return Map("normalEmpty",normal>0,"rareEmpty",rare>0,"emptyCorroborated",normal>=2 || rare>=2,"chestNotice",readings)
}
static ChestCount(reader,bitmap,y,trace := 0) {
text := reader.Read(bitmap,371,y,38,30,5)
if IsObject(trace)
trace["primary"] := text
if RegExMatch(text,"i)^\s*[x×]\s*(\d{1,6})\s*$",&amount)
return Integer(amount[1])
if !RegExMatch(text,"^\s*(\d{1,6})\s*$",&bare)
return -1
other := reader.Read(bitmap,368,y+2,38,24,4)
if IsObject(trace)
trace["alternate"] := other
if RegExMatch(other,"i)^\s*[x×]?\s*(\d{1,6})\s*$",&check) && Integer(check[1])=Integer(bare[1])
return Integer(bare[1])
return -1
}
static ShopOfferVisible(bitmap,y) {
yellow := 0
loop 12 {
px := 540+(A_Index-1)*4
loop 8 {
c := this.Pixel(bitmap,px,y+8+(A_Index-1)*3)
yellow += ((c>>16)&255)>170 && ((c>>8)&255)>110 && (c&255)<100
}
}
return yellow>=30
}
static VisibleShopOffers(bitmap) {
count := 0
for y in [205,259,313]
count += this.ShopOfferVisible(bitmap,y)
return count
}
static EmptyShop(bitmap) {
dark := 0
loop 20 {
x := 390+(A_Index-1)*10
loop 16 {
c := this.Pixel(bitmap,x,210+(A_Index-1)*10)
dark += Max((c>>16)&255,(c>>8)&255,c&255)<70
}
}
return dark>=318
}
static GreenRoom(bitmap,x) => this.RoomDifficulty(bitmap,x) = "Green Room"
static GreyRoom(bitmap,x) => this.RoomDifficulty(bitmap,x) = "Grey Room"
static GreenPixel(bitmap,x,y) {
c := this.Pixel(bitmap,x,y), r := (c>>16)&255, g := (c>>8)&255, b := c&255
return g>130 && g>r*1.6 && g>b*1.4
}
static ReadDeath(reader,bitmap) {
if !this.GreenPixel(bitmap,325,375) || !this.GreenPixel(bitmap,475,375)
return 0
heading := reader.Read(bitmap,255,205,300,65,3)
label := StrLower(RegExReplace(heading,"[^A-Za-z]",""))
imageTitle := false, title := InStr(label,"youdied")>0
if !title {
path := A_ScriptDir "\Images\Detection\AA\Dungeons\death-title.png"
if !FileExist(path)
FileInstall("Images\Detection\AA\Dungeons\death-title.png",path,1)
if !CrusadersDetection.definitions.Has("dungeon-death-title")
CrusadersDetection.definitions["dungeon-death-title"] := {name:"Dungeon You Died",group:"Dungeons",file:"AA\Dungeons\death-title.png",kind:"Image",x:220,y:195,w:360,h:90,tolerance:25,frames:2,cx:0,cy:0,cw:0,ch:0}
imageTitle := CrusadersDetection.FindBitmap(bitmap,"dungeon-death-title"), title := imageTitle
}
if !title
return 0
button := reader.Read(bitmap,310,360,185,48,3)
depth := reader.Read(bitmap,250,320,300,35,3)
if !imageTitle && !InStr(StrLower(button),"continue") && !InStr(StrLower(RegExReplace(depth,"[^A-Za-z]","")),"depthreached")
return 0
lobbyHud := reader.Read(bitmap,720,430,80,150,3)
wave := reader.Read(bitmap,140,60,220,65,3)
inLobby := RegExMatch(lobbyHud,"i)\bAreas\b") && !RegExMatch(wave,"i)\bWave\s*\d+")
return Map("kind","dungeon-died","inLobby",!!inLobby,"continueX",400,"continueY",383,"closeX",670,"closeY",147,"text",heading "`n" depth "`n" button,"ownerWait",0)
}
static ReadReturnLobby(reader,bitmap) {
green := 0
for point in [[240,105],[380,105],[240,132],[380,132]]
green += this.GreenPixel(bitmap,point[1],point[2])
if green<2
return 0
left := AAMansionRoute.CleanMapText(reader.Read(bitmap,220,95,180,55,3))
right := AAMansionRoute.CleanMapText(reader.Read(bitmap,400,95,185,55,3))
if InStr(left,"returntolobby") && InStr(right,"opendungeon")
return Map("kind","dungeon-return-lobby","returnX",312,"returnY",120,"text",left " " right,"ownerWait",0)
return 0
}
static FastMenu(reader,bitmap) {
if (death := this.ReadDeath(reader,bitmap))
return death
if this.GreenPixel(bitmap,270,335) && this.GreenPixel(bitmap,370,335) {
text := reader.Read(bitmap,235,240,335,125,2), result := this.Parse(text)
if result["kind"] = "dungeon-finish"
return result
}
if this.GreenPixel(bitmap,325,375) && this.GreenPixel(bitmap,475,375) {
label := reader.Read(bitmap,310,365,185,45,2)
if InStr(StrLower(RegExReplace(label,"[^A-Za-z]","")),"enterdungeon")
return Map("kind","dungeon-entry-menu","text",label,"ownerWait",0)
}
if this.GreenPixel(bitmap,440,394) && this.GreenPixel(bitmap,540,394) {
text := reader.Read(bitmap,150,175,210,65,2), result := this.Parse(text)
if result["kind"] = "dungeon-shop" || result["kind"] = "dungeon-chests"
return result
for pair in [["chests-title","dungeon-chests"],["shop-title","dungeon-shop"]]
if CrusadersDetection.FindBitmap(bitmap,"dungeon-" pair[1])
return Map("kind",pair[2],"text",text,"ownerWait",0)
}
accept := this.Pixel(bitmap,375,394), deny := this.Pixel(bitmap,550,394)
if ((accept>>16)&255)>150 && ((accept>>8)&255)>100 && (accept&255)<80 && ((deny>>16)&255)>160 && ((deny>>8)&255)<80 && (deny&255)<80 {
text := reader.Read(bitmap,150,175,210,65,2), result := this.Parse(text)
if result["kind"] = "dungeon-shrine"
return result
}
return 0
}
static ActiveRoom(reader,bitmap) {
text := reader.Read(bitmap,140,60,220,65,3)
if RegExMatch(text,"i)\bWave\s*(\d+)",&wave) && Integer(wave[1])>=1 {
title := StrLower(RegExReplace(reader.Read(bitmap,110,110,580,95,2),"[^A-Za-z]",""))
if !InStr(title,"dungeonrun") && !InStr(title,"ungeonrun")
return Map("kind","dungeon-active","wave",Integer(wave[1]),"text",text,"ownerWait",0)
}
return Map("kind","none","text",text,"ownerWait",0)
}
static framePixels := 0
static frameBitmap := 0
static frameStride := 0
static Pixel(bitmap,x,y) {
if this.framePixels && bitmap=this.frameBitmap && x>=0 && x<800 && y>=0 && y<600
return NumGet(this.framePixels,y*this.frameStride+x*4,"UInt")
return Gdip_GetPixel(bitmap,x,y)
}
static Read(reader,bitmap,transition := false,fastBoard := false,seed := 0,readShopMoney := true) {
previous := [this.framePixels,this.frameBitmap,this.frameStride]
this.framePixels := 0, this.frameBitmap := 0, this.frameStride := 0
if Gdip_GetImageWidth(bitmap)=800 && Gdip_GetImageHeight(bitmap)=600 && Gdip_LockBits(bitmap,0,0,800,600,&stride,&pixels,&bits,1)=0 {
try {
if stride>=3200 {
copy := Buffer(stride*600)
DllCall("ntdll\RtlMoveMemory","Ptr",copy,"Ptr",pixels,"UPtr",copy.Size)
this.framePixels := copy, this.frameBitmap := bitmap, this.frameStride := stride
}
} finally Gdip_UnlockBits(bitmap,&bits)
}
try return this.ReadFrame(reader,bitmap,transition,fastBoard,seed,readShopMoney)
finally {
this.framePixels := previous[1], this.frameBitmap := previous[2], this.frameStride := previous[3]
}
}
static ReadFrame(reader,bitmap,transition := false,fastBoard := false,seed := 0,readShopMoney := true) {
if transition {
scan := AATransitionVision.Read(reader,bitmap,CrusadersCatalog.Maps["Dungeons"])
if scan["kind"] != "none" && (scan["context"] = "dungeon" || scan["context"] = "alternate-loading") {
scan["kind"] := "dungeon-map"
return scan
}
if scan["context"] != ""
return Map("kind","none","text",scan["text"],"ownerWait",0)
return this.ActiveRoom(reader,bitmap)
}
if fastBoard && (death := this.ReadDeath(reader,bitmap))
return death
if fastBoard {
text := reader.Read(bitmap,280,175,215,40,4)
result := this.Parse(text)
if result["kind"] != "dungeon-board" || this.FindEnter(bitmap)
return Map("kind","none","text",text,"ownerWait",0)
} else if (seed || (seed := this.FastMenu(reader,bitmap))) {
result := seed
} else {
text := reader.Read(bitmap,110,110,580,380,2)
text .= "`n" reader.Read(bitmap,280,175,215,40,4)
result := this.Parse(text)
}
if result["kind"] = "none"
result := this.Parse(reader.Read(bitmap,160,65,460,110,2))
if result["kind"] = "none" {
active := this.ActiveRoom(reader,bitmap)
if active["kind"] != "none"
return active
}
if result["kind"] = "none"
for pair in [["shop-title","dungeon-shop"],["shrine-title","dungeon-shrine"],["chests-title","dungeon-chests"]]
if CrusadersDetection.FindBitmap(bitmap,"dungeon-" pair[1]) {
result["kind"] := pair[2]
break
}
if result["kind"] = "dungeon-finish" {
label := StrLower(reader.Read(bitmap,240,320,160,50,3))
if InStr(label,"finish") && this.GreenPixel(bitmap,270,335) && this.GreenPixel(bitmap,370,335)
result["finishX"] := 321, result["finishY"] := 342
}
if result["kind"] = "dungeon-room" || result["kind"] = "dungeon-entry-menu" {
initial := result["kind"] = "dungeon-entry-menu"
if initial {
lobbyText := reader.Read(bitmap,720,430,80,150,3)
result["inLobby"] := RegExMatch(lobbyText,"i)\bAreas\b")>0
result["inMatch"] := RegExMatch(reader.Read(bitmap,140,60,220,65,3),"i)\bWave\s*\d+")>0
}
button := this.FindEnter(bitmap,initial ? 365 : 385)
if button
result["enterX"] := button[1], result["enterY"] := button[2]+(initial ? 15 : 0)
if !initial && button {
close := this.PurpleClose(bitmap,button[1])
if close {
result["closeX"] := close[1], result["closeY"] := close[2]
result["curseText"] := reader.Read(bitmap,button[1]-67,315,138,65,4)
result["curseRisk"] := this.CurseRisk(result["curseText"])
}
}
}
if result["kind"] = "dungeon-shop" {
result["unreadable"] := [], result["offers"] := [],result["shopRows"] := [], result["empty"] := this.EmptyShop(bitmap), result["visibleOffers"] := this.VisibleShopOffers(bitmap)
if readShopMoney {
hoardText := RegExReplace(reader.Read(bitmap,176,411,43,28,4),"[^0-9]","")
result["hoard"] := hoardText != "" ? Integer(hoardText) : -1
}
for y in [205,259,313] {
if !this.ShopOfferVisible(bitmap,y)
continue
nameText := reader.Read(bitmap,412,y,121,15,4)
retry := reader.Read(bitmap,407,y-5,130,22,5)
primary := this.ShopItemName(nameText), alternate := this.ShopItemName(retry)
conflict := primary!="" && alternate!="" && primary!=alternate
item := conflict ? "" : primary!="" ? primary : alternate
imageItem := ""
if item="" && !conflict
item := imageItem := this.ShopImageItem(bitmap,y)
row := Map("row",((y-205)//54+1),"rawName",nameText,"retryName",retry,"item",item,"nameConflict",conflict,"imageItem",imageItem)
priceText := ""
if readShopMoney {
priceTrace := Map(),priceText := this.ShopPrice(reader,bitmap,y,priceTrace)
row["price"]:=priceText,row["priceOCR"]:=priceTrace
}
result["shopRows"].Push(row)
if item != "" && (!readShopMoney || priceText != "") {
offer := Map("name",item,"x",563,"y",y+20)
if readShopMoney
offer["price"]:=Integer(priceText)
result["offers"].Push(offer)
} else result["unreadable"].Push("Row " row["row"] ": " (conflict ? "conflicting item names: " primary " / " alternate : item="" ? "item name unreadable" : "price unreadable"))
}
result["continue"] := InStr(StrLower(reader.Read(bitmap,420,390,152,35,3)),"continue") > 0
}
if result["kind"] = "dungeon-shrine" {
buttons := StrLower(RegExReplace(reader.Read(bitmap,355,385,255,48,3),"[^A-Za-z]",""))
result["buttons"] := InStr(buttons,"accept") && InStr(buttons,"deny")
}
if result["kind"] = "dungeon-chests" {
result["chestRows"] := []
for row in [["normal",260],["rare",320]] {
countTrace := Map()
result[row[1] "Count"] := this.ChestCount(reader,bitmap,row[2],countTrace)
result["chestRows"].Push(Map("type",row[1],"count",result[row[1] "Count"],"countOCR",countTrace))
}
for key,value in this.ChestNotice(reader,bitmap)
result[key] := value
result["continue"] := InStr(StrLower(reader.Read(bitmap,400,389,170,40,3)),"continue") > 0
}
if result["kind"] = "dungeon-board" {
result["cards"] := []
result["cardChecks"] := []
heartsText := fastBoard ? "" : reader.Read(bitmap,210,385,80,40,4)
if RegExMatch(heartsText,"([0-5])\s*/\s*5",&life)
result["hearts"] := Integer(life[1])
for x in [202,280,357,435,512] {
if !this.CardAvailable(bitmap,x) {
result["cardChecks"].Push(Map("x",x,"rejected","fewer than 3 bright frame corners"))
continue
}
difficulty := this.RoomDifficulty(bitmap,x)
boss := difficulty = "" && this.BossRoom(bitmap,x)
result["cardChecks"].Push(Map("x",x,"difficulty",difficulty,"boss",!!boss,"frameBright",true))
if difficulty = "" && !boss
continue
cardText := this.ReadCardText(reader,bitmap,x,boss ? 3 : difficulty = "Purple Room" ? 3 : 4)
rewards := this.CardRewards(cardText)
if boss {
if !RegExMatch(StrLower(cardText),"boss|8066|b066")
continue
result["cards"].Push(Map("category","Boss","difficulty","Boss","available",true,"rewards",["Boss"],"x",x+43,"y",360))
continue
}
category := difficulty
if difficulty = "Grey Room" && rewards.Length {
if rewards[1] = "Chest" && rewards.Length = 1 {
gold := 0, white := 0
loop 80 {
px := x+A_Index
loop 20 {
c := this.Pixel(bitmap,px,365+A_Index), red := (c>>16)&255, green := (c>>8)&255, blue := c&255
gold += red>160 && green>90 && blue<90
white += Min(red,green,blue)>160
}
}
if gold>=5 && gold>white
rewards[1] := "Rare Chest"
}
category := rewards[1]
}
result["cards"].Push(Map("category",category,"difficulty",difficulty,"rewards",rewards,"x",x+43,"y",360))
}
}
return result
}
}
class AAChestDebug {
__New(io) {
this.io := io,this.phase := "detect",this.chest := "normal",this.frames := 0,this.signature := "",this.due := 0,this.deadline := Adventures.Tick()+30000
}
Act(x,y,next,now,wait := 500) {
this.io.Click(x,y)
if next="reward"
this.openingCounted := false
this.phase := next,this.due := now+wait,this.deadline := now+45000,this.frames := 0,this.signature := ""
}
Handle(scan,now) {
if this.phase="done" || now<this.due
return
if now>this.deadline
throw Error("Chest debug timed out; phase=" this.phase "; chest=" this.chest "; " AADungeons.Diagnostic(scan))
kind := scan["kind"]
if HasMethod(this.io,"ObserveChests")
this.io.ObserveChests(scan)
empty := this.chest="normal" ? scan.Get("normalEmpty",false) : scan.Get("rareEmpty",false) || scan.Get("normalEmpty",false)
signature := kind "|" empty "|" scan.Get("continue",false) "|" scan.Get("finishX",0)
this.frames := signature=this.signature ? this.frames+1 : 1,this.signature := signature
if this.frames<2 && !(this.phase="reward" && kind="dungeon-chests" && empty && scan.Get("emptyCorroborated",false))
return
if this.phase="finish" {
if kind="dungeon-finish" && scan.Has("finishX") {
this.Act(scan["finishX"],scan["finishY"],"done",now)
this.io.Log("Chest debug complete: Finish clicked; no further actions")
}
return
}
if this.phase="reward" || this.phase="reward-chain" {
if kind="dungeon-chests" && empty {
if this.chest="normal" {
this.chest := "rare",this.phase := "clear-common",this.deadline := now+30000
this.io.Log("Chest debug: common empty popup confirmed; waiting for it to clear before rare test")
} else this.Act(485,407,"finish",now)
this.frames := 0,this.signature := ""
} else if kind="reward" {
if !this.HasOwnProp("openingCounted") || !this.openingCounted {
this.openingCounted := true
if HasMethod(this.io,"ChestOpened")
this.io.ChestOpened(this.chest)
}
if !this.io.Reward()
throw Error("Chest reward webhook could not be queued; reward left open")
this.Act(400,300,"reward-chain",now,1500)
}
if this.phase="reward-chain" && kind="dungeon-chests" && !empty
this.phase := "menu"
else return
}
if kind!="dungeon-chests" || !scan.Get("continue",false)
return
if this.phase="clear-common" {
if scan.Get("normalEmpty",false) || scan.Get("rareEmpty",false)
return
this.phase := "menu"
}
if this.phase="detect" || this.phase="menu" {
this.io.Log("Chest debug: opening " this.chest " chest")
this.Act(565,this.chest="normal" ? 259 : 319,"reward",now,350)
}
}
}
class AADungeonRun {
__New(runner) {
this.runner := runner, this.phase := "board", this.depth := 0, this.hearts := -1
this.candidate := "", this.frames := 0, this.minSerial := 0, this.lastAction := 0
this.roomWins := 0, this.roomLosses := 0, this.completed := 0
}
RequestStage() => (this.phase = "death-returning" || this.phase = "await-death-exit") ? "dungeon-death-exit" : this.HasOwnProp("chestPending") && this.chestPending ? "dungeon-chest-reward" : this.phase = "loading" ? "dungeon-transition" : (this.phase = "board" || this.phase = "await-entry-board") ? "dungeon-board" : "dungeon"
CheckDeathExit() {
if (this.phase != "await-death-exit" && this.phase != "death-returning" && this.phase != "await-lobby-death-continue") || !this.HasOwnProp("deathWaitStarted")
return false
if Adventures.Tick()-this.deathWaitStarted<(this.phase = "death-returning" ? 120000 : 15000)
return false
this.RejoinDiagnostic("Death exit timed out; expected " (this.phase = "death-returning" ? "confirmed lobby after Return to lobby" : this.phase = "await-lobby-death-continue" ? "Enter Dungeon after Continue" : "Return to lobby after closing death X")
"; closeAttempts=" this.GetAttempts("deathAttempts") "; returnAttempts=" this.GetAttempts("deathReturnAttempts"))
return true
}
GetAttempts(name) => this.HasOwnProp(name) ? this.%name% : 0
RejoinDiagnostic(reason) {
if this.runner.app.HasOwnProp("owner") && this.runner.app.owner.HasOwnProp("dungeonBossDebug") && this.runner.app.owner.dungeonBossDebug {
this.runner.app.SaveDungeonErrorReport("L boss test failed: " reason)
this.runner.app.owner.dungeonBossDebug := false,this.runner.app.owner.dungeonCycleDebug := false
this.runner.Pause("L boss test failed; Error Report saved")
return
}
detail := this.HasOwnProp("lastObservation") ? this.lastObservation : "No completed scan received"
this.runner.app.Log("Dungeon recovery: " reason "; phase=" this.phase "; currentDepth=" this.depth "; " detail "; rejoining lobby")
if HasMethod(this.runner.app,"SaveDungeonErrorReport")
this.runner.app.SaveDungeonErrorReport("Dungeon recovery: " reason "; phase=" this.phase "; currentDepth=" this.depth "; " detail)
this.phase := "rejoining"
this.runner.app.RejoinNextMode(true)
}
ContinueShop() {
if this.phase != "shop-purchased" || Adventures.Tick() < this.runner.due
return
this.phase := "shop-verifying", this.frames := 0, this.candidate := ""
this.minSerial := this.runner.worker.serial+1
this.runner.due := 0
}
LeaveShop(message) {
this.Click(495,407), this.phase := "await-shop-return"
this.runner.app.Log(message)
}
ObserveShopTimeout(scan,now) {
if this.phase="await-shop-return" || this.phase="shop-purchased"
return false
if this.phase!="shop-ready" && this.phase!="shop-verifying" {
this.shopPurchases := 0,this.shopAttempted := Map()
this.shopUnreadableSince := 0,this.emptySince := 0,this.lastShopIssue := ""
this.shopContinueFrames := 0,this.phase := "shop-ready"
}
this.shopContinueFrames := scan.Get("continue",false) ? this.GetAttempts("shopContinueFrames")+1 : 0
if this.phase="shop-verifying" {
if now-this.shopPending.at>=8000 && this.shopContinueFrames>=2 {
reason := "Shop: purchase unconfirmed for " this.shopPending.name "; expected purchased name absent, fewer rows, remaining names=" Jxon_Dump(this.shopPending.remainingNames) "; " AADungeons.Diagnostic(scan) "; continuing without another purchase click"
if HasMethod(this.runner.app,"SaveDungeonErrorReport")
this.runner.app.SaveDungeonErrorReport(reason)
this.LeaveShop(reason)
return true
}
return false
}
offers := scan.Get("offers",[])
if offers.Length=scan.Get("visibleOffers",-1) && (offers.Length>0 || scan.Get("empty",false)) {
this.shopUnreadableSince := 0
return false
}
if !this.shopUnreadableSince
this.shopUnreadableSince := now
if now-this.shopUnreadableSince<8000 || this.shopContinueFrames<2
return false
reason := "Shop offers stayed unreadable: recognized " offers.Length "/" scan.Get("visibleOffers",3) " item names; " AADungeons.Diagnostic(scan)
if HasMethod(this.runner.app,"SaveDungeonErrorReport")
this.runner.app.SaveDungeonErrorReport(reason)
this.LeaveShop(reason "; continuing without a purchase")
return true
}
Handle(scan) {
r := this.runner, now := Adventures.Tick(), kind := scan["kind"]
if this.phase = "rejoining"
return
if scan.Get("id",0) < this.minSerial || now < r.due
return
this.lastObservation := AADungeons.Diagnostic(scan)
if r.app.HasOwnProp("owner") && r.app.owner.HasOwnProp("dungeonBossDebug") && r.app.owner.dungeonBossDebug {
owner := r.app.owner
if kind="dungeon-chests" {
if !owner.dungeonBossChestQueued {
owner.dungeonBossChestQueued := true
SetTimer(ObjBindMethod(owner,"BeginBossChestTest"),-1)
}
return
}
if kind="dungeon-died" || kind="dungeon-entry-menu" {
this.RejoinDiagnostic("L boss test ended before chest menu; expected successful boss result")
return
}
}
if HasMethod(r.app,"ObserveDungeonChests")
r.app.ObserveDungeonChests(scan)
if kind = "dungeon-died" {
signature := "dungeon-died|" scan.Get("inLobby",false)
this.frames := this.candidate = signature ? this.frames+1 : 1, this.candidate := signature
if this.frames < 2
return
if scan.Get("inLobby",false) {
if this.phase != "await-lobby-death-continue" {
this.deathWaitStarted := now, this.deathLobbyAttempts := 0, this.deathLobbyLast := 0
}
if this.deathLobbyAttempts>=3 || (this.deathLobbyLast && now-this.deathLobbyLast<1500)
return
this.chestPending := false, this.chestsContinued := false
this.Click(scan.Get("continueX",400),scan.Get("continueY",383))
this.deathLobbyAttempts++, this.deathLobbyLast := now
this.phase := "await-lobby-death-continue"
r.app.Log("Dungeon lobby death summary: Continue clicked; waiting for Enter Dungeon")
return
}
if !this.HasOwnProp("deathWaitStarted") {
this.deathWaitStarted := now, this.deathAttempts := 0, this.deathLastClick := 0
}
if this.deathAttempts>=3 || (this.deathLastClick && now-this.deathLastClick<1500)
return
this.chestPending := false
this.Click(scan.Get("closeX",670),scan.Get("closeY",147))
this.deathAttempts++, this.deathLastClick := now
this.chestsContinued := true, this.phase := "await-death-exit"
r.app.Log("Dungeon lives exhausted: close X attempt " this.deathAttempts "; confirming screen closes")
return
}
if this.HasOwnProp("chestPending") && this.chestPending {
if now > this.chestDeadline {
this.RejoinDiagnostic("Chest reward timed out after 45 seconds; expected reward dismissal followed by the chest menu; rewardDismissed=" this.chestRewardDismissed)
return
}
if kind = "reward" {
if now < this.rewardNotBefore
return
if !this.GetAttempts("chestOpeningCounted") && this.HasOwnProp("chestType") {
this.chestOpeningCounted := true
if HasMethod(r.app,"CountDungeonChest")
r.app.CountDungeonChest(this.chestType)
}
if !this.GetAttempts("chestRewardReported") {
this.chestRewardReported := true
if HasMethod(r.app,"SendDungeonReward") {
try r.app.SendDungeonReward()
catch Error as err
r.app.Log("Dungeon reward webhook failed: " err.Message)
}
}
this.Click(400,300)
this.chestRewardDismissed := true,this.chestRewardReported := false
this.rewardNotBefore := Adventures.Tick()+1500
r.due := this.rewardNotBefore
r.app.Log("Dismissing chest reward; checking for another reward or chest menu")
return
}
pendingType := this.HasOwnProp("chestType") ? this.chestType : ""
if kind="dungeon-chests" && pendingType!="" && scan.Get(pendingType "Empty",false) {
this.chestEmptyFrames := this.GetAttempts("chestEmptyFrames")+1
if this.chestEmptyFrames<2 && !scan.Get("emptyCorroborated",false)
return
this.chestPending := false,this.chestRewardDismissed := true
if pendingType="normal" {
this.commonChestsExhausted := true
r.app.Log("No more common chests: confirmed popup; switching to rare chests")
} else {
this.rareChestsExhausted := true
r.app.Log("No more rare chests: confirmed popup; continuing Dungeon")
}
this.candidate := "",this.frames := 0
} else this.chestEmptyFrames := 0
if !this.chestRewardDismissed
return
if kind = "dungeon-result" {
this.Click(488,121)
return
}
if kind != "dungeon-chests"
return
this.chestPending := false
}
if kind="dungeon-shop" {
if this.ObserveShopTimeout(scan,now)
return
} else this.shopContinueFrames := 0
if kind="dungeon-chests" {
unknown := ""
for row in [["normal","DungeonNormalChests"],["rare","DungeonRareChests"]] {
allowed := (r.app.model.preferences["DungeonNormalChests"]="Both" || (row[1]="normal" && r.app.model.preferences["DungeonNormalChests"]="Checkpoint")) || (this.HasOwnProp("bossCleared") && this.bossCleared)
if allowed && !scan.Get(row[1] "Empty",false) && scan.Get(row[1] "Count",-1)<0
unknown .= (unknown!="" ? ", " : "") row[1]
}
if unknown!="" {
this.chestUnreadableSince := now
if now-this.chestUnreadableSince>=20000 {
this.RejoinDiagnostic("Chest counts unreadable for 20 seconds: " unknown "; expected a confirmed count before opening chests")
return
}
} else this.chestUnreadableSince := 0
} else this.chestUnreadableSince := 0
signature := kind "|" scan.Get("map","") "|" scan.Get("depth",0)
if kind = "dungeon-board"
signature .= "|" Jxon_Dump(scan.Get("cards",[]))
if kind = "dungeon-shop" {
for offer in scan.Get("offers",[])
signature .= "|" offer["name"] "@" offer["x"] "," offer["y"]
signature .= "|" scan.Get("visibleOffers",0) "|" scan.Get("empty",false) "|" scan.Get("continue",false)
}
if kind = "dungeon-room"
signature .= "|" scan.Get("enterX",0) "|" scan.Get("enterY",0)
. "|" scan.Get("closeX",0) "|" scan.Get("closeY",0) "|" scan.Get("curseRisk",2)
if kind = "dungeon-entry-menu"
signature .= "|" scan.Get("inLobby",false) "|" scan.Get("inMatch",false)
. "|" scan.Get("enterX",0) "|" scan.Get("enterY",0)
if kind = "dungeon-chests"
signature .= "|" scan.Get("normalCount",-1) "|" scan.Get("rareCount",-1)
. "|" scan.Get("normalEmpty",false) "|" scan.Get("rareEmpty",false) "|" scan.Get("continue",false)
if kind = "dungeon-shrine"
signature .= "|" scan.Get("buttons",false)
this.frames := signature = this.candidate ? this.frames+1 : 1, this.candidate := signature
if this.frames < 2
return
if kind != "none" && kind != "dungeon-return-lobby" && this.phase != "death-returning" && this.HasOwnProp("deathWaitStarted") {
this.DeleteProp("deathWaitStarted")
r.app.Log("Dungeon death screen closed")
}
if kind = "dungeon-return-lobby" && this.HasOwnProp("deathWaitStarted") {
if !this.HasOwnProp("deathReturnAttempts")
this.deathReturnAttempts := 0, this.deathReturnLast := 0
if this.deathReturnAttempts>=3 || (this.deathReturnLast && now-this.deathReturnLast<2000)
return
this.Click(scan["returnX"],scan["returnY"])
this.deathReturnAttempts++, this.deathReturnLast := now
this.phase := "death-returning", this.deathWaitStarted := now
r.app.Log("Dungeon death: Return to lobby clicked; waiting for confirmed lobby")
return
}
if kind = "lobby" && this.phase = "death-returning" {
this.phase := "rejoining"
r.app.Log("Dungeon death: lobby confirmed; continuing Dungeon navigation")
r.app.ResumeDungeonLobby()
return
}
if kind = "dungeon-finish" {
if this.phase != "await-finish-entry" && scan.Has("finishX") {
this.Click(scan["finishX"],scan["finishY"]), this.phase := "await-finish-entry", this.chestsContinued := true
r.app.Log("Final chest confirmation: Finish; waiting to rejoin lobby")
}
return
}
if kind = "dungeon-entry-menu" && (scan.Get("inMatch",false) || (this.HasOwnProp("chestsContinued") && this.chestsContinued)) {
this.chestsContinued := false, this.phase := "rejoining"
this.Click(670,150)
r.app.Log("Dungeon finished; closing entry menu and rejoining lobby")
r.app.Continuation()
r.app.RejoinNextMode(true)
return
}
if kind = "dungeon-entry-menu" && ((this.phase = "board" && this.depth = 0) || this.phase = "await-lobby-death-continue") && scan.Get("inLobby",false) && scan.Has("enterX") {
this.Click(scan["enterX"],scan["enterY"])
this.phase := "await-entry-board", this.depth := 0
r.app.Log("Starting new Dungeon run; waiting for route board")
return
}
if kind = "dungeon-active" {
if this.phase = "loading" && this.HasOwnProp("pendingRoomMap") && this.pendingRoomMap!="" {
name := this.pendingRoomMap
r.app.LoadDungeonMap(name), r.defeated := false, r.resultCounted := false
this.phase := "combat"
r.Change("AwaitVote",120000)
r.app.Log("Dungeon transition was missed; confirmed active room uses previously identified map: " name)
} else {
this.RejoinDiagnostic("Wave counter confirms combat, but neither a recognized transition map nor a validated room-popup map was available")
}
return
}
if kind = "dungeon-no-key"
throw Error("No Dungeon Run Keys remain. Obtain a key, then resume.")
if kind = "dungeon-relic"
throw Error("Dungeon " SubStr(kind,9) " detected. Complete this uncalibrated menu manually, then resume; no purchase, accept or chest click was guessed.")
if kind = "dungeon-shop" {
if this.phase = "await-shop-return"
return
if this.phase = "shop-purchased" {
this.ContinueShop()
return
}
if this.phase = "shop-verifying" {
pending := this.shopPending, stillVisible := false
for offer in scan.Get("offers",[])
if offer["name"] = pending.name
stillVisible := true
offers := scan.Get("offers",[]), visible := scan.Get("visibleOffers",-1)
if !stillVisible && visible>=0 && visible=pending.visibleOffers-1 && offers.Length=visible && AADungeons.SameShopNames(offers,pending.remainingNames) && (visible>0 || scan.Get("empty",false)) {
this.shopPurchases++
r.app.Log("Shop: purchase confirmed (" this.shopPurchases ") - " pending.name)
limit := r.app.model.preferences.Get("DungeonShopLimit","2")
limit := limit="1" ? 1 : limit="3" ? 3 : 2
if this.shopPurchases>=limit {
this.LeaveShop("Shop: purchase limit reached; continuing")
return
}
this.phase := "shop-ready"
if scan.Get("empty",false) && scan.Get("offers",[]).Length = 0 {
this.LeaveShop("Shop: all offers purchased; continuing")
return
}
} else {
if stillVisible && visible=pending.visibleOffers && offers.Length=visible && now-pending.at>=2000 {
this.phase := "shop-ready"
r.app.Log("Shop: item stayed available after one attempt: " pending.name "; trying next priority")
} else {
return
}
}
}
if scan.Get("empty",false) && scan.Get("continue",false) && scan.Get("offers",[]).Length = 0 {
if !this.HasOwnProp("emptySince") || !this.emptySince
this.emptySince := now
if now-this.emptySince >= 1500 {
this.Click(495,407), this.phase := "await-shop-return"
r.app.Log("Shop: confirmed empty; continuing")
}
return
}
this.emptySince := 0
offers := scan.Get("offers",[])
if !offers.Length || offers.Length != scan.Get("visibleOffers",3) {
if !this.HasOwnProp("shopUnreadableSince") || !this.shopUnreadableSince
this.shopUnreadableSince := now
reason := "recognized " offers.Length "/" scan.Get("visibleOffers",3) " item names"
for issue in scan.Get("unreadable",[])
reason .= "; " issue
if reason != this.lastShopIssue {
this.lastShopIssue := reason
r.app.Log("Shop: retrying detection - " reason)
}
return
}
this.shopUnreadableSince := 0
best := 0
for name in AADungeons.Ordered(r.app.model.preferences["DungeonShopPriority"],AADungeons.Items) {
for offer in offers
if offer["name"] = name && !this.shopAttempted.Has(name) {
best := offer
break
}
if best
break
}
if best {
this.Click(best["x"],best["y"]), this.phase := "shop-purchased"
this.shopAttempted[best["name"]] := true
remainingNames := [],removed := false
for offer in offers {
if !removed && offer["name"]=best["name"]
removed := true
else remainingNames.Push(offer["name"])
}
this.shopPending := {name:best["name"],remainingNames:remainingNames,visibleOffers:scan.Get("visibleOffers",offers.Length),at:now}
r.due := Adventures.Tick()+500
r.app.Log("Shop: buying priority item: " best["name"])
} else {
this.Click(495,407), this.phase := "await-shop-return"
r.app.Log("Shop: all recognized priority items attempted; continuing")
}
return
}
if kind = "dungeon-shrine" {
if this.phase = "await-shrine-return" || !scan.Get("buttons",false)
return
action := r.app.model.preferences["DungeonShrineAction"]
this.Click(action = "Accept" ? 418 : 546,407), this.phase := "await-shrine-return"
r.app.Log("Shrine: " (action = "Accept" ? "Accept" : "Deny") "; waiting for Dungeon board")
return
}
if kind = "dungeon-chests" {
if scan.Get("normalEmpty",false) {
this.commonChestsExhausted := true
r.app.Log("No more common chests: confirmed popup; using rare chest row")
}
if scan.Get("rareEmpty",false)
this.rareChestsExhausted := true
if !scan.Get("continue",false)
return
for row in [["normal",259],["rare",319]] {
allowed := (r.app.model.preferences["DungeonNormalChests"]="Both" || (row[1]="normal" && r.app.model.preferences["DungeonNormalChests"]="Checkpoint")) || (this.HasOwnProp("bossCleared") && this.bossCleared)
if (row[1]="normal" && this.GetAttempts("commonChestsExhausted")) || (row[1]="rare" && this.GetAttempts("rareChestsExhausted"))
continue
count := scan.Get(row[1] "Count",-1)
if allowed && !scan.Get(row[1] "Empty",false) {
if count < 0
return
if count > 0 {
this.Click(565,row[2])
this.chestPending := true, this.chestRewardDismissed := false,this.chestType := row[1],this.chestEmptyFrames := 0,this.chestRewardReported := false,this.chestOpeningCounted := false
this.rewardNotBefore := Adventures.Tick()+2000
this.chestDeadline := Adventures.Tick()+45000
r.due := Adventures.Tick()+350
r.app.Log("Opening " row[1] " chest")
return
}
}
}
this.Click(485,407), this.phase := "board", this.chestsContinued := true
r.app.Log("Chest opening complete or deferred by settings; continuing Dungeon")
return
}
if kind = "dungeon-result" {
if this.phase != "result"
return
this.Click(488,121), this.phase := "board"
r.app.Log("Opening Dungeon route board")
return
}
if kind = "dungeon-board" && this.phase != "loading" {
this.commonChestsExhausted := false,this.rareChestsExhausted := false,this.chestEmptyFrames := 0
if this.phase = "details" && now-this.lastAction<2000
return
this.depth := scan["depth"]
if this.depth < 1 || this.depth > 20
throw Error("Dungeon depth is unreadable. Check the route board.")
this.hearts := scan.Get("hearts",-1)
if this.depth = 20
r.app.Log("Dungeon depth 20: checking boss room")
best := 0
roomOrder := this.depth = 20 ? ["Boss"] : AADungeons.Ordered(r.app.model.preferences["DungeonRoomPriority"],AADungeons.Rooms)
bestScore := -1
for card in scan.Get("cards",[]) {
score := AADungeons.PriorityScore(card,roomOrder)
if score>bestScore && score>0
best := card, bestScore := score
}
if !best {
if !this.HasOwnProp("unreadableBoardSince") || !this.unreadableBoardSince
this.unreadableBoardSince := now
if now-this.unreadableBoardSince>=20000 {
this.RejoinDiagnostic("No selectable room matched the configured priorities for 20 seconds; expected a bright frame and recognized Grey/Green/Purple/Boss card")
}
return
}
this.unreadableBoardSince := 0
if best["category"] = "Purple Room" {
for card in scan["cards"]
if card["category"]="Purple Room" && card.Get("available",true) && card["x"]<best["x"]
best:=card
}
this.pendingRoomMap := ""
this.Click(best["x"],best["y"]), this.phase := "details"
r.app.Log("Dungeon depth " this.depth ": selecting " best["category"])
return
}
if kind = "dungeon-room" && this.phase != "loading" {
if !scan.Has("enterX")
return
this.pendingRoomMap := AADungeons.MapName(scan.Get("map",""))
this.Click(scan["enterX"],scan["enterY"]), this.phase := "loading"
r.app.Log("Entering Dungeon room; waiting for transition map")
if r.app.HasOwnProp("owner") && r.app.owner.HasOwnProp("dungeonCycleDebug") && r.app.owner.dungeonCycleDebug && !(r.app.owner.HasOwnProp("dungeonBossDebug") && r.app.owner.dungeonBossDebug) {
r.app.owner.dungeonCycleDebug := false
r.app.Log("L Dungeon test complete: available room selected and Enter clicked")
r.Pause("L Dungeon test complete; room Enter clicked, no unit actions started")
}
return
}
if kind = "dungeon-map" && this.phase = "loading" {
name := scan["map"]
r.app.Log("Dungeon transition confirmed: " AADungeons.Diagnostic(scan))
r.app.LoadDungeonMap(name)
r.defeated := false, r.resultCounted := false
this.phase := "combat"
r.Change("AwaitVote",120000)
r.app.Log("Dungeon map detected: " name)
}
}
Click(x,y) {
r := this.runner
r.ClickAt(x,y)
this.minSerial := r.worker.serial+1, this.frames := 0, this.candidate := ""
this.lastAction := Adventures.Tick(),this.shopContinueFrames := 0
r.due := this.lastAction+350
r.deadline := Adventures.Tick()+120000
}
Resume(elapsed := 0) {
for field in ["deathWaitStarted","deathLastClick","deathLobbyLast","deathReturnLast",
"chestDeadline","rewardNotBefore","chestUnreadableSince","unreadableBoardSince","shopUnreadableSince","emptySince","lastAction"]
if this.HasOwnProp(field) && this.%field% > 0
this.%field% += elapsed
if this.HasOwnProp("shopPending") && this.shopPending.at > 0
this.shopPending.at += elapsed
this.minSerial := 0, this.frames := 0, this.candidate := "",this.shopContinueFrames := 0
if this.phase = "details"
this.phase := "board"
}
}
class AACurseEntryDebug {
phase := "details"
previous := ""
frames := 0
map := ""
Handle(scan) {
identity := ""
if this.phase="details" && scan.Get("kind","")="dungeon-room" && scan.Has("enterX") && scan.Has("enterY")
identity := scan["enterX"] "," scan["enterY"] "," scan.Get("map","")
if this.phase="map" && scan.Get("kind","")="dungeon-map" && AADungeons.MapName(scan.Get("map",""))!=""
identity := AADungeons.MapName(scan["map"])
if identity="" {
this.previous:="",this.frames:=0
return ""
}
this.frames := identity=this.previous ? this.frames+1 : 1,this.previous:=identity
if this.frames<2
return ""
this.previous:="",this.frames:=0
if this.phase="details" {
this.phase:="map"
return "enter"
}
this.map:=identity,this.phase:="done"
return "done"
}
}
SetWorkingDir(A_ScriptDir)
launchTick := DllCall("GetTickCount64","UInt64")
if A_Args.Length >= 2 && A_Args[1] = "--restart-from" {
parent := Integer(A_Args[2])
if parent > 0
ProcessWaitClose(parent,8)
if parent <= 0 || ProcessExist(parent) {
MsgBox("Restart could not finish because the previous macro did not close. Close it and open Start Macro.cmd.","Bayzo's AA Macro v2.2")
ExitApp(1)
}
A_Args.RemoveAt(1,2)
}
AADungeons.Register()
if A_Args.Length>=3 && A_Args[1]="--ocr-worker" {
StoryOcrWorker(A_Args[2],Integer(A_Args[3]))
ExitApp()
}
A_Args := []
mutexName := "Local\BayzoAAMacroInteractive"
if !AAInstance.Acquire(mutexName)
ExitApp()
SendMode("Event")
DetectHiddenWindows(true)
A_IconHidden := false
A_IconTip := "Bayzo's AA Macro v2.2"
AAInstalledAssets.Ensure()
AAAprilFools.Register()
if FileExist(CrusadersTheme.AppIcon)
TraySetIcon(CrusadersTheme.AppIcon,1,true)
global testCancelled := false, testRunning := false
global afkMonitor := 0, joinErrorMonitor := 0, challengeSchedule := 0
OnError(HandleMacroError)
OnExit(ObjBindMethod(CrusadersRuntime,"ReleaseControls"))
OnExit(ObjBindMethod(CrusadersWebhook,"CancelAll"))
previousWindowDelay := A_WinDelay
SetWinDelay(-1)
try {
global selector := CrusadersCreateSelector()
global macroWindow := AAWindow()
} catch Error as err {
MsgBox("The macro could not open.`n`n" err.Message "`nLine " err.Line,"Bayzo's AA Macro v2.2","Iconx")
ExitApp(1)
}
finally SetWinDelay(previousWindowDelay)
A_TrayMenu.Add("Indexes",(*)=>selector.Show())

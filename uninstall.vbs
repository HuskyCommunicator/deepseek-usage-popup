' ============================================================
'  uninstall.vbs  --  remove deepseek-usage-popup
'
'      cscript //nologo uninstall.vbs            remove the Win+R alias only
'      cscript //nologo uninstall.vbs --purge    also delete ds.vbs and
'                                                ds-template.html
'
'  Your DS_USER_TOKEN / ds-token.txt is never touched by this script.
'
'  ------------------------------------------------------------------
'  THIS FILE MUST STAY PURE ASCII. DO NOT ADD NON-ASCII CHARACTERS.
'  See the note at the top of install.vbs for the reason.
'  ------------------------------------------------------------------
' ============================================================

Option Explicit

Dim fso, sh, IS_CONSOLE, gLog

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
IS_CONSOLE = (LCase(Right(WScript.FullName, 11)) = "cscript.exe")
gLog = ""

Main

Sub Main()
  Dim regKey, installDir, dsVbs, tpl, purge, i, a

  regKey = "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe\"
  purge  = False
  installDir = ""

  For i = 0 To WScript.Arguments.Count - 1
    a = WScript.Arguments(i)
    If LCase(a) = "--purge" Then
      purge = True
    Else
      installDir = a
    End If
  Next

  ' Remember where ds.vbs lives before the registry entry goes away
  If installDir = "" Then
    On Error Resume Next
    installDir = sh.RegRead(regKey)
    On Error GoTo 0
    If InStr(installDir, "%") > 0 Then installDir = ""
  End If
  If installDir <> "" Then installDir = fso.GetParentFolderName(installDir)

  ' --- registry --------------------------------------------------
  On Error Resume Next
  sh.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe\Path"
  sh.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe\"
  sh.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe"
  If Err.Number <> 0 Then
    Err.Clear
    Say "[--] no Win+R alias found (already removed?)"
  Else
    Say "[ok] removed Win+R alias : ds"
  End If
  On Error GoTo 0

  ' --- files -----------------------------------------------------
  If purge Then
    If installDir = "" Then
      Say "[--] --purge: install directory unknown, nothing deleted"
    Else
      dsVbs = fso.BuildPath(installDir, "ds.vbs")
      tpl   = fso.BuildPath(installDir, "ds-template.html")
      RemoveFile dsVbs
      RemoveFile tpl
      Say "[ok] purged files in " & installDir
    End If
  Else
    Say "[--] files kept (pass --purge to delete them)"
  End If

  Say ""
  Say "Done. Your ds-token.txt (if any) was left untouched."
  Quit 0
End Sub

Sub RemoveFile(path)
  On Error Resume Next
  If fso.FileExists(path) Then fso.DeleteFile path, True
  If Err.Number <> 0 Then
    Say "[!!] could not delete " & path & " : " & Err.Description
    Err.Clear
  Else
    Say "[ok] deleted " & path
  End If
  On Error GoTo 0
End Sub

Sub Say(s)
  If IS_CONSOLE Then
    WScript.Echo s
  Else
    gLog = gLog & s & vbCrLf
  End If
End Sub

Sub Quit(code)
  If Not IS_CONSOLE Then
    If gLog <> "" Then MsgBox gLog, 64, "deepseek-usage-popup"
  End If
  WScript.Quit code
End Sub

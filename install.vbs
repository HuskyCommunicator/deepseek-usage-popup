' ============================================================
'  install.vbs  --  one-shot installer for deepseek-usage-popup
'
'  Press Win+R, type "ds", get a card with your DeepSeek balance
'  and today's usage.
'
'  RUN IT UNDER cscript SO YOU CAN READ THE OUTPUT:
'      cscript //nologo install.vbs
'
'  Options:
'      install.vbs [TARGET_DIR] [--no-reg]
'        TARGET_DIR   where ds.vbs / ds-template.html get installed
'                     (default: %USERPROFILE%\.claude\bin)
'        --no-reg     skip the "App Paths" registry write
'
'  Environment:
'      DS_USER_TOKEN  if set and ds-token.txt does not exist yet, its
'                     value is written to %USERPROFILE%\.claude\ds-token.txt
'
'  ------------------------------------------------------------------
'  THIS FILE MUST STAY PURE ASCII. DO NOT ADD NON-ASCII CHARACTERS.
'
'  WSH reads a .vbs file as ANSI unless it starts with a UTF-16LE BOM.
'  Non-ASCII text here would turn into mojibake on any machine whose
'  ANSI codepage is not UTF-8. That is also why the installer speaks
'  English: all Chinese documentation lives in README.md instead.
'  (src\ds-src.vbs has the same constraint, but it is transcoded to
'  UTF-16LE by this installer before ever being executed.)
'  ------------------------------------------------------------------
' ============================================================

Option Explicit

Dim fso, sh, IS_CONSOLE, gLog

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
IS_CONSOLE = (LCase(Right(WScript.FullName, 11)) = "cscript.exe")
gLog = ""

Main

' ---------------------------------------------------------------- main
Sub Main()
  Dim repoRoot, srcDir, targetDir, doReg, i, a, dsVbs, tplTgt

  repoRoot  = fso.GetParentFolderName(WScript.ScriptFullName)
  srcDir    = fso.BuildPath(repoRoot, "src")
  targetDir = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.claude\bin"
  doReg     = True

  For i = 0 To WScript.Arguments.Count - 1
    a = WScript.Arguments(i)
    If LCase(a) = "--no-reg" Then
      doReg = False
    Else
      targetDir = a
    End If
  Next

  Say "deepseek-usage-popup installer"
  Say "  repo   : " & repoRoot
  Say "  target : " & targetDir
  Say ""

  ' --- 1. sources present ---------------------------------------
  If Not fso.FileExists(fso.BuildPath(srcDir, "ds-src.vbs")) Then
    Say "[FAIL] src\ds-src.vbs not found - run install.vbs from the repo root."
    Quit 1
  End If
  If Not fso.FileExists(fso.BuildPath(srcDir, "ds-template.html")) Then
    Say "[FAIL] src\ds-template.html not found."
    Quit 1
  End If

  ' --- 2. target directory --------------------------------------
  If Not fso.FolderExists(targetDir) Then
    On Error Resume Next
    fso.CreateFolder targetDir
    If Err.Number <> 0 Then
      Say "[FAIL] cannot create " & targetDir & " : " & Err.Description
      Quit 1
    End If
    On Error GoTo 0
    Say "[ok] created " & targetDir
  Else
    Say "[ok] target directory exists"
  End If

  ' --- 3. transcode ds-src.vbs (UTF-8) -> ds.vbs (UTF-16LE) -----
  dsVbs = fso.BuildPath(targetDir, "ds.vbs")
  If Not Transcode(fso.BuildPath(srcDir, "ds-src.vbs"), dsVbs) Then
    Say "[FAIL] transcode failed - is src\ds-src.vbs valid UTF-8?"
    Quit 1
  End If
  Say "[ok] " & dsVbs & "  (UTF-16LE with BOM)"

  ' --- 4. copy the HTA template ---------------------------------
  tplTgt = fso.BuildPath(targetDir, "ds-template.html")
  On Error Resume Next
  fso.CopyFile fso.BuildPath(srcDir, "ds-template.html"), tplTgt, True
  If Err.Number <> 0 Then
    Say "[FAIL] cannot copy template: " & Err.Description
    Quit 1
  End If
  On Error GoTo 0
  Say "[ok] " & tplTgt

  ' --- 5. Win+R alias -------------------------------------------
  If doReg Then
    On Error Resume Next
    sh.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe\", _
                dsVbs, "REG_SZ"
    sh.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe\Path", _
                targetDir, "REG_SZ"
    If Err.Number <> 0 Then
      Say "[FAIL] registry write failed: " & Err.Description
      Quit 1
    End If
    On Error GoTo 0
    Say "[ok] Win+R alias registered : ds"
  Else
    Say "[--] registry write skipped (--no-reg)"
  End If

  ' --- 6. userToken ---------------------------------------------
  Say ""
  If EnsureToken() Then
    Say "[ok] ds-token.txt present - usage will come from the official API"
  Else
    Say "[!!] ds-token.txt MISSING - the card will fall back to local stats."
    Say "     Fix: see README.md > Getting your userToken"
    Say "     Then save it to: " & sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.claude\ds-token.txt"
  End If

  Say ""
  Say "Done.  Press Win+R and type:  ds"
  Say "Self-test (prints text instead of popping the card):"
  Say "  cscript //nologo """ & dsVbs & """"
  Quit 0
End Sub

' --------------------------------------------------- UTF-8 -> UTF-16LE
' ADODB.Stream with Charset="unicode" emits a UTF-16LE BOM, which is
' exactly what wscript needs to read the Chinese literals correctly.
Function Transcode(srcPath, dstPath)
  Dim st, outStream, body

  Transcode = False
  On Error Resume Next

  Set st = CreateObject("ADODB.Stream")
  st.Type = 2
  st.Charset = "utf-8"
  st.Open
  st.LoadFromFile srcPath
  body = st.ReadText
  st.Close
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If

  Set outStream = CreateObject("ADODB.Stream")
  outStream.Type = 2
  outStream.Charset = "unicode"
  outStream.Open
  outStream.WriteText body
  outStream.SaveToFile dstPath, 2
  outStream.Close
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If

  On Error GoTo 0
  Transcode = fso.FileExists(dstPath)
End Function

' ------------------------------------------------------- userToken file
Function EnsureToken()
  Dim tokPath, envTok, ts

  EnsureToken = False
  tokPath = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.claude\ds-token.txt"

  If fso.FileExists(tokPath) Then
    EnsureToken = True
    Exit Function
  End If

  ' ExpandEnvironmentStrings leaves the literal text when a var is unset
  envTok = sh.ExpandEnvironmentStrings("%DS_USER_TOKEN%")
  If InStr(envTok, "%") > 0 Then Exit Function

  On Error Resume Next
  ' ASCII (not Unicode): a BOM would corrupt the token when ds.vbs reads
  ' it back with FileSystemObject.OpenTextFile.
  Set ts = fso.CreateTextFile(tokPath, True, False)
  ts.Write Trim(envTok)
  ts.Close
  On Error GoTo 0

  EnsureToken = fso.FileExists(tokPath)
End Function

' ------------------------------------------------------------ logging
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

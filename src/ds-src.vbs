Option Explicit

' ============================================================
'  ds.vbs  --  Win+R 输入 ds，弹窗显示 DeepSeek 余额与今日用量
'
'  仓库
'    https://github.com/HuskyCommunicator/deepseek-usage-popup
'
'  本文件是 UTF-8（无 BOM）源码，必须由 install.vbs / build.vbs 转成
'  UTF-16LE 才能被 wscript 正确执行（否则中文会乱码）。
'
'  数据来源
'    余额  ->  https://api.deepseek.com/user/balance
'               （API key 读自 ~/.claude/settings.json）
'    用量  ->  https://platform.deepseek.com/api/v0/usage/{amount,cost}
'               （userToken 读自 ~/.claude/ds-token.txt）
'    兜底  ->  本地 Claude Code 会话记录 ~/.claude/projects/**/*.jsonl
'
'  用 cscript 运行会输出到控制台而不是弹窗，便于自检。
' ============================================================

Dim sh, fso, IS_CONSOLE, HOME, SCRIPT_DIR

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
HOME = sh.ExpandEnvironmentStrings("%USERPROFILE%")
' 模板跟脚本放在一起，这样装到哪个目录都能找到
SCRIPT_DIR = fso.GetParentFolderName(WScript.ScriptFullName)
IS_CONSOLE = (LCase(Right(WScript.FullName, 11)) = "cscript.exe")

' ==================== 一、余额 ====================
Dim apiKey, balOk, bal
apiKey = ReadApiKey()
balOk = False
bal = 0
If apiKey <> "" Then FetchBalance apiKey, balOk, bal

' ==================== 二、官网用量 ====================
Dim userToken, oReq, oIn, oOut, oHit, oCost, usageOk
userToken = ReadFileTrim(HOME & "\.claude\ds-token.txt")
usageOk = False
oReq = 0 : oIn = 0 : oOut = 0 : oHit = 0 : oCost = 0
If userToken <> "" Then usageOk = FetchOfficialUsage(userToken, oReq, oIn, oOut, oHit, oCost)

' ==================== 三、本地兜底 ====================
Dim lReq, lIn, lOut, lHit, lCC
lReq = 0 : lIn = 0 : lOut = 0 : lHit = 0 : lCC = 0
If Not usageOk Then CollectLocalStats lReq, lIn, lOut, lHit, lCC

' ==================== 四、输出 ====================
Dim vDate, vBalance, vCost, vReq, vIn, vOut, vCache, vTotal, vPct, vSource
Dim plain

vDate = DateKey(Date())
If balOk Then vBalance = FormatNumber(bal, 2, -1, 0, 0) Else vBalance = "--"

If usageOk Then
  vCost   = FormatNumber(oCost, 2, -1, 0, 0)
  vReq    = Thousands(oReq)
  vIn     = Thousands(oIn)
  vOut    = Thousands(oOut)
  vCache  = Thousands(oHit)
  vTotal  = Thousands(oIn + oHit + oOut)
  If (oHit + oIn) > 0 Then vPct = FormatNumber(oHit / (oHit + oIn) * 100, 1, -1, 0, 0) Else vPct = "0"
  vSource = "官方接口"
Else
  vCost   = "--"
  vReq    = Thousands(lReq)
  vIn     = Thousands(lIn + lCC)
  vOut    = Thousands(lOut)
  vCache  = Thousands(lCC)
  vTotal  = Thousands(lIn + lCC + lOut)
  If (lIn + lCC) > 0 Then vPct = FormatNumber(lCC / (lIn + lCC) * 100, 1, -1, 0, 0) Else vPct = "0"
  If userToken = "" Then vSource = "本地统计" Else vSource = "登录态过期 · 本地统计"
End If

If IS_CONSOLE Then
  ' 控制台模式：纯文本自检
  plain = "剩余余额：CNY " & vBalance & vbCrLf
  plain = plain & "今日消费：CNY " & vCost & vbCrLf & vbCrLf
  plain = plain & "请求次数：" & vReq & " 次" & vbCrLf
  plain = plain & "输入 Token：" & vIn & vbCrLf
  plain = plain & "输出 Token：" & vOut & vbCrLf
  plain = plain & "缓存读取：" & vCache & vbCrLf
  plain = plain & "Tokens 合计：" & vTotal & vbCrLf
  plain = plain & "缓存命中率：" & vPct & "%" & vbCrLf & vbCrLf
  plain = plain & "（数据来源：" & vSource & "）"
  WScript.Echo plain
Else
  ShowPopup
End If

' ==================== 读 API Key ====================
Function ReadApiKey()
  Dim path, body, m
  ReadApiKey = ""
  path = HOME & "\.claude\settings.json"
  If Not fso.FileExists(path) Then Exit Function

  On Error Resume Next
  Dim st
  Set st = CreateObject("ADODB.Stream")
  st.Type = 2
  st.Charset = "utf-8"
  st.Open
  st.LoadFromFile path
  body = st.ReadText
  st.Close
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If
  On Error GoTo 0

  Set m = New RegExp
  m.Pattern = """ANTHROPIC_AUTH_TOKEN""\s*:\s*""([^""]+)"""
  If m.Test(body) Then ReadApiKey = m.Execute(body)(0).SubMatches(0)
End Function

' ==================== 读纯文本文件 ====================
Function ReadFileTrim(path)
  Dim f, s
  ReadFileTrim = ""
  If Not fso.FileExists(path) Then Exit Function
  On Error Resume Next
  Set f = fso.OpenTextFile(path, 1)
  s = f.ReadAll
  f.Close
  On Error GoTo 0
  s = Replace(s, vbCr, "")
  s = Replace(s, vbLf, "")
  ReadFileTrim = Trim(s)
End Function

' ==================== 余额查询 ====================
Sub FetchBalance(key, ByRef ok, ByRef value)
  Dim http, m
  ok = False
  value = 0

  On Error Resume Next
  Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
  http.Open "GET", "https://api.deepseek.com/user/balance", False
  http.SetRequestHeader "Authorization", "Bearer " & key
  http.SetRequestHeader "Accept", "application/json"
  http.SetTimeouts 5000, 5000, 10000, 15000
  http.Send
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Sub
  End If
  On Error GoTo 0

  If http.Status <> 200 Then Exit Sub

  Set m = New RegExp
  m.Pattern = """total_balance""\s*:\s*""([^""]+)"""
  If m.Test(http.ResponseText) Then
    value = CDbl(m.Execute(http.ResponseText)(0).SubMatches(0))
    ok = True
  End If
End Sub

' ==================== 官网用量（amount + cost） ====================
Function FetchOfficialUsage(tok, ByRef req, ByRef miss, ByRef outTok, ByRef hit, ByRef cost)
  Dim y, mth, dayKey, amtJson, costJson, amtDay, costDay
  Dim aP, aH, aM, aO, aR, cP, cH, cM, cO, cR

  FetchOfficialUsage = False
  req = 0 : miss = 0 : outTok = 0 : hit = 0 : cost = 0

  y = Year(Date())
  mth = Month(Date())
  dayKey = DateKey(Date())

  amtJson = HttpGetOfficial("https://platform.deepseek.com/api/v0/usage/amount?year=" & y & "&month=" & mth, tok)
  If amtJson = "" Then Exit Function
  costJson = HttpGetOfficial("https://platform.deepseek.com/api/v0/usage/cost?year=" & y & "&month=" & mth, tok)
  If costJson = "" Then Exit Function

  amtDay = SliceDay(amtJson, dayKey)
  costDay = SliceDay(costJson, dayKey)
  If amtDay = "" Then Exit Function

  aP = 0 : aH = 0 : aM = 0 : aO = 0 : aR = 0
  ParseUsage amtDay, aP, aH, aM, aO, aR

  cP = 0 : cH = 0 : cM = 0 : cO = 0 : cR = 0
  If costDay <> "" Then ParseUsage costDay, cP, cH, cM, cO, cR

  req = aR
  hit = aH
  miss = aM
  outTok = aO
  cost = cP + cH + cM + cO + cR

  FetchOfficialUsage = True
End Function

Function HttpGetOfficial(url, tok)
  Dim http
  HttpGetOfficial = ""
  On Error Resume Next
  Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
  http.Open "GET", url, False
  http.SetRequestHeader "authorization", "Bearer " & tok
  http.SetRequestHeader "accept", "*/*"
  http.SetRequestHeader "user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36 Edg/155.0.0.0"
  http.SetRequestHeader "x-client-bundle-id", "com.deepseek.chat"
  http.SetRequestHeader "x-client-locale", "zh_CN"
  http.SetRequestHeader "x-client-platform", "web"
  http.SetRequestHeader "x-client-timezone-offset", CStr(LocalOffsetMinutes() * 60)
  http.SetRequestHeader "x-client-version", "1.0.0"
  http.SetRequestHeader "referer", "https://platform.deepseek.com/usage"
  http.SetTimeouts 5000, 5000, 10000, 20000
  http.Send
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If
  On Error GoTo 0
  If http.Status = 200 Then HttpGetOfficial = http.ResponseText
End Function

' 从整月 JSON 里切出指定日期那一段（到下一个 "date":" 为止）
Function SliceDay(json, dayKey)
  Dim p, rest, nxt
  SliceDay = ""
  p = InStr(json, """date"":""" & dayKey & """")
  If p = 0 Then Exit Function
  rest = Mid(json, p)
  nxt = InStr(rest, """date"":""")
  nxt = InStr(nxt + 1, rest, """date"":""")
  If nxt > 0 Then rest = Left(rest, nxt - 1)
  SliceDay = rest
End Function

' 从一段 JSON 里把各模型的 usage 累加起来
Sub ParseUsage(slice, ByRef prompt, ByRef hit, ByRef miss, ByRef outTok, ByRef req)
  Dim re, re2, m, m2, usageStr, t, v
  Set re = New RegExp
  re.Pattern = """usage""\s*:\s*\[([^\]]*)\]"
  re.Global = True

  Set re2 = New RegExp
  re2.Pattern = """type""\s*:\s*""([A-Z_]+)""\s*,\s*""amount""\s*:\s*""([^""]+)"""
  re2.Global = True

  For Each m In re.Execute(slice)
    usageStr = m.SubMatches(0)
    For Each m2 In re2.Execute(usageStr)
      t = m2.SubMatches(0)
      v = CDbl(m2.SubMatches(1))
      Select Case t
        Case "PROMPT_TOKEN"
          prompt = prompt + v
        Case "PROMPT_CACHE_HIT_TOKEN"
          hit = hit + v
        Case "PROMPT_CACHE_MISS_TOKEN"
          miss = miss + v
        Case "RESPONSE_TOKEN"
          outTok = outTok + v
        Case "REQUEST"
          req = req + v
      End Select
    Next
  Next
End Sub

' ==================== 本地统计（兜底） ====================
Dim gTzMin, gUtcStart, gUtcEnd
Dim gReq, gIn, gOut, gCR, gCC
Dim gReTs, gReId, gReUsage

Sub CollectLocalStats(ByRef req, ByRef inTok, ByRef outTok, ByRef hitCR, ByRef hitCC)
  Dim root, uStart

  gReq = 0 : gIn = 0 : gOut = 0 : gCR = 0 : gCC = 0

  Set gReTs = New RegExp
  gReTs.Pattern = """timestamp""\s*:\s*""([^""]+)"""

  Set gReId = New RegExp
  gReId.Pattern = """id""\s*:\s*""([^""]+)"""

  ' usage 字段用正则抓；JSON 里的 \" 被转义，所以匹配不到别的同名 key
  Set gReUsage = New RegExp
  gReUsage.Pattern = """input_tokens""\s*:\s*(\d+)\s*,\s*" & _
                     """cache_creation_input_tokens""\s*:\s*(\d+)\s*,\s*" & _
                     """cache_read_input_tokens""\s*:\s*(\d+)\s*,\s*" & _
                     """output_tokens""\s*:\s*(\d+)"

  gTzMin = LocalOffsetMinutes()
  uStart = DateAdd("n", -gTzMin, Date())
  gUtcStart = IsoKey(uStart)
  gUtcEnd = IsoKey(DateAdd("d", 1, uStart))

  root = HOME & "\.claude\projects"
  If Not fso.FolderExists(root) Then
    req = 0 : inTok = 0 : outTok = 0 : hitCR = 0 : hitCC = 0
    Exit Sub
  End If

  On Error Resume Next
  WalkLocal fso.GetFolder(root)
  On Error GoTo 0

  req = gReq : inTok = gIn : outTok = gOut : hitCR = gCR : hitCC = gCC
End Sub

Sub WalkLocal(folder)
  Dim f, subf
  On Error Resume Next
  For Each f In folder.Files
    If LCase(fso.GetExtensionName(f.Name)) = "jsonl" Then
      ' 只读今天改动过的文件
      If DateValue(f.DateLastModified) = Date() Then ProcessLocalFile f.Path
    End If
  Next
  On Error GoTo 0
  For Each subf In folder.SubFolders
    WalkLocal subf
  Next
End Sub

Sub ProcessLocalFile(path)
  Dim ts, line, tsStr, t19, lid, mc
  Dim nIn, nCC, nCR, nOut, prev
  Dim seen
  Set seen = CreateObject("Scripting.Dictionary")

  On Error Resume Next
  Set ts = fso.OpenTextFile(path, 1)
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Sub
  End If

  Do Until ts.AtEndOfStream
    line = ts.ReadLine
    If InStr(line, """cache_read_input_tokens""") > 0 Then
      tsStr = GetField(gReTs, line)
      If tsStr <> "" Then
        t19 = Left(tsStr, 19)
        If t19 >= gUtcStart And t19 < gUtcEnd Then
          lid = GetField(gReId, line)
          If lid <> "" Then
            If gReUsage.Test(line) Then
              Set mc = gReUsage.Execute(line)(0)
              nIn  = CLng(mc.SubMatches(0))
              nCC  = CLng(mc.SubMatches(1))
              nCR  = CLng(mc.SubMatches(2))
              nOut = CLng(mc.SubMatches(3))
              If seen.Exists(lid) Then
                ' 同一条响应流式写入多条，只有最后一条带完整 usage，先撤掉再记新的
                prev = seen(lid)
                gIn  = gIn  - prev(0)
                gCC  = gCC  - prev(1)
                gCR  = gCR  - prev(2)
                gOut = gOut - prev(3)
              Else
                gReq = gReq + 1
              End If
              gIn  = gIn  + nIn
              gCC  = gCC  + nCC
              gCR  = gCR  + nCR
              gOut = gOut + nOut
              seen(lid) = Array(nIn, nCC, nCR, nOut)
            End If
          End If
        End If
      End If
    End If
  Loop
  ts.Close
  On Error GoTo 0
End Sub

Function GetField(re, line)
  GetField = ""
  If re.Test(line) Then GetField = re.Execute(line)(0).SubMatches(0)
End Function

' ==================== 工具函数 ====================
Function LocalOffsetMinutes()
  Dim v
  On Error Resume Next
  v = sh.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\ActiveTimeBias")
  On Error GoTo 0

  If Not IsNumeric(v) Then
    LocalOffsetMinutes = 480          ' 拿不到就按 UTC+8 算
    Exit Function
  End If

  ' 注册表里是带符号的 DWORD，可能被读成 4294966816 这种，先还原
  v = CDbl(v)
  If v >= 2147483648 Then v = v - 4294967296
  LocalOffsetMinutes = -CLng(v)
End Function

Function IsoKey(d)
  IsoKey = Year(d) & "-" & Right("0" & Month(d), 2) & "-" & Right("0" & Day(d), 2) & "T" & _
           Right("0" & Hour(d), 2) & ":" & Right("0" & Minute(d), 2) & ":" & Right("0" & Second(d), 2)
End Function

Function DateKey(d)
  DateKey = Year(d) & "-" & Right("0" & Month(d), 2) & "-" & Right("0" & Day(d), 2)
End Function

Function Money2(v)
  Money2 = "¥" & FormatNumber(v, 2, -1, 0, 0)
End Function

Function Pct(a, b)
  If b = 0 Then
    Pct = "--"
  Else
    Pct = FormatNumber(a / b * 100, 1) & "%"
  End If
End Function

Function Thousands(n)
  Dim s, out, i, c
  s = CStr(CLng(n))
  out = ""
  i = 0
  For c = Len(s) To 1 Step -1
    out = Mid(s, c, 1) & out
    i = i + 1
    If i Mod 3 = 0 And c > 1 Then out = "," & out
  Next
  Thousands = out
End Function

Function IIf(cond, a, b)
  If cond Then IIf = a Else IIf = b
End Function

Sub ShowMsg(text, icon)
  If IS_CONSOLE Then
    WScript.Echo text
  Else
    MsgBox text, icon, "DeepSeek 用量"
  End If
End Sub

' ==================== 弹窗渲染（HTA） ====================
Sub ShowPopup()
  Dim tplPath, tmpPath, body

  tplPath = SCRIPT_DIR & "\ds-template.html"
  If Not fso.FileExists(tplPath) Then
    ShowMsg "缺少模板文件：" & vbCrLf & tplPath, 16
    Exit Sub
  End If

  body = ReadUtf8(tplPath)
  If body = "" Then
    ShowMsg "模板读取失败：" & vbCrLf & tplPath, 16
    Exit Sub
  End If

  body = Replace(body, "{{DATE}}",    vDate)
  body = Replace(body, "{{BALANCE}}", vBalance)
  body = Replace(body, "{{COST}}",    vCost)
  body = Replace(body, "{{REQ}}",     vReq)
  body = Replace(body, "{{IN_TOK}}",  vIn)
  body = Replace(body, "{{OUT_TOK}}", vOut)
  body = Replace(body, "{{CACHE}}",   vCache)
  body = Replace(body, "{{TOTAL}}",   vTotal)
  body = Replace(body, "{{HIT_PCT}}", vPct)
  body = Replace(body, "{{SOURCE}}",  vSource)

  tmpPath = sh.ExpandEnvironmentStrings("%TEMP%") & "\ds-popup.hta"
  If Not WriteUtf8(tmpPath, body) Then
    ShowMsg "写入临时文件失败：" & vbCrLf & tmpPath, 16
    Exit Sub
  End If

  On Error Resume Next
  sh.Run "mshta.exe """ & tmpPath & """", 1, False
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    ShowMsg "弹窗启动失败（mshta）", 16
    Exit Sub
  End If
  On Error GoTo 0
End Sub

' ADODB.Stream 读写 UTF-8；不带 BOM，否则 IE 会掉进怪癖模式
Function ReadUtf8(path)
  Dim st
  ReadUtf8 = ""
  On Error Resume Next
  Set st = CreateObject("ADODB.Stream")
  st.Type = 2
  st.Charset = "utf-8"
  st.Open
  st.LoadFromFile path
  ReadUtf8 = st.ReadText
  st.Close
  If Err.Number <> 0 Then
    Err.Clear
    ReadUtf8 = ""
  End If
  On Error GoTo 0
End Function

' 注意：ADODB.Stream 写 UTF-8 会自带 BOM，BOM 落在 <!DOCTYPE> 之前会让 IE 掉进
' 怪癖模式（CSS 全部失准），所以写完后切二进制把前 3 个字节剪掉
Function WriteUtf8(path, body)
  Dim st, bin
  WriteUtf8 = False
  On Error Resume Next
  Set st = CreateObject("ADODB.Stream")
  st.Type = 2
  st.Charset = "utf-8"
  st.Open
  st.WriteText body
  st.Position = 0
  st.Type = 1                 ' 切到二进制流；此时 Position 必须为 0
  If st.Size >= 3 Then st.Position = 3

  Set bin = CreateObject("ADODB.Stream")
  bin.Type = 1
  bin.Open
  st.CopyTo bin
  bin.SaveToFile path, 2
  bin.Close
  st.Close

  If Err.Number = 0 Then
    WriteUtf8 = True
  Else
    Err.Clear
  End If
  On Error GoTo 0
End Function

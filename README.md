# deepseek-usage-popup

> 按 `Win+R` 输入 `ds`，弹出一张卡片，显示你的 DeepSeek 账户余额和今日用量。
>
> Press `Win+R`, type `ds`, get a card with your DeepSeek balance and today's usage.

一个纯 Windows 脚本（VBScript + HTA），**零依赖**——不用装 Node、Python、PowerShell 模块。
装一个文件，注册一个注册表键，就完事。

[English documentation ↓](#english)

---

## 效果

```
┌──────────────────────────────────────┐
│ ◆ DeepSeek 用量           2026-10-10 │
│                                      │
│ 剩余余额             CNY 15.45       │
│ 今日消费             CNY  8.14       │
│ ──────────────────────────────────── │
│ 请求次数                   578 次    │
│ 输入 Token              1,164,583    │
│ 输出 Token                648,602    │
│ 缓存读取               27,199,232    │
│ Tokens 合计            29,012,417    │
│                                      │
│ 缓存命中率                  95.9%    │
│ ████████████████████████████░░░░     │
│                                      │
│ 官方接口                  Esc 关闭   │
└──────────────────────────────────────┘
```

窗口按内容高度自适应并居中，`Esc` / `空格` / `回车` 关闭。

---

## 前置条件

| 要求 | 说明 |
|---|---|
| Windows | 任何带 `wscript.exe` / `mshta.exe` 的版本（Win7 及以上都行） |
| Claude Code | 用来提供 API key，脚本从 `~/.claude/settings.json` 里读 |
| DeepSeek API key | 在 <https://platform.deepseek.com/api_keys> 创建，`sk-` 开头 |
| DeepSeek 账号登录态 | 就是 userToken，见下面[「获取 userToken」](#获取-usertoken) |

> **只用 Claude Code + DeepSeek 的 Anthropic 兼容端点的用户**，`settings.json` 里通常已经有
> `ANTHROPIC_AUTH_TOKEN`，脚本直接就能读到，不用额外配置。

---

## 快速开始

```bat
git clone https://github.com/HuskyCommunicator/deepseek-usage-popup.git
cd deepseek-usage-popup
cscript //nologo install.vbs
```

> 用 `cscript` 跑而不是双击——这样你能看到输出。双击也能用，只是结果会汇总到一个提示框里。

安装器会做四件事：

1. 把 `src/ds-src.vbs` 从 UTF-8 转码成 **UTF-16LE**，写成 `%USERPROFILE%\.claude\bin\ds.vbs`
2. 复制 `src/ds-template.html` 到 `%USERPROFILE%\.claude\bin\`
3. 写注册表 `HKCU\...\App Paths\ds.exe`，让 `Win+R` 认得 `ds`
4. 检查 `%USERPROFILE%\.claude\ds-token.txt` 是否存在

如果第 4 步报 `[!!] ds-token.txt MISSING`，去下一节。否则 **按 `Win+R` 输入 `ds` 收工**。

---

## 获取 userToken

**这是唯一需要手动做的一步。** userToken 是你在 DeepSeek 网页版的登录态，
不是 `sk-` 开头的 API key——两者完全不同，别混。

1. 浏览器打开 <https://platform.deepseek.com/usage>，确保已登录
2. 按 `F12` 打开开发者工具，切到 **Network / 网络** 面板
3. **刷新页面**（`F5`）
4. 在筛选框里输入 `api/v0`，找一条叫 `amount` 或 `cost` 的请求
   （找不到就用 `get_api_keys` 也行，只要有 `authorization` 头）
5. 点开该请求 → **Headers / 标头** → **Request Headers / 请求标头**
6. 复制 `authorization` 的值，形如：

   ```
   Bearer aB3dEf6hIj9kLm2nOp5qRs8tUv1wXy4zA7cD0eF3gH6iJ9kLm2nOp5qRs8tU
   ```

7. 去掉开头的 `Bearer `（连同那个空格），剩下的一长串就是 userToken

8. 把它存成一个纯文本文件：

   ```
   %USERPROFILE%\.claude\ds-token.txt
   ```

   **文件里只有这一行 token，不要有换行符、不要有空格、不要有其他内容。**

用记事本的坑：记事本默认会加一个 UTF-8 BOM，也可能在末尾加换行。
最稳的做法是用命令行写：

```bat
> "%USERPROFILE%\.claude\ds-token.txt" echo 把token粘到这里
```

（`>` 加 `echo` 会写入一行并以 CRLF 结尾——脚本读取时会自动 `Trim` 掉换行和空白，没问题。）

### 自动化安装时怎么传 token

`install.vbs` 支持从环境变量读：

```bat
set DS_USER_TOKEN=aB3dEf6hIj9kLm2nOp5qRs8tUv1wXy4zA7cD0eF3gH6iJ9kLm2n...
cscript //nologo install.vbs
```

`install.vbs` 只在 `ds-token.txt` **不存在**时才写——已经有的文件不会被覆盖。

### 它会过期吗

会。userToken 就是浏览器登录态，通常几周到几个月。失效后卡片会显示
**「登录态过期 · 本地统计」**，数字退回本地 transcript 口径（和官网对不上）。
按上面步骤重新抓一个覆盖 `ds-token.txt` 即可。

---

## 验证

```bat
cscript //nologo "%USERPROFILE%\.claude\bin\ds.vbs"
```

`cscript` 模式下脚本输出纯文本而不是弹窗，方便排查：

```
剩余余额：CNY 15.45
今日消费：CNY 8.14

请求次数：578 次
输入 Token：1,164,583
...
（数据来源：官方接口）
```

- 看到 `（数据来源：官方接口）` → 一切正常
- 看到 `（数据来源：本地统计）` → 没找到 token
- 看到 `（数据来源：登录态过期 · 本地统计）` → token 失效了，重新抓
- 余额显示 `--` → `settings.json` 里没有 `ANTHROPIC_AUTH_TOKEN`

---

## 手动安装

不想跑 `install.vbs`，或者想搞清楚它到底干了什么，照下面做。

### 方式 A：半自动（推荐）

`install.vbs` 可以只做转码和复制，不碰注册表：

```bat
cscript //nologo install.vbs "%USERPROFILE%\.claude\bin" --no-reg
```

然后手动注册 `Win+R` 别名：

```bat
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe" /ve /d "%USERPROFILE%\.claude\bin\ds.vbs" /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe" /v Path /d "%USERPROFILE%\.claude\bin" /f
```

### 方式 B：全手动

1. **建目录并放文件**

   ```bat
   mkdir "%USERPROFILE%\.claude\bin"
   copy src\ds-template.html "%USERPROFILE%\.claude\bin\"
   copy src\ds-src.vbs       "%USERPROFILE%\.claude\bin\ds-src.vbs"
   ```

2. **转码**（关键步骤，见下方[「为什么必须转码」](#为什么必须转码)）

   用记事本打开 `%USERPROFILE%\.claude\bin\ds-src.vbs`，
   **文件 → 另存为**，编码选 **`UTF-16 LE`**，文件名填 `ds.vbs`，保存。
   （记事本存 UTF-16 会自带 BOM，正是 wscript 需要的。）

   或者干脆让 `install.vbs` 只做这一步（不碰注册表）：

   ```bat
   cscript //nologo install.vbs "%USERPROFILE%\.claude\bin" --no-reg
   ```

   转码完成后，`ds-src.vbs` 这个中间产物就没用了，可以删掉。
   `ds.vbs` 才是真正执行的脚本。

3. **注册别名**（同方式 A 的两条 `reg add`）

4. **写 token**（见上一节）

5. **验证**（见上一节）

---

## 工作原理

### 触发链路

```
Win+R  →  输入 ds
      →  Shell 查注册表 HKCU\...\App Paths\ds.exe
      →  默认值 = C:\Users\<你>\.claude\bin\ds.vbs
      →  wscript.exe 执行（所以没有黑框）
      →  脚本判断运行模式：cscript 走控制台自检，wscript 走弹窗
```

`App Paths` 是 Windows 自带的机制——任何注册在这里的 `.exe` 键名都能被
`Win+R` / `ShellExecute` 直接按名字找到。用一个 `.vbs` 冒充 `ds.exe` 是刻意的做法，
这样不用改 `PATH` 环境变量。

### 三个数据源

| 卡片项 | 来源 | 认证 |
|---|---|---|
| 剩余余额 | `https://api.deepseek.com/user/balance` | `sk-` API key，从 `~/.claude/settings.json` 的 `ANTHROPIC_AUTH_TOKEN` 正则抠出 |
| 请求次数 / tokens / 消费 / 命中率 | `https://platform.deepseek.com/api/v0/usage/amount` 和 `/cost` | **userToken**，从 `~/.claude/ds-token.txt` 读 |
| 兜底 | 本地 `~/.claude/projects/**/*.jsonl` 会话记录 | 无 |

官方用量接口是**网页私有 API**，没有公开文档。必须带齐一整套请求头才不会被挡：

```
authorization: Bearer <userToken>
user-agent: Mozilla/5.0 ...
x-client-bundle-id: com.deepseek.chat
x-client-locale: zh_CN
x-client-platform: web
x-client-timezone-offset: <本地时区偏移秒数>
x-client-version: 1.0.0
referer: https://platform.deepseek.com/usage
```

参数是 `?year=YYYY&month=M`——**不是**日期区间，传 `start_date` 会返回 `422`。

拿到整月 JSON 后：先按 `"date":"YYYY-MM-DD"` 切出今天那一段，
再把 `PROMPT_TOKEN` / `PROMPT_CACHE_HIT_TOKEN` / `PROMPT_CACHE_MISS_TOKEN` /
`RESPONSE_TOKEN` / `REQUEST` 各模型累加。

### 渲染

```
读 src/ds-template.html (UTF-8)
  → 字符串替换 {{BALANCE}} {{COST}} 等占位符
  → 写 %TEMP%\ds-popup.hta (UTF-8，无 BOM)
  → mshta.exe 拉起 IE 内核的窗口
```

用 HTA 而不是原生 `MsgBox`，是因为 `MsgBox` 完全不能改样式。
HTA 能用完整的 CSS，代价是要处理 IE 内核的一堆怪癖（见下）。

---

## 三个必须知道的坑

改这个项目之前，一定要读这一节。这三个坑都踩过，症状都很迷惑。

### 坑 1：`.vbs` 必须存成 UTF-16LE

`wscript.exe` / `cscript.exe` 读取 `.vbs` 时，**没有 BOM 就按系统 ANSI 码页解析**。
中文 Windows 的 ANSI 码页是 GBK，但源文件是 UTF-8——于是所有中文字面量变乱码，
连语法都可能报错。

所以 `src/ds-src.vbs` 是 **UTF-8（无 BOM）** 的可编辑源码，
而部署出去的 `ds.vbs` 必须是 **UTF-16LE（带 BOM）**。
`install.vbs` 里的 `Transcode()` 负责这步：

```vbs
outStream.Charset = "unicode"   ' ADODB 写 unicode 会自动带 UTF-16LE BOM
```

**改完源码一定要重新跑 `install.vbs`，否则改动不会生效。**

### 坑 2：HTA 不能带 BOM

`ADODB.Stream` 以 UTF-8 写文件时**默认会写 BOM**（`EF BB BF`）。
但 BOM 会落在 `<!DOCTYPE html>` 之前，IE 内核看到这个就掉进**怪癖模式（quirks mode）**，
CSS 全部失准——布局错位、颜色丢失、flex 失效。

所以 `WriteUtf8` 写完要把流切成二进制、跳过前 3 字节：

```vbs
st.Type = 1                  ' 切二进制
If st.Size >= 3 Then st.Position = 3
```

### 坑 3：本地统计和官网永远对不上

Claude Code 的 transcript（`~/.claude/projects/**/*.jsonl`）**只记录 Claude Code 自己发出的请求**。
官网的口径是**整个账号、所有 key、所有模型**的合计。同一个账号如果还有别的东西在调 API，
两边数字必然差一截——实测差过近一倍。

另外 transcript 有个陷阱：**一次流式响应会写多条 JSONL 记录**，
只有最后一条带完整 `usage`。所以本地统计必须按 `message.id` 去重、
以最后一条为准（`ProcessLocalFile` 里那段"先撤掉再记新的"就是干这个的）。

本地统计只是**兜底**，不是权威数据。要准确就用 userToken 走官方接口。

---

## 文件结构

```
deepseek-usage-popup/
├── README.md              本文件
├── LICENSE                MIT
├── .gitignore
├── install.vbs            一键安装（纯 ASCII）
├── uninstall.vbs          卸载（纯 ASCII）
└── src/
    ├── ds-src.vbs         UTF-8 源码 —— 改这个
    └── ds-template.html   HTA 卡片模板 —— 改样式改这个
```

安装后在 `%USERPROFILE%\.claude\bin\` 下生成：

```
ds.vbs                ← 由 src/ds-src.vbs 转码而来（UTF-16LE），别直接改
ds-template.html      ← 由 src/ds-template.html 复制而来
```

> **为什么 `install.vbs` / `uninstall.vbs` 全用英文？**
>
> 它们自己也是 `.vbs`，也会被按 ANSI 解析——所以**它们里面不能出现任何非 ASCII 字符**，
> 否则在非 UTF-8 码页的机器上直接乱码。中文文档只能放 `README.md`。
> 改这两个文件时请保持纯 ASCII。

---

## 配置项

| 位置 | 项 | 默认 | 说明 |
|---|---|---|---|
| `install.vbs` | 第一个参数 | `%USERPROFILE%\.claude\bin` | 安装目录 |
| `install.vbs` | `--no-reg` | — | 跳过注册表写入 |
| `install.vbs` | 环境变量 `DS_USER_TOKEN` | — | 仅在 `ds-token.txt` 不存在时写入 |
| `ds-src.vbs` | `~/.claude/settings.json` 的 `ANTHROPIC_AUTH_TOKEN` | — | 余额接口用的 API key |
| `ds-src.vbs` | `~/.claude/ds-token.txt` | — | 用量接口用的 userToken |
| `ds-template.html` | 配色常量 | 见文件 `<style>` | `#4ddbb0` 余额、`#ffb454` 消费、`#3fd68c` 命中率 |

想换个安装位置：

```bat
cscript //nologo install.vbs "D:\tools\ds"
```

---

## 常见问题

**`Win+R` 输入 `ds` 没反应**
- 注册表没写成功。检查：`reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe"`
- 关闭 `Win+R` 对话框重新打开一次再试
- 杀毒软件拦了 `.vbs` 执行——看有没有拦截日志

**卡片一闪而过 / 提示 mshta 启动失败**
- 系统缺 `mshta.exe`（极少见），或安全软件拦截
- 先用 `cscript //nologo ds.vbs` 看纯文本输出能不能出来

**数字和官网对不上**
- 卡片底部写的是 `官方接口` 还是 `本地统计`？
- 写着 `本地统计` → token 没配好，数字是 Claude Code 本地的口径，不代表账号全量
- 详见[坑 3](#坑-3本地统计和官网永远对不上)

**卡片排版错乱 / 没颜色 / 挤成一团**
- HTA 带了 BOM，IE 掉进怪癖模式了
- 检查 `%TEMP%\ds-popup.hta` 前 3 字节是不是 `EF BB BF`。是的话说明 `WriteUtf8` 的
  去 BOM 逻辑被改坏了

**提示 `429 Error - Request Blocked`**
- 请求头缺了 `x-client-*` 那一套，或者短时间内请求太频繁
- 或者 userToken 已失效被风控

**提示 `422`，`loc` 指向 `query.month` / `query.year`**
- 参数写错了。必须是 `?year=YYYY&month=M`，不能传日期区间

**改了 `src/ds-src.vbs` 但没生效**
- 忘了重新跑 `install.vbs`。改源码不重新转码 = 白改

**余额显示 `--`**
- `settings.json` 里没有 `ANTHROPIC_AUTH_TOKEN`，或这个 key 无效/被删

---

## 卸载

```bat
cscript //nologo uninstall.vbs            :: 只删 Win+R 别名
cscript //nologo uninstall.vbs --purge    :: 连 ds.vbs 和 ds-template.html 一起删
```

`ds-token.txt` 和 `settings.json` **不会被碰**，需要的话自己删。

---

## 安全说明

- **`ds-token.txt` 等于你的账号登录态。** 拿到它的人可以读你账号的全部用量数据。
  不要提交到 git、不要发到群里、不要贴进 issue。
- `.gitignore` 已经排除了 `ds-token.txt`，但**提交前请自己 `git status` 再确认一遍**。
- API key 没有单独存文件，脚本每次运行时从 `settings.json` 现读。
- 所有请求都是**只读**的（`GET`），脚本不会修改你账号里的任何东西。

---

## 免责声明

`platform.deepseek.com/api/v0/usage/*` 是 DeepSeek 网页版的**私有接口**，
不是官方公开 API。它可能随时改名、改参数、加风控或直接下线，本项目不做保证。
接口挂了的时候 `usage/amount` 拿不到数据，卡片会自动退回本地统计兜底，不会报错崩溃。

---

## English

### What it is

A zero-dependency Windows tool (VBScript + HTA). Press `Win+R`, type `ds`,
and you get a card with your DeepSeek balance and today's usage.

### Requirements

- Windows (anything with `wscript.exe` and `mshta.exe`)
- Claude Code, with a DeepSeek API key in `~/.claude/settings.json`
  (`ANTHROPIC_AUTH_TOKEN`)
- Your DeepSeek **userToken** (see below)

### Install

```bat
git clone https://github.com/HuskyCommunicator/deepseek-usage-popup.git
cd deepseek-usage-popup
cscript //nologo install.vbs
```

The installer transcodes the UTF-8 source into a UTF-16LE `ds.vbs`, copies the
HTA template, and registers the `ds` alias under
`HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\ds.exe`.

Then run this once to check:

```bat
cscript //nologo "%USERPROFILE%\.claude\bin\ds.vbs"
```

The card shows `官方接口` (official API) when the token works, and falls back to
`本地统计` (local stats, Claude Code's own transcript only) when it does not.

### Getting your userToken

The userToken is your **browser login session**, not the `sk-` API key.

1. Open <https://platform.deepseek.com/usage> while logged in
2. `F12` → **Network**
3. Reload the page
4. Filter for `api/v0`, open the `amount` or `cost` request
5. Copy the `authorization` request header — it looks like `Bearer aB3dEf6hIj9...`
6. Strip the leading `Bearer ` and save the rest as
   `%USERPROFILE%\.claude\ds-token.txt` (a single line, nothing else)

Or, for automated setups:

```bat
set DS_USER_TOKEN=aB3dEf6hIj9kLm2nOp5qRs8tUv1wXy4zA7cD0eF3gH6iJ9kLm2n...
cscript //nologo install.vbs
```

It expires after a few weeks/months. Re-grab it and overwrite the file.

### Two encoding traps

1. **`.vbs` must be UTF-16LE.** WSH reads a `.vbs` as ANSI when it has no BOM,
   so any non-ASCII literal gets mangled. That is why `src/ds-src.vbs` is kept
   as UTF-8 and transcoded on install. **Re-run `install.vbs` after every source
   edit** or your change will not take effect.
2. **The HTA must not have a BOM.** A BOM before `<!DOCTYPE html>` pushes the IE
   engine into quirks mode and every CSS rule breaks. `WriteUtf8` strips it.

`install.vbs` and `uninstall.vbs` themselves must stay **pure ASCII** for trap 1.

### Uninstall

```bat
cscript //nologo uninstall.vbs --purge
```

### Disclaimer

`platform.deepseek.com/api/v0/usage/*` is a private web API, not a documented
public one. It can change or disappear at any time. When it breaks, the card
silently falls back to local stats.

---

## License

MIT — see [LICENSE](LICENSE).

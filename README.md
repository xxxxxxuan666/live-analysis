# 直播创意分析 Skill

`livestream-competitor-monitor-skill` 用于抖音等直播间的竞品直播创意分析。它可以录屏/录音、抓取评论区 JSONL、用 FunASR 转写直播系统声音，并生成单直播间分析报告、多直播间对比报告和飞书文档。

详细使用说明见 [USAGE.md](USAGE.md)。如果一键安装失败，可按 [MANUAL_INSTALL.md](MANUAL_INSTALL.md) 逐项手动安装依赖。

## 核心能力

- 输入直播间链接后录屏：画面 + 系统声音。
- 输入直播间链接后录音：仅系统声音。
- 停止录制后自动抽取音频并转写文本。
- 同步抓取抖音直播评论 JSONL。
- 自动归档录屏、音频、转写文本、评论 JSONL。
- 分析主播话术、直播贴面、游戏画面、评论互动和脚本循环机制。
- 生成飞书分析文档。

## 推荐安装方式

把下面整段命令复制到 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Join-Path $env:TEMP 'live-analysis'; if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }; git clone https://github.com/xxxxxxuan666/live-analysis.git $d; powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $d 'install.ps1')"
```

如果还需要生成飞书文档，使用这个版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Join-Path $env:TEMP 'live-analysis'; if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }; git clone https://github.com/xxxxxxuan666/live-analysis.git $d; powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $d 'install.ps1') -InstallLarkCli"
```

如果希望安装后立刻做验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Join-Path $env:TEMP 'live-analysis'; if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }; git clone https://github.com/xxxxxxuan666/live-analysis.git $d; powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $d 'install.ps1') -InstallLarkCli -Verify"
```

安装完成后，重启 Codex / Claude Code / Cursor Agent 等工具。

## Atlas 安装后的依赖说明

Atlas 只会安装 Skill 文件，不会替用户电脑安装系统级工具或驱动。因此通过 Atlas 下载后，仍需要本机具备以下依赖：

| 依赖 | 是否必需 | 用途 |
|---|---:|---|
| Git | 必需 | GitHub 兜底安装、更新仓库 |
| ffmpeg | 必需 | 录屏、录音、抽音频、抽帧 |
| Python 3.11 | 必需 | Playwright、评论抓取、FunASR |
| Playwright Chromium | 必需 | 直播间信息识别、评论抓取 |
| FunASR / PyTorch / ModelScope / soundfile | 必需 | 语音转文字 |
| lark-cli | 可选 | 发布飞书文档 |
| editdistance | 可选 | WER/CER 文本评测，不影响转写 |
| 系统声音采集设备 | 录直播系统声时必需 | Stereo Mix、VB-CABLE、Voicemeeter、virtual-audio-capturer 或 OBS audio |

## 手动安装命令

如果一键安装失败，可以按下面顺序逐项安装。

### 1. Git

```powershell
winget install --id Git.Git --accept-package-agreements --accept-source-agreements
```

### 2. ffmpeg

```powershell
winget install --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
```

### 3. Python 3.11

```powershell
winget install --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements
```

### 4. Playwright + Chromium

```powershell
py -3.11 -m pip install -U pip
py -3.11 -m pip install -U playwright
py -3.11 -m playwright install chromium
```

### 5. FunASR 转写环境

```powershell
$skill = Join-Path $env:USERPROFILE ".agents\skills\livestream-competitor-monitor-skill"
$venv = Join-Path $skill ".venv-funasr"

py -3.11 -m venv $venv
$python = Join-Path $venv "Scripts\python.exe"

& $python -m pip install -U pip
& $python -m pip install -U torch torchaudio funasr modelscope huggingface_hub soundfile
```

验证：

```powershell
$skill = Join-Path $env:USERPROFILE ".agents\skills\livestream-competitor-monitor-skill"
$python = Join-Path $skill ".venv-funasr\Scripts\python.exe"
& $python -c "import funasr, torch, modelscope, soundfile; print('FunASR OK', torch.__version__)"
```

### 6. lark-cli

只有需要生成飞书文档时才安装。

```powershell
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
npm install -g @larksuite/cli
```

验证：

```powershell
lark-cli.cmd --version
```

### 7. 系统声音采集

录直播系统声音前，先查看当前可用设备：

```powershell
ffmpeg -hide_banner -list_devices true -f dshow -i dummy
```

如果看到下面任一设备，就可以作为系统声音采集源：

- `Stereo Mix`
- `立体声混音`
- `virtual-audio-capturer`
- `VB-CABLE`
- `CABLE Output`
- `Voicemeeter`
- `OBS Audio`

如果没有，请手动启用 Stereo Mix，或安装 VB-CABLE、Voicemeeter、virtual-audio-capturer、OBS audio 等虚拟音频方案。系统声音采集涉及驱动和系统音频路由，不建议由 Skill 静默自动安装。

## 最小可用状态

只要下面项目成功，就能使用核心分析能力：

- Skill 文件已安装
- ffmpeg 可用
- Python 3.11 可用
- Playwright Chromium 可用
- FunASR + PyTorch 可用

下面项目不是核心失败：

- `editdistance` 未安装：只影响 WER/CER 指标，不影响转写或报告。
- 系统声音采集未配置：不能直接录直播系统声音，但仍可分析已有视频、音频、文本和评论文件。

## 使用示例

开始录屏：

```text
https://live.douyin.com/直播间ID?anchor_id= 录屏
```

开始录音：

```text
https://live.douyin.com/直播间ID?anchor_id= 录音
```

停止录制：

```text
停止
```

生成飞书文档：

```text
生成飞书分析文档
```

分析已有视频：

```text
请分析这个录屏文件：C:\path\demo.mkv
```

## 文件归档

默认归档目录：

```text
桌面\直播录文件存档
```

单个直播间目录格式：

```text
<游戏产品名>-<直播间名称>-<yyyyMMdd>
```

常见输出文件：

- 录屏文件：`.mkv`
- 音频文件：`.wav`
- 转写文本：`-funasr.md`
- 转写 JSON：`-funasr.json`
- 评论文件：`-comments.jsonl`
- session 文件：`live-monitor-session.json`

## 常见问题

### 为什么 editdistance 显示 skipped？

`editdistance` 是可选组件，只用于 WER/CER 文本评测指标。它不影响 FunASR 转写、直播分析或飞书报告。

### 为什么系统声音采集显示 manual setup needed？

这是正常情况。系统声音采集依赖用户本机声卡、驱动或虚拟音频路由。请手动配置 Stereo Mix、VB-CABLE、Voicemeeter、virtual-audio-capturer 或 OBS audio。

### Mac 能用吗？

Mac 可以用于分析已有录屏、音频、文本和评论文件。直播间链接自动录屏目前主要面向 Windows，因为 Mac 的录屏和系统声音采集方案不同。

## 安全边界

- 只分析公开、已授权或自有直播材料。
- 不要绕过平台访问控制、登录限制、付费墙或反录制措施。
- 不要长期保存观众个人信息；评论内容用于模式总结时应匿名化。

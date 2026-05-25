# 手动安装依赖命令

如果一键安装失败，可以按下面顺序逐项手动安装。以下命令默认面向 Windows PowerShell。

## 0. 基础检查

```powershell
git --version
chrome --version
ffmpeg -version
python --version
node --version
npm --version
```

如果某一项提示找不到命令，就按下面对应章节安装。

## 1. Git

用于从 GitHub 克隆 skill 仓库。

```powershell
winget install --id Git.Git --accept-package-agreements --accept-source-agreements
```

安装后关闭并重新打开 PowerShell，再检查：

```powershell
git --version
```

## 2. 下载并安装 Skill 文件

```powershell
$repo = Join-Path $env:TEMP "live-analysis"
if (Test-Path -LiteralPath $repo) {
  Remove-Item -LiteralPath $repo -Recurse -Force
}
git clone https://github.com/xxxxxxuan666/live-analysis.git $repo

$target = Join-Path $env:USERPROFILE ".agents\skills\livestream-competitor-monitor-skill"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
if (Test-Path -LiteralPath $target) {
  Remove-Item -LiteralPath $target -Recurse -Force
}
Copy-Item -LiteralPath $repo -Destination $target -Recurse -Force

Write-Host "Skill installed to: $target"
```

安装后需要重启 Codex / Claude Code / Cursor Agent 等工具。

## 3. Google Chrome

用于打开抖音直播间。评论爬虫依赖 Chrome CDP，因此直播链接必须由 Google Chrome 打开，不能只开在 Edge 或系统默认浏览器里。

```powershell
winget install --id Google.Chrome --accept-package-agreements --accept-source-agreements
```

安装后关闭并重新打开 PowerShell，再检查：

```powershell
chrome --version
```

如果 `chrome` 命令不可用，但下面文件存在，也可以正常使用：

```powershell
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

## 4. ffmpeg

用于录屏、录音、抽音频和抽帧。

```powershell
winget install --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
```

安装后关闭并重新打开 PowerShell，再检查：

```powershell
ffmpeg -version
```

## 5. Python 3.11

用于 Playwright、评论抓取和 FunASR 转写。建议安装 Python 3.11，避免较新 Python 版本缺少部分依赖 wheel。

```powershell
winget install --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements
```

安装后关闭并重新打开 PowerShell，再检查：

```powershell
py -3.11 --version
python --version
```

如果 `python` 仍不可用，可以临时使用 `py -3.11` 执行下面的 Python 命令。

## 6. Playwright + Chromium

用于识别直播间信息和抓取评论区内容。

```powershell
py -3.11 -m pip install -U pip
py -3.11 -m pip install -U playwright
py -3.11 -m playwright install chromium
```

验证：

```powershell
py -3.11 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); print(b.version); b.close(); p.stop()"
```

## 7. FunASR 转写环境

用于把直播系统声音转成文本。推荐安装在 skill 自己的虚拟环境中。

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
& $python -c "import funasr, torch, modelscope, soundfile; print('FunASR deps OK', torch.__version__)"
```

### 可选：editdistance

`editdistance` 只用于 WER/CER 文本评测指标，不影响直播转写、分析报告或飞书文档生成。

```powershell
$skill = Join-Path $env:USERPROFILE ".agents\skills\livestream-competitor-monitor-skill"
$python = Join-Path $skill ".venv-funasr\Scripts\python.exe"
& $python -m pip install -U editdistance
```

如果它提示缺少 MSVC 或编译失败，可以跳过。

## 8. lark-cli

用于生成飞书文档。只有需要发布飞书报告时才安装。

```powershell
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
npm install -g @larksuite/cli
```

验证：

```powershell
lark-cli --version
```

如果 PowerShell 执行策略拦截 `lark-cli.ps1`，优先用：

```powershell
lark-cli.cmd --version
```

## 9. 系统声音采集设备

录直播系统声音必须有一个系统声音采集设备。这个步骤通常涉及驱动、虚拟声卡或系统音频路由，不能保证所有电脑都能静默安装成功。

先检查当前 DirectShow 音频设备：

```powershell
ffmpeg -hide_banner -list_devices true -f dshow -i dummy
```

如果输出里能看到下面任一设备，就可以用来录系统声音：

- `Stereo Mix`
- `立体声混音`
- `virtual-audio-capturer`
- `VB-CABLE`
- `CABLE Output`
- `Voicemeeter`
- `OBS Audio`

如果没有，请任选一种手动安装或启用：

### 方案 A：启用 Stereo Mix / 立体声混音

1. 打开 Windows 声音设置。
2. 进入“更多声音设置”。
3. 进入“录制”标签。
4. 右键空白处，勾选“显示禁用的设备”。
5. 启用 `Stereo Mix` / `立体声混音`。
6. 再运行 `ffmpeg -hide_banner -list_devices true -f dshow -i dummy` 检查。

### 方案 B：安装 VB-CABLE

安装 VB-CABLE 后，把系统输出路由到虚拟声卡，再让 ffmpeg 采集 `CABLE Output`。

安装完成后检查：

```powershell
ffmpeg -hide_banner -list_devices true -f dshow -i dummy
```

### 方案 C：安装 Voicemeeter

适合需要更复杂音频路由的用户。安装后检查 DirectShow 设备里是否出现 Voicemeeter 相关输入/输出。

### 方案 D：使用 OBS Audio / 桌面音频

如果用户本来使用 OBS，可以配置 OBS 的桌面音频或虚拟音频设备，再让 skill 采集对应 DirectShow 音频源。

## 9. 完整验证命令

```powershell
$skill = Join-Path $env:USERPROFILE ".agents\skills\livestream-competitor-monitor-skill"

Test-Path -LiteralPath $skill
ffmpeg -version
py -3.11 --version

py -3.11 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); print('Chromium', b.version); b.close(); p.stop()"

$funasrPython = Join-Path $skill ".venv-funasr\Scripts\python.exe"
& $funasrPython -c "import funasr, torch, modelscope, soundfile; print('FunASR OK', torch.__version__)"

ffmpeg -hide_banner -list_devices true -f dshow -i dummy
```

## 10. 最小可用状态

只要下面项目是 OK，就可以开始使用核心能力：

- Skill 文件已安装
- Google Chrome 可用
- ffmpeg 可用
- Python 3.11 可用
- Playwright Chromium 可用
- FunASR + PyTorch 可用

下面项目不是核心失败：

- `editdistance` 未安装：只影响 WER/CER 评测指标，不影响转写。
- 系统声音采集未配置：需要手动配置后才能录直播系统声音；但仍可分析已有视频、音频、文本和评论文件。

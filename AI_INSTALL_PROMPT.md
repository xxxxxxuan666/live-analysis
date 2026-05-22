# AI Install Prompt

把下面整段发给 Codex、Claude Code、Cursor Agent 或其他本机 AI 助手即可安装。

```text
请帮我安装 GitHub 上的 livestream-competitor-monitor-skill，并安装它运行录屏、评论采集、转写和飞书发布所需的基础工具。

严格按下面步骤执行：

1. 打开 PowerShell。
2. 运行下面命令下载安装脚本并执行：

powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/xxxxxxuan666/live-analysis/main/install.ps1'; $p=Join-Path $env:TEMP 'install-livestream-competitor-monitor-skill.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; powershell -NoProfile -ExecutionPolicy Bypass -File $p"

3. 如果我还需要生成飞书文档，再改用下面命令安装，可额外安装 lark-cli：

powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/xxxxxxuan666/live-analysis/main/install.ps1'; $p=Join-Path $env:TEMP 'install-livestream-competitor-monitor-skill.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; powershell -NoProfile -ExecutionPolicy Bypass -File $p -InstallLarkCli"

4. 安装完成后，告诉我：
- skill 安装路径
- ffmpeg 是否可用
- python 是否可用
- playwright chromium 是否安装完成
- FunASR 依赖是否安装完成
- 如果我要录直播间系统声音，还需要配置 Stereo Mix、virtual-audio-capturer、VB-CABLE、Voicemeeter 或其他系统声音采集设备

不要改装其他相似 skill，不要把仓库名替换成别的名字。
```

## 如果只想下载 skill，不安装工具

```text
请只下载并安装 livestream-competitor-monitor-skill，不安装 ffmpeg、Python 包或 lark-cli。

powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/xxxxxxuan666/live-analysis/main/install.ps1'; $p=Join-Path $env:TEMP 'install-livestream-competitor-monitor-skill.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; powershell -NoProfile -ExecutionPolicy Bypass -File $p -SkipToolInstall"
```

# livestream-competitor-monitor-skill

用于抖音等直播间的竞品直播监控分析：录屏/录音、系统声音采集、评论 JSONL 抓取、FunASR 转写、单直播间分析报告、多直播间对比和飞书文档发布。

## 一键安装

把 [AI_INSTALL_PROMPT.md](AI_INSTALL_PROMPT.md) 里的整段文字发给本机 AI 助手，它会帮你下载安装并检查依赖。

也可以自己在 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/xxxxxxuan666/livestream-competitor-monitor-skill/main/install.ps1'; $p=Join-Path $env:TEMP 'install-livestream-competitor-monitor-skill.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; powershell -NoProfile -ExecutionPolicy Bypass -File $p"
```

需要飞书文档发布能力时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/xxxxxxuan666/livestream-competitor-monitor-skill/main/install.ps1'; $p=Join-Path $env:TEMP 'install-livestream-competitor-monitor-skill.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; powershell -NoProfile -ExecutionPolicy Bypass -File $p -InstallLarkCli"
```

## 安装内容

- skill 安装到 `%USERPROFILE%\.agents\skills\livestream-competitor-monitor-skill`
- 自动检查或安装：
  - ffmpeg
  - Python 3.11+
  - Playwright + Chromium
  - FunASR / ModelScope / soundfile
  - lark-cli（可选）

## 录屏前准备

录直播系统声音需要配置系统声音采集设备，例如：

- Stereo Mix
- virtual-audio-capturer
- VB-CABLE
- Voicemeeter
- OBS audio / desktop audio capture

不要使用麦克风作为默认采集源。

## 使用示例

安装并重启 Codex / Agent 后，直接对 AI 说：

```text
https://live.douyin.com/直播间ID?anchor_id= 录屏
```

停止时说：

```text
停止
```

生成报告时说：

```text
生成飞书分析文档
```

## 安全边界

只分析公开、已授权或自有直播材料。不要绕过平台访问控制、登录限制、付费墙或反录制措施。

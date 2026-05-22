param(
  [string]$RepoZipUrl = "https://github.com/xxxxxxuan666/live-analysis/archive/refs/heads/main.zip",
  [string]$InstallRoot = "",
  [switch]$SkipToolInstall,
  [switch]$InstallLarkCli
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
  $user = [System.Environment]::GetEnvironmentVariable("PATH", "User")
  $env:PATH = "$machine;$user"
}

function Invoke-WingetInstall {
  param(
    [string]$Id,
    [string]$Name
  )
  if (-not (Test-Command "winget")) {
    Write-Warning "winget was not found. Please install $Name manually."
    return
  }
  Write-Step "Installing $Name with winget"
  winget install --id $Id --accept-package-agreements --accept-source-agreements
  Refresh-Path
}

function Ensure-Ffmpeg {
  if (Test-Command "ffmpeg") {
    Write-Host "ffmpeg found: $((Get-Command ffmpeg).Source)"
    return
  }
  Invoke-WingetInstall -Id "Gyan.FFmpeg" -Name "ffmpeg"
  if (-not (Test-Command "ffmpeg")) {
    Write-Warning "ffmpeg is still not available in PATH. Please reopen PowerShell or install ffmpeg manually."
  }
}

function Ensure-Python {
  if (Test-Command "python") {
    Write-Host "python found: $((Get-Command python).Source)"
    return
  }
  Invoke-WingetInstall -Id "Python.Python.3.11" -Name "Python 3.11"
  if (-not (Test-Command "python")) {
    throw "Python was not found after installation. Please reopen PowerShell or install Python 3.11+ manually."
  }
}

function Ensure-Node {
  if (Test-Command "node") {
    Write-Host "node found: $((Get-Command node).Source)"
    return
  }
  Invoke-WingetInstall -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
}

function Install-PythonPackages {
  Ensure-Python
  Write-Step "Installing Python packages: playwright, funasr, modelscope, soundfile"
  python -m pip install -U pip
  python -m pip install -U playwright funasr modelscope huggingface_hub soundfile
  python -m playwright install chromium
}

function Install-LarkCliIfRequested {
  if (-not $InstallLarkCli) {
    Write-Host "Skipping lark-cli. Use -InstallLarkCli if Feishu document publishing is needed."
    return
  }
  Ensure-Node
  Write-Step "Installing lark-cli"
  npm install -g @larksuite/cli
}

function Get-SkillSourceFromExpandedZip {
  param([string]$ExpandedRoot)
  $direct = Get-ChildItem -LiteralPath $ExpandedRoot -Directory | Select-Object -First 1
  if (-not $direct) {
    throw "Could not find expanded repository folder under $ExpandedRoot"
  }
  if (Test-Path -LiteralPath (Join-Path $direct.FullName "SKILL.md")) {
    return $direct.FullName
  }
  $nested = Join-Path $direct.FullName "livestream-competitor-monitor-skill"
  if (Test-Path -LiteralPath (Join-Path $nested "SKILL.md")) {
    return $nested
  }
  $nestedInSkills = Join-Path $direct.FullName "skills\livestream-competitor-monitor-skill"
  if (Test-Path -LiteralPath (Join-Path $nestedInSkills "SKILL.md")) {
    return $nestedInSkills
  }
  throw "Could not locate SKILL.md in downloaded repository."
}

if (-not $InstallRoot) {
  $InstallRoot = Join-Path $env:USERPROFILE ".agents\skills"
}

Write-Step "Downloading livestream-competitor-monitor-skill"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("livestream-skill-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "skill.zip"
$expandPath = Join-Path $tempRoot "expanded"
New-Item -ItemType Directory -Force -Path $tempRoot, $expandPath | Out-Null

Invoke-WebRequest -UseBasicParsing -Uri $RepoZipUrl -OutFile $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $expandPath -Force

$skillSource = Get-SkillSourceFromExpandedZip -ExpandedRoot $expandPath
$target = Join-Path $InstallRoot "livestream-competitor-monitor-skill"

Write-Step "Installing skill to $target"
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
if (Test-Path -LiteralPath $target) {
  Remove-Item -LiteralPath $target -Recurse -Force
}
Copy-Item -LiteralPath $skillSource -Destination $target -Recurse -Force

if (-not $SkipToolInstall) {
  Ensure-Ffmpeg
  Install-PythonPackages
  Install-LarkCliIfRequested
} else {
  Write-Host "Skipping tool installation because -SkipToolInstall was provided."
}

Write-Step "Installation complete"
Write-Host "Skill path: $target"
Write-Host "Restart Codex or your Agent tool so it can reload skills."
Write-Host "For recording system audio, configure Stereo Mix, virtual-audio-capturer, VB-CABLE, Voicemeeter, or another system-audio DirectShow device."

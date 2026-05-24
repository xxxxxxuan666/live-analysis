param(
  [string]$RepoZipUrl = "https://github.com/xxxxxxuan666/live-analysis/archive/refs/heads/main.zip",
  [string]$InstallRoot = "",
  [switch]$SkipToolInstall,
  [switch]$InstallLarkCli,
  [switch]$InstallPython,
  [switch]$InstallSystemAudioCapture,
  [switch]$Verify
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
  $env:PATH = "$user;$machine"
}

function Add-UserPathPrefix {
  param([string[]]$Paths)
  $current = [System.Environment]::GetEnvironmentVariable("PATH", "User")
  $existing = @()
  if ($current) {
    $existing = $current -split ";" | Where-Object { $_ }
  }
  $newParts = @()
  foreach ($path in $Paths) {
    if ($path -and (Test-Path -LiteralPath $path) -and ($newParts -notcontains $path)) {
      $newParts += $path
    }
  }
  $remaining = $existing | Where-Object { $newParts -notcontains $_ }
  [System.Environment]::SetEnvironmentVariable("PATH", (($newParts + $remaining) -join ";"), "User")
  Refresh-Path
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

function Test-PythonInvoker {
  param(
    [string]$FilePath,
    [string[]]$PrefixArgs = @()
  )
  try {
    $version = (& $FilePath @PrefixArgs --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch "Python 3\.") {
      return $null
    }
    return [pscustomobject]@{
      FilePath = $FilePath
      PrefixArgs = $PrefixArgs
      Version = $version
      Display = (($FilePath + " " + ($PrefixArgs -join " ")).Trim())
    }
  } catch {
    return $null
  }
}

function Get-PythonInvoker {
  Refresh-Path

  $py = Get-Command "py.exe" -ErrorAction SilentlyContinue
  if ($py) {
    $candidate = Test-PythonInvoker -FilePath $py.Source -PrefixArgs @("-3.11")
    if ($candidate) {
      return $candidate
    }
    $candidate = Test-PythonInvoker -FilePath $py.Source -PrefixArgs @("-3")
    if ($candidate) {
      return $candidate
    }
  }

  foreach ($name in @("python.exe", "python")) {
    $commands = @(Get-Command $name -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
      if ($command.Source -like "*\Microsoft\WindowsApps\python.exe") {
        continue
      }
      $candidate = Test-PythonInvoker -FilePath $command.Source
      if ($candidate) {
        return $candidate
      }
    }
  }

  $defaultPython = Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe"
  if (Test-Path -LiteralPath $defaultPython) {
    $candidate = Test-PythonInvoker -FilePath $defaultPython
    if ($candidate) {
      return $candidate
    }
  }

  return $null
}

function Invoke-Python {
  param(
    [Parameter(Mandatory=$true)][object]$Python,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments
  )
  & $Python.FilePath @($Python.PrefixArgs + $Arguments)
}

function Ensure-Python {
  $python = Get-PythonInvoker
  if ($python) {
    Write-Host "python found: $($python.Display) ($($python.Version))"
    return $python
  }

  if (-not $InstallPython) {
    Write-Host "Python 3 was not found. Installing Python 3.11 because Python is required for Playwright and FunASR."
  }

  Invoke-WingetInstall -Id "Python.Python.3.11" -Name "Python 3.11"
  $pythonDir = Join-Path $env:LOCALAPPDATA "Programs\Python\Python311"
  Add-UserPathPrefix -Paths @($pythonDir, (Join-Path $pythonDir "Scripts"))
  $python = Get-PythonInvoker
  if (-not $python) {
    throw "Python was not found after installation. Please reopen PowerShell or install Python 3.11+ manually."
  }
  Write-Host "python found: $($python.Display) ($($python.Version))"
  return $python
}

function Ensure-Node {
  if (Test-Command "node") {
    Write-Host "node found: $((Get-Command node).Source)"
    return
  }
  Invoke-WingetInstall -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
}

function Install-PythonPackages {
  $python = Ensure-Python
  Write-Step "Installing Python packages: playwright, funasr, modelscope, soundfile, torch"
  Invoke-Python -Python $python -m pip install -U pip
  Invoke-Python -Python $python -m pip install -U playwright funasr modelscope huggingface_hub soundfile
  Invoke-Python -Python $python -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
  Invoke-Python -Python $python -m playwright install chromium
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

function Test-DirectShowAudioDevice {
  param([string]$DeviceName = "virtual-audio-capturer")
  if (-not (Test-Command "ffmpeg")) {
    return $false
  }
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = (& ffmpeg -hide_banner -list_devices true -f dshow -i dummy 2>&1 | Out-String)
    return ($output -match [regex]::Escape("`"$DeviceName`""))
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Install-SystemAudioCaptureIfRequested {
  if (-not $InstallSystemAudioCapture) {
    Write-Host "Skipping system-audio capture device install. Use -InstallSystemAudioCapture to install virtual-audio-capturer."
    return
  }
  Ensure-Ffmpeg
  if (Test-DirectShowAudioDevice) {
    Write-Host "virtual-audio-capturer found."
    return
  }

  Write-Step "Installing virtual-audio-capturer"
  $api = "https://api.github.com/repos/rdp/screen-capture-recorder-to-video-windows-free/releases/latest"
  $release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "livestream-competitor-monitor-installer" }
  $asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
  if (-not $asset) {
    throw "Could not find screen-capture-recorder installer in latest GitHub release."
  }
  $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
  Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $installerPath
  Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
  Start-Sleep -Seconds 2

  if (-not (Test-DirectShowAudioDevice)) {
    throw "virtual-audio-capturer was not found after installation. Reopen PowerShell or reboot, then run ffmpeg device listing again."
  }
  Write-Host "virtual-audio-capturer installed."
}

function Test-LarkCli {
  $cmd = Get-Command "lark-cli.cmd" -ErrorAction SilentlyContinue
  if ($cmd) {
    & $cmd.Source --version | Out-Null
    return ($LASTEXITCODE -eq 0)
  }
  $cmd = Get-Command "lark-cli" -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -notlike "*.ps1") {
    & $cmd.Source --version | Out-Null
    return ($LASTEXITCODE -eq 0)
  }
  return $false
}

function Invoke-InstallVerification {
  param([string]$SkillPath)
  Write-Step "Verifying installation"
  $failures = New-Object System.Collections.Generic.List[string]

  function Add-CheckResult {
    param(
      [string]$Name,
      [bool]$Passed,
      [string]$Detail = ""
    )
    if ($Passed) {
      Write-Host "[PASS] $Name $Detail"
    } else {
      Write-Host "[FAIL] $Name $Detail"
      $script:verificationFailures.Add($Name) | Out-Null
    }
  }

  $script:verificationFailures = $failures

  Add-CheckResult -Name "skill path" -Passed (Test-Path -LiteralPath $SkillPath) -Detail $SkillPath

  $ffmpegOk = $false
  if (Test-Command "ffmpeg") {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & ffmpeg -version *> $null
    $ErrorActionPreference = $previousErrorActionPreference
    $ffmpegOk = ($LASTEXITCODE -eq 0)
  }
  Add-CheckResult -Name "ffmpeg" -Passed $ffmpegOk

  $python = Get-PythonInvoker
  Add-CheckResult -Name "python" -Passed ([bool]$python) -Detail $(if ($python) { $python.Version } else { "" })

  $pipOk = $false
  if ($python) {
    Invoke-Python -Python $python -m pip --version *> $null
    $pipOk = ($LASTEXITCODE -eq 0)
  }
  Add-CheckResult -Name "pip" -Passed $pipOk

  $funasrOk = $false
  if ($python) {
    Invoke-Python -Python $python -c "import funasr, torch, modelscope, soundfile; print(torch.__version__)" *> $null
    $funasrOk = ($LASTEXITCODE -eq 0)
  }
  Add-CheckResult -Name "FunASR dependencies" -Passed $funasrOk

  $chromiumOk = $false
  if ($python) {
    Invoke-Python -Python $python -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); print(b.version); b.close(); p.stop()" *> $null
    $chromiumOk = ($LASTEXITCODE -eq 0)
  }
  Add-CheckResult -Name "Playwright Chromium" -Passed $chromiumOk

  if ($InstallLarkCli) {
    Add-CheckResult -Name "lark-cli" -Passed (Test-LarkCli)
  } else {
    Write-Host "[SKIP] lark-cli (use -InstallLarkCli to install and verify)"
  }

  if ($InstallSystemAudioCapture) {
    $audioOk = Test-DirectShowAudioDevice
    Add-CheckResult -Name "virtual-audio-capturer" -Passed $audioOk
    if ($audioOk) {
      $testWav = Join-Path ([System.IO.Path]::GetTempPath()) "virtual-audio-capturer-test.wav"
      Remove-Item -LiteralPath $testWav -ErrorAction SilentlyContinue
      $previousErrorActionPreference = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      & ffmpeg -y -f dshow -i audio="virtual-audio-capturer" -t 3 $testWav *> $null
      $ErrorActionPreference = $previousErrorActionPreference
      Add-CheckResult -Name "system audio recording test" -Passed (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $testWav))
    }
  } else {
    Write-Host "[SKIP] virtual-audio-capturer (use -InstallSystemAudioCapture to install and verify)"
  }

  if ($failures.Count -gt 0) {
    throw "Verification failed: $($failures -join ', ')"
  }
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
  Install-SystemAudioCaptureIfRequested
} else {
  Write-Host "Skipping tool installation because -SkipToolInstall was provided."
}

if ($Verify) {
  Invoke-InstallVerification -SkillPath $target
}

Write-Step "Installation complete"
Write-Host "Skill path: $target"
Write-Host "Restart Codex or your Agent tool so it can reload skills."
if ($InstallSystemAudioCapture) {
  Write-Host "System audio capture device: virtual-audio-capturer"
} else {
  Write-Host "For recording system audio, configure Stereo Mix, virtual-audio-capturer, VB-CABLE, Voicemeeter, or another system-audio DirectShow device."
}

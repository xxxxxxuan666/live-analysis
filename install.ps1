param(
  [string]$RepoZipUrl = "",
  [string]$InstallRoot = "",
  [switch]$SkipToolInstall,
  [switch]$InstallLarkCli,
  [switch]$InstallPython,
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

function Resolve-ChromePath {
  $candidates = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Get-Item -LiteralPath $candidate).FullName
    }
  }
  $cmd = Get-Command chrome.exe -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }
  return ""
}

function Ensure-Chrome {
  $chromePath = Resolve-ChromePath
  if ($chromePath) {
    Write-Host "Google Chrome found: $chromePath"
    return
  }
  Invoke-WingetInstall -Id "Google.Chrome" -Name "Google Chrome"
  $chromePath = Resolve-ChromePath
  if (-not $chromePath) {
    Write-Warning "Google Chrome is still not available. Please install Google Chrome manually because Douyin comment crawling requires Chrome CDP."
  }
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
    if ($LASTEXITCODE -ne 0 -or $version -notmatch "Python 3\.(10|11|12)\.") {
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
    Write-Host "Python 3.10-3.12 was not found. Installing Python 3.11 because it has better wheel support for FunASR dependencies."
  }

  Invoke-WingetInstall -Id "Python.Python.3.11" -Name "Python 3.11"
  $pythonDir = Join-Path $env:LOCALAPPDATA "Programs\Python\Python311"
  Add-UserPathPrefix -Paths @($pythonDir, (Join-Path $pythonDir "Scripts"))
  $python = Get-PythonInvoker
  if (-not $python) {
    throw "Python 3.10-3.12 was not found after installation. Please reopen PowerShell or install Python 3.11 manually."
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
  param([string]$SkillPath)
  $python = Ensure-Python
  Write-Step "Installing Python packages: playwright"
  Invoke-Python -Python $python -m pip install -U pip
  Invoke-Python -Python $python -m pip install -U playwright
  Invoke-Python -Python $python -m playwright install chromium
  Write-Step "Preparing FunASR virtual environment"
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "scripts\setup-funasr.ps1") -EnvDir (Join-Path $SkillPath ".venv-funasr")
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
  $chromePath = Resolve-ChromePath
  Add-CheckResult -Name "Google Chrome" -Passed ([bool]$chromePath) -Detail $chromePath

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

  $funasrPython = Join-Path $SkillPath ".venv-funasr\Scripts\python.exe"
  $funasrOk = $false
  if (Test-Path -LiteralPath $funasrPython) {
    & $funasrPython -c "import funasr, torch, modelscope, soundfile; print(torch.__version__)" *> $null
    $funasrOk = ($LASTEXITCODE -eq 0)
  }
  Add-CheckResult -Name "FunASR dependencies" -Passed $funasrOk -Detail $(if (Test-Path -LiteralPath $funasrPython) { "in skill venv" } else { "venv not found" })

  if ($funasrOk) {
    & $funasrPython -c "import editdistance" *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[PASS] optional editdistance installed"
    } else {
      Write-Host "[OPTIONAL] editdistance not installed. This only affects WER/CER evaluation metrics, not livestream transcription or reports."
    }
  }

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

  Write-Host "[INFO] system audio capture device must be configured manually: Stereo Mix, virtual-audio-capturer, VB-CABLE, Voicemeeter, or OBS audio."

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

function Copy-SkillDirectory {
  param(
    [string]$Source,
    [string]$Destination
  )
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  $excludedNames = @(".git", "__pycache__", ".venv", ".venv-funasr")
  foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
    if ($excludedNames -contains $item.Name) {
      continue
    }
    if ($item.Name -like "*.zip" -or $item.Name -like "*.pyc") {
      continue
    }
    Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
  }
}

if (-not $InstallRoot) {
  $InstallRoot = Join-Path $env:USERPROFILE ".agents\skills"
}

if ($RepoZipUrl) {
  Write-Step "Downloading livestream-competitor-monitor-skill"
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("livestream-skill-" + [guid]::NewGuid().ToString("N"))
  $zipPath = Join-Path $tempRoot "skill.zip"
  $expandPath = Join-Path $tempRoot "expanded"
  New-Item -ItemType Directory -Force -Path $tempRoot, $expandPath | Out-Null

  Invoke-WebRequest -UseBasicParsing -Uri $RepoZipUrl -OutFile $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $expandPath -Force
  $skillSource = Get-SkillSourceFromExpandedZip -ExpandedRoot $expandPath
} else {
  Write-Step "Installing livestream-competitor-monitor-skill from local checkout"
  $skillSource = $PSScriptRoot
}
$target = Join-Path $InstallRoot "livestream-competitor-monitor-skill"

Write-Step "Installing skill to $target"
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
if (Test-Path -LiteralPath $target) {
  Remove-Item -LiteralPath $target -Recurse -Force
}
Copy-SkillDirectory -Source $skillSource -Destination $target

if (-not $SkipToolInstall) {
  Ensure-Chrome
  Ensure-Ffmpeg
  Install-PythonPackages -SkillPath $target
  Install-LarkCliIfRequested
} else {
  Write-Host "Skipping tool installation because -SkipToolInstall was provided."
}

if ($Verify) {
  Invoke-InstallVerification -SkillPath $target
}

Write-Step "Installation complete"
Write-Host "Skill path: $target"
Write-Host "Restart Codex or your Agent tool so it can reload skills."
Write-Host "For recording system audio, configure Stereo Mix, virtual-audio-capturer, VB-CABLE, Voicemeeter, or another system-audio DirectShow device."

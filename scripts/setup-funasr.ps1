param(
  [string]$EnvDir = ""
)

$skillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $EnvDir) {
  $EnvDir = Join-Path $skillDir ".venv-funasr"
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
  $py = Get-Command "py.exe" -ErrorAction SilentlyContinue
  if ($py) {
    $candidate = Test-PythonInvoker -FilePath $py.Source -PrefixArgs @("-3.11")
    if ($candidate) {
      return $candidate
    }
    foreach ($version in @("-3.12", "-3.10")) {
      $candidate = Test-PythonInvoker -FilePath $py.Source -PrefixArgs @($version)
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

  return $null
}

function Invoke-Python {
  param(
    [Parameter(Mandatory=$true)][object]$Python,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments
  )
  & $Python.FilePath @($Python.PrefixArgs + $Arguments)
}

$pythonCmd = Get-PythonInvoker
if (-not $pythonCmd) {
  Write-Error "Python 3.10-3.12 was not found. Install Python 3.11 before setting up FunASR."
  exit 1
}

if (-not (Test-Path -LiteralPath $EnvDir)) {
  Invoke-Python -Python $pythonCmd -m venv $EnvDir
}

$python = Join-Path $EnvDir "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
  Write-Error "Python executable not found after venv creation: $python"
  exit 1
}

& $python -m pip install -U pip
& $python -m pip install -U torch torchaudio funasr modelscope huggingface_hub soundfile
try {
  & $python -m pip install -U editdistance
} catch {
  Write-Warning "Optional package editdistance was not installed. This only affects WER/CER evaluation metrics, not livestream transcription or reports."
}

Write-Host "FunASR environment ready."
Write-Host "Python: $python"

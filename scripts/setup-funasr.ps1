param(
  [string]$EnvDir = ""
)

$skillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $EnvDir) {
  $EnvDir = Join-Path $skillDir ".venv-funasr"
}

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  $pythonCmd = Get-Command python.exe -ErrorAction SilentlyContinue
}

if (-not $pythonCmd) {
  Write-Error "Python was not found. Install Python 3.10+ or 3.11+ before setting up FunASR."
  exit 1
}

if (-not (Test-Path -LiteralPath $EnvDir)) {
  & $pythonCmd.Source -m venv $EnvDir
}

$python = Join-Path $EnvDir "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
  Write-Error "Python executable not found after venv creation: $python"
  exit 1
}

& $python -m pip install -U pip
& $python -m pip install -U torch torchaudio funasr modelscope huggingface_hub soundfile

Write-Host "FunASR environment ready."
Write-Host "Python: $python"

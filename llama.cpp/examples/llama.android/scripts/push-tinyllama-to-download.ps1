param(
    [string]$Adb = "adb",
    [string]$DevicePath = "/sdcard/Download/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf"
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$modelPath = Join-Path $repoRoot "models\tinyllama-1.1b-chat-v1.0-q4_k_m.gguf"

if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "TinyLlama model not found at: $modelPath"
}

Write-Host "Using model:" $modelPath
& $Adb start-server | Out-Null
& $Adb shell "mkdir -p /sdcard/Download" | Out-Null
& $Adb push $modelPath $DevicePath

if ($LASTEXITCODE -ne 0) {
    throw "adb push failed."
}

Write-Host "TinyLlama copied to:" $DevicePath
Write-Host "Open the Android app and import the model from the Download folder."

# Auto Drive Fetch – GitHub Pages installer
$url = "https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/ADF_CLI.cmd"
$out = "$env:temp\ADF_CLI.cmd"

try {
    Write-Host "Downloading Auto Drive Fetch..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    if (Test-Path $out) {
        Write-Host "✅ Download successful. Starting installer..." -ForegroundColor Green
        Start-Process $out -Wait
    }
}
catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    pause
    exit 1
}
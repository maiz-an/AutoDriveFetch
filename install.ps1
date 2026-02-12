# Auto Drive Fetch – One‑line installer from GitHub Pages
$rawUrl = "https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/ADF_CLI.cmd"
$outFile = "$env:temp\ADF_CLI.cmd"

try {
    # Add cache‑buster to force fresh download
    $cacheBuster = "?cachebust=$([guid]::NewGuid())"
    Invoke-WebRequest -Uri "$rawUrl$cacheBuster" -OutFile $outFile -UseBasicParsing
    if (Test-Path $outFile) {
        Write-Host "✅ Download successful. Starting installer..." -ForegroundColor Green
        Start-Process $outFile -Wait
    }
}
catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    pause
    exit 1
}
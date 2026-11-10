$ErrorActionPreference = 'Stop'

$project = Join-Path $PSScriptRoot 'Windows\CapriCompanion.Windows.csproj'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Capri Companion'
$stageDir = Join-Path $env:TEMP "CapriCompanion-publish-$PID"
$sdkDir = Join-Path $env:LOCALAPPDATA 'CapriCompanion\dotnet-sdk'

function Get-DotNetSdkMajor {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $null }
    $versions = & dotnet --list-sdks 2>$null
    foreach ($version in $versions) {
        if ($version -match '^10\.') { return 10 }
    }
    return $null
}

$sdkMajor = Get-DotNetSdkMajor
if ($null -eq $sdkMajor) {
    Write-Host '.NET 10 SDK is missing. Installing it for your Windows account…' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $bootstrap = Join-Path $env:TEMP 'capri-dotnet-install.ps1'
    Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $bootstrap
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap -Channel '10.0' -InstallDir $sdkDir
    if ($LASTEXITCODE -ne 0) { throw '.NET SDK installation failed.' }
    $env:PATH = "$sdkDir;$env:PATH"
}

$runtime = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win-arm64' } else { 'win-x64' }
Write-Host "Building Capri for $runtime and installing it for this Windows account…" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
& dotnet publish $project --configuration Release --runtime $runtime --self-contained true --output $stageDir
if ($LASTEXITCODE -ne 0) { throw 'Capri could not be built. Check the messages above and try again.' }

$app = Join-Path $installDir 'CapriCompanion.exe'
if (-not (Test-Path (Join-Path $stageDir 'CapriCompanion.exe'))) { throw 'Build completed, but CapriCompanion.exe was not created.' }
Get-Process -Name 'CapriCompanion' -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $installDir) { Remove-Item -Path $installDir -Recurse -Force }
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item -Path (Join-Path $stageDir '*') -Destination $installDir -Recurse -Force
Remove-Item -Path $stageDir -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $app)) { throw "Install completed, but $app was not created." }
Start-Process -FilePath $app
Write-Host "Capri is installed in $installDir" -ForegroundColor Green

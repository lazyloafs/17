param(
    [string]$Archetype = "rf_arcane_devotion",
    [int]$Generations = 60,
    [int]$Population = 60,
    [string]$BuildName = "",
    [switch]$NoTradeItems,
    [switch]$SkipClusters
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Ensure PoB is patched
& (Join-Path $RepoRoot "install-button.ps1") -HeadlessOnly

$PoBDir = $env:POB_PATH
if (-not $PoBDir) { $PoBDir = "E:\Path of Building Community" }

$settingsDir = Join-Path $env:APPDATA "Path of Building\Settings"
$headlessConfig = Join-Path $settingsDir "headless_optimizer_request.json"

$request = @{
    archetype = $Archetype
    generations = $Generations
    population = $Population
    useTradeItems = (-not $NoTradeItems)
    optimizeClusters = (-not $SkipClusters)
    requireRegen = $true
    buildName = $BuildName
    timestamp = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 4

New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
Set-Content -Path $headlessConfig -Value $request

Write-Host "Headless optimizer request written."
Write-Host "  Archetype:  $Archetype"
Write-Host "  GA:         ${Generations}/${Population} (tournament selection)"
Write-Host "  Trade pool: $(-not $NoTradeItems)"
Write-Host "  Clusters:   $(-not $SkipClusters)"
Write-Host ""
Write-Host "Open Path of Building, load your build, then click 'Deep Optimize' on the Tree tab."
Write-Host "Or run with PoB open — the optimizer reads: $headlessConfig"
Write-Host ""
Write-Host "For fully automated headless runs, PoB must be running with the patched module."
Write-Host "The engine applies results directly to the active build save."

# Optional: launch PoB minimized if not running
$pobExe = Join-Path $PoBDir "Path of Building.exe"
if (Test-Path $pobExe) {
    $proc = Get-Process -Name "Path of Building" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "Starting PoB..."
        Start-Process $pobExe
    }
}

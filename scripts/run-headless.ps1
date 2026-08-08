param(
    [string]$Archetype = "rf_arcane_devotion",
    [int]$Generations = 60,
    [int]$Population = 60,
    [string]$BuildName = "",
    [switch]$NoTradeItems,
    [switch]$SkipClusters,
    [switch]$DualPhase,
    [switch]$OptimizeJewels
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

& (Join-Path $RepoRoot "install-button.ps1") -HeadlessOnly

$PoBDir = $env:POB_PATH
if (-not $PoBDir) { $PoBDir = "E:\Path of Building Community" }

$settingsDir = Join-Path $env:APPDATA "Path of Building\Settings"
$headlessConfig = Join-Path $settingsDir "headless_optimizer_request.json"

if (-not $PSBoundParameters.ContainsKey('DualPhase')) { $DualPhase = $true }
if (-not $PSBoundParameters.ContainsKey('OptimizeJewels')) { $OptimizeJewels = $true }

$request = @{
    archetype = $Archetype
    generations = $Generations
    population = $Population
    dualPhase = $DualPhase.IsPresent
    useTradeItems = (-not $NoTradeItems)
    optimizeClusters = (-not $SkipClusters)
    optimizeJewels = $OptimizeJewels.IsPresent
    mutateJewelPaths = $OptimizeJewels.IsPresent
    requireRegen = $true
    buildName = $BuildName
    baselinePath = (Join-Path $RepoRoot "builds\baseline_rf_arcane_devotion.pob.txt")
    timestamp = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 4

New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
Set-Content -Path $headlessConfig -Value $request

Write-Host "localoptimizer headless request queued."
Write-Host "  Archetype:   $Archetype"
Write-Host "  Phase 1:     $Generations gens x $Population pop (main: max DPS/mana)"
if ($DualPhase) {
    Write-Host "  Phase 2:     $Generations gens x $Population pop (opposite: regen/eHP, retain DPS floor)"
}
Write-Host "  Trade pool:  $(-not $NoTradeItems)"
Write-Host "  Clusters:    $(-not $SkipClusters)"
Write-Host "  SP jewels:   $OptimizeJewels"
Write-Host "  Baseline:    builds\baseline_rf_arcane_devotion.pob.txt"
Write-Host ""
Write-Host "Config: $headlessConfig"

$pobExe = Join-Path $PoBDir "Path of Building.exe"
if (Test-Path $pobExe) {
    $proc = Get-Process -Name "Path of Building" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "Starting PoB..."
        Start-Process $pobExe
    }
}

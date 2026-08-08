param(
    [string]$Archetype = "rf_arcane_devotion",
    [int]$Generations = 60,
    [int]$Population = 60,
    [string]$BuildName = "",
    [ValidateSet("dps", "tank", "dual")]
    [string]$Mode = "dual",
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

if ($Mode -eq "dps") {
    $Archetype = "generic_dps"
    $DualPhase = $false
    $singlePhase = "main"
    $requireRegen = $false
} elseif ($Mode -eq "tank") {
    $Archetype = "generic_tanky"
    $DualPhase = $false
    $singlePhase = "opposite"
    $requireRegen = $true
} else {
    if (-not $PSBoundParameters.ContainsKey('DualPhase')) { $DualPhase = $true }
    $singlePhase = $null
    $requireRegen = $true
}

if (-not $PSBoundParameters.ContainsKey('OptimizeJewels')) { $OptimizeJewels = $true }

$request = @{
    archetype = $Archetype
    generations = $Generations
    population = $Population
    dualPhase = [bool]$DualPhase
    singlePhase = $singlePhase
    useTradeItems = (-not $NoTradeItems)
    optimizeClusters = (-not $SkipClusters)
    optimizeJewels = [bool]$OptimizeJewels
    mutateJewelPaths = [bool]$OptimizeJewels
    requireRegen = [bool]$requireRegen
    buildName = $BuildName
    baselinePath = (Join-Path $RepoRoot "builds\baseline_rf_arcane_devotion.pob.txt")
    timestamp = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 4

New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
Set-Content -Path $headlessConfig -Value $request

Write-Host "localoptimizer headless request queued."
Write-Host "  Mode:        $Mode"
Write-Host "  Archetype:   $Archetype"
Write-Host "  Generations: $Generations x $Population"
if ($DualPhase) {
    Write-Host "  Phase 2:     $Generations gens x $Population pop (opposite: regen/eHP, retain DPS floor)"
} elseif ($singlePhase) {
    Write-Host "  Single phase: $singlePhase"
}
Write-Host "  Trade pool:  $(-not $NoTradeItems)"
Write-Host "  Clusters:    $(-not $SkipClusters)"
Write-Host "  SP jewels:   $OptimizeJewels"
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

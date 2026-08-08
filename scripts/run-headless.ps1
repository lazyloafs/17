param(
    [string]$Archetype = "rf_arcane_devotion",
    [int]$Generations = 60,
    [int]$Population = 60,
    [string]$BuildName = "",
    [switch]$NoTradeItems,
    [switch]$SkipClusters,
    [switch]$DualPhase,
    [switch]$OptimizeJewels,
    [switch]$NoZigzag,
    [int]$Phase1EliteCarryover = 12,
    [double]$Phase2MutationRate = 0.20
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

& (Join-Path $RepoRoot "install-button.ps1") -HeadlessOnly

$PoBDir = $env:POB_PATH
if (-not $PoBDir) { $PoBDir = "E:\Path of Building Community" }

$settingsDir = Join-Path $env:APPDATA "Path of Building\Settings"
$headlessConfig = Join-Path $settingsDir "headless_optimizer_request.json"
$logPath = Join-Path $settingsDir "localoptimizer.log"

if (-not $PSBoundParameters.ContainsKey('DualPhase')) { $DualPhase = $true }
if (-not $PSBoundParameters.ContainsKey('OptimizeJewels')) { $OptimizeJewels = $true }

$request = @{
    archetype = $Archetype
    generations = $Generations
    population = $Population
    dualPhase = [bool]$DualPhase
    useTradeItems = (-not $NoTradeItems)
    optimizeClusters = (-not $SkipClusters)
    optimizeJewels = [bool]$OptimizeJewels
    mutateJewelPaths = [bool]$OptimizeJewels
    preferZigzagPaths = (-not $NoZigzag)
    requireRegen = $true
    noTimeLimit = $true
    timeLimitSeconds = $null
    phase1EliteCarryover = $Phase1EliteCarryover
    phase2MutationRate = $Phase2MutationRate
    buildName = $BuildName
    baselinePath = (Join-Path $RepoRoot "builds\baseline_rf_arcane_devotion.pob.txt")
    phases = @{
        main = @{ generations = $Generations; objective = "max_dps_mana" }
        opposite = @{ generations = $Generations; objective = "max_regen_ehp"; retainDpsRatio = 0.92 }
    }
    splitPersonality = @{
        enabled = [bool]$OptimizeJewels
        preferZigzag = (-not $NoZigzag)
        rule = "25% increased effect per Allocated Passive Skill between jewel and class start"
    }
    timestamp = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 6

New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
Set-Content -Path $headlessConfig -Value $request
Add-Content -Path $logPath -Value ("{0} queued dualPhase={1} gens={2} pop={3} jewels={4} noTimeLimit=true" -f (Get-Date -Format "o"), $DualPhase, $Generations, $Population, $OptimizeJewels)

Write-Host "localoptimizer headless request queued."
Write-Host "  Archetype:   $Archetype"
Write-Host "  Phase 1:     $Generations gens x $Population pop (main: max DPS/mana)"
if ($DualPhase) {
    Write-Host "  Phase 2:     $Generations gens x $Population pop (opposite: regen/eHP, retain DPS floor)"
    Write-Host "  Carryover:   $Phase1EliteCarryover phase-1 elites into phase 2"
}
Write-Host "  Time limit:  none (local — runs all generations to completion)"
Write-Host "  Trade pool:  $(-not $NoTradeItems)"
Write-Host "  Clusters:    $(-not $SkipClusters)"
Write-Host "  SP jewels:   $OptimizeJewels (zigzag=$(-not $NoZigzag))"
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

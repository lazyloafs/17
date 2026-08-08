# Idempotent PoB patcher — copies optimizer modules and wires the Deep Optimize button (~1s).
param(
    [string]$PoBDir = $env:POB_PATH,
    [switch]$HeadlessOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $PoBDir -or -not (Test-Path $PoBDir)) {
    $PoBDir = "E:\Path of Building Community"
}
if (-not (Test-Path $PoBDir)) {
    Write-Error "PoB not found at '$PoBDir'. Set POB_PATH to your Path of Building Community folder."
}

$Marker = "# poenodefinderlocally-deep-optimizer"
$BuildLua = Join-Path $PoBDir "Modules\Build.lua"
$DestModule = Join-Path $PoBDir "Modules\DeepOptimizer.lua"
$DestEngine = Join-Path $PoBDir "DeepOptimizer"

# Copy optimizer engine
New-Item -ItemType Directory -Force -Path $DestEngine | Out-Null
Copy-Item -Force (Join-Path $RepoRoot "optimizer\*") $DestEngine
Copy-Item -Force (Join-Path $RepoRoot "pob-patch\Modules\DeepOptimizer.lua") $DestModule
Copy-Item -Force -Recurse (Join-Path $RepoRoot "configs") (Join-Path $PoBDir "DeepOptimizer\configs")

# Patch Build.lua once
if (Test-Path $BuildLua) {
    $content = Get-Content $BuildLua -Raw
    if ($content -notmatch [regex]::Escape($Marker)) {
        $hook = @"

$Marker
if not self.deepOptimizer then
	self.deepOptimizer = LoadModule("Modules/DeepOptimizer")
end
if self.deepOptimizer then
	self.deepOptimizer:Init(self)
end
"@
        # Insert after Build module constructor begins (after function declaration)
        if ($content -match '(?s)(function BuildModule:New\(\).*?self\.abortSave\s*=\s*false)') {
            $content = $content -replace '(?s)(function BuildModule:New\(\).*?self\.abortSave\s*=\s*false)', "`$1`n$hook"
            Set-Content -Path $BuildLua -Value $content -NoNewline
            Write-Host "Patched Build.lua with deep optimizer hook."
        } else {
            Write-Warning "Could not auto-patch Build.lua — DeepOptimizer.lua was copied; add manual hook if button missing."
        }
    }
} else {
    Write-Warning "Build.lua not found — module copied only."
}

# Copy configs to user settings for headless runs
$settingsDir = Join-Path $env:APPDATA "Path of Building\Settings"
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
Copy-Item -Force (Join-Path $RepoRoot "configs\optimizer-defaults.json") (Join-Path $settingsDir "deep_optimizer_defaults.json")

Write-Host "poenodefinderlocally optimizer installed to: $PoBDir"
if ($HeadlessOnly) { exit 0 }

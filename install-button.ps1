# Idempotent PoB patcher — copies optimizer modules and wires Opt DPS / Opt Tank buttons (~1s).
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

$Marker = "# localoptimizer-deep-optimizer"
$BuildLua = Join-Path $PoBDir "Modules\Build.lua"
$DestModule = Join-Path $PoBDir "Modules\DeepOptimizer.lua"
$DestEngine = Join-Path $PoBDir "DeepOptimizer"

# Copy optimizer engine
New-Item -ItemType Directory -Force -Path $DestEngine | Out-Null
Copy-Item -Force (Join-Path $RepoRoot "optimizer\*") $DestEngine
Copy-Item -Force (Join-Path $RepoRoot "pob-patch\Modules\DeepOptimizer.lua") $DestModule
Copy-Item -Force -Recurse (Join-Path $RepoRoot "configs") (Join-Path $PoBDir "DeepOptimizer\configs")
if (Test-Path (Join-Path $RepoRoot "builds")) {
    Copy-Item -Force -Recurse (Join-Path $RepoRoot "builds") (Join-Path $PoBDir "DeepOptimizer\builds")
}

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

Write-Host "localoptimizer installed to: $PoBDir"

# Patch TreeTab.lua once — wires Opt DPS / Opt Tank buttons when a build opens
$TreeTabMarker = "# localoptimizer-tree-tab-hook"
$TreeTabLua = Join-Path $PoBDir "Classes\TreeTab.lua"
if (Test-Path $TreeTabLua) {
    $treeContent = Get-Content $TreeTabLua -Raw
    if ($treeContent -notmatch [regex]::Escape($TreeTabMarker)) {
        $treeHook = @"

$TreeTabMarker
if main and main.deepOptimizer then
	main.deepOptimizer:HookBuild(build, self)
end
"@
        if ($treeContent -match 'self\.controls\.powerReportList\.shown\s*=\s*false') {
            $treeContent = $treeContent -replace '(self\.controls\.powerReportList\.shown\s*=\s*false)', "`$1`n$treeHook"
            Set-Content -Path $TreeTabLua -Value $treeContent -NoNewline
            Write-Host "Patched TreeTab.lua with Opt DPS / Opt Tank button hook."
        } else {
            Write-Warning "Could not auto-patch TreeTab.lua — buttons may not appear until manual hook is added."
        }
    }
} else {
    Write-Warning "TreeTab.lua not found — button hook skipped."
}

if ($HeadlessOnly) { exit 0 }

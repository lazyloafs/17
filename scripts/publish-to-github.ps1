# Publish this tree to https://github.com/lazyloafs/localoptimizer
# Prerequisites: GitHub CLI logged in as lazyloafs (or a PAT with repo scope)
param(
    [string]$RepoName = "localoptimizer",
    [string]$Owner = "lazyloafs",
    [string]$Branch = "master"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

$remote = "https://github.com/$Owner/$RepoName.git"
Write-Host "Publishing to $remote ($Branch)..."

$exists = $true
try {
    gh repo view "$Owner/$RepoName" | Out-Null
} catch {
    $exists = $false
}

if (-not $exists) {
    Write-Host "Creating public repo $Owner/$RepoName ..."
    gh repo create "$Owner/$RepoName" --public --source=. --remote=localoptimizer --push
    Write-Host "Done. https://github.com/$Owner/$RepoName"
    exit 0
}

if (-not (git remote | Select-String -Pattern '^localoptimizer$')) {
    git remote add localoptimizer $remote
} else {
    git remote set-url localoptimizer $remote
}

git push -u localoptimizer "HEAD:refs/heads/$Branch" --force
Write-Host "Published. Clone: git clone https://github.com/$Owner/$RepoName"

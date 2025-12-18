param(
    [string]$BasePack,
    [string]$OverlayPack,
    [string]$Output
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-ResourcePacks {
    param([string]$Folder)
    Get-ChildItem -Path $Folder -Directory | ForEach-Object {
        $manifestPath = Join-Path $_.FullName "manifest.json"
        if (Test-Path $manifestPath) {
            try {
                $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
                $hasResource = $m.modules | Where-Object { $_.type -eq "resources" }
                if ($hasResource) {
                    [PSCustomObject]@{
                        Name = $_.Name
                        Path = $_.FullName
                    }
                }
            } catch {
                # Hellow fellow Comment Reader, this just ignores.
            }
        }
    }
}

function Pick-Pack {
    param(
        [array]$Packs,
        [string]$Label
    )
    Write-Host ""; Write-Host "Select $Label pack:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Packs.Count; $i++) {
        Write-Host "[$i] $($Packs[$i].Name)"
    }
    $choice = Read-Host "Enter number"
    if (-not ($choice -as [int]) -or $choice -lt 0 -or $choice -ge $Packs.Count) {
        throw "Invalid selection for $Label."
    }
    return $Packs[$choice]
}

$packs = Get-ResourcePacks -Folder $root
if (-not $packs -or $packs.Count -lt 2) { throw "Need at least two resource packs in $root" }

# Resolve Base
if ($BasePack) {
    $basePath = Join-Path $root $BasePack
    if (-not (Test-Path $basePath)) { throw "Base pack not found: $basePath" }
    $base = [PSCustomObject]@{ Name = Split-Path $basePath -Leaf; Path = $basePath }
} else {
    $base = Pick-Pack -Packs $packs -Label "BASE (keeps original assets)"
}

# Resolve Overlay
if ($OverlayPack) {
    $overlayPath = Join-Path $root $OverlayPack
    if (-not (Test-Path $overlayPath)) { throw "Overlay pack not found: $overlayPath" }
    $overlay = [PSCustomObject]@{ Name = Split-Path $overlayPath -Leaf; Path = $overlayPath }
} else {
    $overlay = Pick-Pack -Packs $packs -Label "OVERLAY (assets to merge/override)"
}

if (-not $Output) {
    $safeBase = ($base.Name -replace "[^A-Za-z0-9_-]","_")
    $safeOverlay = ($overlay.Name -replace "[^A-Za-z0-9_-]","_")
    $Output = "merged_${safeBase}_${safeOverlay}"
}

$outPath = Join-Path $root $Output
if ($outPath -eq $base.Path -or $outPath -eq $overlay.Path) { throw "Output folder must differ from source packs." }

if (Test-Path $outPath) { Remove-Item $outPath -Recurse -Force }
Copy-Item $base.Path $outPath -Recurse -Force

Write-Host "Merging overlay pack assets..." -ForegroundColor Yellow
$overlayItems = Get-ChildItem -Path $overlay.Path -Recurse -Force
foreach ($item in $overlayItems) {
    if ($item.Name -eq "manifest.json" -and $item.Directory.FullName -eq $overlay.Path) {
        continue
    }
    
    $relativePath = $item.FullName.Substring($overlay.Path.Length + 1)
    $destPath = Join-Path $outPath $relativePath
    
    if ($item.PSIsContainer) {
        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        }
    } else {
        $destDir = Split-Path $destPath
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $item.FullName -Destination $destPath -Force
    }
}

$manifestPath = Join-Path $outPath "manifest.json"
if (Test-Path $manifestPath) {
    $json = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $json.header.name = "$($base.Name) + $($overlay.Name) (Merged)"
    $json.header.description = "Base: $($base.Name) with assets merged from: $($overlay.Name)."
    $json.header.uuid = [guid]::NewGuid().ToString()
    if ($json.modules.Count -gt 0) { $json.modules[0].uuid = [guid]::NewGuid().ToString() }
    $json | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
}

Write-Host "Merged pack created at: $outPath" -ForegroundColor Green
Write-Host "Total files merged: $(Get-ChildItem $outPath -Recurse -Force | Where-Object { -not $_.PSIsContainer } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor Green

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

if ($BasePack) {
    $basePath = Join-Path $root $BasePack
    if (-not (Test-Path $basePath)) { throw "Base pack not found: $basePath" }
    $base = [PSCustomObject]@{ Name = Split-Path $basePath -Leaf; Path = $basePath }
} else {
    $base = Pick-Pack -Packs $packs -Label "BASE (keeps most assets)"
}

if ($OverlayPack) {
    $overlayPath = Join-Path $root $OverlayPack
    if (-not (Test-Path $overlayPath)) { throw "Overlay pack not found: $overlayPath" }
    $overlay = [PSCustomObject]@{ Name = Split-Path $overlayPath -Leaf; Path = $overlayPath }
} else {
    $overlay = Pick-Pack -Packs $packs -Label "OVERLAY (UI to apply)"
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

$copyPairs = @(
    @{ Source = Join-Path $overlay.Path "ui"; Dest = Join-Path $outPath "ui" },
    @{ Source = Join-Path $overlay.Path "textures\guis"; Dest = Join-Path $outPath "textures\guis" },
    @{ Source = Join-Path $overlay.Path "textures\playtime"; Dest = Join-Path $outPath "textures\playtime" },
    @{ Source = Join-Path $overlay.Path "Kafal-Settings.json"; Dest = Join-Path $outPath "Kafal-Settings.json" }
)

foreach ($pair in $copyPairs) {
    if (Test-Path $pair.Source) {
        Copy-Item $pair.Source $pair.Dest -Recurse -Force
    }
}

$manifestPath = Join-Path $outPath "manifest.json"
if (Test-Path $manifestPath) {
    $json = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $json.header.name = "$($base.Name) + $($overlay.Name) (Merged with GeyserPackMerger by LarroxTv)"
    $json.header.description = "This Pack was merged by GeyserPackMerger, created by LarroxTv"
    $json.header.uuid = [guid]::NewGuid().ToString()
    if ($json.modules.Count -gt 0) { $json.modules[0].uuid = [guid]::NewGuid().ToString() }
    $json | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
}

Write-Host "Merged pack created at: $outPath" -ForegroundColor Green

# GeyserPackMerger

Merge two Bedrock resource packs – the overlay pack's assets are layered onto the base pack. All files and folders are merged recursively, with overlay assets overriding base pack conflicts.

## What the Script Does
- Finds all resource packs in the folder (manifest.json with modules.type="resources").
- Copies the base pack into a new output folder.
- Recursively overlays **all** files and folders from the overlay pack (except manifest.json).
- Generates fresh UUIDs and renames the manifest title based on the selected packs.

## Requirements
- Windows with PowerShell 5+.
- Both packs extracted in the same folder as the script.

## Usage (Interactive)
1) Open PowerShell in the folder containing the script and packs.
2) Run the script:
   ```powershell
   .\geyser_pack_merger.ps1
   ```
3) Select numbers for the base pack (keeps original assets) and overlay pack (assets to merge).
4) Output folder is created as `merged_<base>_<overlay>`. Zip this folder and load it as a resource pack.

## Usage (With Parameters)
```powershell
.\geyser_pack_merger.ps1 -BasePack "MaCoolPack" -OverlayPack "SecondRandomPack" -Output "merged_cool_random_pack"
```

## Notes
- Output folder must differ from source packs; any existing output will be overwritten.
- All files from the overlay pack recursively override matching files in the base pack.
- The manifest.json remains from the base pack (only name, description, and UUIDs are updated).
- After zipping, place the pack high in the resource pack stack for overlay assets to take effect.

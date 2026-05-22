# =========================================================
# WINDOWS APPDATA / CACHE MIGRATION TOOL
# LINK / UNLINK MODES  |  CUSTOM DESTINATION NAMING
# =========================================================
# RUN POWERSHELL AS ADMINISTRATOR
# =========================================================

# =========================================================
# UTILITY FUNCTIONS
# =========================================================

function Write-Section($text) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Write-Good($text) { Write-Host "[+] $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "[!] $text" -ForegroundColor Yellow }
function Write-Bad($text)  { Write-Host "[X] $text" -ForegroundColor Red }

function Read-Input($prompt) {
    $val = (Read-Host "$prompt  [Q=Quit / R=Restart]").Trim()
    if ($val.ToUpper() -eq "Q") {
        Write-Warn "Exiting..."
        exit
    }
    if ($val.ToUpper() -eq "R") {
        Write-Warn "Restarting..."
        if ($PSCommandPath) {
            & $PSCommandPath
        } else {
            Write-Bad "Cannot restart: script was not run from a .ps1 file."
        }
        exit
    }
    return $val
}

function Get-FolderType($path) {
    if ($path -like "*AppData\Roaming*")  { return "Roaming"  }
    if ($path -like "*AppData\LocalLow*") { return "LocalLow" }
    if ($path -like "*AppData\Local*")    { return "Local"    }
    if ($path -like "*\.*")               { return "Root"     }
    return "Other"
}

# =========================================================
# MODE SELECT
# =========================================================

Write-Host ""
Write-Host "########################################" -ForegroundColor DarkCyan
Write-Host "#   AppData Migration Tool             #" -ForegroundColor DarkCyan
Write-Host "#   [L] Link   |   [U] Unlink          #" -ForegroundColor DarkCyan
Write-Host "########################################" -ForegroundColor DarkCyan
Write-Host ""

$modeInput = (Read-Input "Select mode  [L = Link / U = Unlink]").ToUpper()

if ($modeInput -notin @("L", "U")) {
    Write-Bad "Invalid mode. Enter L or U."
    Read-Host "Press Enter to exit"
    exit
}

$mode = if ($modeInput -eq "L") { "LINK" } else { "UNLINK" }

# =========================================================
# ==================  LINK MODE  ==========================
# =========================================================

if ($mode -eq "LINK") {

    # -------------------------------------------------------
    # CONFIG
    # -------------------------------------------------------

    $app = Read-Input "App name to migrate (used for scanning)"

    Write-Host ""
    Write-Host "Destination folder name on D:\ drive." -ForegroundColor DarkGray
    Write-Host "Press ENTER to use default: [$app]" -ForegroundColor DarkGray
    $customName = Read-Input "Custom destination folder name (or ENTER for default)"

    if ([string]::IsNullOrWhiteSpace($customName)) {
        $customName = $app
    }

    $base    = $HOME
    $appRoot = "D:\APPDATA_REDIRECT\$customName"

    Write-Good "Destination root: $appRoot"

    $results  = @()
    $snapshot = @{}

    # -------------------------------------------------------
    # SCAN
    # -------------------------------------------------------

    Write-Section "SCANNING FOR APP FOLDERS"

    $scanPaths = @(
        (Join-Path $base "AppData\Local"),
        (Join-Path $base "AppData\Roaming"),
        (Join-Path $base "AppData\LocalLow"),
        (Join-Path $base "AppData\Local\Programs"),
        (Join-Path $base "AppData\Roaming\Microsoft\Windows\Start Menu")
    )

    foreach ($scanPath in $scanPaths) {
        if (-not (Test-Path $scanPath)) { continue }
        Get-ChildItem $scanPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$app*" } |
        ForEach-Object { $results += $_.FullName }
    }

    Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$app*" -or $_.Name -like ".$app*" } |
    ForEach-Object { $results += $_.FullName }

    $results = $results | Select-Object -Unique

    if ($results.Count -eq 0) {
        Write-Bad "No folders found matching '$app'"
        Read-Host "Press Enter to exit"
        exit
    }

    # -------------------------------------------------------
    # CATEGORISE
    # -------------------------------------------------------

    Write-Section "FOUND FOLDERS"

    $selectableFolders = @()
    $migratedFolders   = @()

    foreach ($path in $results) {
        $type = Get-FolderType $path
        $item = Get-Item $path -ErrorAction SilentlyContinue

        if ($item -and $item.LinkType -eq "Junction") {
            $target = if ($item.Target -is [array]) { $item.Target[0] } else { $item.Target }
            if ($target -and (Test-Path $target)) {
                $migratedFolders += [PSCustomObject]@{ Path = $path; Type = $type; Target = $target }
                continue
            }
        }

        $selectableFolders += [PSCustomObject]@{ Path = $path; Type = $type }
    }

    # ---- Already migrated ----
    if ($migratedFolders.Count -gt 0) {
        Write-Host ""
        Write-Host "[ALREADY LINKED / MIGRATED]" -ForegroundColor Green
        Write-Host "--------------------------------------------------"
        foreach ($m in $migratedFolders) {
            Write-Host ""
            Write-Host "  [-] [$($m.Type)]"
            Write-Host "      $($m.Path)"
            Write-Host "       -> $($m.Target)" -ForegroundColor DarkGray
        }
    }

    # ---- Ready to migrate ----
    if ($selectableFolders.Count -eq 0) {
        Write-Host ""
        Write-Good "Everything already linked. Nothing to do."
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host ""
    Write-Host "[READY TO LINK]" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------"

    for ($i = 0; $i -lt $selectableFolders.Count; $i++) {
        Write-Host ""
        Write-Host "  [$($i+1)] [$($selectableFolders[$i].Type)]"
        Write-Host "      $($selectableFolders[$i].Path)"
    }

    # -------------------------------------------------------
    # SELECT WHICH TO MIGRATE
    # -------------------------------------------------------

    Write-Host ""
    $choice = Read-Input "Select folders to link (e.g. 1,2  OR  all)"

    $selectedFolders = @()

    if ($choice.Trim().ToLower() -eq "all") {
        $selectedFolders = $selectableFolders
    } else {
        foreach ($idx in ($choice -split "," | ForEach-Object { $_.Trim() })) {
            if ($idx -match '^\d+$') {
                $num = [int]$idx - 1
                if ($num -ge 0 -and $num -lt $selectableFolders.Count) {
                    $selectedFolders += $selectableFolders[$num]
                }
            }
        }
    }

    if ($selectedFolders.Count -eq 0) {
        Write-Bad "No valid folders selected."
        Read-Host "Press Enter to exit"
        exit
    }

    # -------------------------------------------------------
    # CUSTOM DESTINATION NAMES (only for selected folders)
    # -------------------------------------------------------

    Write-Host ""
    Write-Host "Custom destination sub-folder name for each selected folder." -ForegroundColor DarkGray
    Write-Host "Press ENTER to keep the original folder name." -ForegroundColor DarkGray
    Write-Host ""

    $folderDestNames = @{}

    foreach ($f in $selectedFolders) {
        $origLeaf = Split-Path $f.Path -Leaf
        $hint = Read-Input "  Destination name for '$origLeaf' (ENTER = keep '$origLeaf')"
        $hint = $hint.Trim()
        if ([string]::IsNullOrWhiteSpace($hint)) { $hint = $origLeaf }
        $folderDestNames[$f.Path] = $hint
    }

    $approvedFolders = $selectedFolders | ForEach-Object { $_.Path }

    # -------------------------------------------------------
    # SNAPSHOT
    # -------------------------------------------------------

    Write-Section "CREATING SNAPSHOTS"

    foreach ($orig in $approvedFolders) {

        if ($orig -like "*Microsoft*" -or $orig -like "*Temp*" -or $orig -like "C:\Windows*") {
            Write-Warn "Skipping dangerous folder: $orig"
            continue
        }

        $type     = Get-FolderType $orig
        $leafName = $folderDestNames[$orig]

        $dest = switch ($type) {
            "Roaming"  { "$appRoot\Roaming\$leafName"  }
            "LocalLow" { "$appRoot\LocalLow\$leafName" }
            "Local"    { "$appRoot\Local\$leafName"    }
            default    { "$appRoot\Root\$leafName"     }
        }

        $fileCount = (Get-ChildItem $orig -Recurse -ErrorAction SilentlyContinue).Count
        $sizeKB    = [math]::Round((
            Get-ChildItem $orig -Recurse -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum
        ).Sum / 1KB, 1)

        $snapshot[$orig] = @{ dest = $dest; files = $fileCount; sizeKB = $sizeKB; state = "pending" }

        Write-Good "Snapshot: $orig"
        Write-Host "    Dest    : $dest"
        Write-Host "    Files   : $fileCount  |  Size KB: $sizeKB"
    }

    # -------------------------------------------------------
    # MIGRATION
    # -------------------------------------------------------

    Write-Section "STARTING LINK MIGRATION"

    foreach ($orig in $snapshot.Keys) {

        $dest = $snapshot[$orig].dest

        Write-Host ""
        Write-Host "Linking: $orig" -ForegroundColor Cyan

        try {
            Stop-Process -Name $app -Force -ErrorAction SilentlyContinue

            $parent = Split-Path $dest -Parent
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            robocopy $orig $dest /E /MOVE /NFL /NDL /NJH /NJS | Out-Null
            $rc = $LASTEXITCODE

            if ($rc -gt 7) { throw "Robocopy failed (exit $rc)" }
            if (Test-Path $orig) { throw "Original still exists after move" }

            Write-Good "Files moved"

            New-Item -ItemType Junction -Path $orig -Target $dest | Out-Null

            $item = Get-Item $orig -ErrorAction SilentlyContinue
            if (-not $item -or $item.LinkType -ne "Junction") {
                throw "Junction creation failed"
            }

            Write-Good "Junction (mklink /J) created"
            Write-Host "    $orig  ->  $dest"

            $snapshot[$orig].state = "success"
        }
        catch {
            Write-Bad $_
            Write-Warn "Rolling back..."

            try {
                $item = Get-Item $orig -ErrorAction SilentlyContinue
                if ($item -and $item.LinkType -eq "Junction") {
                    Remove-Item $orig -Force
                }

                if (Test-Path $dest) {
                    robocopy $dest $orig /E /MOVE /NFL /NDL /NJH /NJS | Out-Null
                }

                if (Test-Path $orig) {
                    Write-Good "Rollback successful"
                    $snapshot[$orig].state = "rolled_back"
                } else {
                    Write-Bad "Rollback incomplete"
                    $snapshot[$orig].state = "manual_check_required"
                }
            }
            catch {
                Write-Bad "Rollback failed"
                $snapshot[$orig].state = "rollback_failed"
            }
        }
    }

    # -------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------

    Write-Section "LINK SUMMARY"

    $table = @()
    foreach ($orig in $snapshot.Keys) {
        $table += [PSCustomObject]@{
            Folder      = Split-Path $orig -Leaf
            Source      = $orig
            Destination = $snapshot[$orig].dest
            SizeKB      = $snapshot[$orig].sizeKB
            State       = $snapshot[$orig].state
        }
    }

    $table | Format-Table -AutoSize

    Write-Good "Link migration completed."
    Write-Host ""
    Read-Host "Press Enter to exit"
}

# =========================================================
# ==================  UNLINK MODE  ========================
# =========================================================

if ($mode -eq "UNLINK") {

    Write-Section "SCANNING FOR ALL JUNCTIONS (mklink /J)"

    $base      = $HOME
    $scanRoots = @(
        (Join-Path $base "AppData\Local"),
        (Join-Path $base "AppData\Roaming"),
        (Join-Path $base "AppData\LocalLow"),
        (Join-Path $base "AppData\Local\Programs"),
        $base
    )

    $junctions = @()

   foreach ($root in $scanRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LinkType -eq "Junction" } |
        ForEach-Object {
            $targetPath = if ($_.Target -is [array]) { $_.Target[0] } else { $_.Target }
            if ($targetPath -and (Test-Path $targetPath)) {
                $junctions += [PSCustomObject]@{
                    Path   = $_.FullName
                    Target = $targetPath
                    Type   = Get-FolderType $_.FullName
                }
            }
        }
    }

    # Deduplicate in case scan roots overlap
    $junctions = $junctions | Sort-Object Path -Unique

    if ($junctions.Count -eq 0) {
        Write-Bad "No active junctions found under your profile."
        Read-Host "Press Enter to exit"
        exit
    }

    # -------------------------------------------------------
    # DISPLAY ALL JUNCTIONS
    # -------------------------------------------------------

    Write-Host ""
    Write-Host "[ALL ACTIVE JUNCTIONS FOUND]" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------"

    for ($i = 0; $i -lt $junctions.Count; $i++) {
        Write-Host ""
        Write-Host "  [$($i+1)] [$($junctions[$i].Type)]"
        Write-Host "      Junction : $($junctions[$i].Path)"
        Write-Host "      Target   : $($junctions[$i].Target)" -ForegroundColor DarkGray
    }

    Write-Host ""
    $choice = Read-Input "Select junctions to UNLINK and restore (e.g. 1,2  OR  all)"

    $approved = @()

    if ($choice.Trim().ToLower() -eq "all") {
        $approved = $junctions
    } else {
        foreach ($idx in ($choice -split "," | ForEach-Object { $_.Trim() })) {
            if ($idx -match '^\d+$') {
                $num = [int]$idx - 1
                if ($num -ge 0 -and $num -lt $junctions.Count) {
                    $approved += $junctions[$num]
                }
            }
        }
    }

    if ($approved.Count -eq 0) {
        Write-Bad "No valid junctions selected."
        Read-Host "Press Enter to exit"
        exit
    }

    # -------------------------------------------------------
    # UNLINK & RESTORE
    # -------------------------------------------------------

    Write-Section "UNLINKING AND RESTORING DATA"

    $unlinkSummary = @()

    foreach ($j in $approved) {

        $jPath  = $j.Path
        $target = $j.Target

        Write-Host ""
        Write-Host "Unlinking: $jPath" -ForegroundColor Cyan
        Write-Host "  From   : $target" -ForegroundColor DarkGray

        $state = "pending"

        try {
            if (
                $jPath -like "*Microsoft*" -or
                $jPath -like "*Temp*" -or
                $jPath -like "C:\Windows*"
            ) {
                throw "Blocked: dangerous system path"
            }

            if (-not (Test-Path $target)) {
                throw "Target path does not exist: $target"
            }

            Remove-Item $jPath -Force

            if (Test-Path $jPath) {
                throw "Junction removal failed - path still present"
            }

            Write-Good "Junction removed"

            $parent = Split-Path $jPath -Parent
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            robocopy $target $jPath /E /MOVE /NFL /NDL /NJH /NJS | Out-Null
            $rc = $LASTEXITCODE

            if ($rc -gt 7) { throw "Robocopy restore failed (exit $rc)" }

            if (-not (Test-Path $jPath)) {
                throw "Restore destination missing after robocopy"
            }

            Write-Good "Data restored to original location"
            Write-Host "    $jPath"

            $remaining = (Get-ChildItem $target -Recurse -ErrorAction SilentlyContinue).Count
            if ($remaining -eq 0) {
                Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
                Write-Good "Empty target folder cleaned up"
            } else {
                Write-Warn "Target folder still has $remaining items (not deleted): $target"
            }

            $state = "restored"
        }
        catch {
            Write-Bad $_

            if (-not (Test-Path $jPath) -and (Test-Path $target)) {
                Write-Warn "Attempting to recreate junction to avoid data loss..."
                try {
                    New-Item -ItemType Junction -Path $jPath -Target $target | Out-Null
                    Write-Warn "Junction recreated. Unlink aborted safely."
                    $state = "aborted_junction_restored"
                }
                catch {
                    Write-Bad "Could not recreate junction. Manual intervention required."
                    $state = "manual_check_required"
                }
            } else {
                $state = "failed"
            }
        }

        $unlinkSummary += [PSCustomObject]@{
            Junction     = Split-Path $jPath -Leaf
            OriginalPath = $jPath
            RestoredFrom = $target
            State        = $state
        }
    }

    # -------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------

    Write-Section "UNLINK SUMMARY"

    $unlinkSummary | Format-Table -AutoSize

    Write-Good "Unlink process completed."
    Write-Host ""
    Read-Host "Press Enter to exit"
}

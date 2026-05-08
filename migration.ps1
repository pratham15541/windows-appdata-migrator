# =========================================================
# WINDOWS APPDATA / CACHE MIGRATION TOOL
# FULL ROBUST SAFE VERSION
# =========================================================

# RUN POWERSHELL AS ADMINISTRATOR

# =========================================================
# CONFIG
# =========================================================

$app = (Read-Host "Which app do you want to migrate?").Trim()

$base = $HOME
$appRoot = "D:\APPDATA_REDIRECT\$app"

$results = @()
$snapshot = @{}

# =========================================================
# UTILITY FUNCTIONS
# =========================================================

function Write-Section($text) {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host $text -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Write-Good($text) {

    Write-Host "[+] $text" -ForegroundColor Green
}

function Write-Warn($text) {

    Write-Host "[!] $text" -ForegroundColor Yellow
}

function Write-Bad($text) {

    Write-Host "[X] $text" -ForegroundColor Red
}

# =========================================================
# SCAN
# =========================================================

Write-Section "SCANNING FOR APP FOLDERS"

foreach ($sub in @("AppData\Local","AppData\Roaming","AppData\LocalLow")) {

    $scanPath = Join-Path $base $sub

    if (Test-Path $scanPath) {

        Get-ChildItem $scanPath -Directory -ErrorAction SilentlyContinue |

        Where-Object {
            $_.Name -like "*$app*"
        } |

        ForEach-Object {
            $results += $_.FullName
        }
    }
}

Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |

Where-Object {
    $_.Name -like "*$app*" -or
    $_.Name -like ".$app*"
} |

ForEach-Object {
    $results += $_.FullName
}

$programsPath = Join-Path $base "AppData\Local\Programs"

if (Test-Path $programsPath) {

    Get-ChildItem $programsPath -Directory -ErrorAction SilentlyContinue |

    Where-Object {
        $_.Name -like "*$app*"
    } |

    ForEach-Object {
        $results += $_.FullName
    }
}

$results = $results | Select-Object -Unique

if ($results.Count -eq 0) {

    Write-Bad "No folders found matching '$app'"
    Read-Host "Press Enter to exit"
    exit
}

# =========================================================
# DISPLAY RESULTS
# =========================================================

Write-Section "FOUND FOLDERS"

$selectableFolders = @()
$migratedFolders = @()

foreach ($path in $results) {

    $type = "Other"

    if ($path -like "*AppData\Roaming*") {
        $type = "Roaming"
    }
    elseif ($path -like "*AppData\LocalLow*") {
        $type = "LocalLow"
    }
    elseif ($path -like "*AppData\Local*") {
        $type = "Local"
    }
    elseif ($path -like "*\.*") {
        $type = "Root"
    }

    $item = Get-Item $path -ErrorAction SilentlyContinue

    if ($item -and $item.LinkType -eq "Junction") {

        $target = $item.Target

        if ($target -and (Test-Path $target)) {

            $migratedFolders += [PSCustomObject]@{
                Path = $path
                Type = $type
                Target = $target
            }

            continue
        }
    }

    $selectableFolders += [PSCustomObject]@{
        Path = $path
        Type = $type
    }
}

# -------------------------------
# ALREADY MIGRATED
# -------------------------------

if ($migratedFolders.Count -gt 0) {

    Write-Host ""
    Write-Host "[ALREADY MIGRATED]" -ForegroundColor Green
    Write-Host "--------------------------------------------------"

    foreach ($m in $migratedFolders) {

        Write-Host ""
        Write-Host "[-] [$($m.Type)]"
        Write-Host "    $($m.Path)"
        Write-Host "    -> $($m.Target)" -ForegroundColor DarkGray
    }
}

# -------------------------------
# READY TO MIGRATE
# -------------------------------

if ($selectableFolders.Count -gt 0) {

    Write-Host ""
    Write-Host "[READY TO MIGRATE]" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------"

    for ($i = 0; $i -lt $selectableFolders.Count; $i++) {

        Write-Host ""
        Write-Host "[$($i+1)] [$($selectableFolders[$i].Type)]"
        Write-Host "    $($selectableFolders[$i].Path)"
    }
}
else {

    Write-Host ""
    Write-Good "Everything already migrated."

    Read-Host "Press Enter to exit"
    exit
}

# =========================================================
# SELECT
# =========================================================

Write-Host ""

$choice = Read-Host "Select folders to migrate (example: 1,2 OR all)"

$approvedFolders = @()

if ($choice.Trim().ToLower() -eq "all") {

    $approvedFolders = $selectableFolders.Path
}
else {

    $indexes = $choice -split "," | ForEach-Object {
        $_.Trim()
    }

    foreach ($idx in $indexes) {

        if ($idx -match '^\d+$') {

            $num = [int]$idx - 1

            if ($num -ge 0 -and $num -lt $selectableFolders.Count) {

                $approvedFolders += $selectableFolders[$num].Path
            }
        }
    }
}

if ($approvedFolders.Count -eq 0) {

    Write-Bad "No valid folders selected."
    Read-Host "Press Enter to exit"
    exit
}

# =========================================================
# SNAPSHOT
# =========================================================

Write-Section "CREATING SNAPSHOTS"

foreach ($orig in $approvedFolders) {

    if (
        $orig -like "*Microsoft*" -or
        $orig -like "*Temp*" -or
        $orig -like "C:\Windows*"
    ) {

        Write-Warn "Skipping dangerous folder:"
        Write-Host "    $orig"
        continue
    }

    if ($orig -like "*AppData\Roaming*") {

        $dest = "$appRoot\Roaming\" + (Split-Path $orig -Leaf)

    }
    elseif ($orig -like "*AppData\LocalLow*") {

        $dest = "$appRoot\LocalLow\" + (Split-Path $orig -Leaf)

    }
    elseif ($orig -like "*AppData\Local*") {

        $dest = "$appRoot\Local\" + (Split-Path $orig -Leaf)

    }
    else {

        $dest = "$appRoot\Root\" + (Split-Path $orig -Leaf)
    }

    $fileCount = (
        Get-ChildItem $orig -Recurse -ErrorAction SilentlyContinue
    ).Count

    $sizeKB = [math]::Round((

        Get-ChildItem $orig -Recurse -ErrorAction SilentlyContinue |

        Measure-Object -Property Length -Sum

    ).Sum / 1KB, 1)

    $snapshot[$orig] = @{

        dest   = $dest
        files  = $fileCount
        sizeKB = $sizeKB
        state  = "pending"
    }

    Write-Good "Snapshot created"
    Write-Host "    Original : $orig"
    Write-Host "    Dest     : $dest"
    Write-Host "    Files    : $fileCount"
    Write-Host "    Size KB  : $sizeKB"
}

# =========================================================
# MIGRATION
# =========================================================

Write-Section "STARTING MIGRATION"

foreach ($orig in $snapshot.Keys) {

    $dest = $snapshot[$orig].dest

    Write-Host ""
    Write-Host "Migrating:" -ForegroundColor Cyan
    Write-Host "    $orig"

    try {

        Stop-Process -Name $app -Force -ErrorAction SilentlyContinue

        $parent = Split-Path $dest -Parent

        if (-not (Test-Path $parent)) {

            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        robocopy $orig $dest /E /MOVE /NFL /NDL /NJH /NJS | Out-Null

        $rc = $LASTEXITCODE

        if ($rc -gt 7) {

            throw "Robocopy failed with exit code $rc"
        }

        if (Test-Path $orig) {

            throw "Original path still exists after move"
        }

        Write-Good "Files moved successfully"

        New-Item -ItemType Junction -Path $orig -Target $dest | Out-Null

        $item = Get-Item $orig -ErrorAction SilentlyContinue

        if (-not $item -or $item.LinkType -ne "Junction") {

            throw "Junction creation failed"
        }

        Write-Good "Junction created"
        Write-Host "    $orig"
        Write-Host "     ->"
        Write-Host "    $dest"

        $snapshot[$orig].state = "success"
    }

    catch {

        Write-Bad $_

        Write-Warn "Starting rollback..."

        try {

            if (Test-Path $orig) {

                $item = Get-Item $orig -ErrorAction SilentlyContinue

                if ($item -and $item.LinkType -eq "Junction") {

                    Remove-Item $orig -Force
                }
            }

            if (Test-Path $dest) {

                robocopy $dest $orig /E /MOVE /NFL /NDL /NJH /NJS | Out-Null
            }

            if (Test-Path $orig) {

                Write-Good "Rollback successful"
                $snapshot[$orig].state = "rolled_back"
            }
            else {

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

# =========================================================
# FINAL SUMMARY
# =========================================================

Write-Section "FINAL SUMMARY"

$table = @()

foreach ($orig in $snapshot.Keys) {

    $table += [PSCustomObject]@{

        Folder       = Split-Path $orig -Leaf
        OriginalPath = $orig
        Destination  = $snapshot[$orig].dest
        SizeKB       = $snapshot[$orig].sizeKB
        State        = $snapshot[$orig].state
    }
}

$table | Format-Table -AutoSize

Write-Host ""

Write-Good "Migration process completed."

Write-Host ""
Read-Host "Press Enter to exit"
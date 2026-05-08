# Windows AppData Junction Migrator

Move heavy Windows AppData/cache folders from `C:` to another drive safely using NTFS junctions.

Useful for:
- Cursor
- VS Code
- Docker
- AI/ML tools
- Node.js caches
- Low-storage SSD systems
- OR majority apps

---

# Why This Exists

Modern developer and AI tools often store huge amounts of data inside:

```txt
C:\Users\<user>\AppData
```

Even when applications are installed on another drive.

Over time this can:
- fill the OS SSD
- slow Windows updates
- reduce available storage
- cause crashes/issues on low-space systems

This utility safely relocates those folders to another drive while preserving compatibility.

---

# How It Works

The tool:

1. Scans for app-related folders
2. Detects already migrated junctions
3. Lets you choose which folders to move
4. Moves data using `robocopy`
5. Creates NTFS junctions pointing to the new location
6. Verifies migration success
7. Automatically rolls back on failure

---

# Example

Before:

```txt
C:\Users\prath\.cursor
```

After migration:

```txt
C:\Users\prath\.cursor
 -> D:\APPDATA_REDIRECT\Cursor\Root\.cursor
```

Applications still think files are on `C:`,
but storage actually lives on `D:`.

---

# Features

- Safe migration workflow
- NTFS junction support
- Already-migrated detection
- Broken junction detection
- Rollback on errors
- Multi-folder selection
- Interactive PowerShell UI
- Uses `robocopy` for reliable transfers

---

# Example Output

```txt
[ALREADY MIGRATED]
--------------------------------------------------

[-] [Roaming]
    C:\Users\prath\AppData\Roaming\Cursor
    -> D:\APPDATA_REDIRECT\Cursor\Roaming\Cursor


[READY TO MIGRATE]
--------------------------------------------------

[1] [Local]
    C:\Users\prath\AppData\Local\Cursor
```

---

# Requirements

- Windows
- PowerShell
- Administrator privileges
- NTFS filesystem

---

# Usage
## PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File migration.ps1
```

---

# Folder Structure

```txt
migration.ps1
README.md
```

---

# Safety Notes

Do NOT migrate:
- Windows system folders
- Microsoft core directories
- Temp/system-critical paths

Always close applications before migration.

---

# Recommended Use Cases

- Moving App caches to another SSD
- Relocating VS Code extension storage
- Reducing OS drive usage
- Managing AI model/cache storage
- Freeing space on laptops with small SSDs

---

# License

MIT License
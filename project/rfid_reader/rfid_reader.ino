/*
 * RFID reader v2 — ESP32 + RC522 + 16x2 I2C LCD
 *
 * Posts each card to the PULSE server and shows the server's answer.
 *
 *  - Reader identity: each ESP32 has its own DEVICE_KEY from the admin
 *    console (RFID readers -> Add reader) or `python tools/manage.py add-reader`.
 *    Leave DEVICE_KEY empty to use the original keyless /tap route.
 *  - The LCD text comes from the server ("lcd" lines), so new results need
 *    no firmware change.
 *  - Offline queue: when the server cannot be reached, taps are kept in
 *    flash (up to QUEUE_MAX) with their time and sent when it is back. The
 *    server ignores a tap it has already recorded (client_event_id).
 *  - Optional TIME OUT push button (KIOSK readers): press, then tap.
 *  - Heartbeat every minute so the admin console shows the reader online;
 *    its reply also sets this clock, so no internet (NTP) is required.
 *
 * Wiring: see PROJECT_GUIDE.md section 3. Button: GPIO 27 to GND (internal pull-up).
 * Libraries: MFRC522 (GithubCommunity), LiquidCrystal I2C (Frank de Brabander),
 *            ArduinoJson 7.x (Benoit Blanchon). Board: ESP32 Dev Module.
 */
#include <SPI.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <sys/time.h>
#include <time.h>

// ------------------------------------------------------------ configuration
const char* WIFI_SSID   = "YOUR_WIFI_SSID";            // 2.4 GHz network only
const char* WIFI_PASS   = "YOUR_WIFI_PASSWORD";
const char* SERVER_BASE = "http://192.168.1.50:5001";  // the server PC's IPv4 address
const char* DEVICE_CODE = "GATE-1";                    // as created in the admin console
const char* DEVICE_KEY  = "";                          // paste the reader key here; "" = legacy /tap
const char* FIRMWARE    = "2.0.0";

#define SS_PIN             5
#define I2C_SDA            21
#define I2C_SCL            22
#define LCD_ADDRESS        0x27   // try 0x3F if the LCD stays blank
#define TIMEOUT_BUTTON_PIN 27     // -1 when there is no button
#define QUEUE_MAX          50
#define HTTP_TIMEOUT_MS    4000
#define HEARTBEAT_MS       60000UL
#define RESULT_SHOW_MS     2000
#define SCHOOL_UTC_OFFSET  (8 * 3600)

MFRC522 rfid(SS_PIN, MFRC522::UNUSED_PIN);  // RST tied to 3V3: software reset
LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);
Preferences store;

uint32_t eventSeq = 0;           // persisted; makes client_event_id unique across reboots
uint16_t qHead = 0, qCount = 0;  // ring buffer of offline taps in flash
unsigned long lastWifiTry = 0, lastHeartbeat = 0, lastFlush = 0, showUntil = 0;
bool clockSet = false, idleShown = false;

// ------------------------------------------------------------ display
void lcdLines(const String& l1, const String& l2) {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(l1.substring(0, 16));
  lcd.setCursor(0, 1); lcd.print(l2.substring(0, 16));
}

void showFor(const String& l1, const String& l2, unsigned long ms = RESULT_SHOW_MS) {
  lcdLines(l1, l2);
  showUntil = millis() + ms;
  idleShown = false;
}

void showIdle() {
  if (WiFi.status() != WL_CONNECTED) lcdLines("OFFLINE MODE", "Taps are saved");
  else if (qCount > 0) lcdLines("Tap your card", "Syncing " + String(qCount) + "...");
  else lcdLines("System Ready", "Tap your card");
  idleShown = true;
}

// ------------------------------------------------------------ helpers
bool usingDeviceApi() { return strlen(DEVICE_KEY) > 0; }

String uidToHex(MFRC522& reader) {
  String uid = "";
  for (byte i = 0; i < reader.uid.size; i++) {
    if (reader.uid.uidByte[i] < 0x10) uid += "0";  // zero-pad so UIDs always match the DB
    uid += String(reader.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

uint32_t nowEpoch() { return clockSet ? (uint32_t)time(nullptr) : 0; }

String isoTime(uint32_t epoch) {
  time_t t = (time_t)epoch + SCHOOL_UTC_OFFSET;
  struct tm tmv;
  gmtime_r(&t, &tmv);
  char buf[32];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S+08:00", &tmv);
  return String(buf);
}

String nextEventId() {
  eventSeq++;
  store.putUInt("seq", eventSeq);
  return String(DEVICE_CODE) + "-" + String(eventSeq);
}

// One HTTP POST. Returns the status code (negative when the server was not reached).
int postJson(const String& path, const String& body, JsonDocument& reply) {
  if (WiFi.status() != WL_CONNECTED) return -1;
  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(String(SERVER_BASE) + path)) return -1;
  http.addHeader("Content-Type", "application/json");
  if (usingDeviceApi()) http.addHeader("X-Device-Key", DEVICE_KEY);
  int code = http.POST(body);
  if (code > 0) {
    DeserializationError err = deserializeJson(reply, http.getString());
    if (err) Serial.println("Bad JSON from server: " + String(err.c_str()));
  }
  http.end();
  return code;
}

// ------------------------------------------------------------ offline queue (flash ring buffer)
void queuePush(const String& uid, const String& cid, uint32_t epoch) {
  if (qCount == QUEUE_MAX) {             // full: drop the oldest
    qHead = (qHead + 1) % QUEUE_MAX;
    qCount--;
  }
  uint16_t slot = (qHead + qCount) % QUEUE_MAX;
  store.putString(("q" + String(slot)).c_str(), uid + "|" + cid + "|" + String(epoch));
  qCount++;
  store.putUShort("qh", qHead);
  store.putUShort("qc", qCount);
}

bool queuePeek(String& uid, String& cid, uint32_t& epoch) {
  if (qCount == 0) return false;
  String v = store.getString(("q" + String(qHead)).c_str(), "");
  int a = v.indexOf('|'), b = v.indexOf('|', a + 1);
  if (a < 0 || b < 0) { uid = ""; return true; }  // corrupt slot: let the caller drop it
  uid = v.substring(0, a);
  cid = v.substring(a + 1, b);
  epoch = (uint32_t)v.substring(b + 1).toInt();
  return true;
}

void queuePop() {
  if (qCount == 0) return;
  store.remove(("q" + String(qHead)).c_str());
  qHead = (qHead + 1) % QUEUE_MAX;
  qCount--;
  store.putUShort("qh", qHead);
  store.putUShort("qc", qCount);
}

// ------------------------------------------------------------ server calls
// Sends one tap. Returns the HTTP status; fills l1/l2 with what to show.
int sendTap(const String& uid, const String& cid, uint32_t epoch, String& l1, String& l2) {
  JsonDocument reply;
  JsonDocument req;
  req["uid"] = uid;
  String path = "/tap";
  if (usingDeviceApi()) {
    path = "/api/v1/device/tap";
    req["client_event_id"] = cid;
    if (epoch > 0) req["tapped_at"] = isoTime(epoch);
  }
  String body;
  serializeJson(req, body);
  int code = postJson(path, body, reply);
  Serial.println("POST " + path + " -> " + String(code));

  if (code == 200) {
    if (reply["lcd"].is<JsonArray>()) {
      l1 = reply["lcd"][0] | "";
      l2 = reply["lcd"][1] | "";
    } else {  // legacy server reply: map the result ourselves
      String status = reply["status"] | "", result = reply["result"] | "";
      String name = reply["name"] | "", action = reply["action"] | "";
      if (status == "granted") { l1 = name; l2 = action + " - OK"; }
      else if (status == "warning") { l1 = "ALREADY IN"; l2 = "Press TIME OUT"; }
      else if (result == "VISIT_LIMIT_EXCEEDED") { l1 = "VISIT LIMIT"; l2 = "See staff"; }
      else if (result == "REJECT_NO_OPEN_RECORD") { l1 = "NO TIME IN"; l2 = "See staff"; }
      else if (result == "REJECT_EXPIRED_VISITOR") { l1 = "CARD EXPIRED"; l2 = "See staff"; }
      else { l1 = "ACCESS DENIED"; l2 = "Not registered"; }
    }
  } else if (code == 401) {
    l1 = "READER NOT SET"; l2 = "Check device key";
  } else if (code > 0) {
    l1 = "SERVER ERROR"; l2 = "Code: " + String(code);
  }
  return code;
}

void sendHeartbeat() {
  if (!usingDeviceApi() || WiFi.status() != WL_CONNECTED) return;
  JsonDocument req, reply;
  req["firmware"] = FIRMWARE;
  req["rssi"] = WiFi.RSSI();
  req["queue_len"] = qCount;
  String body;
  serializeJson(req, body);
  if (postJson("/api/v1/device/heartbeat", body, reply) == 200 && reply["epoch"].is<uint32_t>()) {
    struct timeval tv = { (time_t)reply["epoch"].as<uint32_t>(), 0 };
    settimeofday(&tv, nullptr);
    clockSet = true;
  }
}

// ------------------------------------------------------------ loop tasks
void handleWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  if (millis() - lastWifiTry < 5000) return;  // never block the card reader
  lastWifiTry = millis();
  Serial.println("WiFi: reconnecting...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASS);
}

void handleButton() {
  if (TIMEOUT_BUTTON_PIN < 0 || digitalRead(TIMEOUT_BUTTON_PIN) != LOW) return;
  delay(30);  // debounce
  if (digitalRead(TIMEOUT_BUTTON_PIN) != LOW) return;
  while (digitalRead(TIMEOUT_BUTTON_PIN) == LOW) delay(5);
  if (!usingDeviceApi()) { showFor("TIME OUT", "Use the kiosk"); return; }
  JsonDocument reply;
  int code = postJson("/api/v1/device/arm-timeout", "{}", reply);
  if (code == 200) showFor(reply["lcd"][0] | "TIME OUT ready", reply["lcd"][1] | "Tap your card", 15000);
  else if (code == 409) showFor("NOT A KIOSK", "Tap exit reader");
  else showFor("OFFLINE", "Try again");
}

void handleQueue() {
  if (qCount == 0 || WiFi.status() != WL_CONNECTED || millis() - lastFlush < 1500) return;
  lastFlush = millis();
  String uid, cid, l1, l2;
  uint32_t epoch = 0;
  if (!queuePeek(uid, cid, epoch)) return;
  if (uid.length() == 0) { queuePop(); return; }
  int code = sendTap(uid, cid, epoch, l1, l2);
  if (code > 0 && code != 401 && code < 500) queuePop();  // recorded, or rejected for good
  if (idleShown) showIdle();
}

void handleCard() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;
  String uid = uidToHex(rfid);
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  Serial.println("Card UID: " + uid);

  String cid = nextEventId(), l1, l2;
  uint32_t epoch = nowEpoch();
  int code = sendTap(uid, cid, epoch, l1, l2);
  if (code <= 0 || code >= 500) {
    if (usingDeviceApi()) {
      queuePush(uid, cid, epoch);
      showFor("SAVED OFFLINE", "Will sync later");
    } else {
      showFor("SERVER ERROR", "Try again");
    }
  } else {
    showFor(l1, l2);
  }
}

// ------------------------------------------------------------ setup / loop
void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  Wire.begin(I2C_SDA, I2C_SCL);
  lcd.init();
  lcd.backlight();
  if (TIMEOUT_BUTTON_PIN >= 0) pinMode(TIMEOUT_BUTTON_PIN, INPUT_PULLUP);

  store.begin("rfid", false);
  eventSeq = store.getUInt("seq", 0);
  qHead = store.getUShort("qh", 0) % QUEUE_MAX;
  qCount = min((int)store.getUShort("qc", 0), QUEUE_MAX);

  lcdLines("PULSE " + String(FIRMWARE), DEVICE_CODE);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 10000) delay(250);  // boot only
  if (WiFi.status() == WL_CONNECTED) Serial.println("WiFi OK. ESP32 IP: " + WiFi.localIP().toString());
  configTime(0, 0, "pool.ntp.org", "time.google.com");  // used if the LAN has internet
  sendHeartbeat();
  lastHeartbeat = millis();
  showIdle();
}

void loop() {
  handleWifi();
  handleButton();
  handleCard();
  handleQueue();
  if (!clockSet && time(nullptr) > 1700000000) clockSet = true;  // NTP answered
  if (millis() - lastHeartbeat > HEARTBEAT_MS) {
    lastHeartbeat = millis();
    sendHeartbeat();
  }
  if (!idleShown && millis() > showUntil) showIdle();
  delay(20);
}

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>

const char* WIFI_SSID  = "ZZZ";
const char* WIFI_PASS  = "12345678";
const char* SERVER_URL = "http://192.168.10.64:5001/tap";

#define SS_PIN  5

MFRC522 rfid(SS_PIN, MFRC522::UNUSED_PIN);

String uidToHex(MFRC522& reader) {
  String uid = "";
  for (byte i = 0; i < reader.uid.size; i++) {
    if (reader.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(reader.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected. ESP32 IP: " + WiFi.localIP().toString());
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  connectWiFi();
  Serial.println("System ready. Tap your card.");
}

void loop() {
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  String uid = uidToHex(rfid);
  Serial.println("Card UID: " + uid);
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  if (WiFi.status() != WL_CONNECTED) connectWiFi();

  HTTPClient http;
  Serial.println("POST target: " + String(SERVER_URL));
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");

  String body = "{\"uid\":\"" + uid + "\"}";
  int httpCode = http.POST(body);
  Serial.println("HTTP status: " + String(httpCode));

  if (httpCode == 200) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, http.getString());
    if (error == DeserializationError::Ok) {
      String status = doc["status"] | "";
      String name = doc["name"] | "";
      String action = doc["action"] | "";
      String result = doc["result"] | "";

      if (status == "granted") {
        Serial.println(name + " - " + action + " - OK");
      } else if (status == "warning") {
        Serial.println("ALREADY CHECKED IN - press TIME OUT on the kiosk");
      } else if (result == "VISIT_LIMIT_EXCEEDED") {
        Serial.println("VISIT LIMIT - see attendance staff");
      } else if (result == "REJECT_NO_OPEN_RECORD") {
        Serial.println("NO CHECK-IN - see attendance staff");
      } else {
        Serial.println("ACCESS DENIED - card not registered");
      }
    } else {
      Serial.println("Invalid server JSON: " + String(error.c_str()));
    }
  } else {
    Serial.println("HTTP error: " + String(httpCode));
    if (httpCode < 0) Serial.println("Check server address, WiFi, and firewall port 5001.");
  }

  http.end();
  delay(2000);
  Serial.println("Ready to scan.");
}
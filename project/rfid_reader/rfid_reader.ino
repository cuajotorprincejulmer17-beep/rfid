#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>


const char* WIFI_SSID  = "YOUR_WIFI_SSID";          // <-- put your WiFi name (2.4 GHz only!)
const char* WIFI_PASS  = "YOUR_WIFI_PASSWORD";       // <-- put your WiFi password
const char* SERVER_URL = "http://192.168.1.50:5001/tap";  // PC IPv4 on the current network

#define SS_PIN  5
#define I2C_SDA 21
#define I2C_SCL 22

MFRC522 rfid(SS_PIN, MFRC522::UNUSED_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2);   // if LCD stays blank, try 0x3F instead of 0x27

String uidToHex(MFRC522& reader) {
  String uid = "";
  for (byte i = 0; i < reader.uid.size; i++) {
    if (reader.uid.uidByte[i] < 0x10) uid += "0";  // zero-pad so UIDs always match the DB
    uid += String(reader.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void lcdMessage(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(line1.substring(0, 16));
  lcd.setCursor(0, 1); lcd.print(line2.substring(0, 16));
}

void connectWiFi() {
  lcdMessage("Connecting WiFi", "Please wait...");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\nWiFi OK! ESP32 IP: " + WiFi.localIP().toString());
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  Wire.begin(I2C_SDA, I2C_SCL);
  lcd.init();
  lcd.backlight();
  connectWiFi();
  lcdMessage("System Ready", "Tap your card");
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
    JsonDocument doc;   // ArduinoJson v7. If you have v6, use: StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, http.getString());
    if (error == DeserializationError::Ok) {
      String status  = doc["status"] | "";
      String name    = doc["name"] | "";
      String action  = doc["action"] | "";
      String result  = doc["result"] | "";
      Serial.println("Server result: " + status + " / " + result + " / " + action);
      if (status == "granted")      lcdMessage(name, action + " - OK");
      else if (status == "warning") lcdMessage("ALREADY IN", "Press TIME OUT");
      else if (result == "VISIT_LIMIT_EXCEEDED") lcdMessage("VISIT LIMIT", "See attendance staff");
      else if (result == "REJECT_NO_OPEN_RECORD") lcdMessage("NO CHECK-IN", "See attendance staff");
      else                          lcdMessage("ACCESS DENIED", "Not registered");
    } else {
      Serial.println("Invalid server JSON: " + String(error.c_str()));
    }
  } else {
    Serial.println("HTTP error: " + String(httpCode));
    lcdMessage("SERVER ERROR", "Code: " + String(httpCode));
  }

  http.end();
  delay(2000);                       // show result + anti-spam cooldown
  lcdMessage("System Ready", "Tap your card");
}

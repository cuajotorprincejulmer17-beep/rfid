#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>


const char* WIFI_SSID  = "ZZZ";          // <-- put your WiFi name (2.4 GHz only!)
const char* WIFI_PASS  = "12345678";       // <-- put your WiFi password
const char* SERVER_URL = "http://192.168.56.64:5001/tap";  // PC IPv4 on the current network

#define SS_PIN  5
#define I2C_SDA 21
#define I2C_SCL 22

// 16x2 LCD with I2C backpack (PCF8574)
#define LCD_ADDR 0x27   // if LCD stays blank, try 0x3F instead of 0x27
#define LCD_COLS 16
#define LCD_ROWS 2

MFRC522 rfid(SS_PIN, MFRC522::UNUSED_PIN);
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);

String uidToHex(MFRC522& reader) {
  String uid = "";
  for (byte i = 0; i < reader.uid.size; i++) {
    if (reader.uid.uidByte[i] < 0x10) uid += "0";  // zero-pad so UIDs always match the DB
    uid += String(reader.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// Cut to 16 chars and pad with spaces so old text is overwritten (no clear() flicker).
String fitLine(String text) {
  text = text.substring(0, LCD_COLS);
  while (text.length() < LCD_COLS) text += " ";
  return text;
}

void lcdMessage(String line1, String line2) {
  lcd.setCursor(0, 0); lcd.print(fitLine(line1));
  lcd.setCursor(0, 1); lcd.print(fitLine(line2));
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
      else if (result == "VISIT_LIMIT_EXCEEDED") lcdMessage("VISIT LIMIT", "See staff");
      else if (result == "REJECT_NO_OPEN_RECORD") lcdMessage("NO CHECK-IN", "See staff");
      else                          lcdMessage("ACCESS DENIED", "Not registered");
    } else {
      Serial.println("Invalid server JSON: " + String(error.c_str()));
      lcdMessage("SERVER ERROR", "Bad reply");
    }
  } else {
    Serial.println("HTTP error: " + String(httpCode));
    lcdMessage("SERVER ERROR", "Code: " + String(httpCode));
  }

  http.end();
  delay(2000);                       // show result + anti-spam cooldown
  lcdMessage("System Ready", "Tap your card");
}

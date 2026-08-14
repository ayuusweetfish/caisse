#include <Arduino.h>
#include <Wire.h>

static HardwareSerial Serial_1(USART1);

#define LED_PIN PC13

void setup() {
  Serial_1.begin(9600);
  pinMode(LED_PIN, OUTPUT);

  Serial_1.println("starting!");

  Wire.begin(PB6, PB7);

  Wire.beginTransmission(0x5A);
  Wire.write(0x5E);   // Register ECR
  Wire.write(0x01);   // CL = 00, ELEPROX_EN = 00, ELE_EN = 0001
  Wire.endTransmission();

  Wire.beginTransmission(0x5A);
  Wire.write(0x5D);   // Register CDT:SFI:ESI
  Wire.endTransmission();
  Wire.requestFrom(0x5A, 1);
  int i = Wire.read();
  char s[32];
  snprintf(s, sizeof s, "CDT:SFI:ESI = 0x%02x", i);
  Serial_1.println(s);
}

void loop() {
  digitalWrite(LED_PIN, 0);
  delay(200);
  digitalWrite(LED_PIN, 1);
  delay(200);

  Wire.beginTransmission(0x5A);
  Wire.write(0x04);   // Register EFD0LB
  Wire.endTransmission();
  Wire.requestFrom(0x5A, 1);
  Wire.read(n);

  Serial_1.println("running");
}

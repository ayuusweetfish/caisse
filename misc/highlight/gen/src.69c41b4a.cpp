#include <Arduino.h>

HardwareSerial Serial_1(USART1);
HardwareSerial Serial_2(USART2);

#define LED_PIN PC13

void setup() {
  Serial_1.begin(9600);
  Serial_2.begin(9600);
  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_PIN, 0);
  delay(200);
  digitalWrite(LED_PIN, 1);
  delay(200);
  Serial_1.println("run serial 1");
  Serial_2.println("run serial 2");
}
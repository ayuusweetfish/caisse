#include <SPI.h>
#include <MCP_DAC.h>

#define PIN_CS    8
#define PIN_SCK   9
#define PIN_SDI  10

MCP4821 McpDac(PIN_SDI, PIN_SCK);

void setup() {
  Serial.begin(9600);

  McpDac.begin(PIN_CS);
  McpDac.setGain(2);
  delayMicroseconds(100);
}

void loop() {
  static int t = 0;
  t ^= 1;
  McpDac.analogWrite(t * 4095);
  delayMicroseconds(1);
  Serial.print(t);
  Serial.print("  ");
  Serial.println(analogRead(A0));
  delay(1000);
}

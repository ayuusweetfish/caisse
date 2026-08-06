#include <MCP_DAC.h>

#define PIN_DAC_CS   PIN_A2
#define PIN_DAC_SCK  PIN_A1
#define PIN_DAC_SDI  PIN_A0

MCP4821 McpDac(PIN_DAC_SDI, PIN_DAC_SCK);

void setup() {
  // CTC mode, prescaler = 8
  TCCR1A = (0 << WGM11) | (0 << WGM10);
  TCCR1B = (0 << WGM13) | (1 << WGM12) | (0 << CS12) | (1 << CS11) | (0 << CS10);
  // 2 MHz clock / 0x0200 = 4 kHz
  OCR1A = 0x01FF;
  TIMSK1 |= (1 << OCIE1A);

  McpDac.begin(PIN_DAC_CS);
  delayMicroseconds(100);
}

static struct SineTable_t {
  int16_t table[8];
  SineTable_t() {
    int N = sizeof(table) / sizeof(table[0]);
    for (int i = 0; i < N; i++)
      table[i] = (int16_t)(sinf((float)i / N * M_PI * 2) * 32768.0f - 0.5f);
  }
  inline int16_t operator [] (size_t n) { return table[n]; }
} SineTable;

ISR(TIMER1_COMPA_vect) {
  static int phaseCounter = 0;
  phaseCounter = (phaseCounter + 1) % 8;
  int16_t sample = SineTable[phaseCounter]; // Sine
  // int16_t sample = phaseCounter * 4000;     // Sawtooth
  // int16_t sample = (phaseCounter < 4 ? 32000 : 0);  // Square
  // Calculate DAC value: map `sample` from [0, 32767] to [15, 30]
  uint16_t sample_i = (uint16_t)((((int32_t)sample + (1L << 15)) * 30L + (1L << 15)) >> 16);
  McpDac.analogWrite(sample_i);
}

void loop() {
}

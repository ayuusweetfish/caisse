const PROGMEM int16_t kickTable[] = { /* ... */ };
const PROGMEM int16_t stringsTable[] = { /* ... */ };
SampleSynth<sizeof kickTable / sizeof kickTable[0], kickTable> synKick;
SampleSynth<sizeof stringsTable / sizeof stringsTable[0], stringsTable> synStrings;

int16_t nextSample = 0;

ISR(TIMER1_COMPA_vect) {
  // 尽快输出上一个采样
  McpDac.fastWriteA(nextSample);

  // 合成下一个采样
  int16_t sample = 0;
  sample = sat_add(sample, synKick.sample());
  sample = sat_add(sample, synStrings.sample());
  uint16_t sample_i = (uint16_t)
    ((((int32_t)sample + (1L << 15)) * 120L + (1L << 15)) >> 16);
  nextSample = sample_i;

  // 每隔 2 秒从头播放一次
  static int timerCount = 0, pinStatus = 0;
  if ((timerCount = ((timerCount + 1) % 8000)) == 0) {
    digitalWrite(13, (pinStatus ^= 1));
    // synKick.start();
    synStrings.start();
  }
}

template<int Length, const int16_t *Table> struct SampleSynth {
  int pos;
  SampleSynth() { pos = -1; }
  inline void start() { pos = 0; }
  inline int16_t sample() {
    if (pos < 0) return 0;
    int16_t result = pgm_read_word(&Table[pos]);  // 见下
    if (++pos == Length) pos = -1;
    return result;
  }
};

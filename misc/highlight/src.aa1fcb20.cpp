void setup() {
  // 清空 CS12:0，然后重新写入 0b101
  TCCR1B = (TCCR1B
    & ~((1 << CS12) | (1 << CS11) | (1 << CS10)))
    |  ((1 << CS12) | (0 << CS11) | (1 << CS10));
  TIMSK1 |= (1 << TOIE1);
  pinMode(13, OUTPUT);
}

ISR(TIMER1_OVF_vect) {
  static int timerCount = 0, pinStatus = 0;
  if ((timerCount = ((timerCount + 1) & 16383)) == 0)
    digitalWrite(13, (pinStatus ^= 1));
}

void loop() { }

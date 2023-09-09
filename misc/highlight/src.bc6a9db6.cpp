void setup() {
  TCCR1A = 0;   // WGM12:0 置零
  TCCR1B = (0 << CS12) | (0 << CS11) | (1 << CS10);
  TIMSK1 |= (1 << TOIE1);
  pinMode(13, OUTPUT);
}

ISR(TIMER1_OVF_vect) {
  static int timerCount = 0, pinStatus = 0;
  if ((timerCount = ((timerCount + 1) & 255)) == 0)
    digitalWrite(13, (pinStatus ^= 1));
}

void loop() { }

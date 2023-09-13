ISR(TIMER1_OVF_vect) {
  static int timerCount = 0;
  timerCount++;
  if (timerCount % 24 == 0)
    McpDac.analogWrite(((timerCount / 24) & 1) * 6);
}

#include <CapacitiveSensor.h>
#include <rh_mp3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define REGION_KICK     1
#define REGION_TOP      0
#define REGION_SQUEEZE  0
#define REGION_FLUFF    0
#define REGION_PICK     0
#define REGION_SLIDE    0

#define INSPECT_SENSORS 0
#define PLAY_MP3        !INSPECT_SENSORS

static inline bool sign(unsigned long a, unsigned long b) { return a < b; }
// Returns whether x is outside of the range [a, b), which may wrap around the maximum value
static inline bool outside(unsigned long a, unsigned long b, unsigned long x) {
  return sign(x, a) ^ sign(x, b) ^ sign(a, b);
}
template <typename T> inline void swap(T &a, T &b) { T t = a; a = b; b = t; }
inline int cmp_long(const void *a, const void *b) { return (int)(*(long *)a - *(long *)b); }

struct FungiCapSensor {
  long base;

  volatile IO_REG_TYPE *sReg;
  IO_REG_TYPE sBit;
  volatile IO_REG_TYPE *rReg;
  IO_REG_TYPE rBit;

  static const long SENSOR_BASE_UNINIT_TAG = 0x3FFFFFF0;
  static const long SENSOR_TIMEOUT = 0x3FFFFFFF;

  static const int N_SAMPLES_PER_OUTPUT = 11;
  static const int N_HIST = 3;
  static const int N_SAMPLES_TOTAL = N_HIST * N_SAMPLES_PER_OUTPUT;
  long histSamples[N_SAMPLES_TOTAL];

  FungiCapSensor(uint8_t sendPin, uint8_t recvPin) {
    pinMode(sendPin, OUTPUT);
    pinMode(recvPin, INPUT);
    base = SENSOR_BASE_UNINIT_TAG;

    sReg = PIN_TO_BASEREG(sendPin);
    sBit = PIN_TO_BITMASK(sendPin);
    rReg = PIN_TO_BASEREG(recvPin);
    rBit = PIN_TO_BITMASK(recvPin);
  }

  inline long sampleRaw() {
    unsigned long t0, tm, t1, t2;

    noInterrupts();
    DIRECT_WRITE_LOW(sReg, sBit);
    DIRECT_MODE_INPUT(rReg, rBit);
    DIRECT_MODE_OUTPUT(rReg, rBit);
    DIRECT_WRITE_LOW(rReg, rBit);
    delayMicroseconds(10);
    DIRECT_MODE_INPUT(rReg, rBit);
    t0 = micros();
    tm = t0 + 2000000;  // May overflow and wrap around
    DIRECT_WRITE_HIGH(sReg, sBit);
    interrupts();
    while (!DIRECT_READ(rReg, rBit)) {
      unsigned long T = micros();
      if (outside(t0, tm, T)) return SENSOR_TIMEOUT;
    }
    t1 = micros() - t0;

    noInterrupts();
    DIRECT_WRITE_HIGH(rReg, rBit);
    DIRECT_MODE_OUTPUT(rReg, rBit);
    DIRECT_WRITE_HIGH(rReg, rBit);
    DIRECT_MODE_INPUT(rReg, rBit);
    t0 = micros();
    tm = t0 + 2000000;
    DIRECT_WRITE_LOW(sReg, sBit);
    interrupts();
    while (DIRECT_READ(rReg, rBit)) {
      unsigned long T = micros();
      if (outside(t0, tm, T)) return SENSOR_TIMEOUT;
    }
    t2 = micros() - t0;

    return (t1 + t2) / 4;
  }

  inline void populateCalibration() {
    for (int i = 0; i < N_SAMPLES_TOTAL; i++) histSamples[i] = sampleRaw();
  }

  inline long sampleCalibrated() {
    /* memmove(
      histSamples,
      histSamples + sizeof(histSamples[0]) * N_SAMPLES_PER_OUTPUT,
      sizeof(histSamples[0]) * (N_HIST - 1) * N_SAMPLES_PER_OUTPUT
    ); */
    for (int i = 0; i < N_SAMPLES_TOTAL; i++)
      if (i + N_SAMPLES_PER_OUTPUT < N_SAMPLES_TOTAL)
        histSamples[i] = histSamples[i + N_SAMPLES_PER_OUTPUT];
      else
        histSamples[i] = sampleRaw();

    long a[N_SAMPLES_TOTAL];
    memcpy(a, histSamples, sizeof a);
    qsort(a, N_SAMPLES_TOTAL, sizeof(long), cmp_long);
    long result = 0;
    const int I_START = N_SAMPLES_TOTAL / 2 - 5;
    const int I_END = N_SAMPLES_TOTAL / 2 + 5;
    for (int i = I_START; i < I_END; i++)
      if ((result += a[i]) >= SENSOR_TIMEOUT) result = SENSOR_TIMEOUT;
    // Normalize
    if (result < SENSOR_TIMEOUT) result = result * 10 / (I_END - I_START);

    long delta = base - result;
    if (delta >= 0) {
      if (delta >= 1 && base != SENSOR_BASE_UNINIT_TAG) delta = 1;
      base -= delta;
    }
    return result - base;
  }
};

FungiCapSensor sensor[] = {
#if REGION_SQUEEZE || REGION_FLUFF || REGION_PICK || REGION_SLIDE
  FungiCapSensor(12, 2),
#endif
#if REGION_SQUEEZE || REGION_FLUFF || REGION_PICK || REGION_SLIDE || REGION_TOP
  FungiCapSensor(12, 3),
  FungiCapSensor(12, 4),
#endif
  FungiCapSensor(12, 5),
  FungiCapSensor(12, 6),
  FungiCapSensor(12, 7),
  FungiCapSensor(12, 8),
  FungiCapSensor(12, 9),
  FungiCapSensor(12, 10),
  FungiCapSensor(12, 11),
};
const int N_SENSORS = sizeof sensor / sizeof sensor[0];
unsigned long lastBaseInc;

template <size_t N, size_t A, size_t B, long ThrAbsl, int ThrRel, int Interval> struct SensorHistoryTrigger {
  long history[N];
  size_t ptr;
  int wait;
  SensorHistoryTrigger() {
    ptr = 0;
    wait = N - 1;
  }
  inline int shift(long value) {
    history[ptr] = value;
    if (++ptr == N) ptr = 0;
    if (wait == 0) {
      bool result = false;
      // Overall trend
      int upCount = 0;
      for (int i = 0; i < N - 1; i++) if (history[i] < history[i + 1]) upCount++;
      if (upCount > N / 2) {
        long a[N];
        memcpy(a, history, sizeof a);
        qsort(a, N, sizeof(long), cmp_long);
        result = (a[B] - a[A] >= ThrAbsl && a[B] - a[A] >= a[N - 1] * ThrRel / 16);
      }
      if (result) wait = Interval;
      return (int)result;
    } else {
      wait--;
      return 0;
    }
  }
};

template <long ThrAbslFirst, long ThrAbsl, int Capacity, int CountThr> struct SensorContinuousTrigger {
  int count;
  bool state;
  SensorContinuousTrigger() {
    count = 0;
    state = false;
  }
  inline int shift(long value) {
    if (value >= (state ? ThrAbsl : ThrAbslFirst)) {
      if (count < Capacity) count++;
    } else {
      if (count > 0) count--;
    }
    bool last = state;
    state = (count >= CountThr);
    if (last ^ state) {
      if (state) count = Capacity;
      return state ? +1 : -1;
    } else {
      return 0;
    }
  }
};

#if REGION_KICK
#define TRIGGER_INSTANT
SensorHistoryTrigger<5, 1, 3, 20, 8, 30> triggers[N_SENSORS];
#endif

#if REGION_TOP
#define TRIGGER_CONT
SensorContinuousTrigger<80, 40, 1, 1> triggers[N_SENSORS];
#endif

#if REGION_FLUFF
#endif

#if REGION_SQUEEZE
#define TRIGGER_CONT
SensorContinuousTrigger<90, 50, 2, 2> triggers[N_SENSORS];
#endif

#if REGION_PICK
#define TRIGGER_CONT
SensorContinuousTrigger<40, 20, 20, 5> triggers[N_SENSORS];
#endif

#if REGION_SLIDE
#define TRIGGER_CONT
SensorContinuousTrigger<6, 5, 3, 2> triggers[N_SENSORS];
#endif

MP3 mp3;

#define MP3_DELAY 50
void setMp3Volume(int vol) {
  static unsigned long last = 0;
  unsigned long t = millis();
  if (!outside(last, last + MP3_DELAY, t)) return;
  last = t;
  mp3.setVolume(vol);
}

void setup() {
#if !PLAY_MP3
  Serial.begin(9600);
#endif

  TCCR1A = (1 << WGM10);
  TCCR1B = (0 << CS12) | (0 << CS11) | (1 << CS10);
  TIMSK1 |= (1 << TOIE1);
  pinMode(13, OUTPUT);

  mp3.begin();
#if REGION_FLUFF
  mp3.setVolume(0);
  delay(300);
  mp3.play(1);
  delay(300);
  mp3.playLoop();
  delay(300);
#else
  mp3.setVolume(31);
  delay(300);
  mp3.noLoop();
  delay(300);
#endif

  for (int i = 0; i < N_SENSORS; i++) sensor[i].populateCalibration();
  lastBaseInc = millis();
}

ISR(TIMER1_OVF_vect) {
  static int timerCount = 0, pinStatus = 0;
  if ((timerCount = ((timerCount + 1) & 32767)) == 0)
    digitalWrite(13, (pinStatus ^= 1));
}

int fadeOut = -1;

void loop() {
  if (outside(lastBaseInc, lastBaseInc + 1000, millis())) {
    for (int i = 0; i < N_SENSORS; i++) sensor[i].base++;
    lastBaseInc = millis();
  }

  long result[N_SENSORS];
  for (int i = 0; i < N_SENSORS; i++) {
    result[i] = sensor[i].sampleCalibrated();
    if (result[i] >= FungiCapSensor::SENSOR_TIMEOUT) continue;
    #if defined(TRIGGER_INSTANT) || defined(TRIGGER_CONT)
      int change = triggers[i].shift(result[i]);
      if (change) {
      #if !PLAY_MP3
        Serial.print(change == +1 ? "Onset   " : "Release ");
        Serial.print(i);
        Serial.print(" @ ");
        Serial.print(millis());
        Serial.println();
      #else
        if (change == +1) {
          fadeOut = -1;
          setMp3Volume(31);
          delay(MP3_DELAY);
        #if REGION_TOP
          mp3.play(1 + i - (i >= 3 ? 1 : 0));
        #else
          mp3.play(1 + i);
        #endif
        #if REGION_PICK || REGION_SLIDE
        } else {
          if (fadeOut < 0) fadeOut = 31;
        #endif
        }
      #endif
      }
    #endif
  }

  #if REGION_FLUFF
  {
    static long resultTotalMax = 0;
    long resultTotal = 0;
    for (int i = 0; i < N_SENSORS; i++) resultTotal += result[i];
    if (resultTotalMax < resultTotal && resultTotalMax < 150)
      resultTotalMax += 2;
    else if (resultTotalMax > 0)
      resultTotalMax -= 1;
    int vol = (resultTotalMax - 50) / 3;  // 50 ~ 143 correspond to 0 ~ 31
    // int vol = (resultTotalMax - 15) / 2;  // 15 ~ 77 correspond to 0 ~ 31
    if (vol < 0) vol = 0; else if (vol > 31) vol = 31;
    setMp3Volume(vol);
    // char s[64];
    // sprintf(s, "\t0\t300\t%5ld\t%5ld\t%d", resultTotal, resultTotalMax, vol);
    // Serial.println(s);
  }
  #elif REGION_PICK || REGION_SLIDE
  if (fadeOut >= 0) {
    setMp3Volume(fadeOut);
    fadeOut -= 2;
    // if (fadeOut < 0) mp3.stop();
  }
  #endif

#if !PLAY_MP3 && INSPECT_SENSORS
  static int count = 0;
  // if (++count == 16) count = 0; else return;
  Serial.print("\t");
  char line[N_SENSORS * 7 + 1];
  for (int i = 0; i < N_SENSORS; i++)
    sprintf(line + i * 7, "%6ld\t", result[i]);
  Serial.print(line);
  Serial.print("\t|\t");
  for (int i = 0; i < N_SENSORS; i++)
    sprintf(line + i * 7, "%6ld\t", sensor[i].base);
  Serial.println(line);
#endif
}

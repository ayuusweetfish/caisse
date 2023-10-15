#include <CapacitiveSensor.h>
#include <stdio.h>
#include <stdlib.h>

CapacitiveSensor sensor[] = {
  CapacitiveSensor(12, 2),
  CapacitiveSensor(12, 3),
  CapacitiveSensor(12, 4),
  CapacitiveSensor(12, 5),
  CapacitiveSensor(12, 6),
  CapacitiveSensor(12, 7),
  CapacitiveSensor(12, 8),
  CapacitiveSensor(12, 9),
  CapacitiveSensor(12, 10),
  CapacitiveSensor(12, 11),
};
const int N_SENSORS = sizeof sensor / sizeof sensor[0];

template <typename T> inline void swap(T &a, T &b) { T t = a; a = b; b = t; }

long sensorBase[N_SENSORS]; // Floor values for sensors
int lastBaseInc;

void setup() {
  Serial.begin(9600);
  for (int i = 0; i < N_SENSORS; i++) {
    sensor[i].set_CS_AutocaL_Millis(0xFFFFFFFF);
    sensorBase[i] = 0x7FFFFFF0; // Avoid accidental wraparound
  }
  lastBaseInc = millis();
}

void loop() {
  long result[N_SENSORS];
  for (int i = 0; i < N_SENSORS; i++) {
    const int N_SAMPLES = 5;
    long samples[N_SAMPLES];
    for (int j = 0; j < N_SAMPLES; j++)
      samples[j] = sensor[i].capacitiveSensorRaw(5);
    for (int j = 0; j < N_SAMPLES; j++)
      for (int k = j + 1; k < N_SAMPLES; k++)
        if (samples[j] > samples[k]) swap(samples[j], samples[k]);
    result[i] = samples[N_SAMPLES / 2];
  }

  if (lastBaseInc + 1000 < millis()) {
    for (int i = 0; i < N_SENSORS; i++) sensorBase[i]++;
    lastBaseInc = millis();
  }
  for (int i = 0; i < N_SENSORS; i++) {
    if (sensorBase[i] > result[i]) {
      if (sensorBase[i] == 0x7FFFFFF0) sensorBase[i] = result[i];
      else sensorBase[i]--;
    }
    result[i] -= sensorBase[i];
  }

  char line[N_SENSORS * 6 + 1];
  for (int i = 0; i < N_SENSORS; i++)
    sprintf(line + i * 6, "%5ld\t", result[i]);
  Serial.println(line);
}
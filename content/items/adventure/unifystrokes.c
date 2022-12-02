#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"        // v2.27
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"  // v1.16

#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
  if (argc < 3) {
    printf("Usage: %s <input-file> <output-file> [<thr-strokedet> [<thr-fadel> <thr-fadeh> [<r> <g> <b>]]]\n", argv[0]);
    return 0;
  }

  float thr_strokedet = 35;
  if (argc >= 4)
    thr_strokedet = (float)strtof(argv[3], NULL);
  uint64_t thr_fadel = 10, thr_fadeh = 30;
  if (argc >= 6) {
    thr_fadel = (uint64_t)strtoll(argv[4], NULL, 10);
    thr_fadeh = (uint64_t)strtoll(argv[5], NULL, 10);
  }
  float tint[3] = {0, 0, 0};
  if (argc >= 9) {
    for (int k = 0; k < 3; k++)
      tint[k] = (float)strtof(argv[6 + k], NULL);
  }

  int w, h;
  uint8_t *pxi = stbi_load(argv[1], &w, &h, NULL, 3);
  if (pxi == NULL) {
    printf("Cannot open %s\n", argv[1]);
    return 1;
  }
  uint8_t *pxo = (uint8_t *)malloc(w * h * 3);
#define arr(_a, _r, _c, _ch) (_a[((_r) * w + (_c)) * 3 + (_ch)])

  // Sum (s[i] - s[j])^2
  // = 2n Sum s[i]^2 - 2 (Sum s[i])^2

  uint64_t *s1 = (uint64_t *)malloc(sizeof(uint64_t) * (w + 1) * (h + 1) * 3);
  uint64_t *s2 = (uint64_t *)malloc(sizeof(uint64_t) * (w + 1) * (h + 1) * 3);
  for (int k = 0; k < 3; k++) {
    for (int r = 0; r < h; r++) arr(s1, r, 0, k) = arr(s2, r, 0, k) = 0;
    for (int c = 0; c < w; c++) arr(s1, 0, c, k) = arr(s2, 0, c, k) = 0;
  }
  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++)
  for (int k = 0; k < 3; k++) {
    uint64_t val = arr(pxi, r, c, k);
    arr(s1, r + 1, c + 1, k) =
        val
      + arr(s1, r + 1, c, k)
      + arr(s1, r, c + 1, k)
      - arr(s1, r, c, k);
    arr(s2, r + 1, c + 1, k) =
        val * val
      + arr(s2, r + 1, c, k)
      + arr(s2, r, c + 1, k)
      - arr(s2, r, c, k);
  }

  bool *instroke = (bool *)malloc(sizeof(bool) * w * h);
#define arrflat(_a, _r, _c) (_a[(_r) * w + (_c)])

  int R = 3;
  int N = (2*R + 1) * (2*R + 1);
  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++)
    if (r >= R && r < h - (R + 1) && c >= R && c <= w - (R + 1)) {
      uint64_t sum = 0;
      for (int k = 0; k < 3; k++) {
        sum += 2 * N * (
            arr(s1, r + R + 1, c + R + 1, k)
          - arr(s1, r + R + 1, c - R, k)
          - arr(s1, r - R, c + R + 1, k)
          + arr(s1, r - R, c - R, k)
        );
        sum += 2 * (
            arr(s1, r + R + 1, c + R + 1, k)
          - arr(s1, r + R + 1, c - R, k)
          - arr(s1, r - R, c + R + 1, k)
          + arr(s1, r - R, c - R, k)
        );
      }
      arrflat(instroke, r, c) = sum <= thr_strokedet * thr_strokedet * N * (N-1);
    } else {
      arrflat(instroke, r, c) = false;
    }

/* Debug: extracted strokes
  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++)
  for (int k = 0; k < 3; k++) {
    arr(pxo, r, c, k) = (arrflat(instroke, r, c) ? 0 : 255);
  }
*/

  // Monochrome canvas
  float *pxv = (float *)malloc(sizeof(float) * w * h);
  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++) arrflat(pxv, r, c) = 0;

  int *q = (int *)malloc(sizeof(int) * w * h);
  int qhead, qtail;
  float *pxdist = (float *)malloc(sizeof(float) * w * h);

  bool *filled = (bool *)malloc(sizeof(bool) * w * h);
  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++) arrflat(filled, r, c) = false;

  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++) if (arrflat(instroke, r, c)) {
    // Find the connected component and average the pixel values
    uint64_t sum[3] = {0, 0, 0};
    qhead = 0; qtail = 1;
    q[0] = r * w + c;
    arrflat(instroke, r, c) = false;
    while (qhead < qtail) {
      int ri = q[qhead] / w, ci = q[qhead] % w;
      qhead++;
      for (int k = 0; k < 3; k++) sum[k] += arr(pxi, ri, ci, k);
      // 4-connected component
      // -1 0
      // 0  1
      // 0 -1
      // 1  0
      for (int dir = 0; dir < 4; dir++) {
        int rj = ri + (dir - 1) / 2;
        int cj = ci + ((dir + 2) % 4 - 1) / 2;
        if (rj >= 0 && rj < h && cj >= 0 && cj < w && arrflat(instroke, rj, cj)) {
          q[qtail++] = rj * w + cj;
          arrflat(instroke, rj, cj) = false;
        }
      }
    }

    float avg[3];
    for (int k = 0; k < 3; k++) avg[k] = (float)sum[k] / qtail;

  /* Debug: inspect average
    for (int i = 0; i < qtail; i++) {
      int ri = q[i] / w, ci = q[i] % w;
      for (int k = 0; k < 3; k++) arr(pxo, ri, ci, k) = (uint8_t)(avg[k] + 0.5f);
    }
  */

    if (avg[0] + avg[1] + avg[2] <= 60 || qtail < 20) continue;

    // Fill solid
    for (int i = 0; i < qtail; i++) {
      int ri = q[i] / w, ci = q[i] % w;
      arrflat(filled, ri, ci) = true;
      float dist = 0;
      for (int k = 0; k < 3; k++) {
        float diff = (arr(pxi, ri, ci, k) - avg[k]);
        dist += diff * diff;
      }
      dist = sqrtf(dist / 3);
      arrflat(pxdist, ri, ci) = dist;
    }
    // Restore queue
    qhead = 0;
    while (qhead < qtail) {
      int ri = q[qhead] / w, ci = q[qhead] % w;
      qhead++;
      float dist = arrflat(pxdist, ri, ci);
    /*
      // Take maximum distance of surrounding pixels including itself (erosion)
      float dist = 0;
      for (int rj = ri - 1; rj <= ri + 1; rj++)
      for (int cj = ci - 1; cj <= ci + 1; cj++)
        if (rj >= 0 && rj < h && cj >= 0 && cj < w && arrflat(filled, rj, cj)) {
          if (dist < arrflat(pxdist, rj, cj))
            dist = arrflat(pxdist, rj, cj);
        }
    */
      // Assign value
      float value = 1 - (dist - thr_fadel) / (thr_fadeh - thr_fadel);
      value = (value < 0 ? 0 : value > 1 ? 1 : value);
      arrflat(pxv, ri, ci) = value;
      // 8-connected component
      for (int rj = ri - 1; rj <= ri + 1; rj++)
      for (int cj = ci - 1; cj <= ci + 1; cj++)
        if (rj >= 0 && rj < h && cj >= 0 && cj < w && !arrflat(filled, rj, cj)) {
          float dist = 0;
          for (int k = 0; k < 3; k++) {
            float diff = (arr(pxi, rj, cj, k) - avg[k]);
            dist += diff * diff;
          }
          dist = sqrtf(dist / 3);
          if (dist <= thr_fadeh) {
            arrflat(pxdist, rj, cj) = dist;
            q[qtail++] = rj * w + cj;
            arrflat(filled, rj, cj) = true;
          }
        }
    }
  }

  for (int r = 0; r < h; r++)
  for (int c = 0; c < w; c++)
  for (int k = 0; k < 3; k++) {
    arr(pxo, r, c, k) = 255 - (uint8_t)(arrflat(pxv, r, c) * (255 - tint[k]) + 0.5f);
  }

  if (!stbi_write_png(argv[2], w, h, 3, pxo, w * 3)) {
    printf("Cannot write %s\n", argv[2]);
    return 1;
  }

  return 0;
}

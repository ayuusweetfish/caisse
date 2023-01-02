#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static inline int myrand() {
  static uint32_t seed = 20230102;
  seed = ((uint64_t)seed * 1103515245 + 12345) & 0x7fffffff;
  return seed >> 4;
}
#define rand myrand

#define N 30
#define M 8

bool a[N][M];
int f[N];
void do_case()
{
  int count = rand() % (N * M * 2 / 3) + (N * M / 6);
  memset(a, false, sizeof a);
  for (int i = 0; i < count; i++) {
    int n = rand() % N, m = rand() % M;
    a[n][m] = true;
  }
  int K = 10 + rand() % 6;

  for (int j = 0; j < M; j++) {
    for (int i = 0; i < N; i++)
      putchar(a[i][j] ? '#' : '.');
    putchar('\n');
  }
  printf("K = %d | dens = %.4f\n", K, (double)count / (N * M));

  for (int i = 0; i < N; i++) {
    bool occ[M] = { false };
    int occnum = 0;
    int best = INT_MAX / 2, decision = -2;
    for (int j = i; j >= 0; j--) {
      for (int k = 0; k < M; k++) if (!occ[k] && a[j][k]) {
        occ[k] = true;
        occnum++;
      }
      int cur = (j == 0 ? 0 : f[j - 1]) + (i - j + 1 + K) * occnum;
      if (best > cur) {
        best = cur;
        decision = j - 1;
      }
    }
    f[i] = best;
    printf(" %d", decision);
    printf("[%d]", best);
  }
  putchar('\n');
}

int main()
{
  do_case();
  return 0;
}

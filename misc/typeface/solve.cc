#include <cstdint>    // uint64_t
#include <cstdio>     // fgets
#include <cstring>    // memset, memmove
#include <algorithm>  // shuffle, sort
#include <random>     // mt19937
#include <set>        // multiset
#include <unordered_set>
#include <utility>    // pair
#include <vector>

/*
static const int N = 30;
static int activepenalty = 1;
static int segpenalty = 2;

101010101010101010101010101010
111111111111111000000000000000
111000111000111000111000111000
011010011001100110011001100110
111111111110011001100000000000
*/

static const int N = 3000;
static int activepenalty = 20;
static int segpenalty = 50;

template <typename T> struct arrayN {
  T a[N];
  inline T &operator [] (size_t i) { return a[i]; }
  inline const T &operator [] (size_t i) const { return a[i]; }
  inline T *begin() { return a; }
  inline T *end() { return a + N; }
};
static std::vector<arrayN<bool>> A;

typedef arrayN<int> perm;

template <bool Decision = false>
static inline int eval(const perm &p)
{
  int K = A.size();
  int last[K];
  int ordlasts[K];
  for (int i = 0; i < K; i++) last[i] = ordlasts[i] = -1;
  arrayN<int> f, decision;
  for (int i = 0; i < N; i++) {
    // Update last positions
    for (int j = 0; j < K; j++) ordlasts[j] *= 2;
    for (int j = 0; j < K; j++) if (A[j][p[i]]) {
      int *pos = std::lower_bound(ordlasts, ordlasts + K, last[j] * 2);
      *pos -= 1;
      last[j] = i;
    }
    int fillptr = 0;
    for (int j = 0; j < K; j++) {
      if (ordlasts[j] % 2 == 0) ordlasts[fillptr++] = ordlasts[j] / 2;
    }
    for (; fillptr < K; fillptr++) ordlasts[fillptr] = i;
    // Update dynamic programming results
    // This is suboptimal w.r.t. empty segments, but we leave this to GA
    f[i] = (activepenalty + i + 1) * K + segpenalty;
    if (Decision) decision[i] = -1;
    for (int k = 0; k < K; k++) {
      int pos = ordlasts[k];
      if (pos == i) break;
      int cur = (pos == -1 ? 0 : f[pos]) +
        (activepenalty + i - pos) * (K - k - 1) + segpenalty;
      if (f[i] > cur) {
        f[i] = cur;
        if (Decision) decision[i] = pos;
      }
    }
  }
  // Print solution
  if (Decision) {
    arrayN<bool> crop;
    for (int i = 0; i < N; i++) crop[i] = false;
    for (int i = N - 1; i >= 0; i = decision[i]) crop[i] = true;
    for (int i = 0; i < N; i++) putchar(crop[i] ? '>' : '-'); putchar('\n');
    for (int i = 0; i < K; i++) {
      for (int j = 0; j < N; j++) putchar(A[i][p[j]] ? '#' : '.');
      putchar('\n');
    }
  }
  return f[N - 1];
}

typedef uint64_t hash_t;
static inline hash_t phash(const perm &p)
{
  hash_t result = 0;
  for (int i = 0; i < N; i++) result = result * 100007 + p[i];
  return result;
}

static inline void pmx(const perm &a, const perm &b, perm &c, int l, int r)
{
  if (l == r) r = N - 1;
  if (l > r) std::swap(l, r);
  static int map[N];
  memset(map, -1, sizeof map);
  for (int i = l; i < r; i++) {
    c[i] = a[i];
    map[a[i]] = b[i];
  }
  for (int i = 0; i < l; i++) {
    int x = b[i];
    while (map[x] != -1) x = map[x];
    c[i] = x;
  }
  for (int i = r; i < N; i++) {
    int x = b[i];
    while (map[x] != -1) x = map[x];
    c[i] = x;
  }
}

static inline void mut(perm &p, int rand1, int rand2)
{
  std::swap(p[rand1], p[rand2]);
}

int main()
{
  char s[N + 3];
  while (fgets(s, sizeof s, stdin)) {
    arrayN<bool> r;
    for (int i = 0; i < N; i++) r[i] = (s[i] == '1');
    A.push_back(r);
  }
  printf("#rows = %zu\n", A.size());

  std::mt19937 g(221215);

  perm p0;
  arrayN<std::pair<int, int>> count;
  for (int i = 0; i < N; i++) count[i] = {0, i};
  for (int i = 0; i < A.size(); i++)
    for (int j = 0; j < N; j++) if (A[i][j]) count[j].first++;
  std::sort(count.begin(), count.end());
  for (int i = 0; i < N; i++) p0[i] = count[N - 1 - i].second;

  static int n_pop = 100;
  static int n_reprod = 150;
  static int n_its = 1000;
  std::unordered_set<int> hashes;
  struct indiv {
    int val;
    hash_t hash;
    perm chro;
    inline bool operator < (const indiv &other) const { return val < other.val; }
  };
  indiv genome[n_pop + n_reprod];
  // Initial population
  for (int i = 0; i < n_pop; i++) {
    if (i == 0) {
      genome[i].chro = p0;
    } else {
      for (int j = 0; j < N; j++) genome[i].chro[j] = j;
      std::shuffle(genome[i].chro.begin(), genome[i].chro.end(), g);
    }
    genome[i].hash = phash(genome[i].chro);
    genome[i].val = eval(genome[i].chro);
  }
  // Evolution
  for (int it = 0; it < n_its; it++) {
    hashes.clear();
    for (int i = 0; i < n_pop; i++) hashes.insert(genome[i].hash);
    for (int i = 0; i < n_reprod; i++) {
      do {
        int u = g() % n_pop, v = g() % (n_pop - 1);
        if (u == v) v = n_pop - 1;
        int l = g() % N, r = g() % (N - 1);
        pmx(genome[u].chro, genome[v].chro, genome[n_pop + i].chro, l, r);
        while (g() & 1) mut(genome[n_pop + i].chro, g() % N, g() % N);
        genome[n_pop + i].hash = phash(genome[n_pop + i].chro);
      } while (hashes.count(genome[n_pop + i].hash));
      genome[n_pop + i].val = eval(genome[n_pop + i].chro);
    }
    std::sort(genome, genome + n_pop + n_reprod);
    printf("it = %4d |", it);
    for (int i = 0; i < 10; i++) printf(" %6d", genome[i].val);
    putchar('\n');
  }

  for (int i = 0; i < N; i++) printf("%d%c", genome[0].chro[i], i == N - 1 ? '\n' : ' ');
  eval<true>(genome[0].chro);

  return 0;
}

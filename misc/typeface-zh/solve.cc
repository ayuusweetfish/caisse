#include <cstdint>    // uint64_t
#include <cstdio>     // fgets, fopen, fgetc
#include <cstring>    // memset, memmove, strlen
#include <algorithm>  // shuffle, sort
#include <map>
#include <random>     // mt19937
#include <set>        // multiset
#include <unordered_map>
#include <unordered_set>
#include <utility>    // pair
#include <vector>

static const int MaxN = 2000;
static int N = 0;
static int activepenalty = 5;
static int segpenalty = 0;
static int segminsize = 50;

template <typename T> struct arrayN {
  T a[MaxN];
  arrayN() { }
  arrayN(const T value) { for (int i = 0; i < N; i++) a[i] = value; }
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
      if (pos >= i - segminsize) break;
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
  static int map[MaxN];
  memset(map, -1, sizeof(int) * N);
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

typedef int_fast32_t codepoint;

static inline codepoint readutf8(FILE *f)
{
  uint8_t b = fgetc(f);
  if (b < 0b10000000) return b;
  if (b <= 0b11011111)
    return ((b & 0b11111) << 6) | (fgetc(f) & 0b111111);
  if (b <= 0b11101111)
    return ((b & 0b1111) << 12) |
      ((fgetc(f) & 0b111111) << 6) | (fgetc(f) & 0b111111);
  if (b <= 0b11110111)
    return ((b & 0b1111) << 18) | ((fgetc(f) & 0b111111) << 12) |
      ((fgetc(f) & 0b111111) << 6) | (fgetc(f) & 0b111111);
  return -1;
}

static inline void printutf8(codepoint c)
{
  if (c <= 0x7f) {
    putchar(c);
  } else if (c <= 0x7ff) {
    putchar(0b11000000 | (c >> 6));
    putchar(0b10000000 | (c & 0b111111));
  } else if (c <= 0xffff) {
    putchar(0b11100000 | (c >> 12));
    putchar(0b10000000 | ((c >> 6) & 0b111111));
    putchar(0b10000000 | (c & 0b111111));
  } else if (c <= 0x10ffff) {
    putchar(0b11110000 | (c >> 18));
    putchar(0b10000000 | ((c >> 12) & 0b111111));
    putchar(0b10000000 | ((c >> 6) & 0b111111));
    putchar(0b10000000 | (c & 0b111111));
  }
}

int main()
{
  bool incremental = (getenv("INC") != NULL);
  if (incremental) fprintf(stderr, "Incremental mode: common charset will not be updated\n");

  // Charset
  // otfinfo -u AaKaiSong2WanZi2.ttf | perl -pe 's/^uni([0-9A-F]+) .*$/\1/g' > AaKaiSong2WanZi2.charset.txt
  std::unordered_set<codepoint> charset;
  {
    FILE *f = fopen("AaKaiSong2WanZi2.charset.txt", "r");
    codepoint c;
    while (fscanf(f, "%x", &c) == 1) charset.insert(c);
    fclose(f);
  }

  std::map<codepoint, int> cpcount;
  std::vector<codepoint> cpseq;
  std::vector<std::unordered_set<codepoint>> docs;
  std::vector<char *> docnames;
  char s[1024];
  while (fgets(s, sizeof s, stdin)) {
    size_t len = strlen(s);
    if (s[len - 1] == '\n') s[len - 1] = '\0';
    FILE *f = fopen(s, "r");

    fgets(s, sizeof s, stdin);  // Read an identifier on a new line
    len = strlen(s);
    if (s[len - 1] == '\n') s[len - 1] = '\0';
    docnames.push_back(strdup(s));

    std::unordered_set<int> cpset;
    while (true) {
      codepoint c = readutf8(f);
      if (c == -1) break;
      // http://ftp.unicode.org/Public/UNIDATA/Blocks.txt
      if (c >= 0x800) {
        auto it = cpcount.lower_bound(c);
        if (it == cpcount.end() || it->first != c) {
          if (charset.count(c) == 0) continue;
          it = cpcount.insert(it, {c, 0});
        }
        if (cpset.count(c) == 0) {
          cpset.insert(c);
          it->second += 1;
        }
      }
    }
    docs.emplace_back(cpset);
    fprintf(stderr, "%4zu %s\n", docs.rbegin()->size(), s);
  }
  fprintf(stderr, "#glyphs = %zu\n", cpcount.size());

  int K = docs.size();
  fprintf(stderr, "#documents = %d\n", K);

  if (incremental) {
    // Read previously saved common charset
    FILE *f = fopen("common.txt", "r");
    std::unordered_set<codepoint> commoncps;
    codepoint c;
    while ((c = readutf8(f)) != '\n') commoncps.insert(c);

    for (int i = 0; i < K; i++) {
      printf("%s\t", docnames[i]);
      std::vector<codepoint> cps;
      for (const auto c : docs[i])
        if (commoncps.count(c) == 0) cps.push_back(c);
      std::sort(cps.begin(), cps.end());
      for (codepoint c : cps) printf(" %04x", c);
      printf("\n");
    }
    return 0;
  }

  std::unordered_map<codepoint, int> cpid;
  // first = codepoint, second = count
  for (const auto &entry : cpcount) if (entry.second >= 3) {
    cpid[entry.first] = cpseq.size();
    cpseq.push_back(entry.first);
  }

  N = cpid.size();
  fprintf(stderr, "#frequent glyphs = %d\n", N);
  if (N > MaxN) {
    fprintf(stderr, "MaxN = %d, please recompile\n", MaxN);
    return 1;
  }

  for (int i = 0; i < K; i++) {
    arrayN<bool> row(false);
    for (const int c : docs[i]) {
      auto it = cpid.find(c);
      if (it != cpid.end()) row[it->second] = true;
    }
    A.push_back(row);
  }

  std::mt19937 g(221215);

  perm p0;
  arrayN<std::pair<int, int>> count;
  for (int i = 0; i < N; i++) count[i] = {0, i};
  for (int i = 0; i < K; i++)
    for (int j = 0; j < N; j++) if (A[i][j]) count[j].first++;
  std::sort(count.begin(), count.end());
  for (int i = 0; i < N; i++) p0[i] = count[N - 1 - i].second;

  static int n_pop = 250;
  static int n_reprod = 150;
  static int n_its = 5000;
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
    if (it / (n_its / 20) != (it + 1) / (n_its / 20)) {
      for (int i = n_pop / 2; i < n_pop; i++) {
        for (int j = 0; j < N; j++) genome[i].chro[j] = j;
        std::shuffle(genome[i].chro.begin(), genome[i].chro.end(), g);
        genome[i].hash = phash(genome[i].chro);
        genome[i].val = eval(genome[i].chro);
      }
    }
    fprintf(stderr, "it = %4d |", it);
    for (int i = 0; i < 10; i++) fprintf(stderr, " %6d", genome[i].val);
    fprintf(stderr, "\n");
  }

  for (int i = 0; i < N; i++)
    // printf("%04x%c", cpseq[genome[0].chro[i]], i == N - 1 ? '\n' : ' ');
    printutf8(cpseq[genome[0].chro[i]]);
  putchar('\n');
  eval<true>(genome[0].chro);
  // .,$s/./& /g

  return 0;
}

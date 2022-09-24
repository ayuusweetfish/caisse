#include <dirent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum entry_type {
  ENTRY_TEXT = 0,
  ENTRY_EXPR = 1,
  ENTRY_STMT = 2,
  ENTRY_BLOCK = 3,
} entry_type;
typedef struct entry {
  entry_type ty;
  const char *text;
  size_t len;
} entry;
typedef struct entry_list {
  entry *e;
  size_t count;
} entry_list;

void print_entries(entry_list l)
{
  static const char *type_names[] = {
    "----", "expr", "stmt", "blck"
  };
  for (size_t i = 0; i < l.count; i++) {
    printf("[%s] [", type_names[l.e[i].ty]);
    // fwrite(l.e[i].text, (l.e[i].len < 20 ? l.e[i].len : 20), 1, stdout);
    if (l.e[i].len <= 45) {
      for (size_t j = 0; j < l.e[i].len; j++) {
        char c = l.e[i].text[j];
        putchar(c == '\n' ? ' ' : c);
      }
    } else {
      for (size_t j = 0; j < 20; j++) {
        char c = l.e[i].text[j];
        putchar(c == '\n' ? ' ' : c);
      }
      fputs("]...[", stdout);
      for (size_t j = 0; j < 20; j++) {
        char c = l.e[i].text[l.e[i].len - 20 + j];
        putchar(c == '\n' ? ' ' : c);
      }
    }
    fputs("]\n", stdout);
  }
  fflush(stdout);
}

void append_entry(entry_list *l, size_t *cap, const entry e)
{
  if (l->count == *cap) {
    *cap *= 2;
    l->e = (entry *)realloc(l->e, *cap * sizeof(entry));
  }
  l->e[l->count++] = e;
}

entry_list parse(const char *s)
{
  entry_list l;
  size_t cap = 8;
  l.count = 0;
  l.e = (entry *)malloc(cap * sizeof(entry));

  const char *S = s;  // Original start
  const char *last = s;
  while (*s != '\0') {
    if (s[0] == '{' && s[1] == '{') {
      // New text entry
      if (last != s) {
        append_entry(&l, &cap, (entry){
          .ty = ENTRY_TEXT,
          .text = last,
          .len = s - last,
        });
      }
      // Find matching closing brackets
      size_t n_obrkts = 2;
      while (s[n_obrkts] == '{') n_obrkts++;
      const char *end = s + n_obrkts;
      size_t n_cbrkts;
      for (n_cbrkts = 0; n_cbrkts < n_obrkts && *end != '\0'; end++)
        if (*end == '}') n_cbrkts++;
        else n_cbrkts = 0;
      if (n_cbrkts != n_obrkts) {
        puts("No matching closing brackets!");
        exit(1);
      }
      // Create entry
      entry e = {
        .text = s + n_obrkts,
        .len = end - s - n_obrkts * 2,
      };
      switch (s[n_obrkts]) {
        case '!':
          e.ty = ENTRY_STMT;
          e.text++; e.len--;
          break;
        case '=':
          e.ty = ENTRY_BLOCK;
          e.text++; e.len--;
          break;
        default:
          e.ty = ENTRY_EXPR;
          break;
      }
      append_entry(&l, &cap, e);
      // Move pointer forward
      s = last = end;
    } else {
      s++;
    }
  }

  if (last != s) {
    append_entry(&l, &cap, (entry){
      .ty = ENTRY_TEXT,
      .text = last,
      .len = s - last,
    });
  }

  return l;
}

char *read_all(const char *path)
{
  FILE *f = fopen(path, "r");
  fseek(f, 0, SEEK_END);
  size_t len = (size_t)ftell(f);
  fseek(f, 0, SEEK_SET);
  char *buf = (char *)malloc(len);
  fread(buf, len, 1, f);
  fclose(f);
  return buf;
}

static inline bool endswith(const char *a, const char *b)
{
  size_t la = strlen(a), lb = strlen(b);
  return (memcmp(a + la - lb, b, lb) == 0);
}
static inline char *multicat(const char *a, const char *b)
{
  size_t la = strlen(a), lb = strlen(b);
  char *s = (char *)malloc(la + lb + 1);
  memcpy(s, a, la);
  memcpy(s + la, b, lb);
  s[la + lb] = '\0';
  return s;
}

int main()
{
  print_entries(parse(read_all("index.html")));

  DIR *dir = opendir("site");
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL) {
    if (endswith(ent->d_name, ".html")) {
      char *full_path = multicat("site/", ent->d_name);
      puts(full_path);
      print_entries(parse(read_all(full_path)));
    }
  }

  return 0;
}

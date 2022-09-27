#include "minilua.h"

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
        case ':':
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

typedef struct str {
  char *p;
  size_t len, cap;
} str;

static inline str str_new()
{
  return (str){
    .p = (char *)malloc(9),
    .len = 0,
    .cap = 8,
  };
}
static inline void str_push(str *s, const char *t, size_t l)
{
  if (s->len + l > s->cap) {
    do s->cap *= 2; while (s->len + l > s->cap);
    s->p = (char *)realloc(s->p, s->cap + 1);
  }
  memcpy(s->p + s->len, t, l);
  s->len += l;
}
static inline void str_pushn(str *s, const char *t)
{
  str_push(s, t, strlen(t));
}
static inline char *str_get(const str *s)
{
  s->p[s->len] = '\0';
  return s->p;
}
static inline void str_free(str *s)
{
  free(s->p);
}

static inline bool is_id_char(char c)
{
  return
    (c >= '0' && c <= '9') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= 'a' && c <= 'z') ||
    c == '_';
}
static inline bool is_space(char c)
{
  return (
    c == '\t' || c == '\n' || c == '\v' ||
    c == '\f' || c == '\r' || c == ' '
  );
}

char *trim(char *s, size_t len, size_t *newlen)
{
  size_t i = 0, j = len - 1;
  while (i < len && is_space(s[i])) i++;
  while (j >= i && is_space(s[j])) j--;
  *newlen = j + 1 - i;
  return s + i;
}

bool calc_cond(const char **body, lua_State *L)
{
  const char *s = *body;
  if (*s != '@') return true;
  s++;  // Skip '@'
  const char *cond_end = s;
  while (is_id_char(*cond_end)) cond_end++;
  // Evaluate condition expression
  str expr = str_new();
  str_pushn(&expr, "return ");
  str_push(&expr, s, cond_end - s);
  printf("cond: %s\n", str_get(&expr));
  luaL_loadbuffer(L, expr.p, expr.len, "condition expression");
  str_free(&expr);
  lua_call(L, 0, 1);
  bool cond = lua_toboolean(L, -1);
  lua_pop(L, 1);
  puts(cond ? "yes" : "no");
  // Return
  *body = cond_end;
  return cond;
}

void eval_template(str *s, entry_list l, lua_State *L)
{
  str *top_level_s = s;

  char *block_name = NULL;
  bool block_disabled = false;
  str block_s;

  for (size_t i = 0; i < l.count; i++) {
    const entry e = l.e[i];
    if (e.ty == ENTRY_TEXT && !block_disabled && s != NULL) {
      str_push(s, e.text, e.len);
    } else if (e.ty == ENTRY_EXPR && !block_disabled) {
      const char *body = e.text;
      bool exec = calc_cond(&body, L);
      if (exec) {
        str expr = str_new();
        str_pushn(&expr, "return (");
        str_push(&expr, body, e.text + e.len - body);
        str_pushn(&expr, ")");
        luaL_loadbuffer(L, expr.p, expr.len, "template expression");
        printf("expr: %s\n", str_get(&expr));
        str_free(&expr);
        lua_call(L, 0, 1);
        size_t len;
        const char *result = lua_tolstring(L, -1, &len);
        lua_pop(L, 1);
        if (result != NULL)
          str_push(s, result, len);
      }
    } else if (e.ty == ENTRY_STMT && !block_disabled) {
      const char *body = e.text;
      bool exec = calc_cond(&body, L);
      if (exec) {
        luaL_loadbuffer(L, body, e.text + e.len - body, "template statement");
        lua_call(L, 0, 0);
      }
    } else if (e.ty == ENTRY_BLOCK) {
      const char *body = e.text;
      bool exec = calc_cond(&body, L);
      if (exec) {
        // Free previous
        if (block_name != NULL) {
          size_t trimmed_len;
          char *trimmed_start = trim(s->p, s->len, &trimmed_len);
          lua_pushlstring(L, trimmed_start, trimmed_len);
          lua_setglobal(L, block_name);
          free(block_name);
          str_free(s);
        }
        // Copy the name of the block
        while (!is_id_char(*body) && body < e.text + e.len) body++;
        const char *name_start = body;
        while (is_id_char(*body) && body < e.text + e.len) body++;
        size_t name_len = body - name_start;
        if (name_len > 0) {
          block_name = (char *)malloc(name_len + 1);
          memcpy(block_name, name_start, name_len);
          block_name[name_len] = '\0';
          printf("block: %s\n", block_name);
          // Switch to a separate string buffer
          block_s = str_new();
          s = &block_s;
          block_disabled = false;
        } else {
          // Back to top-level
          block_name = NULL;
          block_disabled = false;
          s = top_level_s;
        }
      } else {
        block_disabled = true;
      }
    }
  }
  if (block_name != NULL) {
    size_t trimmed_len;
    char *trimmed_start = trim(s->p, s->len, &trimmed_len);
    lua_pushlstring(L, trimmed_start, trimmed_len);
    lua_setglobal(L, block_name);
    free(block_name);
    str_free(s);
  }
}

char *eval(entry_list index, entry_list page, size_t *len)
{
  str s = str_new();

  lua_State *L = luaL_newstate();
  luaopen_base(L);

  lua_pushboolean(L, true);
  lua_setglobal(L, "zh");

  eval_template(NULL, page, L);
  eval_template(&s, index, L);

  if (len != NULL) *len = s.len;
  return str_get(&s);
}

char *read_all(const char *path)
{
  FILE *f = fopen(path, "r");
  fseek(f, -1, SEEK_END);
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
  entry_list index_l = parse(read_all("index.html"));
  print_entries(index_l);

  DIR *dir = opendir("site");
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL) {
    if (endswith(ent->d_name, ".html")) {
      char *full_path = multicat("site/", ent->d_name);
      putchar('\n');
      puts(full_path);
      entry_list l = parse(read_all(full_path));
      print_entries(l);
      putchar('\n');
      size_t len;
      char *rendered = eval(index_l, l, &len);
      char *rendered_path = multicat("rendered/", ent->d_name);
      FILE *f = fopen(rendered_path, "w");
      fwrite(rendered, len, 1, f);
      fclose(f);
    }
  }

  return 0;
}

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>

int main()
{
  FILE *f = fopen("index.html", "r");
  fseek(f, 0, SEEK_END);
  size_t len = (size_t)ftell(f);
  fseek(f, 0, SEEK_SET);
  char *buf = (char *)malloc(len);
  fread(buf, len, 1, f);
  fclose(f);
  for (size_t i = 0; i < len; i++) putchar(buf[i]);

  DIR *dir = opendir("site");
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL) {
    puts(ent->d_name);
  }

  return 0;
}

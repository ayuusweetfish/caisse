#include <stdio.h>    // fgets, perror
#include <string.h>   // strlen
#include <unistd.h>   // getcwd
#include <limits.h>   // PATH_MAX

void trim_newline(char *str)
{
  size_t len = strlen(str);
  if (len > 0 && str[len - 1] == '\n') str[len - 1] = '\0';
}

int main()
{
  static char src[PATH_MAX], dst[PATH_MAX];

  if (getcwd(src, sizeof src) == NULL) {
    perror("getcwd");
    return 1;
  }

  size_t cwd_len = strlen(src);
  src[cwd_len] = '/';

  while (fgets(src + cwd_len + 1, sizeof src - (cwd_len + 1), stdin) != NULL) {
    if (fgets(dst, sizeof dst, stdin) == NULL) break;
    trim_newline(src + cwd_len + 1);
    trim_newline(dst);
    if (symlink(src, dst) != 0) perror("symlink");
  }

  return 0;
}

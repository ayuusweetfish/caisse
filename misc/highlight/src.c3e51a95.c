#include <ctype.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

static FILE *f_out_gdb;

static uint8_t page_buf[256];
static int page_buf_ptr = 0;
static uint32_t page_start = 0;

static inline void flush_gdb_script()
{
  if (page_start % 0x10000 == 0) {
    fprintf(f_out_gdb, "echo Erase block 0x%06x\\n\n", page_start);
    fprintf(f_out_gdb, "call flash_erase_64k(0x%06x)\n", page_start);
  }
  fprintf(f_out_gdb, "set flash_test_write_buf = {");
  for (int i = 0; i < page_buf_ptr; i++) {
    if (i != 0) fprintf(f_out_gdb, ", ");
    fprintf(f_out_gdb, "%d", page_buf[i]);
  }
  fprintf(f_out_gdb, "}\n");
  fprintf(f_out_gdb, "call flash_test_write(0x%06x, %d)\n", page_start, page_buf_ptr);
  fprintf(f_out_gdb, "echo Written page 0x%06x\\n\n", page_start);

  page_buf_ptr = 0;
  page_start += 256;
}

static inline void add_data(uint8_t data)
{
  page_buf[page_buf_ptr++] = data;
  if (page_buf_ptr == 256) flush_gdb_script();
}

int main(int argc, char *argv[])
{
  if (argc <= 2) {
    printf("Usage: %s <input> [<input> ...] <output-gdbinit>\n", argv[0]);
    return 0;
  }

  const char *path_out_gdb = argv[argc - 1];
  f_out_gdb = fopen(path_out_gdb, "w");
  fprintf(stderr, "Writing GDB script to %s\n", path_out_gdb);
  if (f_out_gdb == NULL) {
    fprintf(stderr, "Cannot open %s for writing\n", path_out_gdb);
    return 1;
  }

  fprintf(f_out_gdb, "b flash_test_write_breakpoint\n");
  fprintf(f_out_gdb, "commands\n");

  int in_count = argc - 2;
  for (int i = 0; i < in_count; i++) {
    const char *path_in = argv[1 + i];
    FILE *f_in = fopen(path_in, "rb");
    // fprintf(stderr, "Reading file (%d/%d) %s\n", i + 1, in_count, path_in);
    if (f_in == NULL) {
      fprintf(stderr, "Cannot open %s for reading\n", path_in);
      return 1;
    }

    const char *name = path_in;
    for (const char *p = path_in; *p != '\0'; p++)
      if (*p == '/' || *p == '\\') name = p;
    uint32_t addr_start = page_start + page_buf_ptr;

    fprintf(f_out_gdb, "echo ======== File (%d/%d) %s ========\\n\n", i + 1, in_count, name);

    int b;
    while ((b = fgetc(f_in)) != EOF) add_data(b);

    uint32_t len = page_start + page_buf_ptr - addr_start;

#define print_name() do { \
    int spaces = 16; \
    for (const char *p = name; *p != '\0'; p++) { \
      putchar(isalnum(*p) ? *p : '_'); \
      spaces--; \
    } \
    for (int i = 0; i < spaces; i++) putchar(' '); \
  } while (0)

    printf("#define FILE_ADDR_");
    print_name();
    printf(" %" PRId32 "\n", addr_start);
    printf("#define FILE_SIZE_");
    print_name();
    printf(" %" PRId32 "\n", len);
  }
  flush_gdb_script();

  fprintf(f_out_gdb, "end\n");
  fprintf(f_out_gdb, "r\n");

  fclose(f_out_gdb);

  return 0;
}

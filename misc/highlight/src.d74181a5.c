static inline void swv_putchar(uint8_t c)
{
  // 取消原本的 SWV 输出
  // ITM_SendChar(c);
  if (c == '\n') {
    swv_buf[swv_buf_ptr++] = '\0';
    swv_trap_line();
    swv_buf_ptr = 0;
  } else if (swv_buf_ptr < (sizeof swv_buf) - 1) {
    swv_buf[swv_buf_ptr++] = c;
  }
}

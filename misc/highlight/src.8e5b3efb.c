#include <stm32f1xx_hal.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

const int Threshold[16] = {
  10, 10, 10, 10, 10, 10, 10, 10,
  10, 10, 10, 10, 10, 10, 10, 10,
};

I2C_HandleTypeDef i2c1 = { 0 };
UART_HandleTypeDef uart1 = { 0 };

#define min(_a, _b) ((_a) < (_b) ? (_a) : (_b))
#define max(_a, _b) ((_a) > (_b) ? (_a) : (_b))

struct debouncer {
  int32_t high;
  int16_t threshold;
  int8_t count;
  bool on, first;
};

static inline void debouncer_init(struct debouncer *d)
{
  d->first = true;
}

static inline void debouncer_update(struct debouncer *d, int32_t value)
{
  if (d->first) {
    d->high = value * 3 / 4;
    d->first = false;
  }

  d->high = max(d->high - 1, min(d->high + 64, value));
  if (value < d->high - d->threshold)
    d->count = min(d->count + 1, 25); // 250 ms to fill up
  else
    d->count = max(d->count - 1, 0);
  if (!d->on && d->count >= 15) d->on = true;
  else if (d->on && d->count < 10) d->on = false;
}

// Software I2C
// ======

static uint32_t hclk_per_us;
void DWT_Delay_Init()
{
  CoreDebug->DEMCR &= ~CoreDebug_DEMCR_TRCENA_Msk;
  CoreDebug->DEMCR |=  CoreDebug_DEMCR_TRCENA_Msk;

  DWT->CTRL &= ~DWT_CTRL_CYCCNTENA_Msk;
  DWT->CTRL |=  DWT_CTRL_CYCCNTENA_Msk;
  DWT->CYCCNT = 0;

  // HCLK freq = 64 MHz
  // hclk_per_us = 64
  hclk_per_us = HAL_RCC_GetHCLKFreq() / 1000000;
}
static inline void DWT_Delay_us(uint32_t microseconds)
{
  uint32_t clk_cycle_start = DWT->CYCCNT;
  uint32_t cyc = microseconds * hclk_per_us;
  while ((DWT->CYCCNT - clk_cycle_start) < cyc) { }
}
void I2C_delay()
{
  // 25 us = 40 kHz
  DWT_Delay_us(25);
}
static bool read_SCL() { return HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_8); }
static bool read_SDA() { return HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_9); }
static void set_SCL() { HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_SET); }
static void clear_SCL() { HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_RESET); }
static void set_SDA() { HAL_GPIO_WritePin(GPIOB, GPIO_PIN_9, GPIO_PIN_SET); }
static void clear_SDA() { HAL_GPIO_WritePin(GPIOB, GPIO_PIN_9, GPIO_PIN_RESET); }

// 0 - no error
// 1 - no acknowledgement
// 2 - timeout
// 4 - bus error, arbitration lost
static int i2c_err = 0;
static int i2c_first_err_line = -1;

static void i2c_mark_err(int line, int flag)
{
  if (i2c_err == 0) i2c_first_err_line = line;
  i2c_err |= flag;
}

static void wait_SCL_rise(int line)
{
  uint32_t limit = DWT->CYCCNT + 100 * hclk_per_us;
  do {
    if (read_SCL()) return;
  } while (DWT->CYCCNT < limit);
  i2c_mark_err(line, 2);
}

static bool started = false;

void i2c_init()
{
  DWT_Delay_Init();
  clear_SCL();
  clear_SDA();
}

void i2c_start_cond(void)
{
  if (true || started) {  // XXX: ?
    set_SDA();
    I2C_delay();
    set_SCL();
    wait_SCL_rise(__LINE__);

    I2C_delay();
  }

  if (read_SDA() == 0) {
    i2c_mark_err(__LINE__, 4);
    return;
  }

  clear_SDA();
  I2C_delay();
  clear_SCL();
  started = true;
}

void i2c_stop_cond(void)
{
  clear_SDA();
  I2C_delay();

  set_SCL();
  wait_SCL_rise(__LINE__);

  I2C_delay();

  set_SDA();
  I2C_delay();

  if (read_SDA() == 0) {
    i2c_mark_err(__LINE__, 4);
    return;
  }

  started = false;
}

// Write a bit to I2C bus
void i2c_write_bit(bool bit)
{
  if (bit) {
    set_SDA();
  } else {
    clear_SDA();
  }

  I2C_delay();

  set_SCL();

  I2C_delay();

  wait_SCL_rise(__LINE__);

  if (bit && (read_SDA() == 0)) {
    i2c_mark_err(__LINE__, 4);
    return;
  }

  clear_SCL();
}

// Read a bit from I2C bus
bool i2c_read_bit(void)
{
  bool bit;

  set_SDA();

  I2C_delay();

  set_SCL();

  wait_SCL_rise(__LINE__);

  I2C_delay();

  bit = read_SDA();

  clear_SCL();

  return bit;
}

// Write a byte to I2C bus. Return 0 if ack by the target.
bool i2c_write_byte(bool send_start,
                    bool send_stop,
                    unsigned char byte)
{
  unsigned bit;
  bool     nack;

  if (send_start) {
    i2c_start_cond();
  }

  for (bit = 0; bit < 8; ++bit) {
    i2c_write_bit((byte & 0x80) != 0);
    byte <<= 1;
  }

  nack = i2c_read_bit();

  if (send_stop) {
    i2c_stop_cond();
  }

  if (nack) i2c_mark_err(__LINE__, 1);
  return nack;
}

// Read a byte from I2C bus
unsigned char i2c_read_byte(bool nack, bool send_stop)
{
  unsigned char byte = 0;
  unsigned char bit;

  for (bit = 0; bit < 8; ++bit) {
    byte = (byte << 1) | i2c_read_bit();
  }

  i2c_write_bit(nack);

  if (send_stop) {
    i2c_stop_cond();
  }

  return byte;
}

void i2c_write(uint8_t addr, const uint8_t *data, size_t size)
{
  i2c_write_byte(true, false, addr);
  for (size_t i = 0; i < size; i++)
    i2c_write_byte(false, (i == size - 1), data[i]);
}

/*
void i2c_read(uint8_t addr, uint8_t *data, size_t size)
{
  i2c_write_byte(true, false, addr | 1);
}
*/

void i2c_write_reg_byte(uint8_t addr, uint8_t reg, uint8_t data)
{
  i2c_write_byte(true, false, addr);
  i2c_write_byte(false, false, reg);
  i2c_write_byte(false, true, data);
}

void i2c_read_reg(uint8_t addr, uint8_t reg, size_t size, uint8_t *buf)
{
  i2c_write_byte(true, false, addr);
  i2c_write_byte(false, false, reg);
  i2c_write_byte(true, false, addr | 1);
  for (size_t i = 0; i < size; i++)
    buf[i] = i2c_read_byte(i == size - 1, i == size - 1);
}
// End of I2C

static inline void mpr121_reset(uint8_t addr)
{
  // Soft Reset
  i2c_write_reg_byte(addr, 0x80, 0x63);
  // Up-Side Limit / Low-Side Limit / Target Level Register
  // USL = 2.6/3.3 * 256
  //  TL = USL * 0.9
  // LSL = USL * 0.5
  i2c_write_reg_byte(addr, 0x7D, 202);
  i2c_write_reg_byte(addr, 0x7F, 182);
  i2c_write_reg_byte(addr, 0x7E, 101);
  // Filter/Global CDT Configuration Register (0x5D)
  // CDT = 000, SFI = 00, ESI = 010
  i2c_write_reg_byte(addr, 0x5D, 0x02);
  // Auto-Configure Control Register 0
  // FFI = 00, RETRY = 00, BVA = 10, ARE = 0, ACE = 1
  i2c_write_reg_byte(addr, 0x7B, 0x09);
  // Electrode Configuration Register (ECR)
  // CL = 10
  i2c_write_reg_byte(addr, 0x5E, 0x81 + 8);

  char s[32];
  int n = sprintf(s, "i2c_err = %d, line = %d\r\n", i2c_err, i2c_first_err_line);
  HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);

}

uint8_t dispbuf[128 * 8 + 1];

const uint8_t Tamzen7x14[95][14] = {
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x00, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x78, 0x00, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x40, 0xf0, 0x40, 0xf0, 0x40, 0x00, 0x00, 0x02, 0x0f, 0x02, 0x0f, 0x02, 0x00},
  {0x00, 0xc0, 0x20, 0x38, 0x20, 0x20, 0x00, 0x00, 0x08, 0x09, 0x39, 0x09, 0x06, 0x00},
  {0x60, 0x90, 0x60, 0x80, 0x40, 0x20, 0x00, 0x04, 0x02, 0x01, 0x06, 0x09, 0x06, 0x00},
  {0x00, 0x70, 0x88, 0x70, 0x00, 0x80, 0x00, 0x00, 0x07, 0x08, 0x09, 0x06, 0x05, 0x08},
  {0x00, 0x00, 0x00, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0xc0, 0x30, 0x08, 0x00, 0x00, 0x00, 0x00, 0x07, 0x18, 0x20, 0x00, 0x00},
  {0x00, 0x00, 0x08, 0x30, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x20, 0x18, 0x07, 0x00, 0x00},
  {0x00, 0x80, 0x00, 0xc0, 0x00, 0x80, 0x00, 0x00, 0x02, 0x01, 0x07, 0x01, 0x02, 0x00},
  {0x00, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x07, 0x01, 0x01, 0x00},
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4c, 0x3c, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00},
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0c, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x00, 0x80, 0x60, 0x18, 0x00, 0x00, 0x18, 0x06, 0x01, 0x00, 0x00, 0x00},
  {0x00, 0xe0, 0x10, 0x90, 0x50, 0xe0, 0x00, 0x00, 0x07, 0x09, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0x40, 0x20, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x08, 0x08, 0x0f, 0x08, 0x08, 0x00},
  {0x00, 0x20, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x0c, 0x0a, 0x09, 0x08, 0x08, 0x00},
  {0x00, 0x10, 0x10, 0x90, 0xd0, 0x30, 0x00, 0x00, 0x04, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0x80, 0x40, 0x20, 0xf0, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x0f, 0x01, 0x00},
  {0x00, 0xf0, 0x90, 0x90, 0x90, 0x10, 0x00, 0x00, 0x04, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xc0, 0xa0, 0x90, 0x90, 0x00, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0x10, 0x10, 0x10, 0xd0, 0x30, 0x00, 0x00, 0x00, 0x0c, 0x03, 0x00, 0x00, 0x00},
  {0x00, 0x60, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xe0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x00, 0x09, 0x09, 0x05, 0x03, 0x00},
  {0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0c, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4c, 0x3c, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x00, 0x80, 0x40, 0x20, 0x00, 0x00, 0x00, 0x01, 0x02, 0x04, 0x08, 0x00},
  {0x00, 0x40, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x02, 0x02, 0x02, 0x02, 0x02, 0x00},
  {0x00, 0x20, 0x40, 0x80, 0x00, 0x00, 0x00, 0x00, 0x08, 0x04, 0x02, 0x01, 0x00, 0x00},
  {0x00, 0x10, 0x08, 0x88, 0x48, 0x30, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00},
  {0x00, 0xe0, 0x10, 0x10, 0x90, 0xe0, 0x00, 0x00, 0x0f, 0x10, 0x13, 0x12, 0x13, 0x00},
  {0x00, 0xc0, 0x20, 0x10, 0x20, 0xc0, 0x00, 0x00, 0x0f, 0x01, 0x01, 0x01, 0x0f, 0x00},
  {0x00, 0xf0, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x0f, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xc0, 0x20, 0x10, 0x10, 0x10, 0x00, 0x00, 0x03, 0x04, 0x08, 0x08, 0x08, 0x00},
  {0x00, 0xf0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x0f, 0x08, 0x08, 0x04, 0x03, 0x00},
  {0x00, 0xf0, 0x90, 0x90, 0x90, 0x10, 0x00, 0x00, 0x0f, 0x08, 0x08, 0x08, 0x08, 0x00},
  {0x00, 0xf0, 0x90, 0x90, 0x90, 0x10, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0xc0, 0x20, 0x10, 0x10, 0x10, 0x00, 0x00, 0x03, 0x04, 0x08, 0x09, 0x0f, 0x00},
  {0x00, 0xf0, 0x80, 0x80, 0x80, 0xf0, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0f, 0x00},
  {0x00, 0x10, 0x10, 0xf0, 0x10, 0x10, 0x00, 0x00, 0x08, 0x08, 0x0f, 0x08, 0x08, 0x00},
  {0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x06, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xf0, 0x80, 0x40, 0x20, 0x10, 0x00, 0x00, 0x0f, 0x01, 0x02, 0x04, 0x08, 0x00},
  {0x00, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x08, 0x08, 0x08, 0x08, 0x00},
  {0x00, 0xf0, 0x20, 0xc0, 0x20, 0xf0, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0f, 0x00},
  {0x00, 0xf0, 0x20, 0x40, 0x80, 0xf0, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0f, 0x00},
  {0x00, 0xe0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xf0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x0f, 0x01, 0x01, 0x01, 0x00, 0x00},
  {0x00, 0xe0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x18, 0x27, 0x00},
  {0x00, 0xf0, 0x10, 0x10, 0x10, 0xe0, 0x00, 0x00, 0x0f, 0x01, 0x03, 0x05, 0x08, 0x00},
  {0x00, 0x60, 0x90, 0x90, 0x10, 0x10, 0x00, 0x00, 0x08, 0x08, 0x08, 0x09, 0x06, 0x00},
  {0x00, 0x10, 0x10, 0xf0, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00},
  {0x00, 0xf0, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xf0, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x00, 0x03, 0x0c, 0x03, 0x00, 0x00},
  {0x00, 0xf0, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x0f, 0x08, 0x07, 0x08, 0x0f, 0x00},
  {0x00, 0x30, 0x40, 0x80, 0x40, 0x30, 0x00, 0x00, 0x0c, 0x02, 0x01, 0x02, 0x0c, 0x00},
  {0x00, 0x30, 0xc0, 0x00, 0xc0, 0x30, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00},
  {0x00, 0x10, 0x10, 0x90, 0x70, 0x10, 0x00, 0x00, 0x08, 0x0e, 0x09, 0x08, 0x08, 0x00},
  {0x00, 0x00, 0xf8, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x3f, 0x20, 0x20, 0x00, 0x00},
  {0x00, 0x18, 0x60, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x06, 0x18, 0x00},
  {0x00, 0x00, 0x08, 0x08, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x3f, 0x00, 0x00},
  {0x00, 0x40, 0x20, 0x10, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20},
  {0x00, 0x00, 0x08, 0x10, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x40, 0x40, 0x40, 0x80, 0x00, 0x00, 0x06, 0x09, 0x09, 0x09, 0x0f, 0x00},
  {0x00, 0xf8, 0x80, 0x40, 0x40, 0x80, 0x00, 0x00, 0x0f, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x08, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0xf0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x0f, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0x80, 0x00, 0x00, 0x07, 0x09, 0x09, 0x09, 0x09, 0x00},
  {0x00, 0x40, 0xe0, 0x50, 0x50, 0x50, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0xc0, 0x00, 0x00, 0x07, 0x28, 0x28, 0x28, 0x1f, 0x00},
  {0x00, 0xf8, 0x80, 0x40, 0x40, 0x80, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0f, 0x00},
  {0x00, 0x40, 0x40, 0xd8, 0x00, 0x00, 0x00, 0x00, 0x08, 0x08, 0x0f, 0x08, 0x08, 0x00},
  {0x00, 0x00, 0x40, 0x40, 0xd8, 0x00, 0x00, 0x00, 0x20, 0x20, 0x20, 0x1f, 0x00, 0x00},
  {0x00, 0xf8, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00, 0x0f, 0x01, 0x02, 0x04, 0x08, 0x00},
  {0x00, 0x08, 0x08, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x08, 0x08, 0x00},
  {0x00, 0xc0, 0x40, 0xc0, 0x40, 0x80, 0x00, 0x00, 0x0f, 0x00, 0x0f, 0x00, 0x0f, 0x00},
  {0x00, 0xc0, 0x80, 0x40, 0x40, 0x80, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0f, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0x80, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0xc0, 0x80, 0x40, 0x40, 0x80, 0x00, 0x00, 0x7f, 0x08, 0x08, 0x08, 0x07, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0xc0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x04, 0x7f, 0x00},
  {0x00, 0xc0, 0x80, 0x40, 0x40, 0x40, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x80, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x08, 0x09, 0x09, 0x0a, 0x04, 0x00},
  {0x00, 0x40, 0xf0, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x00},
  {0x00, 0xc0, 0x00, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x07, 0x08, 0x08, 0x08, 0x0f, 0x00},
  {0x00, 0xc0, 0x00, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x00, 0x03, 0x0c, 0x03, 0x00, 0x00},
  {0x00, 0xc0, 0x00, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x0f, 0x08, 0x07, 0x08, 0x0f, 0x00},
  {0x00, 0x40, 0x80, 0x00, 0x80, 0x40, 0x00, 0x00, 0x08, 0x04, 0x03, 0x04, 0x08, 0x00},
  {0x00, 0xc0, 0x00, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x07, 0x48, 0x48, 0x44, 0x3f, 0x00},
  {0x00, 0x40, 0x40, 0x40, 0xc0, 0x40, 0x00, 0x00, 0x08, 0x0c, 0x0b, 0x08, 0x08, 0x00},
  {0x00, 0x00, 0x00, 0xf0, 0x08, 0x08, 0x00, 0x00, 0x01, 0x01, 0x1e, 0x20, 0x20, 0x00},
  {0x00, 0x00, 0x00, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0x00},
  {0x00, 0x08, 0x08, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x1e, 0x01, 0x01, 0x00},
  {0x00, 0x60, 0x10, 0x20, 0x40, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
};

const uint8_t Spleen5x8[95][5] = {
  {0x00, 0x00, 0x00, 0x00, 0x00},
  {0x00, 0x00, 0x5f, 0x00, 0x00},
  {0x00, 0x07, 0x00, 0x07, 0x00},
  {0x24, 0x7e, 0x24, 0x7e, 0x24},
  {0x44, 0x4a, 0xff, 0x32, 0x00},
  {0xc6, 0x30, 0x0c, 0x63, 0x00},
  {0x30, 0x4e, 0x59, 0x26, 0x50},
  {0x00, 0x00, 0x07, 0x00, 0x00},
  {0x00, 0x3c, 0x42, 0x81, 0x00},
  {0x00, 0x81, 0x42, 0x3c, 0x00},
  {0x54, 0x38, 0x38, 0x54, 0x00},
  {0x10, 0x10, 0x7c, 0x10, 0x10},
  {0x00, 0x80, 0x60, 0x00, 0x00},
  {0x10, 0x10, 0x10, 0x10, 0x00},
  {0x00, 0x00, 0x40, 0x00, 0x00},
  {0xc0, 0x30, 0x0c, 0x03, 0x00},
  {0x3c, 0x52, 0x4a, 0x3c, 0x00},
  {0x00, 0x44, 0x7e, 0x40, 0x00},
  {0x64, 0x52, 0x52, 0x4c, 0x00},
  {0x24, 0x42, 0x4a, 0x34, 0x00},
  {0x1e, 0x10, 0x7c, 0x10, 0x00},
  {0x4e, 0x4a, 0x4a, 0x32, 0x00},
  {0x3c, 0x4a, 0x4a, 0x30, 0x00},
  {0x06, 0x62, 0x12, 0x0e, 0x00},
  {0x34, 0x4a, 0x4a, 0x34, 0x00},
  {0x0c, 0x52, 0x52, 0x3c, 0x00},
  {0x00, 0x00, 0x48, 0x00, 0x00},
  {0x00, 0x80, 0x68, 0x00, 0x00},
  {0x00, 0x18, 0x24, 0x42, 0x00},
  {0x28, 0x28, 0x28, 0x28, 0x00},
  {0x00, 0x42, 0x24, 0x18, 0x00},
  {0x02, 0x51, 0x09, 0x06, 0x00},
  {0x3c, 0x42, 0x5a, 0x5c, 0x00},
  {0x7c, 0x12, 0x12, 0x7c, 0x00},
  {0x7e, 0x4a, 0x4a, 0x34, 0x00},
  {0x3c, 0x42, 0x42, 0x42, 0x00},
  {0x7e, 0x42, 0x42, 0x3c, 0x00},
  {0x3c, 0x4a, 0x4a, 0x42, 0x00},
  {0x7c, 0x12, 0x12, 0x02, 0x00},
  {0x3c, 0x42, 0x4a, 0x7a, 0x00},
  {0x7e, 0x08, 0x08, 0x7e, 0x00},
  {0x00, 0x42, 0x7e, 0x42, 0x00},
  {0x40, 0x42, 0x3e, 0x02, 0x00},
  {0x7e, 0x08, 0x08, 0x76, 0x00},
  {0x3e, 0x40, 0x40, 0x40, 0x00},
  {0x7e, 0x0c, 0x0c, 0x7e, 0x00},
  {0x7e, 0x0c, 0x30, 0x7e, 0x00},
  {0x3c, 0x42, 0x42, 0x3c, 0x00},
  {0x7e, 0x12, 0x12, 0x0c, 0x00},
  {0x3c, 0x42, 0xc2, 0xbc, 0x00},
  {0x7e, 0x12, 0x12, 0x6c, 0x00},
  {0x44, 0x4a, 0x4a, 0x32, 0x00},
  {0x02, 0x02, 0x7e, 0x02, 0x02},
  {0x3e, 0x40, 0x40, 0x7e, 0x00},
  {0x1e, 0x60, 0x60, 0x1e, 0x00},
  {0x7e, 0x30, 0x30, 0x7e, 0x00},
  {0x66, 0x18, 0x18, 0x66, 0x00},
  {0x4e, 0x50, 0x50, 0x3e, 0x00},
  {0x62, 0x52, 0x4a, 0x46, 0x00},
  {0x00, 0xff, 0x81, 0x81, 0x00},
  {0x03, 0x0c, 0x30, 0xc0, 0x00},
  {0x00, 0x81, 0x81, 0xff, 0x00},
  {0x08, 0x04, 0x02, 0x04, 0x08},
  {0x80, 0x80, 0x80, 0x80, 0x00},
  {0x00, 0x01, 0x02, 0x00, 0x00},
  {0x20, 0x54, 0x54, 0x78, 0x00},
  {0x7f, 0x44, 0x44, 0x38, 0x00},
  {0x38, 0x44, 0x44, 0x44, 0x00},
  {0x38, 0x44, 0x44, 0x7f, 0x00},
  {0x38, 0x54, 0x54, 0x5c, 0x00},
  {0x08, 0x7e, 0x09, 0x01, 0x00},
  {0x98, 0xa4, 0xa4, 0x5c, 0x00},
  {0x7f, 0x04, 0x04, 0x78, 0x00},
  {0x00, 0x08, 0x7a, 0x40, 0x00},
  {0x80, 0x80, 0x7a, 0x00, 0x00},
  {0x7f, 0x10, 0x28, 0x44, 0x00},
  {0x00, 0x3f, 0x40, 0x40, 0x00},
  {0x7c, 0x18, 0x18, 0x7c, 0x00},
  {0x7c, 0x04, 0x04, 0x78, 0x00},
  {0x38, 0x44, 0x44, 0x38, 0x00},
  {0xfc, 0x24, 0x24, 0x18, 0x00},
  {0x18, 0x24, 0x24, 0xfc, 0x00},
  {0x78, 0x04, 0x04, 0x0c, 0x00},
  {0x48, 0x54, 0x54, 0x24, 0x00},
  {0x04, 0x3f, 0x44, 0x40, 0x00},
  {0x3c, 0x40, 0x40, 0x7c, 0x00},
  {0x1c, 0x60, 0x60, 0x1c, 0x00},
  {0x7c, 0x30, 0x30, 0x7c, 0x00},
  {0x64, 0x18, 0x18, 0x64, 0x00},
  {0x9c, 0xa0, 0xa0, 0x7c, 0x00},
  {0x44, 0x64, 0x54, 0x4c, 0x00},
  {0x18, 0x7e, 0x81, 0x81, 0x00},
  {0x00, 0x00, 0xff, 0x00, 0x00},
  {0x81, 0x81, 0x7e, 0x18, 0x00},
  {0x10, 0x08, 0x10, 0x10, 0x08},
};

// row: [0, 4)
// col: [0, 16)
static inline void print_char(int row, int col, char c)
{
#if 1
  int index = row * 256 + col * 8;
  for (int dpage = 0; dpage <= 1; dpage++)
    for (int dcol = 0; dcol < 8; dcol++)
      dispbuf[index + dpage * 128 + dcol] =
        (dcol == 7 ? 0 : Tamzen7x14[c - 32][dcol + dpage * 7]);
#else
  int index = row * 128 + col * 5;
  for (int dcol = 0; dcol < 5; dcol++)
    dispbuf[index + dcol] = Spleen5x8[c - 32][dcol];
#endif
}
static inline void print_string(int row, int col, const char *s)
{
  for (; *s != '\0'; s++) {
    if (*s == '\n') {
      row = (row + 1) % 4;
      col = 0;
    } else {
      print_char(row, col, *s);
      if (++col == 16) { col = 0; row = (row + 1) % 4; }
    }
  }
}

static inline void print_clear(int r0, int c0, int r1, int c1)
{
  for (int p = r0 * 2; p <= r1 * 2 + 1; p++)
    for (int c = c0 * 8; c <= c1 * 8 + 7; c++)
      dispbuf[p * 128 + c] = 0;
}
static inline void print_invert(int r0, int c0, int r1, int c1)
{
  for (int p = r0 * 2; p <= r1 * 2 + 1; p++)
    for (int c = c0 * 8; c <= c1 * 8 + 7; c++)
      dispbuf[p * 128 + c] ^= 0xff;
}

static inline bool flush_region_restart(int p0, int c0, int p1, int c1)
{
  uint8_t cmdbuf[] = {
    0x00,       // Co = 0, D/C# = 0 (command stream)
    // 0x20, 0x01, // Set Memory Addressing Mode - Vertical Addressing Mode
    0x21,       // Set Column Address
    c0, c1,
    0x22,       // Set Page Address
    p0, p1,
  };
  bool result = HAL_I2C_Master_Transmit(&i2c1, 0x3C << 1, cmdbuf, sizeof cmdbuf, 50);
  return (result == HAL_OK && i2c1.ErrorCode == 0);
}

static inline void flush_region(int p0, int c0, int p1, int c1)
{
  static uint8_t databuf[1025];
  databuf[0] = 0x40;  // Co = 0, D/C# = 1 (data stream)
  for (int c = c0, i = 1; c <= c1; c++)
    for (int p = p0; p <= p1; p++)
      databuf[i++] = dispbuf[p * 128 + c];
  HAL_I2C_Master_Transmit_DMA(&i2c1, 0x3C << 1, databuf, 1 + (c1 - c0 + 1) * (p1 - p0 + 1));
}

static inline bool sd1306_reset()
{
  // OLED screen
  HAL_StatusTypeDef ready = HAL_I2C_IsDeviceReady(&i2c1, 0x3C << 1, 3, 50);
  if (ready != HAL_OK) return false;

  char s[32];
  int n = snprintf(s, sizeof s, "screen ready state: %d\r\n", (int)ready);
  HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);

  uint8_t commands[] = {
    0x00, // Co = 0, D/C# = 0 (command stream)

    0xAE, // Set Display OFF
    0xA8, 0x3F, // Set Multiplex Ratio

    // Rotate upside down
    // 0xA0, 0xC0 (reset values) for original orientation
    0xA1, // Set Segment Re-map
    0xC8, // Set COM Output Scan Direction - remapped mode

    0xA4, // Entire Display ON
    0x8D, 0x14, // Set Charge Pump
    0xAF, // Set Display ON
    0x20, 0x01, // Set Memory Addressing Mode - Vertical Addressing Mode
    // 0x21, 0x00, 0x7F, // Set Column Address
    // 0x22, 0x00, 0x07, // Set Page Address
  };
  HAL_I2C_Master_Transmit(&i2c1, 0x3C << 1, commands, sizeof commands, 50);

  HAL_Delay(100);

  flush_region_restart(0, 0, 7, 127);
  flush_region(0, 0, 7, 127);
  while (HAL_I2C_GetState(&i2c1) & 0x03) HAL_Delay(1);

  return true;
}

int main()
{
  HAL_Init();

  // ======== GPIO ========
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
  GPIO_InitTypeDef GPIO_InitStruct;

  GPIO_InitStruct.Pin = GPIO_PIN_13;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);
  HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);

  // ======== UART ========
  // Clocks
  RCC_OscInitTypeDef RCC_OscInitStruct = { 0 };
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI_DIV2;
  RCC_OscInitStruct.PLL.PLLMUL = RCC_PLL_MUL16;
  HAL_RCC_OscConfig(&RCC_OscInitStruct);

  RCC_ClkInitTypeDef RCC_ClkInitStruct = { 0 };
  RCC_ClkInitStruct.ClockType =
    RCC_CLOCKTYPE_SYSCLK |
    RCC_CLOCKTYPE_HCLK |
    RCC_CLOCKTYPE_PCLK1 |
    RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;
  HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2);

  // GPIO ports
  // USART1_TX
  GPIO_InitStruct.Pin = GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);
  // USART1_RX
  GPIO_InitStruct.Pin = GPIO_PIN_10;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  // Handle
  __HAL_RCC_USART1_CLK_ENABLE();
  uart1.Instance = USART1;
  uart1.Init.BaudRate = 115200;
  uart1.Init.WordLength = UART_WORDLENGTH_8B;
  uart1.Init.StopBits = UART_STOPBITS_1;
  uart1.Init.Parity = UART_PARITY_NONE;
  uart1.Init.Mode = UART_MODE_TX_RX;
  uart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  uart1.Init.OverSampling = UART_OVERSAMPLING_16;
  HAL_UART_Init(&uart1);

  // ======== DMA ========
  __HAL_RCC_DMA1_CLK_ENABLE();
  DMA_HandleTypeDef dma_tx;
  dma_tx.Instance = DMA1_Channel6;
  dma_tx.Init.Direction = DMA_MEMORY_TO_PERIPH;
  dma_tx.Init.PeriphInc = DMA_PINC_DISABLE;
  dma_tx.Init.MemInc = DMA_MINC_ENABLE;
  dma_tx.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
  dma_tx.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
  dma_tx.Init.Mode = DMA_NORMAL;
  dma_tx.Init.Priority = DMA_PRIORITY_LOW;
  HAL_DMA_Init(&dma_tx);

  DMA_HandleTypeDef dma_rx;
  dma_rx.Instance = DMA1_Channel7;
  dma_rx.Init.Direction = DMA_PERIPH_TO_MEMORY;
  dma_rx.Init.PeriphInc = DMA_PINC_DISABLE;
  dma_rx.Init.MemInc = DMA_MINC_ENABLE;
  dma_rx.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
  dma_rx.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
  dma_rx.Init.Mode = DMA_NORMAL;
  dma_rx.Init.Priority = DMA_PRIORITY_LOW;
  HAL_DMA_Init(&dma_rx);

  HAL_NVIC_SetPriority(SysTick_IRQn, 0, 0);
  HAL_NVIC_SetPriority(DMA1_Channel6_IRQn, 15, 1);
  HAL_NVIC_EnableIRQ(DMA1_Channel6_IRQn);
  HAL_NVIC_SetPriority(DMA1_Channel7_IRQn, 15, 0);
  HAL_NVIC_EnableIRQ(DMA1_Channel7_IRQn);
  HAL_NVIC_SetPriority(I2C1_EV_IRQn, 15, 2);
  HAL_NVIC_EnableIRQ(I2C1_EV_IRQn);
  HAL_NVIC_SetPriority(I2C1_ER_IRQn, 15, 1);
  HAL_NVIC_EnableIRQ(I2C1_ER_IRQn);

  // ======== I2C ========
  // GPIO ports
  // I2C1_SCL, I2C1_SDA
  GPIO_InitStruct.Pin = GPIO_PIN_6 | GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_OD;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  __HAL_RCC_I2C1_CLK_ENABLE();
  i2c1.Instance = I2C1;
  i2c1.Init.ClockSpeed = 200000;
  i2c1.Init.DutyCycle = I2C_DUTYCYCLE_2;
  i2c1.Init.OwnAddress1 = 0x00;
  i2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  i2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  i2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  i2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  __HAL_LINKDMA(&i2c1, hdmatx, dma_tx);
  __HAL_LINKDMA(&i2c1, hdmarx, dma_rx);
  HAL_I2C_Init(&i2c1);

  // ======== Software I2C ========
  // GPIO ports
  // PB8, PB9
  GPIO_InitStruct.Pin = GPIO_PIN_8 | GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_OD;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  i2c_init();

  // ======== Main ========
  HAL_UART_Transmit(&uart1, (uint8_t *)"hello!\r\n", 8, 1000);

  HAL_Delay(5); // Stablize voltage?

  // GPIO output
  const struct {
    GPIO_TypeDef *port;
    uint16_t pin;
  } gate_outputs[16] = {
    {GPIOA, GPIO_PIN_0},
    {GPIOA, GPIO_PIN_1},
    {GPIOA, GPIO_PIN_2},
    {GPIOA, GPIO_PIN_3},
    {GPIOA, GPIO_PIN_4},
    {GPIOA, GPIO_PIN_5},
    {GPIOA, GPIO_PIN_6},
    {GPIOA, GPIO_PIN_7},
    {GPIOB, GPIO_PIN_12},
    {GPIOB, GPIO_PIN_13},
    {GPIOB, GPIO_PIN_14},
    {GPIOB, GPIO_PIN_15},
    {GPIOA, GPIO_PIN_8},
    {GPIOA, GPIO_PIN_11},
    {GPIOA, GPIO_PIN_12},
    {GPIOA, GPIO_PIN_15},
  };
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  for (int i = 0; i < 16; i++) {
    GPIO_InitStruct.Pin = gate_outputs[i].pin;
    HAL_GPIO_Init(gate_outputs[i].port, &GPIO_InitStruct);
  }

  uint8_t buf[64];
  char s[128];
  int n;

  bool screen_present = sd1306_reset();

  struct debouncer d[16] = {{ 0 }};
  for (int i = 0; i < 16; i++) {
    d[i].threshold = Threshold[i] * 64;
    debouncer_init(&d[i]);
  }

  flush_region_restart(0, 0, 7, 127);

  uint32_t last_tick = HAL_GetTick();
  int err[2] = { 0 };
  mpr121_reset(0x5A << 1);
  mpr121_reset(0x5B << 1);

  while (1) {
    static uint32_t T = 0;

    // Read data from electrodes
    for (int part = 0; part <= 1; part++) {
      uint8_t addr = (0x5A + part * 2) << 1;

      if (err[part] != 0) {
        // Retry checking every 50 ticks
        if (T % 50 != 0) continue;
        uint8_t status = 0;
        i2c_err = 0;
        i2c_read_reg(addr, 0x5E, 1, &status);
        if (i2c_err == 0 && ((status & 15) < 9)) {
          mpr121_reset(0x5A << 1);
          for (int i = 0; i < 8; i++)
            debouncer_init(&d[i + part * 8]);
        }
        // The device might not be able to be initialised (e.g. not present)
        // In such cases we keep the error code and skip
        if (i2c_err != 0) continue;
      }

      i2c_err = 0;
      i2c_read_reg(addr, 0x04, 16, buf + part * 16);
      err[part] = i2c_err;
    }

    if (!screen_present && T % 10 == 0 && (err[0] != 0 || err[1] != 0)) {
      n = snprintf(s, sizeof s, "(error %d, %d)\r\n", err[0], err[1]);
      HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);
    }

    for (int i = 0; i < 16; i++) if (err[i / 8] == 0) {
      int32_t value = ((uint32_t)buf[i * 2 + 1] << 8) | buf[i * 2 + 0];
      debouncer_update(&d[i], value * 64);
    }

    for (int i = 0; i < 16; i++)
      HAL_GPIO_WritePin(
        gate_outputs[i].port, gate_outputs[i].pin,
        (d[i].on && err[i / 8] == 0) ? GPIO_PIN_SET : GPIO_PIN_RESET);

    n = snprintf(s, sizeof s, "value = %4ld %4ld %4ld %4ld %4ld %4ld  on = %c %c %c %c %c %c\r\n",
      ((uint32_t)buf[0 * 2 + 1] << 8) | buf[0 * 2 + 0],
      ((uint32_t)buf[1 * 2 + 1] << 8) | buf[1 * 2 + 0],
      ((uint32_t)buf[2 * 2 + 1] << 8) | buf[2 * 2 + 0],
      ((uint32_t)buf[3 * 2 + 1] << 8) | buf[3 * 2 + 0],
      ((uint32_t)buf[4 * 2 + 1] << 8) | buf[4 * 2 + 0],
      ((uint32_t)buf[5 * 2 + 1] << 8) | buf[5 * 2 + 0],
      d[0].on ? '*' : '-',
      d[1].on ? '*' : '-',
      d[2].on ? '*' : '-',
      d[3].on ? '*' : '-',
      d[4].on ? '*' : '-',
      d[5].on ? '*' : '-'
    );
    if (T % 10 == 0) HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);
    // n = snprintf(s, sizeof s, "err %d %d\r\n", err[0], err[1]);
    // HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);

    if (screen_present && T % 10 == 0) {
      memset(dispbuf, 0, 128 * 8);
      for (int i = 0; i < 16; i++) {
        snprintf(s, sizeof s, " %3ld",
          min(((uint32_t)buf[i * 2 + 1] << 8) | buf[i * 2 + 0], 999)
        );
        print_string(i % 4, (i / 4) * 4, s);
        if (d[i].on)
          print_invert(i % 4, (i / 4) * 4, i % 4, (i / 4) * 4 + 3);
      }

      for (int part = 0; part <= 1; part++) if (err[part] != 0) {
        print_clear(0, part * 8 + 0, 3, part * 8 + 7);
        print_char(1, part * 8 + 1, '(');
        print_char(1, part * 8 + 2, '>');
        print_char(1, part * 8 + 3, (T / 100) % 2 == 0 ? '_' : '-');
        print_char(1, part * 8 + 4, '<');
        print_char(1, part * 8 + 5, ')');
        print_char(2, part * 8 + 2, (err[part] & 4) ? '*' : '.');
        print_char(2, part * 8 + 3, (err[part] & 2) ? '*' : '.');
        print_char(2, part * 8 + 4, (err[part] & 1) ? '*' : '.');
      }

      while (HAL_I2C_GetState(&i2c1) & 0x03) HAL_Delay(1);
      flush_region(0, 0, 7, 127);
    }

    // HAL_Delay(10);
    uint32_t cur_tick;
    do cur_tick = HAL_GetTick(); while (cur_tick < last_tick + 10);
    last_tick = cur_tick;
    if (T % 100 == 0) HAL_UART_Transmit(&uart1, (uint8_t *)"second\r\n", 8, 1000);

    if (i2c1.ErrorCode != 0) {
      int n = snprintf(s, sizeof s, "(screen error %ld)\r\n", i2c1.ErrorCode);
      HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);
      screen_present = false;
      i2c1.ErrorCode = 0;
    }

    if (!screen_present && T % 100 == 0) {
      // Try probe screen again
      screen_present = sd1306_reset();
      if (screen_present) {
        flush_region_restart(0, 0, 7, 127);
      }
      int n = snprintf(s, sizeof s, "(screen present: %d)\r\n", (int)screen_present);
      HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);
    }
    T++;
  }
}

void SysTick_Handler()
{
  HAL_IncTick();
}

void I2C1_EV_IRQHandler()
{
  HAL_I2C_EV_IRQHandler(&i2c1);
}

void I2C1_ER_IRQHandler()
{
  HAL_I2C_ER_IRQHandler(&i2c1);
}

void DMA1_Channel6_IRQHandler()
{
  HAL_DMA_IRQHandler(i2c1.hdmatx);
}

void DMA1_Channel7_IRQHandler()
{
  HAL_DMA_IRQHandler(i2c1.hdmarx);
}

void HAL_I2C_MasterTxCpltCallback(I2C_HandleTypeDef *i2c)
{
}
#include <stm32f1xx_hal.h>
#include <stdbool.h>
#include <stdio.h>

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
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
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
  UART_HandleTypeDef uart1;
  uart1.Instance = USART1;
  uart1.Init.BaudRate = 115200;
  uart1.Init.WordLength = UART_WORDLENGTH_8B;
  uart1.Init.StopBits = UART_STOPBITS_1;
  uart1.Init.Parity = UART_PARITY_NONE;
  uart1.Init.Mode = UART_MODE_TX_RX;
  uart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  uart1.Init.OverSampling = UART_OVERSAMPLING_16;
  HAL_UART_Init(&uart1);

  // ======== I2C ========
  // GPIO ports
  // I2C1_SCL, I2C1_SDA
  GPIO_InitStruct.Pin = GPIO_PIN_6 | GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_OD;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  __HAL_RCC_I2C1_CLK_ENABLE();
  I2C_HandleTypeDef i2c1 = { 0 };
  i2c1.Instance = I2C1;
  i2c1.Init.ClockSpeed = 50000;
  i2c1.Init.DutyCycle = I2C_DUTYCYCLE_2;
  i2c1.Init.OwnAddress1 = 0x00;
  i2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  i2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  i2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  i2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  HAL_I2C_Init(&i2c1);

  // ======== Main ========
  HAL_UART_Transmit(&uart1, (uint8_t *)"hello!\r\n", 8, 1000);

  // PA0, PA1 output
  GPIO_InitStruct.Pin = GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3 | GPIO_PIN_4 | GPIO_PIN_5;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  uint8_t buf[32];

  // Soft Reset
  buf[0] = 0x63;
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x80, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Up-Side Limit / Low-Side Limit / Target Level Register
  // USL = 2.6/3.3 * 256
  //  TL = USL * 0.9
  // LSL = USL * 0.5
  buf[0] = 202;
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7D, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  buf[0] = 182;
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7F, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  buf[0] = 101;
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7E, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Filter/Global CDT Configuration Register (0x5D)
  buf[0] = 0x02;  // CDT = 000, SFI = 00, ESI = 010
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x5D, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Auto-Configure Control Register 0
  buf[0] = 0x0B;  // FFI = 00, RETRY = 00, BVA = 10, ARE = 1, ACE = 1
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7B, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Electrode Configuration Register (ECR)
#define N_ELECTRODES 6
  buf[0] = 0x81 + N_ELECTRODES; // CL = 10
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x5E, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);

  HAL_Delay(100);

  bool first = true;
  struct debouncer d[N_ELECTRODES] = {{ 0 }};

  while (1) {
    // Read 0x04 through 0x2A
    HAL_I2C_Mem_Read(&i2c1, 0x5A << 1, 0x04, I2C_MEMADD_SIZE_8BIT, buf, N_ELECTRODES * 2, 1000);
    if (first) {
      first = false;
      for (int i = 0; i < N_ELECTRODES; i++) {
        d[i].threshold = (i == 2 || i == 3 || i == 4 ? 640 : 320);
        debouncer_init(&d[i]);
      }
    }
    for (int i = 0; i < N_ELECTRODES; i++) {
      int32_t value = ((uint32_t)buf[i * 2 + 1] << 8) | buf[i * 2 + 0];
      debouncer_update(&d[i], value * 64);
    }

    bool error = (i2c1.ErrorCode != HAL_I2C_ERROR_NONE);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_0, !error && d[0].on ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1, !error && d[1].on ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_2, !error && d[2].on ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, !error && d[3].on ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, !error && d[4].on ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, !error && d[5].on ? GPIO_PIN_SET : GPIO_PIN_RESET);

    char s[128];
    int n;
    if (!error) {
      n = snprintf(s, sizeof s, "value = %4ld %4ld %4ld %4ld %4ld %4ld  on = %c %c %c %c %c %c\r\n",
        ((uint32_t)buf[0 * 2 + 1] << 8) | buf[0 * 2 + 0],
        ((uint32_t)buf[1 * 2 + 1] << 8) | buf[1 * 2 + 0],
        ((uint32_t)buf[2 * 2 + 1] << 8) | buf[2 * 2 + 0],
        ((uint32_t)buf[3 * 2 + 1] << 8) | buf[3 * 2 + 0],
        ((uint32_t)buf[4 * 2 + 1] << 8) | buf[4 * 2 + 0],
        ((uint32_t)buf[5 * 2 + 1] << 8) | buf[5 * 2 + 0],
        // d[0].high / 64, d[1].high / 64, d[2].high / 64, d[3].high / 64,
        d[0].on ? '*' : '-',
        d[1].on ? '*' : '-',
        d[2].on ? '*' : '-',
        d[3].on ? '*' : '-',
        d[4].on ? '*' : '-',
        d[5].on ? '*' : '-'
      );
    } else {
      n = snprintf(s, sizeof s, "(error %ld)\r\n", i2c1.ErrorCode);
      HAL_I2C_DeInit(&i2c1);
      HAL_I2C_Init(&i2c1);
      // Soft Reset
      buf[0] = 0x63;
      HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x80, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
      first = true;
    }

    static int T;
    if (++T == 10) { T = 0; HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000); }

    HAL_Delay(10);
  }
}

void SysTick_Handler()
{
  HAL_IncTick();
}

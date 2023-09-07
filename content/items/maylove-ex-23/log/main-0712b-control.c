#include <stm32f1xx_hal.h>
#include <stdbool.h>
#include <stdio.h>

#define min(_a, _b) ((_a) < (_b) ? (_a) : (_b))
#define max(_a, _b) ((_a) > (_b) ? (_a) : (_b))

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
  uart1.Init.BaudRate = 9600;
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
  GPIO_InitStruct.Pin = GPIO_PIN_0 | GPIO_PIN_1;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  uint8_t buf[16];

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
  buf[0] = 0xe4;  // CDT = 111, SFI = 00, ESI = 100
  // HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x5D, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Auto-Configure Control Register 0
  buf[0] = 0x0B;  // FFI = 00, RETRY = 00, BVA = 10, ARE = 1, ACE = 1
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7B, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Auto-Configure Control Register 1
  buf[0] = 0x80;  // SCTS = 1
  // HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x7C, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
  // Electrode Configuration Register (ECR)
#define N_ELECTRODES 2
  buf[0] = 0x01 + N_ELECTRODES;
  HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x5E, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);

  HAL_Delay(100);

  int16_t high[N_ELECTRODES];
  int8_t count[N_ELECTRODES] = { 0 };
  bool light_on[N_ELECTRODES] = { false };
  uint8_t since_high_dec = 0;
  bool first = true;

  while (1) {
    HAL_I2C_Mem_Read(&i2c1, 0x5A << 1, 0x04, I2C_MEMADD_SIZE_8BIT, buf, 4, 1000);
    int16_t value[2] = {
      ((uint16_t)buf[1] << 8) | buf[0],
      ((uint16_t)buf[3] << 8) | buf[2],
    };
    if (++since_high_dec == 20) {
      since_high_dec = 0;
      for (int i = 0; i < N_ELECTRODES; i++)
        if (high[i] > 0) high[i]--;
    }
    // TODO: Populate with more samples
    if (first) {
      first = false;
      for (int i = 0; i < N_ELECTRODES; i++) high[i] = value[i];
    }
    for (int i = 0; i < N_ELECTRODES; i++) {
      high[i] = max(high[i], min(high[i] + 1, value[i]));
      if (value[i] < high[i] - 15)
        count[i] = min(count[i] + 1, 25); // 500 ms to fill up
      else
        count[i] = max(count[i] - 1, 0);
      if (!light_on[i] && count[i] >= 15) light_on[i] = true;
      else if (light_on[i] && count[i] < 10) light_on[i] = false;
    }

    bool error = (i2c1.ErrorCode != HAL_I2C_ERROR_NONE);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_0, !error && light_on[0] ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1, !error && light_on[1] ? GPIO_PIN_SET : GPIO_PIN_RESET);

    char s[128];
    int n;
    if (!error) {
      n = snprintf(s, sizeof s, "value = %4d %4d  high = %4d %4d  count = %2d %2d  on = %c %c\r\n",
        value[0], value[1],
        high[0], high[1],
        count[0], count[1],
        light_on[0] ? '*' : '-',
        light_on[1] ? '*' : '-'
      );
    } else {
      n = snprintf(s, sizeof s, "(error)\r\n");
      HAL_I2C_DeInit(&i2c1);
      HAL_I2C_Init(&i2c1);
      // Soft Reset
      buf[0] = 0x63;
      HAL_I2C_Mem_Write(&i2c1, 0x5A << 1, 0x80, I2C_MEMADD_SIZE_8BIT, buf, 1, 1000);
      first = true;
    }
    if (since_high_dec % 4 == 0)
      HAL_UART_Transmit(&uart1, (uint8_t *)s, n, 1000);

    HAL_Delay(10);
  }
}

void SysTick_Handler()
{
  HAL_IncTick();
}

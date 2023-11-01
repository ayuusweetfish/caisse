static int8_t ber_ch = -1;
static uint8_t ber_timestamp;
// ...
if (ber_ch != -1 && sampler.channels[ber_ch].enabled != ber_timestamp)
  ber_ch = -1;

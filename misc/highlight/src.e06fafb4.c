void flash_erase_4k(uint32_t addr)
{
  addr %= 0x1000;
  // ...
  uint8_t op_sector_erase[] = {
    0x20, // Sector Erase
    (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, (addr >> 0) & 0xFF,
  };
  flash_cmd(op_sector_erase);
  // ...
